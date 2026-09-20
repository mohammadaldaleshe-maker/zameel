# Zameel v2 — Master Product & Engineering Specification

## 1. Product vision
Zameel v2 is the student's operating system: academic identity, scoped community,
study resources, AI study assistance, classmates, groups, campus life, and future opportunities.

The app should feel useful every day rather than acting as a collection of disconnected screens.

## 2. Primary navigation
Keep the bottom navigation to five destinations:
1. Home
2. Community
3. Study
4. Messages
5. Profile

Secondary modules are opened from Home or section hubs: AI, Calendar, Campus, Jobs,
Groups, Notifications, Search, Saved.

## 3. Screen map
### Onboarding & account
- Splash
- Welcome
- 3-step onboarding
- Registration
- Email/phone verification
- University
- College
- Major
- Academic year
- Profile photo

### Home
- Zameel Daily
- personalized feed
- upcoming academic items
- new college files
- classmates
- opportunities
- notifications

### Community
- Global
- My University
- My College
- My Major
- My Groups
- Community detail
- Create post
- Post detail
- Comments
- Polls
- Events
- Announcements

### Study
- Study hub
- My Library
- College Library
- Course page
- Material detail
- My summaries
- AI Study
- Quiz Me
- Flashcards
- Study Groups

### People & communication
- Classmates
- Student profile
- Reputation
- Private messages
- Community realtime chat
- Study group detail

### Campus
- Campus hub
- Places
- Events
- Clubs
- Services
- Study spaces
- Live map where appropriate

### Future
- Jobs
- Internships
- Opportunities
- Career profile

### Utility
- Search
- Saved
- Notifications
- Calendar
- Settings
- Privacy & security

## 4. Academic access model
Global: every authenticated Zameel student.
University: same university.
College: same university + same college.
Major: same university + same college + same major/department.
Study files: same university + same college.
Private messages: sender/recipient only.

The Flutter UI is never the security boundary. Supabase/Postgres RLS must enforce the same rules.

## 5. Core database direction
Move gradually from free-text academic fields to canonical IDs:
- university_id
- college_id
- major_id
- academic_year_id

Keep display names cached or joined from canonical tables.

## 6. Community model
A community is more than chat. It supports:
- posts
- discussions
- questions
- files
- announcements
- polls
- events
- members
- moderation
- saves
- reactions

Feed priority:
1. Major
2. College
3. University
4. Global

## 7. Study model
College-scoped library with:
- lectures
- summaries
- past exams/questions
- books
- course materials
- ratings
- downloads/usage statistics
- course and semester metadata

AI Study actions:
- summarize
- explain
- generate questions
- quiz
- flashcards
- translate
- identify weak topics

## 8. Retention loop
Open → Zameel Daily → see something relevant → interact → receive useful answer/file/AI help
→ save/share → notification → return tomorrow.

## 9. Reputation
Reward useful contributions, not raw posting volume:
- helpful answer
- useful summary
- approved study material
- group contribution
- community moderation

Badges:
- مساعد التخصص
- مساهم متميز
- خبير المادة
- صديق الطلاب

## 10. Engineering architecture
The current project contains a large legacy HomeFeedScreen. V2 should migrate gradually toward
feature-based architecture instead of a risky big-bang rewrite:

lib/
  core/
  features/
    auth/
    home/
    community/
    study/
    ai/
    messaging/
    people/
    campus/
    opportunities/
    profile/

Each feature should separate UI, state/view-model, and data/repository code.

Flutter's current architecture guidance emphasizes maintainability, scalability and testability;
use those principles as the refactor target.

## 11. Security checklist
- RLS enabled on every exposed table
- explicit grants for anon/authenticated
- no service-role/secret key in Flutter
- storage policies match database scope
- private messages never exposed through community queries
- update policies include WITH CHECK
- realtime channels follow authorization rules
- rate limits for posting/comments/uploads where appropriate
- moderation and abuse reporting
- audit important admin actions
- RLS tests for allow + deny cases

## 12. Current migration status
Migration 019 establishes the present community/study-file scope using the existing string academic
fields. It should be applied and tested in Supabase before depending on the feature in production.

Migration 020 is a non-destructive target schema plan. It is documentation until reconciled with the
live database; do not execute it as-is.

## 13. Release phases
### V2.0 Foundation
Academic identity, scoped access, security, navigation, architecture.

### V2.1 Daily
Zameel Daily, smart feed, notifications, home personalization.

### V2.2 Study
College library, course materials, AI Study, Quiz Me, flashcards.

### V2.3 People
Classmates, study groups, reputation, contribution system.

### V2.4 Campus
Events, places, services, clubs, campus discovery.

### V2.5 Future
Jobs, internships, career profile, opportunity matching.

## 14. Acceptance criteria
- A medical student cannot see political-science college materials.
- A student cannot read another university's college-scoped materials.
- A major community cannot be read by another major in the same college.
- Global community is visible to all authenticated students.
- A user cannot insert a community message as another user.
- A user cannot move an existing study file into another academic scope.
- Private messages remain private.
- Demo/synthetic post IDs never reach DB-backed comment/like/save operations.
- Empty/incomplete academic identity disables scoped academic destinations.
- Production build has no debug secrets.

## 15. Existing project preservation
This V2 package keeps the stable V1.3.8 functionality and adds a central Zameel v2 hub so the
migration can be tested incrementally. Existing modules such as Books, Chat, Friends, Campus,
Jobs, Calendar, Groups, AI, Search, Notifications and Profile are reused rather than duplicated.
