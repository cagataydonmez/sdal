/**
 * Migration: cohort group management
 *  1. Add is_cohort_group + cohort_year columns to groups table
 *  2. Mark existing cohort groups (named "${year} Mezunları" or "Öğretmenler")
 *  3. Auto-create missing cohort groups for all distinct mezuniyetyili values
 *  4. Add all admin users as owners of every cohort group (idempotent)
 *
 * Usage: SDAL_DB_PATH=/var/lib/sdal/data/sdal.sqlite node scripts/migrate-cohort-groups.mjs
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

const TEACHER_COHORT_VALUE = '9999';
const MIN_YEAR = 1960;
const MAX_YEAR = new Date().getFullYear() + 5;

// --- Step 1: verify table exists, add columns ---
const hasGroupsTableEarly = db.prepare("SELECT name FROM sqlite_master WHERE type='table' AND name='groups'").get();
if (!hasGroupsTableEarly) { console.log('ℹ️  groups table not found — skipping (start the app first to create tables)'); db.close(); process.exit(0); }

const groupCols = db.prepare('PRAGMA table_info(groups)').all().map(r => r.name);
if (!groupCols.includes('is_cohort_group')) {
  db.prepare("ALTER TABLE groups ADD COLUMN is_cohort_group INTEGER DEFAULT 0").run();
  console.log('✅  groups.is_cohort_group added');
} else { console.log('⏭️   groups.is_cohort_group already exists'); }

if (!groupCols.includes('cohort_year')) {
  db.prepare("ALTER TABLE groups ADD COLUMN cohort_year TEXT").run();
  console.log('✅  groups.cohort_year added');
} else { console.log('⏭️   groups.cohort_year already exists'); }

// --- Step 2: mark existing cohort groups ---
function cohortYearFromName(name) {
  if (name === 'Öğretmenler') return TEACHER_COHORT_VALUE;
  const m = name.match(/^(\d{4}) Mezunları$/);
  if (m) {
    const y = parseInt(m[1], 10);
    if (y >= MIN_YEAR && y <= MAX_YEAR) return String(y);
  }
  return null;
}

const allGroups = db.prepare('SELECT id, name FROM groups').all();
let marked = 0;
for (const g of allGroups) {
  const cy = cohortYearFromName(g.name);
  if (cy) {
    db.prepare('UPDATE groups SET is_cohort_group = 1, cohort_year = ? WHERE id = ?').run(cy, g.id);
    marked++;
  }
}
console.log(`✅  Marked ${marked} existing cohort group(s)`);

// --- Step 3: auto-create missing cohort groups ---
const cohortRows = db.prepare(
  `SELECT DISTINCT CAST(mezuniyetyili AS TEXT) AS cy
   FROM uyeler
   WHERE mezuniyetyili IS NOT NULL AND mezuniyetyili != '' AND mezuniyetyili != '0'`
).all();

const rootUser = db.prepare("SELECT id FROM uyeler WHERE LOWER(COALESCE(role,'')) = 'root' LIMIT 1").get();
const rootId = rootUser?.id || 1;
const now = new Date().toISOString();

let created = 0;
for (const row of cohortRows) {
  const cy = row.cy?.trim();
  if (!cy) continue;
  const isTeacher = cy === TEACHER_COHORT_VALUE;
  if (!isTeacher) {
    const y = parseInt(cy, 10);
    if (isNaN(y) || y < MIN_YEAR || y > MAX_YEAR) continue;
  }
  const groupName = isTeacher ? 'Öğretmenler' : `${cy} Mezunları`;
  let group = db.prepare('SELECT id FROM groups WHERE name = ?').get(groupName);
  if (!group) {
    const desc = isTeacher ? 'SDAL öğretmenlerine özel iletişim ağı.' : `SDAL ${cy} yılı mezunlarına özel iletişim ağı.`;
    const r = db.prepare(
      'INSERT INTO groups (name, description, cover_image, owner_id, created_at, visibility, show_contact_hint, is_cohort_group, cohort_year) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)'
    ).run(groupName, desc, '/images/cohort_default.jpg', rootId, now, 'public', 1, 1, cy);
    group = { id: r.lastInsertRowid };
    db.prepare('INSERT OR IGNORE INTO group_members (group_id, user_id, role, created_at) VALUES (?, ?, ?, ?)').run(group.id, rootId, 'owner', now);
    created++;
    console.log(`  ✅ Created group: ${groupName}`);
  }

  // Ensure all users with this cohort are members
  const cohortUsers = isTeacher
    ? db.prepare(`SELECT id FROM uyeler WHERE CAST(mezuniyetyili AS TEXT) = ?`).all(TEACHER_COHORT_VALUE)
    : db.prepare(`SELECT id FROM uyeler WHERE CAST(mezuniyetyili AS TEXT) = ?`).all(cy);
  for (const u of cohortUsers) {
    db.prepare('INSERT OR IGNORE INTO group_members (group_id, user_id, role, created_at) VALUES (?, ?, ?, ?)').run(group.id, u.id, 'member', now);
  }
}
console.log(`✅  Created ${created} missing cohort group(s) and backfilled members`);

// --- Step 4: add all admins as owners of every cohort group ---
const admins = db.prepare(
  `SELECT id FROM uyeler WHERE admin = 1 OR LOWER(COALESCE(role,'')) IN ('admin','root')`
).all();

const cohortGroups = db.prepare('SELECT id FROM groups WHERE is_cohort_group = 1').all();
let ownerRows = 0;
for (const cg of cohortGroups) {
  for (const admin of admins) {
    const existing = db.prepare('SELECT role FROM group_members WHERE group_id = ? AND user_id = ?').get(cg.id, admin.id);
    if (!existing) {
      db.prepare('INSERT OR IGNORE INTO group_members (group_id, user_id, role, created_at) VALUES (?, ?, ?, ?)').run(cg.id, admin.id, 'owner', now);
      ownerRows++;
    } else if (existing.role !== 'owner') {
      db.prepare("UPDATE group_members SET role = 'owner' WHERE group_id = ? AND user_id = ?").run(cg.id, admin.id);
      ownerRows++;
    }
  }
}
console.log(`✅  Ensured ${ownerRows} admin owner row(s) across cohort groups`);

console.log('\nDone.\n');
db.close();
