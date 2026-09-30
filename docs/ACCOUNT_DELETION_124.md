# Account deletion 124 — review and rollout

Based on the source archive supplied 2026-09-30 and three production catalog
reports. Existing delete_my_account only removed auth.users, with no FK from
public.users to auth.users. Several other tables have no account FK; some
commercial/admin references block deletion.

## Implemented scope

- Preserve delete_my_account() RPC signature for existing APK/web callers.
- Authenticated caller can request only their own account. Anonymous callers
  cannot request. Worker target comes solely from an internally claimed job.
- Persistent queue, per-job one-time dispatch credentials, five-minute leases,
  bounded Storage batches, retries and review state after ten worker failures.
- Ban login first; transactional cleanup of explicitly listed personal rows;
  NULL nullable audit references; delete public.users; remove exact captured
  files through Storage API; hard-delete Auth using Admin API. Completion is
  recorded only after all those stages have succeeded.
- Metadata cleanup errors roll back that database stage and leave files intact.
  Failure after successful database cleanup cannot restore removed content;
  manifests preserve remaining file work for retry. Do not claim global
  transactionality across Storage, Auth and Postgres.
- Capture Storage ownership metadata, established UUID path prefixes, private
  media UUID third path segment, and the legacy radio table's exact paths.
  Storage metadata is never directly deleted or modified.
- Existing own account FKs/CASCADE remain unchanged. Unknown FK failures stop
  and retry rather than disabling constraints or deleting unrelated rows.
- Keep the speed update and all other application features intact.
- User-facing messages distinguish a received request from completed deletion.
- Worker cron runs every minute. Dispatches up to three jobs. Short batches
  yield; transient errors retry after five minutes. No completion-time guarantee.
- Completed job identifiers are removed after seven days by the dispatcher.

## Explicit blockers / remaining work before claiming store readiness

Shared/business/administrative account owners are intentionally rejected BEFORE
queuing destructive work, with a support address. Owning a group, Lamma,
graduation book or meeting requires an ownership-handover decision. No such
handover UI or manual-review console is implemented here. This limitation must
be resolved before presenting all-account self-service deletion as complete.

No application policy was changed to deny an already-issued JWT immediately.
Banning Auth prevents subsequent login; existing access tokens can remain valid
until expiry. New writes completed during cleanup are rediscovered where the
known ownership/path patterns apply; unrecognized ownerless legacy media and
externally hosted copies need a separate audit. Stored third-party content and
backups are not claimed to be erased by this workflow.

The approved production source does not include all recent admin migrations.
The provided live catalog reports informed safeguards, but PostgreSQL runtime
integration is REQUIRED. Feature/account guard triggers can still reject
cleanup and require a targeted fix from the actual error stage. Review pending
and review jobs; never silently treat them as deleted.

This is a testable implementation, NOT proof of store compliance or a final
privacy policy. Keep the draft privacy policy until deletion is verified and
shared ownership, support processing and provider backup retention are settled.

## Checks performed here

Seven worker behavioral tests passed using Node: execution ordering, DB failure
before Storage, Storage failure retaining manifest, Auth failure preventing
completion, large-account resume, malformed manifest and late-file rediscovery.
Changed Dart lexical structure was checked. Flutter/Dart/Deno/PostgreSQL are not
available here. No Flutter analyzer, Flutter tests, Deno type check, deployed
RPCs, SQL fixtures or real account deletion have been executed here.

## Rollout (one stage at a time)

1. Apply source patch with its hash-checked PowerShell installer.
2. Run flutter analyze and flutter test; run the Node worker test.
3. Run 124_account_deletion_jobs.sql once in Supabase SQL Editor. It creates
   infrastructure and replaces the RPC but deletes no account on installation.
   Until the cron is enabled, requests explicitly fail worker-not-ready.
4. Deploy: npx supabase functions deploy account-deletion --project-ref
   jwuqyykjmltroneqtjoc --no-verify-jwt
5. Test an unauthenticated POST with arbitrary UUID job/token: expect 403
   invalid_job_token. A route/API error means STOP before enabling the worker.
6. Run 124_account_deletion_verification.sql in SQL Editor. Synthetic job rows
   roll back; no real accounts or objects are touched.
7. Run 124_enable_account_deletion_worker.sql after successful deploy/checks.
8. Test using a NEW disposable non-admin/non-partner account with one post,
   image, story, clip and comment. Never use the owner's real account. Record
   baseline counts for a separate control account. Request through the web page
   (its RPC signature remains compatible), inspect job state, confirm BOTH Auth
   and public.users disappear, exact files are absent, and control data remains.
9. Test shared account safeguard with a disposable owned group: request must
   return review error without deleting content. Do NOT delete an actual paid
   advertiser to test this.
10. Build the new APK only after integration checks; test the new messages and
    logout/local-cache clearing. Commit only the manifest paths.

Monitoring (SQL Editor, omit user identifiers in screenshots):
select state, data_removed, attempts, last_error, count(*)
from public.zameel_account_deletion_jobs
 group by state,data_removed,attempts,last_error;

If failure occurs, report state + last_error stage. Never export token/lease or
credential columns. Stopping cron pauses cleanup and also prevents new requests
(worker readiness guard). It does not restore content already removed.

Official references checked 2026-09-30:
https://supabase.com/docs/guides/storage/management/delete-objects
https://supabase.com/docs/guides/auth/managing-user-data
https://supabase.com/docs/guides/functions/schedule-functions
