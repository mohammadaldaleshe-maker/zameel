-- Install once after 129, before deploying the new console or building the app.
begin;
do $$ begin
 if to_regprocedure('public.can_view_story(uuid,uuid)') is null or to_regprocedure('public.can_view_clip(uuid,uuid)') is null
 or to_regprocedure('public.zameel_report_counts(uuid,uuid[])') is null then raise exception 'reporting_130_prerequisite_missing'; end if;
end $$;
alter table public.clips add column if not exists is_hidden boolean not null default false;
alter table public.clips add column if not exists is_deleted_by_admin boolean not null default false;
drop policy if exists reporting_media_visibility_guard on public.clips;
create policy reporting_media_visibility_guard on public.clips as restrictive for select to authenticated,anon using(not is_hidden and not is_deleted_by_admin);
alter table public.social_stories add column if not exists is_hidden boolean not null default false;
alter table public.social_stories add column if not exists is_deleted_by_admin boolean not null default false;
drop policy if exists reporting_media_visibility_guard on public.social_stories;
create policy reporting_media_visibility_guard on public.social_stories as restrictive for select to authenticated,anon using(not is_hidden and not is_deleted_by_admin);
create or replace function public.zameel_guard_media_moderation() returns trigger
language plpgsql security invoker set search_path='' as $$
begin
 if coalesce(auth.role(),'')='service_role' or (auth.role() is null and current_user='postgres') then return new; end if;
 if TG_OP='INSERT' then
  if new.is_hidden or new.is_deleted_by_admin then raise exception 'media_moderation_not_authorized'; end if;
 elsif new.is_hidden is distinct from old.is_hidden or new.is_deleted_by_admin is distinct from old.is_deleted_by_admin then
  raise exception 'media_moderation_not_authorized';
 end if;
 return new;
end $$;
revoke all on function public.zameel_guard_media_moderation() from public,anon,authenticated;
drop trigger if exists zameel_guard_media_moderation on public.clips;
create trigger zameel_guard_media_moderation before insert or update of is_hidden,is_deleted_by_admin on public.clips
for each row execute function public.zameel_guard_media_moderation();
drop trigger if exists zameel_guard_media_moderation on public.social_stories;
create trigger zameel_guard_media_moderation before insert or update of is_hidden,is_deleted_by_admin on public.social_stories
for each row execute function public.zameel_guard_media_moderation();
do $install$
declare kind text; original text; backup text; definition text; arg_names text[]; target_table text;
begin
 foreach kind in array array['story','clip'] loop
  original='can_view_'||kind;backup='zameel_can_view_'||kind||'_before130';
  if to_regprocedure('public.'||backup||'(uuid,uuid)') is null then
   definition=pg_get_functiondef(to_regprocedure('public.'||original||'(uuid,uuid)'));
   if position('FUNCTION public.'||original||'(' in definition)=0 then raise exception 'unsupported_visibility_function_definition'; end if;
   execute replace(definition,'FUNCTION public.'||original||'(','FUNCTION public.'||backup||'(');
  end if;
  execute format('revoke all on function public.%I(uuid,uuid) from public,anon,authenticated',backup);
  select proargnames into arg_names from pg_proc where oid=to_regprocedure('public.'||original||'(uuid,uuid)');
  if coalesce(array_length(arg_names,1),0)<2 then raise exception 'visibility_argument_names_missing'; end if;
  target_table=case kind when 'clip' then 'clips' else 'social_stories' end;
  execute format('create or replace function public.%I(%I uuid,%I uuid) returns boolean language sql stable security definer set search_path='''' as $guard$ select exists(select 1 from public.%I x where x.id=$2 and not x.is_hidden and not x.is_deleted_by_admin) and public.%I($1,$2) $guard$',original,arg_names[1],arg_names[2],target_table,backup);
  execute format('revoke all on function public.%I(uuid,uuid) from public,anon',original);
  execute format('grant execute on function public.%I(uuid,uuid) to authenticated',original);
 end loop;
end $install$;
create table if not exists public.zameel_clip_reports(
 id uuid primary key default gen_random_uuid(),
 clip_id uuid not null references public.clips(id) on delete cascade,
 reporter_id uuid not null references public.users(id) on delete cascade,
 reported_user_id uuid references public.users(id) on delete set null,
 category text not null check(category in ('spam','harassment','hate','sexual','violence','privacy','other')),
 reason text not null default '' check(char_length(reason)<=1000),
 status text not null default 'open' check(status in ('open','in_review','hidden','dismissed','deleted')),
 created_at timestamptz not null default now(),reviewed_at timestamptz,
 reviewed_by uuid references public.users(id) on delete set null,review_reason text,
 unique(clip_id,reporter_id)
);
create index if not exists zameel_clip_reports_status_idx on public.zameel_clip_reports(status);
create index if not exists zameel_clip_reports_owner_idx on public.zameel_clip_reports(reported_user_id,created_at desc);
create index if not exists zameel_clip_reports_reporter_idx on public.zameel_clip_reports(reporter_id,created_at desc);
alter table public.zameel_clip_reports enable row level security;
revoke all on public.zameel_clip_reports from public,anon,authenticated;
grant select on public.zameel_clip_reports to authenticated;
grant insert(clip_id,reporter_id,category,reason) on public.zameel_clip_reports to authenticated;
grant all on public.zameel_clip_reports to service_role;
drop policy if exists media_report_own_read on public.zameel_clip_reports;
create policy media_report_own_read on public.zameel_clip_reports for select to authenticated using(reporter_id=auth.uid());
drop policy if exists media_report_insert on public.zameel_clip_reports;
create policy media_report_insert on public.zameel_clip_reports for insert to authenticated with check(
 reporter_id=auth.uid() and status='open' and reviewed_at is null and reviewed_by is null
 and public.zameel_account_can_write() and exists(select 1 from public.clips x where x.id=clip_id
 and x.user_id=reported_user_id and x.user_id<>auth.uid() and not x.is_hidden and not x.is_deleted_by_admin)
);
create table if not exists public.zameel_story_reports(
 id uuid primary key default gen_random_uuid(),
 story_id uuid not null references public.social_stories(id) on delete cascade,
 reporter_id uuid not null references public.users(id) on delete cascade,
 reported_user_id uuid references public.users(id) on delete set null,
 category text not null check(category in ('spam','harassment','hate','sexual','violence','privacy','other')),
 reason text not null default '' check(char_length(reason)<=1000),
 status text not null default 'open' check(status in ('open','in_review','hidden','dismissed','deleted')),
 created_at timestamptz not null default now(),reviewed_at timestamptz,
 reviewed_by uuid references public.users(id) on delete set null,review_reason text,
 unique(story_id,reporter_id)
);
create index if not exists zameel_story_reports_status_idx on public.zameel_story_reports(status);
create index if not exists zameel_story_reports_owner_idx on public.zameel_story_reports(reported_user_id,created_at desc);
create index if not exists zameel_story_reports_reporter_idx on public.zameel_story_reports(reporter_id,created_at desc);
alter table public.zameel_story_reports enable row level security;
revoke all on public.zameel_story_reports from public,anon,authenticated;
grant select on public.zameel_story_reports to authenticated;
grant insert(story_id,reporter_id,category,reason) on public.zameel_story_reports to authenticated;
grant all on public.zameel_story_reports to service_role;
drop policy if exists media_report_own_read on public.zameel_story_reports;
create policy media_report_own_read on public.zameel_story_reports for select to authenticated using(reporter_id=auth.uid());
drop policy if exists media_report_insert on public.zameel_story_reports;
create policy media_report_insert on public.zameel_story_reports for insert to authenticated with check(
 reporter_id=auth.uid() and status='open' and reviewed_at is null and reviewed_by is null
 and public.zameel_account_can_write() and exists(select 1 from public.social_stories x where x.id=story_id
 and x.user_id=reported_user_id and x.user_id<>auth.uid() and not x.is_hidden and not x.is_deleted_by_admin)
);
create or replace function public.zameel_guard_media_report() returns trigger
language plpgsql security definer set search_path='' as $$
declare target uuid; content_id uuid;
begin
 if auth.uid() is null or new.reporter_id<>auth.uid() or not public.zameel_account_can_write() then raise exception 'account_cannot_report'; end if;
 if TG_TABLE_NAME='zameel_clip_reports' then
  content_id=new.clip_id;select user_id into target from public.clips where id=content_id;
 elsif TG_TABLE_NAME='zameel_story_reports' then
  content_id=new.story_id;select user_id into target from public.social_stories where id=content_id;
 else raise exception 'invalid_content_type'; end if;
 if target is null or target=auth.uid() then raise exception 'content_not_available'; end if;
 if new.category='other' and char_length(trim(new.reason))<5 then raise exception 'report_reason_required'; end if;
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('media-report:'||auth.uid()::text,0));
 if ((select count(*) from public.zameel_clip_reports where reporter_id=auth.uid() and created_at>now()-interval '1 hour')+
     (select count(*) from public.zameel_story_reports where reporter_id=auth.uid() and created_at>now()-interval '1 hour'))>=20 then
  if TG_TABLE_NAME='zameel_clip_reports' then
   if not exists(select 1 from public.zameel_clip_reports where clip_id=content_id and reporter_id=auth.uid()) then raise exception 'report_rate_limited'; end if;
  else
   if not exists(select 1 from public.zameel_story_reports where story_id=content_id and reporter_id=auth.uid()) then raise exception 'report_rate_limited'; end if;
  end if;
 end if;
 new.reported_user_id=target;
 return new;
end $$;
revoke all on function public.zameel_guard_media_report() from public,anon,authenticated;
drop trigger if exists zameel_media_report_guard on public.zameel_clip_reports;
create trigger zameel_media_report_guard before insert on public.zameel_clip_reports for each row execute function public.zameel_guard_media_report();
drop trigger if exists zameel_media_report_guard on public.zameel_story_reports;
create trigger zameel_media_report_guard before insert on public.zameel_story_reports for each row execute function public.zameel_guard_media_report();
create or replace function public.zameel_report_media(p_content_type text,p_content_id uuid,p_category text,p_reason text default '')
returns jsonb language plpgsql security invoker set search_path='' as $$
declare visible boolean; report_id uuid; existing_id uuid; duplicate boolean=false;
begin
 if auth.uid() is null or not public.zameel_account_can_write() then raise exception 'account_cannot_report'; end if;
 if p_content_type is null or p_content_type not in ('clip','story') then raise exception 'invalid_content_type'; end if;
 if p_content_type='clip' then
  select exists(select 1 from public.clips where id=p_content_id and user_id<>auth.uid() and not is_hidden and not is_deleted_by_admin) into visible;
 else
  select exists(select 1 from public.social_stories where id=p_content_id and user_id<>auth.uid() and not is_hidden and not is_deleted_by_admin and expires_at>now()) into visible;
 end if;
 if not visible then raise exception 'content_not_available'; end if;
 if p_category is null or p_category not in ('spam','harassment','hate','sexual','violence','privacy','other') or char_length(coalesce(p_reason,''))>1000 then raise exception 'invalid_report_reason'; end if;
 if p_category='other' and char_length(trim(coalesce(p_reason,'')))<5 then raise exception 'report_reason_required'; end if;
 if p_content_type='clip' then
  select id into existing_id from public.zameel_clip_reports where clip_id=p_content_id and reporter_id=auth.uid();
  if existing_id is not null then return jsonb_build_object('report_id',existing_id,'already_reported',true); end if;
  insert into public.zameel_clip_reports(clip_id,reporter_id,category,reason) values(p_content_id,auth.uid(),p_category,trim(coalesce(p_reason,'')))
  on conflict(clip_id,reporter_id) do nothing returning id into report_id;
  if report_id is null then duplicate=true;select id into report_id from public.zameel_clip_reports where clip_id=p_content_id and reporter_id=auth.uid(); end if;
 else
  select id into existing_id from public.zameel_story_reports where story_id=p_content_id and reporter_id=auth.uid();
  if existing_id is not null then return jsonb_build_object('report_id',existing_id,'already_reported',true); end if;
  insert into public.zameel_story_reports(story_id,reporter_id,category,reason) values(p_content_id,auth.uid(),p_category,trim(coalesce(p_reason,'')))
  on conflict(story_id,reporter_id) do nothing returning id into report_id;
  if report_id is null then duplicate=true;select id into report_id from public.zameel_story_reports where story_id=p_content_id and reporter_id=auth.uid(); end if;
 end if;
 return jsonb_build_object('report_id',report_id,'already_reported',duplicate);
end $$;
revoke all on function public.zameel_report_media(text,uuid,text,text) from public,anon;
grant execute on function public.zameel_report_media(text,uuid,text,text) to authenticated;
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
revoke all on function public.zameel_review_media_report(text,uuid,uuid,text,uuid,text) from public,anon,authenticated;
grant execute on function public.zameel_review_media_report(text,uuid,uuid,text,uuid,text) to service_role;
create or replace function public.zameel_report_counts(p_reviewer_id uuid,p_owner_ids uuid[])
returns jsonb language plpgsql security definer set search_path='' stable as $$
declare result jsonb;
begin
 if not public.admin_has_permission('reports.read',p_reviewer_id) or not public.admin_can_access_screen('reports',p_reviewer_id) then raise exception 'report_read_not_authorized'; end if;
 if p_owner_ids is null and not exists(select 1 from public.admin_users au join public.admin_roles ar on ar.id=au.role_id where au.user_id=p_reviewer_id and au.is_active and (ar.role_key='super_admin' or exists(select 1 from public.admin_scopes s where s.user_id=au.user_id and s.scope_type='global'))) then raise exception 'global_scope_required'; end if;
 with report_rows as (
  select r.status from public.zameel_post_reports r where p_owner_ids is null or r.reported_user_id=any(p_owner_ids)
  union all select r.status from public.zameel_clip_reports r where p_owner_ids is null or r.reported_user_id=any(p_owner_ids)
  union all select r.status from public.zameel_story_reports r where p_owner_ids is null or r.reported_user_id=any(p_owner_ids)
  union all select r.status from public.zameel_radio_reports r join public.zameel_radio_posts p on p.id=r.post_id where p_owner_ids is null or p.user_id=any(p_owner_ids)
  union all select r.status from public.zameel_college_reports r join public.zameel_college_entries p on p.id=r.entry_id where p_owner_ids is null or p.user_id=any(p_owner_ids)
 ) select jsonb_build_object('total',count(*),'pending',count(*) filter(where status='open'),
  'in_review',count(*) filter(where status='in_review'),'resolved',count(*) filter(where status in ('hidden','dismissed','deleted')),
  'unresolved',count(*) filter(where status in ('open','in_review'))) into result from report_rows;
 return result;
end $$;
revoke all on function public.zameel_report_counts(uuid,uuid[]) from public,anon,authenticated;
grant execute on function public.zameel_report_counts(uuid,uuid[]) to service_role;
notify pgrst,'reload schema';
commit;
