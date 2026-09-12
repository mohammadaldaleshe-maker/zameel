# Zameel WebRTC + Stories runtime repair — 2026-09-12

## WebRTC
- Caller creates and persists SDP offer immediately after Supabase Realtime subscription; it no longer depends on receiving a one-shot ready event.
- Broadcast signaling remains enabled for low latency.
- call_signals is replayed and polled while connecting, protecting offer/answer/ICE against missed realtime events.
- Remote ICE candidates are queued until remote SDP is installed.
- Unified Plan is explicit.
- Remote tracks are attached even when RTCTrackEvent.streams is empty.
- ICE failure triggers restartIce and a real ICE-restart renegotiation.
- connectionState, iceConnectionState, iceGatheringState and signalingState are logged for diagnosis.
- The callee marks direct_call_sessions active when answering.
- Existing synchronized hangup behavior is preserved.
- Optional TURN is supported through WEBRTC_TURN_URL / WEBRTC_TURN_USERNAME / WEBRTC_TURN_CREDENTIAL dart-defines; no secret is hard-coded.

## Stories
- Viewing a story calls record_story_view_compat instead of assuming viewer_id.
- The compatibility RPC detects viewer_id or legacy user_id at runtime.
- Story owners read viewers through get_story_viewers_compat, bypassing fragile FK-name/PostgREST relationship hints after explicit ownership checks.
- Story owners can see likes/reactions and liker names through get_story_reactions_compat.
- The story viewer now shows Views & likes with two tabs and counts.
- Existing reaction state is loaded when a story opens or changes pages.

## Required database step
Run supabase/migrations/029_webrtc_story_runtime_repair.sql in Supabase SQL Editor before testing this build.
