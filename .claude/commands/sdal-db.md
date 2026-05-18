# SDAL Database

Use the `sdal-db-migration` skill.

Task:

`$ARGUMENTS`

If no arguments were provided or `$ARGUMENTS` is not expanded by this Claude version, ask me for the database task or use the task I pasted below this command.

Rules:
- Read `docs/ai/ARCHITECTURE_INDEX.md` and `docs/ai/TASK_PROTOCOL.md` first.
- Do not scan the whole repo.
- Search first with `rg`.
- Read only focused migration, query, route/service, and client impact files.
- Consider SQLite/Postgres compatibility unless explicitly scoped.
- Include rollback/risk analysis for migration work.
- Plan before editing.
- Make the smallest safe change.
- Run targeted validation only.
- Do not commit unless I explicitly ask.
- Final summary must include files changed, checks run, rollback notes, compatibility, and risks.
