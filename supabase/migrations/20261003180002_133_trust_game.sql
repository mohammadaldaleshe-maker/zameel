-- 133: private two-player quiz, server clocks, reserved coins and atomic settlement.
begin;
create table if not exists public.zameel_trust_settings(
 id boolean primary key default true check(id), initial_coins integer not null default 1000 check(initial_coins between 0 and 1000000),
 stake integer not null default 50 check(stake between 1 and 10000), reward_unit integer not null default 10 check(reward_unit between 1 and 1000),
 last_sweep_at timestamptz not null default now());
insert into public.zameel_trust_settings(id) values(true) on conflict do nothing;
create table if not exists public.zameel_coin_wallets(
 user_id uuid primary key references public.users(id) on delete cascade,
 balance numeric(18,1) not null check(balance>=0), created_at timestamptz not null default now());
create table if not exists public.zameel_trust_matches(
 id uuid primary key default gen_random_uuid(), player1 uuid references public.users(id) on delete set null,
 player2 uuid references public.users(id) on delete set null, check(player1<>player2),
 phase text not null default 'questions' check(phase in ('questions','decision','finished','cancelled','abandoned')),
 stake integer not null, reward_unit integer not null, prize integer not null default 0,
 round_no integer not null default 1 check(round_no between 1 and 10), deadline timestamptz not null,
 seen1 timestamptz not null default now(),seen2 timestamptz not null default now(),
 choice1 text check(choice1 in ('trust','betray')),choice2 text check(choice2 in ('trust','betray')),
 payout1 numeric(18,1),payout2 numeric(18,1),reason text,
 created_at timestamptz not null default now(),finished_at timestamptz);
create table if not exists public.zameel_trust_active(
 user_id uuid primary key references public.users(id) on delete cascade,
 match_id uuid not null references public.zameel_trust_matches(id) on delete cascade);
create table if not exists public.zameel_trust_queue(
 user_id uuid primary key references public.users(id) on delete cascade, expires_at timestamptz not null);
create table if not exists public.zameel_coin_ledger(
 id uuid primary key default gen_random_uuid(), user_id uuid not null references public.users(id) on delete cascade,
 match_id uuid references public.zameel_trust_matches(id) on delete set null,
 delta numeric(18,1) not null, balance_after numeric(18,1) not null check(balance_after>=0),
 event_key text not null unique, reason text not null, created_at timestamptz not null default now());
create index if not exists coin_ledger_user_idx on public.zameel_coin_ledger(user_id,created_at desc);
create table if not exists public.zameel_trust_rounds(
 match_id uuid not null references public.zameel_trust_matches(id) on delete cascade,
 round_no integer not null,question_id uuid,question_ar text not null,question_en text not null,
 options_ar jsonb not null,options_en jsonb not null,correct_index smallint not null,
 selected1 smallint check(selected1 between 0 and 3),selected2 smallint check(selected2 between 0 and 3),
 resolved_at timestamptz,won boolean,primary key(match_id,round_no));
create table if not exists public.zameel_trust_messages(
 id bigint generated always as identity primary key,match_id uuid not null references public.zameel_trust_matches(id) on delete cascade,
 sender_id uuid references public.users(id) on delete set null,client_id uuid not null,
 body text not null check(length(trim(body)) between 1 and 500),created_at timestamptz not null default now(),
 unique(match_id,sender_id,client_id));
create index if not exists trust_messages_match_idx on public.zameel_trust_messages(match_id,id desc);
create table if not exists public.zameel_trust_reports(
 id uuid primary key default gen_random_uuid(),match_id uuid not null references public.zameel_trust_matches(id) on delete cascade,
 reporter_id uuid references public.users(id) on delete set null,reason text not null,
 status text not null default 'open' check(status in ('open','resolved','dismissed')),
 review_note text,reviewed_by uuid references public.users(id) on delete set null,created_at timestamptz not null default now(),
 unique(match_id,reporter_id));
-- No direct client table access. In particular, answer keys, IDs and decisions are private.
do $$ declare t text; begin foreach t in array array['zameel_trust_settings','zameel_coin_wallets','zameel_coin_ledger',
 'zameel_trust_matches','zameel_trust_active','zameel_trust_queue','zameel_trust_rounds','zameel_trust_messages','zameel_trust_reports'] loop
 execute format('alter table public.%I enable row level security',t);
 execute format('revoke all on public.%I from public,anon,authenticated',t);
 execute format('grant all on public.%I to service_role',t);
 end loop; end $$;
grant usage,select on sequence public.zameel_trust_messages_id_seq to service_role;
create or replace function public.zameel_trust_require_access(p_join boolean default false)
returns uuid language plpgsql security definer set search_path='' as $$
declare me uuid:=auth.uid(); begin
 if me is null or not coalesce(public.zameel_account_can_write(),false)
 or not exists(select 1 from public.users where id=me and onboarding_complete) then raise exception 'trust_account_unavailable'; end if;
 if p_join and not exists(select 1 from public.feature_flags where feature_key='trust_game' and scope_type='global'
 and scope_value='*' and is_enabled and display_mode='enabled' and rollout_percent=100) then raise exception 'trust_temporarily_unavailable'; end if;
 return me;
end $$;
create or replace function public.zameel_coin_change(p_user uuid,p_delta numeric,p_key text,p_reason text,p_match uuid default null)
returns void language plpgsql security definer set search_path='' as $$
declare amount numeric; begin
 if exists(select 1 from public.zameel_coin_ledger where event_key=p_key) then return; end if;
 select balance into amount from public.zameel_coin_wallets where user_id=p_user for update;
 if amount is null then raise exception 'wallet_missing'; end if;
 if exists(select 1 from public.zameel_coin_ledger where event_key=p_key) then return; end if;
 if amount+p_delta<0 then raise exception 'insufficient_coins'; end if;
 update public.zameel_coin_wallets set balance=balance+p_delta where user_id=p_user returning balance into amount;
 insert into public.zameel_coin_ledger(user_id,match_id,delta,balance_after,event_key,reason)
 values(p_user,p_match,p_delta,amount,p_key,p_reason);
end $$;
create or replace function public.zameel_coin_ensure(p_user uuid)
returns void language plpgsql security definer set search_path='' as $$
declare amount integer; created uuid; begin
 select initial_coins into amount from public.zameel_trust_settings where id;
 insert into public.zameel_coin_wallets(user_id,balance) values(p_user,amount) on conflict do nothing returning user_id into created;
 if created is not null then insert into public.zameel_coin_ledger(user_id,delta,balance_after,event_key,reason)
 values(p_user,amount,amount,'initial:'||p_user::text,'initial_grant'); end if;
end $$;
create or replace function public.zameel_trust_settle(p_match uuid,p_mode text,p_loser uuid default null)
returns void language plpgsql security definer set search_path='' as $$
declare m public.zameel_trust_matches; a numeric:=0;b numeric:=0;v_phase text; begin
 select * into m from public.zameel_trust_matches where id=p_match for update;
 if m.id is null or m.phase not in ('questions','decision') then return; end if;
 if p_mode='result' then
  if m.choice1 is null or m.choice2 is null then raise exception 'decisions_incomplete'; end if;
  v_phase:='finished';
  if m.choice1='trust' and m.choice2='trust' then a:=m.stake+m.prize/2.0;b:=a;
  elsif m.choice1='betray' and m.choice2='trust' then a:=2*m.stake+m.prize;
  elsif m.choice1='trust' and m.choice2='betray' then b:=2*m.stake+m.prize; end if;
 elsif p_mode='abandoned' then
  if p_loser is null or p_loser not in (m.player1,m.player2) then raise exception 'invalid_loser'; end if;
  v_phase:='abandoned';if p_loser=m.player1 then b:=m.stake;else a:=m.stake;end if;
 elsif p_mode in ('server_outage','both_disconnected','admin_refund','account_deleted') then
  v_phase:='cancelled';a:=m.stake;b:=m.stake;
 else raise exception 'invalid_settlement';end if;
 -- Consistent wallet lock order, independent of which participant makes the call.
 perform 1 from public.zameel_coin_wallets where user_id in (m.player1,m.player2) order by user_id for update;
 if m.player1 is not null then perform public.zameel_coin_change(m.player1,a,'settle:'||m.id||':1',p_mode,m.id);end if;
 if m.player2 is not null then perform public.zameel_coin_change(m.player2,b,'settle:'||m.id||':2',p_mode,m.id);end if;
 update public.zameel_trust_matches set phase=v_phase,payout1=a,payout2=b,reason=p_mode,finished_at=now() where id=m.id;
 delete from public.zameel_trust_active where match_id=m.id;
end $$;
create or replace function public.zameel_trust_tick(p_match uuid)
returns void language plpgsql security definer set search_path='' as $$
declare m public.zameel_trust_matches; r public.zameel_trust_rounds; begin
 select * into m from public.zameel_trust_matches where id=p_match for update;
 if m.id is null or m.phase not in ('questions','decision') then return;end if;
 if m.player1 is null or m.player2 is null then perform public.zameel_trust_settle(m.id,'account_deleted');return;end if;
 if m.seen1 < now()-interval '90 seconds' and m.seen2 < now()-interval '90 seconds' then
  perform public.zameel_trust_settle(m.id,'both_disconnected');return;
 elsif m.seen1 < now()-interval '90 seconds' then perform public.zameel_trust_settle(m.id,'abandoned',m.player1);return;
 elsif m.seen2 < now()-interval '90 seconds' then perform public.zameel_trust_settle(m.id,'abandoned',m.player2);return;end if;
 if m.phase='decision' then
  if m.choice1 is not null and m.choice2 is not null then perform public.zameel_trust_settle(m.id,'result');
  elsif now()>=m.deadline then
   if m.choice1 is null and m.choice2 is null then perform public.zameel_trust_settle(m.id,'both_disconnected');
   else perform public.zameel_trust_settle(m.id,'abandoned',case when m.choice1 is null then m.player1 else m.player2 end);end if;
  end if;return;
 end if;
 select * into r from public.zameel_trust_rounds where match_id=m.id and round_no=m.round_no;
 if now()>=m.deadline or (r.selected1 is not null and r.selected1=r.selected2) then
  update public.zameel_trust_rounds set resolved_at=now(),won=(now()<m.deadline and selected1=selected2 and selected1=correct_index)
   where match_id=m.id and round_no=m.round_no returning * into r;
  update public.zameel_trust_matches set prize=prize+case when coalesce(r.won,false) then m.round_no*m.reward_unit else 0 end,
   phase=case when m.round_no=10 then 'decision' else 'questions' end,
   round_no=least(10,m.round_no+1),deadline=now()+interval '90 seconds' where id=m.id;
 end if;
end $$;
create or replace function public.zameel_trust_view(p_match uuid,p_user uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare m public.zameel_trust_matches; r public.zameel_trust_rounds; result jsonb; messages jsonb; last_round jsonb; is_one boolean;
begin
 select * into m from public.zameel_trust_matches where id=p_match;
 if m.id is null or (p_user is distinct from m.player1 and p_user is distinct from m.player2) then raise exception 'match_access_denied';end if;
 is_one:=p_user=m.player1;
 select jsonb_agg(jsonb_build_object('round_no',round_no,'won',won,'correct_index',correct_index,'options_ar',options_ar,'options_en',options_en)
 order by round_no desc) into last_round from public.zameel_trust_rounds where match_id=m.id and resolved_at is not null;
 result:=jsonb_build_object('match_id',m.id,'phase',m.phase,'round_no',m.round_no,'prize',m.prize,
 'stake',m.stake,'reward_unit',m.reward_unit,'server_now',now(),'deadline',m.deadline,
 'balance',(select balance from public.zameel_coin_wallets where user_id=p_user),
 'own_choice',case when is_one then m.choice1 else m.choice2 end,
 'opponent_decided',case when is_one then m.choice2 is not null else m.choice1 is not null end,
 'last_round',last_round->0,'reason',m.reason);
 if m.phase='questions' then
  select * into r from public.zameel_trust_rounds where match_id=m.id and round_no=m.round_no;
  result:=result||jsonb_build_object('question',jsonb_build_object('question_ar',r.question_ar,'question_en',r.question_en,
   'options_ar',r.options_ar,'options_en',r.options_en,'own_selected',case when is_one then r.selected1 else r.selected2 end,
   'opponent_selected',case when is_one then r.selected2 else r.selected1 end));
 end if;
 if m.phase in ('questions','decision') then
  select coalesce(jsonb_agg(x order by x.id),'[]'::jsonb) into messages from
   (select id,body,(sender_id=p_user) as own,created_at from public.zameel_trust_messages where match_id=m.id order by id desc limit 100) x;
  result:=result||jsonb_build_object('messages',messages);
 else
  result:=result||jsonb_build_object('own_payout',case when is_one then m.payout1 else m.payout2 end,
   'opponent_choice',case when is_one then m.choice2 else m.choice1 end,
   'opponent', (select jsonb_build_object('name',u.name,'profile_image',u.profile_image) from public.users u
    where u.id=case when is_one then m.player2 else m.player1 end));
 end if;
 return result;
end $$;
create or replace function public.zameel_trust_sweep()
returns void language plpgsql security definer set search_path='' as $$
declare last_at timestamptz; m record; begin
 -- A missed server scheduler window cancels affected matches and returns stakes.
 select last_sweep_at into last_at from public.zameel_trust_settings where id for update;
 for m in select id,created_at from public.zameel_trust_matches where phase in ('questions','decision') order by id loop
  if not exists(select 1 from public.feature_flags where feature_key='trust_game' and is_enabled and display_mode='enabled') then
   perform public.zameel_trust_settle(m.id,'admin_refund');
  elsif now()-last_at>interval '150 seconds' and m.created_at<=last_at then
   perform public.zameel_trust_settle(m.id,'server_outage');
  else perform public.zameel_trust_tick(m.id);end if;
 end loop;
 update public.zameel_trust_settings set last_sweep_at=now() where id;
 delete from public.zameel_trust_queue where expires_at<now();
 delete from public.zameel_trust_messages where created_at<now()-interval '30 days';
end $$;
create or replace function public.zameel_trust_state(p_match uuid default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare me uuid:=public.zameel_trust_require_access(); mid uuid; begin
 -- Sweep first so reconnecting after the grace period cannot erase an expired loss.
 mid:=p_match;
 if mid is null then select match_id into mid from public.zameel_trust_active where user_id=me;end if;
 perform public.zameel_trust_sweep();perform public.zameel_coin_ensure(me);
 if mid is not null then
  if not exists(select 1 from public.zameel_trust_matches where id=mid and me in(player1,player2)) then raise exception 'match_access_denied';end if;
  update public.zameel_trust_matches set seen1=case when player1=me then now() else seen1 end,
   seen2=case when player2=me then now() else seen2 end where id=mid and phase in ('questions','decision');
  return public.zameel_trust_view(mid,me);
 end if;
 update public.zameel_trust_queue set expires_at=now()+interval '30 seconds' where user_id=me;
 return jsonb_build_object('phase',case when exists(select 1 from public.zameel_trust_queue where user_id=me) then 'waiting' else 'lobby' end,
 'balance',(select balance from public.zameel_coin_wallets where user_id=me),
 'stake',(select stake from public.zameel_trust_settings where id),'reward_unit',(select reward_unit from public.zameel_trust_settings where id));
end $$;
create or replace function public.zameel_trust_join()
returns jsonb language plpgsql security definer set search_path='' as $$
declare me uuid:=public.zameel_trust_require_access(true); other uuid;mid uuid;cfg public.zameel_trust_settings;
 questions jsonb;item jsonb;n integer:=0;
begin
 perform pg_catalog.pg_advisory_xact_lock(133,1);perform public.zameel_trust_sweep();
 select match_id into mid from public.zameel_trust_active where user_id=me;
 if mid is not null then return public.zameel_trust_view(mid,me);end if;
 select * into cfg from public.zameel_trust_settings where id;
 perform public.zameel_coin_ensure(me);
 if (select balance from public.zameel_coin_wallets where user_id=me)<cfg.stake then raise exception 'insufficient_coins';end if;
 select q.user_id into other from public.zameel_trust_queue q join public.zameel_coin_wallets w on w.user_id=q.user_id
 where q.user_id<>me and q.expires_at>now() and w.balance>=cfg.stake
 and not public.is_blocked(me,q.user_id)
 and not exists(select 1 from public.zameel_trust_active a where a.user_id=q.user_id)
 and not exists(select 1 from public.admin_user_states s where s.user_id=q.user_id and
  (s.status='blocked' or s.status='suspended' and (s.suspended_until is null or s.suspended_until>now())))
 order by random() limit 1;
 if other is null then
  insert into public.zameel_trust_queue(user_id,expires_at) values(me,now()+interval '30 seconds')
   on conflict(user_id) do update set expires_at=excluded.expires_at;
  return public.zameel_trust_state(null);
 end if;
 select jsonb_agg(x) into questions from(select id,question_ar,question_en,options_ar,options_en,correct_index
 from public.zameel_quiz_questions where status='published' order by random() limit 10) x;
 if coalesce(jsonb_array_length(questions),0)<>10 then raise exception 'ten_published_questions_required';end if;
 perform 1 from public.zameel_coin_wallets where user_id in (me,other) order by user_id for update;
 insert into public.zameel_trust_matches(player1,player2,stake,reward_unit,deadline)
 values(other,me,cfg.stake,cfg.reward_unit,now()+interval '90 seconds') returning id into mid;
 insert into public.zameel_trust_active(user_id,match_id) values(me,mid),(other,mid);
 for item in select value from jsonb_array_elements(questions) loop n:=n+1;
  insert into public.zameel_trust_rounds(match_id,round_no,question_id,question_ar,question_en,options_ar,options_en,correct_index)
  values(mid,n,(item->>'id')::uuid,item->>'question_ar',item->>'question_en',item->'options_ar',item->'options_en',(item->>'correct_index')::smallint);
 end loop;
 perform public.zameel_coin_change(other,-cfg.stake,'stake:'||mid||':1','match_stake',mid);
 perform public.zameel_coin_change(me,-cfg.stake,'stake:'||mid||':2','match_stake',mid);
 delete from public.zameel_trust_queue where user_id in(me,other);
 return public.zameel_trust_view(mid,me);
end $$;
create or replace function public.zameel_trust_answer(p_match uuid,p_round integer,p_selected integer)
returns jsonb language plpgsql security definer set search_path='' as $$
declare me uuid:=public.zameel_trust_require_access();m public.zameel_trust_matches; begin
 perform public.zameel_trust_sweep();
 select * into m from public.zameel_trust_matches where id=p_match for update;
 if m.id is null or (me is distinct from m.player1 and me is distinct from m.player2) then raise exception 'match_access_denied';end if;
 if p_selected is null or p_selected not between 0 and 3 then raise exception 'invalid_selection';end if;
 if m.phase='questions' and m.round_no=p_round and now()<m.deadline then
  update public.zameel_trust_rounds set selected1=case when me=m.player1 then p_selected else selected1 end,
   selected2=case when me=m.player2 then p_selected else selected2 end where match_id=m.id and round_no=p_round;
  perform public.zameel_trust_tick(m.id);
 end if;
 return public.zameel_trust_state(m.id);
end $$;
create or replace function public.zameel_trust_decide(p_match uuid,p_choice text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare me uuid:=public.zameel_trust_require_access();m public.zameel_trust_matches; begin
 perform public.zameel_trust_sweep();select * into m from public.zameel_trust_matches where id=p_match for update;
 if m.id is null or (me is distinct from m.player1 and me is distinct from m.player2) then raise exception 'match_access_denied';end if;
 if p_choice is null or p_choice not in ('trust','betray') then raise exception 'invalid_decision';end if;
 if m.phase='decision' and now()<m.deadline then
  if me=m.player1 and m.choice1 is null then update public.zameel_trust_matches set choice1=p_choice where id=m.id;
  elsif me=m.player2 and m.choice2 is null then update public.zameel_trust_matches set choice2=p_choice where id=m.id;end if;
  perform public.zameel_trust_tick(m.id);
 end if;
 return public.zameel_trust_state(m.id);
end $$;
create or replace function public.zameel_trust_leave(p_match uuid default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare me uuid:=public.zameel_trust_require_access();mid uuid; begin
 delete from public.zameel_trust_queue where user_id=me;
 mid:=p_match;if mid is null then select match_id into mid from public.zameel_trust_active where user_id=me;end if;
 if mid is not null then
  if not exists(select 1 from public.zameel_trust_matches where id=mid and me in(player1,player2)) then raise exception 'match_access_denied';end if;
  perform public.zameel_trust_settle(mid,'abandoned',me);return public.zameel_trust_view(mid,me);
 end if;
 return public.zameel_trust_state(null);
end $$;
create or replace function public.zameel_trust_chat(p_match uuid,p_body text,p_client_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare me uuid:=public.zameel_trust_require_access();m public.zameel_trust_matches; begin
 perform public.zameel_trust_sweep();select * into m from public.zameel_trust_matches where id=p_match for update;
 if m.id is null or (me is distinct from m.player1 and me is distinct from m.player2) then raise exception 'match_access_denied';end if;
 if m.phase not in ('questions','decision') then raise exception 'match_chat_closed';end if;
 if p_client_id is null or p_body is null or length(trim(p_body)) not between 1 and 500 then raise exception 'invalid_message';end if;
 if exists(select 1 from public.zameel_trust_messages where match_id=m.id and sender_id=me and client_id=p_client_id) then return public.zameel_trust_state(m.id);end if;
 if (select count(*) from public.zameel_trust_messages where match_id=m.id and sender_id=me and created_at>now()-interval '10 seconds')>=5 then raise exception 'chat_rate_limit';end if;
 insert into public.zameel_trust_messages(match_id,sender_id,client_id,body) values(m.id,me,p_client_id,trim(p_body));
 return public.zameel_trust_state(m.id);
end $$;
create or replace function public.zameel_trust_report(p_match uuid,p_reason text)
returns void language plpgsql security definer set search_path='' as $$
declare me uuid:=public.zameel_trust_require_access();begin
 if not exists(select 1 from public.zameel_trust_matches where id=p_match and me in(player1,player2)) then raise exception 'match_access_denied';end if;
 if p_reason is null or length(trim(p_reason)) not between 5 and 1000 then raise exception 'invalid_report';end if;
 insert into public.zameel_trust_reports(match_id,reporter_id,reason) values(p_match,me,trim(p_reason)) on conflict(match_id,reporter_id) do nothing;
end $$;
create or replace function public.zameel_coin_history()
returns jsonb language plpgsql security definer set search_path='' as $$
declare me uuid:=public.zameel_trust_require_access(); result jsonb;begin
 select coalesce(jsonb_agg(x order by x.created_at desc),'[]'::jsonb) into result from
 (select delta,balance_after,reason,created_at from public.zameel_coin_ledger where user_id=me order by created_at desc limit 100)x;
 return result;
end $$;
-- Deny all helper execution; expose only authenticated, participant-checked RPCs.
do $$ declare f record; begin for f in select oid::regprocedure as signature from pg_proc
 where pronamespace='public'::regnamespace and (proname like 'zameel_trust_%' or proname like 'zameel_coin_%') loop
 execute format('revoke all on function %s from public,anon,authenticated',f.signature);
 end loop;end $$;
grant execute on function public.zameel_trust_join(),public.zameel_trust_state(uuid),public.zameel_trust_answer(uuid,integer,integer),
 public.zameel_trust_decide(uuid,text),public.zameel_trust_leave(uuid),public.zameel_trust_chat(uuid,text,uuid),
 public.zameel_trust_report(uuid,text),public.zameel_coin_history() to authenticated;
grant execute on function public.zameel_trust_sweep() to service_role;
insert into public.feature_flags(feature_key,name_ar,description,is_enabled,display_mode,rollout_percent,scope_type,scope_value)
 values('trust_game','ثقة أم غدر','لعبة ثنائية بعملة زميل الافتراضية',true,'enabled',100,'global','*') on conflict(feature_key) do nothing;
commit;
