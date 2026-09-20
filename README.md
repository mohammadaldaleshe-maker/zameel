# Zameel — زميل

**جامعتك • مجتمعك • مستقبلك**

Zameel is a Flutter university social platform built around a social-first, education-first feed. The project supports Arabic and English and uses Supabase for authentication, data and media storage.

## What is in this build

- Flutter application with Arabic/English localization
- Supabase authentication and user profiles
- Home feed with text/image/video posts
- Likes and saved posts
- Profile editing and profile image upload
- Stories/video playback
- Search, friends, groups, books, chat, campus, companies, jobs, calendar and other existing product areas
- Account deletion flow backed by a Supabase RPC
- Android release configuration targeting API 36
- R8 release shrinking
- Production signing template
- Supabase core schema migration

## Local setup

1. Install the Flutter stable SDK and Android Studio.
2. Open this folder in Android Studio or VS Code.
3. Run:

```powershell
flutter pub get
flutter analyze
flutter test
```

4. Create `android/local.properties` automatically by running Flutter/Android tooling on your machine, or configure it with your local SDK paths.
5. Apply `supabase/migrations/001_core_schema.sql` to the production Supabase project if it is a fresh database.

## Production Supabase configuration

The app accepts:

- `SUPABASE_URL`
- `SUPABASE_PUBLISHABLE_KEY`

using `--dart-define`. Defaults are retained for the existing Zameel Supabase project so the current project remains easy to run.

Never put a Supabase service-role key in the Flutter app.

## Google Play release

Google Play requires new apps and updates submitted from August 31, 2026 to target Android 16 / API 36 or higher. This project targets API 36.

Before publishing:

- choose and confirm the final unique application ID (`com.zameel.app` in this build)
- create a Play upload keystore
- copy `android/key.properties.example` to `android/key.properties` and fill it in
- never commit the keystore or `key.properties`
- complete Play Console privacy/data-safety/account-deletion declarations
- run the release test checklist in `docs/RELEASE_CHECKLIST.md`

Build:

```powershell
.\scripts\build_release.ps1
```

or:

```powershell
flutter build appbundle --release `
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co `
  --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_KEY
```

The preferred Google Play artifact is the signed `.aab` bundle.


## v1.3.1 build fix
- Release Android builds disable R8 minification temporarily because AGP 9.1.0 in the current Codemagic image reports a missing generated default ProGuard file.
- This is a build-stability change; app functionality is unchanged.


## Repair candidate validation

This archive includes the latest repair pass and a security-hardening migration. The repair pass preserves existing screens/features and additionally restores the registration profile-image upload path. It also removes client-side wildcard profile queries so private authentication email data is not unnecessarily returned.

The execution environment used for this repair does not contain the Flutter SDK and cannot reach external package/build servers, so `flutter analyze`, `flutter test`, an Android build, and live Supabase integration tests could not be executed here. Run those commands locally/Codemagic before production release.

## Platform support note (074)

- **Android is the production/release target** and has the configured Firebase app used for FCM/Crashlytics.
- The Flutter web/desktop scaffold remains build-source compatible where possible, but Firebase push/Crashlytics are intentionally not started on platforms that do not yet have provisioned Firebase options. This avoids false runtime failures without inventing credentials.
- To promote web/iOS to production later, provision those Firebase apps with FlutterFire and then enable their push platform setup.

## 074 maintenance hardening

- Restricted post/story/clip media is stored behind authenticated Storage access and resolved with signed URLs. Legacy `posts` and `graduation_book` objects are also protected by Storage RLS.
- Content deletion now removes its backing Storage objects where the user is authorized.
- Device push tokens are detached/invalidated during sign-out and safely reclaimed on account changes.
- Push retries track delivery per device to avoid re-alerting devices that already succeeded.
- Android 10 and Android 11+ bubble paths are handled separately, with official system-notification fallback.
- Native story/clip video upload streams from the picked file instead of loading the whole video into RAM.
- See `docs/PLAY_FGS_SPECIAL_USE_074.md` before Google Play submission.

Apply `supabase/migrations/074_private_media_and_push_delivery.sql` before testing the 074 client against production.
