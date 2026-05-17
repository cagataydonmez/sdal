# Important Commands

Commands below are extracted from repo files unless marked `UNVERIFIED`.

## Root
- Install root dependencies: `npm install`
- Build both React frontends: `npm run build`
- Start backend through root script: `npm run start`
- Sync design tokens: `npm run tokens:sync`

## Backend (`server`)
- Install production deps: `npm --prefix server ci --omit=dev`
- Dev server: `npm --prefix server run dev`
- Start server: `npm --prefix server run start`
- Worker: `npm --prefix server run worker`
- Migrate up/down/status: `npm --prefix server run migrate:up`, `migrate:down`, `migrate:status`
- Migration sanity: `npm --prefix server run migrate:verify`
- SQLite runtime schema: `npm --prefix server run sqlite:ensure-schema`
- Postgres perf audit: `npm --prefix server run perf:audit:pg`
- Data migration/sync: `migrate:data`, `migrate:pg`, `db:sync:to-pg`, `db:sync:to-sqlite`
- Contract tests (partial list — see `server/package.json` for full `test:*` list):
  - `npm --prefix server run test:phase1-contracts`
  - `npm --prefix server run test:phase2-health`
  - `npm --prefix server run test:phase2-notifications`
  - `npm --prefix server run test:phase7-media-hardening`
  - `npm --prefix server run test:phase9-email`

## React Frontends
- Modern install: `npm --prefix frontend-modern ci`
- Modern dev/build/lint/test: `npm --prefix frontend-modern run dev`, `build`, `lint`, `test`
- Classic install: `npm --prefix frontend-classic ci`
- Classic dev/build: `npm --prefix frontend-classic run dev`, `build`

## Flutter (`mobile/flutter_sdal`)
- Get deps: `cd mobile/flutter_sdal && flutter pub get`
- Analyze: `cd mobile/flutter_sdal && flutter analyze`
- Test: `cd mobile/flutter_sdal && flutter test`
- Generate code: `cd mobile/flutter_sdal && dart run build_runner build`
- Build Android APK: `cd mobile/flutter_sdal && flutter build apk --release`
- Build iOS no-codesign: `cd mobile/flutter_sdal && flutter build ios --release --no-codesign`
- Local install/run helper: `cd mobile/flutter_sdal && ./tool/install_local.sh`
- Local iOS simulator helper: `cd mobile/flutter_sdal && ./tool/run_ios_local.sh "iPhone 16 Pro 26.4"`
- Local iOS release helper: `cd mobile/flutter_sdal && ./tool/build_ios_local.sh`

## iOS/watchOS
- Direct iPhone release xcodebuild from README:
  `cd mobile/flutter_sdal/ios && xcodebuild -configuration Release -allowProvisioningUpdates -allowProvisioningDeviceRegistration -workspace Runner.xcworkspace -scheme Runner BUILD_DIR=$HOME/Library/Caches/flutter_sdal_ios_build OBJROOT=$HOME/Library/Caches/flutter_sdal_ios_build -sdk iphoneos -destination generic/platform=iOS FLUTTER_SUPPRESS_ANALYTICS=true COMPILER_INDEX_STORE_ENABLE=NO`
- Watch-specific build/archive commands: Needs confirmation. Existing prior commands may be in shell history, not committed docs.

## Deployment and CI
- CI workflow: `Deploy To DigitalOcean` in `.github/workflows/deploy.yml`
- CI validation installs server/frontends, runs `npm run build`, `npm --prefix server run test:phase2-health`, `npm --prefix server run migrate:verify`
- Production deploy script: `bash ops/deploy-systemd.sh`
- Android CI workflow: `Android Release Build` in `.github/workflows/android-release.yml`

## Database
- Migration runner requires `DATABASE_URL` for Postgres.
- SQLite scripts use `SDAL_DB_PATH` where applicable.
- Do not run data migration/sync commands against production without explicit approval.
