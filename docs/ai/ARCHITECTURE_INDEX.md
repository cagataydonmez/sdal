# Architecture Index

This is a repo-specific map for AI agents. It is not a complete inventory; use it to find the next focused file.

## Backend
- `server/index.js`: production entrypoint; loads dotenv, starts Express app, attaches WebSockets.
- `server/app.js`: re-exports `server/appRuntime.js`.
- `server/appRuntime.js`: main Express composition file, route registration, middleware, upload dirs, auth runtime, notification runtime, networking runtime, WebSocket runtime.
- `server/config/env.js`: `PORT`, `NODE_ENV`, `SDAL_UPLOADS_DIR`, legacy/static paths.
- `server/middleware/session.js`: `express-session`, optional Redis store, cookie security.
- `server/db.js`: DB driver switch for SQLite/Postgres, query normalization/timing, SQLite bootstrap/repair behavior.
- `server/routes/*.js`: route modules. Admin routes use `admin*Routes.js`; auth/security uses `authSecurityRoutes.js`; media-heavy modules include `albumRoutes.js`, `storyRoutes.js`, feed/post handlers in `appRuntime.js`.
- `server/src/services`: service layer for auth, admin, chat, feed, posts, network suggestions.
- `server/src/repositories/legacy`: legacy-compatible repository implementations.
- `server/src/http/controllers`: controller layer for phase/domain routes.
- `server/src/infra`: Redis, Postgres pool, mail sender, mobile OAuth token store, upload quota, realtime bus.

## Backend Feature Areas
- Auth/session: `server/src/auth/*`, `server/src/services/authService.js`, `server/routes/oauthRoutes.js`, `server/routes/authSecurityRoutes.js`, `server/middleware/session.js`, `/api/session` and `/api/auth/*` in `server/appRuntime.js`.
- Admin APIs: `server/routes/admin*Routes.js`, `server/src/admin/*`, `frontend-modern/src/admin`, `mobile/flutter_sdal/lib/features/admin`.
- Upload/media: `server/media/imageProcessor.js`, `server/media/storageProvider.js`, `server/media/uploadPipeline.js`, `server/src/uploads/*`, upload dirs under `uploads/`, static serving in `server/middleware/staticUploads.js` and `server/appRuntime.js`.
- Notifications/mail/push: `server/routes/notificationRoutes.js`, `server/src/notifications/*`, `server/src/admin/adminPushService.js`, `server/src/infra/mailSender.js`, `server/src/infra/verificationEmailTemplates.js`.
- Networking/teacher network: `server/src/networking/*`, `server/routes/network*Routes.js`, `server/routes/teacherNetworkRoutes.js`.

## Flutter
- `mobile/flutter_sdal/lib/main.dart`: Firebase init, App Check, background messaging, `AppConfig`, `ApiClient`, theme stores, Riverpod overrides.
- `mobile/flutter_sdal/lib/app/app.dart`: app shell, localization delegates, router creation.
- `mobile/flutter_sdal/lib/app/providers.dart`: root providers and theme exports.
- `mobile/flutter_sdal/lib/core/config/app_config.dart`: API/site base URLs and `--dart-define` keys.
- `mobile/flutter_sdal/lib/core/network/api_client.dart`: Dio, persistent cookies, multipart upload, WebSocket cookie header.
- `mobile/flutter_sdal/lib/core/routing/app_router.dart`: GoRouter routes and session redirects.
- `mobile/flutter_sdal/lib/core/session/*`: session bootstrap, login/logout, watch session sync.
- `mobile/flutter_sdal/lib/core/media/pick_cropped_image.dart`: media pick/crop helper.
- `mobile/flutter_sdal/lib/features/*`: feature modules with `data`, `application`, `presentation` subfolders.
- `mobile/flutter_sdal/lib/l10n/app_tr.arb`, `app_en.arb`: source localization files. Turkish is template per `mobile/flutter_sdal/l10n.yaml`.

## Flutter Feature Areas
- Admin: `features/admin/data/admin_repository.dart`, `features/admin/application`, `features/admin/presentation`.
- Auth: `features/auth/*`, plus session code in `core/session`.
- Upload/media: albums, feed, stories repositories use `ApiClient.multipart`; UI flows include album/profile/feed/story upload pages.
- Push: `features/push_notifications/*`, `features/notifications/*`, Firebase setup in `main.dart`.
- Watch bridge: `core/watch/watch_bridge_service.dart` pushes session context to iOS.

## iOS/watchOS
- `mobile/flutter_sdal/ios/Runner.xcodeproj/project.pbxproj`: Xcode project; fragile signing/target/embed/icon settings.
- `mobile/flutter_sdal/ios/Runner/AppDelegate.swift`: iOS app lifecycle and method channel wiring.
- `mobile/flutter_sdal/ios/Runner/WatchBridge.swift`: WatchConnectivity bridge from Flutter session cookie to watch.
- `mobile/flutter_sdal/ios/SdalWatch/App`: watch app entry and root content.
- `mobile/flutter_sdal/ios/SdalWatch/Networking/WatchSessionManager.swift`: stores bridged cookie/base URL/theme and retries session context.
- `mobile/flutter_sdal/ios/SdalWatch/Networking/WatchAPIClient.swift`: watch API client using bridged cookie.
- `mobile/flutter_sdal/ios/SdalWatch/Assets.xcassets/AppIcon.appiconset`: watch icons. Icon backup/export folders exist — fragile area.
- `mobile/flutter_sdal/ios/SdalWatch/{App,ViewModels,Views,Models}`: watch SwiftUI app structure.
- `mobile/flutter_sdal/ios/SdalNotificationExtension`: notification service extension.
- `mobile/flutter_sdal/tool/*`: local iOS/TestFlight/build helpers (`run_ios_local.sh`, `build_ios_local.sh`, `install_local.sh`, `testflight_utils.sh`).

## Web/Admin Frontends
- `frontend-modern/src/main.jsx`, `frontend-modern/src/App.jsx`, `frontend-modern/src/router.jsx`: modern React app entry/routing.
- `frontend-modern/src/admin`: admin tables, filters, bulk actions, drawers, query state, admin API client.
- `frontend-modern/src/utils/apiClient.js`, `utils/auth.jsx`, `utils/notification*.js`: web API/auth/notification utilities.
- `frontend-classic`: legacy Vite React app. Needs confirmation for current production role.

## Deployment and CI
- `.github/workflows/deploy.yml`: "Deploy To DigitalOcean"; validates Node 20, installs server/frontends, builds, runs `test:phase2-health`, `migrate:verify`, SSH deploy, diagnostics, health checks.
- `.github/workflows/android-release.yml`: manual Android APK release build and GitHub prerelease publishing.
- `ops/deploy-systemd.sh`: production deploy script; fetches/reset main, installs deps, builds frontends, runs migrations/schema, writes/restarts systemd services, checks `/api/health`.
- `docker-compose.yml`: present. Needs confirmation before using for local/prod workflows.

## Database
- `server/migrations/*.up.sql` and `*.down.sql`: paired migration files through `026_user_activity_events`.
- `server/scripts/migrate.mjs`: Postgres migration runner requiring `DATABASE_URL`.
- `server/scripts/check-migrations-sanity.mjs`: verifies migration artifact pairing/order.
- `server/scripts/sqlite-runtime-schema.mjs`: SQLite runtime schema/default seeding.
- `server/scripts/migrate-legacy-sqlite-to-modern-postgres.mjs`, `migrate-sqlite-to-postgres.mjs`, `db-sync.mjs`: data migration/sync scripts.
- `db/sdal.sqlite*`: local DB files. Do not read casually.

## Do Not Touch Casually
- `server/db.js`, `server/migrations`, DB files under `db/`.
- `ops/deploy-systemd.sh`, `.github/workflows/*`.
- `mobile/flutter_sdal/ios/Runner.xcodeproj/project.pbxproj`, entitlements, signing settings, watch icon assets.
- Generated Dart: `*.g.dart`, `*.freezed.dart`, `mobile/flutter_sdal/lib/l10n/generated`.
- Upload contents, logs, node_modules, Pods, build/dist outputs.

## Known Fragile Areas
- Backend API response shape changes can break Flutter repositories and watch API parsing.
- Session/cookie behavior spans backend, Flutter Dio cookie jar, iOS bridge, and watch app.
- SQLite/Postgres compatibility is custom; SQL changes must consider both drivers unless explicitly Postgres-only.
- Upload/media paths and permissions affect local uploads, production uploads, and generated variants.
- Watch app packaging/icons/signing have embedded project scripts and historical backups.
- Deployment script performs `git reset --hard origin/main` on the server checkout.
