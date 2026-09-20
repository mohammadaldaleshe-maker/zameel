-- Zameel 046: secure AI conversations, optional memory, verified knowledge,
-- and an atomic daily quota. Run after migration 045.
begin;

alter table public.users
  add column if not exists ai_memory_enabled boolean not null default true;

create table if not exists public.ai_conversations (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  title text not null default 'محادثة جديدة',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.ai_messages (
  id bigint generated always as identity primary key,
  conversation_id uuid not null references public.ai_conversations(id) on delete cascade,
  user_id uuid not null references public.users(id) on delete cascade,
  role text not null check (role in ('user','assistant')),
  mode text not null default 'assistant' check (mode in ('assistant','summary','explain')),
  content text not null check (char_length(content) between 1 and 20000),
  created_at timestamptz not null default now()
);

create index if not exists ai_messages_conversation_idx
  on public.ai_messages(conversation_id, created_at desc);

create table if not exists public.ai_daily_usage (
  user_id uuid not null references public.users(id) on delete cascade,
  usage_date date not null default current_date,
  request_count integer not null default 0 check (request_count >= 0),
  updated_at timestamptz not null default now(),
  primary key (user_id, usage_date)
);

create table if not exists public.ai_knowledge_sources (
  id uuid primary key default gen_random_uuid(),
  university text,
  title text not null,
  content text not null,
  source_url text,
  is_verified boolean not null default false,
  is_active boolean not null default true,
  created_by uuid references public.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.ai_faq_entries (
  id uuid primary key default gen_random_uuid(),
  question_ar text not null,
  answer_ar text not null,
  question_en text,
  answer_en text,
  university text,
  keywords text[] not null default '{}',
  is_active boolean not null default true,
  created_by uuid references public.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.ai_conversations enable row level security;
alter table public.ai_messages enable row level security;
alter table public.ai_daily_usage enable row level security;
alter table public.ai_knowledge_sources enable row level security;
alter table public.ai_faq_entries enable row level security;

drop policy if exists ai_conversations_self on public.ai_conversations;
create policy ai_conversations_self on public.ai_conversations for all to authenticated
using (user_id = auth.uid()) with check (user_id = auth.uid());

drop policy if exists ai_messages_self on public.ai_messages;
create policy ai_messages_self on public.ai_messages for all to authenticated
using (user_id = auth.uid()) with check (
  user_id = auth.uid() and exists (
    select 1 from public.ai_conversations c
    where c.id = conversation_id and c.user_id = auth.uid()
  )
);

drop policy if exists ai_usage_read_self on public.ai_daily_usage;
create policy ai_usage_read_self on public.ai_daily_usage for select to authenticated
using (user_id = auth.uid());

drop policy if exists ai_knowledge_read_verified on public.ai_knowledge_sources;
create policy ai_knowledge_read_verified on public.ai_knowledge_sources for select to authenticated
using (is_active and is_verified);

drop policy if exists ai_knowledge_admin_manage on public.ai_knowledge_sources;
create policy ai_knowledge_admin_manage on public.ai_knowledge_sources for all to authenticated
using (exists (
  select 1 from public.users u where u.id = auth.uid()
  and lower(coalesce(u.role,'')) in ('owner','admin')
)) with check (exists (
  select 1 from public.users u where u.id = auth.uid()
  and lower(coalesce(u.role,'')) in ('owner','admin')
));

drop policy if exists ai_faq_read_active on public.ai_faq_entries;
create policy ai_faq_read_active on public.ai_faq_entries for select to authenticated
using (is_active);

drop policy if exists ai_faq_admin_manage on public.ai_faq_entries;
create policy ai_faq_admin_manage on public.ai_faq_entries for all to authenticated
using (exists (
  select 1 from public.users u where u.id = auth.uid()
  and lower(coalesce(u.role,'')) in ('owner','admin')
)) with check (exists (
  select 1 from public.users u where u.id = auth.uid()
  and lower(coalesce(u.role,'')) in ('owner','admin')
));

create or replace function public.consume_zameel_ai_quota(
  target_user_id uuid,
  max_requests integer default 50
) returns integer
language plpgsql security definer set search_path = public set row_security = off
as $$
declare used integer;
begin
  if target_user_id is null or max_requests < 1 then
    raise exception 'invalid_quota_request';
  end if;
  insert into public.ai_daily_usage(user_id, usage_date, request_count, updated_at)
  values (target_user_id, current_date, 1, now())
  on conflict (user_id, usage_date) do update
    set request_count = public.ai_daily_usage.request_count + 1,
        updated_at = now()
    where public.ai_daily_usage.request_count < max_requests
  returning request_count into used;
  if used is null then raise exception 'daily_quota_reached'; end if;
  return greatest(0, max_requests - used);
end;
$$;

revoke all on function public.consume_zameel_ai_quota(uuid, integer) from public, anon, authenticated;
grant execute on function public.consume_zameel_ai_quota(uuid, integer) to service_role;

grant select, insert, update, delete on public.ai_conversations to authenticated;
grant select, insert, update, delete on public.ai_messages to authenticated;
grant select on public.ai_daily_usage to authenticated;
grant select on public.ai_knowledge_sources to authenticated;
grant insert, update, delete on public.ai_knowledge_sources to authenticated;
grant select, insert, update, delete on public.ai_faq_entries to authenticated;

insert into public.ai_faq_entries (
  question_ar, answer_ar, question_en, answer_en, keywords, is_active
)
select
  'من هو مالك تطبيق زميل؟',
  'مالك تطبيق زميل هو الشاب الأردني محمد مشهور.',
  'Who owns the Zameel app?',
  'The owner of the Zameel app is the young Jordanian Mohammad Mashhoor.',
  array['مالك زميل','صاحب زميل','مؤسس زميل','مالك تطبيق زميل','owner of zameel','founder of zameel'],
  true
where not exists (
  select 1 from public.ai_faq_entries
  where lower(trim(question_ar)) = lower(trim('من هو مالك تطبيق زميل؟'))
);

update public.ai_faq_entries
set answer_ar = 'مالك تطبيق زميل هو الشاب الأردني محمد مشهور.',
    question_en = 'Who owns the Zameel app?',
    answer_en = 'The owner of the Zameel app is the young Jordanian Mohammad Mashhoor.',
    keywords = array['مالك زميل','صاحب زميل','مؤسس زميل','مالك تطبيق زميل','owner of zameel','founder of zameel'],
    is_active = true,
    updated_at = now()
where lower(trim(question_ar)) = lower(trim('من هو مالك تطبيق زميل؟'));

commit;
