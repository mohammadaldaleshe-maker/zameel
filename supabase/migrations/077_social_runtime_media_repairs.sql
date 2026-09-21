-- Zameel 077: radio moderation/likes, Lamma chat and runtime repairs.
-- Additive only; completed chat/calls/stories/books schemas are untouched.

create extension if not exists pgcrypto;

alter table public.zameel_radio_posts
  add column if not exists like_count integer not null default 0,
  add column if not exists moderation_status text not null default 'visible',
  add column if not exists deleted_at timestamptz;

do $$ begin
  alter table public.zameel_radio_posts
    add constraint zameel_radio_moderation_status_check
    check (moderation_status in ('visible','pending_review','removed'));
exception when duplicate_object then null;
end $$;

create table if not exists public.zameel_radio_likes (
  post_id uuid not null references public.zameel_radio_posts(id) on delete cascade,
  user_id uuid not null references public.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key(post_id,user_id)
);

create table if not exists public.zameel_radio_admin_mutes (
  user_id uuid primary key references public.users(id) on delete cascade,
  muted_by uuid not null references public.users(id) on delete cascade,
  muted_until timestamptz not null,
  reason text not null default '',
  created_at timestamptz not null default now()
);

alter table public.zameel_radio_likes enable row level security;
alter table public.zameel_radio_admin_mutes enable row level security;

drop policy if exists radio_report_insert on public.zameel_radio_reports;
create policy radio_report_insert on public.zameel_radio_reports
for insert to authenticated with check (
  auth.uid()=reporter_id and not exists(
    select 1 from public.zameel_radio_posts p
    where p.id=post_id and p.user_id=auth.uid()
  )
);

drop policy if exists radio_likes_read on public.zameel_radio_likes;
create policy radio_likes_read on public.zameel_radio_likes
for select to authenticated using (true);

create or replace function public.zameel_is_admin(p_user uuid default auth.uid())
returns boolean language sql stable security definer set search_path=public as $$
  select exists(
    select 1 from public.users u
    where u.id=p_user and lower(coalesce(u.role,'')) in ('owner','admin')
  );
$$;

create or replace function public.zameel_toggle_radio_like(p_post_id uuid)
returns boolean language plpgsql security definer set search_path=public as $$
declare v_liked boolean;
begin
  if auth.uid() is null then raise exception 'authentication_required'; end if;
  if not exists(select 1 from zameel_radio_posts where id=p_post_id and moderation_status='visible' and expires_at>now()) then
    raise exception 'radio_post_unavailable';
  end if;
  if exists(select 1 from zameel_radio_likes where post_id=p_post_id and user_id=auth.uid()) then
    delete from zameel_radio_likes where post_id=p_post_id and user_id=auth.uid();
    v_liked:=false;
  else
    insert into zameel_radio_likes(post_id,user_id) values(p_post_id,auth.uid());
    v_liked:=true;
  end if;
  update zameel_radio_posts
  set like_count=(select count(*) from zameel_radio_likes where post_id=p_post_id)
  where id=p_post_id;
  return v_liked;
end;
$$;

create or replace function public.zameel_hide_radio_after_reports()
returns trigger language plpgsql security definer set search_path=public as $$
begin
  if (select count(*) from public.zameel_radio_reports where post_id=new.post_id) >= 2 then
    update public.zameel_radio_posts
       set is_hidden=true, moderation_status='pending_review'
     where id=new.post_id and moderation_status='visible';
  end if;
  return new;
end;
$$;

create or replace function public.zameel_remove_radio_post(p_post_id uuid)
returns void language plpgsql security definer set search_path=public as $$
declare v_owner uuid;
begin
  select user_id into v_owner from zameel_radio_posts where id=p_post_id;
  if v_owner is null then return; end if;
  if auth.uid()<>v_owner and not zameel_is_admin() then raise exception 'not_allowed'; end if;
  update zameel_radio_posts
     set is_hidden=true, moderation_status='removed', deleted_at=now()
   where id=p_post_id;
end;
$$;

create or replace function public.zameel_admin_review_radio(p_post_id uuid,p_action text)
returns void language plpgsql security definer set search_path=public as $$
begin
  if not zameel_is_admin() then raise exception 'admin_required'; end if;
  if p_action='restore' then
    update zameel_radio_posts set is_hidden=false,moderation_status='visible' where id=p_post_id;
  elsif p_action='remove' then
    update zameel_radio_posts set is_hidden=true,moderation_status='removed',deleted_at=now() where id=p_post_id;
  else
    raise exception 'invalid_action';
  end if;
end;
$$;

create or replace function public.zameel_admin_mute_radio_author(p_post_id uuid,p_days int default 7)
returns void language plpgsql security definer set search_path=public as $$
declare v_author uuid;
begin
  if not zameel_is_admin() then raise exception 'admin_required'; end if;
  select user_id into v_author from zameel_radio_posts where id=p_post_id;
  if v_author is null then return; end if;
  insert into zameel_radio_admin_mutes(user_id,muted_by,muted_until,reason)
  values(v_author,auth.uid(),now()+make_interval(days=>least(greatest(p_days,1),30)),'radio_moderation')
  on conflict(user_id) do update set muted_by=excluded.muted_by,muted_until=excluded.muted_until,reason=excluded.reason;
end;
$$;

drop function if exists public.zameel_radio_feed();
create function public.zameel_radio_feed()
returns table(
  id uuid,
  storage_path text,
  duration_seconds integer,
  is_anonymous boolean,
  created_at timestamptz,
  author_name text,
  author_image text,
  like_count integer,
  liked boolean,
  can_delete boolean,
  moderation_status text,
  is_admin boolean
) language sql stable security definer set search_path=public as $$
  with access as (select auth.uid() uid, zameel_is_admin() admin)
  select p.id,p.storage_path,p.duration_seconds,p.is_anonymous,p.created_at,
         case when p.is_anonymous then null else u.name end,
         case when p.is_anonymous then null else u.profile_image end,
         p.like_count,
         exists(select 1 from zameel_radio_likes x where x.post_id=p.id and x.user_id=auth.uid()),
         (p.user_id=auth.uid() or a.admin),
         p.moderation_status,
         a.admin
    from zameel_radio_posts p
    join users u on u.id=p.user_id
    cross join access a
   where a.uid is not null and p.expires_at>now()
     and p.moderation_status<>'removed'
     and ((p.moderation_status='visible' and not p.is_hidden) or (a.admin and p.moderation_status='pending_review'))
     and not exists(select 1 from zameel_radio_mutes m where m.owner_id=a.uid and m.muted_user_id=p.user_id and m.muted_until>now())
     and not exists(select 1 from zameel_radio_admin_mutes m where m.user_id=p.user_id and m.muted_until>now())
   order by (p.moderation_status='pending_review') desc,p.created_at desc;
$$;

-- Lamma group chat is separate from the established direct-message tables.
create table if not exists public.social_lamma_messages (
  id uuid primary key default gen_random_uuid(),
  lamma_id uuid not null references public.social_lammas(id) on delete cascade,
  sender_id uuid not null references public.users(id) on delete cascade,
  body text not null check(char_length(trim(body)) between 1 and 2000),
  created_at timestamptz not null default now()
);
create index if not exists social_lamma_messages_room_time_idx
  on public.social_lamma_messages(lamma_id,created_at);
alter table public.social_lamma_messages enable row level security;
do $$ begin
  alter publication supabase_realtime add table public.social_lamma_messages;
exception when duplicate_object then null;
end $$;

drop policy if exists lamma_messages_members_read on public.social_lamma_messages;
create policy lamma_messages_members_read on public.social_lamma_messages
for select to authenticated using (
  exists(select 1 from public.social_lamma_members m where m.lamma_id=social_lamma_messages.lamma_id and m.user_id=auth.uid())
);
drop policy if exists lamma_messages_members_insert on public.social_lamma_messages;
create policy lamma_messages_members_insert on public.social_lamma_messages
for insert to authenticated with check (
  sender_id=auth.uid() and exists(
    select 1 from public.social_lamma_members m
    join public.social_lammas l on l.id=m.lamma_id
    where m.lamma_id=social_lamma_messages.lamma_id and m.user_id=auth.uid()
      and l.status in ('open','full') and l.expires_at>now()
  )
);
drop policy if exists lamma_messages_sender_delete on public.social_lamma_messages;
create policy lamma_messages_sender_delete on public.social_lamma_messages
for delete to authenticated using(sender_id=auth.uid());

create or replace function public.zameel_add_lamma_creator()
returns trigger language plpgsql security definer set search_path=public as $$
begin
  insert into public.social_lamma_members(lamma_id,user_id)
  values(new.id,new.creator_id) on conflict do nothing;
  return new;
end;
$$;
drop trigger if exists zameel_lamma_creator_member on public.social_lammas;
create trigger zameel_lamma_creator_member
after insert on public.social_lammas
for each row execute function public.zameel_add_lamma_creator();

create or replace function public.join_social_lamma(p_lamma uuid)
returns boolean language plpgsql security definer set search_path=public as $$
declare cap int; joined int;
begin
  if auth.uid() is null then raise exception 'authentication_required'; end if;
  if exists(select 1 from social_lamma_members where lamma_id=p_lamma and user_id=auth.uid()) then return true; end if;
  select max_members into cap from social_lammas where id=p_lamma and status in ('open','full') and expires_at>now() for update;
  if cap is null then return false; end if;
  select count(*) into joined from social_lamma_members where lamma_id=p_lamma;
  if joined>=cap then update social_lammas set status='full' where id=p_lamma; return false; end if;
  insert into social_lamma_members(lamma_id,user_id) values(p_lamma,auth.uid()) on conflict do nothing;
  select count(*) into joined from social_lamma_members where lamma_id=p_lamma;
  if joined>=cap then update social_lammas set status='full' where id=p_lamma; end if;
  return true;
end;
$$;

revoke all on function public.zameel_toggle_radio_like(uuid) from public,anon;
revoke all on function public.zameel_remove_radio_post(uuid) from public,anon;
revoke all on function public.zameel_admin_review_radio(uuid,text) from public,anon;
revoke all on function public.zameel_admin_mute_radio_author(uuid,int) from public,anon;
grant execute on function public.zameel_toggle_radio_like(uuid) to authenticated;
grant execute on function public.zameel_remove_radio_post(uuid) to authenticated;
grant execute on function public.zameel_admin_review_radio(uuid,text) to authenticated;
grant execute on function public.zameel_admin_mute_radio_author(uuid,int) to authenticated;
grant execute on function public.zameel_radio_feed() to authenticated;
grant execute on function public.join_social_lamma(uuid) to authenticated;
grant select,insert,delete on table public.social_lamma_messages to authenticated;
