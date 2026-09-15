# Zameel Modularization

تم تقسيم `lib/main.dart` إلى ملفات Dart باستخدام `part` مع الحفاظ على نفس مكتبة Dart والـ private members والسلوك الحالي.

## الملفات
- `lib/main.dart` — imports، تهيئة Supabase، providers، deep links، وثوابت/بيانات مشتركة.
- `lib/features/auth_app.dart` — AuthGate و ZameelApp و GlassContainer.
- `lib/features/university.dart` — نماذج الجامعات والكليات والشاشات المرتبطة بها.
- `lib/features/home_feed.dart` — HomeFeedScreen ومنطق الصفحة الرئيسية.
- `lib/features/arc_menu.dart` — الزر العائم والقائمة القوسية القابلة للسحب.
- `lib/features/drawer_profile.dart` — Drawer والملف الشخصي وعناصره.
- `lib/features/posts_media.dart` — المنشورات والصور والفيديو وعارض الوسائط.

## ملاحظة
لم يتم تغيير منطق الميزات أثناء التقسيم؛ الهدف هو تنظيم الكود وتسهيل الصيانة. يجب تشغيل `flutter analyze` و `flutter build apk --release` على جهاز التطوير للتأكد من التوافق مع نسخة Flutter المحلية.
