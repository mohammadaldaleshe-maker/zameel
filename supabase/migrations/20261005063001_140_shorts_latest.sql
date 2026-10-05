begin;
create or replace function public.zameel_shorts_feed(p_author uuid default null,p_exclude uuid[] default '{}'::uuid[],p_offset integer default 0,p_saved boolean default false) returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid:=auth.uid(); result jsonb;
begin
 if coalesce(cardinality(p_exclude),0)>500 then raise exception 'shorts_page_limit'; end if;
 if actor is null or not coalesce(public.zameel_account_can_read(),false) then raise exception 'shorts_unavailable'; end if;
 select coalesce(jsonb_agg(to_jsonb(x)),'[]'::jsonb) into result from (
  select c.*,jsonb_build_object('name',u.name,'profile_image',u.profile_image) as users,
   exists(select 1 from public.clip_likes l where l.clip_id=c.id and l.user_id=actor) as liked,
   coalesce(pref.saved,false) as saved
  from public.clips c join public.users u on u.id=c.user_id
  left join public.zameel_shorts_preferences pref on pref.user_id=actor and pref.clip_id=c.id
  where public.can_view_clip(actor,c.id) and c.video_url not like 'uploading:%' and not(c.id=any(coalesce(p_exclude,'{}'::uuid[])))
   and (p_author is null and (coalesce(p_saved,false) or c.audience='public') or p_author=c.user_id)
   and (not coalesce(p_saved,false) or coalesce(pref.saved,false))
   and not coalesce(pref.hidden,false)
   and not exists(select 1 from public.user_blocks b where (b.blocker_id=actor and b.blocked_id=c.user_id) or (b.blocker_id=c.user_id and b.blocked_id=actor))
  order by c.created_at desc,c.id desc limit 60 offset greatest(0,least(p_offset,100000))
 ) x;
 return result;
end $$;
commit;
