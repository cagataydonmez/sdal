import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import Database from 'better-sqlite3';

const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'sdal-phase5-perf-'));
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
    // column may already exist
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
  CREATE TABLE IF NOT EXISTS group_invites (
    id INTEGER PRIMARY KEY,
    group_id INTEGER,
    invited_user_id INTEGER,
    invited_by INTEGER,
    status TEXT,
    created_at TEXT,
    responded_at TEXT
  );
  CREATE TABLE IF NOT EXISTS chat_messages (
    id INTEGER PRIMARY KEY,
    user_id INTEGER,
    message TEXT,
    created_at TEXT
  );
  CREATE TABLE IF NOT EXISTS member_engagement_scores (
    user_id INTEGER PRIMARY KEY,
    score REAL DEFAULT 0,
    updated_at TEXT
  );
  CREATE TABLE IF NOT EXISTS request_categories (
    id INTEGER PRIMARY KEY,
    category_key TEXT UNIQUE,
    label TEXT,
    description TEXT,
    active INTEGER DEFAULT 1,
    created_at TEXT,
    updated_at TEXT
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
process.env.SDAL_SESSION_SECRET = 'phase5-perf-secret';
process.env.SDAL_ADMIN_PASSWORD = 'AdminPanel!123';
process.env.ROOT_BOOTSTRAP_PASSWORD = 'RootPass!123';
process.env.MAIL_ALLOW_MOCK = 'true';
process.env.SDAL_LEGACY_ROOT_DIR = tmpDir;
process.env.REDIS_URL = '';
process.env.RATE_LIMIT_LOGIN_MAX = '2';
process.env.RATE_LIMIT_LOGIN_WINDOW_SECONDS = '60';
process.env.RATE_LIMIT_CHAT_SEND_MAX = '2';
process.env.RATE_LIMIT_CHAT_SEND_WINDOW_SECONDS = '60';

const { default: app, onServerStarted } = await import('../../app.js');
const { sqlRun, sqlGet } = await import('../../db.js');

await onServerStarted();

function seedUser({ username, password, role = 'user', admin = 0 }) {
  const now = new Date().toISOString();
  sqlRun(
    `INSERT INTO uyeler (kadi, sifre, email, isim, soyisim, aktivasyon, aktiv, ilktarih, mezuniyetyili, ilkbd, admin, role, verified, verification_status)
     VALUES (?, ?, ?, ?, ?, ?, 1, ?, ?, 1, ?, ?, 1, 'approved')`,
    [username, password, `${username}@example.com`, username, 'Perf', `${username}-act`, now, '2011', admin, role]
  );
  return sqlGet('SELECT id FROM uyeler WHERE kadi = ?', [username]).id;
}

seedUser({ username: 'perf_user', password: 'correct-pass' });
seedUser({ username: 'perf_other', password: 'other-pass' });

const server = app.listen(0, '127.0.0.1');
await new Promise((resolve, reject) => {
  server.once('listening', resolve);
  server.once('error', reject);
});
const baseUrl = `http://127.0.0.1:${server.address().port}`;

async function request(pathname, { method = 'GET', cookie = '', body = null } = {}) {
  const resp = await fetch(`${baseUrl}${pathname}`, {
    method,
    headers: {
      ...(cookie ? { cookie } : {}),
      ...(body ? { 'content-type': 'application/json' } : {})
    },
    body: body ? JSON.stringify(body) : undefined
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
    body: { kadi: username, sifre: password }
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

try {
  const bad1 = await login('perf_user', 'wrong-pass');
  const bad2 = await login('perf_user', 'wrong-pass');
  const bad3 = await login('perf_user', 'wrong-pass');
  assert.equal(bad1.resp.status, 400, 'first bad login should fail with 400');
  assert.equal(bad2.resp.status, 400, 'second bad login should fail with 400');
  assert.equal(bad3.resp.status, 429, 'third bad login should be rate limited');

  const goodLogin = await login('perf_other', 'other-pass');
  assert.equal(goodLogin.resp.status, 200, 'independent user login should still work');
  const cookie = goodLogin.cookie;

  for (let i = 0; i < 3; i += 1) {
    const createPost = await request('/api/new/posts', {
      method: 'POST',
      cookie,
      body: { content: `phase5-post-${i}` }
    });
    assert.equal(createPost.resp.status, 200, 'post create should succeed');
  }

  const feed1 = await request('/api/new/feed?limit=2&offset=0', { cookie });
  assert.equal(feed1.resp.status, 200, 'feed page 1 should succeed');
  assert.ok(Array.isArray(feed1.data?.items), 'feed items should be array');
  assert.ok(feed1.data.items.length >= 2, 'feed should return at least 2 items');

  const cursor = Number(feed1.data.items[feed1.data.items.length - 1]?.id || 0);
  assert.ok(cursor > 0, 'feed cursor candidate should be > 0');

  const feed2 = await request(`/api/new/feed?limit=2&cursor=${cursor}`, { cookie });
  assert.equal(feed2.resp.status, 200, 'feed cursor page should succeed');
  assert.ok(Array.isArray(feed2.data?.items), 'feed cursor items should be array');

  const postId = Number(feed1.data.items[0]?.id || 0);
  assert.ok(postId > 0, 'post id should exist for comment tests');

  const c1 = await request(`/api/new/posts/${postId}/comments`, {
    method: 'POST',
    cookie,
    body: { comment: 'perf comment one' }
  });
  const c2 = await request(`/api/new/posts/${postId}/comments`, {
    method: 'POST',
    cookie,
    body: { comment: 'perf comment two' }
  });
  assert.equal(c1.resp.status, 200, 'comment 1 should succeed');
  assert.equal(c2.resp.status, 200, 'comment 2 should succeed');

  const chat1 = await request('/api/new/chat/send', {
    method: 'POST',
    cookie,
    body: { message: 'perf chat one' }
  });
  const chat2 = await request('/api/new/chat/send', {
    method: 'POST',
    cookie,
    body: { message: 'perf chat two' }
  });
  const chat3 = await request('/api/new/chat/send', {
    method: 'POST',
    cookie,
    body: { message: 'perf chat three' }
  });

  assert.equal(chat1.resp.status, 200, 'chat send 1 should succeed');
  assert.equal(chat2.resp.status, 200, 'chat send 2 should succeed');
  assert.equal(chat3.resp.status, 429, 'chat send 3 should be rate limited');

  console.log('phase5 performance tests passed');
} finally {
  server.close();
}

process.exit(0);
