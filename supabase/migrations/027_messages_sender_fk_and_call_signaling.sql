-- Zameel private-chat sender FK compatibility + call signaling follow-up.
-- Run after 026_chat_rls_and_direct_calls.sql.
--
-- Some older live databases still have public.messages.sender_id referencing
-- public.profiles(id).  The current app consistently uses auth.uid() mirrored
-- in public.users(id), so new messages fail with messages_sender_id_fkey when
-- the legacy profiles row does not exist.  Normalize only the sender FK and
-- preserve every existing message.

begin;

-- Heal public.users for every real Supabase Auth account before enforcing the
-- current sender relation.
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

-- Remove every FK attached specifically to messages.sender_id, regardless of
-- whether an older installation points it to profiles, auth.users, or users.
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
      and t.relname = 'messages'
      and c.contype = 'f'
      and pg_get_constraintdef(c.oid) ~* '^FOREIGN KEY \(sender_id\)'
  loop
    execute format(
      'alter table public.messages drop constraint %I',
      r.conname
    );
  end loop;
end $$;

-- NOT VALID keeps historical/demo rows intact while enforcing the correct
-- relation for every new/updated message from this point onward.
alter table public.messages
  add constraint messages_sender_id_fkey
  foreign key (sender_id)
  references public.users(id)
  on delete cascade
  not valid;

create index if not exists messages_sender_idx
  on public.messages(sender_id, created_at desc);

-- Validate immediately when there are no old orphan sender ids.  If there are
-- legacy/demo rows, leave the FK NOT VALID; PostgreSQL still enforces it for
-- all new writes.
do $$
begin
  if not exists (
    select 1
    from public.messages m
    left join public.users u on u.id = m.sender_id
    where u.id is null
  ) then
    alter table public.messages
      validate constraint messages_sender_id_fkey;
  end if;
end $$;

-- Keep chat delivery in Supabase Realtime (idempotent on existing projects).
do $$ begin
  alter publication supabase_realtime add table public.messages;
exception when duplicate_object then null; when undefined_object then null;
end $$;

commit;
