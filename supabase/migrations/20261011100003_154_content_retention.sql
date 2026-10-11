begin;
create table public.zameel_media_purge_jobs_154 (
 id bigint generated always as identity primary key,bucket_id text not null,object_path text not null,
 owner_id uuid not null,resource_type text not null,resource_id uuid not null,
 status text not null default 'pending' check(status in ('pending','completed','failed')),
 attempts integer not null default 0,last_error text,created_at timestamptz not null default now(),completed_at timestamptz,
 unique(bucket_id,object_path,resource_type,resource_id)
);
alter table public.zameel_media_purge_jobs_154 enable row level security;
revoke all on public.zameel_media_purge_jobs_154 from public,anon,authenticated;
grant all on public.zameel_media_purge_jobs_154 to service_role;
grant usage,select on sequence zameel_media_purge_jobs_154_id_seq to service_role;
-- Add only restrictive visibility checks; preserve existing audience/privacy policies.
do $$declare t text;begin
 foreach t in array array['posts','shared_posts','post_comments','clip_comments','clips','social_stories','book_listings','study_files','zameel_library_items','zameel_radio_posts','community_groups','community_group_messages','social_lammas','social_lamma_messages','advertisements','zameel_college_entries'] loop
 if to_regclass('public.'||t) is not null then
 execute format('alter table public.%I add column if not exists is_hidden boolean not null default false',t);
 execute format('create policy maintenance_hidden_154 on public.%I as restrictive for select to authenticated,anon using(not is_hidden)',t);
 if not exists(select 1 from pg_trigger where tgrelid=to_regclass('public.'||t) and tgname='archive_deleted_154') then
 execute format('create trigger archive_deleted_154 before delete on public.%I for each row execute function public.zameel_archive_deleted_154()',t);
 end if;
 end if;end loop;
end $$;
create or replace function public.zameel_guard_hidden_group_154()
returns trigger language plpgsql security definer set search_path=public,pg_temp as $$
declare doc jsonb:=to_jsonb(new);hidden boolean;
begin
 if auth.uid() is null then return new;end if;
 if tg_argv[0]='groups' then select is_hidden into hidden from community_groups where id=(doc->>'group_id')::uuid;
 else select is_hidden into hidden from social_lammas where id=(doc->>'lamma_id')::uuid;end if;
 if hidden then raise exception 'group_unavailable';end if;return new;
end $$;
do $$declare t text;kind text;begin
 foreach t in array array['community_group_messages','community_group_members','social_lamma_messages','social_lamma_members'] loop
 kind:=case when t like 'community_%' then 'groups' else 'lamma' end;
 execute format('create trigger guard_hidden_group_154 before insert or update on public.%I for each row execute function public.zameel_guard_hidden_group_154(%L)',t,kind);
 end loop;
end $$;
create policy hidden_parent_154 on public.community_group_messages as restrictive for select to authenticated,anon using(exists(select 1 from public.community_groups where id=group_id and not is_hidden));
create policy hidden_parent_154 on public.community_group_members as restrictive for select to authenticated,anon using(exists(select 1 from public.community_groups where id=group_id and not is_hidden));
create policy hidden_parent_154 on public.social_lamma_messages as restrictive for select to authenticated,anon using(exists(select 1 from public.social_lammas where id=lamma_id and not is_hidden));
create policy hidden_parent_154 on public.social_lamma_members as restrictive for select to authenticated,anon using(exists(select 1 from public.social_lammas where id=lamma_id and not is_hidden));
create or replace function public.zameel_admin_moderate_154(p_actor uuid,p_table text,p_id uuid,p_decision text,p_reason text,p_retention integer default 30)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare doc jsonb;documents jsonb;asset_doc jsonb;retention public.zameel_moderation_retention_154;asset text;parts text[];bucket text;path text;owner uuid;queued integer:=0;
begin
 if not public.zameel_admin_owner_154(p_actor) then raise exception 'owner_only';end if;
 if p_table not in ('posts','shared_posts','post_comments','clip_comments','clips','social_stories','book_listings','study_files','zameel_library_items','zameel_radio_posts','community_groups','community_group_messages','social_lammas','social_lamma_messages','advertisements','zameel_college_entries') or p_decision not in ('hide','restore','purge') or length(coalesce(trim(p_reason),''))<5 or p_retention not between 1 and 3650 then raise exception 'invalid_moderation';end if;
 execute format('select to_jsonb(r) from public.%I r where id=$1 for update',p_table) into doc using p_id;
 if doc is null then raise exception 'resource_not_found';end if;
 if p_decision='hide' then
 execute format('update public.%I set is_hidden=true where id=$1',p_table) using p_id;
 insert into zameel_moderation_retention_154(table_name,resource_id,hidden_by,reason,retention_days)
 values(p_table,p_id,p_actor,p_reason,p_retention) on conflict(table_name,resource_id) do update
 set hidden_at=case when zameel_moderation_retention_154.restored_at is null then zameel_moderation_retention_154.hidden_at else now() end,hidden_by=p_actor,reason=p_reason,retention_days=p_retention,restored_at=null,purged_at=null;
 elsif p_decision='restore' then
 if p_table='zameel_radio_posts' and (doc->>'expires_at')::timestamptz<=now() then raise exception 'radio_expired_cannot_restore';end if;
 perform set_config('zameel.admin.actor',p_actor::text,true);
 if doc ? 'is_deleted_by_admin' then execute format('update public.%I set is_deleted_by_admin=false where id=$1',p_table) using p_id;end if;
 if p_table='zameel_radio_posts' and doc ? 'moderation_status' then execute format('update public.%I set moderation_status=%L where id=$1',p_table,'visible') using p_id;end if;
 execute format('update public.%I set is_hidden=false where id=$1',p_table) using p_id;
 update zameel_moderation_retention_154 set restored_at=now() where table_name=p_table and resource_id=p_id and purged_at is null;
 else
 select * into retention from zameel_moderation_retention_154 where table_name=p_table and resource_id=p_id for update;
 if retention.id is null or retention.restored_at is not null or retention.hidden_at+make_interval(days=>retention.retention_days)>now() or not coalesce((doc->>'is_hidden')::boolean,false) then raise exception 'retention_period_not_elapsed';end if;
 documents:=jsonb_build_array(doc);
 if p_table='community_groups' then documents:=documents||coalesce((select jsonb_agg(to_jsonb(m)) from community_group_messages m where m.group_id=p_id),'[]'::jsonb);
 elsif p_table='social_lammas' then documents:=documents||coalesce((select jsonb_agg(to_jsonb(m)) from social_lamma_messages m where m.lamma_id=p_id),'[]'::jsonb);end if;
 for asset_doc in select value from jsonb_array_elements(documents) loop
 owner:=coalesce(asset_doc->>'user_id',asset_doc->>'owner_id',asset_doc->>'creator_id',asset_doc->>'sender_id',asset_doc->>'created_by',asset_doc->>'representative_id')::uuid;
 -- Only objects actually owned by this content's author can be purged.
 for asset in select value#>>'{}' from jsonb_path_query(asset_doc,'$.** ? (@.type() == "string")') value loop
 bucket:=null;path:=null;
 if p_table='study_files' and asset=doc->>'storage_path' then bucket:='study_files';path:=asset;
 elsif p_table='zameel_radio_posts' and asset=doc->>'storage_path' then bucket:='zameel-radio';path:=asset;
 elsif p_table='zameel_college_entries' and asset=doc->>'image_path' then bucket:='beautiful-college';path:=asset;
 elsif p_table='advertisements' and exists(select 1 from jsonb_array_elements(coalesce(doc->'media','[]'::jsonb)) item where item->>'path'=asset) then bucket:='advertisements';path:=asset;
 else
 parts:=regexp_match(asset,'^https://jwuqyykjmltroneqtjoc[.]supabase[.]co/storage/v1/object/(?:public|sign|authenticated)/([^/]+)/([^?]+)');
 if parts is not null then bucket:=parts[1];path:=parts[2];end if;
 end if;
 if bucket is not null and path not like '%..%' and path not like '%\\%' and path not like '%\%%' and exists(select 1 from storage.objects o where o.bucket_id=bucket and o.name=path and o.owner_id=owner::text) then
 insert into zameel_media_purge_jobs_154(bucket_id,object_path,owner_id,resource_type,resource_id) values(bucket,path,owner,p_table,p_id) on conflict do nothing;
 queued:=queued+1;
 end if;
 end loop;
 end loop;
 perform set_config('zameel.admin.actor',p_actor::text,true);
 execute format('delete from public.%I where id=$1',p_table) using p_id;
 update zameel_moderation_retention_154 set purged_at=now() where id=retention.id;
 update zameel_content_archive_154 set snapshot=jsonb_build_object('id',p_id,'permanently_deleted',true),deleted_by=p_actor,deletion_source='owner_permanent_delete' where (table_name=p_table and resource_id=p_id::text) or (p_table='community_groups' and snapshot->>'group_id'=p_id::text) or (p_table='social_lammas' and snapshot->>'lamma_id'=p_id::text);
 end if;
 insert into zameel_admin_access_log_154(actor_id,action,data_key,target_id,details) values(p_actor,p_decision,'shared',p_id::text,jsonb_build_object('table',p_table,'reason',p_reason,'retention_days',p_retention,'queued_media',queued));
 return jsonb_build_object('saved',true,'media_queued',queued);
end $$;
create or replace function public.zameel_media_purge_safe_154(p_actor uuid,p_job bigint)
returns boolean language plpgsql security definer set search_path=public,pg_temp as $$
declare job zameel_media_purge_jobs_154%rowtype;object_doc jsonb;t text;referenced boolean;
begin
 if not public.zameel_admin_owner_154(p_actor) then raise exception 'owner_only';end if;
 select * into job from zameel_media_purge_jobs_154 where id=p_job;
 if not found then raise exception 'purge_job_not_found';end if;
 if not exists(select 1 from zameel_moderation_retention_154 where table_name=job.resource_type and resource_id=job.resource_id and purged_at is not null) then return false;end if;
 select to_jsonb(o) into object_doc from storage.objects o where o.bucket_id=job.bucket_id and o.name=job.object_path;
 if object_doc is null then return true;end if;
 if object_doc->>'owner_id' is distinct from job.owner_id::text or (object_doc->>'created_at')::timestamptz>job.created_at then return false;end if;
 foreach t in array array['posts','shared_posts','post_comments','clip_comments','clips','social_stories','book_listings','study_files','zameel_library_items','zameel_radio_posts','community_group_messages','social_lamma_messages','advertisements','zameel_college_entries'] loop
  if to_regclass('public.'||t) is not null then
   execute format('select exists(select 1 from public.%I r where strpos(to_jsonb(r)::text,$1)>0)',t) into referenced using job.object_path;
   if referenced then return false;end if;
  end if;
 end loop;
 if exists(select 1 from zameel_content_archive_154 where not coalesce((snapshot->>'permanently_deleted')::boolean,false) and strpos(snapshot::text,job.object_path)>0) then return false;end if;
 return true;
end $$;
revoke all on function public.zameel_media_purge_safe_154(uuid,bigint) from public,anon,authenticated;
grant execute on function public.zameel_media_purge_safe_154(uuid,bigint) to service_role;
revoke all on function public.zameel_guard_hidden_group_154(),public.zameel_admin_moderate_154(uuid,text,uuid,text,text,integer) from public,anon,authenticated;
grant execute on function public.zameel_admin_moderate_154(uuid,text,uuid,text,text,integer) to service_role;
notify pgrst,'reload schema';
commit;
