-- Zameel v1.3.8 notification hardening.
-- Adds durable post comments, server-side notifications for colleague requests,
-- token locale support, and safe notification preferences.

begin;

-- ------------------------------------------------------------
-- Durable comments for normal posts.
-- ------------------------------------------------------------
create table if not exists public.post_comments (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.posts(id) on delete cascade,
  user_id uuid not null references public.users(id) on delete cascade,
  content text not null check (char_length(trim(content)) between 1 and 2000),
  created_at timestamptz not null default now()
);

create index if not exists post_comments_post_idx
  on public.post_comments(post_id, created_at);

create index if not exists post_comments_user_idx
  on public.post_comments(user_id, created_at desc);

alter table public.post_comments enable row level security;

drop policy if exists post_comments_select_authenticated on public.post_comments;
drop policy if exists post_comments_insert_self on public.post_comments;
drop policy if exists post_comments_delete_self on public.post_comments;

create policy post_comments_select_authenticated
on public.post_comments for select to authenticated
using (true);

create policy post_comments_insert_self
on public.post_comments for insert to authenticated
with check (user_id = auth.uid());

create policy post_comments_delete_self
on public.post_comments for delete to authenticated
using (user_id = auth.uid());

-- Keep posts.comments_count synchronized with durable comments.
create or replace function public.sync_post_comments_count()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    update public.posts
      set comments_count = (select count(*) from public.post_comments where post_id = new.post_id)
      where id = new.post_id;
    return new;
  elsif tg_op = 'DELETE' then
    update public.posts
      set comments_count = (select count(*) from public.post_comments where post_id = old.post_id)
      where id = old.post_id;
    return old;
  end if;
  return null;
end;
$$;

drop trigger if exists post_comments_sync_counter on public.post_comments;
create trigger post_comments_sync_counter
after insert or delete on public.post_comments
for each row execute function public.sync_post_comments_count();

update public.posts p
set comments_count = (
  select count(*) from public.post_comments c where c.post_id = p.id
);

-- Notify the post owner when another user comments.
create or replace function public.notify_on_post_comment()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  owner_id uuid;
  actor_name text;
begin
  select p.user_id into owner_id
  from public.posts p
  where p.id = new.post_id;

  if owner_id is null or owner_id = new.user_id then
    return new;
  end if;

  select coalesce(name, 'زميل') into actor_name
  from public.users where id = new.user_id;

  insert into public.notifications(
    user_id, actor_id, type, title_ar, title_en,
    body_ar, body_en, data
  ) values (
    owner_id,
    new.user_id,
    'post_comment',
    'تعليق جديد',
    'New comment',
    actor_name || ' علّق على منشورك',
    actor_name || ' commented on your post',
    jsonb_build_object('post_id', new.post_id, 'comment_id', new.id)
  );
  return new;
end;
$$;

drop trigger if exists post_comments_create_notification on public.post_comments;
create trigger post_comments_create_notification
after insert on public.post_comments
for each row execute function public.notify_on_post_comment();

-- ------------------------------------------------------------
-- Push token locale and preference safety.
-- ------------------------------------------------------------
alter table public.push_device_tokens
  add column if not exists locale text not null default 'ar';

-- ------------------------------------------------------------
-- Server-side colleague request notifications.
-- This removes reliance on the Flutter client to create notifications.
-- ------------------------------------------------------------
create or replace function public.notify_on_friend_request()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  sender_name text;
begin
  select coalesce(name, new.sender_name, 'زميل')
    into sender_name
  from public.users
  where id = new.sender_id;

  insert into public.notifications(
    user_id, actor_id, type, title_ar, title_en,
    body_ar, body_en, data
  ) values (
    new.receiver_id,
    new.sender_id,
    'friend_request',
    'طلب زميل جديد',
    'New colleague request',
    sender_name || ' أرسل لك طلب زميل',
    sender_name || ' sent you a colleague request',
    jsonb_build_object('request_id', new.id)
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
    title_ar := 'تم قبول طلب الزمالة';
    title_en := 'Colleague request accepted';
    body_ar := 'تم قبول طلب الزمالة الذي أرسلته.';
    body_en := 'Your colleague request was accepted.';
  elsif new.status = 'rejected' then
    recipient := new.sender_id;
    title_ar := 'تم رفض طلب الزمالة';
    title_en := 'Colleague request declined';
    body_ar := 'تم رفض طلب الزمالة الذي أرسلته.';
    body_en := 'Your colleague request was declined.';
  else
    return new;
  end if;

  insert into public.notifications(
    user_id, actor_id, type, title_ar, title_en,
    body_ar, body_en, data
  ) values (
    recipient,
    new.receiver_id,
    'friend_request_' || new.status,
    title_ar,
    title_en,
    body_ar,
    body_en,
    jsonb_build_object('request_id', new.id)
  );

  return new;
end;
$$;

drop trigger if exists friend_requests_status_notification on public.friend_requests;
create trigger friend_requests_status_notification
after update of status on public.friend_requests
for each row
execute function public.notify_on_friend_request_update();

-- ------------------------------------------------------------
-- Useful test/repair helper: queue any existing unread notification
-- that never made it into the push queue.
-- ------------------------------------------------------------
insert into public.push_notification_queue(notification_id)
select n.id
from public.notifications n
left join public.push_notification_queue q on q.notification_id = n.id
where q.id is null;

commit;
