-- Zameel 076: verified student registration, Radio Zameel and Beautiful College.
-- Existing social tables are intentionally not altered.

create extension if not exists pgcrypto;

create table if not exists public.zameel_registration_profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  first_name text not null check (char_length(trim(first_name)) between 2 and 40),
  father_name text not null check (char_length(trim(father_name)) between 2 and 40),
  family_name text not null check (char_length(trim(family_name)) between 2 and 60),
  display_name_format text not null check (display_name_format in ('first_father','first_family','full_three')),
  phone text not null,
  email text not null,
  verification_method text not null check (verification_method in ('email','phone')),
  email_verified boolean not null default false,
  phone_verified boolean not null default false,
  university text not null check (char_length(trim(university)) >= 2),
  college text not null check (char_length(trim(college)) >= 2),
  major text not null check (char_length(trim(major)) >= 2),
  academic_year text not null check (academic_year in ('first','second','third','fourth','fifth','sixth','graduate')),
  gender text not null check (gender in ('male','female')),
  onboarding_complete boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint registration_one_verified_channel check (email_verified or phone_verified)
);

create unique index if not exists zameel_registration_email_unique
  on public.zameel_registration_profiles (lower(email));
create unique index if not exists zameel_registration_phone_unique
  on public.zameel_registration_profiles (regexp_replace(phone, '[^0-9+]', '', 'g'));

alter table public.zameel_registration_profiles enable row level security;
drop policy if exists registration_owner_read on public.zameel_registration_profiles;
create policy registration_owner_read on public.zameel_registration_profiles
  for select using (auth.uid() = user_id);
drop policy if exists registration_owner_insert on public.zameel_registration_profiles;
create policy registration_owner_insert on public.zameel_registration_profiles
  for insert with check (auth.uid() = user_id);
drop policy if exists registration_owner_update on public.zameel_registration_profiles;
create policy registration_owner_update on public.zameel_registration_profiles
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);

alter table public.users add column if not exists academic_year text;
alter table public.users add column if not exists display_name_format text default 'first_family';
alter table public.users add column if not exists onboarding_complete boolean not null default false;

-- Preserve every established account. Only accounts created through the new
-- flow are required to produce a private registration row before completion.
update public.users
set onboarding_complete = true
where coalesce(trim(university),'') <> ''
  and coalesce(trim(college),'') <> ''
  and coalesce(trim(department),'') <> '';

create or replace function public.zameel_enforce_completed_registration()
returns trigger language plpgsql security definer set search_path=public as $$
begin
  if new.onboarding_complete and not old.onboarding_complete
     and not exists (select 1 from public.zameel_registration_profiles p where p.user_id=new.id) then
    raise exception 'verified registration profile required';
  end if;
  return new;
end;
$$;
drop trigger if exists zameel_users_require_registration on public.users;
create trigger zameel_users_require_registration before update of onboarding_complete on public.users
for each row execute function public.zameel_enforce_completed_registration();

create or replace function public.zameel_jordan_cycle_day(p_at timestamptz default now())
returns date language sql stable as $$
  select case
    when (p_at at time zone 'Asia/Amman')::time < time '07:00'
      then (p_at at time zone 'Asia/Amman')::date - 1
    else (p_at at time zone 'Asia/Amman')::date
  end;
$$;

create table if not exists public.zameel_radio_posts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  storage_path text not null unique,
  duration_seconds integer not null check (duration_seconds between 1 and 120),
  is_anonymous boolean not null default false,
  cycle_day date not null default public.zameel_jordan_cycle_day(),
  expires_at timestamptz not null,
  is_hidden boolean not null default false,
  created_at timestamptz not null default now()
);

create table if not exists public.zameel_radio_reports (
  post_id uuid not null references public.zameel_radio_posts(id) on delete cascade,
  reporter_id uuid not null references public.users(id) on delete cascade,
  reason text not null check (char_length(trim(reason)) between 2 and 300),
  created_at timestamptz not null default now(),
  primary key (post_id, reporter_id)
);

create table if not exists public.zameel_radio_mutes (
  owner_id uuid not null references public.users(id) on delete cascade,
  muted_user_id uuid not null references public.users(id) on delete cascade,
  muted_until timestamptz not null default (now() + interval '7 days'),
  created_at timestamptz not null default now(),
  primary key (owner_id, muted_user_id),
  check (owner_id <> muted_user_id)
);

create or replace function public.zameel_hide_radio_after_reports()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if (select count(*) from public.zameel_radio_reports where post_id = new.post_id) >= 2 then
    update public.zameel_radio_posts set is_hidden = true where id = new.post_id;
  end if;
  return new;
end;
$$;
drop trigger if exists zameel_radio_two_reports on public.zameel_radio_reports;
create trigger zameel_radio_two_reports after insert on public.zameel_radio_reports
for each row execute function public.zameel_hide_radio_after_reports();

alter table public.zameel_radio_posts enable row level security;
alter table public.zameel_radio_reports enable row level security;
alter table public.zameel_radio_mutes enable row level security;
drop policy if exists radio_current_read on public.zameel_radio_posts;
create policy radio_current_read on public.zameel_radio_posts for select using (
  auth.uid() is not null and not is_hidden and expires_at > now()
  and not exists (select 1 from public.zameel_radio_mutes m
    where m.owner_id = auth.uid() and m.muted_user_id = user_id and m.muted_until > now())
);
drop policy if exists radio_owner_insert on public.zameel_radio_posts;
create policy radio_owner_insert on public.zameel_radio_posts for insert with check (auth.uid() = user_id);
drop policy if exists radio_owner_delete on public.zameel_radio_posts;
create policy radio_owner_delete on public.zameel_radio_posts for delete using (auth.uid() = user_id);
drop policy if exists radio_report_insert on public.zameel_radio_reports;
create policy radio_report_insert on public.zameel_radio_reports for insert with check (auth.uid() = reporter_id);
drop policy if exists radio_report_own_read on public.zameel_radio_reports;
create policy radio_report_own_read on public.zameel_radio_reports for select using (auth.uid() = reporter_id);
drop policy if exists radio_mute_owner_all on public.zameel_radio_mutes;
create policy radio_mute_owner_all on public.zameel_radio_mutes for all
  using (auth.uid() = owner_id) with check (auth.uid() = owner_id);

create or replace function public.zameel_radio_feed()
returns table(
  id uuid,
  storage_path text,
  duration_seconds integer,
  is_anonymous boolean,
  created_at timestamptz,
  author_name text,
  author_image text
) language sql stable security definer set search_path=public as $$
  select p.id, p.storage_path, p.duration_seconds, p.is_anonymous, p.created_at,
         case when p.is_anonymous then null else u.name end,
         case when p.is_anonymous then null else u.profile_image end
  from public.zameel_radio_posts p
  join public.users u on u.id=p.user_id
  where auth.uid() is not null and not p.is_hidden and p.expires_at > now()
    and not exists (
      select 1 from public.zameel_radio_mutes m
      where m.owner_id=auth.uid() and m.muted_user_id=p.user_id and m.muted_until > now()
    )
  order by p.created_at desc;
$$;

create or replace function public.zameel_mute_radio_author(p_post_id uuid)
returns void language plpgsql security definer set search_path=public as $$
declare v_author uuid;
begin
  select user_id into v_author from public.zameel_radio_posts where id=p_post_id;
  if auth.uid() is null or v_author is null or v_author=auth.uid() then return; end if;
  insert into public.zameel_radio_mutes(owner_id,muted_user_id,muted_until)
  values(auth.uid(),v_author,now()+interval '7 days')
  on conflict(owner_id,muted_user_id) do update set muted_until=excluded.muted_until;
end;
$$;

create table if not exists public.zameel_college_entries (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  image_path text not null unique,
  caption text not null default '' check (char_length(caption) <= 240),
  university text not null,
  place_name text not null check (char_length(trim(place_name)) between 2 and 100),
  cycle_day date not null default public.zameel_jordan_cycle_day(),
  like_count integer not null default 0 check (like_count >= 0),
  is_hidden boolean not null default false,
  created_at timestamptz not null default now(),
  unique (user_id, cycle_day)
);

create table if not exists public.zameel_college_likes (
  entry_id uuid not null references public.zameel_college_entries(id) on delete cascade,
  user_id uuid not null references public.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (entry_id, user_id)
);

create table if not exists public.zameel_college_reports (
  entry_id uuid not null references public.zameel_college_entries(id) on delete cascade,
  reporter_id uuid not null references public.users(id) on delete cascade,
  reason text not null check (char_length(trim(reason)) between 2 and 300),
  created_at timestamptz not null default now(),
  primary key (entry_id, reporter_id)
);

create table if not exists public.zameel_college_winners (
  cycle_day date primary key,
  entry_id uuid not null references public.zameel_college_entries(id) on delete cascade,
  selected_at timestamptz not null default now()
);

create or replace function public.zameel_toggle_college_like(p_entry_id uuid)
returns boolean language plpgsql security definer set search_path = public as $$
declare v_liked boolean;
begin
  if auth.uid() is null then raise exception 'authentication required'; end if;
  if exists (select 1 from zameel_college_likes where entry_id=p_entry_id and user_id=auth.uid()) then
    delete from zameel_college_likes where entry_id=p_entry_id and user_id=auth.uid();
    v_liked := false;
  else
    insert into zameel_college_likes(entry_id,user_id) values(p_entry_id,auth.uid());
    v_liked := true;
  end if;
  update zameel_college_entries set like_count=(select count(*) from zameel_college_likes where entry_id=p_entry_id)
    where id=p_entry_id;
  return v_liked;
end;
$$;

create or replace function public.zameel_hide_college_after_reports()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if (select count(*) from zameel_college_reports where entry_id = new.entry_id) >= 2 then
    update zameel_college_entries set is_hidden = true where id = new.entry_id;
  end if;
  return new;
end;
$$;
drop trigger if exists zameel_college_two_reports on public.zameel_college_reports;
create trigger zameel_college_two_reports after insert on public.zameel_college_reports
for each row execute function public.zameel_hide_college_after_reports();

create or replace function public.zameel_select_college_winner(p_cycle date default public.zameel_jordan_cycle_day())
returns uuid language plpgsql security definer set search_path=public as $$
declare v_entry uuid;
begin
  if p_cycle = public.zameel_jordan_cycle_day()
     and (now() at time zone 'Asia/Amman')::time < time '20:00' then
    raise exception 'winner selection opens at 20:00 Asia/Amman';
  end if;
  select id into v_entry from zameel_college_entries
   where cycle_day=p_cycle and not is_hidden
   order by like_count desc, created_at asc limit 1;
  if v_entry is not null then
    insert into zameel_college_winners(cycle_day,entry_id) values(p_cycle,v_entry)
    on conflict(cycle_day) do update set entry_id=excluded.entry_id, selected_at=now();
  end if;
  return v_entry;
end;
$$;

alter table public.zameel_college_entries enable row level security;
alter table public.zameel_college_likes enable row level security;
alter table public.zameel_college_reports enable row level security;
alter table public.zameel_college_winners enable row level security;
drop policy if exists college_entry_read on public.zameel_college_entries;
create policy college_entry_read on public.zameel_college_entries for select using (auth.uid() is not null and not is_hidden);
drop policy if exists college_entry_insert on public.zameel_college_entries;
create policy college_entry_insert on public.zameel_college_entries for insert with check (
  auth.uid()=user_id
  and (now() at time zone 'Asia/Amman')::time >= time '07:00'
  and (now() at time zone 'Asia/Amman')::time < time '20:00'
);
drop policy if exists college_entry_owner_delete on public.zameel_college_entries;
create policy college_entry_owner_delete on public.zameel_college_entries for delete using (auth.uid()=user_id);
drop policy if exists college_like_read on public.zameel_college_likes;
create policy college_like_read on public.zameel_college_likes for select using (auth.uid() is not null);
drop policy if exists college_report_insert on public.zameel_college_reports;
create policy college_report_insert on public.zameel_college_reports for insert with check (auth.uid()=reporter_id);
drop policy if exists college_winner_read on public.zameel_college_winners;
create policy college_winner_read on public.zameel_college_winners for select using (auth.uid() is not null);

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values ('zameel-radio','zameel-radio',false,12582912,array['audio/aac','audio/mp4','audio/m4a'])
on conflict(id) do update set public=false, file_size_limit=excluded.file_size_limit, allowed_mime_types=excluded.allowed_mime_types;
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values ('beautiful-college','beautiful-college',true,10485760,array['image/jpeg','image/png','image/webp'])
on conflict(id) do update set public=true, file_size_limit=excluded.file_size_limit, allowed_mime_types=excluded.allowed_mime_types;

drop policy if exists radio_storage_owner_insert on storage.objects;
create policy radio_storage_owner_insert on storage.objects for insert to authenticated
with check (bucket_id='zameel-radio' and owner_id=auth.uid()::text);
drop policy if exists radio_storage_read on storage.objects;
create policy radio_storage_read on storage.objects for select to authenticated using (bucket_id='zameel-radio');
drop policy if exists radio_storage_owner_delete on storage.objects;
create policy radio_storage_owner_delete on storage.objects for delete to authenticated
using (bucket_id='zameel-radio' and owner_id=auth.uid()::text);
drop policy if exists college_storage_owner_insert on storage.objects;
create policy college_storage_owner_insert on storage.objects for insert to authenticated
with check (bucket_id='beautiful-college' and (storage.foldername(name))[1]=auth.uid()::text);
drop policy if exists college_storage_public_read on storage.objects;
create policy college_storage_public_read on storage.objects for select using (bucket_id='beautiful-college');
drop policy if exists college_storage_owner_delete on storage.objects;
create policy college_storage_owner_delete on storage.objects for delete to authenticated
using (bucket_id='beautiful-college' and owner_id=auth.uid()::text);

grant execute on function public.zameel_toggle_college_like(uuid) to authenticated;
grant execute on function public.zameel_select_college_winner(date) to authenticated;
grant execute on function public.zameel_radio_feed() to authenticated;
grant execute on function public.zameel_mute_radio_author(uuid) to authenticated;
revoke select on public.zameel_radio_posts from authenticated;
