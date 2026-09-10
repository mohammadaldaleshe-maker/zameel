-- Zameel v1.3.8: graduation book image storage and RLS.
-- Safe to run more than once. Does not delete existing images or page data.

insert into storage.buckets (id, name, public)
values ('graduation_book', 'graduation_book', true)
on conflict (id) do update set public = true;

-- Upload: owner or the page author/member may upload only into their own page folder.
drop policy if exists graduation_book_storage_insert on storage.objects;
create policy graduation_book_storage_insert
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'graduation_book'
  and exists (
    select 1
    from public.graduation_book_pages p
    join public.graduation_books b on b.id = p.book_id
    where p.book_id::text = split_part(name, '/', 1)
      and p.page_number::text = split_part(name, '/', 2)
      and (p.author_id = auth.uid() or b.owner_id = auth.uid())
  )
);

-- Read: the bucket is public, so existing getPublicUrl() links continue to work.
-- Authenticated users may also read through the storage API.
drop policy if exists graduation_book_storage_select on storage.objects;
create policy graduation_book_storage_select
on storage.objects
for select
to authenticated
using (bucket_id = 'graduation_book');

-- Delete/replace only files belonging to the current user's page.
drop policy if exists graduation_book_storage_delete on storage.objects;
create policy graduation_book_storage_delete
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'graduation_book'
  and exists (
    select 1
    from public.graduation_book_pages p
    join public.graduation_books b on b.id = p.book_id
    where p.book_id::text = split_part(name, '/', 1)
      and p.page_number::text = split_part(name, '/', 2)
      and (p.author_id = auth.uid() or b.owner_id = auth.uid())
  )
);
