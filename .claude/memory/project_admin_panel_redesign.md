---
name: Admin Panel Redesign 2026-05-16
description: Security hardening, admin push notifications, and Flutter UX work done on the SDAL Sosyal admin panel
type: project
---

Admin panel security hardening and admin push notification service implemented on 2026-05-16.

**Why:** Production security audit found XSS-risk legacy routes, missing audit logs, overly-permissive DB endpoints, and no operational push notifications for root/admin/mod users.

**How to apply:** When touching admin routes or Flutter admin pages, build on these conventions:
- `logAdminAction` (which internally calls `writeAuditLog`) is the correct way to log admin actions — do not call `writeAuditLog` directly from routes.
- DB destructive endpoints (driver switch, restore) are now `requireRootAdmin` — do not revert to `requireAdmin`.
- `adminPushService` is instantiated in `appRuntime.js` after `dispatchPushNotification` is available; pass it to route files that need it.
- Content delete in moderator workspace now uses `_DeleteReasonSheet` bottom sheet — maintain this pattern for any new destructive actions.

**Key files changed:**
- `server/appRuntime.js` — removed hirsiz routes, import + instantiate adminPushService
- `server/src/admin/adminPushService.js` — NEW: permission-aware admin push service
- `server/routes/adminDbRoutes.js` — root-gated driver switch/restore, added adminPushService push
- `server/routes/adminRootRoutes.js` — added adminPushService push on factory reset and permission group changes
- `server/routes/adminOperationsRoutes.js` — added audit log to user delete, reason to grad year change
- `server/routes/adminManagementRoutes.js` — same as ops routes
- `mobile/.../admin_workspace_pages.dart` — root-gated api-monitor nav card, added _DeleteReasonSheet
