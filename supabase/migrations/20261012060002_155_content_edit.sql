begin;
do $$declare t text;begin foreach t in array array['posts','clips','messages','community_group_messages','community_messages','zameel_anonymous_messages','social_lamma_messages','social_stories','book_listings','study_files','zameel_radio_posts','zameel_college_entries','calendar_events','community_groups','social_lammas','polls'] loop if to_regclass('public.'||t) is not null then execute format('alter table public.%I add column if not exists edited_at timestamptz',t);end if;end loop;end $$;
create or replace function public.zameel_edit_content_155(p_table text,p_id uuid,p_changes jsonb) returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare actor uuid:=auth.uid();owner_column text;original jsonb;result jsonb;item record;assignments text:='';url text;path text;media_item jsonb;
begin
 if actor is null or not public.zameel_account_can_write() then raise exception 'write_not_allowed';end if;
 if p_table not in ('posts','clips','messages','community_group_messages','community_messages','zameel_anonymous_messages','social_lamma_messages','social_stories','book_listings','study_files','zameel_radio_posts','zameel_college_entries','calendar_events','community_groups','social_lammas','polls') or jsonb_typeof(p_changes)<>'object' then raise exception 'unsupported_content';end if;
 select column_name into owner_column from information_schema.columns where table_schema='public' and table_name=p_table and column_name in ('user_id','sender_id','owner_id','creator_id') order by case column_name when 'sender_id' then 0 when 'user_id' then 1 else 2 end limit 1;
 if owner_column is null then raise exception 'unsupported_content';end if;
 execute format('select to_jsonb(t) from public.%I t where id=$1 for update',p_table) into original using p_id;
 if original is null or original->>owner_column is distinct from actor::text then raise exception 'not_content_owner';end if;
 if coalesce((original->>'is_hidden')::boolean,false) or coalesce((original->>'deleted')::boolean,false) or coalesce((original->>'is_deleted_by_admin')::boolean,false) or original->>'deleted_at' is not null then raise exception 'content_unavailable';end if;
 for item in select key,value from jsonb_each(p_changes) loop
 if item.key not in ('title','description','caption','content','body','text','text_ar','text_en','price','author','condition','name','notes','question','event_date','event_time','starts_at','course','place_name','is_anonymous','media_items','image_url','video_url') or not original?item.key then raise exception 'unsupported_field';end if;
 if item.key in ('media_items','image_url','video_url') and p_table not in ('posts','clips') then raise exception 'unsupported_media_edit';end if;
 if item.key='media_items' then
 if jsonb_typeof(item.value)<>'array' or jsonb_array_length(item.value)>10 then raise exception 'invalid_media';end if;
 for media_item in select value from jsonb_array_elements(item.value) loop
 if media_item->>'type' not in ('image','video') or media_item->>'url' is null then raise exception 'invalid_media';end if;
 end loop;
 elsif item.key='is_anonymous' and jsonb_typeof(item.value)<>'boolean' then raise exception 'invalid_boolean';
 elsif item.key='event_time' and jsonb_typeof(item.value) not in ('string','null') then raise exception 'invalid_time';
 elsif item.key not in ('image_url','video_url','price','is_anonymous','event_time') and (jsonb_typeof(item.value)<>'string' or length(item.value#>>'{}')>10000) then raise exception 'invalid_text';end if;
 assignments:=assignments||case when assignments='' then '' else ',' end||format('%I=(jsonb_populate_record(null::public.%I,$1)).%I',item.key,p_table,item.key);
 end loop;
 if assignments='' then raise exception 'empty_changes';end if;
 -- New media must already exist in the actor's storage namespace. Old references are preserved.
 for url in select value#>>'{}' from jsonb_each(p_changes) where key in ('image_url','video_url') and value<>'null'::jsonb
 union select value->>'url' from jsonb_array_elements(coalesce(p_changes->'media_items','[]')) loop
 if url in (original->>'image_url',original->>'video_url') or exists(select 1 from jsonb_array_elements(coalesce(original->'media_items','[]')) m where m->>'url'=url) then continue;end if;
 if url like 'https://jwuqyykjmltroneqtjoc.supabase.co/storage/v1/object/public/posts/'||actor::text||'/posts/%' then
 path:=substring(url from '/object/public/posts/(.+)$');if path like '%..%' or not exists(select 1 from storage.objects where bucket_id='posts' and name=path) then raise exception 'invalid_media_owner';end if;
 elsif p_table='posts' and url like 'zameel-private://zameel_private_media?path=posts%2F'||p_id::text||'%2F'||actor::text||'%2F%' then
 path:=replace(substring(url from '[?]path=(.*)$'),'%2F','/');if path like '%..%' or not exists(select 1 from storage.objects where bucket_id='zameel_private_media' and name=path) then raise exception 'invalid_media_owner';end if;
 else raise exception 'invalid_media_owner';end if;
 if p_table='posts' and coalesce(original->>'audience','public')<>'public' and url like 'https://%' then raise exception 'private_media_required';end if;
 end loop;
 if p_table='posts' and coalesce(p_changes->>'text_ar',original->>'text_ar','')='' and jsonb_array_length(coalesce(p_changes->'media_items',original->'media_items','[]'))=0 then raise exception 'empty_post';end if;
 if p_table='clips' and coalesce(p_changes->>'video_url',original->>'video_url','')='' then raise exception 'video_required';end if;
 if p_table='social_lammas' and p_changes?'starts_at' and (p_changes->>'starts_at')::timestamptz>=(original->>'expires_at')::timestamptz then raise exception 'start_after_expiry';end if;
 if p_table='clips' and p_changes?'video_url' and p_changes->>'video_url' is distinct from original->>'video_url' and original?'cover_url' then assignments:=assignments||',cover_url=null';end if;
 execute format('update public.%I set %s,edited_at=now() where id=$2 returning to_jsonb(%I.*)',p_table,assignments,p_table) into result using p_changes,p_id;
 return result;
end $$;
revoke all on function public.zameel_edit_content_155(text,uuid,jsonb) from public,anon;
grant execute on function public.zameel_edit_content_155(text,uuid,jsonb) to authenticated;
do $$begin if to_regclass('public.community_group_messages') is not null and to_regprocedure('public.get_community_group_messages(uuid)') is not null then
execute $function$create or replace function public.get_community_group_messages_155(target_group_id uuid) returns setof jsonb language sql security invoker stable set search_path=public,pg_temp as $body$
select to_jsonb(original)||jsonb_build_object('edited_at',m.edited_at) from public.get_community_group_messages(target_group_id) original join public.community_group_messages m on m.id=original.id;
$body$ $function$;
execute 'revoke all on function public.get_community_group_messages_155(uuid) from public,anon';execute 'grant execute on function public.get_community_group_messages_155(uuid) to authenticated';
end if;end $$;
notify pgrst,'reload schema';commit;
