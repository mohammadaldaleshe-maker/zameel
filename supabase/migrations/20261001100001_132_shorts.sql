-- Draft: install only after release validation. Existing clip audiences stay unchanged.
begin;
create or replace function public.enforce_clip_duration_45_seconds() returns trigger language plpgsql set search_path='' as $$
begin
 if new.duration_seconds is null or new.duration_seconds<1 or new.duration_seconds>120 then raise exception 'shorts_duration_must_be_1_to_120_seconds' using errcode='23514'; end if;
 return new;
end $$;
alter table public.clips add column if not exists cover_url text;
alter table public.clips add column if not exists views_count bigint not null default 0;
create or replace function public.zameel_guard_shorts_counter() returns trigger language plpgsql security invoker set search_path='' as $$
begin
 if current_user in ('postgres','service_role','supabase_admin') then return new; end if;
 if TG_OP='INSERT' then
  if new.views_count<>0 then raise exception 'shorts_counter_not_authorized'; end if;
 elsif new.views_count is distinct from old.views_count then raise exception 'shorts_counter_not_authorized'; end if;
 return new;
end $$;
revoke all on function public.zameel_guard_shorts_counter() from public,anon,authenticated;
drop trigger if exists shorts_counter_guard on public.clips;
create trigger shorts_counter_guard before insert or update of views_count on public.clips for each row execute function public.zameel_guard_shorts_counter();
create table if not exists public.zameel_shorts_preferences (
 user_id uuid not null references public.users(id) on delete cascade,
 clip_id uuid not null references public.clips(id) on delete cascade,
 saved boolean not null default false, hidden boolean not null default false,
 watched_seconds integer not null default 0 check(watched_seconds between 0 and 120),
 last_counted_at timestamptz, primary key(user_id,clip_id)
);
create table if not exists public.zameel_shorts_sessions (
 id uuid primary key default gen_random_uuid(), user_id uuid not null references public.users(id) on delete cascade,
 clip_id uuid not null references public.clips(id) on delete cascade, created_at timestamptz not null default now(), counted boolean not null default false
);
alter table public.zameel_shorts_preferences enable row level security;
alter table public.zameel_shorts_sessions enable row level security;
revoke all on public.zameel_shorts_preferences,public.zameel_shorts_sessions from public,anon,authenticated;
grant all on public.zameel_shorts_preferences,public.zameel_shorts_sessions to service_role;
create index if not exists shorts_likes_user_idx on public.clip_likes(user_id,clip_id);
create index if not exists shorts_sessions_expiry_idx on public.zameel_shorts_sessions(created_at);
create or replace function public.zameel_shorts_preference(p_clip uuid,p_action text) returns void language plpgsql security definer set search_path='' as $$
declare actor uuid:=auth.uid();
begin
 if actor is null or not coalesce(public.zameel_account_can_write(),false) or not coalesce(public.can_view_clip(actor,p_clip),false) then raise exception 'shorts_unavailable'; end if;
 if p_action is null or p_action not in ('save','unsave','hide') then raise exception 'invalid_shorts_action'; end if;
 insert into public.zameel_shorts_preferences(user_id,clip_id,saved,hidden) values(actor,p_clip,p_action='save',p_action='hide')
 on conflict(user_id,clip_id) do update set saved=case when p_action='hide' then zameel_shorts_preferences.saved else p_action='save' end,hidden=zameel_shorts_preferences.hidden or p_action='hide';
end $$;
create or replace function public.zameel_shorts_start(p_clip uuid) returns uuid language plpgsql security definer set search_path='' as $$
declare actor uuid:=auth.uid(); result uuid;
begin
 if actor is null or not coalesce(public.zameel_account_can_write(),false) or not coalesce(public.can_view_clip(actor,p_clip),false) then raise exception 'shorts_unavailable'; end if;
 -- Limit session creation and remove old ephemeral sessions without a new service.
 if (select count(*) from public.zameel_shorts_sessions where user_id=actor and created_at>now()-interval '1 minute')>=30 then raise exception 'shorts_rate_limited'; end if;
 delete from public.zameel_shorts_sessions where user_id=actor and created_at<now()-interval '1 hour';
 insert into public.zameel_shorts_sessions(user_id,clip_id) values(actor,p_clip) returning id into result; return result;
end $$;
create or replace function public.zameel_shorts_view(p_session uuid,p_seconds integer) returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid:=auth.uid(); session public.zameel_shorts_sessions; preference public.zameel_shorts_preferences; counted boolean:=false;
begin
 if actor is null or not coalesce(public.zameel_account_can_write(),false) then raise exception 'shorts_unavailable'; end if;
 select * into session from public.zameel_shorts_sessions where id=p_session and user_id=actor for update;
 if session.id is null or session.created_at<now()-interval '1 hour' or now()-session.created_at<interval '3 seconds' or p_seconds is null or p_seconds<3 then raise exception 'invalid_shorts_view'; end if;
 if not coalesce(public.can_view_clip(actor,session.clip_id),false) then raise exception 'shorts_unavailable'; end if;
 insert into public.zameel_shorts_preferences(user_id,clip_id) values(actor,session.clip_id) on conflict do nothing;
 select * into preference from public.zameel_shorts_preferences where user_id=actor and clip_id=session.clip_id for update;
 if not session.counted and (preference.last_counted_at is null or preference.last_counted_at<=now()-interval '24 hours') and exists(select 1 from public.clips where id=session.clip_id and user_id<>actor) then
  update public.clips set views_count=views_count+1 where id=session.clip_id;
  update public.zameel_shorts_preferences set last_counted_at=now() where user_id=actor and clip_id=session.clip_id; counted=true;
 end if;
 update public.zameel_shorts_sessions set counted=true where id=session.id;
 update public.zameel_shorts_preferences set watched_seconds=greatest(watched_seconds,least(120,p_seconds)) where user_id=actor and clip_id=session.clip_id;
 return jsonb_build_object('counted',counted);
end $$;
create or replace function public.zameel_shorts_feed(p_author uuid default null,p_exclude uuid[] default '{}'::uuid[],p_offset integer default 0,p_saved boolean default false) returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid:=auth.uid(); result jsonb;
begin
 if coalesce(cardinality(p_exclude),0)>500 then raise exception 'shorts_page_limit'; end if;
 if actor is null or not coalesce(public.zameel_account_can_read(),false) then raise exception 'shorts_unavailable'; end if;
 select coalesce(jsonb_agg(to_jsonb(x)),'[]'::jsonb) into result from (
  select c.*,jsonb_build_object('name',u.name,'profile_image',u.profile_image) as users,
   exists(select 1 from public.clip_likes l where l.clip_id=c.id and l.user_id=actor) as liked,
   coalesce(pref.saved,false) as saved
  from public.clips c join public.users u on u.id=c.user_id
  left join public.zameel_shorts_preferences pref on pref.user_id=actor and pref.clip_id=c.id
  where public.can_view_clip(actor,c.id) and c.video_url not like 'uploading:%' and not(c.id=any(coalesce(p_exclude,'{}'::uuid[])))
   and (p_author is null and (coalesce(p_saved,false) or c.audience='public') or p_author=c.user_id)
   and (not coalesce(p_saved,false) or coalesce(pref.saved,false))
   and not coalesce(pref.hidden,false)
   and not exists(select 1 from public.user_blocks b where (b.blocker_id=actor and b.blocked_id=c.user_id) or (b.blocker_id=c.user_id and b.blocked_id=actor))
  order by case when p_author is not null or coalesce(p_saved,false) then extract(epoch from c.created_at) else random()+case when random()<0.5 then least(1.0,coalesce((select sum(p.watched_seconds+case when p.saved then 60 else 0 end)::numeric/300 from public.zameel_shorts_preferences p join public.clips history on history.id=p.clip_id where p.user_id=actor and history.user_id=c.user_id),0)+coalesce((select count(*)::numeric/5 from public.clip_likes liked join public.clips liked_clip on liked_clip.id=liked.clip_id where liked.user_id=actor and liked_clip.user_id=c.user_id),0)) else 0 end end desc,c.id desc limit 60 offset case when p_author is not null or coalesce(p_saved,false) then greatest(0,least(p_offset,100000)) else 0 end
 ) x;
 return result;
end $$;
revoke all on function public.zameel_shorts_preference(uuid,text),public.zameel_shorts_start(uuid),public.zameel_shorts_view(uuid,integer),public.zameel_shorts_feed(uuid,uuid[],integer,boolean) from public,anon,authenticated;
grant execute on function public.zameel_shorts_preference(uuid,text),public.zameel_shorts_start(uuid),public.zameel_shorts_view(uuid,integer),public.zameel_shorts_feed(uuid,uuid[],integer,boolean) to authenticated;
update public.feature_flags set name_ar='زميل شورتس' where feature_key='clips';
commit;
