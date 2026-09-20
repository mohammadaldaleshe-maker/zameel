-- Zameel 067 — multi-media posts runtime repair
-- Scope: only normal post media storage/schema. No engagement/chat/call/story tables change.
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
    jsonb_typeof(media_items) = 'array'
    and jsonb_array_length(media_items) <= 10
  );

insert into storage.buckets (id, name, public)
values ('posts', 'posts', true)
on conflict (id) do update set public = true;

drop policy if exists posts_public_read on storage.objects;
create policy posts_public_read
on storage.objects for select
to public using (bucket_id = 'posts');

drop policy if exists posts_owner_insert on storage.objects;
create policy posts_owner_insert
on storage.objects for insert
to authenticated
with check (
  bucket_id = 'posts'
  and (storage.foldername(name))[1] = auth.uid()::text
);

drop policy if exists posts_owner_delete on storage.objects;
create policy posts_owner_delete
on storage.objects for delete
to authenticated
using (
  bucket_id = 'posts'
  and (storage.foldername(name))[1] = auth.uid()::text
);

commit;
