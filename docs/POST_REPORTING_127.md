# Zameel 127: post reporting and administration

Scope: ordinary feed posts (text, image, video, mixed media) and profile post menus.
This does not add advertisement, story, clip, comment or account reporting/blocking.
Existing radio and beautiful-college reports stay in the admin reports screen.

## Behavior
- The post menu offers Report for another signed-in user's post; existing owner/admin delete actions remain.
- Category plus optional details (required for Other), busy state, cancel and retry errors.
- Success appears only after a completed RPC response. One report per reporter/post.
- Reporter identity comes from auth.uid(); author comes from the post, not client input.
- Submission uses SECURITY INVOKER and existing post SELECT policies, so hidden/private/inaccessible posts cannot be reported by guessing an ID.
- Normal clients cannot insert moderation status, author, creation/review timestamps, or change/delete reports.
- Rate guard serializes a reporter's submissions and permits 20 new reports per hour.
- No automatic hide by report counts: authorized administrator reviews first.
- Admin list includes category, details, post text excerpt, reporter, status and date; it applies owner scope to post reports and existing radio/college reports.
- Reports.manage, screen access, active admin and content-owner scope are checked server-side.
- A service-only transaction updates post visibility, review state and audit records together. Invalid report/post pairs fail.
- Rejecting an open report does not restore a separately hidden post. Restoring is an explicit action on a hidden report.
- is_hidden changes are server managed. Existing owner/admin visibility policy is preserved. Users still edit other post fields normally.
- Post and reporter foreign keys CASCADE; review/target identities SET NULL where applicable, preserving compatibility with account deletion cleanup.

## Rollout (one step at a time)
1. Apply app patch against uploaded app HEAD 3792ce2, then flutter analyze and flutter test.
2. Apply admin patch against the uploaded admin archive; node --test test/*.mjs and node test/post_reporting_test.mjs.
3. Run supabase/migrations/127_post_reporting.sql ONCE in Supabase SQL Editor (same file in both packages). It submits no report and moderates no existing post.
4. Run 127_post_reporting_verification.sql in SQL Editor. Expected PASS; it changes no user data.
5. Deploy admin-console from the ADMIN repo: npx supabase functions deploy admin-console --project-ref jwuqyykjmltroneqtjoc --no-verify-jwt
6. Commit only listed manifest files separately in app/admin repos; build and install new APK and admin release.
7. Live test using two disposable ordinary accounts: A posts, B opens menu and submits; admin sees one open report. Repeat B submission: still one report. Hide: public viewers lose post after fresh query; owner/admin may inspect it under existing policy. Reject an unrelated open report: hidden state must not reverse. Explicit restore: post returns after refresh.
8. Verify anonymous calls fail, normal users cannot execute review RPC, scoped admin cannot read/moderate another scope, and unauthorized permission cannot change state.
9. Test own-account deletion after submitting a report: report cascade should not block cleanup. Do not delete a real customer/admin account.

## Validation here and limits
The three existing admin contract/smoke suites pass, plus six behavior tests executing the actual new Edge review branch and shared reporting helpers. Save/delete/profile audience behavior outside the replaced menu controls was retained.
No Flutter/Dart/Deno/PostgreSQL runtime is available here. No live RPC, RLS or moderation integration is claimed; run rollout checks before publishing.
Previously cached post metadata/previously downloaded media may remain on a device until its normal refresh/cleanup. This patch does not remove offline files remotely or change update 123's speed behavior. Moderation protects fresh post SELECT queries; it is not a claim that every saved external media link becomes unusable.
Review ownership-handover deletion, sensitive-data disclosures/consent, UGC reporting on remaining surfaces, blocking, child-safety/age standards and store declarations remain separate release work.
