-- Zameel feature controls applied manually to production on 2026-09-26.
-- Idempotent schema migration for study files, Zameel Library, and the
-- notifications-center client flag. Do not include user data in this file.
begin;

insert into public.feature_flags
  (feature_key, name_ar, description, is_enabled, display_mode,
   rollout_percent, scope_type, scope_value)
values
  ('study_files', 'الملفات الدراسية',
   'عرض ورفع وتنزيل الملفات الدراسية', true, 'enabled', 100, 'global', '*'),
  ('zameel_library', 'مكتبة زميل',
   'الكتب والملخصات المفهرسة في مكتبة زميل', true, 'enabled', 100, 'global', '*'),
  ('notifications_center', 'مركز الإشعارات',
   'عرض شاشة الإشعارات داخل التطبيق', true, 'enabled', 100, 'global', '*')
on conflict (feature_key) do nothing;

create or replace function public.zameel_study_files_is_enabled()
returns boolean language sql stable security definer
set search_path = public, pg_temp set row_security = off as $$
  select coalesce((
    select is_enabled = true and display_mode = 'enabled'
    from public.feature_flags
    where feature_key = 'study_files' and scope_type = 'global'
      and scope_value = '*'
  ), false);
$$;
revoke all on function public.zameel_study_files_is_enabled() from public, anon;
grant execute on function public.zameel_study_files_is_enabled() to authenticated;

create or replace function public.zameel_guard_study_files_write()
returns trigger language plpgsql security definer
set search_path = public, pg_temp as $$
begin
  if coalesce(auth.role(), '') <> 'service_role'
     and not public.zameel_study_files_is_enabled() then
    raise exception 'study_files_temporarily_unavailable' using errcode = 'P0001';
  end if;
  return new;
end;
$$;
revoke all on function public.zameel_guard_study_files_write()
  from public, anon, authenticated;
drop trigger if exists study_files_feature_guard_write on public.study_files;
create trigger study_files_feature_guard_write
before insert or update on public.study_files
for each row execute function public.zameel_guard_study_files_write();

drop policy if exists study_files_feature_read on public.study_files;
create policy study_files_feature_read on public.study_files as restrictive
for select to authenticated using (public.zameel_study_files_is_enabled());
drop policy if exists study_storage_feature_read on storage.objects;
create policy study_storage_feature_read on storage.objects as restrictive
for select to authenticated
using (bucket_id <> 'study_files' or public.zameel_study_files_is_enabled());
drop policy if exists study_storage_feature_insert on storage.objects;
create policy study_storage_feature_insert on storage.objects as restrictive
for insert to authenticated
with check (bucket_id <> 'study_files' or public.zameel_study_files_is_enabled());

create or replace function public.zameel_library_is_enabled()
returns boolean language sql stable security definer
set search_path = public, pg_temp set row_security = off as $$
  select coalesce((
    select is_enabled = true and display_mode = 'enabled'
    from public.feature_flags
    where feature_key = 'zameel_library' and scope_type = 'global'
      and scope_value = '*'
  ), false);
$$;
revoke all on function public.zameel_library_is_enabled() from public, anon;
grant execute on function public.zameel_library_is_enabled() to authenticated;

drop policy if exists zameel_library_feature_read on public.zameel_library_categories;
create policy zameel_library_feature_read
on public.zameel_library_categories as restrictive
for select to authenticated using (public.zameel_library_is_enabled());
drop policy if exists zameel_library_feature_read on public.zameel_library_items;
create policy zameel_library_feature_read
on public.zameel_library_items as restrictive
for select to authenticated using (public.zameel_library_is_enabled());
drop policy if exists zameel_library_feature_read on public.zameel_library_download_counts;
create policy zameel_library_feature_read
on public.zameel_library_download_counts as restrictive
for select to authenticated using (public.zameel_library_is_enabled());

create or replace function public.zameel_guard_library_download_count()
returns trigger language plpgsql security definer
set search_path = public, pg_temp as $$
begin
  if coalesce(auth.role(), '') <> 'service_role'
     and not public.zameel_library_is_enabled() then
    raise exception 'zameel_library_temporarily_unavailable' using errcode = 'P0001';
  end if;
  return new;
end;
$$;
revoke all on function public.zameel_guard_library_download_count()
  from public, anon, authenticated;
drop trigger if exists zameel_library_feature_download_write
  on public.zameel_library_download_counts;
create trigger zameel_library_feature_download_write
before insert or update on public.zameel_library_download_counts
for each row execute function public.zameel_guard_library_download_count();

commit;
