# SDAL Admin Panel Redesign Plan

## Discovery Summary
- Mobile app: Flutter/Riverpod/GoRouter under `mobile/flutter_sdal`. Admin entry is `/admin`, moderator entry is `/moderation`, both currently implemented in `features/admin`.
- Backend: Express/Node under `server`. Admin routes are split across moderation, operations, management, request moderation, content moderation, notifications, DB, language, security, and root routes.
- Auth/RBAC: existing roles are `user`, `mod`, `admin`, `root`; moderators can also receive per-resource keys in `moderator_permissions`.
- Data: both Postgres migrations and SQLite compatibility exist. Audit infrastructure exists (`audit_logs` / `audit_log` view) and admin mutations already get a coarse endpoint audit record.
- Existing mobile admin is functional but too broad for phone use: operational/database/language/experiment/API-monitor screens sit beside daily moderation/member tasks.

## Inventory
### Keep And Improve
- Admin home: keep, but reshape into a mobile command center with attention cards and permission-aware modules.
- Requests: keep member, verification, graduation-year, and teacher-network queues.
- Content moderation: keep posts, comments, stories, groups, messages, and content approval.
- Notifications/broadcasts: keep when push infrastructure is already enabled.
- User/member management: keep search/detail and add safer status/role actions.
- Auth security: keep as admin/root visibility only.

### Merge Or Simplify
- Split technical operations from daily admin work. Show module controls/settings only to broad admins, not moderators.
- Merge verification/member requests into one “Talepler” task area.
- Present moderation as one queue-first module, with deeper lists behind filters.

### Remove From Default Mobile Surface
- Database backup/restore/driver switching: root-only technical surface, not a default admin card.
- API monitor: developer support tool, not a primary admin feature.
- Experiments/engagement A/B: keep backend but remove from daily phone navigation.
- Language string management: keep backend/web use, omit from default mobile command center.
- Hard-delete member as a default action: replace with suspend/unsuspend and require reason.

### Rebuild Or Harden
- Authorization: centralize admin permissions and expose `/api/admin/permissions/me`.
- Sensitive actions: role/status/moderation changes must require a reason and write specific audit records.
- User status changes: add soft suspend/activate endpoint instead of relying on full profile edit or hard delete.
- Audit log: add a mobile-safe endpoint for authorized users.

### Add
- Permission catalog mapping existing roles/moderator keys into product permissions.
- Mobile-focused admin summary endpoint with attention items and module availability.
- Audit log endpoint with pagination and sanitized metadata.
- User role/status patch endpoints with privilege-escalation prevention and audit.
- Reusable Flutter admin widgets for cards, status chips, search/filter, permission gate, empty/error states, and confirm-reason sheets.

## Target Mobile IA
1. Komuta Merkezi: attention queue, quick actions, recent audit/activity where permitted.
2. Üyeler: search, status/role chips, user detail, suspend/unsuspend, role changes.
3. Moderasyon: requests, verification, posts/comments/stories/groups/messages based on permissions.
4. Bildirimler: broadcasts and push health for content/admin roles.
5. Denetim: audit log for root/admin/auditor-equivalent permission.
6. Ayarlar: only practical module/auth settings for admins; root-only technical tools remain behind explicit root routes.

## Implementation Pass
- Add a central backend permission module and wire it into runtime route registration.
- Add mobile-safe routes:
  - `GET /api/admin/permissions/me`
  - `GET /api/admin/mobile/summary`
  - `GET /api/admin/audit-log`
  - `PATCH /api/admin/users/:id/role`
  - `PATCH /api/admin/users/:id/status`
- Refactor Flutter `/admin` and `/moderation` entry screens to consume these routes and show permission-aware modules.
- Add focused reusable admin widgets under `features/admin/presentation/widgets`.
- Keep old deep admin section routes available for now, but remove noisy technical cards from the default mobile command center.

## Validation
- Run backend syntax/start check or narrow route tests where available.
- Run `dart format` on touched Flutter files.
- Run `flutter analyze` if environment allows.
- Manually verify non-admin and moderator permission behavior from route code.
