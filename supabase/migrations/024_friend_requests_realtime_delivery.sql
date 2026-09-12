-- Zameel: friend request delivery + in-app realtime repair.
-- Re-applies participant RLS, durable request notifications, realtime publication,
-- and backfills notifications for pending requests that were saved without one.

begin;

-- ---------------------------------------------------------------------------
-- Legacy push-queue compatibility
-- ---------------------------------------------------------------------------
-- Some deployed databases still have an older AFTER INSERT trigger on
-- public.notifications whose function is named queue_push_notification().
-- The current app also installs notifications_enqueue_push, so both triggers
-- may try to queue the same notification and hit the unique notification_id
-- constraint. Remove only those legacy triggers before doing any backfill.
do $$
declare
  legacy_trigger record;
begin
  for legacy_trigger in
    select t.tgname
    from pg_trigger t
    join pg_class c on c.oid = t.tgrelid
    join pg_namespace n on n.oid = c.relnamespace
    join pg_proc p on p.oid = t.tgfoid
    where not t.tgisinternal
      and n.nspname = 'public'
      and c.relname = 'notifications'
      and p.proname = 'queue_push_notification'
  loop
    execute format('drop trigger if exists %I on public.notifications', legacy_trigger.tgname);
  end loop;
end $$;

-- Reinstall the canonical idempotent queue function/trigger. This supports
-- both the modern queue shape and older databases that still have user_id.
create or replace function public.enqueue_notification_for_push()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'push_notification_queue'
      and column_name = 'user_id'
  ) then
    execute $sql$
      insert into public.push_notification_queue(notification_id, user_id)
      values ($1, $2)
      on conflict (notification_id) do nothing
    $sql$ using new.id, new.user_id;
  else
    insert into public.push_notification_queue(notification_id)
    values (new.id)
    on conflict (notification_id) do nothing;
  end if;

  return new;
end;
$$;

drop trigger if exists notifications_enqueue_push on public.notifications;
create trigger notifications_enqueue_push
after insert on public.notifications
for each row execute function public.enqueue_notification_for_push();

-- Keep the deployed table shape compatible with current Flutter queries.
alter table public.friend_requests add column if not exists sender_name text not null default '';
alter table public.friend_requests add column if not exists receiver_name text not null default '';
alter table public.friend_requests add column if not exists updated_at timestamptz not null default now();

create index if not exists friend_requests_receiver_idx
  on public.friend_requests(receiver_id, status, created_at desc);
create index if not exists friend_requests_sender_idx
  on public.friend_requests(sender_id, status, created_at desc);

-- Participants must be able to read their own requests. The receiver may accept
-- or reject; the sender may cancel. Re-create policies to repair schema drift.
alter table public.friend_requests enable row level security;

drop policy if exists friend_requests_select_participants on public.friend_requests;
drop policy if exists friend_requests_insert_sender on public.friend_requests;
drop policy if exists friend_requests_update_participants on public.friend_requests;
drop policy if exists friend_requests_receiver_update on public.friend_requests;
drop policy if exists friend_requests_sender_cancel on public.friend_requests;

create policy friend_requests_select_participants
on public.friend_requests for select to authenticated
using (sender_id = auth.uid() or receiver_id = auth.uid());

create policy friend_requests_insert_sender
on public.friend_requests for insert to authenticated
with check (sender_id = auth.uid() and receiver_id <> auth.uid());

create policy friend_requests_receiver_update
on public.friend_requests for update to authenticated
using (receiver_id = auth.uid())
with check (receiver_id = auth.uid() and status in ('accepted','rejected'));

create policy friend_requests_sender_cancel
on public.friend_requests for update to authenticated
using (sender_id = auth.uid())
with check (sender_id = auth.uid() and status = 'cancelled');

-- Recipient-only notification access.
alter table public.notifications enable row level security;

drop policy if exists notifications_select_self on public.notifications;
drop policy if exists notifications_update_self on public.notifications;
drop policy if exists notifications_delete_self on public.notifications;

create policy notifications_select_self
on public.notifications for select to authenticated
using (user_id = auth.uid());

create policy notifications_update_self
on public.notifications for update to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

create policy notifications_delete_self
on public.notifications for delete to authenticated
using (user_id = auth.uid());

-- A SECURITY DEFINER trigger makes notification creation independent of client
-- notification INSERT policies and of the sender account's privacy setting.
create or replace function public.notify_on_friend_request()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  display_name text;
begin
  display_name := coalesce(
    (select nullif(trim(u.name), '') from public.users u where u.id = new.sender_id),
    nullif(trim(new.sender_name), ''),
    'Zameel user'
  );

  insert into public.notifications(
    user_id, actor_id, type, title_ar, title_en,
    body_ar, body_en, data, is_read
  ) values (
    new.receiver_id,
    new.sender_id,
    'friend_request',
    'طلب زمالة جديد',
    'New colleague request',
    display_name || ' أرسل لك طلب زمالة',
    display_name || ' sent you a colleague request',
    jsonb_build_object(
      'request_id', new.id,
      'sender_id', new.sender_id,
      'receiver_id', new.receiver_id
    ),
    false
  );

  return new;
end;
$$;

drop trigger if exists friend_requests_create_notification on public.friend_requests;
create trigger friend_requests_create_notification
after insert on public.friend_requests
for each row
when (new.status = 'pending')
execute function public.notify_on_friend_request();

create or replace function public.notify_on_friend_request_update()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  recipient uuid;
  actor uuid;
  notification_type text;
  title_ar text;
  title_en text;
  body_ar text;
  body_en text;
begin
  if old.status = new.status then
    return new;
  end if;

  if new.status = 'accepted' then
    recipient := new.sender_id;
    actor := new.receiver_id;
    notification_type := 'friend_request_accepted';
    title_ar := 'تم قبول طلب الزمالة';
    title_en := 'Colleague request accepted';
    body_ar := 'تم قبول طلب الزمالة الذي أرسلته.';
    body_en := 'Your colleague request was accepted.';
  elsif new.status = 'rejected' then
    recipient := new.sender_id;
    actor := new.receiver_id;
    notification_type := 'friend_request_rejected';
    title_ar := 'تم رفض طلب الزمالة';
    title_en := 'Colleague request declined';
    body_ar := 'تم رفض طلب الزمالة الذي أرسلته.';
    body_en := 'Your colleague request was declined.';
  else
    return new;
  end if;

  insert into public.notifications(
    user_id, actor_id, type, title_ar, title_en,
    body_ar, body_en, data, is_read
  ) values (
    recipient,
    actor,
    notification_type,
    title_ar,
    title_en,
    body_ar,
    body_en,
    jsonb_build_object('request_id', new.id),
    false
  );

  return new;
end;
$$;

drop trigger if exists friend_requests_status_notification on public.friend_requests;
create trigger friend_requests_status_notification
after update of status on public.friend_requests
for each row
execute function public.notify_on_friend_request_update();

-- Restore a missing in-app notification for any request that is still pending.
-- NOT EXISTS makes the migration safe to run more than once.
insert into public.notifications(
  user_id, actor_id, type, title_ar, title_en,
  body_ar, body_en, data, is_read, created_at
)
select
  r.receiver_id,
  r.sender_id,
  'friend_request',
  'طلب زمالة جديد',
  'New colleague request',
  coalesce(nullif(trim(u.name), ''), nullif(trim(r.sender_name), ''), 'Zameel user') || ' أرسل لك طلب زمالة',
  coalesce(nullif(trim(u.name), ''), nullif(trim(r.sender_name), ''), 'Zameel user') || ' sent you a colleague request',
  jsonb_build_object(
    'request_id', r.id,
    'sender_id', r.sender_id,
    'receiver_id', r.receiver_id
  ),
  false,
  r.created_at
from public.friend_requests r
left join public.users u on u.id = r.sender_id
where r.status = 'pending'
  and not exists (
    select 1
    from public.notifications n
    where n.user_id = r.receiver_id
      and n.type = 'friend_request'
      and n.data ->> 'request_id' = r.id::text
  );

-- Realtime must contain both tables for live badge/request updates.
do $$
begin
  alter publication supabase_realtime add table public.friend_requests;
exception
  when duplicate_object then null;
  when undefined_object then null;
end $$;

do $$
begin
  alter publication supabase_realtime add table public.notifications;
exception
  when duplicate_object then null;
  when undefined_object then null;
end $$;

commit;
