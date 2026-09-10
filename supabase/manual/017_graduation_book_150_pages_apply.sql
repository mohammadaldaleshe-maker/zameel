-- Zameel: fixed 150-page graduation book (75 two-page spreads).
-- Keeps physical page numbers stable: owner = pages 1-2; each participant gets
-- the next available odd/even pair. Empty pages remain reserved in the book.

create or replace function public.ensure_graduation_book_150_pages(p_book_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_owner uuid;
  v_page integer;
begin
  if v_uid is null then
    raise exception 'not_authenticated';
  end if;

  select owner_id into v_owner
  from public.graduation_books
  where id = p_book_id;

  if v_owner is null then
    raise exception 'book_not_found';
  end if;

  if v_owner <> v_uid then
    raise exception 'owner_only';
  end if;

  -- Create the physical 150-page capacity without overwriting existing content.
  insert into public.graduation_book_pages(book_id, page_number, author_id, title, strokes, images, elements)
  select
    p_book_id,
    gs,
    case when gs in (1, 2) then v_owner else null end,
    null,
    '[]'::jsonb,
    '[]'::jsonb,
    '[]'::jsonb
  from generate_series(1, 150) gs
  on conflict (book_id, page_number) do nothing;

  -- Claim pages 1-2 for the owner only when they are still unassigned.
  update public.graduation_book_pages
  set author_id = v_owner,
      title = case
        when title in ('صفحتي الشخصية', 'صفحتي الشخصية - الصور والذكريات', 'صفحتي الشخصية - الرسالة')
             and strokes = '[]'::jsonb and images = '[]'::jsonb and elements = '[]'::jsonb
          then null
        else title
      end,
      updated_at = now()
  where book_id = p_book_id
    and page_number in (1, 2)
    and author_id is null;

  -- Remove only legacy placeholder titles from otherwise empty pages.
  update public.graduation_book_pages
  set title = null,
      updated_at = now()
  where book_id = p_book_id
    and title in (
      'صفحتي الشخصية',
      'صفحتي الشخصية - الصور والذكريات',
      'صفحتي الشخصية - الرسالة',
      'صفحتي - الصور والذكريات',
      'صفحتي - الكلمات والكتابة'
    )
    and strokes = '[]'::jsonb
    and images = '[]'::jsonb
    and elements = '[]'::jsonb;
end;
$$;

grant execute on function public.ensure_graduation_book_150_pages(uuid) to authenticated;

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
  v_existing integer;
begin
  if v_uid is null then
    raise exception 'not_authenticated';
  end if;

  select owner_id into v_owner
  from public.graduation_books
  where id = p_book_id;

  if v_owner is null then
    raise exception 'book_not_found';
  end if;
  if v_owner = v_uid then
    return;
  end if;

  if not exists (
    select 1 from public.graduation_book_members
    where book_id = p_book_id and user_id = v_uid
  ) then
    raise exception 'not_a_member';
  end if;

  perform pg_advisory_xact_lock(hashtextextended(p_book_id::text, 0));

  -- The owner allocates the physical 150-page capacity. If this has not been
  -- run yet, make the same capacity available here as a safe fallback.
  insert into public.graduation_book_pages(book_id, page_number, author_id, title, strokes, images, elements)
  select
    p_book_id,
    gs,
    case when gs in (1, 2) then v_owner else null end,
    null,
    '[]'::jsonb,
    '[]'::jsonb,
    '[]'::jsonb
  from generate_series(1, 150) gs
  on conflict (book_id, page_number) do nothing;

  select count(*) into v_existing
  from public.graduation_book_pages
  where book_id = p_book_id and author_id = v_uid;

  if v_existing >= 2 then
    return;
  end if;

  if v_existing = 1 then
    select min(page_number) into v_first
    from public.graduation_book_pages
    where book_id = p_book_id and author_id = v_uid;

    if v_first is null or v_first % 2 = 0 then
      raise exception 'invalid_member_page_pair';
    end if;

    update public.graduation_book_pages
    set author_id = v_uid,
        title = null,
        strokes = '[]'::jsonb,
        images = '[]'::jsonb,
        elements = '[]'::jsonb,
        updated_at = now()
    where book_id = p_book_id
      and page_number = v_first + 1
      and author_id is null;
    return;
  end if;

  select gs into v_first
  from generate_series(3, 149, 2) gs
  where exists (
    select 1 from public.graduation_book_pages p1
    where p1.book_id = p_book_id and p1.page_number = gs and p1.author_id is null
  )
  and exists (
    select 1 from public.graduation_book_pages p2
    where p2.book_id = p_book_id and p2.page_number = gs + 1 and p2.author_id is null
  )
  order by gs
  limit 1;

  if v_first is null then
    raise exception 'book_full';
  end if;

  update public.graduation_book_pages
  set author_id = v_uid,
      title = null,
      strokes = '[]'::jsonb,
      images = '[]'::jsonb,
      elements = '[]'::jsonb,
      updated_at = now()
  where book_id = p_book_id
    and page_number in (v_first, v_first + 1)
    and author_id is null;
end;
$$;

grant execute on function public.ensure_graduation_book_member_pages(uuid) to authenticated;

create or replace function public.remove_graduation_book_member(p_book_id uuid, p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_owner uuid;
begin
  if auth.uid() is null then
    raise exception 'not_authenticated';
  end if;

  select owner_id into v_owner
  from public.graduation_books
  where id = p_book_id;

  if v_owner <> auth.uid() then
    raise exception 'owner_only';
  end if;
  if p_user_id = v_owner then
    raise exception 'cannot_remove_owner';
  end if;

  -- Keep the fixed 150-page book intact: just release the participant's pair.
  update public.graduation_book_pages
  set author_id = null,
      title = null,
      strokes = '[]'::jsonb,
      images = '[]'::jsonb,
      elements = '[]'::jsonb,
      updated_at = now()
  where book_id = p_book_id
    and author_id = p_user_id;

  delete from public.graduation_book_members
  where book_id = p_book_id and user_id = p_user_id;
end;
$$;

grant execute on function public.remove_graduation_book_member(uuid, uuid) to authenticated;
