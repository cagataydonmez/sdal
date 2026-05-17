# Task Protocol

## Standard Workflow
1. Restate objective and expected blast radius.
2. Identify minimal files with `rg`, `git ls-files`, or pruned `find`.
3. Search first; avoid whole-repo reads.
4. Read focused sections only, then summarize relevant files before editing.
5. Plan the smallest safe change.
6. Apply the smallest safe patch.
7. Run targeted checks only.
8. Summarize changed files, tests/checks, and risks.

## Backend API Changes
- Start with `server/package.json`, `server/appRuntime.js`, the specific `server/routes/*` file, and relevant `server/src/services` or `server/src/repositories`.
- Search Flutter and web clients for the endpoint or payload fields before changing contracts.
- If auth/session is involved, inspect `server/middleware/session.js`, `server/src/auth`, and Flutter `core/session`.
- Validate with the narrowest contract script in `server/package.json` or `test:phase2-health` if no narrower test exists.

## Flutter UI Changes
- Start with `mobile/flutter_sdal/pubspec.yaml`, `lib/core/routing/app_router.dart`, and the specific feature folder.
- Check repositories and models for API assumptions before changing UI state.
- For user-facing strings, update `lib/l10n/app_tr.arb` and `app_en.arb`; do not edit generated localization files directly.
- Prefer `cd mobile/flutter_sdal && flutter analyze`; run targeted `flutter test <file>` when available.

## Admin Panel Changes
- Identify whether the surface is Flutter admin (`mobile/flutter_sdal/lib/features/admin`) or React admin (`frontend-modern/src/admin`).
- Check backend `server/routes/admin*Routes.js` and `server/src/admin/*` for permissions and payload shape.
- Verify permission/role behavior before changing controls or bulk actions.

## watchOS Changes
- Map both sides: Flutter `core/watch/watch_bridge_service.dart`, iOS `Runner/WatchBridge.swift`, watch `SdalWatch/Networking`, and the SwiftUI view/model involved.
- Treat `project.pbxproj`, entitlements, app icons, bundle IDs, and signing as fragile.
- Use local helper docs/scripts in `mobile/flutter_sdal/README.md` and `mobile/flutter_sdal/tool`.

## Deployment Changes
- Start with `.github/workflows/deploy.yml`, `ops/deploy-systemd.sh`, `server/config/env.js`, and relevant env variables.
- Do not run production SSH, reset, systemctl, or destructive commands without explicit permission.
- Document exact command risk and rollback path.
- Validate locally with syntax/lightweight checks where possible; CI deploy behavior may remain `UNVERIFIED`.

## Database Migration Changes
- Inspect existing migration numbering and pairing in `server/migrations`.
- Use paired `.up.sql` and `.down.sql`.
- Check `server/db.js`, `server/scripts/migrate.mjs`, and affected backend queries.
- Consider SQLite runtime schema if the feature must support SQLite.
- Run `npm --prefix server run migrate:verify`; run app-specific contract tests when query behavior changes.

## Bug Investigation
- Separate confirmed facts from hypotheses.
- Reproduce or trace minimally with logs, tests, or route/client call paths.
- Do not make speculative fixes. Patch only when the cause is grounded in code or a repro.

## Review-Only Tasks
- Do not edit files.
- Inspect `git status --short`, `git diff --stat`, changed files, and direct call sites.
- Report blocking issues first, then non-blocking issues, then residual risk/test gaps.
