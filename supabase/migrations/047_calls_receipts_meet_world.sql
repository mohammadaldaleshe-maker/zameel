-- Zameel 047: message receipts, reliable meet sessions and call diagnostics.
-- Run once after migration 046.
begin;

alter table public.messages add column if not exists delivered_at timestamptz;
alter table public.messages add column if not exists read_at timestamptz;
update public.messages set read_at=coalesce(read_at,created_at),delivered_at=coalesce(delivered_at,created_at)
where coalesce(is_read,false)=true;
create index if not exists messages_receipts_idx
on public.messages(conversation_id,sender_id,read_at,created_at desc);

create or replace function public.mark_conversation_delivered(target_conversation_id uuid)
returns integer language plpgsql security definer set search_path=public set row_security=off as $$
declare changed integer;
begin
 if auth.uid() is null or not exists(select 1 from public.conversation_members where conversation_id=target_conversation_id and user_id=auth.uid()) then
  raise exception 'conversation_membership_required';
 end if;
 update public.messages set delivered_at=coalesce(delivered_at,now())
 where conversation_id=target_conversation_id and sender_id<>auth.uid() and delivered_at is null;
 get diagnostics changed=row_count; return changed;
end $$;

create or replace function public.mark_conversation_read(target_conversation_id uuid)
returns integer language plpgsql security definer set search_path=public set row_security=off as $$
declare changed integer;
begin
 if auth.uid() is null or not exists(select 1 from public.conversation_members where conversation_id=target_conversation_id and user_id=auth.uid()) then
  raise exception 'conversation_membership_required';
 end if;
 update public.messages set delivered_at=coalesce(delivered_at,now()),read_at=coalesce(read_at,now()),is_read=true
 where conversation_id=target_conversation_id and sender_id<>auth.uid() and read_at is null;
 get diagnostics changed=row_count; return changed;
end $$;

alter table public.meet_colleague_requests add column if not exists meeting_lat double precision;
alter table public.meet_colleague_requests add column if not exists meeting_lng double precision;
alter table public.meet_colleague_requests add column if not exists requester_updated_at timestamptz;
alter table public.meet_colleague_requests add column if not exists recipient_updated_at timestamptz;
alter table public.meet_colleague_requests add column if not exists ended_at timestamptz;
alter table public.meet_colleague_requests add column if not exists ended_by uuid references public.users(id) on delete set null;
alter table public.meet_colleague_requests drop constraint if exists meet_colleague_requests_status_check;
alter table public.meet_colleague_requests add constraint meet_colleague_requests_status_check
check(status in('pending','accepted','declined','cancelled','completed','expired'));

create or replace function public.respond_meet_colleague(target_request_id uuid,accept_request boolean,my_lat double precision default null,my_lng double precision default null)
returns void language plpgsql security definer set search_path=public set row_security=off as $$
declare r public.meet_colleague_requests;
begin
 select * into r from public.meet_colleague_requests where id=target_request_id and recipient_id=auth.uid() and status='pending' and expires_at>now() for update;
 if r.id is null then raise exception 'meet_request_not_available'; end if;
 if accept_request and (my_lat is null or my_lng is null) then raise exception 'location_required_for_acceptance'; end if;
 update public.meet_colleague_requests set
  status=case when accept_request then 'accepted' else 'declined' end,
  recipient_lat=case when accept_request then my_lat else null end,
  recipient_lng=case when accept_request then my_lng else null end,
  requester_updated_at=case when accept_request then now() else requester_updated_at end,
  recipient_updated_at=case when accept_request then now() else recipient_updated_at end,
  meeting_lat=case when accept_request then (requester_lat+my_lat)/2 else null end,
  meeting_lng=case when accept_request then (requester_lng+my_lng)/2 else null end,
  responded_at=now()
 where id=r.id;
 insert into public.notifications(user_id,actor_id,type,title_ar,title_en,body_ar,body_en,data,is_read)
 values(r.requester_id,auth.uid(),case when accept_request then 'meet_colleague_accepted' else 'meet_colleague_declined' end,case when accept_request then 'تم قبول طلب اللقاء' else 'تم رفض طلب اللقاء' end,case when accept_request then 'Meeting request accepted' else 'Meeting request declined' end,case when accept_request then 'وافق زميلك وبدأت جلسة مشاركة الموقع.' else 'لم يوافق زميلك على طلب اللقاء.' end,case when accept_request then 'Your colleague accepted and temporary location sharing started.' else 'Your colleague declined the meeting request.' end,jsonb_build_object('meet_request_id',r.id,'conversation_id',r.conversation_id),false);
end $$;

create or replace function public.update_my_meet_location(target_request_id uuid,my_lat double precision,my_lng double precision)
returns void language plpgsql security definer set search_path=public set row_security=off as $$
declare r public.meet_colleague_requests;
begin
 select * into r from public.meet_colleague_requests where id=target_request_id and auth.uid() in(requester_id,recipient_id) and status='accepted' and expires_at>now() for update;
 if r.id is null then raise exception 'active_meet_not_found'; end if;
 if my_lat not between -90 and 90 or my_lng not between -180 and 180 then raise exception 'invalid_location'; end if;
 if auth.uid()=r.requester_id then
  update public.meet_colleague_requests set requester_lat=my_lat,requester_lng=my_lng,requester_updated_at=now() where id=r.id;
 else
  update public.meet_colleague_requests set recipient_lat=my_lat,recipient_lng=my_lng,recipient_updated_at=now() where id=r.id;
 end if;
end $$;

create or replace function public.end_meet_colleague(target_request_id uuid,complete_meet boolean default false)
returns void language plpgsql security definer set search_path=public set row_security=off as $$
declare r public.meet_colleague_requests;
begin
 select * into r from public.meet_colleague_requests where id=target_request_id and auth.uid() in(requester_id,recipient_id) and status in('pending','accepted') for update;
 if r.id is null then return; end if;
 update public.meet_colleague_requests set status=case when complete_meet then 'completed' else 'cancelled' end,ended_at=now(),ended_by=auth.uid(),responded_at=coalesce(responded_at,now()) where id=r.id;
 insert into public.notifications(user_id,actor_id,type,title_ar,title_en,body_ar,body_en,data,is_read)
 values(case when auth.uid()=r.requester_id then r.recipient_id else r.requester_id end,auth.uid(),'meet_colleague_ended','انتهت جلسة اللقاء','Meeting session ended','تم إيقاف مشاركة الموقع وإغلاق خريطة اللقاء.','Location sharing stopped and the meeting map was closed.',jsonb_build_object('meet_request_id',r.id,'conversation_id',r.conversation_id),false);
end $$;

drop function if exists public.get_active_meet_colleague(uuid);
create function public.get_active_meet_colleague(target_conversation_id uuid)
returns table(request_id uuid,requester_id uuid,recipient_id uuid,status text,requester_lat double precision,requester_lng double precision,recipient_lat double precision,recipient_lng double precision,meeting_lat double precision,meeting_lng double precision,requester_updated_at timestamptz,recipient_updated_at timestamptz,expires_at timestamptz)
language sql security definer set search_path=public set row_security=off as $$
 select m.id,m.requester_id,m.recipient_id,m.status,m.requester_lat,m.requester_lng,m.recipient_lat,m.recipient_lng,m.meeting_lat,m.meeting_lng,m.requester_updated_at,m.recipient_updated_at,m.expires_at
 from public.meet_colleague_requests m where m.conversation_id=target_conversation_id and auth.uid() in(m.requester_id,m.recipient_id) and m.status in('pending','accepted') and m.expires_at>now() order by m.created_at desc limit 1;
$$;

alter table public.direct_call_sessions add column if not exists connected_at timestamptz;
alter table public.direct_call_sessions add column if not exists failure_reason text;
alter table public.direct_call_sessions add column if not exists connection_attempts integer not null default 0;

create or replace function public.refund_zameel_ai_quota(target_user_id uuid)
returns void language sql security definer set search_path=public set row_security=off as $$
 update public.ai_daily_usage set request_count=greatest(0,request_count-1),updated_at=now()
 where user_id=target_user_id and usage_date=current_date;
$$;
revoke all on function public.refund_zameel_ai_quota(uuid) from public,anon,authenticated;
grant execute on function public.refund_zameel_ai_quota(uuid) to service_role;

revoke execute on function public.mark_conversation_delivered(uuid),public.mark_conversation_read(uuid),public.update_my_meet_location(uuid,double precision,double precision),public.end_meet_colleague(uuid,boolean),public.get_active_meet_colleague(uuid) from public,anon;
grant execute on function public.mark_conversation_delivered(uuid),public.mark_conversation_read(uuid),public.update_my_meet_location(uuid,double precision,double precision),public.end_meet_colleague(uuid,boolean),public.get_active_meet_colleague(uuid) to authenticated;

do $$ begin alter publication supabase_realtime add table public.messages; exception when duplicate_object then null; end $$;
do $$ begin alter publication supabase_realtime add table public.meet_colleague_requests; exception when duplicate_object then null; end $$;
commit;
