# SDAL Email Setup Runbook (Phase 9)

This runbook implements two production paths:
1. Recommended (primary): Brevo SMTP free tier
2. Fallback: self-hosted Postfix on the droplet

The app is already wired for:
- provider abstraction (`MAIL_PROVIDER`)
- retries/timeouts (`MAIL_SEND_*`)
- webhook ingestion for delivery/bounce signals (`POST /api/mail/webhooks/brevo`)

## 0) Current integration points in this repo

- Mail runtime: `server/src/infra/mailSender.js`
- Queue worker mail job: `server/worker.js` (`mail.send`)
- Mail triggers:
  - activation: `POST /api/activation/resend`
  - password reset: `POST /api/password-reset`
  - admin bulk mail: `POST /api/admin/email/bulk`
- Test endpoint: `POST /api/mail/test`
- Brevo webhook endpoint (token-protected): `POST /api/mail/webhooks/brevo`

## 1) Recommended option: Brevo SMTP (free tier)

As of March 5, 2026, Brevo Help Center docs describe Free plan limits as `300 email sends/day` with no credit card required.

## 1.1 Create Brevo account and SMTP key

1. Sign up in Brevo and open `Settings -> SMTP & API`.
2. Generate a new SMTP key (store it immediately, it is shown once).
3. Note SMTP host: `smtp-relay.brevo.com`.
4. Use SMTP credentials (username + SMTP key), not API key, for SMTP relay.

## 1.2 Authenticate your sending domain

In Brevo `Senders, Domains & Dedicated IP -> Domains`, add your domain and copy DNS records shown by Brevo.

Important:
- Brevo-generated DKIM/DMARC records are account/domain specific. Prefer Brevo panel values over generic examples.
- You must keep only one SPF record and one DMARC record per domain/subdomain.

DNS templates (replace placeholders):

```txt
# SPF (example when using Brevo + other provider merged)
Type: TXT
Host/Name: @
Value: v=spf1 include:_spf.google.com include:spf.brevo.com mx ~all
TTL: 3600

# DKIM (example pattern - use exact selector/value from Brevo UI)
Type: CNAME (or TXT, depending on Brevo instruction)
Host/Name: <selector>._domainkey
Value: <selector-domain-value-provided-by-brevo>
TTL: 3600

# DMARC (start strict monitoring if your team is ready; otherwise p=none first)
Type: TXT
Host/Name: _dmarc
Value: v=DMARC1; p=quarantine; rua=mailto:dmarc@YOUR_DOMAIN; ruf=mailto:dmarc@YOUR_DOMAIN; fo=1; adkim=s; aspf=s; pct=100
TTL: 3600
```

Check DNS propagation:

```bash
dig +short TXT YOUR_DOMAIN
dig +short TXT _dmarc.YOUR_DOMAIN
dig +short CNAME <selector>._domainkey.YOUR_DOMAIN
```

## 1.3 App configuration (`/etc/sdal/sdal.env`)

```bash
sudo nano /etc/sdal/sdal.env
```

Set/confirm:

```bash
MAIL_PROVIDER=smtp
MAIL_ALLOW_MOCK=false

MAIL_FROM=SDAL <noreply@YOUR_DOMAIN>
MAIL_SMTP_HOST=smtp-relay.brevo.com
MAIL_SMTP_PORT=587
MAIL_SMTP_SECURE=false
MAIL_SMTP_USER=<BREVO_SMTP_LOGIN>
MAIL_SMTP_PASS=<BREVO_SMTP_KEY>
MAIL_SMTP_TLS_REJECT_UNAUTHORIZED=true

MAIL_SEND_TIMEOUT_MS=10000
MAIL_SEND_MAX_RETRIES=2
MAIL_SEND_RETRY_BACKOFF_MS=1200
```

Restart services:

```bash
sudo systemctl restart sdal-api.service sdal-worker.service
sudo systemctl status sdal-api.service --no-pager
sudo systemctl status sdal-worker.service --no-pager
```

## 1.4 Configure webhook (bounce/complaint basics)

Generate shared secret:

```bash
openssl rand -hex 24
```

Put it in `/etc/sdal/sdal.env`:

```bash
MAIL_WEBHOOK_SHARED_SECRET=<RANDOM_HEX>
```

In Brevo transactional webhooks, set webhook URL:

```txt
https://YOUR_DOMAIN/api/mail/webhooks/brevo
```

Add custom request header:

```txt
x-sdal-webhook-token: <RANDOM_HEX>
```

Restart API:

```bash
sudo systemctl restart sdal-api.service
```

Manual webhook test:

```bash
curl -i -X POST "https://YOUR_DOMAIN/api/mail/webhooks/brevo" \
  -H "content-type: application/json" \
  -H "x-sdal-webhook-token: <RANDOM_HEX>" \
  -d '[{"event":"delivered","email":"test@example.com","message-id":"m-1"}]'
```

Expected:
- HTTP 200
- `{"ok":true,"received":1}`

## 1.5 Verification checklist

1. Send test message:

```bash
curl -sS -X POST "https://YOUR_DOMAIN/api/mail/test" \
  -H "content-type: application/json" \
  -d '{"to":"you@yourmailbox.com"}' | jq
```

2. Run critical flow tests from server directory:

```bash
npm run test:phase9-email
```

3. Inspect logs for mail send attempts/retries:

```bash
sudo journalctl -u sdal-api.service -n 200 --no-pager | grep -i "\[mail\]"
sudo journalctl -u sdal-worker.service -n 200 --no-pager | grep -i "\[mail\]"
```

4. Confirm webhook events arriving:

```bash
sudo journalctl -u sdal-api.service -n 200 --no-pager | grep -i "mail_webhook_event"
```

## 2) Fallback option: self-hosted Postfix (warning)

Warning:
- Self-hosted SMTP on a fresh droplet usually has weaker deliverability than specialized providers.
- Major mailbox providers may throttle or reject mail if rDNS, reputation, SPF/DKIM/DMARC, and warm-up are weak.
- Use this as fallback, not first choice.

## 2.1 Install Postfix + OpenDKIM

```bash
sudo apt update
sudo apt install -y postfix opendkim opendkim-tools mailutils swaks
```

During Postfix setup choose:
- `Internet Site`
- system mail name: `mail.YOUR_DOMAIN`

## 2.2 Hostname and TLS certificate

```bash
echo "mail.YOUR_DOMAIN" | sudo tee /etc/hostname
sudo hostnamectl set-hostname mail.YOUR_DOMAIN
```

Issue certificate (if nginx+certbot already used):

```bash
sudo certbot certonly --nginx -d mail.YOUR_DOMAIN
```

## 2.3 Postfix config

```bash
sudo postconf -e "myhostname = mail.YOUR_DOMAIN"
sudo postconf -e "myorigin = /etc/mailname"
sudo postconf -e "inet_interfaces = all"
sudo postconf -e "inet_protocols = ipv4"
sudo postconf -e "smtpd_tls_cert_file = /etc/letsencrypt/live/mail.YOUR_DOMAIN/fullchain.pem"
sudo postconf -e "smtpd_tls_key_file = /etc/letsencrypt/live/mail.YOUR_DOMAIN/privkey.pem"
sudo postconf -e "smtpd_tls_security_level = may"
sudo postconf -e "smtp_tls_security_level = may"
sudo postconf -e "smtpd_tls_loglevel = 1"
sudo postconf -e "mynetworks = 127.0.0.0/8 [::1]/128"
```

## 2.4 OpenDKIM key and binding

```bash
sudo mkdir -p /etc/opendkim/keys/YOUR_DOMAIN
cd /etc/opendkim/keys/YOUR_DOMAIN
sudo opendkim-genkey -s default -d YOUR_DOMAIN
sudo chown -R opendkim:opendkim /etc/opendkim/keys
sudo chmod 600 /etc/opendkim/keys/YOUR_DOMAIN/default.private
```

Configure OpenDKIM:

```bash
sudo tee /etc/opendkim.conf >/dev/null <<'EOF'
Syslog yes
UMask 002
Mode sv
Canonicalization relaxed/relaxed
SubDomains no
AutoRestart yes
Background yes
DNSTimeout 5
SignatureAlgorithm rsa-sha256
Socket inet:8891@localhost
KeyTable /etc/opendkim/key.table
SigningTable refile:/etc/opendkim/signing.table
TrustedHosts /etc/opendkim/trusted.hosts
EOF

sudo tee /etc/opendkim/key.table >/dev/null <<'EOF'
default._domainkey.YOUR_DOMAIN YOUR_DOMAIN:default:/etc/opendkim/keys/YOUR_DOMAIN/default.private
EOF

sudo tee /etc/opendkim/signing.table >/dev/null <<'EOF'
*@YOUR_DOMAIN default._domainkey.YOUR_DOMAIN
EOF

sudo tee /etc/opendkim/trusted.hosts >/dev/null <<'EOF'
127.0.0.1
localhost
YOUR_DOMAIN
mail.YOUR_DOMAIN
EOF
```

Bind Postfix to OpenDKIM milter:

```bash
sudo postconf -e "milter_default_action = accept"
sudo postconf -e "milter_protocol = 6"
sudo postconf -e "smtpd_milters = inet:localhost:8891"
sudo postconf -e "non_smtpd_milters = inet:localhost:8891"
```

Restart:

```bash
sudo systemctl restart opendkim
sudo systemctl restart postfix
sudo systemctl status opendkim --no-pager
sudo systemctl status postfix --no-pager
```

## 2.5 DNS records for self-hosted Postfix

```txt
# A record
mail.YOUR_DOMAIN -> <DROPLET_PUBLIC_IP>

# MX record
YOUR_DOMAIN -> mail.YOUR_DOMAIN (priority 10)

# SPF record
Type: TXT
Host: @
Value: v=spf1 mx a:mail.YOUR_DOMAIN ~all

# DKIM record
# Copy value from:
# /etc/opendkim/keys/YOUR_DOMAIN/default.txt

# DMARC record
Type: TXT
Host: _dmarc
Value: v=DMARC1; p=quarantine; rua=mailto:dmarc@YOUR_DOMAIN; ruf=mailto:dmarc@YOUR_DOMAIN; fo=1; adkim=s; aspf=s; pct=100
```

## 2.6 App env for local Postfix

Set in `/etc/sdal/sdal.env`:

```bash
MAIL_PROVIDER=smtp
MAIL_ALLOW_MOCK=false
MAIL_FROM=SDAL <noreply@YOUR_DOMAIN>
MAIL_SMTP_HOST=127.0.0.1
MAIL_SMTP_PORT=25
MAIL_SMTP_SECURE=false
MAIL_SMTP_USER=
MAIL_SMTP_PASS=
MAIL_SMTP_TLS_REJECT_UNAUTHORIZED=true
MAIL_SEND_TIMEOUT_MS=10000
MAIL_SEND_MAX_RETRIES=2
MAIL_SEND_RETRY_BACKOFF_MS=1200
```

Restart:

```bash
sudo systemctl restart sdal-api.service sdal-worker.service postfix opendkim
```

## 2.7 Test and troubleshoot

SMTP probe:

```bash
swaks --to you@yourmailbox.com --from noreply@YOUR_DOMAIN --server 127.0.0.1 --data "Subject: SDAL Postfix test\n\nPostfix test body"
```

App test:

```bash
curl -sS -X POST "https://YOUR_DOMAIN/api/mail/test" \
  -H "content-type: application/json" \
  -d '{"to":"you@yourmailbox.com"}' | jq
```

Logs:

```bash
sudo journalctl -u postfix -n 200 --no-pager
sudo journalctl -u opendkim -n 200 --no-pager
sudo journalctl -u sdal-worker.service -n 200 --no-pager | grep -i "\[mail\]"
```

## 3) Bounce/complaint handling baseline

For Brevo:
- enable webhook events at least for: `delivered`, `hard_bounce`, `soft_bounce`, `blocked`, `spam`
- keep webhook token enabled (`MAIL_WEBHOOK_SHARED_SECRET`)
- monitor `mail_webhook_event` logs

For self-hosted Postfix:
- there is no provider webhook
- rely on Postfix logs/DSN bounces and mailbox feedback loops if available

## 4) Source references (official docs used)

- Brevo plan limits and pricing: [help.brevo.com article](https://help.brevo.com/hc/en-us/articles/208589409), [Free plan limits](https://help.brevo.com/hc/en-us/articles/208580669-What-are-the-limits-of-the-Free-plans-)
- Brevo SMTP relay setup: [developers.brevo.com SMTP integration](https://developers.brevo.com/docs/smtp-integration)
- Brevo SMTP keys: [help.brevo.com SMTP keys](https://help.brevo.com/hc/en-us/articles/7959631848850-Create-and-manage-your-SMTP-keys)
- Brevo transactional webhook payloads: [developers.brevo.com transactional webhooks](https://developers.brevo.com/docs/transactional-webhooks)
- Brevo SPF merge guidance: [help.brevo.com merge SPF](https://help.brevo.com/hc/en-us/articles/4414335084434-Merging-multiple-SPF-records)
- Brevo domain auth (DKIM/DMARC): [help.brevo.com domain authentication](https://help.brevo.com/hc/en-us/articles/12163873383186-Authenticate-your-domain-with-Brevo-Brevo-code-DKIM-DMARC)
- Ubuntu Postfix install/config: [ubuntu.com server docs](https://ubuntu.com/server/docs/how-to/mail-services/install-postfix/)
- Postfix TLS configuration: [postfix.org TLS_README](https://www.postfix.org/TLS_README.html)
