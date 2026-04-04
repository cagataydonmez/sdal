# Flutter Mobile Roadmap

## V1 — Core Member App

**Status:** Implemented

### Summary
- Built a brand-new Flutter iOS app in `mobile/flutter_sdal`.
- Ignored the legacy iOS implementations as implementation sources.
- Used the SDAL backend and current web product behavior as the product source of truth.
- Delivered the first core member app surface: auth, app shell, feed, explore, networking hub/inbox/teacher links, notifications, messenger, and profile/verification.

### Implemented Scope
- Fresh Flutter workspace with feature-first structure under `lib/app`, `lib/core/*`, and `lib/features/*`.
- Core packages and architecture in place:
  - `flutter_riverpod`
  - `go_router`
  - `dio` + cookie persistence
  - `flutter_web_auth_2`
  - `image_picker`
  - `web_socket_channel`
  - tolerant response decoding for plain JSON, `{ ok, code, message, data }`, and text errors
- App bootstrap flow implemented:
  - runtime config
  - `/api/site-access`
  - `/api/session`
  - authenticated/unauthenticated/module-closed/banned/verification-gated shell states
- Public auth/account routes:
  - login
  - register
  - activation
  - activation resend
  - password reset
  - OAuth callback
- Authenticated shell and member routes:
  - `Feed`
  - `Explore`
  - `Inbox`
  - `Notifications`
  - `Profile`
  - post detail
  - member detail
  - thread detail
  - networking hub/inbox/teachers
  - profile photo
  - profile verification

### Backend Work Completed
- Kept the existing backend namespace and cookie-session model.
- Hardened mobile OAuth:
  - configurable mobile callback scheme/path
  - shared TTL-backed mobile exchange-token storage instead of in-memory-only flow
- Exposed banned state through `/api/session`.

### Interfaces Covered
- `/api/auth/login`
- `/api/session`
- `/api/auth/logout`
- `/api/auth/oauth/providers`
- `/api/auth/oauth/:provider/start`
- `/api/auth/oauth/mobile/exchange`
- `/api/site-access`
- `/api/register`
- `/api/register/preview`
- `/api/activate`
- `/api/activation/resend`
- `/api/password-reset`
- `/api/new/feed`
- `/api/new/posts*`
- `/api/members*`
- `/api/new/explore/suggestions`
- `/api/new/follow/:id`
- `/api/new/connections/*`
- `/api/new/mentorship/*`
- `/api/new/network/*`
- `/api/new/teachers/*`
- `/api/new/notifications*`
- `/api/sdal-messenger/*`
- `/api/profile*`
- `/api/new/verified/*`

### Validation Baseline
- Flutter analyze/test workflow established.
- Backend OAuth contract coverage added for the mobile flow.
- iOS app boots through the tracked Flutter project rather than legacy shells.

---

## V2 — Release-Candidate Hardening

**Status:** Implemented

### Summary
- Treated the second pass as a release-candidate hardening phase rather than new feature breadth.
- Focused on iOS build reproducibility, typed DTO migration on critical paths, controller-driven mutations, localization infrastructure, and broader automated coverage.

### Implemented Changes
- iOS project normalization and tracked local build helpers:
  - simulator/local run helper
  - release no-codesign helper
  - documented iOS run/build flow in README
- Shared tolerant parser extracted and tested as a first-class API boundary.
- Typed contract migration introduced with `freezed` and `json_serializable` for critical-path modules:
  - session/auth
  - feed
  - notifications
  - messenger
  - profile
- Shared JSON coercion/converter helpers added for lossy and aliased backend fields.
- Riverpod mutation controllers added for:
  - auth
  - feed actions/composer
  - notifications actions/preferences
  - messenger send/create-thread flows
  - profile edit/upload/verification flows
- Localization scaffold added with Turkish and English ARB files, generated localizations, and app shell wiring.
- Major shell and feature strings moved out of hardcoded copy and into localization resources.
- Messenger thread screen moved off page-local mutation state to shared controller-driven behavior.

### Interfaces and Internal Contracts Formalized
- Shared action-state model for controller mutations.
- Generated DTOs and converters for core feature repositories.
- Testable router redirect and module-gate helpers.
- Localized app shell and status screens.

### Test and Build Outcomes
- `flutter analyze` clean.
- Expanded Flutter test suite covering:
  - parser behavior
  - route gating
  - session models
  - feed action controller
  - notifications action controller
  - auth action controller
  - messenger action controller
  - profile models
- Tracked iOS release helper completed successfully and produced a local `Runner.app` artifact.

---

## V3 — Remaining Member-Facing Flutter Frontend Parity

**Status:** Planned

### Summary
- V3 will cover the remaining backend-backed, member-facing product surfaces that exist in the current web app but are not yet in `mobile/flutter_sdal`.
- Scope is `Member Core` with `Full Member Parity`: implement read, create, manage, and action flows for included member modules wherever the backend already supports them.
- Keep the existing 5-tab Flutter shell unchanged. New work ships as secondary routes and embedded surfaces inside the current tab structure.
- Explicitly out of scope for V3: admin/moderation, legacy boards (`/api/panolar`), legacy inbox/messages (`/api/messages*`), games, help pages, and push/APNs work.

### Implementation Changes
- **1. Shell, routing, and shared infra**
  - Keep tabs as `Feed`, `Explore`, `Inbox`, `Notifications`, `Profile`.
  - Add secondary Flutter routes:
    - `/feed/live-chat`
    - `/following`
    - `/groups`
    - `/groups/:groupId`
    - `/events`
    - `/announcements`
    - `/jobs`
    - `/opportunities`
    - `/albums`
    - `/albums/:categoryId`
    - `/albums/photo/:photoId`
    - `/albums/upload`
    - `/requests`
  - Do not add a standalone stories tab. Stories ship as reusable rails plus a full-screen story viewer pushed from feed, profile, and member detail.
  - Extend `moduleKeyForLocation` to mirror backend module keys already used by site access: `following`, `groups`, `albums`, `events`, `announcements`, `jobs`, `opportunities`, `requests`; map live chat to `feed`.
  - Reuse the V2 architecture: typed DTOs at repository boundaries, Riverpod controllers for mutations, shared loading/empty/error states, localized copy only.

- **2. Feed-adjacent realtime surfaces**
  - **Stories**
    - Add `features/stories` with a rail widget, full-screen viewer, and current-user management sheet.
    - Integrate rails into `FeedPage`, `ProfilePage`, and `MemberDetailPage`.
    - Support list, mine, user, upload, mark-viewed, edit caption, delete/remove, and repost using the existing `/api/new/stories*` family.
    - Keep feed/community story scope support by passing `feedType=main|community` where supported by backend.
  - **Live chat**
    - Add `features/live_chat` with message list, send, edit, delete, older-message pagination, and websocket updates.
    - Use `/api/new/chat/messages`, `/api/new/chat/send`, `/api/new/chat/messages/:id`, and `/ws/chat`.
    - Expose live chat from the feed surface via `/feed/live-chat`; do not create a new root tab.

- **3. Community and content modules**
  - **Announcements**
    - Add `features/announcements` with list, create, optional image upload, and pending-state feedback for non-admin submissions.
    - Use `/api/new/announcements` and `/api/new/announcements/upload`.
  - **Events**
    - Add `features/events` with list, create, optional image upload, comment list/create, RSVP, and response-visibility settings for owners.
    - Use `/api/new/events*`, including comments, respond, notify, and response-visibility flows supported by backend.
  - **Groups**
    - Add `features/groups` with list and detail screens.
    - Detail must cover membership state, members/managers, group posts, join/leave, join requests review, invitations, role changes, settings, cover upload, group events, and group announcements.
    - Use the existing `/api/new/groups*` family exactly; no new mobile API.
    - Treat groups as the largest V3 slice and implement after shared patterns from announcements/events are stable.

- **4. Growth, archive, and self-service modules**
  - **Jobs and opportunity inbox**
    - Add `features/opportunities` with two routes: jobs board and opportunity inbox.
    - Jobs must support list/filter, create/delete own job, apply, application review for poster/admin, and result states.
    - Opportunity inbox must support tabs, cursor pagination, and action links back into jobs/networking/notifications.
    - Use `/api/new/jobs*` and `/api/new/opportunities`.
  - **Albums**
    - Add `features/albums` with categories, category detail, photo detail, photo comments, latest-photo strip, and upload flow.
    - Use `/api/albums`, `/api/albums/:id`, `/api/photos/:id`, `/api/photos/:id/comments`, `/api/album/upload`, `/api/album/categories/active`, and `/api/album/latest`.
  - **Following**
    - Add `features/following` for list, infinite scroll, and unfollow actions using `/api/new/follows` and existing follow toggle endpoints.
  - **Member requests**
    - Add `features/requests` for request categories, create request, attachment upload, my requests list, and notification-driven deep links.
    - Use `/api/new/request-categories`, `/api/new/requests/my`, `/api/new/requests/upload`, and `/api/new/requests`.
    - Keep email change as part of profile flows; use requests only for the request system already present in backend/web.

- **5. Delivery order**
  - Phase 1: routing/module-gate expansion, shared pagination/upload/media helpers, following, member requests.
  - Phase 2: announcements and events.
  - Phase 3: jobs and opportunity inbox.
  - Phase 4: albums.
  - Phase 5: stories and live chat.
  - Phase 6: groups list/detail with full member-management and group-content parity.
  - Phase 7: polish pass across new modules, deeplinking, notification landing, and release hardening.

### Public APIs / Interfaces
- **Backend routes to adopt in V3**
  - Stories: `/api/new/stories*`
  - Live chat: `/api/new/chat/messages`, `/api/new/chat/send`, `/api/new/chat/messages/:id`, `/ws/chat`
  - Announcements: `/api/new/announcements*`
  - Events: `/api/new/events*`
  - Groups: `/api/new/groups*`
  - Jobs/opportunities: `/api/new/jobs*`, `/api/new/opportunities`
  - Albums: `/api/albums*`, `/api/album/*`, `/api/photos*`
  - Following: `/api/new/follows`, existing `/api/new/follow/:id`
  - Requests: `/api/new/request-categories`, `/api/new/requests*`
- **Internal Flutter additions**
  - New feature packages: `stories`, `live_chat`, `announcements`, `events`, `groups`, `opportunities`, `albums`, `following`, `requests`
  - Typed DTOs and converters for story, chat, announcement, event, group, job/opportunity, album, follow, and request payloads
  - Riverpod action controllers for all new mutation-heavy features
  - Story viewer and live chat realtime event models
  - Expanded localization catalog for all new user-facing copy

### Test Plan
- **Flutter unit/controller tests**
  - DTO decoding for every new route family, including legacy aliases and mixed response envelopes
  - Controllers for story actions, live-chat send/edit/delete, announcement/event creation, group membership/admin actions, job apply/review, album upload/comment, follow/unfollow, request create/upload
  - Route gating for new module keys and notification/deeplink landing
- **Flutter widget tests**
  - Story rails and viewer on feed/profile/member detail
  - Live chat realtime/send/edit/delete flows
  - Announcements/events create/read/action flows
  - Groups list/detail including join, invitation, request review, and group content tabs
  - Jobs/opportunity inbox flows
  - Albums browse/photo/comment/upload flows
  - Following and member-request flows
- **Backend contract coverage**
  - Add narrow tests for the exact new mobile-used endpoints above, especially stories, chat, groups, jobs/opportunities, albums, and requests
- **Acceptance criteria**
  - `flutter analyze` clean
  - Expanded Flutter test suite covering all new V3 modules
  - Current iOS run/release helper flow still works after V3 changes
  - Notification landings and module-closed behavior work for all newly added routes

### Assumptions
- V3 remains iOS-first in Flutter, but architecture stays cross-platform-safe.
- The 5-tab shell remains unchanged; all new modules are secondary routes or embedded surfaces.
- Member core includes stories, live chat, groups, events, announcements, jobs, opportunities, albums, following, and request flows.
- V3 excludes admin/moderation, legacy inbox/messages, boards, games, and help.
- No code or UI is copied from legacy iOS implementations; backend behavior and current web UX are reference only.
- Backend namespace stays as-is; only narrow backend fixes are allowed if typed decoding or stable UX is blocked.
