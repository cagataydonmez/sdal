import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import Database from 'better-sqlite3';

const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'sdal-phase2-connections-'));
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
  CREATE TABLE IF NOT EXISTS groups (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT,
    description TEXT,
    cover_image TEXT,
    owner_id INTEGER,
    created_at TEXT,
    visibility TEXT DEFAULT 'public',
    show_contact_hint INTEGER DEFAULT 0
  );
  CREATE TABLE IF NOT EXISTS group_members (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    group_id INTEGER,
    user_id INTEGER,
    role TEXT,
    created_at TEXT
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
  CREATE TABLE IF NOT EXISTS member_engagement_scores (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER UNIQUE,
    score REAL DEFAULT 0,
    updated_at TEXT
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
process.env.SDAL_SESSION_SECRET = 'phase2-connections-secret';
process.env.SDAL_ADMIN_PASSWORD = 'AdminPanel!123';
process.env.ROOT_BOOTSTRAP_PASSWORD = 'RootPass!123';
process.env.MAIL_ALLOW_MOCK = 'true';
process.env.SDAL_LEGACY_ROOT_DIR = tmpDir;
process.env.REDIS_URL = '';
process.env.JOB_INLINE_WORKER = 'true';

const { default: app, onServerStarted } = await import('../../app.js');
const { sqlRun, sqlGet } = await import('../../db.js');
await onServerStarted();

function seedUser(username, password) {
  const now = new Date().toISOString();
  sqlRun(
    `INSERT INTO uyeler (kadi, sifre, email, isim, soyisim, aktivasyon, aktiv, ilktarih, mezuniyetyili, ilkbd, admin, role, verified, verification_status)
     VALUES (?, ?, ?, ?, ?, ?, 1, ?, ?, 1, 0, 'user', 1, 'approved')`,
    [username, password, `${username}@example.com`, username, 'Conn', `${username}-act`, now, '2012']
  );
  return Number(sqlGet('SELECT id FROM uyeler WHERE kadi = ?', [username]).id);
}

const userAId = seedUser('phase2_conn_a', 'phase2-pass-a');
const userBId = seedUser('phase2_conn_b', 'phase2-pass-b');
const userCId = seedUser('phase2_conn_c', 'phase2-pass-c');

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
  const cookieA = await login('phase2_conn_a', 'phase2-pass-a');
  const cookieB = await login('phase2_conn_b', 'phase2-pass-b');
  const now = new Date().toISOString();
  const groupId = Number(sqlRun('INSERT INTO groups (name, owner_id, created_at, visibility) VALUES (?, ?, ?, ?)', ['Phase2 Affinity', userAId, now, 'public']).lastInsertRowid);
  sqlRun('INSERT INTO group_members (group_id, user_id, role, created_at) VALUES (?, ?, ?, ?)', [groupId, userAId, 'owner', now]);
  sqlRun('INSERT INTO group_members (group_id, user_id, role, created_at) VALUES (?, ?, ?, ?)', [groupId, userBId, 'member', now]);
  sqlRun(
    `INSERT INTO mentorship_requests (requester_id, mentor_id, status, focus_area, message, created_at, updated_at, responded_at)
     VALUES (?, ?, 'accepted', 'career', 'ok', ?, ?, ?)` ,
    [userAId, userCId, now, now, now]
  );
  sqlRun(
    `INSERT INTO mentorship_requests (requester_id, mentor_id, status, focus_area, message, created_at, updated_at, responded_at)
     VALUES (?, ?, 'accepted', 'career', 'ok', ?, ?, ?)` ,
    [userBId, userCId, now, now, now]
  );
  sqlRun(
    `INSERT INTO teacher_alumni_links (teacher_user_id, alumni_user_id, relationship_type, class_year, notes, created_by, created_at)
     VALUES (?, ?, 'student', '2012', '', ?, ?)` ,
    [userCId, userAId, userAId, now]
  );
  sqlRun(
    `INSERT INTO teacher_alumni_links (teacher_user_id, alumni_user_id, relationship_type, class_year, notes, created_by, created_at)
     VALUES (?, ?, 'student', '2012', '', ?, ?)` ,
    [userCId, userBId, userBId, now]
  );

  const send = await request(`/api/new/connections/request/${userBId}`, { method: 'POST', cookie: cookieA });
  assert.equal(send.res.status, 200);
  assert.equal(send.data?.status, 'pending');

  const pending = await request('/api/new/connections/requests?direction=incoming&status=pending', { cookie: cookieB });
  assert.equal(pending.res.status, 200);
  assert.equal(Array.isArray(pending.data?.items), true);
  assert.equal(pending.data.items.length, 1);

  const reqId = Number(pending.data.items[0].id);
  const accept = await request(`/api/new/connections/accept/${reqId}`, { method: 'POST', cookie: cookieB });
  assert.equal(accept.res.status, 200);
  assert.equal(accept.data?.status, 'accepted');

  const followAB = sqlGet('SELECT id FROM follows WHERE follower_id = ? AND following_id = ?', [userAId, userBId]);
  const followBA = sqlGet('SELECT id FROM follows WHERE follower_id = ? AND following_id = ?', [userBId, userAId]);
  assert.ok(followAB?.id);
  assert.ok(followBA?.id);

  const sendAgain = await request(`/api/new/connections/request/${userBId}`, { method: 'POST', cookie: cookieA });
  assert.equal(sendAgain.res.status, 409);
  assert.equal(sendAgain.data?.code, 'ALREADY_CONNECTED');

  const suggestions = await request('/api/new/explore/suggestions?limit=20&offset=0', { cookie: cookieA });
  assert.equal(suggestions.res.status, 200);
  const suggestedB = (suggestions.data?.items || []).find((item) => Number(item.id) === userCId);
  assert.ok(suggestedB);
  const reasonText = (suggestedB.reasons || []).join(' | ').toLowerCase();
  assert.ok(reasonText.includes('mentorluk') || reasonText.includes('ogretmen') || reasonText.includes('ortak grup'));
  assert.equal(Array.isArray(suggestedB.trust_badges), true);
  assert.equal(suggestedB.trust_badges.includes('teacher_network'), true);

  console.log('phase2 connections tests passed');
} finally {
  await new Promise((resolve) => server.close(resolve));
}
