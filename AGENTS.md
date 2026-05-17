# AGENTS.md

## Repo Overview
- Monorepo for SDAL: Node.js/Express backend, React web/frontends, Flutter mobile app, iOS/watchOS companion app, SQLite/Postgres data layer, and DigitalOcean deployment.
- Backend entrypoints: `server/index.js`, `server/app.js`, `server/appRuntime.js`.
- Flutter app: `mobile/flutter_sdal/lib/main.dart`, `mobile/flutter_sdal/lib/app`, `mobile/flutter_sdal/lib/core`, `mobile/flutter_sdal/lib/features`.
- iOS/watchOS: `mobile/flutter_sdal/ios/Runner.xcodeproj/project.pbxproj`, `mobile/flutter_sdal/ios/Runner`, `mobile/flutter_sdal/ios/SdalWatch`, `mobile/flutter_sdal/ios/SdalNotificationExtension`.
- AI operating docs live in `docs/ai/`; Codex skills live in `.agents/skills/`.

## Context Strategy
- Do not scan the whole repo. Search first, read only relevant files.
- Start with `package.json`, `server/package.json`, `mobile/flutter_sdal/pubspec.yaml`, entrypoints, then route/repository/service files related to the task.
- Prefer `rg`, `git ls-files`, `find` with prune rules, and focused `sed -n` ranges.
- Avoid generated, binary, dependency, and build artifacts unless the task is specifically about them.

## Required Workflow
1. Restate the objective and likely blast radius.
2. Identify minimal files with targeted search.
3. Summarize relevant files before editing.
4. Plan the smallest safe patch.
5. Edit only task-related docs/code.
6. Run the narrowest useful check.
7. Summarize changed files, commands run, and remaining risks.

## Forbidden Or Sensitive Areas
- Avoid: `node_modules`, `.git`, `build`, `dist`, `coverage`, `.dart_tool`, `ios/Pods`, generated Dart files (`*.g.dart`, `*.freezed.dart`, `lib/l10n/generated`), binary assets, DB files in `db/`, logs, and upload contents.
- Do not change product behavior, migrations, deployment scripts, Xcode project files, signing, or app code unless the user explicitly asks.
- Treat `server/db.js`, `server/migrations`, `server/scripts/migrate*.mjs`, `ops/deploy-systemd.sh`, `.github/workflows`, and `mobile/flutter_sdal/ios/Runner.xcodeproj/project.pbxproj` as fragile.

## Module Notes
- Backend: Express routes are registered mostly in `server/appRuntime.js`; route modules live in `server/routes`; domain/service/repository code lives in `server/src`.
- Auth/session: backend uses `express-session` in `server/middleware/session.js`; Flutter persists cookies through Dio/cookie_jar in `mobile/flutter_sdal/lib/core/network/api_client.dart`.
- Database: `server/db.js` supports SQLite and Postgres; migrations are paired `server/migrations/*.up.sql` and `*.down.sql`.
- Upload/media: uploads use `server/media/*`, `server/src/uploads/*`, `SDAL_UPLOADS_DIR`, and public `/uploads` or `/api/media/*` paths.
- Notifications/mail/push: backend code is in `server/src/notifications`, `server/src/admin/adminPushService.js`, `server/src/infra/mailSender.js`; Flutter uses `features/push_notifications` and Firebase.
- Flutter: Riverpod providers, GoRouter routing, Dio API client, ARB localization with Turkish template (`mobile/flutter_sdal/l10n.yaml`).
- watchOS: session bridge spans Flutter `core/watch/watch_bridge_service.dart`, iOS `Runner/WatchBridge.swift`, and watch `SdalWatch/Networking`.
- Deployment: GitHub Actions deploy to DigitalOcean and run `ops/deploy-systemd.sh`; production paths/env come from secrets and `/etc/sdal/sdal.env`.

## Verification Commands
- Root build: `npm run build`
- Root start: `npm run start`
- Backend dev/start: `npm --prefix server run dev`, `npm --prefix server run start`
- Backend migration checks: `npm --prefix server run migrate:verify`, `npm --prefix server run migrate:status`
- Backend targeted contracts: `npm --prefix server run test:phase2-health`, plus specific `test:*` scripts in `server/package.json`
- Frontend modern: `npm --prefix frontend-modern run lint`, `npm --prefix frontend-modern run test`, `npm --prefix frontend-modern run build`
- Flutter: `cd mobile/flutter_sdal && flutter analyze`, `cd mobile/flutter_sdal && flutter test`
- iOS local helpers: `mobile/flutter_sdal/tool/run_ios_local.sh`, `mobile/flutter_sdal/tool/build_ios_local.sh`

## Safety Rules
- Never commit unless explicitly asked.
- Never run destructive production commands or broad resets without explicit permission.
- Check Flutter API client/repositories before changing backend response shapes.
- Check ARB files for user-facing Flutter text.
- For migrations, include rollback and SQLite/Postgres compatibility analysis.
- Mark uncertain findings as `Needs confirmation` or `UNVERIFIED`.
