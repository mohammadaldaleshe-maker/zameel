-- Zameel v1.3.6+22 feature additions
-- Idempotent migration for the already-existing schema.

begin;

alter table public.users
  add column if not exists account_privacy text not null default 'public',
  add column if not exists default_post_audience text not null default 'public',
  add column if not exists allow_messages boolean not null default true,
  add column if not exists allow_calls boolean not null default true,
  add column if not exists notifications_enabled boolean not null default true,
  add column if not exists gender text;

alter table public.notifications
  add column if not exists title_ar text not null default '',
  add column if not exists title_en text not null default '',
  add column if not exists body_ar text not null default '',
  add column if not exists body_en text not null default '',
  add column if not exists data jsonb not null default '{}'::jsonb;

do $$
begin
  alter table public.users drop constraint if exists users_account_privacy_check;
  alter table public.users add constraint users_account_privacy_check
    check (account_privacy in ('public','colleagues'));
exception when duplicate_object then null;
end $$;

do $$
begin
  alter table public.users drop constraint if exists users_default_post_audience_check;
  alter table public.users add constraint users_default_post_audience_check
    check (default_post_audience in ('public','friends','private'));
exception when duplicate_object then null;
end $$;

do $$
begin
  alter table public.users drop constraint if exists users_gender_check;
  alter table public.users add constraint users_gender_check
    check (gender is null or gender in ('female','male','other'));
exception when duplicate_object then null;
end $$;

alter table public.posts
  add column if not exists audience text not null default 'public',
  add column if not exists shares_count integer not null default 0;

do $$
begin
  alter table public.posts drop constraint if exists posts_audience_check;
  alter table public.posts add constraint posts_audience_check
    check (audience in ('public','friends','private'));
exception when duplicate_object then null;
end $$;

create table if not exists public.friend_requests (
  id uuid primary key default gen_random_uuid(),
  sender_id uuid not null references public.users(id) on delete cascade,
  receiver_id uuid not null references public.users(id) on delete cascade,
  sender_name text not null default '',
  receiver_name text not null default '',
  status text not null default 'pending',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (sender_id <> receiver_id),
  check (status in ('pending','accepted','rejected','cancelled'))
);

create unique index if not exists friend_requests_pending_unique
  on public.friend_requests(sender_id, receiver_id)
  where status = 'pending';

create index if not exists friend_requests_receiver_idx
  on public.friend_requests(receiver_id, status, created_at desc);

create table if not exists public.shared_posts (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.posts(id) on delete cascade,
  shared_by uuid not null references public.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique(post_id, shared_by)
);

create index if not exists shared_posts_user_idx
  on public.shared_posts(shared_by, created_at desc);

create index if not exists shared_posts_post_idx
  on public.shared_posts(post_id, created_at desc);

create table if not exists public.meeting_rooms (
  id uuid primary key default gen_random_uuid(),
  room_code text not null unique,
  host_id uuid not null references public.users(id) on delete cascade,
  title text not null default 'Zameel Meeting',
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  ended_at timestamptz
);

create index if not exists meeting_rooms_host_idx
  on public.meeting_rooms(host_id, created_at desc);

create index if not exists meeting_rooms_code_idx
  on public.meeting_rooms(room_code);

alter table public.friend_requests enable row level security;
alter table public.shared_posts enable row level security;
alter table public.meeting_rooms enable row level security;
alter table public.notifications enable row level security;
alter table public.users enable row level security;
alter table public.posts enable row level security;

drop policy if exists friend_requests_select_participants on public.friend_requests;
create policy friend_requests_select_participants on public.friend_requests
for select to authenticated
using (sender_id = auth.uid() or receiver_id = auth.uid());

drop policy if exists friend_requests_insert_sender on public.friend_requests;
create policy friend_requests_insert_sender on public.friend_requests
for insert to authenticated
with check (sender_id = auth.uid() and receiver_id <> auth.uid());

drop policy if exists friend_requests_receiver_update on public.friend_requests;
create policy friend_requests_receiver_update on public.friend_requests
for update to authenticated
using (receiver_id = auth.uid())
with check (receiver_id = auth.uid() and status in ('accepted','rejected'));

drop policy if exists friend_requests_sender_cancel on public.friend_requests;
create policy friend_requests_sender_cancel on public.friend_requests
for update to authenticated
using (sender_id = auth.uid())
with check (sender_id = auth.uid() and status = 'cancelled');

drop policy if exists shared_posts_select_visible on public.shared_posts;
create policy shared_posts_select_visible on public.shared_posts
for select to authenticated
using (
  shared_by = auth.uid()
  or exists (
    select 1
    from public.posts p
    join public.users u on u.id = p.user_id
    where p.id = shared_posts.post_id
      and (
        p.user_id = auth.uid()
        or (
          u.account_privacy = 'public'
          and (
            p.audience = 'public'
            or (p.audience = 'friends' and public.is_colleague(auth.uid(), p.user_id))
          )
        )
        or (
          u.account_privacy = 'colleagues'
          and public.is_colleague(auth.uid(), p.user_id)
          and p.audience in ('public','friends')
        )
      )
  )
);

drop policy if exists shared_posts_insert_self on public.shared_posts;
create policy shared_posts_insert_self on public.shared_posts
for insert to authenticated
with check (shared_by = auth.uid());

drop policy if exists shared_posts_delete_self on public.shared_posts;
create policy shared_posts_delete_self on public.shared_posts
for delete to authenticated
using (shared_by = auth.uid());

drop policy if exists meeting_rooms_select_active on public.meeting_rooms;
create policy meeting_rooms_select_active on public.meeting_rooms
for select to authenticated
using (is_active = true or host_id = auth.uid());

drop policy if exists meeting_rooms_insert_host on public.meeting_rooms;
create policy meeting_rooms_insert_host on public.meeting_rooms
for insert to authenticated
with check (host_id = auth.uid());

drop policy if exists meeting_rooms_update_host on public.meeting_rooms;
create policy meeting_rooms_update_host on public.meeting_rooms
for update to authenticated
using (host_id = auth.uid())
with check (host_id = auth.uid());

drop policy if exists users_select_privacy_v136 on public.users;
create policy users_select_privacy_v136 on public.users
for select to authenticated
using (
  id = auth.uid()
  or account_privacy = 'public'
  or public.is_colleague(auth.uid(), id)
);

drop policy if exists posts_select_privacy_v136 on public.posts;
create policy posts_select_privacy_v136 on public.posts
for select to authenticated
using (
  user_id = auth.uid()
  or (
    exists (
      select 1 from public.users u
      where u.id = posts.user_id
        and (
          u.account_privacy = 'public'
          or public.is_colleague(auth.uid(), u.id)
        )
    )
    and (
      audience = 'public'
      or (audience = 'friends' and public.is_colleague(auth.uid(), user_id))
    )
  )
);

commit;
