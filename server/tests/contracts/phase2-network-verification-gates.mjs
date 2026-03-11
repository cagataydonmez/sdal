import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import Database from 'better-sqlite3';
import { fileURLToPath } from 'node:url';

const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'sdal-phase2-network-verification-'));
const bootstrapPath = path.join(tmpDir, 'bootstrap.sqlite');
const runtimeDbPath = path.join(tmpDir, 'runtime.sqlite');
const currentDir = path.dirname(fileURLToPath(import.meta.url));
const sourceDb = path.resolve(currentDir, '../../../db/sdal.sqlite');
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
  CREATE TABLE IF NOT EXISTS teacher_alumni_links (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    teacher_user_id INTEGER NOT NULL,
    alumni_user_id INTEGER NOT NULL,
    relationship_type TEXT NOT NULL,
    class_year INTEGER,
    notes TEXT,
    confidence_score REAL NOT NULL DEFAULT 1.0,
    created_by INTEGER,
    created_at TEXT NOT NULL,
    UNIQUE(teacher_user_id, alumni_user_id, relationship_type, class_year)
  );
  CREATE TABLE IF NOT EXISTS jobs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    poster_id INTEGER,
    company TEXT,
    title TEXT,
    description TEXT,
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
    created_at TEXT NOT NULL,
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
process.env.SDAL_SESSION_SECRET = 'phase2-network-verification-secret';
process.env.SDAL_ADMIN_PASSWORD = 'AdminPanel!123';
process.env.ROOT_BOOTSTRAP_PASSWORD = 'RootPass!123';
process.env.MAIL_ALLOW_MOCK = 'true';
process.env.SDAL_LEGACY_ROOT_DIR = tmpDir;
process.env.REDIS_URL = '';
process.env.JOB_INLINE_WORKER = 'true';

const { default: app, onServerStarted } = await import('../../app.js');
const { sqlRun, sqlGet } = await import('../../db.js');
await onServerStarted();

function seedUser(username, password, { verified = 1, verificationStatus = 'approved', mentorOptIn = 0, role = 'user', mezuniyetYili = '2012' } = {}) {
  const now = new Date().toISOString();
  sqlRun(
    `INSERT INTO uyeler (kadi, sifre, email, isim, soyisim, aktivasyon, aktiv, ilktarih, mezuniyetyili, ilkbd, admin, role, verified, verification_status, mentor_opt_in)
     VALUES (?, ?, ?, ?, ?, ?, 1, ?, ?, 1, 0, ?, ?, ?, ?)`,
    [username, password, `${username}@example.com`, username, 'Verification', `${username}-act`, now, mezuniyetYili, role, verified, verificationStatus, mentorOptIn]
  );
  return Number(sqlGet('SELECT id FROM uyeler WHERE kadi = ?', [username]).id);
}

const unverifiedUserId = seedUser('phase2_unverified', 'phase2-pass-unverified', { verified: 0, verificationStatus: 'pending' });
const verifiedPeerId = seedUser('phase2_verified_peer', 'phase2-pass-verified-peer');
const verifiedMentorId = seedUser('phase2_verified_mentor', 'phase2-pass-verified-mentor', { mentorOptIn: 1 });
const teacherId = seedUser('phase2_teacher', 'phase2-pass-teacher', { role: 'teacher', mezuniyetYili: 'ogretmen' });
const verifiedPosterId = seedUser('phase2_job_poster', 'phase2-pass-job-poster');

const now = new Date().toISOString();
sqlRun(
  'INSERT INTO jobs (poster_id, company, title, description, location, job_type, link, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
  [verifiedPosterId, 'SDAL Tech', 'Backend Engineer', 'Test listing', 'İstanbul', 'full_time', null, now]
);
const seededJobId = Number(sqlGet('SELECT id FROM jobs WHERE poster_id = ? ORDER BY id DESC LIMIT 1', [verifiedPosterId]).id);

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

function assertVerificationRequired(out) {
  assert.equal(out.res.status, 403);
  if (out.data && typeof out.data === 'object') {
    if (out.data.code) {
      assert.equal(out.data.code, 'VERIFICATION_REQUIRED');
      return;
    }
    if (typeof out.data.message === 'string') {
      assert.match(out.data.message, /doğrulama/i);
      return;
    }
  }
  assert.match(String(out.data || ''), /doğrulama/i);
}

try {
  const unverifiedCookie = await login('phase2_unverified', 'phase2-pass-unverified');

  const connectionReq = await request(`/api/new/connections/request/${verifiedPeerId}`, {
    method: 'POST',
    cookie: unverifiedCookie
  });
  assertVerificationRequired(connectionReq);

  const mentorshipReq = await request(`/api/new/mentorship/request/${verifiedMentorId}`, {
    method: 'POST',
    cookie: unverifiedCookie,
    body: { focus_area: 'Career', message: 'Need mentorship' }
  });
  assertVerificationRequired(mentorshipReq);

  const teacherLinkReq = await request(`/api/new/teachers/network/link/${teacherId}`, {
    method: 'POST',
    cookie: unverifiedCookie,
    body: { relationship_type: 'taught_in_class', class_year: 2012 }
  });
  assertVerificationRequired(teacherLinkReq);

  const applyReq = await request(`/api/new/jobs/${seededJobId}/apply`, {
    method: 'POST',
    cookie: unverifiedCookie,
    body: { cover_letter: 'Please consider me.' }
  });
  assertVerificationRequired(applyReq);

  const postJobReq = await request('/api/new/jobs', {
    method: 'POST',
    cookie: unverifiedCookie,
    body: {
      company: 'SDAL Labs',
      title: 'Frontend Engineer',
      description: 'Build alumni platform',
      location: 'Remote',
      job_type: 'full_time'
    }
  });
  assertVerificationRequired(postJobReq);

  console.log('phase2 network verification gate tests passed');
} finally {
  await new Promise((resolve) => server.close(resolve));
}
