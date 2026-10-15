begin;
set local lock_timeout='2s';
set local statement_timeout='60s';
lock table public.zameel_college_entries,public.post_comments,public.clip_comments,public.zameel_profile_photo_comments,public.advertisement_comments in access exclusive mode nowait;

create or replace function public.zameel_college_entry_visible161(p_entry uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select auth.uid() is not null and public.zameel_account_can_read() and exists(
 select 1 from public.zameel_college_entries e where e.id=p_entry and not e.is_hidden
 and e.cycle_day=public.zameel_jordan_cycle_day()
 and (((now() at time zone 'Asia/Amman')::time>=time '07:00' and (now() at time zone 'Asia/Amman')::time<time '20:00')
 or exists(select 1 from public.zameel_college_winners w where w.cycle_day=e.cycle_day and w.entry_id=e.id)));
$$;
revoke all on function public.zameel_college_entry_visible161(uuid) from public,anon;
grant execute on function public.zameel_college_entry_visible161(uuid) to authenticated;
drop policy if exists college_cycle161 on public.zameel_college_entries;
create policy college_cycle161 on public.zameel_college_entries as restrictive for select to authenticated using(public.zameel_college_entry_visible161(id));

create table if not exists public.zameel_college_comments161(
 id uuid primary key default gen_random_uuid(), entry_id uuid not null references public.zameel_college_entries(id) on delete cascade,
 user_id uuid not null references public.users(id) on delete cascade,content text not null check(length(trim(content)) between 1 and 2000),
 created_at timestamptz not null default now());
create index if not exists college_comments_page161 on public.zameel_college_comments161(entry_id,created_at,id);
alter table public.zameel_college_comments161 enable row level security;
revoke all on public.zameel_college_comments161 from public,anon,authenticated;
grant select,insert,delete on public.zameel_college_comments161 to authenticated;
grant all on public.zameel_college_comments161 to service_role;
drop policy if exists college_comments_read161 on public.zameel_college_comments161;
create policy college_comments_read161 on public.zameel_college_comments161 for select to authenticated using(public.zameel_college_entry_visible161(entry_id));
drop policy if exists college_comments_insert161 on public.zameel_college_comments161;
create policy college_comments_insert161 on public.zameel_college_comments161 for insert to authenticated with check(user_id=auth.uid() and public.zameel_account_can_write() and public.zameel_college_entry_visible161(entry_id));
drop policy if exists zameel_device_gate160 on public.zameel_college_comments161;
create policy zameel_device_gate160 on public.zameel_college_comments161 as restrictive for all to authenticated using((select public.zameel_device_authorized160())) with check((select public.zameel_device_authorized160()));

-- The owner of the parent content, never the comment author, controls deletion.
create or replace function public.zameel_comment_owner161(p_kind text,p_id uuid) returns uuid
language plpgsql stable security definer set search_path='' as $$
declare owner_id uuid;
begin
 case p_kind
 when 'post' then select p.user_id into owner_id from public.post_comments c join public.posts p on p.id=c.post_id where c.id=p_id;
 when 'clip' then select p.user_id into owner_id from public.clip_comments c join public.clips p on p.id=c.clip_id where c.id=p_id;
 when 'photo' then select p.owner_id into owner_id from public.zameel_profile_photo_comments c join public.zameel_profile_photos p on p.id=c.photo_id where c.id=p_id;
 when 'advertisement' then select a.user_id into owner_id from public.advertisement_comments c join public.advertisements p on p.id=c.advertisement_id join public.partner_accounts a on a.partner_id=p.partner_id where c.id=p_id;
 when 'college' then select p.user_id into owner_id from public.zameel_college_comments161 c join public.zameel_college_entries p on p.id=c.entry_id where c.id=p_id;
 else raise exception 'invalid_comment_kind';
 end case;
 return owner_id;
end $$;
revoke all on function public.zameel_comment_owner161(text,uuid) from public,anon,authenticated;
-- Expose only an ownership boolean, not the parent identity.
create or replace function public.zameel_can_delete_comment161(p_kind text,p_id uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select auth.uid() is not null and public.zameel_account_can_write() and public.zameel_device_authorized160() and public.zameel_comment_owner161(p_kind,p_id)=auth.uid();
$$;
revoke all on function public.zameel_can_delete_comment161(text,uuid) from public,anon;
grant execute on function public.zameel_can_delete_comment161(text,uuid) to authenticated;

do $$declare item record;begin
 for item in select * from(values('post_comments','post'),('clip_comments','clip'),('zameel_profile_photo_comments','photo'),('advertisement_comments','advertisement'),('zameel_college_comments161','college')) as x(tab,kind) loop
 execute format('drop policy if exists comment_owner_only161 on public.%I',item.tab);
 execute format('create policy comment_owner_only161 on public.%I as restrictive for delete to authenticated using(public.zameel_can_delete_comment161(%L,id))',item.tab,item.kind);
 execute format('drop policy if exists comment_owner_delete161 on public.%I',item.tab);
 execute format('create policy comment_owner_delete161 on public.%I for delete to authenticated using(public.zameel_can_delete_comment161(%L,id))',item.tab,item.kind);
 execute format('grant delete on public.%I to authenticated',item.tab);
 end loop;
end $$;

create or replace function public.zameel_delete_comment161(p_kind text,p_id uuid) returns boolean
language plpgsql security definer set search_path='' as $$
declare tab text;
begin
 if not coalesce(public.zameel_can_delete_comment161(p_kind,p_id),false) then raise exception 'comment_owner_required';end if;
 tab:=case p_kind when 'post' then 'post_comments' when 'clip' then 'clip_comments' when 'photo' then 'zameel_profile_photo_comments' when 'advertisement' then 'advertisement_comments' when 'college' then 'zameel_college_comments161' end;
 if tab is null then raise exception 'invalid_comment_kind';end if;
 if p_kind='advertisement' then
 with recursive tree(id) as (
 select c.id from public.advertisement_comments c where c.id=p_id
 union select c.id from public.advertisement_comments c join tree t on c.parent_id=t.id where c.advertisement_id=(select root.advertisement_id from public.advertisement_comments root where root.id=p_id)
 ) delete from public.advertisement_comments c where c.id in(select id from tree);
 else execute format('delete from public.%I where id=$1',tab) using p_id;end if;
 return true;
end $$;
revoke all on function public.zameel_delete_comment161(text,uuid) from public,anon;
grant execute on function public.zameel_delete_comment161(text,uuid) to authenticated;

create or replace function public.zameel_college_snapshot161() returns jsonb
language sql stable security invoker set search_path='' as $$
 select jsonb_build_object('cycle_day',public.zameel_jordan_cycle_day(),'accepting',
 (now() at time zone 'Asia/Amman')::time>=time '07:00' and (now() at time zone 'Asia/Amman')::time<time '20:00',
 'selection_due',(now() at time zone 'Asia/Amman')::time>=time '20:00',
 'winner_id',(select w.entry_id from public.zameel_college_winners w where w.cycle_day=public.zameel_jordan_cycle_day()),
 'entries',coalesce((select jsonb_agg(to_jsonb(x)) from(select e.*,jsonb_build_object('name',u.name,'profile_image',u.profile_image) as users from public.zameel_college_entries e left join public.users u on u.id=e.user_id
 where e.cycle_day=public.zameel_jordan_cycle_day() and public.zameel_college_entry_visible161(e.id) order by e.like_count desc,e.created_at limit 200)x),'[]'::jsonb));
$$;
revoke all on function public.zameel_college_snapshot161() from public,anon;
grant execute on function public.zameel_college_snapshot161() to authenticated;
create or replace function public.zameel_comment_delete_rights161(p_kind text,p_ids uuid[]) returns uuid[]
language sql stable security definer set search_path='' as $$
 select array(select id from unnest(p_ids[1:100]) id where public.zameel_can_delete_comment161(p_kind,id));
$$;
revoke all on function public.zameel_comment_delete_rights161(text,uuid[]) from public,anon;
grant execute on function public.zameel_comment_delete_rights161(text,uuid[]) to authenticated;
commit;
