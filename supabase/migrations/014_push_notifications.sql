-- Zameel push notification infrastructure.
-- Stores FCM registration tokens per authenticated user/device.
-- The notifications table remains the canonical source of events.

create table if not exists public.push_device_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  token text not null unique,
  platform text not null default 'android',
  updated_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

create index if not exists push_device_tokens_user_idx
  on public.push_device_tokens(user_id, updated_at desc);

alter table public.push_device_tokens enable row level security;

drop policy if exists push_device_tokens_select_own on public.push_device_tokens;
drop policy if exists push_device_tokens_insert_own on public.push_device_tokens;
drop policy if exists push_device_tokens_update_own on public.push_device_tokens;
drop policy if exists push_device_tokens_delete_own on public.push_device_tokens;

create policy push_device_tokens_select_own
on public.push_device_tokens for select to authenticated
using (user_id = auth.uid());

create policy push_device_tokens_insert_own
on public.push_device_tokens for insert to authenticated
with check (user_id = auth.uid());

create policy push_device_tokens_update_own
on public.push_device_tokens for update to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

create policy push_device_tokens_delete_own
on public.push_device_tokens for delete to authenticated
using (user_id = auth.uid());

-- Optional queue used by the push sender. This keeps notification creation
-- decoupled from the network provider and avoids blocking the user action.
create table if not exists public.push_notification_queue (
  id uuid primary key default gen_random_uuid(),
  notification_id uuid not null references public.notifications(id) on delete cascade,
  status text not null default 'pending' check (status in ('pending','processing','sent','failed')),
  attempts integer not null default 0,
  last_error text,
  created_at timestamptz not null default now(),
  processed_at timestamptz
);

create unique index if not exists push_notification_queue_notification_unique
  on public.push_notification_queue(notification_id);

create index if not exists push_notification_queue_pending_idx
  on public.push_notification_queue(status, created_at)
  where status in ('pending','failed');

alter table public.push_notification_queue enable row level security;

-- Queue is server-managed; clients do not read/write it.

drop trigger if exists notifications_enqueue_push on public.notifications;

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

create trigger notifications_enqueue_push
after insert on public.notifications
for each row execute function public.enqueue_notification_for_push();


-- ============================================================
-- Automatic app events -> notifications rows
-- The existing notifications table remains the single source
-- of truth; inserting here automatically enters the push queue.
-- ============================================================

create or replace function public.notify_on_message()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  member record;
  sender_name text;
begin
  select coalesce(name, 'زميل') into sender_name
  from public.users where id = new.sender_id;

  for member in
    select cm.user_id
    from public.conversation_members cm
    where cm.conversation_id = new.conversation_id
      and cm.user_id <> new.sender_id
  loop
    insert into public.notifications(
      user_id, actor_id, type, title_ar, title_en, body_ar, body_en, data
    ) values (
      member.user_id,
      new.sender_id,
      'message',
      'رسالة جديدة',
      'New message',
      sender_name || ' أرسل لك رسالة',
      sender_name || ' sent you a message',
      jsonb_build_object('conversation_id', new.conversation_id, 'message_id', new.id)
    );
  end loop;
  return new;
end;
$$;

drop trigger if exists messages_create_notification on public.messages;
create trigger messages_create_notification
after insert on public.messages
for each row execute function public.notify_on_message();


create or replace function public.notify_on_like()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  owner_id uuid;
  actor_name text;
begin
  select p.user_id into owner_id from public.posts p where p.id = new.post_id;
  if owner_id is null or owner_id = new.user_id then return new; end if;
  select coalesce(name, 'زميل') into actor_name from public.users where id = new.user_id;

  insert into public.notifications(
    user_id, actor_id, type, title_ar, title_en, body_ar, body_en, data
  ) values (
    owner_id,
    new.user_id,
    'post_like',
    'إعجاب جديد',
    'New like',
    actor_name || ' أعجب بمنشورك',
    actor_name || ' liked your post',
    jsonb_build_object('post_id', new.post_id)
  );
  return new;
end;
$$;

drop trigger if exists likes_create_notification on public.likes;
create trigger likes_create_notification
after insert on public.likes
for each row execute function public.notify_on_like();


create or replace function public.notify_on_follow()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  actor_name text;
begin
  if new.follower_id = new.following_id then return new; end if;
  select coalesce(name, 'زميل') into actor_name from public.users where id = new.follower_id;
  insert into public.notifications(
    user_id, actor_id, type, title_ar, title_en, body_ar, body_en, data
  ) values (
    new.following_id,
    new.follower_id,
    'follow',
    'زميل جديد',
    'New colleague',
    actor_name || ' بدأ بمتابعتك',
    actor_name || ' started following you',
    jsonb_build_object('user_id', new.follower_id)
  );
  return new;
end;
$$;

drop trigger if exists follows_create_notification on public.follows;
create trigger follows_create_notification
after insert on public.follows
for each row execute function public.notify_on_follow();


create or replace function public.notify_on_shared_post()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  owner_id uuid;
  actor_name text;
begin
  select p.user_id into owner_id from public.posts p where p.id = new.post_id;
  if owner_id is null or owner_id = new.shared_by then return new; end if;
  select coalesce(name, 'زميل') into actor_name from public.users where id = new.shared_by;
  insert into public.notifications(
    user_id, actor_id, type, title_ar, title_en, body_ar, body_en, data
  ) values (
    owner_id,
    new.shared_by,
    'post_share',
    'مشاركة جديدة',
    'New share',
    actor_name || ' شارك منشورك',
    actor_name || ' shared your post',
    jsonb_build_object('post_id', new.post_id)
  );
  return new;
end;
$$;

drop trigger if exists shared_posts_create_notification on public.shared_posts;
create trigger shared_posts_create_notification
after insert on public.shared_posts
for each row execute function public.notify_on_shared_post();


create or replace function public.notify_on_story_reaction()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  owner_id uuid;
  actor_name text;
begin
  select s.user_id into owner_id from public.social_stories s where s.id = new.story_id;
  if owner_id is null or owner_id = new.user_id then return new; end if;
  select coalesce(name, 'زميل') into actor_name from public.users where id = new.user_id;
  insert into public.notifications(
    user_id, actor_id, type, title_ar, title_en, body_ar, body_en, data
  ) values (
    owner_id,
    new.user_id,
    'story_reaction',
    'تفاعل جديد',
    'New story reaction',
    actor_name || ' تفاعل مع قصتك',
    actor_name || ' reacted to your story',
    jsonb_build_object('story_id', new.story_id, 'reaction', new.reaction)
  );
  return new;
end;
$$;

drop trigger if exists story_reactions_create_notification on public.story_reactions;
create trigger story_reactions_create_notification
after insert on public.story_reactions
for each row execute function public.notify_on_story_reaction();


create or replace function public.notify_on_clip_comment()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  owner_id uuid;
  actor_name text;
begin
  select c.user_id into owner_id from public.clips c where c.id = new.clip_id;
  if owner_id is null or owner_id = new.user_id then return new; end if;
  select coalesce(name, 'زميل') into actor_name from public.users where id = new.user_id;
  insert into public.notifications(
    user_id, actor_id, type, title_ar, title_en, body_ar, body_en, data
  ) values (
    owner_id,
    new.user_id,
    'clip_comment',
    'تعليق جديد',
    'New comment',
    actor_name || ' علّق على مقطعك',
    actor_name || ' commented on your clip',
    jsonb_build_object('clip_id', new.clip_id, 'comment_id', new.id)
  );
  return new;
end;
$$;

drop trigger if exists clip_comments_create_notification on public.clip_comments;
create trigger clip_comments_create_notification
after insert on public.clip_comments
for each row execute function public.notify_on_clip_comment();


create or replace function public.notify_on_graduation_book_member()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  owner_id uuid;
  actor_name text;
begin
  select b.owner_id into owner_id from public.graduation_books b where b.id = new.book_id;
  if owner_id is null or owner_id = new.user_id then return new; end if;
  select coalesce(name, 'زميل') into actor_name from public.users where id = new.user_id;
  insert into public.notifications(
    user_id, actor_id, type, title_ar, title_en, body_ar, body_en, data
  ) values (
    owner_id,
    new.user_id,
    'graduation_book_join',
    'انضمام إلى دفتر الخريجين',
    'New graduation book participant',
    actor_name || ' انضم إلى دفتر الخريجين الخاص بك',
    actor_name || ' joined your graduation book',
    jsonb_build_object('book_id', new.book_id)
  );
  return new;
end;
$$;

drop trigger if exists graduation_book_members_create_notification on public.graduation_book_members;
create trigger graduation_book_members_create_notification
after insert on public.graduation_book_members
for each row execute function public.notify_on_graduation_book_member();
