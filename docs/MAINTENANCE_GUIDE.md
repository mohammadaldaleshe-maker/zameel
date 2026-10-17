# دليل صيانة تطبيق زميل (Zameel)

دليل للمبرمج الذي سيتسلم المشروع. كُتب بعد فحص ثابت للكود، **دون تشغيل التطبيق على جهاز ودون مترجم Flutter**،
فما فيه عن السلوك الفعلي على الهاتف يحتاج تأكيداً باختبار.

## 1. ما هو المشروع

تطبيق Flutter (أندرويد) لمنصة اجتماعية للطلبة الجامعيين في الأردن. الإصدار الحالي في `pubspec.yaml` (`2.0.25+34`).
الخلفية على Supabase (قاعدة Postgres مع RLS ودوال Edge وتخزين). إشعارات وتحليلات Firebase. مكالمات WebRTC وLiveKit.
مدفوعات Google Play Billing. **يشترك مع لوحة التحكم (مستودع `zameel-admin-windows`) في مشروع Supabase نفسه.**

## 2. خريطة المجلدات

| المسار | المحتوى |
|---|---|
| `lib/main.dart` | نقطة الدخول والروابط العميقة والإشعارات. يضم 8 ملفات بـ `part` (مكتبة واحدة كبيرة) |
| `lib/features/` | الشاشات الكبيرة المضمومة إلى main (`home_feed.dart` و`posts_media.dart` و`university.dart`...) |
| `lib/screens/` | الشاشات حسب الميزة (chat وcalls وstories وprofile وpromotions...) |
| `lib/services/` | الخدمات والمنطق (المشاركة والكاش والمكالمات والدفع...) |
| `lib/widgets/` | عناصر واجهة قابلة لإعادة الاستخدام |
| `lib/providers/` | حالة التطبيق (`provider`) |
| `android/` | إعداد أندرويد وكود Kotlin الأصلي (المكالمات الواردة والفقاعات والاستديو والرفع) |
| `supabase/migrations/` | مخطط قاعدة البيانات بالترتيب. لا تعدّل migration قديماً، أضف migration جديداً دائماً |
| `supabase/functions/` | دوال Edge: `send-push-notifications` و`play-billing` و`livekit-token` و`account-deletion` و`zameel-ai` و`jobs-search` و`brand-study-file` و`daily-social-maintenance`، والمشترك في `_shared/` |
| `test/` | اختبارات Flutter |
| `verification/` | فحوص Node/Dart أثقل (قاعدة pglite وأمان ودفع). مجلد `verification/` له `package.json` خاص |
| `scripts/test/` | اختبارات Node للدوال الخلفية |
| `docs/` | الوثائق. `docs/history/updates/` سجل حزم التحديثات القديمة، و`docs/history/features/` ملاحظات الميزات القديمة |

## 3. الأوامر الأساسية

```powershell
flutter pub get
flutter analyze
flutter test --timeout 3m --concurrency 1
node --test scripts/test/*.mjs
npm ci --prefix verification --ignore-scripts
```

البناء الرسمي يتم في GitHub Actions (`.github/workflows/android-apk-github.yml`) أو Codemagic (`codemagic.yaml`).
المفاتيح تُمرَّر بـ `--dart-define` أو GitHub Secrets، ولا تُكتب في الملفات.

## 4. أشياء يجب أن تعرفها

- **R8 معطّل فعلياً** (`isMinifyEnabled = false` في `android/app/build.gradle.kts`) رغم أن `README.md` و`docs/RELEASE_CHECKLIST.md` يقولان إنه مفعّل. الكود هو المرجع. وتفعيله يحتاج مرحلة اختبار مستقلة لأنه قد يكسر WebRTC وFirebase.
- **البناء المحلي للإصدار بلا `key.properties` يُوقَّع بشهادة debug.** لا ترفع ملف AAB مبنياً هكذا إلى Google Play.
- **بوابة الجهاز** (`zameel_security160.config.enabled`) قيمتها الافتراضية `false` في قاعدة البيانات، وتشترك فيها لوحة التحكم.
- **مصدرا migrations:** نحو 56 ملفاً متطابقة بين هذا المستودع ولوحة التحكم، وملفات خاصة بكل مستودع. تحقق من المستودعين قبل نشر قاعدة جديدة من الصفر.
- سياسات قراءة مفتوحة لكل المستخدمين المسجلين (`using (true)`) ما زالت على جداول منها `follows` و`social_notes` و`highlights` و`highlight_stories` و`community_groups` و`polls` و`poll_options`. هذا قرار منتج يحتاج مراجعة، لا خطأ مؤكد.

## 5. الأمان

**سليم عند الفحص:** لا مفاتيح سرية في الملفات ولا في تاريخ git (المفتاح الظاهر هو `publishable` المسموح بظهوره)؛
كل دوال `SECURITY DEFINER` تحدد `search_path`؛ التحقق من مشتريات Google Play في الخادم؛ حذف الحساب برمز مهمة يُستعمل مرة واحدة؛
`allowBackup=false`؛ لا حركة cleartext.

**معلق:**
1. تثبيت إصدار `supabase-js` في الدوال (يُستورد حالياً `@2` دون رقم دقيق من esm.sh). ثبّت رقماً بعد اختباره.
2. تقييد مفتاح Firebase API في Google Cloud بحزمة التطبيق وبصمة SHA-1.
3. رابط `zameel://chat` يقبل `partner_name` و`partner_id` من الرابط (الأفضل جلب الاسم من القاعدة دائماً).
4. أرقام جهات الاتصال تُجزَّأ بـ SHA-256 بلا ملح قبل الرفع، وفضاء الأرقام صغير فيمكن عكسها.
5. الجلسة في `SharedPreferences` الافتراضي (لا `flutter_secure_storage`).

## 6. قواعد العمل المتفق عليها

- لا تغيّر ما يعمل دون طلب صريح، وعدّل السطور المطلوبة فقط.
- كل تعديل في فرع مستقل وملف patch وسطر في `CHANGELOG.md`.
- لا تخلط إصلاح الأخطاء مع التنظيم في تعديل واحد.
- لا مفاتيح حقيقية في المستودع.
- جدول `docs/REQUESTS_COVERAGE_2026-10.md` يقابل طلبات الصيانة الأخيرة بالكود، ويحدد ما يحتاج اختباراً على هاتف.
