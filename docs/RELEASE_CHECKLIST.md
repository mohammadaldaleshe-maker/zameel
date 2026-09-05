# Zameel — Google Play release checklist

## Included in this release candidate
- Android application ID: `com.zameel.app`
- Target/compile SDK: Android API 36
- Release build configured for R8 shrinking
- Release signing configuration reads `android/key.properties`
- Debug signing is retained only as a development fallback; never publish an AAB built without an upload key
- Supabase URL and publishable key support `--dart-define`
- Core Supabase migration for users, posts, likes, saved posts and current media buckets
- Existing functional repair pass retained, including the Stories `hasVideo` compile fix

## Before publishing
1. Create/confirm the final Google Play application ID. It cannot be changed after publication.
2. Create an upload keystore and fill `android/key.properties` from `android/key.properties.example`.
3. Keep the keystore and `key.properties` out of source control.
4. Run the Supabase migration in `supabase/migrations/001_core_schema.sql` against the production project.
5. Configure Supabase Auth email/OTP settings and production redirect URLs.
6. Test registration, verification, login, profile editing, image upload, post creation, likes, saves, deletion and logout on a real Android device.
7. Run `flutter clean`, `flutter pub get`, `flutter analyze` and `flutter test`.
8. Build with `flutter build appbundle --release`.
9. Upload the AAB to the Google Play internal testing track first.
10. Complete Play Console Data safety, content rating, app access, privacy policy and account deletion requirements as applicable.

## Production configuration example
```powershell
flutter build appbundle --release `
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co `
  --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_KEY
```

The production AAB is normally created under `build/app/outputs/bundle/release/`.

## Security note
The client no longer contains a hard-coded administrator username/password. Administrative access must be implemented through authenticated Supabase roles and server-side authorization.

## v1.3.0 professional profile & partners upgrade
- [x] New Zameel brand assets applied to Android/iOS/Web launch and icons.
- [x] Professional student profile dashboard with cover, bio, username, headline, stats and shortcuts.
- [x] Profile follow/unfollow flow connected to `follows`.
- [x] Profile post like button uses optimistic UI and persistent `likes` rows.
- [x] Like counter trigger keeps `posts.likes_count` synchronized.
- [x] Zameel Partners is accessible to normal users, not only admins.
- [x] Books file picker updated for `file_picker` v12 API.
- [ ] Run Supabase migration `004_professional_upgrade.sql` before testing likes/profile fields/following.
- [ ] Run Codemagic Android test workflow and install the generated APK on a physical phone.
