begin;
create or replace function public.zameel_download_media(p_type text,p_id uuid,p_index integer default 0)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare item jsonb;media jsonb;owner text;begin
 if auth.uid() is null or p_index<0 or p_index>19 then raise exception 'download_not_authorized';end if;
 if p_type='clip' then
  select to_jsonb(c) into item from public.clips c where c.id=p_id and public.can_view_clip(auth.uid(),c.id)
  and not coalesce(c.is_hidden,false) and (c.audience='public' or c.user_id=auth.uid());
  media:=jsonb_build_object('url',item->>'video_url','type','video');
 elsif p_type='post' then
  select to_jsonb(p) into item from public.posts p where p.id=p_id and public.can_view_post(auth.uid(),p.id)
  and not coalesce(p.is_hidden,false) and (p.audience='public' or p.user_id=auth.uid());
  if jsonb_typeof(item->'media_items')='array' and jsonb_array_length(item->'media_items')>0 then
   media:=(item->'media_items')->p_index;
  elsif p_index=0 and coalesce(item->>'image_url','')<>'' then media:=jsonb_build_object('url',item->>'image_url','type','image');
  elsif p_index=0 and coalesce(item->>'video_url','')<>'' then media:=jsonb_build_object('url',item->>'video_url','type','video');end if;
 else raise exception 'invalid_media_type';end if;
 if item is null or media is null or media->>'type' not in ('image','video') or coalesce(media->>'url','')='' then raise exception 'media_unavailable';end if;
 select coalesce(nullif(to_jsonb(u)->>'username',''),u.name,'زميل') into owner from public.users u where u.id=(item->>'user_id')::uuid;
 return jsonb_build_object('url',media->>'url','type',media->>'type','owner',owner);
end $$;
revoke all on function public.zameel_download_media(text,uuid,integer) from public,anon;
grant execute on function public.zameel_download_media(text,uuid,integer) to authenticated;
-- Allow actual video attachments while retaining the existing 15 MB limit.
do $$ declare c record;begin
 if to_regclass('public.chat_attachments') is not null then
  for c in select conname from pg_constraint where conrelid='public.chat_attachments'::regclass and contype='c' and pg_get_constraintdef(oid) like '%media_type%' loop
   execute format('alter table public.chat_attachments drop constraint %I',c.conname);
  end loop;
  alter table public.chat_attachments add constraint chat_attachment_media_type_check check(media_type in ('image','video','file'));
 end if;
end $$;
notify pgrst,'reload schema';
commit;
