begin;
create extension if not exists pg_net;

-- Called only by database triggers. The credential remains in Vault and is
-- never included in migration source or exposed through a client RPC.
create or replace function public.zameel_dispatch_call_push_142(p_body jsonb)
returns void language plpgsql security definer set search_path = '' as $$
declare v_secret text;
begin
  select decrypted_secret into v_secret
  from vault.decrypted_secrets where name = 'zameel_push_webhook_secret';
  if v_secret is null then return; end if;
  perform net.http_post(
    url := 'https://jwuqyykjmltroneqtjoc.supabase.co/functions/v1/send-push-notifications',
    headers := jsonb_build_object('Content-Type', 'application/json', 'x-zameel-push-secret', v_secret),
    body := p_body, timeout_milliseconds := 60000
  );
exception when others then
  -- A transient dispatch failure must not prevent creating/ending a call.
  -- Existing cron retries queued invitations; native expiry ends old ringing.
  raise warning 'Zameel immediate call dispatch failed (SQLSTATE %)', SQLSTATE;
end;
$$;
revoke all on function public.zameel_dispatch_call_push_142(jsonb) from public, anon, authenticated;

create or replace function public.zameel_immediate_call_queue_142()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if exists (select 1 from public.notifications n where n.id = new.notification_id
    and n.type in ('incoming_voice_call', 'incoming_video_call')) then
    perform public.zameel_dispatch_call_push_142(jsonb_build_object('notification_id', new.notification_id));
  end if;
  return new;
end;
$$;
revoke all on function public.zameel_immediate_call_queue_142() from public, anon, authenticated;
drop trigger if exists zameel_immediate_call_queue_142 on public.push_notification_queue;
create trigger zameel_immediate_call_queue_142 after insert on public.push_notification_queue
for each row execute function public.zameel_immediate_call_queue_142();

create or replace function public.zameel_call_stop_push_142()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if old.status is distinct from new.status and new.status <> 'ringing' then
    perform public.zameel_dispatch_call_push_142(jsonb_build_object('call_ended_room', new.room_id));
  end if;
  return new;
end;
$$;
revoke all on function public.zameel_call_stop_push_142() from public, anon, authenticated;
drop trigger if exists zameel_call_stop_push_142 on public.direct_call_sessions;
create trigger zameel_call_stop_push_142 after update of status on public.direct_call_sessions
for each row execute function public.zameel_call_stop_push_142();
commit;
