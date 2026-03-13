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
const { sqlRun, sqlGet, sqlAll } = await import('../../db.js');
await onServerStarted();

function seedUser(username, password, role = 'user') {
  const now = new Date().toISOString();
  const admin = role === 'admin' ? 1 : 0;
  sqlRun(
    `INSERT INTO uyeler (kadi, sifre, email, isim, soyisim, aktivasyon, aktiv, ilktarih, mezuniyetyili, ilkbd, admin, role, verified, verification_status)
     VALUES (?, ?, ?, ?, ?, ?, 1, ?, ?, 1, ?, ?, 1, 'approved')`,
    [username, password, `${username}@example.com`, username, 'Network', `${username}-act`, now, '2012', admin, role]
  );
  return Number(sqlGet('SELECT id FROM uyeler WHERE kadi = ?', [username]).id);
}

const alumniId = seedUser('phase2_alumni_a', 'phase2-pass-a', 'user');
const teacherId = seedUser('phase2_teacher_a', 'phase2-pass-b', 'teacher');
const regularUserId = seedUser('phase2_regular_a', 'phase2-pass-c', 'user');
const adminId = seedUser('phase2_admin_a', 'phase2-pass-admin', 'admin');

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
  const adminCookie = await login('phase2_admin_a', 'phase2-pass-admin');

  const invalidYear = await request(`/api/new/teachers/network/link/${teacherId}`, {
    method: 'POST',
    cookie: alumniCookie,
    body: { relationship_type: 'taught_in_class', class_year: 1899, notes: 'Invalid year' }
  });
  assert.equal(invalidYear.res.status, 400);
  assert.equal(invalidYear.data?.ok, false);
  assert.equal(invalidYear.data?.code, 'INVALID_CLASS_YEAR');

  const invalidTarget = await request(`/api/new/teachers/network/link/${regularUserId}`, {
    method: 'POST',
    cookie: alumniCookie,
    body: { relationship_type: 'advisor', class_year: 2012 }
  });
  assert.equal(invalidTarget.res.status, 409);
  assert.equal(invalidTarget.data?.ok, false);
  assert.equal(invalidTarget.data?.code, 'INVALID_TEACHER_TARGET');

  const link = await request(`/api/new/teachers/network/link/${teacherId}`, {
    method: 'POST',
    cookie: alumniCookie,
    body: { relationship_type: 'taught_in_class', class_year: 2012, notes: 'Mathematics', created_via: 'manual_alumni_link', source_surface: 'member_detail_page' }
  });
  assert.equal(link.res.status, 200);
  assert.equal(link.data?.ok, true);
  assert.equal(link.data?.code, 'TEACHER_NETWORK_LINK_CREATED');
  assert.equal(link.data?.data?.status, 'linked');
  assert.equal(link.data?.data?.audit?.created_via, 'manual_alumni_link');
  assert.equal(link.data?.data?.audit?.source_surface, 'member_detail_page');
  assert.equal(link.data?.data?.audit?.review_status, 'pending');
  assert.equal(typeof link.data?.data?.confidence_score, 'number');
  assert.equal(link.data?.data?.confidence_score > 0, true);
  assert.equal(link.data?.status, 'linked');

  const duplicate = await request(`/api/new/teachers/network/link/${teacherId}`, {
    method: 'POST',
    cookie: alumniCookie,
    body: { relationship_type: 'taught_in_class', class_year: 2012 }
  });
  assert.equal(duplicate.res.status, 409);
  assert.equal(duplicate.data?.ok, false);
  assert.equal(duplicate.data?.code, 'RELATIONSHIP_ALREADY_EXISTS');
  assert.equal(Array.isArray(duplicate.data?.duplicates), true);

  const similarWarning = await request(`/api/new/teachers/network/link/${teacherId}`, {
    method: 'POST',
    cookie: alumniCookie,
    body: { relationship_type: 'mentor', class_year: 2012, notes: 'Second relationship' }
  });
  assert.equal(similarWarning.res.status, 409);
  assert.equal(similarWarning.data?.ok, false);
  assert.equal(similarWarning.data?.code, 'SIMILAR_RELATIONSHIP_EXISTS');
  assert.equal(Array.isArray(similarWarning.data?.similar_links), true);
  assert.equal(similarWarning.data?.similar_links.length >= 1, true);
  assert.equal(similarWarning.data?.requires_confirmation, true);

  const similarConfirmed = await request(`/api/new/teachers/network/link/${teacherId}`, {
    method: 'POST',
    cookie: alumniCookie,
    body: { relationship_type: 'mentor', class_year: 2012, notes: 'Second relationship', confirm_similar: true }
  });
  assert.equal(similarConfirmed.res.status, 200);
  assert.equal(similarConfirmed.data?.ok, true);
  assert.equal(similarConfirmed.data?.data?.status, 'linked');

  const myTeachers = await request('/api/new/teachers/network?direction=my_teachers&relationship_type=taught_in_class', { cookie: alumniCookie });
  assert.equal(myTeachers.res.status, 200);
  assert.equal(myTeachers.data?.ok, true);
  assert.equal(myTeachers.data?.code, 'TEACHER_NETWORK_LIST_OK');
  assert.equal(Array.isArray(myTeachers.data?.data?.items), true);
  assert.equal(Array.isArray(myTeachers.data?.items), true);
  assert.equal(myTeachers.data.items.length, 1);
  assert.equal(Number(myTeachers.data.items[0].teacher_user_id), teacherId);
  assert.equal(myTeachers.data.items[0].review_status, 'pending');
  assert.equal(myTeachers.data.items[0].created_via, 'manual_alumni_link');
  assert.equal(myTeachers.data.items[0].source_surface, 'member_detail_page');
  assert.equal(typeof myTeachers.data.items[0].confidence_score, 'number');

  const myStudents = await request('/api/new/teachers/network?direction=my_students&class_year=2012', { cookie: teacherCookie });
  assert.equal(myStudents.res.status, 200);
  assert.equal(myStudents.data?.ok, true);
  assert.equal(Array.isArray(myStudents.data?.items), true);
  assert.equal(myStudents.data.items.length, 2);
  assert.equal(Number(myStudents.data.items[0].alumni_user_id), alumniId);

  const adminList = await request('/api/new/admin/teacher-network/links?relationship_type=taught_in_class', { cookie: adminCookie });
  assert.equal(adminList.res.status, 200);
  assert.equal(Array.isArray(adminList.data?.items), true);
  assert.equal(adminList.data.items.length, 1);
  const adminRow = adminList.data.items[0];
  assert.equal(adminRow.review_status, 'pending');
  assert.equal(adminRow.created_via, 'manual_alumni_link');
  assert.equal(adminRow.source_surface, 'member_detail_page');
  assert.equal(adminRow.moderation_assessment?.risk_level, 'medium');
  assert.equal(adminRow.moderation_assessment?.recommended_action, 'merge');
  assert.equal(Array.isArray(adminRow.moderation_assessment?.risk_signals), true);
  assert.equal(Array.isArray(adminRow.moderation_assessment?.positive_signals), true);
  const initialConfidence = Number(adminRow.confidence_score || 0);
  assert.equal(initialConfidence > 0, true);

  const review = await request(`/api/new/admin/teacher-network/links/${adminRow.id}/review`, {
    method: 'POST',
    cookie: adminCookie,
    body: { status: 'confirmed', note: 'Matches alumni statement' }
  });
  assert.equal(review.res.status, 200);
  assert.equal(review.data?.ok, true);
  assert.equal(review.data?.status, 'confirmed');
  assert.equal(review.data?.review_note, 'Matches alumni statement');
  assert.equal(typeof review.data?.reviewed_at, 'string');
  assert.equal(Number(review.data?.confidence_score || 0) >= initialConfidence, true);

  const adminListAfterReview = await request('/api/new/admin/teacher-network/links?review_status=confirmed', { cookie: adminCookie });
  assert.equal(adminListAfterReview.res.status, 200);
  assert.equal(Array.isArray(adminListAfterReview.data?.items), true);
  assert.equal(adminListAfterReview.data.items.length, 1);
  assert.equal(adminListAfterReview.data.items[0].review_status, 'confirmed');
  assert.equal(Number(adminListAfterReview.data.items[0].last_reviewed_by || 0), adminId);
  assert.equal(adminListAfterReview.data.items[0].reviewer_kadi, 'phase2_admin_a');
  assert.equal(adminListAfterReview.data.items[0].review_note, 'Matches alumni statement');
  assert.equal(typeof adminListAfterReview.data.items[0].reviewed_at, 'string');
  assert.equal(Number(adminListAfterReview.data.items[0].confidence_score || 0) >= initialConfidence, true);

  const myTeachersAfterReview = await request('/api/new/teachers/network?direction=my_teachers&relationship_type=taught_in_class', { cookie: alumniCookie });
  assert.equal(myTeachersAfterReview.res.status, 200);
  assert.equal(myTeachersAfterReview.data.items[0].review_status, 'confirmed');
  assert.equal(Number(myTeachersAfterReview.data.items[0].confidence_score || 0) >= initialConfidence, true);

  const adminMentorList = await request('/api/new/admin/teacher-network/links?relationship_type=mentor', { cookie: adminCookie });
  assert.equal(adminMentorList.res.status, 200);
  assert.equal(Array.isArray(adminMentorList.data?.items), true);
  assert.equal(adminMentorList.data.items.length, 1);
  const mentorRow = adminMentorList.data.items[0];
  assert.equal(mentorRow.moderation_assessment?.recommended_action, 'merge');
  assert.equal(mentorRow.moderation_assessment?.duplicate_active_count >= 1, true);
  assert.equal(mentorRow.moderation_assessment?.risk_signals.some((item) => item.code === 'duplicate_active_pair'), true);

  const mergeReview = await request(`/api/new/admin/teacher-network/links/${mentorRow.id}/review`, {
    method: 'POST',
    cookie: adminCookie,
    body: { status: 'merged', note: 'Duplicate claim merged into primary record', merge_into_link_id: adminRow.id }
  });
  assert.equal(mergeReview.res.status, 200);
  assert.equal(mergeReview.data?.ok, true);
  assert.equal(mergeReview.data?.status, 'merged');
  assert.equal(Number(mergeReview.data?.merged_into_link_id || 0), adminRow.id);

  const adminMergedList = await request('/api/new/admin/teacher-network/links?review_status=merged', { cookie: adminCookie });
  assert.equal(adminMergedList.res.status, 200);
  assert.equal(Array.isArray(adminMergedList.data?.items), true);
  assert.equal(adminMergedList.data.items.length, 1);
  assert.equal(Number(adminMergedList.data.items[0].merged_into_link_id || 0), adminRow.id);
  assert.equal(adminMergedList.data.items[0].review_note, 'Duplicate claim merged into primary record');

  const myStudentsAfterMerge = await request('/api/new/teachers/network?direction=my_students&class_year=2012', { cookie: teacherCookie });
  assert.equal(myStudentsAfterMerge.res.status, 200);
  assert.equal(Array.isArray(myStudentsAfterMerge.data?.items), true);
  assert.equal(myStudentsAfterMerge.data.items.length, 1);

  const optionsAfterMerge = await request(`/api/new/teachers/options?term=no-match&limit=10&include_id=${teacherId}`, { cookie: alumniCookie });
  assert.equal(optionsAfterMerge.res.status, 200);
  assert.equal(Number(optionsAfterMerge.data.items[0]?.existing_link_count || 0), 1);

  const rejectReview = await request(`/api/new/admin/teacher-network/links/${adminRow.id}/review`, {
    method: 'POST',
    cookie: adminCookie,
    body: { status: 'rejected', note: 'Evidence not strong enough yet' }
  });
  assert.equal(rejectReview.res.status, 200);
  assert.equal(rejectReview.data?.status, 'rejected');

  const adminRejectedList = await request('/api/new/admin/teacher-network/links?review_status=rejected', { cookie: adminCookie });
  assert.equal(adminRejectedList.res.status, 200);
  assert.equal(Array.isArray(adminRejectedList.data?.items), true);
  assert.equal(adminRejectedList.data.items.length, 1);
  assert.equal(adminRejectedList.data.items[0].review_note, 'Evidence not strong enough yet');

  const myTeachersAfterReject = await request('/api/new/teachers/network?direction=my_teachers&relationship_type=taught_in_class', { cookie: alumniCookie });
  assert.equal(myTeachersAfterReject.res.status, 200);
  assert.equal(Array.isArray(myTeachersAfterReject.data?.items), true);
  assert.equal(myTeachersAfterReject.data.items.length, 0);

  const resetReview = await request(`/api/new/admin/teacher-network/links/${adminRow.id}/review`, {
    method: 'POST',
    cookie: adminCookie,
    body: { status: 'pending', note: 'Returned to queue for another pass' }
  });
  assert.equal(resetReview.res.status, 200);
  assert.equal(resetReview.data?.status, 'pending');

  const myTeachersAfterReset = await request('/api/new/teachers/network?direction=my_teachers&relationship_type=taught_in_class', { cookie: alumniCookie });
  assert.equal(myTeachersAfterReset.res.status, 200);
  assert.equal(myTeachersAfterReset.data.items.length, 1);
  assert.equal(myTeachersAfterReset.data.items[0].review_status, 'pending');

  const moderationEvents = sqlAll(
    `SELECT event_type, to_status
     FROM teacher_alumni_link_moderation_events
     WHERE link_id IN (?, ?)
     ORDER BY id ASC`,
    [adminRow.id, mentorRow.id]
  );
  assert.equal(moderationEvents.length >= 4, true);
  assert.equal(moderationEvents.some((row) => row.event_type === 'teacher_link_reviewed' && row.to_status === 'confirmed'), true);
  assert.equal(moderationEvents.some((row) => row.event_type === 'teacher_link_merged' && row.to_status === 'merged'), true);
  assert.equal(moderationEvents.some((row) => row.event_type === 'teacher_link_reviewed' && row.to_status === 'rejected'), true);
  assert.equal(moderationEvents.some((row) => row.event_type === 'teacher_link_reviewed' && row.to_status === 'pending'), true);

  const optionsWithInclude = await request(`/api/new/teachers/options?term=no-match&limit=10&include_id=${teacherId}`, { cookie: alumniCookie });
  assert.equal(optionsWithInclude.res.status, 200);
  assert.equal(optionsWithInclude.data?.ok, true);
  assert.equal(optionsWithInclude.data?.code, 'TEACHER_OPTIONS_OK');
  assert.equal(Array.isArray(optionsWithInclude.data?.data?.items), true);
  assert.equal(Array.isArray(optionsWithInclude.data?.items), true);
  assert.equal(Number(optionsWithInclude.data.items[0]?.id || 0), teacherId);
  assert.equal(Number(optionsWithInclude.data.items[0]?.existing_link_count || 0), 1);

  const invalidFilter = await request('/api/new/teachers/network?direction=my_students&class_year=2201', { cookie: teacherCookie });
  assert.equal(invalidFilter.res.status, 400);
  assert.equal(invalidFilter.data?.ok, false);
  assert.equal(invalidFilter.data?.code, 'INVALID_CLASS_YEAR');

  console.log('phase2 teacher network tests passed');
} finally {
  await new Promise((resolve) => server.close(resolve));
}
