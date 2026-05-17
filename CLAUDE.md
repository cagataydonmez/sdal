# CLAUDE.md

Use this repo in token-efficient mode.

## Start Here
- Read `AGENTS.md` for compact repo guidance.
- Use `docs/ai/ARCHITECTURE_INDEX.md` for path maps.
- Use `docs/ai/TASK_PROTOCOL.md` for workflows.
- Use the matching `.claude/skills/sdal-*/SKILL.md` before backend, Flutter, watchOS, review, debug, deploy, DB, or UI/UX work.
- Apply `.claude/rules/*.md` when touching scoped paths.

## Core Rules
- Do not scan the whole repo. Search first with `rg`, `git ls-files`, or pruned `find`.
- Avoid `node_modules`, `.git`, build outputs, `.dart_tool`, `ios/Pods`, generated Dart, DB files, logs, uploads, and binary assets.
- Read focused sections only; summarize relevant files before editing.
- Plan before editing and make the smallest safe patch.
- Do not change product behavior unless the user asks for product code changes.
- Do not commit unless explicitly asked.

## Useful Checks
- Backend: `npm --prefix server run migrate:verify`, targeted `npm --prefix server run test:*`.
- Frontend modern: `npm --prefix frontend-modern run lint`, `npm --prefix frontend-modern run test`.
- Flutter: `cd mobile/flutter_sdal && flutter analyze`, `cd mobile/flutter_sdal && flutter test`.
- Deployment validation in CI runs root frontend build, `test:phase2-health`, and `migrate:verify`.

End every task with changed files, commands run, and unverified risks.
