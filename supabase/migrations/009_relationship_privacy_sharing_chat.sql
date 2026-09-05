-- Zameel relationships, privacy, sharing and realtime chat.
-- Run after the existing migrations.

alter table public.users add column if not exists account_privacy text not null default 'public';
update public.users set account_privacy = 'public' where account_privacy is null;
alter table public.users drop constraint if exists users_account_privacy_check;
alter table public.users add constraint users_account_privacy_check check (account_privacy in ('public','colleagues'));

alter table public.posts add column if not exists audience text not null default 'public';
alter table public.posts add column if not exists shares_count integer not null default 0;
alter table public.posts drop constraint if exists posts_audience_check;
alter table public.posts add constraint posts_audience_check check (audience in ('public','friends','private'));

create table if not exists public.friend_requests (
  id uuid primary key default gen_random_uuid(),
  sender_id uuid not null references public.users(id) on delete cascade,
  receiver_id uuid not null references public.users(id) on delete cascade,
  sender_name text not null default '',
  receiver_name text not null default '',
  status text not null default 'pending' check (status in ('pending','accepted','rejected','cancelled')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (sender_id <> receiver_id)
);
create unique index if not exists friend_requests_pending_unique
  on public.friend_requests(sender_id, receiver_id) where status = 'pending';
create index if not exists friend_requests_receiver_idx on public.friend_requests(receiver_id, status, created_at desc);
create index if not exists friend_requests_sender_idx on public.friend_requests(sender_id, status, created_at desc);

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  actor_id uuid references public.users(id) on delete set null,
  type text not null,
  title_ar text not null default '',
  title_en text not null default '',
  body_ar text not null default '',
  body_en text not null default '',
  data jsonb not null default '{}'::jsonb,
  is_read boolean not null default false,
  created_at timestamptz not null default now()
);
create index if not exists notifications_user_idx on public.notifications(user_id, created_at desc);

create table if not exists public.shared_posts (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.posts(id) on delete cascade,
  shared_by uuid not null references public.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique(post_id, shared_by)
);
create index if not exists shared_posts_user_idx on public.shared_posts(shared_by, created_at desc);
create index if not exists shared_posts_post_idx on public.shared_posts(post_id, created_at desc);

create table if not exists public.conversations (
  id uuid primary key default gen_random_uuid(),
  is_group boolean not null default false,
  title text,
  created_by uuid references public.users(id) on delete set null,
  created_at timestamptz not null default now()
);

create table if not exists public.conversation_members (
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  user_id uuid not null references public.users(id) on delete cascade,
  joined_at timestamptz not null default now(),
  primary key (conversation_id, user_id)
);
create index if not exists conversation_members_user_idx on public.conversation_members(user_id, joined_at desc);

create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  sender_id uuid not null references public.users(id) on delete cascade,
  body text not null check (char_length(body) between 1 and 5000),
  created_at timestamptz not null default now()
);
create index if not exists messages_conversation_idx on public.messages(conversation_id, created_at);

alter table public.friend_requests add column if not exists sender_name text not null default '';
alter table public.friend_requests add column if not exists receiver_name text not null default '';

-- Existing one-way follows are kept for compatibility; accepted friendship is represented by friend_requests.
create or replace function public.is_colleague(a uuid, b uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select a = b
    or exists (
      select 1 from public.friend_requests r
      where r.status = 'accepted'
        and ((r.sender_id = a and r.receiver_id = b) or (r.sender_id = b and r.receiver_id = a))
    )
    or (
      exists (select 1 from public.follows f where f.follower_id = a and f.following_id = b)
      and exists (select 1 from public.follows f where f.follower_id = b and f.following_id = a)
    );
$$;
grant execute on function public.is_colleague(uuid, uuid) to authenticated;

create or replace function public.sync_post_shares_count()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if TG_OP = 'INSERT' then
    update public.posts set shares_count = (select count(*) from public.shared_posts where post_id = new.post_id) where id = new.post_id;
    return new;
  elsif TG_OP = 'DELETE' then
    update public.posts set shares_count = (select count(*) from public.shared_posts where post_id = old.post_id) where id = old.post_id;
    return old;
  end if;
  return null;
end;
$$;
drop trigger if exists shared_posts_sync_counter on public.shared_posts;
create trigger shared_posts_sync_counter
after insert or delete on public.shared_posts
for each row execute function public.sync_post_shares_count();
update public.posts p set shares_count = (select count(*) from public.shared_posts s where s.post_id = p.id);


create or replace function public.create_direct_conversation(other_user_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  me uuid := auth.uid();
  existing uuid;
  cid uuid;
begin
  if me is null then raise exception 'not_authenticated'; end if;
  if other_user_id is null or other_user_id = me then raise exception 'invalid_partner'; end if;
  if not public.is_colleague(me, other_user_id) then raise exception 'colleague_only'; end if;
  select c.id into existing
  from public.conversations c
  where c.is_group = false
    and exists (select 1 from public.conversation_members cm where cm.conversation_id=c.id and cm.user_id=me)
    and exists (select 1 from public.conversation_members cm where cm.conversation_id=c.id and cm.user_id=other_user_id)
  limit 1;
  if existing is not null then return existing; end if;
  insert into public.conversations(is_group, created_by) values(false, me) returning id into cid;
  insert into public.conversation_members(conversation_id,user_id) values(cid,me),(cid,other_user_id);
  return cid;
end;
$$;
grant execute on function public.create_direct_conversation(uuid) to authenticated;

-- Privacy-aware users and posts policies.
alter table public.friend_requests enable row level security;
alter table public.notifications enable row level security;
alter table public.shared_posts enable row level security;
alter table public.conversations enable row level security;
alter table public.conversation_members enable row level security;
alter table public.messages enable row level security;

-- Users: own row is always visible; public accounts are visible to authenticated users;
-- colleague-only accounts are visible only to colleagues.
drop policy if exists users_select_authenticated on public.users;
create policy users_select_authenticated on public.users for select to authenticated
using (id = auth.uid() or account_privacy = 'public' or public.is_colleague(auth.uid(), id));

-- Posts: enforce both account privacy and post audience at the database level.
drop policy if exists posts_select_authenticated on public.posts;
create policy posts_select_authenticated on public.posts for select to authenticated
using (
  user_id = auth.uid()
  or (
    exists (select 1 from public.users u where u.id = posts.user_id and (u.account_privacy = 'public' or public.is_colleague(auth.uid(), u.id)))
    and (
      audience = 'public'
      or (audience = 'friends' and public.is_colleague(auth.uid(), user_id))
    )
  )
);

-- Friend requests: participants can read/update their own requests.
drop policy if exists friend_requests_select_participants on public.friend_requests;
drop policy if exists friend_requests_insert_sender on public.friend_requests;
drop policy if exists friend_requests_update_participants on public.friend_requests;
drop policy if exists friend_requests_receiver_update on public.friend_requests;
drop policy if exists friend_requests_sender_cancel on public.friend_requests;
create policy friend_requests_select_participants on public.friend_requests for select to authenticated
using (sender_id = auth.uid() or receiver_id = auth.uid());
create policy friend_requests_insert_sender on public.friend_requests for insert to authenticated
with check (sender_id = auth.uid() and receiver_id <> auth.uid());
create policy friend_requests_receiver_update on public.friend_requests for update to authenticated
using (receiver_id = auth.uid())
with check (receiver_id = auth.uid() and status in ('accepted','rejected'));
create policy friend_requests_sender_cancel on public.friend_requests for update to authenticated
using (sender_id = auth.uid())
with check (sender_id = auth.uid() and status = 'cancelled');

-- Notifications belong only to their recipient; actors may be displayed through users RLS.
drop policy if exists notifications_select_self on public.notifications;
drop policy if exists notifications_insert_authenticated on public.notifications;
drop policy if exists notifications_update_self on public.notifications;
drop policy if exists notifications_delete_self on public.notifications;
create policy notifications_select_self on public.notifications for select to authenticated using (user_id = auth.uid());
create policy notifications_insert_authenticated on public.notifications for insert to authenticated with check (actor_id = auth.uid() or actor_id is null);
create policy notifications_update_self on public.notifications for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy notifications_delete_self on public.notifications for delete to authenticated using (user_id = auth.uid());

-- Shares: only the person who shared can remove their share; source post owner cannot delete someone else's share.
drop policy if exists shared_posts_select_visible on public.shared_posts;
drop policy if exists shared_posts_insert_self on public.shared_posts;
drop policy if exists shared_posts_delete_self on public.shared_posts;
create policy shared_posts_select_visible on public.shared_posts for select to authenticated
using (
  shared_by = auth.uid()
  or exists (select 1 from public.posts p where p.id = post_id)
);
create policy shared_posts_insert_self on public.shared_posts for insert to authenticated
with check (shared_by = auth.uid());
create policy shared_posts_delete_self on public.shared_posts for delete to authenticated using (shared_by = auth.uid());

-- Private one-to-one conversations. A conversation is visible only to its members.
drop policy if exists conversations_member_select on public.conversations;
drop policy if exists conversations_member_insert on public.conversations;
create policy conversations_member_select on public.conversations for select to authenticated
using (exists (select 1 from public.conversation_members cm where cm.conversation_id = id and cm.user_id = auth.uid()));
create policy conversations_member_insert on public.conversations for insert to authenticated
with check (created_by = auth.uid());

drop policy if exists conversation_members_self_select on public.conversation_members;
drop policy if exists conversation_members_self_insert on public.conversation_members;
create policy conversation_members_self_select on public.conversation_members for select to authenticated
using (user_id = auth.uid() or exists (select 1 from public.conversation_members cm where cm.conversation_id = conversation_id and cm.user_id = auth.uid()));
create policy conversation_members_self_insert on public.conversation_members for insert to authenticated
with check (user_id = auth.uid() or exists (select 1 from public.conversation_members cm where cm.conversation_id = conversation_id and cm.user_id = auth.uid()));

drop policy if exists messages_member_select on public.messages;
drop policy if exists messages_member_insert on public.messages;
create policy messages_member_select on public.messages for select to authenticated
using (exists (select 1 from public.conversation_members cm where cm.conversation_id = conversation_id and cm.user_id = auth.uid()));
create policy messages_member_insert on public.messages for insert to authenticated
with check (sender_id = auth.uid() and exists (select 1 from public.conversation_members cm where cm.conversation_id = conversation_id and cm.user_id = auth.uid()));

-- Realtime is optional; enabling it is safe when the publication exists.
do $$ begin
  alter publication supabase_realtime add table public.friend_requests;
exception when duplicate_object then null; when undefined_object then null;
end $$;
do $$ begin
  alter publication supabase_realtime add table public.notifications;
exception when duplicate_object then null; when undefined_object then null;
end $$;
do $$ begin
  alter publication supabase_realtime add table public.messages;
exception when duplicate_object then null; when undefined_object then null;
end $$;
