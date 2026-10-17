-- 171: notifications around joining a group.
--  * a join request to a private group  -> the owner is told ("طلب انضمام جديد")
--  * the owner accepts / rejects         -> the requester is told
--  * somebody joins a public group       -> the owner is told ("انضم عضو جديد")
-- Triggers (not RPC edits) so every existing and future join path is covered.
-- Blocked users never notify each other; repeats within an hour are dropped.
begin;

create or replace function public.zameel_notify_group_join_request171()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  grp record;
  who text;
begin
  select g.id, g.name, g.owner_id into grp from public.community_groups g where g.id = new.group_id;
  if grp.id is null then return new; end if;

  if new.status = 'pending' and (tg_op = 'INSERT' or old.status is distinct from 'pending') then
    if grp.owner_id = new.user_id then return new; end if;
    if exists(select 1 from public.user_blocks b
              where (b.blocker_id = grp.owner_id and b.blocked_id = new.user_id)
                 or (b.blocker_id = new.user_id and b.blocked_id = grp.owner_id)) then
      return new;
    end if;
    if exists(select 1 from public.notifications n
              where n.user_id = grp.owner_id and n.actor_id = new.user_id
                and n.type = 'group_join_request' and n.data->>'group_id' = grp.id::text
                and n.created_at > now() - interval '1 hour') then
      return new;
    end if;
    select coalesce(nullif(trim(u.name), ''), 'زميل') into who from public.users u where u.id = new.user_id;
    insert into public.notifications(user_id, actor_id, type, title_ar, title_en, body_ar, body_en, data, is_read)
    values (grp.owner_id, new.user_id, 'group_join_request',
            'طلب انضمام جديد', 'New join request',
            '«' || coalesce(who, 'زميل') || '» يطلب الانضمام إلى مجموعة «' || grp.name || '»',
            '"' || coalesce(who, 'A user') || '" asked to join the group "' || grp.name || '"',
            jsonb_build_object('type', 'group_join_request', 'group_id', grp.id,
                               'group_name', grp.name, 'request_id', new.id, 'user_id', new.user_id),
            false);

  elsif tg_op = 'UPDATE' and old.status = 'pending' and new.status in ('accepted', 'rejected') then
    insert into public.notifications(user_id, actor_id, type, title_ar, title_en, body_ar, body_en, data, is_read)
    values (new.user_id, grp.owner_id,
            case when new.status = 'accepted' then 'group_join_accepted' else 'group_join_rejected' end,
            case when new.status = 'accepted' then 'تم قبول طلبك' else 'تم رفض طلبك' end,
            case when new.status = 'accepted' then 'Request accepted' else 'Request declined' end,
            case when new.status = 'accepted'
                 then 'تم قبول طلب انضمامك إلى مجموعة «' || grp.name || '»'
                 else 'تم رفض طلب انضمامك إلى مجموعة «' || grp.name || '»' end,
            case when new.status = 'accepted'
                 then 'Your request to join "' || grp.name || '" was accepted'
                 else 'Your request to join "' || grp.name || '" was declined' end,
            jsonb_build_object('type', case when new.status = 'accepted' then 'group_join_accepted' else 'group_join_rejected' end,
                               'group_id', grp.id, 'group_name', grp.name),
            false);
  end if;
  return new;
end;
$$;
revoke all on function public.zameel_notify_group_join_request171() from public, anon, authenticated;
drop trigger if exists zameel_group_join_request_notify171 on public.community_group_join_requests;
create trigger zameel_group_join_request_notify171
after insert or update of status on public.community_group_join_requests
for each row execute function public.zameel_notify_group_join_request171();

create or replace function public.zameel_notify_group_member_joined171()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  grp record;
  who text;
begin
  select g.id, g.name, g.owner_id, g.is_private into grp from public.community_groups g where g.id = new.group_id;
  if grp.id is null or grp.is_private or grp.owner_id = new.user_id then return new; end if;
  if exists(select 1 from public.user_blocks b
            where (b.blocker_id = grp.owner_id and b.blocked_id = new.user_id)
               or (b.blocker_id = new.user_id and b.blocked_id = grp.owner_id)) then
    return new;
  end if;
  if exists(select 1 from public.notifications n
            where n.user_id = grp.owner_id and n.actor_id = new.user_id
              and n.type = 'group_member_joined' and n.data->>'group_id' = grp.id::text
              and n.created_at > now() - interval '1 hour') then
    return new;
  end if;
  select coalesce(nullif(trim(u.name), ''), 'زميل') into who from public.users u where u.id = new.user_id;
  insert into public.notifications(user_id, actor_id, type, title_ar, title_en, body_ar, body_en, data, is_read)
  values (grp.owner_id, new.user_id, 'group_member_joined',
          'انضم عضو جديد', 'New member',
          '«' || coalesce(who, 'زميل') || '» انضم إلى مجموعة «' || grp.name || '»',
          '"' || coalesce(who, 'A user') || '" joined the group "' || grp.name || '"',
          jsonb_build_object('type', 'group_member_joined', 'group_id', grp.id,
                             'group_name', grp.name, 'user_id', new.user_id),
          false);
  return new;
end;
$$;
revoke all on function public.zameel_notify_group_member_joined171() from public, anon, authenticated;
drop trigger if exists zameel_group_member_joined171 on public.community_group_members;
create trigger zameel_group_member_joined171
after insert on public.community_group_members
for each row execute function public.zameel_notify_group_member_joined171();

commit;
