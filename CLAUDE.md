# CLAUDE.md — AI Assistant Guide for SDAL

# RTK-First Workflow (Token Optimization)

## Core Rule
Always prefer RTK-filtered commands over built-in tools when exploring or reading code.

## Command Priority
Use these commands in order:

1. Search first:
   - `rtk grep "<pattern>" <path>`
   - `rg "<pattern>" <path>`

2. Discover structure:
   - `rtk ls <path>`
   - `rtk find <path>`

3. Read minimal content:
   - `rtk read <file>`
   - `head -n 200 <file>`
   - `tail -n 200 <file>`

4. Git context:
   - `rtk git status`
   - `rtk git diff`
   - `rtk git log -n 20`

## Strict Constraints
- NEVER read full files blindly
- NEVER scan entire repo with built-in tools
- ALWAYS narrow down with search first
- ALWAYS read only relevant sections

## Avoid
Avoid using:
- Built-in Read tool for large files
- Built-in Grep/Glob when RTK or rg is possible
- Commands that return excessive output

## Strategy
Correct workflow:
1. Search → find candidate files
2. Narrow results
3. Read only necessary parts

## Example Good Flow
```bash
rtk grep "processBlock" .
rtk read src/PluginProcessor.cpp

## Project Overview

SDAL (Social Directory Application Layer) is a Node.js/React monorepo for a social networking platform. It includes an Express backend, two React frontends (classic and modern), and native mobile stubs for iOS/Android.

**Stack**: Node.js 20+, Express 4, PostgreSQL 16, Redis 7, React 18 + Vite 5

---

## Repository Structure

```
sdal/
├── server/                  # Express API server (primary codebase)
├── frontend-modern/         # React + Vite + Capacitor (active frontend)
├── frontend-classic/        # React + Vite (legacy frontend)
├── ios-native/              # iOS native stub
├── android-native/          # Android native stub
├── design/tokens/           # Canonical design token source (JSON)
├── docs/                    # Architecture and deployment documentation (37 files)
├── ops/                     # Deployment and migration shell scripts
├── db/                      # SQLite database files (local dev)
├── uploads/                 # Local media file storage
├── docker-compose.yml       # PostgreSQL + Redis for local dev
├── ecosystem.config.cjs     # PM2 production config
└── railway.json             # Railway deployment config
```

### Server internals (`server/src/`)

```
server/src/
├── admin/            # Admin user management and moderation
├── auth/             # Authentication runtime and helpers
├── bootstrap/        # Domain layer initialization
├── domain/           # Domain entities
├── events/           # WebSocket event chat runtime
├── http/
│   ├── controllers/  # feedController, postController, chatController, authController, adminController
│   ├── dto/          # Legacy API mappers
│   └── middleware/   # idempotency.js, rateLimit.js
├── infra/            # Infrastructure: jobQueue, mailSender, cache, DB pools, realtime bus
├── networking/       # Network discovery and suggestions
├── notifications/    # Notification governance and delivery
├── opportunities/    # Opportunity inbox feature
├── realtime/         # WebSocket runtime
├── repositories/     # DB repository interfaces and legacy SQLite implementations
├── services/         # Business logic: authService, chatService, feedService, postService, etc.
├── shared/           # Shared utilities (httpError.js)
└── uploads/          # Upload security and media processing runtime
```

Key entry points:
- `server/index.js` — Main server entry
- `server/appRuntime.js` — Monolithic app bootstrap (large file, ~170KB)
- `server/worker.js` — Background job worker process
- `server/db.js` — Database abstraction layer (~19KB)

Route files live in `server/routes/` (22 files): auth, account, feed, groups, events, networking, notifications, admin moderation, stories, OAuth, etc.

---

## Development Workflows

### Local Setup

```bash
# Start infrastructure
docker compose up -d postgres redis

# Install and run server
npm --prefix server ci
npm --prefix server run migrate:up
npm --prefix server run start

# Run frontends (separate terminals)
npm --prefix frontend-modern run dev   # port 5174, proxies to :8787
npm --prefix frontend-classic run dev
```

### Environment Configuration

Copy `server/.env.example` to `server/.env`. Key variables:

| Variable | Default | Purpose |
|---|---|---|
| `PORT` | 8787 | Server port |
| `SDAL_DB_DRIVER` | `postgres` | `postgres` or `sqlite` |
| `DATABASE_URL` | — | PostgreSQL connection string |
| `REDIS_URL` | — | Redis connection string |
| `SESSION_SECRET` | — | Express session secret |
| `SPACES_KEY/SECRET` | — | S3/DO Spaces credentials |
| `SMTP_*/RESEND_*` | — | Email provider config |

### Database Migrations

```bash
cd server
npm run migrate:up        # Apply all pending migrations
npm run migrate:down      # Roll back last migration
npm run migrate:status    # Show migration state
npm run migrate:verify    # Sanity check migration artifacts
```

Migrations live in `server/migrations/` as numbered SQL pairs (`001-up.sql` / `001-down.sql`). Currently 7 migration files. **Always add up/down pairs when creating new migrations.**

### Design Tokens

The canonical source is `design/tokens/sdal.tokens.json`. Run this after editing tokens:

```bash
npm run tokens:sync
```

Outputs to:
- `frontend-modern/src/generated/design-tokens.css`
- `ios-native/SDALNative/UI/Generated/SDALDesignTokens.generated.swift`
- `android-native/theme/SDALDesignTokens.kt`

---

## Testing

Tests are integration-style **contract tests** that run against a live server. Run them from `server/`:

```bash
npm run test:phase2-health          # Health check (used in CI)
npm run test:phase1-contracts       # Core API contract
npm run test:phase2-connections     # Social connections
npm run test:phase2-mentorship      # Mentorship flows
npm run test:phase2-notifications   # Notification delivery
npm run test:phase2-opportunity-inbox
npm run test:phase5-performance     # Performance benchmarks
npm run test:phase6-realtime-jobs   # WebSocket + job queue
npm run test:phase7-media-hardening # Upload security
npm run test:phase9-email           # Email providers
# ... plus 6 more phase2-* test scripts
```

**CI only runs** `test:phase2-health` and `migrate:verify`. Run the narrowest relevant contract test to verify changes. There is no unit test framework — the contract tests are the source of truth.

---

## CI/CD

**File**: `.github/workflows/deploy.yml`
**Trigger**: Push to `main`, or manual dispatch

Pipeline stages:
1. **Validate**: Install server deps, run `test:phase2-health`, run `migrate:verify`
2. **Deploy**: SSH into DigitalOcean droplet, run `ops/deploy-systemd.sh`
3. **Health check**: Poll `GET /api/health` with 30 retries at 2s intervals

Required secrets: `DO_HOST`, `DO_USER`, `DO_SSH_KEY`, `DO_PORT`, `DO_APP_DIR`, `DO_ENV_FILE`

Production process manager: **PM2** via `ecosystem.config.cjs` (1 instance, 700MB max memory restart).

---

## Key Conventions

### Server

- ES Modules throughout (`"type": "module"` in `server/package.json`) — use `import`/`export`, not `require`.
- Route handlers are in `server/routes/`; business logic belongs in `server/src/services/`.
- HTTP errors should use `server/src/shared/httpError.js`.
- Rate limiting is configured per-endpoint via `server/src/http/middleware/rateLimit.js`.
- Idempotency keys are handled in `server/src/http/middleware/idempotency.js` — do not bypass this for mutating endpoints.
- Upload limits: **10MB per file**, **140 files/day per user**.
- Image uploads produce 3 WebP variants: `thumb` (200px), `feed` (800px), `full` (1600px). EXIF is stripped automatically.

### Database

- Primary driver: PostgreSQL 16. SQLite is legacy/fallback only (`SDAL_DB_DRIVER=sqlite`).
- All queries go through `server/db.js` or repository classes in `server/src/repositories/`.
- Use parameterized queries always — never string-interpolate user input into SQL.
- PostgreSQL pool: min 1, max 8 connections. Redis client is shared for sessions, cache, and pub/sub.

### Frontend

- **frontend-modern** is the active frontend. `frontend-classic` is legacy — avoid adding features there.
- `frontend-modern` base path is `/new/` and proxies API calls to `:8787`.
- Capacitor is configured for iOS deployment — keep Capacitor config (`capacitor.config.json`) in sync when changing `appId` or server URL.
- Use design tokens from `frontend-modern/src/generated/design-tokens.css` for all colors/spacing — do not hardcode values.

### No linting enforcement

There are no ESLint, Prettier, or pre-commit hook configs. Follow the style of the surrounding code. Use 2-space indentation and single quotes in JS files.

---

## Discovery Order (for AI assistants)

When exploring an unfamiliar area of the codebase:

1. `server/package.json` — available scripts and dependencies
2. `server/routes/` — find the relevant route file
3. `server/src/http/controllers/` — find the controller
4. `server/src/services/` — find the business logic
5. `server/db.js` or `server/src/repositories/` — understand the data layer
6. `server/migrations/` — understand the schema
7. `server/tests/contracts/` — find the relevant contract test

Do not load `appRuntime.js` in full — it is very large. Search for specific function names or patterns within it instead.

---

## Editing Rules

- Never load the whole repo without a strong reason.
- Read and summarize relevant files before editing.
- Prefer symbol-level reads and small targeted snippets.
- Reuse prior findings instead of re-reading the same file.
- Run the narrowest test or check that can verify the change.
- Mention commands run and any unverified risks in your response.

---

## Infrastructure Services

| Service | Role |
|---|---|
| PostgreSQL 16 | Primary database |
| Redis 7 | Sessions, cache, pub/sub, job queue |
| sharp | Server-side image processing (WebP conversion, resizing) |
| nodemailer | SMTP email delivery |
| Resend | Alternative email provider (set `RESEND_API_KEY`) |
| ws | WebSocket server for real-time chat and events |
| multer | Multipart upload handling |
| DigitalOcean Spaces | S3-compatible object storage (optional, configurable in admin panel) |

---

## Important Files

| File | Purpose |
|---|---|
| `server/appRuntime.js` | Monolithic app setup — very large, search rather than read whole |
| `server/db.js` | Database abstraction layer |
| `server/src/infra/` | Infrastructure singletons (pool, redis, cache, mail, jobs) |
| `docs/ARCHITECTURE.md` | System design overview |
| `docs/DEPLOY_UBUNTU.md` | Full Ubuntu production deployment guide |
| `server/.env.example` | All 129 environment variables with documentation |
| `PLAN.md` | Admin panel redesign plan |
| `RESTART_MODERN_PHASED_PLAN.md` | Feature implementation roadmap |
