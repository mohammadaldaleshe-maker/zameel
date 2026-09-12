-- Zameel 032: real book listings and exchange-request workflow.
begin;

create table if not exists public.book_listings (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null constraint book_listings_owner_id_fkey references public.users(id) on delete cascade,
  title text not null check (char_length(title) between 1 and 180),
  author text not null default '', subject text not null default '',
  university text not null, college text not null, department text not null,
  offer_type text not null check (offer_type in ('sale','exchange','lend','donate')),
  book_condition text not null default '', description text not null default '',
  price_label text not null default '', status text not null default 'available'
    check (status in ('available','reserved','completed','withdrawn')),
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);

create table if not exists public.book_exchange_requests (
  id uuid primary key default gen_random_uuid(),
  listing_id uuid not null references public.book_listings(id) on delete cascade,
  requester_id uuid not null references public.users(id) on delete cascade,
  owner_id uuid not null references public.users(id) on delete cascade,
  offered_listing_id uuid references public.book_listings(id) on delete set null,
  status text not null default 'pending' check (status in ('pending','accepted','rejected','cancelled','completed')),
  created_at timestamptz not null default now(), responded_at timestamptz
);

create unique index if not exists book_exchange_one_pending_idx
on public.book_exchange_requests(listing_id,requester_id) where status='pending';

alter table public.book_listings enable row level security;
alter table public.book_exchange_requests enable row level security;
drop policy if exists book_listings_read on public.book_listings;
create policy book_listings_read on public.book_listings for select to authenticated using (true);
drop policy if exists book_listings_owner_insert on public.book_listings;
create policy book_listings_owner_insert on public.book_listings for insert to authenticated with check (owner_id=auth.uid());
drop policy if exists book_listings_owner_update on public.book_listings;
create policy book_listings_owner_update on public.book_listings for update to authenticated using (owner_id=auth.uid()) with check (owner_id=auth.uid());
drop policy if exists book_requests_members_read on public.book_exchange_requests;
create policy book_requests_members_read on public.book_exchange_requests for select to authenticated using (requester_id=auth.uid() or owner_id=auth.uid());

drop function if exists public.request_book_exchange(uuid,uuid);
create function public.request_book_exchange(target_listing_id uuid, offered_listing_id uuid default null)
returns uuid language plpgsql security definer set search_path=public set row_security=off as $$
declare me uuid:=auth.uid(); target public.book_listings; request_id uuid; requester_name text;
begin
  if me is null then raise exception 'not_authenticated'; end if;
  select * into target from public.book_listings where id=target_listing_id and status='available' for update;
  if target.id is null then raise exception 'listing_unavailable'; end if;
  if target.owner_id=me then raise exception 'own_listing'; end if;
  if target.offer_type='exchange' and not exists(select 1 from public.book_listings b where b.id=offered_listing_id and b.owner_id=me and b.status='available') then raise exception 'valid_offered_book_required'; end if;
  select coalesce(nullif(name,''),'زميل') into requester_name from public.users where id=me;
  insert into public.book_exchange_requests(listing_id,requester_id,owner_id,offered_listing_id)
  values(target_listing_id,me,target.owner_id,offered_listing_id) returning id into request_id;
  insert into public.notifications(user_id,actor_id,type,title_ar,title_en,body_ar,body_en,data,is_read)
  values(target.owner_id,me,'book_exchange_request','طلب كتاب جديد','New book request',requester_name||' أرسل طلباً على كتاب '||target.title,requester_name||' requested '||target.title,jsonb_build_object('request_id',request_id,'listing_id',target_listing_id),false);
  return request_id;
end $$;

drop function if exists public.get_incoming_book_requests();
create function public.get_incoming_book_requests()
returns table(request_id uuid, listing_title text, requester_name text, offered_title text, request_status text, created_at timestamptz)
language sql security definer set search_path=public set row_security=off as $$
 select r.id,l.title,coalesce(u.name,'زميل'),o.title,r.status,r.created_at
 from public.book_exchange_requests r join public.book_listings l on l.id=r.listing_id
 join public.users u on u.id=r.requester_id left join public.book_listings o on o.id=r.offered_listing_id
 where r.owner_id=auth.uid() order by r.created_at desc;
$$;

drop function if exists public.respond_book_exchange(uuid,boolean);
create function public.respond_book_exchange(target_request_id uuid, accept_request boolean)
returns void language plpgsql security definer set search_path=public set row_security=off as $$
declare r public.book_exchange_requests; owner_name text;
begin
 select * into r from public.book_exchange_requests where id=target_request_id and owner_id=auth.uid() and status='pending' for update;
 if r.id is null then raise exception 'pending_request_not_found'; end if;
 update public.book_exchange_requests set status=case when accept_request then 'accepted' else 'rejected' end,responded_at=now() where id=r.id;
 if accept_request then update public.book_listings set status='reserved',updated_at=now() where id=r.listing_id or id=r.offered_listing_id; end if;
 select coalesce(nullif(name,''),'زميل') into owner_name from public.users where id=auth.uid();
 insert into public.notifications(user_id,actor_id,type,title_ar,title_en,body_ar,body_en,data,is_read)
 values(r.requester_id,auth.uid(),'book_exchange_response',case when accept_request then 'تم قبول طلب الكتاب' else 'تم رفض طلب الكتاب' end,case when accept_request then 'Book request accepted' else 'Book request rejected' end,owner_name||case when accept_request then ' وافق على طلبك' else ' رفض طلبك' end,owner_name||case when accept_request then ' accepted your request' else ' rejected your request' end,jsonb_build_object('request_id',r.id,'listing_id',r.listing_id),false);
end $$;

revoke execute on function public.request_book_exchange(uuid,uuid),public.get_incoming_book_requests(),public.respond_book_exchange(uuid,boolean) from public,anon;
grant execute on function public.request_book_exchange(uuid,uuid),public.get_incoming_book_requests(),public.respond_book_exchange(uuid,boolean) to authenticated;
commit;
