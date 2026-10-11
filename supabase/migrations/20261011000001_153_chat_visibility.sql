begin;
set local lock_timeout = '5s';

-- A surrogate primary key prevents PostgREST from inferring a new join table.
create table if not exists public.zameel_chat_device_visibility_153 (
 id bigint generated always as identity primary key,
 device_id uuid not null unique references public.push_device_tokens(id) on delete cascade,
 user_id uuid not null references auth.users(id) on delete cascade,
 conversation_id uuid not null references public.conversations(id) on delete cascade,
 expires_at timestamptz not null
);
alter table public.zameel_chat_device_visibility_153 enable row level security;
revoke all on public.zameel_chat_device_visibility_153 from public, anon, authenticated;
grant select, insert, update, delete on public.zameel_chat_device_visibility_153 to service_role;

create or replace function public.zameel_chat_device_visibility_153(p_token text, p_conversation uuid)
returns void language plpgsql security definer set search_path='' as $$
declare me uuid := auth.uid(); device uuid;
begin
 if me is null or not public.zameel_account_can_read() then raise exception 'account_access_denied'; end if;
 if length(coalesce(p_token,'')) not between 1 and 4096 then raise exception 'invalid_device'; end if;
 select id into device from public.push_device_tokens where user_id=me and token=p_token;
 if device is null then raise exception 'device_access_denied'; end if;
 if p_conversation is null then
   delete from public.zameel_chat_device_visibility_153 where device_id=device and user_id=me;
   return;
 end if;
 if not public.is_conversation_member(p_conversation, me) then raise exception 'conversation_access_denied'; end if;
 if exists(select 1 from public.conversation_members cm where cm.conversation_id=p_conversation and cm.user_id<>me and public.is_blocked(me,cm.user_id)) then raise exception 'conversation_access_denied'; end if;
 insert into public.zameel_chat_device_visibility_153(device_id,user_id,conversation_id,expires_at)
 values(device,me,p_conversation,now()+interval '15 seconds')
 on conflict(device_id) do update set user_id=excluded.user_id,conversation_id=excluded.conversation_id,expires_at=excluded.expires_at;
end $$;
revoke all on function public.zameel_chat_device_visibility_153(text,uuid) from public,anon;
grant execute on function public.zameel_chat_device_visibility_153(text,uuid) to authenticated;

-- Keep the old inbox RPC intact for already installed releases.
create or replace function public.zameel_chat_inbox_153()
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare me uuid:=auth.uid(); result jsonb;
begin
 if me is null or not public.zameel_account_can_read() then raise exception 'account_access_denied'; end if;
 select coalesce(jsonb_agg(e.row || jsonb_build_object('unread_count', (
   select count(*) from public.messages m
   join public.conversations c on c.id=m.conversation_id and not c.is_group
   where m.sender_id=(e.row->>'id')::uuid and m.sender_id<>me
   and m.read_at is null and not coalesce(m.is_read,false)
   and public.is_conversation_member(c.id,me)
   and not exists(select 1 from public.zameel_hidden_messages h where h.message_id=m.id and h.user_id=me)
   and not exists(select 1 from public.zameel_deleted_messages d where d.message_id=m.id)
 )) order by e.ordinality),'[]'::jsonb) into result
 from jsonb_array_elements(public.zameel_chat_inbox()) with ordinality e(row,ordinality);
 return result;
end $$;
revoke all on function public.zameel_chat_inbox_153() from public,anon;
grant execute on function public.zameel_chat_inbox_153() to authenticated;

create or replace function public.zameel_chat_mark_read_153(target_conversation_id uuid)
returns integer language plpgsql security definer set search_path='' as $$
declare changed integer; me uuid:=auth.uid();
begin
 if me is null or not public.zameel_account_can_read() or not public.is_conversation_member(target_conversation_id,me) then raise exception 'conversation_access_denied'; end if;
 changed:=public.mark_conversation_read(target_conversation_id);
 update public.notifications set is_read=true where user_id=me and type='message'
   and data->>'conversation_id'=target_conversation_id::text and not coalesce(is_read,false);
 return changed;
end $$;
revoke all on function public.zameel_chat_mark_read_153(uuid) from public,anon;
grant execute on function public.zameel_chat_mark_read_153(uuid) to authenticated;

-- Only the trusted push worker can ask about another account's device.
create or replace function public.zameel_chat_should_suppress_push_153(p_notification uuid,p_device uuid)
returns boolean language sql stable security definer set search_path='' as $$
 select exists(
 select 1 from public.notifications n
 join public.push_device_tokens t on t.id=p_device and t.user_id=n.user_id
 join public.messages m on m.id::text=n.data->>'message_id' and m.conversation_id::text=n.data->>'conversation_id'
 join public.conversations c on c.id=m.conversation_id and not c.is_group
 where n.id=p_notification and n.type='message' and m.sender_id<>n.user_id
   and public.is_conversation_member(c.id,n.user_id)
   and exists(
     select 1 from public.zameel_chat_device_visibility_153 v
     where v.device_id=t.id and v.user_id=n.user_id and v.conversation_id=c.id and v.expires_at>now()
   )
 );
$$;
revoke all on function public.zameel_chat_should_suppress_push_153(uuid,uuid) from public,anon,authenticated;
grant execute on function public.zameel_chat_should_suppress_push_153(uuid,uuid) to service_role;
notify pgrst,'reload schema';
commit;
