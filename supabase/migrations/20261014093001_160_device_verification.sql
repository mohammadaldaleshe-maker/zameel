begin;
set local lock_timeout = '2s';
set local statement_timeout = '60s';
create schema if not exists zameel_security160;
revoke all on schema zameel_security160 from public,anon,authenticated;
create table zameel_security160.config(singleton boolean primary key default true check(singleton),enabled boolean not null default false,previous_hook text,installed_hook boolean not null default false);
insert into zameel_security160.config(singleton) values(true);
create table zameel_security160.devices(
 id uuid primary key default gen_random_uuid(),user_id uuid not null references auth.users(id) on delete cascade,
 secret_hash text not null check(length(secret_hash)=64),label text not null check(length(label) between 1 and 80),
 trusted_after timestamptz not null default now(),created_at timestamptz not null default now(),last_seen_at timestamptz not null default now(),revoked_at timestamptz,
 unique(user_id,secret_hash));
create table zameel_security160.sessions(
 session_id uuid primary key references auth.sessions(id) on delete cascade,
 user_id uuid not null references auth.users(id) on delete cascade,
 device_id uuid not null references zameel_security160.devices(id) on delete cascade,
 approved_at timestamptz not null default now(),revoked_at timestamptz);
create index on zameel_security160.sessions(user_id,device_id);
create table zameel_security160.challenges(
 id uuid primary key default gen_random_uuid(),user_id uuid not null references auth.users(id) on delete cascade,
 session_id uuid not null references auth.sessions(id) on delete cascade,
 secret_hash text not null,label text not null,created_at timestamptz not null default now(),consumed_at timestamptz);
create index on zameel_security160.challenges(user_id,created_at desc);
-- No client grants, including service_role; all access is through bounded functions.
revoke all on all tables in schema zameel_security160 from public,anon,authenticated;
create function zameel_security160.session_valid(p_user uuid,p_session uuid) returns boolean
language sql stable set search_path='' as $$
 select exists(select 1 from auth.sessions a where a.id=p_session and a.user_id=p_user
 and (to_jsonb(a)->>'not_after' is null or (to_jsonb(a)->>'not_after')::timestamptz>now()));
$$;
revoke all on function zameel_security160.session_valid(uuid,uuid) from public,anon,authenticated;
create function public.zameel_device_authorized160() returns boolean
language plpgsql stable security definer set search_path='' as $$
declare claims jsonb:=auth.jwt();uid uuid:=auth.uid();sid uuid;
begin
 if not (select enabled from zameel_security160.config where singleton) then return true;end if;
 if claims->>'role'='service_role' then return true;end if;
 if uid is null then return false;end if;
 begin sid:=(claims->>'session_id')::uuid;exception when invalid_text_representation then return false;end;
 return exists(select 1 from zameel_security160.sessions s
 join zameel_security160.devices d on d.id=s.device_id
 join auth.sessions a on a.id=s.session_id and a.user_id=s.user_id
 where s.session_id=sid and s.user_id=uid and d.user_id=uid and s.revoked_at is null and d.revoked_at is null and zameel_security160.session_valid(uid,sid));
end $$;
create function public.zameel_device_status160() returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare uid uuid:=auth.uid();sid uuid;
begin
 if uid is null then raise exception 'authentication_required';end if;
 begin sid:=(auth.jwt()->>'session_id')::uuid;exception when invalid_text_representation then raise exception 'invalid_session';end;
 if sid is null or not zameel_security160.session_valid(uid,sid) then return jsonb_build_object('enabled',(select enabled from zameel_security160.config where singleton),'approved',false);end if;
 return jsonb_build_object('enabled',(select enabled from zameel_security160.config where singleton),
 'approved',exists(select 1 from zameel_security160.sessions s join zameel_security160.devices d on d.id=s.device_id
 where s.session_id=sid and s.user_id=uid and d.user_id=uid and s.revoked_at is null and d.revoked_at is null));
end $$;
create function public.zameel_device_present160(p_secret text) returns boolean
language plpgsql security definer set search_path='' as $$
declare uid uuid:=auth.uid();sid uuid;did uuid;hash text;cutoff timestamptz;
begin
 if uid is null or p_secret is null or p_secret !~ '^[a-f0-9]{64}$' then raise exception 'invalid_device_proof';end if;
 sid:=(auth.jwt()->>'session_id')::uuid;
 if sid is null or not zameel_security160.session_valid(uid,sid) then raise exception 'invalid_session';end if;
 hash:=encode(sha256(convert_to(p_secret,'UTF8')),'hex');
 select id,trusted_after into did,cutoff from zameel_security160.devices where user_id=uid and secret_hash=hash and revoked_at is null for update;
 if did is null then return false;end if;
 if exists(select 1 from auth.sessions a where a.id=sid and a.created_at<cutoff) then return false;end if;
 -- Explicit revocation cannot be undone by presenting the same device proof.
 if exists(select 1 from zameel_security160.sessions where session_id=sid and revoked_at is not null) then return false;end if;
 insert into zameel_security160.sessions(session_id,user_id,device_id) values(sid,uid,did)
 on conflict(session_id) do nothing;
 update zameel_security160.devices set last_seen_at=now() where id=did and last_seen_at<now()-interval '5 minutes';
 return true;
end $$;
create function public.zameel_device_challenge160(p_secret text,p_label text) returns uuid
language plpgsql security definer set search_path='' as $$
declare uid uuid:=auth.uid();sid uuid;result uuid;
begin
 if uid is null or p_secret is null or p_secret !~ '^[a-f0-9]{64}$' or p_label is null or length(btrim(p_label)) not between 1 and 80 then raise exception 'invalid_device_proof';end if;
 sid:=(auth.jwt()->>'session_id')::uuid;
 -- Serialize per account to make resend bounds effective under concurrent calls.
 perform 1 from auth.users where id=uid and (email_confirmed_at is not null or phone_confirmed_at is not null) for update;
 if not found then raise exception 'confirmed_email_required';end if;
 if sid is null or not zameel_security160.session_valid(uid,sid) then raise exception 'invalid_session';end if;
 if exists(select 1 from zameel_security160.challenges where user_id=uid and created_at>now()-interval '60 seconds') then raise exception 'device_challenge_rate_limited';end if;
 if (select count(*) from zameel_security160.challenges where user_id=uid and created_at>now()-interval '1 hour')>=10 then raise exception 'device_challenge_rate_limited';end if;
 delete from zameel_security160.challenges where user_id=uid and created_at<now()-interval '1 day';
 insert into zameel_security160.challenges(user_id,session_id,secret_hash,label)
 values(uid,sid,encode(sha256(convert_to(p_secret,'UTF8')),'hex'),btrim(p_label)) returning id into result;
 return result;
end $$;
create function public.zameel_device_complete160(p_challenge uuid,p_secret text) returns boolean
language plpgsql security definer set search_path='' as $$
declare uid uuid:=auth.uid();sid uuid;c zameel_security160.challenges;did uuid;is_new boolean;otp_time timestamptz;
begin
 if uid is null or p_secret is null or p_secret !~ '^[a-f0-9]{64}$' then raise exception 'invalid_device_proof';end if;
 sid:=(auth.jwt()->>'session_id')::uuid;
 select * into c from zameel_security160.challenges where id=p_challenge and user_id=uid for update;
 if c.id is null or c.secret_hash<>encode(sha256(convert_to(p_secret,'UTF8')),'hex') or c.consumed_at is not null or c.created_at<now()-interval '10 minutes' then raise exception 'device_challenge_invalid_or_expired';end if;
 -- OTP must have been verified AFTER this challenge, in a new Auth session.
 select max(to_timestamp((x->>'timestamp')::double precision)) into otp_time
 from jsonb_array_elements(coalesce(auth.jwt()->'amr','[]'::jsonb)) x where x->>'method'='otp';
 if sid is null or sid=c.session_id or otp_time is null or otp_time<c.created_at-interval '1 second'
 or otp_time>now()+interval '5 seconds' or not zameel_security160.session_valid(uid,sid)
 then raise exception 'fresh_email_verification_required';end if;
 -- Serialize approval/revocation on this device row; no resurrection through stale requests.
 select id into did from zameel_security160.devices where user_id=uid and secret_hash=c.secret_hash for update;
 is_new:=did is null;
 if is_new then
  insert into zameel_security160.devices(user_id,secret_hash,label) values(uid,c.secret_hash,c.label) returning id into did;
 else
  update zameel_security160.devices set revoked_at=null,label=c.label,last_seen_at=now(),trusted_after=now() where id=did;
 end if;
 insert into zameel_security160.sessions(session_id,user_id,device_id) values(sid,uid,did)
 on conflict(session_id) do update set revoked_at=null,approved_at=now(),device_id=excluded.device_id
 where zameel_security160.sessions.user_id=uid;
 update zameel_security160.challenges set consumed_at=now() where id=c.id;
 -- Superseded password session stays unapproved; it cannot access account data.
 insert into public.notifications(user_id,actor_id,type,title_ar,title_en,body_ar,body_en,data,is_read)
 values(uid,uid,'device_verified160','تسجيل دخول من جهاز جديد','New device sign-in',
 'تم تأكيد جهاز: '||c.label,'Verified device: '||c.label,jsonb_build_object('device_id',did),false);
 return true;
end $$;
create function public.zameel_devices_list160() returns jsonb
language plpgsql stable security definer set search_path='' as $$
begin
 if auth.uid() is null or not public.zameel_device_authorized160() then raise exception 'device_verification_required';end if;
 -- Even during the staged rollout only explicitly approved sessions may manage trust.
 if not coalesce((public.zameel_device_status160()->>'approved')::boolean,false) then raise exception 'device_verification_required';end if;
 return coalesce((select jsonb_agg(row_to_json(t) order by t.created_at desc) from (
 select d.id,d.label,d.created_at,d.last_seen_at,d.revoked_at,
 exists(select 1 from zameel_security160.sessions s where s.device_id=d.id and s.session_id=(auth.jwt()->>'session_id')::uuid) as is_current
 from zameel_security160.devices d where d.user_id=auth.uid() order by d.created_at desc limit 100)t),'[]'::jsonb);
end $$;
create function public.zameel_devices_revoke160(p_device uuid default null) returns integer
language plpgsql security definer set search_path='' as $$
declare count160 integer;
begin
 if auth.uid() is null or not coalesce((public.zameel_device_status160()->>'approved')::boolean,false) then raise exception 'device_verification_required';end if;
 update zameel_security160.devices set revoked_at=now() where user_id=auth.uid() and (p_device is null or id=p_device) and revoked_at is null;
 get diagnostics count160=row_count;
 update zameel_security160.sessions set revoked_at=now() where user_id=auth.uid() and (p_device is null or device_id=p_device) and revoked_at is null;
 return count160;
end $$;
-- A new account already proved its contact through signup OTP; do not ask twice.
create function public.zameel_device_signup160(p_secret text,p_label text) returns boolean
language plpgsql security definer set search_path='' as $$
declare uid uuid:=auth.uid();sid uuid;did uuid;verified timestamptz;otp_time timestamptz;
begin
 if uid is null or p_secret is null or p_secret !~ '^[a-f0-9]{64}$' or p_label is null or length(btrim(p_label)) not between 1 and 80 then raise exception 'invalid_device_proof';end if;
 sid:=(auth.jwt()->>'session_id')::uuid;
 select greatest(email_confirmed_at,phone_confirmed_at) into verified from auth.users where id=uid and created_at>now()-interval '10 minutes';
 if verified is null or sid is null or not zameel_security160.session_valid(uid,sid) then return false;end if;
 select max(to_timestamp((x->>'timestamp')::double precision)) into otp_time
 from jsonb_array_elements(coalesce(auth.jwt()->'amr','[]'::jsonb)) x where x->>'method'='otp';
 if otp_time is null or otp_time<now()-interval '10 minutes' or otp_time>now()+interval '5 seconds' then return false;end if;
 -- First device only. A signup JWT cannot enroll additional devices after the first.
 perform 1 from auth.users where id=uid for update;
 if exists(select 1 from zameel_security160.devices where user_id=uid) then return false;end if;
 insert into zameel_security160.devices(user_id,secret_hash,label)
 values(uid,encode(sha256(convert_to(p_secret,'UTF8')),'hex'),btrim(p_label)) returning id into did;
 insert into zameel_security160.sessions(session_id,user_id,device_id) values(sid,uid,did);
 return true;
end $$;
revoke all on function public.zameel_device_signup160(text,text) from public,anon;
grant execute on function public.zameel_device_signup160(text,text) to authenticated,service_role;

-- Staff portal accounts have generated non-deliverable email aliases. Preserve
-- their owner-issued, one-use activation code as the new-device proof instead.
create function public.zameel_staff_device_login160(p_user uuid,p_session uuid,p_secret text,p_fresh_code boolean) returns boolean
language plpgsql security definer set search_path='' as $$
declare did uuid;cutoff timestamptz;
begin
 if auth.jwt()->>'role' is distinct from 'service_role' then raise exception 'service_only';end if;
 if not exists(select 1 from auth.users a join public.sales_staff_logins l on l.user_id=a.id
 where a.id=p_user and a.email like '%@staff.zameel.example') or not zameel_security160.session_valid(p_user,p_session) then raise exception 'invalid_staff_session';end if;
 if p_secret is null or p_secret !~ '^[a-f0-9]{64}$' then
  return not (select enabled from zameel_security160.config where singleton);
 end if;
 select id,trusted_after into did,cutoff from zameel_security160.devices where user_id=p_user and secret_hash=encode(sha256(convert_to(p_secret,'UTF8')),'hex') and revoked_at is null for update;
 if not p_fresh_code then
  if did is null or exists(select 1 from auth.sessions where id=p_session and created_at<cutoff) then return false;end if;
 else
  insert into zameel_security160.devices(user_id,secret_hash,label) values(p_user,encode(sha256(convert_to(p_secret,'UTF8')),'hex'),'بوابة موظفي زميل')
  on conflict(user_id,secret_hash) do update set revoked_at=null,trusted_after=now(),last_seen_at=now()
  returning id into did;
 end if;
 insert into zameel_security160.sessions(session_id,user_id,device_id) values(p_session,p_user,did) on conflict(session_id) do nothing;
 return true;
end $$;
revoke all on function public.zameel_staff_device_login160(uuid,uuid,text,boolean) from public,anon,authenticated;
grant execute on function public.zameel_staff_device_login160(uuid,uuid,text,boolean) to service_role;

create table zameel_security160.push_proofs(
 token_hash text primary key,user_id uuid not null references auth.users(id) on delete cascade,
 session_id uuid not null references auth.sessions(id) on delete cascade,
 device_id uuid not null references zameel_security160.devices(id) on delete cascade);
revoke all on zameel_security160.push_proofs from public,anon,authenticated;
create function zameel_security160.bind_push() returns trigger
language plpgsql security definer set search_path='' as $$
declare trusted uuid;uid uuid:=auth.uid();sid uuid;
begin
 if tg_op='DELETE' then
  delete from zameel_security160.push_proofs where token_hash=encode(sha256(convert_to(old.token,'UTF8')),'hex');return old;
 end if;
 if tg_op='UPDATE' and (old.token,old.user_id) is distinct from (new.token,new.user_id) then
  delete from zameel_security160.push_proofs where token_hash=encode(sha256(convert_to(old.token,'UTF8')),'hex');
 end if;
 if uid is null or new.user_id<>uid then return new;end if;
 sid:=(auth.jwt()->>'session_id')::uuid;
 select s.device_id into trusted from zameel_security160.sessions s join zameel_security160.devices d on d.id=s.device_id
 where s.session_id=sid and s.user_id=uid and d.user_id=uid and s.revoked_at is null and d.revoked_at is null and zameel_security160.session_valid(uid,sid);
 if trusted is null then return new;end if;
 insert into zameel_security160.push_proofs(token_hash,user_id,session_id,device_id)
 values(encode(sha256(convert_to(new.token,'UTF8')),'hex'),uid,sid,trusted)
 on conflict(token_hash) do update set user_id=excluded.user_id,session_id=excluded.session_id,device_id=excluded.device_id;
 return new;
end $$;
revoke all on function zameel_security160.bind_push() from public,anon,authenticated;
create trigger zameel_bind_push160 after insert or update or delete on public.push_device_tokens for each row execute function zameel_security160.bind_push();
create function public.zameel_push_allowed160(p_user uuid,p_tokens text[]) returns text[]
language plpgsql stable security definer set search_path='' as $$
begin
 if auth.jwt()->>'role' is distinct from 'service_role' then raise exception 'service_only';end if;
 if cardinality(p_tokens)>1000 then raise exception 'too_many_devices';end if;
 return array(select t.token from public.push_device_tokens t where t.user_id=p_user and t.token=any(p_tokens) and (
 not (select enabled from zameel_security160.config where singleton) or exists(
 select 1 from zameel_security160.push_proofs p join zameel_security160.devices d on d.id=p.device_id
 join zameel_security160.sessions s on s.session_id=p.session_id and s.device_id=p.device_id
 where p.token_hash=encode(sha256(convert_to(t.token,'UTF8')),'hex') and p.user_id=p_user and d.user_id=p_user and s.user_id=p_user
 and d.revoked_at is null and s.revoked_at is null and zameel_security160.session_valid(p_user,s.session_id))));
end $$;
revoke all on function public.zameel_push_allowed160(uuid,text[]) from public,anon,authenticated;
grant execute on function public.zameel_push_allowed160(uuid,text[]) to service_role;

-- Data API hook: covers tables, views and SECURITY DEFINER RPCs before execution.
-- Preserve any existing custom hook rather than silently replacing it.
create function public.zameel_device_pre_request160() returns void
language plpgsql security definer set search_path='' as $$
declare path text:=current_setting('request.path',true);old_hook text;
begin
 select previous_hook into old_hook from zameel_security160.config where singleton;
 if old_hook is not null and old_hook<>'' then execute format('select %s()',old_hook::regproc);end if;
 if auth.jwt()->>'role' is distinct from 'authenticated' then return;end if;
 if path=any(array['/rpc/zameel_device_status160','/rpc/zameel_device_present160','/rpc/zameel_device_challenge160',
 '/rpc/zameel_device_complete160','/rpc/zameel_device_authorized160','/rpc/zameel_device_signup160','/rpc/zameel_release_policy']) then return;end if;
 if not public.zameel_device_authorized160() then raise sqlstate '42501' using message='device_verification_required';end if;
end $$;
-- Restrictive policies intersect existing permissions; they never grant new access.
do $$declare t record;begin
 for t in select ns.nspname,c.relname from pg_class c join pg_namespace ns on ns.oid=c.relnamespace
 where c.relkind in('r','p') and c.relrowsecurity and (ns.nspname='public' or (ns.nspname='storage' and c.relname='objects') or (ns.nspname='realtime' and c.relname='messages')) loop
  execute format('create policy zameel_device_gate160 on %I.%I as restrictive for all to authenticated using ((select public.zameel_device_authorized160())) with check ((select public.zameel_device_authorized160()))',t.nspname,t.relname);
 end loop;
end $$;
revoke all on function public.zameel_device_authorized160(),public.zameel_device_status160(),public.zameel_device_present160(text),public.zameel_device_challenge160(text,text),public.zameel_device_complete160(uuid,text),public.zameel_devices_list160(),public.zameel_devices_revoke160(uuid),public.zameel_device_pre_request160() from public,anon;
grant execute on function public.zameel_device_authorized160(),public.zameel_device_status160(),public.zameel_device_present160(text),public.zameel_device_challenge160(text,text),public.zameel_device_complete160(uuid,text),public.zameel_devices_list160(),public.zameel_devices_revoke160(uuid),public.zameel_device_pre_request160() to authenticated,service_role;
-- Installation of the pre-request hook is a separate guarded activation step.
-- During staging enabled=false, preserving old APP/ADMIN behavior.
notify pgrst,'reload schema';
commit;
