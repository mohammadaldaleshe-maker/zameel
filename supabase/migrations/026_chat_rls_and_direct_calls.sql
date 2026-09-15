-- Zameel chat RLS recursion + direct call invitation repair (FIXED).
-- Safe to run after a failed attempt of 026 because the previous script was transactional.
-- Run after 025_chat_members_user_fk_compat.sql.

begin;

-- ---------------------------------------------------------------------------
-- 1) Rebuild the membership helper cleanly.
-- PostgreSQL does not allow CREATE OR REPLACE FUNCTION to rename input
-- parameters for an existing function with the same signature, so remove the
-- old helper first. CASCADE removes only dependent DB objects (normally old
-- policies using this helper); required policies are recreated below.
-- ---------------------------------------------------------------------------
drop function if exists public.is_conversation_member(uuid, uuid) cascade;

create function public.is_conversation_member(
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

revoke execute on function public.is_conversation_member(uuid, uuid) from public, anon;
grant execute on function public.is_conversation_member(uuid, uuid) to authenticated;

-- Remove every legacy policy on conversation_members. Older Zameel installs
-- can contain recursive policies under different names.
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
    execute format('drop policy if exists %I on public.conversation_members', p.policyname);
  end loop;
end $$;

create policy conversation_members_member_select
on public.conversation_members
for select to authenticated
using (
  public.is_conversation_member(conversation_id, auth.uid())
);

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

-- Rebuild conversation/message policies using the non-recursive helper.
drop policy if exists conversations_member_select on public.conversations;
create policy conversations_member_select
on public.conversations
for select to authenticated
using (public.is_conversation_member(id, auth.uid()));

drop policy if exists messages_member_select on public.messages;
create policy messages_member_select
on public.messages
for select to authenticated
using (public.is_conversation_member(conversation_id, auth.uid()));

drop policy if exists messages_member_insert on public.messages;
create policy messages_member_insert
on public.messages
for insert to authenticated
with check (
  sender_id = auth.uid()
  and public.is_conversation_member(conversation_id, auth.uid())
);

drop policy if exists messages_member_update on public.messages;
create policy messages_member_update
on public.messages
for update to authenticated
using (public.is_conversation_member(conversation_id, auth.uid()))
with check (public.is_conversation_member(conversation_id, auth.uid()));

-- ---------------------------------------------------------------------------
-- 2) Rebuild the direct-call RPC cleanly too. Dropping the exact signature
-- avoids the same parameter-name conflict on databases carrying an older RPC.
-- ---------------------------------------------------------------------------
drop function if exists public.start_direct_call(uuid, uuid, text, boolean);

create function public.start_direct_call(
  other_user_id uuid,
  target_conversation_id uuid,
  target_room_id text,
  with_video boolean default true
)
returns uuid
language plpgsql
security definer
set search_path = public
set row_security = off
as $$
declare
  me uuid := auth.uid();
  caller_name text;
  notification_id uuid;
  allowed boolean;
begin
  if me is null then
    raise exception 'not_authenticated';
  end if;

  if other_user_id is null or other_user_id = me then
    raise exception 'invalid_partner';
  end if;

  if target_conversation_id is null or coalesce(trim(target_room_id), '') = '' then
    raise exception 'invalid_call_room';
  end if;

  if not public.is_conversation_member(target_conversation_id, me)
     or not public.is_conversation_member(target_conversation_id, other_user_id) then
    raise exception 'conversation_membership_required';
  end if;

  if public.is_blocked(me, other_user_id) then
    raise exception 'blocked_user';
  end if;

  if not public.is_colleague(me, other_user_id) then
    raise exception 'colleague_only';
  end if;

  select coalesce(u.allow_calls, true)
  into allowed
  from public.users u
  where u.id = other_user_id;

  if coalesce(allowed, false) = false then
    raise exception 'calls_disabled';
  end if;

  select coalesce(nullif(u.name, ''), 'زميل')
  into caller_name
  from public.users u
  where u.id = me;

  insert into public.notifications (
    user_id,
    actor_id,
    type,
    title_ar,
    title_en,
    body_ar,
    body_en,
    data,
    is_read
  ) values (
    other_user_id,
    me,
    case when with_video then 'incoming_video_call' else 'incoming_voice_call' end,
    case when with_video then 'مكالمة فيديو واردة' else 'مكالمة صوتية واردة' end,
    case when with_video then 'Incoming video call' else 'Incoming voice call' end,
    caller_name || case when with_video then ' يتصل بك عبر الفيديو' else ' يتصل بك صوتيًا' end,
    caller_name || case when with_video then ' is video calling you' else ' is calling you' end,
    jsonb_build_object(
      'room_id', target_room_id,
      'conversation_id', target_conversation_id,
      'caller_id', me,
      'video', with_video
    ),
    false
  )
  returning id into notification_id;

  return notification_id;
end;
$$;

revoke execute on function public.start_direct_call(uuid, uuid, text, boolean) from public, anon;
grant execute on function public.start_direct_call(uuid, uuid, text, boolean) to authenticated;

-- Ensure Realtime publication for chat and notification delivery.
do $$ begin
  alter publication supabase_realtime add table public.messages;
exception when duplicate_object then null; when undefined_object then null;
end $$;

do $$ begin
  alter publication supabase_realtime add table public.notifications;
exception when duplicate_object then null; when undefined_object then null;
end $$;

commit;
