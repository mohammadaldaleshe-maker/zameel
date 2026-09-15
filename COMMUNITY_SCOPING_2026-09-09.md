# Zameel Community Scoping — 2026-09-09

## Release rule

Zameel community is separated into three chat scopes:

- **General**: all authenticated Zameel students across all universities.
- **My College**: users whose university and college match the current user's university and college.
- **My Major**: users whose university, college, and department/major all match the current user's academic profile.

The restrictions are enforced in Supabase Row Level Security, not only in Flutter UI.

## Academic library

Study files are scoped to the uploader's university + college. A student can only list/open files belonging to the same university and college. Uploads inherit the authenticated user's university, college, and department from `public.users`.

## Required profile data

For college and major community access, the profile should contain:

- university
- college
- department (major)

If these values are missing, the corresponding community is disabled and study-file uploads are rejected until the profile is completed.
