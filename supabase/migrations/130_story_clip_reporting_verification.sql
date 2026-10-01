-- Read-only installation checks. Run after 130_story_clip_reporting.sql.
do $$
declare t text; submit_oid oid; review_oid oid; c oid;
begin
 submit_oid=to_regprocedure('public.zameel_report_media(text,uuid,text,text)');
 review_oid=to_regprocedure('public.zameel_review_media_report(text,uuid,uuid,text,uuid,text)');
 if submit_oid is null or review_oid is null then raise exception 'media_report_functions_missing'; end if;
 if not has_function_privilege('authenticated',submit_oid,'EXECUTE') or has_function_privilege('anon',submit_oid,'EXECUTE')
 or (select prosecdef from pg_proc where oid=submit_oid) then raise exception 'submit_permissions_invalid'; end if;
 if has_function_privilege('authenticated',review_oid,'EXECUTE') or has_function_privilege('anon',review_oid,'EXECUTE')
 or not has_function_privilege('service_role',review_oid,'EXECUTE') then raise exception 'review_permissions_invalid'; end if;
 foreach t in array array['zameel_clip_reports','zameel_story_reports'] loop
  c=to_regclass('public.'||t);
  if c is null or not (select relrowsecurity from pg_class where oid=c) then raise exception 'report_rls_missing: %',t; end if;
  if has_table_privilege('authenticated',c,'UPDATE') or has_table_privilege('authenticated',c,'DELETE')
  or has_column_privilege('authenticated',c,'status','INSERT')
  or has_column_privilege('authenticated',c,'reported_user_id','INSERT') then raise exception 'report_write_permissions_invalid: %',t; end if;
  if not exists(select 1 from pg_trigger where tgrelid=c and tgname='zameel_media_report_guard' and not tgisinternal) then raise exception 'report_guard_missing'; end if;
 end loop;
 foreach t in array array['clips','social_stories'] loop
  c=to_regclass('public.'||t);
  if not exists(select 1 from pg_policy where polrelid=c and polname='reporting_media_visibility_guard' and not polpermissive)
  or not exists(select 1 from pg_trigger where tgrelid=c and tgname='zameel_guard_media_moderation' and not tgisinternal) then raise exception 'visibility_guard_missing: %',t; end if;
 end loop;
 foreach t in array array['clip','story'] loop
  c=to_regprocedure('public.zameel_can_view_'||t||'_before130(uuid,uuid)');
  if c is null or has_function_privilege('authenticated',c,'EXECUTE') or has_function_privilege('anon',c,'EXECUTE') then raise exception 'visibility_backup_permissions_invalid'; end if;
  if position('is_deleted_by_admin' in pg_get_functiondef(to_regprocedure('public.can_view_'||t||'(uuid,uuid)')))=0 then raise exception 'visibility_wrapper_missing'; end if;
 end loop;
 if position('zameel_clip_reports' in pg_get_functiondef(to_regprocedure('public.zameel_report_counts(uuid,uuid[])')))=0
 or position('zameel_story_reports' in pg_get_functiondef(to_regprocedure('public.zameel_report_counts(uuid,uuid[])')))=0
 or position('admin_content_moderation' in pg_get_functiondef(review_oid))=0 then raise exception 'counts_or_notifications_missing'; end if;
end $$;
select 'PASS: story/clip report permissions, visibility guards, protected decisions and counters installed' as result;
