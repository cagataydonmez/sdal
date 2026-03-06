# SDAL DigitalOcean Kurulum Rehberi

Bu rehber, `frontend-classic` (nostalji), `frontend-modern` (yeni tasarim) ve `server` (API) yapisini tek bir Droplet ustunde calistirmak icindir.

## 1) On Kosullar

- Ubuntu 24.04 Droplet (en az 2 vCPU, 4 GB RAM onerilir)
- Domain DNS yonetimine erisim
- GitHub repo erisimi (deploy icin SSH key)
- Sunucuya SSH erisimi (`root` veya sudo user)

## 2) DNS

Domain panelinde:

- `A` kaydi: `@` -> `DROPLET_IP`
- `A` kaydi: `www` -> `DROPLET_IP` (istersen)

DNS yayilimi bitmeden SSL alma adimini baslatma.

## 3) Sunucu Kurulumu

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y nginx certbot python3-certbot-nginx git ufw jq postgresql postgresql-contrib redis-server
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt install -y nodejs build-essential
```

Deploy kullanicisi olustur (onerilen):

```bash
sudo adduser deploy
sudo usermod -aG sudo deploy
sudo mkdir -p /home/deploy/.ssh
sudo cp /root/.ssh/authorized_keys /home/deploy/.ssh/authorized_keys
sudo chown -R deploy:deploy /home/deploy/.ssh
sudo chmod 700 /home/deploy/.ssh
sudo chmod 600 /home/deploy/.ssh/authorized_keys
```

Firewall:

```bash
sudo ufw allow OpenSSH
sudo ufw allow 'Nginx Full'
sudo ufw --force enable
```

## 4) Repo ve Klasorler

```bash
sudo mkdir -p /var/www
sudo chown -R deploy:deploy /var/www
cd /var/www
git clone <GITHUB_REPO_SSH_URL> sdal
cd /var/www/sdal

sudo mkdir -p /var/lib/sdal/data /var/lib/sdal/uploads /var/lib/sdal/backups /etc/sdal
sudo chown -R deploy:deploy /var/lib/sdal
```

Ilk DB bootstrap (bir kez):

```bash
cp /var/www/sdal/db/sdal.sqlite /var/lib/sdal/data/sdal.sqlite
```

## 5) Environment

```bash
cp /var/www/sdal/server/.env.example /tmp/sdal.env
nano /tmp/sdal.env
sudo mv /tmp/sdal.env /etc/sdal/sdal.env
sudo chmod 600 /etc/sdal/sdal.env
```

Zorunlu degerler:

- `SDAL_BASE_URL=https://senindomainin.com`
- `SDAL_SESSION_SECRET` (uzun random)
- `SDAL_ADMIN_PASSWORD`
- `SDAL_DB_PATH=/var/lib/sdal/data/sdal.sqlite`
- `SDAL_UPLOADS_DIR=/var/lib/sdal/uploads`
- SMTP veya Resend bilgileri

PostgreSQL kullanacaksan:

- `SDAL_DB_DRIVER=postgres`
- `DATABASE_URL=postgresql://sdal_app:...@127.0.0.1:5432/sdal_prod`

Not: `ops/deploy-systemd.sh` sadece schema migration (`migrate:up`) calistirir.
SQLite -> PostgreSQL data migration icin `ops/cutover-sqlite-to-postgres.sh` kullan.

## 6) Nginx Reverse Proxy

`/etc/nginx/sites-available/sdal`:

```nginx
server {
    listen 80;
    server_name senindomainin.com www.senindomainin.com;

    client_max_body_size 20M;

    location / {
        proxy_pass http://127.0.0.1:8787;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    location /ws/chat {
        proxy_pass http://127.0.0.1:8787/ws/chat;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

Etkinlestir:

```bash
sudo ln -s /etc/nginx/sites-available/sdal /etc/nginx/sites-enabled/sdal
sudo nginx -t
sudo systemctl reload nginx
```

## 7) SSL (Let's Encrypt)

```bash
sudo certbot --nginx -d senindomainin.com -d www.senindomainin.com
```

## 8) Ilk Build ve systemd Baslatma

```bash
cd /var/www/sdal
APP_DIR=/var/www/sdal BRANCH=main bash /var/www/sdal/ops/deploy-sdal.sh
sudo systemctl status sdal-api.service --no-pager
sudo systemctl status sdal-worker.service --no-pager
```

`ops/deploy-systemd.sh` varsayilan olarak:
- `/etc/nginx`, `/etc/systemd/system`, `/etc/sdal/sdal.env` snapshot alir
- `nginx -T` server_name listesinden domain baseline alir
- deploy sonrasi domain regression kontrolu yapar (once healthy olup sonra 5xx/000 olursa fail)

Gecici bypass (onerilmez):
```bash
SKIP_DOMAIN_REGRESSION_GUARD=1 bash /var/www/sdal/ops/deploy-systemd.sh
```

Kontrol:

- `https://senindomainin.com/new`
- `https://senindomainin.com/api/health`

## 9) GitHub Auto Deploy

GitHub repository `Settings -> Secrets and variables -> Actions` altina:

- `DO_HOST` = droplet ip
- `DO_PORT` = `22`
- `DO_USER` = deploy user (onerilen: `deploy`)
- `DO_SSH_KEY` = private key
- `DO_APP_DIR` = `/var/www/sdal`
- `DO_ENV_FILE` = `/etc/sdal/sdal.env` (opsiyonel; bossa varsayilan bu)

GitHub repository `Settings -> Variables -> Actions` altina:

- `EXPECTED_DB_DRIVER` = `postgres` (onerilen)

`main` branch'e push oldugunda `.github/workflows/deploy.yml`:
1. server smoke testleri + migration dosya sanity kontrolu calistirir.
2. basariliysa SSH ile `ops/deploy-systemd.sh` tetikler.
3. deploy sonrasi `/api/health` yanitini uzaktan dogrular ve `dbDriver` kontrolu yapar.

Branch protection icin onerilen:
- `main` branch merge oncesi bu workflow'un basarili olmasini zorunlu kil.

## 10) In-Place SQLite -> PostgreSQL Cutover (Maintenance Window)

```bash
cd /var/www/sdal
sudo APP_DIR=/var/www/sdal \
  APP_USER=deploy \
  SDAL_ENV_FILE=/etc/sdal/sdal.env \
  SQLITE_PATH=/var/lib/sdal/data/sdal.sqlite \
  bash /var/www/sdal/ops/cutover-sqlite-to-postgres.sh
```

Script sunlari yapar:
- sqlite/postgres/env backup
- `sdal-api` + `sdal-worker` stop/start
- varsayilan olarak Postgres `public` schema reset (temiz modern schema icin)
- `migrate:up` + `migrate:data`
- `migration_report.json` mismatch/FK gate
- health gate (`ok=true`, `dbReady=true`, `dbDriver=postgres`)
- hata durumunda otomatik SQLite rollback

## 11) Yedekleme Onerisi

Gunde en az 1 kez:

- `/var/lib/sdal/data/sdal.sqlite`
- `/var/lib/sdal/uploads`

Ilk asamada basit cron ile local backup alip DigitalOcean Spaces veya baska bir yere tasiyabilirsin.
