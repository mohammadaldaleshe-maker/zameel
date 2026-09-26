-- Advertising is independent of ordinary posts. No existing post or partner
-- policy is replaced here. Apply only after the existing Zameel migrations.
begin;
insert into public.feature_flags
  (feature_key,name_ar,description,is_enabled,display_mode,rollout_percent,scope_type,scope_value)
values ('partner_advertising','إعلانات الشركاء','إعلانات الشركاء المدفوعة',false,'hidden',0,'global','*')
on conflict (feature_key) do nothing;
create table if not exists public.sales_teams (
  id uuid primary key default gen_random_uuid(),
  name text not null check (length(trim(name)) between 1 and 120),
  supervisor_id uuid unique references auth.users(id),
  created_at timestamptz not null default now()
);

create table if not exists public.sales_staff (
  user_id uuid primary key references auth.users(id) on delete cascade,
  team_id uuid references public.sales_teams(id),
  sales_role text not null check (sales_role in ('representative','supervisor','sales_manager','general_manager')),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  check ((sales_role = 'representative' and team_id is not null)
      or (sales_role <> 'representative'))
);
create index if not exists sales_staff_team_idx on public.sales_staff(team_id, sales_role);

-- A partner account is provisioned server-side, after the representative
-- creates the first draft. The generated login identifier is not an email.
create table if not exists public.partner_accounts (
  partner_id uuid primary key references public.business_partners(id) on delete cascade,
  user_id uuid unique references auth.users(id) on delete set null,
  login_name text unique not null,
  must_change_password boolean not null default true,
  recovery_contact_verified boolean not null default false,
  created_at timestamptz not null default now()
);

create table if not exists public.advertiser_terms (
  partner_id uuid primary key references public.business_partners(id) on delete cascade,
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  approved_by uuid not null references auth.users(id),
  created_at timestamptz not null default now(),
  check (ends_at > starts_at)
);

create table if not exists public.advertisements (
  id uuid primary key default gen_random_uuid(),
  partner_id uuid not null references public.business_partners(id),
  representative_id uuid not null references auth.users(id),
  title text not null check (length(trim(title)) between 1 and 180),
  body text not null default '',
  category text not null default 'services',
  search_terms text[] not null default '{}',
  media jsonb not null default '[]'::jsonb check (jsonb_typeof(media) = 'array'),
  latitude double precision check (latitude between -90 and 90),
  longitude double precision check (longitude between -180 and 180),
  status text not null default 'draft' check (status in (
    'draft','supervisor_review','sales_manager_review','general_manager_review',
    'returned','rejected','published','expired','deleted'
  )),
  published_at timestamptz,
  expires_at timestamptz,
  deleted_at timestamptz,
  deleted_by uuid references auth.users(id),
  deletion_reason text,
  view_count bigint not null default 0,
  likes_count bigint not null default 0,
  comments_count bigint not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check ((latitude is null) = (longitude is null))
);
create index if not exists advertisements_partner_status_idx on public.advertisements(partner_id,status,published_at desc);
create index if not exists advertisements_rep_idx on public.advertisements(representative_id,created_at desc);
create index if not exists advertisements_live_idx on public.advertisements(published_at desc)
  where status = 'published' and deleted_at is null;

create table if not exists public.advertisement_decisions (
  id bigint generated always as identity primary key,
  advertisement_id uuid not null references public.advertisements(id),
  actor_id uuid not null references auth.users(id),
  from_status text,
  to_status text not null,
  reason text,
  created_at timestamptz not null default now()
);
create index if not exists advertisement_decisions_ad_idx on public.advertisement_decisions(advertisement_id,created_at);

create table if not exists public.advertisement_views (
  advertisement_id uuid not null references public.advertisements(id) on delete cascade,
  viewer_id uuid not null references auth.users(id) on delete cascade,
  first_viewed_at timestamptz not null default now(),
  primary key (advertisement_id,viewer_id)
);
create table if not exists public.advertisement_likes (
  advertisement_id uuid not null references public.advertisements(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (advertisement_id,user_id)
);
create table if not exists public.advertisement_hides (
  advertisement_id uuid not null references public.advertisements(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (advertisement_id,user_id)
);
create table if not exists public.advertisement_interest_categories (
  user_id uuid not null references auth.users(id) on delete cascade,
  category text not null,
  updated_at timestamptz not null default now(),
  primary key (user_id,category)
);
create table if not exists public.advertisement_comments (
  id uuid primary key default gen_random_uuid(),
  advertisement_id uuid not null references public.advertisements(id) on delete cascade,
  author_id uuid not null references auth.users(id),
  parent_id uuid references public.advertisement_comments(id),
  body text not null check (length(trim(body)) between 1 and 2000),
  created_at timestamptz not null default now()
);
create index if not exists advertisement_comments_ad_idx on public.advertisement_comments(advertisement_id,created_at);

create or replace function public.advertisement_is_live(target public.advertisements)
returns boolean language sql stable security definer set search_path = public as $$
  select target.status = 'published' and target.deleted_at is null
    and target.published_at <= now()
    and target.expires_at > now()
    and exists (select 1 from public.feature_flags flag
      where flag.feature_key = 'partner_advertising'
      and flag.scope_type = 'global' and flag.scope_value = '*'
      and flag.is_enabled and flag.display_mode = 'enabled')
    and exists (select 1 from public.advertiser_terms term
      where term.partner_id = target.partner_id
      and term.starts_at <= now() and term.ends_at > now())
    and exists (select 1 from public.business_partners partner
      where partner.id = target.partner_id
      and partner.is_approved and partner.is_active)
$$;

create or replace function public.advertisement_can_manage(target public.advertisements)
returns boolean language sql stable security definer set search_path = public as $$
  select target.representative_id = auth.uid()
    or exists (select 1 from public.partner_accounts pa
      where pa.partner_id = target.partner_id and pa.user_id = auth.uid())
    or exists (select 1 from public.sales_staff actor
      join public.sales_staff rep on rep.user_id = target.representative_id
      where actor.user_id = auth.uid() and actor.is_active
      and (actor.sales_role in ('sales_manager','general_manager')
        or (actor.sales_role = 'supervisor' and actor.team_id = rep.team_id)))
$$;

alter table public.sales_teams enable row level security;
alter table public.sales_staff enable row level security;
alter table public.partner_accounts enable row level security;
alter table public.advertiser_terms enable row level security;
alter table public.advertisements enable row level security;
alter table public.advertisement_decisions enable row level security;
alter table public.advertisement_views enable row level security;
alter table public.advertisement_likes enable row level security;
alter table public.advertisement_hides enable row level security;
alter table public.advertisement_interest_categories enable row level security;
alter table public.advertisement_comments enable row level security;

create policy sales_staff_read_self on public.sales_staff for select to authenticated
  using (user_id = auth.uid());
create policy partner_account_read_self on public.partner_accounts for select to authenticated
  using (user_id = auth.uid());
create policy advertisements_read on public.advertisements for select to authenticated
  using (public.zameel_account_can_read() and
    (public.advertisement_is_live(advertisements) or public.advertisement_can_manage(advertisements)));
create policy advertiser_terms_read on public.advertiser_terms for select to authenticated
  using (exists (select 1 from public.partner_accounts pa where pa.partner_id = advertiser_terms.partner_id and pa.user_id = auth.uid()));
create policy advertisement_decisions_read on public.advertisement_decisions for select to authenticated
  using (exists (select 1 from public.advertisements ad where ad.id = advertisement_id and public.advertisement_can_manage(ad)));
create policy advertisement_comments_read on public.advertisement_comments for select to authenticated
  using (exists (select 1 from public.advertisements ad where ad.id = advertisement_id
    and (public.advertisement_is_live(ad) or public.advertisement_can_manage(ad))));
create policy advertisement_comments_create on public.advertisement_comments for insert to authenticated
  with check (public.zameel_account_can_write() and author_id = auth.uid() and exists (select 1 from public.advertisements ad
    where ad.id = advertisement_id and public.advertisement_is_live(ad)));
create policy advertisement_likes_read_own on public.advertisement_likes for select to authenticated
  using (user_id = auth.uid());
create policy advertisement_likes_create on public.advertisement_likes for insert to authenticated
  with check (public.zameel_account_can_write() and user_id = auth.uid() and exists (select 1 from public.advertisements ad
    where ad.id = advertisement_id and public.advertisement_is_live(ad)));
create policy advertisement_likes_delete_own on public.advertisement_likes for delete to authenticated
  using (user_id = auth.uid() and public.zameel_account_can_write());
create policy advertisement_hides_read on public.advertisement_hides for select to authenticated
  using (user_id = auth.uid());
create policy advertisement_hides_create on public.advertisement_hides for insert to authenticated
  with check (user_id = auth.uid() and public.zameel_account_can_write());
create policy advertisement_hides_update on public.advertisement_hides for update to authenticated
  using (user_id = auth.uid() and public.zameel_account_can_write())
  with check (user_id = auth.uid());

-- Clients cannot write statistics or approval state directly. These tables
-- are managed by narrowly scoped server operations in the admin console.
revoke all on public.sales_teams, public.sales_staff, public.partner_accounts,
  public.advertiser_terms, public.advertisement_decisions,
  public.advertisement_views from anon, authenticated;
grant select on public.sales_staff, public.partner_accounts,
  public.advertiser_terms, public.advertisement_decisions to authenticated;
grant select on public.advertisements to authenticated;
grant select, insert on public.advertisement_comments to authenticated;
grant select, insert, delete on public.advertisement_likes to authenticated;
grant select, insert, update on public.advertisement_hides to authenticated;

create or replace function public.advertisement_after_like()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'DELETE' then
    update public.advertisements set likes_count =
      (select count(*) from public.advertisement_likes where advertisement_id = old.advertisement_id)
    where id = old.advertisement_id;
    return null;
  end if;
  update public.advertisements set likes_count =
    (select count(*) from public.advertisement_likes where advertisement_id = new.advertisement_id)
  where id = new.advertisement_id;
  return null;
end $$;
create trigger advertisement_like_count after insert or delete on public.advertisement_likes
  for each row execute function public.advertisement_after_like();
create or replace function public.advertisement_after_comment()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'DELETE' then
    update public.advertisements set comments_count =
      (select count(*) from public.advertisement_comments where advertisement_id = old.advertisement_id)
    where id = old.advertisement_id;
    return null;
  end if;
  update public.advertisements set comments_count =
    (select count(*) from public.advertisement_comments where advertisement_id = new.advertisement_id)
  where id = new.advertisement_id;
  return null;
end $$;
create trigger advertisement_comment_count after insert or delete on public.advertisement_comments
  for each row execute function public.advertisement_after_comment();
create trigger advertisements_updated_at before update on public.advertisements
  for each row execute function public.set_updated_at();

create or replace function public.record_advertisement_view(target_ad_id uuid)
returns void language plpgsql security definer
set search_path = public, pg_temp set row_security = off as $$
begin
  if auth.uid() is null or not public.zameel_account_can_read() then return; end if;
  if not exists (select 1 from public.advertisements ad
    where ad.id = target_ad_id and public.advertisement_is_live(ad)) then return; end if;
  insert into public.advertisement_views(advertisement_id,viewer_id)
  values (target_ad_id,auth.uid()) on conflict do nothing;
  if found then
    update public.advertisements set view_count = view_count + 1 where id = target_ad_id;
    insert into public.advertisement_interest_categories(user_id,category)
    select auth.uid(),ad.category from public.advertisements ad where ad.id = target_ad_id
    on conflict (user_id,category) do update set updated_at = now();
  end if;
end $$;
revoke all on function public.record_advertisement_view(uuid) from public, anon;
grant execute on function public.record_advertisement_view(uuid) to authenticated;

create or replace function public.advertisement_check_reply()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.parent_id is not null and not exists (
    select 1 from public.advertisement_comments parent
    where parent.id = new.parent_id and parent.advertisement_id = new.advertisement_id
  ) then raise exception 'comment_parent_mismatch'; end if;
  return new;
end $$;
create trigger advertisement_reply_check before insert on public.advertisement_comments
  for each row execute function public.advertisement_check_reply();

create or replace function public.advertisement_comment_notify()
returns trigger language plpgsql security definer set search_path = public, pg_temp as $$
declare recipient uuid;
begin
  if new.parent_id is null then
    select pa.user_id into recipient from public.advertisements ad
      join public.partner_accounts pa on pa.partner_id = ad.partner_id
      where ad.id = new.advertisement_id;
  else
    select parent.author_id into recipient from public.advertisement_comments parent
      where parent.id = new.parent_id;
  end if;
  if recipient is not null and recipient <> new.author_id then
    insert into public.notifications(user_id,actor_id,type,title_ar,title_en,
      body_ar,body_en,data)
    values(recipient,new.author_id,'advertisement_comment','تعليق على إعلانك',
      'New ad comment','ورد تعليق أو رد على إعلانك','New comment or reply on your ad',
      jsonb_build_object('advertisement_id',new.advertisement_id));
  end if;
  return null;
end $$;
create trigger advertisement_comment_notification after insert on public.advertisement_comments
  for each row execute function public.advertisement_comment_notify();

insert into storage.buckets (id,name,public,file_size_limit,allowed_mime_types)
values ('advertisements','advertisements',false,52428800,
  array['image/jpeg','image/png','image/webp','video/mp4','video/webm'])
on conflict (id) do nothing;
create policy advertisement_upload_own on storage.objects for insert to authenticated
  with check (bucket_id = 'advertisements'
    and (storage.foldername(name))[1] = auth.uid()::text
    and public.zameel_account_can_write()
    and exists (select 1 from public.sales_staff staff
      where staff.user_id = auth.uid() and staff.is_active and staff.sales_role = 'representative'));
create policy advertisement_file_read_own on storage.objects for select to authenticated
  using (bucket_id = 'advertisements'
    and (storage.foldername(name))[1] = auth.uid()::text
    and public.zameel_account_can_read());

-- Called only by the authenticated Edge Function using the service key.
-- All approval steps and the advertiser's one-month term change atomically.
create or replace function public.review_advertisement(
  p_actor uuid, p_advertisement uuid, p_decision text, p_reason text default null
) returns text language plpgsql security definer
set search_path = public, pg_temp set row_security = off as $$
declare
  ad public.advertisements%rowtype;
  actor_role text;
  actor_team uuid;
  rep_team uuid;
  next_status text;
  active_term_ends timestamptz;
begin
  select * into ad from public.advertisements where id = p_advertisement for update;
  if not found then raise exception 'advertisement_not_found'; end if;
  select sales_role,team_id into actor_role,actor_team from public.sales_staff
    where user_id = p_actor and is_active;
  if actor_role is null then raise exception 'sales_access_denied'; end if;
  select team_id into rep_team from public.sales_staff
    where user_id = ad.representative_id and sales_role = 'representative';
  if p_decision in ('submit','approve') and not exists (
    select 1 from public.feature_flags flag where flag.feature_key = 'partner_advertising'
    and flag.scope_type = 'global' and flag.scope_value = '*'
    and flag.is_enabled and flag.display_mode = 'enabled')
    then raise exception 'partner_advertising_temporarily_unavailable'; end if;

  if p_decision = 'delete' then
    if actor_role not in ('supervisor','sales_manager','general_manager')
       or (actor_role = 'supervisor' and actor_team is distinct from rep_team)
       or ad.status = 'deleted' then raise exception 'deletion_denied'; end if;
    if length(trim(coalesce(p_reason,''))) < 5 then raise exception 'reason_required'; end if;
    next_status := 'deleted';
    update public.advertisements set status = next_status,
      deleted_at = now(),deleted_by = p_actor,deletion_reason = p_reason where id = ad.id;
  elsif p_decision = 'submit' then
    if actor_role <> 'representative' or p_actor <> ad.representative_id
       or ad.status not in ('draft','returned') then raise exception 'submission_denied'; end if;
    if not exists (select 1 from public.sales_teams team
      join public.sales_staff supervisor on supervisor.user_id = team.supervisor_id
      where team.id = rep_team and supervisor.is_active
        and supervisor.sales_role = 'supervisor')
      then raise exception 'supervisor_not_assigned'; end if;
    next_status := 'supervisor_review';
    update public.advertisements set status = next_status where id = ad.id;
  else
    if not ((ad.status = 'supervisor_review' and actor_role = 'supervisor'
             and actor_team = rep_team and exists (select 1 from public.sales_teams
               where id = rep_team and supervisor_id = p_actor))
      or (ad.status = 'sales_manager_review' and actor_role = 'sales_manager')
      or (ad.status = 'general_manager_review' and actor_role = 'general_manager'))
      then raise exception 'approval_order_denied'; end if;
    if p_decision = 'approve' then
      if ad.status = 'supervisor_review' and not exists (
        select 1 from public.sales_staff where sales_role = 'sales_manager' and is_active)
        then raise exception 'sales_manager_not_assigned'; end if;
      if ad.status = 'sales_manager_review' and not exists (
        select 1 from public.sales_staff where sales_role = 'general_manager' and is_active)
        then raise exception 'general_manager_not_assigned'; end if;
      next_status := case ad.status
        when 'supervisor_review' then 'sales_manager_review'
        when 'sales_manager_review' then 'general_manager_review'
        else 'published' end;
      if next_status = 'published' then
        insert into public.advertiser_terms(partner_id,starts_at,ends_at,approved_by)
        values (ad.partner_id,now(),now() + interval '1 month',p_actor)
        on conflict (partner_id) do update
        set starts_at = excluded.starts_at,ends_at = excluded.ends_at,
            approved_by = excluded.approved_by
        where public.advertiser_terms.ends_at <= now();
        select ends_at into active_term_ends from public.advertiser_terms
          where partner_id = ad.partner_id;
        update public.business_partners set is_approved = true,is_active = true
          where id = ad.partner_id;
      end if;
      update public.advertisements set status = next_status,
        published_at = case when next_status = 'published' then now() else published_at end,
        expires_at = case when next_status = 'published' then active_term_ends else expires_at end
        where id = ad.id;
    elsif p_decision in ('return','reject') then
      if length(trim(coalesce(p_reason,''))) < 5 then raise exception 'reason_required'; end if;
      next_status := case when p_decision = 'return' then 'returned' else 'rejected' end;
      update public.advertisements set status = next_status where id = ad.id;
    else raise exception 'invalid_decision'; end if;
  end if;
  insert into public.advertisement_decisions
    (advertisement_id,actor_id,from_status,to_status,reason)
  values (ad.id,p_actor,ad.status,next_status,p_reason);
  insert into public.notifications(user_id,actor_id,type,title_ar,title_en,
    body_ar,body_en,data)
  select distinct recipient.user_id,p_actor,'advertisement_review',
    'تحديث طلب الإعلان','Ad request update',
    'حالة الإعلان: ' || next_status, 'Ad status: ' || next_status,
    jsonb_build_object('advertisement_id',ad.id,'status',next_status,'reason',p_reason)
  from (
    select case when next_status = 'supervisor_review'
      then (select supervisor_id from public.sales_teams where id = rep_team)
      when next_status = 'sales_manager_review'
      then (select user_id from public.sales_staff where sales_role='sales_manager'
        and is_active order by created_at limit 1)
      when next_status = 'general_manager_review'
      then (select user_id from public.sales_staff where sales_role='general_manager'
        and is_active order by created_at limit 1)
      else ad.representative_id end as user_id
    union all select pa.user_id from public.partner_accounts pa
      where pa.partner_id = ad.partner_id and next_status in ('published','deleted')
  ) recipient
  where recipient.user_id is not null and recipient.user_id <> p_actor
    and exists (select 1 from public.users u where u.id = recipient.user_id);
  return next_status;
end $$;
revoke all on function public.review_advertisement(uuid,uuid,text,text) from public,anon,authenticated;
grant execute on function public.review_advertisement(uuid,uuid,text,text) to service_role;

create or replace function public.sales_representative_summary()
returns table(user_id uuid, name text, team_id uuid, advertisements_count bigint,
  published_count bigint, pending_count bigint)
language sql stable security definer set search_path = public, pg_temp
set row_security = off as $$
  select staff.user_id,coalesce(users.name,'مندوب'),staff.team_id,
    count(ad.id), count(ad.id) filter (where ad.status='published' and ad.expires_at > now()),
    count(ad.id) filter (where ad.status in ('supervisor_review',
      'sales_manager_review','general_manager_review'))
  from public.sales_staff staff
  left join public.users users on users.id = staff.user_id
  left join public.advertisements ad on ad.representative_id = staff.user_id
  where staff.sales_role = 'representative' and staff.is_active
  group by staff.user_id,users.name,staff.team_id
  order by users.name;
$$;
revoke all on function public.sales_representative_summary() from public,anon,authenticated;
grant execute on function public.sales_representative_summary() to service_role;

commit;
