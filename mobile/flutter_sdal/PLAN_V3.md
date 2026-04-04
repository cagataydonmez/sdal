# Flutter Mobile Plan V3

## Status

**State:** In progress  
**Date locked:** 2026-04-04  
**Target:** Begin V3 implementation from the existing Flutter V2 baseline in `mobile/flutter_sdal`

---

## V1 and V2 Baseline

### V1
- Fresh Flutter iOS client shipped in `mobile/flutter_sdal`.
- Core member flows implemented: auth, shell, feed, explore, networking, notifications, messenger, profile, photo, verification.
- Backend integration established against the existing SDAL API and cookie-session model.

### V2
- Release-candidate hardening completed.
- Typed DTOs, Riverpod action controllers, localization scaffolding, parser hardening, and targeted tests were added.
- Local iOS run and release helper scripts were normalized and documented.

---

## Current Code Baseline

This plan is based on the code currently present in `mobile/flutter_sdal`, not on legacy iOS code and not on the SwiftUI starter in `ios-native`.

### Implemented now
- App shell exists with a fixed 5-tab structure: `Feed`, `Explore`, `Inbox`, `Notifications`, `Profile`.
- Router and session gating already exist in:
  - `lib/core/routing/app_router.dart`
  - `lib/core/widgets/app_tab_shell.dart`
- Shared network stack already supports tolerant JSON envelopes, paging primitives, cookies, multipart uploads, and websocket URLs:
  - `lib/core/network/api_client.dart`
  - `lib/core/network/api_result_parser.dart`
  - `lib/core/network/paged_response.dart`
- Existing feature packages cover:
  - `auth`
  - `feed`
  - `explore`
  - `messenger`
  - `networking`
  - `notifications`
  - `profile`
- Existing tests cover routing, parser behavior, session models, and controller baselines.

### Not implemented yet
- No V3 feature packages exist yet for:
  - `stories`
  - `live_chat`
  - `announcements`
  - `events`
  - `groups`
  - `opportunities`
  - `albums`
  - `following`
  - `requests`

---

## V3 Objective

Deliver the remaining backend-backed, member-facing product surfaces that exist in the current SDAL web app but are still missing in Flutter, while keeping the existing tab shell unchanged.

### Scope
- Implement read and mutation flows for:
  - stories
  - live chat
  - announcements
  - events
  - groups
  - jobs
  - opportunities
  - albums
  - following
  - member requests

### Explicit non-goals
- No admin or moderation surfaces
- No legacy boards
- No legacy inbox/messages API migration
- No games or help pages
- No APNs or push-delivery project expansion
- No UI/code reuse from legacy iOS clients

---

## Delivery Rules

- Keep the existing 5-tab shell unchanged.
- Ship new modules as secondary routes or embedded surfaces.
- Reuse the V2 architecture:
  - typed DTOs at repository boundaries
  - Riverpod controllers for mutations
  - localized copy only
  - shared empty/loading/error states
- Use the current backend as-is unless a narrow backend fix is required to unblock typed decoding or a stable UX path.
- Prefer small vertical slices over opening all V3 modules at once.

---

## Execution Order

### Phase 0 - Foundation and routing

**Goal:** make the app capable of hosting V3 modules before feature work starts.

### Primary files
- `lib/core/routing/app_router.dart`
- `lib/core/widgets/app_tab_shell.dart`
- `lib/core/network/api_client.dart`
- `test/core/routing/app_router_test.dart`
- `test/test_support/fake_api_client.dart`

### Work
- Add the secondary routes required for V3:
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
- Extend `moduleKeyForLocation` for `following`, `groups`, `albums`, `events`, `announcements`, `jobs`, `opportunities`, and `requests`.
- Keep live chat under the feed module gate.
- Add any missing shared helpers needed by multiple V3 modules:
  - paged list request patterns
  - multipart upload conventions
  - notification/deeplink route parsing

### Done when
- Router knows every V3 route.
- Module-closed behavior works for every new route family.
- Existing tab shell behavior remains unchanged.

---

### Phase 1 - Smallest useful modules

**Goal:** start with low-complexity surfaces that validate the V3 shape without destabilizing the app shell.

### 1. Following

**New package:** `lib/features/following`

**Deliverables**
- list screen
- infinite scroll
- unfollow action
- deep link entry from notifications or profile paths if needed

**APIs**
- `/api/new/follows`
- existing `/api/new/follow/:id`

### 2. Requests

**New package:** `lib/features/requests`

**Deliverables**
- request categories list
- create request flow
- attachment upload
- my requests list
- notification landing support

**APIs**
- `/api/new/request-categories`
- `/api/new/requests`
- `/api/new/requests/my`
- `/api/new/requests/upload`

### Done when
- The app has shipped its first V3 routes and feature packages.
- Shared upload and pagination patterns are proven in production-shaped flows.

---

### Phase 2 - Community content modules

**Goal:** add medium-complexity read/write modules with familiar feed-style behavior.

### 1. Announcements

**New package:** `lib/features/announcements`

**Deliverables**
- list
- create
- optional image upload
- pending-state feedback for non-admin submissions

**APIs**
- `/api/new/announcements`
- `/api/new/announcements/upload`

### 2. Events

**New package:** `lib/features/events`

**Deliverables**
- list
- create
- optional image upload
- comment list and create
- RSVP
- owner response-visibility controls

**APIs**
- `/api/new/events*`

### Done when
- Announcements and events are fully usable from Flutter.
- Shared content-create patterns are stable enough to reuse for later modules.

---

### Phase 3 - Jobs and opportunity inbox

**Goal:** deliver the first cross-linked multi-surface workflow.

### New package
- `lib/features/opportunities`

### Deliverables
- jobs board
- job filters
- create and delete own job
- apply flow
- application review for poster/admin-capable backend states
- opportunity inbox with tabs and cursor pagination
- action links back into jobs, networking, and notifications

### APIs
- `/api/new/jobs*`
- `/api/new/opportunities`

### Done when
- A member can discover a job, apply, and return through inbox-driven follow-up flows.

---

### Phase 4 - Albums

**Goal:** add archive/media browsing before tackling realtime and group complexity.

### New package
- `lib/features/albums`

### Deliverables
- categories list
- category detail
- photo detail
- photo comments
- latest-photo strip
- upload flow

### APIs
- `/api/albums`
- `/api/albums/:id`
- `/api/photos/:id`
- `/api/photos/:id/comments`
- `/api/album/upload`
- `/api/album/categories/active`
- `/api/album/latest`

### Done when
- Albums support browse, detail, comment, and upload flows with typed decoding.

---

### Phase 5 - Stories and live chat

**Goal:** add the remaining realtime-adjacent social surfaces after shared infrastructure is already proven.

### 1. Stories

**New package:** `lib/features/stories`

**Deliverables**
- story rail widget
- full-screen viewer
- current-user management sheet
- feed/profile/member-detail integrations
- upload
- mark viewed
- edit caption
- delete/remove
- repost

**APIs**
- `/api/new/stories*`

### 2. Live chat

**New package:** `lib/features/live_chat`

**Deliverables**
- message list
- send
- edit
- delete
- older-message pagination
- websocket updates
- entry route at `/feed/live-chat`

**APIs**
- `/api/new/chat/messages`
- `/api/new/chat/send`
- `/api/new/chat/messages/:id`
- `/ws/chat`

### Done when
- Feed-adjacent realtime surfaces work without adding a new root tab.

---

### Phase 6 - Groups

**Goal:** complete the largest and riskiest V3 surface after the smaller patterns are stable.

### New package
- `lib/features/groups`

### Deliverables
- groups list
- group detail
- membership state
- members and managers
- group posts
- join and leave
- join request review
- invitations
- role changes
- settings
- cover upload
- group events
- group announcements

### APIs
- `/api/new/groups*`

### Done when
- Flutter reaches practical member parity for the groups domain without adding new mobile-specific backend APIs.

---

### Phase 7 - Hardening and release pass

**Goal:** close parity gaps created by deep links, notification landings, and cross-feature navigation.

### Work
- polish empty/loading/error states across all V3 modules
- verify every notification landing route
- verify every module gate
- tighten localization coverage
- review upload failure states and retry behavior
- confirm iOS helper scripts still build and run after all V3 additions

### Done when
- V3 routes behave consistently under cold start, authenticated redirect, module-closed, and verification-gated entry paths.

---

## Cross-Cutting Deliverables

These should be implemented incrementally, not as a standalone rewrite.

### Shared technical work
- Typed DTOs and converters for every new route family
- Repository boundaries for each new feature package
- Riverpod action controllers for each mutation-heavy module
- Shared pagination and upload patterns reused across modules
- Notification and deep-link routing coverage for new destinations
- Localization coverage for all new user-facing strings

### Quality bar
- No hardcoded user-facing copy in new V3 surfaces
- No feature-specific networking shortcuts that bypass shared parsing rules
- No route added without module-gate behavior
- No mutation-heavy feature shipped without controller-level test coverage

---

## Validation Plan

Run the narrowest verification that matches the slice being shipped.

### Per-phase minimum checks
- `flutter test test/core/routing/app_router_test.dart`
- targeted controller or model tests for the feature being added
- widget tests for the new route or interaction when the flow is UI-heavy

### End-of-phase checks
- `flutter analyze`
- focused `flutter test` runs covering the touched modules

### End-of-V3 checks
- `flutter analyze`
- `flutter test`
- `./tool/run_ios_local.sh "iPhone 16 Pro 26.4"` if simulator validation is needed
- `./tool/build_ios_local.sh`

---

## First Slice To Start Now

Start with **Phase 0 plus Phase 1**.

### Immediate order
1. Expand router/module gating for all planned V3 destinations.
2. Add the shared helpers required by both `following` and `requests`.
3. Implement `following`.
4. Implement `requests`.
5. Add focused tests for router behavior and the first two feature controllers.

### Why this order
- It changes the smallest number of existing files first.
- It proves the V3 route model without opening the most complex domains.
- It validates pagination, uploads, and notification landing on simpler member-facing surfaces before groups, stories, and live chat.

---

## Risks

- Groups are the largest parity gap and should not start before announcements, events, and jobs patterns are stable.
- Stories and live chat introduce realtime and media behavior; they should reuse proven primitives instead of inventing their own flow.
- Albums use legacy-style route families compared with the `/api/new/*` surfaces, so typed decoding may need extra coercion coverage.
- Opportunity inbox and requests are likely notification-entry surfaces, so route parsing and cold-start handling must be tested early.

---

## Definition of Done

V3 is done when all scoped member-facing modules above are available in Flutter, routed behind the existing shell, protected by module and verification gates, localized, covered by targeted tests, and still compatible with the documented iOS run and release helpers.
