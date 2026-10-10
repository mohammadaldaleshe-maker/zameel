begin;
create or replace function public.zameel_trust_start_bot()
returns jsonb language plpgsql security definer set search_path='' as $$
declare me uuid:=public.zameel_trust_require_access(true);mid uuid;cfg public.zameel_trust_settings;item jsonb;n integer:=0;begin
 perform pg_advisory_xact_lock(133,1);
 select match_id into mid from public.zameel_trust_active where user_id=me;
 if mid is not null then return public.zameel_trust_view(mid,me);end if;
 if not exists(select 1 from public.zameel_trust_queue where user_id=me and queued_at<=now()-interval '15 seconds' and expires_at>now()) then raise exception 'match_search_not_ready';end if;
 if exists(select 1 from public.zameel_trust_queue q join public.zameel_coin_wallets w on w.user_id=q.user_id where q.user_id<>me and q.expires_at>now() and w.balance>=(select stake from public.zameel_trust_settings where id) and not public.is_blocked(me,q.user_id) and not exists(select 1 from public.zameel_trust_active a where a.user_id=q.user_id) and not exists(select 1 from public.admin_user_states s where s.user_id=q.user_id and (s.status='blocked' or s.status='suspended' and (s.suspended_until is null or s.suspended_until>now())))) then return public.zameel_trust_join();end if;
 select * into cfg from public.zameel_trust_settings where id;perform public.zameel_coin_ensure(me);
 if (select balance from public.zameel_coin_wallets where user_id=me)<cfg.stake then raise exception 'insufficient_coins';end if;
 if (select count(*) from public.zameel_trust_questions)<10 then raise exception 'ten_published_questions_required';end if;
 insert into public.zameel_trust_matches(player1,player2,is_bot,stake,reward_unit,deadline)
 values(me,null,true,cfg.stake,cfg.reward_unit,now()+interval '90 seconds') returning id into mid;
 insert into public.zameel_trust_active(user_id,match_id) values(me,mid);
 for item in select to_jsonb(q) from (select * from public.zameel_trust_questions order by random() limit 10) q loop
 n:=n+1;insert into public.zameel_trust_rounds(match_id,round_no,question_id,question_ar,question_en,options_ar,options_en,correct_index,selected2)
 values(mid,n,(item->>'id')::uuid,item->>'question_ar',item->>'question_en',item->'options_ar',item->'options_en',(item->>'correct_index')::smallint,null);
 end loop;
 perform public.zameel_coin_change(me,-cfg.stake,'stake:'||mid||':1','match_stake',mid);
 delete from public.zameel_trust_queue where user_id=me;
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
  if m.is_bot then update public.zameel_trust_rounds set selected2=selected1 where match_id=m.id and round_no=p_round and selected1 is not null;end if;
  perform public.zameel_trust_tick(m.id);
 end if;
 return public.zameel_trust_state(m.id);
end $$;
update public.zameel_trust_rounds r set selected2=null from public.zameel_trust_matches m where m.id=r.match_id and m.is_bot and m.phase='questions' and r.resolved_at is null and r.selected1 is null;
revoke all on function public.zameel_trust_start_bot() from public,anon;
grant execute on function public.zameel_trust_start_bot() to authenticated;
notify pgrst,'reload schema';
commit;
