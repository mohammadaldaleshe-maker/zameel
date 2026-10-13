begin;
-- Preserve existing content visibility and foreign keys; profile activity only.
create or replace function public.zameel_shared_activity_156(p_owner uuid default null,p_kind text default 'all',p_offset integer default 0) returns setof jsonb language sql stable security invoker set search_path=public,pg_temp as $$
 select doc from (
 select jsonb_build_object('id',s.id,'kind','post','shared_by',s.shared_by,'shared_at',s.created_at,'created_at',s.created_at,'name',u.name,'profile_image',to_jsonb(u)->>'profile_image','posts',to_jsonb(p)||jsonb_build_object('users',jsonb_build_object('name',author.name,'profile_image',author.profile_image,'verification_expires_at',author.verification_expires_at))) doc,s.created_at stamp
 from shared_posts s join posts p on p.id=s.post_id join users u on u.id=s.shared_by join users author on author.id=p.user_id
 where (p_owner is not null and s.shared_by=p_owner) and p_kind in ('all','post') and p.upload_state156='ready' and not p.is_hidden and (to_jsonb(p)->>'deleted_at') is null and (p_owner is not null or p.audience='public') and not is_blocked(auth.uid(),s.shared_by)
 union all
 select jsonb_build_object('id',s.id,'kind','clip','shared_by',s.shared_by,'shared_at',s.created_at,'created_at',s.created_at,'name',u.name,'profile_image',to_jsonb(u)->>'profile_image','clips',to_jsonb(c)) doc,s.created_at stamp
 from shared_clips s join clips c on c.id=s.clip_id join users u on u.id=s.shared_by
 where (p_owner is not null and s.shared_by=p_owner) and p_kind in ('all','clip') and c.upload_state156='ready' and not c.is_hidden and (to_jsonb(c)->>'deleted_at') is null and c.video_url not like 'uploading://%' and (p_owner is not null or c.audience='public') and not is_blocked(auth.uid(),s.shared_by)
 ) activity order by stamp desc,doc->>'id' limit 30 offset greatest(0,least(p_offset,100000));
$$;
notify pgrst, 'reload schema';
commit;
