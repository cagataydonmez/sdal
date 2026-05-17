---
paths:
  - "server/**"
---

# Backend Rules

- Search first; do not scan all of `server`.
- Start at `server/appRuntime.js` only to locate route registration, then inspect focused route/service/repository files.
- Before changing API contracts, search `mobile/flutter_sdal/lib` and `frontend-modern/src` for endpoint and field usage.
- Treat auth/session, uploads/media, admin permissions, and `server/db.js` as fragile.
- Prefer targeted `npm --prefix server run test:*` checks and `npm --prefix server run migrate:verify` for migration-related changes.
