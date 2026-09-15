# Zameel Push Runtime/Build Fix – 2026-09-06

- Made FirebaseMessaging initialization lazy so the core app can still start if Firebase config is missing or invalid.
- Prevented duplicate eager FirebaseMessaging.instance creation before Firebase.initializeApp().
- Codemagic now fails early if GOOGLE_SERVICES_JSON_BASE64 is missing or decodes to an empty google-services.json.
- Bumped app build number to 1.3.8+26.

The Firebase service-account secret for the Supabase Edge Function remains server-side only.
