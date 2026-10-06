begin;
-- Remove obsolete permissive policies; retain scoped policies.
drop policy if exists "Authenticated users can delete post media" on storage.objects;
drop policy if exists "Authenticated users can read post media" on storage.objects;
drop policy if exists "Authenticated users can upload post media" on storage.objects;
drop policy if exists users_select_privacy on public.users;

-- Invoker trigger: direct client writes cannot grant/remove administrative roles.
create or replace function public.zameel_guard_profile_role_144()
returns trigger language plpgsql set search_path = '' as $$
begin
 if current_user not in ('postgres','service_role','supabase_admin') then
  if (tg_op='INSERT' and new.role in ('admin','staff')) or
     (tg_op='UPDATE' and new.role is distinct from old.role
       and (new.role in ('admin','staff') or old.role in ('admin','staff'))) then
   raise exception 'administrative_role_requires_server';
  end if;
 end if;
 return new;
end $$;
drop trigger if exists zameel_guard_profile_role_144 on public.users;
create trigger zameel_guard_profile_role_144 before insert or update of role on public.users
for each row execute function public.zameel_guard_profile_role_144();

-- Ordinary message UPDATE is limited to receipts; content and sender stay immutable.
create or replace function public.zameel_guard_message_update_144()
returns trigger language plpgsql set search_path = '' as $$
begin
 if current_user not in ('postgres','service_role','supabase_admin') then
  if (to_jsonb(new) - array['is_read','read_at','delivered_at']) is distinct from
     (to_jsonb(old) - array['is_read','read_at','delivered_at']) then
   raise exception 'message_content_is_immutable';
  end if;
  if old.sender_id=auth.uid() and to_jsonb(new) is distinct from to_jsonb(old) then
   raise exception 'sender_cannot_acknowledge_own_message';
  end if;
 end if;
 return new;
end $$;
drop trigger if exists zameel_guard_message_update_144 on public.messages;
create trigger zameel_guard_message_update_144 before update on public.messages
for each row execute function public.zameel_guard_message_update_144();
revoke all on function public.zameel_guard_profile_role_144(),public.zameel_guard_message_update_144() from public,anon,authenticated;
-- Client notifications may only acknowledge receipt; creation stays server-side.
create or replace function public.zameel_guard_notification_144()
returns trigger language plpgsql set search_path = '' as $$
begin
 if current_user not in ('postgres','service_role','supabase_admin') then
  if tg_op='INSERT' then raise exception 'notification_requires_server'; end if;
  if (to_jsonb(new)-'is_read') is distinct from (to_jsonb(old)-'is_read') then
   raise exception 'notification_content_is_immutable';
  end if;
 end if;
 return new;
end $$;
drop trigger if exists zameel_guard_notification_144 on public.notifications;
create trigger zameel_guard_notification_144 before insert or update on public.notifications
for each row execute function public.zameel_guard_notification_144();

-- An existing call cannot be retargeted to a third participant or rejuvenated.
create or replace function public.zameel_guard_call_identity_144()
returns trigger language plpgsql set search_path = '' as $$
begin
 if current_user not in ('postgres','service_role','supabase_admin') then
  if (new.room_id,new.conversation_id,new.caller_id,new.callee_id,new.created_at,new.with_video)
     is distinct from
     (old.room_id,old.conversation_id,old.caller_id,old.callee_id,old.created_at,old.with_video) then
   raise exception 'call_identity_is_immutable';
  end if;
 end if;
 return new;
end $$;
drop trigger if exists zameel_guard_call_identity_144 on public.direct_call_sessions;
create trigger zameel_guard_call_identity_144 before update on public.direct_call_sessions
for each row execute function public.zameel_guard_call_identity_144();
revoke all on function public.zameel_guard_notification_144(),public.zameel_guard_call_identity_144() from public,anon,authenticated;

create or replace function public.zameel_validate_staff_grant_144(
 p_target uuid,p_role text,p_scopes jsonb,p_permissions jsonb default '{}'::jsonb)
returns void language plpgsql security definer set search_path='' as $$
declare caller_role text; existing_role text; item jsonb; perm text;
begin
 if auth.uid() is null or not public.admin_has_permission('staff.manage') then raise exception 'not_authorized';end if;
 if exists(select 1 from public.admin_screen_access where user_id=auth.uid() and screen_key='employees' and not allowed) then raise exception 'screen_access_denied';end if;
 if p_target=auth.uid() then raise exception 'cannot_change_own_access';end if;
 select r.role_key into caller_role from public.admin_users a join public.admin_roles r on r.id=a.role_id where a.user_id=auth.uid() and a.is_active;
 select r.role_key into existing_role from public.admin_users a join public.admin_roles r on r.id=a.role_id where a.user_id=p_target;
 if not exists(select 1 from public.admin_roles where role_key=p_role) then raise exception 'invalid_role';end if;
 if jsonb_typeof(p_scopes) is distinct from 'array' or jsonb_typeof(p_permissions) is distinct from 'object' then raise exception 'invalid_access_input';end if;
 for item in select value from jsonb_array_elements(p_scopes) loop
  if coalesce(item->>'type','') not in ('global','university','college','department') then raise exception 'invalid_scope_type';end if;
  if item->>'type'<>'global' and coalesce(nullif(trim(item->>'value'),''),'*')='*' then raise exception 'scope_value_required';end if;
 end loop;
 if caller_role='super_admin' then return;end if;
 if p_role='super_admin' or existing_role='super_admin' then raise exception 'super_admin_required';end if;
 if not public.admin_scope_allows_user(p_target) then raise exception 'resource_outside_scope';end if;
 if not exists(select 1 from public.admin_roles where role_key=p_role) then raise exception 'invalid_role';end if;
 for perm in select rp.permission_key from public.admin_role_permissions rp join public.admin_roles r on r.id=rp.role_id where r.role_key=p_role loop
  if coalesce(p_permissions->>perm,'true')::boolean and not public.admin_has_permission(perm) then raise exception 'cannot_grant_permission_beyond_own';end if;
 end loop;
 for perm in select key from jsonb_each(p_permissions) where value='true'::jsonb loop
  if not public.admin_has_permission(perm) then raise exception 'cannot_grant_permission_beyond_own';end if;
 end loop;
 for item in select value from jsonb_array_elements(p_scopes) loop
  if not exists(select 1 from public.admin_scopes s where s.user_id=auth.uid() and
    (s.scope_type='global' or (s.scope_type=item->>'type' and s.scope_value=trim(item->>'value')))) then
   raise exception 'cannot_grant_scope_beyond_own';end if;
 end loop;
end $$;
revoke all on function public.zameel_validate_staff_grant_144(uuid,text,jsonb,jsonb) from public,anon,authenticated;
CREATE OR REPLACE FUNCTION public.admin_set_staff_access(p_user_id uuid, p_role_key text, p_active boolean, p_require_2fa boolean, p_scopes jsonb, p_permissions jsonb, p_screens jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
 SET row_security TO 'off'
AS $function$
declare
 rid uuid; item jsonb; caller_role text; target_role text; active_super_admins integer;
begin
 perform public.zameel_validate_staff_grant_144(p_user_id,p_role_key,coalesce(p_scopes,'[]'::jsonb),coalesce(p_permissions,'{}'::jsonb));
 if not public.admin_has_permission('staff.manage') then raise exception 'not_authorized'; end if;
 if p_user_id=auth.uid() then raise exception 'cannot_change_own_access'; end if;

 select r.role_key into caller_role
 from public.admin_users a join public.admin_roles r on r.id=a.role_id
 where a.user_id=auth.uid() and a.is_active;

 select r.role_key into target_role
 from public.admin_users a join public.admin_roles r on r.id=a.role_id
 where a.user_id=p_user_id;

 if (p_role_key='super_admin' or target_role='super_admin') and caller_role<>'super_admin' then
   raise exception 'super_admin_required';
 end if;

 if target_role='super_admin' and (p_role_key<>'super_admin' or not p_active) then
   select count(*) into active_super_admins
   from public.admin_users a join public.admin_roles r on r.id=a.role_id
   where a.is_active and r.role_key='super_admin';
   if active_super_admins <= 1 then raise exception 'cannot_disable_last_super_admin'; end if;
 end if;

 select id into rid from public.admin_roles where role_key=p_role_key;
 if rid is null then raise exception 'invalid_role'; end if;

 update public.admin_users
 set role_id=rid,is_active=p_active,require_2fa=p_require_2fa,updated_at=now()
 where user_id=p_user_id;
 if not found then raise exception 'staff_not_found'; end if;

 delete from public.admin_scopes where user_id=p_user_id;
 for item in select value from jsonb_array_elements(coalesce(p_scopes,'[]'::jsonb)) loop
  if item->>'type' not in ('global','university','college','department') then raise exception 'invalid_scope_type'; end if;
  if item->>'type'<>'global' and coalesce(nullif(trim(item->>'value'),''),'*')='*' then raise exception 'scope_value_required'; end if;
  insert into public.admin_scopes(user_id,scope_type,scope_value)
  values(p_user_id,item->>'type',case when item->>'type'='global' then '*' else trim(item->>'value') end);
 end loop;

 delete from public.admin_user_permission_overrides where user_id=p_user_id;
 insert into public.admin_user_permission_overrides(user_id,permission_key,allowed,updated_by)
 select p_user_id,key,(value::text)::boolean,auth.uid()
 from jsonb_each(coalesce(p_permissions,'{}'::jsonb));

 delete from public.admin_screen_access where user_id=p_user_id;
 insert into public.admin_screen_access(user_id,screen_key,allowed,updated_by)
 select p_user_id,key,(value::text)::boolean,auth.uid()
 from jsonb_each(coalesce(p_screens,'{}'::jsonb));

 perform public.admin_log('staff.access.update','admin_user',p_user_id::text,
   jsonb_build_object('role',p_role_key,'active',p_active,'require_2fa',p_require_2fa,'scopes',p_scopes));
end $function$;
CREATE OR REPLACE FUNCTION public.admin_assign_staff(p_email text, p_role_key text, p_scope_type text DEFAULT 'global'::text, p_scope_value text DEFAULT '*'::text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
 SET row_security TO 'off'
AS $function$
declare target uuid; rid uuid;
begin
 -- Check the resolved target before any administrative write.

 if not public.admin_has_permission('staff.manage') then raise exception 'not_authorized'; end if;
 select id into target from public.users where lower(coalesce(email,''))=lower(trim(p_email)) limit 1;
 if target is null then raise exception 'zameel_user_not_found'; end if;
 select id into rid from public.admin_roles where role_key=p_role_key;
 if rid is null then raise exception 'invalid_admin_role'; end if;
 perform public.zameel_validate_staff_grant_144(target,p_role_key,jsonb_build_array(jsonb_build_object('type',p_scope_type,'value',p_scope_value)));
 insert into public.admin_users(user_id,role_id,is_active,require_2fa,created_by) values(target,rid,true,true,auth.uid())
 on conflict(user_id) do update set role_id=excluded.role_id,is_active=true,updated_at=now();
 delete from public.admin_scopes where user_id=target;
 insert into public.admin_scopes(user_id,scope_type,scope_value) values(target,p_scope_type,coalesce(nullif(p_scope_value,''),'*'));
 perform public.admin_log('staff.assign','admin_user',target::text,jsonb_build_object('role',p_role_key,'scope_type',p_scope_type,'scope_value',p_scope_value));
 return target;
end $function$;
CREATE OR REPLACE FUNCTION public.zameel_select_college_winner(p_cycle date DEFAULT zameel_jordan_cycle_day())
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_entry uuid;
begin
 if coalesce(auth.role(),'') <> 'service_role' and not (auth.uid() is null and session_user in ('postgres','supabase_admin')) then
  if auth.uid() is null then raise exception 'authentication_required';end if;
  if p_cycle is distinct from public.zameel_jordan_cycle_day() then raise exception 'invalid_winner_cycle';end if;
 end if;
  if not public.zameel_college_challenge_is_enabled() then return null; end if;
  if p_cycle = public.zameel_jordan_cycle_day()
     and (now() at time zone 'Asia/Amman')::time < time '20:00' then
    raise exception 'winner selection opens at 20:00 Asia/Amman';
  end if;
  select id into v_entry from zameel_college_entries
   where cycle_day=p_cycle and not is_hidden
   order by like_count desc, created_at asc limit 1;
  if v_entry is not null then
    insert into zameel_college_winners(cycle_day,entry_id) values(p_cycle,v_entry)
    on conflict(cycle_day) do update set entry_id=excluded.entry_id, selected_at=now();
  end if;
  return v_entry;
end;
$function$;
revoke all on function public.zameel_select_college_winner(date) from public,anon;
grant execute on function public.zameel_select_college_winner(date) to authenticated,service_role;

revoke execute on function public.admin_assign_staff(text,text,text,text),public.admin_set_staff_access(uuid,text,boolean,boolean,jsonb,jsonb,jsonb) from public,anon;
grant execute on function public.admin_assign_staff(text,text,text,text),public.admin_set_staff_access(uuid,text,boolean,boolean,jsonb,jsonb,jsonb) to authenticated;
commit;
