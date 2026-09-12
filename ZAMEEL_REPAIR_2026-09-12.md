# Zameel repair — 2026-09-12

Implemented in this package:

- Reliable direct-call WebRTC signaling: Supabase Broadcast remains the fast path, while `call_signals` persists offer/answer/ICE/ready/bye packets so a late subscriber can replay them instead of staying on "Waiting for colleague".
- Shared direct-call session state in `direct_call_sessions` with caller/callee membership and synchronized `ended` status.
- A visible red end-call button in the in-call control bar. Ending from either side sends `bye` and marks the shared session ended so the peer closes too.
- Notification taps now route friend requests, calls, post like/comment notifications, chat/conversation notifications, and story notifications toward their originating feature when identifiers are present in notification `data`.
- Story views are recorded for real Supabase stories.
- Story owners can open a viewers list from inside their own story.
- Other users can like/unlike a story from inside the story viewer.
- SQL migration `028_calls_story_engagement_and_navigation.sql` adds the durable call tables, RLS policies, Realtime publication, story owner read access for viewers/reactions, and rebuilds `start_direct_call` so the durable call session is created before notification delivery.

## Required database step

Run `supabase/manual/028_calls_story_engagement_and_navigation.sql` in Supabase SQL Editor after the earlier migrations, especially 027.

## Validation note

The execution container used for this repair does not provide Flutter/Dart executables, so `flutter analyze` could not be executed here. The changed Dart files were structurally checked for balanced delimiters and manually inspected around every changed block.
