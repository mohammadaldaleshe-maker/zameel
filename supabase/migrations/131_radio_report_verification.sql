do $$
begin
 if not has_table_privilege('authenticated','public.zameel_radio_posts','SELECT') then raise exception 'radio_read_permission_missing'; end if;
 if exists(select 1 from pg_trigger where tgrelid='public.zameel_radio_reports'::regclass and tgname='zameel_radio_two_reports' and not tgisinternal) then raise exception 'automatic_two_report_hiding_still_active'; end if;
 if not exists(select 1 from pg_policy where polrelid='public.zameel_radio_posts'::regclass and polname='radio_deleted_visibility_guard' and not polpermissive) then raise exception 'deleted_radio_guard_missing'; end if;
 if has_function_privilege('authenticated','public.zameel_admin_unmute_radio(uuid,uuid,text)','EXECUTE')
 or has_function_privilege('anon','public.zameel_admin_unmute_radio(uuid,uuid,text)','EXECUTE')
 or not has_function_privilege('service_role','public.zameel_admin_unmute_radio(uuid,uuid,text)','EXECUTE') then raise exception 'unmute_permissions_invalid'; end if;
 if has_function_privilege('authenticated','public.zameel_review_radio_report(uuid,uuid,text,uuid,text)','EXECUTE')
 or has_function_privilege('anon','public.zameel_review_radio_report(uuid,uuid,text,uuid,text)','EXECUTE')
 or not has_function_privilege('service_role','public.zameel_review_radio_report(uuid,uuid,text,uuid,text)','EXECUTE') then raise exception 'radio_review_permissions_invalid'; end if;
end $$;
select 'PASS: radio report read permission, manual-only decisions and protected unmute installed' as result;
