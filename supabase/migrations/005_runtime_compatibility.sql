begin;

-- Runtime compatibility for the current Flutter social services.
-- Safe to run after the main compatibility migration.

alter table public.users add column if not exists profile_image text;
alter table public.users add column if not exists cover_image text;
alter table public.users add column if not exists headline text;

alter table public.profiles add column if not exists cover_image text;
alter table public.profiles add column if not exists headline text;

alter table public.social_stories add column if not exists caption text;
alter table public.social_stories add column if not exists audience text not null default 'friends';
alter table public.social_notes add column if not exists audience text not null default 'friends';
alter table public.social_notes add column if not exists updated_at timestamptz not null default now();
alter table public.clips add column if not exists audience text not null default 'public';

-- Keep profile image/cover data mirrored when possible.
update public.profiles p
set avatar_url = coalesce(p.avatar_url, u.profile_image),
    cover_image = coalesce(p.cover_image, u.cover_image),
    headline = coalesce(p.headline, u.headline),
    updated_at = now()
from public.users u
where p.id = u.id;

-- Existing social tables created by earlier project migrations use user_id.
-- The Flutter service also uses user_id, so enforce the matching uniqueness key.
create unique index if not exists close_friends_user_friend_unique
on public.close_friends(user_id, friend_id);

commit;
