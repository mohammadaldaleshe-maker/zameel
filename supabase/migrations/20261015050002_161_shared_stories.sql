begin;
set local lock_timeout='2s';set local statement_timeout='60s';
lock table public.social_stories in access exclusive mode nowait;
alter table public.social_stories add column if not exists shared_source_kind161 text;
alter table public.social_stories add column if not exists shared_source_id161 uuid;
alter table public.social_stories add column if not exists shared_index161 integer not null default 0;
alter table public.social_stories add column if not exists shared_batch161 uuid;
create unique index if not exists shared_story_batch161 on public.social_stories(user_id,shared_batch161,shared_index161) where shared_batch161 is not null;

-- Build media only from the current public source; callers cannot supply URLs or author identity.
create or replace function public.zameel_story_source161(p_kind text,p_id uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare doc jsonb;author_doc jsonb;items jsonb:='[]'::jsonb;item jsonb;body text;
begin
 if auth.uid() is null or not public.zameel_account_can_read() then return null;end if;
 if p_kind='post' then select to_jsonb(p) into doc from public.posts p where p.id=p_id;
 elsif p_kind='clip' then select to_jsonb(p) into doc from public.clips p where p.id=p_id;
 else return null;end if;
 if doc is null or doc->>'audience' is distinct from 'public' or coalesce(doc->>'is_hidden','false')='true' or doc->>'deleted_at' is not null
 or doc->>'upload_state156' is distinct from 'ready' then return null;end if;
 select to_jsonb(u) into author_doc from public.users u where u.id=(doc->>'user_id')::uuid;
 if author_doc is null or author_doc->>'account_privacy' is distinct from 'public' or public.is_blocked(auth.uid(),(doc->>'user_id')::uuid) then return null;end if;
 if p_kind='clip' then
 if nullif(doc->>'video_url','') is null or doc->>'video_url' like 'uploading://%' then return null;end if;
 items:=jsonb_build_array(jsonb_build_object('type','video','url',doc->>'video_url'));
 else
 if jsonb_typeof(doc->'media_items')='array' then
 for item in select value from jsonb_array_elements(doc->'media_items') limit 20 loop
 if item->>'type' in('image','video') and nullif(item->>'url','') is not null and item->>'url' not like 'uploading://%' then items:=items||jsonb_build_array(jsonb_build_object('type',item->>'type','url',item->>'url'));end if;
 end loop;end if;
 if jsonb_array_length(items)=0 then
 if nullif(doc->>'image_url','') is not null and doc->>'image_url' not like 'uploading://%' then items:=items||jsonb_build_array(jsonb_build_object('type','image','url',doc->>'image_url'));end if;
 if nullif(doc->>'video_url','') is not null and doc->>'video_url' not like 'uploading://%' then items:=items||jsonb_build_array(jsonb_build_object('type','video','url',doc->>'video_url'));end if;
 end if;
 if doc->>'type' in('image','video') and jsonb_array_length(items)=0 then return null;end if;
 end if;
 body:=coalesce(nullif(doc->>'caption',''),nullif(doc->>'text_ar',''),nullif(doc->>'text',''),nullif(doc->>'content',''),doc->>'text_en','');
 return jsonb_build_object('author_id',doc->>'user_id','author_name',author_doc->>'name','author_image',author_doc->>'profile_image','text',body,'media',items);
end $$;
revoke all on function public.zameel_story_source161(text,uuid) from public,anon;
grant execute on function public.zameel_story_source161(text,uuid) to authenticated;

create or replace function public.zameel_guard_shared_story161() returns trigger
language plpgsql security definer set search_path='' as $$
declare source jsonb;media jsonb;
begin
 if new.shared_source_kind161 is null and new.shared_source_id161 is null then
 if new.shared_batch161 is not null or new.shared_index161<>0 then raise exception 'invalid_shared_story';end if;
 return new;end if;
 if new.shared_source_kind161 not in('post','clip') or new.shared_source_id161 is null or new.shared_index161 not between 0 and 19 then raise exception 'invalid_shared_story';end if;
 source:=public.zameel_story_source161(new.shared_source_kind161,new.shared_source_id161);
 if source is null then raise exception 'source_not_public';end if;
 media:=source->'media'->new.shared_index161;
 if media is null and (new.shared_index161<>0 or jsonb_array_length(source->'media')>0) then raise exception 'invalid_shared_media_index';end if;
 new.media_url:=media->>'url';new.media_type:=coalesce(media->>'type','text');new.caption:=source->>'text';
 new.audience:='public';new.upload_state156:='ready';
 if tg_op='INSERT' then new.expires_at:=now()+interval '24 hours';end if;
 return new;
end $$;
drop trigger if exists shared_story_guard161 on public.social_stories;
create trigger shared_story_guard161 before insert or update on public.social_stories for each row execute function public.zameel_guard_shared_story161();
drop policy if exists shared_story_visible161 on public.social_stories;
create policy shared_story_visible161 on public.social_stories as restrictive for select to authenticated using(shared_source_kind161 is null or public.zameel_story_source161(shared_source_kind161,shared_source_id161) is not null);

create or replace function public.zameel_share_story161(p_kind text,p_id uuid,p_request uuid) returns uuid[]
language plpgsql security definer set search_path='' as $$
declare source jsonb;result uuid[];story_id uuid;idx integer;total integer;existing record;
begin
 if auth.uid() is null or not public.zameel_account_can_write() or not public.zameel_device_authorized160() then raise exception 'account_access_denied';end if;
 if p_request is null then raise exception 'request_identity_required';end if;
 perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text||p_request::text,161));
 for existing in select id,shared_source_kind161,shared_source_id161 from public.social_stories where user_id=auth.uid() and shared_batch161=p_request loop
 if existing.shared_source_kind161 is distinct from p_kind or existing.shared_source_id161 is distinct from p_id then raise exception 'request_identity_conflict';end if;
 result:=array_append(result,existing.id);
 end loop;
 if result is not null then return result;end if;
 source:=public.zameel_story_source161(p_kind,p_id);if source is null then raise exception 'source_not_public';end if;
 total:=greatest(1,jsonb_array_length(source->'media'));
 for idx in 0..total-1 loop
 insert into public.social_stories(user_id,media_type,caption,audience,shared_source_kind161,shared_source_id161,shared_index161,shared_batch161)
 values(auth.uid(),'text','','public',p_kind,p_id,idx,p_request) returning id into story_id;
 result:=array_append(result,story_id);
 end loop;
 return result;
end $$;
revoke all on function public.zameel_share_story161(text,uuid,uuid) from public,anon;
grant execute on function public.zameel_share_story161(text,uuid,uuid) to authenticated;

create or replace function public.zameel_shared_story_sources161(p_ids uuid[]) returns jsonb
language sql stable security invoker set search_path='' as $$
 select coalesce(jsonb_object_agg(s.id,public.zameel_story_source161(s.shared_source_kind161,s.shared_source_id161)),'{}'::jsonb)
 from public.social_stories s where s.id=any(p_ids[1:40]) and s.shared_source_kind161 is not null and s.expires_at>now();
$$;
revoke all on function public.zameel_shared_story_sources161(uuid[]) from public,anon;
grant execute on function public.zameel_shared_story_sources161(uuid[]) to authenticated;
notify pgrst,'reload schema';
commit;
