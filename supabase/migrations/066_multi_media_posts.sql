-- Zameel 066 — multi-media posts
-- Additive only. A post remains one row and one engagement target.
-- likes/post_comments/replies/saved_posts/shared_posts are intentionally untouched.

begin;

alter table public.posts
  add column if not exists media_items jsonb;

update public.posts
set media_items = '[]'::jsonb
where media_items is null;

alter table public.posts
  alter column media_items set default '[]'::jsonb,
  alter column media_items set not null;

alter table public.posts
  drop constraint if exists posts_media_items_check;

alter table public.posts
  add constraint posts_media_items_check
  check (
    case
      when jsonb_typeof(media_items) = 'array'
        then jsonb_array_length(media_items) <= 10
      else false
    end
  );

commit;
