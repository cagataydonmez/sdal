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
  return sqlGet('SELECT id FROM uyeler WHERE kadi = ?', [username]).id;
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
