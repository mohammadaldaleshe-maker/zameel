# Zameel 067 — Multi-media + true floating chat bubble repair
Date: 2026-09-19

## Scope lock
This repair intentionally changes only:
1. Normal post publishing with multiple photos/videos plus optional text.
2. Android direct-message floating bubble behavior.

No call, story, book, campus, meeting, WebRTC, LiveKit, relationship, comment, like, save, share, or general feed-ranking logic was redesigned.

## Multi-media post repair
- Home and Profile use the same mixed-media picker path.
- Uses `FileType.media` with file_picker 12.x multi-selection.
- Maximum remains 10 media items.
- Upload first tries a durable native path and falls back to `PlatformFile.readAsBytes()` when Android returns content-backed media.
- All media remains attached to one `posts.id`; engagement remains unchanged.
- Migration `067_multi_media_runtime_repair.sql` is idempotent and re-asserts only the `posts.media_items` column, its 10-item constraint, and the existing `posts` storage bucket read/insert/delete policies.

## True Android floating bubble repair
- Adds `SYSTEM_ALERT_WINDOW` and a real `TYPE_APPLICATION_OVERLAY` chat head.
- Adds an Android foreground service declared as `specialUse` for the chat-head overlay.
- The permission screen is requested once from Zameel while the app is foregrounded.
- After permission is granted and the user returns to Zameel, the bubble service is started while the app is foregrounded.
- Incoming direct-message FCM data updates the already-running overlay.
- Tapping the bubble opens the existing `zameel://chat` deep link for the correct conversation.
- Existing Android Conversation/Notification bubble behavior remains as a fallback.
- FlutterFire delivery is preserved by subclassing and delegating to `FlutterFirebaseMessagingReceiver`.

## Required database step
Run this migration in Supabase SQL Editor before testing media posts:

`supabase/migrations/067_multi_media_runtime_repair.sql`

## Required local checks
```powershell
flutter pub get
flutter analyze
flutter test
```

## Phone test
1. Launch Zameel and allow notifications.
2. When Android opens "Display over other apps", enable it for Zameel and return to the app.
3. Put Zameel in the background and send a direct message from a second account/device.
4. Confirm the draggable Zameel bubble appears above another app and opens the correct chat when tapped.
5. Create one post containing text + at least 3 photos + 2 videos, publish it, restart Zameel, and confirm all media remains in the same post.
