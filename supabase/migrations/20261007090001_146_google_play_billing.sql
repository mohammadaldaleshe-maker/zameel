-- Google Play billing candidate; apply only after isolated DB and native build validation.
-- No client can create a paid receipt or grant an entitlement through these functions.
begin;
create table public.zameel_play_payment_intents (
 id uuid primary key default gen_random_uuid(),
 user_id uuid references public.users(id) on delete set null,
 kind text not null check(kind in ('verification','promotion')),
 request_id uuid not null,
 product_id text not null,
 days integer,
 state text not null default 'awaiting_payment' check(state in ('awaiting_payment','paid','cancelled')),
 account_binding text not null check(account_binding ~ '^[a-f0-9]{64}$'),
 intent_binding text not null unique check(intent_binding ~ '^[a-f0-9]{64}$'),
 created_at timestamptz not null default now(),
 unique(kind,request_id),
 check((kind='verification' and days is null and product_id='zameel_verification_month') or
       (kind='promotion' and days is not null and days between 1 and 30 and product_id='zameel_promotion_'||lpad(days::text,2,'0')||'_days'))
);
create table public.zameel_play_purchase_ledger (
 token_sha256 text primary key check(token_sha256 ~ '^[a-f0-9]{64}$'),
 intent_id uuid unique references public.zameel_play_payment_intents(id) on delete set null,
 product_id text not null,
 order_id text,
 token_cipher text not null,
 last_error text,
 purchased_at timestamptz not null,
 recorded_at timestamptz not null default now(),
 is_test boolean not null,
 settlement_state text not null default 'awaiting_review' check(settlement_state in
  ('awaiting_review','approved','refund_required','refunded','revoked')),
 acknowledgement_state text not null default 'pending' check(acknowledgement_state in ('pending','completed')),
 provider_checked_at timestamptz not null default now()
);
create index zameel_play_worker_due on public.zameel_play_purchase_ledger(provider_checked_at) where settlement_state not in ('refunded','revoked');
-- No raw purchase tokens or credentials are exposed by these tables.
alter table public.zameel_play_payment_intents enable row level security;
alter table public.zameel_play_purchase_ledger enable row level security;
revoke all on public.zameel_play_payment_intents,public.zameel_play_purchase_ledger from public,anon,authenticated;
grant all on public.zameel_play_payment_intents,public.zameel_play_purchase_ledger to service_role;

create function public.zameel_play_prepare_intent(p_actor uuid,p_kind text,p_request uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare r public.zameel_play_payment_intents; new_id uuid; owner uuid; source_status text; duration integer; product text;
begin
 if p_actor is null or p_kind is null or p_kind not in ('verification','promotion') or p_request is null then raise exception 'invalid_payment_intent';end if;
 -- Serializes preparation for this account and verifies it exists.
 perform 1 from public.users where id=p_actor for update;
 if not found then raise exception 'payment_account_missing';end if;
 if exists(select 1 from public.admin_user_states where user_id=p_actor and status in ('blocked','suspended')) then raise exception 'payment_account_unavailable';end if;
 if p_kind='verification' then
  select user_id,status into owner,source_status from public.zameel_verification_requests where id=p_request for update;
  product:='zameel_verification_month';
 else
  select owner_id,status,days into owner,source_status,duration from public.zameel_post_promotions where id=p_request for update;
  if duration is null or duration not between 1 and 30 then raise exception 'invalid_promotion_duration';end if;
  product:='zameel_promotion_'||lpad(duration::text,2,'0')||'_days';
 end if;
 if owner is distinct from p_actor or source_status is distinct from 'pending' then raise exception 'payment_request_unavailable';end if;
 select * into r from public.zameel_play_payment_intents where kind=p_kind and request_id=p_request for update;
 if found then
  if r.user_id is distinct from p_actor or r.state='cancelled' then raise exception 'payment_intent_unavailable';end if;
  return to_jsonb(r);
 end if;
 new_id:=gen_random_uuid();
 insert into public.zameel_play_payment_intents(id,user_id,kind,request_id,product_id,days,account_binding,intent_binding)
 values(new_id,p_actor,p_kind,p_request,product,duration,
  encode(extensions.digest(convert_to('zameel:account:v1:'||p_actor::text,'UTF8'),'sha256'),'hex'),
  encode(extensions.digest(convert_to('zameel:intent:v1:'||new_id::text,'UTF8'),'sha256'),'hex')) returning * into r;
 return to_jsonb(r);
end $$;

-- Only the authenticated Edge Function service client may call this AFTER checking Google.
-- All arguments are derived from the Google response or a trusted DB intent, not device claims.
create function public.zameel_play_record_verified_purchase(p_actor uuid,p_intent uuid,p_token_sha256 text,
 p_product text,p_account_binding text,p_intent_binding text,p_purchased_at timestamptz,p_order text,p_is_test boolean,p_cipher text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare i public.zameel_play_payment_intents; r public.zameel_play_purchase_ledger;
begin
 if p_actor is null or p_intent is null or p_token_sha256 is null or p_token_sha256 !~ '^[a-f0-9]{64}$'
  or p_cipher is null or length(p_cipher)>16000 or p_purchased_at is null or p_is_test is null or length(coalesce(p_order,''))>256 then raise exception 'invalid_verified_payment';end if;
 select * into i from public.zameel_play_payment_intents where id=p_intent for update;
 if i.id is null or i.user_id is distinct from p_actor or i.product_id is distinct from p_product
  or i.account_binding is distinct from p_account_binding or i.intent_binding is distinct from p_intent_binding then raise exception 'payment_binding_mismatch';end if;
 if i.state not in ('awaiting_payment','paid','cancelled') then raise exception 'payment_intent_unavailable';end if;
 -- Conflicting token claims cannot overwrite the original receipt. Unique constraints also cover concurrency.
 insert into public.zameel_play_purchase_ledger(token_sha256,intent_id,product_id,purchased_at,order_id,is_test,token_cipher)
 values(p_token_sha256,p_intent,p_product,p_purchased_at,p_order,p_is_test,p_cipher)
 on conflict(token_sha256) do nothing;
 select * into r from public.zameel_play_purchase_ledger where token_sha256=p_token_sha256 for update;
 if r.intent_id is distinct from p_intent or r.product_id is distinct from p_product or r.is_test is distinct from p_is_test then raise exception 'purchase_token_already_used';end if;
 if i.state='cancelled' then update public.zameel_play_purchase_ledger set settlement_state='refund_required' where token_sha256=p_token_sha256 and settlement_state not in ('refunded','revoked') returning * into r;end if;
 update public.zameel_play_purchase_ledger set provider_checked_at=now() where token_sha256=p_token_sha256;
 update public.zameel_play_payment_intents set state=case when state='cancelled' then 'cancelled' else 'paid' end where id=p_intent;
 -- Intentionally no badge expiry or promotion status is changed here.
 return jsonb_build_object('intent_id',p_intent,'payment_state','paid','settlement_state',r.settlement_state,
  'acknowledgement_state',r.acknowledgement_state);
end $$;
revoke all on function public.zameel_play_prepare_intent(uuid,text,uuid),
 public.zameel_play_record_verified_purchase(uuid,uuid,text,text,text,text,timestamptz,text,boolean,text) from public,anon,authenticated;
grant execute on function public.zameel_play_prepare_intent(uuid,text,uuid),
 public.zameel_play_record_verified_purchase(uuid,uuid,text,text,text,text,timestamptz,text,boolean,text) to service_role;


alter table public.zameel_verification_requests add column payment_source text not null default 'manual' check(payment_source in ('manual','google_play'));
alter table public.zameel_post_promotions add column payment_source text not null default 'manual' check(payment_source in ('manual','google_play'));
create or replace function public.zameel_play_request_verification() returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor uuid:=auth.uid(); r public.zameel_verification_requests; code text;
begin
 if actor is null or not coalesce(public.zameel_account_can_write(),false) then raise exception 'verification_account_unavailable';end if;
 perform 1 from public.users where id=actor for update;
 select * into r from public.zameel_verification_requests where user_id=actor and status='pending';
 if r.id is not null then if r.payment_source<>'google_play' then raise exception 'existing_manual_request';end if; return to_jsonb(r);end if;
 for attempt in 1..50 loop
 code:=chr(65+floor(random()*26)::int)||chr(65+floor(random()*26)::int)||lpad(floor(random()*10000)::int::text,4,'0');
 if exists(select 1 from public.zameel_post_promotions where payment_code=code) then continue;end if;
 begin
 insert into public.zameel_verification_requests(user_id,payment_code,wallet_number,beneficiary,payment_source) values(actor,code,'Google Play','Google Play','google_play') returning * into r;
 return to_jsonb(r);
 exception when unique_violation then null;
 end;
 end loop;
 raise exception 'payment_code_generation_failed';
end $$;

create or replace function public.zameel_play_request_promotion(p_post uuid,p_days integer,p_audience text,p_countrywide boolean,p_cities text[],p_universities text[],p_min_age integer,p_max_age integer,p_gender text,p_notes text default '') returns jsonb
language plpgsql security definer set search_path='' as $$
declare r public.zameel_post_promotions; cfg public.zameel_promotion_settings; old_result jsonb; code text; tries integer:=0;
begin
 if auth.uid() is null or not coalesce(public.zameel_account_can_write(),false) then raise exception 'account_unavailable';end if;
 if p_audience is null or p_audience not in ('general','students') or p_countrywide is null or p_min_age is null or p_max_age is null or p_min_age not between 18 and 100 or p_max_age not between p_min_age and 100 or p_gender is null or p_gender not in ('male','female','both') or p_cities is null or p_universities is null or cardinality(p_cities)>1500 or cardinality(p_universities)>100 then raise exception 'invalid_promotion_target';end if;
 if (p_audience='students' and (cardinality(p_universities)=0 or cardinality(p_cities)>0 or p_countrywide)) or (p_audience='general' and (cardinality(p_universities)>0 or (p_countrywide and cardinality(p_cities)>0) or (not p_countrywide and cardinality(p_cities)=0))) then raise exception 'invalid_promotion_target';end if;
 if exists(select 1 from unnest(p_cities) c where c is null or not exists(select 1 from public.zameel_promotion_locations where name=c)) or exists(select 1 from unnest(p_universities) u where u is null or not exists(select 1 from public.zameel_promotion_universities where name=u)) then raise exception 'unknown_promotion_location';end if;
 old_result:=public.zameel_request_promotion(p_post,p_days,p_notes);
 select * into r from public.zameel_post_promotions where id=(old_result->>'id')::uuid for update;
 if r.status<>'pending' then raise exception 'promotion_already_active';end if;
 if r.payment_code is not null and r.payment_source<>'google_play' then raise exception 'existing_manual_request';end if;
 if r.payment_code is null then
 loop
 tries:=tries+1;if tries>20 then raise exception 'payment_code_retry';end if;
 code:=chr(65+floor(random()*26)::integer)||chr(65+floor(random()*26)::integer)||lpad(floor(random()*10000)::integer::text,4,'0');
 begin
 update public.zameel_post_promotions set audience_type=p_audience,countrywide=p_countrywide,target_cities=p_cities,target_universities=p_universities,min_age=p_min_age,max_age=p_max_age,target_gender=p_gender,payment_code=code,amount_fils=days*500,wallet_number='Google Play',beneficiary='Google Play',payment_source='google_play',updated_at=now() where id=r.id returning * into r;
 exit;
 exception when unique_violation then null;
 end;
 end loop;
 end if;
 return to_jsonb(r);
end $$;

create function public.zameel_play_review_guard() returns trigger language plpgsql security definer set search_path='' as $$
declare k text; i public.zameel_play_payment_intents;
begin
 if new.payment_source<>'google_play' then return new;end if;
 k:=case tg_table_name when 'zameel_verification_requests' then 'verification' else 'promotion' end;
 select * into i from public.zameel_play_payment_intents where kind=k and request_id=new.id for update;
 if new.status='approved' and old.status<>'approved' and not exists(select 1 from public.zameel_play_purchase_ledger
  where intent_id=i.id and settlement_state='awaiting_review' and acknowledgement_state='completed') then raise exception 'google_payment_confirmation_required';end if;
 if new.status='approved' then
  update public.zameel_play_purchase_ledger set settlement_state='approved' where intent_id=i.id and settlement_state='awaiting_review';
 elsif new.status in ('rejected','cancelled') and old.status is distinct from new.status then
  update public.zameel_play_payment_intents set state='cancelled' where id=i.id;
  update public.zameel_play_purchase_ledger set settlement_state='refund_required' where intent_id=i.id and settlement_state in ('awaiting_review','approved');
 end if;
 return new;
end $$;
create trigger zameel_play_verification_review before update of status on public.zameel_verification_requests for each row execute function public.zameel_play_review_guard();
create trigger zameel_play_promotion_review before update of status on public.zameel_post_promotions for each row execute function public.zameel_play_review_guard();
revoke all on function public.zameel_play_review_guard() from public,anon,authenticated;
revoke all on function public.zameel_play_request_verification(),public.zameel_play_request_promotion(uuid,integer,text,boolean,text[],text[],integer,integer,text,text) from public,anon;
grant execute on function public.zameel_play_request_verification(),public.zameel_play_request_promotion(uuid,integer,text,boolean,text[],text[],integer,integer,text,text) to authenticated;

-- Reconciliation revokes the original grant and prevents approval after refund/chargeback.
create function public.zameel_play_revoke(p_token text,p_state text) returns void language plpgsql security definer set search_path='' as $$
declare i public.zameel_play_payment_intents; r public.zameel_play_purchase_ledger; was_approved boolean; term record; anchor timestamptz; remaining interval;
begin
 if p_state not in ('refunded','revoked') then raise exception 'invalid_revoke_state';end if;
 -- Same lock order as review and record: intent, then ledger.
 select pi.* into i from public.zameel_play_payment_intents pi join public.zameel_play_purchase_ledger l on l.intent_id=pi.id where l.token_sha256=p_token;
 if i.kind='verification' then
  perform 1 from public.users where id=i.user_id for update;
  perform 1 from public.zameel_verification_requests where id=i.request_id for update;
 elsif i.kind='promotion' then
  perform 1 from public.posts where id=(select post_id from public.zameel_post_promotions where id=i.request_id) for update;
  perform 1 from public.zameel_post_promotions where id=i.request_id for update;
 end if;
 perform 1 from public.zameel_play_payment_intents where id=i.id for update;
 select * into r from public.zameel_play_purchase_ledger where token_sha256=p_token for update;
 if r.token_sha256 is null then raise exception 'receipt_missing';end if;
 update public.zameel_play_purchase_ledger set settlement_state=p_state,provider_checked_at=now(),last_error=null where token_sha256=p_token;
 if i.id is null then return;end if;
 update public.zameel_play_payment_intents set state='cancelled' where id=i.id;
 if i.kind='promotion' then
  update public.zameel_post_promotions set status='cancelled',ends_at=least(coalesce(ends_at,now()),now()) where id=i.request_id;
 else
  select status='approved' into was_approved from public.zameel_verification_requests where id=i.request_id;
  update public.zameel_verification_requests set status='rejected',review_note='Google Play purchase revoked or refunded' where id=i.request_id;
  if was_approved then
   -- Close the revoked grant's gap without removing time purchased by another receipt.
   anchor:=now();
   for term in select id,starts_at,ends_at from public.zameel_verification_requests where user_id=i.user_id and status='approved' and ends_at>now() order by starts_at,id for update loop
    remaining:=term.ends_at-greatest(term.starts_at,now());
    update public.zameel_verification_requests set starts_at=anchor,ends_at=anchor+remaining where id=term.id;
    anchor:=anchor+remaining;
   end loop;
   update public.users set verification_expires_at=case when anchor>now() then anchor else null end where id=i.user_id;
  end if;
 end if;
 -- The trigger may request a refund while revoking; the final provider-confirmed state wins.
 update public.zameel_play_purchase_ledger set settlement_state=p_state where token_sha256=p_token;
end $$;
revoke all on function public.zameel_play_revoke(text,text) from public,anon,authenticated;
grant execute on function public.zameel_play_revoke(text,text) to service_role;
notify pgrst,'reload schema';
commit;
