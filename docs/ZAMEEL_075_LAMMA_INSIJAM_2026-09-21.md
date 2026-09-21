# Zameel 075 — Lamma + private Insijam MVP

## What was added

- `Lamma`: university-only, time-limited small social gatherings with 3–8 seats.
- `Insijam`: adults-only, explicit opt-in individual discovery for friendship or a serious connection.
- Mutual interest is required before chat is offered.
- Existing Zameel direct chat is reused after a match.
- A user can pause Insijam immediately.

## Privacy contract

- Insijam is disabled by default.
- No Insijam state or marker is added to public profiles, search, friends, posts, stories, or Lamma.
- The underlying discovery profile is readable only by its owner.
- Birth date, preferences, likes and passes are never returned directly to another client.
- Candidate cards are returned only by a narrow RPC to another authenticated adult who enabled Insijam.
- A one-sided like remains invisible; only a mutual match is visible to its two members.
- Lamma participation and Insijam participation are separate.
- Exact location and phone number are not collected or returned by this feature.

## Required database step

Run `supabase/migrations/075_lamma_social_discovery.sql` in Supabase SQL Editor before opening the feature in the app.

## Phone test checklist

1. Confirm Lamma opens from the drawer and optional floating shortcut.
2. Create a Lamma and join it from a second university account.
3. Confirm a user who did not enable Insijam cannot query discovery profiles.
4. Enable Insijam on two adult test accounts in the same university.
5. Like only from account A; confirm account B receives no disclosure.
6. Like from account B; confirm the mutual-match dialog appears and chat opens.
7. Pause Insijam; confirm the card disappears from new candidate results.
8. Confirm neither public profile shows an Insijam badge or enabled state.

