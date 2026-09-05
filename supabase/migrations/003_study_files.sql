
-- ============================================================
-- ZAMEEL STUDY FILES
-- PDF / Word / PowerPoint uploads inside the Books area.
-- Files are stored in a private bucket and opened through short-lived signed URLs.
-- ============================================================

insert into storage.buckets (id, name, public)
values ('study_files', 'study_files', false)
on conflict (id) do update set public = false;

create table if not exists public.study_files (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  title text not null check (char_length(title) between 1 and 160),
  file_name text not null,
  file_extension text not null check (file_extension in ('pdf', 'doc', 'docx', 'ppt', 'pptx')),
  mime_type text not null,
  file_size bigint not null check (file_size > 0 and file_size <= 26214400),
  course text not null default '',
  storage_path text not null unique,
  created_at timestamptz not null default now()
);

create index if not exists study_files_created_idx on public.study_files(created_at desc);
create index if not exists study_files_user_idx on public.study_files(user_id, created_at desc);
create index if not exists study_files_course_idx on public.study_files(course);

alter table public.study_files enable row level security;

do $$ begin
  drop policy if exists study_files_read on public.study_files;
  drop policy if exists study_files_insert_self on public.study_files;
  drop policy if exists study_files_delete_self on public.study_files;
  drop policy if exists study_files_update_self on public.study_files;
  drop policy if exists study_storage_read on storage.objects;
  drop policy if exists study_storage_insert_self on storage.objects;
  drop policy if exists study_storage_delete_self on storage.objects;
end $$;

create policy study_files_read
on public.study_files for select
to authenticated
using (true);

create policy study_files_insert_self
on public.study_files for insert
to authenticated
with check (user_id = auth.uid() and storage_path like auth.uid()::text || '/study/%');

create policy study_files_delete_self
on public.study_files for delete
to authenticated
using (user_id = auth.uid());

create policy study_files_update_self
on public.study_files for update
to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

create policy study_storage_read
on storage.objects for select
to authenticated
using (bucket_id = 'study_files');

create policy study_storage_insert_self
on storage.objects for insert
to authenticated
with check (
  bucket_id = 'study_files'
  and (storage.foldername(name))[1] = auth.uid()::text
);

create policy study_storage_delete_self
on storage.objects for delete
to authenticated
using (
  bucket_id = 'study_files'
  and (storage.foldername(name))[1] = auth.uid()::text
);
