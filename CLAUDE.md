# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

SDAL (Social Directory Application Layer) is a social networking platform for professional communities (teachers, mentors, job seekers). It is a monorepo with a Node.js/Express backend serving two React frontends (modern and classic) plus iOS/Android native apps via Capacitor.

## Common Commands

All commands assume you are in the repo root unless otherwise noted.

### Development

```bash
# Start backend dev server (port 8787)
npm --prefix server run dev

# Start modern frontend dev server (port 5174, proxies /api → localhost:8787)
npm --prefix frontend-modern run dev

# Start classic frontend dev server
npm --prefix frontend-classic run dev
```

### Build

```bash
# Build both frontends
npm run build

# Build individual frontend
npm --prefix frontend-modern run build
npm --prefix frontend-classic run build
```

### Database Migrations

```bash
npm --prefix server run migrate:up       # Apply pending migrations
npm --prefix server run migrate:down     # Rollback last migration
npm --prefix server run migrate:status   # Show migration state
npm --prefix server run migrate:verify   # Sanity check
```

### Running Tests

Tests are contract-driven Node.js scripts (not Jest/Mocha). The server must be running before executing tests.

```bash
npm --prefix server run test:phase1-contracts
npm --prefix server run test:phase2-health
npm --prefix server run test:phase2-opportunity-inbox
npm --prefix server run test:phase2-connections
npm --prefix server run test:phase2-notifications
npm --prefix server run test:phase5-performance
npm --prefix server run test:phase6-realtime-jobs
npm --prefix server run test:phase7-media-hardening
npm --prefix server run test:phase9-email
```

### Infrastructure (Docker)

```bash
docker-compose up -d     # Start PostgreSQL 16 and Redis 7
docker-compose down
```

### Design Tokens

```bash
npm run tokens:sync      # Sync shared design tokens across web/iOS/Android
```

## Architecture

### Backend (`server/`)

- **Entry point**: `server/index.js` → imports from `server/appRuntime.js`
- **App setup**: `server/appRuntime.js` (~2000 lines) — registers all middleware and 22+ route modules
- **Database abstraction**: `server/db.js` — unified API for both PostgreSQL and SQLite

**Startup sequence**: load env → create Express app → start HTTP server → `onServerStarted()` (migrations, cache warm-up) → attach WebSocket servers.

**Dual-database driver**: Set via `SDAL_DB_DRIVER=sqlite|postgres` or auto-detected from `DATABASE_URL`. SQLite uses synchronous API (`sqlGet`, `sqlAll`, `sqlRun`); PostgreSQL uses async API (`sqlGetAsync`, `sqlAllAsync`, `sqlRunAsync`, `pgQuery`). New routes should use the async API.

**Route organization** (`server/routes/`): 22 domain-scoped modules registered in `appRuntime.js`. Route files for admin are prefixed `admin*`, user-facing routes are named by domain (profileSelfService, teacherNetwork, storyRoutes, etc.).

**Middleware** (`server/middleware/`): presence tracking, request logging, session (Redis-backed, in-memory fallback), static uploads.

**Infrastructure services** initialized in `appRuntime.js`:
- Redis: sessions, rate-limit state, versioned cache namespaces, pub/sub
- Image pipeline: Sharp, WebP conversion, three variants (thumb/feed/full)
- WebSocket runtime: chat and realtime notifications
- Background job queue (namespaced)
- Mail sender: SMTP or Resend API (mock in dev)
- Idempotency middleware: deduplicates POST requests by key

### Frontend (`frontend-modern/`, `frontend-classic/`)

- React 18 + React Router 6 + Vite
- Modern frontend base path: `/new/`
- Dev proxy: `/api` and `/uploads` → `http://localhost:8787`
- iOS/Android: Capacitor 8 wraps `frontend-modern`

### Database Migrations (`server/migrations/`)

SQL files only. Seven sequential migrations (001–007) covering schema creation, seed data, indexes, and a PostgreSQL-to-legacy compatibility layer (`004_phase6_legacy_sql_compat.up.sql`).

Migration scripts for data transfer live in `server/scripts/` (e.g., `migrate-legacy-sqlite-to-modern-postgres.mjs`).

### Environment Configuration

Copy `server/.env.example` to `server/.env`. Key variables:

| Variable | Purpose |
|---|---|
| `SDAL_DB_DRIVER` | `sqlite` or `postgres` |
| `DATABASE_URL` | PostgreSQL connection string |
| `REDIS_URL` | Redis connection string |
| `SDAL_SESSION_SECRET` | Session signing key |
| `STORAGE_PROVIDER` | `local` or `s3` |
| `MAIL_PROVIDER` | `mock`, `smtp`, or `resend` |

Cache TTLs, rate limits, upload quotas, and OAuth credentials are all configured via env vars — see `.env.example` for full schema.

## Key Patterns

- **Async/await**: All new route handlers should use async/await with `sqlGetAsync`/`sqlAllAsync`/`sqlRunAsync`. Older routes may still use synchronous SQLite calls.
- **Rate limiting**: Applied per endpoint type in `appRuntime.js` (login, chat, posts, comments, uploads, connection/mentorship requests).
- **Idempotency**: POST-heavy endpoints (post creation, chat send) use idempotency middleware to prevent duplicate submissions.
- **Versioned cache namespaces**: Feed, profile, stories, and admin settings each have their own cache namespace for targeted invalidation.
- **Image uploads**: Always go through the media pipeline (multer → validation → Sharp → WebP → variant storage → DB record).
