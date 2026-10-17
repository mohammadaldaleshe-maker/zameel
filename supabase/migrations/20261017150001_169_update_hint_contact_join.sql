-- 169: (a) release policy also reports the newest approved build so the app can
--          show a soft "update available" banner (hard blocking is unchanged);
--      (b) "someone from your contacts joined Zameel" notification.
-- Additive and idempotent.

create or replace function public.zameel_release_policy(p_platform text,p_build integer)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare latest public.app_releases; current_release public.app_releases; begin
 if p_platform not in ('android','ios','web') or p_build<1 then raise exception 'invalid_release';end if;
 select * into latest from public.app_releases where platform=p_platform and is_allowed and is_active
 and download_url like 'https://%' order by build_number desc nulls last limit 1;
 if latest.id is null then return jsonb_build_object('allowed',true);end if;
 select * into current_release from public.app_releases where platform=p_platform and build_number=p_build order by created_at desc limit 1;
 return jsonb_build_object('allowed',case when current_release.id is not null then current_release.is_allowed
 else p_build>=coalesce(latest.build_number,0) end,'version_name',latest.version_name,'download_url',latest.download_url,
 'latest_build',latest.build_number);
end $$;
revoke all on function public.zameel_release_policy(text,integer) from public;
grant execute on function public.zameel_release_policy(text,integer) to anon,authenticated;

-- Hashes (SHA-256 of normalised phone numbers, the same hashes the app already
-- uses to find colleagues) of the people in a user's address book. No names, no
-- raw numbers. A user can only write their own list; nobody can read it directly.
create table if not exists public.user_contact_hashes165 (
  user_id uuid not null references public.users(id) on delete cascade,
  phone_hash text not null check (char_length(phone_hash)=64),
  primary key (user_id, phone_hash)
);
create index if not exists user_contact_hashes165_hash_idx on public.user_contact_hashes165(phone_hash);
alter table public.user_contact_hashes165 enable row level security;
revoke all on table public.user_contact_hashes165 from public, anon, authenticated;

-- People who prefer not to announce themselves to their contacts.
create table if not exists public.contact_join_optout165 (
  user_id uuid primary key references public.users(id) on delete cascade,
  created_at timestamptz not null default now()
);
alter table public.contact_join_optout165 enable row level security;
revoke all on table public.contact_join_optout165 from public, anon, authenticated;

create or replace function public.zameel_sync_contact_hashes165(p_hashes text[])
returns integer language plpgsql security definer set search_path='' as $$
declare cleaned text[]; saved int;
begin
  if auth.uid() is null then raise exception 'authentication_required'; end if;
  select coalesce(array_agg(distinct h),array[]::text[]) into cleaned
    from (select h from unnest(coalesce(p_hashes,array[]::text[])) h where h ~ '^[0-9a-f]{64}$' limit 2000) x;
  delete from public.user_contact_hashes165 where user_id=auth.uid() and not (phone_hash = any(cleaned));
  insert into public.user_contact_hashes165(user_id,phone_hash)
    select auth.uid(),h from unnest(cleaned) h on conflict do nothing;
  select count(*) into saved from public.user_contact_hashes165 where user_id=auth.uid();
  return saved;
end;
$$;

create or replace function public.zameel_set_contact_join_visible165(p_visible boolean)
returns boolean language plpgsql security definer set search_path='' as $$
begin
  if auth.uid() is null then raise exception 'authentication_required'; end if;
  if coalesce(p_visible,true) then
    delete from public.contact_join_optout165 where user_id=auth.uid();
  else
    insert into public.contact_join_optout165(user_id) values(auth.uid()) on conflict do nothing;
  end if;
  return coalesce(p_visible,true);
end;
$$;

create or replace function public.zameel_get_contact_join_visible165()
returns boolean language plpgsql security definer set search_path='' stable as $$
begin
  if auth.uid() is null then raise exception 'authentication_required'; end if;
  return not exists(select 1 from public.contact_join_optout165 where user_id=auth.uid());
end;
$$;

-- One notification per (holder of the number, new member). Fires when a user
-- first gets a phone hash (registration), never again for that user.
create unique index if not exists notifications_contact_joined_165_uidx
  on public.notifications (user_id, ((data->>'joined_user_id')))
  where type='contact_joined';

create or replace function public.zameel_notify_contacts_joined165()
returns trigger language plpgsql security definer set search_path='' as $$
declare display_name text;
begin
  if new.phone_hash is null then return new; end if;
  if tg_op='UPDATE' and old.phone_hash is not null then return new; end if;
  if exists(select 1 from public.contact_join_optout165 where user_id=new.id) then return new; end if;
  display_name:=coalesce(nullif(trim(new.name),''),'زميل');
  insert into public.notifications(user_id,actor_id,type,title_ar,title_en,body_ar,body_en,data,is_read)
  select c.user_id,new.id,'contact_joined',
    'انضم أحد معارفك إلى زميل 🎉','Someone you know joined Zameel 🎉',
    display_name||' من جهات اتصالك أصبح الآن على زميل. أضفه زميلاً لك!',
    display_name||' from your contacts is now on Zameel. Add them as your colleague!',
    jsonb_build_object('joined_user_id',new.id,'user_id',new.id),false
  from public.user_contact_hashes165 c
  where c.phone_hash=new.phone_hash and c.user_id<>new.id
    and not exists(select 1 from public.user_blocks b
      where (b.blocker_id=c.user_id and b.blocked_id=new.id) or (b.blocker_id=new.id and b.blocked_id=c.user_id))
  on conflict do nothing;
  return new;
end;
$$;
drop trigger if exists zameel_users_contact_joined_165 on public.users;
create trigger zameel_users_contact_joined_165
after insert or update of phone_hash on public.users
for each row execute function public.zameel_notify_contacts_joined165();

revoke all on function public.zameel_sync_contact_hashes165(text[]) from public, anon;
revoke all on function public.zameel_set_contact_join_visible165(boolean) from public, anon;
revoke all on function public.zameel_get_contact_join_visible165() from public, anon;
revoke all on function public.zameel_notify_contacts_joined165() from public, anon, authenticated;
grant execute on function public.zameel_sync_contact_hashes165(text[]) to authenticated;
grant execute on function public.zameel_set_contact_join_visible165(boolean) to authenticated;
grant execute on function public.zameel_get_contact_join_visible165() to authenticated;

notify pgrst, 'reload schema';
