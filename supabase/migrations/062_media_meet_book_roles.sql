-- Zameel 062: expose book-operation roles to the client.
-- Media caching and Meet lobby changes are client-side and need no DB schema.
begin;

drop function if exists public.get_book_requests();
create function public.get_book_requests()
returns table(
  request_id uuid,
  listing_title text,
  requester_name text,
  owner_name text,
  requester_image text,
  requester_university text,
  requester_college text,
  initial_message text,
  offered_title text,
  request_status text,
  listing_offer_type text,
  member_role text,
  created_at timestamptz
)
language sql
security definer
set search_path=public
set row_security=off
as $$
  select
    r.id,
    l.title,
    coalesce(requester.name,'زميل'),
    coalesce(owner_user.name,'زميل'),
    coalesce(requester.profile_image,''),
    coalesce(requester.university,''),
    coalesce(requester.college,''),
    r.initial_message,
    o.title,
    r.status,
    coalesce(l.offer_type,'sale'),
    case when r.owner_id=auth.uid() then 'owner' else 'requester' end,
    r.created_at
  from public.book_exchange_requests r
  join public.book_listings l on l.id=r.listing_id
  join public.users requester on requester.id=r.requester_id
  join public.users owner_user on owner_user.id=r.owner_id
  left join public.book_listings o on o.id=r.offered_listing_id
  where auth.uid() in(r.owner_id,r.requester_id)
  order by r.created_at desc;
$$;

revoke execute on function public.get_book_requests() from public,anon;
grant execute on function public.get_book_requests() to authenticated;

commit;
