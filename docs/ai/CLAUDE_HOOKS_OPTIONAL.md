# Optional Claude Hooks

Do not install hooks automatically. These are optional ideas for later if you want stricter guardrails.

## Notify When Claude Needs Input

- Hook idea: play a sound or show a desktop notification when Claude pauses for approval/input.
- Risk: low, but can be annoying if too broad.

## Block Protected File Edits

- Hook idea: warn or block edits to `server/db.js`, `server/migrations`, `.github/workflows`, `ops/deploy-systemd.sh`, `mobile/flutter_sdal/ios/Runner.xcodeproj/project.pbxproj`, entitlements, DB files, uploads, and generated Dart.
- Risk: medium. A hard block can prevent legitimate fixes, so prefer warning first.

## Warn Before Deployment Scripts

- Hook idea: detect commands touching `ops/deploy-systemd.sh`, SSH, `systemctl`, or DigitalOcean deploy commands.
- Risk: low as a warning, high as an automatic blocker if it interrupts planned deploy work.

## Warn Before Database Migrations

- Hook idea: detect edits under `server/migrations` or commands like `migrate:up`, `migrate:down`, `db:sync`, or data migration scripts.
- Risk: medium. Migrations can be valid but need rollback and DB compatibility notes.

## Add Context For SDAL Slash Commands

- Hook idea: when `/sdal-*` commands are used, automatically remind Claude to read `docs/ai/ARCHITECTURE_INDEX.md`, `docs/ai/TASK_PROTOCOL.md`, and the matching `.claude/skills/sdal-*`.
- Risk: low. Keep the injected context short to avoid defeating the token-efficiency goal.

## Recommended First Hook

Start with warning-only hooks for protected edits and deployment/database commands. Avoid auto-editing, auto-approving, or auto-running production commands.
