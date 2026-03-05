# SDAL Database Migration Runbook (Phase 3)

This document defines the Phase 3 migration workflow:
1. Create modern PostgreSQL schema via numbered migrations.
2. Run one-time SQLite -> modern PostgreSQL data migration.
3. Validate row parity + FK integrity.
4. Cut over runtime configuration.
5. Roll back safely if needed.

## Prerequisites

- PostgreSQL is running and reachable by `DATABASE_URL`.
- Legacy SQLite file exists (`db/sdal.sqlite` or your production snapshot).
- Backup location is writable.

## New Migration System

- SQL migrations: `server/migrations/*.up.sql` and `*.down.sql`
- Runner: `server/scripts/migrate.mjs`
- Migration tracking table: `schema_migrations`

## Available Commands

From repo root:

```bash
npm --prefix server run migrate:status
npm --prefix server run migrate:up
npm --prefix server run migrate:down -- --steps 1
npm --prefix server run migrate:down -- --to 001_modern_schema
npm --prefix server run migrate:data
```

## Step-by-Step: Pre-Cutover (Recommended)

1. Export current env for migration session:

```bash
export DATABASE_URL='postgresql://sdal_app:CHANGE_ME@127.0.0.1:5432/sdal_prod'
export SQLITE_PATH='/absolute/path/to/sdal.sqlite'
```

2. Create backup folder + timestamp:

```bash
mkdir -p backups
TS="$(date +%Y%m%d-%H%M%S)"
```

3. Backup SQLite source:

```bash
cp "$SQLITE_PATH" "backups/sqlite-precutover-$TS.sqlite"
```

4. Backup PostgreSQL target before schema/data migration:

```bash
pg_dump "$DATABASE_URL" -Fc -f "backups/postgres-precutover-$TS.dump"
```

5. Check migration status:

```bash
npm --prefix server run migrate:status
```

6. Apply modern schema migration(s):

```bash
npm --prefix server run migrate:up
```

7. Run one-time SQLite -> modern PostgreSQL transfer:

```bash
npm --prefix server run migrate:data -- --sqlite "$SQLITE_PATH" --report "./migration_report.json"
```

## Validation Checklist (Mandatory)

1. Review migration report:

```bash
cat migration_report.json
```

2. Confirm:
- `summary.mismatchCount == 0`
- `summary.fkViolationCount == 0`
- no table-level count mismatches in `mismatches[]`

3. Spot-check critical tables:

```bash
psql "$DATABASE_URL" -c "SELECT COUNT(*) FROM users;"
psql "$DATABASE_URL" -c "SELECT COUNT(*) FROM posts;"
psql "$DATABASE_URL" -c "SELECT COUNT(*) FROM conversation_messages;"
psql "$DATABASE_URL" -c "SELECT COUNT(*) FROM identity_verification_requests;"
```

4. Run app smoke contracts against migrated DB config (recommended in maintenance window).

## Production Cutover

After validation passes:

1. Update runtime env:

```bash
# in server/.env (or your secret manager)
SDAL_DB_DRIVER=postgres
DATABASE_URL=postgresql://sdal_app:CHANGE_ME@127.0.0.1:5432/sdal_prod
```

2. Restart service/process manager.

3. Verify health:

```bash
curl -s http://127.0.0.1:8787/api/health | jq
```

Expected: `dbDriver=postgres`, `dbReady=true`.

## Rollback Strategy

## Trigger Rollback If

- Any FK integrity violation appears in `migration_report.json`
- Any major row-count mismatch in critical tables (`users`, `posts`, `conversation_messages`)
- Critical endpoint regressions after cutover

## Rollback Steps

1. Switch runtime back to SQLite:

```bash
# in server/.env
SDAL_DB_DRIVER=sqlite
SDAL_DB_PATH=/absolute/path/to/your/known-good.sqlite
```

2. Restart app service.

3. If PostgreSQL must be reverted to pre-cutover state:

```bash
pg_restore --clean --if-exists -d "$DATABASE_URL" "backups/postgres-precutover-$TS.dump"
```

4. Re-run API smoke checks.

## Migrations in This Phase

- `server/migrations/001_modern_schema.up.sql`
- `server/migrations/001_modern_schema.down.sql`

## One-Time Data Migration Tool

- `server/scripts/migrate-legacy-sqlite-to-modern-postgres.mjs`
- Writes report to `migration_report.json` by default (repo root).

## Notes

- The migrator preserves legacy numeric IDs where possible to keep relationship mapping deterministic.
- `conversation_members` is synthesized from legacy `sdal_messenger_threads` participants.
- Sequence synchronization is performed after import for identity-backed tables.
