-- 138: owner receipts, targeted distribution, version policy and audited post deletion.
begin;
create or replace function public.zameel_promoted_post_ids() returns table(post_id uuid,ends_at timestamptz)
language sql stable security definer set search_path='' as $$
 select x.post_id,x.ends_at from public.zameel_post_promotions x join public.posts p on p.id=x.post_id
 left join public.zameel_audience_profiles a on a.user_id=auth.uid() join public.users u on u.id=auth.uid()
 where auth.uid() is not null and public.zameel_promotions_enabled() and x.status='approved' and x.starts_at<=now() and x.ends_at>now()
 and p.audience='public' and not coalesce(p.is_hidden,false) and public.can_view_post(auth.uid(),p.id)
 and not exists(select 1 from public.admin_user_states s where s.user_id in (auth.uid(),x.owner_id) and s.status in ('blocked','suspended'))
 and (x.owner_id=auth.uid() or (a.country='JO' and extract(year from age(current_date,a.birth_date)) between x.min_age and x.max_age
 and (x.target_gender='both' or a.gender=x.target_gender)
 and ((x.audience_type='general' and (x.countrywide or a.city=any(x.target_cities))) or (x.audience_type='students' and u.account_type='student' and u.university=any(x.target_universities)))
 ))
 order by x.starts_at desc limit 30;
$$;

alter table public.app_releases add column if not exists is_allowed boolean not null default true;
alter table public.app_releases add column if not exists download_url text not null default '';
create index if not exists app_release_build_idx on public.app_releases(platform,build_number desc);
insert into public.app_releases(platform,version_name,build_number,is_allowed,download_url)
values ('android','2.0.2',11,true,''),
('android','2.0.3',12,true,''),
('android','2.0.4',13,true,'')
on conflict(platform,version_name) do update set build_number=excluded.build_number;
create or replace function public.zameel_release_policy(p_platform text,p_build integer)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare latest public.app_releases; current_release public.app_releases; begin
 if p_platform not in ('android','ios','web') or p_build<1 then raise exception 'invalid_release';end if;
 select * into latest from public.app_releases where platform=p_platform and is_allowed and is_active
 and download_url like 'https://%' order by build_number desc nulls last limit 1;
 if latest.id is null then return jsonb_build_object('allowed',true);end if;
 select * into current_release from public.app_releases where platform=p_platform and build_number=p_build order by created_at desc limit 1;
 return jsonb_build_object('allowed',case when current_release.id is not null then current_release.is_allowed
 else p_build>=coalesce(latest.build_number,0) end,'version_name',latest.version_name,'download_url',latest.download_url);
end $$;
revoke all on function public.zameel_release_policy(text,integer) from public;
grant execute on function public.zameel_release_policy(text,integer) to anon,authenticated;
create or replace function public.zameel_admin_release_policy(p_actor uuid,p_id uuid,p_allowed boolean,p_url text,p_note text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare item public.app_releases;begin
 if not coalesce(public.admin_has_permission('releases.manage',p_actor),false)
 or not coalesce(public.admin_can_access_screen('operations',p_actor),false) then raise exception 'release_not_authorized';end if;
 if p_allowed is null or coalesce(p_url,'') !~ '^https://[^ /]+' or length(p_url)>2048 or length(trim(coalesce(p_note,'')))<5 then raise exception 'invalid_release_policy';end if;
 perform pg_advisory_xact_lock(138,16);
 select * into item from public.app_releases where id=p_id for update;
 if item.id is null then raise exception 'release_not_found';end if;
 if not p_allowed and not exists(select 1 from public.app_releases where platform=item.platform and id<>p_id and is_allowed and is_active and download_url like 'https://%') then raise exception 'cannot_disable_last_release';end if;
 update public.app_releases set is_allowed=p_allowed,download_url=p_url where id=p_id;
 insert into public.admin_audit_logs(actor_id,action,resource_type,resource_id,details)
 values(p_actor,'release.policy','app_release',p_id::text,jsonb_build_object('allowed',p_allowed,'url',p_url,'note',p_note));
 return jsonb_build_object('saved',true);
end $$;
revoke all on function public.zameel_admin_release_policy(uuid,uuid,boolean,text,text) from public,anon,authenticated;
grant execute on function public.zameel_admin_release_policy(uuid,uuid,boolean,text,text) to service_role;
create or replace function public.zameel_admin_delete_post(p_actor uuid,p_post uuid,p_screen text,p_note text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare item public.posts; begin
 if p_screen not in ('users','promotions') or not coalesce(public.admin_can_access_screen(p_screen,p_actor),false)
 or not coalesce(public.admin_has_permission('content.moderate',p_actor),false) then raise exception 'post_delete_not_authorized';end if;
 if length(trim(coalesce(p_note,'')))<5 then raise exception 'reason_required';end if;
 select * into item from public.posts where id=p_post for update;
 if item.id is null then raise exception 'post_not_available';end if;
 if p_screen='promotions' and not exists(select 1 from public.zameel_post_promotions where post_id=p_post) then raise exception 'promotion_not_found';end if;
 update public.posts set is_hidden=true,is_deleted_by_admin=true where id=p_post;
 update public.zameel_post_promotions set status='cancelled',review_note=p_note where post_id=p_post and status in ('pending','approved');
 update public.zameel_post_reports set status='deleted',reviewed_by=p_actor,reviewed_at=now(),review_reason=p_note where post_id=p_post;
 insert into public.admin_audit_logs(actor_id,action,resource_type,resource_id,details)
 values(p_actor,'post.admin.delete','post',p_post::text,jsonb_build_object('owner',item.user_id,'screen',p_screen,'note',p_note));
 return jsonb_build_object('deleted',true,'post_id',p_post);
end $$;
revoke all on function public.zameel_admin_delete_post(uuid,uuid,text,text) from public,anon,authenticated;
grant execute on function public.zameel_admin_delete_post(uuid,uuid,text,text) to service_role;
notify pgrst,'reload schema';
commit;
