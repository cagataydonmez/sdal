#!/usr/bin/env bash
set -euo pipefail

log() {
  printf '[deploy] %s\n' "$*"
}

fail() {
  printf '[deploy] ERROR: %s\n' "$*" >&2
  exit 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "missing required command: $1"
}

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="${APP_DIR:-$(cd -- "$SCRIPT_DIR/.." && pwd)}"
BRANCH="${BRANCH:-main}"
ENV_FILE="${ENV_FILE:-/etc/sdal/sdal.env}"
API_SERVICE_NAME="${SDAL_API_SERVICE_NAME:-sdal-api.service}"
WORKER_SERVICE_NAME="${SDAL_WORKER_SERVICE_NAME:-sdal-worker.service}"
SERVICE_USER="${SDAL_SERVICE_USER:-${SUDO_USER:-$(id -un)}}"
NPM_BIN="$(command -v npm || true)"
NODE_ENV_VALUE="${NODE_ENV:-production}"

[[ -d "$APP_DIR/.git" ]] || fail "APP_DIR is not a git checkout: $APP_DIR"
require_cmd git
require_cmd node
require_cmd npm

cd "$APP_DIR"
log "app_dir=$APP_DIR branch=$BRANCH env_file=$ENV_FILE user=$(id -un) service_user=$SERVICE_USER"

git config --global --add safe.directory "$APP_DIR" >/dev/null 2>&1 || true
git fetch --prune origin "$BRANCH"
git checkout "$BRANCH"
git reset --hard "origin/$BRANCH"

if [[ -f "$ENV_FILE" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  set +a
else
  log "env file not found yet: $ENV_FILE"
fi

# --- App Store review: device-verification bypass -------------------------
# Apple's review test account ("test") could not receive the new-device email
# verification code. Idempotently keep it in TEST_BYPASS_DEVICE_CHECK_USERNAMES
# so it logs in without the email challenge. Safe to remove after approval.
REVIEW_BYPASS_USER="test"
if [[ -f "$ENV_FILE" && -w "$ENV_FILE" ]]; then
  current_bypass="${TEST_BYPASS_DEVICE_CHECK_USERNAMES:-}"
  if [[ ",${current_bypass}," != *",${REVIEW_BYPASS_USER},"* ]]; then
    if grep -q '^TEST_BYPASS_DEVICE_CHECK_USERNAMES=' "$ENV_FILE"; then
      if [[ -n "$current_bypass" ]]; then
        new_bypass="${current_bypass},${REVIEW_BYPASS_USER}"
      else
        new_bypass="$REVIEW_BYPASS_USER"
      fi
      esc_bypass="$(printf '%s' "$new_bypass" | sed -e 's/[&/\]/\\&/g')"
      sed -i "s/^TEST_BYPASS_DEVICE_CHECK_USERNAMES=.*/TEST_BYPASS_DEVICE_CHECK_USERNAMES=${esc_bypass}/" "$ENV_FILE"
    else
      printf '\nTEST_BYPASS_DEVICE_CHECK_USERNAMES=%s\n' "$REVIEW_BYPASS_USER" >>"$ENV_FILE"
    fi
    log "ensured review device-check bypass for: $REVIEW_BYPASS_USER"
  else
    log "review device-check bypass already present"
  fi
elif [[ -f "$ENV_FILE" ]]; then
  log "env file not writable; skipping review device-check bypass: $ENV_FILE"
fi
# --------------------------------------------------------------------------

# --- Sync privacy policy into the nginx web root --------------------------
# The privacy policy is served as a static file by nginx (not the app). Keep
# the version-controlled copy in sync wherever an existing privacy_policy.html
# is found under an nginx root or the common defaults. Best-effort, idempotent.
SRC_PRIVACY="$APP_DIR/frontend-classic/public/privacy_policy.html"
if [[ -f "$SRC_PRIVACY" ]]; then
  nginx_roots=""
  if command -v nginx >/dev/null 2>&1; then
    nginx_roots="$(nginx -T 2>/dev/null | awk '$1=="root"{gsub(/;/,"",$2); print $2}' | sort -u || true)"
  fi
  for web_root in $nginx_roots /var/www/html /usr/share/nginx/html; do
    [[ -d "$web_root" ]] || continue
    while IFS= read -r target; do
      [[ -n "$target" ]] || continue
      if cp "$SRC_PRIVACY" "$target" 2>/dev/null; then
        log "synced privacy_policy.html -> $target"
      fi
    done < <(find "$web_root" -maxdepth 4 -name privacy_policy.html 2>/dev/null || true)
  done
fi
# --------------------------------------------------------------------------

mkdir -p logs
if [[ -n "${SDAL_UPLOADS_DIR:-}" ]]; then
  mkdir -p "$SDAL_UPLOADS_DIR"
fi
if [[ -n "${SDAL_DB_PATH:-}" ]]; then
  mkdir -p "$(dirname "$SDAL_DB_PATH")"
fi

log "installing server dependencies"
npm --prefix server ci --omit=dev

log "installing frontend dependencies"
# Frontend builds need Vite and related build tooling from devDependencies.
# Production deploy env files can set NODE_ENV/NPM_CONFIG_OMIT, so clear those
# only for frontend dependency installation. The final systemd runtime still
# gets NODE_ENV=production.
env -u NODE_ENV -u NPM_CONFIG_OMIT -u NPM_CONFIG_PRODUCTION npm --prefix frontend-classic ci --production=false
env -u NODE_ENV -u NPM_CONFIG_OMIT -u NPM_CONFIG_PRODUCTION npm --prefix frontend-modern ci --production=false

[[ -x frontend-classic/node_modules/.bin/vite ]] || fail "frontend-classic Vite was not installed"
[[ -x frontend-modern/node_modules/.bin/vite ]] || fail "frontend-modern Vite was not installed"

log "building frontends"
npm run build

if [[ "${SDAL_DB_DRIVER:-}" == "postgres" || -n "${DATABASE_URL:-}" ]]; then
  log "running postgres migrations"
  npm --prefix server run migrate:up
elif [[ -n "${SDAL_DB_PATH:-}" ]]; then
  log "ensuring sqlite runtime schema"
  npm --prefix server run sqlite:ensure-schema -- --db-path "$SDAL_DB_PATH"
  log "running cohort groups migration"
  SDAL_DB_PATH="$SDAL_DB_PATH" node server/scripts/migrate-cohort-groups.mjs || log "cohort groups migration skipped (non-fatal)"
else
  log "sqlite path not configured; runtime bootstrap will handle schema"
fi

if command -v systemctl >/dev/null 2>&1; then
  if [[ "$(id -u)" == "0" ]]; then
    [[ -n "$NPM_BIN" ]] || fail "npm binary could not be resolved"
    log "writing systemd units"
    cat >"/etc/systemd/system/$API_SERVICE_NAME" <<UNIT
[Unit]
Description=SDAL API
After=network.target

[Service]
Type=simple
User=$SERVICE_USER
WorkingDirectory=$APP_DIR/server
Environment=NODE_ENV=$NODE_ENV_VALUE
EnvironmentFile=-$ENV_FILE
ExecStart=$NPM_BIN run start
Restart=always
RestartSec=5
KillSignal=SIGTERM

[Install]
WantedBy=multi-user.target
UNIT

    cat >"/etc/systemd/system/$WORKER_SERVICE_NAME" <<UNIT
[Unit]
Description=SDAL Worker
After=network.target

[Service]
Type=simple
User=$SERVICE_USER
WorkingDirectory=$APP_DIR/server
Environment=NODE_ENV=$NODE_ENV_VALUE
EnvironmentFile=-$ENV_FILE
ExecStart=$NPM_BIN run worker
Restart=always
RestartSec=5
KillSignal=SIGTERM

[Install]
WantedBy=multi-user.target
UNIT

    systemctl daemon-reload
    systemctl enable "$API_SERVICE_NAME"
  fi

  log "restarting api service"
  systemctl restart "$API_SERVICE_NAME"

  if [[ "${SDAL_ENABLE_WORKER:-false}" == "true" ]]; then
    log "enabling worker service"
    systemctl enable "$WORKER_SERVICE_NAME"
    systemctl restart "$WORKER_SERVICE_NAME"
  elif systemctl is-active --quiet "$WORKER_SERVICE_NAME" || systemctl is-enabled --quiet "$WORKER_SERVICE_NAME" 2>/dev/null; then
    log "restarting existing worker service"
    systemctl restart "$WORKER_SERVICE_NAME" || true
  else
    log "worker service left disabled; set SDAL_ENABLE_WORKER=true to enable it"
  fi
else
  fail "systemctl is not available on this host"
fi

PORT_TO_USE="${PORT:-8787}"
log "waiting for health on port $PORT_TO_USE"
for attempt in $(seq 1 30); do
  if curl -fsS --max-time 4 "http://127.0.0.1:${PORT_TO_USE}/api/health" >/tmp/sdal-health.json 2>/dev/null; then
    cat /tmp/sdal-health.json
    log "deploy complete"
    exit 0
  fi
  sleep 2
done

systemctl status "$API_SERVICE_NAME" --no-pager -l || true
journalctl -u "$API_SERVICE_NAME" -n 120 --no-pager || true
fail "api health did not become ready"
