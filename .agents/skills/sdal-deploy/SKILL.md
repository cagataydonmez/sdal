---
name: sdal-deploy
description: Use for SDAL deployment, CI/CD, GitHub Actions, DigitalOcean, systemd, Nginx/proxy assumptions, PM2/system service questions, env files, production paths, and deploy script issues.
---

# SDAL Deploy

## When To Use
- `.github/workflows`, `ops`, production env/path, DigitalOcean SSH, systemd service, release, build/deploy failure.

## Workflow
1. Restate deploy target and whether work is local, CI, or production.
2. Inspect `.github/workflows/deploy.yml`, `ops/deploy-systemd.sh`, and relevant package scripts.
3. Identify exact commands and whether they are safe, read-only, or destructive.
4. Do not run production SSH/systemctl/reset commands without explicit approval.
5. Plan minimal config/script/docs change.
6. Validate with local syntax or CI-equivalent lightweight checks where possible.
7. Document exact unverified production assumptions.

## Search Strategy
- `rg -n "deploy|systemd|ssh|DATABASE_URL|SDAL_|PORT|health|nginx|pm2|reset --hard" .github ops server scripts`
- Read only relevant workflow/script ranges.

## Inspect Areas
- `.github/workflows/deploy.yml`
- `.github/workflows/android-release.yml`
- `ops/deploy-systemd.sh`
- `server/config/env.js`, `server/db.js`, migration scripts.
- `mobile/flutter_sdal/README.md`, `tool/*` for mobile release issues.

## Safety Rules
- `ops/deploy-systemd.sh` can run `git reset --hard` on server checkout and restart services.
- Production env defaults to `/etc/sdal/sdal.env`.
- Do not assume Nginx/PM2 config exists unless found.
- Do not expose secrets in summaries.

## Validation
- `npm --prefix server run migrate:verify`
- `npm run build` for frontend deploy changes.
- CI-only behavior remains `UNVERIFIED` unless run in CI.

## Output Format
- Command risk table or concise list.
- Files changed.
- Checks run.
- Production assumptions and rollback notes.
