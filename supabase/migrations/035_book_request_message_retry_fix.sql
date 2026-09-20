-- Zameel 035: allow a student to edit/resend the message of an existing pending reservation.
-- Run after 034. Safe to execute more than once.
begin;

create or replace function public.request_book_simple(target_listing_id uuid, initial_message text)
returns uuid language plpgsql security definer set search_path=public set row_security=off as $$
declare me uuid:=auth.uid(); target public.book_listings; request_id uuid; requester_name text;
begin
  if me is null then raise exception 'not_authenticated'; end if;
  if coalesce(trim(request_book_simple.initial_message),'')='' then raise exception 'initial_message_required'; end if;

  select * into target from public.book_listings where id=target_listing_id for update;
  if target.id is null or target.status not in ('available','reserved') then raise exception 'listing_unavailable'; end if;
  if target.owner_id=me then raise exception 'own_listing'; end if;

  select id into request_id from public.book_exchange_requests
   where listing_id=target.id and requester_id=me and status='pending'
   order by created_at desc limit 1 for update;

  if request_id is not null then
    update public.book_exchange_requests
       set initial_message=left(trim(request_book_simple.initial_message),1500), created_at=now()
     where id=request_id;
    return request_id;
  end if;

  select id into request_id from public.book_exchange_requests
   where listing_id=target.id and requester_id=me and status='accepted'
   order by created_at desc limit 1;
  if request_id is not null then
    insert into public.book_exchange_messages(request_id,sender_id,message_text)
    values(request_id,me,left(trim(request_book_simple.initial_message),1500));
    return request_id;
  end if;

  if target.status<>'available' then raise exception 'listing_reserved'; end if;
  insert into public.book_exchange_requests(listing_id,requester_id,owner_id,initial_message)
  values(target.id,me,target.owner_id,left(trim(request_book_simple.initial_message),1500)) returning id into request_id;

  select coalesce(nullif(name,''),'زميل') into requester_name from public.users where id=me;
  insert into public.notifications(user_id,actor_id,type,title_ar,title_en,body_ar,body_en,data,is_read)
  values(target.owner_id,me,'book_exchange_request','طلب حجز كتاب','Book reservation request',
    requester_name||' يريد حجز كتاب '||target.title,requester_name||' wants to reserve '||target.title,
    jsonb_build_object('request_id',request_id,'listing_id',target.id),false);
  return request_id;
end $$;

revoke execute on function public.request_book_simple(uuid,text) from public,anon;
grant execute on function public.request_book_simple(uuid,text) to authenticated;
commit;
