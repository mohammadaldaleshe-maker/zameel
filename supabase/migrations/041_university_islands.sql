-- Zameel 041: add university islands to the campus-world registry.
-- Run once after migration 040.

begin;

insert into public.university_campuses
  (name_ar,name_en,center_latitude,center_longitude,campus_radius_meters,outer_ring_meters,is_active)
values
  ('الجامعة الأردنية','The University of Jordan',32.0138,35.8720,1100,3000,true),
  ('جامعة العلوم والتكنولوجيا الأردنية','Jordan University of Science and Technology',32.4931,35.9870,1700,3000,true),
  ('جامعة اليرموك','Yarmouk University',32.4833,36.0000,900,3000,true),
  ('الجامعة الهاشمية','The Hashemite University',32.1024,36.1850,1800,3000,true)
on conflict (name_ar) do update set
  name_en=excluded.name_en,
  center_latitude=excluded.center_latitude,
  center_longitude=excluded.center_longitude,
  campus_radius_meters=excluded.campus_radius_meters,
  outer_ring_meters=3000,
  is_active=true,
  updated_at=now();

commit;
