-- Zameel social engagement layer: Instagram/Snapchat/WhatsApp-inspired,
-- adapted for university life. Run after 001_core_schema.sql.

create table if not exists public.follows (
  follower_id uuid not null references public.users(id) on delete cascade,
  following_id uuid not null references public.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (follower_id, following_id),
  check (follower_id <> following_id)
);

create table if not exists public.close_friends (
  owner_id uuid not null references public.users(id) on delete cascade,
  friend_id uuid not null references public.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (owner_id, friend_id),
  check (owner_id <> friend_id)
);

create table if not exists public.social_stories (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  media_url text,
  media_type text not null default 'image' check (media_type in ('image','video','text')),
  caption text not null default '',
  audience text not null default 'friends' check (audience in ('public','friends','close_friends','faculty','group')),
  group_id uuid,
  expires_at timestamptz not null default (now() + interval '24 hours'),
  created_at timestamptz not null default now()
);

create table if not exists public.story_views (
  story_id uuid not null references public.social_stories(id) on delete cascade,
  viewer_id uuid not null references public.users(id) on delete cascade,
  viewed_at timestamptz not null default now(),
  primary key (story_id, viewer_id)
);

create table if not exists public.story_reactions (
  story_id uuid not null references public.social_stories(id) on delete cascade,
  user_id uuid not null references public.users(id) on delete cascade,
  reaction text not null default '❤️',
  created_at timestamptz not null default now(),
  primary key (story_id, user_id)
);

create table if not exists public.social_notes (
  user_id uuid primary key references public.users(id) on delete cascade,
  text text not null default '',
  audience text not null default 'friends' check (audience in ('friends','close_friends')),
  updated_at timestamptz not null default now(),
  expires_at timestamptz not null default (now() + interval '24 hours')
);

create table if not exists public.clips (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  video_url text not null,
  caption text not null default '',
  duration_seconds integer not null check (duration_seconds > 0 and duration_seconds <= 120),
  audience text not null default 'public' check (audience in ('public','friends','faculty','group')),
  likes_count integer not null default 0,
  comments_count integer not null default 0,
  shares_count integer not null default 0,
  created_at timestamptz not null default now()
);

create table if not exists public.clip_likes (
  clip_id uuid not null references public.clips(id) on delete cascade,
  user_id uuid not null references public.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (clip_id, user_id)
);

create table if not exists public.clip_comments (
  id uuid primary key default gen_random_uuid(),
  clip_id uuid not null references public.clips(id) on delete cascade,
  user_id uuid not null references public.users(id) on delete cascade,
  text text not null check (char_length(text) between 1 and 1000),
  created_at timestamptz not null default now()
);

create table if not exists public.highlights (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  title text not null check (char_length(title) between 1 and 40),
  cover_url text,
  created_at timestamptz not null default now()
);

create table if not exists public.highlight_stories (
  highlight_id uuid not null references public.highlights(id) on delete cascade,
  story_id uuid not null references public.social_stories(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (highlight_id, story_id)
);

create index if not exists follows_following_idx on public.follows(following_id);
create index if not exists stories_user_created_idx on public.social_stories(user_id, created_at desc);
create index if not exists stories_expires_idx on public.social_stories(expires_at);
create index if not exists clips_created_idx on public.clips(created_at desc);
create index if not exists clips_user_idx on public.clips(user_id, created_at desc);
create index if not exists clip_comments_clip_idx on public.clip_comments(clip_id, created_at);
create index if not exists highlights_user_idx on public.highlights(user_id, created_at desc);

do $$ begin
  execute 'alter table public.social_stories enable row level security';
  execute 'alter table public.story_views enable row level security';
  execute 'alter table public.story_reactions enable row level security';
  execute 'alter table public.social_notes enable row level security';
  execute 'alter table public.clips enable row level security';
  execute 'alter table public.clip_likes enable row level security';
  execute 'alter table public.clip_comments enable row level security';
  execute 'alter table public.follows enable row level security';
  execute 'alter table public.close_friends enable row level security';
  execute 'alter table public.highlights enable row level security';
  execute 'alter table public.highlight_stories enable row level security';
end $$;

-- Re-runnable policy setup
do $$ begin
  drop policy if exists follows_read on public.follows;
  drop policy if exists follows_insert_self on public.follows;
  drop policy if exists follows_delete_self on public.follows;
  drop policy if exists close_friends_self on public.close_friends;
  drop policy if exists stories_read on public.social_stories;
  drop policy if exists stories_insert_self on public.social_stories;
  drop policy if exists stories_update_self on public.social_stories;
  drop policy if exists stories_delete_self on public.social_stories;
  drop policy if exists story_views_self on public.story_views;
  drop policy if exists story_reactions_self on public.story_reactions;
  drop policy if exists notes_read on public.social_notes;
  drop policy if exists notes_self on public.social_notes;
  drop policy if exists clips_read on public.clips;
  drop policy if exists clips_insert_self on public.clips;
  drop policy if exists clips_update_self on public.clips;
  drop policy if exists clips_delete_self on public.clips;
  drop policy if exists clip_likes_read on public.clip_likes;
  drop policy if exists clip_likes_self on public.clip_likes;
  drop policy if exists clip_comments_read on public.clip_comments;
  drop policy if exists clip_comments_self on public.clip_comments;
  drop policy if exists clip_comments_delete_self on public.clip_comments;
  drop policy if exists highlights_read on public.highlights;
  drop policy if exists highlights_self on public.highlights;
  drop policy if exists highlight_stories_read on public.highlight_stories;
  drop policy if exists highlight_stories_self on public.highlight_stories;
end $$;

-- Basic authenticated policies. Audience-specific filtering should be enforced
-- by backend views/functions as the social graph grows.
create policy follows_read on public.follows for select to authenticated using (true);
create policy follows_insert_self on public.follows for insert to authenticated with check (follower_id = auth.uid());
create policy follows_delete_self on public.follows for delete to authenticated using (follower_id = auth.uid());
create policy close_friends_self on public.close_friends for all to authenticated using (owner_id = auth.uid()) with check (owner_id = auth.uid());
create policy stories_read on public.social_stories for select to authenticated using (expires_at > now());
create policy stories_insert_self on public.social_stories for insert to authenticated with check (user_id = auth.uid());
create policy stories_update_self on public.social_stories for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy stories_delete_self on public.social_stories for delete to authenticated using (user_id = auth.uid());
create policy story_views_self on public.story_views for all to authenticated using (viewer_id = auth.uid()) with check (viewer_id = auth.uid());
create policy story_reactions_self on public.story_reactions for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy notes_read on public.social_notes for select to authenticated using (true);
create policy notes_self on public.social_notes for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy clips_read on public.clips for select to authenticated using (true);
create policy clips_insert_self on public.clips for insert to authenticated with check (user_id = auth.uid());
create policy clips_update_self on public.clips for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy clips_delete_self on public.clips for delete to authenticated using (user_id = auth.uid());
create policy clip_likes_read on public.clip_likes for select to authenticated using (true);
create policy clip_likes_self on public.clip_likes for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy clip_comments_read on public.clip_comments for select to authenticated using (true);
create policy clip_comments_self on public.clip_comments for insert to authenticated with check (user_id = auth.uid());
create policy clip_comments_delete_self on public.clip_comments for delete to authenticated using (user_id = auth.uid());
create policy highlights_read on public.highlights for select to authenticated using (true);
create policy highlights_self on public.highlights for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy highlight_stories_read on public.highlight_stories for select to authenticated using (true);
create policy highlight_stories_self on public.highlight_stories for all to authenticated using (exists (select 1 from public.highlights h where h.id=highlight_id and h.user_id=auth.uid()));
