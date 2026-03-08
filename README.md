# SDAL (Social Directory Application Layer)

This is the backend and frontend monolithic setup for SDAL.

## Development Stack (Context7 Baseline)

- Runtime: Node.js 20+
- Primary DB: PostgreSQL (SQLite kept for legacy import/fallback workflows)
- Frontend: React + Vite (`frontend-classic`, `frontend-modern`)
- Optional frontend path: Next.js can be added on top of existing `/api/*` contracts

## Shared Design Tokens (Web + iOS + Android)

- Canonical source: `design/tokens/sdal.tokens.json`
- Sync command: `npm run tokens:sync`
- Generated outputs:
  - `frontend-modern/src/generated/design-tokens.css`
  - `ios-native/SDALNative/UI/Generated/SDALDesignTokens.generated.swift`
  - `android-native/theme/SDALDesignTokens.kt`

Quick local bootstrap:

```bash
docker compose up -d postgres redis
npm --prefix server ci
npm --prefix server run migrate:up
npm --prefix server run start
```

## Backend Media Pipeline (Feb 2026 update)

The image upload pipeline now supports:
- Automatic WebP conversion and EXIF metadata stripping
- Generation of 3 variants: `thumb` (200px), `feed` (800px), and `full` (1600px)
- Local filesystem or DigitalOcean Spaces (S3) storage abstraction
- Configuration via the Admin Panel under the **"Medya Depolama"** tab

### Spaces/S3 Configuration

To use an S3-compatible object storage provider like DO Spaces, add the following to your `server/.env`:

```env
SPACES_KEY=your_access_key
SPACES_SECRET=your_secret_key
SPACES_BUCKET=your_bucket_name
SPACES_REGION=fra1
SPACES_ENDPOINT=https://fra1.digitaloceanspaces.com
SPACES_CDN_BASE=https://your-custom-cdn.com # Optional
```

Then go to the Admin Panel -> Sistem -> Medya Depolama, switch the provider to "Spaces", and test the connection.

### Migration Scripts

Two template scripts are available in `server/scripts/`:
- `migrate-to-spaces.mjs`: For moving existing local `/uploads/images` files to Spaces.
- `orphan-cleanup.mjs`: For finding old variant files that no longer have a database record.
