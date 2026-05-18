# SDAL Flutter

Use the `sdal-flutter-change` skill.

Task:

`$ARGUMENTS`

If no arguments were provided or `$ARGUMENTS` is not expanded by this Claude version, ask me for the Flutter task or use the task I pasted below this command.

Rules:
- Read `docs/ai/ARCHITECTURE_INDEX.md` and `docs/ai/TASK_PROTOCOL.md` first.
- Do not scan the whole repo.
- Search first with `rg`.
- Read only focused Flutter feature, routing, state, API, and localization files.
- Check ARB files for user-facing strings.
- Plan before editing.
- Make the smallest safe change.
- Run targeted validation only.
- Do not commit unless I explicitly ask.
- Final summary must include files changed, checks run, localization status, and risks.
