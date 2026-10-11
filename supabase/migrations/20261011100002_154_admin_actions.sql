begin;
alter table public.zameel_blocked_emails_154 add column expires_at timestamptz;
create or replace function public.zameel_guard_blocked_email_154()
returns trigger language plpgsql security definer set search_path=public,pg_temp as $$
begin
 if tg_op='UPDATE' and new.email is not distinct from old.email then return new;end if;
 if exists(select 1 from zameel_blocked_emails_154 where email_normalized=lower(trim(new.email)) and released_at is null and (expires_at is null or expires_at>now())) then raise exception 'registration_unavailable';end if;return new;
end $$;
create or replace function public.zameel_before_user_created_154(event jsonb)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
begin
 if exists(select 1 from zameel_blocked_emails_154 where email_normalized=lower(trim(event->'user'->>'email')) and released_at is null and (expires_at is null or expires_at>now())) then
 return jsonb_build_object('error',jsonb_build_object('http_code',403,'message','Registration is unavailable for this account.'));
 end if;return '{}'::jsonb;
end $$;
create or replace function public.zameel_sync_blocked_email_154()
returns trigger language plpgsql security definer set search_path=public,pg_temp as $$
declare address text;
begin
 select lower(trim(email)) into address from auth.users where id=new.user_id;
 if address is null then return new;end if;
 if new.status in ('blocked','suspended') then
 insert into zameel_blocked_emails_154(email_normalized,blocked_by,reason,expires_at)
 values(address,new.updated_by,new.reason,new.suspended_until)
 on conflict(email_normalized) do update set blocked_by=excluded.blocked_by,reason=excluded.reason,blocked_at=now(),released_at=null,expires_at=excluded.expires_at;
 elsif new.status='active' then update zameel_blocked_emails_154 set released_at=now() where email_normalized=address and released_at is null;
 end if;return new;
end $$;
create trigger preserve_blocked_email_154 after insert or update on public.admin_user_states for each row execute function public.zameel_sync_blocked_email_154();
-- Seed the registry for accounts that are currently blocked or suspended.
insert into public.zameel_blocked_emails_154(email_normalized,blocked_by,reason,expires_at)
select lower(trim(a.email)),s.updated_by,s.reason,s.suspended_until from public.admin_user_states s join auth.users a on a.id=s.user_id
where s.status in ('blocked','suspended') and a.email is not null and (s.suspended_until is null or s.suspended_until>now()) on conflict do nothing;
create table public.zameel_free_verification_154 (
 id bigint generated always as identity primary key,user_id uuid not null references auth.users(id) on delete cascade,
 granted_by uuid not null references auth.users(id),starts_at timestamptz not null,ends_at timestamptz not null,
 reason text not null,created_at timestamptz not null default now(),check(ends_at>starts_at)
);
alter table public.zameel_free_verification_154 enable row level security;
revoke all on public.zameel_free_verification_154 from public,anon,authenticated;
grant all on public.zameel_free_verification_154 to service_role;
grant usage,select on sequence public.zameel_free_verification_154_id_seq to service_role;
create or replace function public.zameel_admin_user_action_154(p_actor uuid,p_user uuid,p_operation text,p_input jsonb)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare reason text:=trim(p_input->>'reason'); days integer; ends timestamptz;
begin
 if not public.zameel_admin_owner_154(p_actor) then raise exception 'owner_only';end if;
 if length(coalesce(reason,''))<5 or not exists(select 1 from users where id=p_user) then raise exception 'invalid_user_action';end if;
 if p_operation='free_verification' then
 days:=(p_input->>'days')::integer;if days not between 1 and 3650 then raise exception 'invalid_duration';end if;
 if exists(select 1 from admin_user_states where user_id=p_user and status in ('blocked','suspended')) then raise exception 'account_unavailable';end if;
 -- A free grant extends existing time; it never shortens a paid entitlement.
 select greatest(coalesce(verification_expires_at,now()),now())+make_interval(days=>days) into ends from users where id=p_user for update;
 insert into zameel_free_verification_154(user_id,granted_by,starts_at,ends_at,reason) values(p_user,p_actor,now(),ends,reason);
 update users set verification_expires_at=ends where id=p_user;
 elsif p_operation='notification' then
 if length(trim(coalesce(p_input->>'title',''))) not between 1 and 120 or length(trim(coalesce(p_input->>'message',''))) not between 1 and 2000 then raise exception 'invalid_notification';end if;
 insert into notifications(user_id,actor_id,type,title_ar,title_en,body_ar,body_en,data)
 values(p_user,p_actor,'admin',(p_input->>'title'),(p_input->>'title'),(p_input->>'message'),(p_input->>'message'),jsonb_build_object('source','owner_private'));
 else raise exception 'unsupported_user_action';end if;
 insert into zameel_admin_access_log_154(actor_id,action,data_key,target_id,details) values(p_actor,p_operation,'users',p_user::text,jsonb_build_object('reason',reason,'ends_at',ends));
 return jsonb_build_object('saved',true,'ends_at',ends);
end $$;
-- New service categories preserve the original values used by existing versions.
alter table public.business_partners drop constraint if exists business_partners_category_check;
alter table public.business_partners add constraint business_partners_category_check check(category in ('offers','education','career','services','entertainment','humanitarian','other'));
alter table public.business_partners add column latitude double precision check(latitude between -90 and 90),add column longitude double precision check(longitude between -180 and 180),add column contact_phone text,add column contact_email text;
alter table public.business_partners add constraint partner_coordinates_154 check((latitude is null)=(longitude is null));
alter table public.advertisements add column owner_sponsored boolean not null default false;
create or replace function public.zameel_admin_partner_154(p_actor uuid,p_partner uuid,p_input jsonb)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare target uuid:=coalesce(p_partner,gen_random_uuid());category text:=p_input->>'category';lat double precision:=(p_input->>'latitude')::double precision;lng double precision:=(p_input->>'longitude')::double precision;days integer:=(p_input->>'days')::integer;active boolean:=coalesce((p_input->>'active')::boolean,true); ad uuid; reason text:=trim(p_input->>'reason');
begin
 if not public.zameel_admin_owner_154(p_actor) then raise exception 'owner_only';end if;
 if length(coalesce(reason,''))<5 or length(trim(coalesce(p_input->>'name',''))) not between 1 and 160 or category not in ('offers','education','career','services','entertainment','humanitarian','other') or lat is null or lng is null or lat not between -90 and 90 or lng not between -180 and 180 or days is null or days not between 1 and 3650 then raise exception 'invalid_partner';end if;
 if coalesce(p_input->>'website_url','')<>'' and p_input->>'website_url' !~ '^https://' then raise exception 'invalid_website';end if;
 if coalesce(p_input->>'logo_url','')<>'' and p_input->>'logo_url' !~ '^https://' then raise exception 'invalid_logo';end if;
 if p_partner is not null and not exists(select 1 from business_partners where id=p_partner) then raise exception 'partner_not_found';end if;
 insert into business_partners(id,owner_id,name,category,description,logo_url,website_url,is_approved,is_active,latitude,longitude,contact_phone,contact_email)
 values(target,p_actor,trim(p_input->>'name'),category,left(coalesce(p_input->>'description',''),10000),nullif(p_input->>'logo_url',''),nullif(p_input->>'website_url',''),true,active,lat,lng,left(p_input->>'contact_phone',100),left(p_input->>'contact_email',254))
 on conflict(id) do update set name=excluded.name,category=excluded.category,description=excluded.description,logo_url=excluded.logo_url,website_url=excluded.website_url,is_approved=true,is_active=active,latitude=lat,longitude=lng,contact_phone=excluded.contact_phone,contact_email=excluded.contact_email,updated_at=now();
 insert into advertiser_terms(partner_id,starts_at,ends_at,approved_by) values(target,now(),now()+make_interval(days=>days),p_actor)
 on conflict(partner_id) do update set ends_at=excluded.ends_at,approved_by=p_actor,starts_at=least(advertiser_terms.starts_at,now());
 if p_input->>'post_title' is not null and trim(p_input->>'post_title')<>'' then
 insert into advertisements(partner_id,representative_id,title,body,category,latitude,longitude,status,published_at,expires_at,owner_sponsored)
 values(target,p_actor,left(trim(p_input->>'post_title'),180),left(coalesce(p_input->>'post_body',''),10000),category,lat,lng,case when active then 'published' else 'draft' end,now(),now()+make_interval(days=>days),true) returning id into ad;
 end if;
 if active then
 update feature_flags set is_enabled=true,display_mode='enabled',rollout_percent=100 where feature_key in ('partner_advertising','business_partners') and scope_type='global' and scope_value='*';
 end if;
 -- Approval is by the owner here; no receipt or paid revenue is fabricated.
 insert into zameel_admin_access_log_154(actor_id,action,data_key,target_id,details) values(p_actor,'partner_save','partners',target::text,jsonb_build_object('reason',reason,'advertisement_id',ad,'active',active));
 return jsonb_build_object('saved',true,'partner_id',target,'advertisement_id',ad);
end $$;
revoke all on function public.zameel_sync_blocked_email_154(),public.zameel_admin_user_action_154(uuid,uuid,text,jsonb),public.zameel_admin_partner_154(uuid,uuid,jsonb) from public,anon,authenticated;
grant execute on function public.zameel_admin_user_action_154(uuid,uuid,text,jsonb),public.zameel_admin_partner_154(uuid,uuid,jsonb) to service_role;
notify pgrst,'reload schema';
commit;
