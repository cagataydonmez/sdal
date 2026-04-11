#!/usr/bin/env bash
set -Eeuo pipefail

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run as root (sudo -i)."
  exit 1
fi

ENV_FILE="${SDAL_ENV_FILE:-/etc/sdal/sdal.env}"
APP_PORT="${APP_PORT:-}"
APP_DOMAIN="${APP_DOMAIN:-}"
APP_DOMAIN_WWW="${APP_DOMAIN_WWW:-}"
SITE_PATH="${NGINX_SITE_PATH:-/etc/nginx/sites-available/sdal}"
SITE_LINK_PATH="${NGINX_SITE_LINK_PATH:-/etc/nginx/sites-enabled/sdal}"

if [[ -f "$ENV_FILE" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  set +a
fi

APP_PORT="${APP_PORT:-${PORT:-8787}}"

if [[ -z "$APP_DOMAIN" && -n "${SDAL_BASE_URL:-}" ]]; then
  APP_DOMAIN="$(python3 -c 'from urllib.parse import urlparse; import os; print(urlparse(os.environ["SDAL_BASE_URL"]).hostname or "")')"
fi

if [[ -z "$APP_DOMAIN" ]]; then
  echo "APP_DOMAIN is required. Export APP_DOMAIN or set SDAL_BASE_URL in ${ENV_FILE}."
  exit 1
fi

APP_DOMAIN_WWW="${APP_DOMAIN_WWW:-$APP_DOMAIN}"

TLS_LIVE_DIR="/etc/letsencrypt/live/${APP_DOMAIN}"
TLS_FULLCHAIN="${TLS_LIVE_DIR}/fullchain.pem"
TLS_PRIVKEY="${TLS_LIVE_DIR}/privkey.pem"
TLS_OPTIONS="/etc/letsencrypt/options-ssl-nginx.conf"
TLS_DHPARAM="/etc/letsencrypt/ssl-dhparams.pem"
HAS_TLS=0

if [[ -f "$TLS_FULLCHAIN" && -f "$TLS_PRIVKEY" ]]; then
  HAS_TLS=1
fi

mkdir -p "$(dirname "$SITE_PATH")" "$(dirname "$SITE_LINK_PATH")"

cat >"$SITE_PATH" <<EOF
map \$http_upgrade \$connection_upgrade {
  default upgrade;
  '' close;
}

EOF

if [[ "$HAS_TLS" -eq 1 ]]; then
  cat >>"$SITE_PATH" <<EOF
server {
  listen 80;
  server_name ${APP_DOMAIN} ${APP_DOMAIN_WWW};

  location /.well-known/acme-challenge/ {
    root /var/www/html;
  }

  location / {
    return 301 https://\$host\$request_uri;
  }
}

server {
  listen 443 ssl;
  server_name ${APP_DOMAIN} ${APP_DOMAIN_WWW};

  client_max_body_size 20m;
  ssl_certificate ${TLS_FULLCHAIN};
  ssl_certificate_key ${TLS_PRIVKEY};
EOF

  if [[ -f "$TLS_OPTIONS" ]]; then
    cat >>"$SITE_PATH" <<EOF
  include ${TLS_OPTIONS};
EOF
  fi

  if [[ -f "$TLS_DHPARAM" ]]; then
    cat >>"$SITE_PATH" <<EOF
  ssl_dhparam ${TLS_DHPARAM};
EOF
  fi

  cat >>"$SITE_PATH" <<EOF

  location / {
    proxy_pass http://127.0.0.1:${APP_PORT};
    proxy_http_version 1.1;
    proxy_set_header Host \$host;
    proxy_set_header X-Real-IP \$remote_addr;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto \$scheme;
  }

  location = /ws/chat {
    proxy_pass http://127.0.0.1:${APP_PORT};
    proxy_http_version 1.1;
    proxy_set_header Upgrade \$http_upgrade;
    proxy_set_header Connection \$connection_upgrade;
    proxy_set_header Host \$host;
    proxy_set_header X-Real-IP \$remote_addr;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto \$scheme;
  }

  location = /ws/messenger {
    proxy_pass http://127.0.0.1:${APP_PORT};
    proxy_http_version 1.1;
    proxy_set_header Upgrade \$http_upgrade;
    proxy_set_header Connection \$connection_upgrade;
    proxy_set_header Host \$host;
    proxy_set_header X-Real-IP \$remote_addr;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto \$scheme;
  }
}
EOF
else
  cat >>"$SITE_PATH" <<EOF
server {
  listen 80;
  server_name ${APP_DOMAIN} ${APP_DOMAIN_WWW};

  client_max_body_size 20m;

  location / {
    proxy_pass http://127.0.0.1:${APP_PORT};
    proxy_http_version 1.1;
    proxy_set_header Host \$host;
    proxy_set_header X-Real-IP \$remote_addr;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto \$scheme;
  }

  location = /ws/chat {
    proxy_pass http://127.0.0.1:${APP_PORT};
    proxy_http_version 1.1;
    proxy_set_header Upgrade \$http_upgrade;
    proxy_set_header Connection \$connection_upgrade;
    proxy_set_header Host \$host;
    proxy_set_header X-Real-IP \$remote_addr;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto \$scheme;
  }

  location = /ws/messenger {
    proxy_pass http://127.0.0.1:${APP_PORT};
    proxy_http_version 1.1;
    proxy_set_header Upgrade \$http_upgrade;
    proxy_set_header Connection \$connection_upgrade;
    proxy_set_header Host \$host;
    proxy_set_header X-Real-IP \$remote_addr;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto \$scheme;
  }
}
EOF
fi

ln -sf "$SITE_PATH" "$SITE_LINK_PATH"
rm -f /etc/nginx/sites-enabled/default
nginx -t
systemctl reload nginx

echo "Configured nginx site at ${SITE_PATH}"
if [[ "$HAS_TLS" -eq 1 ]]; then
  echo "TLS detected for ${APP_DOMAIN}; https + websocket routes configured."
else
  echo "TLS certificate not detected for ${APP_DOMAIN}; http + websocket routes configured."
fi
