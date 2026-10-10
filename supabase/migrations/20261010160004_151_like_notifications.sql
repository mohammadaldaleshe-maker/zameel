begin;
create table if not exists public.zameel_like_notified(post_id uuid not null references public.posts(id) on delete cascade,actor_id uuid not null references public.users(id) on delete cascade,owner_id uuid not null references public.users(id) on delete cascade,primary key(post_id,actor_id,owner_id));
alter table public.zameel_like_notified enable row level security;
revoke all on public.zameel_like_notified from public,anon,authenticated;
insert into public.zameel_like_notified select distinct p.id,n.actor_id,n.user_id from public.notifications n join public.posts p on p.id::text=n.data->>'post_id' where n.type in ('like','post_like') and n.actor_id is not null on conflict do nothing;
insert into public.zameel_like_notified select distinct l.post_id,l.user_id,p.user_id from public.likes l join public.posts p on p.id=l.post_id where l.user_id<>p.user_id on conflict do nothing;
create or replace function public.notify_on_like()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  owner_id uuid;
  actor_name text;
begin
  select p.user_id into owner_id from public.posts p where p.id = new.post_id;
  if owner_id is null or owner_id = new.user_id then return new; end if;
  insert into public.zameel_like_notified(post_id,actor_id,owner_id) values(new.post_id,new.user_id,owner_id) on conflict do nothing;
  if not found then return new;end if;
  select coalesce(name, 'زميل') into actor_name from public.users where id = new.user_id;

  insert into public.notifications(
    user_id, actor_id, type, title_ar, title_en, body_ar, body_en, data
  ) values (
    owner_id,
    new.user_id,
    'post_like',
    'إعجاب جديد',
    'New like',
    actor_name || ' أعجب بمنشورك',
    actor_name || ' liked your post',
    jsonb_build_object('post_id', new.post_id)
  );
  return new;
end;
$$;


create or replace function public.zameel_cancel_like_alert() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if old.type in ('like','post_like') then
 insert into public.notifications(user_id,type,title_ar,title_en,body_ar,body_en,data) values(old.user_id,'notification_cancel','','','','',jsonb_build_object('cancel_notification_id',old.id));
 end if;return old;
end $$;
revoke all on function public.zameel_cancel_like_alert() from public,anon,authenticated;
drop trigger if exists zameel_cancel_like_alert on public.notifications;
create trigger zameel_cancel_like_alert after delete on public.notifications for each row execute function public.zameel_cancel_like_alert();
create or replace function public.zameel_dispatch_cancel_alert() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if exists(select 1 from public.notifications where id=new.notification_id and type='notification_cancel') then perform public.zameel_dispatch_call_push_142(jsonb_build_object('notification_id',new.notification_id));end if;return new;
end $$;
revoke all on function public.zameel_dispatch_cancel_alert() from public,anon,authenticated;
drop trigger if exists zameel_dispatch_cancel_alert on public.push_notification_queue;
create trigger zameel_dispatch_cancel_alert after insert on public.push_notification_queue for each row execute function public.zameel_dispatch_cancel_alert();
commit;
