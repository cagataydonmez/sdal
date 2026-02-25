#!/usr/bin/env bash
set -euo pipefail

ENV_FILE="/etc/sdal/sdal.env"
if [[ ! -f "$ENV_FILE" ]]; then
  echo "[start] missing env file: $ENV_FILE" >&2
  exit 1
fi

set -a
source "$ENV_FILE"
set +a

cd /var/www/sdal
exec npm run start
