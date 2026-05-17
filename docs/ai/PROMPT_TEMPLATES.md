# Prompt Templates

Copy, paste, and fill the bracketed parts.

## Backend Bug Fix
Use the `sdal-backend-change` and `sdal-debug` skills. Fix `[bug]` in the Node backend. Do not scan the whole repo. Start by searching for the endpoint/function names, then inspect only relevant route/service/repository files. Before changing any API contract, search Flutter and React clients for call sites. Make the smallest safe patch, run the narrowest backend contract/test command, and summarize changed files, checks, and risks.

## Flutter Admin UI Improvement
Use the `sdal-flutter-change` and `sdal-uiux` skills. Improve `[admin UI area]` in `mobile/flutter_sdal`. Do not scan the whole repo. Inspect the relevant feature admin presentation/application/data files, route entry, and ARB files for user-facing strings. Keep UI practical and consistent with existing patterns. Run `flutter analyze` or a targeted Flutter test if feasible. Summarize changes and any unverified visual risks.

## watchOS/TestFlight Issue
Use the `sdal-watchos-change` and `sdal-debug` skills. Investigate `[watch/TestFlight issue]`. Do not scan the whole repo. Inspect the watch target, `Runner/WatchBridge.swift`, `SdalWatch/Networking`, relevant SwiftUI view/model, and build helper docs/scripts. Treat `project.pbxproj`, entitlements, icons, and signing as fragile. Separate confirmed facts from hypotheses and avoid speculative project-file edits.

## Deployment Issue
Use the `sdal-deploy` and `sdal-debug` skills. Investigate `[deploy issue]` involving CI/DigitalOcean/systemd/env. Do not run production/destructive commands without approval. Inspect `.github/workflows/deploy.yml`, `ops/deploy-systemd.sh`, env usage, and relevant backend health/migration paths. Document command risks and provide the safest verification path.

## Database Migration Issue
Use the `sdal-db-migration` and `sdal-backend-change` skills. Work on `[schema/query issue]`. Inspect existing migration numbering/pairs, affected backend queries, and SQLite/Postgres compatibility. Include rollback analysis. Run `npm --prefix server run migrate:verify` and the narrowest affected contract test if feasible.

## Review Current Branch
Use the `sdal-review` skill. Review the current branch only. Do not edit. Inspect `git status --short`, `git diff --stat`, changed files, and direct call sites. Prioritize blocking bugs/regressions/security risks with file/line references. End with risk level and test gaps.

## Security/Auth Review
Use the `sdal-review`, `sdal-backend-change`, and `sdal-debug` skills. Review `[auth/session/security area]`. Inspect backend session/auth routes, Flutter session repository/API client, and any watch bridge impact. Do not edit unless explicitly asked. Separate confirmed issues from hardening suggestions.

## Localization Update
Use the `sdal-flutter-change` skill. Update localization for `[text/feature]`. Do not edit generated localization files. Update `mobile/flutter_sdal/lib/l10n/app_tr.arb` and `app_en.arb`, inspect call sites using `AppLocalizations`, and run the narrowest Flutter localization/analyze check available.

## Token-Efficient Repo Investigation
Use `docs/ai/ARCHITECTURE_INDEX.md` and relevant skills. Investigate `[question]` with minimal context. Use `rg`, `git ls-files`, and focused `sed` ranges. Do not read generated files, uploads, DB files, build outputs, Pods, node_modules, or the whole repo. Return confirmed facts, likely paths, and `Needs confirmation` items.
