-- 138: independent easy Jordan pool and a disclosed server-controlled bot.
begin;
alter table public.zameel_trust_matches add column if not exists is_bot boolean not null default false;
alter table public.zameel_trust_queue add column if not exists queued_at timestamptz not null default now();
create table if not exists public.zameel_trust_questions(
 id uuid primary key default gen_random_uuid(),question_ar text not null unique,question_en text not null,
 options_ar jsonb not null,options_en jsonb not null,correct_index smallint not null check(correct_index between 0 and 3),source_url text not null);
alter table public.zameel_trust_questions enable row level security;
revoke all on public.zameel_trust_questions from anon,authenticated;
insert into public.zameel_trust_questions(question_ar,question_en,options_ar,options_en,correct_index,source_url) values('ما عاصمة الأردن؟','What is the capital of Jordan?','["عمّان", "إربد", "العقبة", "الزرقاء"]','["Amman", "Irbid", "Aqaba", "Zarqa"]',0,'https://en.visitjordan.com/uploads/brochures/familyenglish2022.pdf') on conflict(question_ar) do nothing;
insert into public.zameel_trust_questions(question_ar,question_en,options_ar,options_en,correct_index,source_url) values('في أي دولة تقع البتراء؟','In which country is Petra?','["العراق", "الأردن", "مصر", "لبنان"]','["Iraq", "Jordan", "Egypt", "Lebanon"]',1,'https://en.visitjordan.com/uploads/brochures/familyenglish2022.pdf') on conflict(question_ar) do nothing;
insert into public.zameel_trust_questions(question_ar,question_en,options_ar,options_en,correct_index,source_url) values('أي مدينة أردنية تقع على البحر الأحمر؟','Which Jordanian city is on the Red Sea?','["إربد", "السلط", "العقبة", "عمّان"]','["Irbid", "Salt", "Aqaba", "Amman"]',2,'https://en.visitjordan.com/uploads/brochures/familyenglish2022.pdf') on conflict(question_ar) do nothing;
insert into public.zameel_trust_questions(question_ar,question_en,options_ar,options_en,correct_index,source_url) values('أي مدينة تُعرف بالمدينة الوردية؟','Which city is known as the Rose City?','["الزرقاء", "الرمثا", "المفرق", "البتراء"]','["Zarqa", "Ramtha", "Mafraq", "Petra"]',3,'https://en.visitjordan.com/uploads/brochures/familyenglish2022.pdf') on conflict(question_ar) do nothing;
insert into public.zameel_trust_questions(question_ar,question_en,options_ar,options_en,correct_index,source_url) values('أي من هذه المعالم يقع في الأردن؟','Which landmark is in Jordan?','["وادي رم", "برج إيفل", "سور الصين", "برج بيزا"]','["Wadi Rum", "Eiffel Tower", "Great Wall of China", "Leaning Tower of Pisa"]',0,'https://en.visitjordan.com/uploads/brochures/familyenglish2022.pdf') on conflict(question_ar) do nothing;
insert into public.zameel_trust_questions(question_ar,question_en,options_ar,options_en,correct_index,source_url) values('أي مدينة أردنية تضم المدرج الروماني الشهير في وسطها؟','Which Jordanian city has the famous downtown Roman Theatre?','["الطفيلة", "عمّان", "العقبة", "المفرق"]','["Tafilah", "Amman", "Aqaba", "Mafraq"]',1,'https://en.visitjordan.com/uploads/brochures/familyenglish2022.pdf') on conflict(question_ar) do nothing;
insert into public.zameel_trust_questions(question_ar,question_en,options_ar,options_en,correct_index,source_url) values('ما اسم البحر المعروف بملوحته العالية في الأردن؟','Which sea in Jordan is known for high salinity?','["بحر البلطيق", "بحر العرب", "البحر الميت", "البحر الأسود"]','["Baltic Sea", "Arabian Sea", "Dead Sea", "Black Sea"]',2,'https://en.visitjordan.com/uploads/brochures/familyenglish2022.pdf') on conflict(question_ar) do nothing;
insert into public.zameel_trust_questions(question_ar,question_en,options_ar,options_en,correct_index,source_url) values('في أي دولة تقع مدينة إربد؟','In which country is Irbid?','["المغرب", "تونس", "مصر", "الأردن"]','["Morocco", "Tunisia", "Egypt", "Jordan"]',3,'https://en.visitjordan.com/uploads/brochures/familyenglish2022.pdf') on conflict(question_ar) do nothing;
insert into public.zameel_trust_questions(question_ar,question_en,options_ar,options_en,correct_index,source_url) values('في أي دولة تقع مدينة الزرقاء؟','In which country is Zarqa?','["الأردن", "لبنان", "ليبيا", "الجزائر"]','["Jordan", "Lebanon", "Libya", "Algeria"]',0,'https://en.visitjordan.com/uploads/brochures/familyenglish2022.pdf') on conflict(question_ar) do nothing;
insert into public.zameel_trust_questions(question_ar,question_en,options_ar,options_en,correct_index,source_url) values('في أي دولة تقع مدينة السلط؟','In which country is Salt?','["العراق", "الأردن", "مصر", "تونس"]','["Iraq", "Jordan", "Egypt", "Tunisia"]',1,'https://en.visitjordan.com/uploads/brochures/familyenglish2022.pdf') on conflict(question_ar) do nothing;
insert into public.zameel_trust_questions(question_ar,question_en,options_ar,options_en,correct_index,source_url) values('في أي دولة تقع مدينة مادبا؟','In which country is Madaba?','["قطر", "عُمان", "الأردن", "الكويت"]','["Qatar", "Oman", "Jordan", "Kuwait"]',2,'https://en.visitjordan.com/uploads/brochures/familyenglish2022.pdf') on conflict(question_ar) do nothing;
insert into public.zameel_trust_questions(question_ar,question_en,options_ar,options_en,correct_index,source_url) values('أي من هذه المدن أردنية؟','Which of these cities is Jordanian?','["باريس", "روما", "لندن", "جرش"]','["Paris", "Rome", "London", "Jerash"]',3,'https://en.visitjordan.com/uploads/brochures/familyenglish2022.pdf') on conflict(question_ar) do nothing;
insert into public.zameel_trust_questions(question_ar,question_en,options_ar,options_en,correct_index,source_url) values('أي مدينة أردنية تشتهر بقلعتها؟','Which Jordanian city is famous for its castle?','["عجلون", "مدريد", "برلين", "أثينا"]','["Ajloun", "Madrid", "Berlin", "Athens"]',0,'https://en.visitjordan.com/uploads/brochures/familyenglish2022.pdf') on conflict(question_ar) do nothing;
insert into public.zameel_trust_questions(question_ar,question_en,options_ar,options_en,correct_index,source_url) values('أي من هذه المدن تقع في الأردن؟','Which of these cities is located in Jordan?','["سيول", "الكرك", "طوكيو", "بكين"]','["Seoul", "Karak", "Tokyo", "Beijing"]',1,'https://en.visitjordan.com/uploads/brochures/familyenglish2022.pdf') on conflict(question_ar) do nothing;
insert into public.zameel_trust_questions(question_ar,question_en,options_ar,options_en,correct_index,source_url) values('في أي دولة تقع أم قيس؟','In which country is Umm Qais?','["فرنسا", "إسبانيا", "الأردن", "إيطاليا"]','["France", "Spain", "Jordan", "Italy"]',2,'https://en.visitjordan.com/uploads/brochures/familyenglish2022.pdf') on conflict(question_ar) do nothing;
insert into public.zameel_trust_questions(question_ar,question_en,options_ar,options_en,correct_index,source_url) values('أي وادٍ أردني يشتهر بالسياحة الصحراوية؟','Which Jordanian valley is famous for desert tourism?','["وادي اللوار", "وادي الراين", "وادي النيل", "وادي رم"]','["Loire Valley", "Rhine Valley", "Nile Valley", "Wadi Rum"]',3,'https://en.visitjordan.com/uploads/brochures/familyenglish2022.pdf') on conflict(question_ar) do nothing;
insert into public.zameel_trust_questions(question_ar,question_en,options_ar,options_en,correct_index,source_url) values('ما المدينة الأردنية التي تضم ميناءً على البحر الأحمر؟','Which Jordanian city has a Red Sea port?','["العقبة", "إربد", "جرش", "عجلون"]','["Aqaba", "Irbid", "Jerash", "Ajloun"]',0,'https://en.visitjordan.com/uploads/brochures/familyenglish2022.pdf') on conflict(question_ar) do nothing;
insert into public.zameel_trust_questions(question_ar,question_en,options_ar,options_en,correct_index,source_url) values('أي من هذه المدن هي عاصمة الأردن؟','Which city is Jordan’s capital?','["بغداد", "عمّان", "القاهرة", "بيروت"]','["Baghdad", "Amman", "Cairo", "Beirut"]',1,'https://en.visitjordan.com/uploads/brochures/familyenglish2022.pdf') on conflict(question_ar) do nothing;
insert into public.zameel_trust_questions(question_ar,question_en,options_ar,options_en,correct_index,source_url) values('ما اسم النهر الذي يحمل اسم الأردن؟','Which river shares Jordan’s name?','["نهر الأمازون", "نهر السين", "نهر الأردن", "نهر النيل"]','["Amazon", "Seine", "Jordan River", "Nile"]',2,'https://en.visitjordan.com/uploads/brochures/familyenglish2022.pdf') on conflict(question_ar) do nothing;
insert into public.zameel_trust_questions(question_ar,question_en,options_ar,options_en,correct_index,source_url) values('أي من هذه المواقع الأردنية مدينة أثرية؟','Which Jordanian site is an ancient city?','["برج إيفل", "تمثال الحرية", "ساعة بيغ بن", "البتراء"]','["Eiffel Tower", "Statue of Liberty", "Big Ben", "Petra"]',3,'https://en.visitjordan.com/uploads/brochures/familyenglish2022.pdf') on conflict(question_ar) do nothing;
insert into public.zameel_trust_questions(question_ar,question_en,options_ar,options_en,correct_index,source_url) values('أين تقع مدينة معان؟','In which country is Maan?','["الأردن", "المغرب", "تونس", "الجزائر"]','["Jordan", "Morocco", "Tunisia", "Algeria"]',0,'https://en.visitjordan.com/uploads/brochures/familyenglish2022.pdf') on conflict(question_ar) do nothing;
insert into public.zameel_trust_questions(question_ar,question_en,options_ar,options_en,correct_index,source_url) values('في أي دولة تقع الطفيلة؟','In which country is Tafilah?','["السودان", "الأردن", "لبنان", "مصر"]','["Sudan", "Jordan", "Lebanon", "Egypt"]',1,'https://en.visitjordan.com/uploads/brochures/familyenglish2022.pdf') on conflict(question_ar) do nothing;
insert into public.zameel_trust_questions(question_ar,question_en,options_ar,options_en,correct_index,source_url) values('أي مدينة أردنية اسمها موجود في اسم قلعة الكرك؟','Which Jordanian city shares the name of Karak Castle?','["الزرقاء", "المفرق", "الكرك", "عمّان"]','["Zarqa", "Mafraq", "Karak", "Amman"]',2,'https://en.visitjordan.com/uploads/brochures/familyenglish2022.pdf') on conflict(question_ar) do nothing;
insert into public.zameel_trust_questions(question_ar,question_en,options_ar,options_en,correct_index,source_url) values('أي مدينة أردنية اسمها موجود في اسم قلعة عجلون؟','Which Jordanian city shares the name of Ajloun Castle?','["العقبة", "معان", "الرمثا", "عجلون"]','["Aqaba", "Maan", "Ramtha", "Ajloun"]',3,'https://en.visitjordan.com/uploads/brochures/familyenglish2022.pdf') on conflict(question_ar) do nothing;
insert into public.zameel_trust_questions(question_ar,question_en,options_ar,options_en,correct_index,source_url) values('أي من هذه الأماكن وجهة سياحية في الأردن؟','Which is a tourist destination in Jordan?','["البحر الميت", "جبال الألب", "جزر المالديف", "شلالات نياغرا"]','["Dead Sea", "Alps", "Maldives", "Niagara Falls"]',0,'https://en.visitjordan.com/uploads/brochures/familyenglish2022.pdf') on conflict(question_ar) do nothing;
insert into public.zameel_trust_questions(question_ar,question_en,options_ar,options_en,correct_index,source_url) values('أي مدينة أردنية تقع على خليج العقبة؟','Which Jordanian city is on the Gulf of Aqaba?','["إربد", "العقبة", "السلط", "مادبا"]','["Irbid", "Aqaba", "Salt", "Madaba"]',1,'https://en.visitjordan.com/uploads/brochures/familyenglish2022.pdf') on conflict(question_ar) do nothing;
insert into public.zameel_trust_questions(question_ar,question_en,options_ar,options_en,correct_index,source_url) values('في أي دولة تقع مدينة المفرق؟','In which country is Mafraq?','["اليمن", "ليبيا", "الأردن", "مصر"]','["Yemen", "Libya", "Jordan", "Egypt"]',2,'https://en.visitjordan.com/uploads/brochures/familyenglish2022.pdf') on conflict(question_ar) do nothing;
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
   on conflict(user_id) do update set queued_at=case when public.zameel_trust_queue.expires_at<now() then now() else public.zameel_trust_queue.queued_at end,expires_at=excluded.expires_at;
  return public.zameel_trust_state(null);
 end if;
 select jsonb_agg(x) into questions from(select id,question_ar,question_en,options_ar,options_en,correct_index
 from public.zameel_trust_questions order by random() limit 10) x;
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
 values(mid,n,(item->>'id')::uuid,item->>'question_ar',item->>'question_en',item->'options_ar',item->'options_en',(item->>'correct_index')::smallint,floor(random()*4)::smallint);
 end loop;
 perform public.zameel_coin_change(me,-cfg.stake,'stake:'||mid||':1','match_stake',mid);
 delete from public.zameel_trust_queue where user_id=me;
 return public.zameel_trust_view(mid,me);
end $$;
revoke all on function public.zameel_trust_start_bot() from public,anon,authenticated;
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
 if exists(select 1 from public.zameel_trust_queue where user_id=me and expires_at>now() and queued_at<=now()-interval '15 seconds') then return public.zameel_trust_start_bot();end if;
 update public.zameel_trust_queue set expires_at=now()+interval '30 seconds' where user_id=me;
 return jsonb_build_object('phase',case when exists(select 1 from public.zameel_trust_queue where user_id=me) then 'waiting' else 'lobby' end,
 'balance',(select balance from public.zameel_coin_wallets where user_id=me),
 'stake',(select stake from public.zameel_trust_settings where id),'reward_unit',(select reward_unit from public.zameel_trust_settings where id));
end $$;
create or replace function public.zameel_trust_tick(p_match uuid)
returns void language plpgsql security definer set search_path='' as $$
declare m public.zameel_trust_matches; r public.zameel_trust_rounds; begin
 select * into m from public.zameel_trust_matches where id=p_match for update;
 if m.id is null or m.phase not in ('questions','decision') then return;end if;
 if m.player1 is null or (m.player2 is null and not m.is_bot) then perform public.zameel_trust_settle(m.id,'account_deleted');return;end if;
 if m.is_bot then
  update public.zameel_trust_matches set seen2=now(),choice2=case when phase='decision' and choice2 is null then case when random()<0.5 then 'trust' else 'betray' end else choice2 end where id=m.id returning * into m;
 end if;
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
 'is_bot',m.is_bot,'opponent_name',case when m.is_bot then 'زميل' else null end,'stake',m.stake,'reward_unit',m.reward_unit,'server_now',now(),'deadline',m.deadline,
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
   'opponent', case when m.is_bot then jsonb_build_object('name','زميل','is_bot',true) else (select jsonb_build_object('id',u.id,'name',u.name,'profile_image',u.profile_image) from public.users u
    where u.id=case when is_one then m.player2 else m.player1 end) end);
 end if;
 return result;
end $$;
notify pgrst,'reload schema';
commit;
