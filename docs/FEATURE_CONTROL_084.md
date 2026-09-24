# Feature control integration

Install together with Zameel Admin's SQL migration `084_feature_visibility_control.sql` and redeployed `admin-console` Edge Function. The app reads global feature modes using the authenticated RPC. Home drawer, floating shortcuts, key home cards and feed publishing entry respond to admin changes. The state refreshes when home opens, app resumes and before shortcut entry. Existing installations need this updated APK.

This is a client navigation control, not a security boundary. Other routes such as notifications/deep links, screens already open, and direct Supabase writes need server-side guards for comprehensive suspension. Flutter analyze and device validation remain necessary because the Flutter SDK is unavailable in this workspace.
