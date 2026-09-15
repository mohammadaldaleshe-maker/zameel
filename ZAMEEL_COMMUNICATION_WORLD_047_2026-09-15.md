# Zameel 047 — Communication and World Map

## Delivered

- Read receipts for private chat messages with live updates.
- Accepted Meet a Colleague sessions open inside the lower half of chat.
- Both users share temporary live location only after consent.
- Distance plus walking/driving estimates and end/arrived controls.
- Either participant can terminate the session and location sharing.
- Dedicated Android notification and incoming-call channels with Zameel sounds.
- Caller ringback sound stops on answer, failure or hang-up.
- Faster WebRTC signaling replay, candidate pooling, recovery attempts and a clear timeout.
- Worldwide OpenStreetMap exploration while retaining verified campus places.
- One-tap destination selection and animated avatar distance measurement.
- Failed Gemini provider requests refund their daily quota and show a clean message.

## Important production requirement

STUN alone cannot connect every pair of mobile networks. Configure the existing
`WEBRTC_TURN_URL`, `WEBRTC_TURN_USERNAME`, and `WEBRTC_TURN_CREDENTIAL` values
in Codemagic before claiming universal call reliability.

## Apply and deploy

1. Run `supabase/migrations/047_calls_receipts_meet_world.sql` in SQL Editor.
2. Deploy both updated functions:

```powershell
npx supabase@latest functions deploy send-push-notifications --project-ref jwuqyykjmltroneqtjoc
npx supabase@latest functions deploy zameel-ai --project-ref jwuqyykjmltroneqtjoc
```

3. Run:

```powershell
flutter pub get
dart format lib/screens/chat/chat_screen.dart lib/screens/campus/live_map_screen.dart lib/screens/meet/meet_screen.dart lib/services/push_notification_service.dart lib/services/app_sound_service.dart
flutter analyze
flutter test
```

4. Test calls using two physical phones on different networks. Test foreground,
background and terminated-app incoming calls before starting Codemagic.
