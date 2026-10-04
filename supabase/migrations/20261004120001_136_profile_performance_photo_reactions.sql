-- 136: approval notifications and private, non-promotable profile photo reactions.
begin;
create index if not exists notifications_promotion_receipt_idx on public.notifications((data->>'promotion_id')) where type='post_promotion_approved';
create or replace function public.zameel_promotion_approval_notify() returns trigger
language plpgsql security definer set search_path='' as $$ begin
 if new.status='approved' and old.status is distinct from 'approved' and not exists(select 1 from public.notifications n where n.type='post_promotion_approved' and n.data->>'promotion_id'=new.id::text) then
  insert into public.notifications(user_id,actor_id,type,title_ar,title_en,body_ar,body_en,data,is_read)
  values(new.owner_id,new.reviewed_by,'post_promotion_approved','تمت الموافقة على التمويل','Promotion approved',
    'تم اعتماد تمويل منشورك وبدأت مدة الترويج','Your post promotion was approved and has started',
    jsonb_build_object('post_id',new.post_id,'promotion_id',new.id),false);
 end if;
 return new;
end $$;
drop trigger if exists zameel_promotion_approval_notify on public.zameel_post_promotions;
create trigger zameel_promotion_approval_notify after update of status on public.zameel_post_promotions for each row execute function public.zameel_promotion_approval_notify();
revoke all on function public.zameel_promotion_approval_notify() from public,anon,authenticated;
insert into public.notifications(user_id,actor_id,type,title_ar,title_en,body_ar,body_en,data,is_read)
select x.owner_id,x.reviewed_by,'post_promotion_approved','تمت الموافقة على التمويل','Promotion approved','تم اعتماد تمويل منشورك وبدأت مدة الترويج','Your post promotion was approved and has started',jsonb_build_object('post_id',x.post_id,'promotion_id',x.id),false
from public.zameel_post_promotions x where x.status='approved' and x.ends_at>now()
and not exists(select 1 from public.notifications n where n.type='post_promotion_approved' and n.data->>'promotion_id'=x.id::text);

-- Publish only badge identities; payment details remain owner/admin-only.
create or replace function public.zameel_visible_promotion_badges(p_owner uuid)
returns table(post_id uuid,ends_at timestamptz) language sql stable security definer set search_path='' as $$
 select x.post_id,x.ends_at from public.zameel_post_promotions x join public.posts p on p.id=x.post_id
 where auth.uid() is not null and p.user_id=p_owner and x.status='approved' and x.starts_at<=now() and x.ends_at>now()
 and p.audience='public' and not coalesce(p.is_hidden,false) and public.can_view_post(auth.uid(),p.id)
 and public.zameel_promotions_enabled()
 and not exists(select 1 from public.admin_user_states s where s.user_id=x.owner_id and s.status in ('blocked','suspended'));
$$;
revoke all on function public.zameel_visible_promotion_badges(uuid) from public,anon;
grant execute on function public.zameel_visible_promotion_badges(uuid) to authenticated;

create table if not exists public.zameel_profile_photos(
 id uuid primary key default gen_random_uuid(), owner_id uuid not null references public.users(id) on delete cascade,
 kind text not null check(kind in ('avatar','cover')), image_url text not null check(length(image_url) between 1 and 8192),
 created_at timestamptz not null default now());
create unique index if not exists zameel_profile_photo_identity on public.zameel_profile_photos(owner_id,kind,md5(image_url));
create table if not exists public.zameel_profile_photo_likes(
 photo_id uuid not null references public.zameel_profile_photos(id) on delete cascade,
 user_id uuid not null references public.users(id) on delete cascade, created_at timestamptz not null default now(),
 primary key(photo_id,user_id));
create table if not exists public.zameel_profile_photo_comments(
 id uuid primary key default gen_random_uuid(), photo_id uuid not null references public.zameel_profile_photos(id) on delete cascade,
 user_id uuid not null references public.users(id) on delete cascade,
 content text not null check(length(trim(content)) between 1 and 2000), created_at timestamptz not null default now());
create index if not exists zameel_profile_photo_comment_page on public.zameel_profile_photo_comments(photo_id,created_at desc,id desc);

create or replace function public.zameel_can_view_profile_photo(p_owner uuid,p_kind text,p_url text) returns boolean
language sql stable security definer set search_path='' as $$
 select auth.uid() is not null and public.zameel_account_can_read() and exists(
 select 1 from public.users u where u.id=p_owner
 and p_kind in ('avatar','cover') and p_url=case p_kind when 'avatar' then u.profile_image else u.cover_image end
 and (u.id=auth.uid() or (not public.is_blocked(auth.uid(),u.id) and (u.account_privacy='public' or public.is_colleague(auth.uid(),u.id)))));
$$;
create or replace function public.zameel_can_view_photo_id(p_photo uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.zameel_profile_photos p where p.id=p_photo and public.zameel_can_view_profile_photo(p.owner_id,p.kind,p.image_url));
$$;
revoke all on function public.zameel_can_view_profile_photo(uuid,text,text),public.zameel_can_view_photo_id(uuid) from public,anon;
grant execute on function public.zameel_can_view_profile_photo(uuid,text,text),public.zameel_can_view_photo_id(uuid) to authenticated;

alter table public.zameel_profile_photos enable row level security;
alter table public.zameel_profile_photo_likes enable row level security;
alter table public.zameel_profile_photo_comments enable row level security;
revoke all on public.zameel_profile_photos,public.zameel_profile_photo_likes,public.zameel_profile_photo_comments from public,anon,authenticated;
grant select on public.zameel_profile_photos,public.zameel_profile_photo_likes,public.zameel_profile_photo_comments to authenticated;
grant all on public.zameel_profile_photos,public.zameel_profile_photo_likes,public.zameel_profile_photo_comments to service_role;
drop policy if exists photo_visible on public.zameel_profile_photos;
create policy photo_visible on public.zameel_profile_photos for select to authenticated using(public.zameel_can_view_profile_photo(owner_id,kind,image_url));
drop policy if exists photo_likes_visible on public.zameel_profile_photo_likes;
create policy photo_likes_visible on public.zameel_profile_photo_likes for select to authenticated using(public.zameel_can_view_photo_id(photo_id));
drop policy if exists photo_comments_visible on public.zameel_profile_photo_comments;
create policy photo_comments_visible on public.zameel_profile_photo_comments for select to authenticated using(public.zameel_can_view_photo_id(photo_id));

create or replace function public.zameel_open_profile_photo(p_owner uuid,p_kind text,p_url text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare photo uuid;
begin
 if not coalesce(public.zameel_can_view_profile_photo(p_owner,p_kind,p_url),false) then raise exception 'profile_photo_unavailable';end if;
 insert into public.zameel_profile_photos(owner_id,kind,image_url) values(p_owner,p_kind,p_url)
 on conflict(owner_id,kind,md5(image_url)) do update set image_url=excluded.image_url returning id into photo;
 return jsonb_build_object('id',photo,
 'likes',(select count(*) from public.zameel_profile_photo_likes where photo_id=photo),
 'liked',exists(select 1 from public.zameel_profile_photo_likes where photo_id=photo and user_id=auth.uid()));
end $$;

create or replace function public.zameel_toggle_profile_photo_like(p_photo uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare liked boolean;
begin
 if not coalesce(public.zameel_account_can_write(),false) or not coalesce(public.zameel_can_view_photo_id(p_photo),false) then raise exception 'profile_photo_unavailable';end if;
 perform 1 from public.zameel_profile_photos where id=p_photo for update;
 if exists(select 1 from public.zameel_profile_photo_likes where photo_id=p_photo and user_id=auth.uid()) then
 delete from public.zameel_profile_photo_likes where photo_id=p_photo and user_id=auth.uid();liked:=false;
 else insert into public.zameel_profile_photo_likes(photo_id,user_id) values(p_photo,auth.uid());liked:=true;end if;
 return jsonb_build_object('liked',liked,'likes',(select count(*) from public.zameel_profile_photo_likes where photo_id=p_photo));
end $$;

create or replace function public.zameel_comment_profile_photo(p_photo uuid,p_content text) returns uuid
language plpgsql security definer set search_path='' as $$
declare result uuid;
begin
 if not coalesce(public.zameel_account_can_write(),false) or not coalesce(public.zameel_can_view_photo_id(p_photo),false) then raise exception 'profile_photo_unavailable';end if;
 if not exists(select 1 from public.feature_flags where feature_key='comments' and is_enabled and display_mode='enabled' and scope_type='global' and scope_value='*') then raise exception 'comments_unavailable';end if;
 if p_content is null or length(trim(p_content)) not between 1 and 2000 then raise exception 'invalid_comment';end if;
 insert into public.zameel_profile_photo_comments(photo_id,user_id,content) values(p_photo,auth.uid(),trim(p_content)) returning id into result;
 return result;
end $$;
revoke all on function public.zameel_open_profile_photo(uuid,text,text),public.zameel_toggle_profile_photo_like(uuid),public.zameel_comment_profile_photo(uuid,text) from public,anon;
grant execute on function public.zameel_open_profile_photo(uuid,text,text),public.zameel_toggle_profile_photo_like(uuid),public.zameel_comment_profile_photo(uuid,text) to authenticated;
-- Photos use dedicated tables and cannot be submitted to the post-promotion RPC.
create or replace function public.zameel_profile_post_totals(p_owner uuid) returns jsonb
language sql stable security invoker set search_path='' as $$
 select jsonb_build_object('likes',coalesce(sum(likes_count),0),'comments',coalesce(sum(comments_count),0)) from public.posts where user_id=p_owner;
$$;
revoke all on function public.zameel_profile_post_totals(uuid) from public,anon;
grant execute on function public.zameel_profile_post_totals(uuid) to authenticated;
notify pgrst,'reload schema';
commit;
