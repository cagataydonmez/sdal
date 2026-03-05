import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import Database from 'better-sqlite3';

const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'sdal-phase2-health-'));
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
process.env.SDAL_SESSION_SECRET = 'phase2-health-secret';
process.env.SDAL_ADMIN_PASSWORD = 'AdminPanel!123';
process.env.ROOT_BOOTSTRAP_PASSWORD = 'RootPass!123';
process.env.MAIL_ALLOW_MOCK = 'true';
process.env.SDAL_LEGACY_ROOT_DIR = tmpDir;
process.env.REDIS_URL = '';

const { default: app, onServerStarted } = await import('../../app.js');
await onServerStarted();

const server = app.listen(0);
await new Promise((resolve, reject) => {
  server.once('listening', resolve);
  server.once('error', reject);
});

const baseUrl = `http://127.0.0.1:${server.address().port}`;

try {
  for (const endpoint of ['/api/health', '/health']) {
    const response = await fetch(`${baseUrl}${endpoint}`);
    const body = await response.json();

    assert.equal(response.status, 200, `${endpoint} status must be 200`);
    assert.equal(typeof body.ok, 'boolean', `${endpoint} must preserve ok`);
    assert.equal(typeof body.dbPath, 'string', `${endpoint} must preserve dbPath`);
    assert.equal(body.dbDriver, 'sqlite', `${endpoint} dbDriver expected sqlite`);
    assert.equal(typeof body.dbReady, 'boolean', `${endpoint} dbReady expected`);
    assert.equal(typeof body.redisReady, 'boolean', `${endpoint} redisReady expected`);
    assert.ok(body.checks && typeof body.checks === 'object', `${endpoint} checks missing`);
    assert.ok(body.checks.db && typeof body.checks.db === 'object', `${endpoint} checks.db missing`);
    assert.ok(body.checks.redis && typeof body.checks.redis === 'object', `${endpoint} checks.redis missing`);
    assert.equal(body.checks.db.ready, true, `${endpoint} sqlite check should be ready`);
    assert.equal(body.checks.redis.configured, false, `${endpoint} redis should be optional in this test`);
  }

  console.log('phase2 health tests passed');
} finally {
  server.close();
}

process.exit(0);
