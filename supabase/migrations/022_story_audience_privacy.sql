-- Story privacy scopes for Zameel.
-- Adds explicit college/department audiences and enforces them in RLS.
-- Also normalizes legacy close_friends schemas that used user_id instead of owner_id.

-- ---------------------------------------------------------------------------
-- close_friends compatibility
-- Some deployed Zameel databases have:  user_id + friend_id
-- Newer project code expects:            owner_id + friend_id
-- Keep both schemas working without destroying existing data.
-- ---------------------------------------------------------------------------
do $$
begin
  if to_regclass('public.close_friends') is not null then
    -- Legacy schema: user_id is the owner. Add/backfill owner_id for the
    -- current Flutter client and for the policies below.
    if not exists (
      select 1
      from information_schema.columns
      where table_schema = 'public'
        and table_name = 'close_friends'
        and column_name = 'owner_id'
    ) then
      if exists (
        select 1
        from information_schema.columns
        where table_schema = 'public'
          and table_name = 'close_friends'
          and column_name = 'user_id'
      ) then
        alter table public.close_friends add column owner_id uuid;
        update public.close_friends
        set owner_id = user_id
        where owner_id is null;

        alter table public.close_friends
          alter column owner_id set not null;
      else
        raise exception
          'close_friends has neither owner_id nor legacy user_id; cannot determine the owner column';
      end if;
    end if;
  end if;
end
$$;

-- When this is a legacy table that still has user_id, mirror user_id and
-- owner_id so both old database constraints and the new Flutter client work.
do $$
begin
  if to_regclass('public.close_friends') is not null
     and exists (
       select 1 from information_schema.columns
       where table_schema = 'public'
         and table_name = 'close_friends'
         and column_name = 'user_id'
     )
     and exists (
       select 1 from information_schema.columns
       where table_schema = 'public'
         and table_name = 'close_friends'
         and column_name = 'owner_id'
     ) then

    execute $fn$
      create or replace function public.zameel_sync_close_friend_owner()
      returns trigger
      language plpgsql
      as $body$
      begin
        if new.owner_id is null then
          new.owner_id := new.user_id;
        end if;
        if new.user_id is null then
          new.user_id := new.owner_id;
        end if;
        return new;
      end
      $body$
    $fn$;

    drop trigger if exists zameel_close_friend_owner_sync on public.close_friends;
    create trigger zameel_close_friend_owner_sync
      before insert or update on public.close_friends
      for each row
      execute function public.zameel_sync_close_friend_owner();
  end if;
end
$$;

-- Make owner_id useful to PostgREST/Supabase queries on legacy databases.
create index if not exists close_friends_owner_id_idx
  on public.close_friends(owner_id);
create index if not exists close_friends_friend_id_idx
  on public.close_friends(friend_id);

-- Allow a user to read close-friend rows in which they are the selected friend.
-- Existing owner-only write policies remain unchanged.
drop policy if exists close_friends_member_read on public.close_friends;
create policy close_friends_member_read
on public.close_friends
for select
to authenticated
using (owner_id = auth.uid() or friend_id = auth.uid());

-- ---------------------------------------------------------------------------
-- Story audience values
-- ---------------------------------------------------------------------------
alter table public.social_stories
  drop constraint if exists social_stories_audience_check;

alter table public.social_stories
  add constraint social_stories_audience_check
  check (audience in (
    'public',
    'friends',
    'close_friends',
    'faculty',
    'group',
    'college',
    'department'
  ));

-- Recreate story read policy with audience-aware rules.
drop policy if exists stories_read on public.social_stories;

create policy stories_read
on public.social_stories
for select
to authenticated
using (
  expires_at > now()
  and (
    user_id = auth.uid()
    or audience = 'public'
    or (
      audience = 'friends'
      and public.is_colleague(auth.uid(), user_id)
    )
    or (
      audience = 'close_friends'
      and exists (
        select 1
        from public.close_friends cf
        where cf.owner_id = social_stories.user_id
          and cf.friend_id = auth.uid()
      )
    )
    or (
      audience in ('college', 'faculty')
      and exists (
        select 1
        from public.users viewer
        join public.users owner on owner.id = social_stories.user_id
        where viewer.id = auth.uid()
          and nullif(trim(lower(viewer.university)), '') is not null
          and nullif(trim(lower(viewer.college)), '') is not null
          and trim(lower(viewer.university)) = trim(lower(owner.university))
          and trim(lower(viewer.college)) = trim(lower(owner.college))
      )
    )
    or (
      audience in ('department', 'group')
      and exists (
        select 1
        from public.users viewer
        join public.users owner on owner.id = social_stories.user_id
        where viewer.id = auth.uid()
          and nullif(trim(lower(viewer.university)), '') is not null
          and nullif(trim(lower(viewer.college)), '') is not null
          and nullif(trim(lower(viewer.department)), '') is not null
          and trim(lower(viewer.university)) = trim(lower(owner.university))
          and trim(lower(viewer.college)) = trim(lower(owner.college))
          and trim(lower(viewer.department)) = trim(lower(owner.department))
      )
    )
  )
);
