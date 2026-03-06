#!/usr/bin/env bash
set -euo pipefail

APP_DIR="${APP_DIR:-/var/www/sdal}"
BRANCH="${BRANCH:-main}"
ENV_FILE="${ENV_FILE:-/etc/sdal/sdal.env}"

if [[ ! -d "$APP_DIR/.git" ]]; then
  echo "[deploy] Git repo not found at $APP_DIR"
  exit 1
fi

if sudo -n true >/dev/null 2>&1; then
  SUDO="sudo"
else
  SUDO=""
fi

echo "[deploy] app_dir=$APP_DIR branch=$BRANCH"
cd "$APP_DIR"

git fetch origin "$BRANCH"
git checkout "$BRANCH"
git pull --ff-only origin "$BRANCH"

export NODE_OPTIONS="${NODE_OPTIONS:---max-old-space-size=768}"

npm --prefix server install --omit=dev
npm --prefix frontend-classic ci
npm --prefix frontend-modern ci
npm run build

if [[ -f "$ENV_FILE" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  set +a
fi

mkdir -p /var/lib/sdal/data /var/lib/sdal/uploads /var/lib/sdal/backups /var/lib/sdal/legacy-logs

if [[ "${SDAL_DB_DRIVER:-sqlite}" == "sqlite" ]]; then
  if [[ ! -f /var/lib/sdal/data/sdal.sqlite && -f "$APP_DIR/db/sdal.sqlite" ]]; then
    cp "$APP_DIR/db/sdal.sqlite" /var/lib/sdal/data/sdal.sqlite
    echo "[deploy] initialized sqlite db at /var/lib/sdal/data/sdal.sqlite"
  fi
fi

if [[ "${SDAL_DB_DRIVER:-}" == "postgres" && -n "${DATABASE_URL:-}" ]]; then
  echo "[deploy] applying postgres migrations"
  npm --prefix server run migrate:up
fi

$SUDO systemctl daemon-reload || true
$SUDO systemctl restart sdal-api.service
$SUDO systemctl restart sdal-worker.service

PORT_VALUE="${PORT:-8787}"
echo "[deploy] health probe on 127.0.0.1:${PORT_VALUE}"
curl -fsS "http://127.0.0.1:${PORT_VALUE}/api/health" >/dev/null

echo "[deploy] completed"
