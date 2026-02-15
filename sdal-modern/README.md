# SDAL Modern (Node + React)

## Overview
This is a modernized React + Node.js rewrite of the legacy SDAL classic ASP site. The UI keeps the legacy look (colors, tables, images) while the backend runs on Express with SQLite.

## Prereqs
- Node.js 18+ (or 20+)
- `sqlite3` CLI
- `mdbtools` (for one-time migration from Access `.mdb`)

## Install
```bash
npm install
npm --prefix client install
npm --prefix server install
```

## One-time DB migration (Linux)
```bash
./scripts/migrate-mdb-to-sqlite.sh
```

By default it reads `.mdb` files from `/Users/cagataydonmez/Desktop/SDAL` and writes `db/sdal.sqlite`.
You can override with env vars:
```bash
MDB_DIR=/path/to/mdbs OUT_DB=/path/to/sdal.sqlite ./scripts/migrate-mdb-to-sqlite.sh
```

## Run (dev)
```bash
npm run dev
```
- Client: http://localhost:5173
- Server: http://localhost:8787

## Run (prod)
```bash
npm run build
npm run start
```

## Production: Prevent Data Loss On Deploy
SQLite file must live on a **persistent volume**, not inside ephemeral container filesystem.

### 1) Configure persistent DB path
Set one of these environment variables in deploy platform:

```bash
SDAL_DB_PATH=/app/data/sdal.sqlite
# or
SDAL_DB_DIR=/app/data
```

If `/app/data` is a mounted volume (Railway Volume, Docker volume, etc.), deploys will not wipe users/posts.
Set uploads to same volume as well:
```bash
SDAL_UPLOADS_DIR=/app/data/uploads
```

### 2) Optional safety gates
```bash
# fail startup if db file does not already exist
SDAL_DB_REQUIRE_EXISTING=true

# one-time bootstrap copy (only used when target DB is missing)
SDAL_DB_BOOTSTRAP_PATH=../db/sdal.sqlite
```

### 3) Railway note
- Add a Volume in Railway and mount to `/app/data`.
- Set `SDAL_DB_PATH=/app/data/sdal.sqlite`.
- Set `SDAL_UPLOADS_DIR=/app/data/uploads`.
- Admin DB backups are stored under `/app/data/backups`.
- Redeploy.

## Backward Compatibility Strategy
- Keep schema evolution additive (`CREATE TABLE IF NOT EXISTS`, `ALTER TABLE ... ADD COLUMN`).
- Do not remove or rename old columns without migration compatibility layer.
- Continue using idempotent startup migrations (`ensureColumn`) for old databases.
- For legacy Access data, keep one-time importer:
  - `./scripts/migrate-mdb-to-sqlite.sh`

## Notes
- Legacy images are served from `client/public/legacy`.
- `.asp` URLs are redirected to modern routes.
- Email features (activation/password) use SMTP if configured:
  - `SMTP_HOST`, `SMTP_PORT`, `SMTP_USER`, `SMTP_PASS`, `SMTP_FROM`
  - `SDAL_BASE_URL` for activation links (defaults to `http://localhost:8787`)
