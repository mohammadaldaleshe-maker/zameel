-- 164: reply to a specific message inside a direct chat (like WhatsApp).
--
-- Additive only:
--   * messages.reply_to_id (nullable) points at the message being answered.
--   * zameel_send_reply164 sends a text message that answers another message of
--     the SAME conversation. It repeats the membership and block checks of
--     send_direct_message (migration 051); send_direct_message is not changed.
--   * zameel_chat_messages keeps every existing key and adds three more:
--     reply_to_id, reply_preview (short text of the replied message) and
--     reply_sender_id. Nothing else in the function changes.
begin;

alter table public.messages
  add column if not exists reply_to_id uuid references public.messages(id) on delete set null;
create index if not exists messages_reply_to_idx on public.messages(reply_to_id) where reply_to_id is not null;

create or replace function public.zameel_send_reply164(
  p_conversation uuid, p_content text, p_reply_to uuid)
returns jsonb
language plpgsql security definer set search_path='' set row_security=off as $$
declare
  me uuid := auth.uid();
  saved public.messages;
begin
  if me is null then raise exception 'not_authenticated'; end if;
  if coalesce(trim(p_content), '') = '' then raise exception 'message_required'; end if;
  if not exists (select 1 from public.conversation_members m
                 where m.conversation_id = p_conversation and m.user_id = me) then
    raise exception 'conversation_membership_required';
  end if;
  if exists (
    select 1
    from public.conversation_members mine
    join public.conversation_members other
      on other.conversation_id = mine.conversation_id and other.user_id <> me
    join public.user_blocks b
      on (b.blocker_id = me and b.blocked_id = other.user_id)
      or (b.blocker_id = other.user_id and b.blocked_id = me)
    where mine.conversation_id = p_conversation and mine.user_id = me
  ) then
    raise exception 'conversation_blocked';
  end if;
  if p_reply_to is not null and not exists (
    select 1 from public.messages r
    where r.id = p_reply_to and r.conversation_id = p_conversation) then
    raise exception 'reply_target_not_in_conversation';
  end if;

  insert into public.messages(conversation_id, sender_id, content, media_url, media_type, is_read, reply_to_id)
  values (p_conversation, me, left(trim(p_content), 5000), null, null, false, p_reply_to)
  returning * into saved;

  return jsonb_build_object(
    'id', saved.id, 'content', saved.content, 'sender_id', saved.sender_id,
    'created_at', saved.created_at, 'media_url', saved.media_url,
    'media_type', saved.media_type, 'is_read', saved.is_read,
    'delivered_at', saved.delivered_at, 'read_at', saved.read_at,
    'reply_to_id', saved.reply_to_id,
    'reply_preview', (select case
        when dd.message_id is not null then 'تم حذف هذه الرسالة'
        when coalesce(rm.media_url, '') <> '' and coalesce(trim(rm.content), '') = '' then '📎 مرفق'
        else left(rm.content, 120) end
      from public.messages rm
      left join public.zameel_deleted_messages dd on dd.message_id = rm.id
      where rm.id = saved.reply_to_id),
    'reply_sender_id', (select rm.sender_id from public.messages rm where rm.id = saved.reply_to_id));
end $$;
revoke all on function public.zameel_send_reply164(uuid, text, uuid) from public, anon;
grant execute on function public.zameel_send_reply164(uuid, text, uuid) to authenticated;

create or replace function public.zameel_chat_messages(p_conversation uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare me uuid:=auth.uid(); result jsonb;
begin
 if me is null or not public.is_conversation_member(p_conversation,me) then raise exception 'conversation_membership_required';end if;
 select coalesce(jsonb_agg(q.row order by q.created_at,q.id),'[]'::jsonb) into result from (
 select m.id,m.created_at,
 jsonb_build_object('id',m.id,'content',case when d.message_id is null then m.content else 'تم حذف هذه الرسالة' end,
 'sender_id',m.sender_id,'created_at',m.created_at,'media_url',case when d.message_id is null then m.media_url end,
 'media_type',case when d.message_id is null then m.media_type end,'is_read',m.is_read,'delivered_at',m.delivered_at,'read_at',m.read_at,
 'deleted',d.message_id is not null,'likes',(select count(*) from public.zameel_message_likes l where l.message_id=m.id),
 'liked',exists(select 1 from public.zameel_message_likes l where l.message_id=m.id and l.user_id=me),
 'reply_to_id',m.reply_to_id,
 'reply_preview',(select case
     when dd.message_id is not null then 'تم حذف هذه الرسالة'
     when coalesce(rm.media_url,'')<>'' and coalesce(trim(rm.content),'')='' then '📎 مرفق'
     else left(rm.content,120) end
   from public.messages rm left join public.zameel_deleted_messages dd on dd.message_id=rm.id
   where rm.id=m.reply_to_id and rm.conversation_id=p_conversation),
 'reply_sender_id',(select rm.sender_id from public.messages rm where rm.id=m.reply_to_id and rm.conversation_id=p_conversation)) as row
 from public.messages m left join public.zameel_deleted_messages d on d.message_id=m.id
 where m.conversation_id=p_conversation and not exists(select 1 from public.zameel_hidden_messages h where h.message_id=m.id and h.user_id=me)
 order by m.created_at desc,m.id desc limit 300) q;
 return result;
end $$;
revoke all on function public.zameel_chat_messages(uuid) from public,anon;
grant execute on function public.zameel_chat_messages(uuid) to authenticated;

notify pgrst, 'reload schema';
commit;
