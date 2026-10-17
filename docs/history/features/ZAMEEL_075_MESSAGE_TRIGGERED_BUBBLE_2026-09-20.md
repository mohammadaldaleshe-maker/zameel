# Zameel 075 — Message-triggered bubble

This maintenance revision removes the permanent Android foreground bubble host.

Behavior:
- Opening Zameel does not start a bubble foreground service.
- No permanent "Chat bubbles are ready" notification is posted.
- No automatic setup/test bubble is shown on app open.
- A real direct-message FCM may start a short-lived overlay service.
- The foreground notification for that service is the actual incoming message notification and uses the existing `zameel_bubble_thunder` sound channel.
- The custom overlay chat head is shown only for the real incoming message.
- Opening Zameel or dismissing the chat head stops the short-lived service.
- If Android rejects the message-triggered foreground-service start, the existing official Android Conversation/Bubble notification fallback remains active.

No Flutter social, feed, media, calls, stories, books, profile, or Supabase data behavior was changed in this revision.
