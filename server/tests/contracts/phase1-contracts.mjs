import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import Database from 'better-sqlite3';

const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'sdal-phase1-contracts-'));
const bootstrapPath = path.join(tmpDir, 'bootstrap.sqlite');
const runtimeDbPath = path.join(tmpDir, 'runtime.sqlite');

const sourceDb = path.resolve(process.cwd(), '../db/sdal.sqlite');
fs.copyFileSync(sourceDb, bootstrapPath);

const bootstrapDb = new Database(bootstrapPath);
bootstrapDb.exec(`
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
`);
const compatibilityColumns = [
  "ALTER TABLE uyeler ADD COLUMN role TEXT DEFAULT 'user';",
  "ALTER TABLE uyeler ADD COLUMN verified INTEGER DEFAULT 0;",
  "ALTER TABLE uyeler ADD COLUMN verification_status TEXT DEFAULT 'pending';"
];
for (const sql of compatibilityColumns) {
  try {
    bootstrapDb.exec(sql);
  } catch {
    // column already exists
  }
}

const postsCompatibilityColumns = [
  "ALTER TABLE posts ADD COLUMN group_id INTEGER;",
  "ALTER TABLE posts ADD COLUMN image_record_id TEXT;"
];
for (const sql of postsCompatibilityColumns) {
  try {
    bootstrapDb.exec(sql);
  } catch {
    // column already exists
  }
}
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
  CREATE TABLE IF NOT EXISTS groups (
    id INTEGER PRIMARY KEY,
    name TEXT,
    description TEXT,
    owner_id INTEGER,
    cover_image TEXT,
    visibility TEXT,
    created_at TEXT
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
  CREATE TABLE IF NOT EXISTS engagement_ab_assignments (
    user_id INTEGER PRIMARY KEY,
    variant TEXT,
    assigned_at TEXT,
    updated_at TEXT
  );
  CREATE TABLE IF NOT EXISTS moderator_permissions (
    id INTEGER PRIMARY KEY,
    user_id INTEGER NOT NULL,
    permission_key TEXT NOT NULL,
    enabled INTEGER NOT NULL DEFAULT 1,
    created_by INTEGER,
    updated_by INTEGER,
    created_at TEXT,
    updated_at TEXT
  );
  CREATE UNIQUE INDEX IF NOT EXISTS moderator_permissions_unique_idx ON moderator_permissions(user_id, permission_key);
  CREATE TABLE IF NOT EXISTS moderator_scopes (
    id INTEGER PRIMARY KEY,
    user_id INTEGER NOT NULL,
    scope_type TEXT NOT NULL DEFAULT 'graduation_year',
    scope_value TEXT NOT NULL,
    graduation_year INTEGER,
    created_by INTEGER,
    created_at TEXT
  );
  CREATE UNIQUE INDEX IF NOT EXISTS moderator_scopes_unique_idx ON moderator_scopes(user_id, scope_type, scope_value);
  CREATE TABLE IF NOT EXISTS audit_log (
    id INTEGER PRIMARY KEY,
    actor_user_id INTEGER,
    action TEXT NOT NULL,
    target_type TEXT,
    target_id TEXT,
    metadata TEXT,
    ip TEXT,
    user_agent TEXT,
    created_at TEXT
  );
`);
const nowTs = new Date().toISOString();
bootstrapDb
  .prepare('INSERT OR IGNORE INTO site_controls (id, site_open, maintenance_message, updated_at) VALUES (1, 1, ?, ?)')
  .run('Site geçici bakım modundadır. Lütfen daha sonra tekrar deneyin.', nowTs);
const moduleKeys = [
  'feed', 'main_feed', 'explore', 'following', 'groups', 'messages', 'messenger', 'notifications',
  'albums', 'games', 'events', 'announcements', 'jobs', 'profile', 'help', 'requests', 'year_feed'
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
process.env.SDAL_SESSION_SECRET = 'phase1-contract-secret';
process.env.SDAL_ADMIN_PASSWORD = 'AdminPanel!123';
process.env.ROOT_BOOTSTRAP_PASSWORD = 'RootPass!123';
process.env.MAIL_ALLOW_MOCK = 'true';
process.env.SDAL_LEGACY_ROOT_DIR = tmpDir;

const snapshotPath = path.resolve(process.cwd(), 'tests/fixtures/phase1-contract-snapshot.json');
const snapshot = JSON.parse(fs.readFileSync(snapshotPath, 'utf8'));

const { default: app, onServerStarted } = await import('../../app.js');
const { sqlRun, sqlGet } = await import('../../db.js');

await onServerStarted();

function seedUser({ username, password, role = 'user', admin = 0, graduationYear = '2011' }) {
  const now = new Date().toISOString();
  sqlRun(
    `INSERT INTO uyeler (kadi, sifre, email, isim, soyisim, aktivasyon, aktiv, ilktarih, mezuniyetyili, ilkbd, admin, role, verified, verification_status)
     VALUES (?, ?, ?, ?, ?, ?, 1, ?, ?, 1, ?, ?, 1, 'approved')`,
    [username, password, `${username}@example.com`, username, 'Contract', `${username}-act`, now, graduationYear, admin, role]
  );
  const id = sqlGet('SELECT id FROM uyeler WHERE kadi = ?', [username]).id;
  try {
    sqlRun(
      `INSERT OR REPLACE INTO users (id, username, password_hash, email, first_name, last_name, graduation_year, is_active, is_verified, role, created_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, 1, 1, ?, ?)`,
      [id, username, password, `${username}@example.com`, username, 'Contract', Number(graduationYear) || null, role, now]
    );
  } catch {
    // users table may not exist in legacy-only test DB.
  }
  return id;
}

const adminUserId = seedUser({ username: 'admin1', password: 'adminpass', role: 'admin', admin: 1, graduationYear: '2010' });
const userId = seedUser({ username: 'user1', password: 'userpass', role: 'user', admin: 0, graduationYear: '2011' });

const server = app.listen(0);
await new Promise((resolve, reject) => {
  server.once('listening', resolve);
  server.once('error', reject);
});
const baseUrl = `http://127.0.0.1:${server.address().port}`;

function sortedKeys(obj) {
  return Object.keys(obj || {}).sort((a, b) => a.localeCompare(b));
}

async function login(username, password) {
  const resp = await fetch(`${baseUrl}/api/auth/login`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ kadi: username, sifre: password })
  });
  const body = await resp.json();
  const setCookieValues = typeof resp.headers.getSetCookie === 'function'
    ? resp.headers.getSetCookie()
    : (resp.headers.get('set-cookie') ? [resp.headers.get('set-cookie')] : []);
  const cookie = setCookieValues
    .map((entry) => String(entry || '').split(';')[0])
    .filter(Boolean)
    .join('; ');
  return { resp, body, cookie };
}

async function requestJson(pathname, { method = 'GET', cookie = '', body = null } = {}) {
  const resp = await fetch(`${baseUrl}${pathname}`, {
    method,
    headers: {
      ...(cookie ? { cookie } : {}),
      ...(body ? { 'content-type': 'application/json' } : {})
    },
    body: body ? JSON.stringify(body) : undefined
  });

  let json = null;
  const text = await resp.text();
  if (text) {
    try {
      json = JSON.parse(text);
    } catch {
      json = text;
    }
  }

  return { resp, json };
}

try {
  const userLogin = await login('user1', 'userpass');
  assert.equal(userLogin.resp.status, snapshot.authLogin.status, 'auth login status mismatch');
  assert.deepEqual(sortedKeys(userLogin.body), [...snapshot.authLogin.bodyKeys].sort(), 'auth login body keys mismatch');
  assert.deepEqual(sortedKeys(userLogin.body.user), [...snapshot.authLogin.userKeys].sort(), 'auth login user keys mismatch');

  const postCreate = await requestJson('/api/new/posts', {
    method: 'POST',
    cookie: userLogin.cookie,
    body: { content: 'phase1 contract post body' }
  });
  assert.equal(postCreate.resp.status, snapshot.createPost.status, 'create post status mismatch');
  for (const [key, value] of Object.entries(snapshot.createPost.requiredBody)) {
    assert.equal(postCreate.json?.[key], value, `create post expected ${key}`);
  }
  for (const key of snapshot.createPost.requiredKeys) {
    assert.ok(Object.prototype.hasOwnProperty.call(postCreate.json || {}, key), `create post missing key ${key}`);
  }

  const createdPostId = Number(postCreate.json?.id || 0);
  assert.ok(createdPostId > 0, 'create post did not return id');

  const feed = await requestJson('/api/new/feed?limit=20&offset=0', {
    cookie: userLogin.cookie
  });
  assert.equal(feed.resp.status, snapshot.feed.status, 'feed status mismatch');
  assert.deepEqual(sortedKeys(feed.json), [...snapshot.feed.bodyKeys].sort(), 'feed body keys mismatch');
  assert.ok(Array.isArray(feed.json?.items), 'feed items must be array');
  const firstFeedItem = feed.json.items[0] || {};
  assert.deepEqual(sortedKeys(firstFeedItem), [...snapshot.feed.itemKeys].sort(), 'feed item keys mismatch');
  assert.deepEqual(sortedKeys(firstFeedItem.author || {}), [...snapshot.feed.authorKeys].sort(), 'feed author keys mismatch');


  const now = new Date().toISOString();
  sqlRun('INSERT INTO groups (name, description, owner_id, created_at) VALUES (?, ?, ?, ?)', [
    '2011 Mezunları',
    'phase1 contracts cohort',
    userId,
    now
  ]);
  const cohortGroup = sqlGet('SELECT id FROM groups WHERE name = ? ORDER BY id DESC LIMIT 1', ['2011 Mezunları']);
  assert.ok(Number(cohortGroup?.id || 0) > 0, 'cohort group should exist for year mode test');
  sqlRun('INSERT INTO posts (user_id, content, group_id, created_at) VALUES (?, ?, ?, ?)', [
    userId,
    'phase1 cohort feed post',
    cohortGroup.id,
    now
  ]);

  const yearFeed = await requestJson('/api/new/feed?mode=year&limit=10', {
    cookie: userLogin.cookie
  });
  assert.equal(yearFeed.resp.status, 200, 'year mode feed status mismatch');
  assert.ok(Array.isArray(yearFeed.json?.items), 'year mode feed items must be array');

  const commentCreate = await requestJson(`/api/new/posts/${createdPostId}/comments`, {
    method: 'POST',
    cookie: userLogin.cookie,
    body: { comment: 'phase1 contract comment' }
  });
  assert.equal(commentCreate.resp.status, snapshot.commentCreate.status, 'comment create status mismatch');
  for (const [key, value] of Object.entries(snapshot.commentCreate.requiredBody)) {
    assert.equal(commentCreate.json?.[key], value, `comment create expected ${key}`);
  }

  const chatSend = await requestJson('/api/new/chat/send', {
    method: 'POST',
    cookie: userLogin.cookie,
    body: { message: 'phase1 contract chat message' }
  });
  assert.equal(chatSend.resp.status, snapshot.chatSend.status, 'chat send status mismatch');
  for (const [key, value] of Object.entries(snapshot.chatSend.requiredBody)) {
    assert.equal(chatSend.json?.[key], value, `chat send expected ${key}`);
  }
  assert.deepEqual(sortedKeys(chatSend.json?.item || {}), [...snapshot.chatSend.itemKeys].sort(), 'chat send item keys mismatch');

  const chatList = await requestJson('/api/new/chat/messages?limit=20', {
    cookie: userLogin.cookie
  });
  assert.equal(chatList.resp.status, snapshot.chatList.status, 'chat list status mismatch');
  assert.deepEqual(sortedKeys(chatList.json || {}), [...snapshot.chatList.bodyKeys].sort(), 'chat list body keys mismatch');
  assert.ok(Array.isArray(chatList.json?.items), 'chat list items must be array');

  const rootLogin = await login('root', 'RootPass!123');
  assert.equal(rootLogin.resp.status, 200, 'root login failed');

  const legacyDashboardSummary = await requestJson('/api/new/admin/stats', {
    cookie: rootLogin.cookie
  });
  assert.equal(legacyDashboardSummary.resp.status, 200, 'legacy dashboard summary status mismatch');

  const dashboardSummary = await requestJson('/api/admin/dashboard/summary', {
    cookie: rootLogin.cookie
  });
  assert.equal(dashboardSummary.resp.status, 200, 'dashboard summary status mismatch');
  assert.deepEqual(
    sortedKeys(dashboardSummary.json || {}),
    sortedKeys(legacyDashboardSummary.json || {}),
    'dashboard summary shape mismatch against legacy endpoint'
  );

  const legacyDashboardActivity = await requestJson('/api/new/admin/live', {
    cookie: rootLogin.cookie
  });
  assert.equal(legacyDashboardActivity.resp.status, 200, 'legacy dashboard activity status mismatch');

  const dashboardActivity = await requestJson('/api/admin/dashboard/activity', {
    cookie: rootLogin.cookie
  });
  assert.equal(dashboardActivity.resp.status, 200, 'dashboard activity status mismatch');
  assert.deepEqual(
    sortedKeys(dashboardActivity.json || {}),
    sortedKeys(legacyDashboardActivity.json || {}),
    'dashboard activity shape mismatch against legacy endpoint'
  );

  const roleUpdate = await requestJson(`/admin/users/${adminUserId}/role`, {
    method: 'POST',
    cookie: rootLogin.cookie,
    body: { role: 'mod' }
  });
  assert.equal(roleUpdate.resp.status, snapshot.adminRoleUpdate.status, 'admin role update status mismatch');
  for (const [key, value] of Object.entries(snapshot.adminRoleUpdate.requiredBody)) {
    assert.equal(roleUpdate.json?.[key], value, `admin role update expected ${key}`);
  }
  for (const key of snapshot.adminRoleUpdate.requiredKeys) {
    assert.ok(Object.prototype.hasOwnProperty.call(roleUpdate.json || {}, key), `admin role update missing key ${key}`);
  }

  console.log('phase1 contract tests passed');
} finally {
  server.close();
}

process.exit(0);
