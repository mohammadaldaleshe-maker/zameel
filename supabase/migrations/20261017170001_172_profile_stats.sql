-- 172: the personal statistics panel now shows real numbers.
-- What was wrong before:
--   * "الزملاء" counted mutual follows, but a colleague in Zameel is an accepted
--     friend request (the same rule stories and privacy already use);
--   * clips (shorts), their comments/likes and stories were not counted in
--     active days or in the weekly chart;
--   * hidden or still-uploading posts and clips were counted.
-- Only the caller's own numbers are returned. Same function names and old keys
-- are kept, so older app versions keep working.
begin;

create or replace function public.get_my_activity_stats()
returns jsonb
language sql
security definer
set search_path = ''
set row_security = off
stable
as $$
  select jsonb_build_object(
    'posts', (select count(*) from public.posts p
              where p.user_id = auth.uid()
                and not coalesce(p.is_hidden, false)
                and coalesce(p.upload_state156, 'ready') = 'ready'),
    'clips', (select count(*) from public.clips c
              where c.user_id = auth.uid()
                and not coalesce(c.is_hidden, false)
                and coalesce(c.upload_state156, 'ready') = 'ready'),
    'stories', (select count(*) from public.social_stories s where s.user_id = auth.uid()),
    'likes', (select count(*) from public.likes l
              join public.posts p on p.id = l.post_id
              where p.user_id = auth.uid() and not coalesce(p.is_hidden, false))
           + (select count(*) from public.clip_likes cl
              join public.clips c on c.id = cl.clip_id
              where c.user_id = auth.uid() and not coalesce(c.is_hidden, false)),
    'comments', (select count(*) from public.post_comments c where c.user_id = auth.uid())
              + (select count(*) from public.clip_comments c where c.user_id = auth.uid()),
    'friends', (select count(distinct case when fr.sender_id = auth.uid() then fr.receiver_id else fr.sender_id end)
                from public.friend_requests fr
                where fr.status = 'accepted'
                  and auth.uid() in (fr.sender_id, fr.receiver_id)
                  and not exists (
                    select 1 from public.user_blocks b
                    where (b.blocker_id = auth.uid()
                           and b.blocked_id = case when fr.sender_id = auth.uid() then fr.receiver_id else fr.sender_id end)
                       or (b.blocked_id = auth.uid()
                           and b.blocker_id = case when fr.sender_id = auth.uid() then fr.receiver_id else fr.sender_id end))),
    'followers', (select count(*) from public.follows f where f.following_id = auth.uid()),
    'following', (select count(*) from public.follows f where f.follower_id = auth.uid()),
    'saved_posts', (select count(*) from public.saved_posts s where s.user_id = auth.uid()),
    'saved_books', (select count(*) from public.book_listings b
                    where b.owner_id = auth.uid() and b.status <> 'withdrawn'),
    'clip_views', (select coalesce(sum(c.views_count), 0)::bigint from public.clips c
                   where c.user_id = auth.uid() and not coalesce(c.is_hidden, false)),
    'active_days', (
      select count(distinct d)::int from (
        select p.created_at::date d from public.posts p where p.user_id = auth.uid()
        union all select c.created_at::date from public.clips c where c.user_id = auth.uid()
        union all select s.created_at::date from public.social_stories s where s.user_id = auth.uid()
        union all select c.created_at::date from public.post_comments c where c.user_id = auth.uid()
        union all select c.created_at::date from public.clip_comments c where c.user_id = auth.uid()
        union all select l.created_at::date from public.likes l where l.user_id = auth.uid()
        union all select l.created_at::date from public.clip_likes l where l.user_id = auth.uid()
      ) q
    )
  );
$$;

create or replace function public.get_my_weekly_activity()
returns table(day_date date, activity_count bigint)
language sql
security definer
set search_path = ''
set row_security = off
stable
as $$
  with days as (
    select generate_series(current_date - 6, current_date, '1 day'::interval)::date d
  ), activity as (
    select p.created_at::date d from public.posts p where p.user_id = auth.uid() and p.created_at >= current_date - 6
    union all select c.created_at::date from public.clips c where c.user_id = auth.uid() and c.created_at >= current_date - 6
    union all select s.created_at::date from public.social_stories s where s.user_id = auth.uid() and s.created_at >= current_date - 6
    union all select c.created_at::date from public.post_comments c where c.user_id = auth.uid() and c.created_at >= current_date - 6
    union all select c.created_at::date from public.clip_comments c where c.user_id = auth.uid() and c.created_at >= current_date - 6
    union all select l.created_at::date from public.likes l where l.user_id = auth.uid() and l.created_at >= current_date - 6
    union all select l.created_at::date from public.clip_likes l where l.user_id = auth.uid() and l.created_at >= current_date - 6
  )
  select days.d, count(activity.d) from days left join activity on activity.d = days.d group by days.d order by days.d;
$$;

revoke all on function public.get_my_activity_stats(), public.get_my_weekly_activity() from public, anon;
grant execute on function public.get_my_activity_stats(), public.get_my_weekly_activity() to authenticated;
notify pgrst, 'reload schema';

commit;
