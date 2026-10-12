begin;
lock table public.advertisements, public.business_partners in access exclusive mode nowait;
alter table public.business_partners add column if not exists deleted_at timestamptz;
create or replace function public.zameel_admin_partner_visibility_156(p_actor uuid,p_partner uuid,p_active boolean,p_reason text)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
begin
 if not zameel_admin_owner_154(p_actor) then raise exception 'owner_only';end if;
 if p_active is null or length(trim(coalesce(p_reason,'')))<5 then raise exception 'reason_required';end if;
 perform 1 from business_partners where id=p_partner and deleted_at is null for update;
 if not found then raise exception 'partner_not_found';end if;
 update business_partners set is_active=p_active,updated_at=now() where id=p_partner;
 insert into zameel_admin_access_log_154(actor_id,action,data_key,target_id,details)
 values(p_actor,case when p_active then 'partner_show' else 'partner_hide' end,'partners',p_partner::text,jsonb_build_object('reason',p_reason));
 return jsonb_build_object('saved',true,'active',p_active);
end $$;
create or replace function public.zameel_admin_partner_delete_156(p_actor uuid,p_partner uuid)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare result jsonb;
begin
 result:=zameel_admin_partner_delete_155(p_actor,p_partner,null);
 update business_partners set deleted_at=coalesce(deleted_at,now()),is_active=false where id=p_partner;
 return result;
end $$;
revoke all on function public.zameel_admin_partner_visibility_156(uuid,uuid,boolean,text),public.zameel_admin_partner_delete_156(uuid,uuid) from public,anon,authenticated;
grant execute on function public.zameel_admin_partner_visibility_156(uuid,uuid,boolean,text),public.zameel_admin_partner_delete_156(uuid,uuid) to service_role;
create or replace function public.zameel_admin_read_156(p_actor uuid,p_key text,p_target uuid default null,p_offset integer default 0,p_query text default '',p_from timestamptz default null,p_to timestamptz default null,p_status text default '')
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
 when 'partners' then source_sql:='select to_jsonb(p)||jsonb_build_object(''status'',case when p.is_active then ''active'' else ''hidden'' end) doc from business_partners p where p.deleted_at is null';
 when 'audit' then source_sql:='select to_jsonb(a) doc from zameel_admin_access_log_154 a';
 else raise exception 'unsupported_data_key';
 end case;
 source_sql:='with source as ('||source_sql||'), filtered as(select doc from source where ($2='''' or doc::text ilike ''%''||replace(replace(replace($2,''\'',''\\''),''%'',''\%''),''_'',''\_'')||''%'') and ($3 is null or coalesce(doc->>''created_at'',doc->>''deleted_at'',doc->>''last_message_at'',doc->>''updated_at'',doc->>''last_seen_at'')::timestamptz >= $3) and ($4 is null or coalesce(doc->>''created_at'',doc->>''deleted_at'',doc->>''last_message_at'',doc->>''updated_at'',doc->>''last_seen_at'')::timestamptz <= $4) and ($5='''' or coalesce(doc->>''status'',doc->>''event'',doc->>''activity'','''')=$5))';
 execute source_sql||' select count(*) from filtered' into total using p_target,p_query,p_from,p_to,p_status;
 execute source_sql||' select coalesce(jsonb_agg(doc),''[]''::jsonb) from(select doc from filtered order by coalesce(doc->>''created_at'',doc->>''deleted_at'',doc->>''last_message_at'',doc->>''updated_at'',doc->>''last_seen_at'') desc nulls last,doc->>''id'',doc::text offset $6 limit 100) page' into result using p_target,p_query,p_from,p_to,p_status,p_offset;
 insert into zameel_admin_access_log_154(actor_id,action,data_key,target_id,details) values(p_actor,'read',p_key,p_target::text,jsonb_build_object('offset',p_offset,'count',jsonb_array_length(result)));
 return jsonb_build_object('rows',result,'total',total,'offset',p_offset,'page_size',100,'historical_events_available_from',(select min(created_at) from zameel_admin_access_log_154));
end $$;
revoke all on function public.zameel_admin_read_156(uuid,text,uuid,integer,text,timestamptz,timestamptz,text) from public,anon,authenticated;
grant execute on function public.zameel_admin_read_156(uuid,text,uuid,integer,text,timestamptz,timestamptz,text) to service_role;
notify pgrst,'reload schema';

create or replace function public.zameel_partner_deleted_guard_156() returns trigger language plpgsql set search_path=public,pg_temp as $$
begin
 if tg_table_name='business_partners' then
  if old.deleted_at is not null and (new.deleted_at is null or new.is_active) then raise exception 'partner_deleted';end if;
 else
  if new.status not in ('deleted','stopped') and exists(select 1 from business_partners where id=new.partner_id and deleted_at is not null) then raise exception 'partner_deleted';end if;
 end if;
 return new;
end $$;
drop trigger if exists partner_deleted_guard156 on public.business_partners;
create trigger partner_deleted_guard156 before update on public.business_partners for each row execute function public.zameel_partner_deleted_guard_156();
drop trigger if exists advertisement_partner_deleted_guard156 on public.advertisements;
create trigger advertisement_partner_deleted_guard156 before insert or update on public.advertisements for each row execute function public.zameel_partner_deleted_guard_156();

commit;
