begin;
create table public.zameel_wall_posts158(
 id uuid primary key default gen_random_uuid(), owner_id uuid not null references public.users(id) on delete cascade,
 author_id uuid not null references public.users(id) on delete cascade,
 content text not null default '' check(length(content)<=10000), media jsonb not null default '[]',
 created_at timestamptz not null default now(), deleted_at timestamptz,
 check(jsonb_typeof(media)='array' and jsonb_array_length(media)<=10)
);
create index wall_owner158 on public.zameel_wall_posts158(owner_id,created_at desc);
alter table public.zameel_wall_posts158 enable row level security;
revoke all on public.zameel_wall_posts158 from public,anon,authenticated;
create or replace function public.zameel_wall_visible158(p_owner uuid) returns boolean
language sql stable security definer set search_path=public,pg_temp as $$
 select auth.uid() is not null and zameel_account_can_read() and not is_blocked(auth.uid(),p_owner)
 and exists(select 1 from users u where u.id=p_owner and (u.id=auth.uid() or u.account_privacy='public' or is_colleague(auth.uid(),u.id)))
$$;
create or replace function public.zameel_wall_list158(p_owner uuid,p_offset integer default 0)
returns setof jsonb language sql stable security definer set search_path=public,pg_temp as $$
 select to_jsonb(w)-'deleted_at'||jsonb_build_object('author_name',u.name,'author_photo',u.profile_image)
 from zameel_wall_posts158 w join users u on u.id=w.author_id
 where w.owner_id=p_owner and w.deleted_at is null and zameel_wall_visible158(p_owner) and not is_blocked(auth.uid(),w.author_id)
 order by w.created_at desc,w.id desc limit 30 offset greatest(0,least(p_offset,100000))
$$;
create or replace function public.zameel_wall_create158(p_owner uuid,p_id uuid,p_content text,p_media jsonb default '[]')
returns uuid language plpgsql security definer set search_path=public,pg_temp as $$
declare item jsonb;path text; result uuid;
begin
 if auth.uid() is null or not zameel_account_can_write() or auth.uid()=p_owner or not zameel_wall_visible158(p_owner)
 or not is_colleague(auth.uid(),p_owner) or not exists(select 1 from zameel_member_settings158 where user_id=p_owner and allow_friend_posts) then raise exception 'friend_wall_disabled';end if;
 if p_id is null or p_content is null or length(p_content)>10000 or jsonb_typeof(p_media) is distinct from 'array' or jsonb_array_length(p_media)>10 or (length(trim(p_content))=0 and jsonb_array_length(p_media)=0) then raise exception 'invalid_wall_post';end if;
 for item in select * from jsonb_array_elements(p_media) loop
  path:=item->>'path';
  if item->>'type' is null or item->>'type' not in ('image','video') or path is null or path not like auth.uid()::text||'/'||p_id::text||'/%' or path like '%..%' or position('\\' in path)>0
  or not exists(select 1 from storage.objects where bucket_id='zameel_wall158' and name=path and owner_id=auth.uid()::text) then raise exception 'invalid_wall_media';end if;
 end loop;
 insert into zameel_wall_posts158(id,owner_id,author_id,content,media) values(p_id,p_owner,auth.uid(),p_content,p_media)
 on conflict(id) do nothing returning id into result;
 if result is null then
 if exists(select 1 from zameel_wall_posts158 where id=p_id and author_id=auth.uid() and owner_id=p_owner) then return p_id;end if;
 raise exception 'wall_identity_conflict';end if;
 insert into notifications(user_id,actor_id,type,title_ar,title_en,body_ar,body_en,data,is_read)
 values(p_owner,auth.uid(),'friend_wall_post','منشور على صفحتك','New post on your profile','نشر صديقك على صفحتك الشخصية','A friend posted on your profile',jsonb_build_object('type','friend_wall_post','profile_id',p_owner,'wall_id',p_id),false);
 insert into notifications(user_id,actor_id,type,title_ar,title_en,body_ar,body_en,data,is_read)
 values(auth.uid(),auth.uid(),'upload_complete','اكتمل النشر','Upload complete','تم نشر محتواك على صفحة صديقك','Your post was published on your friend profile',jsonb_build_object('type','upload_complete','profile_id',p_owner,'wall_id',p_id),false);
 return p_id;
end $$;
create or replace function public.zameel_wall_delete158(p_id uuid) returns void
language plpgsql security definer set search_path=public,pg_temp as $$
begin
 if auth.uid() is null or not zameel_account_can_write() then raise exception 'not_allowed';end if;
 update zameel_wall_posts158 set deleted_at=coalesce(deleted_at,now()) where id=p_id and auth.uid() in (owner_id,author_id);
 if not found then raise exception 'not_allowed';end if;
end $$;
create or replace function public.zameel_wall_status158(p_id uuid) returns boolean
language sql stable security definer set search_path=public,pg_temp as $$
 select auth.uid() is not null and exists(select 1 from zameel_wall_posts158 where id=p_id and author_id=auth.uid())
$$;
create or replace function public.zameel_wall_upload_exists158(p_id uuid,p_path text) returns boolean
language sql stable security definer set search_path=public,pg_temp as $$
 select auth.uid() is not null and p_path like auth.uid()::text||'/'||p_id::text||'/%'
 and exists(select 1 from storage.objects where bucket_id='zameel_wall158' and name=p_path and owner_id=auth.uid()::text)
$$;
revoke all on function public.zameel_wall_status158(uuid),public.zameel_wall_upload_exists158(uuid,text) from public,anon;
grant execute on function public.zameel_wall_status158(uuid),public.zameel_wall_upload_exists158(uuid,text) to authenticated;
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
 values('zameel_wall158','zameel_wall158',false,83886080,array['image/jpeg','image/png','image/webp','video/mp4','video/quicktime','video/webm']) on conflict(id) do nothing;
create policy wall_upload158 on storage.objects for insert to authenticated with check(bucket_id='zameel_wall158' and (storage.foldername(name))[1]=auth.uid()::text and zameel_account_can_write());
create or replace function public.zameel_wall_media_visible158(p_path text) returns boolean
language sql stable security definer set search_path=public,pg_temp as $$
 select exists(select 1 from zameel_wall_posts158 w where w.deleted_at is null and zameel_wall_visible158(w.owner_id) and not is_blocked(auth.uid(),w.author_id)
 and exists(select 1 from jsonb_array_elements(w.media) item where item->>'path'=p_path))
$$;
revoke all on function public.zameel_wall_media_visible158(text) from public,anon;
grant execute on function public.zameel_wall_media_visible158(text) to authenticated;
create policy wall_read158 on storage.objects for select to authenticated using(bucket_id='zameel_wall158' and zameel_wall_media_visible158(name));
-- Referenced files are retained for moderation; no broad storage deletion grant.
revoke all on function public.zameel_wall_visible158(uuid),public.zameel_wall_list158(uuid,integer),public.zameel_wall_create158(uuid,uuid,text,jsonb),public.zameel_wall_delete158(uuid) from public,anon;
grant execute on function public.zameel_wall_visible158(uuid),public.zameel_wall_list158(uuid,integer),public.zameel_wall_create158(uuid,uuid,text,jsonb),public.zameel_wall_delete158(uuid) to authenticated;
notify pgrst,'reload schema';commit;
