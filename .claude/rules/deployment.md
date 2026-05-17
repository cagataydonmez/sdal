---
paths:
  - ".github/workflows/**"
  - "ops/**"
  - "docker-compose.yml"
  - "server/config/**"
---

# Deployment Rules

- Inspect `.github/workflows/deploy.yml` and `ops/deploy-systemd.sh` before deploy assumptions.
- Do not run production SSH, `systemctl`, or reset commands without explicit approval.
- Remember `ops/deploy-systemd.sh` can `git reset --hard origin/$BRANCH` on the server checkout.
- Do not expose secrets or env values in summaries.
- Prefer local validation: `npm run build`, `npm --prefix server run test:phase2-health`, `npm --prefix server run migrate:verify`.
