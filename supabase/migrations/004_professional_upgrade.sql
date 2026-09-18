-- Zameel Professional Upgrade
-- Profile identity fields + reliable post-like counters.

alter table public.users add column if not exists username text;
alter table public.users add column if not exists bio text not null default '';
alter table public.users add column if not exists headline text not null default '';
alter table public.users add column if not exists status text not null default '';
alter table public.users add column if not exists cover_image text;
alter table public.users add column if not exists website text not null default '';
alter table public.users add column if not exists profile_completed_at timestamptz;

create unique index if not exists users_username_unique_idx
on public.users (lower(username))
where username is not null and length(trim(username)) > 0;

-- Keep the denormalized counter in sync with the source of truth (likes table).
create or replace function public.sync_post_likes_count()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if TG_OP = 'INSERT' then
    update public.posts
    set likes_count = (select count(*) from public.likes where post_id = new.post_id)
    where id = new.post_id;
    return new;
  elsif TG_OP = 'DELETE' then
    update public.posts
    set likes_count = (select count(*) from public.likes where post_id = old.post_id)
    where id = old.post_id;
    return old;
  end if;
  return null;
end;
$$;

drop trigger if exists likes_sync_post_counter on public.likes;
create trigger likes_sync_post_counter
after insert or delete on public.likes
for each row execute function public.sync_post_likes_count();

-- Repair existing counters once when this migration is applied.
update public.posts p
set likes_count = (
  select count(*) from public.likes l where l.post_id = p.id
);

-- Make profile fields readable/editable under the existing user RLS rules.
-- The users_update_self policy already limits updates to auth.uid().
