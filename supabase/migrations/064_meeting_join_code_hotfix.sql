-- Zameel 064: meeting join hotfix.
-- Fixes PL/pgSQL output-column ambiguity in ON CONFLICT and accepts a code
-- embedded in a full shared invitation message.
begin;

create or replace function public.join_zameel_meeting(target_room_code text)
returns table(room_code text,title text,host_id uuid)
language plpgsql
security definer
set search_path=public
set row_security=off
as $$
declare
  me uuid:=auth.uid();
  r public.meeting_rooms;
  normalized_code text;
begin
  if me is null then raise exception 'not_authenticated'; end if;

  normalized_code := upper(trim(coalesce(target_room_code,'')));
  if normalized_code !~ '^ZM[A-Z0-9]{8}$' then
    normalized_code := (regexp_match(normalized_code, 'ZM[A-Z0-9]{8}'))[1];
  end if;
  if normalized_code is null or normalized_code = '' then
    raise exception 'meeting_not_found';
  end if;

  select mr.* into r
  from public.meeting_rooms mr
  where upper(mr.room_code)=normalized_code
  for update;

  if r.id is null then raise exception 'meeting_not_found'; end if;
  if not r.is_active then raise exception 'meeting_ended'; end if;
  if exists(
    select 1 from public.meeting_room_bans b
    where b.room_code=r.room_code and b.user_id=me
  ) then
    raise exception 'meeting_access_revoked';
  end if;

  insert into public.meeting_room_members(room_code,user_id,joined_at)
  values(r.room_code,me,now())
  on conflict on constraint meeting_room_members_pkey
  do update set joined_at=excluded.joined_at;

  insert into public.meeting_room_attendance(room_code,user_id,first_joined_at,last_joined_at)
  values(r.room_code,me,now(),now())
  on conflict on constraint meeting_room_attendance_pkey
  do update set last_joined_at=excluded.last_joined_at;

  return query select r.room_code,r.title,r.host_id;
end $$;

revoke execute on function public.join_zameel_meeting(text) from public,anon;
grant execute on function public.join_zameel_meeting(text) to authenticated;

commit;
