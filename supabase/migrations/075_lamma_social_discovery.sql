-- Zameel 075: opt-in social discovery (Lamma + individual Insijam).
-- No user is discoverable until they explicitly enable the feature.

create extension if not exists pgcrypto;

create table if not exists public.social_discovery_profiles (
  user_id uuid primary key references public.users(id) on delete cascade,
  enabled boolean not null default false,
  intent text not null default 'friendship' check (intent in ('friendship','serious','both')),
  birth_date date,
  preferred_gender text not null default 'any' check (preferred_gender in ('any','male','female')),
  min_age smallint not null default 18 check (min_age between 18 and 80),
  max_age smallint not null default 35 check (max_age between 18 and 80 and max_age >= min_age),
  intro text not null default '' check (char_length(intro) <= 280),
  interests text[] not null default '{}',
  updated_at timestamptz not null default now(),
  check (birth_date is null or birth_date <= (current_date - interval '18 years')::date)
);

create table if not exists public.social_discovery_actions (
  actor_id uuid not null references public.users(id) on delete cascade,
  target_id uuid not null references public.users(id) on delete cascade,
  decision text not null check (decision in ('like','pass')),
  created_at timestamptz not null default now(),
  primary key (actor_id,target_id),
  check (actor_id <> target_id)
);

create table if not exists public.social_discovery_matches (
  id uuid primary key default gen_random_uuid(),
  user_low uuid not null references public.users(id) on delete cascade,
  user_high uuid not null references public.users(id) on delete cascade,
  status text not null default 'active' check (status in ('active','closed')),
  matched_at timestamptz not null default now(),
  unique(user_low,user_high),
  check (user_low <> user_high)
);

create table if not exists public.social_lammas (
  id uuid primary key default gen_random_uuid(),
  creator_id uuid not null references public.users(id) on delete cascade,
  title text not null check (char_length(title) between 3 and 80),
  vibe text not null check (vibe in ('coffee','walk','lunch','games','ideas','new_students','chill')),
  university text not null default '',
  college text not null default '',
  starts_at timestamptz not null default (now() + interval '30 minutes'),
  expires_at timestamptz not null default (now() + interval '3 hours'),
  max_members smallint not null default 6 check (max_members between 3 and 8),
  status text not null default 'open' check (status in ('open','full','ended')),
  created_at timestamptz not null default now()
);

create table if not exists public.social_lamma_members (
  lamma_id uuid not null references public.social_lammas(id) on delete cascade,
  user_id uuid not null references public.users(id) on delete cascade,
  joined_at timestamptz not null default now(),
  primary key (lamma_id,user_id)
);

alter table public.social_discovery_profiles enable row level security;
alter table public.social_discovery_actions enable row level security;
alter table public.social_discovery_matches enable row level security;
alter table public.social_lammas enable row level security;
alter table public.social_lamma_members enable row level security;

drop policy if exists social_profile_self on public.social_discovery_profiles;
create policy social_profile_self on public.social_discovery_profiles
for all to authenticated using (user_id=auth.uid()) with check (user_id=auth.uid());

-- There is intentionally no policy that lets another user SELECT this table.
-- Candidate cards are exposed only through the narrow SECURITY DEFINER RPC,
-- and only to adults who explicitly enabled Insijam themselves. This keeps
-- enabled state, birth date, preferences and rejected/liked people private.

drop policy if exists social_actions_self on public.social_discovery_actions;
create policy social_actions_self on public.social_discovery_actions
for all to authenticated using (actor_id=auth.uid()) with check (actor_id=auth.uid());

drop policy if exists social_matches_members on public.social_discovery_matches;
create policy social_matches_members on public.social_discovery_matches
for select to authenticated using (auth.uid() in (user_low,user_high));

drop policy if exists social_lammas_same_university on public.social_lammas;
create policy social_lammas_same_university on public.social_lammas
for select to authenticated using (
  status in ('open','full') and expires_at>now() and exists (
    select 1 from public.users me where me.id=auth.uid()
      and (coalesce(social_lammas.university,'')='' or me.university=social_lammas.university)
  )
);
drop policy if exists social_lammas_create on public.social_lammas;
create policy social_lammas_create on public.social_lammas
for insert to authenticated with check (creator_id=auth.uid());
drop policy if exists social_lammas_owner_update on public.social_lammas;
create policy social_lammas_owner_update on public.social_lammas
for update to authenticated using (creator_id=auth.uid()) with check (creator_id=auth.uid());

drop policy if exists social_lamma_members_visible on public.social_lamma_members;
create policy social_lamma_members_visible on public.social_lamma_members
for select to authenticated using (
  exists(select 1 from public.social_lammas l where l.id=social_lamma_members.lamma_id and l.status in ('open','full') and l.expires_at>now())
);

create or replace function public.get_social_discovery_candidates(p_limit int default 20)
returns table(user_id uuid,name text,profile_image text,university text,college text,department text,gender text,age int,intent text,intro text,interests text[])
language sql security definer set search_path=public stable as $$
  with me as (
    select p.*,u.gender my_gender,u.university my_university
    from social_discovery_profiles p join users u on u.id=p.user_id
    where p.user_id=auth.uid() and p.enabled and p.birth_date <= (current_date-interval '18 years')::date
  )
  select u.id,u.name,u.profile_image,u.university,u.college,u.department,u.gender,
    extract(year from age(current_date,p.birth_date))::int,p.intent,p.intro,p.interests
  from social_discovery_profiles p join users u on u.id=p.user_id cross join me
  where p.enabled and p.user_id<>auth.uid() and p.birth_date <= (current_date-interval '18 years')::date
    and u.university=me.my_university
    and extract(year from age(current_date,p.birth_date)) between me.min_age and me.max_age
    and extract(year from age(current_date,me.birth_date)) between p.min_age and p.max_age
    and (me.preferred_gender='any' or lower(coalesce(u.gender,''))=me.preferred_gender)
    and (p.preferred_gender='any' or lower(coalesce(me.my_gender,''))=p.preferred_gender)
    and not exists(select 1 from social_discovery_actions a where a.actor_id=auth.uid() and a.target_id=p.user_id)
    and not exists(select 1 from user_blocks b where (b.blocker_id=auth.uid() and b.blocked_id=p.user_id) or (b.blocker_id=p.user_id and b.blocked_id=auth.uid()))
  order by cardinality(array(select unnest(p.interests) intersect select unnest(me.interests))) desc,p.updated_at desc
  limit least(greatest(p_limit,1),50)
$$;

create or replace function public.react_social_discovery(p_target uuid,p_decision text)
returns boolean language plpgsql security definer set search_path=public as $$
declare matched boolean:=false; lo uuid; hi uuid;
begin
  if auth.uid() is null or p_target=auth.uid() or p_decision not in ('like','pass') then raise exception 'invalid_reaction'; end if;
  if not exists(select 1 from social_discovery_profiles where user_id=auth.uid() and enabled) then raise exception 'discovery_not_enabled'; end if;
  insert into social_discovery_actions(actor_id,target_id,decision) values(auth.uid(),p_target,p_decision)
  on conflict(actor_id,target_id) do update set decision=excluded.decision,created_at=now();
  if p_decision='like' and exists(select 1 from social_discovery_actions where actor_id=p_target and target_id=auth.uid() and decision='like') then
    lo:=least(auth.uid(),p_target); hi:=greatest(auth.uid(),p_target);
    insert into social_discovery_matches(user_low,user_high) values(lo,hi) on conflict(user_low,user_high) do update set status='active';
    matched:=true;
  end if;
  return matched;
end $$;

create or replace function public.get_my_social_matches()
returns table(user_id uuid,name text,profile_image text,department text,matched_at timestamptz)
language sql security definer set search_path=public stable as $$
  select u.id,u.name,u.profile_image,u.department,m.matched_at
  from social_discovery_matches m
  join users u on u.id=case when m.user_low=auth.uid() then m.user_high else m.user_low end
  where m.status='active' and auth.uid() in (m.user_low,m.user_high)
  order by m.matched_at desc
$$;

create or replace function public.join_social_lamma(p_lamma uuid)
returns boolean language plpgsql security definer set search_path=public as $$
declare cap int; joined int;
begin
  select max_members into cap from social_lammas where id=p_lamma and status='open' and expires_at>now() for update;
  if cap is null then return false; end if;
  select count(*) into joined from social_lamma_members where lamma_id=p_lamma;
  if joined>=cap then update social_lammas set status='full' where id=p_lamma; return false; end if;
  insert into social_lamma_members(lamma_id,user_id) values(p_lamma,auth.uid()) on conflict do nothing;
  select count(*) into joined from social_lamma_members where lamma_id=p_lamma;
  if joined>=cap then update social_lammas set status='full' where id=p_lamma; end if;
  return true;
end $$;

revoke all on function public.get_social_discovery_candidates(int) from public,anon;
revoke all on function public.react_social_discovery(uuid,text) from public,anon;
revoke all on function public.get_my_social_matches() from public,anon;
revoke all on function public.join_social_lamma(uuid) from public,anon;
grant execute on function public.get_social_discovery_candidates(int) to authenticated;
grant execute on function public.react_social_discovery(uuid,text) to authenticated;
grant execute on function public.get_my_social_matches() to authenticated;
grant execute on function public.join_social_lamma(uuid) to authenticated;
