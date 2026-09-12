# Zameel Push Notifications - Final Setup Checklist

هذا الإصدار يحوّل الإشعارات إلى مسار كامل:

1. التطبيق يسجل FCM token في `public.push_device_tokens`.
2. كل حدث ينشئ صفًا في `public.notifications`.
3. trigger يضعه في `public.push_notification_queue`.
4. Database Webhook على `push_notification_queue INSERT` يستدعي Edge Function.
5. Edge Function ترسل الإشعار عبر Firebase Cloud Messaging.
6. التطبيق يعرض Push في الخلفية/عند الإغلاق، وإشعارًا محليًا عند الـforeground.

## 1) Supabase SQL

شغّل:

`supabase/migrations/016_notifications_hardening_comments.sql`

بعد أن تكون migrations السابقة مطبقة، خاصة 014 و015.

## 2) Firebase

في Firebase Console أنشئ/استخدم Android app بالـpackage:

`com.zameel.app`

نزّل `google-services.json`.

لا تضع أي service account JSON أو private key داخل Git.

FCM يتطلب أن يكون التطبيق قد فُتح مرة واحدة لتسجيل الجهاز، وعلى Android 13+ يجب منح إذن الإشعارات. راجع Firebase docs الرسمية عند تجهيز Firebase/FCM.

## 3) Codemagic

الأفضل عدم رفع `google-services.json` داخل GitHub. خزنه في Codemagic كمتغير بيئة مشفّر Base64 باسم:

`GOOGLE_SERVICES_JSON_BASE64`

ثم أضف في workflow خطوة قبل `flutter pub get`:

```bash
if [ -n "$GOOGLE_SERVICES_JSON_BASE64" ]; then
  echo "$GOOGLE_SERVICES_JSON_BASE64" | base64 --decode > android/app/google-services.json
fi
```

بهذا يبقى ملف Firebase خارج Git.

## 4) Supabase Edge Function secrets

في Edge Function Secrets أضف:

- `FCM_SERVICE_ACCOUNT_JSON` = محتوى service-account JSON الخاص بـFirebase.
- `ZAMEEL_PUSH_WEBHOOK_SECRET` = قيمة عشوائية طويلة (32+ حرفًا).

لا تضع هذه القيم في GitHub أو Flutter.

## 5) Deploy function

```bash
supabase functions deploy send-push-notifications
```

الدالة تستخدم `supabase/config.toml` مع:

```toml
[functions.send-push-notifications]
verify_jwt = false
```

لأن استدعاءها يتم من Database Webhook، لكنها محمية بـ`x-zameel-push-secret`.

## 6) Create Database Webhook

في Supabase Dashboard:

Database → Webhooks → Create webhook

- Name: `zameel_push_queue`
- Table: `public.push_notification_queue`
- Event: `INSERT`
- Method: `POST`
- URL:

`https://jwuqyykjmltroneqtjoc.supabase.co/functions/v1/send-push-notifications`

Header:

`x-zameel-push-secret: <نفس قيمة ZAMEEL_PUSH_WEBHOOK_SECRET>`

Database Webhooks تعمل بعد تغيير الصف وتستخدم pg_net بشكل غير متزامن، لذلك لا توقف عملية الإدراج.

## 7) Test from Supabase

بعد تسجيل جهاز من التطبيق، تحقق:

```sql
select id, user_id, platform, locale, updated_at
from public.push_device_tokens
order by updated_at desc;
```

ثم أرسل رسالة من الحساب A إلى الحساب B. تحقق:

```sql
select id, user_id, actor_id, type, title_ar, body_ar, created_at
from public.notifications
order by created_at desc
limit 10;
```

ثم:

```sql
select id, notification_id, status, attempts, last_error, created_at, processed_at
from public.push_notification_queue
order by created_at desc
limit 10;
```

في الحالة السليمة يجب أن تتحول queue إلى `sent`.

## 8) Required phone tests

اختبر على هاتفين مختلفين:

### Test A - foreground
A يرسل رسالة → B مفتوح على Zameel → يظهر إشعار فورًا.

### Test B - background
أغلق الشاشة/انتقل لتطبيق آخر → أرسل رسالة → يظهر Push في شريط الإشعارات.

### Test C - terminated
أغلق Zameel بالكامل بدون Force Stop من إعدادات النظام → أرسل رسالة → يظهر Push، ثم افتح الإشعار.

على Android، إذا تم Force Stop من إعدادات النظام يجب فتح التطبيق مرة أخرى قبل عودة الرسائل الخلفية، وفق متطلبات FCM.

### Test D - colleague request
A يرسل طلب زمالة → B يحصل على Push.

### Test E - post comment
A يعلق على منشور B → B يحصل على Push.

### Test F - like/share/story/clip/graduation
اختبر كل حدث وتأكد من:
- `notifications` يحتوي سجلًا.
- `push_notification_queue` يستقبل سجلًا.
- webhook يستدعي Edge Function.
- الجهاز يعرض Push.

## 9) Never commit secrets

لا ترفع:
- `google-services.json` إذا قررت الاحتفاظ به خارج Git.
- service account JSON.
- private_key.
- Supabase secret/service-role keys.
- `.env` files.
