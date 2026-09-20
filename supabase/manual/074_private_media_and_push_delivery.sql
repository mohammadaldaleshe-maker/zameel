-- Zameel 074: private media storage + idempotent per-device push delivery.
-- Additive migration: existing public media keeps working unchanged.

insert into storage.buckets (id, name, public, file_size_limit)
values ('zameel_private_media', 'zameel_private_media', false, 83886080)
on conflict (id) do update set public = false, file_size_limit = excluded.file_size_limit;

-- Close the direct-link privacy gap for legacy media too. These buckets used to
-- be public; keeping the stored URL strings is harmless because the app now
-- exchanges them for signed URLs before rendering.
update storage.buckets set public = false where id in ('posts', 'graduation_book');

drop policy if exists posts_public_read on storage.objects;
drop policy if exists posts_secure_reference_read on storage.objects;
create policy posts_secure_reference_read
on storage.objects for select to authenticated
using (
  bucket_id = 'posts'
  and (
    (storage.foldername(name))[1] = auth.uid()::text
    or exists (
      select 1 from public.posts p
      where right(coalesce(p.image_url,''), length(name)) = name
         or right(coalesce(p.video_url,''), length(name)) = name
         or position(name in p.media_items::text) > 0
    )
    or exists (
      select 1 from public.social_stories s
      where right(coalesce(s.media_url,''), length(name)) = name
    )
    or exists (
      select 1 from public.clips c
      where right(coalesce(c.video_url,''), length(name)) = name
    )
  )
);

drop policy if exists posts_admin_delete on storage.objects;
create policy posts_admin_delete
on storage.objects for delete to authenticated
using (
  bucket_id = 'posts'
  and exists (select 1 from public.users u where u.id = auth.uid() and u.role = 'admin')
);

drop policy if exists graduation_book_storage_select on storage.objects;
drop policy if exists graduation_book_secure_read on storage.objects;
create policy graduation_book_secure_read
on storage.objects for select to authenticated
using (
  bucket_id = 'graduation_book'
  and exists (
    select 1
    from public.graduation_book_pages p
    where p.book_id::text = split_part(name, '/', 1)
      and p.page_number::text = split_part(name, '/', 2)
  )
);

-- Private object paths are:
--   posts/<post_id>/<owner_id>/...
--   stories/<story_id>/<owner_id>/...
--   clips/<clip_id>/<owner_id>/...
--   graduation/<book_id>/<owner_id>/...
-- Reads intentionally depend on the corresponding table's RLS. If the signed-in
-- user cannot SELECT the row, they cannot mint a signed Storage URL either.

drop policy if exists zameel_private_media_read on storage.objects;
create policy zameel_private_media_read
on storage.objects for select to authenticated
using (
  bucket_id = 'zameel_private_media'
  and (
    ((storage.foldername(name))[1] = 'posts' and exists (
      select 1 from public.posts p
      where p.id = nullif((storage.foldername(name))[2], '')::uuid
    ))
    or ((storage.foldername(name))[1] = 'stories' and exists (
      select 1 from public.social_stories s
      where s.id = nullif((storage.foldername(name))[2], '')::uuid
    ))
    or ((storage.foldername(name))[1] = 'clips' and exists (
      select 1 from public.clips c
      where c.id = nullif((storage.foldername(name))[2], '')::uuid
    ))
    or ((storage.foldername(name))[1] = 'graduation' and exists (
      select 1 from public.graduation_books b
      where b.id = nullif((storage.foldername(name))[2], '')::uuid
    ))
  )
);

drop policy if exists zameel_private_media_insert on storage.objects;
create policy zameel_private_media_insert
on storage.objects for insert to authenticated
with check (
  bucket_id = 'zameel_private_media'
  and (storage.foldername(name))[3] = auth.uid()::text
  and (
    ((storage.foldername(name))[1] = 'posts' and exists (
      select 1 from public.posts p
      where p.id = nullif((storage.foldername(name))[2], '')::uuid and p.user_id = auth.uid()
    ))
    or ((storage.foldername(name))[1] = 'stories' and exists (
      select 1 from public.social_stories s
      where s.id = nullif((storage.foldername(name))[2], '')::uuid and s.user_id = auth.uid()
    ))
    or ((storage.foldername(name))[1] = 'clips' and exists (
      select 1 from public.clips c
      where c.id = nullif((storage.foldername(name))[2], '')::uuid and c.user_id = auth.uid()
    ))
    or ((storage.foldername(name))[1] = 'graduation' and exists (
      select 1 from public.graduation_books b
      where b.id = nullif((storage.foldername(name))[2], '')::uuid and b.owner_id = auth.uid()
    ))
  )
);

drop policy if exists zameel_private_media_update on storage.objects;
create policy zameel_private_media_update
on storage.objects for update to authenticated
using (bucket_id = 'zameel_private_media' and (storage.foldername(name))[3] = auth.uid()::text)
with check (bucket_id = 'zameel_private_media' and (storage.foldername(name))[3] = auth.uid()::text);

drop policy if exists zameel_private_media_delete on storage.objects;
create policy zameel_private_media_delete
on storage.objects for delete to authenticated
using (
  bucket_id = 'zameel_private_media'
  and (
    (storage.foldername(name))[3] = auth.uid()::text
    or exists (select 1 from public.users u where u.id = auth.uid() and u.role = 'admin')
  )
);


-- Atomically attach the current FCM token to the currently authenticated user.
-- A phone can legitimately change accounts while Firebase keeps the same token;
-- doing this in a SECURITY DEFINER function avoids a stale previous-user row
-- blocking the new session through the unique(token) constraint and RLS.
create or replace function public.claim_push_device_token(
  p_token text,
  p_platform text default 'android',
  p_locale text default 'ar'
) returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'not_authenticated';
  end if;
  if nullif(trim(p_token), '') is null then
    raise exception 'empty_push_token';
  end if;

  insert into public.push_device_tokens(user_id, token, platform, locale, updated_at)
  values (auth.uid(), trim(p_token), coalesce(nullif(trim(p_platform), ''), 'android'),
          coalesce(nullif(trim(p_locale), ''), 'ar'), now())
  on conflict (token) do update
    set user_id = excluded.user_id,
        platform = excluded.platform,
        locale = excluded.locale,
        updated_at = now();
end;
$$;

revoke all on function public.claim_push_device_token(text,text,text) from public;
grant execute on function public.claim_push_device_token(text,text,text) to authenticated;

create table if not exists public.push_notification_deliveries (
  queue_id uuid not null references public.push_notification_queue(id) on delete cascade,
  token_id uuid not null references public.push_device_tokens(id) on delete cascade,
  status text not null default 'pending' check (status in ('pending','sent','failed')),
  attempts integer not null default 0,
  last_error text,
  sent_at timestamptz,
  updated_at timestamptz not null default now(),
  primary key (queue_id, token_id)
);

alter table public.push_notification_deliveries enable row level security;
-- Service-role Edge Functions bypass RLS. No client policies are intentionally
-- granted because delivery bookkeeping is server-internal.

create index if not exists push_notification_deliveries_status_idx
  on public.push_notification_deliveries(queue_id, status);
