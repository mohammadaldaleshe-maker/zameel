-- 169: faster chat/like/comment pushes.
-- Before: every queued notification posted an EMPTY body to the push worker, which
-- then walked the whole queue oldest-first, so a few old failed rows (users without
-- a registered device) delayed a fresh chat message by many seconds.
-- Now: each inserted queue row asks the worker for exactly that notification, and a
-- once-a-minute sweep retries rows that failed. Nothing else changes.
begin;

create or replace function public.zameel_dispatch_queued_push()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  push_secret text;
begin
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

-- Retry sweep: asks the worker (empty body = whole queue, never-tried rows first)
-- only when something is actually waiting.
create or replace function public.zameel_push_retry_169()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  push_secret text;
  waiting integer;
begin
  select count(*) into waiting
  from public.push_notification_queue
  where status in ('pending', 'failed')
    and attempts < 5
    and created_at > now() - interval '1 day';
  if waiting = 0 then return 0; end if;

  select decrypted_secret into push_secret
  from vault.decrypted_secrets
  where name = 'zameel_push_webhook_secret';
  if push_secret is null then return 0; end if;

  perform net.http_post(
    url := 'https://jwuqyykjmltroneqtjoc.supabase.co/functions/v1/send-push-notifications',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-zameel-push-secret', push_secret
    ),
    body := '{}'::jsonb,
    timeout_milliseconds := 60000
  );
  return waiting;
exception when others then
  raise warning 'Push retry sweep failed (SQLSTATE %)', SQLSTATE;
  return 0;
end;
$$;

revoke all on function public.zameel_push_retry_169() from public, anon, authenticated;

do $$
begin
  if to_regnamespace('cron') is not null then
    perform cron.schedule('zameel-push-retry-169', '* * * * *', 'select public.zameel_push_retry_169();');
  end if;
exception when others then
  raise warning 'Push retry job was not scheduled (SQLSTATE %); enable pg_cron and run this migration again', SQLSTATE;
end;
$$;

commit;
