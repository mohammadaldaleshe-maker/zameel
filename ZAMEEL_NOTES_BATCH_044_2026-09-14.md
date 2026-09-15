# Zameel batch 044 — 2026-09-14

## Included changes

- Campus search for verified buildings, services, and partner places.
- Long-press destination selection with walking/driving route, distance, and ETA.
- Configurable `ROUTING_BASE_URL` with a safe direct-distance fallback.
- On-device “My Activity” campus walking session: estimated steps, distance, duration, calories, and a daily goal.
- Colleague search by name, username, university, college, or major.
- Right-edge drawer gesture retained with a narrow activation area.
- Suggested colleagues moved after the fifth feed post.
- Public clip cards now show publisher identity instead of the generic “Clip” label.
- Jordan phone normalization and legacy phone-hash rebuild.
- Call history in contact calling and chat: direction, type, state, date/time, duration, and redial.
- Distinct high-priority incoming-call notification channel and sound preferences.
- Full post context when opening comment/like notifications.
- Comment timestamp, edit/delete ownership, edited marker, and target-comment highlighting.
- Notification timestamp and realtime removal when the underlying comment/like/post is deleted.

## Required deployment order

1. Run `supabase/migrations/044_search_calls_comments_notifications.sql` in Supabase SQL Editor.
2. Run `flutter pub get`.
3. Run `flutter analyze` and `flutter test`.
4. Commit and push only after both checks pass.

## Production routing

Set `ROUTING_BASE_URL` in Codemagic to an OSRM-compatible routing service under your control. The public default endpoint is suitable for development and falls back gracefully, but it is not a production SLA.
