-- Zameel 038: neutral colleague discovery, visibility cleanup, clip shares,
-- and consent-aware contact calls. Run after migration 037.

begin;

alter table public.users
  add column if not exists phone_hash text,
  add column if not exists discovery_lat double precision,
  add column if not exists discovery_lng double precision,
  add column if not exists discovery_updated_at timestamptz;

create or replace function public.refresh_user_phone_hash()
returns trigger language plpgsql security definer set search_path = public as $$
declare normalized text;
begin
  normalized := regexp_replace(coalesce(new.phone, ''), '[^0-9]', '', 'g');
  if left(normalized,2)='00' then normalized:=substring(normalized from 3); end if;
  if length(normalized)=10 and left(normalized,1)='0' then normalized:='962'||substring(normalized from 2); end if;
  new.phone_hash := case when normalized = '' then null else encode(digest(normalized, 'sha256'), 'hex') end;
  return new;
end; $$;

drop trigger if exists users_refresh_phone_hash on public.users;
create trigger users_refresh_phone_hash before insert or update of phone on public.users
for each row execute function public.refresh_user_phone_hash();
update public.users set phone = phone where phone is not null;
create index if not exists users_phone_hash_idx on public.users(phone_hash) where phone_hash is not null;

create or replace function public.get_suggested_colleagues(
  search_text text default '',
  contact_hashes text[] default array[]::text[],
  viewer_lat double precision default null,
  viewer_lng double precision default null
)
returns table(user_id uuid, name text, profile_image text, match_score integer, match_reason text, request_status text)
language plpgsql security definer set search_path = public set row_security = off as $$
declare me uuid := auth.uid(); mine public.users;
begin
  if me is null then raise exception 'not_authenticated'; end if;
  select * into mine from public.users where id = me;
  if viewer_lat is not null and viewer_lng is not null then
    update public.users set discovery_lat = viewer_lat, discovery_lng = viewer_lng,
      discovery_updated_at = now() where id = me;
  end if;
  return query
  with candidates as (
    select u.*,
      (case when u.phone_hash = any(coalesce(contact_hashes, array[]::text[])) then 100 else 0 end
       + case when nullif(mine.university,'') is not null and u.university = mine.university then 45 else 0 end
       + case when nullif(mine.college,'') is not null and u.college = mine.college then 30 else 0 end
       + case when nullif(mine.department,'') is not null and u.department = mine.department then 25 else 0 end
       + least(40, 10 * (select count(*)::int from public.friend_requests a
           join public.friend_requests b on
             (case when a.sender_id = me then a.receiver_id else a.sender_id end) =
             (case when b.sender_id = u.id then b.receiver_id else b.sender_id end)
           where a.status='accepted' and b.status='accepted'
             and me in (a.sender_id,a.receiver_id) and u.id in (b.sender_id,b.receiver_id)))
       + case when viewer_lat is not null and viewer_lng is not null and u.discovery_lat is not null and u.discovery_lng is not null
               and abs(u.discovery_lat-viewer_lat)+abs(u.discovery_lng-viewer_lng) < .08 then 15 else 0 end
      )::int score
    from public.users u
    where u.id <> me
      and (coalesce(trim(search_text),'') = '' or u.name ilike '%'||trim(search_text)||'%' or u.university ilike '%'||trim(search_text)||'%' or u.department ilike '%'||trim(search_text)||'%')
      and not exists (select 1 from public.user_blocks b where (b.blocker_id=me and b.blocked_id=u.id) or (b.blocker_id=u.id and b.blocked_id=me))
      and not public.is_colleague(me,u.id)
  )
  select c.id, coalesce(nullif(c.name,''),'زميل'), c.profile_image, c.score,
    case when c.phone_hash = any(coalesce(contact_hashes,array[]::text[])) then 'من جهات اتصالك'
         when c.university = mine.university and c.department = mine.department then 'من جامعتك وتخصصك'
         when c.university = mine.university then 'من جامعتك'
         else 'صلة مقترحة' end,
    coalesce((select r.status from public.friend_requests r where (r.sender_id=me and r.receiver_id=c.id) or (r.sender_id=c.id and r.receiver_id=me) order by r.created_at desc limit 1),'none')
  from candidates c
  order by c.score desc, c.created_at desc
  limit 20;
end; $$;

revoke execute on function public.get_suggested_colleagues(text,text[],double precision,double precision) from public, anon;
grant execute on function public.get_suggested_colleagues(text,text[],double precision,double precision) to authenticated;

create or replace function public.send_colleague_request(target_user_id uuid)
returns uuid language plpgsql security definer set search_path=public set row_security=off as $$
declare me uuid:=auth.uid(); rid uuid; me_name text; target_name text;
begin
  if me is null then raise exception 'not_authenticated'; end if;
  if target_user_id is null or target_user_id=me then raise exception 'invalid_target'; end if;
  if exists(select 1 from public.user_blocks where (blocker_id=me and blocked_id=target_user_id) or (blocker_id=target_user_id and blocked_id=me)) then raise exception 'blocked'; end if;
  select id into rid from public.friend_requests where (sender_id=me and receiver_id=target_user_id) or (sender_id=target_user_id and receiver_id=me) order by created_at desc limit 1;
  if rid is not null then return rid; end if;
  select coalesce(name,'زميل') into me_name from public.users where id=me;
  select coalesce(name,'زميل') into target_name from public.users where id=target_user_id;
  insert into public.friend_requests(sender_id,receiver_id,sender_name,receiver_name) values(me,target_user_id,me_name,target_name) returning id into rid;
  return rid;
end; $$;
revoke execute on function public.send_colleague_request(uuid) from public,anon;
grant execute on function public.send_colleague_request(uuid) to authenticated;

create or replace function public.cleanup_post_shares_after_visibility()
returns trigger language plpgsql security definer set search_path=public as $$
begin
  if new.audience='private' then delete from public.shared_posts where post_id=new.id;
  elsif new.audience='friends' then delete from public.shared_posts s where s.post_id=new.id and not public.is_colleague(new.user_id,s.shared_by);
  end if;
  return new;
end; $$;
drop trigger if exists posts_cleanup_shares_visibility on public.posts;
create trigger posts_cleanup_shares_visibility after update of audience on public.posts
for each row when (old.audience is distinct from new.audience) execute function public.cleanup_post_shares_after_visibility();

create table if not exists public.shared_clips(
  id uuid primary key default gen_random_uuid(),
  clip_id uuid not null references public.clips(id) on delete cascade,
  shared_by uuid not null references public.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique(clip_id,shared_by)
);
alter table public.shared_clips enable row level security;
drop policy if exists shared_clips_read on public.shared_clips;
create policy shared_clips_read on public.shared_clips for select to authenticated using (shared_by=auth.uid() or exists(select 1 from public.clips c where c.id=clip_id and (c.user_id=auth.uid() or c.audience='public' or (c.audience='friends' and public.is_colleague(auth.uid(),c.user_id)))));
drop policy if exists shared_clips_insert on public.shared_clips;
create policy shared_clips_insert on public.shared_clips for insert to authenticated with check (shared_by=auth.uid() and exists(select 1 from public.clips c where c.id=clip_id and c.audience in ('public','friends') and c.is_hidden=false));
drop policy if exists shared_clips_delete on public.shared_clips;
create policy shared_clips_delete on public.shared_clips for delete to authenticated using (shared_by=auth.uid());

create or replace function public.sync_clip_shares_count()
returns trigger language plpgsql security definer set search_path=public as $$
begin
  update public.clips
  set shares_count=(select count(*) from public.shared_clips where clip_id=coalesce(new.clip_id,old.clip_id))
  where id=coalesce(new.clip_id,old.clip_id);
  return coalesce(new,old);
end; $$;
drop trigger if exists shared_clips_sync_counter on public.shared_clips;
create trigger shared_clips_sync_counter after insert or delete on public.shared_clips
for each row execute function public.sync_clip_shares_count();

create or replace function public.cleanup_clip_shares_after_visibility()
returns trigger language plpgsql security definer set search_path=public as $$
begin
  if new.audience='private' or new.is_hidden then delete from public.shared_clips where clip_id=new.id;
  elsif new.audience='friends' then delete from public.shared_clips s where s.clip_id=new.id and not public.is_colleague(new.user_id,s.shared_by);
  end if;
  return new;
end; $$;
drop trigger if exists clips_cleanup_shares_visibility on public.clips;
create trigger clips_cleanup_shares_visibility after update of audience,is_hidden on public.clips
for each row when (old.audience is distinct from new.audience or old.is_hidden is distinct from new.is_hidden) execute function public.cleanup_clip_shares_after_visibility();

create or replace function public.match_registered_contacts(contact_hashes text[])
returns table(user_id uuid,name text,profile_image text,phone_hash text,allow_calls boolean)
language sql stable security definer set search_path=public set row_security=off as $$
  select u.id,coalesce(nullif(u.name,''),'زميل'),u.profile_image,u.phone_hash,coalesce(u.allow_calls,true)
  from public.users u
  where u.id<>auth.uid() and u.phone_hash=any(coalesce(contact_hashes,array[]::text[]))
    and not exists(select 1 from public.user_blocks b where (b.blocker_id=auth.uid() and b.blocked_id=u.id) or (b.blocker_id=u.id and b.blocked_id=auth.uid()));
$$;
revoke execute on function public.match_registered_contacts(text[]) from public,anon;
grant execute on function public.match_registered_contacts(text[]) to authenticated;

create or replace function public.create_contact_conversation(other_user_id uuid)
returns uuid language plpgsql security definer set search_path=public set row_security=off as $$
declare me uuid:=auth.uid(); cid uuid; allowed boolean;
begin
  if me is null then raise exception 'not_authenticated'; end if;
  if other_user_id is null or other_user_id=me then raise exception 'invalid_partner'; end if;
  if public.is_blocked(me,other_user_id) then raise exception 'blocked_user'; end if;
  select coalesce(allow_calls,true) into allowed from public.users where id=other_user_id;
  if not found then raise exception 'user_not_registered'; end if;
  if not allowed then raise exception 'calls_disabled'; end if;
  select c.id into cid from public.conversations c
   where c.is_group=false
     and exists(select 1 from public.conversation_members m where m.conversation_id=c.id and m.user_id=me)
     and exists(select 1 from public.conversation_members m where m.conversation_id=c.id and m.user_id=other_user_id)
   limit 1;
  if cid is not null then return cid; end if;
  insert into public.conversations(is_group,created_by) values(false,me) returning id into cid;
  insert into public.conversation_members(conversation_id,user_id) values(cid,me),(cid,other_user_id);
  return cid;
end; $$;
revoke execute on function public.create_contact_conversation(uuid) from public,anon;
grant execute on function public.create_contact_conversation(uuid) to authenticated;

create or replace function public.start_contact_call(other_user_id uuid,target_conversation_id uuid,target_room_id text,with_video boolean default true)
returns uuid language plpgsql security definer set search_path=public set row_security=off as $$
declare me uuid:=auth.uid(); caller_name text; notification_id uuid; allowed boolean;
begin
  if me is null then raise exception 'not_authenticated'; end if;
  if other_user_id is null or other_user_id=me then raise exception 'invalid_partner'; end if;
  if target_conversation_id is null or coalesce(trim(target_room_id),'')='' then raise exception 'invalid_call_room'; end if;
  if not public.is_conversation_member(target_conversation_id,me) or not public.is_conversation_member(target_conversation_id,other_user_id) then raise exception 'conversation_membership_required'; end if;
  if public.is_blocked(me,other_user_id) then raise exception 'blocked_user'; end if;
  select coalesce(allow_calls,true) into allowed from public.users where id=other_user_id;
  if not coalesce(allowed,false) then raise exception 'calls_disabled'; end if;
  select coalesce(nullif(name,''),'زميل') into caller_name from public.users where id=me;
  insert into public.direct_call_sessions(room_id,conversation_id,caller_id,callee_id,with_video,status)
  values(target_room_id,target_conversation_id,me,other_user_id,with_video,'ringing')
  on conflict(room_id) do update set status='ringing',created_at=now(),answered_at=null,ended_at=null;
  insert into public.notifications(user_id,actor_id,type,title_ar,title_en,body_ar,body_en,data,is_read)
  values(other_user_id,me,case when with_video then 'incoming_video_call' else 'incoming_voice_call' end,
    case when with_video then 'مكالمة فيديو واردة' else 'مكالمة صوتية واردة' end,
    case when with_video then 'Incoming video call' else 'Incoming voice call' end,
    caller_name||case when with_video then ' يتصل بك عبر الفيديو' else ' يتصل بك صوتيًا' end,
    caller_name||case when with_video then ' is video calling you' else ' is calling you' end,
    jsonb_build_object('room_id',target_room_id,'conversation_id',target_conversation_id,'caller_id',me,'video',with_video),false)
  returning id into notification_id;
  return notification_id;
end; $$;
revoke execute on function public.start_contact_call(uuid,uuid,text,boolean) from public,anon;
grant execute on function public.start_contact_call(uuid,uuid,text,boolean) to authenticated;

commit;
