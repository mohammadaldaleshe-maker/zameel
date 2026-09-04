# Zameel v1.3.3+19 — Real Features Setup

هذه النسخة تجريبية وليست نسخة نهائية.

## 1) Supabase SQL
نفّذ بالترتيب كل ملفات migrations الجديدة، وبالأخص:
- `supabase/migrations/007_real_features.sql`

## 2) Zameel AI الحقيقي
تم نقل منطق الذكاء الاصطناعي إلى Supabase Edge Function حتى لا يتم وضع مفتاح OpenAI داخل تطبيق Flutter.

Deploy:

```powershell
supabase functions deploy zameel-ai
supabase secrets set OPENAI_API_KEY="YOUR_OPENAI_API_KEY"
```

اختياريًا:

```powershell
supabase secrets set OPENAI_MODEL="gpt-5"
```

المساعد يستخدم OpenAI Responses API، ويمكنه استخدام Web Search عند الحاجة إلى معلومات حديثة. لا تضع المفتاح في `lib/` أو `--dart-define` داخل التطبيق.

## 3) التقويم الجامعي الحقيقي
تمت إضافة `university-calendar` Edge Function.

المصادر المسموح بها في هذه النسخة هي مواقع جامعات رسمية:
- الجامعة الأردنية: `ju.edu.jo` و `registration.ju.edu.jo`
- جامعة اليرموك: `yu.edu.jo` و `admreg.yu.edu.jo`
- جامعة العلوم والتكنولوجيا الأردنية: `just.edu.jo`
- الجامعة الهاشمية: `hu.edu.jo`

Deploy:

```powershell
supabase functions deploy university-calendar
```

يتم تحديث التقويم عند فتح شاشة التقويم أو الضغط على زر المزامنة، وتُحفظ نسخة مخزنة في `university_calendar_events` مع رابط المصدر الرسمي لكل حدث.

## 4) الرؤية للمنشورات
القيم الجديدة في `posts.audience`:
- `public` = عامة
- `friends` = الزملاء/الأشخاص الذين يتابعهم صاحب المنشور
- `private` = لي فقط

تمت إضافة RLS حتى لا يكون الاختفاء مجرد فلترة في الواجهة.

## 5) الصور والـClips
- تغيير صورة الحساب/الغلاف أصبح اختيارًا مؤقتًا حتى الضغط على «حفظ التغييرات».
- دعم اختيار الصورة من المعرض أو الكاميرا.
- الـClips تعرض فيديوهات Supabase الفعلية داخل التطبيق.
- إضافة «تصوير Clip» و«من المعرض».

## 6) الخريطة
اختيار مبنى/خدمة من البحث أو القوائم يعيد المستخدم إلى تبويب الخريطة ويُحرّك الخريطة إلى الإحداثية الخاصة بالمكان.


## v1.3.4+20
- Run `008_real_features_hardening.sql` in Supabase.
- Deploy `zameel-ai` and `university-calendar` Edge Functions.
- Configure `OPENAI_API_KEY` and optionally `OPENAI_MODEL` as Supabase secrets.
- For automatic calendar refresh, schedule the calendar Edge Function with Supabase Cron. Supabase supports recurring jobs that invoke Edge Functions.
- New Clips are stored in the dedicated `clips` Storage bucket.


## تحقق سريع بعد النشر
- جرّب Profile > تغيير الصورة: يجب أن تظهر معاينة وزر حفظ ثابت أسفل الشاشة.
- جرّب Community > Clips > تصوير Clip: يجب أن تفتح الكاميرا الأصلية داخل التطبيق، ثم بعد الإيقاف يرفع الفيديو إلى Storage bucket `clips`.
- جرّب تغيير خصوصية Clip إلى عامة/للزملاء/لي فقط.
- جرّب Campus > مبنى > توجيه: يغلق الحوار ويحدد المبنى مباشرة على الخريطة.
- جرّب Calendar > تحديث: يعرض آخر بيانات من المصدر الرسمي، مع cache احتياطي عند تعذر الاتصال.
