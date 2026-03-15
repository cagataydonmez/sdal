import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import Database from 'better-sqlite3';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'sdal-phase2-opportunity-inbox-'));
const bootstrapPath = path.join(tmpDir, 'bootstrap.sqlite');
const runtimeDbPath = path.join(tmpDir, 'runtime.sqlite');
const sourceDb = path.resolve(__dirname, '../../../db/sdal.sqlite');
fs.copyFileSync(sourceDb, bootstrapPath);

const bootstrapDb = new Database(bootstrapPath);
bootstrapDb.exec(`
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
    read_at TEXT,
    created_at TEXT
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
    status TEXT NOT NULL DEFAULT 'pending',
    reviewed_at TEXT,
    reviewed_by INTEGER,
    decision_note TEXT,
    created_at TEXT,
    UNIQUE(job_id, applicant_id)
  );
`);
bootstrapDb.close();

process.env.SDAL_DB_PATH = runtimeDbPath;
process.env.SDAL_DB_BOOTSTRAP_PATH = bootstrapPath;
process.env.SDAL_SESSION_SECRET = 'phase2-opportunity-inbox-secret';
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
    [username, password, `${username}@example.com`, username, 'Inbox', `${username}-act`, now, year, role, mentorOptIn]
  );
  return Number(sqlGet('SELECT id FROM uyeler WHERE kadi = ?', [username]).id);
}

const meId = seedUser('phase2_opp_me', 'phase2-pass-me', 'teacher', 'teacher', 1);
const connectionSenderId = seedUser('phase2_opp_sender', 'phase2-pass-sender', 'user', '2011');
const mentorshipRequesterId = seedUser('phase2_opp_mentee', 'phase2-pass-mentee', 'user', '2012');
const suggestionId = seedUser('phase2_opp_candidate', 'phase2-pass-candidate', 'user', '2011', 1);
const teacherSourceId = seedUser('phase2_opp_teacher', 'phase2-pass-teacher', 'user', '2010');
const jobApplicantId = seedUser('phase2_opp_job_applicant', 'phase2-pass-job-app', 'user', '2014');
const otherPosterId = seedUser('phase2_opp_poster', 'phase2-pass-poster', 'user', '2013');

sqlRun('UPDATE uyeler SET ilktarih = ? WHERE id = ?', ['2026-01-01T00:00:00.000Z', meId]);

const now = new Date().toISOString();
sqlRun('INSERT INTO connection_requests (sender_id, receiver_id, status, created_at, updated_at) VALUES (?, ?, ?, ?, ?)', [connectionSenderId, meId, 'pending', now, now]);
sqlRun(
  `INSERT INTO mentorship_requests (requester_id, mentor_id, status, focus_area, message, created_at, updated_at)
   VALUES (?, ?, 'requested', 'career', 'yardim', ?, ?)`,
  [mentorshipRequesterId, meId, now, now]
);
sqlRun(
  `INSERT INTO notifications (user_id, type, source_user_id, entity_id, message, created_at)
   VALUES (?, 'teacher_network_linked', ?, ?, 'Seni öğretmen ağına ekledi.', ?)`,
  [meId, teacherSourceId, meId, now]
);

sqlRun(
  `INSERT INTO jobs (poster_id, company, title, description, location, job_type, link, created_at)
   VALUES (?, 'SDAL Labs', 'Backend Engineer', 'API role', 'Istanbul', 'full_time', 'https://example.com/backend', ?)`,
  [meId, now]
);
const reviewJobId = Number(sqlGet('SELECT id FROM jobs WHERE poster_id = ? ORDER BY id DESC LIMIT 1', [meId]).id);
sqlRun(
  `INSERT INTO job_applications (job_id, applicant_id, cover_letter, status, created_at)
   VALUES (?, ?, 'Bu rol ilgimi çekiyor', 'pending', ?)`,
  [reviewJobId, jobApplicantId, now]
);
const reviewApplicationId = Number(sqlGet('SELECT id FROM job_applications WHERE job_id = ? AND applicant_id = ?', [reviewJobId, jobApplicantId]).id);

sqlRun(
  `INSERT INTO jobs (poster_id, company, title, description, location, job_type, link, created_at)
   VALUES (?, 'Graph Co', 'Product Manager', 'Community role', 'Remote', 'full_time', 'https://example.com/product', ?)`,
  [otherPosterId, now]
);
const myAppliedJobId = Number(sqlGet('SELECT id FROM jobs WHERE poster_id = ? ORDER BY id DESC LIMIT 1', [otherPosterId]).id);
sqlRun(
  `INSERT INTO job_applications (job_id, applicant_id, cover_letter, status, reviewed_at, reviewed_by, decision_note, created_at)
   VALUES (?, ?, 'Deneyimim uygun', 'accepted', ?, ?, 'Görüşmeye bekliyoruz.', ?)`,
  [myAppliedJobId, meId, now, otherPosterId, now]
);
const myAppliedApplicationId = Number(sqlGet('SELECT id FROM job_applications WHERE job_id = ? AND applicant_id = ?', [myAppliedJobId, meId]).id);

sqlRun(
  `INSERT INTO jobs (poster_id, company, title, description, location, job_type, link, created_at)
   VALUES (?, 'Warm Intro Inc', 'Growth Lead', 'Network-heavy role', 'Ankara', 'hybrid', 'https://example.com/growth', ?)`,
  [otherPosterId, now]
);
const recommendationJobId = Number(sqlGet('SELECT id FROM jobs WHERE title = ?', ['Growth Lead']).id);

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
  const cookieMe = await login('phase2_opp_me', 'phase2-pass-me');

  const inbox = await request('/api/new/opportunities?limit=20&tab=all', { cookie: cookieMe });
  assert.equal(inbox.res.status, 200);
  assert.equal(inbox.data?.ok, true);
  assert.equal(inbox.data?.code, 'OPPORTUNITY_INBOX_OK');
  const payload = inbox.data?.data?.opportunities;
  assert.ok(payload);
  assert.equal(payload.tab, 'all');
  assert.equal(Array.isArray(payload.items), true);
  assert.equal(payload.summary.now >= 4, true);
  assert.equal(String(payload.items[0]?.kind || ''), 'mentorship_request');
  assert.equal(payload.items.some((item) => item.kind === 'connection_request'), true);
  assert.equal(payload.items.some((item) => item.kind === 'teacher_link_update'), true);
  assert.equal(payload.items.some((item) => item.kind === 'job_application_review' && Number(item.entity_id || 0) === reviewApplicationId), true);
  assert.equal(payload.items.some((item) => item.kind === 'job_application_update' && Number(item.entity_id || 0) === myAppliedApplicationId), true);
  assert.equal(payload.items.some((item) => item.kind === 'member_suggestion' && Number(item.entity_id || 0) === suggestionId), true);
  assert.equal(payload.items.some((item) => item.kind === 'job_recommendation' && Number(item.entity_id || 0) === recommendationJobId), true);

  const jobsOnly = await request('/api/new/opportunities?limit=20&tab=jobs', { cookie: cookieMe });
  assert.equal(jobsOnly.res.status, 200);
  const jobsPayload = jobsOnly.data?.data?.opportunities;
  assert.equal(jobsPayload.tab, 'jobs');
  assert.equal(jobsPayload.items.every((item) => item.category === 'jobs'), true);

  const page1 = await request('/api/new/opportunities?limit=2&tab=all', { cookie: cookieMe });
  assert.equal(page1.res.status, 200);
  const page1Payload = page1.data?.data?.opportunities;
  assert.equal(page1Payload.items.length, 2);
  assert.equal(Boolean(page1Payload.next_cursor), true);

  const page2 = await request(`/api/new/opportunities?limit=2&tab=all&cursor=${encodeURIComponent(page1Payload.next_cursor)}`, { cookie: cookieMe });
  assert.equal(page2.res.status, 200);
  const page2Payload = page2.data?.data?.opportunities;
  assert.equal(page2Payload.items.length >= 1, true);
  assert.notEqual(page2Payload.items[0]?.id, page1Payload.items[0]?.id);

  console.log('phase2 opportunity inbox tests passed');
} finally {
  await new Promise((resolve) => server.close(resolve));
}
