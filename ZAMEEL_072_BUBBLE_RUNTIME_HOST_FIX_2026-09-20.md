# Zameel 072 — Android floating bubble runtime host fix

## Root cause fixed
The previous implementation attempted to create `ZameelOverlayService` from the background FCM receiver for every incoming direct message. With `targetSdk = 36`, that path is not reliable on modern Android: background foreground-service starts are restricted, high-priority FCM can be downgraded, and Android 15+ tightened the old `SYSTEM_ALERT_WINDOW` foreground-service exemption.

## New runtime architecture
- The overlay host foreground service starts while `MainActivity` is visible and overlay permission is granted.
- The host stays alive (`START_STICKY`) while Zameel is in the background.
- Incoming FCM direct-message receivers no longer create a foreground service.
- They deliver a private in-app broadcast to the already-running host.
- The host creates the real `TYPE_APPLICATION_OVERLAY` chat head.
- If the host is unavailable, overlay permission is missing, or Android rejects the overlay, the existing conversation-notification fallback remains active.
- Returning to Zameel hides only the visible chat head; it no longer kills the host service.
- Opening a chat from the bubble also keeps the host alive for the next message.
- A low-importance ongoing Android notification (`Chat bubbles are ready`) is intentional: Android requires a foreground-service notification for a persistent reliable overlay host.

## Unchanged
- Multi-image, multi-video and mixed-media publishing from 071.
- Chat data, calls, stories, clips, books and profile logic.
- Supabase schema/migrations except the prior 071 maintenance repairs.

## Verification in the maintenance environment
- Full project static audit: 60/60 passed.
- AndroidManifest XML parsed successfully.
- Kotlin parser smoke check produced no syntax/parser diagnostics.
- Regression contracts updated to protect the persistent-host architecture.

`flutter analyze` and `flutter test` still need to be executed in the user's Flutter environment, as with every source build.
