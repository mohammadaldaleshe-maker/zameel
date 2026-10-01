-- 131: install once before deploying/building. No existing mute is removed here.
begin;
grant select on public.zameel_radio_posts to authenticated;
drop trigger if exists zameel_radio_two_reports on public.zameel_radio_reports;
alter table public.zameel_radio_posts add column if not exists is_deleted_by_admin boolean not null default false;
drop policy if exists radio_deleted_visibility_guard on public.zameel_radio_posts;
create policy radio_deleted_visibility_guard on public.zameel_radio_posts as restrictive for select to authenticated,anon using(not is_deleted_by_admin);
create or replace function public.zameel_guard_radio_deleted_flag() returns trigger
language plpgsql security invoker set search_path='' as $$
begin
 if coalesce(auth.role(),'')='service_role' or (auth.role() is null and current_user='postgres') then return new; end if;
 if TG_OP='INSERT' then
  if new.is_deleted_by_admin then raise exception 'radio_moderation_not_authorized'; end if;
 elsif new.is_deleted_by_admin is distinct from old.is_deleted_by_admin then raise exception 'radio_moderation_not_authorized'; end if;
 return new;
end $$;
revoke all on function public.zameel_guard_radio_deleted_flag() from public,anon,authenticated;
drop trigger if exists zameel_guard_radio_deleted_flag on public.zameel_radio_posts;
create trigger zameel_guard_radio_deleted_flag before insert or update of is_deleted_by_admin on public.zameel_radio_posts for each row execute function public.zameel_guard_radio_deleted_flag();
create or replace function public.zameel_admin_unmute_radio(p_user_id uuid,p_reviewer_id uuid,p_reason text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare removed integer;
begin
 if not public.admin_has_permission('reports.manage',p_reviewer_id) or not public.admin_can_access_screen('reports',p_reviewer_id) then raise exception 'radio_unmute_not_authorized'; end if;
 if p_user_id is null or char_length(trim(coalesce(p_reason,'')))<5 then raise exception 'invalid_unmute_request'; end if;
 delete from public.zameel_radio_admin_mutes where user_id=p_user_id;
 get diagnostics removed=row_count;
 insert into public.admin_audit_logs(actor_id,action,resource_type,resource_id,details)
 values(p_reviewer_id,'radio.unmute','user',p_user_id::text,jsonb_build_object('reason',p_reason,'mute_removed',removed>0));
 return jsonb_build_object('unmuted',true,'already_unmuted',removed=0);
end $$;
revoke all on function public.zameel_admin_unmute_radio(uuid,uuid,text) from public,anon,authenticated;
grant execute on function public.zameel_admin_unmute_radio(uuid,uuid,text) to service_role;
create or replace function public.zameel_review_radio_report(p_post_id uuid,p_reporter_id uuid,p_decision text,p_reviewer_id uuid,p_reason text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare owner_id uuid; old_status text; state text; hidden boolean; was_hidden boolean; removed boolean; expiry timestamptz; notification_id uuid;
begin
 if not public.admin_has_permission('reports.manage',p_reviewer_id) or not public.admin_can_access_screen('reports',p_reviewer_id) then raise exception 'report_review_not_authorized'; end if;
 if p_decision is null or p_decision not in ('review','hide','restore','dismiss','delete') or char_length(trim(coalesce(p_reason,'')))<5 then raise exception 'invalid_report_decision'; end if;
 select user_id,is_hidden,is_deleted_by_admin,expires_at into owner_id,hidden,removed,expiry from public.zameel_radio_posts where id=p_post_id for update;
 if owner_id is null then raise exception 'content_not_available'; end if;
 select status into old_status from public.zameel_radio_reports where post_id=p_post_id and reporter_id=p_reporter_id for update;
 if old_status is null then raise exception 'report_not_found'; end if;
 if removed then
  if p_decision='delete' and old_status='deleted' then return jsonb_build_object('status','deleted','already_decided',true,'is_hidden',true); end if;
  raise exception 'content_already_deleted';
 end if;
 if p_decision='review' and old_status not in ('open','in_review') then raise exception 'report_already_resolved'; end if;
 if p_decision='restore' and expiry<=now() then raise exception 'radio_expired_cannot_restore'; end if;
 was_hidden=hidden;
 state=case p_decision when 'review' then 'in_review' when 'hide' then 'hidden' when 'delete' then 'deleted' else 'dismissed' end;
 if p_decision in ('hide','restore','delete') then
  hidden=p_decision<>'restore';
  update public.zameel_radio_posts set is_hidden=hidden,is_deleted_by_admin=(p_decision='delete'),moderation_status=case when hidden then 'removed' else 'visible' end where id=p_post_id;
  insert into public.admin_resource_states(resource_type,resource_id,state,reason,updated_by,updated_at)
  values('radio',p_post_id::text,case when hidden then 'hidden' else 'visible' end,p_reason,p_reviewer_id,now())
  on conflict(resource_type,resource_id) do update set state=excluded.state,reason=excluded.reason,updated_by=excluded.updated_by,updated_at=excluded.updated_at;
 end if;
 update public.zameel_radio_reports set status=state,reviewed_by=p_reviewer_id,reviewed_at=case when p_decision='review' then null else now() end,review_reason=p_reason
 where post_id=p_post_id and (reporter_id=p_reporter_id or p_decision='delete');
 if p_decision='delete' or (p_decision='hide' and not was_hidden) or (p_decision='restore' and was_hidden) then
  insert into public.notifications(user_id,actor_id,type,title_ar,title_en,body_ar,body_en,data,is_read)
  values(owner_id,null,'admin_content_moderation','قرار إدارة زميل بشأن تسجيلك','Zameel radio moderation decision',
  case p_decision when 'delete' then 'تم حذف تسجيلك. ' when 'hide' then 'تم إخفاء تسجيلك. ' else 'تمت استعادة تسجيلك. ' end||'السبب: '||p_reason,
  'Decision: '||p_decision||'. Reason: '||p_reason,jsonb_build_object('content_type','radio','moderated_content_id',p_post_id,'decision',p_decision,'reason',p_reason),false) returning id into notification_id;
 end if;
 insert into public.admin_audit_logs(actor_id,action,resource_type,resource_id,details)
 values(p_reviewer_id,'radio.report.'||p_decision,'radio',p_post_id::text,jsonb_build_object('reporter_id',p_reporter_id,'reason',p_reason));
 return jsonb_build_object('status',state,'is_hidden',hidden,'notification_id',notification_id);
end $$;
revoke all on function public.zameel_review_radio_report(uuid,uuid,text,uuid,text) from public,anon,authenticated;
grant execute on function public.zameel_review_radio_report(uuid,uuid,text,uuid,text) to service_role;
notify pgrst,'reload schema';
commit;
