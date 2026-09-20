-- Zameel 053: durable direct-chat reads + normalized non-recursive chat RLS.
-- Run after migration 052.
--
-- This migration deliberately does NOT change WebRTC/call signaling tables or
-- RPCs. Call stability in app release 054 is handled by isolating autoplay
-- video controllers from the shared media player used elsewhere in the app.

begin;

-- ---------------------------------------------------------------------------
-- 1) Keep a single non-recursive membership helper.
-- ---------------------------------------------------------------------------
create or replace function public.is_conversation_member(
  target_conversation_id uuid,
  target_user_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = public
set row_security = off
as $$
  select exists (
    select 1
    from public.conversation_members cm
    where cm.conversation_id = target_conversation_id
      and cm.user_id = target_user_id
  );
$$;

revoke execute on function public.is_conversation_member(uuid, uuid)
from public, anon;
grant execute on function public.is_conversation_member(uuid, uuid)
to authenticated;

-- ---------------------------------------------------------------------------
-- 2) Normalize chat policies. Older databases can retain recursive or stale
--    policies under different names. Recreate only the rules used by Zameel.
-- ---------------------------------------------------------------------------
alter table public.conversation_members enable row level security;
alter table public.messages enable row level security;

do $$
declare
  p record;
begin
  for p in
    select policyname
    from pg_policies
    where schemaname = 'public'
      and tablename = 'conversation_members'
  loop
    execute format(
      'drop policy if exists %I on public.conversation_members',
      p.policyname
    );
  end loop;
end $$;

create policy conversation_members_member_select
on public.conversation_members
for select to authenticated
using (public.is_conversation_member(conversation_id, auth.uid()));

create policy conversation_members_creator_insert
on public.conversation_members
for insert to authenticated
with check (
  exists (
    select 1
    from public.conversations c
    where c.id = conversation_id
      and c.created_by = auth.uid()
  )
  and not public.is_blocked(auth.uid(), user_id)
);

do $$
declare
  p record;
begin
  for p in
    select policyname
    from pg_policies
    where schemaname = 'public'
      and tablename = 'messages'
  loop
    execute format('drop policy if exists %I on public.messages', p.policyname);
  end loop;
end $$;

create policy messages_member_select
on public.messages
for select to authenticated
using (public.is_conversation_member(conversation_id, auth.uid()));

create policy messages_member_insert
on public.messages
for insert to authenticated
with check (
  sender_id = auth.uid()
  and public.is_conversation_member(conversation_id, auth.uid())
);

create policy messages_member_update
on public.messages
for update to authenticated
using (public.is_conversation_member(conversation_id, auth.uid()))
with check (public.is_conversation_member(conversation_id, auth.uid()));

-- ---------------------------------------------------------------------------
-- 3) Server-authoritative direct-message loader.
--    This prevents a valid sender's own persisted messages from disappearing
--    because of a stale client/table policy. Membership is checked on server.
-- ---------------------------------------------------------------------------
drop function if exists public.get_direct_messages(uuid, integer, timestamptz);

create function public.get_direct_messages(
  target_conversation_id uuid,
  page_size integer default 300,
  before_created_at timestamptz default null
)
returns table(
  id uuid,
  content text,
  sender_id uuid,
  created_at timestamptz,
  media_url text,
  media_type text,
  is_read boolean,
  delivered_at timestamptz,
  read_at timestamptz
)
language plpgsql
stable
security definer
set search_path = public
set row_security = off
as $$
declare
  me uuid := auth.uid();
  safe_page_size integer := greatest(1, least(coalesce(page_size, 300), 500));
begin
  if me is null then
    raise exception 'not_authenticated';
  end if;

  if not public.is_conversation_member(target_conversation_id, me) then
    raise exception 'conversation_membership_required';
  end if;

  return query
  select q.id,
         q.content,
         q.sender_id,
         q.created_at,
         q.media_url,
         q.media_type,
         q.is_read,
         q.delivered_at,
         q.read_at
  from (
    select m.id,
           m.content,
           m.sender_id,
           m.created_at,
           m.media_url,
           m.media_type,
           m.is_read,
           m.delivered_at,
           m.read_at
    from public.messages m
    where m.conversation_id = target_conversation_id
      and (before_created_at is null or m.created_at < before_created_at)
    order by m.created_at desc, m.id desc
    limit safe_page_size
  ) q
  order by q.created_at asc, q.id asc;
end;
$$;

revoke execute on function public.get_direct_messages(uuid, integer, timestamptz)
from public, anon;
grant execute on function public.get_direct_messages(uuid, integer, timestamptz)
to authenticated;

-- Keep message Realtime active for incoming messages and receipt updates.
do $$ begin
  alter publication supabase_realtime add table public.messages;
exception
  when duplicate_object then null;
  when undefined_object then null;
end $$;

commit;
