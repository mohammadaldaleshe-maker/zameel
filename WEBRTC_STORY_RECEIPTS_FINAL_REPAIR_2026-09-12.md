# Zameel WebRTC and story engagement repair

## Required database step

Run the complete contents of this file once in Supabase SQL Editor:

`supabase/migrations/030_webrtc_rpc_and_story_receipts.sql`

The script is idempotent and installs authenticated RPC functions for durable
call signaling plus a canonical story-view receipt table.

## Runtime changes

- Call offers, answers, ICE candidates, and hangup messages still use Realtime
  Broadcast for speed, with durable RPC-backed signaling as the reliable path.
- The caller and callee replay missed signals until the peer connection forms.
- Complete local SDP is sent after ICE gathering, preventing candidates from
  being lost when a device joins late.
- Durable signals are persisted before Realtime Broadcast and each transport
  receives its own Map copy. This prevents Supabase's broadcast envelope from
  replacing `offer`, `answer`, and `candidate` with `type: broadcast`.
- Story views are stored once per viewer and story. Story owners can see viewer
  and reaction lists, and engagement totals are displayed in the story viewer.
- Codemagic forwards optional TURN settings through `WEBRTC_TURN_URL`,
  `WEBRTC_TURN_USERNAME`, and `WEBRTC_TURN_CREDENTIAL`.

## Verification order

1. Run migration 030 in Supabase SQL Editor.
2. Run migration 031 in Supabase SQL Editor. It adds the direct-call signaling
   mailbox used as the deterministic negotiation path.
3. Run `flutter clean`, `flutter pub get`, and `flutter analyze`.
4. Build and install the same new APK on both devices.
5. Test audio and video on the same Wi-Fi.
6. Test on separate networks. Reliable carrier/mobile-network traversal needs
   valid TURN credentials configured in Codemagic; STUN alone cannot cross all
   NAT and firewall combinations.
