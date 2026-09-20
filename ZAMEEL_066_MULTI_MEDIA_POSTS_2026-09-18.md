# Zameel 066 — Multi-media posts
Date: 2026-09-18
Base: Zameel 065 Android Chat Bubbles

## Scope
Adds multi-media content to normal feed/profile posts without changing the engagement model.

A post is still exactly one row in `public.posts` with exactly one `posts.id`. Likes, comments, threaded replies, saves, shares, notifications, privacy and post deletion permissions continue to target that same post id.

## New publishing capability
- Text-only posts remain supported through the existing text publishing path.
- A normal post can now include text plus multiple images and/or videos.
- A post can contain only multiple images.
- A post can contain only multiple videos.
- A post can mix images and videos in the selected order.
- Maximum: 10 media items per post.
- Supported image formats: JPG/JPEG, PNG, WEBP, GIF.
- Supported video formats: MP4, MOV, M4V, WEBM.
- Media upload is rollback-safe: if publishing fails after uploads begin, newly uploaded files are removed on a best-effort basis.

## Backward compatibility
Migration 066 adds only `posts.media_items jsonb`.
Legacy `image_url`, `video_url` and `type` are still populated for new multi-media posts so older app builds can display at least the first compatible media item.
Existing posts receive `media_items = []` and continue through the old rendering paths.

## Engagement regression protection
The following tables/functions are intentionally not modified by migration 066:
- `likes`
- `post_comments`
- `post_comment_likes`
- `saved_posts`
- `shared_posts`
- comment/reply triggers
- like/comment count triggers
- notification triggers
- post privacy/RLS policies

## UI changes
- Home composer: optional multi-select images/videos alongside text.
- Profile composer: new Multi-media post option.
- Home feed: ordered carousel for new multi-media posts.
- Profile: ordered carousel for new multi-media posts.
- Comments screen: shows the multi-media post above its existing threaded comments/replies.
- Saved posts: shows the multi-media carousel for new posts.
- Legacy single-image and single-video posts keep their existing presentation path.

## Required Supabase migration
Apply once:

`supabase/migrations/066_multi_media_posts.sql`

## Required local verification
```powershell
flutter pub get
flutter analyze
flutter test
```

Then test at minimum:
1. Text-only post.
2. 2+ images in one post.
3. 2+ videos in one post.
4. Text + image + video in one post.
5. Like/unlike the same mixed post.
6. Add a comment, reply to that comment, edit/delete where already supported.
7. Save/unsave and share/unshare the same mixed post.
8. Open the mixed post from profile, comments, saved posts and notifications.
9. Recheck an old image post and an old video post for unchanged behavior.

## REV2 — file_picker 12.x compatibility hotfix
After local `flutter analyze` on 2026-09-18, the multi-media picker code was updated for the federated `file_picker` 12.x API used by this project:
- `FilePicker.platform.pickFiles(...)` -> `FilePicker.pickFiles(...)`.
- `FilePickerResult.files` wrapper removed; `pickFiles()` result is used directly.
- Removed the obsolete `PlatformFile.size` getter usage; `lengthSync()` is used for display-only size when available.
- Removed the obsolete `PlatformFile.bytes` getter usage; `readAsBytes()` is used for binary upload when a native file path is unavailable.
- Replaced invalid `Colors.black66` with the equivalent constant alpha color.

No database, engagement, comments, replies, likes, saves, shares, notifications, privacy, bubbles, calls, or LiveKit behavior was changed by this hotfix.
