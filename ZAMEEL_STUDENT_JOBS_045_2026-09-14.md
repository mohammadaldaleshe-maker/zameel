# Zameel Student Jobs 045

This update converts the existing Jobs drawer item into a live student
opportunities experience.

## Included

- Automatic refresh when the Jobs screen opens.
- Live opportunities from Arbeitnow and Remotive.
- First-class opportunities posted by approved Zameel partners.
- Search and filters for jobs and internships.
- Save/unsave opportunities per user.
- Application-opening history per user.
- Official LinkedIn Jobs search link using the current search phrase and Jordan
  as the location.
- No LinkedIn scraping and no fake/generated job advertisements.

## Supabase deployment

1. Run `supabase/migrations/045_student_jobs_linkedin.sql` in the Supabase SQL
   editor after migration 044.
2. Deploy the updated function:

   `supabase functions deploy jobs-search`

The function uses the built-in `SUPABASE_URL` and
`SUPABASE_SERVICE_ROLE_KEY` secrets to include active opportunities published
by Zameel partners. The mobile client never receives the service-role key.

## Optional provider expansion

Additional licensed providers can be added later inside `jobs-search`. LinkedIn
job data must only be imported after LinkedIn grants the application the
appropriate partner/API access. Until then, Zameel opens LinkedIn's official
Jobs search page rather than scraping it.
