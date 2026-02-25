#!/usr/bin/env bash
set -euo pipefail

APP_DIR="${APP_DIR:-/var/www/sdal}"
BRANCH="${BRANCH:-main}"

if [[ ! -d "$APP_DIR/.git" ]]; then
  echo "[deploy] Git repo not found at $APP_DIR"
  echo "[deploy] Clone the repository once, then rerun."
  exit 1
fi

echo "[deploy] app_dir=$APP_DIR branch=$BRANCH"
cd "$APP_DIR"

git fetch origin "$BRANCH"
git checkout "$BRANCH"
git pull --ff-only origin "$BRANCH"

npm --prefix server install --omit=dev
npm --prefix frontend-classic ci
npm --prefix frontend-modern ci
npm run build

mkdir -p /var/lib/sdal/data
mkdir -p /var/lib/sdal/uploads
mkdir -p /var/lib/sdal/backups

if [[ ! -f /var/lib/sdal/data/sdal.sqlite && -f db/sdal.sqlite ]]; then
  cp db/sdal.sqlite /var/lib/sdal/data/sdal.sqlite
  echo "[deploy] initial sqlite db copied to /var/lib/sdal/data/sdal.sqlite"
fi

if [[ -f /etc/sdal/sdal.env ]] && grep -q '^SDAL_DB_DRIVER=postgres' /etc/sdal/sdal.env; then
  echo "[deploy] postgres driver detected"
  set -a
  source /etc/sdal/sdal.env
  set +a
  mkdir -p /var/lib/sdal/backups
  if [[ ! -f /var/lib/sdal/.pg_migrated ]]; then
    echo "[deploy] running sqlite -> postgres migration (one-time)"
    SQLITE_PATH="${SQLITE_PATH:-/var/lib/sdal/data/sdal.sqlite}" npm --prefix server run migrate:pg
    touch /var/lib/sdal/.pg_migrated
  fi
fi

pm2 startOrReload ecosystem.config.cjs --env production
pm2 save

echo "[deploy] completed"
