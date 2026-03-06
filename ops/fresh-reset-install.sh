#!/usr/bin/env bash
set -Eeuo pipefail

trap 'echo "[ERROR] Failed at line $LINENO"; exit 1' ERR

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run as root (sudo -i)."
  exit 1
fi

read -rp "This will DELETE SDAL DB/uploads and reinstall SDAL. Type RESET to continue: " CONFIRM
if [[ "$CONFIRM" != "RESET" ]]; then
  echo "Aborted."
  exit 1
fi

echo "=== SDAL fresh reset installer ==="

read -rp "APP_DOMAIN (example.com): " APP_DOMAIN
if [[ -z "${APP_DOMAIN}" ]]; then
  echo "APP_DOMAIN is required."
  exit 1
fi

read -rp "APP_DOMAIN_WWW [www.${APP_DOMAIN}]: " APP_DOMAIN_WWW
APP_DOMAIN_WWW="${APP_DOMAIN_WWW:-www.${APP_DOMAIN}}"

read -rp "APP_REPO_SSH (git@github.com:ORG/REPO.git): " APP_REPO_SSH
if [[ -z "${APP_REPO_SSH}" ]]; then
  echo "APP_REPO_SSH is required."
  exit 1
fi

read -rp "BRANCH [main]: " BRANCH
BRANCH="${BRANCH:-main}"

read -rp "APP_DIR [/var/www/sdal]: " APP_DIR
APP_DIR="${APP_DIR:-/var/www/sdal}"

read -rp "APP_USER [deploy]: " APP_USER
APP_USER="${APP_USER:-deploy}"

read -rp "APP_GROUP [${APP_USER}]: " APP_GROUP
APP_GROUP="${APP_GROUP:-$APP_USER}"

read -rp "APP_PORT [8787]: " APP_PORT
APP_PORT="${APP_PORT:-8787}"

read -rp "Cagatay email [cagatay@${APP_DOMAIN}]: " CAGATAY_EMAIL
CAGATAY_EMAIL="${CAGATAY_EMAIL:-cagatay@${APP_DOMAIN}}"

read -rsp "root user password (login password): " ROOT_USER_PASSWORD; echo
read -rsp "cagatay user password (login password): " CAGATAY_USER_PASSWORD; echo

if [[ -z "${ROOT_USER_PASSWORD}" || -z "${CAGATAY_USER_PASSWORD}" ]]; then
  echo "Both root and cagatay passwords are required."
  exit 1
fi

read -rp "MAIL_FROM_ADDRESS [noreply@${APP_DOMAIN}]: " MAIL_FROM_ADDRESS
MAIL_FROM_ADDRESS="${MAIL_FROM_ADDRESS:-noreply@${APP_DOMAIN}}"

read -rp "BREVO_SMTP_LOGIN: " BREVO_SMTP_LOGIN
read -rsp "BREVO_SMTP_KEY: " BREVO_SMTP_KEY; echo
if [[ -z "${BREVO_SMTP_LOGIN}" || -z "${BREVO_SMTP_KEY}" ]]; then
  echo "BREVO_SMTP_LOGIN and BREVO_SMTP_KEY are required."
  exit 1
fi

read -rp "GOOGLE_OAUTH_CLIENT_ID (blank = disabled): " GOOGLE_OAUTH_CLIENT_ID
if [[ -n "${GOOGLE_OAUTH_CLIENT_ID}" ]]; then
  read -rsp "GOOGLE_OAUTH_CLIENT_SECRET: " GOOGLE_OAUTH_CLIENT_SECRET; echo
else
  GOOGLE_OAUTH_CLIENT_SECRET=""
fi

read -rp "X_OAUTH_CLIENT_ID (blank = disabled): " X_OAUTH_CLIENT_ID
if [[ -n "${X_OAUTH_CLIENT_ID}" ]]; then
  read -rsp "X_OAUTH_CLIENT_SECRET: " X_OAUTH_CLIENT_SECRET; echo
else
  X_OAUTH_CLIENT_SECRET=""
fi

read -rp "Run certbot now? [y/N]: " RUN_CERTBOT
RUN_CERTBOT="$(echo "${RUN_CERTBOT:-n}" | tr '[:upper:]' '[:lower:]')"

SDAL_ENV_FILE="/etc/sdal/sdal.env"
REDIS_PASS="$(openssl rand -hex 24)"
SDAL_SESSION_SECRET="$(openssl rand -hex 32)"
ROOT_BOOTSTRAP_PASSWORD="$ROOT_USER_PASSWORD"
SDAL_ADMIN_PASSWORD="$ROOT_USER_PASSWORD"
MAIL_WEBHOOK_SHARED_SECRET="$(openssl rand -hex 24)"

echo "=== Installing system packages ==="
apt-get update -y
DEBIAN_FRONTEND=noninteractive apt-get install -y \
  ca-certificates curl gnupg lsb-release unzip jq ufw fail2ban git logrotate \
  nginx certbot python3-certbot-nginx \
  postgresql postgresql-contrib redis-server sqlite3 build-essential

echo "=== Installing Node.js 20.x ==="
if ! command -v node >/dev/null 2>&1 || [[ "$(node -v | sed 's/^v//' | cut -d. -f1)" -lt 20 ]]; then
  curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
  apt-get install -y nodejs
fi

echo "=== Ensuring app user/group ==="
id "$APP_USER" >/dev/null 2>&1 || adduser --disabled-password --gecos "" "$APP_USER"
getent group "$APP_GROUP" >/dev/null 2>&1 || groupadd "$APP_GROUP"
usermod -aG sudo "$APP_USER" || true
usermod -aG "$APP_GROUP" "$APP_USER" || true

echo "=== Preparing directories ==="
mkdir -p /var/www /etc/sdal /var/lib/sdal/data /var/lib/sdal/uploads /var/lib/sdal/backups /var/lib/sdal/legacy-logs
chown -R "$APP_USER:$APP_GROUP" /var/www /var/lib/sdal

echo "=== Cloning/updating repo ==="
if [[ -d "$APP_DIR/.git" ]]; then
  runuser -u "$APP_USER" -- bash -lc "cd '$APP_DIR' && git fetch origin '$BRANCH' && git checkout '$BRANCH' && git pull --ff-only origin '$BRANCH'"
else
  runuser -u "$APP_USER" -- git clone --branch "$BRANCH" "$APP_REPO_SSH" "$APP_DIR"
fi

echo "=== Installing npm dependencies and building frontends ==="
runuser -u "$APP_USER" -- bash -lc "cd '$APP_DIR' && npm --prefix server install --omit=dev && npm --prefix frontend-classic ci && npm --prefix frontend-modern ci && npm run build"

echo "=== Resetting runtime data (sqlite + uploads) ==="
rm -rf /var/lib/sdal/uploads/* /var/lib/sdal/legacy-logs/* || true
cp "$APP_DIR/db/sdal.sqlite" /var/lib/sdal/data/sdal.sqlite
chown "$APP_USER:$APP_GROUP" /var/lib/sdal/data/sdal.sqlite

ROOT_USER_PASSWORD="$ROOT_USER_PASSWORD" \
CAGATAY_USER_PASSWORD="$CAGATAY_USER_PASSWORD" \
CAGATAY_EMAIL="$CAGATAY_EMAIL" \
runuser -u "$APP_USER" -- bash -lc "cd '$APP_DIR' && node server/scripts/reset-sqlite-fresh.mjs \
  --db '/var/lib/sdal/data/sdal.sqlite' \
  --root-password \"\$ROOT_USER_PASSWORD\" \
  --cagatay-password \"\$CAGATAY_USER_PASSWORD\" \
  --cagatay-email \"\$CAGATAY_EMAIL\""

echo "=== Configuring Redis ==="
cp /etc/redis/redis.conf /etc/redis/redis.conf.bak.$(date +%Y%m%d-%H%M%S)
awk '
  !/^[[:space:]]*#?[[:space:]]*bind[[:space:]]+/ &&
  !/^[[:space:]]*#?[[:space:]]*protected-mode[[:space:]]+/ &&
  !/^[[:space:]]*#?[[:space:]]*port[[:space:]]+/ &&
  !/^[[:space:]]*#?[[:space:]]*requirepass[[:space:]]+/ &&
  !/^[[:space:]]*user[[:space:]]+default[[:space:]]+/
  { print }
' /etc/redis/redis.conf > /etc/redis/redis.conf.new
{
  echo "bind 127.0.0.1 ::1"
  echo "protected-mode yes"
  echo "port 6379"
  echo "requirepass ${REDIS_PASS}"
} >> /etc/redis/redis.conf.new
mv /etc/redis/redis.conf.new /etc/redis/redis.conf
systemctl enable --now redis-server
redis-cli -a "$REDIS_PASS" ping >/dev/null

echo "=== Writing ${SDAL_ENV_FILE} ==="
cat > "$SDAL_ENV_FILE" <<EOF
NODE_ENV=production
PORT=${APP_PORT}
SDAL_BASE_URL=https://${APP_DOMAIN}
SDAL_SESSION_SECRET=${SDAL_SESSION_SECRET}
SDAL_ADMIN_PASSWORD=${SDAL_ADMIN_PASSWORD}
ROOT_BOOTSTRAP_PASSWORD=${ROOT_BOOTSTRAP_PASSWORD}
SDAL_SLOW_QUERY_MS=200
SDAL_LEGACY_ROOT_DIR=/var/lib/sdal/legacy-logs

SDAL_DB_DRIVER=sqlite
SDAL_DB_PATH=/var/lib/sdal/data/sdal.sqlite
SDAL_UPLOADS_DIR=/var/lib/sdal/uploads
SDAL_DB_REQUIRE_EXISTING=true
SDAL_DB_REQUIRED_TABLE=uyeler
SDAL_DB_AUTO_REPAIR_MISSING_SCHEMA=true
SDAL_DB_BOOTSTRAP_PATH=
SDAL_DB_DIR=

DATABASE_URL=
PGSSLMODE=disable
PGPOOL_MAX=20
PGPOOL_MIN=2
PGPOOL_IDLE_MS=30000
PGPOOL_CONNECT_TIMEOUT_MS=5000
PG_QUERY_TIMEOUT_MS=20000
PG_STATEMENT_TIMEOUT_MS=15000

REDIS_URL=redis://:${REDIS_PASS}@127.0.0.1:6379/0
REDIS_SESSION_PREFIX=sdal:sess:
REDIS_CONNECT_TIMEOUT_MS=4000
REDIS_RETRY_MAX_DELAY_MS=5000
REDIS_KEEPALIVE_MS=5000
REDIS_PING_INTERVAL_MS=30000

JOB_QUEUE_NAMESPACE=sdal:jobs:main
JOB_INLINE_WORKER=false
WS_ALLOW_LEGACY_QUERY_AUTH=false

FEED_CACHE_TTL_SECONDS=20
PROFILE_CACHE_TTL_SECONDS=25
STORY_RAIL_CACHE_TTL_SECONDS=20
ADMIN_SETTINGS_CACHE_TTL_SECONDS=45

RATE_LIMIT_LOGIN_MAX=8
RATE_LIMIT_LOGIN_WINDOW_SECONDS=600
RATE_LIMIT_CHAT_SEND_MAX=30
RATE_LIMIT_CHAT_SEND_WINDOW_SECONDS=60
RATE_LIMIT_POST_WRITE_MAX=20
RATE_LIMIT_POST_WRITE_WINDOW_SECONDS=600
RATE_LIMIT_COMMENT_WRITE_MAX=30
RATE_LIMIT_COMMENT_WRITE_WINDOW_SECONDS=600
RATE_LIMIT_UPLOAD_MAX=25
RATE_LIMIT_UPLOAD_WINDOW_SECONDS=600

MEDIA_MAX_UPLOAD_BYTES=10485760
UPLOAD_QUOTA_WINDOW_SECONDS=86400
UPLOAD_QUOTA_MAX_FILES=140
UPLOAD_QUOTA_MAX_BYTES=367001600
UPLOAD_QUOTA_ADMIN_MULTIPLIER=3

MAIL_PROVIDER=smtp
MAIL_ALLOW_MOCK=false
MAIL_SEND_TIMEOUT_MS=10000
MAIL_SEND_MAX_RETRIES=2
MAIL_SEND_RETRY_BACKOFF_MS=1200
MAIL_WEBHOOK_SHARED_SECRET=${MAIL_WEBHOOK_SHARED_SECRET}
MAIL_FROM="SDAL <${MAIL_FROM_ADDRESS}>"
MAIL_SMTP_HOST=smtp-relay.brevo.com
MAIL_SMTP_PORT=587
MAIL_SMTP_SECURE=false
MAIL_SMTP_USER="${BREVO_SMTP_LOGIN}"
MAIL_SMTP_PASS="${BREVO_SMTP_KEY}"
MAIL_SMTP_TLS_REJECT_UNAUTHORIZED=true

SMTP_HOST=smtp-relay.brevo.com
SMTP_PORT=587
SMTP_SECURE=false
SMTP_USER="${BREVO_SMTP_LOGIN}"
SMTP_PASS="${BREVO_SMTP_KEY}"
SMTP_FROM="SDAL <${MAIL_FROM_ADDRESS}>"
SMTP_TLS_REJECT_UNAUTHORIZED=true

STORAGE_PROVIDER=local
STORAGE_LOCAL_DIR=/var/lib/sdal/uploads
STORAGE_S3_BUCKET=
STORAGE_S3_REGION=
STORAGE_S3_ENDPOINT=
STORAGE_S3_ACCESS_KEY=
STORAGE_S3_SECRET_KEY=

GOOGLE_OAUTH_CLIENT_ID=${GOOGLE_OAUTH_CLIENT_ID}
GOOGLE_OAUTH_CLIENT_SECRET=${GOOGLE_OAUTH_CLIENT_SECRET}
GOOGLE_OAUTH_REDIRECT_URI=https://${APP_DOMAIN}/api/auth/oauth/google/callback
X_OAUTH_CLIENT_ID=${X_OAUTH_CLIENT_ID}
X_OAUTH_CLIENT_SECRET=${X_OAUTH_CLIENT_SECRET}
X_OAUTH_REDIRECT_URI=https://${APP_DOMAIN}/api/auth/oauth/x/callback
EOF

chown root:"$APP_GROUP" "$SDAL_ENV_FILE"
chmod 640 "$SDAL_ENV_FILE"

echo "=== Creating systemd services ==="
cat > /etc/systemd/system/sdal-api.service <<EOF
[Unit]
Description=SDAL API Service
After=network.target redis-server.service
Wants=redis-server.service

[Service]
Type=simple
User=${APP_USER}
Group=${APP_GROUP}
WorkingDirectory=${APP_DIR}
EnvironmentFile=${SDAL_ENV_FILE}
ExecStart=/usr/bin/npm --prefix ${APP_DIR}/server run start
Restart=always
RestartSec=5
TimeoutStopSec=30
KillSignal=SIGTERM
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

cat > /etc/systemd/system/sdal-worker.service <<EOF
[Unit]
Description=SDAL Background Worker
After=network.target redis-server.service sdal-api.service
Wants=redis-server.service

[Service]
Type=simple
User=${APP_USER}
Group=${APP_GROUP}
WorkingDirectory=${APP_DIR}
EnvironmentFile=${SDAL_ENV_FILE}
ExecStart=/usr/bin/npm --prefix ${APP_DIR}/server run worker
Restart=always
RestartSec=5
TimeoutStopSec=30
KillSignal=SIGTERM
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

echo "=== Configuring nginx (without touching other sites) ==="
cat > /etc/nginx/sites-available/sdal <<EOF
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
    proxy_set_header Upgrade \$http_upgrade;
    proxy_set_header Connection "upgrade";
  }
}
EOF

ln -sf /etc/nginx/sites-available/sdal /etc/nginx/sites-enabled/sdal
systemctl enable --now nginx
nginx -t
systemctl reload nginx

if [[ "$RUN_CERTBOT" == "y" || "$RUN_CERTBOT" == "yes" ]]; then
  echo "=== Running certbot ==="
  if [[ "$APP_DOMAIN_WWW" == "$APP_DOMAIN" ]]; then
    certbot --nginx -d "$APP_DOMAIN" --redirect --agree-tos -m "admin@${APP_DOMAIN}" --no-eff-email || true
  else
    certbot --nginx -d "$APP_DOMAIN" -d "$APP_DOMAIN_WWW" --redirect --agree-tos -m "admin@${APP_DOMAIN}" --no-eff-email || true
  fi
fi

echo "=== Enabling firewall baseline (ssh/http/https) ==="
ufw allow OpenSSH || true
ufw allow 80/tcp || true
ufw allow 443/tcp || true
ufw --force enable || true

systemctl daemon-reload
systemctl enable --now sdal-api.service sdal-worker.service
systemctl restart sdal-api.service sdal-worker.service

echo "=== Health check ==="
curl -fsS "http://127.0.0.1:${APP_PORT}/api/health" | jq

echo
echo "DONE"
echo "SDAL URL: https://${APP_DOMAIN}"
echo "Login users:"
echo "  username: root"
echo "  username: cagatay"
echo "Existing nginx sites were not removed (dedekorkutpedal.com untouched)."
