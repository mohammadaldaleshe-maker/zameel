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

-- Preserve all existing message and call identity guards from security 144.
do $guard$
declare expression text;
begin
 select pg_get_expr(conbin,conrelid) into expression from pg_constraint
 where conrelid='public.messages'::regclass and conname='messages_media_type_check';
 if expression is not null and position('audio' in expression)=0 then
 alter table public.messages drop constraint messages_media_type_check;
 execute format('alter table public.messages add constraint messages_media_type_check check ((%s) or media_type=''audio'')',expression);
 end if;
 select pg_get_expr(conbin,conrelid) into expression from pg_constraint
 where conrelid='public.chat_attachments'::regclass and conname='chat_attachments_media_type_check';
 if expression is not null and (position('audio' in expression)=0 or position('video' in expression)=0) then
 alter table public.chat_attachments drop constraint chat_attachments_media_type_check;
 execute format('alter table public.chat_attachments add constraint chat_attachments_media_type_check check ((%s) or media_type in (''audio'',''video''))',expression);
 end if;
end $guard$;

create table if not exists public.zameel_chat_clears (
 user_id uuid not null references auth.users(id) on delete cascade,
 conversation_id uuid not null references public.conversations(id) on delete cascade,
 cleared_at timestamptz not null default now(),primary key(user_id,conversation_id));
alter table public.zameel_chat_clears enable row level security;
revoke all on public.zameel_chat_clears from anon,authenticated;

create table if not exists public.zameel_hidden_messages (
 user_id uuid not null references auth.users(id) on delete cascade,
 message_id uuid not null references public.messages(id) on delete cascade,
 primary key(user_id,message_id));
create table if not exists public.zameel_deleted_messages (
 message_id uuid primary key references public.messages(id) on delete cascade,
 deleted_by uuid not null references auth.users(id) on delete cascade,
 deleted_at timestamptz not null default now());
create table if not exists public.zameel_message_likes (
 user_id uuid not null references auth.users(id) on delete cascade,
 message_id uuid not null references public.messages(id) on delete cascade,
 primary key(user_id,message_id));
alter table public.zameel_hidden_messages enable row level security;
alter table public.zameel_deleted_messages enable row level security;
alter table public.zameel_message_likes enable row level security;
revoke all on public.zameel_hidden_messages,public.zameel_deleted_messages,public.zameel_message_likes from anon,authenticated;

create or replace function public.zameel_chat_action(p_action text,p_conversation uuid,p_message uuid default null)
returns void language plpgsql security definer set search_path='' as $$
declare me uuid:=auth.uid(); msg public.messages;
begin
 if me is null or not public.is_conversation_member(p_conversation,me) then raise exception 'conversation_membership_required';end if;
 if not public.zameel_account_can_write() then raise exception 'account_suspended_read_only';end if;
 if p_action='clear' then
 insert into public.zameel_chat_clears values(me,p_conversation,clock_timestamp())
 on conflict(user_id,conversation_id) do update set cleared_at=excluded.cleared_at;
 insert into public.zameel_hidden_messages select me,m.id from public.messages m where m.conversation_id=p_conversation on conflict do nothing;return;
 end if;
 select * into msg from public.messages where id=p_message and conversation_id=p_conversation;
 if not found then raise exception 'message_not_found';end if;
 if p_action='hide' then
 insert into public.zameel_hidden_messages values(me,p_message) on conflict do nothing;
 elsif p_action='delete_everyone' then
 if msg.sender_id<>me then raise exception 'sender_required';end if;
 insert into public.zameel_deleted_messages(message_id,deleted_by) values(p_message,me) on conflict do nothing;
 update public.messages set content='تم حذف هذه الرسالة',media_url=null,media_type=null where id=p_message;
 delete from public.zameel_message_likes where message_id=p_message;
 elsif p_action='like' then
 if msg.media_url is null or exists(select 1 from public.zameel_deleted_messages where message_id=p_message) then raise exception 'media_required';end if;
 if exists(select 1 from public.zameel_message_likes where user_id=me and message_id=p_message) then
 delete from public.zameel_message_likes where user_id=me and message_id=p_message;
 else insert into public.zameel_message_likes values(me,p_message) on conflict do nothing;end if;
 else raise exception 'invalid_action';end if;
end $$;
revoke all on function public.zameel_chat_action(text,uuid,uuid) from public,anon;
grant execute on function public.zameel_chat_action(text,uuid,uuid) to authenticated;

create or replace function public.zameel_chat_messages(p_conversation uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare me uuid:=auth.uid(); result jsonb;
begin
 if me is null or not public.is_conversation_member(p_conversation,me) then raise exception 'conversation_membership_required';end if;
 select coalesce(jsonb_agg(q.row order by q.created_at,q.id),'[]'::jsonb) into result from (
 select m.id,m.created_at,
 jsonb_build_object('id',m.id,'content',case when d.message_id is null then m.content else 'تم حذف هذه الرسالة' end,
 'sender_id',m.sender_id,'created_at',m.created_at,'media_url',case when d.message_id is null then m.media_url end,
 'media_type',case when d.message_id is null then m.media_type end,'is_read',m.is_read,'delivered_at',m.delivered_at,'read_at',m.read_at,
 'deleted',d.message_id is not null,'likes',(select count(*) from public.zameel_message_likes l where l.message_id=m.id),
 'liked',exists(select 1 from public.zameel_message_likes l where l.message_id=m.id and l.user_id=me)) as row
 from public.messages m left join public.zameel_deleted_messages d on d.message_id=m.id
 where m.conversation_id=p_conversation and not exists(select 1 from public.zameel_hidden_messages h where h.message_id=m.id and h.user_id=me)
 order by m.created_at desc,m.id desc limit 300) q;
 return result;
end $$;
revoke all on function public.zameel_chat_messages(uuid) from public,anon;
grant execute on function public.zameel_chat_messages(uuid) to authenticated;

create or replace function public.zameel_chat_calls(p_conversation uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare result jsonb;
begin
 if auth.uid() is null or not public.is_conversation_member(p_conversation,auth.uid()) then raise exception 'conversation_membership_required';end if;
 select coalesce(jsonb_agg(to_jsonb(h) order by h.created_at),'[]'::jsonb) into result
 from public.get_call_history(p_conversation) h
 where not exists(select 1 from public.zameel_chat_clears c where c.user_id=auth.uid() and c.conversation_id=p_conversation and h.created_at<=c.cleared_at);
 return result;
end $$;
revoke all on function public.zameel_chat_calls(uuid) from public,anon;
grant execute on function public.zameel_chat_calls(uuid) to authenticated;

create or replace function public.zameel_clear_call_history(p_conversation uuid default null)
returns void language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null then raise exception 'authentication_required';end if;
 insert into public.hidden_call_history(user_id,room_id)
 select auth.uid(),s.room_id from public.direct_call_sessions s
 where auth.uid() in(s.caller_id,s.callee_id) and (p_conversation is null or s.conversation_id=p_conversation)
 on conflict do nothing;
end $$;
revoke all on function public.zameel_clear_call_history(uuid) from public,anon;
grant execute on function public.zameel_clear_call_history(uuid) to authenticated;

create or replace function public.zameel_chat_presence(p_conversation uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare me uuid:=auth.uid(); result jsonb;
begin
 if me is null or not public.is_conversation_member(p_conversation,me) then raise exception 'conversation_membership_required';end if;
 select jsonb_build_object('is_online',u.show_online_status and u.last_seen_at>now()-interval '70 seconds') into result
 from public.conversation_members cm join public.users u on u.id=cm.user_id
 where cm.conversation_id=p_conversation and cm.user_id<>me
 and (select coalesce(show_online_status,true) from public.users where id=me) limit 1;
 return coalesce(result,'{"is_online":false}'::jsonb);
end $$;
revoke all on function public.zameel_chat_presence(uuid) from public,anon;
grant execute on function public.zameel_chat_presence(uuid) to authenticated;
notify pgrst,'reload schema';

commit;
