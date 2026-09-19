# Zameel 070 — Unified publishing menu

This full source package builds on Zameel 069 and keeps its real mixed-media
selection and Android chat-bubble repairs.

## Home composer changes

- Tapping **Share something with your colleagues** now opens one focused menu.
- The menu contains: post, photo, video, and clip.
- The separate photo and video shortcuts were removed from the home feed.
- The books shortcut remains visible below the composer.
- The menu follows the Zameel blue/purple visual identity and supports Arabic
  and English layout directions.

## Included from 069

- Mixed image/video selection uses Android's native multi-select picker.
- A single post can contain text plus multiple images and videos.
- Android conversation notifications use versioned bubble channels and request
  automatic bubble expansion when the device permits it.

## Required verification

The redundant `dart:typed_data` import reported by `flutter analyze` was
removed from `post_publish_service.dart` in this fixed package.

Run from this directory:

```powershell
flutter pub get
dart format lib
flutter analyze
flutter test
```

Deploy the updated push function if Zameel 069 has not already been deployed:

```powershell
npx supabase@latest functions deploy send-push-notifications --project-ref jwuqyykjmltroneqtjoc
```
