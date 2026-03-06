# SDAL Modern Rebuild Plan (Clean Start, New Repo)

## 1. Objective

Rebuild SDAL from scratch in a **new repository**, using only the **modern site** approach, and deliver in phases.

Phase order:
1. Foundation
2. Membership (first functional release)
3. Social core
4. Community modules
5. Admin and operations hardening

This plan is based on the current repo behavior and contracts, but removes legacy/classic coupling and migration complexity.

---

## 2. Hard Constraints for the New Repo

1. No classic frontend (`frontend-classic`) and no legacy ASP route compatibility.
2. No runtime schema mutation in app startup.
3. One canonical DB model from day one (PostgreSQL-first).
4. Keep API payload semantics compatible with modern frontend expectations where needed.
5. Ship phase-by-phase behind clear acceptance gates.

---

## 3. Source Implementation Baseline (from this repo)

Use these files as behavior references while re-implementing:

1. Backend auth and membership routes:
`/Users/cagataydonmez/Desktop/SDAL/server/app.js`

2. Modular backend scaffolding (good base pattern):
`/Users/cagataydonmez/Desktop/SDAL/server/src/bootstrap/createPhase1DomainLayer.js`
`/Users/cagataydonmez/Desktop/SDAL/server/src/services/authService.js`
`/Users/cagataydonmez/Desktop/SDAL/server/src/http/controllers/authController.js`

3. Membership UI pages (modern):
`/Users/cagataydonmez/Desktop/SDAL/frontend-modern/src/pages/LoginPage.jsx`
`/Users/cagataydonmez/Desktop/SDAL/frontend-modern/src/pages/RegisterPage.jsx`
`/Users/cagataydonmez/Desktop/SDAL/frontend-modern/src/pages/ActivationPage.jsx`
`/Users/cagataydonmez/Desktop/SDAL/frontend-modern/src/pages/ActivationResendPage.jsx`
`/Users/cagataydonmez/Desktop/SDAL/frontend-modern/src/pages/PasswordResetPage.jsx`
`/Users/cagataydonmez/Desktop/SDAL/frontend-modern/src/pages/ProfilePage.jsx`
`/Users/cagataydonmez/Desktop/SDAL/frontend-modern/src/pages/ProfilePhotoPage.jsx`
`/Users/cagataydonmez/Desktop/SDAL/frontend-modern/src/pages/ProfileVerificationPage.jsx`
`/Users/cagataydonmez/Desktop/SDAL/frontend-modern/src/pages/ProfileEmailChangePage.jsx`
`/Users/cagataydonmez/Desktop/SDAL/frontend-modern/src/pages/ExplorePage.jsx`
`/Users/cagataydonmez/Desktop/SDAL/frontend-modern/src/pages/MemberDetailPage.jsx`
`/Users/cagataydonmez/Desktop/SDAL/frontend-modern/src/utils/auth.jsx`

4. Existing contract checks to port and simplify:
`/Users/cagataydonmez/Desktop/SDAL/server/tests/contracts/phase1-contracts.mjs`
`/Users/cagataydonmez/Desktop/SDAL/server/tests/contracts/phase9-email.mjs`

5. Current data model references:
`/Users/cagataydonmez/Desktop/SDAL/server/migrations/001_modern_schema.up.sql`
`/Users/cagataydonmez/Desktop/SDAL/docs/INVENTORY.md`

---

## 4. Phase Model

| Phase | Name | Goal | Result |
|---|---|---|---|
| 0 | Foundation | Clean architecture, infra, CI, base schema | Deployable empty shell |
| 1 | Membership | Registration, login, activation, profile, directory | First production release |
| 2 | Social Core | Feed, posts, likes, comments, follows | User engagement loop |
| 3 | Community | Groups, events, announcements, jobs | Full community features |
| 4 | Admin/Ops | Moderation, controls, backups, audits | Operational maturity |

**Important:** Only Phase 0 and Phase 1 are implementation-ready in this document. Phases 2+ stay scoped/high-level until Phase 1 is stable.

---

## 5. Phase 0 Detailed Plan (Foundation)

### 5.1 Repository Layout

Use a clean two-app structure:

1. `apps/api` (Node.js + Express)
2. `apps/web` (React + Vite)
3. `packages/shared` (optional DTO/types/validation constants)
4. `infra` (systemd/nginx/deploy scripts)
5. `docs` (runbooks, contracts, architecture)

### 5.2 Backend Foundations

1. Express app with strict middleware order:
   - request id
   - logging
   - JSON parser
   - session
   - auth user resolver
   - error handler
2. DB access through pooled `pg` client only.
3. Session store:
   - Redis in production
   - in-memory only for local dev
4. Password hashing:
   - `scrypt` format parity with current behavior
   - add rehash flag support for future algo upgrades
5. Migration runner:
   - numbered SQL migrations
   - `migrate:up`, `migrate:down`, `migrate:status`

### 5.3 Frontend Foundations

1. New modern SPA only (no `/` classic app).
2. Route base can stay `/new` for continuity or become `/` (decide once and keep consistent).
3. Auth context with `/api/session` bootstrap.
4. Shared `apiClient` helper with `credentials: 'include'`.
5. Error state conventions per page.

### 5.4 Infrastructure Foundations

1. Docker compose for local:
   - PostgreSQL
   - Redis
2. Production droplet baseline:
   - Node 20
   - PostgreSQL local-only bind
   - Redis local-only bind
   - Nginx reverse proxy
   - systemd units for API and worker
3. Environment file template:
   - include only variables used by Phase 0/1
   - no dead vars

### 5.5 CI/CD Foundations

1. CI jobs:
   - lint
   - unit tests
   - API integration tests
   - build web
2. Deployment script:
   - pull
   - install
   - migrate up
   - restart services
   - health probe

### 5.6 Phase 0 Exit Gate

All must pass:
1. `GET /api/health` returns `200`.
2. DB migrations run from empty DB.
3. Web app loads and can hit API.
4. Session cookie is set/cleared in a trivial auth stub test.
5. Deploy script can provision a fresh droplet without manual code edits.

---

## 6. Phase 1 Detailed Plan (Membership)

## 6.1 Phase 1 Scope

Phase 1 includes:
1. Register with captcha and consent checks.
2. Login/logout/session.
3. Account activation and activation resend.
4. Password reminder/reset initiation email flow.
5. Profile read/update.
6. Profile photo upload.
7. Profile email change request + verify token flow.
8. Verification request creation + optional proof upload.
9. Members directory list + member detail view.

Phase 1 excludes:
1. Feed/posts/comments/likes.
2. Chat/messenger.
3. Groups/events/announcements/jobs.
4. Advanced admin panel.

## 6.2 Data Model for Phase 1

Create only required tables first:

1. `users`
2. `oauth_identities` (keep structure now even if OAuth providers are disabled initially)
3. `verification_requests`
4. `email_change_requests`
5. `site_settings`
6. `module_settings`
7. `audit_logs` (minimal)

Use modern naming in DB and map to frontend-compatible response shapes in controllers.

Minimum `users` fields for Phase 1:

1. `id`
2. `username` (unique)
3. `password_hash`
4. `email` (unique, case-insensitive index)
5. `first_name`
6. `last_name`
7. `activation_token`
8. `is_active`
9. `is_banned`
10. `is_profile_initialized`
11. `graduation_year` (integer or null for teacher mapping strategy)
12. `city`
13. `profession`
14. `website_url`
15. `signature`
16. `avatar_path`
17. `role`
18. `is_verified`
19. `verification_status`
20. `privacy_consent_at`
21. `directory_consent_at`
22. `company_name`
23. `job_title`
24. `expertise`
25. `linkedin_url`
26. `university_name`
27. `university_department`
28. `is_mentor_opted_in`
29. `mentor_topics`
30. `oauth_provider`
31. `oauth_subject`
32. `oauth_email_verified`
33. `created_at`
34. `updated_at`

## 6.3 API Contract (Phase 1)

Implement these endpoints first:

1. `GET /api/health`
2. `GET /api/captcha`
3. `GET /api/session`
4. `POST /api/auth/login`
5. `POST /api/auth/logout`
6. `POST /api/register/check`
7. `POST /api/register`
8. `GET /api/activate`
9. `POST /api/activation/resend`
10. `POST /api/password-reset`
11. `GET /api/profile`
12. `PUT /api/profile`
13. `POST /api/profile/password`
14. `POST /api/profile/photo`
15. `POST /api/profile/email-change/request`
16. `GET /api/profile/email-change/verify`
17. `POST /api/new/verified/request`
18. `POST /api/new/verified/proof`
19. `GET /api/members`
20. `GET /api/members/:id`
21. `GET /kvkk`
22. `GET /kvkk/acik-riza`

### Required behavior parity notes

1. Keep login error semantics equivalent to current flow (missing username/password, user not found, banned, inactive, bad password).
2. Keep register validation strictness:
   - username required, max 15
   - password required, max 20, repeated match
   - email required, max 50, regex format
   - graduation year required and valid
   - captcha numeric and exact match
   - KVKK and directory consent required
3. Keep activation behavior:
   - fail on missing/invalid token
   - fail if already activated
   - rotate activation token after success
4. Keep profile graduation-year lock rule for verified members.
5. Keep `/api/members` filters supported in modern explore page:
   - `term`, `gradYear`, `location`, `profession`, `expertise`, `title`
   - `mentors`, `verified`, `withPhoto`, `online`, `relation`, `sort`

### 6.3.1 Endpoint-level Contract Notes (Phase 1)

| Endpoint | Auth | Request | Response | Critical rules |
|---|---|---|---|---|
| `GET /api/session` | optional | none | `{ user: null }` or `{ user: {...} }` | Include role/admin/state flags for frontend guards |
| `POST /api/auth/login` | no | `{ kadi, sifre }` | `{ user, needsProfile }` | Keep error semantics from current auth flow |
| `POST /api/auth/logout` | yes | none | `204` | Must destroy session and clear auth cookies |
| `GET /api/captcha` | no | none | image/svg | Numeric code, stored in session |
| `POST /api/register/check` | no | `{ kadi?, email? }` | `{ ok, kadiExists, emailExists }` | Reject empty request with no kadi/email |
| `POST /api/register` | no | `kadi,sifre,sifre2,email,isim,soyisim,mezuniyetyili,gkodu,kvkk_consent,directory_consent` | `{ ok, mailSent, message }` | Full validation + activation mail queue |
| `GET /api/activate` | no | query `id,akt` | `{ ok, kadi }` | Rotate token and mark active |
| `POST /api/activation/resend` | no | `{ email }` | `{ ok }` | Fail if user missing or already active |
| `POST /api/password-reset` | no | `{ kadi?, email? }` | `{ ok }` | Do not return password in email |
| `GET /api/profile` | yes | none | `{ user }` | Include consent booleans derived from timestamps |
| `PUT /api/profile` | yes | profile payload | `{ ok }` | Lock graduation year if user verified |
| `POST /api/profile/password` | yes | `{ eskisifre,yenisifre,yenisifretekrar }` | `{ ok }` | Verify old password first |
| `POST /api/profile/photo` | yes | multipart `file` | `{ ok, photo }` | Strict file safety + upload limits |
| `POST /api/profile/email-change/request` | yes | `{ email }` | `{ ok }` | create token, send verify mail |
| `GET /api/profile/email-change/verify` | no | query `token` | redirect | Token status and expiry checks required |
| `POST /api/new/verified/proof` | yes | multipart `proof` | `{ ok, proof_path, proof_image_record_id }` | allow JPG/PNG/PDF only |
| `POST /api/new/verified/request` | yes | `{ proof_path?, proof_image_record_id? }` | `{ ok }` | only one pending request per user |
| `GET /api/members` | yes | query filters | `{ rows,page,pages,total,... }` | keep search/sort/filter semantics |
| `GET /api/members/:id` | yes | path `id` | `{ row }` | return 404 when missing |
| `GET /kvkk` | no | none | html | static consent info |
| `GET /kvkk/acik-riza` | no | none | html | static directory consent info |

## 6.4 Frontend Deliverables (Phase 1)

Pages to build in new repo:

1. Login
2. Register
3. Activation
4. Activation resend
5. Password reset request
6. Profile
7. Profile photo
8. Profile verification
9. Profile email change
10. Explore members
11. Member detail

Routing rules:

1. Public routes: login/register/activation/password pages.
2. Protected routes: profile/explore/member detail.
3. Unauthenticated user is redirected to login.
4. Profile-incomplete user is forced to profile completion page.

### 6.4.1 UI -> API mapping checklist

1. `LoginPage` -> `POST /api/auth/login` -> `refresh /api/session` -> redirect.
2. `RegisterPage`:
   - debounce uniqueness checks via `/api/register/check`
   - show captcha image from `/api/captcha`
   - submit to `/api/register`
3. `ActivationPage` -> `GET /api/activate?id&akt`.
4. `ActivationResendPage` -> `POST /api/activation/resend`.
5. `PasswordResetPage` -> `POST /api/password-reset`.
6. `ProfilePage` -> `GET /api/profile` + `PUT /api/profile`.
7. `ProfilePhotoPage` -> `POST /api/profile/photo`.
8. `ProfileVerificationPage`:
   - optional `POST /api/new/verified/proof`
   - then `POST /api/new/verified/request`
9. `ProfileEmailChangePage` -> `POST /api/profile/email-change/request`.
10. `ExplorePage` -> `GET /api/members`.
11. `MemberDetailPage` -> `GET /api/members/:id`.

## 6.5 Validation and Security Rules

1. Rate limits:
   - login attempts
   - upload endpoints
2. Session cookie:
   - `httpOnly=true`
   - `sameSite=lax`
   - `secure=true` in production
3. Uploaded file safety checks:
   - extension + MIME + magic bytes
   - size cap
   - quota control
4. Email tokens:
   - strong random token
   - expiry for email-change verification
5. Password handling:
   - never plain-text
   - timing-safe compare
6. SQL safety:
   - parameterized queries only
7. Audit logging for sensitive updates:
   - role changes (future phase)
   - email change verify
   - verification request actions

### 6.5.1 Register/Profile validation matrix

| Field | Rule |
|---|---|
| `kadi` | required, trimmed, max 15, profanity check, unique |
| `sifre` | required, max 20, must match repeat |
| `email` | required, valid format, max 50, unique case-insensitive |
| `isim` | required, max 20 |
| `soyisim` | required, max 20 |
| `mezuniyetyili` | required, valid year or `teacher`, no future year |
| `gkodu` | numeric only, exact captcha session match |
| `kvkk_consent` | must be true for register |
| `directory_consent` | must be true for register |
| profile `mezuniyetyili` | immutable when `is_verified=true` |

## 6.6 Email Flows (Phase 1)

Implement templates and delivery for:

1. Registration activation email.
2. Activation resend email.
3. Password reset guidance email.
4. Email change verification email.

Operational requirements:

1. Queue/retry delivery with timeout.
2. Return success payload even when send fails only if business action already persisted and UI can recover.
3. Provide clear status for resend/reset endpoints.

## 6.7 Testing Plan (Phase 1)

### Unit tests

1. Password hash/verify.
2. Validation helpers.
3. Token generation and expiry helpers.
4. Role normalization helpers.

### Integration/API tests

1. Login success/failure matrix.
2. Register happy-path and all major validation rejections.
3. Activation and resend.
4. Password reset request.
5. Profile update and graduation-year lock.
6. Verification request + proof upload.
7. Members list filters and pagination.

### Contract tests

Port and adapt from existing repo:

1. `phase1-contracts` style checks for auth payload shape.
2. `phase9-email` style checks for activation resend and password reset endpoint behavior.

### E2E smoke tests (web)

1. Register -> activation -> login -> profile update.
2. Login -> view explore members -> open member detail.
3. Profile email change request -> token verify redirect.

## 6.8 Phase 1 Definition of Done

All must pass:

1. All Phase 1 routes implemented and documented.
2. All Phase 1 tests passing in CI.
3. Fresh production deploy from empty DB works.
4. Session/auth works across browser refresh and logout.
5. Register + activate + login flow verified manually in staging.
6. Profile save and member directory search verified manually in staging.
7. Basic observability available:
   - request logs
   - error logs
   - `/api/health`
8. Rollback strategy documented (DB snapshot + previous release artifact).

## 6.9 Phase 1 Work Breakdown Structure (WBS)

### Backend WBS

1. `Auth module`
   - login use-case
   - logout use-case
   - session payload composer
2. `Registration module`
   - captcha issue/verify
   - uniqueness check endpoint
   - register endpoint + activation token create
3. `Activation module`
   - activate by token
   - resend activation
4. `Password module`
   - reminder/reset initiation mail endpoint
   - profile password change endpoint
5. `Profile module`
   - read profile
   - update profile
   - photo upload
   - email change request + verification
6. `Verification module`
   - proof upload
   - request create
7. `Members module`
   - list endpoint with filters/sort/pagination
   - member detail endpoint
8. `Compliance module`
   - KVKK and acik-riza static pages

### Frontend WBS

1. Auth context and protected-route wrapper.
2. Public membership pages.
3. Profile pages.
4. Member directory pages.
5. Shared validation/error UX.
6. i18n keys for all phase-1 strings.

### Operations WBS

1. Environment template and secrets docs.
2. Migration runner and migration CI.
3. Service units and reverse proxy config.
4. Backup and restore scripts.
5. Staging and production runbooks.

## 6.10 Phase 1 Implementation Sequence (Execution Order)

1. Create repo skeleton and CI.
2. Add DB migration framework.
3. Add initial Phase 1 schema migration.
4. Add session + auth core.
5. Implement `login/logout/session`.
6. Implement captcha and register/check/register.
7. Implement activate/resend/password-reset endpoints.
8. Implement profile read/update/password/photo/email-change.
9. Implement verification request/proof endpoints.
10. Implement members list/detail endpoints.
11. Build frontend pages and route guards.
12. Integrate i18n strings needed by membership pages.
13. Run full test suite and harden edge cases.
14. Deploy to fresh droplet and complete staging UAT.
15. Production cutover for Phase 1.

---

## 7. Deployment Plan for New Repo (Phase 1 Ready)

## 7.1 Environment Strategy

1. `development`: local docker services.
2. `staging`: single droplet mirror of prod.
3. `production`: single droplet, systemd-managed.

## 7.2 Droplet Provision Steps

1. Base packages and security hardening.
2. Node 20 install.
3. PostgreSQL + Redis local bind only.
4. Create app user and directories.
5. Clone new repo.
6. Install dependencies and build web.
7. Apply migrations.
8. Start API + worker via systemd.
9. Configure Nginx reverse proxy and TLS.
10. Run health and smoke checks.

## 7.3 Operational Minimums

1. Nightly PostgreSQL backup.
2. Redis persistence enabled.
3. App log rotation.
4. Health check monitor and alert.
5. One-command deploy script with health rollback stop condition.

---

## 8. Post-Phase-1 Roadmap (Build On Top)

These stay high-level until Phase 1 is stable.

## Phase 2: Social Core

1. Feed
2. Posts
3. Likes
4. Comments
5. Follows
6. Notifications baseline

## Phase 3: Community

1. Groups
2. Events
3. Announcements
4. Jobs
5. Stories

## Phase 4: Admin and Governance

1. Admin shell modularization
2. Moderation permissions/scopes
3. Site/module controls
4. Audit and safety tooling

---

## 9. Risk Register and Mitigations

1. **Risk:** repeating migration complexity.
   - **Mitigation:** single canonical schema, no dual legacy naming in DB.
2. **Risk:** auth regressions.
   - **Mitigation:** contract tests for login/session/register flows.
3. **Risk:** deployment drift on droplet.
   - **Mitigation:** idempotent provision and deploy scripts, env template under version control.
4. **Risk:** email deliverability issues.
   - **Mitigation:** queue retries, clear fallback responses, provider health endpoint checks.
5. **Risk:** oversized Phase 1.
   - **Mitigation:** strict scope gate (membership only), no feed/chat/groups in first release.

---

## 10. Ready-to-Start Checklist

Before coding in the new repo:

1. Freeze this plan as `docs/IMPLEMENTATION_PLAN.md` in the new repo.
2. Confirm route base decision (`/new` vs `/`).
3. Confirm PostgreSQL-only strategy.
4. Confirm Phase 1 scope lock (no social modules).
5. Create initial milestones:
   - M0 Foundation done
   - M1 Auth/Register done
   - M2 Profile/Directory done
   - M3 Staging deploy + UAT done

When all five are confirmed, implementation can start.
