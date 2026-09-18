-- Zameel 061: production hardening without changing auth roles/admin model.
-- Focus: block/privacy enforcement, search performance, book realtime support.

begin;

-- ---------------------------------------------------------------------------
-- Visibility helpers. SECURITY DEFINER avoids recursive RLS while returning
-- only booleans; every helper explicitly enforces blocking and audience rules.
-- ---------------------------------------------------------------------------
create or replace function public.can_view_post(p_viewer uuid, p_post_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.posts p
    join public.users u on u.id = p.user_id
    where p.id = p_post_id
      and (
        p.user_id = p_viewer
        or (
          not public.is_blocked(p_viewer, p.user_id)
          and (u.account_privacy = 'public' or public.is_colleague(p_viewer, p.user_id))
          and (
            p.audience = 'public'
            or (p.audience = 'friends' and public.is_colleague(p_viewer, p.user_id))
          )
        )
      )
  );
$$;

create or replace function public.can_view_story(p_viewer uuid, p_story_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.social_stories s
    where s.id = p_story_id
      and s.expires_at > now()
      and (
        s.user_id = p_viewer
        or (
          not public.is_blocked(p_viewer, s.user_id)
          and (
            s.audience = 'public'
            or (s.audience = 'friends' and public.is_colleague(p_viewer, s.user_id))
            or (
              s.audience = 'close_friends'
              and exists (
                select 1 from public.close_friends cf
                where cf.owner_id = s.user_id and cf.friend_id = p_viewer
              )
            )
            or (
              s.audience in ('college','faculty')
              and exists (
                select 1
                from public.users viewer
                join public.users owner on owner.id = s.user_id
                where viewer.id = p_viewer
                  and nullif(trim(lower(viewer.university)), '') is not null
                  and nullif(trim(lower(viewer.college)), '') is not null
                  and trim(lower(viewer.university)) = trim(lower(owner.university))
                  and trim(lower(viewer.college)) = trim(lower(owner.college))
              )
            )
            or (
              s.audience in ('department','group')
              and exists (
                select 1
                from public.users viewer
                join public.users owner on owner.id = s.user_id
                where viewer.id = p_viewer
                  and nullif(trim(lower(viewer.university)), '') is not null
                  and nullif(trim(lower(viewer.college)), '') is not null
                  and nullif(trim(lower(viewer.department)), '') is not null
                  and trim(lower(viewer.university)) = trim(lower(owner.university))
                  and trim(lower(viewer.college)) = trim(lower(owner.college))
                  and trim(lower(viewer.department)) = trim(lower(owner.department))
              )
            )
          )
        )
      )
  );
$$;

create or replace function public.can_view_clip(p_viewer uuid, p_clip_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.clips c
    where c.id = p_clip_id
      and (
        c.user_id = p_viewer
        or (
          not public.is_blocked(p_viewer, c.user_id)
          and c.is_hidden = false
          and (
            c.audience = 'public'
            or (c.audience = 'friends' and public.is_colleague(p_viewer, c.user_id))
            or c.audience in ('faculty','group')
          )
        )
      )
  );
$$;

revoke execute on function public.can_view_post(uuid,uuid) from public, anon;
revoke execute on function public.can_view_story(uuid,uuid) from public, anon;
revoke execute on function public.can_view_clip(uuid,uuid) from public, anon;
grant execute on function public.can_view_post(uuid,uuid) to authenticated;
grant execute on function public.can_view_story(uuid,uuid) to authenticated;
grant execute on function public.can_view_clip(uuid,uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- Profiles: remove parallel SELECT policies so an older permissive policy
-- cannot OR around blocking/privacy.
-- ---------------------------------------------------------------------------
drop policy if exists users_select_authenticated on public.users;
drop policy if exists users_select_privacy_v136 on public.users;
create policy users_select_authenticated
on public.users for select to authenticated
using (
  id = auth.uid()
  or (
    not public.is_blocked(auth.uid(), id)
    and (account_privacy = 'public' or public.is_colleague(auth.uid(), id))
  )
);

-- Posts: one canonical read policy.
drop policy if exists posts_select_authenticated on public.posts;
drop policy if exists posts_select_privacy_v136 on public.posts;
create policy posts_select_authenticated
on public.posts for select to authenticated
using (public.can_view_post(auth.uid(), id));

-- Stories and clips: canonical read policies with block enforcement.
drop policy if exists stories_read on public.social_stories;
create policy stories_read
on public.social_stories for select to authenticated
using (public.can_view_story(auth.uid(), id));

drop policy if exists clips_read on public.clips;
create policy clips_read
on public.clips for select to authenticated
using (public.can_view_clip(auth.uid(), id));

-- Shared content must respect the source content's canonical visibility.
drop policy if exists shared_posts_select_visible on public.shared_posts;
create policy shared_posts_select_visible
on public.shared_posts for select to authenticated
using (shared_by = auth.uid() or public.can_view_post(auth.uid(), post_id));

drop policy if exists shared_clips_read on public.shared_clips;
create policy shared_clips_read
on public.shared_clips for select to authenticated
using (shared_by = auth.uid() or public.can_view_clip(auth.uid(), clip_id));

drop policy if exists shared_posts_insert_self on public.shared_posts;
create policy shared_posts_insert_self
on public.shared_posts for insert to authenticated
with check (shared_by = auth.uid() and public.can_view_post(auth.uid(), post_id));

drop policy if exists shared_clips_insert on public.shared_clips;
create policy shared_clips_insert
on public.shared_clips for insert to authenticated
with check (shared_by = auth.uid() and public.can_view_clip(auth.uid(), clip_id));

-- Post interactions inherit post visibility.
drop policy if exists likes_select_authenticated on public.likes;
create policy likes_select_authenticated
on public.likes for select to authenticated
using (public.can_view_post(auth.uid(), post_id));

drop policy if exists likes_insert_self on public.likes;
create policy likes_insert_self
on public.likes for insert to authenticated
with check (user_id = auth.uid() and public.can_view_post(auth.uid(), post_id));

drop policy if exists saved_posts_insert_self on public.saved_posts;
create policy saved_posts_insert_self
on public.saved_posts for insert to authenticated
with check (user_id = auth.uid() and public.can_view_post(auth.uid(), post_id));

drop policy if exists post_comments_select_authenticated on public.post_comments;
create policy post_comments_select_authenticated
on public.post_comments for select to authenticated
using (public.can_view_post(auth.uid(), post_id));

drop policy if exists post_comments_insert_self on public.post_comments;
create policy post_comments_insert_self
on public.post_comments for insert to authenticated
with check (user_id = auth.uid() and public.can_view_post(auth.uid(), post_id));

drop policy if exists post_comment_likes_read on public.post_comment_likes;
create policy post_comment_likes_read
on public.post_comment_likes for select to authenticated
using (
  exists (
    select 1 from public.post_comments pc
    where pc.id = comment_id
      and public.can_view_post(auth.uid(), pc.post_id)
  )
);

drop policy if exists post_comment_likes_insert_self on public.post_comment_likes;
create policy post_comment_likes_insert_self
on public.post_comment_likes for insert to authenticated
with check (
  user_id = auth.uid()
  and exists (
    select 1 from public.post_comments pc
    where pc.id = comment_id
      and public.can_view_post(auth.uid(), pc.post_id)
  )
);

-- Clip interactions inherit clip visibility instead of using global reads.
drop policy if exists clip_likes_read on public.clip_likes;
create policy clip_likes_read
on public.clip_likes for select to authenticated
using (public.can_view_clip(auth.uid(), clip_id));

drop policy if exists clip_likes_self on public.clip_likes;
drop policy if exists clip_likes_insert_self on public.clip_likes;
drop policy if exists clip_likes_delete_self on public.clip_likes;
create policy clip_likes_insert_self
on public.clip_likes for insert to authenticated
with check (user_id = auth.uid() and public.can_view_clip(auth.uid(), clip_id));
create policy clip_likes_delete_self
on public.clip_likes for delete to authenticated
using (user_id = auth.uid());

drop policy if exists clip_comments_read on public.clip_comments;
create policy clip_comments_read
on public.clip_comments for select to authenticated
using (public.can_view_clip(auth.uid(), clip_id));

drop policy if exists clip_comments_self on public.clip_comments;
create policy clip_comments_self
on public.clip_comments for insert to authenticated
with check (user_id = auth.uid() and public.can_view_clip(auth.uid(), clip_id));

drop policy if exists clip_comment_likes_read on public.clip_comment_likes;
create policy clip_comment_likes_read
on public.clip_comment_likes for select to authenticated
using (
  exists (
    select 1 from public.clip_comments cc
    where cc.id = comment_id
      and public.can_view_clip(auth.uid(), cc.clip_id)
  )
);

drop policy if exists clip_comment_likes_insert_self on public.clip_comment_likes;
create policy clip_comment_likes_insert_self
on public.clip_comment_likes for insert to authenticated
with check (
  user_id = auth.uid()
  and exists (
    select 1 from public.clip_comments cc
    where cc.id = comment_id
      and public.can_view_clip(auth.uid(), cc.clip_id)
  )
);

-- Story engagement must not bypass story visibility through direct API calls.
drop policy if exists story_views_self_write on public.story_views;
create policy story_views_self_write
on public.story_views for insert to authenticated
with check (viewer_id = auth.uid() and public.can_view_story(auth.uid(), story_id));

drop policy if exists story_views_self_update on public.story_views;
create policy story_views_self_update
on public.story_views for update to authenticated
using (viewer_id = auth.uid())
with check (viewer_id = auth.uid() and public.can_view_story(auth.uid(), story_id));

drop policy if exists story_reactions_self_insert on public.story_reactions;
create policy story_reactions_self_insert
on public.story_reactions for insert to authenticated
with check (user_id = auth.uid() and public.can_view_story(auth.uid(), story_id));

drop policy if exists story_reactions_self_update on public.story_reactions;
create policy story_reactions_self_update
on public.story_reactions for update to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid() and public.can_view_story(auth.uid(), story_id));

-- The compatibility RPC used by the story viewer also checks canonical visibility.
create or replace function public.record_story_view_compat(p_story_id uuid)
returns void
language plpgsql
security definer
set search_path = public
set row_security = off
as $$
declare
  me uuid := auth.uid();
  owner_id uuid;
  has_viewer_id boolean;
  has_user_id boolean;
begin
  if me is null then raise exception 'not_authenticated'; end if;
  if not public.can_view_story(me, p_story_id) then return; end if;

  select s.user_id into owner_id
  from public.social_stories s
  where s.id = p_story_id and s.expires_at > now();
  if owner_id is null or owner_id = me then return; end if;

  select exists (
    select 1 from information_schema.columns
    where table_schema='public' and table_name='story_views' and column_name='viewer_id'
  ) into has_viewer_id;
  select exists (
    select 1 from information_schema.columns
    where table_schema='public' and table_name='story_views' and column_name='user_id'
  ) into has_user_id;

  if has_viewer_id and has_user_id then
    execute $q$
      insert into public.story_views(story_id, viewer_id, user_id, viewed_at)
      values ($1, $2, $2, now()) on conflict do nothing
    $q$ using p_story_id, me;
    execute 'update public.story_views set viewed_at=now() where story_id=$1 and (viewer_id=$2 or user_id=$2)'
      using p_story_id, me;
  elsif has_viewer_id then
    execute $q$
      insert into public.story_views(story_id, viewer_id, viewed_at)
      values ($1, $2, now()) on conflict do nothing
    $q$ using p_story_id, me;
    execute 'update public.story_views set viewed_at=now() where story_id=$1 and viewer_id=$2'
      using p_story_id, me;
  elsif has_user_id then
    execute $q$
      insert into public.story_views(story_id, user_id, viewed_at)
      values ($1, $2, now()) on conflict do nothing
    $q$ using p_story_id, me;
    execute 'update public.story_views set viewed_at=now() where story_id=$1 and user_id=$2'
      using p_story_id, me;
  else
    raise exception 'story_views has no viewer identity column';
  end if;
end;
$$;
revoke execute on function public.record_story_view_compat(uuid) from public, anon;
grant execute on function public.record_story_view_compat(uuid) to authenticated;

-- Book listings from users who blocked each other are not exposed.
drop policy if exists book_listings_read on public.book_listings;
create policy book_listings_read
on public.book_listings for select to authenticated
using (owner_id = auth.uid() or not public.is_blocked(auth.uid(), owner_id));

-- ---------------------------------------------------------------------------
-- Search indexes for the new server-side advanced search.
-- ---------------------------------------------------------------------------
create extension if not exists pg_trgm;
create index if not exists users_name_trgm_idx on public.users using gin (name gin_trgm_ops);
create index if not exists users_university_trgm_idx on public.users using gin (university gin_trgm_ops);
create index if not exists users_college_trgm_idx on public.users using gin (college gin_trgm_ops);
create index if not exists users_department_trgm_idx on public.users using gin (department gin_trgm_ops);
create index if not exists posts_text_ar_trgm_idx on public.posts using gin (text_ar gin_trgm_ops);
create index if not exists posts_text_en_trgm_idx on public.posts using gin (text_en gin_trgm_ops);
create index if not exists book_listings_title_trgm_idx on public.book_listings using gin (title gin_trgm_ops);
create index if not exists book_listings_author_trgm_idx on public.book_listings using gin (author gin_trgm_ops);
create index if not exists book_listings_subject_trgm_idx on public.book_listings using gin (subject gin_trgm_ops);

-- Book request chat now uses Supabase Realtime instead of polling.
do $$
begin
  alter publication supabase_realtime add table public.book_exchange_messages;
exception
  when duplicate_object then null;
  when undefined_object then null;
end $$;

commit;
