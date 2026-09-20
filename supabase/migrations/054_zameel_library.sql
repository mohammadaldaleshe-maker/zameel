-- Zameel 055 / DB migration 054
-- Official Zameel Library: admin-managed catalog layered over bundled starter content.
begin;

create table if not exists public.zameel_library_categories (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  name_ar text not null unique,
  name_en text,
  icon_name text,
  sort_order integer not null default 0,
  is_active boolean not null default true,
  created_by uuid references public.users(id) on delete set null default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.zameel_library_items (
  id uuid primary key default gen_random_uuid(),
  item_type text not null check (item_type in ('book','summary')),
  title text not null check (char_length(trim(title)) between 1 and 500),
  category text not null check (char_length(trim(category)) between 1 and 200),
  author text,
  description text,
  keywords text[] not null default '{}',
  source_url text,
  file_url text,
  content_text text,
  rights_status text,
  circulation_status text,
  is_published boolean not null default false,
  is_featured boolean not null default false,
  created_by uuid references public.users(id) on delete set null default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint zameel_library_item_source_check check (
    item_type = 'summary'
    or source_url is not null
    or file_url is not null
  )
);

create index if not exists zameel_library_items_category_idx
  on public.zameel_library_items(category, item_type, is_published);
create index if not exists zameel_library_items_featured_idx
  on public.zameel_library_items(is_featured desc, created_at desc);
create index if not exists zameel_library_items_keywords_gin
  on public.zameel_library_items using gin(keywords);

alter table public.zameel_library_categories enable row level security;
alter table public.zameel_library_items enable row level security;

drop policy if exists zameel_library_categories_read on public.zameel_library_categories;
create policy zameel_library_categories_read
on public.zameel_library_categories for select to authenticated
using (is_active);

drop policy if exists zameel_library_categories_admin on public.zameel_library_categories;
create policy zameel_library_categories_admin
on public.zameel_library_categories for all to authenticated
using (exists (
  select 1 from public.users u
  where u.id = auth.uid()
    and lower(coalesce(u.role,'')) in ('owner','admin')
))
with check (exists (
  select 1 from public.users u
  where u.id = auth.uid()
    and lower(coalesce(u.role,'')) in ('owner','admin')
));

drop policy if exists zameel_library_items_read_published on public.zameel_library_items;
create policy zameel_library_items_read_published
on public.zameel_library_items for select to authenticated
using (is_published);

drop policy if exists zameel_library_items_admin on public.zameel_library_items;
create policy zameel_library_items_admin
on public.zameel_library_items for all to authenticated
using (exists (
  select 1 from public.users u
  where u.id = auth.uid()
    and lower(coalesce(u.role,'')) in ('owner','admin')
))
with check (exists (
  select 1 from public.users u
  where u.id = auth.uid()
    and lower(coalesce(u.role,'')) in ('owner','admin')
));

grant select on public.zameel_library_categories to authenticated;
grant insert, update, delete on public.zameel_library_categories to authenticated;
grant select on public.zameel_library_items to authenticated;
grant insert, update, delete on public.zameel_library_items to authenticated;

insert into public.zameel_library_categories(slug, name_ar, sort_order)
values
  ('cat_001', 'إدارة الأعمال', 1),
  ('cat_002', 'الأحياء', 2),
  ('cat_003', 'الأمن السيبراني', 3),
  ('cat_004', 'الإحصاء', 4),
  ('cat_005', 'الإدارة العامة', 5),
  ('cat_006', 'الإعلام والصحافة', 6),
  ('cat_007', 'الاقتصاد', 7),
  ('cat_008', 'التاريخ', 8),
  ('cat_009', 'التربية', 9),
  ('cat_010', 'التسويق', 10),
  ('cat_011', 'التغذية', 11),
  ('cat_012', 'التمريض', 12),
  ('cat_013', 'التمويل', 13),
  ('cat_014', 'الجغرافيا', 14),
  ('cat_015', 'الجيولوجيا', 15),
  ('cat_016', 'الخدمة الاجتماعية', 16),
  ('cat_017', 'الدبلوماسية', 17),
  ('cat_018', 'الدراسات الأمنية', 18),
  ('cat_019', 'الذكاء الاصطناعي وعلوم البيانات', 19),
  ('cat_020', 'الرياضيات', 20),
  ('cat_021', 'الزراعة', 21),
  ('cat_022', 'السياحة والضيافة', 22),
  ('cat_023', 'الصحة العامة', 23),
  ('cat_024', 'الصيدلة', 24),
  ('cat_025', 'العلاقات الدولية', 25),
  ('cat_026', 'العلوم البيئية', 26),
  ('cat_027', 'العلوم السياسية', 27),
  ('cat_028', 'العلوم الطبية الأساسية', 28),
  ('cat_029', 'العمارة', 29),
  ('cat_030', 'الفلسفة', 30),
  ('cat_031', 'الفيزياء', 31),
  ('cat_032', 'القانون', 32),
  ('cat_033', 'القانون الدولي', 33),
  ('cat_034', 'الكيمياء', 34),
  ('cat_035', 'اللغة الإنجليزية', 35),
  ('cat_036', 'اللغة العربية', 36),
  ('cat_037', 'المحاسبة', 37),
  ('cat_038', 'الهندسة الصناعية', 38),
  ('cat_039', 'الهندسة الكهربائية', 39),
  ('cat_040', 'الهندسة المدنية', 40),
  ('cat_041', 'الهندسة الميكانيكية', 41),
  ('cat_042', 'حقوق الإنسان', 42),
  ('cat_043', 'دراسات السلام والنزاعات', 43),
  ('cat_044', 'ريادة الأعمال', 44),
  ('cat_045', 'علم الاجتماع', 45),
  ('cat_046', 'علم النفس', 46),
  ('cat_047', 'علوم الحاسوب', 47),
  ('cat_048', 'نظم المعلومات', 48),
  ('cat_049', 'نظم المعلومات الإدارية', 49),
  ('cat_050', 'هندسة البرمجيات', 50)
on conflict (name_ar) do update
set is_active = true,
    sort_order = excluded.sort_order,
    updated_at = now();

commit;
