begin;
alter table public.zameel_post_promotions add column if not exists impressions bigint not null default 0;
alter table public.zameel_post_promotions add column if not exists clicks bigint not null default 0;
create table if not exists public.zameel_promotion_events(
 id uuid primary key, promotion_id uuid not null references public.zameel_post_promotions(id) on delete cascade,
 viewer_id uuid not null references public.users(id) on delete cascade,
 shown_at timestamptz not null default now(),clicked_at timestamptz
);
create index if not exists promotion_viewer_day on public.zameel_promotion_events(viewer_id,promotion_id,shown_at);
alter table public.zameel_promotion_events enable row level security;
revoke all on public.zameel_promotion_events from public,anon,authenticated;
grant all on public.zameel_promotion_events to service_role;
-- Internal eligibility includes the authoritative demographic profile and post visibility.
create or replace function public.zameel_promotion_candidates()
returns setof public.zameel_post_promotions language sql stable security definer set search_path='' as $$
 select x.* from public.zameel_post_promotions x join public.posts p on p.id=x.post_id
 join public.zameel_audience_profiles a on a.user_id=auth.uid() join public.users u on u.id=auth.uid()
 where auth.uid() is not null and public.zameel_promotions_enabled() and x.status='approved' and x.starts_at<=now() and x.ends_at>now()
 and p.audience='public' and not coalesce(p.is_hidden,false) and public.can_view_post(auth.uid(),p.id)
 and not exists(select 1 from public.admin_user_states s where s.user_id in (auth.uid(),x.owner_id) and s.status in ('blocked','suspended'))
 and a.country='JO' and extract(year from age(current_date,a.birth_date)) between x.min_age and x.max_age
 and (x.target_gender='both' or a.gender=x.target_gender)
 and ((x.audience_type='general' and (x.countrywide or a.city=any(x.target_cities))) or (x.audience_type='students' and u.account_type='student' and u.university=any(x.target_universities)))
$$;
revoke all on function public.zameel_promotion_candidates() from public,anon,authenticated;
-- Daily limit uses Asia/Amman midnight. Least-delivered eligible campaigns rotate first.
create or replace function public.zameel_promoted_post_ids() returns table(post_id uuid,ends_at timestamptz)
language sql stable security definer set search_path='' as $$
 select x.post_id,x.ends_at from public.zameel_promotion_candidates() x
 where (select count(*) from public.zameel_promotion_events e where e.viewer_id=auth.uid() and e.promotion_id=x.id
 and e.shown_at >= date_trunc('day',now() at time zone 'Asia/Amman') at time zone 'Asia/Amman')<2
 order by x.impressions,coalesce((select max(e.shown_at) from public.zameel_promotion_events e where e.viewer_id=auth.uid() and e.promotion_id=x.id),'-infinity'::timestamptz),x.starts_at,x.id limit 50
$$;
create or replace function public.zameel_record_promotion(p_post uuid,p_event uuid,p_click boolean default false)
returns boolean language plpgsql security definer set search_path='' as $$
declare actor uuid:=auth.uid(); campaign public.zameel_post_promotions; event public.zameel_promotion_events; last_post uuid;
begin
 if actor is null or p_event is null or p_click is null then return false;end if;
 -- Serialize concurrent tabs/devices belonging to the same viewer.
 perform pg_advisory_xact_lock(hashtextextended(actor::text,150));
 select * into campaign from public.zameel_promotion_candidates() c where c.post_id=p_post order by c.starts_at desc,c.id desc limit 1;
 if campaign.id is null then return false;end if;
 select * into event from public.zameel_promotion_events where id=p_event;
 if event.id is not null then
  if event.viewer_id<>actor or event.promotion_id<>campaign.id then return false;end if;
  if p_click and event.clicked_at is null then
   update public.zameel_promotion_events set clicked_at=now() where id=p_event;
   update public.zameel_post_promotions set clicks=clicks+1 where id=campaign.id;
  end if;
  return true;
 end if;
 if p_click then return false;end if;
 if (select count(*) from public.zameel_promotion_events e where e.viewer_id=actor and e.promotion_id=campaign.id
 and e.shown_at >= date_trunc('day',now() at time zone 'Asia/Amman') at time zone 'Asia/Amman')>=2 then return false;end if;
 select p.post_id into last_post from public.zameel_promotion_events e join public.zameel_post_promotions p on p.id=e.promotion_id
 where e.viewer_id=actor and e.shown_at >= date_trunc('day',now() at time zone 'Asia/Amman') at time zone 'Asia/Amman' order by e.shown_at desc,e.id desc limit 1;
 if last_post=p_post then return false;end if;
 insert into public.zameel_promotion_events(id,promotion_id,viewer_id) values(p_event,campaign.id,actor);
 update public.zameel_post_promotions set impressions=impressions+1 where id=campaign.id;
 return true;
end $$;
revoke all on function public.zameel_record_promotion(uuid,uuid,boolean) from public,anon,authenticated;
grant execute on function public.zameel_record_promotion(uuid,uuid,boolean),public.zameel_promoted_post_ids() to authenticated;
revoke all on function public.zameel_promoted_post_ids() from public,anon;
-- Aggregates only. Viewer identities remain private.
create or replace function public.zameel_promotion_stats(p_id uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare campaign public.zameel_post_promotions;
begin
 select * into campaign from public.zameel_post_promotions where id=p_id;
 if campaign.id is null or auth.uid() is null or campaign.owner_id<>auth.uid() then raise exception 'promotion_stats_denied';end if;
 return jsonb_build_object('impressions',campaign.impressions,'clicks',campaign.clicks);
end $$;
revoke all on function public.zameel_promotion_stats(uuid) from public,anon,authenticated;
grant execute on function public.zameel_promotion_stats(uuid) to authenticated;
notify pgrst,'reload schema';
commit;
