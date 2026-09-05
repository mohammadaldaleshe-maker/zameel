# Zameel v1.3.7 setup notes

## Supabase
Run `supabase/migrations/011_graduation_book.sql` in the Supabase SQL editor.

## Jobs provider
The jobs Edge Function uses Jooble. Configure `JOOBLE_API_KEY` as an Edge Function secret. Optionally configure `JOOBLE_API_URL`. When not configured, the app keeps the existing demo jobs visible instead of hiding them.

## Graduation Book
The book supports owner pages, touch handwriting, draggable/resizable/rotatable images, page deletion except page 1, invitation links, visibility/write settings, and print-ready PDF export.

## Demo content
Existing demo/experimental content is intentionally preserved. The feed also keeps real user posts and falls back to remaining posts when any balancing category runs out.


## v1.3.7 update notes
- Demo users/posts are intentionally local-only and remain visible alongside real Supabase posts.
- Apply `011_graduation_book.sql` before testing the Graduation Book.
- Jobs use the Supabase `jobs-search` function first and fall back to Arbeitnow's public API when no Jooble key is configured.
