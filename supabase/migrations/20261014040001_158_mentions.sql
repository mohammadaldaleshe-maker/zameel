begin;
lock table public.posts, public.clips, public.post_comments, public.clip_comments in access exclusive mode nowait;
alter table public.clips add column if not exists mention_ids156 uuid[] not null default '{}';
alter table public.post_comments add column if not exists mention_ids156 uuid[] not null default '{}';
alter table public.clip_comments add column if not exists mention_ids156 uuid[] not null default '{}';
create table public.zameel_mentions158 (
 kind text not null check(kind in ('post','clip','post_comment','clip_comment')),
 content_id uuid not null, user_id uuid not null references public.users(id) on delete cascade,
 actor_id uuid not null references public.users(id) on delete cascade,
 created_at timestamptz not null default now(), primary key(kind,content_id,user_id)
);
alter table public.zameel_mentions158 enable row level security;
revoke all on public.zameel_mentions158 from public,anon,authenticated;
create or replace function public.zameel_mention_visible158(p_kind text,p_id uuid,p_viewer uuid)
returns boolean language plpgsql stable security definer set search_path=public,pg_temp as $$
declare parent_id uuid;doc jsonb;
begin
 if p_viewer is null or p_kind not in ('post','clip','post_comment','clip_comment') then return false;end if;
 if p_kind='post_comment' then
 select post_id into parent_id from post_comments where id=p_id;
 return parent_id is not null and zameel_mention_visible158('post',parent_id,p_viewer);
 elsif p_kind='clip_comment' then
 select clip_id into parent_id from clip_comments where id=p_id;
 return parent_id is not null and zameel_mention_visible158('clip',parent_id,p_viewer);
 elsif p_kind='post' then select to_jsonb(p) into doc from posts p where id=p_id;
 else select to_jsonb(c) into doc from clips c where id=p_id;end if;
 if doc is null or coalesce((doc->>'is_hidden')::boolean,false) or doc->>'deleted_at' is not null or doc->>'upload_state156' is distinct from 'ready' then return false;end if;
 return exists(select 1 from users where id=(doc->>'user_id')::uuid and (id=p_viewer or account_privacy='public' or is_colleague(p_viewer,id))) and case when p_kind='post' then can_view_post(p_viewer,p_id) else can_view_clip(p_viewer,p_id) end;
end $$;
create or replace function public.zameel_mentions_read158(p_kind text,p_id uuid)
returns table(id uuid,name text) language sql stable security definer set search_path=public,pg_temp as $$
 select distinct u.id,u.name from users u join (
 select m.user_id from zameel_mentions158 m where m.kind=p_kind and m.content_id=p_id
 union select m.user_id from zameel_post_mentions156 m where p_kind='post' and m.post_id=p_id
 ) m on m.user_id=u.id
 where auth.uid() is not null and zameel_account_can_read() and zameel_mention_visible158(p_kind,p_id,auth.uid())
 and not is_blocked(auth.uid(),u.id) order by u.name,u.id limit 30
$$;
create or replace function public.zameel_mentions_notify158() returns trigger
language plpgsql security definer set search_path=public,pg_temp as $$
declare doc jsonb:=to_jsonb(new);kind text;body text;parent_id uuid;ids uuid[];everyone boolean;target uuid;fresh uuid;actor_name text;notification_type text;payload jsonb;
begin
 if tg_op='UPDATE' and (to_jsonb(old)-array['likes_count','comments_count','shares_count','views_count','updated_at'])=(doc-array['likes_count','comments_count','shares_count','views_count','updated_at']) then return new;end if;
 kind:=case tg_table_name when 'posts' then 'post' when 'clips' then 'clip' when 'post_comments' then 'post_comment' else 'clip_comment' end;
 if kind in ('post','clip') and doc->>'upload_state156'<>'ready' then return new;end if;
 body:=coalesce(doc->>'content',doc->>'text',doc->>'caption',doc->>'text_ar','')||' '||coalesce(doc->>'text_en','');
 everyone:=body ~ '(^|[[:space:]])@الجميع($|[[:space:][:punct:]])';
 ids:=new.mention_ids156;
 if cardinality(ids)>30 then raise exception 'too_many_mentions';end if;
 select name into actor_name from users where id=new.user_id;
 notification_type:=case kind when 'post' then 'post_mention' when 'post_comment' then 'post_mention' when 'clip' then 'clip_mention' else 'clip_comment_mention' end;
 parent_id:=case kind when 'post_comment' then (doc->>'post_id')::uuid when 'clip_comment' then (doc->>'clip_id')::uuid else new.id end;
 payload:=jsonb_build_object('type',notification_type,'post_id',case when kind in ('post','post_comment') then parent_id end,'clip_id',case when kind in ('clip','clip_comment') then parent_id end,'comment_id',case when kind in ('post_comment','clip_comment') then new.id end);
 for target in select distinct u.id from users u where u.id<>new.user_id
 and ((u.id=any(ids) and is_colleague(new.user_id,u.id)) or (everyone and (is_colleague(new.user_id,u.id) or exists(select 1 from follows f where f.follower_id=u.id and f.following_id=new.user_id))))
 and not is_blocked(new.user_id,u.id) and zameel_mention_visible158(kind,new.id,u.id)
 loop
  fresh:=null;
  insert into zameel_mentions158(kind,content_id,user_id,actor_id) values(kind,new.id,target,new.user_id) on conflict do nothing returning user_id into fresh;
  if fresh is not null and not(kind='post' and exists(select 1 from zameel_post_mentions156 where post_id=new.id and user_id=target)) then
   insert into notifications(user_id,actor_id,type,title_ar,title_en,body_ar,body_en,data,is_read)
   values(target,new.user_id,notification_type,'إشارة إليك','You were mentioned',coalesce(actor_name,'زميل')||' أشار إليك في '||case when kind like '%comment' then 'تعليق' else 'منشور' end,coalesce(actor_name,'A colleague')||' mentioned you',payload,false);
  end if;
 end loop;
 return new;
end $$;
create or replace function public.zameel_published156() returns trigger language plpgsql security definer set search_path=public,pg_temp as $$
declare target uuid;actor_name text;inserted_id uuid;completed_id uuid;
begin
 if new.upload_state156<>'ready' then return new;end if;
 if tg_op='UPDATE' and old.upload_state156='ready' then return new;end if;
 if new.background156 then completed_id:=null;insert into zameel_upload_completed156(resource_type,resource_id) values(tg_table_name,new.id) on conflict do nothing returning resource_id into completed_id;
 if completed_id is not null then insert into notifications(user_id,actor_id,type,title_ar,title_en,body_ar,body_en,data,is_read) values(new.user_id,new.user_id,'upload_complete','اكتمل النشر','Upload complete','تم رفع محتواك ونشره بنجاح','Your content was uploaded and published',jsonb_build_object('type','upload_complete','resource',tg_table_name,'post_id',case when tg_table_name='posts' then new.id else null end,'clip_id',case when tg_table_name='clips' then new.id else null end),false);end if;end if;
 return new;
end $$;

create trigger posts_mentions158 after insert or update on public.posts for each row execute function zameel_mentions_notify158();
create trigger clips_mentions158 after insert or update on public.clips for each row execute function zameel_mentions_notify158();
create trigger post_comments_mentions158 after insert or update on public.post_comments for each row execute function zameel_mentions_notify158();
create trigger clip_comments_mentions158 after insert or update on public.clip_comments for each row execute function zameel_mentions_notify158();
revoke all on function public.zameel_mention_visible158(text,uuid,uuid),public.zameel_mentions_notify158(),public.zameel_mentions_read158(text,uuid) from public,anon,authenticated;
grant execute on function public.zameel_mentions_read158(text,uuid) to authenticated;
notify pgrst,'reload schema';
commit;
