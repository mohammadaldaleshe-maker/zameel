# Zameel 071 — Full maintenance final

> Status: **full maintenance source finalized for handoff on 2026-09-20**.
> The source has passed the complete static/schema/contract audit available in
> this environment. A physical Android/FCM run remains the final deployment
> validation step because this container does not include Flutter/Android SDKs.

## 1. Publishing repair

- Home **Photo** gallery path now uses `PostPublishService.pickMultipleImages()`.
- Home **Video** gallery path now uses `PostPublishService.pickMultipleVideos()`.
- Camera capture remains intentionally one item per capture.
- Home mixed **Post** composer supports text + multiple photos + multiple videos.
- Profile photo/video post shortcuts now use the same multi-select publisher.
- All normal media posts persist the ordered `media_items` array on one `posts` row.
- Legacy `image_url` and `video_url` stay populated for older builds.
- Max item count remains 10 and is enforced in both client code and migration SQL.
- Per-file and total-size checks run **before the first upload**, preventing wasted
  Storage traffic when a selection is already too large.

The locked project dependency is `image_picker 1.2.3`, which exposes
`pickMultiImage`, `pickMultiVideo` and `pickMultipleMedia`.

## 2. Floating chat-bubble repair

The 070 source had only Android Conversation/Bubble notification support. It no
longer contained the real app-over-app overlay service that existed in 067.

071 restores and hardens a true overlay path:

- `SYSTEM_ALERT_WINDOW` permission.
- `ZameelOverlayService` using `TYPE_APPLICATION_OVERLAY`.
- Android 14+ foreground-service `specialUse` declaration and permission.
- Explicit user prompt that opens Android display-over-other-apps settings.
- The permission prompt is retryable on a later app launch if declined/revoked.
- Incoming direct-message data push starts the overlay only when Zameel is not
  already in the foreground and overlay permission is granted.
- If foreground-service startup fails, the code immediately posts the standard
  Android conversation notification instead.
- If the service starts but overlay creation later fails, it also posts the
  standard conversation notification instead of dropping the message.
- A race where overlay permission is revoked between receiver and service start
  is covered by the same fallback.
- Persisted drag coordinates are clamped to the visible display so a previously
  moved/rotated bubble cannot reopen entirely off-screen.
- Tapping the overlay opens the existing `zameel://chat` deep link.
- FlutterFire delivery is still delegated through `super.onReceive(...)`.

## 3. Push and CI hardening

- Direct Android chat messages remain data-only HIGH-priority FCM messages.
- Sender id/name/avatar/preview are enriched by the push function.
- The test APK workflow no longer permits a build without
  `GOOGLE_SERVICES_JSON_BASE64`; such a build cannot meaningfully validate FCM
  or chat bubbles.
- Both Codemagic workflows are pinned to Flutter `3.47.1` for reproducibility.
- Both workflows now run `flutter test --no-pub` after static analysis.
- App fallback version was aligned with `pubspec.yaml` (`2.0.0+9`).

## 4. Added regression tests

`test/regression_contract_test.dart` fails CI if any of these regressions return:

- Home Photo/Video shortcuts stop using multi-select.
- Profile Photo/Video paths stop using the unified publisher.
- Mixed picker or `media_items` persistence is removed.
- Pre-upload total-size guard moves after the upload loop.
- Overlay permission/service declarations disappear.
- Overlay or notification fallback paths disappear.
- FlutterFire delegation disappears.
- Overlay permission becomes permanently unrecoverable after decline.
- Direct chat push loses HIGH priority/sender fields.
- CI again permits an APK without Firebase configuration.

## 5. Broad static audit results

- YAML parse: `pubspec.yaml` and `codemagic.yaml` valid.
- Android manifest XML parse: valid.
- Local Dart package/relative import targets: no missing files found.
- Declared pubspec asset paths: no missing paths found.
- Native manifest component source files: no missing files found.
- Native raw sound references: present.
- Git conflict markers: none found.
- Migration numeric-prefix duplicates: none found.
- Literal Supabase tables used by the client/functions: **54**; all have migration
  references.
- Literal RPCs used by the client: **72**; all have migration references.
- Privileged-secret scan found no embedded service-role/private-key value; the
  private-key text found in the push function is only code that strips PEM
  header/footer from an environment-provided key.
- Kotlin parser smoke test found no Kotlin syntax diagnostics. Full Android
  semantic compilation cannot be done without the Android SDK.
- Edge TypeScript parser smoke test found no TypeScript syntax diagnostics;
  unresolved Deno/remote-import types are expected outside Deno.
- Publishing/bubble/push/CI static contract suite: **60 / 60 passed**.

## 6. Final maintenance verification boundary

The source-level maintenance pass is complete. The current execution environment
does not contain Flutter/Dart or Android SDK tooling, so these deployment checks
must execute in Codemagic/the target Android device:

- `flutter pub get`
- `flutter analyze`
- `flutter test`
- `flutter build apk --release`

It also cannot prove from source alone that the current Supabase project has the
latest `send-push-notifications` deployment or that a particular physical Android
phone/OEM accepts overlay behavior exactly as expected.

The repository CI is now configured to enforce those checks before producing a
test APK. The source handoff is final; device-specific behavior is intentionally
left to the real Android/FCM execution environment rather than being guessed from
static code.


## 7. Migration-order hardening completed on 2026-09-20

- Fixed migration `012_relationship_controls.sql` to insert direct-chat members
  using the canonical `conversation_members.joined_at` column instead of the
  nonexistent `created_at` column on a fresh database.
- Hardened migration `061_privacy_search_books_battery_cleanup.sql` so story-view
  write policies support `viewer_id`, legacy `user_id`, or both without failing
  a migration run.
- Client/database column audit: 764 query-column usages checked successfully.
- Dart RPC parameter audit: 85 calls checked against SQL function signatures;
  no unknown parameter names were found.
- Migration-order audit: 61 migrations / 73 known tables checked; no unresolved
  static schema-order references remained after dynamic-compatibility handling.
