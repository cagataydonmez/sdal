import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import Database from 'better-sqlite3';

const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'sdal-phase2-mentorship-'));
const bootstrapPath = path.join(tmpDir, 'bootstrap.sqlite');
const runtimeDbPath = path.join(tmpDir, 'runtime.sqlite');
const sourceDb = path.resolve(process.cwd(), '../db/sdal.sqlite');
fs.copyFileSync(sourceDb, bootstrapPath);

const bootstrapDb = new Database(bootstrapPath);
bootstrapDb.exec(`
  CREATE TABLE IF NOT EXISTS mentorship_requests (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    requester_id INTEGER NOT NULL,
    mentor_id INTEGER NOT NULL,
    status TEXT DEFAULT 'requested',
    focus_area TEXT,
    message TEXT,
    created_at TEXT,
    updated_at TEXT,
    responded_at TEXT,
    UNIQUE(requester_id, mentor_id)
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
for (const moduleKey of ['feed', 'main_feed', 'year_feed', 'explore', 'following', 'groups', 'messages', 'messenger', 'notifications', 'albums', 'games', 'events', 'announcements', 'jobs', 'profile', 'help', 'requests']) {
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
process.env.SDAL_SESSION_SECRET = 'phase2-mentorship-secret';
process.env.SDAL_ADMIN_PASSWORD = 'AdminPanel!123';
process.env.ROOT_BOOTSTRAP_PASSWORD = 'RootPass!123';
process.env.MAIL_ALLOW_MOCK = 'true';
process.env.SDAL_LEGACY_ROOT_DIR = tmpDir;
process.env.REDIS_URL = '';
process.env.JOB_INLINE_WORKER = 'true';

const { default: app, onServerStarted } = await import('../../app.js');
const { sqlRun, sqlGet } = await import('../../db.js');
await onServerStarted();

function seedUser(username, password, mentorOptIn = 0) {
  const now = new Date().toISOString();
  sqlRun(
    `INSERT INTO uyeler (kadi, sifre, email, isim, soyisim, aktivasyon, aktiv, ilktarih, mezuniyetyili, ilkbd, admin, role, verified, verification_status, mentor_opt_in)
     VALUES (?, ?, ?, ?, ?, ?, 1, ?, ?, 1, 0, 'user', 1, 'approved', ?)`,
    [username, password, `${username}@example.com`, username, 'Mentor', `${username}-act`, now, '2012', mentorOptIn]
  );
  return Number(sqlGet('SELECT id FROM uyeler WHERE kadi = ?', [username]).id);
}

const requesterId = seedUser('phase2_mentee', 'phase2-pass-mentee', 0);
const mentorId = seedUser('phase2_mentor', 'phase2-pass-mentor', 1);

const server = app.listen(0, '127.0.0.1');
await new Promise((resolve, reject) => {
  server.once('listening', resolve);
  server.once('error', reject);
});
const baseUrl = `http://127.0.0.1:${server.address().port}`;

async function request(pathname, { method = 'GET', cookie = '', body = null } = {}) {
  const res = await fetch(`${baseUrl}${pathname}`, {
    method,
    headers: {
      ...(cookie ? { cookie } : {}),
      ...(body ? { 'content-type': 'application/json' } : {})
    },
    body: body ? JSON.stringify(body) : undefined
  });
  const text = await res.text();
  let data = null;
  if (text) {
    try { data = JSON.parse(text); } catch { data = text; }
  }
  return { res, data };
}

async function login(kadi, sifre) {
  const out = await request('/api/auth/login', { method: 'POST', body: { kadi, sifre } });
  assert.equal(out.res.status, 200);
  const rawCookies = typeof out.res.headers.getSetCookie === 'function' ? out.res.headers.getSetCookie() : [out.res.headers.get('set-cookie')].filter(Boolean);
  return rawCookies.map((row) => String(row || '').split(';')[0]).join('; ');
}

try {
  const menteeCookie = await login('phase2_mentee', 'phase2-pass-mentee');
  const mentorCookie = await login('phase2_mentor', 'phase2-pass-mentor');

  const send = await request(`/api/new/mentorship/request/${mentorId}`, {
    method: 'POST',
    cookie: menteeCookie,
    body: { focus_area: 'Backend', message: 'Kariyer yönlendirmesi isterim.' }
  });
  assert.equal(send.res.status, 200);
  assert.equal(send.data?.ok, true);
  assert.equal(send.data?.code, 'MENTORSHIP_REQUEST_CREATED');
  assert.equal(send.data?.data?.status, 'requested');
  assert.equal(send.data?.status, 'requested');

  const incoming = await request('/api/new/mentorship/requests?direction=incoming&status=requested', { cookie: mentorCookie });
  assert.equal(incoming.res.status, 200);
  assert.equal(incoming.data?.ok, true);
  assert.equal(incoming.data?.code, 'MENTORSHIP_REQUESTS_LIST_OK');
  assert.equal(Array.isArray(incoming.data?.data?.items), true);
  assert.equal(Array.isArray(incoming.data?.items), true);
  assert.equal(incoming.data.items.length, 1);

  const requestId = Number(incoming.data.items[0].id);
  const accept = await request(`/api/new/mentorship/accept/${requestId}`, { method: 'POST', cookie: mentorCookie });
  assert.equal(accept.res.status, 200);
  assert.equal(accept.data?.ok, true);
  assert.equal(accept.data?.code, 'MENTORSHIP_REQUEST_ACCEPTED');
  assert.equal(accept.data?.data?.status, 'accepted');
  assert.equal(accept.data?.status, 'accepted');

  const accepted = await request('/api/new/mentorship/requests?direction=outgoing&status=accepted', { cookie: menteeCookie });
  assert.equal(accepted.res.status, 200);
  assert.equal(accepted.data?.ok, true);
  assert.equal(accepted.data.items.length, 1);

  const duplicate = await request(`/api/new/mentorship/request/${mentorId}`, { method: 'POST', cookie: menteeCookie });
  assert.equal(duplicate.res.status, 409);
  assert.equal(duplicate.data?.ok, false);
  assert.equal(duplicate.data?.code, 'REQUEST_ALREADY_ACCEPTED');

  console.log('phase2 mentorship tests passed');
} finally {
  await new Promise((resolve) => server.close(resolve));
}
