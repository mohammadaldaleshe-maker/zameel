-- Zameel v1.3.8: two-page graduate spreads + editable text/stickers.
create extension if not exists pgcrypto;

alter table public.graduation_book_pages
  add column if not exists elements jsonb not null default '[]'::jsonb;

-- Every book owner gets the first two pages as their personal spread.
do $$
declare
  r record;
begin
  for r in
    select b.id as book_id, b.owner_id
    from public.graduation_books b
  loop
    if not exists (
      select 1 from public.graduation_book_pages p
      where p.book_id = r.book_id and p.page_number = 1
    ) then
      insert into public.graduation_book_pages(book_id,page_number,author_id,title,elements)
      values(r.book_id,1,r.owner_id,'صفحتي الشخصية - الصور والذكريات','[]'::jsonb);
    end if;
    if not exists (
      select 1 from public.graduation_book_pages p
      where p.book_id = r.book_id and p.page_number = 2
    ) then
      insert into public.graduation_book_pages(book_id,page_number,author_id,title,elements)
      values(r.book_id,2,r.owner_id,'صفحتي الشخصية - الرسالة','[]'::jsonb);
    end if;
  end loop;
end $$;

create or replace function public.ensure_graduation_book_member_pages(p_book_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_owner uuid;
  v_first integer;
  v_count integer;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  select owner_id into v_owner from public.graduation_books where id = p_book_id;
  if v_owner is null then raise exception 'book_not_found'; end if;
  if v_owner = v_uid then return; end if;
  if not exists (
    select 1 from public.graduation_book_members
    where book_id = p_book_id and user_id = v_uid
  ) then
    raise exception 'not_a_member';
  end if;

  perform pg_advisory_xact_lock(hashtextextended(p_book_id::text, 0));

  select count(*), min(page_number)
    into v_count, v_first
  from public.graduation_book_pages
  where book_id = p_book_id and author_id = v_uid;

  if v_count = 0 then
    select coalesce(max(page_number),0) + 1 into v_first
    from public.graduation_book_pages where book_id = p_book_id;
    insert into public.graduation_book_pages(book_id,page_number,author_id,title,elements)
    values
      (p_book_id,v_first,v_uid,'صفحتي - الصور والذكريات','[]'::jsonb),
      (p_book_id,v_first+1,v_uid,'صفحتي - الكلمات والكتابة','[]'::jsonb);
  elsif v_count = 1 then
    insert into public.graduation_book_pages(book_id,page_number,author_id,title,elements)
    values(p_book_id,v_first+1,v_uid,'صفحتي - الكلمات والكتابة','[]'::jsonb)
    on conflict (book_id,page_number) do nothing;
  end if;
end;
$$;

grant execute on function public.ensure_graduation_book_member_pages(uuid) to authenticated;

create or replace function public.join_graduation_book(p_book_id uuid,p_token text) returns boolean
language plpgsql security definer set search_path=public as $$
declare v_ok boolean;
begin
  select (is_public and allow_writes and invite_token=p_token) into v_ok
  from graduation_books where id=p_book_id;
  if coalesce(v_ok,false) then
    insert into graduation_book_members(book_id,user_id)
      values(p_book_id,auth.uid()) on conflict do nothing;
    perform public.ensure_graduation_book_member_pages(p_book_id);
    return true;
  end if;
  return false;
end $$;

grant execute on function public.join_graduation_book(uuid,text) to authenticated;

-- Backfill exactly one two-page spread for existing members.
do $$
declare
  r record;
begin
  for r in
    select m.book_id, m.user_id
    from public.graduation_book_members m
  loop
    perform pg_advisory_xact_lock(hashtextextended(r.book_id::text, 0));
    if not exists (
      select 1 from public.graduation_book_pages p
      where p.book_id = r.book_id and p.author_id = r.user_id
    ) then
      insert into public.graduation_book_pages(book_id,page_number,author_id,title,elements)
      select r.book_id,
             coalesce(max(page_number),0)+1,
             r.user_id,
             'صفحتي - الصور والذكريات',
             '[]'::jsonb
      from public.graduation_book_pages
      where book_id = r.book_id;
      insert into public.graduation_book_pages(book_id,page_number,author_id,title,elements)
      select r.book_id,
             max(page_number)+1,
             r.user_id,
             'صفحتي - الكلمات والكتابة',
             '[]'::jsonb
      from public.graduation_book_pages
      where book_id = r.book_id and author_id = r.user_id;
    elsif (
      select count(*) from public.graduation_book_pages
      where book_id = r.book_id and author_id = r.user_id
    ) = 1 then
      insert into public.graduation_book_pages(book_id,page_number,author_id,title,elements)
      select r.book_id,
             min(page_number)+1,
             r.user_id,
             'صفحتي - الكلمات والكتابة',
             '[]'::jsonb
      from public.graduation_book_pages
      where book_id = r.book_id and author_id = r.user_id;
    end if;
  end loop;
end $$;


-- Owner-only participant management: remove a participant and both of their pages.
create or replace function public.remove_graduation_book_member(p_book_id uuid, p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare v_owner uuid;
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  select owner_id into v_owner from public.graduation_books where id = p_book_id;
  if v_owner <> auth.uid() then raise exception 'owner_only'; end if;
  if p_user_id = v_owner then raise exception 'cannot_remove_owner'; end if;

  delete from public.graduation_book_pages
    where book_id = p_book_id and author_id = p_user_id;
  delete from public.graduation_book_members
    where book_id = p_book_id and user_id = p_user_id;

  -- Keep physical page numbers contiguous for the printed book.
  -- Use a temporary offset so the UNIQUE(book_id,page_number) constraint
  -- is never violated while rows are renumbered.
  update public.graduation_book_pages
    set page_number = page_number + 1000000, updated_at = now()
    where book_id = p_book_id;

  with ordered as (
    select id,
           row_number() over (order by page_number, id)::integer as new_number
    from public.graduation_book_pages
    where book_id = p_book_id
  )
  update public.graduation_book_pages p
  set page_number = ordered.new_number,
      updated_at = now()
  from ordered
  where p.id = ordered.id;
end;
$$;

grant execute on function public.remove_graduation_book_member(uuid, uuid) to authenticated;

drop policy if exists graduation_book_members_owner_delete on public.graduation_book_members;
create policy graduation_book_members_owner_delete
on public.graduation_book_members for delete
using (exists (
  select 1 from public.graduation_books b
  where b.id = book_id and b.owner_id = auth.uid()
));
