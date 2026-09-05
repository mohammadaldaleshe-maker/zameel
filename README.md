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
