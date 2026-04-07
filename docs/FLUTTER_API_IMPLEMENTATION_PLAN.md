# Flutter API Coverage Implementation Plan

Last updated: 2026-04-07

## Goal

Implement every `docs/API_REFERENCE.md` endpoint that should be supported by the Flutter app, close partial integrations for APIs that are already present, and reconcile documentation gaps where the Flutter app already depends on server endpoints that are not documented or are documented under a different contract.

This document is intentionally implementation-oriented. It is not a generic audit report; it is a concrete rollout plan designed to avoid missing hidden API work such as:

- query parameter parity
- pagination parity
- canonical vs alias endpoint usage
- upload/multipart parity
- admin-only route coverage inside the existing Flutter admin shell
- feature flags, badges, and menu/sidebar bootstrap data
- telemetry/read/open side effects that are easy to skip even when the main endpoint is already wired

---

## Source Basis

This plan is based on:

- `docs/API_REFERENCE.md`
- current Flutter API usage under `mobile/flutter_sdal/lib/**`
- current Flutter route surface in `mobile/flutter_sdal/lib/core/routing/app_router.dart`
- current admin shell in `mobile/flutter_sdal/lib/features/admin/presentation/admin_pages.dart`
- existing repository/data-layer files under `mobile/flutter_sdal/lib/features/*/data`

Important constraint:

- `API_REFERENCE.md` is not fully aligned with current server/client reality. Some APIs are already used by Flutter but are missing from the reference, and some referenced endpoints are only partially represented in Flutter or are represented through aliases.

That means the implementation must start with contract reconciliation, not with blind endpoint-by-endpoint coding.

---

## Scope Classification

### In Scope

- All user-facing mobile APIs documented in `API_REFERENCE.md`
- All admin APIs that should be reachable from the existing Flutter admin routes
- Missing side-effect endpoints for already rendered surfaces
- Documentation mismatches that block correct Flutter implementation

### Out of Scope For Direct Flutter UI

These still need to be accounted for in the plan so they are not forgotten, but they should not be implemented as normal Flutter feature screens:

- webhook receivers
- operational-only health probes used by CI/load balancers
- browser-only redirect targets where Flutter already delegates to external auth flow
- classic ASP legacy utility routes unless product explicitly wants native parity

### Decision Required

The following sections need an explicit product decision before implementation starts, because the API exists but Flutter may intentionally choose not to support it:

- Legacy Inbox
- Bulletin boards / quick access / tournaments / arcade mini-games
- classic utility routes

If the decision is “not supported in Flutter”, that should be documented explicitly and removed from the implementation backlog rather than left ambiguous.

---

## Executive Summary

### Already Broadly Covered

- session bootstrap
- login/logout/oauth exchange
- profile read/update/password/photo
- feed list/post detail/comments/create
- stories rail, upload, manage, view, repost
- modern messenger base flows
- albums base flows
- events and announcements base list/create/comment flows
- notifications list/read/preferences
- networking hub/inbox base flows
- teacher links / follow / following
- jobs / applications / opportunities inbox
- request categories / request creation / my requests

### Major Missing Areas

- auth pre-validation endpoints
- email change verification landing flow
- shell/menu/sidebar/module-access endpoints
- member latest list
- feed destructive operations and canonical reaction parity
- notifications telemetry + canonical mark-all-read parity
- network metrics + network telemetry + explicit request list endpoints
- legacy inbox
- group leave/delete/list-posts parity
- event/announcement moderation/delete parity
- miscellaneous app features
- almost the entire admin API surface

### High-Risk Contract Mismatches

- `POST /api/new/posts/:id/react` in docs vs `POST /api/new/posts/:id/like` in server/client
- docs say feed is cursor-based; Flutter currently hardcodes `limit=20&offset=0`
- docs say messenger thread creation body is `{ recipientIds: [...] }`; Flutter currently posts `{ userId }`
- docs say member search uses `q`, `year`, `city`, `page`; Flutter currently uses `term`, `pageSize`, `excludeSelf`
- docs say jobs filters are `q`, `city`, `type`; Flutter currently sends `search`, `location`, `job_type`
- docs say teacher options use `q`; Flutter currently sends `term`
- docs include canonical story `PATCH`/`DELETE`; Flutter currently uses legacy alias endpoints for edit/delete
- notifications “mark all read” is documented as `/api/new/notifications/read`; Flutter currently uses `/bulk-read`

These mismatches must be resolved before or during implementation, otherwise the team will keep shipping against an unstable contract.

---

## Section-by-Section Coverage Matrix

## 1. System & Health

Current Flutter coverage:

- `GET /api/site-access`
- `GET /api/session`
- `GET /api/captcha`

Missing or partial:

- `GET /api/health`
- optional diagnostic use of `/health`

Plan:

1. Decide whether Flutter needs a real connectivity probe beyond bootstrap failures.
2. If yes, add a lightweight diagnostics/bootstrap health provider and a hidden “connection status” surface.
3. If no, mark `/api/health` as operational-only and explicitly de-scope it from Flutter UI.

Files likely touched:

- `mobile/flutter_sdal/lib/core/session/session_repository.dart`
- `mobile/flutter_sdal/lib/app/app.dart`
- new `mobile/flutter_sdal/lib/core/diagnostics/*`

## 2. Authentication & Registration

Status: done except legal content screens and OAuth contract cleanup

Current Flutter coverage:

- login
- logout
- register
- activate
- resend activation
- password reset
- OAuth provider list
- OAuth mobile token exchange
- CAPTCHA rendering

Missing documented endpoints or flows:

- `POST /api/register/preview`
- `POST /api/register/check`
- legal content routes `/kvkk` and `/kvkk/acik-riza`
- formal handling of OAuth start/callback contract in docs

Partial implementation gaps:

- registration is single-submit; no preview/check preflight
- no inline uniqueness validation for username/e-mail
- no pre-submit validation step
- no native legal-policy screens or external-opener flow

Plan:

1. [done] Add an auth repository layer for pre-validation and uniqueness checks instead of keeping everything in `AuthActionController`.
2. [done] Implement registration wizard validation stages:
   - field-level uniqueness check
   - pre-submit preview/validation
   - final submit
3. [pending] Add a reusable legal content screen strategy:
   - either in-app webview/native screen
   - or external browser launcher with clear routing from registration/profile flows
4. [pending] Keep OAuth browser start/callback indirect, but document that Flutter uses `/api/auth/oauth/:provider/start` via `FlutterWebAuth2`.
5. [pending] Update docs to include `/api/auth/login` and `/api/auth/logout`, which Flutter already uses but `API_REFERENCE.md` currently omits.

Files likely touched:

- `mobile/flutter_sdal/lib/core/session/session_repository.dart`
- `mobile/flutter_sdal/lib/features/auth/application/auth_action_controller.dart`
- `mobile/flutter_sdal/lib/features/auth/presentation/auth_pages.dart`
- `mobile/flutter_sdal/lib/core/routing/app_router.dart`
- new `mobile/flutter_sdal/lib/features/legal/*`

## 3. OAuth

Current Flutter coverage:

- provider discovery
- browser-start through returned `startUrl`
- mobile token exchange

Missing or partial:

- no explicit contract object for provider start/callback edge cases
- no standardized error mapping for provider-specific failures

Plan:

1. Keep current auth flow, but move provider start/callback handling into a dedicated auth repository/use-case.
2. Normalize OAuth error payload parsing and callback query handling.
3. Add tests covering:
   - missing token
   - provider-disabled
   - callback error
   - exchange failure

Files likely touched:

- `mobile/flutter_sdal/lib/features/auth/application/auth_action_controller.dart`
- `mobile/flutter_sdal/lib/core/session/session_repository.dart`
- new auth unit tests

## 4. Profile & Self-Service

Status: done for mobile implementation parity in this phase, docs sync still pending

Current Flutter coverage:

- `GET /api/profile`
- `PUT /api/profile`
- `POST /api/profile/email-change/request`
- `POST /api/profile/password`
- `POST /api/profile/photo`
- `GET /api/new/request-categories`
- `GET /api/new/requests/my`
- `POST /api/new/requests`
- `POST /api/new/requests/upload`

Implemented in Flutter but missing from `API_REFERENCE.md`:

- `POST /api/new/verified/proof`
- `POST /api/new/verified/request`

Missing documented endpoints or flows:

- `GET /api/profile/email-change/verify`
- `GET /api/menu`
- `GET /api/sidebar`
- `POST /api/module-access-requests`

Partial implementation gaps:

- no email-change verification landing screen
- no shell/bootstrap integration for server-driven menu/sidebar
- no server-driven badge/menu source of truth
- no module access request CTA flow when a route is closed/restricted

Plan:

1. [done] Add a profile/self-service repository split:
   - profile data
   - account actions
   - shell metadata (menu/sidebar)
2. [done] Implement email-change verify route:
   - new route screen
   - token parsing
   - success/failure states
3. [done] Implement module-access request flow:
   - restricted module intercept
   - request form or one-tap request
   - post-submit state
4. [done] Integrate `/api/menu` as a shell metadata source:
   - nav labels
   - badge counts
   - optional visibility/permissions
5. [done] Decide whether `/api/sidebar` should power a desktop/tablet sidebar only or remain unused in mobile layout.
   Mobile decision: use it as lightweight quick-glance shell metadata in the app menu instead of a dedicated sidebar screen.
6. [pending] Update docs to include verification proof/request endpoints already used by Flutter.

Files likely touched:

- `mobile/flutter_sdal/lib/features/profile/data/profile_repository.dart`
- `mobile/flutter_sdal/lib/features/profile/presentation/profile_page.dart`
- `mobile/flutter_sdal/lib/features/profile/presentation/profile_verification_page.dart`
- `mobile/flutter_sdal/lib/core/widgets/app_tab_shell.dart`
- `mobile/flutter_sdal/lib/core/widgets/feature_scaffold.dart`
- `mobile/flutter_sdal/lib/core/routing/app_router.dart`
- new shell metadata repository/providers

## 5. Member Directory

Status: done for latest-members and documented query parity baseline

Current Flutter coverage:

- `GET /api/members`
- `GET /api/members/:id`

Missing documented endpoints:

- `GET /api/members/latest`

Partial implementation gaps:

- member search query contract is not aligned with docs
- no latest-members widget/surface

Plan:

1. [done] Align member search query support with API reference:
   - `q`
   - `year`
   - `city`
   - `page`
2. [done] Preserve current extra query params only if server supports them and docs are updated.
3. [done] Implement “latest members” widget or section:
   - explore page
   - feed secondary card
   - or profile/discovery module
4. [pending] Add filters UI for year/city if product wants parity with docs.

Files likely touched:

- `mobile/flutter_sdal/lib/features/explore/data/explore_repository.dart`
- `mobile/flutter_sdal/lib/features/explore/presentation/explore_page.dart`
- optional `mobile/flutter_sdal/lib/features/networking/presentation/*`

## 6. Feed & Posts

Status: in progress

Current Flutter coverage:

- `GET /api/new/feed`
- `POST /api/new/posts`
- `GET /api/new/posts/:id`
- `GET /api/new/posts/:id/comments`
- `POST /api/new/posts/:id/comments`
- image-post creation through `POST /api/new/posts/upload` (undocumented)
- reaction through `POST /api/new/posts/:id/like` (docs mismatch)

Missing documented endpoints:

- `DELETE /api/new/posts/:id`
- `POST /api/new/posts/:id/react` or documented parity with `/like`
- `DELETE /api/new/posts/:id/comments/:commentId`
- `GET /api/new/online-members`

Partial implementation gaps:

- feed pagination not wired as documented
- no delete post UI
- no delete comment UI
- reaction contract mismatch
- no dedicated online-members widget
- potential missing optimistic updates / cursor support

Plan:

1. [done] Resolve canonical reaction contract:
   - either update docs to `/like`
   - or add `/react` support in Flutter and optionally keep `/like` fallback
2. [partial] Add destructive actions:
   - delete post from feed card and post detail
   - [blocked by backend gap] delete own comment in post detail
3. [pending] Implement cursor pagination properly for feed list if server/reference requires it.
4. [pending] Parse and preserve pagination metadata in `FeedRepository`.
5. [done] Add online-members surface if product wants doc parity:
   - feed header card
   - optional lightweight horizontal strip
6. [pending] Document `POST /api/new/posts/upload` in API reference because Flutter already uses it.

Files likely touched:

- `mobile/flutter_sdal/lib/features/feed/data/feed_repository.dart`
- `mobile/flutter_sdal/lib/features/feed/application/feed_action_controller.dart`
- `mobile/flutter_sdal/lib/features/feed/presentation/feed_page.dart`
- `mobile/flutter_sdal/lib/features/feed/presentation/post_detail_page.dart`
- new tests for delete/reaction/comment parity

## 7. Stories

Status: partial

Current Flutter coverage:

- feed rail
- my stories
- member stories
- upload
- edit
- delete
- mark viewed
- repost

Missing or partial:

- canonical `PATCH /api/new/stories/:id` is not used
- canonical `DELETE /api/new/stories/:id` is not used
- Flutter currently leans on legacy alias endpoints for edit/delete
- upload response is not strongly typed
- story state refresh still depends on broad invalidation rather than typed optimistic merging

Plan:

1. [done] Switch story edit/delete to canonical `PATCH` / `DELETE` with alias fallback only if needed.
2. [done] Introduce a typed story mutation response model.
3. [pending] Tighten story state management:
   - optimistic update on upload/edit/delete/repost
   - explicit handling for active vs expired partitions
4. [done] Confirm story feed query params match docs and backend behavior for `feedType`.
5. [done] Keep alias endpoints only as backward-compatibility fallback, not as primary integration.

Files likely touched:

- `mobile/flutter_sdal/lib/features/stories/data/stories_repository.dart`
- `mobile/flutter_sdal/lib/features/stories/application/stories_action_controller.dart`
- `mobile/flutter_sdal/lib/features/stories/presentation/stories_rail.dart`
- `mobile/flutter_sdal/lib/features/stories/presentation/expired_stories_page.dart`

## 8. Messenger (Modern)

Status: partial

Current Flutter coverage:

- contacts search
- threads list
- create thread
- messages list
- send message
- mark thread read
- realtime websocket listener

Partial implementation gaps:

- no `before` cursor/pagination for thread history
- thread creation body shape does not match docs (`userId` vs `recipientIds`)
- no explicit support for group thread creation
- realtime websocket contract is not represented in API reference

Plan:

1. [done] Align thread creation with docs:
   - post `{ recipientIds: [...] }`
   - [partial] support 1:1 and multi-recipient creation
2. [done] Add paginated history loading using `before`.
3. [done] Add UI support for older-history load / reverse infinite scroll.
4. [pending] Add tests for thread creation and pagination.
5. [pending] Extend docs with websocket transport notes for `/ws/messenger` if realtime is considered part of supported contract.

Files likely touched:

- `mobile/flutter_sdal/lib/features/messenger/data/messenger_repository.dart`
- `mobile/flutter_sdal/lib/features/messenger/presentation/inbox_page.dart`
- `mobile/flutter_sdal/lib/features/messenger/presentation/thread_detail_page.dart`

## 9. Legacy Inbox

Current Flutter coverage:

- none

Documented endpoints:

- unread count
- list
- recipients search
- detail
- send
- delete

Decision gate:

- If Flutter should support the legacy inbox, build a dedicated compatibility module.
- If Flutter should standardize on modern messenger only, de-scope this section explicitly and update product/API expectations.

Recommended plan:

1. Product decision first.
2. If supported:
   - create `features/legacy_inbox/{data,application,presentation}`
   - add unread badge source integration
   - add list/detail/compose/delete flows
3. If not supported:
   - document “modern messenger replaces legacy inbox in Flutter”
   - keep only badge compatibility if required by backend business rules

## 10. Albums & Photos

Current Flutter coverage:

- categories
- active categories
- latest
- upload
- category detail
- photo detail
- photo comments list/add

Status:

- core API coverage is already strong

Partial follow-up tasks:

1. Validate pagination parity for category detail and latest feeds.
2. Add repository/widget tests so albums remain a regression-safe baseline.
3. Decide whether admin album moderation belongs in Flutter admin rollout.

## 11. Community Events

Current Flutter coverage:

- list
- create text
- create with upload
- comments list/add
- RSVP response
- response visibility
- notify audience

Missing documented endpoints:

- `POST /api/new/events/:id/approve`
- `DELETE /api/new/events/:id`

Plan:

1. Add delete event for owner/moderator flows.
2. Add moderator/admin approve action where relevant.
3. Decide whether notify audience remains mod-only and should live under admin event moderation rather than public events page.

Files likely touched:

- `mobile/flutter_sdal/lib/features/community/data/community_repository.dart`
- `mobile/flutter_sdal/lib/features/community/presentation/events_page.dart`
- admin rollout files if approval is kept in admin

## 12. Community Announcements

Current Flutter coverage:

- list
- create text
- create with upload

Missing documented endpoints:

- `POST /api/new/announcements/:id/approve`
- `DELETE /api/new/announcements/:id`

Plan:

1. Add delete announcement for owner/moderator.
2. Add moderator approval flow if announcements are moderated.
3. Clarify whether approval belongs in public UI or admin moderation UI.

Files likely touched:

- `mobile/flutter_sdal/lib/features/community/data/community_repository.dart`
- `mobile/flutter_sdal/lib/features/community/presentation/announcements_page.dart`

## 13. Groups

Documented Flutter coverage:

- list groups
- create group
- group detail
- join group

Implemented in Flutter but under-documented in `API_REFERENCE.md`:

- invitations list/create/respond
- join-request review
- settings update
- role change
- cover upload
- group event create/delete
- group announcement create/delete
- group post image upload

Missing documented endpoints:

- `POST /api/new/groups/:id/leave`
- `DELETE /api/new/groups/:id`
- `GET /api/new/groups/:id/posts`

Partial implementation gaps:

- join is present, leave is not
- group posts can be created but not fetched from documented posts endpoint
- delete group owner flow is missing
- docs do not reflect several already-implemented moderation/management endpoints

Plan:

1. Add leave group flow explicitly.
2. Add delete group flow with owner confirmation UX.
3. Add paginated group posts fetch endpoint integration.
4. Decide whether group detail should continue relying on embedded recent posts or switch to dedicated posts API.
5. Update API reference to include all currently implemented group-management endpoints.

Files likely touched:

- `mobile/flutter_sdal/lib/features/groups/data/groups_repository.dart`
- `mobile/flutter_sdal/lib/features/groups/presentation/group_detail_page.dart`
- `mobile/flutter_sdal/lib/features/groups/presentation/groups_page.dart`

## 14. Notifications

Status: partial, with canonical mark-all-read + cursor pagination + core telemetry hooks now implemented

Current Flutter coverage:

- list
- unread count
- preferences get/update
- single read
- open
- bulk-read

Missing documented endpoints or parity:

- `POST /api/new/notifications/read` mark-all-read canonical path
- `POST /api/new/notifications/telemetry`
- pagination support on notifications list

Partial implementation gaps:

- `mark-all-read` now uses canonical `/read`, keeps `/bulk-read` only as fallback
- telemetry now records `impression`, `open`, `action`, and read-without-open as `no_action`
- notification list now supports `next_cursor` pagination in Flutter
- `landed` / `bounce` destination telemetry is still pending because it should be emitted from destination screens, not the notification list itself
- bottom-tab unread count still keeps `/api/new/notifications/unread` as source of truth and uses `/api/menu` only as defensive fallback

Plan:

1. Resolve canonical mark-all-read behavior:
   - done: use `/read` as canonical
   - done: keep `/bulk-read` only as fallback compatibility path
2. Add telemetry event hooks:
   - done: impression
   - done: open
   - done: action-run
   - done: dismiss-equivalent mapped to `no_action` on mark-read / mark-all-read
   - pending: landed / downstream outcome events on destination surfaces
3. Add pagination support to notifications repository and page.
   - done
4. Ensure badge counts can come either from dedicated unread endpoint or `/api/menu`, then choose a single source of truth.
   - partial: Flutter uses unread endpoint as source of truth and keeps `/api/menu` as fallback for resilience

Files likely touched:

- `mobile/flutter_sdal/lib/features/notifications/data/notifications_repository.dart`
- `mobile/flutter_sdal/lib/features/notifications/presentation/notifications_page.dart`
- `mobile/flutter_sdal/lib/core/widgets/app_tab_shell.dart`

## 15. Network Discovery & Explore

Status: partial, with metrics and supported client telemetry now integrated

Current Flutter coverage:

- network hub
- explore suggestions
- network inbox
- teacher-links read

Missing documented endpoints:

- `GET /api/new/network/metrics`
- `POST /api/new/network/telemetry`

Current implementation update:

- `GET /api/new/network/metrics` is now integrated into the networking hub
- `POST /api/new/network/telemetry` is now used for supported client events:
  - `network_hub_viewed`
  - `network_hub_suggestions_loaded`
  - `network_explore_viewed`
  - `network_explore_suggestions_loaded`
  - `teacher_network_viewed`

Partial implementation gaps:

- server telemetry route only accepts a narrow client-event vocabulary; it does not currently accept dedicated `profile_open_from_suggestion` or generic CTA-click events
- explore/profile-open and CTA analytics still rely on backend contract expansion if they must be first-class telemetry events

Plan:

1. Add a network metrics/insights page or expand the existing hub into a multi-tab surface.
   - done: hub now consumes dedicated metrics payload and shows an insights card
2. Add network telemetry calls for:
   - done: hub/explore/teacher page viewed events
   - done: suggestion-batch loaded events for hub and explore
   - blocked by backend event vocabulary: profile open from suggestion
   - blocked by backend event vocabulary: CTA click
3. Standardize analytics source-surface tags across networking flows.
   - partial: `network_hub`, `explore_page`, and `teachers_network_page` are now used consistently on the new telemetry calls

Files likely touched:

- `mobile/flutter_sdal/lib/features/networking/data/networking_repository.dart`
- `mobile/flutter_sdal/lib/features/networking/presentation/networking_pages.dart`
- `mobile/flutter_sdal/lib/features/explore/presentation/explore_page.dart`

## 16. Connection & Mentorship Requests

Current Flutter coverage:

- send connection request
- accept/ignore/cancel connection request
- send mentorship request
- accept/decline mentorship request

Missing documented endpoints:

- `GET /api/new/connections/requests`
- `GET /api/new/mentorship/requests`

Partial implementation gaps:

- app relies on aggregated inbox payload, not explicit request-list endpoints
- no standalone request history/pagination API integration

Plan:

1. Decide whether inbox aggregation is sufficient.
2. If not, implement dedicated providers/pages for connection and mentorship request lists.
3. If yes, still verify that inbox payload fully covers all request states documented by the standalone endpoints.

Files likely touched:

- `mobile/flutter_sdal/lib/features/networking/data/networking_repository.dart`
- `mobile/flutter_sdal/lib/features/networking/presentation/networking_pages.dart`

## 17. Teacher Network

Current Flutter coverage:

- teacher network list
- teacher options search
- teacher link create
- follow member
- follows list

Status:

- consumer-facing coverage is good

Partial follow-up:

1. Verify query parameter parity for teacher options search.
2. Decide whether follow/follows should remain under teacher/networking section or become reusable member-profile infrastructure.

## 18. Opportunities & Jobs

Current Flutter coverage:

- opportunities inbox
- jobs list
- create job
- delete job
- apply to job
- applications list
- application review

Partial implementation gaps:

- filter query names may not match docs
- no explicit typed contract validation for list filters
- no dedicated job detail endpoint, but docs do not currently require one

Plan:

1. Verify and align jobs filter keys with documented contract.
2. Add repository tests for filter serialization.
3. Keep jobs as one of the “already strong” modules after contract alignment.

Files likely touched:

- `mobile/flutter_sdal/lib/features/opportunities/data/opportunities_repository.dart`
- `mobile/flutter_sdal/lib/features/opportunities/presentation/jobs_page.dart`

## 19. Miscellaneous App Features

Current Flutter coverage:

- none from this section

Missing documented endpoints:

- bulletin boards (`/api/panolar`)
- quick access
- tournament register
- snake/tetris/arcade leaderboards and score submission

Decision gate:

- If these are part of Flutter product roadmap, create separate feature modules.
- If not, explicitly de-scope and record them as web/classic-only.

Recommended implementation order if kept in scope:

1. quick access
2. bulletin boards
3. mini-games / leaderboards
4. tournament registration

## 20–32. Admin APIs

Current Flutter coverage:

- route shell exists
- static admin hub exists
- no real data integration

Missing:

- effectively the full admin API implementation

Admin rollout should be treated as its own program, not as one oversized ticket.

### Admin Phase A: Session, permissions, dashboard backbone

Endpoints:

- admin login/logout/session/root-status
- moderation permission catalog / my-permissions
- dashboard summary/live

Deliverables:

- real admin auth/session repository
- permission-aware admin shell
- dashboard cards and live activity data

### Admin Phase B: User management and request moderation

Endpoints:

- admin users list/search/detail/update/delete
- graduation year update
- verification requests
- member requests queue/review
- manual verify
- teacher-network review queue

Deliverables:

- list/detail pages
- filter/search UI
- review actions
- confirmation/error states

### Admin Phase C: Content moderation

Endpoints:

- groups/stories/posts/comments/chat/messages moderation
- filters CRUD

Deliverables:

- moderation queues
- delete actions
- filter rule management

### Admin Phase D: Operations, security, notifications governance

Endpoints:

- site controls
- media settings + test
- upload-image helper
- security status
- notification governance / ops / experiments

Deliverables:

- operations pages
- security dashboard
- notification governance forms

### Admin Phase E: Experiments, analytics, database, language, email, albums admin

Endpoints:

- engagement scores / A-B management
- network analytics
- DB backups / restore / driver switch / copy data
- language CRUD / strings / config
- email categories/templates/send/bulk
- admin album categories/photos/comments

Deliverables:

- specialized admin sections per existing hub card

Files likely created:

- `mobile/flutter_sdal/lib/features/admin/data/*`
- `mobile/flutter_sdal/lib/features/admin/application/*`
- `mobile/flutter_sdal/lib/features/admin/presentation/*`

Critical note:

- The current `admin_pages.dart` is a static scaffold only. The admin rollout should replace section placeholder pages with real feature modules incrementally.

## 33. Legacy Utility Routes

Current Flutter relevance:

- direct image/media endpoints are already used indirectly by the app
- classic ASP routes are not native-app features

Plan:

1. Keep media route helpers centralized in `AppConfig` / image widgets.
2. Do not build Flutter UI around classic ASP utilities unless product explicitly requires it.
3. Record those endpoints as “compatibility-only / not native UI features”.

---

## Already Implemented In Flutter But Missing Or Mismatched In `API_REFERENCE.md`

These need a doc update or a contract decision before implementation starts:

1. `POST /api/auth/login`
2. `POST /api/auth/logout`
3. `POST /api/new/posts/upload`
4. `POST /api/new/posts/:id/like` vs documented `POST /api/new/posts/:id/react`
5. `POST /api/new/verified/proof`
6. `POST /api/new/verified/request`
7. live chat endpoints:
   - `GET /api/new/chat/messages`
   - `POST /api/new/chat/send`
   - edit/delete aliases
8. websocket channels:
   - `/ws/messenger`
   - `/ws/chat`
9. group-management endpoints currently used by Flutter but not fully documented:
   - invitations list/create/respond
   - join-request review
   - settings update
   - role change
   - cover upload
   - group event create/delete
   - group announcement create/delete
   - group post image upload

Before implementation begins, the team should decide for each mismatch whether to:

- update the docs
- change the Flutter app
- add server aliases so both old and new contracts are safe

---

## Phase Order

Recommended execution order:

1. Contract reconciliation and docs alignment
2. Shared API infrastructure improvements
3. Auth/profile/shell gaps
4. Feed/stories/notifications parity fixes
5. Network/explore/request-list parity
6. Legacy inbox or explicit de-scope
7. Miscellaneous feature decision
8. Admin program rollout in phases A–E

This order prevents the team from building new UI on top of unstable endpoint contracts.

---

## Shared Infrastructure Work Required Before Feature Coding

These cross-cutting tasks should happen early:

1. Create a central “contract parity checklist” for every repository:
   - method
   - path
   - query params
   - pagination
   - body shape
   - response shape
   - side effects
2. Standardize paged/cursor helpers in the Dart data layer.
3. Standardize action endpoint execution helpers for:
   - POST/PUT/DELETE
   - optimistic update
   - rollback
4. Add a common external-link / legal-content / token-verification screen pattern.
5. Add repository-level tests for query serialization on modules with known mismatches.
6. Add a docs-alignment checklist to PR template or release checklist so the contract stays synchronized.

---

## Validation Plan

Each feature phase should ship with the smallest possible targeted validation:

### Automated

- `dart format` on touched files
- `mcp__dart__analyze_files` on touched repositories/pages/providers
- `mcp__dart__run_tests` for:
  - repository serialization tests
  - model decoding tests
  - widget tests for new routes/pages where practical

### Manual

- login/bootstrap smoke test
- profile update/photo/password/email change flow
- feed create/react/delete/comment flow
- stories upload/edit/delete/repost/view flow
- notifications read/open/preferences/mark-all flow
- networking request lifecycle flow
- messenger thread creation/read/send/realtime flow
- jobs apply/review flow
- admin role-specific permission smoke tests once admin implementation begins

### Release Gates

Do not mark a section complete until:

1. all documented endpoints in that section are either:
   - implemented in Flutter, or
   - explicitly de-scoped with written rationale
2. all already-used but undocumented endpoints in that section are reconciled in `API_REFERENCE.md`
3. all query/body/response mismatches discovered in audit are resolved or intentionally aliased

---

## Definition Of Done

The API implementation effort is complete only when all of the following are true:

1. Every `API_REFERENCE.md` endpoint relevant to Flutter is classified as:
   - implemented
   - intentionally unsupported in Flutter
   - operational-only / non-UI
2. Every currently implemented Flutter API dependency is accurately documented.
3. There are no unresolved method/path/query/body mismatches between Flutter and the agreed API contract.
4. The static admin shell has either been replaced with real integrations or explicitly scoped down.
5. The team has an endpoint ownership map so future features do not re-open contract drift.

---

## Recommended Backlog Breakdown

Use these as implementation epics:

1. Epic 01 — Contract reconciliation and documentation fixes
2. Epic 02 — Auth, registration, legal, and bootstrap parity
3. Epic 03 — Shell metadata, menu/sidebar, module-access requests
4. Epic 04 — Feed/posts/stories parity and cleanup
5. Epic 05 — Notifications parity and telemetry
6. Epic 06 — Network metrics, telemetry, and explicit request lists
7. Epic 07 — Legacy inbox decision and implementation or de-scope
8. Epic 08 — Miscellaneous feature decision set
9. Epic 09 — Admin core session/dashboard
10. Epic 10 — Admin management and moderation
11. Epic 11 — Admin operations/security/experiments
12. Epic 12 — Admin database/language/email/albums

This backlog split is small enough to schedule, but broad enough that no section from `API_REFERENCE.md` disappears between phases.
