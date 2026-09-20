# Zameel 073 — Final bubble architecture

This revision does not claim that Android allows an app to force a floating bubble on every device. It implements the strongest platform-compliant hybrid available:

- Primary: `TYPE_APPLICATION_OVERLAY` after the user grants Display over other apps.
- A one-time on-device self-test verifies that `WindowManager.addView()` actually succeeds on that phone.
- The overlay host starts while `MainActivity` is visible and stays foreground.
- If an OEM kills the host, a high-priority direct-message FCM may restart it; failures are caught and fall back safely.
- Fallback: official Android Conversation/Bubble notification.
- Android 11+ system bubbles use a long-lived conversation shortcut and `BubbleMetadata.Builder(shortcutId)`.
- The app no longer relies on `NotificationChannel.setAllowBubbles(true)`, which Android 11+ ignores.
- If system bubbles are not allowed, Zameel opens the official app bubble settings for the user.
- Incoming bubbles are not auto-expanded from the background.

The user/system can still disable bubbles or kill background work. No third-party app can override those Android controls.
