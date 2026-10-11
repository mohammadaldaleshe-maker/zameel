-- Update 154. Apply only after 153 and after candidate checks pass.
begin;
create table public.zameel_admin_delegations_154 (
 id bigint generated always as identity primary key,
 employee_id uuid not null references auth.users(id) on delete cascade,
 data_key text not null check(data_key in ('users','shared','deleted','presence','correspondents','relations','library','calls','radio','groups','lamma','revenue','partners','audit','reports')),
 expires_at timestamptz, revoked_at timestamptz,
 granted_by uuid not null references auth.users(id), created_at timestamptz not null default now(),
 unique(employee_id,data_key)
);
create table public.zameel_admin_access_log_154 (
 id bigint generated always as identity primary key,
 actor_id uuid references auth.users(id) on delete set null,
 action text not null, data_key text not null, target_id text,
 details jsonb not null default '{}', created_at timestamptz not null default now()
);
create table public.zameel_content_archive_154 (
 id bigint generated always as identity primary key,
 table_name text not null, resource_id text not null, owner_id uuid,
 snapshot jsonb not null, deleted_by uuid, deleted_at timestamptz not null default now(),
 deletion_source text not null default 'database_delete'
);
create table public.zameel_membership_history_154 (
 id bigint generated always as identity primary key,
 kind text not null, group_id uuid not null, user_id uuid not null,
 event text not null, actor_id uuid, occurred_at timestamptz not null default now()
);
create table public.zameel_download_history_154 (
 id bigint generated always as identity primary key,
 user_id uuid not null references auth.users(id) on delete cascade,
 item_key text not null, item_type text not null, saved_at timestamptz not null default now()
);
create table public.zameel_blocked_emails_154 (
 id bigint generated always as identity primary key,
 email_normalized text not null unique, blocked_by uuid references auth.users(id) on delete set null,
 reason text not null, blocked_at timestamptz not null default now(), released_at timestamptz
);
create table public.zameel_moderation_retention_154 (
 id bigint generated always as identity primary key,
 table_name text not null, resource_id uuid not null, hidden_at timestamptz not null default now(),
 retention_days integer not null check(retention_days between 1 and 3650),
 hidden_by uuid references auth.users(id), reason text not null,
 restored_at timestamptz, purged_at timestamptz, unique(table_name,resource_id)
);
create or replace function public.zameel_admin_owner_154(p_actor uuid)
returns boolean language sql stable security definer set search_path=public,pg_temp as $$
 select exists(select 1 from admin_users a join admin_roles r on r.id=a.role_id where a.user_id=p_actor and a.is_active and r.role_key='super_admin');
$$;
create or replace function public.zameel_admin_can_read_154(p_actor uuid,p_key text)
returns boolean language sql stable security definer set search_path=public,pg_temp as $$
 select public.zameel_admin_owner_154(p_actor) or exists(
 select 1 from zameel_admin_delegations_154 d join admin_users a on a.user_id=d.employee_id
 where a.is_active and d.employee_id=p_actor and d.data_key=p_key and d.revoked_at is null and (d.expires_at is null or d.expires_at>now()));
$$;
create or replace function public.zameel_archive_deleted_154()
returns trigger language plpgsql security definer set search_path=public,pg_temp as $$
 declare doc jsonb:=to_jsonb(old);
 begin
 insert into zameel_content_archive_154(table_name,resource_id,owner_id,snapshot,deleted_by)
 values(tg_table_name,doc->>'id',coalesce(doc->>'user_id',doc->>'owner_id',doc->>'creator_id',doc->>'sender_id',doc->>'created_by',doc->>'author_id',doc->>'shared_by',doc->>'representative_id')::uuid,doc,coalesce(nullif(current_setting('zameel.admin.actor',true),'')::uuid,auth.uid()));
 return old;
 end;
$$;
create or replace function public.zameel_membership_event_154()
returns trigger language plpgsql security definer set search_path=public,pg_temp as $$
 declare doc jsonb; member uuid; actor uuid:=coalesce(nullif(current_setting('zameel.admin.actor',true),'')::uuid,auth.uid());
 begin
 doc:=case when tg_op='DELETE' then to_jsonb(old) else to_jsonb(new) end;
 member:=(doc->>'user_id')::uuid;
 insert into zameel_membership_history_154(kind,group_id,user_id,event,actor_id,occurred_at)
 values(tg_argv[0],coalesce(doc->>'group_id',doc->>'lamma_id')::uuid,member,
 case when tg_op='INSERT' then 'joined' when actor=member then 'left' when actor is not null then 'removed' else 'removed_actor_unavailable' end,
 actor,case when tg_op='INSERT' then coalesce((doc->>'joined_at')::timestamptz,now()) else now() end);
 return case when tg_op='DELETE' then old else new end;
 end;
$$;
-- Preserve all existing foreign keys and API embeddings. New archive tables have a single surrogate primary key.
do $$declare t text; begin
 foreach t in array array['posts','social_stories','clips','study_files','zameel_library_items','zameel_radio_posts','community_groups','community_group_messages','social_lammas','social_lamma_messages','advertisements'] loop
 if to_regclass('public.'||t) is not null then
 execute format('create trigger archive_deleted_154 before delete on public.%I for each row execute function public.zameel_archive_deleted_154()',t);
 end if; end loop;
 foreach t in array array['community_group_members','social_lamma_members'] loop
 if to_regclass('public.'||t) is not null then
 execute format('create trigger membership_history_154 after insert or delete on public.%I for each row execute function public.zameel_membership_event_154(%L)',t,case when t='community_group_members' then 'groups' else 'lamma' end);
 end if; end loop;
 end $$;
create or replace function public.zameel_record_study_save_154(p_file uuid)
returns void language plpgsql security definer set search_path=public,pg_temp as $$
 begin
 if auth.uid() is null or not public.zameel_account_can_read() then raise exception 'account_access_denied'; end if;
 -- This records a client-reported successful save, not proof of a physical device download.
 if not exists(select 1 from public.study_files where id=p_file) then raise exception 'file_unavailable'; end if;
 insert into zameel_download_history_154(user_id,item_key,item_type) values(auth.uid(),p_file::text,'study_file');
 end $$;
-- Retain the public signature and counter behavior; add an actor-specific event atomically.
create or replace function public.record_zameel_library_download(target_item_key text,target_item_type text default 'book')
returns bigint language plpgsql security definer set search_path=public,pg_temp set row_security=off as $$
 declare result_count bigint;
 begin
 if auth.uid() is null or not public.zameel_account_can_read() then raise exception 'account_access_denied';end if;
 if coalesce(trim(target_item_key),'')='' or length(target_item_key)>1000 then raise exception 'invalid_item_key';end if;
 if target_item_type is null or target_item_type not in ('book','summary') then target_item_type:='book';end if;
 insert into zameel_library_download_counts(item_key,item_type,download_count,updated_at)
 values(target_item_key,target_item_type,1,now()) on conflict(item_key) do update
 set download_count=zameel_library_download_counts.download_count+1,item_type=excluded.item_type,updated_at=now() returning download_count into result_count;
 insert into zameel_download_history_154(user_id,item_key,item_type) values(auth.uid(),target_item_key,target_item_type);
 return result_count;
 end $$;
-- Auth hook. It must be enabled in Supabase Authentication Hooks after the SQL check.
create or replace function public.zameel_before_user_created_154(event jsonb)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
 begin
 if exists(select 1 from zameel_blocked_emails_154 where email_normalized=lower(trim(event->'user'->>'email')) and released_at is null) then
 return jsonb_build_object('error',jsonb_build_object('http_code',403,'message','Registration is unavailable for this account.'));
 end if;return '{}'::jsonb;
 end $$;
-- Defense in depth: enforce the same registry even if an Auth hook is not configured.
create or replace function public.zameel_guard_blocked_email_154()
returns trigger language plpgsql security definer set search_path=public,pg_temp as $$
 begin
 if exists(select 1 from zameel_blocked_emails_154 where email_normalized=lower(trim(new.email)) and released_at is null) then raise exception 'registration_unavailable';end if;
 return new;
 end $$;
create trigger zameel_blocked_email_registration_154 before insert or update of email on auth.users
 for each row execute function public.zameel_guard_blocked_email_154();
-- Deny direct access to operational logs, identities and delegation data.
do $$declare t text;begin
 foreach t in array array['zameel_admin_delegations_154','zameel_admin_access_log_154','zameel_content_archive_154','zameel_membership_history_154','zameel_download_history_154','zameel_blocked_emails_154','zameel_moderation_retention_154'] loop
 execute format('alter table public.%I enable row level security',t);
 execute format('revoke all on table public.%I from public,anon,authenticated',t);
 execute format('grant all on table public.%I to service_role',t);
 end loop;
 end $$;
revoke all on function public.zameel_admin_owner_154(uuid), public.zameel_admin_can_read_154(uuid,text),public.zameel_archive_deleted_154(),public.zameel_membership_event_154(),public.zameel_guard_blocked_email_154() from public,anon,authenticated;
grant execute on function public.zameel_admin_owner_154(uuid), public.zameel_admin_can_read_154(uuid,text) to service_role;
revoke all on function public.zameel_record_study_save_154(uuid), public.record_zameel_library_download(text,text) from public,anon;
grant execute on function public.zameel_record_study_save_154(uuid), public.record_zameel_library_download(text,text) to authenticated;
revoke all on function public.zameel_before_user_created_154(jsonb) from public,anon,authenticated;
grant execute on function public.zameel_before_user_created_154(jsonb) to supabase_auth_admin;
create or replace function public.zameel_admin_read_154(p_actor uuid,p_key text,p_target uuid default null,p_offset integer default 0,p_query text default '',p_from timestamptz default null,p_to timestamptz default null,p_status text default '')
returns jsonb language plpgsql security definer set search_path=public,pg_temp set row_security=off as $$
declare source_sql text; result jsonb; total bigint; t text; owner_expression text;
begin
 if not public.zameel_admin_can_read_154(p_actor,p_key) then raise exception 'read_delegation_required';end if;
 if p_offset<0 or p_offset>10000000 or length(p_query)>300 then raise exception 'invalid_filter';end if;
 case p_key
 when 'users' then source_sql:='select jsonb_build_object(''id'',to_jsonb(u)->''id'',''name'',to_jsonb(u)->''name'',''email'',to_jsonb(u)->''email'',''account_type'',to_jsonb(u)->''account_type'',''university'',to_jsonb(u)->''university'',''college'',to_jsonb(u)->''college'',''department'',to_jsonb(u)->''department'',''role'',to_jsonb(u)->''role'',''created_at'',to_jsonb(u)->''created_at'',''last_seen_at'',to_jsonb(u)->''last_seen_at'',''verification_expires_at'',to_jsonb(u)->''verification_expires_at'',''profile_image'',to_jsonb(u)->''profile_image'') as doc from public.users u';
 if to_regclass('public.admin_user_states') is not null then source_sql:='select doc||jsonb_build_object(''admin_user_states'',(select jsonb_build_object(''status'',a.status,''reason'',a.reason,''suspended_until'',a.suspended_until) from admin_user_states a where a.user_id=(doc->>''id'')::uuid)) doc from ('||source_sql||') profiles';end if;
 if to_regclass('public.zameel_registration_profiles') is not null then source_sql:='select doc||jsonb_build_object(''academic_details'',(select jsonb_build_object(''academic_degree'',a.academic_degree,''student_number'',a.student_number) from zameel_registration_profiles a where a.user_id=(doc->>''id'')::uuid)) doc from ('||source_sql||') profiles';end if;
 when 'presence' then source_sql:='select jsonb_build_object(''id'',u.id,''name'',u.name,''email'',u.email,''last_seen_at'',u.last_seen_at) doc from users u where u.id=$1';
 when 'shared' then
 source_sql:='';
 foreach t in array array['posts','shared_posts','social_stories','clips','book_listings','study_files','zameel_library_items','zameel_radio_posts','post_comments','clip_comments','zameel_college_entries'] loop
 if to_regclass('public.'||t) is not null then
 if source_sql<>'' then source_sql:=source_sql||' union all ';end if;
 source_sql:=source_sql||format('select to_jsonb(r)||jsonb_build_object(''resource_type'',%L) doc from public.%I r where $1 is null or coalesce(to_jsonb(r)->>''user_id'',to_jsonb(r)->>''owner_id'',to_jsonb(r)->>''created_by'',to_jsonb(r)->>''author_id'',to_jsonb(r)->>''shared_by'')=$1::text',t,t);
 end if;end loop;
 when 'deleted' then source_sql:='select to_jsonb(a) doc from zameel_content_archive_154 a where $1 is null or a.owner_id=$1';
 when 'correspondents' then source_sql:='select jsonb_build_object(''id'',u.id,''name'',u.name,''conversation_id'',m.conversation_id,''last_message_at'',(select max(x.created_at) from messages x where x.conversation_id=m.conversation_id)) doc from conversation_members m join users u on u.id=m.user_id join conversations c on c.id=m.conversation_id where m.user_id<>$1 and not c.is_group and exists(select 1 from conversation_members own where own.conversation_id=m.conversation_id and own.user_id=$1) and exists(select 1 from messages x where x.conversation_id=m.conversation_id)';
 when 'relations' then source_sql:='select jsonb_build_object(''id'',u.id,''name'',u.name,''relation'',case when f.follower_id=$1 then ''following'' else ''follower'' end,''created_at'',f.created_at) doc from follows f join users u on u.id=case when f.follower_id=$1 then f.following_id else f.follower_id end where $1 in(f.follower_id,f.following_id) union all select jsonb_build_object(''id'',u.id,''name'',u.name,''relation'',''colleague'',''created_at'',f.updated_at) from friend_requests f join users u on u.id=case when f.sender_id=$1 then f.receiver_id else f.sender_id end where f.status=''accepted'' and $1 in(f.sender_id,f.receiver_id)';
 when 'library' then source_sql:='select to_jsonb(d)||jsonb_build_object(''activity'',''downloaded'',''created_at'',d.saved_at) doc from zameel_download_history_154 d where $1 is null or d.user_id=$1 union all select to_jsonb(f)||jsonb_build_object(''activity'',''uploaded'',''resource_type'',''study_files'') from study_files f where $1 is null or f.user_id=$1 union all select to_jsonb(f)||jsonb_build_object(''activity'',''uploaded'',''resource_type'',''zameel_library_items'') from zameel_library_items f where $1 is null or f.created_by=$1';
 if to_regclass('public.book_listings') is not null then source_sql:=source_sql||' union all select to_jsonb(f)||jsonb_build_object(''activity'',''uploaded'',''resource_type'',''book_listings'') from book_listings f where $1 is null or f.owner_id=$1';end if;
 when 'calls' then source_sql:='select jsonb_build_object(''id'',c.room_id,''caller_id'',c.caller_id,''callee_id'',c.callee_id,''caller_name'',a.name,''callee_name'',b.name,''created_at'',c.created_at,''answered_at'',c.answered_at,''ended_at'',c.ended_at,''status'',c.status,''with_video'',c.with_video,''duration_seconds'',case when c.answered_at is not null and c.ended_at is not null then greatest(0,extract(epoch from c.ended_at-c.answered_at)) else null end) doc from direct_call_sessions c join users a on a.id=c.caller_id join users b on b.id=c.callee_id where $1 is null or $1 in(c.caller_id,c.callee_id)';
 when 'radio' then source_sql:='select to_jsonb(r)||jsonb_build_object(''author_name'',u.name,''author_email'',u.email) doc from zameel_radio_posts r join users u on u.id=r.user_id';
 when 'groups' then
 if p_target is null then source_sql:='select to_jsonb(g)||jsonb_build_object(''creator_name'',u.name) doc from community_groups g join users u on u.id=g.owner_id';
 else source_sql:='select to_jsonb(m)||jsonb_build_object(''record_type'',''message'',''resource_type'',''community_group_messages'',''author_name'',u.name) doc from community_group_messages m join users u on u.id=m.user_id where m.group_id=$1 union all select to_jsonb(m)||jsonb_build_object(''record_type'',''current_member'',''name'',u.name,''created_at'',m.joined_at) from community_group_members m join users u on u.id=m.user_id where m.group_id=$1 union all select to_jsonb(m)||jsonb_build_object(''record_type'',''membership_event'',''name'',u.name,''created_at'',m.occurred_at) from zameel_membership_history_154 m left join users u on u.id=m.user_id where m.kind=''groups'' and m.group_id=$1';end if;
 when 'lamma' then
 if p_target is null then source_sql:='select to_jsonb(g)||jsonb_build_object(''creator_name'',u.name) doc from social_lammas g join users u on u.id=g.creator_id';
 else source_sql:='select to_jsonb(m)||jsonb_build_object(''record_type'',''message'',''resource_type'',''social_lamma_messages'',''author_name'',u.name) doc from social_lamma_messages m join users u on u.id=m.sender_id where m.lamma_id=$1 union all select to_jsonb(m)||jsonb_build_object(''record_type'',''current_member'',''name'',u.name,''created_at'',m.joined_at) from social_lamma_members m join users u on u.id=m.user_id where m.lamma_id=$1 union all select to_jsonb(m)||jsonb_build_object(''record_type'',''membership_event'',''name'',u.name,''created_at'',m.occurred_at) from zameel_membership_history_154 m left join users u on u.id=m.user_id where m.kind=''lamma'' and m.group_id=$1';end if;
 when 'reports' then source_sql:='select to_jsonb(r)||jsonb_build_object(''id'',r.post_id,''report_id'',r.id,''resource_type'',''posts'',''type'',''post'',''preview'',left(coalesce(to_jsonb(c)->>''text_ar'',''''),400)) doc from zameel_post_reports r left join posts c on c.id=r.post_id union all select to_jsonb(r)||jsonb_build_object(''id'',r.clip_id,''report_id'',r.id,''resource_type'',''clips'',''type'',''clip'',''preview'',left(coalesce(to_jsonb(c)->>''caption'',''''),400)) doc from zameel_clip_reports r left join clips c on c.id=r.clip_id union all select to_jsonb(r)||jsonb_build_object(''id'',r.story_id,''report_id'',r.id,''resource_type'',''social_stories'',''type'',''story'',''preview'',left(coalesce(to_jsonb(c)->>''caption'',''''),400)) doc from zameel_story_reports r left join social_stories c on c.id=r.story_id union all select to_jsonb(r)||jsonb_build_object(''id'',r.post_id,''report_id'',null,''resource_type'',''zameel_radio_posts'',''type'',''radio'',''preview'','''') doc from zameel_radio_reports r left join zameel_radio_posts c on c.id=r.post_id union all select to_jsonb(r)||jsonb_build_object(''id'',r.entry_id,''report_id'',null,''resource_type'',''zameel_college_entries'',''type'',''college'',''preview'','''') doc from zameel_college_reports r left join zameel_college_entries c on c.id=r.entry_id';
 when 'partners' then source_sql:='select to_jsonb(p) doc from business_partners p';
 when 'audit' then source_sql:='select to_jsonb(a) doc from zameel_admin_access_log_154 a';
 else raise exception 'unsupported_data_key';
 end case;
 source_sql:='with source as ('||source_sql||'), filtered as(select doc from source where ($2='''' or doc::text ilike ''%''||replace(replace(replace($2,''\'',''\\''),''%'',''\%''),''_'',''\_'')||''%'') and ($3 is null or coalesce(doc->>''created_at'',doc->>''deleted_at'',doc->>''last_message_at'',doc->>''updated_at'',doc->>''last_seen_at'')::timestamptz >= $3) and ($4 is null or coalesce(doc->>''created_at'',doc->>''deleted_at'',doc->>''last_message_at'',doc->>''updated_at'',doc->>''last_seen_at'')::timestamptz <= $4) and ($5='''' or coalesce(doc->>''status'',doc->>''event'',doc->>''activity'','''')=$5))';
 execute source_sql||' select count(*) from filtered' into total using p_target,p_query,p_from,p_to,p_status;
 execute source_sql||' select coalesce(jsonb_agg(doc),''[]''::jsonb) from(select doc from filtered order by coalesce(doc->>''created_at'',doc->>''deleted_at'',doc->>''last_message_at'',doc->>''updated_at'',doc->>''last_seen_at'') desc nulls last,doc->>''id'',doc::text offset $6 limit 100) page' into result using p_target,p_query,p_from,p_to,p_status,p_offset;
 insert into zameel_admin_access_log_154(actor_id,action,data_key,target_id,details) values(p_actor,'read',p_key,p_target::text,jsonb_build_object('offset',p_offset,'count',jsonb_array_length(result)));
 return jsonb_build_object('rows',result,'total',total,'offset',p_offset,'page_size',100,'historical_events_available_from',(select min(created_at) from zameel_admin_access_log_154));
end $$;
revoke all on function public.zameel_admin_read_154(uuid,text,uuid,integer,text,timestamptz,timestamptz,text) from public,anon,authenticated;
grant execute on function public.zameel_admin_read_154(uuid,text,uuid,integer,text,timestamptz,timestamptz,text) to service_role;
grant usage,select on sequence zameel_admin_delegations_154_id_seq, zameel_admin_access_log_154_id_seq,zameel_content_archive_154_id_seq,zameel_membership_history_154_id_seq,zameel_download_history_154_id_seq,zameel_blocked_emails_154_id_seq,zameel_moderation_retention_154_id_seq to service_role;

create or replace function public.zameel_admin_delegate_154(p_actor uuid,p_employee uuid,p_key text,p_expires timestamptz,p_revoke boolean,p_reason text)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
begin
 if not public.zameel_admin_owner_154(p_actor) then raise exception 'owner_only';end if;
 if length(trim(p_reason))<5 or not exists(select 1 from admin_users where user_id=p_employee and is_active) or p_employee=p_actor then raise exception 'invalid_delegation';end if;
 if p_expires is not null and p_expires<=now() then raise exception 'invalid_expiry';end if;
 insert into zameel_admin_delegations_154(employee_id,data_key,expires_at,revoked_at,granted_by)
 values(p_employee,p_key,p_expires,case when p_revoke then now() end,p_actor)
 on conflict(employee_id,data_key) do update set expires_at=excluded.expires_at,revoked_at=excluded.revoked_at,granted_by=p_actor,created_at=now();
 insert into zameel_admin_access_log_154(actor_id,action,data_key,target_id,details) values(p_actor,case when p_revoke then 'revoke_read' else 'grant_read' end,p_key,p_employee::text,jsonb_build_object('reason',p_reason,'expires_at',p_expires));
 return jsonb_build_object('saved',true);
end $$;
revoke all on function public.zameel_admin_delegate_154(uuid,uuid,text,timestamptz,boolean,text) from public,anon,authenticated;
grant execute on function public.zameel_admin_delegate_154(uuid,uuid,text,timestamptz,boolean,text) to service_role;
notify pgrst,'reload schema';
commit;
