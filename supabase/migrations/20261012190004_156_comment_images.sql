begin;
alter table public.post_comments add column if not exists image_paths156 text[] not null default '{}';
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values('comment-images156','comment-images156',false,12582912,array['image/jpeg','image/png','image/webp']) on conflict(id) do nothing;
create policy comment_images_insert156 on storage.objects for insert to authenticated with check(bucket_id='comment-images156' and (storage.foldername(name))[1]=auth.uid()::text and zameel_account_can_write() and exists(select 1 from posts p where p.id::text=(storage.foldername(name))[2] and not p.is_hidden and p.upload_state156='ready' and can_view_post(auth.uid(),p.id)));
create policy comment_images_read156 on storage.objects for select to authenticated using(bucket_id='comment-images156' and zameel_account_can_read() and ((storage.foldername(name))[1]=auth.uid()::text or exists(select 1 from post_comments c join posts p on p.id=c.post_id where name=any(c.image_paths156) and not c.is_hidden and not p.is_hidden and p.upload_state156='ready' and can_view_post(auth.uid(),c.post_id))));
create or replace function public.zameel_guard_comment_images156() returns trigger language plpgsql security definer set search_path=public,pg_temp as $$
declare path text;
begin
 if tg_op='UPDATE' and old.image_paths156=new.image_paths156 and old.user_id=new.user_id and old.post_id=new.post_id then return new;end if;
 if cardinality(new.image_paths156)>5 then raise exception 'too_many_comment_images';end if;
 if auth.uid() is not null and new.user_id<>auth.uid() then raise exception 'comment_owner_only';end if;
 foreach path in array new.image_paths156 loop
 if path not like new.user_id::text||'/'||new.post_id::text||'/%' or path like '%..%' or path like E'%\\\\%' or not exists(select 1 from storage.objects s where s.bucket_id='comment-images156' and s.name=path and coalesce(to_jsonb(s)->>'owner_id',to_jsonb(s)->>'owner')=new.user_id::text) then raise exception 'invalid_comment_image';end if;
 end loop;return new;
end $$;
drop trigger if exists comment_images_guard156 on public.post_comments;
create trigger comment_images_guard156 before insert or update on public.post_comments for each row execute function zameel_guard_comment_images156();
revoke all on function public.zameel_guard_comment_images156() from public,anon,authenticated;
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
 if p_table='post_comments' and asset=any(array(select jsonb_array_elements_text(coalesce(asset_doc->'image_paths156','[]'::jsonb)))) then bucket:='comment-images156';path:=asset;
 elsif p_table='study_files' and asset=doc->>'storage_path' then bucket:='study_files';path:=asset;
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
notify pgrst,'reload schema';commit;
