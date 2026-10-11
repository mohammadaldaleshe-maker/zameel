-- Preserves report identities, lock order, notifications and original moderation transactions.
begin;
create or replace function public.zameel_review_post_report(
  p_report_id uuid,p_post_id uuid,p_decision text,p_reviewer_id uuid,p_reason text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare item public.zameel_post_reports%rowtype; new_status text; content_hidden boolean;
 post_owner uuid; was_deleted boolean; previous_hidden boolean; notification_id uuid;
begin
  if not public.admin_has_permission('reports.manage',p_reviewer_id)
     or not public.admin_can_access_screen('reports',p_reviewer_id) then raise exception 'report_review_not_authorized'; end if;
  if p_decision is null or p_decision not in ('hide','restore','dismiss','delete','review') or char_length(trim(coalesce(p_reason,'')))<5 then
    raise exception 'invalid_report_decision';
  end if;
  -- Every decision locks the post first, then its report; deletion can resolve sibling reports safely.
  select is_hidden,user_id,is_deleted_by_admin into content_hidden,post_owner,was_deleted
    from public.posts where id=p_post_id for update;
  if not found then raise exception 'post_not_available'; end if;
  select * into item from public.zameel_post_reports where id=p_report_id for update;
  if not found or item.post_id<>p_post_id then raise exception 'report_not_found'; end if;
  if was_deleted then
    if p_decision='delete' and item.status='deleted' then return jsonb_build_object('status','deleted','is_hidden',true,'already_decided',true); end if;
    raise exception 'post_already_deleted';
  end if;
 if not public.zameel_admin_owner_154(p_reviewer_id) then raise exception 'owner_only';end if;
 if item.status not in ('open','in_review') and p_decision<>'restore' then
  if (p_decision='hide' and item.status='hidden') or (p_decision='dismiss' and item.status='dismissed') then
   return jsonb_build_object('status',item.status,'is_hidden',content_hidden,'already_decided',true);
  end if;
  raise exception 'report_already_resolved';
 end if;
 if p_decision='review' and item.status='in_review' then return jsonb_build_object('status','in_review','is_hidden',content_hidden,'already_decided',true);end if;
 if p_decision='restore' and not content_hidden then return jsonb_build_object('status',item.status,'is_hidden',false,'already_decided',true);end if;
  previous_hidden=content_hidden;
  if p_decision='review' then
    if item.status not in ('open','in_review') then raise exception 'report_already_resolved'; end if;
    update public.zameel_post_reports set status='in_review',reviewed_by=p_reviewer_id,reviewed_at=null,review_reason=p_reason where id=item.id;
    insert into public.admin_audit_logs(actor_id,action,resource_type,resource_id,details)
    values(p_reviewer_id,'post.report.review','post',item.post_id::text,jsonb_build_object('report_id',item.id,'reason',p_reason));
    return jsonb_build_object('status','in_review','is_hidden',content_hidden);
  end if;
  new_status=case when p_decision='delete' then 'deleted' when p_decision='hide' then 'hidden' else 'dismissed' end;
  if p_decision='delete' then
    update public.posts set is_hidden=true,is_deleted_by_admin=true where id=item.post_id;
    content_hidden=true;
    update public.zameel_post_reports set status='deleted',reviewed_by=p_reviewer_id,reviewed_at=now(),review_reason=p_reason where post_id=item.post_id;
  end if;
  if p_decision in ('hide','restore') then
    content_hidden=(p_decision='hide');
    update public.posts set is_hidden=content_hidden where id=item.post_id;
    insert into public.admin_resource_states(resource_type,resource_id,state,reason,updated_by,updated_at)
    values('post',item.post_id::text,case when content_hidden then 'hidden' else 'visible' end,p_reason,p_reviewer_id,now())
    on conflict(resource_type,resource_id) do update set state=excluded.state,reason=excluded.reason,
      updated_by=excluded.updated_by,updated_at=excluded.updated_at;
  end if;
  -- Dismissal alone never unhides content moderated elsewhere.
  update public.zameel_post_reports set status=new_status,reviewed_by=p_reviewer_id,
    reviewed_at=now(),review_reason=p_reason where id=item.id;
  -- Notification and moderation commit together. Retries do not notify again when visibility is unchanged.
  if p_decision='delete' or (p_decision='hide' and not previous_hidden) or (p_decision='restore' and previous_hidden) then
    insert into public.notifications(user_id,actor_id,type,title_ar,title_en,body_ar,body_en,data,is_read)
    values(post_owner,null,'admin_post_moderation',
      case p_decision when 'delete' then 'حذفت إدارة زميل منشورك' when 'hide' then 'أخفت إدارة زميل منشورك' else 'أعادت إدارة زميل منشورك' end,
      case p_decision when 'delete' then 'Zameel removed your post' when 'hide' then 'Zameel hid your post' else 'Zameel restored your post' end,
      'السبب: '||p_reason,'Reason: '||p_reason,
      jsonb_build_object('moderated_post_id',item.post_id,'decision',p_decision,'report_id',item.id,'reason',p_reason),false)
    returning id into notification_id;
  end if;
  insert into public.admin_audit_logs(actor_id,action,resource_type,resource_id,details)
  values(p_reviewer_id,'post.report.'||p_decision,'post',item.post_id::text,
    jsonb_build_object('report_id',item.id,'reason',p_reason,'previous_status',item.status));
  return jsonb_build_object('status',new_status,'is_hidden',content_hidden,'notification_id',notification_id);
end $$;
create or replace function public.zameel_review_media_report(
 p_content_type text,p_report_id uuid,p_content_id uuid,p_decision text,p_reviewer_id uuid,p_reason text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare target_table text; report_table text; target_key text; item record; owner_id uuid;
 content_hidden boolean; was_hidden boolean; removed boolean; expires timestamptz; state text; notification_id uuid;
begin
 if not public.admin_has_permission('reports.manage',p_reviewer_id) or not public.admin_can_access_screen('reports',p_reviewer_id) then raise exception 'report_review_not_authorized'; end if;
 if p_content_type is null or p_content_type not in ('clip','story') or p_decision is null or p_decision not in ('review','hide','restore','dismiss','delete') or char_length(trim(coalesce(p_reason,'')))<5 then raise exception 'invalid_report_decision'; end if;
 target_table=case p_content_type when 'clip' then 'clips' else 'social_stories' end;
 report_table='zameel_'||p_content_type||'_reports';target_key=p_content_type||'_id';
 execute format('select user_id,is_hidden,is_deleted_by_admin from public.%I where id=$1 for update',target_table) into owner_id,content_hidden,removed using p_content_id;
 if owner_id is null then raise exception 'content_not_available'; end if;
 execute format('select id,status from public.%I where id=$1 and %I=$2 for update',report_table,target_key) into item using p_report_id,p_content_id;
 if item.id is null then raise exception 'report_not_found'; end if;
 if removed then
  if p_decision='delete' and item.status='deleted' then return jsonb_build_object('status','deleted','is_hidden',true,'already_decided',true); end if;
  raise exception 'content_already_deleted';
 end if;
 if not public.zameel_admin_owner_154(p_reviewer_id) then raise exception 'owner_only';end if;
 if item.status not in ('open','in_review') and p_decision<>'restore' then
  if (p_decision='hide' and item.status='hidden') or (p_decision='dismiss' and item.status='dismissed') then
   return jsonb_build_object('status',item.status,'is_hidden',content_hidden,'already_decided',true);
  end if;
  raise exception 'report_already_resolved';
 end if;
 if p_decision='review' and item.status='in_review' then return jsonb_build_object('status','in_review','is_hidden',content_hidden,'already_decided',true);end if;
 if p_decision='restore' and not content_hidden then return jsonb_build_object('status',item.status,'is_hidden',false,'already_decided',true);end if;
 if p_decision='review' and item.status not in ('open','in_review') then raise exception 'report_already_resolved'; end if;
 if p_decision='restore' and p_content_type='story' then
  select expires_at into expires from public.social_stories where id=p_content_id;
  if expires<=now() then raise exception 'story_expired_cannot_restore'; end if;
 end if;
 was_hidden=content_hidden;
 state=case p_decision when 'review' then 'in_review' when 'delete' then 'deleted' when 'hide' then 'hidden' else 'dismissed' end;
 if p_decision='delete' then
  execute format('update public.%I set is_hidden=true,is_deleted_by_admin=true where id=$1',target_table) using p_content_id;
  content_hidden=true;
  execute format('update public.%I set status=''deleted'',reviewed_by=$2,reviewed_at=now(),review_reason=$3 where %I=$1',report_table,target_key) using p_content_id,p_reviewer_id,p_reason;
 elsif p_decision in ('hide','restore') then
  content_hidden=p_decision='hide';
  execute format('update public.%I set is_hidden=$2 where id=$1',target_table) using p_content_id,content_hidden;
 end if;
 execute format('update public.%I set status=$2,reviewed_by=$3,reviewed_at=$4,review_reason=$5 where id=$1',report_table)
 using p_report_id,state,p_reviewer_id,case when p_decision='review' then null::timestamptz else now() end,p_reason;
 if p_decision in ('delete','hide','restore') then
  insert into public.admin_resource_states(resource_type,resource_id,state,reason,updated_by,updated_at)
  values(p_content_type,p_content_id::text,case when content_hidden then 'hidden' else 'visible' end,p_reason,p_reviewer_id,now())
  on conflict(resource_type,resource_id) do update set state=excluded.state,reason=excluded.reason,updated_by=excluded.updated_by,updated_at=excluded.updated_at;
 end if;
 if p_decision='delete' or (p_decision='hide' and not was_hidden) or (p_decision='restore' and was_hidden) then
  insert into public.notifications(user_id,actor_id,type,title_ar,title_en,body_ar,body_en,data,is_read)
  values(owner_id,null,'admin_content_moderation',
    'قرار إدارة زميل بشأن '||case p_content_type when 'story' then 'حالتك' else 'الكليبس الخاص بك' end,
    'Zameel moderation decision for your '||p_content_type,
    case p_decision when 'delete' then 'تم حذف المحتوى. ' when 'hide' then 'تم إخفاء المحتوى. ' else 'تمت استعادة المحتوى. ' end||'السبب: '||p_reason,
    'Decision: '||p_decision||'. Reason: '||p_reason,
    jsonb_build_object('content_type',p_content_type,'moderated_content_id',p_content_id,'decision',p_decision,'report_id',p_report_id,'reason',p_reason),false)
  returning id into notification_id;
 end if;
 insert into public.admin_audit_logs(actor_id,action,resource_type,resource_id,details)
 values(p_reviewer_id,p_content_type||'.report.'||p_decision,p_content_type,p_content_id::text,jsonb_build_object('report_id',p_report_id,'reason',p_reason,'previous_status',item.status));
 return jsonb_build_object('status',state,'is_hidden',content_hidden,'notification_id',notification_id);
end $$;
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
 if not public.zameel_admin_owner_154(p_reviewer_id) then raise exception 'owner_only';end if;
 if old_status not in ('open','in_review') and p_decision<>'restore' then
  if (p_decision='hide' and old_status='hidden') or (p_decision='dismiss' and old_status='dismissed') then
   return jsonb_build_object('status',old_status,'is_hidden',hidden,'already_decided',true);
  end if;
  raise exception 'report_already_resolved';
 end if;
 if p_decision='review' and old_status='in_review' then return jsonb_build_object('status','in_review','is_hidden',hidden,'already_decided',true);end if;
 if p_decision='restore' and not hidden then return jsonb_build_object('status',old_status,'is_hidden',false,'already_decided',true);end if;
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
create or replace function public.zameel_review_legacy_report(
 p_type text,p_target_id uuid,p_reporter_id uuid,p_decision text,p_reviewer_id uuid,p_reason text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare target_table text; report_table text; target_column text; content_hidden boolean; old_status text; new_status text;
begin
 if not public.admin_has_permission('reports.manage',p_reviewer_id) or not public.admin_can_access_screen('reports',p_reviewer_id) then raise exception 'report_review_not_authorized'; end if;
 if p_type not in ('radio','college') or p_type is null or p_decision not in ('review','hide','restore','dismiss') or p_decision is null or char_length(trim(coalesce(p_reason,'')))<5 then raise exception 'invalid_report_decision'; end if;
 target_table=case p_type when 'radio' then 'zameel_radio_posts' else 'zameel_college_entries' end;
 report_table=case p_type when 'radio' then 'zameel_radio_reports' else 'zameel_college_reports' end;
 target_column=case p_type when 'radio' then 'post_id' else 'entry_id' end;
 execute format('select is_hidden from public.%I where id=$1 for update',target_table) into content_hidden using p_target_id;
 if content_hidden is null then raise exception 'content_not_available'; end if;
 execute format('select status from public.%I where %I=$1 and reporter_id=$2 for update',report_table,target_column) into old_status using p_target_id,p_reporter_id;
 if old_status is null then raise exception 'report_not_found'; end if;
 if not public.zameel_admin_owner_154(p_reviewer_id) then raise exception 'owner_only';end if;
 if old_status not in ('open','in_review') and p_decision<>'restore' then
  if (p_decision='hide' and old_status='hidden') or (p_decision='dismiss' and old_status='dismissed') then
   return jsonb_build_object('status',old_status,'is_hidden',content_hidden,'already_decided',true);
  end if;
  raise exception 'report_already_resolved';
 end if;
 if p_decision='review' and old_status='in_review' then return jsonb_build_object('status','in_review','is_hidden',content_hidden,'already_decided',true);end if;
 if p_decision='restore' and not content_hidden then return jsonb_build_object('status',old_status,'is_hidden',false,'already_decided',true);end if;
 if p_decision='review' and old_status not in ('open','in_review') then raise exception 'report_already_resolved'; end if;
 new_status=case p_decision when 'review' then 'in_review' when 'hide' then 'hidden' else 'dismissed' end;
 if p_decision in ('hide','restore') then
  content_hidden=p_decision='hide';
  if p_type='radio' then update public.zameel_radio_posts set is_hidden=content_hidden,moderation_status=case when content_hidden then 'removed' else 'visible' end where id=p_target_id;
  else update public.zameel_college_entries set is_hidden=content_hidden where id=p_target_id; end if;
  insert into public.admin_resource_states(resource_type,resource_id,state,reason,updated_by,updated_at)
  values(p_type,p_target_id::text,case when content_hidden then 'hidden' else 'visible' end,p_reason,p_reviewer_id,now())
  on conflict(resource_type,resource_id) do update set state=excluded.state,reason=excluded.reason,updated_by=excluded.updated_by,updated_at=excluded.updated_at;
 end if;
 execute format('update public.%I set status=$3,reviewed_by=$4,reviewed_at=$5,review_reason=$6 where %I=$1 and reporter_id=$2',report_table,target_column)
 using p_target_id,p_reporter_id,new_status,p_reviewer_id,case when p_decision='review' then null::timestamptz else now() end,p_reason;
 insert into public.admin_audit_logs(actor_id,action,resource_type,resource_id,details)
 values(p_reviewer_id,p_type||'.report.'||p_decision,p_type,p_target_id::text,jsonb_build_object('reporter_id',p_reporter_id,'reason',p_reason));
 return jsonb_build_object('status',new_status,'is_hidden',content_hidden);
end $$;
revoke all on function public.zameel_review_post_report(uuid,uuid,text,uuid,text),public.zameel_review_media_report(text,uuid,uuid,text,uuid,text),public.zameel_review_radio_report(uuid,uuid,text,uuid,text),public.zameel_review_legacy_report(text,uuid,uuid,text,uuid,text) from public,anon,authenticated;
grant execute on function public.zameel_review_post_report(uuid,uuid,text,uuid,text),public.zameel_review_media_report(text,uuid,uuid,text,uuid,text),public.zameel_review_radio_report(uuid,uuid,text,uuid,text),public.zameel_review_legacy_report(text,uuid,uuid,text,uuid,text) to service_role;
notify pgrst,'reload schema';
commit;
