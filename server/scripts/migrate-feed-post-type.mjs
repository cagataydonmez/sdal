/**
 * Migration: add post_type + entity_id to posts table
 * Usage: SDAL_DB_PATH=/var/lib/sdal/data/sdal.sqlite node scripts/migrate-feed-post-type.mjs
 */
import path from 'path';
import { fileURLToPath } from 'url';
import fs from 'fs';
import { createRequire } from 'module';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const require = createRequire(import.meta.url);

let dbPath = process.env.SDAL_DB_PATH || '';
if (!dbPath) {
  const envFile = path.resolve(__dirname, '../.env');
  if (fs.existsSync(envFile)) {
    for (const line of fs.readFileSync(envFile, 'utf8').split('\n')) {
      const m = line.match(/^SDAL_DB_PATH\s*=\s*(.+)$/);
      if (m) { dbPath = m[1].trim(); break; }
    }
  }
}
if (!dbPath) dbPath = 'server/data/sdal.local.sqlite';
const absDb = path.isAbsolute(dbPath) ? dbPath : path.resolve(__dirname, '../..', dbPath);

if (!fs.existsSync(absDb)) { console.error('DB not found:', absDb); process.exit(1); }

const Database = require('better-sqlite3');
const db = new Database(absDb);

const cols = db.prepare("PRAGMA table_info(posts)").all().map(r => r.name);

let changed = 0;
if (!cols.includes('post_type')) {
  db.prepare("ALTER TABLE posts ADD COLUMN post_type TEXT DEFAULT 'post'").run();
  console.log('✅  posts.post_type column added');
  changed++;
} else {
  console.log('⏭️   posts.post_type already exists');
}

if (!cols.includes('entity_id')) {
  db.prepare("ALTER TABLE posts ADD COLUMN entity_id INTEGER").run();
  console.log('✅  posts.entity_id column added');
  changed++;
} else {
  console.log('⏭️   posts.entity_id already exists');
}

console.log(`\nDone. ${changed} column(s) added.\n`);
db.close();
