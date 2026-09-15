-- Zameel 039: follow-on-request behavior and explicit owner-only safeguards.
-- Run after migration 038.

begin;

-- Some older deployments created follows against public.profiles while the
-- current application uses public.users as its canonical account table.
-- Repoint the two foreign keys only when every existing follow row can be
-- represented safely in users; otherwise keep the legacy keys and let the
-- guarded trigger below avoid breaking colleague requests.
do $$
begin
  if not exists (
    select 1 from public.follows f
    where not exists (select 1 from public.users u where u.id=f.follower_id)
       or not exists (select 1 from public.users u where u.id=f.following_id)
  ) then
    alter table public.follows drop constraint if exists follows_follower_id_fkey;
    alter table public.follows drop constraint if exists follows_following_id_fkey;
    alter table public.follows add constraint follows_follower_id_fkey
      foreign key(follower_id) references public.users(id) on delete cascade;
    alter table public.follows add constraint follows_following_id_fkey
      foreign key(following_id) references public.users(id) on delete cascade;
  end if;
exception when duplicate_object then null;
end $$;

create or replace function public.follow_when_requesting_colleague()
returns trigger
language plpgsql
security definer
set search_path = public
set row_security = off
as $$
begin
  if new.status = 'pending' then
    begin
      insert into public.follows(follower_id, following_id)
      values(new.sender_id, new.receiver_id)
      on conflict do nothing;
    exception when foreign_key_violation then
      -- Never invalidate a colleague request because of a legacy profile row.
      null;
    end;
  end if;
  return new;
end;
$$;

drop trigger if exists friend_request_auto_follow on public.friend_requests;
create trigger friend_request_auto_follow
after insert or update of status on public.friend_requests
for each row
when (new.status = 'pending')
execute function public.follow_when_requesting_colleague();

do $$
begin
  insert into public.follows(follower_id, following_id)
  select r.sender_id, r.receiver_id
  from public.friend_requests r
  join public.users sender on sender.id=r.sender_id
  join public.users receiver on receiver.id=r.receiver_id
  where r.status = 'pending'
  on conflict do nothing;
exception when foreign_key_violation then
  null;
end $$;

-- Reassert owner-only mutation policies so UI hiding is backed by the database.
drop policy if exists users_update_self on public.users;
create policy users_update_self on public.users
for update to authenticated
using (id = auth.uid())
with check (id = auth.uid());

drop policy if exists posts_update_owner on public.posts;
create policy posts_update_owner on public.posts
for update to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

drop policy if exists posts_delete_owner on public.posts;
create policy posts_delete_owner on public.posts
for delete to authenticated
using (user_id = auth.uid());

drop policy if exists stories_update_self on public.social_stories;
create policy stories_update_self on public.social_stories
for update to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

drop policy if exists clips_update_self on public.clips;
create policy clips_update_self on public.clips
for update to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

commit;
