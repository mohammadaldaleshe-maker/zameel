-- Zameel 042: performance, 45-second media policy, profile bio and call lookup.
-- Run once after migration 041.

begin;

create index if not exists posts_created_at_desc_idx
  on public.posts(created_at desc);
create index if not exists posts_user_created_at_idx
  on public.posts(user_id, created_at desc);
create index if not exists likes_user_post_idx
  on public.likes(user_id, post_id);
create index if not exists saved_posts_user_post_idx
  on public.saved_posts(user_id, post_id);
create index if not exists friend_requests_sender_status_idx
  on public.friend_requests(sender_id, status);
create index if not exists friend_requests_receiver_status_idx
  on public.friend_requests(receiver_id, status);
create index if not exists social_stories_expiry_created_idx
  on public.social_stories(expires_at, created_at desc);
create index if not exists clips_audience_created_idx
  on public.clips(audience, created_at desc) where is_hidden = false;
create index if not exists notifications_unread_user_idx
  on public.notifications(user_id, created_at desc) where is_read = false;
create index if not exists direct_call_sessions_callee_status_idx
  on public.direct_call_sessions(callee_id, status, created_at desc);
create index if not exists campus_partner_places_university_status_idx
  on public.campus_partner_places(university_name, status);

alter table public.users drop constraint if exists users_bio_length_check;
alter table public.users add constraint users_bio_length_check
  check (char_length(coalesce(bio, '')) <= 160) not valid;

alter table public.clips drop constraint if exists clips_duration_45_seconds_check;
alter table public.clips add constraint clips_duration_45_seconds_check
  check (duration_seconds between 1 and 45) not valid;

commit;
