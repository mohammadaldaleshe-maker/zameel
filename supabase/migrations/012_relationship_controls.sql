-- Zameel relationship controls: blocking + safe colleague removal + reliable chat RPC.
-- Safe/idempotent migration; preserves existing data.

begin;

create table if not exists public.user_blocks (
  id uuid primary key default gen_random_uuid(),
  blocker_id uuid not null references public.users(id) on delete cascade,
  blocked_id uuid not null references public.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (blocker_id, blocked_id),
  check (blocker_id <> blocked_id)
);

create index if not exists user_blocks_blocker_idx
  on public.user_blocks(blocker_id, created_at desc);

create index if not exists user_blocks_blocked_idx
  on public.user_blocks(blocked_id, created_at desc);

alter table public.user_blocks enable row level security;

-- Ensure legacy membership rows can still be inserted without supplying id.
alter table public.conversation_members
  alter column id set default gen_random_uuid();

drop policy if exists user_blocks_select_self on public.user_blocks;
drop policy if exists user_blocks_insert_self on public.user_blocks;
drop policy if exists user_blocks_delete_self on public.user_blocks;

create policy user_blocks_select_self
on public.user_blocks
for select to authenticated
using (blocker_id = auth.uid() or blocked_id = auth.uid());

create policy user_blocks_insert_self
on public.user_blocks
for insert to authenticated
with check (blocker_id = auth.uid() and blocked_id <> auth.uid());

create policy user_blocks_delete_self
on public.user_blocks
for delete to authenticated
using (blocker_id = auth.uid());

create or replace function public.is_blocked(a uuid, b uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.user_blocks ub
    where (ub.blocker_id = a and ub.blocked_id = b)
       or (ub.blocker_id = b and ub.blocked_id = a)
  );
$$;

grant execute on function public.is_blocked(uuid, uuid) to authenticated;

create or replace function public.is_colleague(a uuid, b uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select
    a = b
    or (
      not public.is_blocked(a, b)
      and (
        exists (
          select 1
          from public.friend_requests r
          where r.status = 'accepted'
            and ((r.sender_id = a and r.receiver_id = b) or (r.sender_id = b and r.receiver_id = a))
        )
        or (
          exists (select 1 from public.follows f where f.follower_id = a and f.following_id = b)
          and exists (select 1 from public.follows f where f.follower_id = b and f.following_id = a)
        )
      )
    );
$$;

grant execute on function public.is_colleague(uuid, uuid) to authenticated;

create or replace function public.create_direct_conversation(other_user_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  me uuid := auth.uid();
  existing uuid;
  cid uuid;
begin
  if me is null then raise exception 'not_authenticated'; end if;
  if other_user_id is null or other_user_id = me then raise exception 'invalid_partner'; end if;
  if public.is_blocked(me, other_user_id) then raise exception 'blocked_user'; end if;
  if not public.is_colleague(me, other_user_id) then raise exception 'colleague_only'; end if;

  select c.id into existing
  from public.conversations c
  where c.is_group = false
    and exists (select 1 from public.conversation_members cm where cm.conversation_id = c.id and cm.user_id = me)
    and exists (select 1 from public.conversation_members cm where cm.conversation_id = c.id and cm.user_id = other_user_id)
  order by c.created_at asc
  limit 1;

  if existing is not null then return existing; end if;

  insert into public.conversations(is_group, created_by)
  values(false, me)
  returning id into cid;

  -- Explicit ids keep this compatible with older conversation_members schemas.
  insert into public.conversation_members(id, conversation_id, user_id, created_at)
  values
    (gen_random_uuid(), cid, me, now()),
    (gen_random_uuid(), cid, other_user_id, now());

  return cid;
end;
$$;

grant execute on function public.create_direct_conversation(uuid) to authenticated;

drop policy if exists users_select_authenticated on public.users;
create policy users_select_authenticated
on public.users
for select to authenticated
using (
  (id = auth.uid())
  or (
    account_privacy = 'public'
    and not public.is_blocked(auth.uid(), id)
  )
  or (
    public.is_colleague(auth.uid(), id)
    and not public.is_blocked(auth.uid(), id)
  )
);

drop policy if exists friend_requests_insert_sender on public.friend_requests;
create policy friend_requests_insert_sender
on public.friend_requests
for insert to authenticated
with check (
  sender_id = auth.uid()
  and receiver_id <> auth.uid()
  and not public.is_blocked(auth.uid(), receiver_id)
);

drop policy if exists messages_member_select on public.messages;
drop policy if exists messages_member_insert on public.messages;
create policy messages_member_select
on public.messages
for select to authenticated
using (
  public.is_conversation_member(conversation_id, auth.uid())
  and not exists (
    select 1 from public.conversation_members other_cm
    where other_cm.conversation_id = conversation_id
      and other_cm.user_id <> auth.uid()
      and public.is_blocked(auth.uid(), other_cm.user_id)
  )
);

create policy messages_member_insert
on public.messages
for insert to authenticated
with check (
  sender_id = auth.uid()
  and public.is_conversation_member(conversation_id, auth.uid())
  and not exists (
    select 1 from public.conversation_members other_cm
    where other_cm.conversation_id = conversation_id
      and other_cm.user_id <> auth.uid()
      and public.is_blocked(auth.uid(), other_cm.user_id)
  )
);

commit;
