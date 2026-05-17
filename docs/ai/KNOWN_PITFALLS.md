# Known Pitfalls

## Auth and Session
- Backend sessions use `express-session` with optional Redis in `server/middleware/session.js`.
- Flutter persists cookies in `mobile/flutter_sdal/lib/core/network/api_client.dart`.
- watchOS depends on the iOS bridge in `mobile/flutter_sdal/ios/Runner/WatchBridge.swift` and `mobile/flutter_sdal/ios/SdalWatch/Networking/WatchSessionManager.swift`.
- Changing cookie names, secure/sameSite settings, `/api/session`, login/logout payloads, or base URL handling can break mobile/watch login.

## API Contracts
- Flutter repositories call many `/api/*` and `/api/new/*` endpoints directly.
- Before changing backend response shapes, search `mobile/flutter_sdal/lib` and `frontend-modern/src` for endpoint and field names.
- Watch API parsing in `WatchAPIClient.swift` accepts several list wrapper keys but can still break on auth/base URL changes.

## Uploads and Media
- Upload root comes from `SDAL_UPLOADS_DIR` or default `../uploads` in `server/config/env.js`.
- Media settings may store local base path or Spaces provider data.
- `server/media/uploadPipeline.js` writes variants and DB `image_records`; failures attempt cleanup.
- Static upload serving and path traversal protections live in `server/appRuntime.js`, `server/middleware/staticUploads.js`, and `server/media/storageProvider.js`.
- Production path/permission mismatches can cause successful DB writes with missing files.

## Database and Migrations
- `server/db.js` normalizes some SQL between SQLite and Postgres; not all SQL is automatically portable.
- Migration files must be paired `.up.sql`/`.down.sql` and pass `npm --prefix server run migrate:verify`.
- `server/scripts/sqlite-runtime-schema.mjs` can matter for SQLite installs even when Postgres migrations pass.
- DB files in `db/` are local data, not docs. Do not inspect casually.

## Push, Mail, Notifications
- Firebase setup spans Flutter `main.dart`, `features/push_notifications`, backend `server/src/notifications`, and `server/src/admin/adminPushService.js`.
- Mail delivery uses `server/src/infra/mailSender.js` and template helpers.
- Push registration endpoints are under `/api/new/mobile/push/*`; check Flutter repository before changing.

## Localization
- `mobile/flutter_sdal/l10n.yaml` uses `app_tr.arb` as template and outputs generated files under `lib/l10n/generated`.
- Do not edit generated localization files directly.
- Missing ARB keys can break generated localization or runtime text.

## watchOS, Icons, Signing, TestFlight
- `mobile/flutter_sdal/ios/Runner.xcodeproj/project.pbxproj` contains watch target, embed watch content, signing, icon injection scripts, and notification extension settings.
- Watch icon backup/export folders show this area has had prior fixes; avoid binary/icon churn unless the task is specifically about watch packaging.
- Bundle IDs observed: `com.sdal.flutterSdal`, `com.sdal.flutterSdal.SdalWatch`, `com.sdal.flutterSdal.SdalNotificationExtension`.

## Deployment
- `ops/deploy-systemd.sh` runs `git reset --hard origin/$BRANCH` on the server checkout.
- Deploy writes systemd units when run as root and restarts services.
- Env defaults to `/etc/sdal/sdal.env` unless overridden by CI secret.
- Production health checks expect `/api/health` on `PORT` or `8787`.

## CI/CD
- Deploy validation installs server/frontends and builds both React apps.
- Android release workflow writes keystore/key.properties from secrets and publishes a prerelease.
- CI secrets and production SSH assumptions cannot be verified locally unless explicitly provided.
