#!/usr/bin/env bash
set -euo pipefail

APP_DIR="${APP_DIR:-/var/www/sdal}"
APP_USER="${APP_USER:-deploy}"
SDAL_ENV_FILE="${SDAL_ENV_FILE:-/etc/sdal/sdal.env}"
SQLITE_PATH="${SQLITE_PATH:-/var/lib/sdal/data/sdal.sqlite}"
BACKUP_DIR="${BACKUP_DIR:-/var/lib/sdal/backups}"
REPORT_PATH="${REPORT_PATH:-}"
API_PORT="${API_PORT:-8787}"
AUTO_ROLLBACK="${AUTO_ROLLBACK:-1}"
# For one-time cutover, force a clean modern schema to avoid legacy column drift
# (e.g. old posts.user_id vs modern posts.author_id).
RESET_POSTGRES_SCHEMA="${RESET_POSTGRES_SCHEMA:-1}"
HEALTH_MAX_ATTEMPTS="${HEALTH_MAX_ATTEMPTS:-30}"
HEALTH_RETRY_SECONDS="${HEALTH_RETRY_SECONDS:-2}"
HEALTH_REQUIRE_OK="${HEALTH_REQUIRE_OK:-1}"

if [[ ! -d "$APP_DIR/.git" ]]; then
  echo "[cutover] app repo not found at $APP_DIR"
  exit 1
fi

if [[ ! -f "$SDAL_ENV_FILE" ]]; then
  echo "[cutover] env file not found at $SDAL_ENV_FILE"
  exit 1
fi

if [[ ! -f "$SQLITE_PATH" ]]; then
  echo "[cutover] sqlite source not found at $SQLITE_PATH"
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "[cutover] jq is required"
  exit 1
fi

if ! command -v pg_dump >/dev/null 2>&1; then
  echo "[cutover] pg_dump is required"
  exit 1
fi

if sudo -n true >/dev/null 2>&1; then
  SUDO="sudo"
else
  SUDO=""
fi

run_with_priv() {
  if [[ -n "$SUDO" ]]; then
    "$SUDO" "$@"
  else
    "$@"
  fi
}

run_as_app_user() {
  local cmd="$1"
  if [[ "$(id -un)" == "$APP_USER" ]]; then
    bash -lc "$cmd"
    return
  fi

  if command -v sudo >/dev/null 2>&1; then
    sudo -u "$APP_USER" bash -lc "$cmd"
    return
  fi

  if [[ "$(id -u)" == "0" ]]; then
    su - "$APP_USER" -s /bin/bash -c "$cmd"
    return
  else
    echo "[cutover] cannot switch to APP_USER=${APP_USER}; run as root/app user or install sudo"
    return 1
  fi
}

set_env_value() {
  local key="$1"
  local value="$2"
  local tmp
  tmp="$(mktemp)"
  if [[ -n "$SUDO" ]]; then
    $SUDO cat "$SDAL_ENV_FILE" >"$tmp"
  else
    cp "$SDAL_ENV_FILE" "$tmp"
  fi
  if grep -qE "^${key}=" "$tmp"; then
    sed -i.bak "s|^${key}=.*|${key}=${value}|" "$tmp"
    rm -f "${tmp}.bak"
  else
    printf '\n%s=%s\n' "$key" "$value" >>"$tmp"
  fi
  run_with_priv cp "$tmp" "$SDAL_ENV_FILE"
  rm -f "$tmp"
}

systemd_unit_exists() {
  local unit="$1"
  systemctl list-unit-files --type=service --all --no-legend --no-pager 2>/dev/null | awk '{print $1}' | grep -Fxq "$unit"
}

stop_sdal_services() {
  if systemd_unit_exists "sdal-worker.service"; then
    run_with_priv systemctl stop sdal-worker.service
  fi
  if systemd_unit_exists "sdal-api.service"; then
    run_with_priv systemctl stop sdal-api.service
  fi
}

start_sdal_services() {
  if systemd_unit_exists "sdal-api.service"; then
    run_with_priv systemctl start sdal-api.service
  fi
  if systemd_unit_exists "sdal-worker.service"; then
    run_with_priv systemctl start sdal-worker.service
  fi
}

TS="$(date +%Y%m%d-%H%M%S)"
ENV_BACKUP_PATH="${BACKUP_DIR}/sdal-env-precutover-${TS}.env"
SQLITE_BACKUP_PATH="${BACKUP_DIR}/sqlite-precutover-${TS}.sqlite"
PG_BACKUP_PATH="${BACKUP_DIR}/postgres-precutover-${TS}.dump"
if [[ -z "$REPORT_PATH" ]]; then
  REPORT_PATH="${BACKUP_DIR}/migration-report-${TS}.json"
fi
REPORT_DIR="$(dirname "$REPORT_PATH")"
ROLLBACK_USED=0

rollback_to_sqlite() {
  if [[ "$ROLLBACK_USED" == "1" ]]; then
    return
  fi
  ROLLBACK_USED=1

  echo "[cutover] rollback: restoring env from ${ENV_BACKUP_PATH}"
  if [[ -f "$ENV_BACKUP_PATH" ]]; then
    run_with_priv cp "$ENV_BACKUP_PATH" "$SDAL_ENV_FILE"
  else
    set_env_value "SDAL_DB_DRIVER" "sqlite"
    set_env_value "SDAL_DB_PATH" "$SQLITE_PATH"
  fi

  echo "[cutover] rollback: restarting services with sqlite config"
  start_sdal_services
}

fail_with() {
  local message="$1"
  echo "[cutover] ERROR: ${message}"
  if [[ "$AUTO_ROLLBACK" == "1" ]]; then
    rollback_to_sqlite || true
  fi
  exit 1
}

health_payload_passes() {
  local body="$1"
  node -e '
    try {
      const body = JSON.parse(process.argv[1]);
      const requireOk = String(process.argv[2] || "1") === "1";
      if (requireOk && !body.ok) process.exit(10);
      if (!body.dbReady) process.exit(11);
      if (String(body.dbDriver || "") !== "postgres") process.exit(12);
      process.exit(0);
    } catch {
      process.exit(20);
    }
  ' "$body" "$HEALTH_REQUIRE_OK"
}

run_with_priv mkdir -p "$BACKUP_DIR"
run_with_priv mkdir -p "$REPORT_DIR"
run_with_priv cp "$SDAL_ENV_FILE" "$ENV_BACKUP_PATH"
run_with_priv cp "$SQLITE_PATH" "$SQLITE_BACKUP_PATH"

if id "$APP_USER" >/dev/null 2>&1; then
  APP_GROUP="$(id -gn "$APP_USER" 2>/dev/null || echo "$APP_USER")"
  run_with_priv chown "$APP_USER:$APP_GROUP" "$REPORT_DIR" || true
fi

set -a
# shellcheck disable=SC1090
source "$SDAL_ENV_FILE"
set +a

if [[ -z "${DATABASE_URL:-}" ]]; then
  fail_with "DATABASE_URL is required in ${SDAL_ENV_FILE}"
fi

echo "[cutover] taking postgres pre-cutover backup: ${PG_BACKUP_PATH}"
if ! run_as_app_user "pg_dump \"$DATABASE_URL\" -Fc -f \"$PG_BACKUP_PATH\""; then
  fail_with "postgres backup failed"
fi

echo "[cutover] stopping sdal services"
stop_sdal_services

if [[ "$RESET_POSTGRES_SCHEMA" == "1" ]]; then
  echo "[cutover] resetting postgres public schema (backup already taken)"
  if ! run_as_app_user "psql \"$DATABASE_URL\" -v ON_ERROR_STOP=1 -c 'DROP SCHEMA IF EXISTS public CASCADE; CREATE SCHEMA public;'"; then
    fail_with "failed to reset postgres public schema; disable with RESET_POSTGRES_SCHEMA=0 if you need non-destructive mode"
  fi
fi

echo "[cutover] migrate status (before)"
if ! run_as_app_user "cd '$APP_DIR' && set -a && source '$SDAL_ENV_FILE' && set +a && npm --prefix server run migrate:status"; then
  fail_with "migrate:status (before) failed"
fi

echo "[cutover] applying schema migrations"
if ! run_as_app_user "cd '$APP_DIR' && set -a && source '$SDAL_ENV_FILE' && set +a && npm --prefix server run migrate:up"; then
  fail_with "migrate:up failed"
fi

echo "[cutover] migrate status (after)"
if ! run_as_app_user "cd '$APP_DIR' && set -a && source '$SDAL_ENV_FILE' && set +a && npm --prefix server run migrate:status"; then
  fail_with "migrate:status (after) failed"
fi

echo "[cutover] running sqlite -> postgres data migration"
if ! run_as_app_user "touch '$REPORT_PATH'"; then
  fail_with "report path is not writable by ${APP_USER}: ${REPORT_PATH}"
fi
if ! run_as_app_user "cd '$APP_DIR' && set -a && source '$SDAL_ENV_FILE' && set +a && npm --prefix server run migrate:data -- --sqlite '$SQLITE_PATH' --report '$REPORT_PATH'"; then
  fail_with "migrate:data failed"
fi

if [[ ! -f "$REPORT_PATH" ]]; then
  fail_with "migration report missing at ${REPORT_PATH}"
fi

MISMATCH_COUNT="$(jq -r '.summary.mismatchCount // 0' "$REPORT_PATH")"
FK_VIOLATION_COUNT="$(jq -r '.summary.fkViolationCount // 0' "$REPORT_PATH")"

if [[ "$MISMATCH_COUNT" != "0" || "$FK_VIOLATION_COUNT" != "0" ]]; then
  fail_with "migration report indicates issues (mismatch=${MISMATCH_COUNT} fk=${FK_VIOLATION_COUNT})"
fi

echo "[cutover] switching runtime driver to postgres"
set_env_value "SDAL_DB_DRIVER" "postgres"
set_env_value "SDAL_DB_PATH" "$SQLITE_PATH"

echo "[cutover] starting sdal services"
start_sdal_services

HEALTH_BODY=""
health_ok=0
for ((attempt=1; attempt<=HEALTH_MAX_ATTEMPTS; attempt+=1)); do
  HEALTH_BODY="$(curl -fsS "http://127.0.0.1:${API_PORT}/api/health" || true)"
  if [[ -n "$HEALTH_BODY" ]] && health_payload_passes "$HEALTH_BODY"; then
    health_ok=1
    break
  fi
  sleep "$HEALTH_RETRY_SECONDS"
done

if [[ "$health_ok" != "1" ]]; then
  echo "[cutover] health payload (last attempt): ${HEALTH_BODY:-<empty>}"
  if systemd_unit_exists "sdal-api.service"; then
    echo "[cutover] sdal-api unit db env directives:"
    run_with_priv systemctl cat sdal-api.service | grep -nE 'Environment(File)?=.*(SDAL_DB_DRIVER|DATABASE_URL|/etc/sdal/sdal.env)' || true
  fi
  if systemd_unit_exists "sdal-worker.service"; then
    echo "[cutover] sdal-worker unit db env directives:"
    run_with_priv systemctl cat sdal-worker.service | grep -nE 'Environment(File)?=.*(SDAL_DB_DRIVER|DATABASE_URL|/etc/sdal/sdal.env)' || true
  fi
  if systemd_unit_exists "sdal-api.service"; then
    echo "[cutover] sdal-api status:"
    run_with_priv systemctl status sdal-api.service --no-pager -l || true
    echo "[cutover] sdal-api journal tail:"
    run_with_priv journalctl -u sdal-api.service -n 80 --no-pager || true
  fi
  fail_with "health validation failed after cutover (attempts=${HEALTH_MAX_ATTEMPTS}, require_ok=${HEALTH_REQUIRE_OK})"
fi

echo "[cutover] success"
echo "[cutover] sqlite backup: ${SQLITE_BACKUP_PATH}"
echo "[cutover] postgres backup: ${PG_BACKUP_PATH}"
echo "[cutover] env backup: ${ENV_BACKUP_PATH}"
echo "[cutover] report: ${REPORT_PATH}"
