# Context Refresh

Use this when repo architecture changes enough that future AI tasks would be misled by old guidance.

## When To Refresh
- New backend entrypoint, route family, auth/session flow, upload/media pipeline, notification/push/mail system, or DB driver behavior.
- New Flutter routing/state/API/localization pattern.
- New iOS/watchOS target, signing flow, icon process, WatchConnectivity flow, or TestFlight helper.
- Deployment, CI, systemd, env, migration, or production path changes.
- Any repeated AI mistake caused by stale docs or missing skills.

## What To Update
- `AGENTS.md`: only compact repo-wide rules and command highlights.
- `CLAUDE.md`: short Claude entry guide pointing to docs and skills.
- `docs/ai/ARCHITECTURE_INDEX.md`: path map and fragile areas.
- `docs/ai/IMPORTANT_COMMANDS.md`: exact commands from package/workflow/docs.
- `docs/ai/KNOWN_PITFALLS.md`: repo-specific hazards.
- `docs/ai/DECISIONS.md`: confirmed architecture decisions only.
- `.agents/skills/*` and `.claude/skills/*`: workflow updates for recurring task types.
- `.claude/rules/*`: path-scoped short rules.

## Refresh Rules
- Search first; do not scan the whole repo.
- Use `scripts/ai-refresh-context.sh` if available, then inspect only relevant paths.
- Keep files short enough to load during future tasks.
- Mark uncertain items as `Needs confirmation` or `UNVERIFIED`.
- Do not include secrets, DB contents, upload contents, generated files, or large command output.
- Prefer exact paths over vague descriptions.
