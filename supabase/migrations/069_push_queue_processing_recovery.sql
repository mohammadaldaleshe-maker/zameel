-- 069_push_queue_processing_recovery.sql
-- Prevent push rows from being stranded forever in `processing` if an Edge
-- Function invocation is terminated after claiming a row but before it can
-- write the final sent/failed status.

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

-- Existing processing rows predate the timestamp column. Start their recovery
-- clock now rather than immediately replaying them during deployment.
update public.push_notification_queue
set processing_started_at = now()
where status = 'processing'
  and processing_started_at is null;

create index if not exists push_notification_queue_processing_started_idx
  on public.push_notification_queue(processing_started_at)
  where status = 'processing';

commit;
