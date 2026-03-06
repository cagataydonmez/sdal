#!/usr/bin/env bash
set -uo pipefail

# Step-by-step DB migration deploy helper for Ubuntu hosts.
# Based on docs/DEPLOY_UBUNTU.md section C.3, plus service restart and quick validation.

APP_DIR_DEFAULT="/var/www/sdal"
APP_USER_DEFAULT="deploy"
SDAL_ENV_FILE_DEFAULT="/etc/sdal/sdal.env"
LOG_DIR_DEFAULT="${HOME}/sdal-deploy-logs"

APP_DIR="${APP_DIR:-$APP_DIR_DEFAULT}"
APP_USER="${APP_USER:-$APP_USER_DEFAULT}"
SDAL_ENV_FILE="${SDAL_ENV_FILE:-$SDAL_ENV_FILE_DEFAULT}"
LOG_DIR="${LOG_DIR:-$LOG_DIR_DEFAULT}"
AUTO_YES="${AUTO_YES:-0}"
SKIP_GIT_PULL="${SKIP_GIT_PULL:-0}"
SKIP_NPM_CI="${SKIP_NPM_CI:-0}"
RESTART_SERVICES="${RESTART_SERVICES:-1}"

mkdir -p "$LOG_DIR"
TS="$(date +%Y%m%d-%H%M%S)"
LOG_FILE="$LOG_DIR/deploy-db-migration-$TS.log"
REPORT_FILE="$LOG_DIR/deploy-db-migration-$TS.report.txt"

PASS_COUNT=0
FAIL_COUNT=0

print_header() {
  echo
  echo "============================================================"
  echo "$1"
  echo "============================================================"
}

note() {
  echo "[$(date '+%F %T')] $*" | tee -a "$LOG_FILE"
}

record_result() {
  local status="$1"
  local step="$2"
  if [[ "$status" == "PASS" ]]; then
    PASS_COUNT=$((PASS_COUNT + 1))
  else
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
  printf '%s | %s\n' "$status" "$step" | tee -a "$REPORT_FILE" >/dev/null
}

run_step() {
  local step="$1"
  shift

  note "STEP: $step"
  note "CMD : $*"

  if "$@" >>"$LOG_FILE" 2>&1; then
    note "RESULT: PASS - $step"
    record_result "PASS" "$step"
    return 0
  else
    local code=$?
    note "RESULT: FAIL($code) - $step"
    record_result "FAIL($code)" "$step"
    return "$code"
  fi
}

run_as_app_user() {
  local cmd="$1"
  sudo -u "$APP_USER" bash -lc "$cmd"
}

systemd_unit_exists() {
  local unit="$1"
  systemctl list-unit-files --type=service --all --no-legend --no-pager 2>/dev/null | awk '{print $1}' | grep -Fxq "$unit"
}

run_service_step_if_present() {
  local unit="$1"
  local label="$2"
  shift 2

  if systemd_unit_exists "$unit"; then
    run_step "$label" "$@"
  else
    note "STEP: $label"
    note "CMD : $*"
    note "RESULT: PASS - $label (skipped: unit $unit not found)"
    record_result "PASS" "$label (skipped: unit $unit not found)"
  fi
}

prompt_var() {
  local name="$1"
  local current="$2"
  local answer

  if [[ "$AUTO_YES" == "1" ]]; then
    export "$name=$current"
    return
  fi

  read -r -p "$name [$current]: " answer
  if [[ -n "$answer" ]]; then
    export "$name=$answer"
  else
    export "$name=$current"
  fi
}

write_summary() {
  {
    echo ""
    echo "========== SDAL DB MIGRATION DEPLOY SUMMARY =========="
    echo "Timestamp : $(date '+%F %T')"
    echo "APP_DIR   : $APP_DIR"
    echo "APP_USER  : $APP_USER"
    echo "ENV FILE  : $SDAL_ENV_FILE"
    echo "LOG FILE  : $LOG_FILE"
    echo "REPORT    : $REPORT_FILE"
    echo "PASS      : $PASS_COUNT"
    echo "FAIL      : $FAIL_COUNT"
    echo "======================================================="
  } | tee -a "$LOG_FILE" | tee -a "$REPORT_FILE" >/dev/null
}

print_header "SDAL DB migration deploy helper"
echo "This script records all outputs so you can paste failures back for fixes."
echo "Log file   : $LOG_FILE"
echo "Report file: $REPORT_FILE"

prompt_var "APP_DIR" "$APP_DIR"
prompt_var "APP_USER" "$APP_USER"
prompt_var "SDAL_ENV_FILE" "$SDAL_ENV_FILE"

if [[ "$AUTO_YES" != "1" ]]; then
  echo
  echo "Execution flags (enter to keep defaults):"
  read -r -p "SKIP_GIT_PULL [${SKIP_GIT_PULL}] (1 to skip): " _a; SKIP_GIT_PULL="${_a:-$SKIP_GIT_PULL}"
  read -r -p "SKIP_NPM_CI [${SKIP_NPM_CI}] (1 to skip): " _b; SKIP_NPM_CI="${_b:-$SKIP_NPM_CI}"
  read -r -p "RESTART_SERVICES [${RESTART_SERVICES}] (0 to skip): " _c; RESTART_SERVICES="${_c:-$RESTART_SERVICES}"
fi

print_header "Preflight checks"
run_step "Check APP_DIR exists" test -d "$APP_DIR"
run_step "Check git repo exists" test -d "$APP_DIR/.git"
run_step "Check env file exists" test -f "$SDAL_ENV_FILE"
run_step "Check sudo available" sudo -n true
run_step "Check APP_USER exists" id "$APP_USER"

if [[ "$SKIP_GIT_PULL" != "1" ]]; then
  print_header "Update repository"
  run_step "git fetch" run_as_app_user "cd '$APP_DIR' && git fetch --all --prune"
  run_step "git pull --ff-only" run_as_app_user "cd '$APP_DIR' && git pull --ff-only"
else
  note "Skipping git pull by choice"
fi

if [[ "$SKIP_NPM_CI" != "1" ]]; then
  print_header "Install server dependencies"
  run_step "npm ci (server, production deps)" run_as_app_user "cd '$APP_DIR' && npm --prefix server ci --omit=dev"
else
  note "Skipping npm ci by choice"
fi

print_header "Load env and backup"
run_step "Backup SQLite (if exists)" bash -lc '
  TS_LOCAL="$(date +%Y%m%d-%H%M%S)";
  if [[ -f /var/lib/sdal/data/sdal.sqlite ]]; then
    sudo -u "'"$APP_USER"'" mkdir -p /var/lib/sdal/backups;
    sudo -u "'"$APP_USER"'" cp /var/lib/sdal/data/sdal.sqlite "/var/lib/sdal/backups/sqlite-pre-migration-${TS_LOCAL}.sqlite";
  fi
'

run_step "Backup PostgreSQL with DATABASE_URL" bash -lc '
  set -a; source "'"$SDAL_ENV_FILE"'"; set +a;
  TS_LOCAL="$(date +%Y%m%d-%H%M%S)";
  sudo -u "'"$APP_USER"'" mkdir -p /var/lib/sdal/backups;
  if [[ -n "${DATABASE_URL:-}" ]]; then
    sudo -u "'"$APP_USER"'" pg_dump "$DATABASE_URL" -Fc -f "/var/lib/sdal/backups/postgres-pre-migration-${TS_LOCAL}.dump";
  else
    echo "DATABASE_URL not set in $SDAL_ENV_FILE";
    exit 1;
  fi
'

print_header "Run migration"
run_step "Migration status before" run_as_app_user "cd '$APP_DIR' && set -a && source '$SDAL_ENV_FILE' && set +a && npm --prefix server run migrate:status"
run_step "Apply migration up" run_as_app_user "cd '$APP_DIR' && set -a && source '$SDAL_ENV_FILE' && set +a && npm --prefix server run migrate:up"
run_step "Migration status after" run_as_app_user "cd '$APP_DIR' && set -a && source '$SDAL_ENV_FILE' && set +a && npm --prefix server run migrate:status"

if [[ "$RESTART_SERVICES" == "1" ]]; then
  print_header "Restart services"
  run_service_step_if_present "sdal-api.service" "Restart sdal-api.service" sudo systemctl restart sdal-api.service
  run_service_step_if_present "sdal-worker.service" "Restart sdal-worker.service" sudo systemctl restart sdal-worker.service
  run_service_step_if_present "sdal-api.service" "Check sdal-api active" sudo systemctl is-active --quiet sdal-api.service
  run_service_step_if_present "sdal-worker.service" "Check sdal-worker active" sudo systemctl is-active --quiet sdal-worker.service
else
  note "Skipping service restart by choice"
fi

print_header "Quick health checks"
run_step "API health endpoint" bash -lc '
  set -a; source "'"$SDAL_ENV_FILE"'"; set +a;
  PORT_TO_USE="${PORT:-8787}";
  BASE_URL_TO_USE="${SDAL_BASE_URL:-http://127.0.0.1:${PORT_TO_USE}}";
  HEALTH_HOST="$(printf "%s" "$BASE_URL_TO_USE" | sed -E "s#^[a-zA-Z]+://([^/:]+).*$#\1#")";

  if curl -fsS -H "Host: ${HEALTH_HOST}" "http://127.0.0.1:${PORT_TO_USE}/api/health" >/dev/null; then
    exit 0;
  fi

  if curl -fsS -H "Host: ${HEALTH_HOST}" "http://127.0.0.1:${PORT_TO_USE}/health" >/dev/null; then
    exit 0;
  fi

  if curl -fsS "http://127.0.0.1:${PORT_TO_USE}/api/health" >/dev/null; then
    exit 0;
  fi

  curl -fsS "http://127.0.0.1:${PORT_TO_USE}/health" >/dev/null
'

write_summary

cat <<EOF2

Done.
- Full log    : $LOG_FILE
- Short report: $REPORT_FILE

Send me BOTH files (or paste their contents), and I will fix failures step-by-step.
EOF2

# Return non-zero if any step failed.
if [[ "$FAIL_COUNT" -gt 0 ]]; then
  exit 1
fi
