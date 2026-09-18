-- Zameel 044: robust contact calls, searchable colleagues, call history,
-- editable comments and self-cleaning interaction notifications.
-- Run after migration 043.
begin;

alter table public.users add column if not exists call_sounds_enabled boolean not null default true;
alter table public.users add column if not exists notification_sounds_enabled boolean not null default true;

create or replace function public.normalize_zameel_phone(value text)
returns text language sql immutable parallel safe as $$
  select case
    when d = '' then ''
    when d ~ '^009627[0-9]{8}$' then substring(d from 3)
    when d ~ '^9627[0-9]{8}$' then d
    when d ~ '^07[0-9]{8}$' then '962' || substring(d from 2)
    when d ~ '^7[0-9]{8}$' then '962' || d
    else d end
  from (select regexp_replace(coalesce(value,''),'[^0-9]','','g') d) s;
$$;

create or replace function public.refresh_user_phone_hash()
returns trigger language plpgsql security definer set search_path=public as $$
declare normalized text;
begin
  normalized:=public.normalize_zameel_phone(new.phone);
  new.phone_hash:=case when normalized='' then null else encode(digest(normalized,'sha256'),'hex') end;
  return new;
end; $$;
update public.users set phone=phone where phone is not null;

create or replace function public.search_colleagues(search_text text)
returns table(user_id uuid,name text,username text,profile_image text,university text,college text,department text,relationship_status text)
language sql stable security definer set search_path=public set row_security=off as $$
  select u.id,coalesce(nullif(u.name,''),'زميل'),u.username,u.profile_image,u.university,u.college,u.department,
    coalesce((select r.status from public.friend_requests r where auth.uid() in(r.sender_id,r.receiver_id) and u.id in(r.sender_id,r.receiver_id) order by r.created_at desc limit 1),'none')
  from public.users u
  where auth.uid() is not null and u.id<>auth.uid()
    and coalesce(trim(search_text),'')<>''
    and (u.name ilike '%'||trim(search_text)||'%' or u.username ilike '%'||trim(search_text)||'%' or u.university ilike '%'||trim(search_text)||'%' or u.college ilike '%'||trim(search_text)||'%' or u.department ilike '%'||trim(search_text)||'%')
    and not exists(select 1 from public.user_blocks b where (b.blocker_id=auth.uid() and b.blocked_id=u.id) or (b.blocker_id=u.id and b.blocked_id=auth.uid()))
  order by (u.university=(select university from public.users where id=auth.uid())) desc,u.name limit 50;
$$;
revoke execute on function public.search_colleagues(text) from public,anon;
grant execute on function public.search_colleagues(text) to authenticated;

alter table public.post_comments add column if not exists updated_at timestamptz;
drop policy if exists post_comments_update_own on public.post_comments;
create policy post_comments_update_own on public.post_comments for update to authenticated
using(user_id=auth.uid()) with check(user_id=auth.uid());
drop policy if exists post_comments_delete_owner on public.post_comments;
create policy post_comments_delete_owner on public.post_comments for delete to authenticated
using(user_id=auth.uid() or exists(select 1 from public.posts p where p.id=post_id and p.user_id=auth.uid()));

create or replace function public.cleanup_interaction_notification()
returns trigger language plpgsql security definer set search_path=public as $$
begin
  if tg_table_name='post_comments' then
    delete from public.notifications where type in('comment','post_comment') and (data->>'comment_id'=old.id::text or (actor_id=old.user_id and data->>'post_id'=old.post_id::text));
  elsif tg_table_name='likes' then
    delete from public.notifications where type in('like','post_like') and actor_id=old.user_id and data->>'post_id'=old.post_id::text;
  end if;
  return old;
end; $$;
drop trigger if exists cleanup_comment_notification on public.post_comments;
create trigger cleanup_comment_notification after delete on public.post_comments for each row execute function public.cleanup_interaction_notification();
drop trigger if exists cleanup_like_notification on public.likes;
create trigger cleanup_like_notification after delete on public.likes for each row execute function public.cleanup_interaction_notification();

create or replace function public.cleanup_post_notifications()
returns trigger language plpgsql security definer set search_path=public as $$
begin delete from public.notifications where data->>'post_id'=old.id::text or data->>'target_post_id'=old.id::text; return old; end; $$;
drop trigger if exists cleanup_deleted_post_notifications on public.posts;
create trigger cleanup_deleted_post_notifications after delete on public.posts for each row execute function public.cleanup_post_notifications();

alter table public.direct_call_sessions drop constraint if exists direct_call_sessions_status_check;
alter table public.direct_call_sessions add constraint direct_call_sessions_status_check
check(status in('ringing','active','ended','declined','missed','cancelled','failed'));
create index if not exists direct_call_sessions_history_idx on public.direct_call_sessions(caller_id,callee_id,created_at desc);
create table if not exists public.hidden_call_history(
 user_id uuid not null references public.users(id) on delete cascade,
 room_id text not null references public.direct_call_sessions(room_id) on delete cascade,
 hidden_at timestamptz not null default now(),primary key(user_id,room_id));
alter table public.hidden_call_history enable row level security;
drop policy if exists hidden_call_history_self on public.hidden_call_history;
create policy hidden_call_history_self on public.hidden_call_history for all to authenticated using(user_id=auth.uid()) with check(user_id=auth.uid());

create or replace function public.get_call_history(target_conversation_id uuid default null)
returns table(room_id text,conversation_id uuid,other_user_id uuid,other_name text,other_image text,direction text,with_video boolean,status text,created_at timestamptz,answered_at timestamptz,ended_at timestamptz,duration_seconds integer)
language sql stable security definer set search_path=public set row_security=off as $$
 select s.room_id,s.conversation_id,case when s.caller_id=auth.uid() then s.callee_id else s.caller_id end,
  coalesce(nullif(u.name,''),'زميل'),u.profile_image,case when s.caller_id=auth.uid() then 'outgoing' else 'incoming' end,
  s.with_video,s.status,s.created_at,s.answered_at,s.ended_at,
  greatest(0,extract(epoch from(coalesce(s.ended_at,case when s.status='active' then now() else s.answered_at end)-s.answered_at))::int)
 from public.direct_call_sessions s join public.users u on u.id=case when s.caller_id=auth.uid() then s.callee_id else s.caller_id end
 where auth.uid() in(s.caller_id,s.callee_id) and (target_conversation_id is null or s.conversation_id=target_conversation_id)
  and not exists(select 1 from public.hidden_call_history h where h.user_id=auth.uid() and h.room_id=s.room_id)
 order by s.created_at desc limit 200;
$$;
revoke execute on function public.get_call_history(uuid) from public,anon;
grant execute on function public.get_call_history(uuid) to authenticated;

create or replace function public.hide_call_from_my_history(target_room_id text)
returns void language sql security definer set search_path=public set row_security=off as $$
 insert into public.hidden_call_history(user_id,room_id)
 select auth.uid(),s.room_id from public.direct_call_sessions s where s.room_id=target_room_id and auth.uid() in(s.caller_id,s.callee_id)
 on conflict do nothing;
$$;
revoke execute on function public.hide_call_from_my_history(text) from public,anon;
grant execute on function public.hide_call_from_my_history(text) to authenticated;

commit;
