/**
 * Seed script: 2 test teacher + 50 test member with Turkish names from randomuser.me
 * Teacher 1 (Ayşe Yıldız): 20 connections across 4 cohorts
 * Teacher 2 (Mehmet Demir): 50 connections across 8 cohorts
 *
 * Usage: node server/scripts/seed-teacher-network-test.mjs
 * Dry run: node server/scripts/seed-teacher-network-test.mjs --dry-run
 * Cleanup: node server/scripts/seed-teacher-network-test.mjs --cleanup
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

// ── DB path (mirrors .env resolution in appRuntime) ───────────────────────────
const envFile = path.resolve(__dirname, '../.env');
let dbPath = 'server/data/sdal.local.sqlite';
if (fs.existsSync(envFile)) {
  const lines = fs.readFileSync(envFile, 'utf8').split('\n');
  for (const line of lines) {
    const m = line.match(/^SDAL_DB_PATH\s*=\s*(.+)$/);
    if (m) { dbPath = m[1].trim(); break; }
  }
}
const absDbPath = path.resolve(__dirname, '../..', dbPath);
console.log('DB path:', absDbPath);
if (!fs.existsSync(absDbPath)) {
  console.error('❌ DB file not found at', absDbPath);
  process.exit(1);
}

// ── Load better-sqlite3 ───────────────────────────────────────────────────────
let Database;
try {
  Database = require('better-sqlite3');
} catch {
  console.error('❌ better-sqlite3 not found. Run: cd server && npm install');
  process.exit(1);
}
const db = new Database(absDbPath);

// ── Helpers ───────────────────────────────────────────────────────────────────
async function hashPassword(password) {
  const salt = crypto.randomBytes(16).toString('hex');
  const derived = await scryptAsync(String(password), salt, 64);
  return `scrypt$${salt}$${Buffer.from(derived).toString('hex')}`;
}

function fetchJson(url) {
  return new Promise((resolve, reject) => {
    const proto = url.startsWith('https') ? require('https') : require('http');
    proto.get(url, (res) => {
      let data = '';
      res.on('data', (chunk) => { data += chunk; });
      res.on('end', () => {
        try { resolve(JSON.parse(data)); }
        catch (e) { reject(e); }
      });
    }).on('error', reject);
  });
}

// ── Cohort plan ───────────────────────────────────────────────────────────────
// 50 members indexed 0-49
// teacher1 uses members 0-19 (20 links, 4 cohorts)
// teacher2 uses members 0-49 (50 links, 8 cohorts)

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
    { class_year: null, memberRange: [48, 49] },  // 2 — no year
  ],
};

const TEACHER_HANDLES = ['ayseyildiz_ogr', 'mehmetdemir_ogr'];
const MEMBER_HANDLE_PREFIX = 'test_uye_';
const TEST_PASSWORD = 'Test1234!';
const SEED_TAG = 'seed_teacher_network_test';

// ── Cleanup mode ──────────────────────────────────────────────────────────────
if (isCleanup) {
  console.log('🧹 Cleanup mode: removing seeded test data...');
  const linksTableExists = db.prepare("SELECT name FROM sqlite_master WHERE type='table' AND name='teacher_alumni_links'").get();
  const teacherIds = db.prepare('SELECT id FROM uyeler WHERE kadi IN (?,?)').all(...TEACHER_HANDLES).map(r => r.id);
  const memberKadis = Array.from({ length: 50 }, (_, i) => `${MEMBER_HANDLE_PREFIX}${String(i).padStart(2, '0')}`);
  const memberIds = db.prepare(`SELECT id FROM uyeler WHERE kadi IN (${memberKadis.map(() => '?').join(',')})`).all(...memberKadis).map(r => r.id);
  const allIds = [...teacherIds, ...memberIds];
  if (allIds.length === 0) {
    console.log('No seeded users found.');
    process.exit(0);
  }
  const placeholders = allIds.map(() => '?').join(',');
  let linksDeleted = { changes: 0 };
  if (linksTableExists) {
    linksDeleted = db.prepare(`DELETE FROM teacher_alumni_links WHERE teacher_user_id IN (${placeholders}) OR alumni_user_id IN (${placeholders})`).run(...allIds, ...allIds);
  }
  const usersDeleted = db.prepare(`DELETE FROM uyeler WHERE id IN (${placeholders})`).run(...allIds);
  console.log(`✅ Deleted ${usersDeleted.changes} users, ${linksDeleted.changes} links.`);
  process.exit(0);
}

// ── Ensure teacher_alumni_links table exists ──────────────────────────────────
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
  db.exec('CREATE INDEX IF NOT EXISTS idx_teacher_alumni_links_teacher ON teacher_alumni_links (teacher_user_id, created_at DESC)');
  db.exec('CREATE INDEX IF NOT EXISTS idx_teacher_alumni_links_alumni ON teacher_alumni_links (alumni_user_id, created_at DESC)');
}

// ── Main ──────────────────────────────────────────────────────────────────────
async function main() {
  console.log(isDryRun ? '🔍 DRY RUN — no DB writes' : '🌱 Seeding teacher network test data...');
  if (!isDryRun) ensureLinksTable();

  // 1. Fetch Turkish user data from randomuser.me
  console.log('📡 Fetching Turkish user profiles from randomuser.me...');
  let randomUsers = [];
  try {
    const page1 = await fetchJson('https://randomuser.me/api/?nat=tr&results=25&seed=sdal_teacher_test_1&inc=name,picture,login');
    const page2 = await fetchJson('https://randomuser.me/api/?nat=tr&results=25&seed=sdal_teacher_test_2&inc=name,picture,login');
    randomUsers = [...page1.results, ...page2.results];
    console.log(`  ✓ Fetched ${randomUsers.length} profiles`);
  } catch (err) {
    console.warn('  ⚠️  randomuser.me fetch failed, using fallback names:', err.message);
    // Fallback Turkish names if API unreachable
    const fallbackNames = [
      ['Ahmet','Kaya'],['Fatma','Çelik'],['Mehmet','Arslan'],['Ayşe','Doğan'],['Ali','Şahin'],
      ['Hatice','Yıldız'],['Hüseyin','Öztürk'],['Zeynep','Aydın'],['İbrahim','Erdoğan'],['Emine','Kılıç'],
      ['Mustafa','Çetin'],['Elif','Koç'],['Süleyman','Kurt'],['Meryem','Özdemir'],['İsmail','Güneş'],
      ['Havva','Polat'],['Yusuf','Demirci'],['Hacer','Yılmaz'],['Recep','Bulut'],['Fadime','Aktaş'],
      ['Osman','Bozkurt'],['Halime','Keskin'],['Kadir','Sarı'],['Gülsüm','Çakır'],['Hasan','Özcan'],
      ['Sümeyye','Acar'],['Ömer','Güler'],['Rabia','Yalçın'],['Ramazan','Kara'],['Büşra','Demir'],
      ['Adem','Şimşek'],['Nuriye','Çelik'],['Hamza','Duman'],['Esra','Taş'],['Yasin','Kaplan'],
      ['Selma','Aslan'],['Serkan','Ateş'],['Dilek','Çavuş'],['Emre','Toprak'],['Songül','Yıldırım'],
      ['Burak','Bayram'],['Merve','Güzel'],['Murat','İlhan'],['Seda','Doğru'],['Kemal','Özgür'],
      ['Canan','Başaran'],['Taner','Eren'],['Nurgül','Sert'],['Onur','Kılınç'],['Pınar','Altın'],
    ];
    randomUsers = fallbackNames.map(([isim, soyisim], i) => ({
      name: { first: isim, last: soyisim },
      picture: { large: `https://i.pravatar.cc/150?img=${i + 1}` },
      login: { username: `fallback${i}` },
    }));
  }

  const now = new Date().toISOString();
  const hashedPassword = await hashPassword(TEST_PASSWORD);

  // 2. Check / insert teachers
  const teachers = [
    { kadi: TEACHER_HANDLES[0], isim: 'Ayşe', soyisim: 'Yıldız', email: 'ayse.yildiz.ogr@test.sdal', photo: 'https://randomuser.me/api/portraits/women/44.jpg' },
    { kadi: TEACHER_HANDLES[1], isim: 'Mehmet', soyisim: 'Demir', email: 'mehmet.demir.ogr@test.sdal', photo: 'https://randomuser.me/api/portraits/men/55.jpg' },
  ];

  const teacherIds = [];
  for (const t of teachers) {
    const existing = db.prepare('SELECT id FROM uyeler WHERE kadi = ?').get(t.kadi);
    if (existing) {
      console.log(`  ↩  Teacher '${t.kadi}' already exists (id=${existing.id})`);
      teacherIds.push(existing.id);
      continue;
    }
    if (!isDryRun) {
      const res = db.prepare(
        `INSERT INTO uyeler (kadi, sifre, email, isim, soyisim, aktivasyon, aktiv, ilktarih, resim, mezuniyetyili, ilkbd, role, admin, verified, verification_status)
         VALUES (?, ?, ?, ?, ?, ?, 1, ?, ?, '9999', 1, 'teacher', 0, 1, 'approved')`
      ).run(t.kadi, hashedPassword, t.email, t.isim, t.soyisim, SEED_TAG, now, t.photo);
      teacherIds.push(Number(res.lastInsertRowid));
      console.log(`  ✓ Teacher '${t.kadi}' inserted (id=${res.lastInsertRowid})`);
    } else {
      console.log(`  [dry] Would insert teacher '${t.kadi}'`);
      teacherIds.push(-1);
    }
  }

  // 3. Insert 50 members
  const memberIds = [];
  for (let i = 0; i < 50; i++) {
    const u = randomUsers[i];
    const kadi = `${MEMBER_HANDLE_PREFIX}${String(i).padStart(2, '0')}`;
    const isim = u.name.first;
    const soyisim = u.name.last;
    const photo = u.picture?.large || `https://i.pravatar.cc/150?img=${i + 10}`;
    const email = `${kadi}@test.sdal`;
    // Assign a graduation year spread across realistic cohorts for member profile
    const memberCohortYears = ['2015','2016','2017','2018','2019','2020','2021','2022','2023','2024'];
    const mezuniyetyili = memberCohortYears[i % memberCohortYears.length];

    const existing = db.prepare('SELECT id FROM uyeler WHERE kadi = ?').get(kadi);
    if (existing) {
      memberIds.push(existing.id);
      continue;
    }
    if (!isDryRun) {
      const res = db.prepare(
        `INSERT INTO uyeler (kadi, sifre, email, isim, soyisim, aktivasyon, aktiv, ilktarih, resim, mezuniyetyili, ilkbd, role, admin, verified, verification_status)
         VALUES (?, ?, ?, ?, ?, ?, 1, ?, ?, ?, 1, 'user', 0, 1, 'approved')`
      ).run(kadi, hashedPassword, email, isim, soyisim, SEED_TAG, now, photo, mezuniyetyili);
      memberIds.push(Number(res.lastInsertRowid));
    } else {
      memberIds.push(-1);
    }
  }
  if (!isDryRun) {
    console.log(`  ✓ ${memberIds.length} members inserted/resolved`);
  } else {
    console.log(`  [dry] Would insert 50 members`);
  }

  // 4. Create teacher_alumni_links
  function createLinks(teacherIdIndex, cohortPlan) {
    const teacherId = teacherIds[teacherIdIndex];
    let totalInserted = 0;
    for (const cohort of cohortPlan) {
      const [start, end] = cohort.memberRange;
      const relationshipTypes = ['taught_in_class', 'club_advisor', 'mentored', 'taught_in_class'];
      for (let idx = start; idx <= end; idx++) {
        const memberId = memberIds[idx];
        const relType = relationshipTypes[idx % relationshipTypes.length];
        const existing = db.prepare(
          'SELECT id FROM teacher_alumni_links WHERE teacher_user_id = ? AND alumni_user_id = ? AND relationship_type = ?'
        ).get(teacherId, memberId, relType);
        if (existing) continue;
        if (!isDryRun) {
          db.prepare(
            `INSERT INTO teacher_alumni_links
               (teacher_user_id, alumni_user_id, relationship_type, class_year, notes, confidence_score, created_via, source_surface, review_status, created_by, created_at)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`
          ).run(
            teacherId, memberId, relType,
            cohort.class_year,
            '',
            0.9,
            'manual_entry',
            'test_seed',
            'pending',
            memberId,
            now
          );
        }
        totalInserted++;
      }
    }
    return totalInserted;
  }

  if (!isDryRun) {
    const t1Links = createLinks(0, COHORT_PLAN.teacher1);
    const t2Links = createLinks(1, COHORT_PLAN.teacher2);
    console.log(`  ✓ Teacher 1 (${teachers[0].kadi}): ${t1Links} links created`);
    console.log(`  ✓ Teacher 2 (${teachers[1].kadi}): ${t2Links} links created`);
  } else {
    let t1c = 0, t2c = 0;
    for (const c of COHORT_PLAN.teacher1) t1c += c.memberRange[1] - c.memberRange[0] + 1;
    for (const c of COHORT_PLAN.teacher2) t2c += c.memberRange[1] - c.memberRange[0] + 1;
    console.log(`  [dry] Would create ${t1c} links for teacher1, ${t2c} links for teacher2`);
  }

  // 5. Summary
  console.log('\n✅ Done!');
  if (!isDryRun) {
    console.log('\n📋 Test accounts (password for all: Test1234!)');
    console.log('─────────────────────────────────────────────────────');
    console.log(`  Teacher 1 — username: ${teachers[0].kadi}  id: ${teacherIds[0]}  (20 links, 4 cohorts)`);
    console.log(`  Teacher 2 — username: ${teachers[1].kadi}  id: ${teacherIds[1]}  (50 links, 8 cohorts)`);
    console.log(`  Members   — username: ${MEMBER_HANDLE_PREFIX}00 … ${MEMBER_HANDLE_PREFIX}49`);
    console.log('─────────────────────────────────────────────────────');
    console.log(`\nPostman/App test URL:`);
    console.log(`  GET /api/new/teachers/${teacherIds[0]}/map`);
    console.log(`  GET /api/new/teachers/${teacherIds[1]}/map`);
    console.log(`\nCleanup: node server/scripts/seed-teacher-network-test.mjs --cleanup`);

    // Write a small JSON summary for Postman collection generation
    const summary = { teachers: teachers.map((t, i) => ({ ...t, id: teacherIds[i] })), memberCount: 50, password: TEST_PASSWORD };
    fs.writeFileSync(path.resolve(__dirname, 'seed-teacher-network-test.json'), JSON.stringify(summary, null, 2));
    console.log('\n  📄 seed-teacher-network-test.json written (used by Postman collection generator)');
  }
}

main().catch((err) => {
  console.error('❌ Seed failed:', err);
  process.exit(1);
});
