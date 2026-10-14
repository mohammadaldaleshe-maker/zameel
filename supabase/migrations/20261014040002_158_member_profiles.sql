begin;
create table public.zameel_member_settings158(
 user_id uuid primary key references public.users(id) on delete cascade,
 birth_date date check(birth_date>=date '1960-01-01'),
 show_birthday boolean not null default false,
 allow_friend_posts boolean not null default false,
 updated_at timestamptz not null default now()
);
alter table public.zameel_member_settings158 enable row level security;
revoke all on public.zameel_member_settings158 from public,anon,authenticated;
create or replace function public.zameel_member_settings_read158(p_owner uuid)
returns jsonb language plpgsql stable security definer set search_path=public,pg_temp as $$
declare r zameel_member_settings158;allowed boolean;
begin
 if auth.uid() is null or not zameel_account_can_read() or is_blocked(auth.uid(),p_owner) then raise exception 'not_allowed';end if;
 select * into r from zameel_member_settings158 where user_id=p_owner;
 allowed:=auth.uid()=p_owner or exists(select 1 from users where id=p_owner and (account_privacy='public' or is_colleague(auth.uid(),p_owner)));
 return jsonb_build_object('birth_date',case when allowed and (auth.uid()=p_owner or r.show_birthday) then r.birth_date end,
 'show_birthday',coalesce(r.show_birthday,false),'allow_friend_posts',coalesce(r.allow_friend_posts,false),
 'can_post',coalesce(r.allow_friend_posts,false) and auth.uid()<>p_owner and is_colleague(auth.uid(),p_owner));
end $$;
create or replace function public.zameel_member_settings_save158(p_birth date,p_show boolean,p_allow boolean)
returns void language plpgsql security definer set search_path=public,pg_temp as $$
begin
 if auth.uid() is null or not zameel_account_can_write() then raise exception 'not_allowed';end if;
 if p_birth is not null and (p_birth<date '1960-01-01' or p_birth>(now() at time zone 'Asia/Amman')::date) then raise exception 'invalid_birth_date';end if;
 if p_birth is not null and exists(select 1 from users where id=auth.uid() and account_type='student') and p_birth>((now() at time zone 'Asia/Amman')::date-interval '17 years')::date then raise exception 'student_minimum_age_17';end if;
 insert into zameel_member_settings158(user_id,birth_date,show_birthday,allow_friend_posts) values(auth.uid(),p_birth,coalesce(p_show,false),coalesce(p_allow,false))
 on conflict(user_id) do update set birth_date=excluded.birth_date,show_birthday=excluded.show_birthday,allow_friend_posts=excluded.allow_friend_posts,updated_at=now();
end $$;
create or replace function public.zameel_complete_registration(p_data jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare me uuid:=auth.uid(); au auth.users; kind text:=p_data->>'account_type';
 format text:=coalesce(p_data->>'display_name_format','first_family'); display_name text;
 first_name text:=trim(p_data->>'first_name'); father_name text:=trim(p_data->>'father_name');
 family_name text:=trim(p_data->>'family_name'); degree text:=p_data->>'academic_degree';
 v_phone text:=regexp_replace(coalesce(p_data->>'phone',''),'[[:space:]-]','','g');
 v_email text:=lower(trim(p_data->>'email')); method text:=p_data->>'verification_method';
 ev boolean; pv boolean; birth date; today date:=(now() at time zone 'Asia/Amman')::date;
begin
 if me is null then raise exception 'authentication_required'; end if;
 if v_phone like '00962%' then v_phone:='+962'||substr(v_phone,6);
 elsif v_phone like '07%' then v_phone:='+962'||substr(v_phone,2);end if;
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
 if method is distinct from 'email' or not coalesce(ev,false) then
 raise exception 'verified_email_required'; end if;
 pv:=false;
 if kind='student' and (degree is null or degree not in ('bachelor','master','doctorate','diploma','higher_diploma','associate_first','associate_second')
 or nullif(trim(p_data->>'student_number'),'') is null or length(p_data->>'student_number')>60
 or coalesce(length(trim(p_data->>'university')),0)<2
 or coalesce(length(trim(p_data->>'college')),0)<2
 or coalesce(length(trim(p_data->>'major')),0)<2) then raise exception 'student_details_required'; end if;
 -- Serialize retries and prevent completed profiles from being overwritten by signup.
 perform 1 from public.users where id=me for update;
 if exists(select 1 from public.users where id=me and onboarding_complete) then
 return jsonb_build_object('completed',true,'already_complete',true); end if;
 begin birth:=(p_data->>'birth_date')::date;exception when others then raise exception 'invalid_birth_date';end;
 if birth is null or birth<date '1960-01-01' or birth>today then raise exception 'invalid_birth_date';end if;
 if kind='student' and birth>(today-interval '17 years')::date then raise exception 'student_minimum_age_17';end if;
 insert into public.zameel_member_settings158(user_id,birth_date) values(me,birth)
 on conflict(user_id) do update set birth_date=excluded.birth_date,updated_at=now();
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

revoke all on function public.zameel_member_settings_read158(uuid),public.zameel_member_settings_save158(date,boolean,boolean) from public,anon;
grant execute on function public.zameel_member_settings_read158(uuid),public.zameel_member_settings_save158(date,boolean,boolean) to authenticated;
notify pgrst,'reload schema';commit;
