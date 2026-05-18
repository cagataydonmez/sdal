# SDAL Review

Use the `sdal-review` skill.

Task:

`$ARGUMENTS`

If no arguments were provided or `$ARGUMENTS` is not expanded by this Claude version, review the task I pasted below this command.

Rules:
- Read `docs/ai/ARCHITECTURE_INDEX.md` and `docs/ai/TASK_PROTOCOL.md` first.
- Do not edit files unless I explicitly ask.
- Do not scan the whole repo.
- Inspect `git status --short`, `git diff --stat`, changed files, and direct call sites.
- Search first with `rg`.
- Read focused diffs and relevant call sites only.
- Report blocking issues first, then non-blocking issues, then test gaps.
- Do not commit.
- Final summary must include reviewed files, checks run, risk level, and residual risks.
