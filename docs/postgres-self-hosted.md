# SDAL - Self-Hosted PostgreSQL (Ubuntu Droplet)

Bu dokuman sadece PostgreSQL sunucu kurulumunu ve temel guvenli ayarlari kapsar.

Not: `server/db.js` icinde kademeli postgres calisma modu eklendi (`SDAL_DB_DRIVER=postgres` + `DATABASE_URL`).

## 1) Kurulum

```bash
sudo apt update
sudo apt install -y postgresql postgresql-contrib
sudo systemctl enable postgresql
sudo systemctl start postgresql
```

## 2) SDAL veritabani ve kullanici olustur

`CHANGE_ME_STRONG_PASSWORD` degerini degistir:

```bash
sudo -u postgres psql <<'SQL'
CREATE ROLE sdal_app WITH LOGIN PASSWORD 'CHANGE_ME_STRONG_PASSWORD';
CREATE DATABASE sdal_prod OWNER sdal_app;
\c sdal_prod
CREATE SCHEMA IF NOT EXISTS public AUTHORIZATION sdal_app;
GRANT ALL PRIVILEGES ON DATABASE sdal_prod TO sdal_app;
SQL
```

## 3) Guvenlik (local-only)

Varsayilan olarak local socket/localhost erisimi yeterli. Disaridan 5432 acma.

Kontrol:

```bash
sudo ss -ltnp | rg 5432
```

UFW'de `5432` portunu acma.

## 4) Uygulama baglanti degiskenleri (hazirlik)

PostgreSQL migration tamamlandiginda kullanilacak:

```env
DATABASE_URL=postgresql://sdal_app:CHANGE_ME_STRONG_PASSWORD@127.0.0.1:5432/sdal_prod
```

Ve:

```env
SDAL_DB_DRIVER=postgres
```

## 4.1) Bir kez veri tasima (SQLite -> PostgreSQL)

```bash
cd /var/www/sdal
DATABASE_URL=postgresql://sdal_app:CHANGE_ME_STRONG_PASSWORD@127.0.0.1:5432/sdal_prod \
SQLITE_PATH=/var/lib/sdal/data/sdal.sqlite \
npm --prefix server run migrate:pg
```

## 5) Backup (gunluk)

```bash
mkdir -p /var/lib/sdal/backups/postgres
pg_dump -U sdal_app -h 127.0.0.1 -d sdal_prod -Fc > /var/lib/sdal/backups/postgres/sdal_$(date +%F_%H%M).dump
```

Cron ile gunluk calistir.
