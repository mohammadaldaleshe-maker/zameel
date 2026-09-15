# Zameel home, books, and study-files repair

## Required Supabase steps

1. Run `supabase/migrations/032_book_exchange_workflow.sql` in SQL Editor.
2. Run `supabase/migrations/033_book_handover_chat_and_contact.sql` in SQL Editor.
3. Deploy the PDF-branding function once:

```powershell
supabase functions deploy brand-study-file --project-ref jwuqyykjmltroneqtjoc
```

The function verifies the signed-in user, downloads the private PDF, embeds the
Zameel mark in every page, and returns the modified bytes directly to the app.
If it has not yet been deployed, downloads still work and fall back to the
original PDF.

## Implemented behavior

- The home feed listens to `posts` changes, refreshes quietly every 30 seconds,
  and refreshes immediately when the app returns to the foreground.
- The Android/iOS status bar uses Zameel teal with light system icons.
- Books are persisted in `book_listings` instead of a local-only demo list.
- Requests are persisted, notify the owner, and can be accepted or rejected
  from the swap icon in the Books screen.
- Accepted requests create a private transaction-chat route, separate from the
  ordinary social chat. An optional owner phone is visible only to transaction
  participants after acceptance.
- Completing handover marks the requested (and offered exchange) books as
  completed, cancels competing pending requests, and removes the books from the
  available marketplace automatically.
- Sale requests show an explicit anti-fraud and cash-on-delivery safety notice.
- The price field rebuilds immediately and is visible only for sale listings.
- The Stories strip uses Zameel mint/teal surfaces instead of a white block.
- An exchange request requires the requester to have an available offered book.
- Study-file taps download bytes directly and open the native save destination;
  no external Supabase page is opened.
- Downloaded filenames start with `Zameel_`. PDF pages also receive the Zameel
  mark after the Edge Function is deployed. Word and PowerPoint remain in their
  original formats and receive the branded filename without modifying content.
