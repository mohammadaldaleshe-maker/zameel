# Zameel 078 — Social and media runtime repairs

## Included

- Radio: one-tap playback, automatic next track, likes, owner/admin removal, user reports, two-report pending review, and admin-only mute/review.
- Beautiful College: explicit PostgREST user relationship and safe user-facing load errors.
- Lamma: creator membership, join/open flow, and a member-only realtime group chat.
- Video and clips: auto-hiding controls, tap-to-show controls, seekable progress, and elapsed/remaining time.
- Full-screen media: hidden/reappearing chrome, image zoom, and safe controller disposal.
- Home: visible Books, Lamma, Zameel Radio, and Beautiful College shortcuts.

## Required database step

Run `supabase/migrations/077_social_runtime_media_repairs.sql` once in the Supabase SQL Editor before testing the updated app.

## Local verification

```powershell
flutter pub get
flutter analyze
flutter test
```

No earlier migration should be run again. Existing chat, calls, stories, books, and repaired features were not changed except for the shared media-viewer controls requested in this release.
