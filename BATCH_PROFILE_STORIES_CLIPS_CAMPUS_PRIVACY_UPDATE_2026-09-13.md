# Zameel profile, stories, clips, campus and privacy batch — 2026-09-13

## Home

- Removed the profile avatar from the top bar; Profile remains available in the side menu.
- Restored enough title space for `Zameel`.
- Changed silent feed refresh from 30 to 15 seconds.
- Refresh pauses in the background and resumes with the app.
- When new posts arrive above the current viewport, the scroll extent delta is compensated so the reader remains at the same content position.

## Stories and clips

- Removed the visible Stories and Public Clips headings.
- Stories remain circular and show their actual image/text or a muted 1.5-second video preview instead of the publisher avatar.
- Public clips use rectangular cards with a muted 1.5-second preview.
- Story and clip lists refresh every 15 seconds and stop refreshing in the background.
- Opened stories and clips show the publisher name and avatar; tapping them opens the publisher profile.

## Profile and ownership

- Profile photos open in a read-only full-screen zoom viewer for owners and visitors.
- Owners have explicit Change photo and Change cover controls.
- Added a clearly labeled About me card.
- Profile publishing now supports text, photo, video and image/video Story creation with public, colleagues or private visibility.
- Visitor profiles show public social metrics and permitted content, but hide Settings, Insights, Activity, Achievements, Saved, My Library, Books, Groups, Videos, Partners and Alumni Book owner shortcuts.
- The public graduation-book shortcut is hidden from visitors in this profile surface.
- Post ownership is checked per post, including reshared posts, before showing visibility, hide or delete actions.
- Existing Supabase RLS is reinforced in migration 039 for users, posts, stories and clips.

## Following and colleague requests

- Sending a colleague request automatically follows its recipient.
- A pending outgoing relation is presented as `Following • request pending`.
- An accepted request is presented as `Colleagues`.
- Existing pending requests are backfilled into follows by migration 039.

## Campus

- Campus displays the university stored in the signed-in profile.
- Building and service labels are scoped to that university.
- Building/service navigation first loads the registered university and uses a bounded lookup around its coordinates.
- A 5 km safety boundary prevents a search result from opening a distant unrelated location.
- If a facility cannot be resolved inside the campus boundary, the user is kept on the university map and asked to select the point there.

## Database

Run after migration 038:

`supabase/migrations/039_profile_follow_and_campus_privacy_hardening.sql`

The final 039 revision detects legacy deployments where `follows` still points
to `profiles`. When existing rows are compatible, its foreign keys are safely
repointed to the canonical `users` table. A missing legacy profile can no longer
cancel a colleague request or abort the migration.

## Verification note

This workspace does not include Flutter SDK. Structural Dart checks and configuration/archive checks are performed here; run `flutter pub get` and `flutter analyze` locally before the single Codemagic build.
