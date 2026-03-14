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
    status TEXT NOT NULL DEFAULT 'pending',
    reviewed_at TEXT,
    reviewed_by INTEGER,
    decision_note TEXT,
    created_at TEXT,
    UNIQUE(job_id, applicant_id)
  );
  CREATE TABLE IF NOT EXISTS groups (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    description TEXT,
    cover_image TEXT,
    owner_id INTEGER,
    created_at TEXT,
    visibility TEXT DEFAULT 'public',
    show_contact_hint INTEGER DEFAULT 1
  );
  CREATE TABLE IF NOT EXISTS group_members (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    group_id INTEGER NOT NULL,
    user_id INTEGER NOT NULL,
    role TEXT NOT NULL DEFAULT 'member',
    created_at TEXT
  );
  CREATE TABLE IF NOT EXISTS group_invites (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    group_id INTEGER NOT NULL,
    invited_user_id INTEGER NOT NULL,
    invited_by INTEGER NOT NULL,
    status TEXT NOT NULL DEFAULT 'pending',
    created_at TEXT,
    responded_at TEXT
  );
  CREATE TABLE IF NOT EXISTS verification_requests (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL,
    status TEXT NOT NULL DEFAULT 'pending',
    proof_path TEXT,
    proof_image_record_id TEXT,
    created_at TEXT,
    reviewed_at TEXT,
    reviewer_id INTEGER
  );
  CREATE TABLE IF NOT EXISTS request_categories (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    category_key TEXT UNIQUE NOT NULL,
    label TEXT NOT NULL,
    description TEXT,
    active INTEGER DEFAULT 1
  );
  CREATE TABLE IF NOT EXISTS member_requests (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL,
    category_key TEXT NOT NULL,
    payload_json TEXT,
    status TEXT NOT NULL DEFAULT 'pending',
    created_at TEXT,
    reviewed_at TEXT,
    reviewer_id INTEGER,
    resolution_note TEXT
  );
  CREATE TABLE IF NOT EXISTS announcements (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    title TEXT NOT NULL,
    body TEXT NOT NULL,
    image TEXT,
    created_at TEXT,
    created_by INTEGER,
    approved INTEGER DEFAULT 0,
    approved_by INTEGER,
    approved_at TEXT
  );
  CREATE TABLE IF NOT EXISTS notification_telemetry_events (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER,
    notification_id INTEGER,
    event_name TEXT NOT NULL,
    notification_type TEXT,
    surface TEXT,
    action_kind TEXT,
    created_at TEXT NOT NULL
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
  CREATE TABLE IF NOT EXISTS follows (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    follower_id INTEGER NOT NULL,
    following_id INTEGER NOT NULL,
    created_at TEXT
  );
  CREATE TABLE IF NOT EXISTS events (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    title TEXT NOT NULL,
    description TEXT,
    location TEXT,
    starts_at TEXT,
    ends_at TEXT,
    image TEXT,
    created_at TEXT,
    created_by INTEGER,
    approved INTEGER DEFAULT 1,
    approved_by INTEGER,
    approved_at TEXT,
    show_response_counts INTEGER DEFAULT 1,
    show_attendee_names INTEGER DEFAULT 0,
    show_decliner_names INTEGER DEFAULT 0
  );
  CREATE TABLE IF NOT EXISTS event_responses (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    event_id INTEGER NOT NULL,
    user_id INTEGER NOT NULL,
    response TEXT NOT NULL,
    created_at TEXT,
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
function ensureColumn(table, column, definitionSql) {
  const columns = bootstrapDb.prepare(`PRAGMA table_info(${table})`).all();
  if (columns.some((row) => String(row.name || '').toLowerCase() === String(column || '').toLowerCase())) return;
  bootstrapDb.exec(`ALTER TABLE ${table} ADD COLUMN ${column} ${definitionSql}`);
}
for (const [column, definition] of [
  ['created_by', 'INTEGER'],
  ['approved', 'INTEGER DEFAULT 1'],
  ['approved_by', 'INTEGER'],
  ['approved_at', 'TEXT'],
  ['show_response_counts', 'INTEGER DEFAULT 1'],
  ['show_attendee_names', 'INTEGER DEFAULT 0'],
  ['show_decliner_names', 'INTEGER DEFAULT 0']
]) {
  ensureColumn('events', column, definition);
}
for (const [column, definition] of [
  ['active', 'INTEGER DEFAULT 1'],
  ['created_at', 'TEXT'],
  ['updated_at', 'TEXT']
]) {
  ensureColumn('request_categories', column, definition);
}
for (const [column, definition] of [
  ['body', 'TEXT'],
  ['image', 'TEXT'],
  ['created_at', 'TEXT'],
  ['created_by', 'INTEGER'],
  ['approved', 'INTEGER DEFAULT 0'],
  ['approved_by', 'INTEGER'],
  ['approved_at', 'TEXT']
]) {
  ensureColumn('announcements', column, definition);
}
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

function seedAdmin(username, password) {
  const now = new Date().toISOString();
  sqlRun(
    `INSERT INTO uyeler (kadi, sifre, email, isim, soyisim, aktivasyon, aktiv, ilktarih, mezuniyetyili, ilkbd, admin, role, verified, verification_status)
     VALUES (?, ?, ?, ?, ?, ?, 1, ?, ?, 1, 1, 'admin', 1, 'approved')`,
    [username, password, `${username}@example.com`, username, 'Admin', `${username}-act`, now, '2012']
  );
  return Number(sqlGet('SELECT id FROM uyeler WHERE kadi = ?', [username]).id);
}

const senderId = seedUser('phase2_notify_sender', 'phase2-pass-a');
const receiverId = seedUser('phase2_notify_receiver', 'phase2-pass-b');
const posterId = seedUser('phase2_notify_poster', 'phase2-pass-c');
const applicantId = seedUser('phase2_notify_applicant', 'phase2-pass-d');
const teacherId = seedUser('phase2_notify_teacher', 'phase2-pass-e', 'teacher');
seedAdmin('phase2_notify_admin', 'phase2-pass-admin');

sqlRun(
  `INSERT INTO events
     (title, description, location, starts_at, ends_at, created_at, created_by, approved, approved_by, approved_at, show_response_counts, show_attendee_names, show_decliner_names)
   VALUES (?, ?, ?, ?, ?, ?, ?, 1, ?, ?, 1, 0, 0)`,
  [
    'Phase2 Notification Summit',
    '<p>Bildirim kapsam testi</p>',
    'Istanbul',
    new Date(Date.now() + 86_400_000).toISOString(),
    new Date(Date.now() + 90_000_000).toISOString(),
    new Date().toISOString(),
    posterId,
    posterId,
    new Date().toISOString()
  ]
);
const eventId = Number(sqlGet('SELECT id FROM events WHERE created_by = ? ORDER BY id DESC LIMIT 1', [posterId]).id);
sqlRun(
  'INSERT INTO follows (follower_id, following_id, created_at) VALUES (?, ?, ?)',
  [receiverId, posterId, new Date().toISOString()]
);

sqlRun(
  `INSERT INTO jobs (poster_id, company, title, description, location, job_type, link, created_at)
   VALUES (?, 'SDAL Labs', 'Notifications Engineer', 'Own the inbox', 'Istanbul', 'full_time', 'https://example.com/job', ?)`,
  [posterId, new Date().toISOString()]
);
const jobId = Number(sqlGet('SELECT id FROM jobs WHERE poster_id = ? ORDER BY id DESC LIMIT 1', [posterId]).id);
sqlRun(
  `INSERT INTO groups (name, description, cover_image, owner_id, created_at, visibility, show_contact_hint)
   VALUES (?, ?, ?, ?, ?, 'private', 1)`,
  ['Phase2 Notifications Group', 'Notification routing coverage', '/images/group.jpg', senderId, new Date().toISOString()]
);
const groupId = Number(sqlGet('SELECT id FROM groups WHERE owner_id = ? ORDER BY id DESC LIMIT 1', [senderId]).id);
sqlRun(
  'INSERT INTO group_members (group_id, user_id, role, created_at) VALUES (?, ?, ?, ?)',
  [groupId, senderId, 'owner', new Date().toISOString()]
);
sqlRun(
  `INSERT OR IGNORE INTO request_categories (category_key, label, description, active)
   VALUES ('graduation_year_change', 'Graduation Year Change', 'Cohort update', 1)`
);

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
  const adminCookie = await login('phase2_notify_admin', 'phase2-pass-admin');

  const initialPreferences = await request('/api/new/notifications/preferences', { cookie: senderCookie });
  assert.equal(initialPreferences.res.status, 200);
  assert.equal(initialPreferences.data?.data?.preferences?.categories?.social, true);
  assert.ok(initialPreferences.data?.data?.experiments?.assignments?.sort_order);

  const updatedPreferences = await request('/api/new/notifications/preferences', {
    method: 'PUT',
    cookie: senderCookie,
    body: {
      categories: {
        social: false,
        groups: true,
        networking: true
      },
      quiet_mode: {
        enabled: true,
        start: '22:00',
        end: '07:00'
      }
    }
  });
  assert.equal(updatedPreferences.res.status, 200);
  assert.equal(updatedPreferences.data?.data?.preferences?.categories?.social, false);
  assert.equal(updatedPreferences.data?.data?.preferences?.quiet_mode?.enabled, true);

  const governance = await request('/api/new/admin/notifications/governance', { cookie: adminCookie });
  assert.equal(governance.res.status, 200);
  assert.equal(Array.isArray(governance.data?.data?.checklist), true);
  assert.equal(governance.data?.data?.inventory.some((item) => item.type === 'verification_approved'), true);

  const experimentList = await request('/api/new/admin/notifications/experiments', { cookie: adminCookie });
  assert.equal(experimentList.res.status, 200);
  assert.equal(experimentList.data?.data?.items.some((item) => item.key === 'cta_wording'), true);

  const experimentUpdate = await request('/api/new/admin/notifications/experiments/cta_wording', {
    method: 'PUT',
    cookie: adminCookie,
    body: { status: 'paused', variants: ['neutral', 'action'] }
  });
  assert.equal(experimentUpdate.res.status, 200);
  assert.equal(experimentUpdate.data?.data?.item?.status, 'paused');

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

  const inviteUnauthorized = await request(`/api/new/events/${eventId}/notify`, {
    method: 'POST',
    cookie: senderCookie,
    body: { mode: 'invite' }
  });
  assert.equal(inviteUnauthorized.res.status, 403);

  const inviteFollowers = await request(`/api/new/events/${eventId}/notify`, {
    method: 'POST',
    cookie: posterCookie,
    body: { mode: 'invite' }
  });
  assert.equal(inviteFollowers.res.status, 200);
  assert.equal(Number(inviteFollowers.data?.count || 0), 1);
  assert.equal(inviteFollowers.data?.mode, 'invite');

  const receiverEventNotifications = await request('/api/new/notifications?limit=20&sort=priority', { cookie: receiverCookie });
  assert.equal(receiverEventNotifications.res.status, 200);
  const inviteNotification = (receiverEventNotifications.data?.data?.items || []).find((item) => item.type === 'event_invite');
  assert.ok(inviteNotification);
  assert.equal(inviteNotification.category, 'events');
  assert.match(String(inviteNotification.target?.href || ''), new RegExp(`/new/events\\?event=${eventId}&focus=response&notification=${inviteNotification.id}`));

  const respondAttend = await request(`/api/new/events/${eventId}/respond`, {
    method: 'POST',
    cookie: applicantCookie,
    body: { response: 'attend' }
  });
  assert.equal(respondAttend.res.status, 200);
  assert.equal(respondAttend.data?.ok, true);

  const reminderAudience = await request(`/api/new/events/${eventId}/notify`, {
    method: 'POST',
    cookie: posterCookie,
    body: { mode: 'reminder' }
  });
  assert.equal(reminderAudience.res.status, 200);
  assert.equal(Number(reminderAudience.data?.count || 0), 1);
  assert.equal(reminderAudience.data?.mode, 'reminder');

  const startsSoonAudience = await request(`/api/new/events/${eventId}/notify`, {
    method: 'POST',
    cookie: posterCookie,
    body: { mode: 'starts_soon' }
  });
  assert.equal(startsSoonAudience.res.status, 200);
  assert.equal(Number(startsSoonAudience.data?.count || 0), 1);
  assert.equal(startsSoonAudience.data?.mode, 'starts_soon');

  const applicantNotifications = await request('/api/new/notifications?limit=20&sort=priority', { cookie: applicantCookie });
  assert.equal(applicantNotifications.res.status, 200);
  const reminderNotification = (applicantNotifications.data?.data?.items || []).find((item) => item.type === 'event_reminder');
  const startsSoonNotification = (applicantNotifications.data?.data?.items || []).find((item) => item.type === 'event_starts_soon');
  assert.ok(reminderNotification);
  assert.ok(startsSoonNotification);
  assert.match(String(reminderNotification.target?.href || ''), new RegExp(`/new/events\\?event=${eventId}&focus=details&notification=${reminderNotification.id}`));
  assert.match(String(startsSoonNotification.target?.href || ''), new RegExp(`/new/events\\?event=${eventId}&focus=details&notification=${startsSoonNotification.id}`));

  const posterEventNotifications = await request('/api/new/notifications?limit=20&sort=priority', { cookie: posterCookie });
  assert.equal(posterEventNotifications.res.status, 200);
  const eventResponseNotification = (posterEventNotifications.data?.data?.items || []).find((item) => item.type === 'event_response');
  assert.ok(eventResponseNotification);
  assert.equal(eventResponseNotification.category, 'events');
  assert.match(String(eventResponseNotification.target?.href || ''), new RegExp(`/new/events\\?event=${eventId}&focus=response&notification=${eventResponseNotification.id}`));

  const posterCursorPage1 = await request('/api/new/notifications?limit=1&sort=priority', { cookie: posterCookie });
  assert.equal(posterCursorPage1.res.status, 200);
  assert.equal(Boolean(posterCursorPage1.data?.data?.hasMore), true);
  const nextCursor = String(posterCursorPage1.data?.data?.next_cursor || '').trim();
  assert.ok(nextCursor.length > 0);
  const page1Items = posterCursorPage1.data?.data?.items || [];
  assert.equal(page1Items.length, 1);
  const posterCursorPage2 = await request(`/api/new/notifications?limit=5&sort=priority&cursor=${encodeURIComponent(nextCursor)}`, { cookie: posterCookie });
  assert.equal(posterCursorPage2.res.status, 200);
  const page2Items = posterCursorPage2.data?.data?.items || [];
  assert.ok(page2Items.length >= 1);
  assert.equal(page2Items.some((item) => Number(item.id) === Number(page1Items[0]?.id || 0)), false);

  const teacherLink = await request(`/api/new/teachers/network/link/${teacherId}`, {
    method: 'POST',
    cookie: senderCookie,
    body: {
      relationship_type: 'mentor',
      created_via: 'manual_alumni_link',
      source_surface: 'teachers_network_page'
    }
  });
  assert.equal(teacherLink.res.status, 200);
  const teacherLinkId = Number(sqlGet('SELECT id FROM teacher_alumni_links WHERE alumni_user_id = ? AND teacher_user_id = ? ORDER BY id DESC LIMIT 1', [senderId, teacherId]).id);
  assert.ok(teacherLinkId > 0);

  const reviewTeacherLink = await request(`/api/new/admin/teacher-network/links/${teacherLinkId}/review`, {
    method: 'POST',
    cookie: adminCookie,
    body: { status: 'confirmed', review_note: 'Kayit dogrulandi.' }
  });
  assert.equal(reviewTeacherLink.res.status, 200);

  const senderNotifications = await request('/api/new/notifications?limit=20&offset=0', { cookie: senderCookie });
  assert.equal(senderNotifications.res.status, 200);
  const teacherReviewNotification = (senderNotifications.data?.data?.items || []).find((item) => item.type === 'teacher_link_review_confirmed');
  assert.ok(teacherReviewNotification);
  assert.equal(teacherReviewNotification.category, 'networking');
  assert.match(String(teacherReviewNotification.target?.href || ''), new RegExp(`/new/network/teachers\\?notification=${teacherReviewNotification.id}`));
  assert.match(String(teacherReviewNotification.target?.href || ''), new RegExp(`link=${teacherLinkId}`));
  assert.match(String(teacherReviewNotification.target?.href || ''), /review=confirmed/);

  sqlRun(
    `INSERT INTO group_invites (group_id, invited_user_id, invited_by, status, created_at)
     VALUES (?, ?, ?, 'pending', ?)`,
    [groupId, receiverId, senderId, new Date().toISOString()]
  );
  const acceptGroupInvite = await request(`/api/new/groups/${groupId}/invitations/respond`, {
    method: 'POST',
    cookie: receiverCookie,
    body: { action: 'accept' }
  });
  assert.equal(acceptGroupInvite.res.status, 200);

  const senderAfterAccept = await request('/api/new/notifications?limit=50&sort=priority', { cookie: senderCookie });
  assert.equal(senderAfterAccept.res.status, 200);
  const groupAcceptedNotification = (senderAfterAccept.data?.data?.items || []).find((item) => item.type === 'group_invite_accepted');
  assert.ok(groupAcceptedNotification);
  assert.match(String(groupAcceptedNotification.target?.href || ''), new RegExp(`/new/groups/${groupId}\\?tab=members&notification=${groupAcceptedNotification.id}`));

  sqlRun(
    `INSERT INTO group_invites (group_id, invited_user_id, invited_by, status, created_at)
     VALUES (?, ?, ?, 'pending', ?)`,
    [groupId, applicantId, senderId, new Date().toISOString()]
  );
  const rejectGroupInvite = await request(`/api/new/groups/${groupId}/invitations/respond`, {
    method: 'POST',
    cookie: applicantCookie,
    body: { action: 'reject' }
  });
  assert.equal(rejectGroupInvite.res.status, 200);

  const senderAfterReject = await request('/api/new/notifications?limit=50&sort=priority', { cookie: senderCookie });
  const groupRejectedNotification = (senderAfterReject.data?.data?.items || []).find((item) => item.type === 'group_invite_rejected');
  assert.ok(groupRejectedNotification);

  const roleChange = await request(`/api/new/groups/${groupId}/role`, {
    method: 'POST',
    cookie: senderCookie,
    body: { userId: receiverId, role: 'moderator' }
  });
  assert.equal(roleChange.res.status, 200);

  const receiverAfterRoleChange = await request('/api/new/notifications?limit=50&sort=priority', { cookie: receiverCookie });
  const roleChangedNotification = (receiverAfterRoleChange.data?.data?.items || []).find((item) => item.type === 'group_role_changed');
  assert.ok(roleChangedNotification);
  assert.match(String(roleChangedNotification.target?.href || ''), new RegExp(`/new/groups/${groupId}\\?tab=members&notification=${roleChangedNotification.id}`));

  sqlRun(
    `INSERT INTO verification_requests (user_id, status, proof_path, proof_image_record_id, created_at)
     VALUES (?, 'pending', '/proofs/receiver.pdf', 'proof-1', ?)`,
    [receiverId, new Date().toISOString()]
  );
  const verificationApprovedId = Number(sqlGet('SELECT id FROM verification_requests WHERE user_id = ? ORDER BY id DESC LIMIT 1', [receiverId]).id);
  const approveVerification = await request(`/api/new/admin/verification-requests/${verificationApprovedId}`, {
    method: 'POST',
    cookie: adminCookie,
    body: { status: 'approved' }
  });
  assert.equal(approveVerification.res.status, 200);

  sqlRun(
    `INSERT INTO verification_requests (user_id, status, proof_path, proof_image_record_id, created_at)
     VALUES (?, 'pending', '/proofs/applicant.pdf', 'proof-2', ?)`,
    [applicantId, new Date().toISOString()]
  );
  const verificationRejectedId = Number(sqlGet('SELECT id FROM verification_requests WHERE user_id = ? ORDER BY id DESC LIMIT 1', [applicantId]).id);
  const rejectVerification = await request(`/api/new/admin/verification-requests/${verificationRejectedId}`, {
    method: 'POST',
    cookie: adminCookie,
    body: { status: 'rejected' }
  });
  assert.equal(rejectVerification.res.status, 200);

  const receiverAfterVerification = await request('/api/new/notifications?limit=50&sort=priority', { cookie: receiverCookie });
  const verificationApprovedNotification = (receiverAfterVerification.data?.data?.items || []).find((item) => item.type === 'verification_approved');
  assert.ok(verificationApprovedNotification);
  assert.match(String(verificationApprovedNotification.target?.href || ''), /\/new\/profile\/verification\?notification=/);
  assert.match(String(verificationApprovedNotification.target?.href || ''), /status=approved/);

  const applicantAfterVerification = await request('/api/new/notifications?limit=50&sort=priority', { cookie: applicantCookie });
  const verificationRejectedNotification = (applicantAfterVerification.data?.data?.items || []).find((item) => item.type === 'verification_rejected');
  assert.ok(verificationRejectedNotification);
  assert.match(String(verificationRejectedNotification.target?.href || ''), /status=rejected/);

  sqlRun(
    `INSERT INTO member_requests (user_id, category_key, payload_json, status, created_at)
     VALUES (?, 'graduation_year_change', ?, 'pending', ?)`,
    [senderId, JSON.stringify({ requestedGraduationYear: '2011' }), new Date().toISOString()]
  );
  const memberRequestApprovedId = Number(sqlGet('SELECT id FROM member_requests WHERE user_id = ? ORDER BY id DESC LIMIT 1', [senderId]).id);
  const approveMemberRequest = await request(`/api/new/admin/requests/${memberRequestApprovedId}/review`, {
    method: 'POST',
    cookie: adminCookie,
    body: { status: 'approved', resolution_note: 'Cohort updated.' }
  });
  assert.equal(approveMemberRequest.res.status, 200);

  sqlRun(
    `INSERT INTO member_requests (user_id, category_key, payload_json, status, created_at)
     VALUES (?, 'graduation_year_change', ?, 'pending', ?)`,
    [posterId, JSON.stringify({ requestedGraduationYear: '2013' }), new Date().toISOString()]
  );
  const memberRequestRejectedId = Number(sqlGet('SELECT id FROM member_requests WHERE user_id = ? ORDER BY id DESC LIMIT 1', [posterId]).id);
  const rejectMemberRequest = await request(`/api/new/admin/requests/${memberRequestRejectedId}/review`, {
    method: 'POST',
    cookie: adminCookie,
    body: { status: 'rejected', resolution_note: 'Rejected for test.' }
  });
  assert.equal(rejectMemberRequest.res.status, 200);

  const senderAfterMemberRequest = await request('/api/new/notifications?limit=50&sort=priority', { cookie: senderCookie });
  const memberRequestApprovedNotification = (senderAfterMemberRequest.data?.data?.items || []).find((item) => item.type === 'member_request_approved');
  assert.ok(memberRequestApprovedNotification);
  assert.match(String(memberRequestApprovedNotification.target?.href || ''), /\/new\/requests\?/);
  assert.match(String(memberRequestApprovedNotification.target?.href || ''), new RegExp(`notification=${memberRequestApprovedNotification.id}`));
  assert.match(String(memberRequestApprovedNotification.target?.href || ''), new RegExp(`request=${memberRequestApprovedId}`));
  assert.match(String(memberRequestApprovedNotification.target?.href || ''), /status=approved/);

  const posterAfterMemberRequest = await request('/api/new/notifications?limit=50&sort=priority', { cookie: posterCookie });
  const memberRequestRejectedNotification = (posterAfterMemberRequest.data?.data?.items || []).find((item) => item.type === 'member_request_rejected');
  assert.ok(memberRequestRejectedNotification);
  assert.match(String(memberRequestRejectedNotification.target?.href || ''), /status=rejected/);

  sqlRun(
    `INSERT INTO announcements (title, body, image, created_at, created_by, approved, approved_by, approved_at)
     VALUES (?, ?, ?, ?, ?, 0, NULL, NULL)`,
    ['Pending approval', '<p>Announcement body</p>', null, new Date().toISOString(), posterId]
  );
  const announcementApprovedId = Number(sqlGet('SELECT id FROM announcements WHERE created_by = ? ORDER BY id DESC LIMIT 1', [posterId]).id);
  const approveAnnouncement = await request(`/api/new/announcements/${announcementApprovedId}/approve`, {
    method: 'POST',
    cookie: adminCookie,
    body: { approved: 1 }
  });
  assert.equal(approveAnnouncement.res.status, 200);

  sqlRun(
    `INSERT INTO announcements (title, body, image, created_at, created_by, approved, approved_by, approved_at)
     VALUES (?, ?, ?, ?, ?, 0, NULL, NULL)`,
    ['Pending rejection', '<p>Announcement body</p>', null, new Date().toISOString(), senderId]
  );
  const announcementRejectedId = Number(sqlGet('SELECT id FROM announcements WHERE created_by = ? ORDER BY id DESC LIMIT 1', [senderId]).id);
  const rejectAnnouncement = await request(`/api/new/announcements/${announcementRejectedId}/approve`, {
    method: 'POST',
    cookie: adminCookie,
    body: { approved: 0 }
  });
  assert.equal(rejectAnnouncement.res.status, 200);

  const posterAfterAnnouncement = await request('/api/new/notifications?limit=50&sort=priority', { cookie: posterCookie });
  const announcementApprovedNotification = (posterAfterAnnouncement.data?.data?.items || []).find((item) => item.type === 'announcement_approved');
  assert.ok(announcementApprovedNotification);
  assert.match(String(announcementApprovedNotification.target?.href || ''), /\/new\/announcements\?/);
  assert.match(String(announcementApprovedNotification.target?.href || ''), new RegExp(`notification=${announcementApprovedNotification.id}`));
  assert.match(String(announcementApprovedNotification.target?.href || ''), new RegExp(`announcement=${announcementApprovedId}`));
  assert.match(String(announcementApprovedNotification.target?.href || ''), /status=approved/);

  const senderAfterAnnouncement = await request('/api/new/notifications?limit=100&sort=priority', { cookie: senderCookie });
  const announcementRejectedNotification = (senderAfterAnnouncement.data?.data?.items || []).find((item) => item.type === 'announcement_rejected')
    || sqlGet(`SELECT id, type, entity_id, message FROM notifications WHERE user_id = ? AND type = 'announcement_rejected' ORDER BY id DESC LIMIT 1`, [senderId]);
  assert.ok(announcementRejectedNotification);
  if (announcementRejectedNotification.target?.href) {
    assert.match(String(announcementRejectedNotification.target?.href || ''), /status=rejected/);
  }

  const telemetry = await request('/api/new/notifications/telemetry', {
    method: 'POST',
    cookie: senderCookie,
    body: {
      events: [
        {
          notification_id: teacherReviewNotification.id,
          event_name: 'impression',
          notification_type: teacherReviewNotification.type,
          surface: 'notifications_page'
        },
        {
          notification_id: teacherReviewNotification.id,
          event_name: 'action',
          notification_type: teacherReviewNotification.type,
          surface: 'notification_panel',
          action_kind: 'open'
        },
        {
          notification_id: teacherReviewNotification.id,
          event_name: 'landed',
          notification_type: teacherReviewNotification.type,
          surface: 'teachers_network_page',
          action_kind: 'resolved'
        }
      ]
    }
  });
  assert.equal(telemetry.res.status, 200);
  assert.equal(Number(telemetry.data?.data?.accepted_count || 0), 3);
  const telemetryCount = Number(sqlGet('SELECT COUNT(*) AS cnt FROM notification_telemetry_events WHERE user_id = ?', [senderId]).cnt || 0);
  assert.ok(telemetryCount >= 3);
  const ops = await request('/api/new/admin/notifications/ops?window=30d', { cookie: adminCookie });
  assert.equal(ops.res.status, 200);
  assert.equal(Array.isArray(ops.data?.data?.delivery_by_type), true);
  assert.equal(ops.data?.data?.delivery_by_type.some((item) => item.type === 'group_invite_accepted'), true);
  assert.equal(Array.isArray(ops.data?.data?.surface_conversion), true);
  assert.equal(Number(ops.data?.data?.quiet_mode_enabled_users || 0) >= 1, true);
  const deliveryAuditCount = Number(sqlGet('SELECT COUNT(*) AS cnt FROM notification_delivery_audit WHERE notification_type IN (?, ?, ?, ?, ?, ?, ?)', ['connection_request', 'job_application', 'teacher_link_review_confirmed', 'event_invite', 'event_response', 'event_reminder', 'event_starts_soon']).cnt || 0);
  assert.ok(deliveryAuditCount >= 7);

  console.log('phase2 notifications tests passed');
} finally {
  await new Promise((resolve) => server.close(resolve));
}
