# Zameel v1.3.8 - Search and Friendship Repair

- Fixed duplicate pending colleague-request inserts in Profile and Friends screens.
- Existing pending/accepted requests are detected before insert.
- PostgreSQL 23505 on the pending-request unique constraint is handled as a normal already-pending state.
- Profile shows an explicit disabled state when there is an incoming colleague request.
- Search now queries real users from Supabase while preserving demo users.
- Real user search matches name, username, university, college and department.
- Tapping a real user result opens their ProfileScreen.
- Search keeps demo results available when the network is unavailable.
