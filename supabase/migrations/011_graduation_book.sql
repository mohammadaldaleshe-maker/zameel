-- Zameel v1.3.7: Alumni / Graduation Book
create extension if not exists pgcrypto;

create table if not exists public.graduation_books (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.users(id) on delete cascade unique,
  title text not null default 'دفتر الخريجين',
  student_name text not null default 'طالب زميل',
  university text not null default '',
  major text not null default '',
  graduation_year text not null default '',
  is_public boolean not null default true,
  allow_writes boolean not null default true,
  invite_token text not null default encode(gen_random_bytes(18), 'hex'),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.graduation_book_pages (
  id uuid primary key default gen_random_uuid(),
  book_id uuid not null references public.graduation_books(id) on delete cascade,
  page_number integer not null check (page_number >= 1),
  author_id uuid references public.users(id) on delete set null,
  title text,
  strokes jsonb not null default '[]'::jsonb,
  images jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(book_id, page_number)
);

create table if not exists public.graduation_book_members (
  book_id uuid not null references public.graduation_books(id) on delete cascade,
  user_id uuid not null references public.users(id) on delete cascade,
  joined_at timestamptz not null default now(),
  primary key(book_id,user_id)
);

alter table public.graduation_books enable row level security;
alter table public.graduation_book_pages enable row level security;
alter table public.graduation_book_members enable row level security;

drop policy if exists graduation_books_owner_select on public.graduation_books;
create policy graduation_books_owner_select on public.graduation_books for select using (owner_id = auth.uid() or is_public = true);
drop policy if exists graduation_books_owner_write on public.graduation_books;
create policy graduation_books_owner_write on public.graduation_books for all using (owner_id = auth.uid()) with check (owner_id = auth.uid());

drop policy if exists graduation_book_pages_select on public.graduation_book_pages;
create policy graduation_book_pages_select on public.graduation_book_pages for select using (exists (select 1 from public.graduation_books b where b.id = book_id and b.owner_id = auth.uid()) or exists (select 1 from public.graduation_books b join public.graduation_book_members m on m.book_id=b.id where b.id = book_id and b.is_public=true and m.user_id=auth.uid()));
drop policy if exists graduation_book_pages_insert on public.graduation_book_pages;
create policy graduation_book_pages_insert on public.graduation_book_pages for insert with check (exists (select 1 from public.graduation_books b where b.id=book_id and (b.owner_id=auth.uid() or (b.is_public=true and b.allow_writes=true and exists(select 1 from public.graduation_book_members m where m.book_id=b.id and m.user_id=auth.uid())))));
drop policy if exists graduation_book_pages_update on public.graduation_book_pages;
create policy graduation_book_pages_update on public.graduation_book_pages for update using (author_id=auth.uid() or exists(select 1 from public.graduation_books b where b.id=book_id and b.owner_id=auth.uid()));
drop policy if exists graduation_book_pages_delete on public.graduation_book_pages;
create policy graduation_book_pages_delete on public.graduation_book_pages for delete using (exists(select 1 from public.graduation_books b where b.id=book_id and b.owner_id=auth.uid()));

drop policy if exists graduation_book_members_select on public.graduation_book_members;
create policy graduation_book_members_select on public.graduation_book_members for select using (user_id=auth.uid() or exists(select 1 from public.graduation_books b where b.id=book_id and b.owner_id=auth.uid()));

create or replace function public.ensure_graduation_book(p_student_name text, p_university text, p_major text, p_graduation_year text) returns uuid
language plpgsql security definer set search_path=public as $$
declare v_id uuid;
begin
  select id into v_id from graduation_books where owner_id=auth.uid();
  if v_id is null then
    insert into graduation_books(owner_id,student_name,university,major,graduation_year) values(auth.uid(),coalesce(nullif(p_student_name,''),'طالب زميل'),coalesce(p_university,''),coalesce(p_major,''),coalesce(p_graduation_year,'')) returning id into v_id;
    insert into graduation_book_pages(book_id,page_number,author_id,title) values(v_id,1,auth.uid(),'صفحتي الشخصية');
  else
    update graduation_books set student_name=coalesce(nullif(p_student_name,''),student_name), university=coalesce(p_university,university), major=coalesce(p_major,major), graduation_year=coalesce(p_graduation_year,graduation_year), updated_at=now() where id=v_id;
  end if;
  return v_id;
end $$;

create or replace function public.join_graduation_book(p_book_id uuid,p_token text) returns boolean
language plpgsql security definer set search_path=public as $$
declare v_ok boolean;
begin
  select (is_public and allow_writes and invite_token=p_token) into v_ok from graduation_books where id=p_book_id;
  if coalesce(v_ok,false) then
    insert into graduation_book_members(book_id,user_id) values(p_book_id,auth.uid()) on conflict do nothing;
    return true;
  end if;
  return false;
end $$;

grant execute on function public.ensure_graduation_book(text,text,text,text) to authenticated;
grant execute on function public.join_graduation_book(uuid,text) to authenticated;

insert into storage.buckets(id,name,public) values('graduation_book','graduation_book',true) on conflict(id) do nothing;
