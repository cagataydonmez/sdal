---
name: sdal-debug
description: Use for SDAL bug investigations across backend, Flutter, watchOS, deployment, database, auth, uploads, notifications, or CI when the root cause is not yet confirmed.
---

# SDAL Debug

## When To Use
- Bug investigation, failing test/build/deploy, runtime error, unexpected API/UI behavior.

## Workflow
1. Restate symptom, expected behavior, and constraints.
2. Gather minimal evidence.
3. Search targeted paths only.
4. Trace caller to callee.
5. Separate confirmed facts, hypotheses, and disproven paths.
6. Reproduce minimally if feasible.
7. Patch only after the likely cause is grounded.
8. Verify with the narrowest check.

## Search Strategy
- Use `rg` for error text, endpoint, symbol, or field across relevant modules.
- Use `git diff --stat` if current changes may be involved.

## Inspect Areas
- Backend routes/services/queries/middleware.
- Flutter repository/controller/widget/router/ARB.
- watchOS bridge/session manager/API client/view model.
- Deploy workflow/script/env/health.

## Safety Rules
- Avoid speculative fixes.
- Do not rewrite unrelated areas.
- Mark unknowns as `Needs confirmation`.

## Validation
- Use the smallest failing or relevant test.
- If not reproducible locally, document why.

## Output Format
- Confirmed facts, hypotheses, fix or next diagnostic step, checks, risks.
