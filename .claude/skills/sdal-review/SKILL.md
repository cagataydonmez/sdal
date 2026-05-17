---
name: sdal-review
description: Use for review-only tasks in SDAL: inspect current changes, diffs, direct call sites, API/client impacts, tests, and risks without editing files.
---

# SDAL Review

## When To Use
- Review, audit, risk check, PR review, or "look over this".
- Do not edit unless explicitly requested.

## Workflow
1. Inspect `git status --short`.
2. Inspect `git diff --stat`.
3. Read focused diffs for changed files.
4. Search direct call sites for changed APIs, fields, routes, widgets, scripts, or migrations.
5. Report blocking issues first, then non-blocking issues, then test gaps.
6. Separate confirmed problems from hypotheses.

## Search Strategy
- `git diff -- <file>`
- `rg -n "changedSymbol|endpoint|field" relevant-paths`

## Inspect Areas
- Backend changes plus Flutter/React call sites.
- Flutter changes plus ARB and tests.
- DB migrations plus queries and rollback.
- Deploy changes plus workflow/script call sites.

## Safety Rules
- Do not scan entire repo.
- Do not edit files.
- Do not run destructive commands.

## Validation
- Run only narrow checks if useful; otherwise review existing evidence.

## Output Format
- Findings by severity with file/line references, risk level, tests, residual risks.
