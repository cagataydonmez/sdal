import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import Database from 'better-sqlite3';
import WebSocket from 'ws';

const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'sdal-phase6-'));
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
  CREATE TABLE IF NOT EXISTS sdal_messenger_threads (
    id INTEGER PRIMARY KEY,
    user_a_id INTEGER NOT NULL,
    user_b_id INTEGER NOT NULL,
    created_at TEXT,
    updated_at TEXT,
    last_message_at TEXT
  );
  CREATE TABLE IF NOT EXISTS sdal_messenger_messages (
    id INTEGER PRIMARY KEY,
    thread_id INTEGER NOT NULL,
    sender_id INTEGER NOT NULL,
    receiver_id INTEGER NOT NULL,
    body TEXT NOT NULL,
    client_written_at TEXT,
    server_received_at TEXT,
    delivered_at TEXT,
    created_at TEXT,
    read_at TEXT,
    deleted_by_sender INTEGER DEFAULT 0,
    deleted_by_receiver INTEGER DEFAULT 0
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
process.env.SDAL_SESSION_SECRET = 'phase6-secret';
process.env.SDAL_ADMIN_PASSWORD = 'AdminPanel!123';
process.env.ROOT_BOOTSTRAP_PASSWORD = 'RootPass!123';
process.env.MAIL_ALLOW_MOCK = 'true';
process.env.SDAL_LEGACY_ROOT_DIR = tmpDir;
process.env.REDIS_URL = '';
process.env.JOB_INLINE_WORKER = 'true';

const { default: app, onServerStarted, attachWebSocketServers } = await import('../../app.js');
const { sqlRun, sqlGet } = await import('../../db.js');

await onServerStarted();

function seedUser({ username, password, role = 'user', admin = 0 }) {
  const now = new Date().toISOString();
  sqlRun(
    `INSERT INTO uyeler (kadi, sifre, email, isim, soyisim, aktivasyon, aktiv, ilktarih, mezuniyetyili, ilkbd, admin, role, verified, verification_status)
     VALUES (?, ?, ?, ?, ?, ?, 1, ?, ?, 1, ?, ?, 1, 'approved')`,
    [username, password, `${username}@example.com`, username, 'Phase6', `${username}-act`, now, '2011', admin, role]
  );
  return sqlGet('SELECT id FROM uyeler WHERE kadi = ?', [username]).id;
}

const userAId = seedUser({ username: 'phase6_user_a', password: 'phase6-pass-a' });
const userBId = seedUser({ username: 'phase6_user_b', password: 'phase6-pass-b' });

const server = app.listen(0, '127.0.0.1');
await new Promise((resolve, reject) => {
  server.once('listening', resolve);
  server.once('error', reject);
});
attachWebSocketServers(server);

const baseUrl = `http://127.0.0.1:${server.address().port}`;
const wsBase = `ws://127.0.0.1:${server.address().port}`;

async function request(pathname, { method = 'GET', cookie = '', body = null, headers = {} } = {}) {
  const resp = await fetch(`${baseUrl}${pathname}`, {
    method,
    headers: {
      ...(cookie ? { cookie } : {}),
      ...(body ? { 'content-type': 'application/json' } : {}),
      ...headers
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

function waitForWsClose(socket) {
  return new Promise((resolve) => {
    socket.on('close', (code) => resolve(code));
    socket.on('error', () => resolve(-1));
  });
}

try {
  const loginA = await login('phase6_user_a', 'phase6-pass-a');
  const loginB = await login('phase6_user_b', 'phase6-pass-b');
  assert.equal(loginA.resp.status, 200, 'user A login should succeed');
  assert.equal(loginB.resp.status, 200, 'user B login should succeed');

  const postHeaders = { 'idempotency-key': 'phase6-post-1' };
  const p1 = await request('/api/new/posts', {
    method: 'POST',
    cookie: loginA.cookie,
    headers: postHeaders,
    body: { content: 'phase6 idempotent post' }
  });
  const p2 = await request('/api/new/posts', {
    method: 'POST',
    cookie: loginA.cookie,
    headers: postHeaders,
    body: { content: 'phase6 idempotent post' }
  });

  assert.equal(p1.resp.status, 200, 'first idempotent post should succeed');
  assert.equal(p2.resp.status, 200, 'replayed idempotent post should succeed');
  assert.equal(Number(p1.data?.id || 0), Number(p2.data?.id || 0), 'idempotent post id should match');
  assert.equal(p2.resp.headers.get('x-idempotent-replay'), '1', 'second post should be replay response');

  const postCount = Number(sqlGet('SELECT COUNT(*) AS c FROM posts WHERE user_id = ? AND content = ?', [userAId, 'phase6 idempotent post'])?.c || 0);
  assert.equal(postCount, 1, 'idempotent post should be inserted once');

  const chatHeaders = { 'idempotency-key': 'phase6-chat-1' };
  const c1 = await request('/api/new/chat/send', {
    method: 'POST',
    cookie: loginA.cookie,
    headers: chatHeaders,
    body: { message: 'phase6 idempotent chat' }
  });
  const c2 = await request('/api/new/chat/send', {
    method: 'POST',
    cookie: loginA.cookie,
    headers: chatHeaders,
    body: { message: 'phase6 idempotent chat' }
  });

  assert.equal(c1.resp.status, 200, 'first idempotent chat should succeed');
  assert.equal(c2.resp.status, 200, 'replayed idempotent chat should succeed');
  assert.equal(Number(c1.data?.id || 0), Number(c2.data?.id || 0), 'idempotent chat id should match');

  const chatCount = Number(sqlGet('SELECT COUNT(*) AS c FROM chat_messages WHERE user_id = ? AND message LIKE ?', [userAId, '%phase6 idempotent chat%'])?.c || 0);
  assert.equal(chatCount, 1, 'idempotent chat should be inserted once');

  const threadCreate = await request('/api/sdal-messenger/threads', {
    method: 'POST',
    cookie: loginA.cookie,
    body: { userId: userBId }
  });
  assert.equal(threadCreate.resp.status, 201, 'messenger thread create should succeed');
  const threadId = Number(threadCreate.data?.threadId || 0);
  assert.ok(threadId > 0, 'thread id should be returned');

  const mHeaders = { 'idempotency-key': 'phase6-messenger-1' };
  const m1 = await request(`/api/sdal-messenger/threads/${threadId}/messages`, {
    method: 'POST',
    cookie: loginA.cookie,
    headers: mHeaders,
    body: { text: 'phase6 idempotent dm', clientWrittenAt: new Date().toISOString() }
  });
  const m2 = await request(`/api/sdal-messenger/threads/${threadId}/messages`, {
    method: 'POST',
    cookie: loginA.cookie,
    headers: mHeaders,
    body: { text: 'phase6 idempotent dm', clientWrittenAt: new Date().toISOString() }
  });

  assert.equal(m1.resp.status, 201, 'first messenger send should succeed');
  assert.equal(m2.resp.status, 201, 'replayed messenger send should succeed');
  assert.equal(Number(m1.data?.item?.id || 0), Number(m2.data?.item?.id || 0), 'idempotent messenger message id should match');

  const dmCount = Number(sqlGet('SELECT COUNT(*) AS c FROM sdal_messenger_messages WHERE thread_id = ? AND body = ?', [threadId, 'phase6 idempotent dm'])?.c || 0);
  assert.equal(dmCount, 1, 'idempotent messenger send should be inserted once');

  const anonWs = new WebSocket(`${wsBase}/ws/chat`);
  const anonCloseCode = await waitForWsClose(anonWs);
  assert.ok([1008, -1].includes(anonCloseCode), 'anonymous websocket should be rejected');

  const authWs = new WebSocket(`${wsBase}/ws/chat`, {
    headers: { Cookie: loginA.cookie }
  });

  await new Promise((resolve, reject) => {
    authWs.once('open', resolve);
    authWs.once('error', reject);
  });

  authWs.send(JSON.stringify({ userId: 999999, message: 'phase6 ws message' }));
  await new Promise((resolve) => setTimeout(resolve, 250));
  authWs.close();

  console.log('phase6 realtime+jobs tests passed');
} finally {
  server.close();
}

process.exit(0);
