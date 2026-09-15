# Zameel – first functional repair pass

This build targets explicit non-functional/dead UI handlers found in the uploaded project.

Fixed:
- Profile > Edit Info now opens the real ProfileScreen editor.
- Profile > My Books now opens BooksScreen.
- Friends search button now performs a local search across friends, requests and suggestions.
- Books chat button now opens a contact/message dialog instead of doing nothing.
- Group details chat button now opens the chat screen.
- Private Groups > Add now creates a new local private group.
- Chat search now searches conversations.
- Chat > New Chat now opens a conversation selector.
- Anonymous Chat search/new-chat buttons now work.
- Campus search now searches buildings and opens building details.
- Campus nearby-company cards now open details.
- Business company cards now open details.
- Business product cards now open details and allow an inquiry action.
- Story video creation now selects a video from the gallery and displays it with playback controls.
- Post sharing now copies the post text to the clipboard.
- Video post saving now toggles the saved state.
- Video post sharing now copies its URL (when available) or post text.

Important:
- This pass is intentionally conservative and keeps the existing main.dart architecture and working features.
- The project currently contains several demo/local data structures. These repairs make the UI interactions functional locally, but they do not turn demo data into a production realtime backend.
- I could not run Flutter/analyze in this environment because the Flutter SDK is not installed here. The source was checked for balanced delimiters and the edited files were reviewed statically.
- Before replacing the working project, keep the original ZIP/Git commit as rollback.

## Release-hardening additions
- Android package identity changed from the template `com.example.my_app` to `com.zameel.app`.
- Android compile/target SDK set to API 36 to meet the Google Play requirement effective August 31, 2026.
- Release builds support real upload-key signing through `android/key.properties` and R8 shrinking.
- Removed machine-specific generated Flutter/Android paths from the distributable project.
- Added Supabase core schema migration, RLS policies, storage buckets and an account-deletion RPC.
- Added runtime Supabase configuration through `--dart-define`.
- Added release checklist, architecture roadmap, privacy-policy template and Windows release-build script.
