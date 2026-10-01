-- Read-only installation checks. This does not publish questions or enable Quiz.
do $$
declare name text;
begin
 foreach name in array array['zameel_quiz_questions','zameel_quiz_players','zameel_quiz_attempts','zameel_quiz_reports','zameel_shorts_preferences','zameel_shorts_sessions'] loop
  if to_regclass('public.'||name) is null then raise exception '132_table_missing: %',name; end if;
  if not (select relrowsecurity from pg_class where oid=to_regclass('public.'||name)) then raise exception '132_rls_missing: %',name; end if;
  if has_table_privilege('authenticated','public.'||name,'SELECT') or has_table_privilege('anon','public.'||name,'SELECT') then raise exception '132_private_table_leak: %',name; end if;
 end loop;
 foreach name in array array['public.zameel_quiz_next()','public.zameel_quiz_answer(uuid,integer)','public.zameel_quiz_leaderboard()','public.zameel_quiz_report(uuid,text)','public.zameel_shorts_feed(uuid,uuid[],integer,boolean)','public.zameel_shorts_start(uuid)','public.zameel_shorts_view(uuid,integer)','public.zameel_shorts_preference(uuid,text)'] loop
  if to_regprocedure(name) is null then raise exception '132_function_missing: %',name; end if;
  if not has_function_privilege('authenticated',name,'EXECUTE') or has_function_privilege('anon',name,'EXECUTE') then raise exception '132_function_acl_failed: %',name; end if;
 end loop;
 foreach name in array array['public.zameel_quiz_admin_question(uuid,uuid,jsonb)','public.zameel_quiz_admin_review(uuid,uuid,integer,text,text)','public.zameel_quiz_claim_generation(uuid)','public.zameel_quiz_admin_import(uuid,jsonb)','public.zameel_quiz_admin_report(uuid,uuid,text,text)'] loop
  if to_regprocedure(name) is null or not has_function_privilege('service_role',name,'EXECUTE') or has_function_privilege('authenticated',name,'EXECUTE') or has_function_privilege('anon',name,'EXECUTE') then raise exception '132_admin_function_acl_failed: %',name; end if;
 end loop;
 if to_regclass('public.quiz_one_pending_idx') is null or to_regclass('public.quiz_one_award_idx') is null then raise exception '132_idempotency_indexes_missing'; end if;
 if public.zameel_quiz_level(15)<>1 or public.zameel_quiz_level(16)<>2 or public.zameel_quiz_level(30)<>2 or public.zameel_quiz_level(31)<>3 or public.zameel_quiz_level(80)<>3 or public.zameel_quiz_level(81)<>4 or public.zameel_quiz_level(140)<>4 or public.zameel_quiz_level(141)<>5 or public.zameel_quiz_level(350)<>5 or public.zameel_quiz_level(351)<>6 then raise exception '132_quiz_levels_wrong'; end if;
end $$;
select 'PASS: private tables, protected RPC permissions, quiz progression and one-award indexes installed' as result;
