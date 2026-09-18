-- Zameel 045: live student opportunities, saved jobs and application tracking.
-- Run after migration 044.
begin;

create table if not exists public.job_opportunities (
  id uuid primary key default gen_random_uuid(),
  external_id text unique,
  provider text not null default 'zameel',
  posted_by uuid references public.users(id) on delete set null,
  title text not null,
  title_ar text,
  company text not null,
  description text,
  requirements text,
  location text,
  opportunity_type text not null default 'job'
    check (opportunity_type in ('job','internship','summer_training')),
  work_mode text not null default 'onsite'
    check (work_mode in ('onsite','remote','hybrid')),
  salary_text text,
  apply_url text,
  source_url text,
  published_at timestamptz not null default now(),
  expires_at timestamptz,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists job_opportunities_live_idx
  on public.job_opportunities(is_active, published_at desc);
create index if not exists job_opportunities_search_idx
  on public.job_opportunities using gin (
    to_tsvector('simple', coalesce(title,'') || ' ' || coalesce(company,'') || ' ' || coalesce(location,''))
  );

create table if not exists public.saved_job_opportunities (
  user_id uuid not null references public.users(id) on delete cascade,
  external_id text not null,
  job_snapshot jsonb not null default '{}'::jsonb,
  saved_at timestamptz not null default now(),
  primary key (user_id, external_id)
);

create table if not exists public.job_applications (
  user_id uuid not null references public.users(id) on delete cascade,
  external_id text not null,
  job_snapshot jsonb not null default '{}'::jsonb,
  status text not null default 'opened'
    check (status in ('opened','applied','interview','accepted','rejected','withdrawn')),
  applied_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (user_id, external_id)
);

alter table public.job_opportunities enable row level security;
alter table public.saved_job_opportunities enable row level security;
alter table public.job_applications enable row level security;

drop policy if exists jobs_read_active on public.job_opportunities;
create policy jobs_read_active on public.job_opportunities for select to authenticated
using (is_active and (expires_at is null or expires_at > now()));

drop policy if exists jobs_partner_manage on public.job_opportunities;
create policy jobs_partner_manage on public.job_opportunities for all to authenticated
using (
  posted_by = auth.uid() or exists (
    select 1 from public.users u
    where u.id = auth.uid() and lower(coalesce(u.role,'')) in ('owner','admin','company','business','campus_manager')
  )
)
with check (
  posted_by = auth.uid() and exists (
    select 1 from public.users u
    where u.id = auth.uid() and lower(coalesce(u.role,'')) in ('owner','admin','company','business','campus_manager')
  )
);

drop policy if exists saved_jobs_self on public.saved_job_opportunities;
create policy saved_jobs_self on public.saved_job_opportunities for all to authenticated
using (user_id = auth.uid()) with check (user_id = auth.uid());

drop policy if exists job_applications_self on public.job_applications;
create policy job_applications_self on public.job_applications for all to authenticated
using (user_id = auth.uid()) with check (user_id = auth.uid());

revoke all on public.job_opportunities from anon;
revoke all on public.saved_job_opportunities from anon;
revoke all on public.job_applications from anon;
grant select on public.job_opportunities to authenticated;
grant select, insert, update, delete on public.saved_job_opportunities to authenticated;
grant select, insert, update, delete on public.job_applications to authenticated;
grant insert, update, delete on public.job_opportunities to authenticated;

commit;
