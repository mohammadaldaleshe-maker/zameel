-- 173: faster, steadier call pushes.
-- 1) Call invitations already have their own immediate trigger (142). The general
--    dispatch trigger (169) used to fire a SECOND worker request for the same call,
--    doubling the load exactly when speed matters. It now leaves call rows alone.
-- 2) Rows stuck in "processing" after a worker crash are released now, so the
--    one-minute retry sweep can deliver them (the worker also uses a 2-minute limit).
--    This also installs the processing-time column and trigger from migration 069
--    if that migration was never applied on this project (safe to repeat).
begin;

alter table public.push_notification_queue
  add column if not exists processing_started_at timestamptz;

create or replace function public.set_push_queue_processing_timestamp()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.status = 'processing' then
    if old.status is distinct from 'processing' or new.processing_started_at is null then
      new.processing_started_at := now();
    end if;
  else
    new.processing_started_at := null;
  end if;
  return new;
end;
$$;

revoke execute on function public.set_push_queue_processing_timestamp()
  from public, anon, authenticated;

drop trigger if exists push_queue_processing_timestamp
  on public.push_notification_queue;

create trigger push_queue_processing_timestamp
before update of status on public.push_notification_queue
for each row
execute function public.set_push_queue_processing_timestamp();

create index if not exists push_notification_queue_processing_started_idx
  on public.push_notification_queue(processing_started_at)
  where status = 'processing';

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
  and created_at < now() - interval '2 minutes';

commit;
