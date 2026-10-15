begin;
set local lock_timeout='2s';
set local statement_timeout='60s';
lock table public.advertisements, public.zameel_post_promotions in access exclusive mode nowait;
create schema if not exists zameel_delivery162;
revoke all on schema zameel_delivery162 from public,anon,authenticated;
create table if not exists zameel_delivery162.ad_events(
 id uuid primary key, ad_id uuid not null references public.advertisements(id) on delete cascade,
 viewer_id uuid not null references public.users(id) on delete cascade, shown_at timestamptz not null default now()
);
create index if not exists ad_events_viewer162 on zameel_delivery162.ad_events(viewer_id,ad_id,shown_at);
revoke all on all tables in schema zameel_delivery162 from public,anon,authenticated;
-- Seed delivery history without charging existing totals a second time.
insert into zameel_delivery162.ad_events(id,ad_id,viewer_id,shown_at)
 select md5('legacy162:'||v.advertisement_id::text||':'||v.viewer_id::text)::uuid,v.advertisement_id,v.viewer_id,v.first_viewed_at from public.advertisement_views v join public.users u on u.id=v.viewer_id on conflict(id) do nothing;
-- Aggregates are private to the campaign owner. Public badges use their existing definer RPC.
drop policy if exists campaign_owner_stats162 on public.zameel_post_promotions;
create policy campaign_owner_stats162 on public.zameel_post_promotions as restrictive for select to authenticated using(owner_id=auth.uid());
-- Hide the legacy advertisement counter at the column privilege layer as well as in public API responses.
revoke select on public.advertisements from public,anon,authenticated;
do $$declare cols text;begin
 select string_agg(quote_ident(attname),',' order by attnum) into cols from pg_attribute
 where attrelid='public.advertisements'::regclass and attnum>0 and not attisdropped and attname<>'view_count';
 execute 'grant select('||cols||') on public.advertisements to authenticated';
end $$;
create or replace function public.zameel_promoted_post_ids() returns table(post_id uuid,ends_at timestamptz)
language sql stable security definer set search_path='' as $$
 select x.post_id,x.ends_at from public.zameel_promotion_candidates() x
 order by coalesce((select max(e.shown_at) from public.zameel_promotion_events e where e.viewer_id=auth.uid() and e.promotion_id=x.id),'-infinity'::timestamptz),x.impressions,x.starts_at,x.id limit 50
$$;
create or replace function public.zameel_record_promotion(p_post uuid,p_event uuid,p_click boolean default false)
returns boolean language plpgsql security definer set search_path='' as $$
declare actor uuid:=auth.uid(); campaign public.zameel_post_promotions; event public.zameel_promotion_events;
begin
 if actor is null or p_event is null or p_click is null or not public.zameel_account_can_read() or not public.zameel_device_authorized160() then return false;end if;
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
 insert into public.zameel_promotion_events(id,promotion_id,viewer_id) values(p_event,campaign.id,actor);
 update public.zameel_post_promotions set impressions=impressions+1 where id=campaign.id;
 return true;
end $$;
create or replace function public.zameel_owner_post_views162(p_posts uuid[])
returns table(post_id uuid,views bigint) language plpgsql stable security definer set search_path='' as $$
begin
 if auth.uid() is null or not public.zameel_account_can_read() or not public.zameel_device_authorized160() then raise exception 'access_denied';end if;
 if coalesce(cardinality(p_posts),0)>100 then raise exception 'too_many_posts';end if;
 return query select x.post_id,sum(x.impressions)::bigint from public.zameel_post_promotions x join public.posts p on p.id=x.post_id
 where (x.status in ('approved','expired') or x.impressions>0) and x.owner_id=auth.uid() and p.user_id=auth.uid() and x.post_id=any(p_posts) group by x.post_id;
end $$;
create or replace function public.zameel_advertisement_feed162(p_limit integer default 50)
returns table(id uuid) language sql stable security definer set search_path='' as $$
 select a.id from public.advertisements a where auth.uid() is not null and public.zameel_account_can_read() and public.zameel_device_authorized160()
 and public.advertisement_is_live(a) and not exists(select 1 from public.advertisement_hides h where h.advertisement_id=a.id and h.user_id=auth.uid())
 order by coalesce((select max(e.shown_at) from zameel_delivery162.ad_events e where e.ad_id=a.id and e.viewer_id=auth.uid()),'-infinity'::timestamptz),a.published_at,a.id
 limit greatest(1,least(coalesce(p_limit,50),50))
$$;
-- A single per-viewer queue across user promotions and partner advertisements.
create or replace function public.zameel_campaign_order162()
returns jsonb language sql stable security definer set search_path='' as $$
 select coalesce(jsonb_agg(q.key order by q.seen nulls first,q.started,q.key),'[]'::jsonb) from (
  select 'post:'||x.post_id::text as key,x.starts_at as started,
   (select max(e.shown_at) from public.zameel_promotion_events e where e.promotion_id=x.id and e.viewer_id=auth.uid()) as seen
  from public.zameel_promotion_candidates() x
  union all
  select 'ad:'||a.id::text,a.published_at,
   (select max(e.shown_at) from zameel_delivery162.ad_events e where e.ad_id=a.id and e.viewer_id=auth.uid())
  from public.advertisements a where public.advertisement_is_live(a)
   and not exists(select 1 from public.advertisement_hides h where h.advertisement_id=a.id and h.user_id=auth.uid())
 ) q where auth.uid() is not null and public.zameel_account_can_read() and public.zameel_device_authorized160()
$$;
revoke all on function public.zameel_campaign_order162() from public,anon;
grant execute on function public.zameel_campaign_order162() to authenticated;
-- Both endpoints take their rows from the same bounded global window: unseen
-- campaigns outside the window cannot be overtaken by a repeated campaign.
create or replace function public.zameel_promoted_post_ids() returns table(post_id uuid,ends_at timestamptz)
language sql stable security definer set search_path='' as $$
 with batch162 as (select value,ordinality from jsonb_array_elements_text(public.zameel_campaign_order162()) with ordinality limit 50)
 select x.post_id,x.ends_at from batch162 w join public.zameel_promotion_candidates() x on w.value='post:'||x.post_id::text order by w.ordinality
$$;
create or replace function public.zameel_advertisement_feed162(p_limit integer default 50)
returns table(id uuid) language sql stable security definer set search_path='' as $$
 with batch162 as (select value,ordinality from jsonb_array_elements_text(public.zameel_campaign_order162()) with ordinality limit greatest(1,least(coalesce(p_limit,50),50)))
 select a.id from batch162 w join public.advertisements a on w.value='ad:'||a.id::text order by w.ordinality
$$;
create or replace function public.zameel_record_advertisement162(p_ad uuid,p_event uuid)
returns boolean language plpgsql security definer set search_path='' as $$
declare actor uuid:=auth.uid(); event zameel_delivery162.ad_events; ad public.advertisements;
begin
 if actor is null or p_event is null or not public.zameel_account_can_read() or not public.zameel_device_authorized160() then return false;end if;
 perform pg_advisory_xact_lock(hashtextextended(actor::text,162));
 select * into ad from public.advertisements a where a.id=p_ad;
 if ad.id is null or not public.advertisement_is_live(ad) or exists(select 1 from public.advertisement_hides h where h.advertisement_id=p_ad and h.user_id=actor) then return false;end if;
 select * into event from zameel_delivery162.ad_events where id=p_event;
 if event.id is not null then return event.viewer_id=actor and event.ad_id=p_ad;end if;
 insert into zameel_delivery162.ad_events(id,ad_id,viewer_id) values(p_event,p_ad,actor);
 update public.advertisements set view_count=view_count+1 where id=p_ad;
 insert into public.advertisement_views(advertisement_id,viewer_id) values(p_ad,actor) on conflict do nothing;
 insert into public.advertisement_interest_categories(user_id,category) select actor,ad.category
 on conflict(user_id,category) do update set updated_at=now();
 return true;
end $$;
-- Preserve the old client signature; new clients supply an idempotent event identity.
create or replace function public.record_advertisement_view(target_ad_id uuid)
returns void language plpgsql security definer set search_path='' as $$begin
 perform public.zameel_record_advertisement162(target_ad_id,gen_random_uuid());
end $$;
revoke all on function public.zameel_owner_post_views162(uuid[]),public.zameel_advertisement_feed162(integer),public.zameel_record_advertisement162(uuid,uuid) from public,anon;
grant execute on function public.zameel_owner_post_views162(uuid[]),public.zameel_advertisement_feed162(integer),public.zameel_record_advertisement162(uuid,uuid) to authenticated;
revoke all on function public.zameel_record_promotion(uuid,uuid,boolean),public.zameel_promoted_post_ids(),public.record_advertisement_view(uuid) from public,anon;
grant execute on function public.zameel_record_promotion(uuid,uuid,boolean),public.zameel_promoted_post_ids(),public.record_advertisement_view(uuid) to authenticated;
notify pgrst,'reload schema';
commit;
