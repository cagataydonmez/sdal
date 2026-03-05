# SDAL Ubuntu 24.04+ Deployment Runbook (Single Droplet, Multi-Instance Ready)

This runbook is copy/paste oriented and aligned to the current repository:
- Dual UI stays active: `/` (classic) and `/new` (modern)
- API + websocket contracts stay active: `/api/*`, `/ws/chat`, `/ws/messenger`
- Process manager: `systemd` (API + worker), no PM2

## 0) Variables (set once per shell)

## 0.1 How to find each variable on a DigitalOcean droplet

Use this section before running exports.

| Variable | How to decide/find it | Command examples |
|---|---|---|
| `APP_DOMAIN` | Your primary production domain pointing to the droplet IP (set in DNS provider panel). | `dig +short A YOUR_DOMAIN` and compare with `curl -s ifconfig.me` |
| `APP_DOMAIN_WWW` | Usually `www.YOUR_DOMAIN`. If you do not use `www`, set same value as `APP_DOMAIN`. | `dig +short A www.YOUR_DOMAIN` |
| `APP_REPO_SSH` | SSH clone URL of your GitHub repository. | On laptop/repo: `git remote get-url origin` (should be `git@github.com:ORG/REPO.git`) |
| `APP_DIR` | Deploy directory on server. Keep default unless you have a different standard. | Recommended: `/var/www/sdal` |
| `APP_USER` | Linux user that owns app files and runs systemd services. | Recommended: `deploy` (created in Section A.2) |
| `APP_GROUP` | Primary group for `APP_USER` (usually same as username). | `id -gn deploy` |
| `APP_PORT` | Internal Node port behind Nginx reverse proxy. | Keep `8787` (matches app defaults) |
| `SDAL_ENV_FILE` | Environment file path loaded by systemd units. | Keep `/etc/sdal/sdal.env` |

If this droplet already hosts an older SDAL deploy, you can discover current values:

```bash
sudo nginx -T 2>/dev/null | grep -E "server_name"
sudo certbot certificates || true
sudo systemctl cat sdal-api.service 2>/dev/null || true
sudo ls -la /etc/sdal 2>/dev/null || true
```

If DNS is not ready yet, use the droplet public IP for temporary checks:

```bash
curl -s ifconfig.me
```

Then point `A` records in your DNS provider:
- `@ -> <droplet_public_ip>`
- `www -> <droplet_public_ip>` (if using `www`)

```bash
export APP_DOMAIN="example.com"
export APP_DOMAIN_WWW="www.example.com"
export APP_REPO_SSH="git@github.com:YOUR_ORG/SDAL.git"
export APP_DIR="/var/www/sdal"
export APP_USER="deploy"
export APP_GROUP="deploy"
export APP_PORT="8787"
export SDAL_ENV_FILE="/etc/sdal/sdal.env"
```

Quick sanity check:

```bash
printf '%s\n' \
  "APP_DOMAIN=$APP_DOMAIN" \
  "APP_DOMAIN_WWW=$APP_DOMAIN_WWW" \
  "APP_REPO_SSH=$APP_REPO_SSH" \
  "APP_DIR=$APP_DIR" \
  "APP_USER=$APP_USER" \
  "APP_GROUP=$APP_GROUP" \
  "APP_PORT=$APP_PORT" \
  "SDAL_ENV_FILE=$SDAL_ENV_FILE"
```

## A) Base hardening

## A.1 Update OS + core packages

```bash
sudo apt update
sudo DEBIAN_FRONTEND=noninteractive apt -y upgrade
sudo apt install -y ca-certificates curl gnupg lsb-release unzip jq ufw fail2ban git logrotate
sudo apt autoremove -y
```

## A.2 Create deploy user and SSH access

```bash
sudo adduser --disabled-password --gecos "" "$APP_USER"
sudo usermod -aG sudo "$APP_USER"
sudo mkdir -p "/home/$APP_USER/.ssh"
sudo cp /root/.ssh/authorized_keys "/home/$APP_USER/.ssh/authorized_keys"
sudo chown -R "$APP_USER:$APP_GROUP" "/home/$APP_USER/.ssh"
sudo chmod 700 "/home/$APP_USER/.ssh"
sudo chmod 600 "/home/$APP_USER/.ssh/authorized_keys"
```

## A.3 SSH daemon hardening

```bash
sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak.$(date +%Y%m%d-%H%M%S)
sudo sed -i 's/^#\?PermitRootLogin .*/PermitRootLogin no/' /etc/ssh/sshd_config
sudo sed -i 's/^#\?PasswordAuthentication .*/PasswordAuthentication no/' /etc/ssh/sshd_config
sudo sed -i 's/^#\?PubkeyAuthentication .*/PubkeyAuthentication yes/' /etc/ssh/sshd_config
sudo sshd -t
sudo systemctl restart ssh
```

## A.4 Firewall

```bash
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow OpenSSH
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw --force enable
sudo ufw status verbose
```

## A.5 Fail2ban baseline

```bash
sudo tee /etc/fail2ban/jail.d/sshd.local >/dev/null <<'EOF'
[sshd]
enabled = true
port = ssh
logpath = %(sshd_log)s
backend = systemd
maxretry = 5
findtime = 10m
bantime = 1h
EOF
sudo systemctl enable --now fail2ban
sudo fail2ban-client status sshd
```

## A.6 Time sync

```bash
sudo timedatectl set-timezone UTC
sudo timedatectl set-ntp true
timedatectl status
```

## B) Install runtime dependencies

## B.1 Node.js LTS (major pinned to 20.x)

```bash
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt install -y nodejs build-essential
node -v
npm -v
```

## B.2 PostgreSQL install + secure local access

```bash
sudo apt install -y postgresql postgresql-contrib
sudo systemctl enable --now postgresql
sudo -u postgres psql -c "SELECT version();"
```

Create app role + DB:

```bash
export PG_APP_DB="sdal_prod"
export PG_APP_USER="sdal_app"
export PG_APP_PASS="$(openssl rand -base64 36 | tr -d '\n')"
echo "PG_APP_PASS=$PG_APP_PASS"

sudo -u postgres psql <<EOF
DO \$\$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = '${PG_APP_USER}') THEN
    CREATE ROLE ${PG_APP_USER} LOGIN PASSWORD '${PG_APP_PASS}';
  END IF;
END
\$\$;
EOF

sudo -u postgres psql -tc "SELECT 1 FROM pg_database WHERE datname='${PG_APP_DB}'" | grep -q 1 || \
sudo -u postgres createdb -O "${PG_APP_USER}" "${PG_APP_DB}"
```

Lock PostgreSQL to localhost:

```bash
PGVER="$(psql -V | awk '{print $3}' | cut -d. -f1)"
PGCONF="/etc/postgresql/${PGVER}/main/postgresql.conf"
PGHBA="/etc/postgresql/${PGVER}/main/pg_hba.conf"

sudo sed -i "s/^#\?listen_addresses.*/listen_addresses = '127.0.0.1'/" "$PGCONF"
sudo tee "$PGHBA" >/dev/null <<EOF
# TYPE  DATABASE        USER            ADDRESS                 METHOD
local   all             postgres                                peer
local   all             all                                     scram-sha-256
host    all             all             127.0.0.1/32            scram-sha-256
host    all             all             ::1/128                 scram-sha-256
EOF
sudo systemctl restart postgresql
```

## B.3 Redis install + secure local access

```bash
sudo apt install -y redis-server
export REDIS_PASS="$(openssl rand -base64 36 | tr -d '\n')"
echo "REDIS_PASS=$REDIS_PASS"
```

```bash
sudo cp /etc/redis/redis.conf /etc/redis/redis.conf.bak.$(date +%Y%m%d-%H%M%S)
sudo sed -i "s/^#\?bind .*/bind 127.0.0.1 ::1/" /etc/redis/redis.conf
sudo sed -i "s/^#\?protected-mode .*/protected-mode yes/" /etc/redis/redis.conf
sudo sed -i "s/^#\?port .*/port 6379/" /etc/redis/redis.conf
sudo sed -i "s/^#\?requirepass .*/requirepass ${REDIS_PASS}/" /etc/redis/redis.conf
sudo systemctl enable --now redis-server
redis-cli -a "$REDIS_PASS" ping
```

## C) App deployment

## C.1 Clone and install

```bash
sudo mkdir -p /var/www
sudo chown -R "$APP_USER:$APP_GROUP" /var/www
sudo -u "$APP_USER" git clone "$APP_REPO_SSH" "$APP_DIR"
```

```bash
sudo mkdir -p /var/lib/sdal/data /var/lib/sdal/uploads /var/lib/sdal/backups /var/lib/sdal/legacy-logs /etc/sdal
sudo chown -R "$APP_USER:$APP_GROUP" /var/lib/sdal /etc/sdal
```

```bash
sudo -u "$APP_USER" bash -lc "cd '$APP_DIR' && npm --prefix server ci --omit=dev && npm --prefix frontend-classic ci && npm --prefix frontend-modern ci && npm run build"
```

Seed SQLite file only if you need legacy data migration:

```bash
if [ ! -f /var/lib/sdal/data/sdal.sqlite ] && [ -f "$APP_DIR/db/sdal.sqlite" ]; then
  sudo -u "$APP_USER" cp "$APP_DIR/db/sdal.sqlite" /var/lib/sdal/data/sdal.sqlite
fi
```

## C.2 Configure environment

```bash
sudo -u "$APP_USER" cp "$APP_DIR/server/.env.example" /tmp/sdal.env
```

Edit `/tmp/sdal.env` with real values, then install:

```bash
sudo mv /tmp/sdal.env "$SDAL_ENV_FILE"
sudo chown root:"$APP_GROUP" "$SDAL_ENV_FILE"
sudo chmod 640 "$SDAL_ENV_FILE"
```

Required production values to set in `$SDAL_ENV_FILE`:
- `NODE_ENV=production`
- `PORT=8787`
- `SDAL_BASE_URL=https://$APP_DOMAIN`
- `SDAL_SESSION_SECRET=<long random>`
- `SDAL_ADMIN_PASSWORD=<strong>`
- `SDAL_LEGACY_ROOT_DIR=/var/lib/sdal/legacy-logs`
- `SDAL_UPLOADS_DIR=/var/lib/sdal/uploads`
- `SDAL_DB_DRIVER=postgres`
- `DATABASE_URL=postgresql://$PG_APP_USER:$PG_APP_PASS@127.0.0.1:5432/$PG_APP_DB`
- `REDIS_URL=redis://:$REDIS_PASS@127.0.0.1:6379/0`
- SMTP/API mail vars

Generate secure app secrets:

```bash
echo "SDAL_SESSION_SECRET=$(openssl rand -base64 48 | tr -d '\n')"
echo "ROOT_BOOTSTRAP_PASSWORD=$(openssl rand -base64 36 | tr -d '\n')"
```

## C.3 Run DB migrations + one-time SQLite -> PostgreSQL migration

```bash
sudo -u "$APP_USER" bash -lc "cd '$APP_DIR' && set -a && source '$SDAL_ENV_FILE' && set +a && npm --prefix server run migrate:up"
```

Take pre-cutover backups:

```bash
TS="$(date +%Y%m%d-%H%M%S)"
if [ -f /var/lib/sdal/data/sdal.sqlite ]; then
  sudo -u "$APP_USER" cp /var/lib/sdal/data/sdal.sqlite "/var/lib/sdal/backups/sqlite-precutover-$TS.sqlite"
fi
sudo -u "$APP_USER" pg_dump "postgresql://${PG_APP_USER}:${PG_APP_PASS}@127.0.0.1:5432/${PG_APP_DB}" -Fc -f "/var/lib/sdal/backups/postgres-precutover-$TS.dump"
```

Run one-time migration (only once per production cutover):

```bash
if [ ! -f /var/lib/sdal/.pg_migrated ]; then
  sudo -u "$APP_USER" bash -lc "cd '$APP_DIR' && set -a && source '$SDAL_ENV_FILE' && set +a && npm --prefix server run migrate:data -- --sqlite '/var/lib/sdal/data/sdal.sqlite' --report '$APP_DIR/migration_report.json'"
  sudo -u "$APP_USER" touch /var/lib/sdal/.pg_migrated
fi
```

Validate report:

```bash
sudo -u "$APP_USER" cat "$APP_DIR/migration_report.json" | jq
```

## C.4 systemd services (API + worker)

Create API service:

```bash
sudo tee /etc/systemd/system/sdal-api.service >/dev/null <<EOF
[Unit]
Description=SDAL API Service
After=network.target postgresql.service redis-server.service
Wants=postgresql.service redis-server.service

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
```

Create worker service:

```bash
sudo tee /etc/systemd/system/sdal-worker.service >/dev/null <<EOF
[Unit]
Description=SDAL Background Worker
After=network.target postgresql.service redis-server.service sdal-api.service
Wants=postgresql.service redis-server.service

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
```

Enable and start:

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now sdal-api.service sdal-worker.service
sudo systemctl status sdal-api.service --no-pager
sudo systemctl status sdal-worker.service --no-pager
```

## C.5 Nginx reverse proxy (frontend + API + websocket upgrades)

Install Nginx:

```bash
sudo apt install -y nginx
sudo systemctl enable --now nginx
```

Create site config:

```bash
sudo tee /etc/nginx/sites-available/sdal >/dev/null <<'EOF'
map $http_upgrade $connection_upgrade {
  default upgrade;
  '' close;
}

server {
  listen 80;
  server_name example.com www.example.com;

  client_max_body_size 20m;

  # Keep Node as source of truth for classic + modern UI routing behavior.
  location / {
    proxy_pass http://127.0.0.1:8787;
    proxy_http_version 1.1;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
  }

  location = /ws/chat {
    proxy_pass http://127.0.0.1:8787;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection $connection_upgrade;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
  }

  location = /ws/messenger {
    proxy_pass http://127.0.0.1:8787;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection $connection_upgrade;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
  }
}
EOF
```

Set domain in config and enable:

```bash
sudo sed -i "s/server_name example.com www.example.com;/server_name ${APP_DOMAIN} ${APP_DOMAIN_WWW};/" /etc/nginx/sites-available/sdal
sudo ln -sf /etc/nginx/sites-available/sdal /etc/nginx/sites-enabled/sdal
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t
sudo systemctl reload nginx
```

## C.6 HTTPS with Let's Encrypt (certbot)

```bash
sudo apt install -y certbot python3-certbot-nginx
sudo certbot --nginx -d "$APP_DOMAIN" -d "$APP_DOMAIN_WWW" --redirect --agree-tos -m "admin@$APP_DOMAIN" --no-eff-email
sudo certbot renew --dry-run
```

## C.7 Log rotation

Journald size limits:

```bash
sudo mkdir -p /etc/systemd/journald.conf.d
sudo tee /etc/systemd/journald.conf.d/sdal.conf >/dev/null <<'EOF'
[Journal]
SystemMaxUse=1G
RuntimeMaxUse=256M
MaxRetentionSec=14day
EOF
sudo systemctl restart systemd-journald
```

Rotate app and legacy file logs:

```bash
sudo tee /etc/logrotate.d/sdal >/dev/null <<'EOF'
/var/www/sdal/logs/*.log /var/lib/sdal/legacy-logs/hatalog/* /var/lib/sdal/legacy-logs/sayfalog/* /var/lib/sdal/legacy-logs/uyedetaylog/* {
  daily
  rotate 14
  missingok
  notifempty
  compress
  delaycompress
  copytruncate
  su deploy deploy
}
EOF
sudo logrotate -f /etc/logrotate.d/sdal
```

## D) Backups

## D.1 Daily PostgreSQL backups (cron + retention)

Create backup script:

```bash
sudo tee /usr/local/bin/sdal-pg-backup.sh >/dev/null <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

BACKUP_DIR="/var/lib/sdal/backups/postgres"
mkdir -p "$BACKUP_DIR"
chmod 700 "$BACKUP_DIR"

TS="$(date +%Y%m%d-%H%M%S)"
OUT="$BACKUP_DIR/sdal-prod-$TS.dump"

if [[ -f /etc/sdal/sdal.env ]]; then
  set -a
  source /etc/sdal/sdal.env
  set +a
fi

pg_dump "$DATABASE_URL" -Fc -f "$OUT"
find "$BACKUP_DIR" -type f -name '*.dump' -mtime +14 -delete
EOF
sudo chmod 750 /usr/local/bin/sdal-pg-backup.sh
sudo chown root:root /usr/local/bin/sdal-pg-backup.sh
```

Schedule daily backup at 03:10:

```bash
echo "10 3 * * * root /usr/local/bin/sdal-pg-backup.sh" | sudo tee /etc/cron.d/sdal-pg-backup >/dev/null
sudo chmod 644 /etc/cron.d/sdal-pg-backup
sudo run-parts --test /etc/cron.d
```

Run now once:

```bash
sudo /usr/local/bin/sdal-pg-backup.sh
ls -lah /var/lib/sdal/backups/postgres
```

## D.2 Restore instructions

```bash
export RESTORE_DUMP="/var/lib/sdal/backups/postgres/sdal-prod-YYYYmmdd-HHMMSS.dump"
set -a; source "$SDAL_ENV_FILE"; set +a
pg_restore --clean --if-exists --no-owner --no-privileges -d "$DATABASE_URL" "$RESTORE_DUMP"
```

## D.3 Uploads backup note

Current uploads live at `/var/lib/sdal/uploads`. Back up with `rsync`, block storage snapshot, or object storage sync:

```bash
sudo rsync -a --delete /var/lib/sdal/uploads/ /var/lib/sdal/backups/uploads-current/
```

Future plan: switch storage provider to object storage (DigitalOcean Spaces/S3-compatible) and reduce local disk coupling.

## E) Monitoring and operations

## E.1 Service and health checks

```bash
sudo systemctl status sdal-api.service --no-pager
sudo systemctl status sdal-worker.service --no-pager
curl -sS "https://$APP_DOMAIN/api/health" | jq
```

## E.2 Live logs

```bash
sudo journalctl -u sdal-api.service -n 150 --no-pager
sudo journalctl -u sdal-worker.service -n 150 --no-pager
sudo journalctl -u sdal-api.service -f
```

## E.3 DB/Redis quick checks

```bash
set -a; source "$SDAL_ENV_FILE"; set +a
psql "$DATABASE_URL" -c "SELECT NOW();"
redis-cli -u "$REDIS_URL" ping
```

## E.4 Disk and memory checks

```bash
df -h
du -h --max-depth=1 /var/lib/sdal | sort -h
free -h
```

## E.5 Slow-query inspection (`pg_stat_statements`)

Enable extension:

```bash
PGVER="$(psql -V | awk '{print $3}' | cut -d. -f1)"
PGCONF="/etc/postgresql/${PGVER}/main/postgresql.conf"
sudo sed -i "s/^#\?shared_preload_libraries.*/shared_preload_libraries = 'pg_stat_statements'/" "$PGCONF"
sudo systemctl restart postgresql
set -a; source "$SDAL_ENV_FILE"; set +a
psql "$DATABASE_URL" -c "CREATE EXTENSION IF NOT EXISTS pg_stat_statements;"
```

Top slow queries:

```bash
set -a; source "$SDAL_ENV_FILE"; set +a
psql "$DATABASE_URL" -c "
SELECT calls,
       round(total_exec_time::numeric, 2) AS total_ms,
       round(mean_exec_time::numeric, 2) AS mean_ms,
       rows,
       left(query, 160) AS sample_query
FROM pg_stat_statements
ORDER BY total_exec_time DESC
LIMIT 20;"
```

## Fresh droplet dry-run checklist

1. `sudo nginx -t` passes and `systemctl status nginx` is `active`.
2. `systemctl status sdal-api sdal-worker` both `active (running)`.
3. `curl https://$APP_DOMAIN/api/health` returns `ok: true`, `dbReady: true`, `redisReady: true`.
4. Both UIs load: `https://$APP_DOMAIN/` and `https://$APP_DOMAIN/new`.
5. Websockets connect in browser devtools for `/ws/chat` and `/ws/messenger`.
6. `migration_report.json` exists and has no FK mismatch alarms before cutover completion.
7. Backup job created dump files under `/var/lib/sdal/backups/postgres`.
8. TLS renewal dry-run succeeds.

## Rollback quick reference

1. Code rollback: checkout previous commit/tag, rebuild, restart `sdal-api` + `sdal-worker`.
2. DB rollback before cutover failure: restore SQLite service config and restart.
3. DB rollback after Postgres cutover failure:
   - restore pre-cutover dump via `pg_restore`
   - or switch env back to SQLite and restart services.
4. Keep `/var/lib/sdal/backups/sqlite-precutover-*.sqlite` and `/var/lib/sdal/backups/postgres-precutover-*.dump` until post-cutover validation is complete.
