-- 070_messages_schema_compatibility.sql
-- Live-database repair companion to the fresh-install guard now embedded in
-- migration 047. Safe and idempotent on databases where these columns already
-- exist.

begin;

-- Normalize the historical messages schema. Early Zameel schemas used `body`,
-- while the current chat client and RPCs use `content` + media/receipt fields.
-- Keep both text columns synchronized so fresh databases and older live
-- databases behave identically during rolling upgrades.
alter table public.messages
  add column if not exists body text,
  add column if not exists content text,
  add column if not exists media_url text,
  add column if not exists media_type text,
  add column if not exists is_read boolean not null default false;

update public.messages
set content = coalesce(nullif(content, ''), body, '')
where content is null or content = '';

update public.messages
set body = coalesce(nullif(body, ''), content, '')
where body is null or body = '';

alter table public.messages alter column content set default '';
alter table public.messages alter column content set not null;

create or replace function public.sync_message_body_content()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if tg_op = 'UPDATE' then
    if new.content is distinct from old.content
       and new.body is not distinct from old.body then
      new.body := new.content;
    elsif new.body is distinct from old.body
       and new.content is not distinct from old.content then
      new.content := new.body;
    end if;
  end if;

  if coalesce(trim(new.content), '') = ''
     and coalesce(trim(new.body), '') <> '' then
    new.content := new.body;
  end if;
  if coalesce(trim(new.body), '') = ''
     and coalesce(trim(new.content), '') <> '' then
    new.body := new.content;
  end if;
  return new;
end;
$$;

revoke execute on function public.sync_message_body_content()
from public, anon, authenticated;

drop trigger if exists messages_sync_body_content on public.messages;
create trigger messages_sync_body_content
before insert or update of body, content on public.messages
for each row execute function public.sync_message_body_content();

commit;
