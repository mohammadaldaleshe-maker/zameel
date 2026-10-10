begin;
-- A surrogate primary key prevents PostgREST inferring a second messages/users
-- relationship. The separate unique key still permits one reaction per actor.
create table if not exists public.zameel_message_reactions (
 id bigint generated always as identity primary key,
 message_id uuid not null references public.messages(id) on delete cascade,
 user_id uuid not null references auth.users(id) on delete cascade,
 emoji text not null check(emoji in ('❤️','😂','🙏','😭','😲','💩')),
 updated_at timestamptz not null default now(),
 unique(message_id,user_id)
);
alter table public.zameel_message_reactions enable row level security;
revoke all on public.zameel_message_reactions from public,anon,authenticated;
create or replace function public.zameel_message_react(p_conversation uuid,p_message uuid,p_emoji text)
returns void language plpgsql security definer set search_path='' as $$
declare me uuid:=auth.uid();sender uuid;
begin
 if me is null or not public.is_conversation_member(p_conversation,me) or not public.zameel_account_can_write() then raise exception 'conversation_access_denied';end if;
 if not exists(select 1 from public.conversations where id=p_conversation and not is_group) then raise exception 'direct_conversation_required';end if;
 select sender_id into sender from public.messages where id=p_message and conversation_id=p_conversation for update;
 if not found or sender=me or public.is_blocked(me,sender) or exists(select 1 from public.zameel_hidden_messages where message_id=p_message and user_id=me) or exists(select 1 from public.zameel_deleted_messages where message_id=p_message) then raise exception 'message_access_denied';end if;
 if p_emoji is null then delete from public.zameel_message_reactions where message_id=p_message and user_id=me;
 elsif p_emoji in ('❤️','😂','🙏','😭','😲','💩') then
 insert into public.zameel_message_reactions(message_id,user_id,emoji) values(p_message,me,p_emoji)
 on conflict(message_id,user_id) do update set emoji=excluded.emoji,updated_at=now();
 else raise exception 'invalid_reaction';end if;
end $$;
create or replace function public.zameel_message_reactions_get(p_conversation uuid,p_messages uuid[])
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare me uuid:=auth.uid();result jsonb;
begin
 if me is null or not public.is_conversation_member(p_conversation,me) or not public.zameel_account_can_read() then raise exception 'conversation_access_denied';end if;
 if coalesce(cardinality(p_messages),0)>100 then raise exception 'reaction_batch_too_large';end if;
 select coalesce(jsonb_agg(jsonb_build_object('message_id',r.message_id,'user_id',r.user_id,'emoji',r.emoji)),'[]'::jsonb) into result
 from public.zameel_message_reactions r join public.messages m on m.id=r.message_id
 where m.conversation_id=p_conversation and m.id=any(p_messages)
 and not public.is_blocked(me,m.sender_id) and not public.is_blocked(me,r.user_id)
 and not exists(select 1 from public.zameel_hidden_messages h where h.message_id=m.id and h.user_id=me)
 and not exists(select 1 from public.zameel_deleted_messages d where d.message_id=m.id);
 return result;
end $$;
revoke all on function public.zameel_message_react(uuid,uuid,text),public.zameel_message_reactions_get(uuid,uuid[]) from public,anon;
grant execute on function public.zameel_message_react(uuid,uuid,text),public.zameel_message_reactions_get(uuid,uuid[]) to authenticated;
-- Restore unambiguous author embedding on installations that have not applied
-- the 151 hotfix. Existing history and its uniqueness remain intact.
alter table public.zameel_like_notified add column if not exists id bigint generated always as identity;
create unique index if not exists zameel_like_notified_identity_unique on public.zameel_like_notified(post_id,actor_id,owner_id);
alter table public.zameel_like_notified drop constraint if exists zameel_like_notified_pkey;
alter table public.zameel_like_notified add constraint zameel_like_notified_pkey primary key(id);
notify pgrst,'reload schema';
commit;
