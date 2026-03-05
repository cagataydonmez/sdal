import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import Database from 'better-sqlite3';

const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'sdal-phase9-email-'));
const bootstrapPath = path.join(tmpDir, 'bootstrap.sqlite');
const runtimeDbPath = path.join(tmpDir, 'runtime.sqlite');

const sourceDb = path.resolve(process.cwd(), '../db/sdal.sqlite');
fs.copyFileSync(sourceDb, bootstrapPath);

const bootstrapDb = new Database(bootstrapPath);
const compatibilityColumns = [
  "ALTER TABLE uyeler ADD COLUMN role TEXT DEFAULT 'user';",
  "ALTER TABLE uyeler ADD COLUMN verified INTEGER DEFAULT 0;",
  "ALTER TABLE uyeler ADD COLUMN verification_status TEXT DEFAULT 'pending';"
];
for (const sql of compatibilityColumns) {
  try {
    bootstrapDb.exec(sql);
  } catch {
    // already exists
  }
}

bootstrapDb.exec(`
  CREATE TABLE IF NOT EXISTS email_kategori (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    ad TEXT NOT NULL,
    tur TEXT NOT NULL,
    deger TEXT,
    aciklama TEXT
  );
  CREATE TABLE IF NOT EXISTS site_controls (
    id INTEGER PRIMARY KEY,
    site_open INTEGER DEFAULT 1,
    maintenance_message TEXT,
    updated_at TEXT
  );
  CREATE TABLE IF NOT EXISTS module_controls (
    module_key TEXT PRIMARY KEY,
    is_open INTEGER DEFAULT 1,
    updated_at TEXT
  );
  CREATE TABLE IF NOT EXISTS media_settings (
    id INTEGER PRIMARY KEY,
    storage_provider TEXT DEFAULT 'local',
    local_base_path TEXT,
    thumb_width INTEGER DEFAULT 200,
    feed_width INTEGER DEFAULT 800,
    full_width INTEGER DEFAULT 1600,
    webp_quality INTEGER DEFAULT 80,
    max_upload_bytes INTEGER DEFAULT 10485760,
    avif_enabled INTEGER DEFAULT 0,
    updated_at TEXT
  );
`);
const nowTs = new Date().toISOString();
bootstrapDb
  .prepare('INSERT OR IGNORE INTO site_controls (id, site_open, maintenance_message, updated_at) VALUES (1, 1, ?, ?)')
  .run('Site geçici bakım modundadır. Lütfen daha sonra tekrar deneyin.', nowTs);
const moduleKeys = [
  'feed', 'main_feed', 'explore', 'following', 'groups', 'messages', 'messenger', 'notifications',
  'albums', 'games', 'events', 'announcements', 'jobs', 'profile', 'help', 'requests'
];
for (const moduleKey of moduleKeys) {
  bootstrapDb
    .prepare('INSERT OR IGNORE INTO module_controls (module_key, is_open, updated_at) VALUES (?, 1, ?)')
    .run(moduleKey, nowTs);
}
bootstrapDb
  .prepare('INSERT OR IGNORE INTO media_settings (id, storage_provider, local_base_path, thumb_width, feed_width, full_width, webp_quality, max_upload_bytes, avif_enabled, updated_at) VALUES (1, ?, ?, 200, 800, 1600, 80, 10485760, 0, ?)')
  .run('local', '/tmp/sdal-test-uploads', nowTs);
bootstrapDb.close();

process.env.SDAL_DB_PATH = runtimeDbPath;
process.env.SDAL_DB_BOOTSTRAP_PATH = bootstrapPath;
process.env.SDAL_SESSION_SECRET = 'phase9-email-secret';
process.env.SDAL_ADMIN_PASSWORD = 'AdminPanel!123';
process.env.ROOT_BOOTSTRAP_PASSWORD = 'RootPass!123';
process.env.MAIL_ALLOW_MOCK = 'true';
process.env.MAIL_PROVIDER = 'mock';
process.env.MAIL_WEBHOOK_SHARED_SECRET = 'phase9-webhook-secret';
process.env.SDAL_LEGACY_ROOT_DIR = tmpDir;
process.env.SDAL_UPLOADS_DIR = path.join(tmpDir, 'uploads');
process.env.REDIS_URL = '';

const { default: app, onServerStarted } = await import('../../app.js');
const { sqlRun, sqlGet } = await import('../../db.js');

await onServerStarted();

function seedUser({
  username,
  password,
  email,
  active = 1,
  admin = 0,
  role = 'user'
}) {
  const now = new Date().toISOString();
  sqlRun(
    `INSERT INTO uyeler (kadi, sifre, email, isim, soyisim, aktivasyon, aktiv, ilktarih, mezuniyetyili, ilkbd, admin, role, verified, verification_status)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 1, ?, ?, 1, 'approved')`,
    [username, password, email, username, 'Mail', `${username}-act`, active, now, '2011', admin, role]
  );
  return sqlGet('SELECT id FROM uyeler WHERE kadi = ?', [username])?.id;
}

seedUser({
  username: 'phase9_pending',
  password: 'phase9-pending-pass',
  email: `phase9.pending.${Date.now()}@example.com`,
  active: 0
});

seedUser({
  username: 'phase9_active',
  password: 'phase9-active-pass',
  email: `phase9.active.${Date.now()}@example.com`,
  active: 1
});

seedUser({
  username: 'phase9_admin',
  password: 'phase9-admin-pass',
  email: `phase9.admin.${Date.now()}@example.com`,
  active: 1,
  admin: 1,
  role: 'admin'
});

const pendingEmail = sqlGet('SELECT email FROM uyeler WHERE kadi = ?', ['phase9_pending'])?.email;
const activeEmail = sqlGet('SELECT email FROM uyeler WHERE kadi = ?', ['phase9_active'])?.email;
const pendingActiveValue = sqlGet('SELECT aktiv FROM uyeler WHERE kadi = ?', ['phase9_pending'])?.aktiv;
assert.ok(pendingEmail, 'pending user email should exist');
assert.ok(activeEmail, 'active user email should exist');
assert.equal(Number(pendingActiveValue || 0), 0, 'pending user should remain inactive');

const server = app.listen(0, '127.0.0.1');
await new Promise((resolve, reject) => {
  server.once('listening', resolve);
  server.once('error', reject);
});

const baseUrl = `http://127.0.0.1:${server.address().port}`;

async function request(pathname, { method = 'GET', cookie = '', body = null, headers = {} } = {}) {
  const resp = await fetch(`${baseUrl}${pathname}`, {
    method,
    headers: {
      ...(cookie ? { cookie } : {}),
      ...headers
    },
    body
  });

  const text = await resp.text();
  let data = null;
  if (text) {
    try {
      data = JSON.parse(text);
    } catch {
      data = text;
    }
  }

  return { resp, data };
}

async function login(username, password) {
  const result = await request('/api/auth/login', {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ kadi: username, sifre: password })
  });

  const setCookieValues = typeof result.resp.headers.getSetCookie === 'function'
    ? result.resp.headers.getSetCookie()
    : (result.resp.headers.get('set-cookie') ? [result.resp.headers.get('set-cookie')] : []);

  const cookie = setCookieValues
    .map((entry) => String(entry || '').split(';')[0])
    .filter(Boolean)
    .join('; ');

  return { ...result, cookie };
}

try {
  const activationResend = await request('/api/activation/resend', {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ email: pendingEmail })
  });
  assert.equal(
    activationResend.resp.status,
    200,
    `activation resend should succeed (status=${activationResend.resp.status}, data=${JSON.stringify(activationResend.data)})`
  );
  assert.equal(activationResend.data?.ok, true, 'activation resend payload should be ok');

  const passwordReset = await request('/api/password-reset', {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ email: activeEmail })
  });
  assert.equal(passwordReset.resp.status, 200, 'password reset should succeed');
  assert.equal(passwordReset.data?.ok, true, 'password reset payload should be ok');

  const adminLogin = await login('phase9_admin', 'phase9-admin-pass');
  assert.equal(adminLogin.resp.status, 200, 'admin login should succeed');
  assert.ok(adminLogin.cookie, 'admin login should set cookie');

  const categoryName = `phase9-cat-${Date.now()}`;
  const categoryCreate = await request('/api/admin/email/categories', {
    method: 'POST',
    cookie: adminLogin.cookie,
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({
      ad: categoryName,
      tur: 'custom',
      deger: 'bulk1@example.com,bulk2@example.com',
      aciklama: 'phase9 test category'
    })
  });
  assert.equal(categoryCreate.resp.status, 200, 'admin category create should succeed');
  assert.equal(categoryCreate.data?.ok, true, 'admin category create payload should be ok');

  const categoryList = await request('/api/admin/email/categories', {
    method: 'GET',
    cookie: adminLogin.cookie
  });
  assert.equal(categoryList.resp.status, 200, 'admin category list should succeed');
  const category = (categoryList.data?.categories || []).find((item) => String(item?.ad || '') === categoryName);
  assert.ok(category?.id, 'new category should be returned in list');

  const bulkSend = await request('/api/admin/email/bulk', {
    method: 'POST',
    cookie: adminLogin.cookie,
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({
      categoryId: category.id,
      subject: 'Phase9 Bulk Test',
      html: '<p>Phase9 bulk send test</p>',
      from: 'SDAL <noreply@example.com>'
    })
  });
  assert.equal(bulkSend.resp.status, 200, 'admin bulk send should succeed');
  assert.equal(bulkSend.data?.ok, true, 'admin bulk send payload should be ok');
  assert.equal(Number(bulkSend.data?.count || 0), 2, 'admin bulk send should include expected recipient count');

  const webhookUnauthorized = await request('/api/mail/webhooks/brevo', {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify([{ event: 'hard_bounce', email: 'nobody@example.com' }])
  });
  assert.equal(webhookUnauthorized.resp.status, 401, 'brevo webhook should reject missing token');

  const webhookAuthorized = await request('/api/mail/webhooks/brevo', {
    method: 'POST',
    headers: {
      'content-type': 'application/json',
      'x-sdal-webhook-token': 'phase9-webhook-secret'
    },
    body: JSON.stringify([{ event: 'delivered', email: 'ok@example.com', 'message-id': 'mid-1' }])
  });
  assert.equal(webhookAuthorized.resp.status, 200, 'brevo webhook should accept shared-secret auth');
  assert.equal(webhookAuthorized.data?.ok, true, 'brevo webhook payload should be ok');
  assert.equal(Number(webhookAuthorized.data?.received || 0), 1, 'brevo webhook should report received event count');

  console.log('phase9 email tests passed');
} finally {
  server.close();
}

process.exit(0);
