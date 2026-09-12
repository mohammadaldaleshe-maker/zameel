# Push Notifications Final Repair - 2026-09-05

- Preserved graduation-book two-page spread version as the base.
- Added durable post comments and automatic comment notifications.
- Moved colleague request/accept/reject notifications to database triggers to avoid duplicate client inserts.
- Added push token locale storage.
- Improved Android 13+ runtime permission handling.
- Improved push token registration after auth changes.
- Added notification preference enforcement at the server sender.
- Hardened FCM sender so invalid tokens are removed while transient failures remain retryable.
- Added secure webhook secret for the push Edge Function.
- Added Supabase Database Webhook setup instructions.
- Added Codemagic Firebase configuration hook via `GOOGLE_SERVICES_JSON_BASE64` without committing secrets.
- No Firebase service-account secrets were added to the repository.
