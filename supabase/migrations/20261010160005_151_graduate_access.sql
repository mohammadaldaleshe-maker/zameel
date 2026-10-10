begin;
-- Keep historical academic labels for graduates without extending student access.
drop policy if exists zameel_graduate_study_read on public.study_files;
create policy zameel_graduate_study_read on public.study_files as restrictive for select to authenticated using(not exists(select 1 from public.users where id=auth.uid() and account_type='graduate'));
drop policy if exists zameel_graduate_study_insert on public.study_files;
create policy zameel_graduate_study_insert on public.study_files as restrictive for insert to authenticated with check(not exists(select 1 from public.users where id=auth.uid() and account_type='graduate'));
drop policy if exists zameel_graduate_study_update on public.study_files;
create policy zameel_graduate_study_update on public.study_files as restrictive for update to authenticated using(not exists(select 1 from public.users where id=auth.uid() and account_type='graduate')) with check(not exists(select 1 from public.users where id=auth.uid() and account_type='graduate'));
drop policy if exists zameel_graduate_study_storage on storage.objects;
create policy zameel_graduate_study_storage on storage.objects as restrictive for select to authenticated using(bucket_id<>'study_files' or not exists(select 1 from public.users where id=auth.uid() and account_type='graduate'));
commit;
