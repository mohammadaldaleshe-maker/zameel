-- Zameel 057
-- Lazy/PDF library download counters + persistent threaded comments/replies/likes.

begin;

-- ---------------------------------------------------------------------------
-- Compatibility with legacy clips longer than 45 seconds.
--
-- Migration 042 introduced a NOT VALID CHECK for 1..45 seconds. PostgreSQL
-- still evaluates a NOT VALID CHECK whenever an existing row is UPDATEd.
-- Some older clips were legitimately stored under the previous <=120 second
-- rule, so updating only likes_count/comments_count would fail for those rows.
--
-- Keep the 45-second policy for every NEW clip and whenever duration_seconds
-- itself is changed, without blocking unrelated updates on legacy clips.
-- ---------------------------------------------------------------------------
alter table public.clips
  drop constraint if exists clips_duration_45_seconds_check;

create or replace function public.enforce_clip_duration_45_seconds()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if new.duration_seconds is null
     or new.duration_seconds < 1
     or new.duration_seconds > 45 then
    raise exception using
      errcode = '23514',
      message = 'clip duration must be between 1 and 45 seconds';
  end if;
  return new;
end;
$$;

drop trigger if exists clips_enforce_duration_45_seconds on public.clips;
create trigger clips_enforce_duration_45_seconds
before insert or update of duration_seconds on public.clips
for each row execute function public.enforce_clip_duration_45_seconds();


-- ---------------------------------------------------------------------------
-- Zameel Library download counters
-- Works for bundled seed items and remote/open-source items alike.
-- ---------------------------------------------------------------------------
create table if not exists public.zameel_library_download_counts (
  item_key text primary key,
  item_type text not null default 'book' check (item_type in ('book','summary')),
  download_count bigint not null default 0 check (download_count >= 0),
  updated_at timestamptz not null default now()
);

alter table public.zameel_library_download_counts enable row level security;
grant select on table public.zameel_library_download_counts to authenticated;

drop policy if exists zameel_library_download_counts_read on public.zameel_library_download_counts;
create policy zameel_library_download_counts_read
on public.zameel_library_download_counts
for select to authenticated
using (true);

create or replace function public.record_zameel_library_download(
  target_item_key text,
  target_item_type text default 'book'
)
returns bigint
language plpgsql
security definer
set search_path = public
set row_security = off
as $$
declare
  result_count bigint;
begin
  if auth.uid() is null then
    raise exception 'not_authenticated';
  end if;
  if coalesce(trim(target_item_key), '') = '' then
    raise exception 'invalid_item_key';
  end if;
  if target_item_type is null or target_item_type not in ('book','summary') then
    target_item_type := 'book';
  end if;

  insert into public.zameel_library_download_counts(
    item_key, item_type, download_count, updated_at
  )
  values(target_item_key, target_item_type, 1, now())
  on conflict (item_key) do update
    set download_count = public.zameel_library_download_counts.download_count + 1,
        item_type = excluded.item_type,
        updated_at = now()
  returning download_count into result_count;

  return result_count;
end;
$$;

revoke execute on function public.record_zameel_library_download(text,text) from public, anon;
grant execute on function public.record_zameel_library_download(text,text) to authenticated;

-- ---------------------------------------------------------------------------
-- Threaded post comments + likes on comments.
-- Public post/image/video comments use the same post_comments table.
-- ---------------------------------------------------------------------------
alter table public.post_comments
  add column if not exists parent_comment_id uuid,
  add column if not exists likes_count integer not null default 0;

-- Recreate the self-reference only if it does not already exist.
do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'post_comments_parent_comment_id_fkey'
      and conrelid = 'public.post_comments'::regclass
  ) then
    alter table public.post_comments
      add constraint post_comments_parent_comment_id_fkey
      foreign key (parent_comment_id)
      references public.post_comments(id)
      on delete cascade;
  end if;
end $$;

create index if not exists post_comments_parent_idx
  on public.post_comments(parent_comment_id, created_at);

create or replace function public.validate_post_comment_parent()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if new.parent_comment_id is not null and not exists (
    select 1 from public.post_comments parent
    where parent.id = new.parent_comment_id
      and parent.post_id = new.post_id
  ) then
    raise exception 'invalid_parent_comment';
  end if;
  return new;
end;
$$;

drop trigger if exists post_comments_validate_parent on public.post_comments;
create trigger post_comments_validate_parent
before insert or update of parent_comment_id, post_id on public.post_comments
for each row execute function public.validate_post_comment_parent();

create table if not exists public.post_comment_likes (
  comment_id uuid not null references public.post_comments(id) on delete cascade,
  user_id uuid not null references public.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key(comment_id, user_id)
);

create index if not exists post_comment_likes_user_idx
  on public.post_comment_likes(user_id, created_at desc);

alter table public.post_comment_likes enable row level security;
grant select, insert, delete on table public.post_comment_likes to authenticated;

drop policy if exists post_comment_likes_read on public.post_comment_likes;
drop policy if exists post_comment_likes_insert_self on public.post_comment_likes;
drop policy if exists post_comment_likes_delete_self on public.post_comment_likes;
create policy post_comment_likes_read
on public.post_comment_likes for select to authenticated
using (true);
create policy post_comment_likes_insert_self
on public.post_comment_likes for insert to authenticated
with check (user_id = auth.uid());
create policy post_comment_likes_delete_self
on public.post_comment_likes for delete to authenticated
using (user_id = auth.uid());

-- Only the comment author edits/deletes their comment in the client-facing flow.
drop policy if exists post_comments_update_own on public.post_comments;
create policy post_comments_update_own
on public.post_comments for update to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

drop policy if exists post_comments_delete_self on public.post_comments;
drop policy if exists post_comments_delete_owner on public.post_comments;
create policy post_comments_delete_self
on public.post_comments for delete to authenticated
using (user_id = auth.uid());

create or replace function public.sync_post_comment_likes_count()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  target_comment_id uuid;
begin
  if tg_op = 'DELETE' then
    target_comment_id := old.comment_id;
  else
    target_comment_id := new.comment_id;
  end if;

  update public.post_comments
  set likes_count = (
    select count(*)::int
    from public.post_comment_likes l
    where l.comment_id = target_comment_id
  )
  where id = target_comment_id;

  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;

drop trigger if exists post_comment_likes_sync_counter on public.post_comment_likes;
create trigger post_comment_likes_sync_counter
after insert or delete on public.post_comment_likes
for each row execute function public.sync_post_comment_likes_count();

update public.post_comments c
set likes_count = (
  select count(*)::int from public.post_comment_likes l where l.comment_id = c.id
);

-- ---------------------------------------------------------------------------
-- Persistent clip comments/replies/likes and durable clip engagement counters.
-- ---------------------------------------------------------------------------
-- Some existing Zameel databases were created before the cached engagement
-- counters were added to public.clips. Add them defensively before triggers or
-- repair statements reference them.
alter table public.clips
  add column if not exists likes_count integer not null default 0,
  add column if not exists comments_count integer not null default 0;

alter table public.clip_comments
  add column if not exists parent_comment_id uuid,
  add column if not exists updated_at timestamptz,
  add column if not exists likes_count integer not null default 0;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'clip_comments_parent_comment_id_fkey'
      and conrelid = 'public.clip_comments'::regclass
  ) then
    alter table public.clip_comments
      add constraint clip_comments_parent_comment_id_fkey
      foreign key (parent_comment_id)
      references public.clip_comments(id)
      on delete cascade;
  end if;
end $$;

create index if not exists clip_comments_parent_idx
  on public.clip_comments(parent_comment_id, created_at);

create or replace function public.validate_clip_comment_parent()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if new.parent_comment_id is not null and not exists (
    select 1 from public.clip_comments parent
    where parent.id = new.parent_comment_id
      and parent.clip_id = new.clip_id
  ) then
    raise exception 'invalid_parent_comment';
  end if;
  return new;
end;
$$;

drop trigger if exists clip_comments_validate_parent on public.clip_comments;
create trigger clip_comments_validate_parent
before insert or update of parent_comment_id, clip_id on public.clip_comments
for each row execute function public.validate_clip_comment_parent();

create table if not exists public.clip_comment_likes (
  comment_id uuid not null references public.clip_comments(id) on delete cascade,
  user_id uuid not null references public.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key(comment_id, user_id)
);

create index if not exists clip_comment_likes_user_idx
  on public.clip_comment_likes(user_id, created_at desc);

alter table public.clip_comment_likes enable row level security;
grant select, insert, delete on table public.clip_comment_likes to authenticated;

drop policy if exists clip_comment_likes_read on public.clip_comment_likes;
drop policy if exists clip_comment_likes_insert_self on public.clip_comment_likes;
drop policy if exists clip_comment_likes_delete_self on public.clip_comment_likes;
create policy clip_comment_likes_read
on public.clip_comment_likes for select to authenticated
using (true);
create policy clip_comment_likes_insert_self
on public.clip_comment_likes for insert to authenticated
with check (user_id = auth.uid());
create policy clip_comment_likes_delete_self
on public.clip_comment_likes for delete to authenticated
using (user_id = auth.uid());

-- Existing read/insert/delete policies are retained; add author-only edit.
drop policy if exists clip_comments_update_self on public.clip_comments;
create policy clip_comments_update_self
on public.clip_comments for update to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

create or replace function public.sync_clip_likes_count()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  target_clip_id uuid;
begin
  if tg_op = 'DELETE' then
    target_clip_id := old.clip_id;
  else
    target_clip_id := new.clip_id;
  end if;

  update public.clips
  set likes_count = (
    select count(*)::int from public.clip_likes l
    where l.clip_id = target_clip_id
  )
  where id = target_clip_id;

  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;

drop trigger if exists clip_likes_sync_counter on public.clip_likes;
create trigger clip_likes_sync_counter
after insert or delete on public.clip_likes
for each row execute function public.sync_clip_likes_count();

create or replace function public.sync_clip_comments_count()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  target_clip_id uuid;
begin
  if tg_op = 'DELETE' then
    target_clip_id := old.clip_id;
  else
    target_clip_id := new.clip_id;
  end if;

  update public.clips
  set comments_count = (
    select count(*)::int from public.clip_comments c
    where c.clip_id = target_clip_id
  )
  where id = target_clip_id;

  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;

drop trigger if exists clip_comments_sync_counter on public.clip_comments;
create trigger clip_comments_sync_counter
after insert or delete on public.clip_comments
for each row execute function public.sync_clip_comments_count();

create or replace function public.sync_clip_comment_likes_count()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  target_comment_id uuid;
begin
  if tg_op = 'DELETE' then
    target_comment_id := old.comment_id;
  else
    target_comment_id := new.comment_id;
  end if;

  update public.clip_comments
  set likes_count = (
    select count(*)::int from public.clip_comment_likes l
    where l.comment_id = target_comment_id
  )
  where id = target_comment_id;

  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;

drop trigger if exists clip_comment_likes_sync_counter on public.clip_comment_likes;
create trigger clip_comment_likes_sync_counter
after insert or delete on public.clip_comment_likes
for each row execute function public.sync_clip_comment_likes_count();

-- Repair any stale counters created by previous client-only updates.
update public.clips c
set likes_count = (
      select count(*)::int from public.clip_likes l where l.clip_id = c.id
    ),
    comments_count = (
      select count(*)::int from public.clip_comments m where m.clip_id = c.id
    );

update public.clip_comments c
set likes_count = (
  select count(*)::int from public.clip_comment_likes l where l.comment_id = c.id
);

commit;
