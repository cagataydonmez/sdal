#!/usr/bin/env bash
set -euo pipefail

APP_DIR="${APP_DIR:-/var/www/sdal}"
BRANCH="${BRANCH:-main}"
ENV_FILE="${ENV_FILE:-/etc/sdal/sdal.env}"
CAPTURE_HOST_SNAPSHOT="${CAPTURE_HOST_SNAPSHOT:-1}"
CAPTURE_DOMAIN_BASELINE="${CAPTURE_DOMAIN_BASELINE:-1}"
SKIP_DOMAIN_REGRESSION_GUARD="${SKIP_DOMAIN_REGRESSION_GUARD:-0}"
HOST_SNAPSHOT_ROOT="${HOST_SNAPSHOT_ROOT:-/var/lib/sdal/backups/host-snapshots}"

TS="$(date +%Y%m%d-%H%M%S)"
WORK_DIR="$(mktemp -d /tmp/sdal-deploy-${TS}-XXXXXX)"
NGINX_DUMP_FILE="${WORK_DIR}/nginx-T.before.txt"
DOMAINS_FILE="${WORK_DIR}/domains.txt"
DOMAIN_STATUS_BEFORE_FILE="${WORK_DIR}/domain-status-before.tsv"
DOMAIN_STATUS_AFTER_FILE="${WORK_DIR}/domain-status-after.tsv"
HOST_SNAPSHOT_DIR="${HOST_SNAPSHOT_ROOT}/${TS}"

cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

log() {
  echo "[deploy] $*"
}

if [[ ! -d "$APP_DIR/.git" ]]; then
  log "Git repo not found at $APP_DIR"
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

capture_nginx_dump() {
  if ! command -v nginx >/dev/null 2>&1; then
    log "nginx not found; skipping nginx domain snapshot"
    return
  fi
  if [[ -n "$SUDO" ]]; then
    $SUDO nginx -T >"$NGINX_DUMP_FILE" 2>&1 || true
  else
    nginx -T >"$NGINX_DUMP_FILE" 2>&1 || true
  fi
}

extract_domains_from_nginx_dump() {
  if [[ ! -f "$NGINX_DUMP_FILE" ]]; then
    : >"$DOMAINS_FILE"
    return
  fi

  awk '
    /server_name[[:space:]]/ {
      for (i = 1; i <= NF; i++) {
        if ($i == "server_name") continue
        gsub(/;/, "", $i)
        if ($i == "" || $i == "_" || $i ~ /^\$/ || $i ~ /\*/) continue
        print $i
      }
    }
  ' "$NGINX_DUMP_FILE" | sort -u >"$DOMAINS_FILE"
}

http_status_for_domain() {
  local domain="$1"
  curl -ksS -o /dev/null -w "%{http_code}" --max-time 10 -H "Host: ${domain}" "http://127.0.0.1/" || echo "000"
}

capture_domain_statuses() {
  local output_file="$1"
  : >"$output_file"

  if [[ "$CAPTURE_DOMAIN_BASELINE" != "1" ]]; then
    return
  fi

  while IFS= read -r domain; do
    local status
    [[ -z "$domain" ]] && continue
    status="$(http_status_for_domain "$domain")"
    printf '%s\t%s\n' "$domain" "$status" >>"$output_file"
  done <"$DOMAINS_FILE"
}

is_healthy_status() {
  local status="${1:-000}"
  [[ "$status" =~ ^[0-9]{3}$ ]] || return 1
  [[ "$status" != "000" ]] || return 1
  [[ "${status:0:1}" != "5" ]] || return 1
  return 0
}

compare_domain_statuses() {
  if [[ "$CAPTURE_DOMAIN_BASELINE" != "1" || ! -s "$DOMAIN_STATUS_BEFORE_FILE" ]]; then
    return
  fi

  declare -A before_map
  while IFS=$'\t' read -r domain status; do
    before_map["$domain"]="$status"
  done <"$DOMAIN_STATUS_BEFORE_FILE"

  local regressions=0
  while IFS=$'\t' read -r domain after_status; do
    local before_status
    before_status="${before_map[$domain]:-}"
    if [[ -z "$before_status" ]]; then
      continue
    fi

    if is_healthy_status "$before_status" && ! is_healthy_status "$after_status"; then
      log "domain regression detected: ${domain} before=${before_status} after=${after_status}"
      regressions=$((regressions + 1))
    fi
  done <"$DOMAIN_STATUS_AFTER_FILE"

  if [[ "$regressions" -gt 0 && "$SKIP_DOMAIN_REGRESSION_GUARD" != "1" ]]; then
    log "failing deploy due to ${regressions} domain regression(s)"
    return 1
  fi
}

capture_host_snapshot() {
  if [[ "$CAPTURE_HOST_SNAPSHOT" != "1" ]]; then
    return
  fi

  if ! run_with_priv mkdir -p "$HOST_SNAPSHOT_DIR"; then
    log "could not create host snapshot dir: ${HOST_SNAPSHOT_DIR}; continuing without host snapshot"
    return
  fi

  if [[ -f "$ENV_FILE" ]]; then
    run_with_priv cp "$ENV_FILE" "${HOST_SNAPSHOT_DIR}/sdal.env.before" || true
  fi

  [[ -d /etc/nginx ]] && run_with_priv tar -C / -czf "${HOST_SNAPSHOT_DIR}/etc-nginx.tar.gz" etc/nginx || true
  [[ -d /etc/systemd/system ]] && run_with_priv tar -C / -czf "${HOST_SNAPSHOT_DIR}/etc-systemd-system.tar.gz" etc/systemd/system || true

  if [[ -f "$NGINX_DUMP_FILE" ]]; then
    run_with_priv cp "$NGINX_DUMP_FILE" "${HOST_SNAPSHOT_DIR}/nginx-T.before.txt" || true
  fi
  if [[ -f "$DOMAINS_FILE" ]]; then
    run_with_priv cp "$DOMAINS_FILE" "${HOST_SNAPSHOT_DIR}/domains.before.txt" || true
  fi
  if [[ -f "$DOMAIN_STATUS_BEFORE_FILE" ]]; then
    run_with_priv cp "$DOMAIN_STATUS_BEFORE_FILE" "${HOST_SNAPSHOT_DIR}/domain-status-before.tsv" || true
  fi

  log "host snapshot stored at ${HOST_SNAPSHOT_DIR}"
}

log "app_dir=$APP_DIR branch=$BRANCH"
cd "$APP_DIR"

capture_nginx_dump
extract_domains_from_nginx_dump
capture_domain_statuses "$DOMAIN_STATUS_BEFORE_FILE"
capture_host_snapshot

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

run_with_priv mkdir -p /var/lib/sdal/data /var/lib/sdal/uploads /var/lib/sdal/backups /var/lib/sdal/legacy-logs

if [[ "${SDAL_DB_DRIVER:-sqlite}" == "sqlite" ]]; then
  if [[ ! -f /var/lib/sdal/data/sdal.sqlite && -f "$APP_DIR/db/sdal.sqlite" ]]; then
    run_with_priv cp "$APP_DIR/db/sdal.sqlite" /var/lib/sdal/data/sdal.sqlite
    log "initialized sqlite db at /var/lib/sdal/data/sdal.sqlite"
  fi
fi

if [[ "${SDAL_DB_DRIVER:-}" == "postgres" && -n "${DATABASE_URL:-}" ]]; then
  log "applying postgres migrations"
  npm --prefix server run migrate:up
fi

$SUDO systemctl daemon-reload || true
$SUDO systemctl restart sdal-api.service
$SUDO systemctl restart sdal-worker.service

PORT_VALUE="${PORT:-8787}"
log "health probe on 127.0.0.1:${PORT_VALUE}"
curl -fsS "http://127.0.0.1:${PORT_VALUE}/api/health" >/dev/null

capture_domain_statuses "$DOMAIN_STATUS_AFTER_FILE"
if [[ "$CAPTURE_HOST_SNAPSHOT" == "1" ]]; then
  if [[ -f "$DOMAIN_STATUS_AFTER_FILE" ]]; then
    run_with_priv cp "$DOMAIN_STATUS_AFTER_FILE" "${HOST_SNAPSHOT_DIR}/domain-status-after.tsv" || true
  fi
fi
compare_domain_statuses

log "completed"
