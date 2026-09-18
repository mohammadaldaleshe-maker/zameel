-- Zameel 031: deterministic two-party WebRTC signaling mailbox.
-- Run after 030. Safe to execute more than once.
begin;

alter table public.direct_call_sessions
  add column if not exists signal_sequence bigint not null default 0,
  add column if not exists signal_mailbox jsonb not null default '[]'::jsonb;

drop function if exists public.publish_call_signal_v2(text, jsonb);
create function public.publish_call_signal_v2(
  target_room_id text,
  signal_payload jsonb
)
returns bigint
language plpgsql
security definer
set search_path = public
set row_security = off
as $$
declare
  me uuid := auth.uid();
  next_sequence bigint;
  current_mailbox jsonb;
  stored_payload jsonb;
begin
  if me is null then raise exception 'not_authenticated'; end if;

  select s.signal_sequence + 1, s.signal_mailbox
    into next_sequence, current_mailbox
  from public.direct_call_sessions s
  where s.room_id = target_room_id
    and me in (s.caller_id, s.callee_id)
    and s.status <> 'ended'
  for update;

  if next_sequence is null then raise exception 'call_membership_required'; end if;
  if jsonb_typeof(signal_payload) <> 'object' then
    raise exception 'invalid_signal_payload';
  end if;

  stored_payload := signal_payload || jsonb_build_object(
    'server_signal_id', next_sequence,
    'signal_id', coalesce(signal_payload->>'signal_id', me::text || ':' || next_sequence::text),
    'from', me::text
  );

  -- A direct call normally uses fewer than 50 messages. Bound the mailbox so
  -- abandoned sessions cannot grow indefinitely.
  if jsonb_array_length(coalesce(current_mailbox, '[]'::jsonb)) >= 200 then
    current_mailbox := '[]'::jsonb;
  end if;

  update public.direct_call_sessions
  set signal_sequence = next_sequence,
      signal_mailbox = coalesce(current_mailbox, '[]'::jsonb) || jsonb_build_array(stored_payload)
  where room_id = target_room_id;

  return next_sequence;
end;
$$;

drop function if exists public.get_call_signals_v2(text);
create function public.get_call_signals_v2(target_room_id text)
returns table(signal_sequence bigint, signals jsonb, status text)
language plpgsql
security definer
set search_path = public
set row_security = off
as $$
declare me uuid := auth.uid();
begin
  if me is null then raise exception 'not_authenticated'; end if;
  return query
  select s.signal_sequence, s.signal_mailbox, s.status
  from public.direct_call_sessions s
  where s.room_id = target_room_id
    and me in (s.caller_id, s.callee_id);
end;
$$;

revoke execute on function public.publish_call_signal_v2(text, jsonb) from public, anon;
revoke execute on function public.get_call_signals_v2(text) from public, anon;
grant execute on function public.publish_call_signal_v2(text, jsonb) to authenticated;
grant execute on function public.get_call_signals_v2(text) to authenticated;

commit;
