---
name: sdal-debug
description: Use for SDAL bug investigations across backend, Flutter, watchOS, deployment, database, auth, uploads, notifications, or CI when the root cause is not yet confirmed.
---

# SDAL Debug

## When To Use
- Bug investigation, failing test/build/deploy, runtime error, unexpected API/UI behavior.
- Use with a module skill when the affected area is known.

## Workflow
1. Restate symptom, expected behavior, and known constraints.
2. Gather minimal evidence: error text, changed files, endpoint, route, screen, test, or log.
3. Search targeted paths only.
4. Build a trace from caller to callee.
5. Separate confirmed facts, hypotheses, and disproven paths.
6. Reproduce with the smallest command or code path if feasible.
7. Patch only after the likely cause is grounded.
8. Verify with the narrowest check.

## Search Strategy
- `rg -n "error text|endpoint|symbol|field" server mobile/flutter_sdal/lib frontend-modern/src .github ops`
- `git diff --stat` if the bug may be from current changes.
- Focus logs/tests/scripts; avoid DB/upload contents unless required and approved.

## Inspect Areas
- Backend: routes, services, DB queries, middleware.
- Flutter: repository, controller/provider, widget, router, ARB.
- watchOS: bridge, session manager, API client, view model.
- Deploy: workflow, deploy script, env, service health.

## Safety Rules
- Avoid speculative fixes.
- Do not rewrite unrelated areas.
- Do not run production/destructive commands without approval.
- Mark unknowns as `Needs confirmation`.

## Validation
- Use the smallest failing/relevant test.
- If unable to reproduce locally, document why and what would confirm it.

## Output Format
- Confirmed facts.
- Hypotheses.
- Fix or next diagnostic step.
- Checks and risks.
