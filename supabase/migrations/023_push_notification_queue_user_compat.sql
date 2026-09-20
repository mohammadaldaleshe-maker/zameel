-- Zameel: compatibility repair for databases where push_notification_queue
-- contains a legacy NOT NULL user_id column.
--
-- The canonical notification recipient is notifications.user_id. Some older
-- deployed schemas kept the recipient duplicated on the queue row. The app's
-- enqueue trigger must therefore support both queue shapes.

begin;

create or replace function public.enqueue_notification_for_push()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'push_notification_queue'
      and column_name = 'user_id'
  ) then
    execute $sql$
      insert into public.push_notification_queue(notification_id, user_id)
      values ($1, $2)
      on conflict (notification_id) do nothing
    $sql$ using new.id, new.user_id;
  else
    insert into public.push_notification_queue(notification_id)
    values (new.id)
    on conflict (notification_id) do nothing;
  end if;

  return new;
end;
$$;

-- Repair any legacy nullable rows, if such rows exist in a particular schema.
do $$
begin
  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'push_notification_queue'
      and column_name = 'user_id'
  ) then
    execute $sql$
      update public.push_notification_queue q
         set user_id = n.user_id
        from public.notifications n
       where q.notification_id = n.id
         and q.user_id is null
    $sql$;
  end if;
end;
$$;

-- Queue notifications that are not yet present, using the correct shape for
-- whichever version of push_notification_queue is deployed.
do $$
begin
  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'push_notification_queue'
      and column_name = 'user_id'
  ) then
    execute $sql$
      insert into public.push_notification_queue(notification_id, user_id)
      select n.id, n.user_id
        from public.notifications n
        left join public.push_notification_queue q
          on q.notification_id = n.id
       where q.id is null
      on conflict (notification_id) do nothing
    $sql$;
  else
    insert into public.push_notification_queue(notification_id)
    select n.id
      from public.notifications n
      left join public.push_notification_queue q
        on q.notification_id = n.id
     where q.id is null
    on conflict (notification_id) do nothing;
  end if;
end;
$$;

-- Recreate the trigger explicitly so installations with drifted trigger state
-- point at the repaired function.
drop trigger if exists notifications_enqueue_push on public.notifications;
create trigger notifications_enqueue_push
after insert on public.notifications
for each row execute function public.enqueue_notification_for_push();

revoke execute on function public.enqueue_notification_for_push() from public, anon, authenticated;

commit;
