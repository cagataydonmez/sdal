---
name: sdal-backend-change
description: Use for SDAL Node.js backend/API route changes, auth/session, admin APIs, uploads/media, notifications/mail/push, database access, or backend contract fixes.
---

# SDAL Backend Change

## When To Use
- Node/Express backend work under `server`.
- API routes, auth/session, admin APIs, upload/media, notifications, mail, push, DB access, or contract behavior.

## Workflow
1. Restate the backend objective and expected client impact.
2. Search first; do not scan entire repo.
3. Inspect route registration in `server/appRuntime.js` only as needed.
4. Read the specific route, service, repository, or infra section involved.
5. Before changing API contracts, search Flutter and React clients for endpoint and field usage.
6. Plan the smallest safe patch and avoid unrelated rewrites.
7. Run the narrowest backend check.
8. Report changed files, checks, and remaining risks.

## Search Strategy
- `rg -n "endpoint|field|function" server mobile/flutter_sdal/lib frontend-modern/src --glob '!**/node_modules/**' --glob '!**/*.g.dart' --glob '!**/*.freezed.dart'`
- `rg -n "register.*Routes|/api/path" server/appRuntime.js server/routes`
- Use `sed -n` for focused line ranges after locating symbols.

## Inspect Areas
- Entrypoints: `server/index.js`, `server/app.js`, `server/appRuntime.js`.
- Routes: `server/routes/*.js`.
- Auth/session: `server/src/auth`, `server/middleware/session.js`, `server/routes/oauthRoutes.js`, Flutter `core/session`.
- Uploads: `server/media/*`, `server/src/uploads/*`, `server/middleware/staticUploads.js`.
- Notifications/mail/push: `server/src/notifications/*`, `server/src/admin/adminPushService.js`, `server/src/infra/mailSender.js`.
- DB: `server/db.js`, `server/migrations`, affected queries.

## Safety Rules
- Do not rewrite unrelated routes/services.
- Do not change response shape without checking Flutter repositories and web call sites.
- Treat DB, migrations, auth/session, uploads, and admin permissions as fragile.

## Validation
- Prefer a specific script from `server/package.json`.
- Common checks: `npm --prefix server run test:phase2-health`, `npm --prefix server run migrate:verify`.

## Output Format
- Objective handled, files changed, client contract impact, checks, risks.
