-- Maintenance 135: private audience data, targeting and manual wallet reconciliation.
begin;
create table if not exists public.zameel_promotion_settings(
 id boolean primary key default true check(id),wallet_number text not null default '',beneficiary text not null default '',
 enabled boolean not null default false,updated_at timestamptz not null default now());
insert into public.zameel_promotion_settings(id) values(true) on conflict do nothing;
alter table public.zameel_promotion_settings enable row level security;
revoke all on public.zameel_promotion_settings from public,anon,authenticated;
grant all on public.zameel_promotion_settings to service_role;
create table if not exists public.zameel_promotion_locations(name text primary key,governorate text not null);
create table if not exists public.zameel_promotion_universities(name text primary key,city text not null);
alter table public.zameel_promotion_locations enable row level security;
alter table public.zameel_promotion_universities enable row level security;
grant select on public.zameel_promotion_locations,public.zameel_promotion_universities to authenticated;
grant all on public.zameel_promotion_locations,public.zameel_promotion_universities to service_role;
drop policy if exists promotion_location_read on public.zameel_promotion_locations;
create policy promotion_location_read on public.zameel_promotion_locations for select to authenticated using(true);
drop policy if exists promotion_university_read on public.zameel_promotion_universities;
create policy promotion_university_read on public.zameel_promotion_universities for select to authenticated using(true);
insert into public.zameel_promotion_locations values('القويرة','العقبة') on conflict do nothing;
insert into public.zameel_promotion_locations values('الراشدية','العقبة') on conflict do nothing;
insert into public.zameel_promotion_locations values('الحميمة و العباسية و العسلية','العقبة') on conflict do nothing;
insert into public.zameel_promotion_locations values('حوض الديسة','العقبة') on conflict do nothing;
insert into public.zameel_promotion_locations values('الديسة','العقبة') on conflict do nothing;
insert into public.zameel_promotion_locations values('قريقرة وفينان','العقبة') on conflict do nothing;
insert into public.zameel_promotion_locations values('قريقرة و فينان','العقبة') on conflict do nothing;
insert into public.zameel_promotion_locations values('وادي عربة','العقبة') on conflict do nothing;
insert into public.zameel_promotion_locations values('وادي عربه','العقبة') on conflict do nothing;
insert into public.zameel_promotion_locations values('قطر ورحمة','العقبة') on conflict do nothing;
insert into public.zameel_promotion_locations values('عجلون','عجلون') on conflict do nothing;
insert into public.zameel_promotion_locations values('عنجرة','عجلون') on conflict do nothing;
insert into public.zameel_promotion_locations values('عين جنا','عجلون') on conflict do nothing;
insert into public.zameel_promotion_locations values('الروابي','عجلون') on conflict do nothing;
insert into public.zameel_promotion_locations values('الصفا','عجلون') on conflict do nothing;
insert into public.zameel_promotion_locations values('كفرنجة','عجلون') on conflict do nothing;
insert into public.zameel_promotion_locations values('راجب','عجلون') on conflict do nothing;
insert into public.zameel_promotion_locations values('الجنيد','عجلون') on conflict do nothing;
insert into public.zameel_promotion_locations values('صخرة','عجلون') on conflict do nothing;
insert into public.zameel_promotion_locations values('عبين و عبلين','عجلون') on conflict do nothing;
insert into public.zameel_promotion_locations values('الشفا','عجلون') on conflict do nothing;
insert into public.zameel_promotion_locations values('الهاشمية','عجلون') on conflict do nothing;
insert into public.zameel_promotion_locations values('حلاوة','عجلون') on conflict do nothing;
insert into public.zameel_promotion_locations values('الوهادنة','عجلون') on conflict do nothing;
insert into public.zameel_promotion_locations values('العيون','عجلون') on conflict do nothing;
insert into public.zameel_promotion_locations values('باعون','عجلون') on conflict do nothing;
insert into public.zameel_promotion_locations values('راسون','عجلون') on conflict do nothing;
insert into public.zameel_promotion_locations values('اوصره','عجلون') on conflict do nothing;
insert into public.zameel_promotion_locations values('عرجان','عجلون') on conflict do nothing;
insert into public.zameel_promotion_locations values('معان','معان') on conflict do nothing;
insert into public.zameel_promotion_locations values('الاشعري','معان') on conflict do nothing;
insert into public.zameel_promotion_locations values('المنشية','معان') on conflict do nothing;
insert into public.zameel_promotion_locations values('الجربا','معان') on conflict do nothing;
insert into public.zameel_promotion_locations values('اذرح','معان') on conflict do nothing;
insert into public.zameel_promotion_locations values('الجفر','معان') on conflict do nothing;
insert into public.zameel_promotion_locations values('الحسينية','معان') on conflict do nothing;
insert into public.zameel_promotion_locations values('الهاشمية — معان','معان') on conflict do nothing;
insert into public.zameel_promotion_locations values('الشراه','معان') on conflict do nothing;
insert into public.zameel_promotion_locations values('المريغة','معان') on conflict do nothing;
insert into public.zameel_promotion_locations values('الشوبك','معان') on conflict do nothing;
insert into public.zameel_promotion_locations values('العبدلية','معان') on conflict do nothing;
insert into public.zameel_promotion_locations values('حمزة','معان') on conflict do nothing;
insert into public.zameel_promotion_locations values('مادبا','مأدبا') on conflict do nothing;
insert into public.zameel_promotion_locations values('الفيصلية','مأدبا') on conflict do nothing;
insert into public.zameel_promotion_locations values('جرينة الشوابكة','مأدبا') on conflict do nothing;
insert into public.zameel_promotion_locations values('غرناطة و العريش','مأدبا') on conflict do nothing;
insert into public.zameel_promotion_locations values('ماعين','مأدبا') on conflict do nothing;
insert into public.zameel_promotion_locations values('المريجات و الحوية','مأدبا') on conflict do nothing;
insert into public.zameel_promotion_locations values('ذيبان','مأدبا') on conflict do nothing;
insert into public.zameel_promotion_locations values('العالية','مأدبا') on conflict do nothing;
insert into public.zameel_promotion_locations values('الشقيق','مأدبا') on conflict do nothing;
insert into public.zameel_promotion_locations values('لب و مليح','مأدبا') on conflict do nothing;
insert into public.zameel_promotion_locations values('لب','مأدبا') on conflict do nothing;
insert into public.zameel_promotion_locations values('مليح','مأدبا') on conflict do nothing;
insert into public.zameel_promotion_locations values('جبل بني حميدة','مأدبا') on conflict do nothing;
insert into public.zameel_promotion_locations values('المفرق','المفرق') on conflict do nothing;
insert into public.zameel_promotion_locations values('ام النعام الشرقية','المفرق') on conflict do nothing;
insert into public.zameel_promotion_locations values('ايدون بني حسن','المفرق') on conflict do nothing;
insert into public.zameel_promotion_locations values('ثغرة الجب','المفرق') on conflict do nothing;
insert into public.zameel_promotion_locations values('ام النعام الغربية','المفرق') on conflict do nothing;
insert into public.zameel_promotion_locations values('الغدير الابيض','المفرق') on conflict do nothing;
insert into public.zameel_promotion_locations values('رحاب','المفرق') on conflict do nothing;
insert into public.zameel_promotion_locations values('رحاب بني حسن','المفرق') on conflict do nothing;
insert into public.zameel_promotion_locations values('الدجنية','المفرق') on conflict do nothing;
insert into public.zameel_promotion_locations values('حمامة العليمات','المفرق') on conflict do nothing;
insert into public.zameel_promotion_locations values('حمامة العموش','المفرق') on conflict do nothing;
insert into public.zameel_promotion_locations values('هويشان','المفرق') on conflict do nothing;
insert into public.zameel_promotion_locations values('الدقمسة','المفرق') on conflict do nothing;
insert into public.zameel_promotion_locations values('نادرة','المفرق') on conflict do nothing;
insert into public.zameel_promotion_locations values('المدور','المفرق') on conflict do nothing;
insert into public.zameel_promotion_locations values('ام بطمه','المفرق') on conflict do nothing;
insert into public.zameel_promotion_locations values('دحل','المفرق') on conflict do nothing;
insert into public.zameel_promotion_locations values('خطلة','المفرق') on conflict do nothing;
insert into public.zameel_promotion_locations values('حميدو الكرام','المفرق') on conflict do nothing;
insert into public.zameel_promotion_locations values('ابو السوس','المفرق') on conflict do nothing;
insert into public.zameel_promotion_locations values('ام رمانه','المفرق') on conflict do nothing;
insert into public.zameel_promotion_locations values('ام خروبه','المفرق') on conflict do nothing;
insert into public.zameel_promotion_locations values('السحري','المفرق') on conflict do nothing;
insert into public.zameel_promotion_locations values('بلعما','المفرق') on conflict do nothing;
insert into public.zameel_promotion_locations values('حيان الرويبض','المفرق') on conflict do nothing;
insert into public.zameel_promotion_locations values('الزنية','المفرق') on conflict do nothing;
insert into public.zameel_promotion_locations values('المزرعة','المفرق') on conflict do nothing;
insert into public.zameel_promotion_locations values('الخربة السمراء','المفرق') on conflict do nothing;
insert into public.zameel_promotion_locations values('حوشا','المفرق') on conflict do nothing;
insert into public.zameel_promotion_locations values('الحمراء','المفرق') on conflict do nothing;
insert into public.zameel_promotion_locations values('المنصورة','المفرق') on conflict do nothing;
insert into public.zameel_promotion_locations values('الطفيلة','الطفيلة') on conflict do nothing;
insert into public.zameel_promotion_locations values('عين البيضاء','الطفيلة') on conflict do nothing;
insert into public.zameel_promotion_locations values('العيص','الطفيلة') on conflict do nothing;
insert into public.zameel_promotion_locations values('الحسين ( رويم','الطفيلة') on conflict do nothing;
insert into public.zameel_promotion_locations values('صنفحه','الطفيلة') on conflict do nothing;
insert into public.zameel_promotion_locations values('عرفه','الطفيلة') on conflict do nothing;
insert into public.zameel_promotion_locations values('عيمه','الطفيلة') on conflict do nothing;
insert into public.zameel_promotion_locations values('بصيرا','الطفيلة') on conflict do nothing;
insert into public.zameel_promotion_locations values('غرندل','الطفيلة') on conflict do nothing;
insert into public.zameel_promotion_locations values('القادسية','الطفيلة') on conflict do nothing;
insert into public.zameel_promotion_locations values('اسكان مصنع اسمنت الجنوب','الطفيلة') on conflict do nothing;
insert into public.zameel_promotion_locations values('ضانا','الطفيلة') on conflict do nothing;
insert into public.zameel_promotion_locations values('الحسا','الطفيلة') on conflict do nothing;
insert into public.zameel_promotion_locations values('جرف الدراويش','الطفيلة') on conflict do nothing;
insert into public.zameel_promotion_locations values('الجيزة','الطفيلة') on conflict do nothing;
insert into public.zameel_promotion_locations values('القسطل و المشتى','الطفيلة') on conflict do nothing;
insert into public.zameel_promotion_locations values('منجا و الزيتونة','الطفيلة') on conflict do nothing;
insert into public.zameel_promotion_locations values('اللبن و الطنيب','الطفيلة') on conflict do nothing;
insert into public.zameel_promotion_locations values('ام العمد و الخضراء','الطفيلة') on conflict do nothing;
insert into public.zameel_promotion_locations values('نتل و الزعفران','الطفيلة') on conflict do nothing;
insert into public.zameel_promotion_locations values('حواره و المناره و جلول','الطفيلة') on conflict do nothing;
insert into public.zameel_promotion_locations values('ام الوليد و ام قيصر','الطفيلة') on conflict do nothing;
insert into public.zameel_promotion_locations values('ارينبة الغربية','الطفيلة') on conflict do nothing;
insert into public.zameel_promotion_locations values('العامرية','الطفيلة') on conflict do nothing;
insert into public.zameel_promotion_locations values('دليلة','الطفيلة') on conflict do nothing;
insert into public.zameel_promotion_locations values('صوفه','الطفيلة') on conflict do nothing;
insert into public.zameel_promotion_locations values('النيروز','الطفيلة') on conflict do nothing;
insert into public.zameel_promotion_locations values('ام رمانه — الطفيلة','الطفيلة') on conflict do nothing;
insert into public.zameel_promotion_locations values('الغبية','الطفيلة') on conflict do nothing;
insert into public.zameel_promotion_locations values('القنيطرة','الطفيلة') on conflict do nothing;
insert into public.zameel_promotion_locations values('ات منطقة المطار','الطفيلة') on conflict do nothing;
insert into public.zameel_promotion_locations values('السيفيه','الطفيلة') on conflict do nothing;
insert into public.zameel_promotion_locations values('مخيم الطالبية زويزا','الطفيلة') on conflict do nothing;
insert into public.zameel_promotion_locations values('ناعور','الطفيلة') on conflict do nothing;
insert into public.zameel_promotion_locations values('العدسية','الطفيلة') on conflict do nothing;
insert into public.zameel_promotion_locations values('الروضة','الطفيلة') on conflict do nothing;
insert into public.zameel_promotion_locations values('حسبان','الطفيلة') on conflict do nothing;
insert into public.zameel_promotion_locations values('المشقر','الطفيلة') on conflict do nothing;
insert into public.zameel_promotion_locations values('العال','الطفيلة') on conflict do nothing;
insert into public.zameel_promotion_locations values('السلط','البلقاء') on conflict do nothing;
insert into public.zameel_promotion_locations values('يرقا','البلقاء') on conflict do nothing;
insert into public.zameel_promotion_locations values('عيرا','البلقاء') on conflict do nothing;
insert into public.zameel_promotion_locations values('زي','البلقاء') on conflict do nothing;
insert into public.zameel_promotion_locations values('علان','البلقاء') on conflict do nothing;
insert into public.zameel_promotion_locations values('الرميمين','البلقاء') on conflict do nothing;
insert into public.zameel_promotion_locations values('ام جوزه','البلقاء') on conflict do nothing;
insert into public.zameel_promotion_locations values('وادي الحور و تجمع سكاني اليزيدية','البلقاء') on conflict do nothing;
insert into public.zameel_promotion_locations values('عين الباشا','البلقاء') on conflict do nothing;
insert into public.zameel_promotion_locations values('صافوت','البلقاء') on conflict do nothing;
insert into public.zameel_promotion_locations values('ابو نصير','البلقاء') on conflict do nothing;
insert into public.zameel_promotion_locations values('ام الدنانير','البلقاء') on conflict do nothing;
insert into public.zameel_promotion_locations values('موبص','البلقاء') on conflict do nothing;
insert into public.zameel_promotion_locations values('السليحي','البلقاء') on conflict do nothing;
insert into public.zameel_promotion_locations values('سلحوب','البلقاء') on conflict do nothing;
insert into public.zameel_promotion_locations values('ام انجاصه','البلقاء') on conflict do nothing;
insert into public.zameel_promotion_locations values('الرمان','البلقاء') on conflict do nothing;
insert into public.zameel_promotion_locations values('العارضة','البلقاء') on conflict do nothing;
insert into public.zameel_promotion_locations values('الصبيحي','البلقاء') on conflict do nothing;
insert into public.zameel_promotion_locations values('خالد بن الوليد','البلقاء') on conflict do nothing;
insert into public.zameel_promotion_locations values('بيوضه','البلقاء') on conflict do nothing;
insert into public.zameel_promotion_locations values('سوميا','البلقاء') on conflict do nothing;
insert into public.zameel_promotion_locations values('دير علا','البلقاء') on conflict do nothing;
insert into public.zameel_promotion_locations values('ابو عبيدة و البلاونة','البلقاء') on conflict do nothing;
insert into public.zameel_promotion_locations values('خزمه','البلقاء') on conflict do nothing;
insert into public.zameel_promotion_locations values('ضرار','البلقاء') on conflict do nothing;
insert into public.zameel_promotion_locations values('الطوال الشمالي','البلقاء') on conflict do nothing;
insert into public.zameel_promotion_locations values('الطوال الجنوبي','البلقاء') on conflict do nothing;
insert into public.zameel_promotion_locations values('معدي','البلقاء') on conflict do nothing;
insert into public.zameel_promotion_locations values('مثلث العارضة','البلقاء') on conflict do nothing;
insert into public.zameel_promotion_locations values('ظهر الرمل','البلقاء') on conflict do nothing;
insert into public.zameel_promotion_locations values('داميا','البلقاء') on conflict do nothing;
insert into public.zameel_promotion_locations values('سويمة','البلقاء') on conflict do nothing;
insert into public.zameel_promotion_locations values('الشونة الوسطى','البلقاء') on conflict do nothing;
insert into public.zameel_promotion_locations values('الشونة الجديدة','البلقاء') on conflict do nothing;
insert into public.zameel_promotion_locations values('الشونة الجنوبية','البلقاء') on conflict do nothing;
insert into public.zameel_promotion_locations values('الكرامة','البلقاء') on conflict do nothing;
insert into public.zameel_promotion_locations values('الكفرين','البلقاء') on conflict do nothing;
insert into public.zameel_promotion_locations values('الروضة — البلقاء','البلقاء') on conflict do nothing;
insert into public.zameel_promotion_locations values('الرامة','البلقاء') on conflict do nothing;
insert into public.zameel_promotion_locations values('الفحيص','البلقاء') on conflict do nothing;
insert into public.zameel_promotion_locations values('ماحص','البلقاء') on conflict do nothing;
insert into public.zameel_promotion_locations values('اربد','إربد') on conflict do nothing;
insert into public.zameel_promotion_locations values('فوعرا','إربد') on conflict do nothing;
insert into public.zameel_promotion_locations values('بيت راس','إربد') on conflict do nothing;
insert into public.zameel_promotion_locations values('كفر جايز','إربد') on conflict do nothing;
insert into public.zameel_promotion_locations values('حكما','إربد') on conflict do nothing;
insert into public.zameel_promotion_locations values('مرو','إربد') on conflict do nothing;
insert into public.zameel_promotion_locations values('علعال','إربد') on conflict do nothing;
insert into public.zameel_promotion_locations values('المغير','إربد') on conflict do nothing;
insert into public.zameel_promotion_locations values('سال','إربد') on conflict do nothing;
insert into public.zameel_promotion_locations values('بشرى','إربد') on conflict do nothing;
insert into public.zameel_promotion_locations values('حواره','إربد') on conflict do nothing;
insert into public.zameel_promotion_locations values('الصريح','إربد') on conflict do nothing;
insert into public.zameel_promotion_locations values('ايدون','إربد') on conflict do nothing;
insert into public.zameel_promotion_locations values('الحصن','إربد') on conflict do nothing;
insert into public.zameel_promotion_locations values('النعيمة','إربد') on conflict do nothing;
insert into public.zameel_promotion_locations values('كتم','إربد') on conflict do nothing;
insert into public.zameel_promotion_locations values('غرب اربد','إربد') on conflict do nothing;
insert into public.zameel_promotion_locations values('كفر يوبا','إربد') on conflict do nothing;
insert into public.zameel_promotion_locations values('بيت يافا','إربد') on conflict do nothing;
insert into public.zameel_promotion_locations values('زحر','إربد') on conflict do nothing;
insert into public.zameel_promotion_locations values('سوم','إربد') on conflict do nothing;
insert into public.zameel_promotion_locations values('ججين','إربد') on conflict do nothing;
insert into public.zameel_promotion_locations values('دوقرا','إربد') on conflict do nothing;
insert into public.zameel_promotion_locations values('الرمثا','إربد') on conflict do nothing;
insert into public.zameel_promotion_locations values('البويضه','إربد') on conflict do nothing;
insert into public.zameel_promotion_locations values('سهل حوران','إربد') on conflict do nothing;
insert into public.zameel_promotion_locations values('الطره','إربد') on conflict do nothing;
insert into public.zameel_promotion_locations values('الشجره','إربد') on conflict do nothing;
insert into public.zameel_promotion_locations values('عمراوه','إربد') on conflict do nothing;
insert into public.zameel_promotion_locations values('الذنيبه','إربد') on conflict do nothing;
insert into public.zameel_promotion_locations values('خالد بن الوليد — إربد','إربد') on conflict do nothing;
insert into public.zameel_promotion_locations values('ملكا','إربد') on conflict do nothing;
insert into public.zameel_promotion_locations values('المنصورة — إربد','إربد') on conflict do nothing;
insert into public.zameel_promotion_locations values('ام قيس','إربد') on conflict do nothing;
insert into public.zameel_promotion_locations values('الحمة الاردنية','إربد') on conflict do nothing;
insert into public.zameel_promotion_locations values('المخيبة','إربد') on conflict do nothing;
insert into public.zameel_promotion_locations values('الكفارات','إربد') on conflict do nothing;
insert into public.zameel_promotion_locations values('حبراص','إربد') on conflict do nothing;
insert into public.zameel_promotion_locations values('حرثا','إربد') on conflict do nothing;
insert into public.zameel_promotion_locations values('يبلا','إربد') on conflict do nothing;
insert into public.zameel_promotion_locations values('الرفيد','إربد') on conflict do nothing;
insert into public.zameel_promotion_locations values('عقربا','إربد') on conflict do nothing;
insert into public.zameel_promotion_locations values('كفرسوم','إربد') on conflict do nothing;
insert into public.zameel_promotion_locations values('اليرموك','إربد') on conflict do nothing;
insert into public.zameel_promotion_locations values('حريما','إربد') on conflict do nothing;
insert into public.zameel_promotion_locations values('خرجا','إربد') on conflict do nothing;
insert into public.zameel_promotion_locations values('معاذ بن جبل','إربد') on conflict do nothing;
insert into public.zameel_promotion_locations values('الشونة الشمالية','إربد') on conflict do nothing;
insert into public.zameel_promotion_locations values('العدسية — إربد','إربد') on conflict do nothing;
insert into public.zameel_promotion_locations values('المنشية — إربد','إربد') on conflict do nothing;
insert into public.zameel_promotion_locations values('وقاص','إربد') on conflict do nothing;
insert into public.zameel_promotion_locations values('الشعلة','إربد') on conflict do nothing;
insert into public.zameel_promotion_locations values('سمر','إربد') on conflict do nothing;
insert into public.zameel_promotion_locations values('سحم','إربد') on conflict do nothing;
insert into public.zameel_promotion_locations values('السرو','إربد') on conflict do nothing;
insert into public.zameel_promotion_locations values('سما الروسان','إربد') on conflict do nothing;
insert into public.zameel_promotion_locations values('حاتم','إربد') on conflict do nothing;
insert into public.zameel_promotion_locations values('طبقة فحل','إربد') on conflict do nothing;
insert into public.zameel_promotion_locations values('الشيخ حسين','إربد') on conflict do nothing;
insert into public.zameel_promotion_locations values('المشارع','إربد') on conflict do nothing;
insert into public.zameel_promotion_locations values('شرحبيل بن حسنة','إربد') on conflict do nothing;
insert into public.zameel_promotion_locations values('كريمه','إربد') on conflict do nothing;
insert into public.zameel_promotion_locations values('وادي الريان','إربد') on conflict do nothing;
insert into public.zameel_promotion_locations values('المزار','إربد') on conflict do nothing;
insert into public.zameel_promotion_locations values('المزار الشمالي','إربد') on conflict do nothing;
insert into public.zameel_promotion_locations values('عنبه','إربد') on conflict do nothing;
insert into public.zameel_promotion_locations values('دير يوسف','إربد') on conflict do nothing;
insert into public.zameel_promotion_locations values('جحفيه','إربد') on conflict do nothing;
insert into public.zameel_promotion_locations values('ارحابا','إربد') on conflict do nothing;
insert into public.zameel_promotion_locations values('زوبيا','إربد') on conflict do nothing;
insert into public.zameel_promotion_locations values('الطيبة','إربد') on conflict do nothing;
insert into public.zameel_promotion_locations values('دير السعنة','إربد') on conflict do nothing;
insert into public.zameel_promotion_locations values('صما','إربد') on conflict do nothing;
insert into public.zameel_promotion_locations values('ايل','معان') on conflict do nothing;
insert into public.zameel_promotion_locations values('الفردخ','معان') on conflict do nothing;
insert into public.zameel_promotion_locations values('الامير راشد','معان') on conflict do nothing;
insert into public.zameel_promotion_locations values('بسطة','معان') on conflict do nothing;
insert into public.zameel_promotion_locations values('جرش','جرش') on conflict do nothing;
insert into public.zameel_promotion_locations values('سوف','جرش') on conflict do nothing;
insert into public.zameel_promotion_locations values('الكفيرء','جرش') on conflict do nothing;
insert into public.zameel_promotion_locations values('المعراض','جرش') on conflict do nothing;
insert into public.zameel_promotion_locations values('ريمون','جرش') on conflict do nothing;
insert into public.zameel_promotion_locations values('نحلة','جرش') on conflict do nothing;
insert into public.zameel_promotion_locations values('الكته','جرش') on conflict do nothing;
insert into public.zameel_promotion_locations values('ساكب','جرش') on conflict do nothing;
insert into public.zameel_promotion_locations values('باب عمان','جرش') on conflict do nothing;
insert into public.zameel_promotion_locations values('مرصع','جرش') on conflict do nothing;
insert into public.zameel_promotion_locations values('المصطبة','جرش') on conflict do nothing;
insert into public.zameel_promotion_locations values('جبة','جرش') on conflict do nothing;
insert into public.zameel_promotion_locations values('النسيم','جرش') on conflict do nothing;
insert into public.zameel_promotion_locations values('قفقفا','جرش') on conflict do nothing;
insert into public.zameel_promotion_locations values('الربوه','جرش') on conflict do nothing;
insert into public.zameel_promotion_locations values('كفرخل','جرش') on conflict do nothing;
insert into public.zameel_promotion_locations values('بليلا','جرش') on conflict do nothing;
insert into public.zameel_promotion_locations values('برما','جرش') on conflict do nothing;
insert into public.zameel_promotion_locations values('منشية بني حسن','المفرق') on conflict do nothing;
insert into public.zameel_promotion_locations values('الخالدية','المفرق') on conflict do nothing;
insert into public.zameel_promotion_locations values('الباسلية','المفرق') on conflict do nothing;
insert into public.zameel_promotion_locations values('الحرش','المفرق') on conflict do nothing;
insert into public.zameel_promotion_locations values('فاع','المفرق') on conflict do nothing;
insert into public.zameel_promotion_locations values('الزعتري والمنشية','المفرق') on conflict do nothing;
insert into public.zameel_promotion_locations values('الزعتري','المفرق') on conflict do nothing;
insert into public.zameel_promotion_locations values('منشية السلطة','المفرق') on conflict do nothing;
insert into public.zameel_promotion_locations values('السرحان','المفرق') on conflict do nothing;
insert into public.zameel_promotion_locations values('سما السرحان','المفرق') on conflict do nothing;
insert into public.zameel_promotion_locations values('مغير السرحان','المفرق') on conflict do nothing;
insert into public.zameel_promotion_locations values('جابر السرحان','المفرق') on conflict do nothing;
insert into public.zameel_promotion_locations values('روابي السرحان','المفرق') on conflict do nothing;
insert into public.zameel_promotion_locations values('الامير حسين بن عبدالله','المفرق') on conflict do nothing;
insert into public.zameel_promotion_locations values('ام السرب','المفرق') on conflict do nothing;
insert into public.zameel_promotion_locations values('الباعج','المفرق') on conflict do nothing;
insert into public.zameel_promotion_locations values('النهضة','المفرق') on conflict do nothing;
insert into public.zameel_promotion_locations values('الزبيدية','المفرق') on conflict do nothing;
insert into public.zameel_promotion_locations values('حويجة','المفرق') on conflict do nothing;
insert into public.zameel_promotion_locations values('ام الجمال','المفرق') on conflict do nothing;
insert into public.zameel_promotion_locations values('الكوم الاحمر و رسم الحصان','المفرق') on conflict do nothing;
insert into public.zameel_promotion_locations values('روضة الاميرة بسمة','المفرق') on conflict do nothing;
insert into public.zameel_promotion_locations values('عمره و عميرة','المفرق') on conflict do nothing;
insert into public.zameel_promotion_locations values('صبحا والدفيانه','المفرق') on conflict do nothing;
insert into public.zameel_promotion_locations values('صبحا و صبحية','المفرق') on conflict do nothing;
insert into public.zameel_promotion_locations values('الدفيانة','المفرق') on conflict do nothing;
insert into public.zameel_promotion_locations values('كوم الرف','المفرق') on conflict do nothing;
insert into public.zameel_promotion_locations values('ام القطين والمكيفته','المفرق') on conflict do nothing;
insert into public.zameel_promotion_locations values('ام القطين','المفرق') on conflict do nothing;
insert into public.zameel_promotion_locations values('المكيفته','المفرق') on conflict do nothing;
insert into public.zameel_promotion_locations values('دير الكهف','المفرق') on conflict do nothing;
insert into public.zameel_promotion_locations values('دير القن','المفرق') on conflict do nothing;
insert into public.zameel_promotion_locations values('قاسم','المفرق') on conflict do nothing;
insert into public.zameel_promotion_locations values('الرويشد','المفرق') on conflict do nothing;
insert into public.zameel_promotion_locations values('منشية الغياث','المفرق') on conflict do nothing;
insert into public.zameel_promotion_locations values('الروضة — المفرق','المفرق') on conflict do nothing;
insert into public.zameel_promotion_locations values('الريشة الغربية','المفرق') on conflict do nothing;
insert into public.zameel_promotion_locations values('الاثني','المفرق') on conflict do nothing;
insert into public.zameel_promotion_locations values('المشاقيق','المفرق') on conflict do nothing;
insert into public.zameel_promotion_locations values('الريشة الشرقية','المفرق') on conflict do nothing;
insert into public.zameel_promotion_locations values('الرقبان','المفرق') on conflict do nothing;
insert into public.zameel_promotion_locations values('مركز حدود الكرامة','المفرق') on conflict do nothing;
insert into public.zameel_promotion_locations values('الصالحية و نايفة','المفرق') on conflict do nothing;
insert into public.zameel_promotion_locations values('الصالحية','المفرق') on conflict do nothing;
insert into public.zameel_promotion_locations values('نايفة','المفرق') on conflict do nothing;
insert into public.zameel_promotion_locations values('بني هاشم','المفرق') on conflict do nothing;
insert into public.zameel_promotion_locations values('الصفاوي','المفرق') on conflict do nothing;
insert into public.zameel_promotion_locations values('الزرقاء','الزرقاء') on conflict do nothing;
insert into public.zameel_promotion_locations values('الرصيفة','الزرقاء') on conflict do nothing;
insert into public.zameel_promotion_locations values('الهاشمية — الزرقاء','الزرقاء') on conflict do nothing;
insert into public.zameel_promotion_locations values('أم صليح وغرسا','الزرقاء') on conflict do nothing;
insert into public.zameel_promotion_locations values('السخنة','الزرقاء') on conflict do nothing;
insert into public.zameel_promotion_locations values('قرى بني هاشم','الزرقاء') on conflict do nothing;
insert into public.zameel_promotion_locations values('بيرين','الزرقاء') on conflict do nothing;
insert into public.zameel_promotion_locations values('أم رمانة ورجم الشوك','الزرقاء') on conflict do nothing;
insert into public.zameel_promotion_locations values('العالوك المسرات','الزرقاء') on conflict do nothing;
insert into public.zameel_promotion_locations values('الكمشة','الزرقاء') on conflict do nothing;
insert into public.zameel_promotion_locations values('صروت','الزرقاء') on conflict do nothing;
insert into public.zameel_promotion_locations values('الوهادنة — الزرقاء','الزرقاء') on conflict do nothing;
insert into public.zameel_promotion_locations values('الظليل','الزرقاء') on conflict do nothing;
insert into public.zameel_promotion_locations values('الحلابات','الزرقاء') on conflict do nothing;
insert into public.zameel_promotion_locations values('الأزرق','الزرقاء') on conflict do nothing;
insert into public.zameel_promotion_locations values('الأزرق الشمالي','الزرقاء') on conflict do nothing;
insert into public.zameel_promotion_locations values('الأزرق الجنوبي','الزرقاء') on conflict do nothing;
insert into public.zameel_promotion_locations values('منطقة العمري الحدودية','الزرقاء') on conflict do nothing;
insert into public.zameel_promotion_locations values('عرجان — الزرقاء','الزرقاء') on conflict do nothing;
insert into public.zameel_promotion_locations values('الكرك','الكرك') on conflict do nothing;
insert into public.zameel_promotion_locations values('بذان وبردى','الكرك') on conflict do nothing;
insert into public.zameel_promotion_locations values('العدنانية','الكرك') on conflict do nothing;
insert into public.zameel_promotion_locations values('منشية ابو حمور','الكرك') on conflict do nothing;
insert into public.zameel_promotion_locations values('ادر','الكرك') on conflict do nothing;
insert into public.zameel_promotion_locations values('الجديدة','الكرك') on conflict do nothing;
insert into public.zameel_promotion_locations values('زيد بن حارثة','الكرك') on conflict do nothing;
insert into public.zameel_promotion_locations values('الشهابية','الكرك') on conflict do nothing;
insert into public.zameel_promotion_locations values('الثنية','الكرك') on conflict do nothing;
insert into public.zameel_promotion_locations values('وادي الكرك','الكرك') on conflict do nothing;
insert into public.zameel_promotion_locations values('السلطاني','الكرك') on conflict do nothing;
insert into public.zameel_promotion_locations values('الوادي الابيض','الكرك') on conflict do nothing;
insert into public.zameel_promotion_locations values('القطرانة','الكرك') on conflict do nothing;
insert into public.zameel_promotion_locations values('طلال','الكرك') on conflict do nothing;
insert into public.zameel_promotion_locations values('الجدعا','الكرك') on conflict do nothing;
insert into public.zameel_promotion_locations values('مؤاب','الكرك') on conflict do nothing;
insert into public.zameel_promotion_locations values('محي','الكرك') on conflict do nothing;
insert into public.zameel_promotion_locations values('ذات راس','الكرك') on conflict do nothing;
insert into public.zameel_promotion_locations values('مؤته والمزار','الكرك') on conflict do nothing;
insert into public.zameel_promotion_locations values('سول','الكرك') on conflict do nothing;
insert into public.zameel_promotion_locations values('المزار الجنوبي','الكرك') on conflict do nothing;
insert into public.zameel_promotion_locations values('العراق','الكرك') on conflict do nothing;
insert into public.zameel_promotion_locations values('الطيبة — الكرك','الكرك') on conflict do nothing;
insert into public.zameel_promotion_locations values('جعفر','الكرك') on conflict do nothing;
insert into public.zameel_promotion_locations values('عي','الكرك') on conflict do nothing;
insert into public.zameel_promotion_locations values('اعي','الكرك') on conflict do nothing;
insert into public.zameel_promotion_locations values('جوزا','الكرك') on conflict do nothing;
insert into public.zameel_promotion_locations values('كثرب','الكرك') on conflict do nothing;
insert into public.zameel_promotion_locations values('شيحان','الكرك') on conflict do nothing;
insert into public.zameel_promotion_locations values('السماكية','الكرك') on conflict do nothing;
insert into public.zameel_promotion_locations values('القصر','الكرك') on conflict do nothing;
insert into public.zameel_promotion_locations values('الياروت','الكرك') on conflict do nothing;
insert into public.zameel_promotion_locations values('الربة','الكرك') on conflict do nothing;
insert into public.zameel_promotion_locations values('عبدالله بن رواحه','الكرك') on conflict do nothing;
insert into public.zameel_promotion_locations values('فقوع','الكرك') on conflict do nothing;
insert into public.zameel_promotion_locations values('امرع','الكرك') on conflict do nothing;
insert into public.zameel_promotion_locations values('صرفا','الكرك') on conflict do nothing;
insert into public.zameel_promotion_locations values('الاغوار الجنوبية','الكرك') on conflict do nothing;
insert into public.zameel_promotion_locations values('غور المزرعة والحديثة','الكرك') on conflict do nothing;
insert into public.zameel_promotion_locations values('غور الصافي','الكرك') on conflict do nothing;
insert into public.zameel_promotion_locations values('عمّان','العاصمة') on conflict do nothing;
insert into public.zameel_promotion_locations values('العقبة','العقبة') on conflict do nothing;
insert into public.zameel_promotion_locations values('إربد','إربد') on conflict do nothing;
insert into public.zameel_promotion_locations values('مأدبا','مأدبا') on conflict do nothing;
insert into public.zameel_promotion_locations values('وادي موسى','معان') on conflict do nothing;
insert into public.zameel_promotion_locations values('البتراء','معان') on conflict do nothing;
insert into public.zameel_promotion_locations values('مؤتة','الكرك') on conflict do nothing;
insert into public.zameel_promotion_locations values('كفر أسد','إربد') on conflict do nothing;
insert into public.zameel_promotion_locations values('دير أبي سعيد','إربد') on conflict do nothing;
insert into public.zameel_promotion_locations values('كفر الماء','إربد') on conflict do nothing;
insert into public.zameel_promotion_locations values('تبنة','إربد') on conflict do nothing;
insert into public.zameel_promotion_locations values('سحاب','العاصمة') on conflict do nothing;
insert into public.zameel_promotion_locations values('أم البساتين','العاصمة') on conflict do nothing;
insert into public.zameel_promotion_locations values('الموقر','العاصمة') on conflict do nothing;
insert into public.zameel_promotion_locations values('أم الرصاص','العاصمة') on conflict do nothing;
insert into public.zameel_promotion_universities values('الجامعة الأردنية','عمّان') on conflict(name) do update set city=excluded.city;
insert into public.zameel_promotion_universities values('جامعة العلوم والتكنولوجيا الأردنية','إربد') on conflict(name) do update set city=excluded.city;
insert into public.zameel_promotion_universities values('جامعة اليرموك','إربد') on conflict(name) do update set city=excluded.city;
insert into public.zameel_promotion_universities values('الجامعة الهاشمية','الزرقاء') on conflict(name) do update set city=excluded.city;
insert into public.zameel_promotion_universities values('جامعة مؤتة','الكرك') on conflict(name) do update set city=excluded.city;
insert into public.zameel_promotion_universities values('جامعة آل البيت','المفرق') on conflict(name) do update set city=excluded.city;
insert into public.zameel_promotion_universities values('جامعة البلقاء التطبيقية','السلط') on conflict(name) do update set city=excluded.city;
insert into public.zameel_promotion_universities values('جامعة الحسين بن طلال','معان') on conflict(name) do update set city=excluded.city;
insert into public.zameel_promotion_universities values('جامعة الطفيلة التقنية','الطفيلة') on conflict(name) do update set city=excluded.city;
insert into public.zameel_promotion_universities values('الجامعة الألمانية الأردنية','عمّان') on conflict(name) do update set city=excluded.city;
insert into public.zameel_promotion_universities values('جامعة الأميرة سمية للتكنولوجيا','عمّان') on conflict(name) do update set city=excluded.city;
insert into public.zameel_promotion_universities values('جامعة عمان الأهلية','عمّان') on conflict(name) do update set city=excluded.city;
insert into public.zameel_promotion_universities values('جامعة الزيتونة الأردنية','عمّان') on conflict(name) do update set city=excluded.city;
insert into public.zameel_promotion_universities values('جامعة العلوم التطبيقية الخاصة','عمّان') on conflict(name) do update set city=excluded.city;
insert into public.zameel_promotion_universities values('جامعة فيلادلفيا','عمّان') on conflict(name) do update set city=excluded.city;
insert into public.zameel_promotion_universities values('جامعة الشرق الأوسط','عمّان') on conflict(name) do update set city=excluded.city;
insert into public.zameel_promotion_universities values('جامعة عمان العربية','عمّان') on conflict(name) do update set city=excluded.city;
insert into public.zameel_promotion_universities values('جامعة الزرقاء','الزرقاء') on conflict(name) do update set city=excluded.city;
insert into public.zameel_promotion_universities values('جامعة جدارا','إربد') on conflict(name) do update set city=excluded.city;
insert into public.zameel_promotion_universities values('جامعة إربد الأهلية','إربد') on conflict(name) do update set city=excluded.city;
insert into public.zameel_promotion_universities values('جامعة جرش','جرش') on conflict(name) do update set city=excluded.city;
insert into public.zameel_promotion_universities values('جامعة البترا','عمّان') on conflict(name) do update set city=excluded.city;
insert into public.zameel_promotion_universities values('جامعة الإسراء','عمّان') on conflict(name) do update set city=excluded.city;
insert into public.zameel_promotion_universities values('جامعة العلوم الإسلامية العالمية','عمّان') on conflict(name) do update set city=excluded.city;
insert into public.zameel_promotion_universities values('الجامعة العربية المفتوحة','عمّان') on conflict(name) do update set city=excluded.city;
insert into public.zameel_promotion_universities values('جامعة عجلون الوطنية','عجلون') on conflict(name) do update set city=excluded.city;
insert into public.zameel_promotion_universities values('الجامعة الأمريكية في مادبا','مادبا') on conflict(name) do update set city=excluded.city;
insert into public.zameel_promotion_universities values('جامعة العقبة للتكنولوجيا','العقبة') on conflict(name) do update set city=excluded.city;

create table if not exists public.zameel_audience_profiles(
 user_id uuid primary key references public.users(id) on delete cascade,
 birth_date date not null,city text not null references public.zameel_promotion_locations(name),
 gender text not null check(gender in ('male','female')),country text not null default 'JO' check(country='JO'),updated_at timestamptz not null default now());
alter table public.zameel_audience_profiles enable row level security;
revoke all on public.zameel_audience_profiles from public,anon,authenticated;
grant select on public.zameel_audience_profiles to authenticated;
grant all on public.zameel_audience_profiles to service_role;
drop policy if exists audience_owner_read on public.zameel_audience_profiles;
create policy audience_owner_read on public.zameel_audience_profiles for select to authenticated using(user_id=auth.uid());
create or replace function public.zameel_save_audience_profile(p_birth_date date,p_city text,p_gender text) returns void
language plpgsql security definer set search_path='' as $$ begin
 if auth.uid() is null or not coalesce(public.zameel_account_can_write(),false) then raise exception 'account_unavailable';end if;
 if p_birth_date is null or p_birth_date<date '1900-01-01' or p_birth_date>current_date or p_gender is null or p_gender not in ('male','female') or not exists(select 1 from public.zameel_promotion_locations where name=p_city) then raise exception 'invalid_audience_profile';end if;
 insert into public.zameel_audience_profiles(user_id,birth_date,city,gender) values(auth.uid(),p_birth_date,p_city,p_gender)
 on conflict(user_id) do update set birth_date=excluded.birth_date,city=excluded.city,gender=excluded.gender,updated_at=now();
end $$;
alter table public.zameel_post_promotions
 add column if not exists audience_type text not null default 'general' check(audience_type in ('general','students')),
 add column if not exists countrywide boolean not null default true,
 add column if not exists target_cities text[] not null default '{}',
 add column if not exists target_universities text[] not null default '{}',
 add column if not exists min_age integer not null default 18 check(min_age between 18 and 100),
 add column if not exists max_age integer not null default 100 check(max_age between 18 and 100 and max_age>=min_age),
 add column if not exists target_gender text not null default 'both' check(target_gender in ('male','female','both')),
 add column if not exists payment_code text check(payment_code is null or payment_code ~ '^[A-Z]{2}[0-9]{4}$'),
 add column if not exists amount_fils integer check(amount_fils is null or (amount_fils between 500 and 15000 and amount_fils=days*500)),
 add column if not exists wallet_number text,
 add column if not exists beneficiary text,
 add column if not exists payment_verified_at timestamptz,
 add column if not exists payment_verified_by uuid references public.users(id);
create unique index if not exists promotion_unique_payment_code on public.zameel_post_promotions(payment_code) where payment_code is not null;
drop policy if exists promotion_visible on public.zameel_post_promotions;
create policy promotion_visible on public.zameel_post_promotions for select to authenticated using(owner_id=auth.uid());
create or replace function public.zameel_promotion_catalog() returns jsonb
language sql stable security definer set search_path='' as $$
 select case when auth.uid() is null then null else jsonb_build_object(
 'cities',(select coalesce(jsonb_agg(jsonb_build_object('name',name,'governorate',governorate) order by governorate,name),'[]') from public.zameel_promotion_locations),
 'universities',(select coalesce(jsonb_agg(jsonb_build_object('name',name,'city',city) order by name),'[]') from public.zameel_promotion_universities),
 'wallet_ready',coalesce((select enabled and length(trim(wallet_number))>0 and length(trim(beneficiary))>0 from public.zameel_promotion_settings where id),false),
 'daily_fils',500) end;
$$;
create or replace function public.zameel_request_promotion_v2(p_post uuid,p_days integer,p_audience text,p_countrywide boolean,p_cities text[],p_universities text[],p_min_age integer,p_max_age integer,p_gender text,p_notes text default '') returns jsonb
language plpgsql security definer set search_path='' as $$
declare r public.zameel_post_promotions; cfg public.zameel_promotion_settings; old_result jsonb; code text; tries integer:=0;
begin
 if auth.uid() is null or not coalesce(public.zameel_account_can_write(),false) then raise exception 'account_unavailable';end if;
 if p_audience is null or p_audience not in ('general','students') or p_countrywide is null or p_min_age is null or p_max_age is null or p_min_age not between 18 and 100 or p_max_age not between p_min_age and 100 or p_gender is null or p_gender not in ('male','female','both') or p_cities is null or p_universities is null or cardinality(p_cities)>1500 or cardinality(p_universities)>100 then raise exception 'invalid_promotion_target';end if;
 if (p_audience='students' and (cardinality(p_universities)=0 or cardinality(p_cities)>0 or p_countrywide)) or (p_audience='general' and (cardinality(p_universities)>0 or (p_countrywide and cardinality(p_cities)>0) or (not p_countrywide and cardinality(p_cities)=0))) then raise exception 'invalid_promotion_target';end if;
 if exists(select 1 from unnest(p_cities) c where c is null or not exists(select 1 from public.zameel_promotion_locations where name=c)) or exists(select 1 from unnest(p_universities) u where u is null or not exists(select 1 from public.zameel_promotion_universities where name=u)) then raise exception 'unknown_promotion_location';end if;
 select * into cfg from public.zameel_promotion_settings where id;
 if not coalesce(cfg.enabled,false) or length(trim(cfg.wallet_number))=0 or length(trim(cfg.beneficiary))=0 then raise exception 'promotion_wallet_not_configured';end if;
 old_result:=public.zameel_request_promotion(p_post,p_days,p_notes);
 select * into r from public.zameel_post_promotions where id=(old_result->>'id')::uuid for update;
 if r.status='pending' and r.payment_code is null then
 loop
 tries:=tries+1;if tries>20 then raise exception 'payment_code_retry';end if;
 code:=chr(65+floor(random()*26)::integer)||chr(65+floor(random()*26)::integer)||lpad(floor(random()*10000)::integer::text,4,'0');
 begin
 update public.zameel_post_promotions set audience_type=p_audience,countrywide=p_countrywide,target_cities=p_cities,target_universities=p_universities,min_age=p_min_age,max_age=p_max_age,target_gender=p_gender,payment_code=code,amount_fils=days*500,wallet_number=cfg.wallet_number,beneficiary=cfg.beneficiary,updated_at=now() where id=r.id returning * into r;
 exit;
 exception when unique_violation then null;
 end;
 end loop;
 end if;
 return jsonb_build_object('id',r.id,'status',r.status,'days',r.days,'payment_code',r.payment_code,'amount_fils',r.amount_fils,'wallet_number',r.wallet_number,'beneficiary',r.beneficiary,'audience_type',r.audience_type,'countrywide',r.countrywide,'target_cities',r.target_cities,'target_universities',r.target_universities,'min_age',r.min_age,'max_age',r.max_age,'target_gender',r.target_gender);
end $$;
create or replace function public.zameel_review_promotion(p_actor uuid,p_id uuid,p_decision text,p_note text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare r public.zameel_post_promotions; target uuid; target_state text;
begin
 if not coalesce(public.admin_has_permission('promotions.manage',p_actor),false) or not coalesce(public.admin_can_access_screen('promotions',p_actor),false) then raise exception 'promotion_review_not_authorized';end if;
 if p_decision is null or p_decision not in ('approve','reject','cancel') or length(trim(coalesce(p_note,'')))<5 then raise exception 'invalid_promotion_review';end if;
 select post_id into target from public.zameel_post_promotions where id=p_id;
 perform 1 from public.posts where id=target for update;
 select * into r from public.zameel_post_promotions where id=p_id for update;
 if r.id is null then raise exception 'promotion_not_found';end if;
 target_state:=case p_decision when 'approve' then 'approved' when 'reject' then 'rejected' else 'cancelled' end;
 if r.status=target_state then return jsonb_build_object('status',r.status);end if;
 if (p_decision in ('approve','reject') and r.status<>'pending') or (p_decision='cancel' and r.status not in ('pending','approved')) then raise exception 'promotion_already_decided';end if;
 if p_decision='approve' and r.payment_code is not null and r.payment_verified_at is null then raise exception 'payment_confirmation_required';end if;
 if p_decision='approve' and (not exists(select 1 from public.posts where id=r.post_id and user_id=r.owner_id and audience='public' and not coalesce(is_hidden,false))
 or exists(select 1 from public.admin_user_states where user_id=r.owner_id and status in ('blocked','suspended'))
 or not exists(select 1 from public.feature_flags where feature_key='post_promotions' and is_enabled and display_mode='enabled' and rollout_percent=100 and scope_type='global' and scope_value='*')) then raise exception 'public_post_unavailable';end if;
 update public.zameel_post_promotions set status=target_state,reviewed_by=p_actor,review_note=trim(p_note),updated_at=now(),
 starts_at=case when p_decision='approve' then now() else starts_at end,
 ends_at=case when p_decision='approve' then now()+make_interval(days=>r.days) else ends_at end where id=p_id;
 insert into public.admin_audit_logs(actor_id,action,resource_type,resource_id,details)
 values(p_actor,'promotion.'||p_decision,'post_promotion',p_id::text,jsonb_build_object('note',p_note,'post_id',r.post_id));
 return jsonb_build_object('status',target_state);
end $$;

create or replace function public.zameel_review_promotion_v2(p_actor uuid,p_id uuid,p_decision text,p_note text,p_payment_code text default '',p_amount_fils integer default 0) returns jsonb
language plpgsql security definer set search_path='' as $$
declare r public.zameel_post_promotions; target uuid;
begin
 if not coalesce(public.admin_has_permission('promotions.manage',p_actor),false) or not coalesce(public.admin_can_access_screen('promotions',p_actor),false) then raise exception 'promotion_review_not_authorized';end if;
 select post_id into target from public.zameel_post_promotions where id=p_id;
 perform 1 from public.posts where id=target for update;
 select * into r from public.zameel_post_promotions where id=p_id for update;
 if r.id is null then raise exception 'promotion_not_found';end if;
 if p_decision='approve' and r.payment_code is not null then
 if upper(trim(coalesce(p_payment_code,'')))<>r.payment_code or p_amount_fils is distinct from r.amount_fils then raise exception 'payment_code_or_amount_mismatch';end if;
 if r.status='pending' and r.payment_verified_at is null then
 update public.zameel_post_promotions set payment_verified_at=now(),payment_verified_by=p_actor where id=p_id;
 end if;
 end if;
 return public.zameel_review_promotion(p_actor,p_id,p_decision,p_note);
end $$;
create or replace function public.zameel_save_promotion_wallet(p_actor uuid,p_wallet text,p_beneficiary text,p_enabled boolean,p_note text) returns jsonb
language plpgsql security definer set search_path='' as $$ begin
 if not coalesce(public.admin_has_permission('promotions.manage',p_actor),false) or not coalesce(public.admin_can_access_screen('promotions',p_actor),false) then raise exception 'promotion_review_not_authorized';end if;
 if p_enabled is null or p_wallet is null or p_beneficiary is null or length(trim(p_note))<5 or length(p_wallet)>40 or length(p_beneficiary)>120 or (p_enabled and (length(trim(p_wallet))<5 or length(trim(p_beneficiary))<2)) then raise exception 'invalid_wallet_settings';end if;
 update public.zameel_promotion_settings set wallet_number=trim(p_wallet),beneficiary=trim(p_beneficiary),enabled=p_enabled,updated_at=now() where id;
 insert into public.admin_audit_logs(actor_id,action,resource_type,resource_id,details) values(p_actor,'promotion.wallet_settings','post_promotion','settings',jsonb_build_object('note',p_note,'enabled',p_enabled));
 return jsonb_build_object('saved',true);
end $$;
create or replace function public.zameel_promoted_post_ids() returns table(post_id uuid,ends_at timestamptz)
language sql stable security definer set search_path='' as $$
 select x.post_id,x.ends_at from public.zameel_post_promotions x join public.posts p on p.id=x.post_id
 join public.zameel_audience_profiles a on a.user_id=auth.uid() join public.users u on u.id=auth.uid()
 where auth.uid() is not null and public.zameel_promotions_enabled() and x.status='approved' and x.starts_at<=now() and x.ends_at>now()
 and p.audience='public' and not coalesce(p.is_hidden,false) and public.can_view_post(auth.uid(),p.id)
 and not exists(select 1 from public.admin_user_states s where s.user_id in (auth.uid(),x.owner_id) and s.status in ('blocked','suspended'))
 and a.country='JO' and extract(year from age(current_date,a.birth_date)) between x.min_age and x.max_age
 and (x.target_gender='both' or a.gender=x.target_gender)
 and ((x.audience_type='general' and (x.countrywide or a.city=any(x.target_cities))) or (x.audience_type='students' and u.account_type='student' and u.university=any(x.target_universities)))
 order by x.starts_at desc limit 5;
$$;
revoke all on function public.zameel_save_audience_profile(date,text,text),public.zameel_promotion_catalog(),public.zameel_request_promotion_v2(uuid,integer,text,boolean,text[],text[],integer,integer,text,text),public.zameel_review_promotion_v2(uuid,uuid,text,text,text,integer),public.zameel_save_promotion_wallet(uuid,text,text,boolean,text) from public,anon,authenticated;
grant execute on function public.zameel_save_audience_profile(date,text,text),public.zameel_promotion_catalog(),public.zameel_request_promotion_v2(uuid,integer,text,boolean,text[],text[],integer,integer,text,text) to authenticated;
grant execute on function public.zameel_review_promotion_v2(uuid,uuid,text,text,text,integer),public.zameel_save_promotion_wallet(uuid,text,text,boolean,text) to service_role;
-- Older app clients cannot create requests that omit payment and targeting.
revoke execute on function public.zameel_request_promotion(uuid,integer,text) from authenticated;
notify pgrst,'reload schema';
commit;
