# SDAL iOS App — Full Implementation Prompt

You are building a production-grade native iOS app in **Swift 6 / SwiftUI** (iOS 17+, Xcode 16+) for **SDAL** — a social networking platform for alumni communities. The app must implement **every** server endpoint, match the web client's UX quality, and include a full admin panel.

---

## 1. Project Foundation

### Tech Stack
- **Language**: Swift 6, strict concurrency
- **UI**: SwiftUI with NavigationStack-based routing
- **Networking**: URLSession async/await, cookie-based session auth
- **WebSocket**: URLSessionWebSocketTask for real-time chat/messenger
- **Images**: AsyncImage + cached thumbnails, WebP support via ImageIO
- **State**: @Observable pattern, environment-injected singletons
- **Push**: APNs via UserNotifications framework
- **Persistence**: UserDefaults for prefs, Keychain for credentials
- **Localization**: TR (default), EN, DE, FR — runtime switchable
- **Theming**: Light/dark/auto with design tokens (see §2)
- **Min target**: iOS 17.0

### Project Structure
```
SDALNative/
├── App/                    # SDALNativeApp, RootView, AppDelegate
├── Core/                   # APIClient, AppState, AppConfig, AppRouting, PushNotificationService, LocalizationManager
├── Models/                 # Codable DTOs per domain (Auth, Feed, Story, Member, Message, Admin, Group, Event, Notification, Network, Opportunity, Album, Game)
├── Features/
│   ├── Auth/               # Login, Register, Activate, PasswordReset
│   ├── Feed/               # FeedView, PostCard, PostComposer, CommentsSheet
│   ├── Stories/            # StoryBar, StoryViewer (Instagram-like grouped viewer)
│   ├── Explore/            # ExploreView, SuggestionsView, MemberDetail
│   ├── Groups/             # GroupsList, GroupDetail, GroupSettings
│   ├── Messages/           # Inbox/Outbox, MessageDetail, Compose
│   ├── Messenger/          # Real-time DM threads (WebSocket)
│   ├── Chat/               # Global live chat (WebSocket)
│   ├── Notifications/      # NotificationsList, PreferencesSheet
│   ├── Events/             # EventsList, EventCreate, RSVP
│   ├── Announcements/      # AnnouncementsList, Create
│   ├── Jobs/               # JobsList, Apply, ApplicationReview
│   ├── Network/            # ConnectionRequests, MentorshipRequests, TeacherNetwork, OpportunityInbox
│   ├── Albums/             # AlbumCategories, PhotoGrid, PhotoDetail, Upload
│   ├── Profile/            # ProfileView, EditProfile, PhotoUpload, VerificationRequest
│   ├── Games/              # GameCatalog, Snake, Tetris, 2048, Memory, Tap
│   ├── Admin/              # Full admin panel (see §6)
│   └── Help/               # HelpView
└── UI/                     # SDALTheme, GlassCard, AsyncAvatar, ScreenErrorView, design tokens
```

---

## 2. Design System

### Color Tokens (from `sdal.tokens.json`)

**Light mode:**
| Token | Hex |
|---|---|
| bg | #f3efe8 |
| bg-2 | #e9dfd2 |
| surface-main | #f6f1e9 |
| card | #fffdfa |
| card-alt | #fbf6ef |
| ink | #1c1c1c |
| muted | #6e6e6e |
| accent | #ff6b4a |
| accent-2 | #1b7f6b |
| line | #e5d9c7 |
| nav-bg | #111111 |
| nav-ink | #f5f5f5 |
| button-bg | #111111 |
| button-ink | #ffffff |
| success-ink | #1f7a37 |
| danger-ink | #a12a2a |
| error-ink | #b91c1c |

**Dark mode:**
| Token | Hex |
|---|---|
| bg | #0f141d |
| bg-2 | #0a0f17 |
| surface-main | #121a25 |
| card | #1a2331 |
| card-alt | #202b3a |
| ink | #e8edf7 |
| muted | #9ba7be |
| accent | #ff7f61 |
| accent-2 | #41a08d |
| line | #2b3345 |
| nav-bg | #090c12 |
| nav-ink | #dce6f8 |
| button-bg | #e8edf7 |
| button-ink | #0f1420 |

### Visual Language
- **Typography**: System font with clear heading/body hierarchy. Headings: semibold/bold, Body: regular
- **Cards**: Subtle rounded corners (12pt), light shadow, card background color
- **Surfaces**: Layered depth — bg → surface → card → card-alt
- **Chips/Badges**: Pill-shaped with accent-soft-bg, small font
- **Navigation**: Dark nav-bg top bar, tab bar at bottom with 5 tabs (Feed, Explore, Chat, Notifications, Profile)
- **Glassmorphism**: Use for overlays and story viewer
- **Animations**: Spring-based transitions, 0.3s default timing
- **Empty states**: Centered icon + message + action button pattern
- **Loading**: Skeleton shimmer views matching content layout

---

## 3. Authentication & Session

### Endpoints
```
POST /api/auth/login          { kadi: String, sifre: String } → { ok, user, role, admin, needsProfile }
POST /api/auth/logout         → 204
POST /api/register/preview    { kadi } → availability check
POST /api/register            { kadi, sifre, isim, soyisim, email, ... } → { ok }
GET  /api/activate?code=X     → activation result
POST /api/activation/resend   { email } → { ok }
POST /api/password-reset      { email } → { ok }
GET  /api/session             → current session user or 401
GET  /api/site-access         → site open/closed status
GET  /api/captcha             → captcha image
```

### OAuth
```
GET  /api/auth/oauth/providers                → available OAuth providers
GET  /api/auth/oauth/:provider/start          → redirect URL
GET  /api/auth/oauth/:provider/callback       → handle callback
POST /api/auth/oauth/mobile/exchange          → exchange code for session (mobile flow)
```

### Behavior
- Store session cookies from login response; attach to all subsequent requests
- On 401 responses, redirect to login
- `needsProfile: true` → force profile completion flow after login
- Role hierarchy: `user < mod < admin < root`
- Root login username is always `root`

---

## 4. Core Features — All Endpoints

### 4.1 Feed
```
GET  /api/new/feed?feedType=main|community&filter=latest|popular|following&limit=1-50&offset=N&cursor=N
POST /api/new/posts                   { content, group_id? }
POST /api/new/posts/upload            multipart: image file
PATCH /api/new/posts/:id              { content }
POST /api/new/posts/:id/edit          alias for PATCH
DELETE /api/new/posts/:id
POST /api/new/posts/:id/delete        alias for DELETE
POST /api/new/posts/:id/like          → { ok, liked }
GET  /api/new/posts/:id/comments?limit=1-100&beforeId=N
POST /api/new/posts/:id/comments      { comment }
POST /api/upload-image                multipart: general image upload
```

**UX Requirements:**
- Tabbed feed scopes: All / Following / Popular
- Community feed tab for graduation-year cohort posts
- Pull-to-refresh + infinite scroll with cursor pagination
- "New posts available" sticky banner
- Post composer with rich text + image upload
- Post cards: avatar, name, verified badge, timestamp, content, image (3 variants: thumb/feed/full), like count, comment count, like button with toggle animation
- Comment sheet as bottom sheet with lazy loading
- Swipe actions on own posts for edit/delete

### 4.2 Stories (Instagram-style)
```
GET  /api/new/stories                 → all active stories grouped by author
GET  /api/new/stories/mine            → current user's stories
GET  /api/new/stories/user/:id        → specific user's stories
POST /api/new/stories/upload          multipart: image + caption
PATCH /api/new/stories/:id            { caption }
POST /api/new/stories/:id/edit        alias
DELETE /api/new/stories/:id
POST /api/new/stories/:id/delete      alias
POST /api/new/stories/:id/remove      alias
POST /api/new/stories/:id/repost
POST /api/new/stories/:id/view        mark as viewed
```

**UX Requirements:**
- Horizontal scrollable story circles at top of feed
- Unviewed = colored ring, viewed = gray ring
- Group by author, sort unviewed-first then by latest
- Full-screen viewer: progress bars per story, auto-advance timer (5s), left/right tap zones, swipe between authors, vertical swipe to dismiss
- Caption overlay at bottom with author header
- Preload next story images
- Upload from story bar "+" button with camera/gallery picker

### 4.3 Explore & Member Discovery
```
GET  /api/members?search=X&sort=X&page=N
GET  /api/members/:id                 → full profile
GET  /api/members/latest              → recently joined
GET  /api/new/explore/suggestions?limit=N&offset=N  → AI-scored suggestions with reasons
POST /api/new/follow/:id             → toggle follow
GET  /api/new/follows                 → following list
GET  /api/new/online-members          → currently online
```

**UX Requirements:**
- Search bar with filters (graduation year, verified, online)
- Suggestion cards with score reasons and trust badges (verified_alumni, mentor, teacher_network)
- Follow/unfollow button with optimistic state
- Member detail: avatar, bio, graduation year, company, stories section, follow button, connection/mentorship request buttons
- Online presence indicator (green dot)

### 4.4 Networking Hub
```
POST /api/new/connections/request/:id       → send connection request
GET  /api/new/connections/requests          → pending requests
POST /api/new/connections/accept/:id
POST /api/new/connections/ignore/:id
POST /api/new/connections/cancel/:id
POST /api/new/mentorship/request/:id        { focus_area?, message? }
GET  /api/new/mentorship/requests
POST /api/new/mentorship/accept/:id
POST /api/new/mentorship/decline/:id
GET  /api/new/network/inbox                 → { connections, mentorship, teacherLinks }
GET  /api/new/network/hub                   → network overview
GET  /api/new/network/metrics               → network analytics
POST /api/new/network/inbox/teacher-links/read
POST /api/new/network/telemetry             → analytics event
```

**UX Requirements:**
- Network inbox with tabs: Connections / Mentorship / Teacher Links
- Incoming/outgoing request lists with accept/ignore/decline actions
- Request counts as badges
- Connection status states: pending, accepted, ignored
- Mentorship status states: requested, accepted, declined, cancelled

### 4.5 Opportunity Inbox
```
GET /api/new/opportunities?category=jobs|networking|updates&bucket=now|soon|later
```

**UX Requirements:**
- Priority-bucketed cards (Now / Soon / Later)
- Each card: title, summary, why_now explanation, action button
- Categories: jobs, networking, updates
- Pull-to-refresh

### 4.6 Teacher Network
```
GET  /api/new/teachers/network              → teacher directory
GET  /api/new/teachers/options              → relationship type options
POST /api/new/teachers/network/link/:teacherId  { relationship_type }
```

### 4.7 Global Chat (Real-time)
```
GET  /api/new/chat/messages?sinceId=N&beforeId=N&limit=1-200
POST /api/new/chat/send                     { message }
PATCH /api/new/chat/messages/:id            { message }
POST /api/new/chat/messages/:id/edit        alias
DELETE /api/new/chat/messages/:id
POST /api/new/chat/messages/:id/delete      alias
WebSocket: ws://HOST/ws/chat                → real-time message stream
```

**WebSocket Message Types:**
```json
{ "type": "chat:message", "id": N, "user_id": N, "message": "...", "created_at": "...", "user": {...} }
{ "type": "chat:updated", "id": N, "message": "..." }
{ "type": "chat:deleted", "id": N }
```

**UX Requirements:**
- Chat bubble UI (WhatsApp-style)
- Own messages right-aligned, others left-aligned
- Auto-scroll to bottom on new messages
- Long-press for edit/delete on own messages
- WebSocket reconnection with exponential backoff
- Show typing indicators if available
- Translate button per message

### 4.8 Direct Messaging (Mailbox)
```
GET  /api/messages?folder=inbox|outbox&page=N&search=X
GET  /api/messages/recipients              → searchable user list
GET  /api/messages/:id                     → message detail
POST /api/messages                         { to, subject, body }
DELETE /api/messages/:id
GET  /api/new/messages/unread              → unread count
```

### 4.9 SDAL Messenger (Real-time DM)
```
GET  /api/sdal-messenger/contacts
POST /api/sdal-messenger/threads
GET  /api/sdal-messenger/threads
GET  /api/sdal-messenger/threads/:id/messages
POST /api/sdal-messenger/threads/:id/messages    { body } (idempotency-key header)
POST /api/sdal-messenger/threads/:id/read
WebSocket: ws://HOST/ws/messenger                → real-time DM stream
```

**WebSocket Message Types:**
```json
{ "type": "messenger:hello", "userId": N }
{ "type": "messenger:new", "threadId": N, "message": {...} }
{ "type": "messenger:delivered", "threadId": N, "messageId": N }
{ "type": "messenger:read", "threadId": N, "userId": N }
```

### 4.10 Notifications
```
GET  /api/new/notifications?limit=N&offset=N&category=social|messaging|groups|events|networking|jobs|system
GET  /api/new/notifications/unread          → { count }
POST /api/new/notifications/read            → mark all read
POST /api/new/notifications/bulk-read       { ids: [N] }
POST /api/new/notifications/:id/read
POST /api/new/notifications/:id/open        → track open
POST /api/new/notifications/telemetry       → analytics
GET  /api/new/notifications/preferences     → toggle settings per category
PUT  /api/new/notifications/preferences     { social_enabled, messaging_enabled, ... }
```

**Notification Types & Categories:**
- **social**: like, comment, mention_post, mention_photo, photo_comment, follow
- **messaging**: mention_message
- **groups**: mention_group, group_join_request/accepted/rejected, group_invite/accepted/declined, group_role_changed
- **events**: mention_event, event_comment, event_invite, event_response, event_reminder, event_starts_soon
- **networking**: connection_request/accepted, mentorship_request/accepted, teacher_network_linked, teacher_link_review_*
- **jobs**: job_application, job_application_reviewed/accepted/rejected
- **system**: verification_approved/rejected, member_request_*, announcement_*

**UX Requirements:**
- Notification list with unread highlighting
- Category filter chips
- Deep-link routing from notification tap to relevant screen
- Badge count on tab bar
- Mark all read button
- Preferences screen with per-category toggles + quiet mode

### 4.11 Groups
```
GET  /api/new/groups                        → user's groups
POST /api/new/groups                        { name, description, visibility }
POST /api/new/groups/:id/join
GET  /api/new/groups/:id/requests
POST /api/new/groups/:id/requests/:requestId  { action: 'approve'|'reject' }
GET  /api/new/groups/:id/invitations
POST /api/new/groups/:id/invitations        { user_ids }
POST /api/new/groups/:id/invitations/respond  { action: 'accept'|'decline' }
POST /api/new/groups/:id/settings           { name, description, visibility }
POST /api/new/groups/:id/cover              multipart: cover image
POST /api/new/groups/:id/role               { userId, role }
GET  /api/new/groups/:id                    → group detail + timeline posts
POST /api/new/groups/:id/posts              { content }
POST /api/new/groups/:id/posts/upload       multipart: image
GET  /api/new/groups/:id/events
POST /api/new/groups/:id/events             { title, description, ... }
DELETE /api/new/groups/:id/events/:eventId
GET  /api/new/groups/:id/announcements
POST /api/new/groups/:id/announcements      { title, content }
DELETE /api/new/groups/:id/announcements/:announcementId
```

### 4.12 Events & Announcements
```
GET  /api/new/events?status=upcoming|past
POST /api/new/events                        { title, description, location, starts_at, ends_at }
POST /api/new/events/upload                 multipart: event image
POST /api/new/events/:id/approve            (admin)
DELETE /api/new/events/:id                  (admin)
POST /api/new/events/:id/respond            { response: 'attend'|'decline' }
POST /api/new/events/:id/response-visibility  { showCounts, showAttendeeNames, showDeclinerNames }
GET  /api/new/events/:id/comments
POST /api/new/events/:id/comments           { body }
POST /api/new/events/:id/notify             → send reminder
GET  /api/new/announcements
POST /api/new/announcements                 { title, content }
POST /api/new/announcements/upload          multipart: image
POST /api/new/announcements/:id/approve     (admin)
DELETE /api/new/announcements/:id           (admin)
```

### 4.13 Jobs
```
GET  /api/new/jobs
POST /api/new/jobs                          { title, description, company, ... }
DELETE /api/new/jobs/:id
POST /api/new/jobs/:id/apply                { message }
GET  /api/new/jobs/:id/applications
POST /api/new/jobs/:jobId/applications/:applicationId/review  { status: 'accepted'|'rejected' }
```

### 4.14 Albums & Photos
```
GET  /api/albums?category=N&page=N
GET  /api/album/categories/active
GET  /api/album/latest
GET  /api/albums/:id
GET  /api/photos/:id
GET  /api/photos/:id/comments
POST /api/photos/:id/comments               { comment }
POST /api/album/upload                      multipart: image + category_id
```

### 4.15 Profile
```
GET  /api/profile                           → current user full profile
PUT  /api/profile                           { isim, soyisim, email, company, title, bio, ... }
POST /api/profile/password                  { current, new }
POST /api/profile/photo                     multipart: photo
POST /api/profile/email-change/request      { newEmail }
GET  /api/profile/email-change/verify?code=X
POST /api/new/verified/request              → request verification
GET  /api/new/request-categories            → support request types
GET  /api/new/requests/my                   → my support requests
POST /api/new/requests                      { category_id, message }
POST /api/new/requests/upload               multipart: attachment
```

### 4.16 Translation
```
POST /api/new/translate                     { text, targetLang }
```

### 4.17 Misc
```
GET  /api/menu                              → navigation menu items
GET  /api/sidebar                           → sidebar data
GET  /api/panolar                           → bulletin boards
POST /api/panolar                           { content }
DELETE /api/panolar/:id
GET  /api/quick-access                      → user's quick access shortcuts
POST /api/quick-access/add                  { item }
POST /api/quick-access/remove              { item }
POST /api/tournament/register              { team data }
GET  /api/health                           → server health check
```

### 4.18 Games
```
GET  /api/games/snake/leaderboard
POST /api/games/snake/score                 { score }
GET  /api/games/tetris/leaderboard
POST /api/games/tetris/score                { score }
GET  /api/games/arcade/:game/leaderboard
POST /api/games/arcade/:game/score          { score }
```

Games to implement: Snake, Tetris, 2048, Memory, Tap Speed. Each with native SwiftUI game board, score tracking, and leaderboard.

---

## 5. Real-time Architecture

### WebSocket Manager
Create a `WebSocketManager` actor that:
1. Maintains persistent connections to `/ws/chat` and `/ws/messenger`
2. Authenticates via session cookie on connection
3. Parses incoming JSON frames and dispatches to appropriate feature stores
4. Handles reconnection with exponential backoff (1s, 2s, 4s, 8s, max 30s)
5. Sends heartbeat pings every 30s
6. Publishes connection state (connected/connecting/disconnected) to UI

### Push Notifications
- Register for APNs on login
- Deep-link routing from push payload to relevant screen (message, chat, notification, explore, profile, group, event)
- Badge management synced with unread notification count

---

## 6. Admin Panel (Complete)

The admin panel is accessible to users with `admin` or `root` role. Implement as a dedicated navigation section with tabs.

### 6.1 Admin Auth & Session
```
GET  /api/admin/session                     → admin session check
POST /api/admin/login                       { password } → admin-level auth
POST /api/admin/logout
GET  /api/admin/root-status                 → root user status
```

### 6.2 Dashboard & Analytics
```
GET  /api/new/admin/stats                   → KPI summary (users, posts, engagement)
GET  /api/new/admin/live                    → live activity feed
GET  /api/new/admin/engagement-scores       → per-user engagement scores
POST /api/new/admin/engagement-scores/recalculate
```

**UX**: KPI cards grid (total users, active today, posts today, engagement score), live activity timeline, engagement leaderboard table.

### 6.3 User Management
```
GET  /api/admin/users/lists?filter=all|active|banned|unverified&page=N
GET  /api/admin/users/search?q=X
GET  /api/admin/users/:id                   → full user detail
PUT  /api/admin/users/:id                   { role, banned, verified, ... }
DELETE /api/admin/users/:id                 → delete user
PUT  /api/new/admin/users/:id/graduation-year  { year }
POST /admin/users/:id/role                  { role } → change role (root only for admin promotion)
POST /admin/moderators/:id/scopes           { scopes } → assign mod scopes
GET  /admin/moderators                      → list all moderators
```

### 6.4 Moderation Permissions
```
GET  /api/admin/moderation/permissions/catalog   → all available permissions
GET  /api/admin/moderation/permissions/:userId   → user's permissions
PUT  /api/admin/moderation/permissions/:userId   { permissions: [...] }
GET  /api/admin/moderation/my-permissions        → current user's mod permissions
```

**Permission Resources:** requests.view, requests.moderate, posts.view, posts.delete, stories.view, stories.delete, chat.view, chat.delete, messages.view, messages.delete, groups.view, groups.delete

### 6.5 Content Moderation
```
GET  /api/new/admin/posts?page=N                → all posts
DELETE /api/new/admin/posts/:id
GET  /api/new/admin/stories                     → all stories
DELETE /api/new/admin/stories/:id
GET  /api/new/admin/chat/messages?page=N        → all chat messages
DELETE /api/new/admin/chat/messages/:id
GET  /api/new/admin/messages?page=N             → all DMs
DELETE /api/new/admin/messages/:id
GET  /api/new/admin/comments?page=N             → all comments
DELETE /api/new/admin/comments/:id
GET  /api/new/admin/groups                      → all groups
DELETE /api/new/admin/groups/:id
```

### 6.6 Verification & Request Moderation
```
GET  /api/new/admin/verification-requests       → pending verifications
POST /api/new/admin/verification-requests/:id   { action: 'approve'|'reject' }
POST /api/new/admin/verify                      { userId, verified: bool }
GET  /api/new/admin/requests/notifications      → pending request count
GET  /api/new/admin/requests?status=pending|reviewed
POST /api/new/admin/requests/:id/review         { action, response }
GET  /api/new/admin/teacher-network/links       → teacher link reviews
POST /api/new/admin/teacher-network/links/:id/review  { action }
```

### 6.7 Filters (Blocked Terms)
```
GET  /api/new/admin/filters
POST /api/new/admin/filters                     { term, action }
PUT  /api/new/admin/filters/:id                 { term, action }
DELETE /api/new/admin/filters/:id
```

### 6.8 Follows Inspector
```
GET /api/new/admin/follows/:userId              → user's follow graph
```

### 6.9 A/B Experiments
```
GET  /api/new/admin/engagement-ab               → engagement experiment config
PUT  /api/new/admin/engagement-ab/:variant      → update variant
POST /api/new/admin/engagement-ab/rebalance
GET  /api/new/admin/network-suggestion-ab       → network suggestion experiment
PUT  /api/new/admin/network-suggestion-ab/:variant
POST /api/new/admin/network-suggestion-ab/apply
POST /api/new/admin/network-suggestion-ab/rollback/:id
POST /api/new/admin/network-suggestion-ab/rebalance
```

### 6.10 Notification Admin
```
GET  /api/new/admin/notifications/governance    → notification rules config
GET  /api/new/admin/notifications/experiments   → notification experiment settings
PUT  /api/new/admin/notifications/experiments/:key  { value }
GET  /api/new/admin/notifications/ops           → notification operations stats
```

### 6.11 Network Analytics (Admin)
```
GET /api/new/admin/network/analytics            → network-wide analytics
```

### 6.12 Site Controls & Media Settings
```
GET  /api/admin/site-controls                   → site-wide toggles
PUT  /api/admin/site-controls                   { modules, settings }
GET  /api/admin/media-settings                  → media storage config
PUT  /api/admin/media-settings                  { provider, credentials }
POST /api/admin/media-settings/test             → test media config
```

### 6.13 Security Status
```
GET /api/new/admin/security/status              → security overview
```

### 6.14 Languages (i18n Admin)
```
GET  /api/admin/languages                       → all languages
POST /api/admin/languages                       { code, name }
PUT  /api/admin/languages/:code                 { name, active }
DELETE /api/admin/languages/:code
GET  /api/admin/language-strings?lang=X         → all strings for language
GET  /api/admin/language-strings/keys           → all translation keys
PUT  /api/admin/language-strings/:lang/:key     { value }
POST /api/admin/language-strings/bulk           { entries: [...] }
POST /api/admin/language-strings/fill-missing   { targetLang, sourceLang }
DELETE /api/admin/language-strings/:lang/:key
DELETE /api/admin/language-strings/key/:key
GET  /api/admin/language-config
PUT  /api/admin/language-config                 { defaultLang, fallbackLang }
```

### 6.15 CMS Pages
```
GET  /api/admin/pages
POST /api/admin/pages                           { title, slug, content }
PUT  /api/admin/pages/:id
DELETE /api/admin/pages/:id
```

### 6.16 Audit Logs
```
GET /api/admin/logs?page=N&type=X               → admin action audit trail
```

### 6.17 Email System
```
POST /api/admin/email/send                      { to, subject, body, templateId? }
GET  /api/admin/email/categories
POST /api/admin/email/categories                { name }
PUT  /api/admin/email/categories/:id
DELETE /api/admin/email/categories/:id
GET  /api/admin/email/templates
POST /api/admin/email/templates                 { name, subject, body, categoryId }
PUT  /api/admin/email/templates/:id
DELETE /api/admin/email/templates/:id
POST /api/admin/email/bulk                      { templateId, recipients, ... }
```

### 6.18 Album Admin
```
GET  /api/admin/album/categories
POST /api/admin/album/categories                { name }
PUT  /api/admin/album/categories/:id
DELETE /api/admin/album/categories/:id
GET  /api/admin/album/photos?category=N&page=N
POST /api/admin/album/photos/bulk               multipart: multiple photos
PUT  /api/admin/album/photos/:id                { caption, category_id }
DELETE /api/admin/album/photos/:id
GET  /api/admin/album/photos/:id/comments
DELETE /api/admin/album/photos/:id/comments/:commentId
```

### 6.19 Tournament Admin
```
GET  /api/admin/tournament                      → all teams
DELETE /api/admin/tournament/:id
```

### 6.20 Database Tools
```
GET  /api/new/admin/db/backups                  → list backups
POST /api/new/admin/db/backups                  → create backup
GET  /api/new/admin/db/backups/:name/download   → download backup file
POST /api/new/admin/db/restore                  multipart: backup file
GET  /api/new/admin/db/driver/status            → current DB driver info
POST /api/new/admin/db/driver/switch            { driver }
POST /api/new/admin/db/driver/copy-data         → migrate data between drivers
```

### Admin UX Requirements
- Tab-based navigation: Dashboard | Users | Moderation | Content | Settings | Tools
- Dashboard: KPI cards + live activity timeline
- User management: searchable list, detail sheet with role/ban/verify actions
- Moderation queues: posts, stories, chat, messages, comments — each with delete action
- Verification queue with approve/reject actions
- Settings: site controls toggles, media config, language management
- Tools: DB backup/restore, audit logs, email system, experiments

---

## 7. Data Models (Codable)

Use lossy decoding throughout — make most fields optional to handle server schema drift gracefully.

```swift
struct User: Codable, Identifiable {
    let id: Int
    var username: String?           // kadi
    var firstName: String?          // isim
    var lastName: String?           // soyisim
    var email: String?
    var avatarUrl: String?          // resim
    var role: String?               // user|mod|admin|root
    var verified: Bool?
    var banned: Bool?               // yasak
    var active: Bool?               // aktiv
    var graduationYear: Int?        // mezuniyetyili
    var company: String?
    var jobTitle: String?
    var bio: String?
    var online: Bool?
    var lastSeen: String?
}

struct Post: Codable, Identifiable {
    let id: Int
    var authorId: Int?
    var content: String?
    var imageUrl: String?
    var groupId: Int?
    var createdAt: String?
    var author: User?
    var likeCount: Int?
    var commentCount: Int?
    var likedByViewer: Bool?
    var variants: ImageVariants?
}

struct ImageVariants: Codable {
    var thumb: String?
    var feed: String?
    var full: String?
}

struct Comment: Codable, Identifiable { let id: Int; var postId: Int?; var authorId: Int?; var body: String?; var createdAt: String?; var author: User? }
struct Story: Codable, Identifiable { let id: Int; var userId: Int?; var imageUrl: String?; var caption: String?; var createdAt: String?; var expiresAt: String?; var author: User?; var viewed: Bool?; var variants: ImageVariants? }
struct Message: Codable, Identifiable { let id: Int; var fromId: Int?; var toId: Int?; var subject: String?; var body: String?; var createdAt: String?; var read: Bool?; var sender: User?; var recipient: User? }
struct ChatMessage: Codable, Identifiable { let id: Int; var userId: Int?; var message: String?; var createdAt: String?; var user: User? }
struct Notification: Codable, Identifiable { let id: Int; var type: String?; var message: String?; var sourceUserId: Int?; var entityId: Int?; var readAt: String?; var createdAt: String?; var sourceUser: User? }
struct Group: Codable, Identifiable { let id: Int; var name: String?; var description: String?; var ownerId: Int?; var visibility: String?; var memberCount: Int?; var coverUrl: String?; var isMember: Bool? }
struct Event: Codable, Identifiable { let id: Int; var title: String?; var description: String?; var location: String?; var startsAt: String?; var endsAt: String?; var createdBy: Int?; var approved: Bool?; var myResponse: String?; var attendCount: Int?; var declineCount: Int? }
struct Job: Codable, Identifiable { let id: Int; var title: String?; var description: String?; var company: String?; var posterId: Int?; var createdAt: String? }
struct ConnectionRequest: Codable, Identifiable { let id: Int; var senderId: Int?; var receiverId: Int?; var status: String?; var createdAt: String?; var user: User? }
struct MentorshipRequest: Codable, Identifiable { let id: Int; var requesterId: Int?; var mentorId: Int?; var status: String?; var focusArea: String?; var message: String?; var user: User? }
struct OpportunityItem: Codable, Identifiable { let id: String; var kind: String?; var source: String?; var category: String?; var score: Double?; var priorityBucket: String?; var title: String?; var summary: String?; var whyNow: String?; var reasons: [String]? }
```

Use `CodingKeys` with snake_case conversion and provide alternate key fallbacks where the server uses Turkish field names.

---

## 8. API Client Architecture

```swift
actor APIClient {
    static let shared = APIClient()
    private let session: URLSession  // with cookie storage
    private let baseURL: URL

    func request<T: Decodable>(_ method: String, _ path: String, body: Encodable? = nil, query: [String: String]? = nil) async throws -> T
    func upload<T: Decodable>(_ path: String, fileData: Data, fileName: String, mimeType: String, fields: [String: String]? = nil) async throws -> T
    func requestRaw(_ method: String, _ path: String) async throws -> Data
}
```

- Attach cookies from shared `HTTPCookieStorage` automatically
- Set `Content-Type: application/json` for JSON bodies
- Use `multipart/form-data` for uploads
- Global error handling: 401 → logout, 403 → show access denied, 429 → rate limit message, 5xx → retry once then show error
- Idempotency-Key header for POST mutations (UUID per request)

---

## 9. Navigation & Deep Linking

### Tab Bar (5 tabs)
1. **Feed** — FeedView (stories bar + posts + composer)
2. **Explore** — ExploreView (search + suggestions + member detail)
3. **Chat** — ChatView (global live chat)
4. **Notifications** — NotificationsView (with unread badge)
5. **Profile** — ProfileView (with admin access if authorized)

### Deep Link Routes
```
sdal://feed
sdal://explore
sdal://explore/member/:id
sdal://chat
sdal://messages
sdal://messages/:id
sdal://notifications
sdal://profile
sdal://groups/:id
sdal://events
sdal://admin
```

### Navigation Stack
Use `NavigationStack` with `NavigationPath` for programmatic navigation. Store path in `AppState` for deep link routing.

---

## 10. Quality Requirements

### Performance
- Image caching with NSCache + disk cache (100MB limit)
- Lazy loading for all lists (LazyVStack)
- Prefetch next page when 3 items from bottom
- Debounce search inputs (300ms)
- Cache feed responses for 20s (match server cache TTL)
- Use `thumb` variant for lists, `feed` for detail, `full` for fullscreen

### Accessibility
- VoiceOver labels on all interactive elements
- Dynamic Type support
- Minimum 44pt touch targets
- Semantic color naming for automatic dark mode

### Error Handling
- Network errors: show inline retry banner
- Validation errors: highlight fields with error messages
- Empty states: icon + descriptive text + action button
- Offline mode: show cached content with offline banner

### Security
- Never store passwords in UserDefaults
- Use Keychain for sensitive credentials
- Certificate pinning for production
- Sanitize HTML in post/message content before rendering (use AttributedString)
- Validate all user input before sending to server

---

## 11. Implementation Order

1. **Core infrastructure**: APIClient, AppState, AppConfig, Theme, Navigation
2. **Auth flow**: Login → Register → Activate → Password Reset
3. **Feed + Stories**: Feed list, post cards, composer, story bar + viewer
4. **Social interactions**: Comments, likes, follow/unfollow
5. **Chat**: Global live chat with WebSocket
6. **Messaging**: Mailbox + Messenger DM threads
7. **Explore & Networking**: Member search, suggestions, connections, mentorship
8. **Groups**: List, detail, posts, events, announcements within groups
9. **Events & Announcements**: Global events/announcements
10. **Notifications**: List, preferences, deep-link routing, push registration
11. **Profile**: View, edit, photo upload, verification
12. **Albums & Photos**: Browse, upload, comments
13. **Jobs & Opportunities**: Job listings, applications, opportunity inbox
14. **Games**: Game catalog with 5 native games
15. **Admin panel**: All 20 admin sections
16. **Polish**: Animations, haptics, edge cases, accessibility audit

---

## 12. Key Implementation Notes

- **Cookie auth**: The server uses `uyegiris`, `uyeid`, `kadi` cookies. Persist cookie jar across app launches.
- **Turkish field names**: Many API responses use Turkish keys (`isim`=firstName, `soyisim`=lastName, `kadi`=username, `sifre`=password, `resim`=avatar, `yasak`=banned, `aktiv`=active, `mezuniyetyili`=graduationYear). Handle both Turkish and English field names in decoders.
- **HTML content**: Post/message content may contain HTML. Render using `AttributedString` with HTML support or a lightweight HTML renderer.
- **Image variants**: Posts and stories return 3 WebP image variants (thumb 200px, feed 800px, full 1600px). Use appropriate variant per context.
- **Rate limits**: Upload: 10MB/file, 140 files/day. Connection requests and mentorship requests have per-user rate limits.
- **Pagination**: Server supports both offset-based (`limit`+`offset`) and cursor-based (`cursor`) pagination. Prefer cursor for feeds.
- **Legacy aliases**: Many endpoints have alias forms (PATCH + POST /edit, DELETE + POST /delete). Use the primary form (PATCH/DELETE) but fall back to alias if needed.
- **Idempotency**: Send `Idempotency-Key: <UUID>` header on all mutating POST requests to prevent duplicate actions.

---

*This prompt covers 218+ server endpoints, 30 client routes, all user roles, real-time WebSocket channels, push notifications, full admin panel with 20 sections, and complete UX specifications. Build each feature incrementally, testing against a running SDAL server instance.*
