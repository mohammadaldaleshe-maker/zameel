begin;
insert into public.admin_permissions(permission_key,name_ar,category) values
 ('trust.read','عرض مباريات ثقة أم غدر والأرصدة','trust'),
 ('trust.manage','ضبط اللعبة وإلغاء مباراة مع إعادة العملات','trust'),
 ('trust.coins','تعديل العملات مع تسجيل السبب','trust'),
 ('trust.reports','معالجة بلاغات اللعبة','trust') on conflict(permission_key) do nothing;
insert into public.admin_role_permissions(role_id,permission_key)
 select r.id,p.permission_key from public.admin_roles r cross join public.admin_permissions p
 where r.role_key='super_admin' and p.category='trust' on conflict do nothing;
create or replace function public.zameel_trust_admin_require(p_actor uuid,p_permission text)
returns void language plpgsql security definer set search_path='' as $$ begin
 if not coalesce(public.admin_has_permission(p_permission,p_actor),false)
 or not coalesce(public.admin_can_access_screen('trust',p_actor),false) then raise exception 'trust_admin_not_authorized';end if;
end $$;
create or replace function public.zameel_trust_admin_config(p_actor uuid,p_initial integer,p_stake integer,p_reward integer)
returns void language plpgsql security definer set search_path='' as $$ begin
 perform public.zameel_trust_admin_require(p_actor,'trust.manage');
 if p_initial is null or p_stake is null or p_reward is null then raise exception 'invalid_settings';end if;
 update public.zameel_trust_settings set initial_coins=p_initial,stake=p_stake,reward_unit=p_reward where id;
 insert into public.admin_audit_logs(actor_id,action,resource_type,resource_id,details)
 values(p_actor,'trust.config','trust_settings','global',jsonb_build_object('initial_coins',p_initial,'stake',p_stake,'reward_unit',p_reward));
end $$;
create or replace function public.zameel_trust_admin_refund(p_actor uuid,p_match uuid,p_reason text)
returns void language plpgsql security definer set search_path='' as $$ begin
 perform public.zameel_trust_admin_require(p_actor,'trust.manage');
 if p_reason is null or length(trim(p_reason))<5 then raise exception 'reason_required';end if;
 if not exists(select 1 from public.zameel_trust_matches where id=p_match) then raise exception 'match_not_found';end if;
 perform public.zameel_trust_settle(p_match,'admin_refund');
 insert into public.admin_audit_logs(actor_id,action,resource_type,resource_id,details)
 values(p_actor,'trust.refund','trust_match',p_match::text,jsonb_build_object('reason',p_reason));
end $$;
create or replace function public.zameel_trust_admin_coins(p_actor uuid,p_user uuid,p_delta integer,p_reason text,p_request uuid)
returns numeric language plpgsql security definer set search_path='' as $$ declare result numeric;begin
 perform public.zameel_trust_admin_require(p_actor,'trust.coins');
 if p_request is null or p_delta is null or p_delta=0 or abs(p_delta::bigint)>1000000
 or p_reason is null or length(trim(p_reason))<5 then raise exception 'invalid_coin_adjustment';end if;
 perform public.zameel_coin_ensure(p_user);
 perform public.zameel_coin_change(p_user,p_delta,'admin:'||p_actor||':'||p_request,p_reason);
 insert into public.admin_audit_logs(actor_id,action,resource_type,resource_id,details)
 values(p_actor,'trust.coins','coin_wallet',p_user::text,jsonb_build_object('delta',p_delta,'reason',p_reason,'request',p_request));
 select balance into result from public.zameel_coin_wallets where user_id=p_user;return result;
end $$;
create or replace function public.zameel_trust_admin_report(p_actor uuid,p_report uuid,p_status text,p_reason text)
returns void language plpgsql security definer set search_path='' as $$ begin
 perform public.zameel_trust_admin_require(p_actor,'trust.reports');
 if p_status is null or p_status not in ('resolved','dismissed') or p_reason is null or length(trim(p_reason))<5 then raise exception 'invalid_report_review';end if;
 update public.zameel_trust_reports set status=p_status,review_note=p_reason,reviewed_by=p_actor where id=p_report;
 if not found then raise exception 'report_not_found';end if;
 insert into public.admin_audit_logs(actor_id,action,resource_type,resource_id,details)
 values(p_actor,'trust.report','trust_report',p_report::text,jsonb_build_object('status',p_status,'reason',p_reason));
end $$;
revoke all on function public.zameel_trust_admin_require(uuid,text),public.zameel_trust_admin_config(uuid,integer,integer,integer),
 public.zameel_trust_admin_refund(uuid,uuid,text),public.zameel_trust_admin_coins(uuid,uuid,integer,text,uuid),
 public.zameel_trust_admin_report(uuid,uuid,text,text) from public,anon,authenticated;
grant execute on function public.zameel_trust_admin_config(uuid,integer,integer,integer),
 public.zameel_trust_admin_refund(uuid,uuid,text),public.zameel_trust_admin_coins(uuid,uuid,integer,text,uuid),
 public.zameel_trust_admin_report(uuid,uuid,text,text) to service_role;
commit;
