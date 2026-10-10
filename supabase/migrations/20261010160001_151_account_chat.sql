begin;
alter table public.users drop constraint if exists users_account_type_check;
alter table public.users add constraint users_account_type_check check(account_type in ('general','student','graduate'));
alter table public.zameel_registration_profiles drop constraint if exists registration_133_student_check;
alter table public.zameel_registration_profiles add constraint registration_133_student_check check(account_type in ('general','student','graduate') and (account_type='general' or (nullif(trim(university),'') is not null and nullif(trim(college),'') is not null and nullif(trim(major),'') is not null)));
create table if not exists public.zameel_academic_changes(id bigint generated always as identity primary key,user_id uuid references public.users(id) on delete cascade,old_status text,new_status text,changed_at timestamptz not null default now());
alter table public.zameel_academic_changes enable row level security;
revoke all on public.zameel_academic_changes from public,anon,authenticated;
grant select on public.zameel_academic_changes to service_role;
create or replace function public.zameel_update_academic_status(p_status text,p_university text default '',p_college text default '',p_major text default '') returns void language plpgsql security definer set search_path='' as $$
declare me uuid:=auth.uid();old_status text; begin
 if me is null or not public.zameel_account_can_write() then raise exception 'account_unavailable';end if;
 if p_status is null or p_status not in ('general','student','graduate') or greatest(length(coalesce(p_university,'')),length(coalesce(p_college,'')),length(coalesce(p_major,'')))>300 then raise exception 'invalid_academic_status';end if;
 if p_status<>'general' and (coalesce(length(trim(p_university)),0)<2 or coalesce(length(trim(p_college)),0)<2 or coalesce(length(trim(p_major)),0)<2) then raise exception 'academic_details_required';end if;
 select account_type into old_status from public.users where id=me for update;
 if not found then raise exception 'account_missing';end if;
 update public.zameel_registration_profiles set account_type=p_status,
 university=case when p_status='general' then university else trim(p_university) end,
 college=case when p_status='general' then college else trim(p_college) end,
 major=case when p_status='general' then major else trim(p_major) end,updated_at=now() where user_id=me;
 update public.users set account_type=p_status,
 role=case when role in ('student','visitor') then case when p_status='student' then 'student' else 'visitor' end else role end,
 university=case when p_status='general' then '' else trim(p_university) end,
 college=case when p_status='general' then '' else trim(p_college) end,
 department=case when p_status='general' then '' else trim(p_major) end where id=me;
 if old_status is distinct from p_status then insert into public.zameel_academic_changes(user_id,old_status,new_status) values(me,old_status,p_status);end if;
end $$;
revoke all on function public.zameel_update_academic_status(text,text,text,text) from public,anon;
grant execute on function public.zameel_update_academic_status(text,text,text,text) to authenticated;
-- Typing state contains no draft text; only members can write/read, and signals expire.
create table if not exists public.zameel_chat_typing(conversation_id uuid not null references public.conversations(id) on delete cascade,user_id uuid not null references public.users(id) on delete cascade,expires_at timestamptz not null,primary key(conversation_id,user_id));
alter table public.zameel_chat_typing enable row level security;
revoke all on public.zameel_chat_typing from public,anon,authenticated;
create or replace function public.zameel_chat_typing_set(p_conversation uuid,p_active boolean) returns void language plpgsql security definer set search_path='' as $$
declare me uuid:=auth.uid();begin
 if me is null or not public.is_conversation_member(p_conversation,me) or not public.zameel_account_can_write() then raise exception 'conversation_access_denied';end if;
 if exists(select 1 from public.conversation_members cm where cm.conversation_id=p_conversation and cm.user_id<>me and public.is_blocked(me,cm.user_id)) then raise exception 'conversation_access_denied';end if;
 if p_active then insert into public.zameel_chat_typing values(p_conversation,me,now()+interval '6 seconds') on conflict(conversation_id,user_id) do update set expires_at=excluded.expires_at;
 else delete from public.zameel_chat_typing where conversation_id=p_conversation and user_id=me;end if;
end $$;
create or replace function public.zameel_chat_typing_get(p_conversation uuid) returns boolean language plpgsql stable security definer set search_path='' as $$
declare me uuid:=auth.uid();begin
 if me is null or not public.is_conversation_member(p_conversation,me) then raise exception 'conversation_access_denied';end if;
 return exists(select 1 from public.zameel_chat_typing t where t.conversation_id=p_conversation and t.user_id<>me and t.expires_at>now() and not public.is_blocked(me,t.user_id));
end $$;
create or replace function public.zameel_chat_inbox() returns jsonb language sql stable security definer set search_path='' as $$
 select coalesce(jsonb_agg(v order by v.last_message_at desc nulls last,v.name,v.id),'[]'::jsonb) from (
 select distinct on(u.id) u.id,u.name,u.profile_image,max(m.created_at) as last_message_at
 from public.conversation_members mine join public.conversations c on c.id=mine.conversation_id and not c.is_group join public.conversation_members other on other.conversation_id=mine.conversation_id and other.user_id<>mine.user_id
 join public.users u on u.id=other.user_id left join public.messages m on m.conversation_id=mine.conversation_id
 where mine.user_id=auth.uid() and not public.is_blocked(auth.uid(),u.id)
 group by u.id,u.name,u.profile_image
 union all select distinct u.id,u.name,u.profile_image,null::timestamptz from public.friend_requests f join public.users u on u.id=case when f.sender_id=auth.uid() then f.receiver_id else f.sender_id end
 where f.status='accepted' and auth.uid() in(f.sender_id,f.receiver_id) and not public.is_blocked(auth.uid(),u.id)
 and not exists(select 1 from public.conversation_members a join public.conversations c on c.id=a.conversation_id and not c.is_group join public.conversation_members b on b.conversation_id=a.conversation_id where a.user_id=auth.uid() and b.user_id=u.id)
 ) v
$$;
revoke all on function public.zameel_chat_typing_set(uuid,boolean),public.zameel_chat_typing_get(uuid),public.zameel_chat_inbox() from public,anon;
grant execute on function public.zameel_chat_typing_set(uuid,boolean),public.zameel_chat_typing_get(uuid),public.zameel_chat_inbox() to authenticated;
create or replace function public.can_access_community_scope(
  p_scope text,
  p_university text,
  p_college text,
  p_department text
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select
    auth.uid() is not null
    and (
      p_scope = 'global'
      or exists (
        select 1
        from public.users u
        where u.id = auth.uid() and u.account_type<>'graduate'
          and nullif(trim(u.university),'') is not null
          and lower(trim(u.university)) = lower(trim(coalesce(p_university,'')))
          and (
            (p_scope = 'faculty'
              and nullif(trim(u.college),'') is not null
              and lower(trim(u.college)) = lower(trim(coalesce(p_college,''))))
            or
            (p_scope = 'major'
              and nullif(trim(u.college),'') is not null
              and nullif(trim(u.department),'') is not null
              and lower(trim(u.college)) = lower(trim(coalesce(p_college,'')))
              and lower(trim(u.department)) = lower(trim(coalesce(p_department,''))))
          )
      )
    );
$$;


notify pgrst,'reload schema';
commit;
