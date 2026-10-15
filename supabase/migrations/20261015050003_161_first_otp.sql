begin;
set local lock_timeout='2s';set local statement_timeout='60s';
-- A fresh, server-signed email/SMS OTP can confirm the first installation too.
-- Password-only sessions and every later/previously revoked installation still use the challenge flow.
create or replace function public.zameel_device_first_otp161(p_secret text,p_label text) returns boolean
language plpgsql security definer set search_path='' as $$
declare uid uuid:=auth.uid();sid uuid;did uuid;confirmed timestamptz;otp_time timestamptz;
begin
 if uid is null or p_secret is null or p_secret !~ '^[a-f0-9]{64}$' or p_label is null or length(btrim(p_label)) not between 1 and 80 then raise exception 'invalid_device_proof';end if;
 sid:=(auth.jwt()->>'session_id')::uuid;
 if sid is null or not zameel_security160.session_valid(uid,sid) then return false;end if;
 select greatest(email_confirmed_at,phone_confirmed_at) into confirmed from auth.users where id=uid;
 if confirmed is null then return false;end if;
 select max(to_timestamp((x->>'timestamp')::double precision)) into otp_time
 from jsonb_array_elements(coalesce(auth.jwt()->'amr','[]'::jsonb)) x where x->>'method'='otp';
 if otp_time is null or otp_time<now()-interval '10 minutes' or otp_time>now()+interval '5 seconds' then return false;end if;
 if not exists(select 1 from auth.sessions s where s.id=sid and s.user_id=uid and s.created_at>=now()-interval '10 minutes') then return false;end if;
 perform 1 from auth.users where id=uid for update;
 if exists(select 1 from zameel_security160.devices where user_id=uid) then return false;end if;
 insert into zameel_security160.devices(user_id,secret_hash,label) values(uid,encode(sha256(convert_to(p_secret,'UTF8')),'hex'),btrim(p_label)) returning id into did;
 insert into zameel_security160.sessions(session_id,user_id,device_id) values(sid,uid,did);
 return true;
end $$;
revoke all on function public.zameel_device_first_otp161(text,text) from public,anon;
grant execute on function public.zameel_device_first_otp161(text,text) to authenticated;
create or replace function public.zameel_device_pre_request160() returns void
language plpgsql security definer set search_path='' as $$
declare path text:=current_setting('request.path',true);old_hook text;
begin
 select previous_hook into old_hook from zameel_security160.config where singleton;
 if old_hook is not null and old_hook<>'' then execute format('select %s()',old_hook::regproc);end if;
 if auth.jwt()->>'role' is distinct from 'authenticated' then return;end if;
 if path=any(array['/rpc/zameel_device_status160','/rpc/zameel_device_present160','/rpc/zameel_device_challenge160',
 '/rpc/zameel_device_complete160','/rpc/zameel_device_authorized160','/rpc/zameel_device_signup160','/rpc/zameel_device_first_otp161','/rpc/zameel_release_policy']) then return;end if;
 if not public.zameel_device_authorized160() then raise sqlstate '42501' using message='device_verification_required';end if;
end $$;
notify pgrst,'reload schema';
commit;
