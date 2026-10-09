begin;

do $$
begin
  if not exists (
    select 1 from vault.decrypted_secrets
    where name = 'zameel_push_webhook_secret'
      and nullif(decrypted_secret, '') is not null
  ) then
    raise exception 'Push webhook secret missing; stopped';
  end if;
end;
$$;

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
    body := '{}'::jsonb,
    timeout_milliseconds := 60000
  );
  return new;
exception when others then
  raise warning 'Immediate push dispatch failed; queued notification retained for retry';
  return new;
end;
$$;

revoke all on function public.zameel_dispatch_queued_push()
from public, anon, authenticated;

drop trigger if exists zameel_push_notifications
on public.push_notification_queue;

create trigger zameel_push_notifications
after insert on public.push_notification_queue
for each row execute function public.zameel_dispatch_queued_push();

commit;
