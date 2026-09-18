-- Zameel 034: simplified reservation, My Library, deduplication and Knowledge Ambassador.
-- Run after 033. Idempotent and safe to execute again.
begin;

alter table public.book_exchange_requests add column if not exists initial_message text not null default '';

create table if not exists public.user_book_library (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  listing_id uuid references public.book_listings(id) on delete set null,
  title text not null check (char_length(trim(title)) between 1 and 180),
  category text not null check (category in ('owned','read','added','sold','exchanged','donated','loaned','borrowed')),
  operation_completed boolean not null default false,
  created_at timestamptz not null default now(),
  unique(user_id, listing_id, category)
);
alter table public.user_book_library enable row level security;
drop policy if exists user_book_library_self on public.user_book_library;
create policy user_book_library_self on public.user_book_library for all to authenticated
using(user_id=auth.uid()) with check(user_id=auth.uid());

-- One active copy of the same book per owner. Normalization ignores spaces/case.
with duplicates as (
  select id,row_number() over(partition by owner_id,lower(regexp_replace(trim(title),'\s+','','g')),
    lower(regexp_replace(trim(author),'\s+','','g')) order by created_at desc,id desc) as position
  from public.book_listings where status in ('available','reserved')
)
update public.book_listings set status='withdrawn',updated_at=now()
where id in(select id from duplicates where position>1);
create unique index if not exists book_listing_owner_active_dedup_idx
on public.book_listings(owner_id, lower(regexp_replace(trim(title),'\s+','','g')), lower(regexp_replace(trim(author),'\s+','','g')))
where status in ('available','reserved');

create or replace function public.request_book_simple(target_listing_id uuid, initial_message text)
returns uuid language plpgsql security definer set search_path=public set row_security=off as $$
declare me uuid:=auth.uid(); target public.book_listings; request_id uuid; requester_name text;
begin
  if me is null then raise exception 'not_authenticated'; end if;
  if coalesce(trim(request_book_simple.initial_message),'')='' then raise exception 'initial_message_required'; end if;
  select * into target from public.book_listings where id=target_listing_id and status='available' for update;
  if target.id is null then raise exception 'listing_unavailable'; end if;
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
  if exists(select 1 from public.book_exchange_requests where listing_id=target.id and requester_id=me and status='accepted') then
    raise exception 'request_already_accepted';
  end if;
  insert into public.book_exchange_requests(listing_id,requester_id,owner_id,initial_message)
  values(target.id,me,target.owner_id,left(trim(request_book_simple.initial_message),1500)) returning id into request_id;
  select coalesce(nullif(name,''),'زميل') into requester_name from public.users where id=me;
  insert into public.notifications(user_id,actor_id,type,title_ar,title_en,body_ar,body_en,data,is_read)
  values(target.owner_id,me,'book_exchange_request','طلب حجز كتاب','Book reservation request',
    requester_name||' يريد حجز كتاب '||target.title,requester_name||' wants to reserve '||target.title,
    jsonb_build_object('request_id',request_id,'listing_id',target.id),false);
  return request_id;
end $$;

create or replace function public.respond_book_exchange(target_request_id uuid, accept_request boolean)
returns void language plpgsql security definer set search_path=public set row_security=off as $$
declare r public.book_exchange_requests; owner_name text;
begin
 select * into r from public.book_exchange_requests where id=target_request_id and owner_id=auth.uid() and status='pending' for update;
 if r.id is null then raise exception 'pending_request_not_found'; end if;
 update public.book_exchange_requests set status=case when accept_request then 'accepted' else 'rejected' end,responded_at=now() where id=r.id;
 if accept_request then
   update public.book_listings set status='reserved',updated_at=now() where id=r.listing_id;
   update public.book_exchange_requests set status='cancelled',responded_at=now()
     where listing_id=r.listing_id and status='pending' and id<>r.id;
   insert into public.book_exchange_messages(request_id,sender_id,message_text)
     values(r.id,r.requester_id,r.initial_message);
 end if;
 select coalesce(nullif(name,''),'زميل') into owner_name from public.users where id=auth.uid();
 insert into public.notifications(user_id,actor_id,type,title_ar,title_en,body_ar,body_en,data,is_read)
 values(r.requester_id,auth.uid(),'book_exchange_response',case when accept_request then 'تم قبول حجز الكتاب' else 'تم رفض حجز الكتاب' end,
 case when accept_request then 'Book reservation accepted' else 'Book reservation rejected' end,
 owner_name||case when accept_request then ' وافق على الحجز؛ افتح محادثة الكتاب' else ' رفض الحجز' end,
 owner_name||case when accept_request then ' accepted the reservation; open the book chat' else ' rejected it' end,
 jsonb_build_object('request_id',r.id,'listing_id',r.listing_id),false);
end $$;

drop function if exists public.get_book_requests();
create function public.get_book_requests()
returns table(request_id uuid,listing_title text,requester_name text,requester_image text,requester_university text,
 requester_college text,initial_message text,offered_title text,request_status text,member_role text,created_at timestamptz)
language sql security definer set search_path=public set row_security=off as $$
 select r.id,l.title,coalesce(u.name,'زميل'),coalesce(u.profile_image,''),coalesce(u.university,''),coalesce(u.college,''),
 r.initial_message,o.title,r.status,case when r.owner_id=auth.uid() then 'owner' else 'requester' end,r.created_at
 from public.book_exchange_requests r join public.book_listings l on l.id=r.listing_id
 join public.users u on u.id=r.requester_id left join public.book_listings o on o.id=r.offered_listing_id
 where auth.uid() in(r.owner_id,r.requester_id) order by r.created_at desc;
$$;

create or replace function public.complete_book_exchange(target_request_id uuid)
returns void language plpgsql security definer set search_path=public set row_security=off as $$
declare r public.book_exchange_requests; l public.book_listings; owner_category text; requester_category text;
begin
 select * into r from public.book_exchange_requests where id=target_request_id and auth.uid() in(owner_id,requester_id) and status='accepted' for update;
 if r.id is null then raise exception 'accepted_request_required'; end if;
 select * into l from public.book_listings where id=r.listing_id;
 owner_category:=case l.offer_type when 'sale' then 'sold' when 'exchange' then 'exchanged' when 'lend' then 'loaned' else 'donated' end;
 requester_category:=case l.offer_type when 'lend' then 'borrowed' else 'owned' end;
 update public.book_exchange_requests set status='completed',responded_at=now() where id=r.id;
 update public.book_listings set status='completed',updated_at=now() where id=r.listing_id;
 insert into public.user_book_library(user_id,listing_id,title,category,operation_completed)
 values(r.owner_id,l.id,l.title,owner_category,true),(r.requester_id,l.id,l.title,requester_category,true)
 on conflict(user_id,listing_id,category) do update set operation_completed=true;
end $$;

create or replace function public.get_my_book_library()
returns table(entry_id uuid,title text,category text,operation_completed boolean,created_at timestamptz)
language sql security definer set search_path=public set row_security=off as $$
 select id,title,category,operation_completed,created_at from public.user_book_library
 where user_id=auth.uid() order by created_at desc;
$$;

create or replace function public.get_my_book_library_summary()
returns table(completed_operations bigint,title_label text)
language sql security definer set search_path=public set row_security=off as $$
 select count(*) filter(where operation_completed),
 case when count(*) filter(where operation_completed)>=100 then 'سفير المعرفة' else '' end
 from public.user_book_library where user_id=auth.uid();
$$;

create or replace function public.add_personal_book(book_title text,is_read boolean default false)
returns uuid language plpgsql security definer set search_path=public set row_security=off as $$
declare new_id uuid;
begin
 if auth.uid() is null then raise exception 'not_authenticated'; end if;
 if coalesce(trim(book_title),'')='' then raise exception 'book_title_required'; end if;
 if exists(select 1 from public.user_book_library where user_id=auth.uid() and lower(trim(title))=lower(trim(book_title)) and category=case when is_read then 'read' else 'owned' end) then raise exception 'book_already_added'; end if;
 insert into public.user_book_library(user_id,title,category) values(auth.uid(),trim(book_title),case when is_read then 'read' else 'owned' end) returning id into new_id;
 return new_id;
end $$;

create or replace function public.remove_my_library_book(target_entry_id uuid)
returns void language plpgsql security definer set search_path=public set row_security=off as $$
begin
 delete from public.user_book_library where id=target_entry_id and user_id=auth.uid() and operation_completed=false;
 if not found then raise exception 'entry_not_removable'; end if;
end $$;

create or replace function public.withdraw_my_book_listing(target_listing_id uuid)
returns void language plpgsql security definer set search_path=public set row_security=off as $$
begin
 update public.book_listings set status='withdrawn',updated_at=now()
 where id=target_listing_id and owner_id=auth.uid() and status='available';
 if not found then raise exception 'listing_not_removable'; end if;
end $$;

revoke execute on function public.request_book_simple(uuid,text),public.get_book_requests(),public.complete_book_exchange(uuid),
 public.get_my_book_library(),public.get_my_book_library_summary(),public.add_personal_book(text,boolean),public.remove_my_library_book(uuid),public.withdraw_my_book_listing(uuid) from public,anon;
grant execute on function public.request_book_simple(uuid,text),public.get_book_requests(),public.complete_book_exchange(uuid),
 public.get_my_book_library(),public.get_my_book_library_summary(),public.add_personal_book(text,boolean),public.remove_my_library_book(uuid),public.withdraw_my_book_listing(uuid) to authenticated;
commit;
