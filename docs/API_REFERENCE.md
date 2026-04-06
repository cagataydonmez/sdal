# SDAL API Reference

Complete reference for all HTTP endpoints exposed by the SDAL Express server (`server/`). Base URL: `http://localhost:8787` in development.

**Legend**
- `Auth` — requires a valid session (`requireAuth` middleware)
- `Admin` — requires admin role (`requireAdmin`)
- `Mod` — requires a specific moderation permission scope
- `RL` — rate-limited endpoint

---

## Table of Contents

1. [System & Health](#1-system--health)
2. [Authentication & Registration](#2-authentication--registration)
3. [OAuth](#3-oauth)
4. [Profile & Self-Service](#4-profile--self-service)
5. [Member Directory](#5-member-directory)
6. [Feed & Posts](#6-feed--posts)
7. [Stories](#7-stories)
8. [Messenger (Modern)](#8-messenger-modern)
9. [Legacy Inbox](#9-legacy-inbox)
10. [Albums & Photos](#10-albums--photos)
11. [Community Events](#11-community-events)
12. [Community Announcements](#12-community-announcements)
13. [Groups](#13-groups)
14. [Notifications](#14-notifications)
15. [Network Discovery & Explore](#15-network-discovery--explore)
16. [Connection & Mentorship Requests](#16-connection--mentorship-requests)
17. [Teacher Network](#17-teacher-network)
18. [Opportunities & Jobs](#18-opportunities--jobs)
19. [Miscellaneous App Features](#19-miscellaneous-app-features)
20. [Admin — User Management](#20-admin--user-management)
21. [Admin — Content Moderation](#21-admin--content-moderation)
22. [Admin — Operations & Site Controls](#22-admin--operations--site-controls)
23. [Admin — Moderation & Roles](#23-admin--moderation--roles)
24. [Admin — Notifications Governance](#24-admin--notifications-governance)
25. [Admin — A/B Experiments & Engagement](#25-admin--ab-experiments--engagement)
26. [Admin — Network Analytics](#26-admin--network-analytics)
27. [Admin — Database Management](#27-admin--database-management)
28. [Admin — Language & Localization](#28-admin--language--localization)
29. [Admin — Security](#29-admin--security)
30. [Admin — Request Moderation](#30-admin--request-moderation)
31. [Admin — Email](#31-admin--email)
32. [Admin — Albums (Admin)](#32-admin--albums-admin)
33. [Legacy Utility Routes](#33-legacy-utility-routes)

---

## 1. System & Health

> Source: `routes/systemRoutes.js`

| Method | Path | Auth | Description | Frontend Usage |
|--------|------|------|-------------|----------------|
| `GET` | `/health` | — | Liveness probe. Returns `{ status: "ok" }`. Used by CI and load balancers. | CI health-check polling, DO deployment health gate |
| `GET` | `/api/health` | — | Alias for `/health`. Preferred by API clients. | Mobile & web bootstrap connectivity check |
| `GET` | `/api/captcha` | — | Returns a CAPTCHA challenge image/token for registration and login forms. | Registration page, login page |
| `GET` | `/api/site-access` | — | Returns site-level feature flags, maintenance mode status, and access rules for the current visitor. | App shell — decides which routes are accessible before login |
| `GET` | `/api/session` | — | Returns current authenticated session info (user id, roles, preferences) or `null` if unauthenticated. | App bootstrap — determines logged-in state and user context |

---

## 2. Authentication & Registration

> Source: `routes/accountRoutes.js`

| Method | Path | Auth | Description | Frontend Usage |
|--------|------|------|-------------|----------------|
| `POST` | `/api/register/preview` | — | Validates registration fields (name, graduation year, etc.) before the user reaches the final submission step. Returns validation errors. | Multi-step registration wizard — step validation |
| `POST` | `/api/register/check` | — | Checks whether a username or e-mail address is already taken. Returns `{ available: true/false }`. | Registration form live uniqueness check |
| `POST` | `/api/register` | — | Submits the full registration form. Creates a pending account and sends an activation e-mail. | Final registration form submission |
| `GET` | `/api/activate` | — | Activates an account using the token from the activation e-mail (`?token=...`). | Activation link landing page |
| `POST` | `/api/activation/resend` | — | Re-sends the activation e-mail for a pending account. | "Resend activation" button on login page |
| `POST` | `/api/password-reset` | — | Initiates password-reset flow or finalises it (depending on request body). Sends a reset e-mail. | Forgot password page |
| `POST` | `/api/mail/test` | Admin | Sends a test e-mail to verify SMTP/Resend configuration is working. | Admin → E-mail settings test |
| `POST` | `/api/mail/webhooks/brevo` | — | Receives delivery/bounce/click webhooks from Brevo (formerly Sendinblue). | Not frontend-facing — webhook receiver |
| `GET` | `/kvkk` | — | Serves the KVKK (Turkish data-protection law) privacy policy page. | Footer legal links |
| `GET` | `/kvkk/acik-riza` | — | Serves the alumni directory open-consent page required by KVKK. | Registration consent step |

---

## 3. OAuth

> Source: `routes/oauthRoutes.js`

| Method | Path | Auth | Description | Frontend Usage |
|--------|------|------|-------------|----------------|
| `GET` | `/api/auth/oauth/providers` | — | Lists enabled OAuth providers (Google, etc.) and their display metadata. | Login page — "Continue with …" button rendering |
| `GET` | `/api/auth/oauth/:provider/start` | — | Redirects the browser to the OAuth provider's authorization URL. `:provider` = `google`, etc. | Login/register page OAuth button click |
| `GET` | `/api/auth/oauth/:provider/callback` | — | Handles the provider redirect after authorization. Creates or links account and sets session. | OAuth provider redirect target (not directly invoked by app code) |
| `POST` | `/api/auth/oauth/mobile/exchange` | — | Exchanges a mobile-obtained OAuth token (e.g., from `google_sign_in` Flutter plugin) for an SDAL session. Returns session cookie. | Flutter app OAuth sign-in flow |

---

## 4. Profile & Self-Service

> Source: `routes/profileSelfServiceRoutes.js`

| Method | Path | Auth | Description | Frontend Usage |
|--------|------|------|-------------|----------------|
| `GET` | `/api/profile` | Auth | Returns the authenticated user's own full profile (bio, education, contact, settings). | Profile edit page initial load |
| `PUT` | `/api/profile` | Auth | Updates the authenticated user's profile fields. Partial updates supported. | Profile edit form save |
| `POST` | `/api/profile/email-change/request` | Auth | Sends a verification e-mail to a new address; starts the e-mail change flow. | Account settings → change e-mail |
| `GET` | `/api/profile/email-change/verify` | — | Verifies the e-mail change token from the link in the verification e-mail (`?token=...`). | E-mail change confirmation link |
| `POST` | `/api/profile/password` | Auth | Changes the authenticated user's password. Requires current password in body. | Account settings → change password |
| `POST` | `/api/profile/photo` | Auth, RL | Uploads a new profile photo. Accepts `multipart/form-data`. Produces thumb/feed/full WebP variants. | Profile photo upload modal |
| `GET` | `/api/menu` | Auth | Returns personalised navigation menu items and badges (unread counts, etc.). | App shell sidebar / tab bar |
| `GET` | `/api/sidebar` | Auth | Returns sidebar widget data (quick links, online members, etc.). | Desktop sidebar widget area |
| `GET` | `/api/new/request-categories` | Auth | Lists categories for member support/change requests (e.g., "graduation year correction"). | Request submission form — category dropdown |
| `GET` | `/api/new/requests/my` | Auth | Lists the authenticated user's own submitted requests and their statuses. | Account → My Requests page |
| `POST` | `/api/new/requests` | Auth | Submits a new member request (e.g., data correction, feature request). | Request submission form |
| `POST` | `/api/new/requests/upload` | Auth | Uploads a supporting attachment for a request. | Request form file attachment |
| `POST` | `/api/module-access-requests` | Auth | Requests access to a restricted module (e.g., teacher network, alumni directory). | Feature gate "Request Access" button |

---

## 5. Member Directory

> Source: `routes/memberDirectoryRoutes.js`

| Method | Path | Auth | Description | Frontend Usage |
|--------|------|------|-------------|----------------|
| `GET` | `/api/members` | Auth | Searches/lists members. Supports query params: `q` (name), `year`, `city`, `page`. | Member search page, network suggestions |
| `GET` | `/api/members/:id` | Auth | Returns a member's public profile including bio, graduation year, social links, and mutual connections. | Member profile view page |
| `GET` | `/api/members/latest` | Auth | Returns recently joined members. | Homepage "New Members" widget |

---

## 6. Feed & Posts

> Source: `routes/eventJobRoutes.js` → `feedController.js`, `postController.js`

| Method | Path | Auth | Description | Frontend Usage |
|--------|------|------|-------------|----------------|
| `GET` | `/api/new/feed` | Auth | Returns the authenticated user's personalised activity feed (posts, stories, events). Supports cursor-based pagination. | Home feed page |
| `POST` | `/api/new/posts` | Auth | Creates a new post. Supports text, link preview, and optional image upload via `multipart/form-data`. | Feed composer |
| `GET` | `/api/new/posts/:id` | Auth | Returns a single post with its reactions and comments. | Post detail / permalink page |
| `DELETE` | `/api/new/posts/:id` | Auth | Deletes a post owned by the authenticated user. | Post overflow menu → Delete |
| `POST` | `/api/new/posts/:id/react` | Auth | Adds or toggles a reaction (like, etc.) on a post. | Post reaction button |
| `GET` | `/api/new/posts/:id/comments` | Auth | Lists comments on a post. | Post detail comment thread |
| `POST` | `/api/new/posts/:id/comments` | Auth | Adds a comment to a post. | Post comment composer |
| `DELETE` | `/api/new/posts/:id/comments/:commentId` | Auth | Deletes a comment owned by the authenticated user. | Comment delete action |
| `GET` | `/api/new/online-members` | Auth | Returns currently online members. | Feed sidebar / presence indicator |

---

## 7. Stories

> Source: `routes/storyRoutes.js`

| Method | Path | Auth | Description | Frontend Usage |
|--------|------|------|-------------|----------------|
| `GET` | `/api/new/stories` | Auth | Returns the stories rail — one item per user who has an active story within 24 hours. | Home feed stories rail |
| `GET` | `/api/new/stories/mine` | Auth | Returns the authenticated user's own stories (including expired ones). | "My Story" management view |
| `GET` | `/api/new/stories/user/:id` | Auth | Returns all active stories for a specific member. | Story viewer for a specific user |
| `POST` | `/api/new/stories/upload` | Auth, RL | Uploads a new story image. Accepts `multipart/form-data` with `image` field. Returns story object. | Story creation sheet |
| `PATCH` | `/api/new/stories/:id` | Auth | Updates the caption of an existing story. | Story edit caption |
| `DELETE` | `/api/new/stories/:id` | Auth | Deletes a story owned by the authenticated user. | Story delete action |
| `POST` | `/api/new/stories/:id/view` | Auth | Records a view event for a story (increments view count). Idempotent per user/story. | Story viewer — auto-called on display |
| `POST` | `/api/new/stories/:id/repost` | Auth | Re-posts an expired story, making it active again for another 24 hours. | "Repost" button on expired stories |
| `POST` | `/api/new/stories/:id/edit` | Auth | Alias for `PATCH /api/new/stories/:id`. | Legacy mobile client compatibility |
| `POST` | `/api/new/stories/:id/delete` | Auth | Alias for `DELETE /api/new/stories/:id`. | Legacy mobile client compatibility |
| `POST` | `/api/new/stories/:id` | Auth | Alias for `PATCH /api/new/stories/:id` (caption update). | Legacy mobile client compatibility |
| `POST` | `/api/new/stories/:id/remove` | Auth | Alias for `DELETE /api/new/stories/:id`. | Legacy mobile client compatibility |

---

## 8. Messenger (Modern)

> Source: `routes/messengerRoutes.js`

| Method | Path | Auth | Description | Frontend Usage |
|--------|------|------|-------------|----------------|
| `GET` | `/api/sdal-messenger/contacts` | Auth | Searches contacts/members for starting a new conversation. Accepts `?q=` query. | New conversation recipient search |
| `POST` | `/api/sdal-messenger/threads` | Auth | Creates a new message thread (DM or group). Body: `{ recipientIds: [...] }`. | New conversation composer |
| `GET` | `/api/sdal-messenger/threads` | Auth | Lists all message threads for the authenticated user, sorted by last message time. | Inbox / conversations list |
| `GET` | `/api/sdal-messenger/threads/:id/messages` | Auth | Returns paginated messages for a thread. Supports cursor pagination via `?before=`. | Thread detail message history |
| `POST` | `/api/sdal-messenger/threads/:id/messages` | Auth | Sends a new message in a thread. Body: `{ text }`. | Thread detail message composer |
| `POST` | `/api/sdal-messenger/threads/:id/read` | Auth | Marks all unread messages in a thread as read. Called when user opens a thread. | Thread detail — auto-called on view |

---

## 9. Legacy Inbox

> Source: `routes/legacyInboxRoutes.js`

| Method | Path | Auth | Description | Frontend Usage |
|--------|------|------|-------------|----------------|
| `GET` | `/api/new/messages/unread` | Auth | Returns the count of unread legacy inbox messages. | App shell badge counter |
| `GET` | `/api/messages` | Auth | Lists legacy inbox messages (sent and received). | Classic frontend inbox page |
| `GET` | `/api/messages/recipients` | Auth | Searches for valid message recipients by name. Accepts `?q=`. | Message compose — recipient autocomplete |
| `GET` | `/api/messages/:id` | Auth | Returns a single legacy message. | Message detail view |
| `POST` | `/api/messages` | Auth | Sends a legacy inbox message. Body: `{ recipientId, subject, body }`. | Legacy message compose form |
| `DELETE` | `/api/messages/:id` | Auth | Deletes a legacy message. | Legacy inbox — delete message |

---

## 10. Albums & Photos

> Source: `routes/albumRoutes.js`

| Method | Path | Auth | Description | Frontend Usage |
|--------|------|------|-------------|----------------|
| `GET` | `/api/albums` | Auth | Lists all album categories with cover image and photo count. | Albums index page |
| `GET` | `/api/album/categories/active` | Auth | Lists only active (non-archived) album categories. | Album browser — public-facing view |
| `GET` | `/api/album/latest` | Auth | Returns the most recently uploaded album photos across all categories. | Homepage "Latest Photos" widget |
| `POST` | `/api/album/upload` | Auth | Uploads a photo to an album category. Accepts `multipart/form-data`. | Album photo upload form |
| `GET` | `/api/albums/:id` | Auth | Returns photos within a specific album category with pagination. | Album category detail page |
| `GET` | `/api/photos/:id` | Auth | Returns metadata and URL for a single photo. | Photo lightbox / detail view |
| `GET` | `/api/photos/:id/comments` | Auth | Lists comments on a photo. | Photo detail comment section |
| `POST` | `/api/photos/:id/comments` | Auth | Adds a comment to a photo. | Photo comment compose |

---

## 11. Community Events

> Source: `routes/communityRoutes.js`

| Method | Path | Auth | Description | Frontend Usage |
|--------|------|------|-------------|----------------|
| `GET` | `/api/new/events` | Auth | Lists upcoming and past community events. Supports `?status=upcoming|past`. | Events page list |
| `POST` | `/api/new/events` | Auth | Creates a new event (text only). Body: `{ title, description, date, location }`. | Event creation form (no image) |
| `POST` | `/api/new/events/upload` | Auth | Creates a new event with a cover image. Accepts `multipart/form-data`. | Event creation form (with image) |
| `POST` | `/api/new/events/:id/approve` | Auth, Mod | Approves a pending event for public display. | Admin / moderator event review |
| `DELETE` | `/api/new/events/:id` | Auth | Deletes an event (owner or moderator). | Event overflow → Delete |
| `POST` | `/api/new/events/:id/respond` | Auth | Submits the authenticated user's RSVP response. Body: `{ status: "going"|"interested"|"not_going" }`. | Event detail RSVP buttons |
| `POST` | `/api/new/events/:id/response-visibility` | Auth | Toggles whether the user's RSVP is visible to others. | Event detail RSVP privacy toggle |
| `GET` | `/api/new/events/:id/comments` | Auth | Lists comments on an event. | Event detail comment section |
| `POST` | `/api/new/events/:id/comments` | Auth | Adds a comment to an event. | Event detail comment composer |
| `POST` | `/api/new/events/:id/notify` | Auth, Mod | Sends push/e-mail notifications about an event to relevant members. | Admin event management — send notification |

---

## 12. Community Announcements

> Source: `routes/communityRoutes.js`

| Method | Path | Auth | Description | Frontend Usage |
|--------|------|------|-------------|----------------|
| `GET` | `/api/new/announcements` | Auth | Lists community announcements ordered by date. | Announcements page |
| `POST` | `/api/new/announcements` | Auth | Creates a new announcement (text only). | Announcement creation form (no image) |
| `POST` | `/api/new/announcements/upload` | Auth | Creates a new announcement with an image. Accepts `multipart/form-data`. | Announcement creation form (with image) |
| `POST` | `/api/new/announcements/:id/approve` | Auth, Mod | Approves a pending announcement for public display. | Moderator announcement review queue |
| `DELETE` | `/api/new/announcements/:id` | Auth | Deletes an announcement (owner or moderator). | Announcement overflow → Delete |

---

## 13. Groups

> Source: `routes/groupRoutes.js` → `routes/communityGroupRoutes.js`

| Method | Path | Auth | Description | Frontend Usage |
|--------|------|------|-------------|----------------|
| `GET` | `/api/new/groups` | Auth | Lists community groups the user can see (public + joined private). | Groups index page |
| `POST` | `/api/new/groups` | Auth | Creates a new group. Body: `{ name, description, isPrivate }`. | Create group form |
| `GET` | `/api/new/groups/:id` | Auth | Returns group detail including members list and recent posts. | Group detail page |
| `POST` | `/api/new/groups/:id/join` | Auth | Joins a public group or requests to join a private group. | Group detail — Join button |
| `POST` | `/api/new/groups/:id/leave` | Auth | Leaves a group. | Group settings — Leave group |
| `DELETE` | `/api/new/groups/:id` | Auth | Deletes a group (owner only). | Group settings — Delete group |
| `GET` | `/api/new/groups/:id/posts` | Auth | Returns posts within a group with pagination. | Group feed tab |
| `POST` | `/api/new/groups/:id/posts` | Auth | Creates a post within a group. | Group post composer |

---

## 14. Notifications

> Source: `routes/notificationRoutes.js`

| Method | Path | Auth | Description | Frontend Usage |
|--------|------|------|-------------|----------------|
| `GET` | `/api/new/notifications` | Auth | Lists the authenticated user's notifications with pagination. | Notifications page |
| `GET` | `/api/new/notifications/unread` | Auth | Returns the unread notification count. | App shell notification badge |
| `POST` | `/api/new/notifications/read` | Auth | Marks all notifications as read. | Notifications page "Mark all read" |
| `POST` | `/api/new/notifications/bulk-read` | Auth | Marks a specific list of notifications as read. Body: `{ ids: [...] }`. | Batch read on scroll/view |
| `POST` | `/api/new/notifications/:id/read` | Auth | Marks a single notification as read. | Notification item tap |
| `POST` | `/api/new/notifications/:id/open` | Auth | Records that the user navigated to the notification's target (click-through tracking). | Notification deep-link navigation |
| `POST` | `/api/new/notifications/telemetry` | Auth | Records notification engagement telemetry (impressions, dismissals). | Notification rendering analytics |
| `GET` | `/api/new/notifications/preferences` | Auth | Returns the user's notification channel preferences (push, e-mail, in-app). | Notification settings page |
| `PUT` | `/api/new/notifications/preferences` | Auth | Updates the user's notification preferences. | Notification settings save |

---

## 15. Network Discovery & Explore

> Source: `routes/networkDiscoveryRoutes.js`

| Method | Path | Auth | Description | Frontend Usage |
|--------|------|------|-------------|----------------|
| `GET` | `/api/new/network/hub` | Auth, RL | Returns the network hub dashboard: connection stats, mentorship summary, suggested people. | Network Hub tab |
| `GET` | `/api/new/network/metrics` | Auth, RL | Returns detailed network analytics for the authenticated user (degree, reach, cohort comparison). | Network metrics / insights page |
| `GET` | `/api/new/explore/suggestions` | Auth, RL | Returns personalised "People You May Know" suggestions. | Explore tab suggestion cards |
| `GET` | `/api/new/network/inbox` | Auth | Returns the network activity inbox: connection requests, mentorship requests, teacher links. | Network inbox page |
| `POST` | `/api/new/network/inbox/teacher-links/read` | Auth | Marks teacher-link inbox items as read. | Network inbox — auto-called on view |
| `POST` | `/api/new/network/telemetry` | Auth | Records network interaction telemetry (suggestion views, profile clicks, etc.). | Explore and network pages analytics |

---

## 16. Connection & Mentorship Requests

> Source: `routes/networkRequestRoutes.js`

| Method | Path | Auth | Description | Frontend Usage |
|--------|------|------|-------------|----------------|
| `POST` | `/api/new/connections/request/:id` | Auth, RL | Sends a connection request to member `:id`. | Member profile → Connect button |
| `GET` | `/api/new/connections/requests` | Auth | Lists incoming and outgoing connection requests. | Network inbox / connection requests tab |
| `POST` | `/api/new/connections/accept/:id` | Auth | Accepts an incoming connection request from member `:id`. | Connection request — Accept |
| `POST` | `/api/new/connections/ignore/:id` | Auth | Ignores/declines an incoming connection request. | Connection request — Ignore |
| `POST` | `/api/new/connections/cancel/:id` | Auth | Cancels an outgoing connection request the user sent. | Pending request — Cancel |
| `POST` | `/api/new/mentorship/request/:id` | Auth, RL | Sends a mentorship request to member `:id`. | Member profile → Request Mentorship |
| `GET` | `/api/new/mentorship/requests` | Auth | Lists incoming and outgoing mentorship requests. | Network inbox / mentorship tab |
| `POST` | `/api/new/mentorship/accept/:id` | Auth | Accepts an incoming mentorship request. | Mentorship request — Accept |
| `POST` | `/api/new/mentorship/decline/:id` | Auth | Declines an incoming mentorship request. | Mentorship request — Decline |

---

## 17. Teacher Network

> Source: `routes/teacherNetworkRoutes.js`

| Method | Path | Auth | Description | Frontend Usage |
|--------|------|------|-------------|----------------|
| `GET` | `/api/new/teachers/network` | Auth | Lists the authenticated user's linked teachers and alumni mentors in the teacher network. | Teacher Network page |
| `GET` | `/api/new/teachers/options` | Auth | Searches available teachers to link to. Accepts `?q=`. | Teacher link search autocomplete |
| `POST` | `/api/new/teachers/network/link/:teacherId` | Auth | Sends a teacher-link request to a teacher by `:teacherId`. | Teacher Network — Link button |
| `POST` | `/api/new/follow/:id` | Auth | Follows a member (one-directional). | Member profile → Follow button |
| `GET` | `/api/new/follows` | Auth | Lists members the authenticated user follows. | Profile → Following list |
| `GET` | `/api/new/admin/follows/:userId` | Admin | Returns the follow list for any user. Used in admin user inspection. | Admin user detail page |

---

## 18. Opportunities & Jobs

> Source: `routes/opportunityRoutes.js`

| Method | Path | Auth | Description | Frontend Usage |
|--------|------|------|-------------|----------------|
| `GET` | `/api/new/opportunities` | Auth, RL | Returns the personalised opportunities inbox (matching jobs and openings). | Opportunities inbox page |
| `GET` | `/api/new/jobs` | Auth | Lists all active job postings. Supports `?q=`, `?city=`, `?type=` filters. | Jobs listing page |
| `POST` | `/api/new/jobs` | Auth | Creates a new job posting. Body: `{ title, description, company, city, type, ... }`. | Post a job form |
| `DELETE` | `/api/new/jobs/:id` | Auth | Deletes a job posting (owner or admin). | Job posting → Delete |
| `POST` | `/api/new/jobs/:id/apply` | Auth | Submits an application for a job. Body: `{ coverLetter, ... }`. | Job detail → Apply button |
| `GET` | `/api/new/jobs/:id/applications` | Auth | Lists applications for a job (visible to job poster). | Job poster → View Applications |
| `POST` | `/api/new/jobs/:jobId/applications/:applicationId/review` | Auth | Updates the status of an application (accepted, rejected, in-review). | Job applications management panel |

---

## 19. Miscellaneous App Features

> Source: `routes/miscAppRoutes.js`

| Method | Path | Auth | Description | Frontend Usage |
|--------|------|------|-------------|----------------|
| `GET` | `/api/panolar` | Auth | Returns bulletin board posts ("panolar"). | Bulletin board page |
| `POST` | `/api/panolar` | Auth | Creates a bulletin board post. | Bulletin board composer |
| `DELETE` | `/api/panolar/:id` | Auth | Deletes a bulletin board post (owner or admin). | Bulletin board post delete |
| `GET` | `/api/quick-access` | Auth | Returns the authenticated user's pinned quick-access items. | Quick access menu |
| `POST` | `/api/quick-access/add` | Auth | Adds an item to the quick-access list. | Quick access → Pin item |
| `POST` | `/api/quick-access/remove` | Auth | Removes an item from the quick-access list. | Quick access → Unpin item |
| `POST` | `/api/tournament/register` | Auth | Registers a team for a tournament. | Tournament registration form |
| `GET` | `/api/games/snake/leaderboard` | Auth | Returns the top scores for the Snake mini-game. | Snake game leaderboard |
| `POST` | `/api/games/snake/score` | Auth | Submits a score for the Snake mini-game. | Snake game over screen |
| `GET` | `/api/games/tetris/leaderboard` | Auth | Returns the top scores for the Tetris mini-game. | Tetris game leaderboard |
| `POST` | `/api/games/tetris/score` | Auth | Submits a score for the Tetris mini-game. | Tetris game over screen |
| `GET` | `/api/games/arcade/:game/leaderboard` | Auth | Returns leaderboard for any arcade game by `:game` slug. | Arcade game leaderboard (generic) |
| `POST` | `/api/games/arcade/:game/score` | Auth | Submits a score for any arcade game. | Arcade game over screen (generic) |

---

## 20. Admin — User Management

> Source: `routes/adminManagementRoutes.js`

| Method | Path | Auth | Description | Frontend Usage |
|--------|------|------|-------------|----------------|
| `GET` | `/api/admin/users/lists` | Admin | Returns paginated member list with filters (`?q=`, `?year=`, `?status=`). | Admin → Members page |
| `GET` | `/api/admin/users/search` | Admin | Full-text search across members. | Admin member search bar |
| `GET` | `/api/admin/users/:id` | Admin | Returns full admin view of a member including account flags, sessions, and activity. | Admin member detail page |
| `PUT` | `/api/admin/users/:id` | Admin | Updates any field on a member account (role, status, flags). | Admin member edit form |
| `DELETE` | `/api/admin/users/:id` | Admin | Permanently deletes a member account and all associated data. | Admin member detail → Delete |
| `DELETE` | `/api/new/admin/members/:id` | Admin | Alias for `DELETE /api/admin/users/:id`. | Modern admin UI delete action |
| `PUT` | `/api/new/admin/users/:id/graduation-year` | Admin | Updates a member's graduation year specifically. | Admin member edit → Graduation Year |
| `GET` | `/api/admin/pages` | Admin | Lists custom CMS pages. | Admin → Pages management |
| `PUT` | `/api/admin/pages/reorder` | Admin | Updates the display order of CMS pages. | Admin pages drag-to-reorder |
| `POST` | `/api/admin/pages` | Admin | Creates a new CMS page. Body: `{ title, slug, content, ... }`. | Admin → New page form |
| `PUT` | `/api/admin/pages/:id` | Admin | Updates a CMS page. | Admin page editor save |
| `DELETE` | `/api/admin/pages/:id` | Admin | Deletes a CMS page. | Admin pages list → Delete |
| `GET` | `/api/admin/logs` | Admin | Returns paginated admin action logs. | Admin → Audit Log page |
| `GET` | `/api/admin/tournament` | Admin | Returns tournament registration data. | Admin → Tournament management |
| `DELETE` | `/api/admin/tournament/:id` | Admin | Deletes a tournament registration. | Admin tournament → Delete entry |

---

## 21. Admin — Content Moderation

> Source: `routes/adminContentModerationRoutes.js`

| Method | Path | Auth | Description | Frontend Usage |
|--------|------|------|-------------|----------------|
| `GET` | `/api/new/admin/verification-requests` | Admin | Lists pending member verification requests. | Admin → Verifications queue |
| `POST` | `/api/new/admin/verification-requests/:id` | Admin | Approves or rejects a verification request. Body: `{ action: "approve"|"reject", reason? }`. | Admin verification review modal |
| `GET` | `/api/new/admin/groups` | Admin | Lists all groups for moderation review. | Admin → Groups moderation |
| `DELETE` | `/api/new/admin/groups/:id` | Admin | Force-deletes a group. | Admin groups → Delete |
| `GET` | `/api/new/admin/stories` | Admin | Lists all stories for moderation review. | Admin → Stories moderation |
| `DELETE` | `/api/new/admin/stories/:id` | Admin | Force-deletes a story. | Admin stories → Delete |
| `GET` | `/api/new/admin/posts` | Admin | Lists posts for moderation with flagged/reported filter support. | Admin → Posts moderation |
| `DELETE` | `/api/new/admin/posts/:id` | Admin | Force-deletes a post. | Admin posts → Delete |
| `GET` | `/api/new/admin/comments` | Admin | Lists comments for moderation. | Admin → Comments moderation |
| `DELETE` | `/api/new/admin/comments/:id` | Admin | Force-deletes a comment. | Admin comments → Delete |
| `GET` | `/api/new/admin/chat/messages` | Admin | Lists chat messages for moderation review. | Admin → Chat moderation |
| `DELETE` | `/api/new/admin/chat/messages/:id` | Admin | Force-deletes a chat message. | Admin chat → Delete message |
| `GET` | `/api/new/admin/messages` | Admin | Lists legacy inbox messages for moderation. | Admin → Messages moderation |
| `DELETE` | `/api/new/admin/messages/:id` | Admin | Force-deletes a legacy inbox message. | Admin messages → Delete |
| `GET` | `/api/new/admin/filters` | Admin | Lists content filters (blocked words, phrases). | Admin → Content Filters |
| `POST` | `/api/new/admin/filters` | Admin | Creates a new content filter rule. Body: `{ pattern, type, action }`. | Admin content filters → Add |
| `PUT` | `/api/new/admin/filters/:id` | Admin | Updates a content filter rule. | Admin content filters → Edit |
| `DELETE` | `/api/new/admin/filters/:id` | Admin | Deletes a content filter rule. | Admin content filters → Delete |

---

## 22. Admin — Operations & Site Controls

> Source: `routes/adminOperationsRoutes.js`

| Method | Path | Auth | Description | Frontend Usage |
|--------|------|------|-------------|----------------|
| `GET` | `/api/admin/site-controls` | Admin | Returns site-wide feature toggle configuration (maintenance mode, registration open, etc.). | Admin → Site Controls page |
| `PUT` | `/api/admin/site-controls` | Admin | Updates site control flags. | Admin site controls save |
| `GET` | `/api/admin/media-settings` | Admin | Returns media storage configuration (local vs. S3/Spaces endpoint, limits). | Admin → Media Settings page |
| `PUT` | `/api/admin/media-settings` | Admin | Updates media storage settings. | Admin media settings save |
| `POST` | `/api/admin/media-settings/test` | Admin | Tests the current media storage configuration by performing a test upload. | Admin media settings → Test Connection |
| `POST` | `/api/upload-image` | Auth, RL | General-purpose image upload endpoint. Returns the URL of the uploaded image. | Rich text editors, post composers |

---

## 23. Admin — Moderation & Roles

> Source: `routes/adminModerationRoutes.js`

| Method | Path | Auth | Description | Frontend Usage |
|--------|------|------|-------------|----------------|
| `POST` | `/api/admin/login` | — | Authenticates an admin user. Sets admin session. | Admin panel login page |
| `POST` | `/api/admin/logout` | Admin | Destroys the admin session. | Admin panel logout button |
| `GET` | `/api/admin/session` | Admin | Returns current admin session info and permissions. | Admin panel session check on boot |
| `GET` | `/api/admin/root-status` | Admin | Returns whether the root (super-admin) account has been set up. | Admin setup wizard |
| `POST` | `/admin/users/:id/role` | Admin | Assigns a role (admin, moderator, member) to a user. | Admin user detail → Role assignment |
| `POST` | `/admin/moderators/:id/scopes` | Admin | Assigns moderation permission scopes to a moderator. | Admin moderator management |
| `GET` | `/admin/moderators` | Admin | Lists all moderators and their scopes. | Admin → Moderators page |
| `GET` | `/api/admin/moderation/permissions/catalog` | Admin | Returns the full catalog of available moderation permissions. | Admin permissions management |
| `GET` | `/api/admin/moderation/permissions/:userId` | Admin | Returns a specific user's moderation permissions. | Admin moderator detail |
| `PUT` | `/api/admin/moderation/permissions/:userId` | Admin | Updates a user's moderation permissions. | Admin moderator permissions editor |
| `GET` | `/api/admin/moderation/my-permissions` | Admin | Returns the current admin's own moderation permissions. | Admin panel — permission-aware UI rendering |
| `POST` | `/admin/moderation/check/:graduationYear` | Admin | Checks whether the current admin has moderation access for a given graduation cohort. | Admin cohort-scoped moderation check |

---

## 24. Admin — Notifications Governance

> Source: `routes/notificationRoutes.js` (admin sub-section)

| Method | Path | Auth | Description | Frontend Usage |
|--------|------|------|-------------|----------------|
| `GET` | `/api/new/admin/notifications/governance` | Admin | Returns notification governance settings (throttle limits, delivery rules). | Admin → Notifications governance page |
| `GET` | `/api/new/admin/notifications/experiments` | Admin | Lists notification A/B experiment configurations. | Admin → Notification experiments |
| `PUT` | `/api/new/admin/notifications/experiments/:key` | Admin | Updates a notification experiment's parameters (variant weights, enabled state). | Admin notification experiment editor |
| `GET` | `/api/new/admin/notifications/ops` | Admin | Returns operational data: delivery queue depth, error rate, last-run timestamps. | Admin → Notification ops dashboard |

---

## 25. Admin — A/B Experiments & Engagement

> Source: `routes/adminExperimentRoutes.js`

| Method | Path | Auth | Description | Frontend Usage |
|--------|------|------|-------------|----------------|
| `GET` | `/api/new/admin/stats` | Admin | Returns admin dashboard summary stats (total members, new signups, active sessions, etc.). | Admin dashboard summary cards |
| `GET` | `/api/admin/dashboard/summary` | Admin | Alias for `/api/new/admin/stats`. | Classic admin dashboard |
| `GET` | `/api/new/admin/live` | Admin | Returns real-time activity data (online users, recent actions) for the admin live view. | Admin dashboard live activity feed |
| `GET` | `/api/admin/dashboard/activity` | Admin | Alias for `/api/new/admin/live`. | Classic admin live view |
| `GET` | `/api/new/admin/engagement-scores` | Admin | Lists per-member engagement scores. | Admin → Engagement scores page |
| `POST` | `/api/new/admin/engagement-scores/recalculate` | Admin | Triggers recalculation of all member engagement scores (async job). | Admin engagement scores → Recalculate |
| `GET` | `/api/new/admin/engagement-ab` | Admin | Returns engagement A/B test overview (variants, traffic splits, metrics). | Admin → Engagement A/B page |
| `PUT` | `/api/new/admin/engagement-ab/:variant` | Admin | Updates parameters for an engagement A/B test variant. | Admin A/B variant editor |
| `POST` | `/api/new/admin/engagement-ab/rebalance` | Admin | Rebalances traffic splits across engagement A/B variants. | Admin A/B → Rebalance |
| `GET` | `/api/new/admin/network-suggestion-ab` | Admin | Returns network suggestion A/B test data and performance metrics. | Admin → Network suggestion A/B page |
| `PUT` | `/api/new/admin/network-suggestion-ab/:variant` | Admin | Updates a network suggestion A/B variant's config. | Admin network A/B variant editor |
| `POST` | `/api/new/admin/network-suggestion-ab/rebalance` | Admin | Rebalances traffic splits for the network suggestion experiment. | Admin network A/B → Rebalance |
| `POST` | `/api/new/admin/network-suggestion-ab/apply` | Admin | Applies the winning A/B recommendation as the new default. | Admin network A/B → Apply recommendation |
| `POST` | `/api/new/admin/network-suggestion-ab/rollback/:id` | Admin | Rolls back a previously applied A/B change. | Admin network A/B → Rollback |

---

## 26. Admin — Network Analytics

> Source: `routes/networkDiscoveryRoutes.js` (admin sub-section)

| Method | Path | Auth | Description | Frontend Usage |
|--------|------|------|-------------|----------------|
| `GET` | `/api/new/admin/network/analytics` | Admin | Returns aggregate network analytics (connection density, cohort graphs, suggestion funnel). | Admin → Network analytics page |

---

## 27. Admin — Database Management

> Source: `routes/adminDbRoutes.js`

| Method | Path | Auth | Description | Frontend Usage |
|--------|------|------|-------------|----------------|
| `GET` | `/api/new/admin/db/backups` | Admin | Lists available database backup files with size and timestamp. | Admin → DB Backups page |
| `POST` | `/api/new/admin/db/backups` | Admin | Triggers creation of a new database backup. | Admin DB backups → Create backup |
| `GET` | `/api/new/admin/db/backups/:name/download` | Admin | Downloads a specific backup file. | Admin DB backups → Download |
| `POST` | `/api/new/admin/db/restore` | Admin | Restores the database from a backup file. Body: `{ backupName }`. | Admin DB backups → Restore |
| `GET` | `/api/new/admin/db/driver/status` | Admin | Returns current DB driver (`postgres` or `sqlite`) and any pending switch state. | Admin → DB Driver status indicator |
| `POST` | `/api/new/admin/db/driver/switch` | Admin | Switches the active database driver. | Admin DB settings → Switch driver |
| `POST` | `/api/new/admin/db/driver/copy-data` | Admin | Copies all data from one DB driver to another (migration tool). | Admin DB → Copy data between drivers |

---

## 28. Admin — Language & Localization

> Source: `routes/adminLanguageRoutes.js`

| Method | Path | Auth | Description | Frontend Usage |
|--------|------|------|-------------|----------------|
| `GET` | `/api/admin/languages` | Admin | Lists all configured languages. | Admin → Languages page |
| `POST` | `/api/admin/languages` | Admin | Adds a new language. Body: `{ code, name, isRTL }`. | Admin languages → Add language |
| `PUT` | `/api/admin/languages/:code` | Admin | Updates language metadata. | Admin language edit form |
| `DELETE` | `/api/admin/languages/:code` | Admin | Removes a language. | Admin language list → Delete |
| `GET` | `/api/admin/language-strings` | Admin | Lists all localization strings (key-value pairs). Supports `?lang=` and `?q=` filters. | Admin → Translation strings page |
| `GET` | `/api/admin/language-strings/keys` | Admin | Lists all translation keys (without values). | Admin translation key overview |
| `PUT` | `/api/admin/language-strings/:lang/:key` | Admin | Creates or updates a single translation string. | Admin translation editor inline edit |
| `POST` | `/api/admin/language-strings/bulk` | Admin | Bulk upserts multiple translation strings. Body: `[{ lang, key, value }]`. | Admin translation → Bulk import |
| `POST` | `/api/admin/language-strings/fill-missing` | Admin | Auto-fills missing translation strings (e.g., from a default language). | Admin translation → Fill missing |
| `DELETE` | `/api/admin/language-strings/:lang/:key` | Admin | Deletes a single translation string. | Admin translation editor → Delete |
| `DELETE` | `/api/admin/language-strings/key/:key` | Admin | Deletes a translation key across all languages. | Admin translation → Delete key |
| `GET` | `/api/admin/language-config` | Admin | Returns language configuration (default language, fallback strategy). | Admin → Language config settings |
| `PUT` | `/api/admin/language-config` | Admin | Updates language configuration. | Admin language config save |

---

## 29. Admin — Security

> Source: `routes/adminSecurityRoutes.js`

| Method | Path | Auth | Description | Frontend Usage |
|--------|------|------|-------------|----------------|
| `GET` | `/api/new/admin/security/status` | Admin | Returns current security posture: active sessions, recent failed logins, suspicious IPs, rate-limit hits. | Admin → Security dashboard |

---

## 30. Admin — Request Moderation

> Source: `routes/adminRequestModerationRoutes.js`

| Method | Path | Auth | Description | Frontend Usage |
|--------|------|------|-------------|----------------|
| `GET` | `/api/new/admin/requests/notifications` | Admin | Returns unread notification count for the admin request queue. | Admin panel → request badge |
| `GET` | `/api/new/admin/requests` | Admin | Lists pending member requests (graduation year corrections, data changes, etc.). | Admin → Member Requests queue |
| `POST` | `/api/new/admin/requests/:id/review` | Admin | Approves or rejects a member request. Body: `{ action: "approve"|"reject", note? }`. | Admin request review modal |
| `POST` | `/api/new/admin/verify` | Admin | Manually verifies a member account. Body: `{ userId }`. | Admin member detail → Verify |
| `GET` | `/api/new/admin/teacher-network/links` | Admin | Lists pending teacher-network link requests awaiting approval. | Admin → Teacher Links queue |
| `POST` | `/api/new/admin/teacher-network/links/:id/review` | Admin | Approves or rejects a teacher-network link request. | Admin teacher links review modal |

---

## 31. Admin — Email

> Source: `routes/adminManagementRoutes.js` (email sub-section)

| Method | Path | Auth | Description | Frontend Usage |
|--------|------|------|-------------|----------------|
| `POST` | `/api/admin/email/send` | Admin | Sends a transactional e-mail to one or more recipients. | Admin → Manual email send form |
| `GET` | `/api/admin/email/categories` | Admin | Lists e-mail categories (newsletters, transactional, etc.). | Admin → Email categories page |
| `POST` | `/api/admin/email/categories` | Admin | Creates an e-mail category. | Admin email categories → Add |
| `PUT` | `/api/admin/email/categories/:id` | Admin | Updates an e-mail category. | Admin email category edit |
| `DELETE` | `/api/admin/email/categories/:id` | Admin | Deletes an e-mail category. | Admin email categories → Delete |
| `GET` | `/api/admin/email/templates` | Admin | Lists e-mail templates. | Admin → Email templates page |
| `POST` | `/api/admin/email/templates` | Admin | Creates an e-mail template. Body: `{ name, subject, htmlBody, category }`. | Admin email templates → New |
| `PUT` | `/api/admin/email/templates/:id` | Admin | Updates an e-mail template. | Admin email template editor save |
| `DELETE` | `/api/admin/email/templates/:id` | Admin | Deletes an e-mail template. | Admin email templates → Delete |
| `POST` | `/api/admin/email/bulk` | Admin | Sends a bulk e-mail campaign to a filtered member segment. | Admin → Bulk email composer |

---

## 32. Admin — Albums (Admin)

> Source: `routes/adminManagementRoutes.js` (album sub-section)

| Method | Path | Auth | Description | Frontend Usage |
|--------|------|------|-------------|----------------|
| `GET` | `/api/admin/album/categories` | Admin | Lists all album categories including inactive ones. | Admin → Albums page |
| `POST` | `/api/admin/album/categories` | Admin | Creates an album category. Body: `{ name, description, isActive }`. | Admin albums → Add category |
| `PUT` | `/api/admin/album/categories/:id` | Admin | Updates an album category. | Admin album category editor |
| `DELETE` | `/api/admin/album/categories/:id` | Admin | Deletes an album category. | Admin albums → Delete category |
| `GET` | `/api/admin/album/photos` | Admin | Lists all album photos with moderation status filter support. | Admin → Album photos moderation |
| `POST` | `/api/admin/album/photos/bulk` | Admin | Bulk approves, rejects, or deletes photos. Body: `{ ids: [...], action }`. | Admin album photos → Bulk action |
| `PUT` | `/api/admin/album/photos/:id` | Admin | Updates a photo's metadata or approval status. | Admin photo edit form |
| `DELETE` | `/api/admin/album/photos/:id` | Admin | Deletes a photo. | Admin photos → Delete |
| `GET` | `/api/admin/album/photos/:id/comments` | Admin | Lists all comments on a photo for moderation. | Admin photo detail → Comments |
| `DELETE` | `/api/admin/album/photos/:id/comments/:commentId` | Admin | Deletes a specific comment on a photo. | Admin photo → Delete comment |

---

## 33. Legacy Utility Routes

> Source: `routes/legacyUtilityRoutes.js`

These routes preserve compatibility with the classic ASP-era frontend and are not intended for use in new code.

| Method | Path | Auth | Description | Frontend Usage |
|--------|------|------|-------------|----------------|
| `GET` | `/api/media/vesikalik/:file` | — | Serves a profile photo by filename. | Classic frontend profile images |
| `GET` | `/api/media/kucukresim` | — | Returns a resized image (legacy params via query string). | Classic frontend image thumbnails |
| `GET` | `/logout` | Auth | Destroys the session and redirects to login. | Classic frontend logout link |
| `GET` | `/aspcaptcha.asp` | — | Issues a legacy CAPTCHA image. | Classic frontend registration |
| `GET` | `/textimage.asp` | — | Generates a text-as-image (e.g., styled username). | Classic frontend profile headers |
| `GET` | `/kucukresim*.asp` | — | Various legacy image resize endpoints (1–8). | Classic frontend image processing |
| `GET` | `/onlineuyekontrol.asp` | — | Returns the online user list in legacy format. | Classic frontend presence indicator |
| `GET` | `/grayscale.asp` | — | Toggles grayscale display mode for the session. | Classic frontend accessibility toggle |
| `GET` | `/fizikselyol.asp` | — | Returns the legacy root path for the current environment. | Classic frontend base-URL discovery |
| `ALL` | `/oyunyilanislem.asp` | Auth | Receives Snake game score submissions (legacy). | Classic frontend Snake game |
| `ALL` | `/oyuntetrisislem.asp` | Auth | Receives Tetris game score submissions (legacy). | Classic frontend Tetris game |
| `POST` | `/albumyorumekle.asp` | Auth | Adds an album comment via legacy form submission. | Classic frontend album page |
| `GET` | `/abandon.asp` | — | Abandons the current session (legacy session management). | Classic frontend session handling |
| `GET` | `/admincikis.asp` | Admin | Legacy admin logout endpoint. | Classic admin panel |

---

*Generated: 2026-04-07 — reflects the server codebase at commit `7fabe3c`.*
