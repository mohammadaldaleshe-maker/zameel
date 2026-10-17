# جدول تغطية طلبات الصيانة (13–16 أكتوبر 2026)

هذا الجدول يقابل قائمة الطلبات بالكود الموجود في المستودعين (التطبيق ولوحة التحكم). أُعدّ بفحص ثابت للكود (قراءة وبحث)،
**دون تشغيل التطبيق على هاتف ودون مترجم Flutter**. لذلك:

- وجود الكود **لا يثبت** أن الميزة تعمل جيداً على الهاتف. هو يثبت فقط أن الميزة مُنفَّذة وليست غائبة.
- ما لم أجد له أثراً واضحاً مكتوب صراحة، ولم أخمّن بشأنه.

**الرموز:** ✅ موجود في الكود | 📱 يحتاج اختباراً على هاتف | ❓ لم أجد دليلاً واضحاً في الكود | 🗄️ عملية بيانات وليست كوداً

| # | المجموعة | الحالة | الدليل أو الملاحظة |
|---|---|---|---|
| 1 | المشاركة داخل التطبيق وخارجه | ✅ 📱 | خيارات «على صفحتي الشخصية» و«المشاركة خارج التطبيق» في `lib/services/external_share156.dart`؛ صفحة المشاركة العامة في الدالة `public-share157` (تُوقّع روابط الوسائط بـ `createSignedUrl`)؛ منطق المشاركة في `lib/features/shared_activity156.dart`. تشغيل الفيديو في الصفحة العامة يحتاج فحصاً على الموقع نفسه |
| 2 | الإشارات إلى الأشخاص | ✅ 📱 | `lib/widgets/mention_field156.dart` (يشمل `@الجميع`)، و`mention_content158.dart`، و`lib/services/mention_display159.dart`؛ الإشارات في التعليقات في `comments_screen.dart` و`clip_comments_screen.dart`؛ إشعار الإشارة `post_mention` |
| 3 | الرئيسية والمنشورات | ✅ 📱 | لا أثر لزر «إعدادات الصفحة الرئيسية» (أُزيل)؛ الوقت النسبي في `lib/services/post_presentation157.dart` مع اختبار `verification/maintenance158/member_time_test.dart`؛ قائمة المعجبين `loadPostLikers163` في `home_feed.dart` و`posts_media.dart`؛ الرجة والمسافات تحتاج هاتفاً |
| 4 | الكيبورد والكتابة | ✅ 📱 | `widgets/keep_keyboard_send_button.dart` و`content_editor155.dart` و`measure_content161.dart`؛ سلوك الكيبورد الفعلي يحتاج هاتفاً |
| 5 | الدردشة والأداء | ✅ 📱 | `widgets/chat_timestamp.dart` و`typing_message_bubble.dart`؛ قفز الرسائل والرجة ونقص الأداء لا يظهر إلا بالتشغيل |
| 6 | الفيديوهات والحالات | ✅ 📱 | شريط تقدم الفيديو `_videoProgress158` في `stories_screen.dart`؛ التخزين المؤقت `media_cache_service_io.dart` |
| 7 | شريط المناسبات | ✅ | `lib/services/header_occasion_156.dart`. لم يُمس بناءً على طلبك |
| 8 | التسجيل وتاريخ الميلاد | ✅ | `lib/services/member_rules158.dart` (من 1960 وعمر 17 على الأقل)، و`open_registration_screen.dart`، والتحقق في قاعدة البيانات `20261014040002_158_member_profiles.sql` (قيد `birth_date >= 1960-01-01`)؛ إظهار تاريخ الميلاد اختياري عبر `show_birthday` |
| 9 | النشر على صفحة الصديق | ✅ 📱 | `widgets/friend_wall158.dart` و`services/friend_wall_service158.dart` وحاوية `zameel_wall158`؛ إعداد السماح `allow_friend_posts` في `profile_settings_screen.dart` وفي migration 158 |
| 10 | التعليقات وأجمل كلية | ✅ ❓ | حذف التعليق `zameel_delete_comment161` مع `can_delete161`؛ سياسة حذف المشارك لمشاركته `college_entry_owner_delete` (migration 076)؛ جدول تعليقات التحدي `zameel_college_comments161`. المشاركات القديمة لا تظهر: `zameel_college_snapshot161` تعرض `cycle_day` الحالي فقط، والدورة تنتهي 07:00 بتوقيت الأردن، واختيار الفائز بعد 20:00. (الصفوف القديمة تبقى في الجدول للأرشيف ولا تُعرض) |
| 11 | حفظ الصور والفيديو | ✅ 📱 | `android/.../GalleryWriter161.kt` (MediaStore)؛ رسائل النجاح تحتاج هاتفاً |
| 12 | المكالمات | ✅ 📱 🗄️ | `ZameelIncomingCall.kt` (إشعار full-screen وفئة CALL)، و`IncomingCallScreen`، و`send-push-notifications/call_push.mjs`، واختبارات `call_push_142/143` و`call_avatar_161` تنجح. ازدواجية الواجهة والانهيار عند وصول مكالمة تحتاج هاتفاً وسجل Android (logcat). مكالمات «علاء» 🗄️ تُفحص من جدول `direct_call_sessions` في Supabase |
| 13 | الدخول وثقة الجهاز | ✅ 📱 | `screens/security/device_verification160.dart` و`devices_screen160.dart` و`DeviceTrust160.kt`، والدوال `zameel_device_authorized160`. **بوابة الجهاز معطلة افتراضياً في قاعدة البيانات** (`enabled=false`)، وتحقق من قيمتها الحية |
| 14 | الإشعارات والحسابات | ❓ 🗄️ | اسم المرسل في `send-push-notifications/index.ts` (`sender_name`)، لكن لم أجد كوداً يخص «الإشعار العام باسم زميل». عرض الحسابات غير المؤكدة أُضيف في لوحة التحكم (صيانة 02، يحتاج migration 163). حذف «الحسابات الثلاثة» عملية بيانات لا أعرف أي حسابات هي ولن أخمّن |
| 15 | المنشورات المموّلة | ✅ 📱 | عداد المشاهدات لصاحب المنشور فقط `_ownerViews162` في `profile_screen.dart`؛ توزيع الحملات في `supabase/migrations/20261015090001_162_campaign_delivery.sql`. الإعجاب بمنشور مروّج: يُرفض إن لم يعد الإعلان «حياً» (انتهت الحملة/أُخفي الشريك) بحسب `advertisement_likes_create`؛ لا خلل ثابت في الكود، وأحتاج نص الخطأ الظاهر على الهاتف |
| 16 | لوحة التحكم والشركاء | ✅ 📱 | كتم الراديو `radio_mutes` و`radio_unmute` في `admin-console/index.ts`؛ حذف الشريك `m154_partner_delete155/156` في `maintenance154.mjs`؛ تعديل المناسبة من اللوحة `m154_header156` في `web/maintenance156.js`؛ إصدار اللوحة 1.3.28 متطابق في `package.json` و`tauri.conf.json` و`Cargo.toml`. **إخفاء الشريك وإظهاره موجود ومتصل من أوله لآخره** (صُحّح هنا خطأ في الجدول الأول): زر في `web/maintenance154.js` ← `m154_partner_visibility156` في `maintenance154.mjs` ← الدالة `zameel_admin_partner_visibility_156` (migration 20261012190001) التي تضبط `is_active`؛ والتطبيق يقرأ الشركاء بشرط `is_active=true` (`remaining_services.dart:224`) فيختفي من القائمة والخريطة؛ وإعلاناته لا تُعرض لأن `advertisement_is_live` تشترط `partner.is_active` |

## ما أنصح باختباره على الهاتف أولاً (بعد تطبيق أي تحديث)

1. استقبال مكالمة صوتية وفيديو والتطبيق مغلق ثم والهاتف مقفل، والرد والرفض.
2. الكتابة العربية في الدردشة والتعليقات (الكيبورد لا يهبط، والمؤشر يتحرك).
3. مشاركة منشور إلى الحالة وإلى خارج التطبيق وفتح الرابط العام.
4. حفظ صورة وفيديو في الاستديو ورسالة النجاح.
5. تسجيل الدخول من هاتف جديد (التحقق مرة واحدة فقط).
6. التمرير في الرئيسية والدردشة بحثاً عن رجة.
