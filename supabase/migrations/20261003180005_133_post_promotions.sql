-- Public-post promotion requests. Existing post RLS remains authoritative.
begin;
insert into public.feature_flags(feature_key,name_ar,description,is_enabled,display_mode,rollout_percent,scope_type,scope_value)
values('post_promotions','ترويج المنشورات العامة','طلبات الترويج والمراجعة الإدارية',true,'enabled',100,'global','*') on conflict(feature_key) do nothing;
insert into public.admin_permissions(permission_key,name_ar,category) values
('promotions.read','عرض طلبات ترويج المنشورات','promotions'),('promotions.manage','مراجعة وإيقاف ترويج المنشورات','promotions') on conflict do nothing;
insert into public.admin_role_permissions(role_id,permission_key)
select r.id,p.permission_key from public.admin_roles r cross join public.admin_permissions p where r.role_key='super_admin' and p.category='promotions' on conflict do nothing;
create table if not exists public.zameel_post_promotions(
 id uuid primary key default gen_random_uuid(),post_id uuid not null references public.posts(id) on delete cascade,
 owner_id uuid not null references public.users(id) on delete cascade,
 days integer not null check(days between 1 and 30),notes text not null default '' check(length(notes)<=1000),
 status text not null default 'pending' check(status in ('pending','approved','rejected','cancelled','expired')),
 starts_at timestamptz,ends_at timestamptz,reviewed_by uuid references public.users(id),review_note text,
 created_at timestamptz not null default now(),updated_at timestamptz not null default now()
);
create unique index if not exists promotion_one_active_post on public.zameel_post_promotions(post_id) where status in ('pending','approved');
alter table public.zameel_post_promotions enable row level security;
revoke all on public.zameel_post_promotions from public,anon,authenticated;
grant select on public.zameel_post_promotions to authenticated;
grant all on public.zameel_post_promotions to service_role;
drop policy if exists promotion_visible on public.zameel_post_promotions;
create policy promotion_visible on public.zameel_post_promotions for select to authenticated using(owner_id=auth.uid() or
(status='approved' and starts_at<=now() and ends_at>now() and exists(select 1 from public.posts p where p.id=post_id and p.audience='public' and not coalesce(p.is_hidden,false))));
create or replace function public.zameel_request_promotion(p_post uuid,p_days integer,p_notes text default '') returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor uuid:=auth.uid(); result public.zameel_post_promotions;
begin
 if actor is null or not coalesce(public.zameel_account_can_write(),false) then raise exception 'promotion_account_unavailable';end if;
 if not exists(select 1 from public.feature_flags where feature_key='post_promotions' and scope_type='global' and scope_value='*' and is_enabled and display_mode='enabled' and rollout_percent=100) then raise exception 'promotion_temporarily_unavailable';end if;
 if p_days is null or p_days not between 1 and 30 or length(coalesce(p_notes,''))>1000 then raise exception 'invalid_promotion_request';end if;
 perform 1 from public.posts where id=p_post and user_id=actor and audience='public' and not coalesce(is_hidden,false) for update;
 if not found then raise exception 'own_public_post_required';end if;
 update public.zameel_post_promotions set status='expired',updated_at=now() where post_id=p_post and status='approved' and ends_at<=now();
 select * into result from public.zameel_post_promotions where post_id=p_post and status in ('pending','approved');
 if result.id is null then
 insert into public.zameel_post_promotions(post_id,owner_id,days,notes) values(p_post,actor,p_days,trim(coalesce(p_notes,''))) returning * into result;
 end if;
 return jsonb_build_object('id',result.id,'status',result.status,'days',result.days,'ends_at',result.ends_at);
end $$;
create or replace function public.zameel_review_promotion(p_actor uuid,p_id uuid,p_decision text,p_note text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare r public.zameel_post_promotions; target uuid; target_state text;
begin
 if not coalesce(public.admin_has_permission('promotions.manage',p_actor),false) or not coalesce(public.admin_can_access_screen('promotions',p_actor),false) then raise exception 'promotion_review_not_authorized';end if;
 if p_decision is null or p_decision not in ('approve','reject','cancel') or length(trim(coalesce(p_note,'')))<5 then raise exception 'invalid_promotion_review';end if;
 select post_id into target from public.zameel_post_promotions where id=p_id;
 perform 1 from public.posts where id=target for update;
 select * into r from public.zameel_post_promotions where id=p_id for update;
 if r.id is null then raise exception 'promotion_not_found';end if;
 target_state:=case p_decision when 'approve' then 'approved' when 'reject' then 'rejected' else 'cancelled' end;
 if r.status=target_state then return jsonb_build_object('status',r.status);end if;
 if (p_decision in ('approve','reject') and r.status<>'pending') or (p_decision='cancel' and r.status not in ('pending','approved')) then raise exception 'promotion_already_decided';end if;
 if p_decision='approve' and (not exists(select 1 from public.posts where id=r.post_id and user_id=r.owner_id and audience='public' and not coalesce(is_hidden,false))
 or exists(select 1 from public.admin_user_states where user_id=r.owner_id and status in ('blocked','suspended'))
 or not exists(select 1 from public.feature_flags where feature_key='post_promotions' and is_enabled and display_mode='enabled' and rollout_percent=100 and scope_type='global' and scope_value='*')) then raise exception 'public_post_unavailable';end if;
 update public.zameel_post_promotions set status=target_state,reviewed_by=p_actor,review_note=trim(p_note),updated_at=now(),
 starts_at=case when p_decision='approve' then now() else starts_at end,
 ends_at=case when p_decision='approve' then now()+make_interval(days=>r.days) else ends_at end where id=p_id;
 insert into public.admin_audit_logs(actor_id,action,resource_type,resource_id,details)
 values(p_actor,'promotion.'||p_decision,'post_promotion',p_id::text,jsonb_build_object('note',p_note,'post_id',r.post_id));
 return jsonb_build_object('status',target_state);
end $$;
create or replace function public.zameel_promotions_enabled() returns boolean language sql stable security definer set search_path='' as $$
 select auth.uid() is not null and exists(select 1 from public.feature_flags where feature_key='post_promotions' and is_enabled and display_mode='enabled' and rollout_percent=100 and scope_type='global' and scope_value='*')
$$;
revoke all on function public.zameel_promotions_enabled() from public,anon;
grant execute on function public.zameel_promotions_enabled() to authenticated;
create or replace function public.zameel_promoted_post_ids() returns table(post_id uuid,ends_at timestamptz)
language sql security invoker set search_path='' as $$
 select x.post_id,x.ends_at from public.zameel_post_promotions x join public.posts p on p.id=x.post_id
 where auth.uid() is not null and x.status='approved' and x.starts_at<=now() and x.ends_at>now() and p.audience='public' and not coalesce(p.is_hidden,false)
 and public.zameel_promotions_enabled()
 order by x.starts_at desc limit 5
$$;
create or replace function public.zameel_cancel_ineligible_promotions() returns trigger language plpgsql security definer set search_path='' as $$ begin
 if new.audience is distinct from 'public' or coalesce(new.is_hidden,false) then
 update public.zameel_post_promotions set status='cancelled',review_note='post_visibility_changed',updated_at=now() where post_id=new.id and status in ('pending','approved');end if;
 return new;
end $$;
drop trigger if exists cancel_ineligible_promotions on public.posts;
create trigger cancel_ineligible_promotions after update of audience,is_hidden on public.posts for each row execute function public.zameel_cancel_ineligible_promotions();
revoke all on function public.zameel_request_promotion(uuid,integer,text),public.zameel_review_promotion(uuid,uuid,text,text),public.zameel_promoted_post_ids(),public.zameel_cancel_ineligible_promotions() from public,anon,authenticated;
grant execute on function public.zameel_request_promotion(uuid,integer,text),public.zameel_promoted_post_ids() to authenticated;
grant execute on function public.zameel_review_promotion(uuid,uuid,text,text) to service_role;
commit;
