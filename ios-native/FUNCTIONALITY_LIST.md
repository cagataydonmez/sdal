# SDAL Native Master Functionality List

This is the master parity tracker for the iOS native app.

## Source-of-truth inventories
- Client-side exhaustive inventory: `/Users/cagataydonmez/Desktop/SDAL/ios-native/SDAL_NEW_CLIENT_FEATURES.md`
- Client-side exhaustive UX/UI inventory: `/Users/cagataydonmez/Desktop/SDAL/ios-native/SDAL_NEW_CLIENT_UX_PARITY.md`
- Server endpoint/API exhaustive inventory: `/Users/cagataydonmez/Desktop/SDAL/ios-native/SDAL_NEW_SERVER_ENDPOINTS.md`

## Implementation protocol
- Implement parity feature-by-feature against both inventory files above.
- Keep API contract compatibility with `sdal-modern/server/index.js`.
- Keep language parity (TR/EN/DE/FR) where applicable.
- Finalization gate after all features: update and validate Xcode project metadata (`.xcodeproj`, file references, build phases, resources).

## Execution plan (efficient order)
1. Foundation pass
- Expand API client and models for every remaining endpoint family before UI-by-UI work.
- Keep decoders lossy/compatible to avoid schema drift crashes.
2. Admin core pass
- Implement admin session/login/logout.
- Add admin dashboard (stats/live), moderation queues (posts/stories/messages/chat), and verification queue actions.
3. Admin operations pass
- Add follows inspector, groups admin actions, filters CRUD, and engagement/scoring screens.
4. Data tools pass
- Add DB tables/browser, backup/download/restore trigger flows.
5. Legacy admin parity pass
- Add legacy admin pages/users/email/album/tournament/logs screens backed by `/api/admin/*`.
6. Hardening pass
- End-to-end parity checks against both exhaustive inventories.
- Update Xcode project metadata and run clean build verification.

## Native module checklist

### 1) Authentication & account lifecycle
- [x] Login
- [x] Logout
- [x] Register
- [x] Activation verify
- [x] Activation resend
- [x] Password reset

### 2) Feed & social
- [x] Feed list scopes (all/following/popular)
- [x] Post create (text)
- [x] Post create (image upload + filter)
- [x] Post edit/delete
- [x] Post edit/delete legacy alias fallback (`/api/new/posts/:id/edit`, `/api/new/posts/:id/delete`)
- [x] Post likes
- [x] Post comments
- [x] Feed/comment payload compatibility hardening (alternate envelope keys + lossy comment fields)
- [x] Story list/view mark/upload
- [x] Story edit/delete/repost/mine management
- [x] Story edit/delete legacy alias fallback (`/api/new/stories/:id/edit`, `/api/new/stories/:id/delete`)
- [x] Story view/delete compatibility fallback (`/api/new/stories/:id`, `/api/new/stories/:id/remove`)
- [x] Story payload compatibility hardening (alternate story envelope/field keys)

### 3) Explore & following
- [x] Member search/discovery
- [x] Suggestion list
- [x] Follow/unfollow
- [x] Following list
- [x] Member profile detail
- [x] Member profile stories integration (`/api/new/stories/user/:id`)
- [x] Member profile stories viewer parity (grouped full-screen sequence + mark-view sync)
- [x] Follow/suggestions payload compatibility hardening (toggle status aliases + members envelope variants)

### 4) Messaging
- [x] Inbox/outbox list
- [x] Message detail
- [x] Compose new message
- [x] Recipient search
- [x] Message delete
- [x] Live chat list/send/edit/delete (`/api/new/chat/*`)
- [x] Chat edit/delete legacy alias fallback (`/api/new/chat/messages/:id/edit`, `/api/new/chat/messages/:id/delete`)
- [x] Unread message badge integration (`/api/new/messages/unread`)
- [x] In-chat translate action (`/api/new/translate`)
- [x] Translate/unread payload compatibility hardening (alternate response keys)
- [x] Chat payload compatibility hardening (message envelopes + `mesaj` send fallback)

### 5) Notifications
- [x] Notification list
- [x] Mark all read
- [x] Notification payload compatibility hardening (alternate envelope/message keys)
- [x] Group invite action flows

### 6) Groups
- [x] Group list/create
- [x] Join/request flow
- [x] Group detail timeline
- [x] Group post create/upload
- [x] Group roles/moderation
- [x] Group invitations + responses
- [x] Group cover/settings
- [x] Group events/announcements
- [x] Group payload compatibility hardening (detail/request/invite/events/announcements envelope variants)

### 7) Media albums
- [x] Album categories
- [x] Album photos list
- [x] Album photo detail/comments
- [x] Album photo upload

### 8) Events & announcements
- [x] Events list/create/respond/comment
- [x] Event approvals/admin operations
- [x] Announcements list/create
- [x] Announcement approvals/admin operations
- [x] Events/announcements payload compatibility hardening (envelope aliases + event comment key fallback)

### 9) Profile
- [x] Profile view/edit
- [x] Profile photo upload
- [x] Verification request
- [x] Story management on profile scope

### 10) Games
- [x] Game list/play scaffold
- [x] Score submit
- [x] Leaderboards

### 11) Admin (native scope)
- [x] Admin auth/session screens
- [x] User management UI
- [x] Admin verify/unverify user action (`/api/new/admin/verify`)
- [x] Moderation UI (posts/stories/chat/messages)
- [x] Engagement scoring/admin analytics UI
- [x] Email templates/sending UI
- [x] DB backup/restore UI
- [x] Filters/moderation tables UI
- [x] Group management UI (list/delete)
- [x] Modern admin API parity sync completed (including backup file download endpoint)
- [x] `sdal_new` route/page/component parity inventory sync completed with native-equivalent mappings
- [x] Games API inventory sync completed (`/api/games/*` + `/api/games/arcade/*`)
- [x] Core `/api/*` + legacy-admin-used-by-sdal_new inventory sync (auth/profile/messages/albums/media/admin email/users/session)
- [x] Legacy admin operations parity batch: users search + pages CRUD + logs + album admin + tournament admin
- [x] Legacy social utility parity batch: album active/latest, members latest, quick-access list/add/remove + native UI hooks
- [x] Legacy core parity batch: register preview, profile password, menu/sidebar, panolar, tournament register + native screens
- [x] Utility parity batch: health/captcha/mail-test endpoints integrated (auth/help diagnostics)

### 12) Platform capabilities
- [x] Push notifications registration flow
- [x] Push deep-link routing (messages/chat/notifications/explore/profile + community destinations)
- [x] Multi-language UI base support
- [x] Online presence strip (`/api/new/online-members`)
- [x] Native Help screen entry point parity (`/new/help` access path)

### 13) UX/UI parity (sdal_new web -> native)
- [x] Story grouped viewer baseline parity (Instagram-like sequence viewer: progress/tap/swipe/auto-advance)
- [x] Story transition/preload polish parity
- [x] Feed tabbed side-panel parity (mobile)
- [x] Notification row/action chip visual parity
- [x] Mailbox density/layout parity polish
- [x] Explore/group/event/admin/games visual rhythm parity
- [x] Breakpoint-level responsive parity hardening

## Current focus
- Continue implementing all remaining unchecked items from:
  - `SDAL_NEW_CLIENT_FEATURES.md`
  - `SDAL_NEW_CLIENT_UX_PARITY.md`
  - `SDAL_NEW_SERVER_ENDPOINTS.md`
- Legacy/classic ASP parity is out of scope; prioritize `sdal_new` endpoints and flows only.
- Keep this file updated per completion pass.
- Remaining unchecked server inventory entries are now limited to classic ASP utility routes and web catch-all routes (`/sdal_new`, `/new/*`, `*`), which are non-native web concerns.
