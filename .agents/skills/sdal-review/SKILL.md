---
name: sdal-review
description: Use for review-only tasks in SDAL: inspect current changes, diffs, direct call sites, API/client impacts, tests, and risks without editing files.
---

# SDAL Review

## When To Use
- User asks for review, audit, risk check, PR review, or "look over this".
- Do not edit unless explicitly requested.

## Workflow
1. Inspect `git status --short`.
2. Inspect `git diff --stat`.
3. List changed files and read focused diffs.
4. Search direct call sites for changed APIs, fields, routes, widgets, scripts, or migrations.
5. Report blocking issues first, then non-blocking issues, then test gaps.
6. Separate confirmed problems from hypotheses.

## Search Strategy
- `git diff -- <file>`
- `rg -n "changedSymbol|endpoint|field" relevant-paths`
- Avoid generated files unless they are the only changed artifact.

## Inspect Areas
- Backend route/service changes plus Flutter/React call sites.
- Flutter UI/repository changes plus ARB and tests.
- DB migrations plus backend queries and rollback.
- Deploy changes plus CI workflow and script call sites.

## Safety Rules
- Do not scan entire repo.
- Do not edit files.
- Do not run destructive commands.
- Do not over-report style preferences as bugs.

## Validation
- Prefer reading existing test output if available.
- If running checks is useful, choose the narrowest command and state it.

## Output Format
- Findings ordered by severity with file/line references.
- Risk level: low, medium, high.
- Tests/checks reviewed or run.
- Residual risks.
