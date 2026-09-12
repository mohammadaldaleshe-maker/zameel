# Zameel v1.3.8 — Security Audit & Repair Report

## Scope

Static audit of the supplied Flutter/Supabase project, including Dart source, Android configuration, Supabase migrations, Edge Functions, storage policies and release configuration. Existing product features were intentionally preserved.

## Repairs applied

1. **Authentication profile image upload restored** in `ProfilePictureScreen`: selected images are uploaded to the authenticated user's `profiles/<uid>/...` path and the resulting URL is persisted to `users.profile_image`.
2. **Authentication email exposure reduced**: the client no longer uses wildcard `users` selects or nested `users(*)` queries.
3. **Database column privilege hardening**: `users.email` is no longer selectable through the normal API role; the signed-in user's email remains available through Supabase Auth.
4. **Graduation invite token hardening**: `graduation_books.invite_token` is no longer selectable through the normal API role. Owners retrieve it through the owner-only `get_graduation_book_invite_token()` RPC.
5. **Post interaction authorization**: likes, saves and comments now require the user to be able to view the source post. This blocks UUID-guessing attacks against private/blocked content.
6. **Notification forgery blocked**: clients cannot insert arbitrary notification rows for other users. Existing server-side notification triggers remain intact.
7. **Conversation membership hardening**: arbitrary members can no longer inject themselves/others into a conversation through the table API; the conversation creator controls membership, while the existing direct-chat RPC remains available.
8. **Block enforcement strengthened** for new follows and graduation-book joining.
9. **Security-definer RPC exposure reduced**: application RPCs remain executable by authenticated users; anonymous execution is revoked. Trigger-only functions are not API-callable.
10. **Migration compatibility repaired**: migration 012 now creates the legacy `conversation_members.id` column before altering it, so a fresh database can apply the migration chain without that known failure.
11. **Push queue cleanup**: already-read historical notifications are not replayed as new push notifications during hardening.
12. **Version consistency**: runtime/Codemagic version definitions updated to 1.3.8.

## Deliberately preserved

- Social feed and demo content
- Stories and Clips
- Friends/follows/groups/private groups
- Chat/anonymous chat
- Campus/live map/routing
- Business/jobs/calendar
- Meet/WebRTC
- AI area
- Graduation Book, 150 pages, two-page spreads, handwriting, images, movable elements, invites and PDF export
- Push notification infrastructure
- Existing branding and platforms

## Remaining release validation

The repair environment has no Flutter SDK and cannot reach external build/package servers. Therefore an APK/AAB build, `flutter analyze`, `flutter test`, live Supabase RLS tests and real-device feature testing could not be executed here. This is an environment limitation, not a claim that those checks passed.

Before production: run `flutter pub get`, `flutter analyze`, `flutter test`, Android release build, and apply migrations 001–018 to a staging Supabase project. Then test the critical flows listed in `docs/RELEASE_CHECKLIST.md`.

## Security residuals

The existing `profiles`, `posts`, and `graduation_book` storage buckets are intentionally public in this product version because the client uses public media URLs and sharing. Database RLS still protects database rows, but a leaked public media URL can be fetched directly. Converting these buckets to private signed URLs would be a separate storage migration and client refactor; it was not performed in this pass so existing media links are not broken.
