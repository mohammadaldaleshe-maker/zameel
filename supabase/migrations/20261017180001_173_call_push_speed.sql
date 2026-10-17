-- 173: faster, steadier call pushes.
-- 1) Call invitations already have their own immediate trigger (142). The general
--    dispatch trigger (169) used to fire a SECOND worker request for the same call,
--    doubling the load exactly when speed matters. It now leaves call rows alone.
-- 2) Rows stuck in "processing" after a worker crash are released now, so the
--    one-minute retry sweep can deliver them (the worker also uses a 2-minute limit).
begin;

create or replace function public.zameel_dispatch_queued_push()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  push_secret text;
  note_type text;
begin
  select n.type into note_type from public.notifications n where n.id = new.notification_id;
  if note_type in ('incoming_voice_call', 'incoming_video_call') then
    return new;
  end if;

  select decrypted_secret into strict push_secret
  from vault.decrypted_secrets
  where name = 'zameel_push_webhook_secret';

  perform net.http_post(
    url := 'https://jwuqyykjmltroneqtjoc.supabase.co/functions/v1/send-push-notifications',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-zameel-push-secret', push_secret
    ),
    body := jsonb_build_object('notification_id', new.notification_id),
    timeout_milliseconds := 60000
  );
  return new;
exception when others then
  raise warning 'Immediate push dispatch failed; queued notification retained for retry';
  return new;
end;
$$;

revoke all on function public.zameel_dispatch_queued_push() from public, anon, authenticated;

-- Release pushes that were abandoned mid-send by a crashed worker.
update public.push_notification_queue
set status = 'failed', processed_at = null, last_error = coalesce(last_error, 'released_after_stuck_processing')
where status = 'processing'
  and coalesce(processing_started_at, created_at) < now() - interval '2 minutes';

commit;
