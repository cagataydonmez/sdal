---
paths:
  - "server/migrations/**"
  - "server/db.js"
  - "server/scripts/*migrate*"
  - "server/scripts/db-sync.mjs"
  - "server/scripts/sqlite-runtime-schema.mjs"
---

# Database Rules

- Pair every new migration with `.up.sql` and `.down.sql`.
- Run `npm --prefix server run migrate:verify` after migration edits.
- Consider SQLite and Postgres compatibility unless the task is explicitly scoped.
- Do not inspect or modify `db/sdal.sqlite*` casually.
- Include rollback/data-loss risk and check affected backend queries/client API impact.
