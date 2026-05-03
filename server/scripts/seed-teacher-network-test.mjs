/**
 * Seed script: 2 test teacher + 50 test member with guaranteed Turkish names.
 * Teacher 1 (Ayşe Kaya):    20 links, 4 cohorts (2024×8, 2022×5, 2019×4, 2016×3)
 * Teacher 2 (Mehmet Arslan): 50 links, 8 cohorts (2024×10, 2023×7, 2022×9, 2020×6, 2018×8, 2016×5, 2014×3, null×2)
 *
 * Usage:
 *   node server/scripts/seed-teacher-network-test.mjs           # seed
 *   node server/scripts/seed-teacher-network-test.mjs --dry-run # preview only
 *   node server/scripts/seed-teacher-network-test.mjs --cleanup # remove seeded data
 */

import crypto from 'crypto';
import { promisify } from 'util';
import { createRequire } from 'module';
import path from 'path';
import { fileURLToPath } from 'url';
import fs from 'fs';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const require = createRequire(import.meta.url);

const isDryRun = process.argv.includes('--dry-run');
const isCleanup = process.argv.includes('--cleanup');
const scryptAsync = promisify(crypto.scrypt);

// ── DB path — env var wins, then .env file, then default ─────────────────────
let dbPathRaw = process.env.SDAL_DB_PATH || '';
if (!dbPathRaw) {
  const envFile = path.resolve(__dirname, '../.env');
  if (fs.existsSync(envFile)) {
    for (const line of fs.readFileSync(envFile, 'utf8').split('\n')) {
      const m = line.match(/^SDAL_DB_PATH\s*=\s*(.+)$/);
      if (m) { dbPathRaw = m[1].trim(); break; }
    }
  }
}
if (!dbPathRaw) dbPathRaw = 'server/data/sdal.local.sqlite';
const absDbPath = path.isAbsolute(dbPathRaw)
  ? dbPathRaw
  : path.resolve(__dirname, '../..', dbPathRaw);
console.log('DB:', absDbPath);
if (!fs.existsSync(absDbPath)) { console.error('❌ DB not found:', absDbPath); process.exit(1); }

const Database = require('better-sqlite3');
const db = new Database(absDbPath);

// ── Helpers ────────────────────────────────────────────────────────────────────
const scrypt = promisify(crypto.scrypt);
async function hashPassword(pw) {
  const salt = crypto.randomBytes(16).toString('hex');
  const buf = await scrypt(String(pw), salt, 64);
  return `scrypt$${salt}$${buf.toString('hex')}`;
}

// ── Turkish name data ──────────────────────────────────────────────────────────
// 50 members — mix of male/female names, varied surnames
const MEMBER_NAMES = [
  // 0-9
  { isim: 'Berk',      soyisim: 'Yılmaz',     gender: 'm' },
  { isim: 'Selin',     soyisim: 'Çelik',      gender: 'f' },
  { isim: 'Emre',      soyisim: 'Kaya',       gender: 'm' },
  { isim: 'Zeynep',    soyisim: 'Doğan',      gender: 'f' },
  { isim: 'Oğuzhan',   soyisim: 'Şahin',      gender: 'm' },
  { isim: 'Büşra',     soyisim: 'Öztürk',     gender: 'f' },
  { isim: 'Furkan',    soyisim: 'Arslan',      gender: 'm' },
  { isim: 'Merve',     soyisim: 'Çetin',      gender: 'f' },
  { isim: 'Alp',       soyisim: 'Erdoğan',    gender: 'm' },
  { isim: 'Esra',      soyisim: 'Koç',        gender: 'f' },
  // 10-19
  { isim: 'Mert',      soyisim: 'Kurt',       gender: 'm' },
  { isim: 'Elif',      soyisim: 'Polat',      gender: 'f' },
  { isim: 'Serhan',    soyisim: 'Güneş',      gender: 'm' },
  { isim: 'Tuğba',     soyisim: 'Aydın',      gender: 'f' },
  { isim: 'Umut',      soyisim: 'Özdemir',    gender: 'm' },
  { isim: 'Gizem',     soyisim: 'Bulut',      gender: 'f' },
  { isim: 'Kaan',      soyisim: 'Demirci',    gender: 'm' },
  { isim: 'Seda',      soyisim: 'Aktaş',      gender: 'f' },
  { isim: 'Berke',     soyisim: 'Bozkurt',    gender: 'm' },
  { isim: 'Melike',    soyisim: 'Keskin',      gender: 'f' },
  // 20-29
  { isim: 'Deniz',     soyisim: 'Sarı',       gender: 'm' },
  { isim: 'Aylin',     soyisim: 'Çakır',      gender: 'f' },
  { isim: 'Burak',     soyisim: 'Özcan',      gender: 'm' },
  { isim: 'Hande',     soyisim: 'Güler',      gender: 'f' },
  { isim: 'Arda',      soyisim: 'Yalçın',     gender: 'm' },
  { isim: 'Pınar',     soyisim: 'Kara',       gender: 'f' },
  { isim: 'Sercan',    soyisim: 'Şimşek',     gender: 'm' },
  { isim: 'Cansu',     soyisim: 'Duman',      gender: 'f' },
  { isim: 'Erdem',     soyisim: 'Taş',        gender: 'm' },
  { isim: 'İlayda',    soyisim: 'Kaplan',     gender: 'f' },
  // 30-39
  { isim: 'Volkan',    soyisim: 'Aslan',      gender: 'm' },
  { isim: 'Özlem',     soyisim: 'Ateş',       gender: 'f' },
  { isim: 'Taner',     soyisim: 'Toprak',     gender: 'm' },
  { isim: 'Dilek',     soyisim: 'Yıldırım',   gender: 'f' },
  { isim: 'Altan',     soyisim: 'Bayram',     gender: 'm' },
  { isim: 'Nurgül',    soyisim: 'Güzel',      gender: 'f' },
  { isim: 'Onur',      soyisim: 'İlhan',      gender: 'm' },
  { isim: 'Ceren',     soyisim: 'Doğru',      gender: 'f' },
  { isim: 'Kemal',     soyisim: 'Özgür',      gender: 'm' },
  { isim: 'Başak',     soyisim: 'Başaran',    gender: 'f' },
  // 40-49
  { isim: 'Semih',     soyisim: 'Eren',       gender: 'm' },
  { isim: 'Yağmur',    soyisim: 'Sert',       gender: 'f' },
  { isim: 'Barış',     soyisim: 'Kılınç',     gender: 'm' },
  { isim: 'Hatice',    soyisim: 'Altın',      gender: 'f' },
  { isim: 'Ozan',      soyisim: 'Çavuş',      gender: 'm' },
  { isim: 'Sibel',     soyisim: 'Acar',       gender: 'f' },
  { isim: 'Murat',     soyisim: 'Sezer',      gender: 'm' },
  { isim: 'Nazlı',     soyisim: 'Karaer',     gender: 'f' },
  { isim: 'Çağrı',     soyisim: 'Soytürk',    gender: 'm' },
  { isim: 'Tuğçe',     soyisim: 'Demir',      gender: 'f' },
];

// Pravatar — deterministic photos by index
function photoUrl(gender, index) {
  // pravatar uses seed-based URLs; men 1-70, women 1-70
  const n = (index % 60) + 1;
  return gender === 'f'
    ? `https://randomuser.me/api/portraits/women/${n}.jpg`
    : `https://randomuser.me/api/portraits/men/${n}.jpg`;
}

// ── Cohort plan ────────────────────────────────────────────────────────────────
const COHORT_PLAN = {
  teacher1: [
    { class_year: 2024, memberRange: [0, 7] },    // 8
    { class_year: 2022, memberRange: [8, 12] },   // 5
    { class_year: 2019, memberRange: [13, 16] },  // 4
    { class_year: 2016, memberRange: [17, 19] },  // 3
  ],
  teacher2: [
    { class_year: 2024, memberRange: [0, 9] },    // 10
    { class_year: 2023, memberRange: [10, 16] },  // 7
    { class_year: 2022, memberRange: [17, 25] },  // 9
    { class_year: 2020, memberRange: [26, 31] },  // 6
    { class_year: 2018, memberRange: [32, 39] },  // 8
    { class_year: 2016, memberRange: [40, 44] },  // 5
    { class_year: 2014, memberRange: [45, 47] },  // 3
    { class_year: null, memberRange: [48, 49] },  // 2
  ],
};

const TEACHERS = [
  { kadi: 'aysekaya_ogr',    isim: 'Ayşe',   soyisim: 'Kaya',   email: 'ayse.kaya.ogr@test.sdal',    photo: 'https://randomuser.me/api/portraits/women/44.jpg' },
  { kadi: 'mehmetarslan_ogr', isim: 'Mehmet', soyisim: 'Arslan', email: 'mehmet.arslan.ogr@test.sdal', photo: 'https://randomuser.me/api/portraits/men/55.jpg'   },
];
const MEMBER_HANDLE_PREFIX = 'test_uye_';
const TEST_PASSWORD = 'Test1234!';

// ── Ensure table ───────────────────────────────────────────────────────────────
function ensureLinksTable() {
  db.exec(`
    CREATE TABLE IF NOT EXISTS teacher_alumni_links (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      teacher_user_id INTEGER NOT NULL,
      alumni_user_id INTEGER NOT NULL,
      relationship_type TEXT NOT NULL,
      class_year INTEGER,
      notes TEXT,
      confidence_score REAL NOT NULL DEFAULT 1.0,
      created_via TEXT NOT NULL DEFAULT 'manual_alumni_link',
      source_surface TEXT NOT NULL DEFAULT 'teachers_network_page',
      last_reviewed_by INTEGER,
      review_status TEXT NOT NULL DEFAULT 'pending',
      review_note TEXT,
      reviewed_at TEXT,
      merged_into_link_id INTEGER,
      created_by INTEGER,
      created_at TEXT NOT NULL,
      UNIQUE(teacher_user_id, alumni_user_id, relationship_type, class_year)
    )
  `);
  db.exec('CREATE INDEX IF NOT EXISTS idx_tal_teacher ON teacher_alumni_links (teacher_user_id, created_at DESC)');
  db.exec('CREATE INDEX IF NOT EXISTS idx_tal_alumni  ON teacher_alumni_links (alumni_user_id,  created_at DESC)');
}

// ── Cleanup ────────────────────────────────────────────────────────────────────
if (isCleanup) {
  console.log('🧹 Cleaning up seeded test data...');
  const linksOk = db.prepare("SELECT name FROM sqlite_master WHERE type='table' AND name='teacher_alumni_links'").get();
  const teacherKadis = TEACHERS.map(t => t.kadi);
  const teacherRows = db.prepare(`SELECT id FROM uyeler WHERE kadi IN (${teacherKadis.map(() => '?').join(',')})`).all(...teacherKadis);
  const memberKadis = Array.from({ length: 50 }, (_, i) => `${MEMBER_HANDLE_PREFIX}${String(i).padStart(2, '0')}`);
  const memberRows = db.prepare(`SELECT id FROM uyeler WHERE kadi IN (${memberKadis.map(() => '?').join(',')})`).all(...memberKadis);
  const allIds = [...teacherRows, ...memberRows].map(r => r.id);
  if (!allIds.length) { console.log('Nothing to clean.'); process.exit(0); }
  const ph = allIds.map(() => '?').join(',');
  const lDel = linksOk
    ? db.prepare(`DELETE FROM teacher_alumni_links WHERE teacher_user_id IN (${ph}) OR alumni_user_id IN (${ph})`).run(...allIds, ...allIds).changes
    : 0;
  const uDel = db.prepare(`DELETE FROM uyeler WHERE id IN (${ph})`).run(...allIds).changes;
  console.log(`✅ Removed ${uDel} users, ${lDel} links.`);
  process.exit(0);
}

// ── Main ───────────────────────────────────────────────────────────────────────
async function main() {
  console.log(isDryRun ? '🔍 DRY RUN — no DB writes' : '🌱 Seeding...');
  if (!isDryRun) ensureLinksTable();

  const now = new Date().toISOString();
  const pw = await hashPassword(TEST_PASSWORD);

  // Insert teachers
  const teacherIds = [];
  for (const t of TEACHERS) {
    const ex = db.prepare('SELECT id FROM uyeler WHERE kadi = ?').get(t.kadi);
    if (ex) {
      console.log(`  ↩  Teacher '${t.kadi}' exists (id=${ex.id})`);
      teacherIds.push(ex.id);
      continue;
    }
    if (!isDryRun) {
      const r = db.prepare(
        `INSERT INTO uyeler (kadi, sifre, email, isim, soyisim, aktivasyon, aktiv, ilktarih, resim, mezuniyetyili, ilkbd, role, admin, verified, verification_status)
         VALUES (?, ?, ?, ?, ?, 'seed', 1, ?, ?, '9999', 1, 'teacher', 0, 1, 'approved')`
      ).run(t.kadi, pw, t.email, t.isim, t.soyisim, now, t.photo);
      teacherIds.push(Number(r.lastInsertRowid));
      console.log(`  ✓ Teacher '${t.kadi}' (id=${r.lastInsertRowid})`);
    } else {
      console.log(`  [dry] teacher '${t.kadi}'`);
      teacherIds.push(-1);
    }
  }

  // Insert members
  const memberIds = [];
  const cohortYears = ['2015','2016','2017','2018','2019','2020','2021','2022','2023','2024'];
  for (let i = 0; i < 50; i++) {
    const n = MEMBER_NAMES[i];
    const kadi = `${MEMBER_HANDLE_PREFIX}${String(i).padStart(2, '0')}`;
    const ex = db.prepare('SELECT id FROM uyeler WHERE kadi = ?').get(kadi);
    if (ex) { memberIds.push(ex.id); continue; }
    if (!isDryRun) {
      const r = db.prepare(
        `INSERT INTO uyeler (kadi, sifre, email, isim, soyisim, aktivasyon, aktiv, ilktarih, resim, mezuniyetyili, ilkbd, role, admin, verified, verification_status)
         VALUES (?, ?, ?, ?, ?, 'seed', 1, ?, ?, ?, 1, 'user', 0, 1, 'approved')`
      ).run(kadi, pw, `${kadi}@test.sdal`, n.isim, n.soyisim, now, photoUrl(n.gender, i), cohortYears[i % cohortYears.length]);
      memberIds.push(Number(r.lastInsertRowid));
    } else {
      memberIds.push(-1);
    }
  }
  if (!isDryRun) console.log(`  ✓ ${memberIds.length} members`);

  // Insert links
  const relTypes = ['taught_in_class', 'club_advisor', 'mentored', 'taught_in_class'];
  function insertLinks(tIdxInTeachers, plan) {
    const tid = teacherIds[tIdxInTeachers];
    let n = 0;
    for (const cohort of plan) {
      const [s, e] = cohort.memberRange;
      for (let i = s; i <= e; i++) {
        const mid = memberIds[i];
        const rel = relTypes[i % relTypes.length];
        const ex = db.prepare(
          'SELECT id FROM teacher_alumni_links WHERE teacher_user_id=? AND alumni_user_id=? AND relationship_type=?'
        ).get(tid, mid, rel);
        if (ex) continue;
        if (!isDryRun) {
          db.prepare(
            `INSERT INTO teacher_alumni_links
               (teacher_user_id,alumni_user_id,relationship_type,class_year,notes,confidence_score,
                created_via,source_surface,review_status,created_by,created_at)
             VALUES (?,?,?,?,?,0.9,'manual_entry','test_seed','pending',?,?)`
          ).run(tid, mid, rel, cohort.class_year, '', mid, now);
        }
        n++;
      }
    }
    return n;
  }

  const l1 = insertLinks(0, COHORT_PLAN.teacher1);
  const l2 = insertLinks(1, COHORT_PLAN.teacher2);

  if (!isDryRun) {
    console.log(`  ✓ ${TEACHERS[0].kadi}: ${l1} links`);
    console.log(`  ✓ ${TEACHERS[1].kadi}: ${l2} links`);
  } else {
    console.log(`  [dry] teacher1: ${l1} links, teacher2: ${l2} links`);
  }

  if (!isDryRun) {
    console.log('\n📋 Accounts — password: Test1234!');
    console.log(`  Teacher 1 — ${TEACHERS[0].kadi}  id:${teacherIds[0]}  (20 links / 4 cohorts)`);
    console.log(`  Teacher 2 — ${TEACHERS[1].kadi}  id:${teacherIds[1]}  (50 links / 8 cohorts)`);
    console.log(`  Members   — test_uye_00 … test_uye_49`);

    fs.writeFileSync(
      path.resolve(__dirname, 'seed-teacher-network-test.json'),
      JSON.stringify({ teachers: TEACHERS.map((t, i) => ({ ...t, id: teacherIds[i] })), memberCount: 50, password: TEST_PASSWORD }, null, 2)
    );
  }
  console.log('\n✅ Done');
}

main().catch(e => { console.error('❌', e.message); process.exit(1); });
