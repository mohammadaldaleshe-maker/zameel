begin;

insert into storage.buckets (id, name, public) values ('clips', 'clips', true) on conflict (id) do nothing;
drop policy if exists clips_public_read on storage.objects;
create policy clips_public_read on storage.objects for select to public using (bucket_id = 'clips');
drop policy if exists clips_owner_insert on storage.objects;
create policy clips_owner_insert on storage.objects for insert to authenticated with check (bucket_id = 'clips' and (storage.foldername(name))[1] = auth.uid()::text);
drop policy if exists clips_owner_update on storage.objects;
create policy clips_owner_update on storage.objects for update to authenticated using (bucket_id = 'clips' and (storage.foldername(name))[1] = auth.uid()::text);
drop policy if exists clips_owner_delete on storage.objects;
create policy clips_owner_delete on storage.objects for delete to authenticated using (bucket_id = 'clips' and (storage.foldername(name))[1] = auth.uid()::text);

alter table public.posts drop constraint if exists posts_audience_check;
alter table public.posts add constraint posts_audience_check check (audience in ('public','friends','private'));
alter table public.clips add column if not exists audience text not null default 'public';
alter table public.clips drop constraint if exists clips_audience_check;
alter table public.clips add constraint clips_audience_check check (audience in ('public','friends','private'));
drop policy if exists clips_read on public.clips;
create policy clips_read on public.clips for select to authenticated using (user_id = auth.uid() or audience = 'public' or (audience = 'friends' and exists (select 1 from public.follows f where f.follower_id = auth.uid() and f.following_id = clips.user_id)));

create index if not exists university_calendar_events_fetched_idx on public.university_calendar_events(university_key, fetched_at desc);
commit;
