---
name: sdal-deploy
description: Use for SDAL deployment, CI/CD, GitHub Actions, DigitalOcean, systemd, Nginx/proxy assumptions, PM2/system service questions, env files, production paths, and deploy script issues.
---

# SDAL Deploy

## When To Use
- `.github/workflows`, `ops`, production env/path, DigitalOcean SSH, systemd service, release, build/deploy failure.

## Workflow
1. Restate deploy target and whether work is local, CI, or production.
2. Inspect workflow, deploy script, and relevant package scripts.
3. Identify commands as safe, read-only, or destructive.
4. Do not run production SSH/systemctl/reset without explicit approval.
5. Plan minimal change.
6. Validate with local syntax or CI-equivalent lightweight checks where possible.
7. Document unverified production assumptions.

## Search Strategy
- Search `.github`, `ops`, `server`, and `scripts` for deploy, env, service, health, and migration terms.

## Inspect Areas
- `.github/workflows/deploy.yml`
- `.github/workflows/android-release.yml`
- `ops/deploy-systemd.sh`
- `server/config/env.js`, `server/db.js`, migration scripts.

## Safety Rules
- Deploy script can `git reset --hard` server checkout and restart services.
- Do not assume Nginx/PM2 config exists unless found.
- Do not expose secrets.

## Validation
- `npm --prefix server run migrate:verify`
- `npm run build` for frontend deploy changes.
- CI-only behavior remains `UNVERIFIED` unless run in CI.

## Output Format
- Command risks, files changed, checks, production assumptions/rollback notes.
