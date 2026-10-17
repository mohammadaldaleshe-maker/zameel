# Zameel 069 — real mixed-media picker and incoming-message bubble

## Multi-media publishing

- Replaced `file_picker` for post composition with
  `ImagePicker.pickMultipleMedia()`.
- Android/iOS can now select multiple photos and videos in the same picker.
- Home and Profile composers use the same picker and upload service.
- One post row keeps the text, privacy and ordered `media_items` list.
- Existing 10-item and 12/80/150 MB quota guards remain active.

## Android direct-chat bubble

- Creates fresh v2 notification channels so an older channel configuration
  cannot silently retain disabled bubble capability.
- Enables bubbles on both sound and silent direct-message channels.
- Requests auto-expansion only when an actual direct-chat push arrives.
- Suppresses the duplicate status notification only after Android accepts the
  message as a bubble. If the device blocks bubbles, the normal notification
  remains as fallback.
- There is no permanent foreground service and no permanent Zameel status icon.

## Required deployment

The updated APK and current push function must both be deployed. After pushing
the source and building the APK, run:

```powershell
npx supabase@latest functions deploy send-push-notifications `
  --project-ref jwuqyykjmltroneqtjoc
```

No new SQL migration is required for 069. Migration 068 remains the latest SQL.

## Phone test

1. Install the new APK (build number 8) on both devices.
2. Open Zameel and sign in so each device refreshes its FCM token.
3. Put the receiving app in the background; do not force-stop it.
4. Send a new direct-chat message from the other account.
5. Confirm the bubble opens the correct conversation.
6. Publish one post containing text, at least two images and two videos.
