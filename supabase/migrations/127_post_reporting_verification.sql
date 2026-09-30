-- Read-only installation/security check; no real users or posts are modified.
do $$ begin
  if not (select relrowsecurity from pg_class where oid='public.zameel_post_reports'::regclass) then
    raise exception 'report_rls_disabled';
  end if;
  if has_function_privilege('anon','public.zameel_report_post(uuid,text,text)','EXECUTE')
     or not has_function_privilege('authenticated','public.zameel_report_post(uuid,text,text)','EXECUTE') then
    raise exception 'report_rpc_privileges_incorrect';
  end if;
  if has_function_privilege('authenticated','public.zameel_review_post_report(uuid,uuid,text,uuid,text)','EXECUTE')
     or has_function_privilege('anon','public.zameel_review_post_report(uuid,uuid,text,uuid,text)','EXECUTE')
     or not has_function_privilege('service_role','public.zameel_review_post_report(uuid,uuid,text,uuid,text)','EXECUTE') then
    raise exception 'review_rpc_privileges_incorrect';
  end if;
  if (select prosecdef from pg_proc where oid='public.zameel_report_post(uuid,text,text)'::regprocedure) then
    raise exception 'report_rpc_must_preserve_post_rls';
  end if;
  if has_column_privilege('authenticated','public.zameel_post_reports','status','INSERT')
     or has_column_privilege('authenticated','public.zameel_post_reports','reported_user_id','INSERT')
     or has_table_privilege('authenticated','public.zameel_post_reports','UPDATE')
     or has_table_privilege('authenticated','public.zameel_post_reports','DELETE') then
    raise exception 'clients_can_spoof_or_review_reports';
  end if;
  if not exists(select 1 from pg_policies where schemaname='public' and tablename='zameel_post_reports'
    and policyname='post_report_self_insert' and cmd='INSERT') then raise exception 'report_insert_policy_missing'; end if;
  if not exists(select 1 from pg_policies where schemaname='public' and tablename='posts'
    and policyname='admin_hidden_posts_guard' and permissive='RESTRICTIVE' and cmd='SELECT') then
    raise exception 'hidden_post_guard_missing';
  end if;
end $$;
select 'PASS: report RLS, caller permissions and protected review installation' as result;
