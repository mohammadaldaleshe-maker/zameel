-- 166: Groups - invitations, invite link, member removal, richer chat.
--   * SECURITY FIX: the group message read/insert policies compared a member row
--     with itself (gm.group_id=group_id resolves to gm.group_id), so any member of
--     ANY group could read or write the messages of EVERY group. They now compare
--     with the message's own group.
--   * Members can invite colleagues (in-app invitation + notification) and share
--     an invite link; the invited person sees only the group card until accepting.
--   * The owner can remove a member (the member cannot rejoin on his own; the
--     owner can invite him again).
--   * Group chat messages may carry one image, video or voice note (private
--     Storage bucket group_media, members only).
-- Everything is additive and idempotent; existing data and functions keep working.

alter table public.community_groups add column if not exists invite_code text;
create unique index if not exists community_groups_invite_code_166_idx
  on public.community_groups(invite_code) where invite_code is not null;

create table if not exists public.community_group_bans (
  group_id uuid not null references public.community_groups(id) on delete cascade,
  user_id uuid not null references public.users(id) on delete cascade,
  banned_by uuid not null references public.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (group_id, user_id)
);
alter table public.community_group_bans enable row level security;
revoke all on table public.community_group_bans from public, anon, authenticated;

create table if not exists public.community_group_invitations (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.community_groups(id) on delete cascade,
  inviter_id uuid not null references public.users(id) on delete cascade,
  invitee_id uuid not null references public.users(id) on delete cascade,
  status text not null default 'pending' check (status in ('pending','accepted','declined','cancelled')),
  created_at timestamptz not null default now(),
  responded_at timestamptz,
  check (inviter_id <> invitee_id)
);
create unique index if not exists community_group_invitations_pending_166_idx
  on public.community_group_invitations(group_id, invitee_id) where status='pending';
create index if not exists community_group_invitations_invitee_166_idx
  on public.community_group_invitations(invitee_id, status, created_at desc);
create index if not exists community_group_invitations_inviter_166_idx
  on public.community_group_invitations(inviter_id, created_at desc);
alter table public.community_group_invitations enable row level security;
revoke all on table public.community_group_invitations from public, anon, authenticated;

alter table public.community_group_messages add column if not exists media_url text;
alter table public.community_group_messages add column if not exists media_type text;
do $$ begin
  alter table public.community_group_messages add constraint community_group_messages_media_type_166
    check (media_type is null or media_type in ('image','video','audio'));
exception when duplicate_object then null; end $$;
do $$ begin
  alter table public.community_group_messages add constraint community_group_messages_media_pair_166
    check ((media_url is null) = (media_type is null));
exception when duplicate_object then null; end $$;

-- Message policies, now bound to the message's own group.
drop policy if exists community_group_messages_read_members on public.community_group_messages;
create policy community_group_messages_read_members on public.community_group_messages
for select to authenticated using (
  exists(select 1 from public.community_group_members gm
         where gm.group_id=community_group_messages.group_id and gm.user_id=auth.uid())
);
drop policy if exists community_group_messages_insert_members on public.community_group_messages;
create policy community_group_messages_insert_members on public.community_group_messages
for insert to authenticated with check (
  user_id=auth.uid()
  and (media_url is null or media_url like (auth.uid()::text||'/'||group_id::text||'/%'))
  and exists(select 1 from public.community_group_members gm
             where gm.group_id=community_group_messages.group_id and gm.user_id=auth.uid())
);

-- Message feed (with the existing edited_at) plus the attachment columns.
create or replace function public.get_community_group_messages_155(target_group_id uuid)
returns setof jsonb language sql security invoker stable set search_path=public,pg_temp as $body$
select to_jsonb(original)
       ||jsonb_build_object('edited_at',m.edited_at,'media_url',m.media_url,'media_type',m.media_type)
from public.get_community_group_messages(target_group_id) original
join public.community_group_messages m on m.id=original.id;
$body$;
revoke all on function public.get_community_group_messages_155(uuid) from public, anon;
grant execute on function public.get_community_group_messages_155(uuid) to authenticated;

-- Joining: a removed member cannot rejoin alone; an invited person joins a private
-- group directly (a member already vouched for him).
create or replace function public.join_community_group(target_group_id uuid)
returns text language plpgsql security definer set search_path=public set row_security=off as $$
declare me uuid:=auth.uid(); target public.community_groups; invited uuid;
begin
  if me is null then raise exception 'not_authenticated'; end if;
  select * into target from public.community_groups where id=target_group_id;
  if target.id is null then raise exception 'group_not_found'; end if;
  if exists(select 1 from public.community_group_members m where m.group_id=target_group_id and m.user_id=me) then
    return 'joined';
  end if;
  if exists(select 1 from public.community_group_bans b where b.group_id=target_group_id and b.user_id=me) then
    raise exception 'removed_from_group';
  end if;
  if target.is_private then
    select i.id into invited from public.community_group_invitations i
      where i.group_id=target_group_id and i.invitee_id=me and i.status='pending' limit 1;
    if invited is null then
      insert into public.community_group_join_requests(group_id,user_id,status,created_at,responded_at)
      values(target_group_id,me,'pending',now(),null)
      on conflict(group_id,user_id) do update
        set status='pending', created_at=now(), responded_at=null;
      return 'requested';
    end if;
    update public.community_group_invitations set status='accepted',responded_at=now() where id=invited;
  end if;
  insert into public.community_group_members(group_id,user_id,role)
  values(target_group_id,me,'member') on conflict do nothing;
  return 'joined';
end $$;

create or replace function public.kick_community_group_member(target_group_id uuid, target_user_id uuid)
returns void language plpgsql security definer set search_path=public set row_security=off as $$
declare me uuid:=auth.uid(); grp_owner uuid;
begin
  if me is null then raise exception 'not_authenticated'; end if;
  select g.owner_id into grp_owner from public.community_groups g where g.id=target_group_id;
  if grp_owner is null or grp_owner<>me then raise exception 'group_owner_required'; end if;
  if target_user_id=grp_owner then raise exception 'cannot_remove_owner'; end if;
  delete from public.community_group_members where group_id=target_group_id and user_id=target_user_id;
  insert into public.community_group_bans(group_id,user_id,banned_by)
  values(target_group_id,target_user_id,me) on conflict do nothing;
  update public.community_group_join_requests set status='rejected',responded_at=now()
   where group_id=target_group_id and user_id=target_user_id and status='pending';
  update public.community_group_invitations set status='cancelled',responded_at=now()
   where group_id=target_group_id and invitee_id=target_user_id and status='pending';
end $$;

create or replace function public.get_community_group_members(target_group_id uuid)
returns table(user_id uuid, name text, profile_image text, role text, joined_at timestamptz)
language plpgsql security definer set search_path=public set row_security=off stable as $$
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  if not exists(select 1 from public.community_group_members gm
                where gm.group_id=target_group_id and gm.user_id=auth.uid()) then
    raise exception 'group_membership_required';
  end if;
  return query
    select m.user_id,coalesce(u.name,'زميل')::text,u.profile_image::text,m.role::text,m.joined_at
    from public.community_group_members m
    join public.users u on u.id=m.user_id
    where m.group_id=target_group_id
    order by (m.role='owner') desc, m.joined_at, m.user_id;
end $$;

-- Invite link: https://zameeljo.com/s/group/<code>. Members can read it; only the
-- owner can replace it (which kills old links).
create or replace function public.zameel_new_group_code166()
returns text language sql volatile set search_path='' as $$
  select substr(replace(gen_random_uuid()::text,'-',''),1,10)
$$;

create or replace function public.get_community_group_invite_code(target_group_id uuid)
returns text language plpgsql security definer set search_path=public set row_security=off as $$
declare code text;
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  if not exists(select 1 from public.community_group_members gm
                where gm.group_id=target_group_id and gm.user_id=auth.uid()) then
    raise exception 'group_membership_required';
  end if;
  select g.invite_code into code from public.community_groups g where g.id=target_group_id for update;
  if code is null then
    loop
      code:=public.zameel_new_group_code166();
      exit when not exists(select 1 from public.community_groups where invite_code=code);
    end loop;
    update public.community_groups set invite_code=code where id=target_group_id;
  end if;
  return code;
end $$;

create or replace function public.reset_community_group_invite_code(target_group_id uuid)
returns text language plpgsql security definer set search_path=public set row_security=off as $$
declare code text;
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  if not exists(select 1 from public.community_groups g where g.id=target_group_id and g.owner_id=auth.uid()) then
    raise exception 'group_owner_required';
  end if;
  loop
    code:=public.zameel_new_group_code166();
    exit when not exists(select 1 from public.community_groups where invite_code=code);
  end loop;
  update public.community_groups set invite_code=code where id=target_group_id;
  return code;
end $$;

-- What a person sees before accepting: the group card only, never its content.
create or replace function public.get_community_group_by_invite_code(target_code text)
returns table(id uuid, name text, description text, group_type text, is_private boolean,
              members bigint, owner_name text, is_joined boolean, is_removed boolean)
language plpgsql security definer set search_path=public set row_security=off stable as $$
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  return query
    select g.id,g.name::text,g.description::text,g.group_type::text,g.is_private,
           (select count(*) from public.community_group_members m where m.group_id=g.id),
           coalesce(o.name,'زميل')::text,
           exists(select 1 from public.community_group_members m where m.group_id=g.id and m.user_id=auth.uid()),
           exists(select 1 from public.community_group_bans b where b.group_id=g.id and b.user_id=auth.uid())
    from public.community_groups g
    join public.users o on o.id=g.owner_id
    where g.invite_code is not null and g.invite_code=lower(trim(target_code));
end $$;

create or replace function public.join_community_group_by_code(target_code text)
returns uuid language plpgsql security definer set search_path=public set row_security=off as $$
declare me uuid:=auth.uid(); gid uuid;
begin
  if me is null then raise exception 'not_authenticated'; end if;
  select g.id into gid from public.community_groups g
   where g.invite_code is not null and g.invite_code=lower(trim(target_code));
  if gid is null then raise exception 'invite_not_found'; end if;
  if exists(select 1 from public.community_group_bans b where b.group_id=gid and b.user_id=me) then
    raise exception 'removed_from_group';
  end if;
  insert into public.community_group_members(group_id,user_id,role)
  values(gid,me,'member') on conflict do nothing;
  update public.community_group_join_requests set status='accepted',responded_at=now()
   where group_id=gid and user_id=me and status='pending';
  update public.community_group_invitations set status='accepted',responded_at=now()
   where group_id=gid and invitee_id=me and status='pending';
  return gid;
end $$;

-- In-app invitations.
create or replace function public.send_community_group_invitation(target_group_id uuid, target_user_id uuid)
returns text language plpgsql security definer set search_path=public set row_security=off as $$
declare me uuid:=auth.uid(); g public.community_groups; inviter_name text; invitation uuid; banned boolean;
begin
  if me is null then raise exception 'not_authenticated'; end if;
  if target_user_id is null or target_user_id=me then raise exception 'invalid_invitee'; end if;
  select * into g from public.community_groups where id=target_group_id;
  if g.id is null then raise exception 'group_not_found'; end if;
  if not exists(select 1 from public.community_group_members gm
                where gm.group_id=target_group_id and gm.user_id=me) then
    raise exception 'group_membership_required';
  end if;
  if not exists(select 1 from public.users where id=target_user_id) then raise exception 'user_not_found'; end if;
  banned:=exists(select 1 from public.community_group_bans b
                 where b.group_id=target_group_id and b.user_id=target_user_id);
  -- Colleagues only. The one exception: the owner may bring back someone he removed.
  if not public.is_colleague(me,target_user_id) and not (banned and g.owner_id=me) then
    raise exception 'colleague_required';
  end if;
  if public.is_blocked(me,target_user_id) then raise exception 'user_unavailable'; end if;
  if exists(select 1 from public.community_group_members gm
            where gm.group_id=target_group_id and gm.user_id=target_user_id) then
    return 'already_member';
  end if;
  if banned and g.owner_id<>me then raise exception 'removed_from_group'; end if;
  if exists(select 1 from public.community_group_invitations i
            where i.group_id=target_group_id and i.invitee_id=target_user_id and i.status='pending') then
    return 'already_invited';
  end if;
  if (select count(*) from public.community_group_invitations i
       where i.inviter_id=me and i.created_at>now()-interval '1 hour')>=30 then
    raise exception 'too_many_invitations';
  end if;
  insert into public.community_group_invitations(group_id,inviter_id,invitee_id)
  values(target_group_id,me,target_user_id) returning id into invitation;
  select coalesce(u.name,'زميل') into inviter_name from public.users u where u.id=me;
  insert into public.notifications(user_id,actor_id,type,title_ar,title_en,body_ar,body_en,data,is_read)
  values(target_user_id,me,'group_invitation','دعوة إلى مجموعة','Group invitation',
         inviter_name||' دعاك للانضمام إلى مجموعة «'||g.name||'»',
         inviter_name||' invited you to join the group "'||g.name||'"',
         jsonb_build_object('type','group_invitation','invitation_id',invitation,
                            'group_id',g.id,'group_name',g.name,'inviter_id',me),
         false);
  return 'sent';
end $$;

create or replace function public.respond_community_group_invitation(target_invitation_id uuid, accept_invitation boolean)
returns uuid language plpgsql security definer set search_path=public set row_security=off as $$
declare me uuid:=auth.uid(); inv public.community_group_invitations;
begin
  if me is null then raise exception 'not_authenticated'; end if;
  select * into inv from public.community_group_invitations i
   where i.id=target_invitation_id and i.invitee_id=me and i.status='pending' for update;
  if inv.id is null then raise exception 'pending_invitation_not_found'; end if;
  if accept_invitation then
    insert into public.community_group_members(group_id,user_id,role)
    values(inv.group_id,me,'member') on conflict do nothing;
    delete from public.community_group_bans where group_id=inv.group_id and user_id=me;
    update public.community_group_join_requests set status='accepted',responded_at=now()
     where group_id=inv.group_id and user_id=me and status='pending';
    update public.community_group_invitations set status='accepted',responded_at=now() where id=inv.id;
  else
    update public.community_group_invitations set status='declined',responded_at=now() where id=inv.id;
  end if;
  return inv.group_id;
end $$;

create or replace function public.get_community_group_invitation(target_invitation_id uuid)
returns table(id uuid, group_id uuid, group_name text, group_description text, group_type text,
              is_private boolean, members bigint, inviter_id uuid, inviter_name text,
              status text, created_at timestamptz)
language plpgsql security definer set search_path=public set row_security=off stable as $$
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  return query
    select i.id,i.group_id,g.name::text,g.description::text,g.group_type::text,g.is_private,
           (select count(*) from public.community_group_members m where m.group_id=g.id),
           i.inviter_id,coalesce(u.name,'زميل')::text,i.status::text,i.created_at
    from public.community_group_invitations i
    join public.community_groups g on g.id=i.group_id
    join public.users u on u.id=i.inviter_id
    where i.id=target_invitation_id and i.invitee_id=auth.uid();
end $$;

create or replace function public.get_my_community_group_invitations()
returns table(id uuid, group_id uuid, group_name text, group_description text, group_type text,
              is_private boolean, members bigint, inviter_id uuid, inviter_name text,
              status text, created_at timestamptz)
language plpgsql security definer set search_path=public set row_security=off stable as $$
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  return query
    select i.id,i.group_id,g.name::text,g.description::text,g.group_type::text,g.is_private,
           (select count(*) from public.community_group_members m where m.group_id=g.id),
           i.inviter_id,coalesce(u.name,'زميل')::text,i.status::text,i.created_at
    from public.community_group_invitations i
    join public.community_groups g on g.id=i.group_id
    join public.users u on u.id=i.inviter_id
    where i.invitee_id=auth.uid() and i.status='pending'
    order by i.created_at desc
    limit 50;
end $$;

revoke all on function public.zameel_new_group_code166() from public, anon, authenticated;
revoke all on function public.join_community_group(uuid) from public, anon;
revoke all on function public.kick_community_group_member(uuid,uuid) from public, anon;
revoke all on function public.get_community_group_members(uuid) from public, anon;
revoke all on function public.get_community_group_invite_code(uuid) from public, anon;
revoke all on function public.reset_community_group_invite_code(uuid) from public, anon;
revoke all on function public.get_community_group_by_invite_code(text) from public, anon;
revoke all on function public.join_community_group_by_code(text) from public, anon;
revoke all on function public.send_community_group_invitation(uuid,uuid) from public, anon;
revoke all on function public.respond_community_group_invitation(uuid,boolean) from public, anon;
revoke all on function public.get_community_group_invitation(uuid) from public, anon;
revoke all on function public.get_my_community_group_invitations() from public, anon;
grant execute on function public.join_community_group(uuid) to authenticated;
grant execute on function public.kick_community_group_member(uuid,uuid) to authenticated;
grant execute on function public.get_community_group_members(uuid) to authenticated;
grant execute on function public.get_community_group_invite_code(uuid) to authenticated;
grant execute on function public.reset_community_group_invite_code(uuid) to authenticated;
grant execute on function public.get_community_group_by_invite_code(text) to authenticated;
grant execute on function public.join_community_group_by_code(text) to authenticated;
grant execute on function public.send_community_group_invitation(uuid,uuid) to authenticated;
grant execute on function public.respond_community_group_invitation(uuid,boolean) to authenticated;
grant execute on function public.get_community_group_invitation(uuid) to authenticated;
grant execute on function public.get_my_community_group_invitations() to authenticated;

-- Private Storage for group chat attachments. Path: <sender id>/<group id>/<file>.
do $$ begin
  if to_regclass('storage.buckets') is not null and to_regclass('storage.objects') is not null then
    insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
    values('group_media','group_media',false,26214400,
      array['image/jpeg','image/png','image/webp','image/gif','video/mp4','video/quicktime','video/webm','audio/mp4','audio/mpeg','audio/aac','audio/wav','audio/ogg'])
    on conflict(id) do update set public=false,file_size_limit=26214400,allowed_mime_types=excluded.allowed_mime_types;

    execute 'drop policy if exists group_media_member_read_166 on storage.objects';
    execute $p$create policy group_media_member_read_166 on storage.objects for select to authenticated
      using (bucket_id='group_media' and exists(select 1 from public.community_group_members m
        where m.group_id::text=split_part(name,'/',2) and m.user_id=auth.uid()))$p$;
    execute 'drop policy if exists group_media_member_insert_166 on storage.objects';
    execute $p$create policy group_media_member_insert_166 on storage.objects for insert to authenticated
      with check (bucket_id='group_media' and split_part(name,'/',1)=auth.uid()::text
        and exists(select 1 from public.community_group_members m
          where m.group_id::text=split_part(name,'/',2) and m.user_id=auth.uid()))$p$;
    execute 'drop policy if exists group_media_owner_delete_166 on storage.objects';
    execute $p$create policy group_media_owner_delete_166 on storage.objects for delete to authenticated
      using (bucket_id='group_media' and split_part(name,'/',1)=auth.uid()::text)$p$;
  end if;
end $$;

notify pgrst, 'reload schema';
