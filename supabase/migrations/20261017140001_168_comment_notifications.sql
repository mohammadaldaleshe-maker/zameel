-- 168: notifications for replies to a comment and for likes on a comment
-- (post comments and clip comments).
--   * "<name> replied to your comment"  (type comment_reply / clip_comment_reply)
--   * "<name> liked your comment"       (type comment_like  / clip_comment_like)
-- Rules: never notify yourself; a like notifies at most once per person and
-- comment (like -> unlike -> like does not spam); un-liking and deleting a
-- comment remove the notification. When a reply answers the post owner's own
-- comment the owner gets only the reply notification, not a second
-- "commented on your post". Push delivery is automatic: every notifications row
-- is queued by the existing enqueue trigger. Additive and idempotent.
begin;

create table if not exists public.zameel_comment_like_notified168(
  kind text not null check (kind in ('post','clip')),
  comment_id uuid not null,
  actor_id uuid not null,
  created_at timestamptz not null default now(),
  primary key(kind, comment_id, actor_id)
);
alter table public.zameel_comment_like_notified168 enable row level security;
revoke all on table public.zameel_comment_like_notified168 from public, anon, authenticated;

-- ---------------------------------------------------------------- post comments
create or replace function public.notify_on_post_comment()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  owner_id uuid;
  actor_name text;
  parent_owner uuid;
begin
  select p.user_id into owner_id from public.posts p where p.id = new.post_id;
  if owner_id is null or owner_id = new.user_id then
    return new;
  end if;

  -- A reply to the owner's own comment is announced as a reply (below).
  if new.parent_comment_id is not null then
    select c.user_id into parent_owner from public.post_comments c where c.id = new.parent_comment_id;
    if parent_owner = owner_id then
      return new;
    end if;
  end if;

  select coalesce(name, 'زميل') into actor_name from public.users where id = new.user_id;

  insert into public.notifications(
    user_id, actor_id, type, title_ar, title_en, body_ar, body_en, data
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

create or replace function public.zameel_notify_post_reply168()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  parent_owner uuid;
  actor_name text;
begin
  if new.parent_comment_id is null then return new; end if;
  select c.user_id into parent_owner from public.post_comments c where c.id = new.parent_comment_id;
  if parent_owner is null or parent_owner = new.user_id then return new; end if;
  select coalesce(nullif(trim(name), ''), 'زميل') into actor_name from public.users where id = new.user_id;
  insert into public.notifications(user_id, actor_id, type, title_ar, title_en, body_ar, body_en, data)
  values (
    parent_owner, new.user_id, 'comment_reply',
    'رد جديد', 'New reply',
    'ردّ ' || actor_name || ' على تعليقك',
    actor_name || ' replied to your comment',
    jsonb_build_object('post_id', new.post_id, 'comment_id', new.id, 'parent_comment_id', new.parent_comment_id)
  );
  return new;
end;
$$;
revoke all on function public.zameel_notify_post_reply168() from public, anon, authenticated;
drop trigger if exists zameel_post_reply_notification168 on public.post_comments;
create trigger zameel_post_reply_notification168
after insert on public.post_comments
for each row execute function public.zameel_notify_post_reply168();

create or replace function public.zameel_notify_post_comment_like168()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  owner_id uuid;
  target_post uuid;
  actor_name text;
begin
  select c.user_id, c.post_id into owner_id, target_post from public.post_comments c where c.id = new.comment_id;
  if owner_id is null or owner_id = new.user_id then return new; end if;
  insert into public.zameel_comment_like_notified168(kind, comment_id, actor_id)
  values ('post', new.comment_id, new.user_id) on conflict do nothing;
  if not found then return new; end if;
  select coalesce(nullif(trim(name), ''), 'زميل') into actor_name from public.users where id = new.user_id;
  insert into public.notifications(user_id, actor_id, type, title_ar, title_en, body_ar, body_en, data)
  values (
    owner_id, new.user_id, 'comment_like',
    'إعجاب جديد', 'New like',
    'أعجب ' || actor_name || ' بتعليقك',
    actor_name || ' liked your comment',
    jsonb_build_object('post_id', target_post, 'comment_id', new.comment_id)
  );
  return new;
end;
$$;
revoke all on function public.zameel_notify_post_comment_like168() from public, anon, authenticated;
drop trigger if exists zameel_post_comment_like_notification168 on public.post_comment_likes;
create trigger zameel_post_comment_like_notification168
after insert on public.post_comment_likes
for each row execute function public.zameel_notify_post_comment_like168();

create or replace function public.zameel_unlike_post_comment_cleanup168()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  delete from public.notifications
  where type = 'comment_like' and actor_id = old.user_id
    and data->>'comment_id' = old.comment_id::text;
  return old;
end;
$$;
revoke all on function public.zameel_unlike_post_comment_cleanup168() from public, anon, authenticated;
drop trigger if exists zameel_post_comment_unlike_cleanup168 on public.post_comment_likes;
create trigger zameel_post_comment_unlike_cleanup168
after delete on public.post_comment_likes
for each row execute function public.zameel_unlike_post_comment_cleanup168();

create or replace function public.zameel_comment_deleted_cleanup168()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  delete from public.notifications
  where type in ('comment_reply','comment_like')
    and (data->>'comment_id' = old.id::text or data->>'parent_comment_id' = old.id::text);
  delete from public.zameel_comment_like_notified168 where kind = 'post' and comment_id = old.id;
  return old;
end;
$$;
revoke all on function public.zameel_comment_deleted_cleanup168() from public, anon, authenticated;
drop trigger if exists zameel_post_comment_deleted_cleanup168 on public.post_comments;
create trigger zameel_post_comment_deleted_cleanup168
after delete on public.post_comments
for each row execute function public.zameel_comment_deleted_cleanup168();

-- ---------------------------------------------------------------- clip comments
create or replace function public.notify_on_clip_comment()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  owner_id uuid;
  actor_name text;
  parent_owner uuid;
begin
  select c.user_id into owner_id from public.clips c where c.id = new.clip_id;
  if owner_id is null or owner_id = new.user_id then return new; end if;
  if new.parent_comment_id is not null then
    select c.user_id into parent_owner from public.clip_comments c where c.id = new.parent_comment_id;
    if parent_owner = owner_id then return new; end if;
  end if;
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

create or replace function public.zameel_notify_clip_reply168()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  parent_owner uuid;
  actor_name text;
begin
  if new.parent_comment_id is null then return new; end if;
  select c.user_id into parent_owner from public.clip_comments c where c.id = new.parent_comment_id;
  if parent_owner is null or parent_owner = new.user_id then return new; end if;
  select coalesce(nullif(trim(name), ''), 'زميل') into actor_name from public.users where id = new.user_id;
  insert into public.notifications(user_id, actor_id, type, title_ar, title_en, body_ar, body_en, data)
  values (
    parent_owner, new.user_id, 'clip_comment_reply',
    'رد جديد', 'New reply',
    'ردّ ' || actor_name || ' على تعليقك',
    actor_name || ' replied to your comment',
    jsonb_build_object('clip_id', new.clip_id, 'comment_id', new.id, 'parent_comment_id', new.parent_comment_id)
  );
  return new;
end;
$$;
revoke all on function public.zameel_notify_clip_reply168() from public, anon, authenticated;
drop trigger if exists zameel_clip_reply_notification168 on public.clip_comments;
create trigger zameel_clip_reply_notification168
after insert on public.clip_comments
for each row execute function public.zameel_notify_clip_reply168();

create or replace function public.zameel_notify_clip_comment_like168()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  owner_id uuid;
  target_clip uuid;
  actor_name text;
begin
  select c.user_id, c.clip_id into owner_id, target_clip from public.clip_comments c where c.id = new.comment_id;
  if owner_id is null or owner_id = new.user_id then return new; end if;
  insert into public.zameel_comment_like_notified168(kind, comment_id, actor_id)
  values ('clip', new.comment_id, new.user_id) on conflict do nothing;
  if not found then return new; end if;
  select coalesce(nullif(trim(name), ''), 'زميل') into actor_name from public.users where id = new.user_id;
  insert into public.notifications(user_id, actor_id, type, title_ar, title_en, body_ar, body_en, data)
  values (
    owner_id, new.user_id, 'clip_comment_like',
    'إعجاب جديد', 'New like',
    'أعجب ' || actor_name || ' بتعليقك',
    actor_name || ' liked your comment',
    jsonb_build_object('clip_id', target_clip, 'comment_id', new.comment_id)
  );
  return new;
end;
$$;
revoke all on function public.zameel_notify_clip_comment_like168() from public, anon, authenticated;
drop trigger if exists zameel_clip_comment_like_notification168 on public.clip_comment_likes;
create trigger zameel_clip_comment_like_notification168
after insert on public.clip_comment_likes
for each row execute function public.zameel_notify_clip_comment_like168();

create or replace function public.zameel_unlike_clip_comment_cleanup168()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  delete from public.notifications
  where type = 'clip_comment_like' and actor_id = old.user_id
    and data->>'comment_id' = old.comment_id::text;
  return old;
end;
$$;
revoke all on function public.zameel_unlike_clip_comment_cleanup168() from public, anon, authenticated;
drop trigger if exists zameel_clip_comment_unlike_cleanup168 on public.clip_comment_likes;
create trigger zameel_clip_comment_unlike_cleanup168
after delete on public.clip_comment_likes
for each row execute function public.zameel_unlike_clip_comment_cleanup168();

create or replace function public.zameel_clip_comment_deleted_cleanup168()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  delete from public.notifications
  where type in ('clip_comment_reply','clip_comment_like')
    and (data->>'comment_id' = old.id::text or data->>'parent_comment_id' = old.id::text);
  delete from public.zameel_comment_like_notified168 where kind = 'clip' and comment_id = old.id;
  return old;
end;
$$;
revoke all on function public.zameel_clip_comment_deleted_cleanup168() from public, anon, authenticated;
drop trigger if exists zameel_clip_comment_deleted_cleanup168 on public.clip_comments;
create trigger zameel_clip_comment_deleted_cleanup168
after delete on public.clip_comments
for each row execute function public.zameel_clip_comment_deleted_cleanup168();

notify pgrst, 'reload schema';
commit;
