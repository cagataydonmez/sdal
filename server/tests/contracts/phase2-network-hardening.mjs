import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import Database from 'better-sqlite3';

const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'sdal-phase2-network-hardening-'));
const bootstrapPath = path.join(tmpDir, 'bootstrap.sqlite');
const runtimeDbPath = path.join(tmpDir, 'runtime.sqlite');
const sourceDb = path.resolve(process.cwd(), '../db/sdal.sqlite');
fs.copyFileSync(sourceDb, bootstrapPath);

const bootstrapDb = new Database(bootstrapPath);
bootstrapDb.exec(`
  CREATE TABLE IF NOT EXISTS follows (
    id INTEGER PRIMARY KEY,
    follower_id INTEGER,
    following_id INTEGER,
    created_at TEXT
  );
  CREATE TABLE IF NOT EXISTS connection_requests (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    sender_id INTEGER,
    receiver_id INTEGER,
    status TEXT,
    created_at TEXT,
    updated_at TEXT,
    responded_at TEXT,
    UNIQUE(sender_id, receiver_id)
  );
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
process.env.SDAL_SESSION_SECRET = 'phase2-network-hardening-secret';
process.env.SDAL_ADMIN_PASSWORD = 'AdminPanel!123';
process.env.ROOT_BOOTSTRAP_PASSWORD = 'RootPass!123';
process.env.MAIL_ALLOW_MOCK = 'true';
process.env.SDAL_LEGACY_ROOT_DIR = tmpDir;
process.env.REDIS_URL = '';
process.env.JOB_INLINE_WORKER = 'true';

process.env.RATE_LIMIT_CONNECTION_REQUEST_MAX = '2';
process.env.RATE_LIMIT_CONNECTION_REQUEST_WINDOW_SECONDS = '3600';
process.env.RATE_LIMIT_MENTORSHIP_REQUEST_MAX = '2';
process.env.RATE_LIMIT_MENTORSHIP_REQUEST_WINDOW_SECONDS = '3600';
process.env.CONNECTION_REQUEST_COOLDOWN_SECONDS = '600';
process.env.MENTORSHIP_REQUEST_COOLDOWN_SECONDS = '600';

const { default: app, onServerStarted } = await import('../../app.js');
const { sqlRun, sqlGet } = await import('../../db.js');
await onServerStarted();

function seedUser(username, password, mentorOptIn = 0) {
  const now = new Date().toISOString();
  sqlRun(
    `INSERT INTO uyeler (kadi, sifre, email, isim, soyisim, aktivasyon, aktiv, ilktarih, mezuniyetyili, ilkbd, admin, role, verified, verification_status, mentor_opt_in)
     VALUES (?, ?, ?, ?, ?, ?, 1, ?, ?, 1, 0, 'user', 1, 'approved', ?)`,
    [username, password, `${username}@example.com`, username, 'Hardening', `${username}-act`, now, '2012', mentorOptIn]
  );
  return Number(sqlGet('SELECT id FROM uyeler WHERE kadi = ?', [username]).id);
}

const connSenderCooldownId = seedUser('phase2_conn_cd_sender', 'phase2-pass-cd-sender');
const connReceiverCooldownId = seedUser('phase2_conn_cd_receiver', 'phase2-pass-cd-receiver');
const connSenderRateId = seedUser('phase2_conn_rl_sender', 'phase2-pass-rl-sender');
const connReceiverRateAId = seedUser('phase2_conn_rl_receiver_a', 'phase2-pass-rl-ra');
const connReceiverRateBId = seedUser('phase2_conn_rl_receiver_b', 'phase2-pass-rl-rb');
const connReceiverRateCId = seedUser('phase2_conn_rl_receiver_c', 'phase2-pass-rl-rc');

const menteeCooldownId = seedUser('phase2_ment_cd_mentee', 'phase2-pass-ment-cd-mentee');
const mentorCooldownId = seedUser('phase2_ment_cd_mentor', 'phase2-pass-ment-cd-mentor', 1);
const menteeRateId = seedUser('phase2_ment_rl_mentee', 'phase2-pass-ment-rl-mentee');
const mentorRateAId = seedUser('phase2_ment_rl_mentor_a', 'phase2-pass-ment-rl-ma', 1);
const mentorRateBId = seedUser('phase2_ment_rl_mentor_b', 'phase2-pass-ment-rl-mb', 1);
const mentorRateCId = seedUser('phase2_ment_rl_mentor_c', 'phase2-pass-ment-rl-mc', 1);

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
  const connSenderCooldownCookie = await login('phase2_conn_cd_sender', 'phase2-pass-cd-sender');
  const connReceiverCooldownCookie = await login('phase2_conn_cd_receiver', 'phase2-pass-cd-receiver');
  const connSenderRateCookie = await login('phase2_conn_rl_sender', 'phase2-pass-rl-sender');
  const menteeCooldownCookie = await login('phase2_ment_cd_mentee', 'phase2-pass-ment-cd-mentee');
  const mentorCooldownCookie = await login('phase2_ment_cd_mentor', 'phase2-pass-ment-cd-mentor');
  const menteeRateCookie = await login('phase2_ment_rl_mentee', 'phase2-pass-ment-rl-mentee');

  const connectionSend = await request(`/api/new/connections/request/${connReceiverCooldownId}`, {
    method: 'POST',
    cookie: connSenderCooldownCookie
  });
  assert.equal(connectionSend.res.status, 200);

  const incomingConnections = await request('/api/new/connections/requests?direction=incoming&status=pending', { cookie: connReceiverCooldownCookie });
  assert.equal(incomingConnections.res.status, 200);
  assert.equal(incomingConnections.data.items.length, 1);

  const ignoreConnection = await request(`/api/new/connections/ignore/${incomingConnections.data.items[0].id}`, {
    method: 'POST',
    cookie: connReceiverCooldownCookie
  });
  assert.equal(ignoreConnection.res.status, 200);
  assert.equal(ignoreConnection.data?.status, 'ignored');

  const cooldownConnection = await request(`/api/new/connections/request/${connReceiverCooldownId}`, {
    method: 'POST',
    cookie: connSenderCooldownCookie
  });
  assert.equal(cooldownConnection.res.status, 429);
  assert.equal(cooldownConnection.data?.code, 'REQUEST_COOLDOWN_ACTIVE');
  assert.ok(Number(cooldownConnection.data?.retry_after_seconds || 0) > 0);

  const connectionRate1 = await request(`/api/new/connections/request/${connReceiverRateAId}`, {
    method: 'POST',
    cookie: connSenderRateCookie
  });
  const connectionRate2 = await request(`/api/new/connections/request/${connReceiverRateBId}`, {
    method: 'POST',
    cookie: connSenderRateCookie
  });
  const connectionRate3 = await request(`/api/new/connections/request/${connReceiverRateCId}`, {
    method: 'POST',
    cookie: connSenderRateCookie
  });
  assert.equal(connectionRate1.res.status, 200);
  assert.equal(connectionRate2.res.status, 200);
  assert.equal(connectionRate3.res.status, 429);
  assert.equal(connectionRate3.data?.code, 'CONNECTION_REQUEST_RATE_LIMITED');

  const mentorshipSend = await request(`/api/new/mentorship/request/${mentorCooldownId}`, {
    method: 'POST',
    cookie: menteeCooldownCookie,
    body: { focus_area: 'Backend', message: 'İlk istek' }
  });
  assert.equal(mentorshipSend.res.status, 200);

  const incomingMentorship = await request('/api/new/mentorship/requests?direction=incoming&status=requested', { cookie: mentorCooldownCookie });
  assert.equal(incomingMentorship.res.status, 200);
  assert.equal(incomingMentorship.data.items.length, 1);

  const declineMentorship = await request(`/api/new/mentorship/decline/${incomingMentorship.data.items[0].id}`, {
    method: 'POST',
    cookie: mentorCooldownCookie
  });
  assert.equal(declineMentorship.res.status, 200);
  assert.equal(declineMentorship.data?.status, 'declined');

  const mentorshipCooldown = await request(`/api/new/mentorship/request/${mentorCooldownId}`, {
    method: 'POST',
    cookie: menteeCooldownCookie,
    body: { focus_area: 'Backend', message: 'Tekrar deneme' }
  });
  assert.equal(mentorshipCooldown.res.status, 429);
  assert.equal(mentorshipCooldown.data?.code, 'MENTORSHIP_COOLDOWN_ACTIVE');
  assert.ok(Number(mentorshipCooldown.data?.retry_after_seconds || 0) > 0);

  const mentorshipRate1 = await request(`/api/new/mentorship/request/${mentorRateAId}`, {
    method: 'POST',
    cookie: menteeRateCookie,
    body: { focus_area: 'Kariyer', message: 'Mentorluk 1' }
  });
  const mentorshipRate2 = await request(`/api/new/mentorship/request/${mentorRateBId}`, {
    method: 'POST',
    cookie: menteeRateCookie,
    body: { focus_area: 'Kariyer', message: 'Mentorluk 2' }
  });
  const mentorshipRate3 = await request(`/api/new/mentorship/request/${mentorRateCId}`, {
    method: 'POST',
    cookie: menteeRateCookie,
    body: { focus_area: 'Kariyer', message: 'Mentorluk 3' }
  });
  assert.equal(mentorshipRate1.res.status, 200);
  assert.equal(mentorshipRate2.res.status, 200);
  assert.equal(mentorshipRate3.res.status, 429);
  assert.equal(mentorshipRate3.data?.code, 'MENTORSHIP_REQUEST_RATE_LIMITED');

  console.log('phase2 network hardening tests passed');
} finally {
  await new Promise((resolve) => server.close(resolve));
}
