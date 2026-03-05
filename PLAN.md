# SDAL Admin Panel Redesign Plan (Phase 1 IA)

## Goals

- Make admin operations understandable, complete, secure, and fast.
- Convert current tab-heavy tool list into an operations console.
- Keep user-facing product flows stable while refactoring admin architecture.

## Information Architecture (Target Navigation)

1. Dashboard
2. Users
3. Content Moderation
4. Messaging & Safety
5. Groups / Events
6. Notifications
7. Settings
8. System

## Global UX Standards (All Sections)

- Persistent sidebar navigation (desktop), drawer sidebar (mobile).
- Standardized data table with:
  - search
  - column filters
  - sortable columns
  - server-side pagination
  - row selection + bulk actions
- Detail drawer for quick inspect/edit; modal only for destructive confirmations.
- Consistent spacing, type scale, sticky page header, action bar.
- Unified status/toast and optimistic UI patterns.
- Permission-aware UI (hide/disable actions by role and moderation permissions).

## Section Design

## 1) Dashboard

- Purpose:
  - At-a-glance operational health and pending-risk queues.
- Actions:
  - Jump-to queue views, trigger safe recalculation jobs, review incidents.
- Related tables:
  - legacy: `uyeler`, `posts`, `stories`, `verification_requests`, `member_requests`, `chat_messages`, `album_foto`
  - modern: `users`, `posts`, `stories`, `identity_verification_requests`, `support_requests`, `live_chat_messages`, `album_photos`
- Related APIs:
  - current: `/api/new/admin/stats`, `/api/new/admin/live`, `/api/new/admin/engagement-scores/recalculate`
  - target: `/api/admin/dashboard/summary`, `/api/admin/dashboard/activity`, `/api/admin/jobs/*`
- UI layout:
  - KPI strip + “needs attention” queues + live activity timeline + quick actions.

## 2) Users

- Purpose:
  - Account lifecycle, verification, role management, and profile moderation.
- Actions:
  - Search/filter members, edit profile flags, verify/reject, role update, scope assignment, hard delete (guarded), bulk status changes.
- Related tables:
  - legacy: `uyeler`, `verification_requests`, `moderator_permissions`, `moderator_scopes`, `member_engagement_scores`
  - modern: `users`, `identity_verification_requests`, `moderation_permissions`, `moderation_scopes`, `user_engagement_scores`
- Related APIs:
  - current: `/api/admin/users/lists`, `/api/admin/users/:id`, `/api/admin/users/:id (PUT/DELETE)`, `/admin/users/:id/role`, `/api/admin/moderation/*`
  - target: `/api/admin/users`, `/api/admin/users/:id`, `/api/admin/users/:id/role`, `/api/admin/users/:id/moderation`, `/api/admin/users/bulk`
- UI layout:
  - left: searchable/paginated user table
  - right: user detail drawer with tabs (`Profile`, `Verification`, `Role & Scope`, `Audit`)

## 3) Content Moderation

- Purpose:
  - Moderate feed/story content with consistent workflows.
- Actions:
  - Review, delete, bulk delete, restore (if soft-delete enabled), reason tagging, escalation.
- Related tables:
  - legacy: `posts`, `stories`, `filtre`, `audit_log`
  - modern: `posts`, `stories`, `blocked_terms`, `audit_logs`
- Related APIs:
  - current: `/api/new/admin/posts`, `/api/new/admin/stories`, `/api/new/admin/filters`
  - target: `/api/admin/moderation/posts`, `/api/admin/moderation/stories`, `/api/admin/moderation/blocked-terms`
- UI layout:
  - queue-first layout: filter bar + moderation table + preview drawer + bulk action bar.

## 4) Messaging & Safety

- Purpose:
  - Moderate chat/direct messages and manage abuse-prevention terms.
- Actions:
  - Inspect/delete chat and inbox messages, tune blocked terms, apply moderation notes.
- Related tables:
  - legacy: `chat_messages`, `gelenkutusu`, `filtre`, `audit_log`
  - modern: `live_chat_messages`, `direct_messages`, `blocked_terms`, `audit_logs`
- Related APIs:
  - current: `/api/new/admin/chat/messages`, `/api/new/admin/messages`, `/api/new/admin/filters`
  - target: `/api/admin/safety/chat`, `/api/admin/safety/direct-messages`, `/api/admin/safety/terms`
- UI layout:
  - split view: queue list + message preview pane + safety controls side panel.

## 5) Groups / Events

- Purpose:
  - Group/event governance and community-level operations.
- Actions:
  - Review/delete groups, moderate group posts/events/announcements, approve/reject event/announcement items.
- Related tables:
  - legacy: `groups`, `group_members`, `group_events`, `group_announcements`, `events`, `announcements`
  - modern: same names (modernized schema already aligned for these domains)
- Related APIs:
  - current: `/api/new/admin/groups`, `/api/new/events`, `/api/new/announcements`
  - target: `/api/admin/groups`, `/api/admin/group-events`, `/api/admin/events`, `/api/admin/announcements`
- UI layout:
  - master list + entity inspector + “related entities” tab (members, posts, pending requests).

## 6) Notifications

- Purpose:
  - Operational notifications and request queues (not end-user bell feed).
- Actions:
  - Review support request categories, process pending requests, monitor queue SLA, trigger follow-up actions.
- Related tables:
  - legacy: `member_requests`, `request_categories`, `verification_requests`
  - modern: `support_requests`, `support_request_categories`, `identity_verification_requests`
- Related APIs:
  - current: `/api/new/admin/requests/notifications`, `/api/new/admin/requests`, `/api/new/admin/verification-requests`
  - target: `/api/admin/notifications/queues`, `/api/admin/notifications/requests`, `/api/admin/notifications/verification`
- UI layout:
  - queue board (pending/in-review/resolved) + detail drawer with payload + decision actions.

## 7) Settings

- Purpose:
  - Product-level admin configuration (site access, modules, media, email templates/categories).
- Actions:
  - Update site/module controls, media settings and connectivity tests, manage email categories/templates.
- Related tables:
  - legacy: `site_controls`, `module_controls`, `media_settings`, `email_kategori`, `email_sablon`
  - modern: `site_settings`, `module_settings`, `media_settings`, `email_categories`, `email_templates`
- Related APIs:
  - current: `/api/admin/site-controls`, `/api/admin/media-settings`, `/api/admin/email/*`
  - target: `/api/admin/settings/site`, `/api/admin/settings/modules`, `/api/admin/settings/media`, `/api/admin/settings/email/*`
- UI layout:
  - settings forms with section cards, inline validation, diff preview, and guarded save flow.

## 8) System

- Purpose:
  - High-risk operational tooling, logs, audits, backups, diagnostics.
- Actions:
  - View filtered audit logs, inspect system logs, create/download backups, controlled restore, DB diagnostics.
- Related tables:
  - legacy: `audit_log`, runtime DB metadata tables
  - modern: `audit_logs`, `schema_migrations`, `jobs`
- Related APIs:
  - current: `/api/admin/logs`, `/api/new/admin/db/*`
  - target: `/api/admin/system/audit`, `/api/admin/system/logs`, `/api/admin/system/backups`, `/api/admin/system/db-inspect`
- UI layout:
  - warnings-first page, explicit permission gates, double-confirmations for restore/destructive operations.

## Frontend Refactor Plan (Module Split)

- Replace monolith `frontend-modern/src/pages/AdminPage.jsx` with:
  - `frontend-modern/src/pages/admin/AdminShellPage.jsx`
  - `frontend-modern/src/pages/admin/sections/DashboardSection.jsx`
  - `frontend-modern/src/pages/admin/sections/UsersSection.jsx`
  - `frontend-modern/src/pages/admin/sections/ContentModerationSection.jsx`
  - `frontend-modern/src/pages/admin/sections/MessagingSafetySection.jsx`
  - `frontend-modern/src/pages/admin/sections/GroupsEventsSection.jsx`
  - `frontend-modern/src/pages/admin/sections/NotificationsSection.jsx`
  - `frontend-modern/src/pages/admin/sections/SettingsSection.jsx`
  - `frontend-modern/src/pages/admin/sections/SystemSection.jsx`
- Shared admin infra:
  - `frontend-modern/src/admin/api/adminClient.js`
  - `frontend-modern/src/admin/hooks/useAdminQueryState.js`
  - `frontend-modern/src/admin/components/AdminDataTable.jsx`
  - `frontend-modern/src/admin/components/AdminFilterBar.jsx`
  - `frontend-modern/src/admin/components/AdminDetailDrawer.jsx`
  - `frontend-modern/src/admin/components/AdminBulkActionsBar.jsx`
  - `frontend-modern/src/admin/components/AdminSidebar.jsx`
- CSS split:
  - keep `frontend-modern/src/admin.css` as entry import
  - add `frontend-modern/src/admin/layout.css`
  - add `frontend-modern/src/admin/table.css`
  - add `frontend-modern/src/admin/forms.css`
  - add `frontend-modern/src/admin/sections/*.css`

## Backend Refactor Guardrails (for next phases)

- Standardize admin route namespace to `/api/admin/*` (keep temporary aliases for compatibility).
- Introduce route-level policy middleware:
  - `requireRole(minRole)`
  - `requireModerationPermission(key)`
  - `requireCohortScope(entityResolver)` for mod-scoped actions
- Enforce root invariants globally:
  - root excluded from all regular member lists/search results
  - root never targetable for impersonation or destructive operations
- Add canonical audit log writer for every admin mutation with consistent event schema.
- Move list endpoints to shared pagination/filter contract:
  - `page`, `limit`, `sort`, `q`, `filters`, and `meta`.

## Delivery Sequence

1. Stabilize API contracts + policy middleware and audit coverage.
2. Introduce modular admin shell and shared table/filter/query-state primitives.
3. Migrate sections one-by-one behind existing `/new/admin` route.
4. Remove dead admin UI/components and deprecate legacy-only admin tabs.
5. Final pass: performance indexes, payload minimization, and security hardening.

