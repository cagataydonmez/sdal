# SDAL Admin Panel Discovery (Phase 0)

## Sources Used

- `docs/INVENTORY.md`
- `docs/admin-panel-fonksiyon-akislari.md`
- `docs/role-hierarchy.md`
- `docs/RENAME_PLAN.md`
- `docs/ARCHITECTURE.md`
- `server/migrations/*.sql`
- `server/scripts/migrate-legacy-sqlite-to-modern-postgres.mjs`
- `db/tmp/schema.sql`
- Active runtime code in:
  - `frontend-modern/src/pages/AdminPage.jsx`
  - `frontend-modern/src/components/admin/*`
  - `frontend-modern/src/admin.css`
  - `server/app.js`
  - `server/src/services/adminService.js`
  - `server/src/http/controllers/adminController.js`

## Discovery Map

### Admin UI Files

- Primary modern admin page:
  - `frontend-modern/src/pages/AdminPage.jsx` (~2935 lines, multi-domain logic in one file)
- Admin UI support components:
  - `frontend-modern/src/components/admin/AdminPageHeader.jsx`
  - `frontend-modern/src/components/admin/AdminPreviewModal.jsx`
  - `frontend-modern/src/components/admin/AccessDeniedView.jsx`
  - `frontend-modern/src/components/admin/AdminLoginView.jsx` (currently unused)
- Admin styles:
  - `frontend-modern/src/admin.css`
  - `frontend-modern/src/utilities.css` (responsive overrides for admin classes)
- Legacy/classic admin UI still exists:
  - `frontend-classic/src/pages/AdminPage.jsx`
  - legacy ASP admin files under `legacy-site/*.asp`

### Admin API / Backend Files

- Main route surface is still in:
  - `server/app.js`
- Role/domain slice extracted but narrow in scope:
  - `server/src/services/adminService.js`
  - `server/src/http/controllers/adminController.js`
  - `server/src/repositories/legacy/legacyAdminRepository.js`
  - wired via `server/src/bootstrap/createPhase1DomainLayer.js`

### Database Tables Used by Admin (Runtime Legacy + Planned Modern Mapping)

- User & roles:
  - legacy: `uyeler`, `moderator_permissions`, `moderator_scopes`, `audit_log`
  - modern mapping: `users`, `moderation_permissions`, `moderation_scopes`, `audit_logs`
- Content moderation:
  - `posts`, `stories`, `chat_messages`, `gelenkutusu`, `groups`, `group_members`, `group_invites`, `group_join_requests`, `group_events`, `group_announcements`
- Verification/requests:
  - `verification_requests`, `member_requests`, `request_categories`
  - modern mapping: `identity_verification_requests`, `support_requests`, `support_request_categories`
- Engagement:
  - `member_engagement_scores`, `engagement_ab_config`, `engagement_ab_assignments`
  - modern mapping: `user_engagement_scores`, `engagement_variants`, `engagement_variant_assignments`
- Legacy admin tools:
  - `sayfalar`, `email_kategori`, `email_sablon`, `filtre`, `album_kat`, `album_foto`, `album_fotoyorum`, `takimlar`
  - modern mapping: `cms_pages`, `email_categories`, `email_templates`, `blocked_terms`, `album_categories`, `album_photos`, `album_photo_comments`, `tournament_teams`
- System settings:
  - `site_controls`, `module_controls`, `media_settings`
  - modern mapping: `site_settings`, `module_settings`, `media_settings`

### Moderation Logic

- Permission model:
  - `requireModerationPermission(<resource.action>)` in `server/app.js`
  - matrix stored in `moderator_permissions`
- Scope model:
  - `requireScopedModeration(graduationYear)` exists but is only used on `/admin/moderation/check/:graduationYear`
  - most moderation endpoints are permission-only and do not enforce cohort scope filtering on data rows
- Moderator assignment:
  - `/admin/moderators/:id/scopes` sets user role to `mod` and inserts scope rows

### User Role Logic

- Role hierarchy present: `user < mod < admin < root`
- Root bootstrap and role normalization in `server/app.js`
- Role update endpoint:
  - `POST /admin/users/:id/role`
  - domain controller enforces root-only promotion to `admin`
- Root protections:
  - root excluded in some list queries (`/api/admin/users/lists`, online member lists)
  - root operations blocked for normal write paths via `requireAuth`
  - inconsistent protection coverage across all admin endpoints/lists

## Duplicated Code / Dead Features / Legacy Artifacts / Inconsistencies / Missing Controls

### Duplicated

- Two admin SPAs:
  - `frontend-modern/src/pages/AdminPage.jsx`
  - `frontend-classic/src/pages/AdminPage.jsx`
- Dual endpoint families and aliases:
  - `/api/admin/*` and `/api/new/admin/*`
  - delete member alias pair: `/api/admin/users/:id` and `/api/new/admin/members/:id`
- Mixed legacy and modern naming in payloads and DB columns.

### Dead / Low-value / Risky

- `frontend-modern/src/components/admin/AdminLoginView.jsx` appears unused.
- `AdminPage.jsx` includes legacy-heavy tabs (pages, raw DB table browser/restore) mixed with operational moderation.
- Legacy ASP admin artifacts remain in repo with known insecure patterns (documented in `docs/admin-panel-fonksiyon-akislari.md`).

### Schema / Naming Inconsistency

- Runtime admin queries still target legacy SQLite names (`uyeler`, `filtre`, `email_kategori`...), while migrations define modern Postgres names.
- `docs/RENAME_PLAN.md` and migration mappings are modernized, but admin runtime is still largely legacy table-coupled.

### Missing Admin Controls

- No unified notifications operations console (only request-category notifications).
- No centralized queue for high-risk moderation decisions with SLA/work-state controls.
- No full audit timeline UI with action-level filtering across all admin mutations.
- No consistent batch moderation actions for posts/stories/messages/groups.

## Top 10 Pain Points

1. `frontend-modern/src/pages/AdminPage.jsx` is a monolith (~2935 lines) mixing API calls, state, permissions, and rendering for ~25 tabs.
2. Admin backend is still concentrated in `server/app.js`, limiting maintainability and testability.
3. Inconsistent authorization model: some endpoints use `requireAdmin`, others `requireRole`, others permission-based checks; no single admin policy layer.
4. Cohort-scoped moderation is not broadly enforced on content endpoints despite role rules requiring moderator scope boundaries.
5. Pagination/filtering is inconsistent: user and engagement endpoints are paginated, many moderation endpoints return fixed large lists (`LIMIT 200/250/300`) or full-table results.
6. Audit logging is partial: only selected actions write `audit_log`; many admin mutations have no canonical audit event.
7. Root account protection is incomplete in admin data surfaces: root excluded in some queries but not all admin lists/insights.
8. Sensitive data exposure risk: `/api/admin/users/:id` returns `u.*` from `uyeler`, which can leak fields not needed by the UI (including credential-related legacy fields).
9. Legacy operational tools (raw DB table browsing + restore in same panel) are mixed into day-to-day moderation UI, increasing accidental-risk surface.
10. UI/UX information architecture is tool-scattered rather than operations-centered, with inconsistent table patterns, action placement, and state handling.

