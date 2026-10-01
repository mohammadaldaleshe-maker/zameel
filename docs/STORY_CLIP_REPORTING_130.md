# Zameel 130 — Story and clip reporting

Adds a report option to the full story and clip viewers for another user's content. Existing post reporting, publishing, reactions and media cache remain in place. Story video pauses while the reporting dialog is open.

Admin reports include stories and clips with protected preview, review, hide, restore, dismiss and delete actions. Counters include all five report sources. Visibility changes produce an owner notification in the database; device push delivery depends on the existing push service. Image previews fit within a 280px-wide, 160px-high box without cropping or forced enlargement.

The migration preserves the installed audience/privacy helpers and adds moderation guards. A deleted item cannot be restored, and an expired story cannot be restored. Moderation deletion hides the record from app readers while retaining evidence for administrators. Offline cached content can remain visible until a successful server refresh; previously issued media links do not become instantly invalid.

## Deployment order
1. Apply both guarded packages to the correct repositories. If DIFFERENT VERSION appears, stop and provide the filename; do not force replacement.
2. App: flutter analyze, flutter test, git diff --check. Admin: node --test test/*.mjs, git diff --check.
3. Run supabase/migrations/130_story_clip_reporting.sql once in Supabase SQL Editor, then 130_story_clip_reporting_verification.sql. Both packages contain identical SQL.
4. Deploy admin-console from the admin repository: npx supabase functions deploy admin-console --project-ref jwuqyykjmltroneqtjoc --no-verify-jwt
5. Commit only the manifest paths, push main, then build and install both a new APK and a new admin release.

## Live acceptance checks
Use another user's active story and clip: open the viewer, choose ⋯ then Report, enter a reason and submit. Check that own content cannot be reported and duplicates do not create additional reports. Private/inaccessible and expired stories must not be reportable. Verify matching content preview, natural small image dimensions, counters and resolved status. Delete content and refresh other accounts; confirm the owner's moderation notification. Check hide/restore and that expired or deleted content cannot be restored.

## Validation performed here
26 Node tests passed, including scope/permission checks, content/report identity matching, clip/story previews and database failure handling. Flutter, a live PostgreSQL database and the native admin UI were not available in the preparation environment; the local checks and live acceptance checks above remain required.
