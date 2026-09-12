-- Zameel chat membership compatibility repair.
-- Fixes legacy conversation_members.user_id foreign keys and missing public.users rows.
-- Safe/idempotent and preserves existing chat rows.

begin;

-- ---------------------------------------------------------------------------
-- 1) Heal public profile rows for every real Supabase Auth account.
-- Some older Zameel databases were created before the auth -> public.users
-- signup trigger was installed, leaving valid Auth users without a public row.
-- ---------------------------------------------------------------------------
insert into public.users (id, email, name)
select
  au.id,
  au.email,
  coalesce(nullif(au.raw_user_meta_data->>'name', ''), 'مستخدم')
from auth.users au
where not exists (
  select 1 from public.users u where u.id = au.id
)
on conflict (id) do nothing;

-- Keep the signup repair in place for all future accounts.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.users (id, email, name)
  values (
    new.id,
    new.email,
    coalesce(nullif(new.raw_user_meta_data->>'name', ''), 'مستخدم')
  )
  on conflict (id) do update
    set email = coalesce(excluded.email, public.users.email);
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_user();

-- ---------------------------------------------------------------------------
-- 2) Normalize the legacy conversation_members shape used by the RPC.
-- ---------------------------------------------------------------------------
alter table public.conversation_members
  add column if not exists id uuid;

update public.conversation_members
set id = gen_random_uuid()
where id is null;

alter table public.conversation_members
  alter column id set default gen_random_uuid();
alter table public.conversation_members
  alter column id set not null;

create unique index if not exists conversation_members_id_unique
  on public.conversation_members(id);

-- Remove ONLY foreign keys attached to conversation_members.user_id.  Existing
-- installations may have this column pointing at a legacy profile/auth table.
do $$
declare
  r record;
begin
  for r in
    select c.conname
    from pg_constraint c
    join pg_class t on t.oid = c.conrelid
    join pg_namespace n on n.oid = t.relnamespace
    where n.nspname = 'public'
      and t.relname = 'conversation_members'
      and c.contype = 'f'
      and pg_get_constraintdef(c.oid) ~* '^FOREIGN KEY \(user_id\)'
  loop
    execute format(
      'alter table public.conversation_members drop constraint %I',
      r.conname
    );
  end loop;
end $$;

-- NOT VALID preserves any old orphan/demo membership rows while enforcing the
-- correct relation for every new or modified row from now on.
alter table public.conversation_members
  add constraint conversation_members_user_id_fkey
  foreign key (user_id)
  references public.users(id)
  on delete cascade
  not valid;

create index if not exists conversation_members_user_idx
  on public.conversation_members(user_id);

-- ---------------------------------------------------------------------------
-- 3) Rebuild the direct-chat RPC so it self-heals missing profile rows and uses
-- only columns guaranteed across old/new conversation_members schemas.
-- ---------------------------------------------------------------------------
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
  if me is null then
    raise exception 'not_authenticated';
  end if;

  if other_user_id is null or other_user_id = me then
    raise exception 'invalid_partner';
  end if;

  -- Repair either public profile lazily if the Auth account is real but its
  -- public.users row was missed by an older signup flow.
  insert into public.users (id, email, name)
  select
    au.id,
    au.email,
    coalesce(nullif(au.raw_user_meta_data->>'name', ''), 'مستخدم')
  from auth.users au
  where au.id in (me, other_user_id)
  on conflict (id) do nothing;

  if not exists (select 1 from public.users u where u.id = me) then
    raise exception 'current_user_profile_missing';
  end if;

  if not exists (select 1 from public.users u where u.id = other_user_id) then
    raise exception 'partner_account_missing';
  end if;

  if public.is_blocked(me, other_user_id) then
    raise exception 'blocked_user';
  end if;

  if not public.is_colleague(me, other_user_id) then
    raise exception 'colleague_only';
  end if;

  select c.id into existing
  from public.conversations c
  where c.is_group = false
    and exists (
      select 1
      from public.conversation_members cm
      where cm.conversation_id = c.id
        and cm.user_id = me
    )
    and exists (
      select 1
      from public.conversation_members cm
      where cm.conversation_id = c.id
        and cm.user_id = other_user_id
    )
  order by c.created_at asc
  limit 1;

  if existing is not null then
    return existing;
  end if;

  insert into public.conversations (is_group, created_by)
  values (false, me)
  returning id into cid;

  -- id has a server default; joined_at/created_at variants in legacy schemas
  -- keep their own defaults, so specifying only stable columns is intentional.
  insert into public.conversation_members (conversation_id, user_id)
  values
    (cid, me),
    (cid, other_user_id);

  return cid;
end;
$$;

revoke execute on function public.create_direct_conversation(uuid) from public, anon;
grant execute on function public.create_direct_conversation(uuid) to authenticated;

commit;
