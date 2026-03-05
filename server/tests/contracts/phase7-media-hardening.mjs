import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import Database from 'better-sqlite3';

const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'sdal-phase7-media-'));
const bootstrapPath = path.join(tmpDir, 'bootstrap.sqlite');
const runtimeDbPath = path.join(tmpDir, 'runtime.sqlite');

const sourceDb = path.resolve(process.cwd(), '../db/sdal.sqlite');
fs.copyFileSync(sourceDb, bootstrapPath);

const bootstrapDb = new Database(bootstrapPath);
const compatibilityColumns = [
  "ALTER TABLE uyeler ADD COLUMN role TEXT DEFAULT 'user';",
  "ALTER TABLE uyeler ADD COLUMN verified INTEGER DEFAULT 0;",
  "ALTER TABLE uyeler ADD COLUMN verification_status TEXT DEFAULT 'pending';"
];
for (const sql of compatibilityColumns) {
  try {
    bootstrapDb.exec(sql);
  } catch {
    // already exists
  }
}

bootstrapDb.exec(`
  CREATE TABLE IF NOT EXISTS posts (
    id INTEGER PRIMARY KEY,
    user_id INTEGER,
    content TEXT,
    image TEXT,
    image_record_id TEXT,
    group_id INTEGER,
    created_at TEXT
  );
  CREATE TABLE IF NOT EXISTS post_comments (
    id INTEGER PRIMARY KEY,
    post_id INTEGER,
    user_id INTEGER,
    comment TEXT,
    created_at TEXT
  );
  CREATE TABLE IF NOT EXISTS post_likes (
    id INTEGER PRIMARY KEY,
    post_id INTEGER,
    user_id INTEGER,
    created_at TEXT
  );
  CREATE TABLE IF NOT EXISTS follows (
    id INTEGER PRIMARY KEY,
    follower_id INTEGER,
    following_id INTEGER,
    created_at TEXT
  );
  CREATE TABLE IF NOT EXISTS chat_messages (
    id INTEGER PRIMARY KEY,
    user_id INTEGER,
    message TEXT,
    created_at TEXT
  );
  CREATE TABLE IF NOT EXISTS notifications (
    id INTEGER PRIMARY KEY,
    user_id INTEGER,
    type TEXT,
    source_user_id INTEGER,
    entity_id INTEGER,
    message TEXT,
    read_at TEXT,
    created_at TEXT
  );
  CREATE TABLE IF NOT EXISTS image_records (
    id TEXT PRIMARY KEY,
    user_id INTEGER,
    entity_type TEXT,
    entity_id TEXT,
    provider TEXT,
    thumb_path TEXT,
    feed_path TEXT,
    full_path TEXT,
    width INTEGER,
    height INTEGER,
    created_at TEXT
  );
  CREATE TABLE IF NOT EXISTS verification_requests (
    id INTEGER PRIMARY KEY,
    user_id INTEGER,
    status TEXT,
    proof_path TEXT,
    proof_image_record_id TEXT,
    created_at TEXT,
    reviewed_at TEXT,
    reviewer_id INTEGER
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
const moduleKeys = [
  'feed', 'main_feed', 'explore', 'following', 'groups', 'messages', 'messenger', 'notifications',
  'albums', 'games', 'events', 'announcements', 'jobs', 'profile', 'help', 'requests'
];
for (const moduleKey of moduleKeys) {
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
process.env.SDAL_SESSION_SECRET = 'phase7-media-secret';
process.env.SDAL_ADMIN_PASSWORD = 'AdminPanel!123';
process.env.ROOT_BOOTSTRAP_PASSWORD = 'RootPass!123';
process.env.MAIL_ALLOW_MOCK = 'true';
process.env.SDAL_LEGACY_ROOT_DIR = tmpDir;
process.env.SDAL_UPLOADS_DIR = path.join(tmpDir, 'uploads');
process.env.REDIS_URL = '';
process.env.UPLOAD_QUOTA_MAX_FILES = '1';
process.env.UPLOAD_QUOTA_MAX_BYTES = '500000';
process.env.UPLOAD_QUOTA_WINDOW_SECONDS = '3600';

const { default: app, onServerStarted } = await import('../../app.js');
const { sqlRun, sqlGet } = await import('../../db.js');

await onServerStarted();

function seedUser({ username, password }) {
  const now = new Date().toISOString();
  sqlRun(
    `INSERT INTO uyeler (kadi, sifre, email, isim, soyisim, aktivasyon, aktiv, ilktarih, mezuniyetyili, ilkbd, admin, role, verified, verification_status)
     VALUES (?, ?, ?, ?, ?, ?, 1, ?, ?, 1, 0, 'user', 1, 'approved')`,
    [username, password, `${username}@example.com`, username, 'Media', `${username}-act`, now, '2011']
  );
  return sqlGet('SELECT id FROM uyeler WHERE kadi = ?', [username]).id;
}

seedUser({ username: 'phase7_user_a', password: 'phase7-pass-a' });
seedUser({ username: 'phase7_user_b', password: 'phase7-pass-b' });

const server = app.listen(0, '127.0.0.1');
await new Promise((resolve, reject) => {
  server.once('listening', resolve);
  server.once('error', reject);
});

const baseUrl = `http://127.0.0.1:${server.address().port}`;

async function request(pathname, { method = 'GET', cookie = '', body = null, headers = {} } = {}) {
  const resp = await fetch(`${baseUrl}${pathname}`, {
    method,
    headers: {
      ...(cookie ? { cookie } : {}),
      ...headers
    },
    body
  });

  const text = await resp.text();
  let data = null;
  if (text) {
    try {
      data = JSON.parse(text);
    } catch {
      data = text;
    }
  }

  return { resp, data };
}

async function login(username, password) {
  const result = await request('/api/auth/login', {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ kadi: username, sifre: password })
  });

  const setCookieValues = typeof result.resp.headers.getSetCookie === 'function'
    ? result.resp.headers.getSetCookie()
    : (result.resp.headers.get('set-cookie') ? [result.resp.headers.get('set-cookie')] : []);

  const cookie = setCookieValues
    .map((entry) => String(entry || '').split(';')[0])
    .filter(Boolean)
    .join('; ');

  return { ...result, cookie };
}

const tinyPngBase64 = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO5WfL8AAAAASUVORK5CYII=';

try {
  const loginA = await login('phase7_user_a', 'phase7-pass-a');
  const loginB = await login('phase7_user_b', 'phase7-pass-b');
  assert.equal(loginA.resp.status, 200, 'user A login should succeed');
  assert.equal(loginB.resp.status, 200, 'user B login should succeed');

  const validBuffer = Buffer.from(tinyPngBase64, 'base64');

  const firstUploadForm = new FormData();
  firstUploadForm.set('entityType', 'post');
  firstUploadForm.set('entityId', '1');
  firstUploadForm.set('image', new Blob([validBuffer], { type: 'image/png' }), 'ok.png');

  const upload1 = await request('/api/upload-image', {
    method: 'POST',
    cookie: loginA.cookie,
    body: firstUploadForm
  });
  assert.equal(upload1.resp.status, 200, 'first upload should succeed');
  assert.equal(typeof upload1.data?.imageId, 'string', 'first upload should return imageId');

  const secondUploadForm = new FormData();
  secondUploadForm.set('entityType', 'post');
  secondUploadForm.set('entityId', '2');
  secondUploadForm.set('image', new Blob([validBuffer], { type: 'image/png' }), 'ok2.png');

  const upload2 = await request('/api/upload-image', {
    method: 'POST',
    cookie: loginA.cookie,
    body: secondUploadForm
  });
  assert.equal(upload2.resp.status, 429, 'second upload should hit quota limit');

  const invalidImageForm = new FormData();
  invalidImageForm.set('content', 'invalid upload should fail');
  invalidImageForm.set('image', new Blob([Buffer.from('not-an-image', 'utf8')], { type: 'image/jpeg' }), 'fake.jpg');

  const invalidUpload = await request('/api/new/posts/upload', {
    method: 'POST',
    cookie: loginB.cookie,
    body: invalidImageForm
  });

  assert.equal(invalidUpload.resp.status, 400, 'invalid image payload should be rejected');
  assert.ok(String(invalidUpload.data || '').toLowerCase().includes('eşleşmiyor') || String(invalidUpload.data || '').toLowerCase().includes('desteklenmeyen'), 'invalid image should fail content validation');

  console.log('phase7 media hardening tests passed');
} finally {
  server.close();
}

process.exit(0);
