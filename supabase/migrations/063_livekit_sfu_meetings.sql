-- Zameel 063: multi-participant Zameel Meet via SFU/LiveKit.
-- Direct chat voice/video calls remain on the existing WebRTC path.
begin;

create table if not exists public.meeting_room_attendance(
  room_code text not null references public.meeting_rooms(room_code) on delete cascade,
  user_id uuid not null references public.users(id) on delete cascade,
  first_joined_at timestamptz not null default now(),
  last_joined_at timestamptz not null default now(),
  primary key(room_code,user_id)
);
create index if not exists meeting_room_attendance_user_idx
  on public.meeting_room_attendance(user_id,last_joined_at desc);

create table if not exists public.meeting_room_bans(
  room_code text not null references public.meeting_rooms(room_code) on delete cascade,
  user_id uuid not null references public.users(id) on delete cascade,
  banned_by uuid not null references public.users(id) on delete cascade,
  banned_at timestamptz not null default now(),
  primary key(room_code,user_id)
);

alter table public.meeting_room_attendance enable row level security;
drop policy if exists meeting_room_attendance_self_read on public.meeting_room_attendance;
create policy meeting_room_attendance_self_read on public.meeting_room_attendance
for select to authenticated
using(user_id=auth.uid());

alter table public.meeting_room_bans enable row level security;
drop policy if exists meeting_room_bans_host_read on public.meeting_room_bans;
create policy meeting_room_bans_host_read on public.meeting_room_bans
for select to authenticated
using(exists(
  select 1 from public.meeting_rooms r
  where r.room_code=meeting_room_bans.room_code and r.host_id=auth.uid()
));

insert into public.meeting_room_attendance(room_code,user_id,first_joined_at,last_joined_at)
select m.room_code,m.user_id,m.joined_at,m.joined_at
from public.meeting_room_members m
on conflict(room_code,user_id) do update
set last_joined_at=greatest(public.meeting_room_attendance.last_joined_at,excluded.last_joined_at);

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
  on conflict(room_code,user_id) do nothing;
  insert into public.meeting_room_attendance(room_code,user_id)
  values(new_code,me)
  on conflict(room_code,user_id) do update set last_joined_at=now();
  return new_code;
end $$;

-- No fixed participant cap. Capacity is controlled by the SFU deployment,
-- not by a two-person database rule.
create or replace function public.join_zameel_meeting(target_room_code text)
returns table(room_code text,title text,host_id uuid)
language plpgsql
security definer
set search_path=public
set row_security=off
as $$
declare me uuid:=auth.uid(); r public.meeting_rooms;
begin
  if me is null then raise exception 'not_authenticated'; end if;
  select mr.* into r from public.meeting_rooms mr
  where upper(mr.room_code)=upper(trim(target_room_code))
  for update;
  if r.id is null then raise exception 'meeting_not_found'; end if;
  if not r.is_active then raise exception 'meeting_ended'; end if;
  if exists(
    select 1 from public.meeting_room_bans b
    where b.room_code=r.room_code and b.user_id=me
  ) then
    raise exception 'meeting_access_revoked';
  end if;

  insert into public.meeting_room_members(room_code,user_id)
  values(r.room_code,me)
  on conflict(room_code,user_id) do update set joined_at=now();

  insert into public.meeting_room_attendance(room_code,user_id)
  values(r.room_code,me)
  on conflict(room_code,user_id) do update set last_joined_at=now();

  return query select r.room_code,r.title,r.host_id;
end $$;

-- In a multi-participant meeting, leaving is not the same as ending the room.
-- The host explicitly ends the room through the LiveKit moderation endpoint.
create or replace function public.leave_zameel_meeting(target_room_code text)
returns void
language plpgsql
security definer
set search_path=public
set row_security=off
as $$
declare me uuid:=auth.uid();
begin
  if me is null then return; end if;
  delete from public.meeting_room_members
  where room_code=target_room_code and user_id=me;
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
         (select count(*) from public.meeting_room_attendance a where a.room_code=r.room_code)
  from public.meeting_rooms r
  where r.host_id=auth.uid()
     or exists(select 1 from public.meeting_room_attendance a where a.room_code=r.room_code and a.user_id=auth.uid())
  order by r.created_at desc
  limit 50;
$$;

revoke execute on function public.create_zameel_meeting(text),public.join_zameel_meeting(text),public.leave_zameel_meeting(text),public.get_my_zameel_meetings() from public,anon;
grant execute on function public.create_zameel_meeting(text),public.join_zameel_meeting(text),public.leave_zameel_meeting(text),public.get_my_zameel_meetings() to authenticated;

commit;
