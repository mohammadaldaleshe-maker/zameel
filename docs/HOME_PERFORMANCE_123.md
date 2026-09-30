# Zameel 123 — home loading and media delivery

Prepared: 2026-09-30 (Asia/Amman).

## What the source audit established

- `main.dart` waited for Firebase initialization and device-token registration before `runApp`.
- `AuthGate` queried the profile before showing the home and recreated its future on token refresh.
- Update 122 awaited Storage URL refresh inside the routine intended to restore a local feed.
- The feed awaited signed media URLs before showing post text, replaced the entire list temporarily with five posts, then waited for likes/saves before restoring all posts.
- The loading branch and loaded branch had different widget ancestors, disposing the story/clip trays at the transition.
- Legacy single-image posts and full-screen story images did not consistently use the persistent image widget.
- A cache-only probe joined an in-flight full download. Rotated signatures had different in-flight request keys despite sharing a disk filename.
- Full video players downloaded the complete file before initialization. Large files on slow connections consequently imposed the entire transfer time before playback.
- There were no persistent home snapshots for the public story tray, public clips or live ads.

These are source-level findings, not measured production timings.

## Implemented in this package

- Render the Flutter app before optional push setup. Notification/deep-link handlers remain active.
- Restore account-specific routing metadata, verify it in the background, and retain the home on token refresh.
- Restore public posts, public stories, public clips and validated published advertisements from local six-hour snapshots. Story/ad expiry is checked on read. Private/friends-only items are not added to persistent snapshots.
- Keep the same feed widget tree during loading and refresh. Key posts/ads by ID.
- Render post metadata as soon as it arrives; resolve media when the visible widget needs it. Keep existing content through transient refresh failure.
- Use one persistent image path for legacy/mixed posts, stories and ads; reduce decoded image memory at display time. This does NOT reduce transferred image bytes.
- Key media by storage object plus account, coalesce equivalent signatures, migrate readable legacy cached files and let cache-only probes return without waiting for downloads.
- Existing local videos play locally. On a miss, stream immediately instead of downloading the entire file first. There is no parallel full-file prefetch of the current video.
- Do not prefetch complete next clips. Story prefetch is limited to the next image.
- Clear local previews on logout and invalidate affected previews on deletion/hiding.
- Add download byte/time and first-post display logs without printing media URLs or user content.

No schema/permission changes, no new dependencies and no paid service enabled.

## Practical limits

A first installation, a cleared/expired cache, or new remote content still needs network access. Public offline snapshots can be stale until the next successful refresh. Private content continues to require current server authorization; no public Storage access was enabled.

The streaming change does not add a persistent HLS/MP4 segment cache. A previously uncached video can use the network again on a later visit; complete legacy cached files are reused. Persistent segment caching is a separate native-player integration and must be measured rather than promised.

The small video previews still require the video source when no preview file exists. Generating durable thumbnails/short previews and adaptive video variants is the remaining media-delivery layer. Original large files are not automatically transformed by this package.

## Verification status

Flutter/Dart SDK is unavailable in the editing environment. `flutter analyze`, Flutter unit/widget tests, Android/iOS/web builds and device performance measurements have NOT been run here. The previous 36 passing tests belong to 122, not this package.

Added 15 behavioral tests covering snapshot privacy/expiry/clearing, stable media identity, streaming source selection, request coalescing, non-blocking cache probes, failed downloads and cross-account isolation. Updated the old source contract that mandated complete-video downloads to enforce streaming without duplicate prefetch. Run the full suite after applying.

## Apply and validate

Extract the archive to its own directory and run `Apply-Zameel-123.ps1 -Repo <repository path>`. The installer verifies original file hashes (ignoring CRLF/LF), validates all payload hashes, creates a backup outside the repo, then copies only listed files. It refuses unknown local revisions before copying anything. Do not manually overwrite conflicts.

Run:

```powershell
flutter analyze
if ($LASTEXITCODE -ne 0) { throw 'Analyze failed' }
flutter test
if ($LASTEXITCODE -ne 0) { throw 'Tests failed' }
git -c core.safecrlf=false diff --check
```

Then review the diff, commit the listed files and build a signed APK in the existing GitHub workflow. Keep the current installed app/data when updating.

## Acceptance on a real device

1. Warm the home once while online. Open a post image, a story image, a clip and an advertisement. Record content used.
2. Close and reopen the process without clearing app data. Measure time from entering home to first cached post/list, separately from first new remote media. Target: cached content within about one second on the tested phone; not yet measured.
3. Repeat briefly offline within six hours: previously saved public rows/images should display. Do not expect an unseen image/video or private story to become available offline.
4. Verify a token refresh does not reset scroll position or dispose the home.
5. Hide/delete an ad/story/clip, refresh online, reopen and check it does not return. Check already-expired stories/ads are excluded from snapshots.
6. Switch accounts: confirm no previous account’s private media/routing snapshots appear. Confirm block/suspension behavior remains enforced.
7. On a slow connection compare first video frame with the old APK. A new full video must start streaming without waiting for the entire file to be cached.
8. Test notification cold-start navigation, mixed-media gallery, video pause/resume, upload/delete, likes and comments. Repeat on iOS/web before calling those releases validated.

## Free versus paid delivery options

Prices checked against official pages on 2026-09-30; usage/tax/other services are additional where applicable.

- Free application work: local snapshots, request coalescing, stable widgets, viewport loading and cache-first playback. This package implements those behaviors; storage/network service bills still apply.
- Free tools: FFmpeg can prepare thumbnails, optimized MP4 and adaptive variants. The software is free; the worker/server doing that work still has compute, storage and traffic costs. It needs an upload-processing queue and migration plan for older media.
- Cloudflare Stream: automatic encoding and adaptive delivery. $5/month per 1,000 stored video minutes, plus $1 per 1,000 delivered minutes. Example: 1,000 stored minutes + 10,000 delivered minutes = $15/month for Stream alone. 100,000 delivered minutes at the same storage level = $105. Preloading/buffering counts as delivered traffic. This has not been integrated or subscribed to.
- Supabase image transformations: available on Pro and above. Pro starts at $25/month; transformations include 100 origin images then $5 per 1,000 origin images, subject to billing package rules. This resizes delivered images, unlike Flutter's decoded-size setting. It does not replace adaptive video encoding.

Recommended production path: validate the app changes first, then integrate one video-processing service and image variants. Keep originals, store source + thumbnail + playback references per media item, publish only after processing succeeds, enforce existing audience/ad-approval rules on playback tokens, and migrate existing media in batches. Benchmark first-frame/image latency on Jordanian Wi-Fi and mobile data before committing to larger spend. No vendor can guarantee zero latency on a first visit or a disconnected phone.

Official references:
- https://developers.cloudflare.com/stream/pricing/
- https://developers.cloudflare.com/stream/
- https://supabase.com/pricing
- https://supabase.com/docs/guides/storage/serving/image-transformations
- https://ffmpeg.org/about.html
