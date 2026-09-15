# Zameel Update 048

- Accepted book requests now unlock the normal private chat engine.
- Book chat keeps presence, message receipts, attachments, and Meet a Colleague while hiding voice/video calls.
- Private image/file attachments (15 MB maximum) are backed by a protected Supabase Storage bucket.
- Incoming calls use a full-screen phone-style swipe interface.
- In-call microphone, speaker, video, camera switch, and hang-up controls remain available.
- Contact calling matches locally hashed numbers and does not require friendship.
- Closing a meeting map ends it for both parties; reopening requires a new request and consent.
- The supplied Zameel ringtone and notification signature are bundled as the
  actual Flutter and Android notification-channel audio resources.

Apply `supabase/migrations/048_books_attachments_calls_meet.sql` after migration 047.
