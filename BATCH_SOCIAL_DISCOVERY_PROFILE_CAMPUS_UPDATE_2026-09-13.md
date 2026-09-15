# Zameel batch update — 2026-09-13

This batch is designed to be tested in one Codemagic build.

## Included

- Profile post images open in a full-screen zoom viewer instead of comments.
- Owners can hide a post or change it between public, colleagues, and private.
- Visibility changes are enforced everywhere by existing RLS and migration 038 removes ineligible shares.
- Text posts can be published directly from the profile.
- The profile top title, arrow, and vertical menu were removed; Android/iOS system back returns to the previous/home screen.
- Suggested colleagues appear on Home with search and add actions.
- Suggestions are gender-neutral and scored by locally hashed phone matches, university, college, major, mutual colleagues, location, and recency.
- Gender is carried correctly through onboarding, shown read-only in settings, and locked by migration 037 after registration.
- Home has a contact-call button. Registered contacts can receive voice/video calls without a friendship requirement if they allow calls; non-registered contacts receive a professional invite prompt.
- Public clips appear as circles below Stories with like, comment, and share only.
- Clip shares are removed automatically when a clip becomes private, hidden, or colleagues-only and the sharer is no longer eligible.
- Campus loads the university stored in the user's profile automatically. The University of Jordan and JUST have direct first-load coordinates; other universities use the existing university lookup.
- The obsolete “search for a university first” blocking message was removed.

## Required database order

Run these files in Supabase SQL Editor after migration 036:

1. `supabase/migrations/037_gender_lock_and_neutral_discovery.sql`
2. `supabase/migrations/038_suggestions_visibility_clips_calls.sql`

## Permissions

- Android: `READ_CONTACTS` added.
- iOS: `NSContactsUsageDescription` added.
- Contact numbers are normalized and SHA-256 hashed on-device; raw address-book numbers are not sent for discovery matching.

## Build note

The workspace used for this repair does not include the Flutter SDK, so the final Dart analyzer and Android release build must run in Codemagic. YAML/XML and archive checks are performed locally before handoff.
