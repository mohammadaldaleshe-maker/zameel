# Google Play foreground-service declaration — Zameel chat bubble host

Android production builds declare `ZameelOverlayService` as a `specialUse`
foreground service. Its only purpose is the user-enabled floating direct-message
chat head. The service starts while `MainActivity` is visible and only when the
user has granted Android's **Display over other apps** permission. It remains
foreground so an incoming direct-message push can update the already-running
chat head without attempting a prohibited background foreground-service launch.

Suggested Play Console description:

> Zameel uses a user-enabled special-use foreground service to keep the floating
> direct-message chat head available after the user grants Display over other
> apps permission. The service displays an ongoing low-priority notification and
> is used only for direct-message bubble delivery. If permission is unavailable,
> Zameel falls back to Android conversation notifications/system bubbles.

Before release, ensure the Play Console foreground-service declaration matches
the manifest and this behavior exactly. Do not describe the service as starting
only after a push; the current implementation intentionally starts the host
while the app is visible.
