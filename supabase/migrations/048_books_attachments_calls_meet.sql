-- Zameel 048: accepted-book chat, private attachments, reliable contact calls,
-- and one-session-only colleague meeting maps. Run after migration 047.
begin;

create table if not exists public.book_request_conversations (
  request_id uuid primary key references public.book_exchange_requests(id) on delete cascade,
  conversation_id uuid not null unique references public.conversations(id) on delete cascade,
  created_at timestamptz not null default now()
);
alter table public.book_request_conversations enable row level security;
drop policy if exists book_request_conversations_members_read on public.book_request_conversations;
create policy book_request_conversations_members_read on public.book_request_conversations
for select to authenticated using (
  exists (
    select 1 from public.book_exchange_requests r
    where r.id=request_id and auth.uid() in (r.owner_id,r.requester_id)
      and r.status in ('accepted','completed')
  )
);
grant select on public.book_request_conversations to authenticated;

create or replace function public.get_or_create_book_conversation(target_request_id uuid)
returns table(conversation_id uuid,partner_id uuid,partner_name text,partner_image text,contact_phone text)
language plpgsql security definer set search_path=public set row_security=off as $$
declare
  me uuid:=auth.uid(); r public.book_exchange_requests; cid uuid; other_id uuid;
begin
  if me is null then raise exception 'not_authenticated'; end if;
  select * into r from public.book_exchange_requests
   where id=target_request_id and me in(owner_id,requester_id)
     and status in('accepted','completed') for update;
  if r.id is null then raise exception 'accepted_request_required'; end if;
  select b.conversation_id into cid from public.book_request_conversations b where b.request_id=r.id;
  if cid is null then
    insert into public.conversations(is_group,created_by) values(false,r.owner_id) returning id into cid;
    insert into public.conversation_members(conversation_id,user_id)
      values(cid,r.owner_id),(cid,r.requester_id) on conflict do nothing;
    insert into public.book_request_conversations(request_id,conversation_id) values(r.id,cid);
    if coalesce(trim(r.initial_message),'')<>'' then
      insert into public.messages(conversation_id,sender_id,content,media_url,media_type,is_read)
      values(cid,r.requester_id,left(trim(r.initial_message),5000),null,null,false);
    end if;
  end if;
  other_id:=case when me=r.owner_id then r.requester_id else r.owner_id end;
  return query select cid,u.id,coalesce(nullif(u.name,''),'زميل'),coalesce(u.profile_image,''),coalesce(c.phone,'')
    from public.users u
    left join public.book_listing_contacts c on c.listing_id=r.listing_id
    where u.id=other_id;
end $$;
revoke execute on function public.get_or_create_book_conversation(uuid) from public,anon;
grant execute on function public.get_or_create_book_conversation(uuid) to authenticated;

create table if not exists public.chat_attachments (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  message_id uuid not null unique references public.messages(id) on delete cascade,
  uploader_id uuid not null references public.users(id) on delete cascade,
  object_path text not null unique,
  file_name text not null,
  file_size bigint not null check(file_size between 1 and 15728640),
  media_type text not null check(media_type in('image','file')),
  created_at timestamptz not null default now()
);
create index if not exists chat_attachments_conversation_idx on public.chat_attachments(conversation_id,created_at desc);
alter table public.chat_attachments enable row level security;
drop policy if exists chat_attachments_members_read on public.chat_attachments;
create policy chat_attachments_members_read on public.chat_attachments for select to authenticated
using(exists(select 1 from public.conversation_members m where m.conversation_id=chat_attachments.conversation_id and m.user_id=auth.uid()));
drop policy if exists chat_attachments_uploader_insert on public.chat_attachments;
create policy chat_attachments_uploader_insert on public.chat_attachments for insert to authenticated
with check(uploader_id=auth.uid() and exists(select 1 from public.conversation_members m where m.conversation_id=chat_attachments.conversation_id and m.user_id=auth.uid()));
drop policy if exists chat_attachments_uploader_delete on public.chat_attachments;
create policy chat_attachments_uploader_delete on public.chat_attachments for delete to authenticated using(uploader_id=auth.uid());
grant select,insert,delete on public.chat_attachments to authenticated;

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('chat_attachments','chat_attachments',false,15728640,null)
on conflict(id) do update set public=false,file_size_limit=15728640;
drop policy if exists zameel_chat_upload on storage.objects;
create policy zameel_chat_upload on storage.objects for insert to authenticated
with check(bucket_id='chat_attachments' and (storage.foldername(name))[1]=auth.uid()::text);
drop policy if exists zameel_chat_read on storage.objects;
create policy zameel_chat_read on storage.objects for select to authenticated
using(bucket_id='chat_attachments' and (
  (storage.foldername(name))[1]=auth.uid()::text or exists(select 1 from public.chat_attachments a join public.conversation_members m on m.conversation_id=a.conversation_id where a.object_path=name and m.user_id=auth.uid())
));
drop policy if exists zameel_chat_delete on storage.objects;
create policy zameel_chat_delete on storage.objects for delete to authenticated
using(bucket_id='chat_attachments' and (storage.foldername(name))[1]=auth.uid()::text);

-- Matching returns only hashes supplied by the signed-in user. Friendship is
-- deliberately not required; blocks and the receiver's call preference remain enforced.
create or replace function public.match_registered_contacts(contact_hashes text[])
returns table(user_id uuid,name text,profile_image text,phone_hash text,allow_calls boolean)
language sql stable security definer set search_path=public set row_security=off as $$
 select u.id,coalesce(nullif(u.name,''),'زميل'),u.profile_image,u.phone_hash,coalesce(u.allow_calls,true)
 from public.users u
 where auth.uid() is not null and u.id<>auth.uid() and u.phone_hash is not null
   and u.phone_hash=any(coalesce(contact_hashes,array[]::text[]))
   and not exists(select 1 from public.user_blocks b where (b.blocker_id=auth.uid() and b.blocked_id=u.id) or (b.blocker_id=u.id and b.blocked_id=auth.uid()));
$$;
revoke execute on function public.match_registered_contacts(text[]) from public,anon;
grant execute on function public.match_registered_contacts(text[]) to authenticated;

-- Closing from either device makes the old request terminal. A future map can
-- only be opened through a newly created request and fresh consent.
create or replace function public.end_meet_colleague(target_request_id uuid,complete_meet boolean default false)
returns void language plpgsql security definer set search_path=public set row_security=off as $$
declare r public.meet_colleague_requests;
begin
 select * into r from public.meet_colleague_requests where id=target_request_id and auth.uid() in(requester_id,recipient_id) and status in('pending','accepted') for update;
 if r.id is null then return; end if;
 update public.meet_colleague_requests set status=case when complete_meet then 'completed' else 'cancelled' end,ended_at=now(),ended_by=auth.uid(),responded_at=coalesce(responded_at,now()) where id=r.id;
 insert into public.notifications(user_id,actor_id,type,title_ar,title_en,body_ar,body_en,data,is_read)
 values(case when auth.uid()=r.requester_id then r.recipient_id else r.requester_id end,auth.uid(),'meet_colleague_ended','انتهت جلسة اللقاء','Meeting session ended','أغلق زميلك خريطة اللقاء. يتطلب فتحها طلبًا جديدًا وموافقة جديدة.','Your colleague closed the meeting map. Opening it again requires a new request and consent.',jsonb_build_object('meet_request_id',r.id,'conversation_id',r.conversation_id),false);
end $$;

do $$ begin alter publication supabase_realtime add table public.book_request_conversations; exception when duplicate_object then null; end $$;
commit;
