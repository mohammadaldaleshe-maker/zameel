# تحديث زميل 135 — الصيانة والاستهداف والدفع

نسخة التطبيق: 2.0.1+10. نسخة لوحة التحكم: 1.3.10.

## ما تغيّر

- تصغير الخط الفعلي بنسبة 10% مع احترام إعداد تكبير النص من الهاتف، دون فرض حجم ثابت على المستخدم.
- توحيد الخلفيات والنصوص مع الوضع الفاتح والداكن في الملف الشخصي والدردشة والكتب، وتقليل فراغ الملف الشخصي وحجم أزرار تغيير الصور.
- تحريك الصورة وتكبيرها قبل الحفظ، داخل إطار دائري للصورة الشخصية وإطار 3:1 للغلاف؛ يشمل اختيار الصورة أثناء التسجيل. الإلغاء لا يرفع الصورة.
- عرض وقت الرسائل بصيغة محلية مفهومة، وإزالة تكرار «كلية» وتحديث وصف الدردشة العامة إلى جميع المستخدمين.
- إبقاء زر إضافة الكتاب العائم وإزالة الزر المكرر من شريط العنوان؛ تصحيح مسح نص البحث مع التصفية.
- استهداف الترويج: الأردن ككل أو عدة مدن/بلدات، أو طلبة جامعة/عدة جامعات. لا تظهر المدن عند اختيار الجامعات، ولا تظهر الجامعات عند اختيار الجميع. قائمة الخيارات تغطي المحافظات الاثنتي عشرة وتضم 383 خيار مدينة/بلدة/منطقة؛ أسماء الجامعات الـ28 مأخوذة من قائمة التطبيق الحالية. مصدر دليل المناطق: https://www.mola.gov.jo/AR/Pages/البلديات ؛ يتضمن الدليل بلدات ومناطق أيضًا، وليس تصنيفًا حصريًا للمدن.
- العمر المستهدف من 18 إلى 100، مع تحديد الحد الأدنى والأعلى، والجنس: ذكور أو إناث أو كلاهما.
- مدة 1–30 يومًا؛ اليوم 0.50 دينار أردني (500 فلس)، ويظهر مجموع كل مدة. السعر والكود يحسبهما الخادم.
- كود دفع فريد من حرفين لاتينيين كبيرين و4 أرقام. يظهر بجانب اسم صاحب الطلب في اللوحة. يبقى الكود نفسه عند إعادة فتح الطلب أو تكرار الإرسال.
- الدفع حوالة يدوية إلى المحفظة؛ تدخل الإدارة الكود والمبلغ الواردين فعلًا، ثم توافق. يبدأ احتساب المدة عند الموافقة. لا يوجد ربط آلي بالمحفظة.
- إضافة إعداد المحفظة واسم المستفيد في شاشة الترويج باللوحة. طلبات الدفع الجديدة تتوقف إلى أن تُضبط البيانات وتُفعّل المحفظة.
- إضافة المدينة وتاريخ الميلاد والجنس كبيانات خاصة في إعدادات الحساب. لا تظهر هذه البيانات أو أكواد الدفع للآخرين. المستخدم الذي لم يحدد بياناته لا يتم تخمين عمره أو مدينته، ولا يدخل الاستهداف المدفوع حتى يكملها. العمر يعتمد على تاريخ الميلاد الذي أدخله المستخدم.
- الطلبات القديمة تبقى محفوظة، وتظهر «طلب قديم» إذا لم يكن لها كود. اعتمادها يحتفظ بمسار المراجعة السابق. لا تُقبل طلبات جديدة من النسخة القديمة التي تتجاوز الاستهداف والدفع.
- المنشورات العادية والأصدقاء والرسائل والقصص والكتب واللعبة وبنك الأسئلة لا تُحذف ولا تُعاد تهيئتها.

## طريقة التطبيق خطوة خطوة

احفظ الحزمتين وملف APPLY_UPDATE_135.ps1 في Downloads. استخدم PowerShell لجميع المراحل التالية، باستثناء لصق SQL داخل SQL Editor.

### 1. النسخ الاحتياطي وفك الضغط فقط

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\Downloads\APPLY_UPDATE_135.ps1" -Stage Prepare
```

أرسل نتيجة المرحلة. سيظهر مسار Update root. لا يتم نسخ تحديثات إلى المستودعين في هذه المرحلة.

### 2. نسخ الملفات المعدّلة فقط والتحقق منها

عيّن المسار الذي ظهر في المرحلة الأولى، ثم:

```powershell
$zameelUpdate135 = 'ضع هنا مسار Update root'
powershell -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\Downloads\APPLY_UPDATE_135.ps1" -Stage Copy -UpdateRoot "$zameelUpdate135"
```

النسخ يقتصر على القائمة المحددة في UPDATE_135_MANIFEST.json لكل مشروع. لا تُنسخ .git ولا تُمسح ملفات المستودع الأخرى.

### 3. فحص التطبيق واللوحة معًا

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\Downloads\APPLY_UPDATE_135.ps1" -Stage Check -UpdateRoot "$zameelUpdate135"
```

يشغّل flutter pub get ثم flutter analyze ثم flutter test، ويشغّل npm ci ثم اختبارات اللوحة ثم bundle:web. يتوقف عند أول خطأ.

### 4. تجهيز SQL في PowerShell ثم تنفيذه في SQL Editor

**الأمر التالي خاص بـPowerShell، وليس SQL Editor:**

```powershell
$zameelAdminRepo = Join-Path $env:USERPROFILE 'Desktop\لوحة التحكم\zameel-admin-feature-control'
Get-Content -LiteralPath "$zameelAdminRepo\supabase\migrations\20261004100001_135_promotion_targeting_wallet.sql" -Raw -Encoding UTF8 | Set-Clipboard
```

افتح SQL Editor لمشروع jwuqyykjmltroneqtjoc، والصق محتوى الحافظة، ثم Run. نفّذ هذا الملف مرة واحدة فقط؛ نسختاه في المشروعين متطابقتان. لا تعِد تشغيل ملفات 133 أو 134.

بعد النجاح نفّذ في **SQL Editor**:

```sql
select
  (select count(*) from public.zameel_promotion_locations) as location_options,
  (select count(*) from public.zameel_promotion_universities) as university_options,
  (select count(*) from public.zameel_quiz_questions where status='published') as published_questions,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='zameel_request_promotion_v2') as request_ready,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='zameel_review_promotion_v2') as review_ready;
```

### 5. نشر وظيفة الإدارة من PowerShell

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\Downloads\APPLY_UPDATE_135.ps1" -Stage DeployFunction -UpdateRoot "$zameelUpdate135"
```

### 6. رفع التحديثات المحددة إلى GitHub

نفّذ بعد نجاح الفحص وSQL ونشر الوظيفة:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\Downloads\APPLY_UPDATE_135.ps1" -Stage CommitAdmin -UpdateRoot "$zameelUpdate135"
powershell -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\Downloads\APPLY_UPDATE_135.ps1" -Stage CommitApp -UpdateRoot "$zameelUpdate135"
```

إذا كانت هناك ملفات قديمة staged أو كان main متأخرًا عن GitHub، يتوقف السكربت للمراجعة. يعرض التغييرات المحددة فقط قبل commit وpush. لا يستخدم git add . ولا يعيد ضبط المستودعات.

### 7. البناء والإعداد وتجربة الهاتف

شغّل بناء التطبيق من GitHub بالطريقة السابقة، وحمّل التطبيق؛ بناء اللوحة يعمل وفق workflow الحالي. افتح اللوحة الجديدة > ترويج المنشورات > إعداد المحفظة، وأدخل رقم المحفظة واسم المستفيد الصحيحين ثم فعّل الخدمة.

على الهاتف جرّب:

1. الملف الشخصي والدردشة والكتب في الوضعين الفاتح والداكن، ثم تكبير النص من إعدادات الهاتف.
2. تحريك صورة شخصية طولية وتكبيرها، ثم الغلاف، والتأكد أن الصورة المحفوظة تطابق المعاينة.
3. الجميع/الأردن ككل، ثم عدة مدن؛ طلبة الجامعات ثم عدة جامعات والتأكد من إخفاء المدينة.
4. تحديد العمر والجنس والمدة، ثم إنشاء الطلب ومراجعة المبلغ والكود. أعد فتح الطلب للتأكد أنه يعرض الكود نفسه.
5. حوالة تجريبية بالكود في الملاحظات؛ قارنها في المحفظة وأدخل الكود والمبلغ في اللوحة. لا توافق قبل وصول الحوالة الفعلية.
6. إكمال بيانات الجمهور الخاصة من إعدادات الحساب على حسابات التجربة للتحقق من الاستهداف. تأكد أن الحساب غير المطابق لا يتلقى الإعلان.

التحقق المحلي لا يغني عن تجربة الصور والتصميم والحوالة على الهاتف والمحفظة الفعليين. تفاصيل ما نُفّذ محليًا في VALIDATION_135.json.
