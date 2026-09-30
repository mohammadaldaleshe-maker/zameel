-- Run once in Supabase SQL Editor. Does not submit a report or moderate content.
begin;
do $$ begin
  if to_regprocedure('public.zameel_account_can_write()') is null
     or to_regprocedure('public.admin_has_permission(text,uuid)') is null
     or to_regprocedure('public.admin_can_access_screen(text,uuid)') is null then
    raise exception 'reporting_prerequisite_missing';
  end if;
end $$;

alter table public.posts add column if not exists is_hidden boolean not null default false;
-- Preserve the existing admin policy, including owner/admin access to hidden posts.
do $$ begin
  if not exists(select 1 from pg_policies where schemaname='public' and tablename='posts' and policyname='admin_hidden_posts_guard') then
    execute 'create policy admin_hidden_posts_guard on public.posts as restrictive for select to authenticated using (not is_hidden or user_id=auth.uid() or public.admin_is_active(auth.uid()))';
  end if;
end $$;

drop policy if exists reporting_hidden_posts_anon_guard on public.posts;
create policy reporting_hidden_posts_anon_guard on public.posts as restrictive for select to anon using (not is_hidden);

-- Client-side editing must not reverse a moderation decision.
create or replace function public.zameel_guard_post_hidden_state()
returns trigger language plpgsql security invoker set search_path='' as $$
begin
  if new.is_hidden is distinct from old.is_hidden
     and coalesce(auth.role(),'')<>'service_role'
     and not (auth.role() is null and current_user='postgres') then
    raise exception 'moderation_state_is_server_managed' using errcode='42501';
  end if;
  return new;
end $$;
revoke all on function public.zameel_guard_post_hidden_state() from public,anon,authenticated;
drop trigger if exists zameel_post_hidden_state_guard on public.posts;
create trigger zameel_post_hidden_state_guard before update of is_hidden on public.posts
for each row execute function public.zameel_guard_post_hidden_state();

create table if not exists public.zameel_post_reports (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.posts(id) on delete cascade,
  reporter_id uuid not null references public.users(id) on delete cascade,
  reported_user_id uuid references public.users(id) on delete set null,
  category text not null check(category in ('spam','harassment','hate','sexual','violence','privacy','other')),
  reason text not null default '' check(char_length(reason)<=1000),
  status text not null default 'open' check(status in ('open','hidden','dismissed')),
  created_at timestamptz not null default now(),
  reviewed_at timestamptz,
  reviewed_by uuid references public.users(id) on delete set null,
  review_reason text,
  unique(post_id,reporter_id)
);
create index if not exists zameel_post_reports_created_idx on public.zameel_post_reports(created_at desc);
create index if not exists zameel_post_reports_scope_idx on public.zameel_post_reports(reported_user_id,created_at desc);
create index if not exists zameel_post_reports_rate_idx on public.zameel_post_reports(reporter_id,created_at desc);
alter table public.zameel_post_reports enable row level security;
revoke all on public.zameel_post_reports from public,anon,authenticated;
grant select on public.zameel_post_reports to authenticated;
-- Clients cannot choose status, author, timestamps or review fields.
grant insert(post_id,reporter_id,category,reason) on public.zameel_post_reports to authenticated;
grant all on public.zameel_post_reports to service_role;

drop policy if exists post_report_own_read on public.zameel_post_reports;
create policy post_report_own_read on public.zameel_post_reports for select to authenticated
using(reporter_id=auth.uid());
drop policy if exists post_report_self_insert on public.zameel_post_reports;
create policy post_report_self_insert on public.zameel_post_reports for insert to authenticated
with check (
  reporter_id=auth.uid() and status='open' and reviewed_by is null and reviewed_at is null
  and public.zameel_account_can_write()
  and exists(select 1 from public.posts p where p.id=post_id and p.user_id<>auth.uid()
    and p.user_id=reported_user_id and not p.is_hidden)
);

create or replace function public.zameel_guard_post_report()
returns trigger language plpgsql security definer set search_path='' as $$
declare target uuid;
begin
  if auth.uid() is null or new.reporter_id<>auth.uid() or not public.zameel_account_can_write() then
    raise exception 'account_cannot_report';
  end if;
  select user_id into target from public.posts where id=new.post_id;
  if target is null or target=auth.uid() then raise exception 'post_not_available'; end if;
  if new.category='other' and char_length(trim(new.reason))<5 then raise exception 'report_reason_required'; end if;
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('post-report:'||auth.uid()::text,0));
  if (select count(*) from public.zameel_post_reports
      where reporter_id=auth.uid() and created_at>now()-interval '1 hour')>=20
     and not exists(select 1 from public.zameel_post_reports where reporter_id=auth.uid() and post_id=new.post_id) then
    raise exception 'report_rate_limited';
  end if;
  new.reported_user_id=target;
  return new;
end $$;
revoke all on function public.zameel_guard_post_report() from public,anon,authenticated;
drop trigger if exists zameel_post_report_guard on public.zameel_post_reports;
create trigger zameel_post_report_guard before insert on public.zameel_post_reports
for each row execute function public.zameel_guard_post_report();

create or replace function public.zameel_report_post(p_post_id uuid,p_category text,p_reason text default '')
returns jsonb language plpgsql security invoker set search_path='' as $$
declare report_id uuid; existing_id uuid;
begin
  if auth.uid() is null or not public.zameel_account_can_write() then raise exception 'account_cannot_report'; end if;
  -- SECURITY INVOKER: existing post audience, account and block policies apply.
  if not exists(select 1 from public.posts where id=p_post_id and user_id<>auth.uid() and not is_hidden) then
    raise exception 'post_not_available';
  end if;
  if p_category is null or p_category not in ('spam','harassment','hate','sexual','violence','privacy','other')
    or char_length(coalesce(p_reason,''))>1000 then raise exception 'invalid_report_reason'; end if;
  select id into existing_id from public.zameel_post_reports where post_id=p_post_id and reporter_id=auth.uid();
  if existing_id is not null then return jsonb_build_object('report_id',existing_id,'already_reported',true); end if;
  insert into public.zameel_post_reports(post_id,reporter_id,category,reason)
    values(p_post_id,auth.uid(),p_category,trim(coalesce(p_reason,'')))
    on conflict(post_id,reporter_id) do nothing returning id into report_id;
  if report_id is null then
    select id into report_id from public.zameel_post_reports where post_id=p_post_id and reporter_id=auth.uid();
    return jsonb_build_object('report_id',report_id,'already_reported',true);
  end if;
  return jsonb_build_object('report_id',report_id,'already_reported',false);
end $$;
revoke all on function public.zameel_report_post(uuid,text,text) from public,anon;
grant execute on function public.zameel_report_post(uuid,text,text) to authenticated;

-- Service-only transaction: Edge verifies active admin, screen, permissions and content-owner scope.
create or replace function public.zameel_review_post_report(
  p_report_id uuid,p_post_id uuid,p_decision text,p_reviewer_id uuid,p_reason text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare item public.zameel_post_reports%rowtype; new_status text; content_hidden boolean;
begin
  if not public.admin_has_permission('reports.manage',p_reviewer_id)
     or not public.admin_can_access_screen('reports',p_reviewer_id) then raise exception 'report_review_not_authorized'; end if;
  if p_decision is null or p_decision not in ('hide','restore','dismiss') or char_length(trim(coalesce(p_reason,'')))<5 then
    raise exception 'invalid_report_decision';
  end if;
  select * into item from public.zameel_post_reports where id=p_report_id for update;
  if not found or item.post_id<>p_post_id then raise exception 'report_not_found'; end if;
  -- Serializes decisions on different reports referring to the same post too.
  select is_hidden into content_hidden from public.posts where id=item.post_id for update;
  if not found then raise exception 'post_not_available'; end if;
  new_status=case when p_decision='hide' then 'hidden' else 'dismissed' end;
  if p_decision in ('hide','restore') then
    content_hidden=(p_decision='hide');
    update public.posts set is_hidden=content_hidden where id=item.post_id;
    insert into public.admin_resource_states(resource_type,resource_id,state,reason,updated_by,updated_at)
    values('post',item.post_id::text,case when content_hidden then 'hidden' else 'visible' end,p_reason,p_reviewer_id,now())
    on conflict(resource_type,resource_id) do update set state=excluded.state,reason=excluded.reason,
      updated_by=excluded.updated_by,updated_at=excluded.updated_at;
  end if;
  -- Dismissal alone never unhides content moderated elsewhere.
  update public.zameel_post_reports set status=new_status,reviewed_by=p_reviewer_id,
    reviewed_at=now(),review_reason=p_reason where id=item.id;
  insert into public.admin_audit_logs(actor_id,action,resource_type,resource_id,details)
  values(p_reviewer_id,'post.report.'||p_decision,'post',item.post_id::text,
    jsonb_build_object('report_id',item.id,'reason',p_reason,'previous_status',item.status));
  return jsonb_build_object('status',new_status,'is_hidden',content_hidden);
end $$;
revoke all on function public.zameel_review_post_report(uuid,uuid,text,uuid,text) from public,anon,authenticated;
grant execute on function public.zameel_review_post_report(uuid,uuid,text,uuid,text) to service_role;
notify pgrst, 'reload schema';
commit;
