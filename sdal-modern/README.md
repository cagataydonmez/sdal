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

## Notes
- Legacy images are served from `client/public/legacy`.
- `.asp` URLs are redirected to modern routes.
- Email features (activation/password) use SMTP if configured:
  - `SMTP_HOST`, `SMTP_PORT`, `SMTP_USER`, `SMTP_PASS`, `SMTP_FROM`
  - `SDAL_BASE_URL` for activation links (defaults to `http://localhost:8787`)
