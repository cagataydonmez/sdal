# SDAL Deploy

Use the `sdal-deploy` skill.

Task:

`$ARGUMENTS`

If no arguments were provided or `$ARGUMENTS` is not expanded by this Claude version, ask me for the deployment task or use the task I pasted below this command.

Rules:
- Read `docs/ai/ARCHITECTURE_INDEX.md` and `docs/ai/TASK_PROTOCOL.md` first.
- Do not scan the whole repo.
- Search first with `rg`.
- Read only focused CI, deploy, env, health, and script sections.
- Do not run production SSH, systemctl, reset, migration, or destructive commands without explicit approval.
- Plan before editing.
- Make the smallest safe change.
- Run targeted local validation only.
- Do not commit unless I explicitly ask.
- Final summary must include files changed, checks run, command risks, production assumptions, and rollback notes.
