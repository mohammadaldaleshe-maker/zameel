-- Zameel core database bootstrap
-- Run this in Supabase SQL Editor for a fresh project.
-- This migration intentionally contains only the foundation required by the
-- current Flutter client; later phases can extend it without replacing it.

create extension if not exists pgcrypto;

create table if not exists public.users (
  id uuid primary key references auth.users(id) on delete cascade,
  email text,
  name text not null default 'مستخدم',
  university text not null default '',
  college text not null default '',
  department text not null default '',
  profile_image text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  role text not null default 'student' check (role in ('student','faculty','graduate','company','visitor','staff','admin'))
);

-- Compatibility for an existing Zameel users table.
alter table public.users add column if not exists email text;
alter table public.users add column if not exists name text not null default 'مستخدم';
alter table public.users add column if not exists university text not null default '';
alter table public.users add column if not exists college text not null default '';
alter table public.users add column if not exists department text not null default '';
alter table public.users add column if not exists profile_image text;
alter table public.users add column if not exists created_at timestamptz not null default now();
alter table public.users add column if not exists updated_at timestamptz not null default now();
alter table public.users add column if not exists role text not null default 'student';

create table if not exists public.posts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  type text not null default 'text' check (type in ('text','image','video','academic','question')),
  text_ar text not null default '',
  text_en text not null default '',
  image_url text,
  video_url text,
  likes_count integer not null default 0 check (likes_count >= 0),
  comments_count integer not null default 0 check (comments_count >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.likes (
  user_id uuid not null references public.users(id) on delete cascade,
  post_id uuid not null references public.posts(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, post_id)
);

create table if not exists public.saved_posts (
  user_id uuid not null references public.users(id) on delete cascade,
  post_id uuid not null references public.posts(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, post_id)
);

create index if not exists posts_created_at_idx on public.posts(created_at desc);
create index if not exists posts_user_id_created_at_idx on public.posts(user_id, created_at desc);
create index if not exists likes_post_id_idx on public.likes(post_id);
create index if not exists saved_posts_user_id_idx on public.saved_posts(user_id);

-- Keep updated_at current without relying on the client.
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists users_set_updated_at on public.users;
create trigger users_set_updated_at
before update on public.users
for each row execute function public.set_updated_at();

drop trigger if exists posts_set_updated_at on public.posts;
create trigger posts_set_updated_at
before update on public.posts
for each row execute function public.set_updated_at();

-- Automatically create the public user row after Supabase Auth signup.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.users (id, email, name)
  values (
    new.id,
    new.email,
    coalesce(new.raw_user_meta_data->>'name', 'مستخدم')
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute procedure public.handle_new_user();


-- Account deletion endpoint required for a production account-based app.
-- The function deletes the authenticated user's Auth record; public.user data
-- is removed through the foreign-key cascade.
create or replace function public.delete_my_account()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'not_authenticated';
  end if;
  delete from auth.users where id = auth.uid();
end;
$$;

grant execute on function public.delete_my_account() to authenticated;

-- Row Level Security: users may read public profiles, edit only themselves.
alter table public.users enable row level security;
alter table public.posts enable row level security;
alter table public.likes enable row level security;
alter table public.saved_posts enable row level security;

drop policy if exists users_select_authenticated on public.users;
create policy users_select_authenticated
on public.users for select
to authenticated using (true);

drop policy if exists users_insert_self on public.users;
create policy users_insert_self
on public.users for insert
to authenticated with check (id = auth.uid());

drop policy if exists users_update_self on public.users;
create policy users_update_self
on public.users for update
to authenticated using (id = auth.uid()) with check (id = auth.uid());

drop policy if exists posts_select_authenticated on public.posts;
create policy posts_select_authenticated
on public.posts for select
to authenticated using (true);

drop policy if exists posts_insert_self on public.posts;
create policy posts_insert_self
on public.posts for insert
to authenticated with check (user_id = auth.uid());

drop policy if exists posts_update_owner on public.posts;
create policy posts_update_owner
on public.posts for update
to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

drop policy if exists posts_delete_owner on public.posts;
create policy posts_delete_owner
on public.posts for delete
to authenticated using (user_id = auth.uid());

drop policy if exists likes_select_authenticated on public.likes;
create policy likes_select_authenticated
on public.likes for select
to authenticated using (true);

drop policy if exists likes_insert_self on public.likes;
create policy likes_insert_self
on public.likes for insert
to authenticated with check (user_id = auth.uid());

drop policy if exists likes_delete_self on public.likes;
create policy likes_delete_self
on public.likes for delete
to authenticated using (user_id = auth.uid());

drop policy if exists saved_posts_select_self on public.saved_posts;
create policy saved_posts_select_self
on public.saved_posts for select
to authenticated using (user_id = auth.uid());

drop policy if exists saved_posts_insert_self on public.saved_posts;
create policy saved_posts_insert_self
on public.saved_posts for insert
to authenticated with check (user_id = auth.uid());

drop policy if exists saved_posts_delete_self on public.saved_posts;
create policy saved_posts_delete_self
on public.saved_posts for delete
to authenticated using (user_id = auth.uid());

-- Storage buckets used by the current client.
insert into storage.buckets (id, name, public)
values ('profiles', 'profiles', true)
on conflict (id) do nothing;

insert into storage.buckets (id, name, public)
values ('posts', 'posts', true)
on conflict (id) do nothing;

-- Public read for current MVP media. Upload/update/delete remain owner-scoped.
drop policy if exists profiles_public_read on storage.objects;
create policy profiles_public_read
on storage.objects for select
to public using (bucket_id = 'profiles');

drop policy if exists profiles_owner_insert on storage.objects;
create policy profiles_owner_insert
on storage.objects for insert
to authenticated with check (bucket_id = 'profiles' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists profiles_owner_update on storage.objects;
create policy profiles_owner_update
on storage.objects for update
to authenticated using (bucket_id = 'profiles' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists profiles_owner_delete on storage.objects;
create policy profiles_owner_delete
on storage.objects for delete
to authenticated using (bucket_id = 'profiles' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists posts_public_read on storage.objects;
create policy posts_public_read
on storage.objects for select
to public using (bucket_id = 'posts');

drop policy if exists posts_owner_insert on storage.objects;
create policy posts_owner_insert
on storage.objects for insert
to authenticated with check (bucket_id = 'posts' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists posts_owner_update on storage.objects;
create policy posts_owner_update
on storage.objects for update
to authenticated using (bucket_id = 'posts' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists posts_owner_delete on storage.objects;
create policy posts_owner_delete
on storage.objects for delete
to authenticated using (bucket_id = 'posts' and (storage.foldername(name))[1] = auth.uid()::text);
