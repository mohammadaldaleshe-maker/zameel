-- Zameel 043: verified real campus places managed by owner/staff.
-- Run after migration 042.
begin;

alter table public.campus_partner_places
  add column if not exists source text not null default 'zameel_verified',
  add column if not exists is_navigable boolean not null default true,
  add column if not exists verified_at timestamptz,
  add column if not exists verified_by uuid references public.users(id) on delete set null;

create or replace function public.can_manage_campus_places(user_id uuid default auth.uid())
returns boolean language sql stable security definer set search_path=public set row_security=off as $$
  select exists(select 1 from public.users
    where id=user_id and lower(coalesce(role,'')) in ('admin','owner','campus_manager'));
$$;

create or replace function public.validate_campus_partner_place()
returns trigger language plpgsql security definer set search_path=public as $$
declare c public.university_campuses; account_role text;
begin
  select * into c from public.university_campuses where name_ar=new.university_name and is_active=true;
  if c.id is null then raise exception 'unknown_or_inactive_campus'; end if;
  select lower(coalesce(role,'')) into account_role from public.users where id=new.owner_id;
  if account_role not in ('company','business','admin','owner','campus_manager') then raise exception 'place_manager_required'; end if;
  if public.zameel_distance_meters(c.center_latitude,c.center_longitude,new.latitude,new.longitude)
      > c.campus_radius_meters+c.outer_ring_meters then raise exception 'place_outside_campus_world'; end if;
  if account_role in ('admin','owner','campus_manager') and new.status='approved' then
    new.verified_by=auth.uid(); new.verified_at=now();
  elsif tg_op='INSERT' then new.status='pending'; end if;
  new.updated_at=now(); return new;
end; $$;

drop policy if exists campus_partner_places_admin_insert on public.campus_partner_places;
create policy campus_partner_places_admin_insert on public.campus_partner_places
for insert to authenticated with check (owner_id=auth.uid() and public.can_manage_campus_places());

drop policy if exists campus_partner_places_admin_update on public.campus_partner_places;
create policy campus_partner_places_admin_update on public.campus_partner_places
for update to authenticated using (public.can_manage_campus_places())
with check (public.can_manage_campus_places());

drop policy if exists campus_partner_places_admin_delete on public.campus_partner_places;
create policy campus_partner_places_admin_delete on public.campus_partner_places
for delete to authenticated using (public.can_manage_campus_places());

revoke execute on function public.can_manage_campus_places(uuid) from public,anon;
grant execute on function public.can_manage_campus_places(uuid) to authenticated;
commit;
