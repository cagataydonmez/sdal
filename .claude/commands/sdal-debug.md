# SDAL Debug

Use the `sdal-debug` skill.

Task:

`$ARGUMENTS`

If no arguments were provided or `$ARGUMENTS` is not expanded by this Claude version, ask me for the bug/symptom or use the task I pasted below this command.

Rules:
- Read `docs/ai/ARCHITECTURE_INDEX.md` and `docs/ai/TASK_PROTOCOL.md` first.
- Do not scan the whole repo.
- Search first with `rg`.
- Read only focused files needed to trace the symptom.
- Separate confirmed facts from hypotheses.
- Plan before editing.
- Avoid speculative fixes.
- Make the smallest safe change only after cause is grounded.
- Run targeted validation only.
- Do not commit unless I explicitly ask.
- Final summary must include facts, fix or next diagnostic step, files changed, checks run, and risks.
