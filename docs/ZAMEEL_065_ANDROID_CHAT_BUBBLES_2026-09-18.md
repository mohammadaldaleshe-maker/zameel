# Zameel 065 — Android Chat Bubbles
Date: 2026-09-18
Base: Zameel 063 LiveKit SFU + applied SQL hotfix 064

## Scope
This release adds Android system conversation bubbles for direct Zameel chat messages without changing direct voice/video calls, LiveKit meetings, stories, books, profile, campus, or other working features.

## Bubble behavior
- Direct-message FCM events on Android are delivered as high-priority data messages.
- `ZameelBubbleReceiver` posts an official Android Conversation/Bubble notification.
- Bubble identity is the sender profile photo when available.
- A small Zameel `Z + lightning` badge is composited onto the bubble icon using the approved brand colors:
  - Primary `#3152E8`
  - Secondary `#4B23B7`
  - Accent `#27C7C7`
- When no sender photo is available, the sender initial is used.
- Tapping the notification opens the correct direct conversation.
- Expanding the bubble opens the same conversation in a dedicated embedded Flutter activity.
- Repeated messages in one conversation update the same notification/bubble id.
- If Android/user settings do not allow bubbles, the same item falls back to a normal conversation notification.

## Zameel bubble sound
- New Android raw resource: `zameel_bubble_thunder.wav`.
- Dedicated notification channel: `zameel_chat_bubbles_v1`.
- Silent companion channel: `zameel_chat_bubbles_silent_v1` when the user has disabled notification sounds.
- Existing call ringtone and general Zameel notification sound are unchanged.

## Push backend
`supabase/functions/send-push-notifications/index.ts` now:
- reads the stored device platform;
- enriches direct-message data with sender id, sender name, sender avatar, message preview and sound preference;
- sends Android direct messages as data-only FCM payloads to avoid duplicate standard notifications;
- leaves non-chat notification delivery and incoming-call delivery on the existing paths;
- leaves iOS on its existing notification path.

## Deep links
Added `zameel://chat` navigation support. Bubble/content taps carry:
- `conversation_id`
- `partner_id`
- `partner_name`

## Android files added
- `android/app/src/main/kotlin/com/zameel/app/ZameelBubbleActivity.kt`
- `android/app/src/main/kotlin/com/zameel/app/ZameelBubbleReceiver.kt`
- `android/app/src/main/res/raw/zameel_bubble_thunder.wav`

## Existing files changed
- `android/app/src/main/AndroidManifest.xml`
- `lib/main.dart`
- `lib/services/push_notification_service.dart`
- `supabase/functions/send-push-notifications/index.ts`
- `pubspec.yaml` (`2.0.0+3`)

## Preserved database hotfix
- `supabase/migrations/064_meeting_join_code_hotfix.sql` is included because it is already applied to the current Zameel database.

## Deployment required
After replacing/updating the Flutter source, deploy the modified push function:

```powershell
npx supabase link --project-ref jwuqyykjmltroneqtjoc
npx supabase functions deploy send-push-notifications
```

No new SQL migration is required for bubbles.

## Android test
1. Install the new build on two Android phones/users.
2. Open Zameel at least once on the receiver so its current FCM token stores `platform=android`.
3. Put the receiver app in the background or close it.
4. Send a direct chat message from the other account.
5. Confirm a conversation notification arrives with the Zameel thunder sound.
6. If Android shows the bubble icon on the notification, enable that conversation as a bubble. Android controls whether apps may show all/selected/no bubbles.
7. Confirm the bubble uses the sender image (or fallback initial) with the Zameel badge.
8. Expand/tap it and confirm it opens the correct chat history.
9. Send another message in the same chat and confirm the same bubble updates.
10. Confirm direct voice/video calls still ring and open through the existing call flow.
