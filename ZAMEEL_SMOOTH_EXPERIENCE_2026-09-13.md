# Zameel smooth experience update

Run `supabase/migrations/042_smooth_social_media_profile_calls.sql` after migration 041.

The update includes:

- non-blocking and cached colleague suggestions;
- reduced refresh pressure and bounded feed/social queries;
- camera publishing for posts, stories, and clips with a 45-second video cap;
- privacy selection after capture;
- direct registered-contact voice/video call flow;
- direct registered-university campus entry with nearby services and leisure;
- searchable university world without user-facing island terminology;
- editable 160-character bio;
- one profile settings control over the cover;
- account deletion moved from the drawer to account settings;
- create-post placement between stories and clips.

For incoming calls while the app is backgrounded or closed, keep Firebase configured in
Codemagic and deploy the existing notification delivery function/webhook for the project.
