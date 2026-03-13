import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import Database from 'better-sqlite3';

const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'sdal-phase2-network-hub-'));
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
    requester_id INTEGER,
    mentor_id INTEGER,
    status TEXT DEFAULT 'requested',
    focus_area TEXT,
    message TEXT,
    created_at TEXT,
    updated_at TEXT,
    responded_at TEXT
  );
  CREATE TABLE IF NOT EXISTS teacher_alumni_links (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    teacher_user_id INTEGER,
    alumni_user_id INTEGER,
    relationship_type TEXT,
    class_year TEXT,
    notes TEXT,
    confidence_score REAL NOT NULL DEFAULT 1.0,
    created_by INTEGER,
    created_at TEXT,
    UNIQUE(teacher_user_id, alumni_user_id, relationship_type, class_year)
  );
  CREATE TABLE IF NOT EXISTS notifications (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER,
    type TEXT,
    source_user_id INTEGER,
    entity_id INTEGER,
    message TEXT,
    is_read INTEGER DEFAULT 0,
    read_at TEXT,
    created_at TEXT
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
bootstrapDb.close();

process.env.SDAL_DB_PATH = runtimeDbPath;
process.env.SDAL_DB_BOOTSTRAP_PATH = bootstrapPath;
process.env.SDAL_SESSION_SECRET = 'phase2-network-hub-secret';
process.env.SDAL_ADMIN_PASSWORD = 'AdminPanel!123';
process.env.ROOT_BOOTSTRAP_PASSWORD = 'RootPass!123';
process.env.MAIL_ALLOW_MOCK = 'true';
process.env.SDAL_LEGACY_ROOT_DIR = tmpDir;
process.env.REDIS_URL = '';
process.env.JOB_INLINE_WORKER = 'true';

const { default: app, onServerStarted } = await import('../../app.js');
const { sqlRun, sqlGet } = await import('../../db.js');
await onServerStarted();

function seedUser(username, password, role = 'user', year = '2011', mentorOptIn = 0) {
  const now = new Date().toISOString();
  sqlRun(
    `INSERT INTO uyeler (kadi, sifre, email, isim, soyisim, aktivasyon, aktiv, ilktarih, mezuniyetyili, ilkbd, admin, role, verified, verification_status, mentor_opt_in)
     VALUES (?, ?, ?, ?, ?, ?, 1, ?, ?, 1, 0, ?, 1, 'approved', ?)`,
    [username, password, `${username}@example.com`, username, 'Hub', `${username}-act`, now, year, role, mentorOptIn]
  );
  return Number(sqlGet('SELECT id FROM uyeler WHERE kadi = ?', [username]).id);
}

const meId = seedUser('phase2_hub_me', 'phase2-pass-me', 'teacher', 'teacher', 1);
const senderId = seedUser('phase2_hub_sender', 'phase2-pass-sender', 'user', '2011');
const receiverId = seedUser('phase2_hub_receiver', 'phase2-pass-receiver', 'user', '2012');
const menteeId = seedUser('phase2_hub_mentee', 'phase2-pass-mentee', 'user', '2011');
const mentorId = seedUser('phase2_hub_mentor', 'phase2-pass-mentor', 'teacher', 'teacher', 1);
const candidateId = seedUser('phase2_hub_candidate', 'phase2-pass-candidate', 'user', '2011', 1);
const teacherSourceId = seedUser('phase2_hub_teacher_source', 'phase2-pass-teacher-source', 'user', '2011');

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
  const cookieMe = await login('phase2_hub_me', 'phase2-pass-me');
  const now = new Date().toISOString();

  sqlRun('UPDATE uyeler SET ilktarih = ? WHERE id = ?', ['2026-01-01T00:00:00.000Z', meId]);

  sqlRun('INSERT INTO connection_requests (sender_id, receiver_id, status, created_at, updated_at) VALUES (?, ?, ?, ?, ?)', [senderId, meId, 'pending', now, now]);
  sqlRun('INSERT INTO connection_requests (sender_id, receiver_id, status, created_at, updated_at) VALUES (?, ?, ?, ?, ?)', [meId, receiverId, 'pending', now, now]);
  sqlRun('INSERT INTO connection_requests (sender_id, receiver_id, status, created_at, updated_at, responded_at) VALUES (?, ?, ?, ?, ?, ?)', [meId, candidateId, 'accepted', now, now, now]);

  sqlRun(
    `INSERT INTO mentorship_requests (requester_id, mentor_id, status, focus_area, message, created_at, updated_at)
     VALUES (?, ?, 'requested', 'career', 'yardim', ?, ?)`,
    [menteeId, meId, now, now]
  );
  sqlRun(
    `INSERT INTO mentorship_requests (requester_id, mentor_id, status, focus_area, message, created_at, updated_at, responded_at)
     VALUES (?, ?, 'accepted', 'career', 'tesekkurler', ?, ?, ?)`,
    [meId, mentorId, now, now, now]
  );

  sqlRun(
    `INSERT INTO teacher_alumni_links (teacher_user_id, alumni_user_id, relationship_type, class_year, notes, created_by, created_at)
     VALUES (?, ?, 'mentor', '2011', 'graph', ?, ?)`,
    [meId, candidateId, meId, now]
  );

  sqlRun(
    `INSERT INTO notifications (user_id, type, source_user_id, entity_id, message, created_at)
     VALUES (?, 'teacher_network_linked', ?, ?, 'Seni öğretmen ağına ekledi.', ?)`,
    [meId, teacherSourceId, meId, now]
  );

  const hub = await request('/api/new/network/hub?window=30d&limit=10&suggestion_limit=6', { cookie: cookieMe });
  assert.equal(hub.res.status, 200);
  assert.equal(hub.data?.ok, true);
  assert.equal(hub.data?.code, 'NETWORK_HUB_BOOTSTRAP_OK');
  assert.equal(typeof hub.data?.message, 'string');

  const payload = hub.data?.data?.hub;
  assert.equal(payload?.window, '30d');
  assert.equal(Array.isArray(payload?.inbox?.connections?.incoming), true);
  assert.equal(Array.isArray(payload?.inbox?.connections?.outgoing), true);
  assert.equal(Array.isArray(payload?.inbox?.mentorship?.incoming), true);
  assert.equal(Array.isArray(payload?.discovery?.suggestions), true);
  assert.equal(typeof payload?.discovery?.experiment_variant, 'string');
  assert.equal(typeof payload?.discovery?.connection_maps?.incoming, 'object');
  assert.equal(typeof payload?.discovery?.connection_maps?.outgoing, 'object');
  assert.equal(payload?.metrics?.connections?.pending_incoming, 1);
  assert.equal(payload?.metrics?.connections?.pending_outgoing, 1);
  assert.equal(payload?.metrics?.mentorship?.accepted, 1);
  assert.equal(payload?.inbox?.teacherLinks?.unread_count, 1);
  assert.equal(payload?.counts?.actionable, 3);
  assert.equal(Number(payload?.discovery?.connection_maps?.incoming?.[senderId] || 0) >= 1, true);
  assert.equal(Number(payload?.discovery?.connection_maps?.outgoing?.[receiverId] || 0) >= 1, true);
  const suggestionAssignment = sqlGet('SELECT variant FROM network_suggestion_ab_assignments WHERE user_id = ?', [meId]);
  assert.equal(typeof suggestionAssignment?.variant, 'string');

  console.log('phase2 network hub tests passed');
} finally {
  await new Promise((resolve) => server.close(resolve));
}
