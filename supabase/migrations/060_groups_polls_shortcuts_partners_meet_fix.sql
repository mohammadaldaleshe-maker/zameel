-- Zameel 060: groups/polls polish, owner partner management, and standalone Meet signaling.
-- Safe to run after 059_activate_remaining_services.sql.
begin;

-- ---------------------------------------------------------------------------
-- Groups: owner deletion + canonical message feed with sender metadata.
-- ---------------------------------------------------------------------------
create or replace function public.delete_community_group(target_group_id uuid)
returns void
language plpgsql
security definer
set search_path=public
set row_security=off
as $$
declare me uuid:=auth.uid();
begin
  if me is null then raise exception 'not_authenticated'; end if;
  delete from public.community_groups
  where id=target_group_id and owner_id=me;
  if not found then raise exception 'group_owner_required'; end if;
end $$;

create or replace function public.get_community_group_messages(target_group_id uuid)
returns table(
  id uuid,
  user_id uuid,
  sender_name text,
  sender_image text,
  content text,
  created_at timestamptz
)
language plpgsql
security definer
set search_path=public
set row_security=off
stable
as $$
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  if not exists(
    select 1 from public.community_group_members gm
    where gm.group_id=target_group_id and gm.user_id=auth.uid()
  ) then raise exception 'group_membership_required'; end if;

  return query
  select m.id,m.user_id,coalesce(u.name,'زميل'),u.profile_image,m.content,m.created_at
  from public.community_group_messages m
  join public.users u on u.id=m.user_id
  where m.group_id=target_group_id
  order by m.created_at,m.id;
end $$;

-- ---------------------------------------------------------------------------
-- Polls: allow a user to change their vote and allow creator deletion.
-- ---------------------------------------------------------------------------
create or replace function public.vote_poll(target_poll_id uuid, target_option_id uuid)
returns void
language plpgsql
security definer
set search_path=public
set row_security=off
as $$
declare me uuid:=auth.uid(); p public.polls;
begin
  if me is null then raise exception 'not_authenticated'; end if;
  select * into p from public.polls where id=target_poll_id;
  if p.id is null then raise exception 'poll_not_found'; end if;
  if p.is_closed or (p.closes_at is not null and p.closes_at<=now()) then raise exception 'poll_closed'; end if;
  if not exists(select 1 from public.poll_options where id=target_option_id and poll_id=target_poll_id) then
    raise exception 'invalid_option';
  end if;

  insert into public.poll_votes(poll_id,option_id,user_id,created_at)
  values(target_poll_id,target_option_id,me,now())
  on conflict(poll_id,user_id)
  do update set option_id=excluded.option_id,created_at=now();
end $$;

create or replace function public.delete_poll(target_poll_id uuid)
returns void
language plpgsql
security definer
set search_path=public
set row_security=off
as $$
declare me uuid:=auth.uid();
begin
  if me is null then raise exception 'not_authenticated'; end if;
  delete from public.polls where id=target_poll_id and creator_id=me;
  if not found then raise exception 'poll_owner_required'; end if;
end $$;

drop function if exists public.get_polls();
create function public.get_polls()
returns table(
  id uuid,
  creator_id uuid,
  question text,
  is_closed boolean,
  created_at timestamptz,
  creator_name text,
  options jsonb,
  user_choice uuid,
  is_owner boolean
)
language sql
security definer
set search_path=public
set row_security=off
stable
as $$
  select p.id,p.creator_id,p.question,
         (p.is_closed or (p.closes_at is not null and p.closes_at<=now())),
         p.created_at,coalesce(u.name,'زميل'),
         coalesce((
           select jsonb_agg(jsonb_build_object(
             'id',o.id,'text',o.text,'order',o.option_order,
             'votes',(select count(*) from public.poll_votes v where v.option_id=o.id)
           ) order by o.option_order)
           from public.poll_options o where o.poll_id=p.id
         ),'[]'::jsonb),
         (select v.option_id from public.poll_votes v where v.poll_id=p.id and v.user_id=auth.uid() limit 1),
         p.creator_id=auth.uid()
  from public.polls p
  join public.users u on u.id=p.creator_id
  order by p.created_at desc;
$$;

-- ---------------------------------------------------------------------------
-- Zameel owner/admin partner controls.
-- ---------------------------------------------------------------------------
create or replace function public.is_zameel_owner(target_user_id uuid default auth.uid())
returns boolean
language sql
security definer
set search_path=public
set row_security=off
stable
as $$
  select exists(
    select 1 from public.users u
    where u.id=target_user_id and lower(coalesce(u.role,'')) in ('owner','admin')
  );
$$;

create or replace function public.admin_add_business_partner(
  target_name text,
  target_category text default 'services',
  target_tag text default '',
  target_description text default '',
  target_website_url text default null,
  target_logo_url text default null
)
returns uuid
language plpgsql
security definer
set search_path=public
set row_security=off
as $$
declare me uuid:=auth.uid(); new_id uuid;
begin
  if me is null then raise exception 'not_authenticated'; end if;
  if not public.is_zameel_owner(me) then raise exception 'zameel_owner_required'; end if;
  if char_length(trim(coalesce(target_name,'')))<1 then raise exception 'partner_name_required'; end if;
  if target_category not in ('offers','education','career','services') then raise exception 'invalid_partner_category'; end if;

  insert into public.business_partners(
    owner_id,name,category,tag,description,website_url,logo_url,is_approved,is_active
  ) values(
    me,trim(target_name),target_category,coalesce(trim(target_tag),''),
    coalesce(trim(target_description),''),nullif(trim(coalesce(target_website_url,'')),''),
    nullif(trim(coalesce(target_logo_url,'')),''),true,true
  ) returning id into new_id;
  return new_id;
end $$;

create or replace function public.admin_delete_business_partner(target_partner_id uuid)
returns void
language plpgsql
security definer
set search_path=public
set row_security=off
as $$
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  if not public.is_zameel_owner(auth.uid()) then raise exception 'zameel_owner_required'; end if;
  delete from public.business_partners where id=target_partner_id;
  if not found then raise exception 'partner_not_found'; end if;
end $$;

-- Let both owner and admin roles approve/manage partner records.
create or replace function public.protect_business_partner_approval()
returns trigger
language plpgsql
security definer
set search_path=public
as $$
begin
  if auth.uid() is not null
     and new.is_approved is distinct from old.is_approved
     and not exists(
       select 1 from public.users u
       where u.id=auth.uid() and lower(coalesce(u.role,'')) in ('owner','admin')
     ) then
    raise exception 'partner_approval_requires_admin';
  end if;
  return new;
end $$;

-- ---------------------------------------------------------------------------
-- Standalone Zameel Meet. Direct-call tables/RPCs remain untouched.
-- ---------------------------------------------------------------------------
create table if not exists public.meeting_room_members(
  room_code text not null references public.meeting_rooms(room_code) on delete cascade,
  user_id uuid not null references public.users(id) on delete cascade,
  joined_at timestamptz not null default now(),
  primary key(room_code,user_id)
);

create table if not exists public.meeting_signals(
  id bigint generated by default as identity primary key,
  room_code text not null references public.meeting_rooms(room_code) on delete cascade,
  sender_id uuid not null references public.users(id) on delete cascade,
  payload jsonb not null,
  created_at timestamptz not null default now()
);
create index if not exists meeting_signals_room_id_idx on public.meeting_signals(room_code,id);

-- Backfill hosts for rooms created by older app builds and keep compatibility
-- if any legacy code still inserts meeting_rooms directly.
insert into public.meeting_room_members(room_code,user_id)
select r.room_code,r.host_id from public.meeting_rooms r
on conflict(room_code,user_id) do nothing;

create or replace function public.meeting_room_add_host_membership()
returns trigger
language plpgsql
security definer
set search_path=public
set row_security=off
as $$
begin
  insert into public.meeting_room_members(room_code,user_id)
  values(new.room_code,new.host_id)
  on conflict(room_code,user_id) do nothing;
  return new;
end $$;

drop trigger if exists meeting_room_add_host_member on public.meeting_rooms;
create trigger meeting_room_add_host_member
after insert on public.meeting_rooms
for each row execute function public.meeting_room_add_host_membership();

alter table public.meeting_room_members enable row level security;
alter table public.meeting_signals enable row level security;

drop policy if exists meeting_room_members_self_read on public.meeting_room_members;
create policy meeting_room_members_self_read on public.meeting_room_members
for select to authenticated
using(user_id=auth.uid());

drop policy if exists meeting_signals_member_read on public.meeting_signals;
create policy meeting_signals_member_read on public.meeting_signals
for select to authenticated
using(exists(
  select 1 from public.meeting_room_members m
  where m.room_code=meeting_signals.room_code and m.user_id=auth.uid()
));

create or replace function public.create_zameel_meeting(target_title text)
returns text
language plpgsql
security definer
set search_path=public
set row_security=off
as $$
declare me uuid:=auth.uid(); new_code text;
begin
  if me is null then raise exception 'not_authenticated'; end if;
  if char_length(trim(coalesce(target_title,'')))<1 then raise exception 'meeting_title_required'; end if;
  loop
    new_code:='ZM'||upper(substr(replace(gen_random_uuid()::text,'-',''),1,8));
    exit when not exists(select 1 from public.meeting_rooms where room_code=new_code);
  end loop;
  insert into public.meeting_rooms(room_code,host_id,title,is_active)
  values(new_code,me,trim(target_title),true);
  insert into public.meeting_room_members(room_code,user_id) values(new_code,me)
  on conflict do nothing;
  return new_code;
end $$;

create or replace function public.join_zameel_meeting(target_room_code text)
returns table(room_code text,title text,host_id uuid)
language plpgsql
security definer
set search_path=public
set row_security=off
as $$
declare me uuid:=auth.uid(); r public.meeting_rooms; member_count integer;
begin
  if me is null then raise exception 'not_authenticated'; end if;
  select mr.* into r from public.meeting_rooms mr
  where upper(mr.room_code)=upper(trim(target_room_code))
  for update;
  if r.id is null then raise exception 'meeting_not_found'; end if;
  if not r.is_active then raise exception 'meeting_ended'; end if;

  if not exists(select 1 from public.meeting_room_members m where m.room_code=r.room_code and m.user_id=me) then
    select count(*) into member_count from public.meeting_room_members m where m.room_code=r.room_code;
    if member_count>=2 then raise exception 'meeting_full'; end if;
    insert into public.meeting_room_members(room_code,user_id) values(r.room_code,me);
  end if;

  return query select r.room_code,r.title,r.host_id;
end $$;

create or replace function public.send_meeting_signal(target_room_code text, signal_payload jsonb)
returns bigint
language plpgsql
security definer
set search_path=public
set row_security=off
as $$
declare me uuid:=auth.uid(); new_id bigint;
begin
  if me is null then raise exception 'not_authenticated'; end if;
  if jsonb_typeof(signal_payload)<>'object' then raise exception 'invalid_signal_payload'; end if;
  if not exists(
    select 1 from public.meeting_room_members m
    join public.meeting_rooms r on r.room_code=m.room_code
    where m.room_code=target_room_code and m.user_id=me and r.is_active
  ) then raise exception 'meeting_membership_required'; end if;
  insert into public.meeting_signals(room_code,sender_id,payload)
  values(target_room_code,me,signal_payload)
  returning id into new_id;
  return new_id;
end $$;

create or replace function public.get_meeting_signals(target_room_code text, after_signal_id bigint default 0)
returns table(signal_id bigint,sender_id uuid,payload jsonb)
language plpgsql
security definer
set search_path=public
set row_security=off
stable
as $$
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  if not exists(
    select 1 from public.meeting_room_members m
    where m.room_code=target_room_code and m.user_id=auth.uid()
  ) then raise exception 'meeting_membership_required'; end if;
  return query
  select s.id,s.sender_id,s.payload
  from public.meeting_signals s
  where s.room_code=target_room_code and s.id>after_signal_id
  order by s.id
  limit 500;
end $$;

create or replace function public.leave_zameel_meeting(target_room_code text)
returns void
language plpgsql
security definer
set search_path=public
set row_security=off
as $$
declare me uuid:=auth.uid(); host uuid;
begin
  if me is null then return; end if;
  select host_id into host from public.meeting_rooms where room_code=target_room_code;
  if host=me then
    update public.meeting_rooms set is_active=false,ended_at=coalesce(ended_at,now())
    where room_code=target_room_code;
  else
    delete from public.meeting_room_members where room_code=target_room_code and user_id=me;
  end if;
end $$;

create or replace function public.get_my_zameel_meetings()
returns table(
  room_code text,title text,host_id uuid,is_active boolean,created_at timestamptz,ended_at timestamptz,participant_count bigint
)
language sql
security definer
set search_path=public
set row_security=off
stable
as $$
  select r.room_code,r.title,r.host_id,r.is_active,r.created_at,r.ended_at,
         (select count(*) from public.meeting_room_members m2 where m2.room_code=r.room_code)
  from public.meeting_rooms r
  where r.host_id=auth.uid()
     or exists(select 1 from public.meeting_room_members m where m.room_code=r.room_code and m.user_id=auth.uid())
  order by r.created_at desc
  limit 50;
$$;

-- Realtime delivery for standalone meeting signals.
do $$ begin
  alter publication supabase_realtime add table public.meeting_signals;
exception when duplicate_object then null; end $$;

revoke execute on function public.meeting_room_add_host_membership(),public.delete_community_group(uuid),public.get_community_group_messages(uuid),
  public.delete_poll(uuid),public.is_zameel_owner(uuid),public.admin_add_business_partner(text,text,text,text,text,text),
  public.admin_delete_business_partner(uuid),public.create_zameel_meeting(text),public.join_zameel_meeting(text),
  public.send_meeting_signal(text,jsonb),public.get_meeting_signals(text,bigint),public.leave_zameel_meeting(text),
  public.get_my_zameel_meetings() from public,anon;

grant execute on function public.delete_community_group(uuid),public.get_community_group_messages(uuid),
  public.delete_poll(uuid),public.is_zameel_owner(uuid),public.admin_add_business_partner(text,text,text,text,text,text),
  public.admin_delete_business_partner(uuid),public.create_zameel_meeting(text),public.join_zameel_meeting(text),
  public.send_meeting_signal(text,jsonb),public.get_meeting_signals(text,bigint),public.leave_zameel_meeting(text),
  public.get_my_zameel_meetings() to authenticated;

-- vote_poll/get_polls already exist from 059; refresh execute grants after replacement.
revoke execute on function public.vote_poll(uuid,uuid),public.get_polls() from public,anon;
grant execute on function public.vote_poll(uuid,uuid),public.get_polls() to authenticated;

commit;
