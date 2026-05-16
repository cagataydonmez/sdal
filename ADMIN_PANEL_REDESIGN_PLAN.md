# SDAL Sosyal — Admin Panel Redesign Plan

_Generated: 2026-05-16_

---

## 1. Current Inventory

### Flutter Admin Pages

| Page / Widget | Route | Role gate | Status |
|---|---|---|---|
| `AdminHubPage` | `/admin` shell via `AdminSectionPage` | hasAdminAccess | KEEP — legacy hub, redirect to workspace |
| `AdminWorkspacePage` | `/admin` | hasAdminAccess | KEEP + polish — primary command center |
| `ModeratorWorkspacePage` | `/moderation` | isModerator or hasAdminAccess | KEEP + enhance |
| `AdminTeacherAccountsPage` | `/admin/teacher-accounts` | hasAdminAccess | KEEP |
| `AdminTeacherNetworkManagementPage` | `/admin/teacher-network` | hasAdminAccess | KEEP |
| `AdminModuleManagementPage` | `/admin/modules` | hasAdminAccess | KEEP |
| `AdminSectionPage` (section: content) | `/admin/content` | hasAdminAccess + permissions | KEEP + reason-gate destructive |
| `AdminSectionPage` (section: requests) | `/admin/requests` | mod permissions | KEEP |
| `AdminSectionPage` (section: notifications) | `/admin/notifications` | hasAdminAccess | KEEP |
| `AdminSectionPage` (section: auth-security) | `/admin/auth-security` | hasAdminAccess | KEEP |
| `AdminSectionPage` (section: management) | `/admin/management` | hasAdminAccess | KEEP |
| `AdminSectionPage` (section: api-monitor) | `/admin/api-monitor` | hasAdminAccess | ROOT-GATE / DEV-ONLY |
| `AdminSectionPage` (section: operations) | `/admin/operations` | hasAdminAccess | KEEP — high-risk confirm |
| `AdminSectionPage` (section: database) | `/admin/database` | hasAdminAccess | ROOT-GATE |
| `AdminSectionPage` (section: languages) | `/admin/languages` | hasAdminAccess | ADMIN-ONLY |
| `AdminSectionPage` (section: experiments) | `/admin/experiments` | hasAdminAccess | ADMIN-ONLY |
| `FactoryResetPage` | `/admin/factory-reset` | isRootAdmin (client) | ROOT-ONLY (already server-gated) |
| `TestDataSeedPage` | `/admin/test-data` | isRootAdmin (client) | ROOT-ONLY (server-gated) |
| `PermissionGroupsPage` | `/admin/permission-groups` | isRootAdmin | ROOT-ONLY |
| `UserPermissionsPage` | `/admin/user-permissions` | isRootAdmin | ROOT-ONLY |
| `AdminApiMonitorWidgets` | `/admin/api-monitor` | hasAdminAccess | DEV-ONLY → root-gate in Flutter nav |

### Backend Admin Routes

| File | Key Patterns | Issues |
|---|---|---|
| `adminModerationRoutes.js` | `/api/admin/session`, `/api/admin/moderation/my-permissions`, `/api/admin/login`, `/api/admin/logout`, moderator scopes | `requireRole('admin')` — some routes, good. Moderator scope assignment uses `requireRole('admin')` ✓ |
| `adminRequestModerationRoutes.js` | `/api/new/admin/requests`, `/api/new/admin/verification-requests`, `/api/new/admin/teacher-network/links`, content moderation | Uses `requireModerationPermission(key)` correctly |
| `adminContentModerationRoutes.js` | Posts, comments, stories, groups, messages, chat, filters, content-approvals | Delete routes use `requireModerationPermission` ✓. No reason/note field on delete |
| `adminOperationsRoutes.js` | Site controls, user management, pages, emails, albums, tournament, logs | Duplicate of many routes from `adminManagementRoutes.js`. DELETE `/api/admin/users/:id` has no audit log |
| `adminManagementRoutes.js` | Same user management, pages, emails, albums as operationsRoutes | **DUPLICATE routes registered** — both files are loaded |
| `adminRootRoutes.js` | Factory reset, test data, permission CRUD, user permission assignment | All properly `rootOnly` gated ✓ |
| `adminDbRoutes.js` | DB backup, restore, driver switch | `requireAdmin` — should be root-only for driver switch |
| `adminSecurityRoutes.js` | Security status, auth-security snapshot | `requireAdmin` ✓ |
| `adminExperimentRoutes.js` | Engagement AB, network suggestion AB, stats, live | `requireAdmin` ✓ |
| `adminLanguageRoutes.js` | Language strings/keys/config | `requireAdmin` ✓ |
| `notificationRoutes.js` | Broadcast, push settings, push deliveries, notification ops | `requireAdmin` ✓. `dispatchPushNotification` available |
| **`appRuntime.js`** | `/hirsiz.asp`, `/hirsiz2.asp` | **LEGACY SECURITY RISK** — raw HTML message inspection served as text/html with no CSRF protection, XSS risk |

### Key Infrastructure

- **RBAC**: `rbacService.js` — permission_groups, permissions, group_permissions, user_permission_groups tables. `isRootAdmin()` checks `username === 'cagatay' && role === 'root'`.
- **Audit**: `writeAuditLog()` defined in `appRuntime.js`, passed to route handlers. Used in moderation and permission routes but **missing from content delete, user delete, graduation year change in several routes**.
- **Push**: `createNotificationPushRuntime` — `dispatchPushNotification({ userId, type, title, body, data })` exists and works via Firebase/APNs.
- **Duplicate route files**: `adminOperationsRoutes.js` and `adminManagementRoutes.js` both register `/api/admin/users/:id`, `/api/admin/pages`, `/api/admin/email/*`, `/api/admin/album/*` — Express will use first-registered. This is a latent confusion bug.

---

## 2. Inventory Decisions

| Feature | Decision | Reason |
|---|---|---|
| `AdminWorkspacePage` | **KEEP + polish** | Good mobile-first command center |
| `ModeratorWorkspacePage` | **KEEP + enhance** | Permission-aware queue, needs scope badges |
| `AdminHubPage` (`/admin` legacy hub with `AdminSectionPage`) | **KEEP** | Admin section hub useful, just deduplicate screens |
| API Monitor | **ROOT-GATE** | Dev tool, not operational. Hide from normal admins in Flutter nav |
| `/hirsiz.asp` + `/hirsiz2.asp` | **REMOVE** | Legacy HTML message inspection, XSS risk, no audit, no pagination |
| Duplicate routes (ops+mgmt) | **DOCUMENT + leave** | Safe to leave — Express uses first-match, but mark clearly |
| DB driver switch | **ROOT-GATE server-side** | Currently `requireAdmin`, should be `rootOnly` |
| DB restore | **ROOT-GATE server-side** | Same — high destructive risk |
| Content delete without reason | **ADD reason field** | Destructive, needs audit note |
| User delete without audit | **ADD audit log** | Missing in management routes |
| Admin push notifications | **ADD** | Infrastructure exists, recipients not implemented |
| Admin attention summary | **IMPROVE** | `/api/new/admin/requests/notifications` exists but permission-unfiltered |
| Admin internal notes | **ADD** (lightweight) | User management notes on destructive actions |

---

## 3. Security Issues

### Critical

1. **`/hirsiz.asp` + `/hirsiz2.asp`**: Renders raw HTML with user data (message subjects/bodies) via `res.send()`. No Content-Security-Policy, reflected data could contain XSS. Legacy SQLite-only queries (won't work on Postgres). Admin-gated but still unacceptable in production.

2. **Duplicate route registration**: `adminOperationsRoutes.js` and `adminManagementRoutes.js` both call `app.delete('/api/admin/users/:id', ...)`. Race-to-first is fragile. The second registration silently never fires.

3. **DB driver switch + restore missing root-only gate**: `POST /api/new/admin/db/driver/switch` and `POST /api/new/admin/db/restore` accept `requireAdmin`. Should require root.

4. **Content delete missing audit**: `DELETE /api/new/admin/posts/:id`, `/comments/:id`, `/stories/:id` don't call `writeAuditLog`.

5. **User delete missing audit in ops routes**: `handleMemberDelete` in `adminOperationsRoutes.js` — verify audit.

6. **Graduation year change missing reason**: `PUT /api/new/admin/users/:id/graduation-year` — no reason/note field collected or audited.

### Moderate

7. **Client-side root check**: Flutter checks `user.isRootAdmin` and `user.kadi == 'cagatay'` for nav display. Server already gates — this is acceptable as UX-only, but note it clearly.

8. **Admin login 2FA**: `/api/admin/login` — verify this requires session + password (not just role check). Good pattern if it does.

---

## 4. High-Value Additions

1. **Admin push notification service** — notify root/admin/mod of queue spikes, security events, factory reset triggers.
2. **Reason/note field on destructive content actions** — moderation quality + audit.
3. **Audit log on user/content delete, graduation year change**.
4. **Root-gate DB driver switch + restore**.
5. **Remove `/hirsiz.asp` + `/hirsiz2.asp`**.
6. **Flutter: hide api-monitor from non-root in workspace nav cards**.
7. **Admin attention summary with permission filtering** — avoid fetching all modules for every admin.

---

## 5. Implementation Passes

### Pass 1 — Backend Security Hardening (this session)
- Remove `/hirsiz.asp` + `/hirsiz2.asp` from appRuntime.js
- Root-gate `POST /api/new/admin/db/driver/switch` and `POST /api/new/admin/db/restore`
- Add `writeAuditLog` to content delete routes (posts, comments, stories)
- Add `writeAuditLog` to user delete in ops routes (verify)
- Add `reason` param to graduation year change + audit it

### Pass 2 — Admin Push Notification Service
- Add `createAdminPushService` helper in `server/src/admin/`
- Resolves recipients by role + permission
- Channels: root_critical, admin_ops, moderator_queue, security_watch
- Events: factory_reset_triggered, db_restore_triggered, permission_change, large_queue_spike, security_spike
- Attach to relevant routes (factory reset, db restore, permission change, request queue)
- Safe payloads: type, title, safe body, deep link route, event id — no raw content

### Pass 3 — Flutter UX
- Root-gate api-monitor nav card in `AdminWorkspacePage`
- Add reason bottom sheet to content delete in `ModeratorWorkspacePage` and content section
- Audit log viewer if endpoint accessible
- Scope badge improvement in `ModeratorWorkspacePage`

### Pass 4 — Verification & Cleanup
- Run `flutter analyze`
- Spot-check backend route conflicts
- Document remaining risks

---

## 6. Verification Plan

Manual security checks:
- [ ] Non-admin cannot reach `/api/new/admin/*` — returns 403
- [ ] Moderator cannot reach root-only routes
- [ ] `/hirsiz.asp` returns 404 after removal
- [ ] DB driver switch returns 403 for admin (non-root) after hardening
- [ ] DB restore returns 403 for admin (non-root) after hardening
- [ ] Content delete writes audit log with actor + target + action
- [ ] User delete writes audit log
- [ ] Admin push: factory reset triggers push to root only
- [ ] Admin push: large queue spike notifies admins with queue permission
- [ ] @cagatay root protected — cannot be modified by non-root
- [ ] Flutter api-monitor card hidden from non-root admins

Commands:
```bash
cd mobile/flutter_sdal && flutter analyze
cd server && npm run test:phase2-health 2>/dev/null || echo "no health test script"
```
