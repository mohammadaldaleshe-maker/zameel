-- Zameel 059: activate remaining production services without touching stable social/calls/library flows.
-- Adds durable calendar, community groups + group chat, polls, anonymous wall,
-- partner directory, and server-computed activity statistics.
begin;

create extension if not exists pgcrypto;

-- ---------------------------------------------------------------------------
-- Personal calendar
-- ---------------------------------------------------------------------------
create table if not exists public.calendar_events (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.users(id) on delete cascade,
  title text not null check (char_length(trim(title)) between 1 and 180),
  event_date date not null,
  event_time time,
  event_type text not null default 'event' check (event_type in ('lecture','exam','assignment','event','other')),
  notes text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists calendar_events_owner_date_idx on public.calendar_events(owner_id,event_date,event_time);
alter table public.calendar_events enable row level security;
drop policy if exists calendar_events_select_self on public.calendar_events;
create policy calendar_events_select_self on public.calendar_events for select to authenticated using (owner_id=auth.uid());
drop policy if exists calendar_events_insert_self on public.calendar_events;
create policy calendar_events_insert_self on public.calendar_events for insert to authenticated with check (owner_id=auth.uid());
drop policy if exists calendar_events_update_self on public.calendar_events;
create policy calendar_events_update_self on public.calendar_events for update to authenticated using (owner_id=auth.uid()) with check (owner_id=auth.uid());
drop policy if exists calendar_events_delete_self on public.calendar_events;
create policy calendar_events_delete_self on public.calendar_events for delete to authenticated using (owner_id=auth.uid());

-- ---------------------------------------------------------------------------
-- Community groups and real group chat
-- ---------------------------------------------------------------------------
create table if not exists public.community_groups (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.users(id) on delete cascade,
  name text not null check (char_length(trim(name)) between 1 and 120),
  description text not null default '',
  group_type text not null default 'interests' check (group_type in ('graduation_year','club','major','interests','study','other')),
  is_private boolean not null default false,
  university text not null default '',
  college text not null default '',
  department text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.community_group_members (
  group_id uuid not null references public.community_groups(id) on delete cascade,
  user_id uuid not null references public.users(id) on delete cascade,
  role text not null default 'member' check (role in ('owner','moderator','member')),
  joined_at timestamptz not null default now(),
  primary key(group_id,user_id)
);

create table if not exists public.community_group_join_requests (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.community_groups(id) on delete cascade,
  user_id uuid not null references public.users(id) on delete cascade,
  status text not null default 'pending' check (status in ('pending','accepted','rejected')),
  created_at timestamptz not null default now(),
  responded_at timestamptz,
  unique(group_id,user_id)
);

create table if not exists public.community_group_messages (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.community_groups(id) on delete cascade,
  user_id uuid not null references public.users(id) on delete cascade,
  content text not null check (char_length(trim(content)) between 1 and 3000),
  created_at timestamptz not null default now()
);

create index if not exists community_groups_created_idx on public.community_groups(created_at desc);
create index if not exists community_group_members_user_idx on public.community_group_members(user_id,joined_at desc);
create index if not exists community_group_join_requests_group_idx on public.community_group_join_requests(group_id,status,created_at desc);
create index if not exists community_group_messages_group_idx on public.community_group_messages(group_id,created_at desc);

-- Group chat must participate in Supabase Realtime just like direct messages.
do $$ begin
  alter publication supabase_realtime add table public.community_group_messages;
exception when duplicate_object then null;
end $$;

alter table public.community_groups enable row level security;
alter table public.community_group_members enable row level security;
alter table public.community_group_join_requests enable row level security;
alter table public.community_group_messages enable row level security;

drop policy if exists community_groups_read on public.community_groups;
create policy community_groups_read on public.community_groups for select to authenticated using (true);
drop policy if exists community_groups_insert_self on public.community_groups;
create policy community_groups_insert_self on public.community_groups for insert to authenticated with check (owner_id=auth.uid());
drop policy if exists community_groups_update_owner on public.community_groups;
create policy community_groups_update_owner on public.community_groups for update to authenticated using (owner_id=auth.uid()) with check (owner_id=auth.uid());
drop policy if exists community_groups_delete_owner on public.community_groups;
create policy community_groups_delete_owner on public.community_groups for delete to authenticated using (owner_id=auth.uid());

drop policy if exists community_group_members_read on public.community_group_members;
create policy community_group_members_read on public.community_group_members for select to authenticated using (
  user_id=auth.uid() or exists(select 1 from public.community_groups g where g.id=group_id and (not g.is_private or g.owner_id=auth.uid()))
);
-- Membership changes go through RPCs so private/member invariants cannot be bypassed.
drop policy if exists community_group_members_insert_self on public.community_group_members;
drop policy if exists community_group_members_delete_self on public.community_group_members;

-- Private-group requests are also RPC-only so only the group owner can approve them.
drop policy if exists community_group_join_requests_read on public.community_group_join_requests;
drop policy if exists community_group_join_requests_write on public.community_group_join_requests;

drop policy if exists community_group_messages_read_members on public.community_group_messages;
create policy community_group_messages_read_members on public.community_group_messages for select to authenticated using (
  exists(select 1 from public.community_group_members gm where gm.group_id=group_id and gm.user_id=auth.uid())
);
drop policy if exists community_group_messages_insert_members on public.community_group_messages;
create policy community_group_messages_insert_members on public.community_group_messages for insert to authenticated with check (
  user_id=auth.uid() and exists(select 1 from public.community_group_members gm where gm.group_id=group_id and gm.user_id=auth.uid())
);
drop policy if exists community_group_messages_delete_self on public.community_group_messages;
create policy community_group_messages_delete_self on public.community_group_messages for delete to authenticated using (user_id=auth.uid());

create or replace function public.community_group_owner_membership()
returns trigger language plpgsql security definer set search_path=public set row_security=off as $$
begin
  insert into public.community_group_members(group_id,user_id,role)
  values(new.id,new.owner_id,'owner') on conflict(group_id,user_id) do update set role='owner';
  return new;
end $$;
drop trigger if exists community_group_add_owner on public.community_groups;
create trigger community_group_add_owner after insert on public.community_groups
for each row execute function public.community_group_owner_membership();

create or replace function public.get_community_groups()
returns table(
  id uuid, owner_id uuid, name text, description text, group_type text,
  is_private boolean, members bigint, is_joined boolean, is_owner boolean, join_status text, created_at timestamptz
)
language sql security definer set search_path=public set row_security=off stable as $$
  select g.id,g.owner_id,g.name,g.description,g.group_type,g.is_private,
         (select count(*) from public.community_group_members m where m.group_id=g.id) as members,
         exists(select 1 from public.community_group_members m where m.group_id=g.id and m.user_id=auth.uid()) as is_joined,
         g.owner_id=auth.uid() as is_owner,
         coalesce((select r.status from public.community_group_join_requests r where r.group_id=g.id and r.user_id=auth.uid()),'none') as join_status,
         g.created_at
  from public.community_groups g
  order by g.created_at desc;
$$;

create or replace function public.join_community_group(target_group_id uuid)
returns text language plpgsql security definer set search_path=public set row_security=off as $$
declare me uuid:=auth.uid(); target public.community_groups;
begin
  if me is null then raise exception 'not_authenticated'; end if;
  select * into target from public.community_groups where id=target_group_id;
  if target.id is null then raise exception 'group_not_found'; end if;
  if exists(select 1 from public.community_group_members m where m.group_id=target_group_id and m.user_id=me) then
    return 'joined';
  end if;
  if target.is_private then
    insert into public.community_group_join_requests(group_id,user_id,status,created_at,responded_at)
    values(target_group_id,me,'pending',now(),null)
    on conflict(group_id,user_id) do update
      set status='pending', created_at=now(), responded_at=null;
    return 'requested';
  end if;
  insert into public.community_group_members(group_id,user_id,role)
  values(target_group_id,me,'member') on conflict do nothing;
  return 'joined';
end $$;

create or replace function public.leave_community_group(target_group_id uuid)
returns void language plpgsql security definer set search_path=public set row_security=off as $$
declare me uuid:=auth.uid(); target_owner uuid;
begin
  if me is null then raise exception 'not_authenticated'; end if;
  select owner_id into target_owner from public.community_groups where id=target_group_id;
  if target_owner=me then raise exception 'owner_cannot_leave'; end if;
  delete from public.community_group_members where group_id=target_group_id and user_id=me;
end $$;


create or replace function public.get_community_group_join_requests(target_group_id uuid)
returns table(request_id uuid, user_id uuid, user_name text, created_at timestamptz)
language sql security definer set search_path=public set row_security=off stable as $$
  select r.id,r.user_id,coalesce(u.name,'زميل'),r.created_at
  from public.community_group_join_requests r
  join public.community_groups g on g.id=r.group_id
  join public.users u on u.id=r.user_id
  where r.group_id=target_group_id and r.status='pending' and g.owner_id=auth.uid()
  order by r.created_at;
$$;

create or replace function public.respond_community_group_join_request(target_request_id uuid, accept_request boolean)
returns void language plpgsql security definer set search_path=public set row_security=off as $$
declare me uuid:=auth.uid(); req public.community_group_join_requests;
begin
  if me is null then raise exception 'not_authenticated'; end if;
  select r.* into req
  from public.community_group_join_requests r
  join public.community_groups g on g.id=r.group_id
  where r.id=target_request_id and r.status='pending' and g.owner_id=me
  for update of r;
  if req.id is null then raise exception 'pending_request_not_found'; end if;
  update public.community_group_join_requests
  set status=case when accept_request then 'accepted' else 'rejected' end,
      responded_at=now()
  where id=req.id;
  if accept_request then
    insert into public.community_group_members(group_id,user_id,role)
    values(req.group_id,req.user_id,'member') on conflict do nothing;
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- Polls
-- ---------------------------------------------------------------------------
create table if not exists public.polls (
  id uuid primary key default gen_random_uuid(),
  creator_id uuid not null references public.users(id) on delete cascade,
  question text not null check (char_length(trim(question)) between 1 and 300),
  is_closed boolean not null default false,
  closes_at timestamptz,
  created_at timestamptz not null default now()
);
create table if not exists public.poll_options (
  id uuid primary key default gen_random_uuid(),
  poll_id uuid not null references public.polls(id) on delete cascade,
  option_order integer not null check(option_order>=0),
  text text not null check(char_length(trim(text)) between 1 and 160),
  unique(poll_id,option_order)
);
create table if not exists public.poll_votes (
  poll_id uuid not null references public.polls(id) on delete cascade,
  option_id uuid not null references public.poll_options(id) on delete cascade,
  user_id uuid not null references public.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key(poll_id,user_id)
);
create index if not exists polls_created_idx on public.polls(created_at desc);
create index if not exists poll_options_poll_idx on public.poll_options(poll_id,option_order);
create index if not exists poll_votes_option_idx on public.poll_votes(option_id);
alter table public.polls enable row level security;
alter table public.poll_options enable row level security;
alter table public.poll_votes enable row level security;
drop policy if exists polls_read on public.polls;
create policy polls_read on public.polls for select to authenticated using (true);
-- Poll creation and voting go through validated RPCs only.
drop policy if exists polls_insert_self on public.polls;
drop policy if exists polls_update_owner on public.polls;
create policy polls_update_owner on public.polls for update to authenticated using (creator_id=auth.uid()) with check (creator_id=auth.uid());
drop policy if exists poll_options_read on public.poll_options;
create policy poll_options_read on public.poll_options for select to authenticated using (true);
drop policy if exists poll_options_insert_owner on public.poll_options;
drop policy if exists poll_votes_read on public.poll_votes;
create policy poll_votes_read on public.poll_votes for select to authenticated using (user_id=auth.uid());
drop policy if exists poll_votes_insert_self on public.poll_votes;

create or replace function public.create_poll(target_question text, target_options text[])
returns uuid language plpgsql security definer set search_path=public set row_security=off as $$
declare me uuid:=auth.uid(); new_id uuid; item text; idx integer:=0;
begin
  if me is null then raise exception 'not_authenticated'; end if;
  if char_length(trim(coalesce(target_question,'')))<1 then raise exception 'question_required'; end if;
  if coalesce(array_length(target_options,1),0)<2 or array_length(target_options,1)>6 then raise exception 'options_2_to_6_required'; end if;
  insert into public.polls(creator_id,question) values(me,trim(target_question)) returning id into new_id;
  foreach item in array target_options loop
    if char_length(trim(coalesce(item,'')))<1 then raise exception 'empty_option'; end if;
    insert into public.poll_options(poll_id,option_order,text) values(new_id,idx,trim(item));
    idx:=idx+1;
  end loop;
  return new_id;
end $$;

create or replace function public.vote_poll(target_poll_id uuid, target_option_id uuid)
returns void language plpgsql security definer set search_path=public set row_security=off as $$
declare me uuid:=auth.uid(); p public.polls;
begin
  if me is null then raise exception 'not_authenticated'; end if;
  select * into p from public.polls where id=target_poll_id;
  if p.id is null then raise exception 'poll_not_found'; end if;
  if p.is_closed or (p.closes_at is not null and p.closes_at<=now()) then raise exception 'poll_closed'; end if;
  if not exists(select 1 from public.poll_options where id=target_option_id and poll_id=target_poll_id) then raise exception 'invalid_option'; end if;
  insert into public.poll_votes(poll_id,option_id,user_id) values(target_poll_id,target_option_id,me);
exception when unique_violation then
  raise exception 'already_voted';
end $$;

create or replace function public.get_polls()
returns table(
  id uuid, question text, is_closed boolean, created_at timestamptz,
  creator_name text, options jsonb, user_choice uuid
)
language sql security definer set search_path=public set row_security=off stable as $$
  select p.id,p.question,(p.is_closed or (p.closes_at is not null and p.closes_at<=now())),p.created_at,
         coalesce(u.name,'زميل'),
         coalesce((
           select jsonb_agg(jsonb_build_object(
             'id',o.id,'text',o.text,'order',o.option_order,
             'votes',(select count(*) from public.poll_votes v where v.option_id=o.id)
           ) order by o.option_order)
           from public.poll_options o where o.poll_id=p.id
         ),'[]'::jsonb),
         (select v.option_id from public.poll_votes v where v.poll_id=p.id and v.user_id=auth.uid() limit 1)
  from public.polls p join public.users u on u.id=p.creator_id
  order by p.created_at desc;
$$;

-- ---------------------------------------------------------------------------
-- Anonymous wall. Sender identity is never returned by the public RPC.
-- ---------------------------------------------------------------------------
create table if not exists public.zameel_anonymous_messages (
  id uuid primary key default gen_random_uuid(),
  sender_id uuid not null references public.users(id) on delete cascade,
  content text not null check(char_length(trim(content)) between 1 and 1200),
  created_at timestamptz not null default now()
);
create index if not exists zameel_anonymous_messages_created_idx on public.zameel_anonymous_messages(created_at desc);
alter table public.zameel_anonymous_messages enable row level security;
-- No direct SELECT policy: the identity-safe RPC below is the read surface.
drop policy if exists zameel_anonymous_messages_insert_self on public.zameel_anonymous_messages;
create policy zameel_anonymous_messages_insert_self on public.zameel_anonymous_messages for insert to authenticated with check(sender_id=auth.uid());
drop policy if exists zameel_anonymous_messages_delete_self on public.zameel_anonymous_messages;
create policy zameel_anonymous_messages_delete_self on public.zameel_anonymous_messages for delete to authenticated using(sender_id=auth.uid());

create or replace function public.send_anonymous_message(target_content text)
returns uuid language plpgsql security definer set search_path=public set row_security=off as $$
declare me uuid:=auth.uid(); new_id uuid;
begin
  if me is null then raise exception 'not_authenticated'; end if;
  insert into public.zameel_anonymous_messages(sender_id,content) values(me,trim(target_content)) returning id into new_id;
  return new_id;
end $$;

create or replace function public.get_anonymous_messages(result_limit integer default 100)
returns table(id uuid, content text, created_at timestamptz, is_mine boolean)
language sql security definer set search_path=public set row_security=off stable as $$
  select a.id,a.content,a.created_at,a.sender_id=auth.uid()
  from public.zameel_anonymous_messages a
  order by a.created_at desc
  limit least(greatest(coalesce(result_limit,100),1),200);
$$;

-- ---------------------------------------------------------------------------
-- Partner directory. Company accounts can submit; approved entries are public
-- to authenticated students. Approval remains an admin operation.
-- ---------------------------------------------------------------------------
create table if not exists public.business_partners (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid references public.users(id) on delete set null,
  name text not null check(char_length(trim(name)) between 1 and 160),
  category text not null default 'services' check(category in ('offers','education','career','services')),
  tag text not null default '',
  description text not null default '',
  website_url text,
  logo_url text,
  is_approved boolean not null default false,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists business_partners_live_idx on public.business_partners(is_approved,is_active,created_at desc);
alter table public.business_partners enable row level security;
drop policy if exists business_partners_read on public.business_partners;
create policy business_partners_read on public.business_partners for select to authenticated using(is_approved or owner_id=auth.uid());
drop policy if exists business_partners_insert_company on public.business_partners;
create policy business_partners_insert_company on public.business_partners for insert to authenticated with check(
  owner_id=auth.uid() and is_approved=false and is_active=true
  and exists(select 1 from public.users u where u.id=auth.uid() and u.role in ('company','admin'))
);
drop policy if exists business_partners_update_owner on public.business_partners;
create policy business_partners_update_owner on public.business_partners for update to authenticated using(owner_id=auth.uid()) with check(owner_id=auth.uid());

-- Partner owners may edit their listing, but cannot approve themselves.
create or replace function public.protect_business_partner_approval()
returns trigger language plpgsql security definer set search_path=public as $$
begin
  if auth.uid() is not null
     and new.is_approved is distinct from old.is_approved
     and not exists(select 1 from public.users u where u.id=auth.uid() and u.role='admin') then
    raise exception 'partner_approval_requires_admin';
  end if;
  return new;
end $$;
drop trigger if exists business_partners_protect_approval on public.business_partners;
create trigger business_partners_protect_approval before update of is_approved on public.business_partners
for each row execute function public.protect_business_partner_approval();

-- ---------------------------------------------------------------------------
-- Activity stats: compute from existing durable social data instead of demos.
-- ---------------------------------------------------------------------------
create or replace function public.get_my_activity_stats()
returns jsonb language sql security definer set search_path=public set row_security=off stable as $$
  select jsonb_build_object(
    'posts', (select count(*) from public.posts p where p.user_id=auth.uid()),
    'likes', (select count(*) from public.likes l join public.posts p on p.id=l.post_id where p.user_id=auth.uid()),
    'comments', (select count(*) from public.post_comments c where c.user_id=auth.uid()),
    'friends', (select count(*) from public.follows f where f.follower_id=auth.uid() and exists (select 1 from public.follows r where r.follower_id=f.following_id and r.following_id=auth.uid())),
    'saved_posts', (select count(*) from public.saved_posts s where s.user_id=auth.uid()),
    'saved_books', (select count(*) from public.book_listings b where b.owner_id=auth.uid() and b.status<>'withdrawn'),
    'active_days', (
      select count(distinct d)::int from (
        select p.created_at::date d from public.posts p where p.user_id=auth.uid()
        union all select c.created_at::date from public.post_comments c where c.user_id=auth.uid()
        union all select l.created_at::date from public.likes l where l.user_id=auth.uid()
      ) q
    )
  );
$$;

create or replace function public.get_my_weekly_activity()
returns table(day_date date, activity_count bigint)
language sql security definer set search_path=public set row_security=off stable as $$
  with days as (
    select generate_series(current_date-6,current_date,'1 day'::interval)::date d
  ), activity as (
    select p.created_at::date d from public.posts p where p.user_id=auth.uid() and p.created_at>=current_date-6
    union all select c.created_at::date from public.post_comments c where c.user_id=auth.uid() and c.created_at>=current_date-6
    union all select l.created_at::date from public.likes l where l.user_id=auth.uid() and l.created_at>=current_date-6
  )
  select days.d,count(activity.d) from days left join activity on activity.d=days.d group by days.d order by days.d;
$$;

-- Updated-at triggers reuse the helper created by migration 001.
drop trigger if exists calendar_events_set_updated_at on public.calendar_events;
create trigger calendar_events_set_updated_at before update on public.calendar_events for each row execute function public.set_updated_at();
drop trigger if exists community_groups_set_updated_at on public.community_groups;
create trigger community_groups_set_updated_at before update on public.community_groups for each row execute function public.set_updated_at();
drop trigger if exists business_partners_set_updated_at on public.business_partners;
create trigger business_partners_set_updated_at before update on public.business_partners for each row execute function public.set_updated_at();

revoke execute on function public.community_group_owner_membership(), public.protect_business_partner_approval(),
  public.get_community_groups(), public.join_community_group(uuid), public.leave_community_group(uuid),
  public.get_community_group_join_requests(uuid), public.respond_community_group_join_request(uuid,boolean),
  public.create_poll(text,text[]), public.vote_poll(uuid,uuid), public.get_polls(),
  public.send_anonymous_message(text), public.get_anonymous_messages(integer),
  public.get_my_activity_stats(), public.get_my_weekly_activity() from public,anon;
grant execute on function public.get_community_groups(), public.join_community_group(uuid), public.leave_community_group(uuid),
  public.get_community_group_join_requests(uuid), public.respond_community_group_join_request(uuid,boolean),
  public.create_poll(text,text[]), public.vote_poll(uuid,uuid), public.get_polls(),
  public.send_anonymous_message(text), public.get_anonymous_messages(integer),
  public.get_my_activity_stats(), public.get_my_weekly_activity() to authenticated;

commit;
