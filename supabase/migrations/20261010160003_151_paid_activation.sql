begin;
-- Called only after fresh Google validation and completed consumption.
create or replace function public.zameel_play_activate(p_token text) returns void language plpgsql security definer set search_path='' as $$
declare i public.zameel_play_payment_intents;l public.zameel_play_purchase_ledger;v public.zameel_verification_requests;p public.zameel_post_promotions;term_start timestamptz;begin
 select x.* into i from public.zameel_play_payment_intents x join public.zameel_play_purchase_ledger y on y.intent_id=x.id where y.token_sha256=p_token;
 if not found or i.user_id is null then raise exception 'payment_intent_missing';end if;
 if i.kind='verification' then
  perform 1 from public.users where id=i.user_id for update;
  select * into v from public.zameel_verification_requests where id=i.request_id for update;
  if not found or v.user_id<>i.user_id or v.payment_source<>'google_play' then raise exception 'payment_request_mismatch';end if;
 else
  select * into p from public.zameel_post_promotions where id=i.request_id;
  if not found then raise exception 'payment_request_missing';end if;
  perform 1 from public.posts where id=p.post_id for update;
  select * into p from public.zameel_post_promotions where id=i.request_id for update;
  if p.owner_id<>i.user_id or p.payment_source<>'google_play' then raise exception 'payment_request_mismatch';end if;
 end if;
 select * into i from public.zameel_play_payment_intents where id=i.id for update;
 select * into l from public.zameel_play_purchase_ledger where token_sha256=p_token for update;
 if l.settlement_state='approved' then return;end if;
 if i.state<>'paid' or l.settlement_state<>'awaiting_review' or l.acknowledgement_state<>'completed' then raise exception 'payment_confirmation_required';end if;
 if exists(select 1 from public.admin_user_states where user_id=i.user_id and status in ('blocked','suspended')) or
 (i.kind='verification' and v.status<>'pending') or (i.kind='promotion' and (not exists(select 1 from public.feature_flags where feature_key='post_promotions' and scope_type='global' and scope_value='*' and is_enabled and display_mode='enabled' and rollout_percent=100) or p.status<>'pending' or not exists(select 1 from public.posts where id=p.post_id and user_id=i.user_id and audience='public' and not coalesce(is_hidden,false)))) then
  update public.zameel_play_purchase_ledger set settlement_state='refund_required' where token_sha256=p_token;return;
 end if;
 if i.kind='verification' then
  select greatest(now(),coalesce(verification_expires_at,now())) into term_start from public.users where id=i.user_id;
  update public.users set verification_expires_at=term_start+interval '1 month' where id=i.user_id;
  update public.zameel_verification_requests set status='approved',starts_at=term_start,ends_at=term_start+interval '1 month',reviewed_at=now(),reviewed_by=null,review_note='Google Play payment confirmed automatically' where id=i.request_id;
 else
  update public.zameel_post_promotions set status='approved',starts_at=now(),ends_at=now()+make_interval(days=>p.days),payment_verified_at=now(),updated_at=now(),reviewed_by=null,review_note='Google Play payment confirmed automatically' where id=i.request_id;
 end if;
 insert into public.notifications(user_id,type,title_ar,title_en,body_ar,body_en,data,is_read) values(i.user_id,case when i.kind='verification' then 'account_verification_review' else 'post_promotion_approved' end,'تم تفعيل طلبك','Purchase activated','تم تأكيد الدفع عبر Google Play وتفعيل طلبك تلقائيًا.','Google Play payment confirmed. Your purchase is active.',jsonb_build_object('request_id',i.request_id,'kind',i.kind)||case when i.kind='promotion' then jsonb_build_object('post_id',p.post_id) else jsonb_build_object('verification_request_id',i.request_id,'user_id',i.user_id) end,false);
end $$;
revoke all on function public.zameel_play_activate(text) from public,anon,authenticated;
grant execute on function public.zameel_play_activate(text) to service_role;
create table if not exists public.zameel_play_finance(
 intent_id uuid primary key references public.zameel_play_payment_intents(id) on delete cascade,
 order_id text not null,currency text not null check(currency~'^[A-Z]{3}$'),
 gross numeric(20,9) not null check(gross>=0),tax numeric(20,9) not null check(tax>=0),developer_revenue numeric(20,9) not null check(developer_revenue>=0),checked_at timestamptz not null default now());
alter table public.zameel_play_finance enable row level security;
revoke all on public.zameel_play_finance from public,anon,authenticated;
grant all on public.zameel_play_finance to service_role;
create or replace function public.zameel_play_revenue(p_kind text,p_offset integer default 0) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare result jsonb;begin
 if p_kind not in ('promotion','verification') or p_kind is null or p_offset<0 or p_offset>100000 then raise exception 'invalid_revenue_filter';end if;
 select jsonb_build_object('rows',coalesce((select jsonb_agg(v) from (
 select i.id,i.request_id,i.user_id,u.name,u.email,l.order_id,l.is_test,l.purchased_at,l.settlement_state,f.currency,f.gross,f.tax,f.developer_revenue,f.checked_at
 from public.zameel_play_payment_intents i join public.zameel_play_purchase_ledger l on l.intent_id=i.id left join public.users u on u.id=i.user_id left join public.zameel_play_finance f on f.intent_id=i.id
 where i.kind=p_kind order by l.purchased_at desc,i.id limit 100 offset p_offset) v),'[]'::jsonb),
 'totals',coalesce((select jsonb_agg(t) from(select f.currency,sum(f.gross) gross,sum(f.tax) tax,sum(f.developer_revenue) developer_revenue,count(*) orders
 from public.zameel_play_finance f join public.zameel_play_payment_intents i on i.id=f.intent_id join public.zameel_play_purchase_ledger l on l.intent_id=i.id
 where i.kind=p_kind and not l.is_test and l.settlement_state='approved' group by f.currency)t),'[]'::jsonb),
 'pending_finance',(select count(*) from public.zameel_play_payment_intents i join public.zameel_play_purchase_ledger l on l.intent_id=i.id left join public.zameel_play_finance f on f.intent_id=i.id where i.kind=p_kind and not l.is_test and l.settlement_state='approved' and f.intent_id is null)) into result;
 return result;
end $$;
revoke all on function public.zameel_play_revenue(text,integer) from public,anon,authenticated;
grant execute on function public.zameel_play_revenue(text,integer) to service_role;
notify pgrst,'reload schema';
commit;
