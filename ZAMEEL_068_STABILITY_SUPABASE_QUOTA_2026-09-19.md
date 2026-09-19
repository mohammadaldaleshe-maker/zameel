# Zameel 068 — Stability and Supabase cached-egress repair

## Confirmed quota cause

The Supabase organization is on the Free Plan. Cached Egress reached
9.861 GB of the included 5 GB (197%). Database size, Storage size, Realtime,
Functions and MAU remain far below their quotas.

## Repairs

- Restored true multi-selection for normal post photos/videos.
- Limited one image to 12 MB, one video to 80 MB and one post to 150 MB.
- Added one-year immutable Cache-Control to new post media objects.
- Changed video playback to download once into the local bounded cache before
  playback. The old path could stream and prefetch the same video concurrently.
- Increased the local media-cache lifetime from 2 to 14 days.
- Added persistent caching for normal post images on Android/iOS/desktop.
- Reduced the feed recovery poll from every 2 minutes to every 10 minutes;
  Realtime remains active.
- Limited likes/saved-state reads to the 30 posts currently displayed.
- Removed the permanent overlay foreground service and sensitive
  SYSTEM_ALERT_WINDOW permission. Official Android conversation bubbles remain.
- The bubble is created only for a new direct-chat message. When Android accepts
  it as a bubble, the duplicate status-area notification is suppressed; if the
  user disabled bubbles, a normal notification remains so messages are not lost.
- Added owner/admin-only `zameel_storage_usage_report()` and an 80 MB server-side
  object limit for the posts bucket. Migration 068 deletes no content.

## Required Supabase step

Run `supabase/migrations/068_stability_and_quota_guard.sql` in SQL Editor.

Then an owner may inspect stored bytes without exposing data:

```sql
select * from public.zameel_storage_usage_report();
```

## Important billing note

Code changes reduce future downloads but cannot erase cached egress already
counted in the current/previous billing cycle. The quota resets with the next
billing cycle. Until then, avoid repeatedly playing the same large test videos.
