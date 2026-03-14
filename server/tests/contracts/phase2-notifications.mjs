import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import Database from 'better-sqlite3';

const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'sdal-phase2-notifications-'));
const bootstrapPath = path.join(tmpDir, 'bootstrap.sqlite');
const runtimeDbPath = path.join(tmpDir, 'runtime.sqlite');
const sourceDb = path.resolve(process.cwd(), '../db/sdal.sqlite');
fs.copyFileSync(sourceDb, bootstrapPath);

const bootstrapDb = new Database(bootstrapPath);
bootstrapDb.exec(`
  CREATE TABLE IF NOT EXISTS notifications (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER,
    type TEXT,
    source_user_id INTEGER,
    entity_id INTEGER,
    message TEXT,
    read_at TEXT,
    created_at TEXT
  );
  CREATE TABLE IF NOT EXISTS connection_requests (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    sender_id INTEGER NOT NULL,
    receiver_id INTEGER NOT NULL,
    status TEXT NOT NULL DEFAULT 'pending',
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    responded_at TEXT
  );
  CREATE TABLE IF NOT EXISTS jobs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    poster_id INTEGER NOT NULL,
    company TEXT NOT NULL,
    title TEXT NOT NULL,
    description TEXT NOT NULL,
    location TEXT,
    job_type TEXT,
    link TEXT,
    created_at TEXT
  );
  CREATE TABLE IF NOT EXISTS job_applications (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    job_id INTEGER NOT NULL,
    applicant_id INTEGER NOT NULL,
    cover_letter TEXT,
    created_at TEXT,
    UNIQUE(job_id, applicant_id)
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
process.env.SDAL_SESSION_SECRET = 'phase2-notifications-secret';
process.env.SDAL_ADMIN_PASSWORD = 'AdminPanel!123';
process.env.ROOT_BOOTSTRAP_PASSWORD = 'RootPass!123';
process.env.MAIL_ALLOW_MOCK = 'true';
process.env.SDAL_LEGACY_ROOT_DIR = tmpDir;
process.env.REDIS_URL = '';

const { default: app, onServerStarted } = await import('../../app.js');
const { sqlRun, sqlGet } = await import('../../db.js');
await onServerStarted();

function seedUser(username, password, role = 'user') {
  const now = new Date().toISOString();
  sqlRun(
    `INSERT INTO uyeler (kadi, sifre, email, isim, soyisim, aktivasyon, aktiv, ilktarih, mezuniyetyili, ilkbd, admin, role, verified, verification_status)
     VALUES (?, ?, ?, ?, ?, ?, 1, ?, ?, 1, 0, ?, 1, 'approved')`,
    [username, password, `${username}@example.com`, username, 'Notify', `${username}-act`, now, '2012', role]
  );
  return Number(sqlGet('SELECT id FROM uyeler WHERE kadi = ?', [username]).id);
}

const senderId = seedUser('phase2_notify_sender', 'phase2-pass-a');
const receiverId = seedUser('phase2_notify_receiver', 'phase2-pass-b');
const posterId = seedUser('phase2_notify_poster', 'phase2-pass-c');
const applicantId = seedUser('phase2_notify_applicant', 'phase2-pass-d');

sqlRun(
  `INSERT INTO jobs (poster_id, company, title, description, location, job_type, link, created_at)
   VALUES (?, 'SDAL Labs', 'Notifications Engineer', 'Own the inbox', 'Istanbul', 'full_time', 'https://example.com/job', ?)`,
  [posterId, new Date().toISOString()]
);
const jobId = Number(sqlGet('SELECT id FROM jobs WHERE poster_id = ? ORDER BY id DESC LIMIT 1', [posterId]).id);

const server = app.listen(0);
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
  const senderCookie = await login('phase2_notify_sender', 'phase2-pass-a');
  const receiverCookie = await login('phase2_notify_receiver', 'phase2-pass-b');
  const posterCookie = await login('phase2_notify_poster', 'phase2-pass-c');
  const applicantCookie = await login('phase2_notify_applicant', 'phase2-pass-d');

  const connectionRequest = await request(`/api/new/connections/request/${receiverId}`, {
    method: 'POST',
    cookie: senderCookie,
    body: { source_surface: 'member_detail_page' }
  });
  assert.equal(connectionRequest.res.status, 200);
  const requestId = Number(connectionRequest.data?.data?.request_id || connectionRequest.data?.request_id || 0);
  assert.ok(requestId > 0);

  const receiverNotifications = await request('/api/new/notifications?limit=10&offset=0', { cookie: receiverCookie });
  assert.equal(receiverNotifications.res.status, 200);
  assert.equal(receiverNotifications.data?.ok, true);
  const connectionNotification = (receiverNotifications.data?.data?.items || []).find((item) => item.type === 'connection_request');
  assert.ok(connectionNotification);
  assert.equal(connectionNotification.category, 'networking');
  assert.equal(connectionNotification.priority, 'actionable');
  assert.equal(connectionNotification.is_actionable, true);
  assert.equal(Array.isArray(connectionNotification.actions), true);
  assert.equal(connectionNotification.actions.some((action) => action.kind === 'accept_connection_request'), true);
  assert.equal(connectionNotification.actions.some((action) => action.kind === 'ignore_connection_request'), true);
  assert.match(String(connectionNotification.target?.href || ''), /\/new\/network\/hub\?section=incoming-connections/);
  assert.match(String(connectionNotification.target?.href || ''), new RegExp(`request=${requestId}`));

  const unreadBeforeOpen = await request('/api/new/notifications/unread', { cookie: receiverCookie });
  assert.equal(Number(unreadBeforeOpen.data?.count || 0) >= 1, true);

  const openNotification = await request(`/api/new/notifications/${connectionNotification.id}/open`, {
    method: 'POST',
    cookie: receiverCookie
  });
  assert.equal(openNotification.res.status, 200);
  assert.ok(openNotification.data?.data?.item?.read_at);

  const unreadAfterOpen = await request('/api/new/notifications/unread', { cookie: receiverCookie });
  assert.equal(Number(unreadAfterOpen.data?.count || 0), 0);

  const apply = await request(`/api/new/jobs/${jobId}/apply`, {
    method: 'POST',
    cookie: applicantCookie,
    body: { cover_letter: 'Bildirim akışını iyileştirmek istiyorum.' }
  });
  assert.equal(apply.res.status, 200);

  const posterNotifications = await request('/api/new/notifications?limit=10&offset=0', { cookie: posterCookie });
  assert.equal(posterNotifications.res.status, 200);
  const jobNotification = (posterNotifications.data?.data?.items || []).find((item) => item.type === 'job_application');
  assert.ok(jobNotification);
  assert.equal(jobNotification.category, 'jobs');
  assert.equal(jobNotification.priority, 'actionable');
  assert.equal(jobNotification.actions.some((action) => action.kind === 'open'), true);
  assert.match(String(jobNotification.target?.href || ''), new RegExp(`/new/jobs\\?job=${jobId}&tab=applications`));

  sqlRun(
    `INSERT INTO notifications (user_id, type, source_user_id, entity_id, message, created_at)
     VALUES (?, 'comment', ?, 77, 'Gönderine yorum yaptı.', ?)`,
    [posterId, applicantId, new Date().toISOString()]
  );
  const extraNotificationId = Number(sqlGet(`SELECT id FROM notifications WHERE user_id = ? AND type = 'comment' ORDER BY id DESC LIMIT 1`, [posterId]).id);
  const bulkRead = await request('/api/new/notifications/bulk-read', {
    method: 'POST',
    cookie: posterCookie,
    body: { ids: [extraNotificationId] }
  });
  assert.equal(bulkRead.res.status, 200);
  assert.equal(Number(bulkRead.data?.data?.updated || 0), 1);

  const readSingle = await request(`/api/new/notifications/${extraNotificationId}/read`, {
    method: 'POST',
    cookie: posterCookie
  });
  assert.equal(readSingle.res.status, 200);
  assert.ok(readSingle.data?.data?.item?.read_at);

  console.log('phase2 notifications tests passed');
} finally {
  await new Promise((resolve) => server.close(resolve));
}
