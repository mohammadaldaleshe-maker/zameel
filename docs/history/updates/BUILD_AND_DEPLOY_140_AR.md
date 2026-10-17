# تحديث زميل 140 — 2.0.6+15

## التعديلات
- إصلاح أسماء أدوات النشر بتكييف لون البطاقات والنص مع المظهر.
- فشل غلاف الشورتس ينتقل إلى معاينة الفيديو؛ فشل المعاينة يظهر إعادة محاولة.
- أولوية معاينة البطاقة الأمامية، مع حد أقصى مهمتين لتجهيز الفيديو.
- زر «فاجئني» يفتح أحدث شورتس، والتقليب من الأحدث إلى الأقدم مع تحميل صفحات إضافية.
- الحفاظ على حالة الزملاء المقترحين عند التمرير وتثبيت مساحة النتائج، مع بدء التحميل بعد رسم الإطار.
- تخزين صور الاقتراحات تلقائياً، وتهيئة أربعة أغلفة وثلاث صور منشورات مسبقاً.
- تجهيز الفيديو التالي بعد نصف ثانية بدلاً من 1.2 ثانية؛ لا تنزيل كامل لمجموعة فيديوهات.
- تنظيف تلقائي للتخزين المؤقت: انتهاء بعد ست ساعات دون استخدام وإزالة الأقدم عند تجاوز 256 ميغابايت. قد يوجد تجاوز مؤقت أثناء تنزيلات متزامنة.
- الاحتفاظ بعزل المحتوى الخاص بين الحسابات.

## حدود التحقق
نجح تحليل Dart للمصدر والاختبارات. اختبارات SQL محلية نجحت للترتيب والصفحات والخصوصية والحظر وإعادة التنفيذ وحفظ قرارات الإصدارات. اختبار طابور المعاينة نجح للأولوية والتزامن والتعافي من الفشل.
أضيفت ثلاثة اختبارات Flutter للتخزين والطابور؛ يجب تشغيل المجموعة الكاملة على جهازك من مرحلة Check. لم يتم قياس التمرير أو سرعة الفيديو على هاتف، ولم يتم تنفيذ بناء Android هنا.
لا ادعاء بأن كل البيانات والملفات مخزنة: تهيئة محدودة تلقائياً مع الإبقاء على آليات التخزين الموجودة، ولا تشغيل دائم عند إغلاق التطبيق.
لا بناء محلي، لا تثبيت NDK، لا نشر Edge Function، ولا إعادة بناء لوحة التحكم؛ تغييرات ADMIN هي SQL ووثائق فقط.

## التنفيذ بالترتيب
نزّل الملفات الثلاثة في Downloads ثم داخل PowerShell:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
& "$env:USERPROFILE\Downloads\APPLY_UPDATE_140.ps1" -Stage Prepare
if (-not $?) { throw 'Preparation failed; stopped' }
```

بعد نجاح Prepare:

```powershell
$zameelUpdate140 = [IO.File]::ReadAllText((Join-Path $env:USERPROFILE 'Downloads\Zameel_Update_140_Path.txt')).Trim()
$zameelScript140 = Join-Path $env:USERPROFILE 'Downloads\APPLY_UPDATE_140.ps1'
& $zameelScript140 -Stage Copy -UpdateRoot $zameelUpdate140
if (-not $?) { throw 'Copy failed; stopped' }
& $zameelScript140 -Stage Check -UpdateRoot $zameelUpdate140
if (-not $?) { throw 'Checks failed; stopped' }
```

نسخ SQL الأول:

```powershell
& $zameelScript140 -Stage Sql1 -UpdateRoot $zameelUpdate140
```

الصق محتوى الحافظة في Supabase SQL Editor وشغله. بعدها انسخ الثاني وشغله بنفس الطريقة:

```powershell
& $zameelScript140 -Stage Sql2 -UpdateRoot $zameelUpdate140
```

فحص SQL داخل المحرر:

```sql
select version_name, build_number, is_allowed, download_url
from public.app_releases
where platform = 'android'
order by build_number desc limit 3;
```

رفع المستودعين معاً بعد نجاح الفحوص وSQL:

```powershell
& $zameelScript140 -Stage CommitAdmin -UpdateRoot $zameelUpdate140
if (-not $?) { throw 'Admin upload failed; stopped' }
& $zameelScript140 -Stage CommitApp -UpdateRoot $zameelUpdate140
if (-not $?) { throw 'App upload failed; stopped' }
```

شغّل بناء Android المعتاد من GitHub Actions، وثبّت النسخة الموقعة 2.0.6. لا تثبّت Debug فوق النسخة الموقعة.

## تجربة الهاتف
1. أسماء منشور/صورة/فيديو/شورتس واضحة في الأصلي والفاتح والداكن.
2. أغلفة الشورتس تظهر؛ الغلاف المتعذر يحاول معاينة الفيديو، والفشل يسمح بإعادة المحاولة. الضغط على البطاقة يفتح العارض.
3. «فاجئني» يبدأ بالأحدث والتقليب يستمر دون تكرار الصفحة الأولى.
4. التمرير قرب الزملاء المقترحين ذهاباً وإياباً، وقياس التعليقة؛ لا تغيّر مفاجئ في ارتفاع القسم.
5. العودة للصور المعروضة بعد إعادة فتح التطبيق لا تعيد تنزيلها ضمن فترة التخزين.
6. تبديل الحساب لا يظهر وسائط الحساب الخاص السابق.
