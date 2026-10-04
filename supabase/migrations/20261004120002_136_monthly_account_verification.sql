begin;
alter table public.users add column if not exists verification_expires_at timestamptz;
create or replace function public.zameel_protect_verification_expiry() returns trigger language plpgsql set search_path='' as $$ begin
 if ((tg_op='INSERT' and new.verification_expires_at is not null) or (tg_op='UPDATE' and new.verification_expires_at is distinct from old.verification_expires_at)) and current_user not in ('postgres','service_role','supabase_admin') then raise exception 'verification_admin_required';end if;
 return new;
end $$;
drop trigger if exists zameel_protect_verification_expiry on public.users;
create trigger zameel_protect_verification_expiry before insert or update of verification_expires_at on public.users for each row execute function public.zameel_protect_verification_expiry();
revoke all on function public.zameel_protect_verification_expiry() from public,anon,authenticated;
insert into public.admin_permissions(permission_key,name_ar,category) values
 ('verification.read','عرض طلبات توثيق الحسابات','users'),('verification.manage','مراجعة توثيق الحسابات المدفوع','users') on conflict do nothing;
insert into public.admin_role_permissions(role_id,permission_key) select r.id,p.permission_key from public.admin_roles r cross join public.admin_permissions p where r.role_key='super_admin' and p.permission_key in ('verification.read','verification.manage') on conflict do nothing;
create table if not exists public.zameel_verification_requests(
 id uuid primary key default gen_random_uuid(),user_id uuid not null references public.users(id) on delete cascade,
 payment_code text not null unique check(payment_code~'^[A-Z]{2}[0-9]{4}$'),amount_fils integer not null default 1000 check(amount_fils=1000),
 wallet_number text not null,beneficiary text not null,status text not null default 'pending' check(status in ('pending','approved','rejected')),
 created_at timestamptz not null default now(),reviewed_at timestamptz,reviewed_by uuid references public.users(id),review_note text,
 starts_at timestamptz,ends_at timestamptz);
create unique index if not exists zameel_one_pending_verification on public.zameel_verification_requests(user_id) where status='pending';
alter table public.zameel_verification_requests enable row level security;
revoke all on public.zameel_verification_requests from public,anon,authenticated;
grant select on public.zameel_verification_requests to authenticated;
grant all on public.zameel_verification_requests to service_role;
drop policy if exists verification_owner_read on public.zameel_verification_requests;
create policy verification_owner_read on public.zameel_verification_requests for select to authenticated using(user_id=auth.uid());

create or replace function public.zameel_request_verification() returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor uuid:=auth.uid(); r public.zameel_verification_requests; w public.zameel_promotion_settings; code text;
begin
 if actor is null or not coalesce(public.zameel_account_can_write(),false) then raise exception 'verification_account_unavailable';end if;
 perform 1 from public.users where id=actor for update;
 select * into r from public.zameel_verification_requests where user_id=actor and status='pending';
 if r.id is not null then return to_jsonb(r);end if;
 select * into w from public.zameel_promotion_settings where id;
 if not coalesce(w.enabled,false) or length(trim(w.wallet_number))<5 or length(trim(w.beneficiary))<2 then raise exception 'promotion_wallet_unavailable';end if;
 for attempt in 1..50 loop
 code:=chr(65+floor(random()*26)::int)||chr(65+floor(random()*26)::int)||lpad(floor(random()*10000)::int::text,4,'0');
 if exists(select 1 from public.zameel_post_promotions where payment_code=code) then continue;end if;
 begin
 insert into public.zameel_verification_requests(user_id,payment_code,wallet_number,beneficiary) values(actor,code,w.wallet_number,w.beneficiary) returning * into r;
 return to_jsonb(r);
 exception when unique_violation then null;
 end;
 end loop;
 raise exception 'payment_code_generation_failed';
end $$;

create or replace function public.zameel_review_verification(p_actor uuid,p_id uuid,p_decision text,p_code text,p_amount_fils integer,p_note text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare r public.zameel_verification_requests; expiry timestamptz; term_start timestamptz; target uuid;
begin
 if not coalesce(public.admin_has_permission('verification.manage',p_actor),false) or not coalesce(public.admin_can_access_screen('users',p_actor),false) then raise exception 'verification_review_not_authorized';end if;
 if p_decision is null or p_decision not in ('approve','reject') or length(trim(coalesce(p_note,'')))<5 then raise exception 'invalid_verification_review';end if;
 select user_id into target from public.zameel_verification_requests where id=p_id;
 perform 1 from public.users where id=target for update;
 select * into r from public.zameel_verification_requests where id=p_id for update;
 if r.id is null then raise exception 'verification_not_found';end if;
 if p_decision='approve' and (upper(trim(coalesce(p_code,'')))<>r.payment_code or p_amount_fils is distinct from 1000) then raise exception 'payment_code_or_amount_mismatch';end if;
 if r.status=(case p_decision when 'approve' then 'approved' else 'rejected' end) then return jsonb_build_object('status',r.status,'ends_at',r.ends_at);end if;
 if r.status<>'pending' then raise exception 'verification_already_decided';end if;
 if p_decision='approve' then
 if exists(select 1 from public.admin_user_states where user_id=r.user_id and status in ('blocked','suspended')) then raise exception 'verification_account_unavailable';end if;
 select greatest(now(),coalesce(verification_expires_at,now())) into term_start from public.users where id=r.user_id;
 expiry:=term_start+interval '1 month';
 update public.users set verification_expires_at=expiry where id=r.user_id;
 end if;
 update public.zameel_verification_requests set status=case p_decision when 'approve' then 'approved' else 'rejected' end,reviewed_at=now(),reviewed_by=p_actor,review_note=trim(p_note),starts_at=case when p_decision='approve' then term_start end,ends_at=expiry where id=p_id;
 insert into public.admin_audit_logs(actor_id,action,resource_type,resource_id,details) values(p_actor,'verification.'||p_decision,'verification',p_id::text,jsonb_build_object('note',p_note,'ends_at',expiry));
 insert into public.notifications(user_id,actor_id,type,title_ar,title_en,body_ar,body_en,data,is_read) values(r.user_id,p_actor,'account_verification_review','تحديث طلب توثيق الحساب','Verification request update',case when p_decision='approve' then 'تم توثيق حسابك لمدة شهر' else 'تمت مراجعة طلبك ورفضه. تواصل مع الدعم للاستفسار عن الدفع.' end,case when p_decision='approve' then 'Your account verification was approved for one month' else 'Your request was rejected. Contact support about your payment.' end,jsonb_build_object('verification_request_id',r.id,'user_id',r.user_id,'ends_at',expiry),false);
 return jsonb_build_object('status',case p_decision when 'approve' then 'approved' else 'rejected' end,'ends_at',expiry);
end $$;
revoke all on function public.zameel_request_verification(),public.zameel_review_verification(uuid,uuid,text,text,integer,text) from public,anon,authenticated;
grant execute on function public.zameel_request_verification() to authenticated;
grant execute on function public.zameel_review_verification(uuid,uuid,text,text,integer,text) to service_role;
create table if not exists public.zameel_payment_receipt_codes(code text primary key,request_type text not null,request_id uuid not null);
alter table public.zameel_payment_receipt_codes enable row level security;
revoke all on public.zameel_payment_receipt_codes from public,anon,authenticated;
grant all on public.zameel_payment_receipt_codes to service_role;
insert into public.zameel_payment_receipt_codes select payment_code,'promotion',id from public.zameel_post_promotions where payment_code is not null on conflict do nothing;
insert into public.zameel_payment_receipt_codes select payment_code,'verification',id from public.zameel_verification_requests on conflict do nothing;
create or replace function public.zameel_reserve_payment_code() returns trigger language plpgsql security definer set search_path='' as $$ begin
 if tg_op='UPDATE' and new.payment_code is not distinct from old.payment_code then return new;end if;
 if new.payment_code is not null then insert into public.zameel_payment_receipt_codes(code,request_type,request_id) values(new.payment_code,tg_table_name,new.id);end if;
 return new;
end $$;
revoke all on function public.zameel_reserve_payment_code() from public,anon,authenticated;
drop trigger if exists zameel_reserve_payment_code on public.zameel_post_promotions;
create trigger zameel_reserve_payment_code before insert or update of payment_code on public.zameel_post_promotions for each row execute function public.zameel_reserve_payment_code();
drop trigger if exists zameel_reserve_payment_code on public.zameel_verification_requests;
create trigger zameel_reserve_payment_code before insert or update of payment_code on public.zameel_verification_requests for each row execute function public.zameel_reserve_payment_code();
notify pgrst,'reload schema';
commit;
