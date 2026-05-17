---
name: sdal-db-migration
description: Use for SDAL database schema, SQL migrations, SQLite/Postgres compatibility, migration runner, data migration/sync scripts, rollback planning, and query-impact analysis.
---

# SDAL DB Migration

## When To Use
- Schema changes, SQL migrations, data backfills, DB scripts, query compatibility, SQLite/Postgres behavior.

## Workflow
1. Restate schema/data objective and affected features.
2. Inspect existing migration numbering and latest files.
3. Read affected queries/routes/services before SQL edits.
4. Consider both Postgres and SQLite unless explicitly scoped.
5. Create paired `.up.sql` and `.down.sql` when adding migrations.
6. Include rollback and data-loss risk analysis.
7. Check Flutter/React API impact when relevant.
8. Run migration sanity check and targeted backend tests.

## Search Strategy
- List latest migration files, then `rg` table/column/query fragments in backend and clients.

## Inspect Areas
- `server/migrations/*.up.sql`, `*.down.sql`.
- `server/scripts/migrate.mjs`, `check-migrations-sanity.mjs`, `sqlite-runtime-schema.mjs`.
- `server/db.js` and affected backend files.

## Safety Rules
- Do not inspect or modify `db/sdal.sqlite*` casually.
- Do not run production migrations without approval.
- Avoid irreversible migrations unless explicitly accepted.

## Validation
- `npm --prefix server run migrate:verify`
- Affected contract test.
- Full up/down requires disposable DB; mark `UNVERIFIED` if not run.

## Output Format
- Migration files, rollback plan, SQLite/Postgres note, checks, risks.
