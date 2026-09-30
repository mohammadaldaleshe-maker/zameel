-- Apply as the project database administrator. No account is deleted on install.
begin;
create extension if not exists pg_net with schema extensions;
create extension if not exists pg_cron with schema pg_catalog;
create table if not exists public.zameel_account_deletion_jobs (
 id uuid primary key default gen_random_uuid(),
 user_id uuid not null unique,
 state text not null default 'pending' check(state in ('pending','processing','review','completed')),
 data_removed boolean not null default false,
 attempts integer not null default 0,
 token uuid,
 lease_until timestamptz,
 next_attempt_at timestamptz not null default now(),
 last_error text,
 created_at timestamptz not null default now(),
 completed_at timestamptz
);
create table if not exists public.zameel_account_deletion_files (
 job_id uuid not null references public.zameel_account_deletion_jobs(id) on delete cascade,
 bucket_id text not null,
 name text not null,
 primary key(job_id,bucket_id,name)
);
alter table public.zameel_account_deletion_jobs enable row level security;
alter table public.zameel_account_deletion_files enable row level security;
revoke all on public.zameel_account_deletion_jobs,public.zameel_account_deletion_files from public,anon,authenticated;
grant all on public.zameel_account_deletion_jobs,public.zameel_account_deletion_files to service_role;

-- Only established user-owned tables/columns. Optional tables are skipped if
-- absent; never apply a guessed delete to an arbitrary application table.
create or replace function public.zameel_deletion_owned_columns()
returns table(table_name text,column_name text)
language sql set search_path = '' as $$
 select * from (values
 ('admin_scopes','user_id'),('admin_screen_access','user_id'),
 ('admin_user_permission_overrides','user_id'),('admin_user_states','user_id'),
 ('admin_users','user_id'),('advertisement_comments','author_id'),
 ('advertisement_hides','user_id'),('advertisement_interest_categories','user_id'),
 ('advertisement_likes','user_id'),('advertisement_views','viewer_id'),
 ('ai_conversations','user_id'),('ai_daily_usage','user_id'),('ai_messages','user_id'),
 ('anonymous_messages','user_id'),('book_exchange_messages','sender_id'),
 ('book_exchange_requests','owner_id'),('book_exchange_requests','requester_id'),
 ('book_listing_contacts','owner_id'),('book_listings','owner_id'),
 ('calendar_events','owner_id'),('call_signals','sender_id'),('chat_attachments','uploader_id'),
 ('campus_partner_places','owner_id'),('clip_comment_likes','user_id'),('clip_comments','user_id'),
 ('clip_likes','user_id'),('clips','user_id'),('close_friends','owner_id'),('close_friends','friend_id'),
 ('comments','user_id'),('community_group_join_requests','user_id'),
 ('community_group_members','user_id'),('community_group_messages','user_id'),
 ('community_messages','user_id'),('conversation_members','user_id'),
 ('data_requests','user_id'),('direct_call_sessions','caller_id'),('direct_call_sessions','callee_id'),
 ('follows','follower_id'),('follows','following_id'),('friend_requests','sender_id'),('friend_requests','receiver_id'),
 ('graduation_book_members','user_id'),('graduation_book_pages','author_id'),
 ('hidden_call_history','user_id'),('highlights','user_id'),('job_applications','user_id'),
 ('likes','user_id'),('meet_colleague_requests','requester_id'),('meet_colleague_requests','recipient_id'),
 ('meeting_room_attendance','user_id'),('meeting_room_bans','user_id'),('meeting_room_members','user_id'),
 ('meeting_signals','sender_id'),('messages','sender_id'),('notifications','user_id'),
 ('poll_votes','user_id'),('polls','creator_id'),('post_comment_likes','user_id'),
 ('post_comments','user_id'),('posts','user_id'),('profiles','id'),
 ('push_device_tokens','user_id'),('push_notification_queue','user_id'),
 ('saved_job_opportunities','user_id'),('saved_posts','user_id'),
 ('shared_clips','shared_by'),('social_discovery_actions','actor_id'),('social_discovery_actions','target_id'),
 ('social_discovery_matches','user_low'),('social_discovery_matches','user_high'),
 ('social_discovery_profiles','user_id'),('social_lamma_members','user_id'),('social_lamma_messages','sender_id'),
 ('social_stories','user_id'),('story_reactions','user_id'),('story_view_receipts','user_id'),
 ('story_view_receipts','viewer_id'),('story_views','user_id'),('story_views','viewer_id'),
 ('study_files','user_id'),('support_tickets','user_id'),('user_book_library','user_id'),
 ('user_blocks','blocker_id'),('user_blocks','blocked_id'),('zameel_registration_profiles','user_id'),
 ('zameel_radio_posts','user_id'),('zameel_radio_reports','reporter_id'),
 ('zameel_radio_mutes','owner_id'),('zameel_radio_mutes','muted_user_id'),
 ('zameel_college_entries','user_id'),('zameel_college_likes','user_id'),('zameel_college_reports','reporter_id')
 ) as t(table_name,column_name)
$$;
revoke all on function public.zameel_deletion_owned_columns() from public,anon,authenticated;

-- Commercial/administrative/shared ownership requires a reviewed handover.
-- Do not delete a partner's purchased ads with the salesperson's login.
create or replace function public.zameel_deletion_review_reason(p_user uuid)
returns text language plpgsql security definer set search_path = '' as $$
declare r record; has_rows boolean;
begin
 for r in select * from (values
  ('sales_staff','user_id'),('partner_accounts','user_id'),
  ('business_partners','owner_id'),('admin_users','user_id'),
  ('community_groups','owner_id'),('social_lammas','creator_id'),
  ('graduation_books','owner_id'),('meeting_rooms','host_id')
 ) as t(tbl,col) loop
  if exists(select 1 from pg_catalog.pg_attribute a
    where a.attrelid=pg_catalog.to_regclass('public.'||r.tbl) and a.attname=r.col and not a.attisdropped) then
   execute format('select exists(select 1 from public.%I where %I=$1)',r.tbl,r.col) into has_rows using p_user;
   if has_rows then return 'shared_or_managed_account:'||r.tbl; end if;
  end if;
 end loop;
 -- Fail before media deletion for unexpected non-null blocking references.
 for r in
  select ns.nspname,cl.relname,a.attname,a.attnotnull
  from pg_catalog.pg_constraint c
  join pg_catalog.pg_class cl on cl.oid=c.conrelid
  join pg_catalog.pg_namespace ns on ns.oid=cl.relnamespace
  join pg_catalog.pg_attribute a on a.attrelid=c.conrelid and a.attnum=c.conkey[1]
  where c.contype='f' and c.confrelid in ('public.users'::regclass,'auth.users'::regclass)
   and c.confdeltype in ('a','r') and array_length(c.conkey,1)=1
 loop
  if r.nspname<>'public' then return 'external_blocking_reference'; end if;
  if r.attnotnull and not exists(select 1 from public.zameel_deletion_owned_columns() o
    where o.table_name=r.relname and o.column_name=r.attname) then
   execute format('select exists(select 1 from %I.%I where %I=$1)',r.nspname,r.relname,r.attname)
    into has_rows using p_user;
   if has_rows then return 'blocking_reference:'||r.relname; end if;
  end if;
 end loop;
 if exists(select 1 from storage.objects o where o.bucket_id='advertisements'
  and (to_jsonb(o)->>'owner_id'=p_user::text or to_jsonb(o)->>'owner'=p_user::text)) then
  return 'shared_advertising_media';
 end if;
 return null;
end $$;
revoke all on function public.zameel_deletion_review_reason(uuid) from public,anon,authenticated;
grant execute on function public.zameel_deletion_review_reason(uuid) to service_role;

-- Dispatch tokens authenticate only one job; never expose a service-role key.
create or replace function public.zameel_dispatch_account_deletions()
returns integer language plpgsql security definer set search_path = '' as $$
declare j record; fresh uuid; sent integer:=0;
begin
 for j in select id from public.zameel_account_deletion_jobs
  where state in ('pending','processing') and next_attempt_at<=now()
   and (lease_until is null or lease_until<now())
  order by created_at limit 3 for update skip locked loop
  fresh:=gen_random_uuid();
  update public.zameel_account_deletion_jobs set token=fresh,lease_until=now()+interval '5 minutes' where id=j.id;
  perform net.http_post(
   url:='https://jwuqyykjmltroneqtjoc.supabase.co/functions/v1/account-deletion',
   headers:='{"Content-Type":"application/json"}'::jsonb,
   body:=jsonb_build_object('job_id',j.id,'token',fresh), timeout_milliseconds:=10000);
  sent:=sent+1;
 end loop;
 -- Remove completed operational identifiers after seven days.
 delete from public.zameel_account_deletion_jobs where state='completed' and completed_at<now()-interval '7 days';
 return sent;
end $$;
revoke all on function public.zameel_dispatch_account_deletions() from public,anon,authenticated;

create or replace function public.delete_my_account()
returns void language plpgsql security definer set search_path = '' as $$
declare uid uuid:=auth.uid(); jid uuid; reason text;
begin
 if uid is null then raise exception 'not_authenticated'; end if;
 if not exists(select 1 from cron.job where jobname='zameel-account-deletion-worker' and active) then
  raise exception 'account_deletion_worker_not_ready';
 end if;
 reason:=public.zameel_deletion_review_reason(uid);
 if reason is not null then
  raise exception 'account_deletion_requires_review' using hint='Contact zameel.jo@gmail.com for shared/business account handover.';
 end if;
 insert into public.zameel_account_deletion_jobs(user_id) values(uid)
  on conflict(user_id) do nothing;
 select id into jid from public.zameel_account_deletion_jobs where user_id=uid;
 -- Capture exact object paths. Storage metadata is read-only here.
 insert into public.zameel_account_deletion_files(job_id,bucket_id,name)
 select jid,o.bucket_id,o.name from storage.objects o
 where (to_jsonb(o)->>'owner_id'=uid::text or to_jsonb(o)->>'owner'=uid::text
  or (o.bucket_id in ('posts','profiles','study_files','chat_attachments','beautiful-college')
   and split_part(o.name,'/',1)=uid::text)
  or (o.bucket_id='zameel_private_media' and split_part(o.name,'/',3)=uid::text))
 on conflict do nothing;
 -- Legacy radio objects can lack owner metadata and have no UUID path prefix.
 if pg_catalog.to_regclass('public.zameel_radio_posts') is not null then
  insert into public.zameel_account_deletion_files(job_id,bucket_id,name)
   select jid,'zameel-radio',storage_path from public.zameel_radio_posts where user_id=uid
   on conflict do nothing;
 end if;
 perform public.zameel_dispatch_account_deletions();
end $$;
revoke all on function public.delete_my_account() from public,anon;
grant execute on function public.delete_my_account() to authenticated;

create or replace function public.zameel_claim_account_deletion(p_job uuid,p_token uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare j public.zameel_account_deletion_jobs;
begin
 select * into j from public.zameel_account_deletion_jobs where id=p_job for update;
 if j.id is null or j.token is distinct from p_token or j.state not in ('pending','processing')
  or j.lease_until<now() then return null; end if;
 -- Consume dispatch credential. The returned lease key is worker-internal.
 update public.zameel_account_deletion_jobs set state='processing',attempts=attempts+1,token=gen_random_uuid()
  where id=p_job returning * into j;
 return jsonb_build_object('id',j.id,'user_id',j.user_id,'lease',j.token,'data_removed',j.data_removed,'attempts',j.attempts);
end $$;

create or replace function public.zameel_discover_account_files(p_job uuid,p_lease uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare j public.zameel_account_deletion_jobs;
begin
 select * into j from public.zameel_account_deletion_jobs where id=p_job for update;
 if j.id is null or j.token is distinct from p_lease or j.state<>'processing' then raise exception 'invalid_worker_lease'; end if;
 insert into public.zameel_account_deletion_files(job_id,bucket_id,name)
 select j.id,o.bucket_id,o.name from storage.objects o
 where (to_jsonb(o)->>'owner_id'=j.user_id::text or to_jsonb(o)->>'owner'=j.user_id::text
  or (o.bucket_id in ('posts','profiles','study_files','chat_attachments','beautiful-college')
   and split_part(o.name,'/',1)=j.user_id::text)
  or (o.bucket_id='zameel_private_media' and split_part(o.name,'/',3)=j.user_id::text))
 on conflict do nothing;
end $$;
revoke all on function public.zameel_discover_account_files(uuid,uuid) from public,anon,authenticated;
grant execute on function public.zameel_discover_account_files(uuid,uuid) to service_role;

create or replace function public.zameel_remove_account_data(p_job uuid,p_lease uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare j public.zameel_account_deletion_jobs; r record; reason text;
begin
 select * into j from public.zameel_account_deletion_jobs where id=p_job for update;
 if j.id is null or j.token is distinct from p_lease or j.state<>'processing' then raise exception 'invalid_worker_lease'; end if;
 if j.data_removed then return; end if;
 reason:=public.zameel_deletion_review_reason(j.user_id);
 if reason is not null then raise exception 'account_deletion_requires_review'; end if;
 -- Remove own rows first. Existing cascades handle descendants. All operations
 -- below are one transaction; a new/unknown FK rolls everything back.
 for r in select * from public.zameel_deletion_owned_columns() loop
  if exists(select 1 from pg_catalog.pg_attribute a
   where a.attrelid=pg_catalog.to_regclass('public.'||r.table_name)
    and a.attname=r.column_name and a.atttypid='uuid'::regtype and not a.attisdropped) then
   execute format('delete from public.%I where %I=$1',r.table_name,r.column_name) using j.user_id;
  end if;
 end loop;
 -- Nullable audit references survive without an account identifier.
 for r in select ns.nspname,cl.relname,a.attname from pg_catalog.pg_constraint c
  join pg_catalog.pg_class cl on cl.oid=c.conrelid
  join pg_catalog.pg_namespace ns on ns.oid=cl.relnamespace
  join pg_catalog.pg_attribute a on a.attrelid=c.conrelid and a.attnum=c.conkey[1]
  where c.contype='f' and c.confrelid in ('public.users'::regclass,'auth.users'::regclass)
   and c.confdeltype in ('a','r') and array_length(c.conkey,1)=1 and not a.attnotnull and ns.nspname='public'
 loop
  execute format('update %I.%I set %I=null where %I=$1',r.nspname,r.relname,r.attname,r.attname) using j.user_id;
 end loop;
 delete from public.users where id=j.user_id;
 update public.zameel_account_deletion_jobs set data_removed=true where id=p_job;
end $$;

create or replace function public.zameel_finish_account_deletion(p_job uuid,p_lease uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare j public.zameel_account_deletion_jobs;
begin
 select * into j from public.zameel_account_deletion_jobs where id=p_job for update;
 if j.id is null or j.token is distinct from p_lease or not j.data_removed then raise exception 'invalid_worker_lease'; end if;
 if exists(select 1 from auth.users where id=j.user_id) or exists(select 1 from public.users where id=j.user_id)
  or exists(select 1 from public.zameel_account_deletion_files where job_id=p_job) then raise exception 'deletion_not_complete'; end if;
 update public.zameel_account_deletion_jobs set state='completed',completed_at=now(),token=null,lease_until=null,last_error=null where id=p_job;
end $$;

revoke all on function public.zameel_claim_account_deletion(uuid,uuid),
 public.zameel_remove_account_data(uuid,uuid),public.zameel_finish_account_deletion(uuid,uuid) from public,anon,authenticated;
grant execute on function public.zameel_claim_account_deletion(uuid,uuid),
 public.zameel_remove_account_data(uuid,uuid),public.zameel_finish_account_deletion(uuid,uuid) to service_role;
commit;
