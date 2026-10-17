-- 165: Lamma moderation and richer chat.
--   * a member can leave a Lamma (the creator cannot: the creator ends it);
--   * the creator can remove any other member, who then cannot rejoin;
--   * member list with names for the creator's remove screen;
--   * chat messages may carry one image, video or voice note;
--   * private Storage bucket for those files, readable only by Lamma members.
-- Everything is additive. Existing tables, policies and functions keep working.

create table if not exists public.social_lamma_bans (
  lamma_id uuid not null references public.social_lammas(id) on delete cascade,
  user_id uuid not null references public.users(id) on delete cascade,
  banned_by uuid not null references public.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (lamma_id, user_id)
);
alter table public.social_lamma_bans enable row level security;
revoke all on table public.social_lamma_bans from public, anon, authenticated;

alter table public.social_lamma_messages add column if not exists media_url text;
alter table public.social_lamma_messages add column if not exists media_type text;
do $$ begin
  alter table public.social_lamma_messages add constraint social_lamma_messages_media_type_165
    check (media_type is null or media_type in ('image','video','audio'));
exception when duplicate_object then null; end $$;
do $$ begin
  alter table public.social_lamma_messages add constraint social_lamma_messages_media_pair_165
    check ((media_url is null) = (media_type is null));
exception when duplicate_object then null; end $$;

-- Same rule as before (member of an open, unexpired Lamma, sender is the caller)
-- plus: an attachment path must live under the sender's own folder for this Lamma.
drop policy if exists lamma_messages_members_insert on public.social_lamma_messages;
create policy lamma_messages_members_insert on public.social_lamma_messages
for insert to authenticated with check (
  sender_id=auth.uid()
  and (media_url is null or media_url like (auth.uid()::text||'/'||lamma_id::text||'/%'))
  and exists(
    select 1 from public.social_lamma_members m
    join public.social_lammas l on l.id=m.lamma_id
    where m.lamma_id=social_lamma_messages.lamma_id and m.user_id=auth.uid()
      and l.status in ('open','full') and l.expires_at>now()
  )
);

create or replace function public.join_social_lamma(p_lamma uuid)
returns boolean language plpgsql security definer set search_path=public as $$
declare cap int; joined int;
begin
  if auth.uid() is null then raise exception 'authentication_required'; end if;
  if exists(select 1 from social_lamma_bans where lamma_id=p_lamma and user_id=auth.uid()) then
    raise exception 'removed_from_lamma';
  end if;
  if exists(select 1 from social_lamma_members where lamma_id=p_lamma and user_id=auth.uid()) then return true; end if;
  select max_members into cap from social_lammas where id=p_lamma and status in ('open','full') and expires_at>now() for update;
  if cap is null then return false; end if;
  select count(*) into joined from social_lamma_members where lamma_id=p_lamma;
  if joined>=cap then update social_lammas set status='full' where id=p_lamma; return false; end if;
  insert into social_lamma_members(lamma_id,user_id) values(p_lamma,auth.uid()) on conflict do nothing;
  select count(*) into joined from social_lamma_members where lamma_id=p_lamma;
  if joined>=cap then update social_lammas set status='full' where id=p_lamma; end if;
  return true;
end;
$$;

create or replace function public.leave_social_lamma(p_lamma uuid)
returns boolean language plpgsql security definer set search_path='' as $$
declare owner uuid; cap int; joined int;
begin
  if auth.uid() is null then raise exception 'authentication_required'; end if;
  select creator_id,max_members into owner,cap from public.social_lammas where id=p_lamma for update;
  if owner is null then return false; end if;
  if owner=auth.uid() then raise exception 'creator_cannot_leave'; end if;
  delete from public.social_lamma_members where lamma_id=p_lamma and user_id=auth.uid();
  select count(*) into joined from public.social_lamma_members where lamma_id=p_lamma;
  update public.social_lammas set status='open' where id=p_lamma and status='full' and joined<cap;
  return true;
end;
$$;

create or replace function public.kick_social_lamma_member(p_lamma uuid, p_user uuid)
returns boolean language plpgsql security definer set search_path='' as $$
declare owner uuid; cap int; joined int;
begin
  if auth.uid() is null then raise exception 'authentication_required'; end if;
  select creator_id,max_members into owner,cap from public.social_lammas where id=p_lamma for update;
  if owner is null then return false; end if;
  if owner<>auth.uid() then raise exception 'creator_required'; end if;
  if p_user=owner then raise exception 'cannot_remove_creator'; end if;
  delete from public.social_lamma_members where lamma_id=p_lamma and user_id=p_user;
  insert into public.social_lamma_bans(lamma_id,user_id,banned_by) values(p_lamma,p_user,auth.uid()) on conflict do nothing;
  select count(*) into joined from public.social_lamma_members where lamma_id=p_lamma;
  update public.social_lammas set status='open' where id=p_lamma and status='full' and joined<cap;
  return true;
end;
$$;

create or replace function public.get_lamma_members(p_lamma uuid)
returns table(user_id uuid, name text, profile_image text, is_creator boolean, joined_at timestamptz)
language plpgsql security definer set search_path='' stable as $$
begin
  if auth.uid() is null then raise exception 'authentication_required'; end if;
  if not exists(select 1 from public.social_lamma_members me where me.lamma_id=p_lamma and me.user_id=auth.uid()) then
    raise exception 'membership_required';
  end if;
  return query
    select m.user_id,u.name::text,u.profile_image::text,(m.user_id=l.creator_id),m.joined_at
    from public.social_lamma_members m
    join public.social_lammas l on l.id=m.lamma_id
    join public.users u on u.id=m.user_id
    where m.lamma_id=p_lamma
    order by (m.user_id=l.creator_id) desc, m.joined_at;
end;
$$;

revoke all on function public.join_social_lamma(uuid) from public, anon;
revoke all on function public.leave_social_lamma(uuid) from public, anon;
revoke all on function public.kick_social_lamma_member(uuid,uuid) from public, anon;
revoke all on function public.get_lamma_members(uuid) from public, anon;
grant execute on function public.join_social_lamma(uuid) to authenticated;
grant execute on function public.leave_social_lamma(uuid) to authenticated;
grant execute on function public.kick_social_lamma_member(uuid,uuid) to authenticated;
grant execute on function public.get_lamma_members(uuid) to authenticated;

-- Private Storage for chat attachments. Path: <sender id>/<lamma id>/<file>.
do $$ begin
  if to_regclass('storage.buckets') is not null and to_regclass('storage.objects') is not null then
    insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
    values('lamma_media','lamma_media',false,26214400,
      array['image/jpeg','image/png','image/webp','image/gif','video/mp4','video/quicktime','video/webm','audio/mp4','audio/mpeg','audio/aac','audio/wav','audio/ogg'])
    on conflict(id) do update set public=false,file_size_limit=26214400,allowed_mime_types=excluded.allowed_mime_types;

    execute 'drop policy if exists lamma_media_member_read_165 on storage.objects';
    execute $p$create policy lamma_media_member_read_165 on storage.objects for select to authenticated
      using (bucket_id='lamma_media' and exists(select 1 from public.social_lamma_members m
        where m.lamma_id::text=split_part(name,'/',2) and m.user_id=auth.uid()))$p$;
    execute 'drop policy if exists lamma_media_member_insert_165 on storage.objects';
    execute $p$create policy lamma_media_member_insert_165 on storage.objects for insert to authenticated
      with check (bucket_id='lamma_media' and split_part(name,'/',1)=auth.uid()::text
        and exists(select 1 from public.social_lamma_members m
          where m.lamma_id::text=split_part(name,'/',2) and m.user_id=auth.uid()))$p$;
    execute 'drop policy if exists lamma_media_owner_delete_165 on storage.objects';
    execute $p$create policy lamma_media_owner_delete_165 on storage.objects for delete to authenticated
      using (bucket_id='lamma_media' and split_part(name,'/',1)=auth.uid()::text)$p$;
  end if;
end $$;

notify pgrst, 'reload schema';
