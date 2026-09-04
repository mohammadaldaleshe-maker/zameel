begin;

-- Real visibility for posts: public / friends (people the author follows) / private.
alter table public.posts add column if not exists audience text not null default 'public';
update public.posts set audience = 'public' where audience is null;

-- Replace the previous broad SELECT policy with an audience-aware policy.
drop policy if exists posts_select_authenticated on public.posts;
drop policy if exists posts_public_read on public.posts;
create policy posts_select_by_audience
on public.posts for select
to authenticated
using (
  user_id = auth.uid()
  or audience = 'public'
  or (
    audience = 'friends'
    and exists (
      select 1 from public.follows f
      where f.follower_id = auth.uid()
        and f.following_id = posts.user_id
    )
  )
);

-- University calendar cache. Data is refreshed from official university sources by the Edge Function.
create table if not exists public.university_calendar_events (
  id uuid primary key default gen_random_uuid(),
  university_key text not null,
  university_name text not null,
  title_ar text,
  title_en text,
  event_date date not null,
  end_date date,
  time_text text,
  source_url text not null,
  source_title text,
  fetched_at timestamptz not null default now(),
  unique (university_key, event_date, title_en, source_url)
);

create unique index if not exists follows_follower_following_unique
  on public.follows(follower_id, following_id);

create index if not exists university_calendar_events_university_date_idx
  on public.university_calendar_events(university_key, event_date);

alter table public.university_calendar_events enable row level security;
drop policy if exists university_calendar_events_select_authenticated on public.university_calendar_events;
create policy university_calendar_events_select_authenticated
on public.university_calendar_events for select
to authenticated using (true);

commit;
