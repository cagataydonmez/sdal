import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import Database from 'better-sqlite3';

const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'sdal-phase2-teacher-network-'));
const bootstrapPath = path.join(tmpDir, 'bootstrap.sqlite');
const runtimeDbPath = path.join(tmpDir, 'runtime.sqlite');
const sourceDb = path.resolve(process.cwd(), '../db/sdal.sqlite');
fs.copyFileSync(sourceDb, bootstrapPath);

const bootstrapDb = new Database(bootstrapPath);
bootstrapDb.exec(`
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
process.env.SDAL_SESSION_SECRET = 'phase2-teacher-network-secret';
process.env.SDAL_ADMIN_PASSWORD = 'AdminPanel!123';
process.env.ROOT_BOOTSTRAP_PASSWORD = 'RootPass!123';
process.env.MAIL_ALLOW_MOCK = 'true';
process.env.SDAL_LEGACY_ROOT_DIR = tmpDir;
process.env.REDIS_URL = '';
process.env.JOB_INLINE_WORKER = 'true';

const { default: app, onServerStarted } = await import('../../app.js');
const { sqlRun, sqlGet } = await import('../../db.js');
await onServerStarted();

function seedUser(username, password, role = 'user') {
  const now = new Date().toISOString();
  sqlRun(
    `INSERT INTO uyeler (kadi, sifre, email, isim, soyisim, aktivasyon, aktiv, ilktarih, mezuniyetyili, ilkbd, admin, role, verified, verification_status)
     VALUES (?, ?, ?, ?, ?, ?, 1, ?, ?, 1, 0, ?, 1, 'approved')`,
    [username, password, `${username}@example.com`, username, 'Network', `${username}-act`, now, '2012', role]
  );
  return Number(sqlGet('SELECT id FROM uyeler WHERE kadi = ?', [username]).id);
}

const alumniId = seedUser('phase2_alumni_a', 'phase2-pass-a', 'user');
const teacherId = seedUser('phase2_teacher_a', 'phase2-pass-b', 'teacher');
const regularUserId = seedUser('phase2_regular_a', 'phase2-pass-c', 'user');

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
  const alumniCookie = await login('phase2_alumni_a', 'phase2-pass-a');
  const teacherCookie = await login('phase2_teacher_a', 'phase2-pass-b');

  const invalidYear = await request(`/api/new/teachers/network/link/${teacherId}`, {
    method: 'POST',
    cookie: alumniCookie,
    body: { relationship_type: 'taught_in_class', class_year: 1899, notes: 'Invalid year' }
  });
  assert.equal(invalidYear.res.status, 400);
  assert.equal(invalidYear.data?.code, 'INVALID_CLASS_YEAR');

  const invalidTarget = await request(`/api/new/teachers/network/link/${regularUserId}`, {
    method: 'POST',
    cookie: alumniCookie,
    body: { relationship_type: 'advisor', class_year: 2012 }
  });
  assert.equal(invalidTarget.res.status, 409);
  assert.equal(invalidTarget.data?.code, 'INVALID_TEACHER_TARGET');

  const link = await request(`/api/new/teachers/network/link/${teacherId}`, {
    method: 'POST',
    cookie: alumniCookie,
    body: { relationship_type: 'taught_in_class', class_year: 2012, notes: 'Mathematics' }
  });
  assert.equal(link.res.status, 200);
  assert.equal(link.data?.status, 'linked');

  const duplicate = await request(`/api/new/teachers/network/link/${teacherId}`, {
    method: 'POST',
    cookie: alumniCookie,
    body: { relationship_type: 'taught_in_class', class_year: 2012 }
  });
  assert.equal(duplicate.res.status, 409);
  assert.equal(duplicate.data?.code, 'RELATIONSHIP_ALREADY_EXISTS');

  const myTeachers = await request('/api/new/teachers/network?direction=my_teachers&relationship_type=taught_in_class', { cookie: alumniCookie });
  assert.equal(myTeachers.res.status, 200);
  assert.equal(Array.isArray(myTeachers.data?.items), true);
  assert.equal(myTeachers.data.items.length, 1);
  assert.equal(Number(myTeachers.data.items[0].teacher_user_id), teacherId);

  const myStudents = await request('/api/new/teachers/network?direction=my_students&class_year=2012', { cookie: teacherCookie });
  assert.equal(myStudents.res.status, 200);
  assert.equal(Array.isArray(myStudents.data?.items), true);
  assert.equal(myStudents.data.items.length, 1);
  assert.equal(Number(myStudents.data.items[0].alumni_user_id), alumniId);

  const invalidFilter = await request('/api/new/teachers/network?direction=my_students&class_year=2201', { cookie: teacherCookie });
  assert.equal(invalidFilter.res.status, 400);
  assert.equal(invalidFilter.data?.code, 'INVALID_CLASS_YEAR');

  console.log('phase2 teacher network tests passed');
} finally {
  await new Promise((resolve) => server.close(resolve));
}
