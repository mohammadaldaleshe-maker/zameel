-- Zameel community scoping: global + university faculty + university major chats,
-- and academic-library visibility by university + college.

create table if not exists public.community_messages (
  id uuid primary key default gen_random_uuid(),
  scope text not null check (scope in ('global','faculty','major')),
  university text,
  college text,
  department text,
  user_id uuid not null references public.users(id) on delete cascade,
  content text not null check (char_length(trim(content)) between 1 and 5000),
  created_at timestamptz not null default now(),
  check (
    (scope = 'global' and university is null and college is null and department is null)
    or (scope = 'faculty' and nullif(trim(university),'') is not null and nullif(trim(college),'') is not null and department is null)
    or (scope = 'major' and nullif(trim(university),'') is not null and nullif(trim(college),'') is not null and nullif(trim(department),'') is not null)
  )
);

create index if not exists community_messages_scope_idx
  on public.community_messages(scope, university, college, department, created_at);

create or replace function public.can_access_community_scope(
  p_scope text,
  p_university text,
  p_college text,
  p_department text
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select
    auth.uid() is not null
    and (
      p_scope = 'global'
      or exists (
        select 1
        from public.users u
        where u.id = auth.uid()
          and nullif(trim(u.university),'') is not null
          and lower(trim(u.university)) = lower(trim(coalesce(p_university,'')))
          and (
            (p_scope = 'faculty'
              and nullif(trim(u.college),'') is not null
              and lower(trim(u.college)) = lower(trim(coalesce(p_college,''))))
            or
            (p_scope = 'major'
              and nullif(trim(u.college),'') is not null
              and nullif(trim(u.department),'') is not null
              and lower(trim(u.college)) = lower(trim(coalesce(p_college,'')))
              and lower(trim(u.department)) = lower(trim(coalesce(p_department,''))))
          )
      )
    );
$$;

grant execute on function public.can_access_community_scope(text,text,text,text) to authenticated;

alter table public.community_messages enable row level security;

drop policy if exists community_messages_select_scoped on public.community_messages;
create policy community_messages_select_scoped
on public.community_messages
for select
to authenticated
using (public.can_access_community_scope(scope, university, college, department));

drop policy if exists community_messages_insert_self_scoped on public.community_messages;
create policy community_messages_insert_self_scoped
on public.community_messages
for insert
to authenticated
with check (
  user_id = auth.uid()
  and public.can_access_community_scope(scope, university, college, department)
);

drop policy if exists community_messages_delete_self on public.community_messages;
create policy community_messages_delete_self
on public.community_messages
for delete
to authenticated
using (user_id = auth.uid());

-- Existing study files become scoped to the uploader's university and college.
alter table public.study_files add column if not exists university text not null default '';
alter table public.study_files add column if not exists college text not null default '';
alter table public.study_files add column if not exists department text not null default '';

update public.study_files sf
set university = coalesce(nullif(u.university,''), ''),
    college = coalesce(nullif(u.college,''), ''),
    department = coalesce(nullif(u.department,''), '')
from public.users u
where u.id = sf.user_id
  and (sf.university = '' or sf.college = '' or sf.department = '');

create index if not exists study_files_academic_scope_idx
  on public.study_files(university, college, department, created_at desc);

drop policy if exists study_files_read on public.study_files;
create policy study_files_read
on public.study_files
for select
to authenticated
using (
  exists (
    select 1
    from public.users me
    where me.id = auth.uid()
      and nullif(trim(me.university),'') is not null
      and nullif(trim(me.college),'') is not null
      and lower(trim(me.university)) = lower(trim(study_files.university))
      and lower(trim(me.college)) = lower(trim(study_files.college))
  )
);

drop policy if exists study_files_insert_self on public.study_files;
create policy study_files_insert_self
on public.study_files
for insert
to authenticated
with check (
  user_id = auth.uid()
  and storage_path like auth.uid()::text || '/study/%'
  and exists (
    select 1 from public.users me
    where me.id = auth.uid()
      and lower(trim(coalesce(me.university,''))) = lower(trim(coalesce(study_files.university,'')))
      and lower(trim(coalesce(me.college,''))) = lower(trim(coalesce(study_files.college,'')))
      and lower(trim(coalesce(me.department,''))) = lower(trim(coalesce(study_files.department,'')))
  )
);

drop policy if exists study_files_update_self on public.study_files;
create policy study_files_update_self
on public.study_files
for update
to authenticated
using (user_id = auth.uid())
with check (
  user_id = auth.uid()
  and exists (
    select 1 from public.users me
    where me.id = auth.uid()
      and lower(trim(coalesce(me.university,''))) = lower(trim(coalesce(study_files.university,'')))
      and lower(trim(coalesce(me.college,''))) = lower(trim(coalesce(study_files.college,'')))
      and lower(trim(coalesce(me.department,''))) = lower(trim(coalesce(study_files.department,'')))
  )
);

-- Storage reads are scoped to the same university + college as the file owner.
drop policy if exists study_storage_read on storage.objects;
create policy study_storage_read
on storage.objects
for select
to authenticated
using (
  bucket_id = 'study_files'
  and exists (
    select 1
    from public.study_files sf
    join public.users me on me.id = auth.uid()
    where sf.storage_path = storage.objects.name
      and nullif(trim(me.university),'') is not null
      and nullif(trim(me.college),'') is not null
      and lower(trim(sf.university)) = lower(trim(me.university))
      and lower(trim(sf.college)) = lower(trim(me.college))
  )
);

-- Realtime for community chat.
do $$
begin
  alter publication supabase_realtime add table public.community_messages;
exception when duplicate_object then
  null;
end $$;
