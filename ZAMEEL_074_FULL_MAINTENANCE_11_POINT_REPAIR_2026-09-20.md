# Zameel 074 — Full Maintenance / 11-Point Repair

Scope: targeted maintenance only. Existing UI and already-working product behavior are preserved.

1. Private/restricted post, story and clip media uses authenticated Storage access and signed URLs; legacy post/graduation buckets are protected.
2. Sign-out unregisters/invalidates the current FCM device token; token claiming safely handles account changes on one phone.
3. Android 10 uses the API-29 PendingIntent bubble builder path; Android 11+ uses conversation shortcuts.
4. Conversation shortcuts use pushDynamicShortcut so Android can manage shortcut limits.
5. App-wide and notification-channel bubble capability are checked before offering the official Android fallback settings.
6. Post/story/clip/graduation media cleanup removes backing Storage objects when content is deleted.
7. Push delivery is tracked per queue item + device token so retries skip devices already delivered successfully.
8. Native story/clip video uploads stream from XFile/File paths instead of loading whole videos into RAM; Web keeps a byte fallback.
9. The persistent overlay foreground service has a truthful specialUse subtype and a Play declaration note in docs/PLAY_FGS_SPECIAL_USE_074.md.
10. Direct dart:io dependencies are isolated behind conditional imports; Firebase startup is restricted to the provisioned Android target so unconfigured platforms do not crash at startup.
11. Dangerous control-flow-in-finally suppression was removed, return/break/continue in finally blocks were eliminated, and 074 regression tests execute SecureMediaService production logic in addition to static contracts.

Required database step before testing 074 against production:
- Apply `supabase/migrations/074_private_media_and_push_delivery.sql` (same SQL is mirrored under `supabase/manual/`).
- Deploy the updated `supabase/functions/send-push-notifications/index.ts` after the migration.

Validation boundary:
- This repair environment does not contain Flutter/Android SDKs, so the final source must still run `flutter pub get`, `flutter analyze`, `flutter test`, and the Codemagic Android build before the APK is installed.
