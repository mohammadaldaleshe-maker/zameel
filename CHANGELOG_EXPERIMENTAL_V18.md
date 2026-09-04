# Zameel experimental v1.3.2+18

Implemented:
- Fixed Clip upload flow to preserve the selected video, upload with media content type, create the clip row, refresh remote clips, and surface the real backend error instead of silently swallowing it.
- Stories now keep previous stories when a new story is added.
- Stories viewer groups stories by the same owner and supports moving between that owner's stories.
- Replaced the Campus fake map with an interactive OpenStreetMap-based map using Flutter Map.
- Added public-post "share to my profile" behavior from the feed; sharing creates a new post on the current user's profile while retaining the original media.
- Renamed Arabic Meet drawer label to `اجتمع بالزملاء`.
- Replaced the Daily Hub circular icon beside `يومك في زميل` with the current user's profile image when available.
- Added `006_demo_data.sql`: 30 demo accounts, 450 varied posts, stories, clips, likes, comments and follows.
