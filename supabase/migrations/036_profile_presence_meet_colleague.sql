-- Zameel 036: expanded profile, reciprocal presence privacy, and consent-based meet location.
-- Run after 035. Safe to execute more than once.
begin;

alter table public.users add column if not exists phone text not null default '';
alter table public.users add column if not exists show_online_status boolean not null default true;
alter table public.users add column if not exists last_seen_at timestamptz;

drop function if exists public.get_book_requests();
create function public.get_book_requests()
returns table(request_id uuid,listing_title text,requester_name text,owner_name text,requester_image text,requester_university text,
 requester_college text,initial_message text,offered_title text,request_status text,member_role text,created_at timestamptz)
language sql security definer set search_path=public set row_security=off as $$
 select r.id,l.title,coalesce(requester.name,'زميل'),coalesce(owner_user.name,'زميل'),coalesce(requester.profile_image,''),
 coalesce(requester.university,''),coalesce(requester.college,''),r.initial_message,o.title,r.status,
 case when r.owner_id=auth.uid() then 'owner' else 'requester' end,r.created_at
 from public.book_exchange_requests r join public.book_listings l on l.id=r.listing_id
 join public.users requester on requester.id=r.requester_id join public.users owner_user on owner_user.id=r.owner_id
 left join public.book_listings o on o.id=r.offered_listing_id
 where auth.uid() in(r.owner_id,r.requester_id) order by r.created_at desc;
$$;

create or replace function public.touch_my_presence()
returns void language sql security definer set search_path=public set row_security=off as $$
  update public.users set last_seen_at=now() where id=auth.uid() and show_online_status=true;
$$;

create or replace function public.get_colleague_presence()
returns table(user_id uuid,is_online boolean,last_seen_at timestamptz)
language sql security definer set search_path=public set row_security=off as $$
  select u.id,(u.show_online_status and u.last_seen_at>now()-interval '2 minutes'),
    case when u.show_online_status then u.last_seen_at else null end
  from public.users u
  where (select coalesce(show_online_status,true) from public.users where id=auth.uid())=true
    and u.show_online_status=true
    and exists(select 1 from public.friend_requests f where f.status='accepted'
      and ((f.sender_id=auth.uid() and f.receiver_id=u.id) or (f.receiver_id=auth.uid() and f.sender_id=u.id)));
$$;

create table if not exists public.meet_colleague_requests (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  requester_id uuid not null references public.users(id) on delete cascade,
  recipient_id uuid not null references public.users(id) on delete cascade,
  status text not null default 'pending' check(status in('pending','accepted','declined','cancelled','expired')),
  requester_lat double precision not null,
  requester_lng double precision not null,
  recipient_lat double precision,
  recipient_lng double precision,
  created_at timestamptz not null default now(),
  responded_at timestamptz,
  expires_at timestamptz not null default now()+interval '2 hours',
  check(requester_id<>recipient_id)
);
create index if not exists meet_colleague_conversation_idx on public.meet_colleague_requests(conversation_id,created_at desc);
alter table public.meet_colleague_requests enable row level security;
drop policy if exists meet_colleague_members_read on public.meet_colleague_requests;
create policy meet_colleague_members_read on public.meet_colleague_requests for select to authenticated
using(auth.uid() in(requester_id,recipient_id));

create or replace function public.request_meet_colleague(target_conversation_id uuid,target_recipient_id uuid,my_lat double precision,my_lng double precision)
returns uuid language plpgsql security definer set search_path=public set row_security=off as $$
declare me uuid:=auth.uid(); new_id uuid;
begin
 if me is null then raise exception 'not_authenticated'; end if;
 if not exists(select 1 from public.conversation_members where conversation_id=target_conversation_id and user_id=me)
   or not exists(select 1 from public.conversation_members where conversation_id=target_conversation_id and user_id=target_recipient_id)
 then raise exception 'conversation_membership_required'; end if;
 update public.meet_colleague_requests set status='expired' where conversation_id=target_conversation_id and status in('pending','accepted') and expires_at<=now();
 if exists(select 1 from public.meet_colleague_requests where conversation_id=target_conversation_id and status in('pending','accepted') and expires_at>now()) then
   raise exception 'active_meet_request_exists';
 end if;
 insert into public.meet_colleague_requests(conversation_id,requester_id,recipient_id,requester_lat,requester_lng)
 values(target_conversation_id,me,target_recipient_id,my_lat,my_lng) returning id into new_id;
 insert into public.notifications(user_id,actor_id,type,title_ar,title_en,body_ar,body_en,data,is_read)
 values(target_recipient_id,me,'meet_colleague_request','طلب «التقِ بزميل»','Meet a colleague request',
 'يريد زميلك مشاركة موقع مؤقت للالتقاء بك','Your colleague wants to share temporary locations to meet',
 jsonb_build_object('meet_request_id',new_id,'conversation_id',target_conversation_id),false);
 return new_id;
end $$;

create or replace function public.respond_meet_colleague(target_request_id uuid,accept_request boolean,my_lat double precision default null,my_lng double precision default null)
returns void language plpgsql security definer set search_path=public set row_security=off as $$
declare r public.meet_colleague_requests;
begin
 select * into r from public.meet_colleague_requests where id=target_request_id and recipient_id=auth.uid() and status='pending' and expires_at>now() for update;
 if r.id is null then raise exception 'meet_request_not_available'; end if;
 if accept_request and (my_lat is null or my_lng is null) then raise exception 'location_required_for_acceptance'; end if;
 update public.meet_colleague_requests set status=case when accept_request then 'accepted' else 'declined' end,
   recipient_lat=case when accept_request then my_lat else null end,recipient_lng=case when accept_request then my_lng else null end,responded_at=now()
 where id=r.id;
end $$;

create or replace function public.get_active_meet_colleague(target_conversation_id uuid)
returns table(request_id uuid,requester_id uuid,recipient_id uuid,status text,requester_lat double precision,requester_lng double precision,
 recipient_lat double precision,recipient_lng double precision,expires_at timestamptz)
language sql security definer set search_path=public set row_security=off as $$
 select m.id,m.requester_id,m.recipient_id,m.status,m.requester_lat,m.requester_lng,m.recipient_lat,m.recipient_lng,m.expires_at
 from public.meet_colleague_requests m where m.conversation_id=target_conversation_id and auth.uid() in(m.requester_id,m.recipient_id)
   and m.status in('pending','accepted') and m.expires_at>now() order by m.created_at desc limit 1;
$$;

create or replace function public.cancel_meet_colleague(target_request_id uuid)
returns void language sql security definer set search_path=public set row_security=off as $$
 update public.meet_colleague_requests set status='cancelled',responded_at=now()
 where id=target_request_id and auth.uid() in(requester_id,recipient_id) and status in('pending','accepted');
$$;

revoke execute on function public.get_book_requests(),public.touch_my_presence(),public.get_colleague_presence(),
 public.request_meet_colleague(uuid,uuid,double precision,double precision),public.respond_meet_colleague(uuid,boolean,double precision,double precision),
 public.get_active_meet_colleague(uuid),public.cancel_meet_colleague(uuid) from public,anon;
grant execute on function public.get_book_requests(),public.touch_my_presence(),public.get_colleague_presence(),
 public.request_meet_colleague(uuid,uuid,double precision,double precision),public.respond_meet_colleague(uuid,boolean,double precision,double precision),
 public.get_active_meet_colleague(uuid),public.cancel_meet_colleague(uuid) to authenticated;
commit;
