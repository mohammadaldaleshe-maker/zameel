begin;
-- The private topic carries only a refresh signal, never account/content data.
create policy zameel_admin_session_receive_154 on realtime.messages for select to authenticated
using(extension='broadcast' and realtime.topic()='zameel_admin_session:'||auth.uid()::text);
create policy zameel_admin_session_isolation_154 on realtime.messages as restrictive for select to authenticated
using(realtime.topic() not like 'zameel_admin_session:%' or realtime.topic()='zameel_admin_session:'||auth.uid()::text);
create policy zameel_admin_session_no_client_send_154 on realtime.messages as restrictive for insert to authenticated
with check(realtime.topic() not like 'zameel_admin_session:%');
create or replace function public.zameel_admin_session_signal_154() returns trigger
language plpgsql security definer set search_path=public,pg_temp as $$
declare target uuid;
begin
 if tg_table_name='admin_users' then
   target:=coalesce(new.user_id,old.user_id);
 else target:=coalesce(new.employee_id,old.employee_id);end if;
 perform realtime.send(jsonb_build_object('refresh',true),'permissions_changed','zameel_admin_session:'||target::text,true);
 return coalesce(new,old);
end $$;
create trigger zameel_admin_session_signal_154 after insert or update or delete on public.zameel_admin_delegations_154 for each row execute function public.zameel_admin_session_signal_154();
create trigger zameel_admin_role_signal_154 after update or delete on public.admin_users for each row execute function public.zameel_admin_session_signal_154();
revoke all on function public.zameel_admin_session_signal_154() from public,anon,authenticated;
notify pgrst,'reload schema';
commit;
