import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import Database from 'better-sqlite3';

const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'sdal-phase2-jobs-applications-'));
const bootstrapPath = path.join(tmpDir, 'bootstrap.sqlite');
const runtimeDbPath = path.join(tmpDir, 'runtime.sqlite');
const sourceDb = path.resolve(process.cwd(), '../db/sdal.sqlite');
fs.copyFileSync(sourceDb, bootstrapPath);

const bootstrapDb = new Database(bootstrapPath);
bootstrapDb.exec(`
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
    status TEXT NOT NULL DEFAULT 'pending',
    reviewed_at TEXT,
    reviewed_by INTEGER,
    decision_note TEXT,
    created_at TEXT,
    UNIQUE(job_id, applicant_id)
  );
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
  CREATE TABLE IF NOT EXISTS notification_delivery_audit (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    notification_id INTEGER,
    user_id INTEGER,
    source_user_id INTEGER,
    entity_id INTEGER,
    notification_type TEXT,
    delivery_status TEXT NOT NULL,
    skip_reason TEXT,
    error_message TEXT,
    created_at TEXT NOT NULL
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
process.env.SDAL_SESSION_SECRET = 'phase2-jobs-applications-secret';
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
    [username, password, `${username}@example.com`, username, 'Jobs', `${username}-act`, now, '2012', role]
  );
  return Number(sqlGet('SELECT id FROM uyeler WHERE kadi = ?', [username]).id);
}

const posterId = seedUser('phase2_jobs_poster', 'phase2-pass-a');
const applicantId = seedUser('phase2_jobs_applicant', 'phase2-pass-b');

sqlRun(
  `INSERT INTO jobs (poster_id, company, title, description, location, job_type, link, created_at)
   VALUES (?, 'SDAL Labs', 'Backend Engineer', 'API role', 'Istanbul', 'full_time', 'https://example.com/job', ?)`,
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
  const posterCookie = await login('phase2_jobs_poster', 'phase2-pass-a');
  const applicantCookie = await login('phase2_jobs_applicant', 'phase2-pass-b');

  const apply = await request(`/api/new/jobs/${jobId}/apply`, {
    method: 'POST',
    cookie: applicantCookie,
    body: { cover_letter: 'Bu rol ile ilgileniyorum.' }
  });
  assert.equal(apply.res.status, 200);
  assert.equal(apply.data?.status, 'applied');

  const duplicate = await request(`/api/new/jobs/${jobId}/apply`, {
    method: 'POST',
    cookie: applicantCookie
  });
  assert.equal(duplicate.res.status, 409);
  assert.equal(duplicate.data?.code, 'ALREADY_APPLIED');

  const ownApply = await request(`/api/new/jobs/${jobId}/apply`, {
    method: 'POST',
    cookie: posterCookie
  });
  assert.equal(ownApply.res.status, 409);
  assert.equal(ownApply.data?.code, 'CANNOT_APPLY_OWN_JOB');

  const listAsPoster = await request(`/api/new/jobs/${jobId}/applications`, { cookie: posterCookie });
  assert.equal(listAsPoster.res.status, 200);
  assert.equal(Array.isArray(listAsPoster.data?.items), true);
  assert.equal(listAsPoster.data.items.length, 1);
  assert.equal(Number(listAsPoster.data.items[0].applicant_id), applicantId);
  const applicationId = Number(listAsPoster.data.items[0].id || 0);
  assert.ok(applicationId > 0);

  const review = await request(`/api/new/jobs/${jobId}/applications/${applicationId}/review`, {
    method: 'POST',
    cookie: posterCookie,
    body: { status: 'accepted', decision_note: 'Ikinci gorusmeye davetlisin.' }
  });
  assert.equal(review.res.status, 200);
  assert.equal(review.data?.ok, true);
  assert.equal(review.data?.data?.status, 'accepted');

  const listAsApplicant = await request(`/api/new/jobs/${jobId}/applications`, { cookie: applicantCookie });
  assert.equal(listAsApplicant.res.status, 403);

  const posterListAfterReview = await request(`/api/new/jobs/${jobId}/applications`, { cookie: posterCookie });
  assert.equal(posterListAfterReview.res.status, 200);
  assert.equal(String(posterListAfterReview.data?.items?.[0]?.status || ''), 'accepted');
  assert.equal(String(posterListAfterReview.data?.items?.[0]?.decision_note || ''), 'Ikinci gorusmeye davetlisin.');

  const applicantJobs = await request('/api/new/jobs', { cookie: applicantCookie });
  assert.equal(applicantJobs.res.status, 200);
  const applicantJobRow = (applicantJobs.data?.items || []).find((item) => Number(item.id || 0) === jobId);
  assert.ok(applicantJobRow);
  assert.equal(Number(applicantJobRow.my_application_id || 0), applicationId);
  assert.equal(String(applicantJobRow.my_application_status || ''), 'accepted');
  assert.equal(String(applicantJobRow.my_application_decision_note || ''), 'Ikinci gorusmeye davetlisin.');

  const applicantNotifications = await request('/api/new/notifications?limit=20&offset=0', { cookie: applicantCookie });
  assert.equal(applicantNotifications.res.status, 200);
  const decisionNotification = (applicantNotifications.data?.data?.items || []).find((item) => item.type === 'job_application_accepted');
  assert.ok(decisionNotification);
  assert.match(String(decisionNotification.target?.href || ''), new RegExp(`/new/jobs\\?job=${jobId}`));
  assert.match(String(decisionNotification.target?.href || ''), new RegExp(`application=${applicationId}`));
  assert.match(String(decisionNotification.target?.href || ''), /focus=my-application/);
  const deliveryAudit = Number(sqlGet('SELECT COUNT(*) AS cnt FROM notification_delivery_audit WHERE notification_type = ? AND delivery_status = ?', ['job_application_accepted', 'inserted']).cnt || 0);
  assert.ok(deliveryAudit >= 1);

  console.log('phase2 jobs applications tests passed');
} finally {
  await new Promise((resolve) => server.close(resolve));
}
