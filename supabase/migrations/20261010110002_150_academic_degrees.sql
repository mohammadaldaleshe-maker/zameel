begin;
create or replace function public.zameel_complete_registration(p_data jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare me uuid:=auth.uid(); au auth.users; kind text:=p_data->>'account_type';
 format text:=coalesce(p_data->>'display_name_format','first_family'); display_name text;
 first_name text:=trim(p_data->>'first_name'); father_name text:=trim(p_data->>'father_name');
 family_name text:=trim(p_data->>'family_name'); degree text:=p_data->>'academic_degree';
 v_phone text:=regexp_replace(coalesce(p_data->>'phone',''),'[[:space:]-]','','g');
 v_email text:=lower(trim(p_data->>'email')); method text:=p_data->>'verification_method';
 ev boolean; pv boolean;
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
insert into public.zameel_promotion_universities(name,city) values
('الجامعة الأردنية',''),
('الجامعة الأردنية / فرع العقبة',''),
('جامعة اليرموك',''),
('جامعة مؤتة',''),
('جامعة العلوم والتكنولوجيا الأردنية',''),
('الجامعة الهاشمية',''),
('جامعة آل البيت',''),
('جامعة البلقاء التطبيقية',''),
('جامعة البلقاء التطبيقية / كلية الأميرة رحمة',''),
('جامعة البلقاء التطبيقية / كلية عمان للعلوم المالية',''),
('جامعة البلقاء التطبيقية / كلية الأميرة عالية / إناث',''),
('جامعة البلقاء التطبيقية / كلية الهندسة التكنولوجية',''),
('جامعة البلقاء التطبيقية / كلية الزرقاء',''),
('جامعة البلقاء التطبيقية / كلية إربد',''),
('جامعة البلقاء التطبيقية / كلية الحصن',''),
('جامعة البلقاء التطبيقية / كلية عجلون',''),
('جامعة البلقاء التطبيقية / كلية الكرك',''),
('جامعة البلقاء التطبيقية / كلية الشوبك',''),
('جامعة البلقاء التطبيقية / كلية العقبة',''),
('جامعة البلقاء التطبيقية / أكاديمية الأمير حسين بن عبدالله الثاني / الموقر',''),
('جامعة البلقاء التطبيقية / كلية معان',''),
('جامعة الحسين بن طلال',''),
('جامعة الطفيلة التقنية',''),
('جامعة العلوم الإسلامية العالمية',''),
('الجامعة الألمانية الأردنية',''),
('جامعة عمان الأهلية',''),
('جامعة العلوم التطبيقية الخاصة',''),
('جامعة فيلادلفيا',''),
('جامعة الإسراء',''),
('جامعة البترا',''),
('جامعة الأميرة سمية للتكنولوجيا',''),
('جامعة الزيتونة الأردنية',''),
('جامعة جرش',''),
('جامعة إربد الأهلية',''),
('جامعة الزرقاء',''),
('جامعة عمان العربية',''),
('جامعة الشرق الأوسط',''),
('جامعة جدارا',''),
('الجامعة الأمريكية في مادبا',''),
('جامعة عجلون الوطنية',''),
('جامعة العقبة للتكنولوجيا',''),
('جامعة الحسين التقنية',''),
('جامعة العقبة للعلوم الطبية',''),
('جامعة ابن سينا للعلوم الطبية',''),
('الجامعة العربية المفتوحة',''),
('كلية عمون الجامعية التطبيقية',''),
('كلية الخوارزمي الجامعية التقنية',''),
('الكلية الجامعية العربية للتكنولوجيا',''),
('كلية لومينوس الجامعية التقنية',''),
('الكلية الجامعية الوطنية للتكنولوجيا',''),
('الأكاديمية الملكية لفنون الطهي',''),
('كلية الملكة نور الفنية للطيران المدني',''),
('كلية المركز الجغرافي الملكي الأردني للعلوم المساحية والجيومكانية',''),
('كلية الأميرة ثروت الجامعية المتوسطة',''),
('معهد الإعلام الأردني',''),
('معهد مادبا لفن الفسيفساء والترميم',''),
('كلية الزرقاء التقنية المتوسطة',''),
('كلية القادسية',''),
('كلية المجتمع الإسلامي',''),
('كلية غرناطة الجامعية المتوسطة',''),
('كلية المفرق الأهلية',''),
('كلية حطين',''),
('كلية توليدو الأهلية',''),
('جامعة البلقاء التطبيقية / كلية جرش الجامعية التقنية',''),
('كلية العلوم التربوية والآداب - الأونروا',''),
('كلية طلال أبوغزاله الجامعية للابتكار','')
on conflict(name) do nothing;
notify pgrst,'reload schema';
commit;
