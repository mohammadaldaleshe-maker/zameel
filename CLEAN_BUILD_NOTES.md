# Zameel clean build package

Prepared from the supplied Zameel_v2.0.0_COLOR_REFRESH_V3_TEAL_44A2A6 project.

Changes in this clean package:
- Preserved the complete Flutter source and platform folders.
- Preserved the existing Android application id: com.zameel.app.
- Preserved the existing Supabase configuration and database migrations.
- Updated the Codemagic test workflow version variable from 1.3.8 to 2.0.0.
- Made Firebase configuration optional for the debug/test APK workflow. The release/internal workflow still requires GOOGLE_SERVICES_JSON_BASE64.
- No Git history is included in this ZIP, so it can be initialized as a fresh repository.

Important:
- This environment does not contain the Flutter SDK, so an actual `flutter analyze` / Android build could not be executed here.
- The supplied project itself contains a previous repair report stating that static source validation was performed, but an actual Flutter build still needs to be run in CodeMagic or on a machine with Flutter.
- The previous CodeMagic `ce6e4bb` checkout failure is a repository/build-cache issue, not a source-code reference; this package contains no reference to that commit.
