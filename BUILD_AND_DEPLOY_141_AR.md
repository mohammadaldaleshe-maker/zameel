# تحديث 141 — إصلاح فيديو الرئيسية داخل الإصدار 2.0.6

إصلاح محدود لعارض وسائط المنشورات: استخدام VideoPlayerWidget بدلاً من مربع أسود ثابت وزر تشغيل. الفيديو الظاهر يبدأ بصوت مكتوم وفق منطق المشغل الحالي ويتوقف عند مغادرة مجال العرض. زر ملء الشاشة يفتح العارض الكامل ويحافظ على ترتيب وسائط المنشور والإعجاب والتعليق. الصور والإطار وحجم الوسائط لا تتغير.

الحزمة تحتوي الملفات المعدلة فقط؛ ليست نسخة كاملة من المشروع. يتطلب السكربت تحديث 140 ويوقف النسخ إن كان عارض الوسائط مختلفاً. يأخذ نسخة احتياطية من الملفات التي سيستبدلها ويترك باقي الملفات والتعديلات المحلية كما هي.

يبقى الإصدار 2.0.6+15 في إعدادات التطبيق؛ هذا إصلاح لنفس الإصدار دون تحديث سياسة الإصدارات. بناء GitHub التالي يحصل على رقم Android جديد حسب إعداد workflow الحالي. للتأكد من تثبيت الإصلاح نزّل APK من عملية البناء التي تستخدم التزام رفع 141، وليس APK من البناء السابق.

لا SQL، لا تحديث لوحة التحكم، لا نشر دالة، ولا بناء محلي.

## الخطوات
نزّل السكربت والملف المضغوط إلى Downloads.

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
& "$env:USERPROFILE\Downloads\APPLY_UPDATE_141.ps1" -Stage Prepare
if (-not $?) { throw 'Preparation failed; stopped' }
```

بعد نجاح التجهيز، النسخ والفحص معاً:

```powershell
$zameelUpdate141 = [IO.File]::ReadAllText((Join-Path $env:USERPROFILE 'Downloads\Zameel_Update_141_Path.txt')).Trim()
$zameelScript141 = Join-Path $env:USERPROFILE 'Downloads\APPLY_UPDATE_141.ps1'
& $zameelScript141 -Stage Copy -UpdateRoot $zameelUpdate141
if (-not $?) { throw 'Copy failed; stopped' }
& $zameelScript141 -Stage Check -UpdateRoot $zameelUpdate141
if (-not $?) { throw 'Checks failed; stopped' }
```

بعد نجاح جميع الاختبارات:

```powershell
& $zameelScript141 -Stage CommitApp -UpdateRoot $zameelUpdate141
if (-not $?) { throw 'App upload failed; stopped' }
```

شغّل GitHub Actions على main بوضع signed، ثم ثبّت APK الناتج فوق النسخة الحالية دون حذف التطبيق.

## التحقق على الهاتف
- الفيديو داخل الرئيسية يعرض المحتوى عند ظهوره بدلاً من خلفية سوداء ثابتة.
- الصوت مكتوم افتراضياً ويمكن تغييره من أدوات المشغل.
- يتوقف التشغيل عند التمرير بعيداً أو فتح العارض الكامل.
- زر ملء الشاشة يفتح الفيديو والتقليب بين الوسائط يعمل.
- منشور متعدد الصور والفيديوهات يعرض الوسيط المختار؛ الصور والإعجاب والتعليق تعمل.

نجح تحليل Dart للمصدر والاختبارات هنا. لم تُشغّل اختبارات Flutter أو يُبنَ APK في هذه البيئة؛ مرحلة Check على جهازك وبناء GitHub وتجربة الهاتف هي التحقق المتبقي.
