-- Zameel 052: authorized clip removal used by the vertical clips viewer.
-- Run after migration 051.
begin;

create or replace function public.delete_clip_authorized(target_clip_id uuid)
returns void
language plpgsql
security definer
set search_path=public
set row_security=off
as $$
declare
  me uuid:=auth.uid();
  clip_owner uuid;
  my_role text;
begin
  if me is null then raise exception 'not_authenticated'; end if;

  select c.user_id into clip_owner
  from public.clips c
  where c.id=target_clip_id
  for update;

  if clip_owner is null then return; end if;

  select lower(coalesce(u.role,'')) into my_role
  from public.users u
  where u.id=me;

  if clip_owner<>me and my_role not in ('owner','admin') then
    raise exception 'clip_delete_not_allowed';
  end if;

  delete from public.clips where id=target_clip_id;
end $$;

revoke execute on function public.delete_clip_authorized(uuid)
from public,anon;
grant execute on function public.delete_clip_authorized(uuid)
to authenticated;

commit;
