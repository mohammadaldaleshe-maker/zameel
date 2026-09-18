-- Zameel 051: reliable, server-confirmed direct messages.
-- Run after migration 050 (safe to run even when 050 was not applied).
begin;

create or replace function public.send_direct_message(
  target_conversation_id uuid,
  message_content text
)
returns table(
  id uuid,
  content text,
  sender_id uuid,
  created_at timestamptz,
  media_url text,
  media_type text,
  is_read boolean,
  delivered_at timestamptz,
  read_at timestamptz
)
language plpgsql
security definer
set search_path=public
set row_security=off
as $$
declare
  me uuid:=auth.uid();
  saved public.messages;
begin
  if me is null then raise exception 'not_authenticated'; end if;
  if coalesce(trim(message_content),'')='' then
    raise exception 'message_required';
  end if;
  if not exists(
    select 1 from public.conversation_members m
    where m.conversation_id=target_conversation_id and m.user_id=me
  ) then
    raise exception 'conversation_membership_required';
  end if;
  if exists(
    select 1
    from public.conversation_members mine
    join public.conversation_members other
      on other.conversation_id=mine.conversation_id and other.user_id<>me
    join public.user_blocks b
      on (b.blocker_id=me and b.blocked_id=other.user_id)
      or (b.blocker_id=other.user_id and b.blocked_id=me)
    where mine.conversation_id=target_conversation_id and mine.user_id=me
  ) then
    raise exception 'conversation_blocked';
  end if;

  insert into public.messages(
    conversation_id,sender_id,content,media_url,media_type,is_read
  ) values(
    target_conversation_id,me,left(trim(message_content),5000),null,null,false
  ) returning * into saved;

  return query select saved.id,saved.content,saved.sender_id,saved.created_at,
    saved.media_url,saved.media_type,saved.is_read,saved.delivered_at,saved.read_at;
end $$;

revoke execute on function public.send_direct_message(uuid,text)
from public,anon;
grant execute on function public.send_direct_message(uuid,text)
to authenticated;

do $$ begin
  alter publication supabase_realtime add table public.messages;
exception when duplicate_object then null;
end $$;

commit;
