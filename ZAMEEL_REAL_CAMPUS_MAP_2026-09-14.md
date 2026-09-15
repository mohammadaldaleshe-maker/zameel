# Zameel real campus map

Apply `supabase/migrations/043_verified_campus_places_admin.sql` after migration 042.

- Mapbox remains removed.
- The map geometry and buildings come from OpenStreetMap tiles.
- There are no invented campus places in Dart code.
- Only approved places stored in Supabase appear as Zameel destinations.
- Owners, admins, and `campus_manager` staff can open the place manager, tap an exact map point, add a destination, and approve/hide it.
- Company places remain pending until management approval.
- The user marker is a human character with gender-based appearance and walking animation.
- The 3 km ring is used only to validate external services, not to distort the internal campus scale.

Before a public launch, configure a production OSM-compatible tile provider or self-hosted tiles; the public OpenStreetMap tile endpoint is appropriate for development and light testing, not uncontrolled high-volume production traffic.
