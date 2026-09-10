# Graduation Book image upload fix — 2026-09-05

- Fixed image upload flow on the left/photo page.
- Added safe image extension/content-type handling.
- Added storage error handling with actionable Supabase migration path.
- Added `supabase/migrations/015_graduation_book_storage.sql`.
- Added `supabase/manual/015_graduation_book_storage.sql` for one-time application in Supabase SQL Editor.
- Existing book pages, text, drawings, push notifications, and other features are preserved.
