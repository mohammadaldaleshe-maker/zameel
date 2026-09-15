-- Zameel 040: gamified campus worlds and moderated partner places.
-- Run after migration 039.

begin;

create table if not exists public.university_campuses (
  id uuid primary key default gen_random_uuid(),
  name_ar text not null unique,
  name_en text not null default '',
  center_latitude double precision not null check (center_latitude between -90 and 90),
  center_longitude double precision not null check (center_longitude between -180 and 180),
  campus_radius_meters integer not null check (campus_radius_meters between 100 and 10000),
  outer_ring_meters integer not null default 3000 check (outer_ring_meters = 3000),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

insert into public.university_campuses
  (name_ar,name_en,center_latitude,center_longitude,campus_radius_meters)
values
  ('الجامعة الأردنية','The University of Jordan',32.0138,35.8720,1100),
  ('جامعة العلوم والتكنولوجيا الأردنية','Jordan University of Science and Technology',32.4950,35.9912,1700)
on conflict (name_ar) do update set
  name_en=excluded.name_en,
  center_latitude=excluded.center_latitude,
  center_longitude=excluded.center_longitude,
  campus_radius_meters=excluded.campus_radius_meters,
  outer_ring_meters=3000,
  updated_at=now();

create table if not exists public.campus_partner_places (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.users(id) on delete cascade,
  university_name text not null references public.university_campuses(name_ar) on update cascade,
  name_ar text not null check (char_length(trim(name_ar)) between 2 and 120),
  name_en text not null default '',
  category text not null default 'student_service',
  description text not null default '',
  latitude double precision not null check (latitude between -90 and 90),
  longitude double precision not null check (longitude between -180 and 180),
  status text not null default 'pending' check (status in ('pending','approved','rejected','suspended')),
  reviewed_by uuid references public.users(id) on delete set null,
  reviewed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists campus_partner_places_university_status_idx
  on public.campus_partner_places(university_name,status);
create index if not exists campus_partner_places_owner_idx
  on public.campus_partner_places(owner_id,created_at desc);

create or replace function public.zameel_distance_meters(
  lat1 double precision,lng1 double precision,
  lat2 double precision,lng2 double precision
) returns double precision
language sql immutable parallel safe
as $$
  select 6371000 * 2 * asin(sqrt(
    power(sin(radians(lat2-lat1)/2),2) +
    cos(radians(lat1))*cos(radians(lat2))*power(sin(radians(lng2-lng1)/2),2)
  ));
$$;

create or replace function public.validate_campus_partner_place()
returns trigger language plpgsql security definer set search_path=public as $$
declare c public.university_campuses; account_role text;
begin
  select * into c from public.university_campuses
  where name_ar=new.university_name and is_active=true;
  if c.id is null then raise exception 'unknown_or_inactive_campus'; end if;

  select role into account_role from public.users where id=new.owner_id;
  if account_role <> 'company' then raise exception 'partner_account_required'; end if;

  if public.zameel_distance_meters(
      c.center_latitude,c.center_longitude,new.latitude,new.longitude
    ) > c.campus_radius_meters + c.outer_ring_meters then
    raise exception 'place_outside_campus_world';
  end if;

  if tg_op='INSERT' then new.status='pending'; end if;
  new.updated_at=now();
  return new;
end;
$$;

drop trigger if exists validate_campus_partner_place_trigger
  on public.campus_partner_places;
create trigger validate_campus_partner_place_trigger
before insert or update of university_name,latitude,longitude,owner_id
on public.campus_partner_places
for each row execute function public.validate_campus_partner_place();

alter table public.university_campuses enable row level security;
alter table public.campus_partner_places enable row level security;

drop policy if exists university_campuses_read on public.university_campuses;
create policy university_campuses_read on public.university_campuses
for select to authenticated using (is_active=true);

drop policy if exists campus_partner_places_read on public.campus_partner_places;
create policy campus_partner_places_read on public.campus_partner_places
for select to authenticated using (status='approved' or owner_id=auth.uid());

drop policy if exists campus_partner_places_insert on public.campus_partner_places;
create policy campus_partner_places_insert on public.campus_partner_places
for insert to authenticated with check (
  owner_id=auth.uid() and exists (
    select 1 from public.users u where u.id=auth.uid() and u.role='company'
  )
);

drop policy if exists campus_partner_places_owner_update on public.campus_partner_places;
create policy campus_partner_places_owner_update on public.campus_partner_places
for update to authenticated using (owner_id=auth.uid() and status in ('pending','rejected'))
with check (owner_id=auth.uid() and status='pending');

drop policy if exists campus_partner_places_admin_update on public.campus_partner_places;
create policy campus_partner_places_admin_update on public.campus_partner_places
for update to authenticated using (
  exists (select 1 from public.users u where u.id=auth.uid() and u.role='admin')
) with check (
  exists (select 1 from public.users u where u.id=auth.uid() and u.role='admin')
);

drop policy if exists campus_partner_places_owner_delete on public.campus_partner_places;
create policy campus_partner_places_owner_delete on public.campus_partner_places
for delete to authenticated using (
  owner_id=auth.uid() and status in ('pending','rejected')
);

revoke all on function public.zameel_distance_meters(double precision,double precision,double precision,double precision) from public,anon;
grant execute on function public.zameel_distance_meters(double precision,double precision,double precision,double precision) to authenticated;

commit;
