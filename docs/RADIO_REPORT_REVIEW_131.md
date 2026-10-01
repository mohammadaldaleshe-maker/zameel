# Zameel 131 — Radio reporting and moderation UI

Radio reports no longer hide a recording automatically after two reports. The installed trigger is removed; existing hidden recordings are not restored automatically. Radio still expires on its existing daily schedule. A report now confirms receipt for administrative review. Error messages distinguish duplicate reports from other failures.

The migration records the required authenticated SELECT grant on radio posts while retaining existing RLS. It installs service-only, permission-checked radio review and unmute transactions. Delete hides the recording from app readers and blocks restore while retaining the record until existing scheduled cleanup. Review decisions and unmute actions are audited. Owner notifications are queued for visibility changes; actual push delivery depends on the existing push service.

Admin report rows use a ⋯ menu. Report fonts are smaller. Radio preview offers an audio player and displays the real account name even for anonymous recordings, only behind admin permissions and scope checks. The radio section in community management also displays the real account name. App users continue to see anonymous recordings without this added identity disclosure.

Report images start in a small 240x140 maximum size. Wheel zoom is limited from 0.5x to 5x inside the preview frame, with plus, minus and reset controls. Images are contained rather than cropped or forced larger.

Muted radio accounts are accessible from Reports → Radio mutes. Readers can view the scoped list; reports.manage is required to lift a mute. The list contains up to 100 currently muted accounts. Unmute requires a reason and records the authenticated actor; it does not change ordinary account bans or user-to-user mute preferences.

## Apply and deploy
1. Apply both guarded packages to their own repositories. Stop on DIFFERENT VERSION and provide the filename; do not overwrite manually.
2. App: flutter analyze, flutter test, git diff --check. Admin: node --test test/*.mjs, git diff --check.
3. Run 131_radio_report_review.sql ONCE in Supabase SQL Editor, then 131_radio_report_verification.sql. SQL in both packages is identical.
4. Deploy admin-console from the admin repository using the usual project ref jwuqyykjmltroneqtjoc.
5. Commit only manifest paths, push, then build and install both APK and Windows admin.
6. Test with two accounts: report another user's radio, verify row and audio, compare anonymous public display with the administrative real name, check ⋯ decisions/counters/notification, wheel and button zoom, and lift a mute then record again. Confirm multiple reports cannot automatically hide new recordings.

## Validation and limits
35 Node tests passed locally, including scope denial, safe audio signing, anonymous author access, radio review transaction errors and unmute authorization. Flutter, live PostgreSQL and native UI rendering were unavailable here; local Flutter checks and live acceptance remain required. The daily radio cleanup and its cascading report deletion are unchanged, so this update does not provide a permanent radio evidence archive. Previously issued signed audio URLs expire after their short lifetime; offline snapshots refresh when network requests succeed.
