# SDAL watchOS

Use the `sdal-watchos-change` skill.

Task:

`$ARGUMENTS`

If no arguments were provided or `$ARGUMENTS` is not expanded by this Claude version, ask me for the watchOS/TestFlight task or use the task I pasted below this command.

Rules:
- Read `docs/ai/ARCHITECTURE_INDEX.md` and `docs/ai/TASK_PROTOCOL.md` first.
- Do not scan the whole repo.
- Search first with `rg`.
- Read only focused Flutter watch bridge, iOS bridge, watch Swift, project/signing, or helper files.
- Treat Xcode project files, entitlements, icons, and signing as fragile.
- Plan before editing.
- Make the smallest safe change.
- Run targeted validation only.
- Do not commit unless I explicitly ask.
- Final summary must include files changed, checks run, signing/TestFlight risk, and unverified items.
