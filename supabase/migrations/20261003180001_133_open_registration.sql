-- 133: open registration. Existing Auth identities, roles and academic data survive.
begin;
alter table public.users add column if not exists account_type text;
update public.users set account_type=case when role='student' and nullif(trim(university),'') is not null
 then 'student' else 'general' end where account_type is null;
alter table public.users alter column account_type set default 'general';
alter table public.users alter column account_type set not null;
alter table public.users drop constraint if exists users_account_type_check;
alter table public.users add constraint users_account_type_check check(account_type in ('general','student'));
alter table public.zameel_registration_profiles add column if not exists account_type text not null default 'student';
alter table public.zameel_registration_profiles add column if not exists academic_degree text;
alter table public.zameel_registration_profiles add column if not exists student_number text;
alter table public.zameel_registration_profiles alter column university drop not null;
alter table public.zameel_registration_profiles alter column college drop not null;
alter table public.zameel_registration_profiles alter column major drop not null;
alter table public.zameel_registration_profiles alter column academic_year drop not null;
alter table public.zameel_registration_profiles drop constraint if exists registration_133_student_check;
-- Legacy students remain valid without retroactively demanding new fields.
alter table public.zameel_registration_profiles add constraint registration_133_student_check
 check(account_type in ('student','general') and (account_type='general' or
 (nullif(trim(university),'') is not null and nullif(trim(college),'') is not null and nullif(trim(major),'') is not null)));
-- The server derives verification from Auth, rather than trusting client booleans.
revoke insert,update,delete on public.zameel_registration_profiles from anon,authenticated;
create or replace function public.zameel_complete_registration(p_data jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare me uuid:=auth.uid(); au auth.users; kind text:=p_data->>'account_type';
 format text:=coalesce(p_data->>'display_name_format','first_family'); display_name text;
 first_name text:=trim(p_data->>'first_name'); father_name text:=trim(p_data->>'father_name');
 family_name text:=trim(p_data->>'family_name'); degree text:=p_data->>'academic_degree';
 v_phone text:=regexp_replace(coalesce(p_data->>'phone',''),'[^0-9+]','','g');
 v_email text:=lower(trim(p_data->>'email')); method text:=p_data->>'verification_method';
 ev boolean; pv boolean;
begin
 if me is null then raise exception 'authentication_required'; end if;
 select * into au from auth.users where id=me;
 ev:=au.email_confirmed_at is not null and lower(au.email)=v_email;
 pv:=au.phone_confirmed_at is not null and regexp_replace(au.phone,'[^0-9]','','g')=regexp_replace(v_phone,'[^0-9]','','g');
 if kind is null or kind not in ('general','student') or format not in ('first_father','first_family','full_three')
 or first_name is null or length(first_name) not between 2 and 40
 or father_name is null or length(father_name) not between 2 and 40
 or family_name is null or length(family_name) not between 2 and 60
 or (p_data->>'gender') is null or p_data->>'gender' not in ('male','female')
 or v_email is null or v_email !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$'
 or v_phone !~ '^\+9627[789][0-9]{7}$' then raise exception 'invalid_registration'; end if;
 if method is null or method not in ('email','phone') or
 (method='email' and not coalesce(ev,false)) or (method='phone' and not coalesce(pv,false)) then
 raise exception 'verified_contact_required'; end if;
 if kind='student' and (degree is null or degree not in ('bachelor','master','doctorate')
 or nullif(trim(p_data->>'student_number'),'') is null or length(p_data->>'student_number')>60
 or coalesce(length(trim(p_data->>'university')),0)<2
 or coalesce(length(trim(p_data->>'college')),0)<2
 or coalesce(length(trim(p_data->>'major')),0)<2) then raise exception 'student_details_required'; end if;
 -- Serialize retries and prevent completed profiles from being overwritten by signup.
 perform 1 from public.users where id=me for update;
 if exists(select 1 from public.users where id=me and onboarding_complete) then
 return jsonb_build_object('completed',true,'already_complete',true); end if;
 display_name:=case format when 'first_father' then first_name||' '||father_name
 when 'full_three' then first_name||' '||father_name||' '||family_name else first_name||' '||family_name end;
 insert into public.zameel_registration_profiles(user_id,first_name,father_name,family_name,
 display_name_format,phone,email,verification_method,email_verified,phone_verified,
 university,college,major,academic_year,gender,onboarding_complete,account_type,academic_degree,student_number)
 values(me,first_name,father_name,family_name,format,v_phone,v_email,method,coalesce(ev,false),coalesce(pv,false),
 case when kind='student' then trim(p_data->>'university') end,
 case when kind='student' then trim(p_data->>'college') end,
 case when kind='student' then trim(p_data->>'major') end,
 case when kind='student' then case when degree='bachelor' then 'first' else 'graduate' end end,
 p_data->>'gender',true,kind,case when kind='student' then degree end,
 case when kind='student' then trim(p_data->>'student_number') end)
 on conflict(user_id) do update set first_name=excluded.first_name,father_name=excluded.father_name,
 family_name=excluded.family_name,display_name_format=excluded.display_name_format,
 phone=excluded.phone,email=excluded.email,verification_method=excluded.verification_method,
 email_verified=excluded.email_verified,phone_verified=excluded.phone_verified,
 university=excluded.university,college=excluded.college,major=excluded.major,
 academic_year=excluded.academic_year,gender=excluded.gender,onboarding_complete=true,
 account_type=excluded.account_type,academic_degree=excluded.academic_degree,student_number=excluded.student_number,updated_at=now();
 update public.users set name=display_name,email=v_email,phone=v_phone,
 university=case when kind='student' then trim(p_data->>'university') else '' end,
 college=case when kind='student' then trim(p_data->>'college') else '' end,
 department=case when kind='student' then trim(p_data->>'major') else '' end,
 account_type=kind,role=case when role in ('student','visitor') then case when kind='student' then 'student' else 'visitor' end else role end,gender=p_data->>'gender',display_name_format=format,onboarding_complete=true where id=me;
 update auth.users set raw_user_meta_data=coalesce(raw_user_meta_data,'{}'::jsonb)-'registration' where id=me;
 return jsonb_build_object('completed',true,'account_type',kind);
end $$;
revoke all on function public.zameel_complete_registration(jsonb) from public,anon;
grant execute on function public.zameel_complete_registration(jsonb) to authenticated;
commit;
