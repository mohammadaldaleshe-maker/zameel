begin;
alter table public.posts add column if not exists upload_state156 text not null default 'ready' check(upload_state156 in ('pending','ready'));
alter table public.posts add column if not exists mention_ids156 uuid[] not null default '{}';
alter table public.posts add column if not exists background156 boolean not null default false;
alter table public.clips add column if not exists upload_state156 text not null default 'ready' check(upload_state156 in ('pending','ready'));
alter table public.clips add column if not exists background156 boolean not null default false;
alter table public.social_stories add column if not exists upload_state156 text not null default 'ready' check(upload_state156 in ('pending','ready'));
alter table public.social_stories add column if not exists background156 boolean not null default false;
drop policy if exists posts_ready156 on public.posts;
create policy posts_ready156 on public.posts as restrictive for select to authenticated using(user_id=auth.uid() or upload_state156='ready');
drop policy if exists clips_ready156 on public.clips;
create policy clips_ready156 on public.clips as restrictive for select to authenticated using(user_id=auth.uid() or upload_state156='ready');
drop policy if exists stories_ready156 on public.social_stories;
create policy stories_ready156 on public.social_stories as restrictive for select to authenticated using(user_id=auth.uid() or upload_state156='ready');
create or replace function public.zameel_shared_activity_156(p_owner uuid default null,p_kind text default 'all',p_offset integer default 0) returns setof jsonb language sql stable security invoker set search_path=public,pg_temp as $$
 select doc from (
 select jsonb_build_object('id',s.id,'kind','post','shared_by',s.shared_by,'shared_at',s.created_at,'created_at',s.created_at,'name',u.name,'posts',to_jsonb(p)||jsonb_build_object('users',jsonb_build_object('name',author.name,'profile_image',author.profile_image,'verification_expires_at',author.verification_expires_at))) doc,s.created_at stamp
 from shared_posts s join posts p on p.id=s.post_id join users u on u.id=s.shared_by join users author on author.id=p.user_id
 where (p_owner is null or s.shared_by=p_owner) and p_kind in ('all','post') and p.upload_state156='ready' and not p.is_hidden and (to_jsonb(p)->>'deleted_at') is null and (p_owner is not null or p.audience='public') and not is_blocked(auth.uid(),s.shared_by)
 union all
 select jsonb_build_object('id',s.id,'kind','clip','shared_by',s.shared_by,'shared_at',s.created_at,'created_at',s.created_at,'name',u.name,'clips',to_jsonb(c)) doc,s.created_at stamp
 from shared_clips s join clips c on c.id=s.clip_id join users u on u.id=s.shared_by
 where (p_owner is null or s.shared_by=p_owner) and p_kind in ('all','clip') and c.upload_state156='ready' and not c.is_hidden and (to_jsonb(c)->>'deleted_at') is null and c.video_url not like 'uploading://%' and (p_owner is not null or c.audience='public') and not is_blocked(auth.uid(),s.shared_by)
 ) activity order by stamp desc,doc->>'id' limit 30 offset greatest(0,least(p_offset,100000));
$$;
create or replace function public.zameel_mention_candidates_156(p_query text default '') returns table(id uuid,name text) language sql stable security definer set search_path=public,pg_temp as $$
 select u.id,u.name from users u where auth.uid() is not null and zameel_account_can_read() and u.id<>auth.uid() and is_colleague(auth.uid(),u.id) and not is_blocked(auth.uid(),u.id) and u.name ilike '%'||left(p_query,100)||'%' order by u.name,u.id limit 20
$$;
create table if not exists public.zameel_post_mentions156(post_id uuid references public.posts(id) on delete cascade,user_id uuid references public.users(id) on delete cascade,created_at timestamptz not null default now(),primary key(post_id,user_id));
alter table public.zameel_post_mentions156 enable row level security;
revoke all on public.zameel_post_mentions156 from anon,authenticated;
create table if not exists public.zameel_upload_completed156(resource_type text,resource_id uuid,primary key(resource_type,resource_id));
alter table public.zameel_upload_completed156 enable row level security;revoke all on public.zameel_upload_completed156 from anon,authenticated;
create or replace function public.zameel_published156() returns trigger language plpgsql security definer set search_path=public,pg_temp as $$
declare target uuid;actor_name text;inserted_id uuid;completed_id uuid;
begin
 if new.upload_state156<>'ready' then return new;end if;
 if tg_op='UPDATE' and old.upload_state156='ready' then return new;end if;
 if tg_table_name='posts' then
 if cardinality(new.mention_ids156)>30 then raise exception 'too_many_mentions';end if;
 select name into actor_name from users where id=new.user_id;
 foreach target in array new.mention_ids156 loop
 if target=new.user_id or not is_colleague(new.user_id,target) or is_blocked(new.user_id,target) or not can_view_post(target,new.id) then continue;end if;
 inserted_id:=null;insert into zameel_post_mentions156(post_id,user_id) values(new.id,target) on conflict do nothing returning user_id into inserted_id;
 if inserted_id is not null then insert into notifications(user_id,actor_id,type,title_ar,title_en,body_ar,body_en,data,is_read) values(target,new.user_id,'post_mention','إشارة في منشور','Mentioned in a post',coalesce(actor_name,'زميل')||' أشار إليك في منشوره',coalesce(actor_name,'A colleague')||' mentioned you in a post',jsonb_build_object('post_id',new.id,'type','post_mention'),false);end if;
 end loop;end if;
 if new.background156 then completed_id:=null;insert into zameel_upload_completed156(resource_type,resource_id) values(tg_table_name,new.id) on conflict do nothing returning resource_id into completed_id;
 if completed_id is not null then insert into notifications(user_id,actor_id,type,title_ar,title_en,body_ar,body_en,data,is_read) values(new.user_id,new.user_id,'upload_complete','اكتمل النشر','Upload complete','تم رفع محتواك ونشره بنجاح','Your content was uploaded and published',jsonb_build_object('type','upload_complete','resource',tg_table_name,'post_id',case when tg_table_name='posts' then new.id else null end,'clip_id',case when tg_table_name='clips' then new.id else null end),false);end if;end if;
 return new;
end $$;
drop trigger if exists posts_published156 on public.posts;
create trigger posts_published156 after insert or update of upload_state156 on public.posts for each row execute function zameel_published156();
drop trigger if exists clips_published156 on public.clips;
create trigger clips_published156 after insert or update of upload_state156 on public.clips for each row execute function zameel_published156();
drop trigger if exists stories_published156 on public.social_stories;
create trigger stories_published156 after insert or update of upload_state156 on public.social_stories for each row execute function zameel_published156();
revoke all on function public.zameel_published156(),public.zameel_shared_activity_156(uuid,text,integer),public.zameel_mention_candidates_156(text) from public,anon;
grant execute on function public.zameel_shared_activity_156(uuid,text,integer),public.zameel_mention_candidates_156(text) to authenticated;
create or replace function public.zameel_post_mentions_read156(p_post uuid) returns table(id uuid,name text) language sql stable security definer set search_path=public,pg_temp as $$ select u.id,u.name from zameel_post_mentions156 m join users u on u.id=m.user_id join posts p on p.id=m.post_id where m.post_id=p_post and auth.uid() is not null and zameel_account_can_read() and can_view_post(auth.uid(),p_post) and not p.is_hidden and (to_jsonb(p)->>'deleted_at') is null and p.upload_state156='ready' $$;
revoke all on function public.zameel_post_mentions_read156(uuid) from public,anon;grant execute on function public.zameel_post_mentions_read156(uuid) to authenticated;
notify pgrst,'reload schema';commit;
