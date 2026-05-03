/**
 * Integration test for GET /api/new/teachers/:id/map
 *
 * Requires: server running on localhost (reads PORT from .env, defaults 8787)
 * Usage: node server/scripts/test-teacher-network-map.mjs
 */

import http from 'http';
import https from 'https';
import path from 'path';
import { fileURLToPath } from 'url';
import fs from 'fs';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

// ── Config ─────────────────────────────────────────────────────────────────────
const envFile = path.resolve(__dirname, '../.env');
let BASE_URL = 'http://localhost:8787';
if (fs.existsSync(envFile)) {
  for (const line of fs.readFileSync(envFile, 'utf8').split('\n')) {
    const m = line.match(/^SDAL_BASE_URL\s*=\s*(.+)$/);
    if (m) { BASE_URL = m[1].trim(); break; }
  }
}

const seedFile = path.resolve(__dirname, 'seed-teacher-network-test.json');
if (!fs.existsSync(seedFile)) {
  console.error('❌ seed-teacher-network-test.json not found. Run the seed script first.');
  process.exit(1);
}
const { teachers, password } = JSON.parse(fs.readFileSync(seedFile, 'utf8'));
const [T1, T2] = teachers;

// ── HTTP helpers ───────────────────────────────────────────────────────────────
function request(method, path, body, cookieJar = {}) {
  return new Promise((resolve, reject) => {
    const url = new URL(path, BASE_URL);
    const lib = url.protocol === 'https:' ? https : http;
    const payload = body ? JSON.stringify(body) : undefined;
    const headers = {
      'Content-Type': 'application/json',
      'Cookie': Object.entries(cookieJar).map(([k, v]) => `${k}=${v}`).join('; '),
    };
    if (payload) headers['Content-Length'] = Buffer.byteLength(payload);

    const req = lib.request({ hostname: url.hostname, port: url.port || (url.protocol === 'https:' ? 443 : 80), path: url.pathname + url.search, method, headers }, (res) => {
      let data = '';
      res.on('data', c => data += c);
      res.on('end', () => {
        const setCookie = res.headers['set-cookie'] || [];
        for (const c of setCookie) {
          const [pair] = c.split(';');
          const [k, v] = pair.trim().split('=');
          if (k && v !== undefined) cookieJar[k.trim()] = v.trim();
        }
        try { resolve({ status: res.statusCode, body: JSON.parse(data), cookieJar }); }
        catch { resolve({ status: res.statusCode, body: data, cookieJar }); }
      });
    });
    req.on('error', reject);
    if (payload) req.write(payload);
    req.end();
  });
}

// ── Assertions ─────────────────────────────────────────────────────────────────
let passed = 0;
let failed = 0;

function assert(label, condition, detail = '') {
  if (condition) {
    console.log(`  ✅  ${label}`);
    passed++;
  } else {
    console.log(`  ❌  ${label}${detail ? '  →  ' + detail : ''}`);
    failed++;
  }
}

function assertEqual(label, actual, expected) {
  assert(label, actual === expected, `expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}`);
}

function section(title) {
  console.log(`\n${'─'.repeat(60)}\n${title}\n${'─'.repeat(60)}`);
}

// ── Tests ──────────────────────────────────────────────────────────────────────
async function run() {
  console.log(`\n🧪 Teacher Network Map — integration tests`);
  console.log(`   Server: ${BASE_URL}`);

  // ── 1. Auth ──────────────────────────────────────────────────────────────────
  section('1. Authentication');
  const jar = {};

  const unauth = await request('GET', `/api/new/teachers/${T1.id}/map`, null, {});
  assert('Unauthenticated request is rejected', [401, 403].includes(unauth.status), `status=${unauth.status}`);

  const login = await request('POST', '/api/auth/login', { kadi: T1.kadi, sifre: password }, jar);
  assertEqual('Login returns 200', login.status, 200);
  assert('Login response has user object', typeof login.body?.user === 'object');
  assertEqual('Logged-in user is correct', login.body?.user?.kadi, T1.kadi);
  assert('Session cookie set', Object.keys(jar).length > 0, JSON.stringify(jar));

  // ── 2. Teacher 1 map (20 links / 4 cohorts) ──────────────────────────────────
  section(`2. Teacher 1 map — ${T1.isim} ${T1.soyisim} (${T1.kadi})`);
  const r1 = await request('GET', `/api/new/teachers/${T1.id}/map`, null, jar);

  assertEqual('Status 200', r1.status, 200);
  assertEqual('ok = true',  r1.body?.ok, true);
  assertEqual('code = TEACHER_MAP_OK', r1.body?.code, 'TEACHER_MAP_OK');

  const d1 = r1.body?.data ?? {};
  assert('teacher object present', !!d1.teacher);
  assertEqual('teacher.kadi matches', d1.teacher?.kadi, T1.kadi);
  assertEqual('teacher.isim matches', d1.teacher?.isim, T1.isim);
  assert('teacher has photo', !!d1.teacher?.resim);

  assertEqual('total_links = 20', d1.total_links, 20);
  assertEqual('4 cohorts', d1.cohorts?.length, 4);

  const c1Labels = d1.cohorts?.map(c => c.label) ?? [];
  assert('cohort 2024 present', c1Labels.includes('2024'));
  assert('cohort 2022 present', c1Labels.includes('2022'));
  assert('cohort 2019 present', c1Labels.includes('2019'));
  assert('cohort 2016 present', c1Labels.includes('2016'));

  const c1_2024 = d1.cohorts?.find(c => c.label === '2024');
  assertEqual('2024 cohort has 8 members', c1_2024?.members?.length, 8);

  let allHavePhoto1 = true, allHaveName1 = true;
  for (const cohort of d1.cohorts ?? []) {
    for (const m of cohort.members ?? []) {
      if (!m.resim) allHavePhoto1 = false;
      if (!m.isim || !m.soyisim) allHaveName1 = false;
    }
  }
  assert('All members have profile photo', allHavePhoto1);
  assert('All members have Turkish name (isim + soyisim)', allHaveName1);

  // Check cohort member counts
  const expected1 = { '2024': 8, '2022': 5, '2019': 4, '2016': 3 };
  for (const [label, count] of Object.entries(expected1)) {
    const c = d1.cohorts?.find(x => x.label === label);
    assertEqual(`  ${label}: ${count} members`, c?.members?.length, count);
  }

  // ── 3. Teacher 2 map (50 links / 8 cohorts) ──────────────────────────────────
  section(`3. Teacher 2 map — ${T2.isim} ${T2.soyisim} (${T2.kadi})`);
  const r2 = await request('GET', `/api/new/teachers/${T2.id}/map`, null, jar);

  assertEqual('Status 200', r2.status, 200);
  assertEqual('ok = true',  r2.body?.ok, true);
  const d2 = r2.body?.data ?? {};

  assertEqual('teacher.kadi matches', d2.teacher?.kadi, T2.kadi);
  assertEqual('total_links = 50', d2.total_links, 50);
  assertEqual('8 cohorts', d2.cohorts?.length, 8);

  const expected2 = { '2024': 10, '2023': 7, '2022': 9, '2020': 6, '2018': 8, '2016': 5, '2014': 3, 'Belirtilmemiş': 2 };
  for (const [label, count] of Object.entries(expected2)) {
    const c = d2.cohorts?.find(x => x.label === label);
    assertEqual(`  ${label}: ${count} members`, c?.members?.length, count);
  }

  const noYearCohort = d2.cohorts?.find(c => c.type === 'no_year');
  assert('Belirtilmemiş cohort type=no_year', noYearCohort?.type === 'no_year');

  let allHavePhoto2 = true, allHaveName2 = true;
  for (const cohort of d2.cohorts ?? []) {
    for (const m of cohort.members ?? []) {
      if (!m.resim) allHavePhoto2 = false;
      if (!m.isim || !m.soyisim) allHaveName2 = false;
    }
  }
  assert('All 50 members have profile photo', allHavePhoto2);
  assert('All 50 members have Turkish name', allHaveName2);

  // Print first member of each cohort as spot-check
  console.log('\n  Cohort spot-check:');
  for (const c of d2.cohorts ?? []) {
    const m = c.members?.[0];
    console.log(`    ${c.label.padEnd(16)} ${c.members.length} üye — ilk: ${m?.isim} ${m?.soyisim}`);
  }

  // ── 4. Edge cases ─────────────────────────────────────────────────────────────
  section('4. Edge cases');

  const r404 = await request('GET', '/api/new/teachers/999999/map', null, jar);
  assertEqual('Non-existent teacher → 404', r404.status, 404);
  assertEqual('TEACHER_NOT_FOUND code', r404.body?.code, 'TEACHER_NOT_FOUND');

  const rBad = await request('GET', '/api/new/teachers/0/map', null, jar);
  assertEqual('teacherId=0 → 400', rBad.status, 400);
  assertEqual('INVALID_TEACHER_ID code', rBad.body?.code, 'INVALID_TEACHER_ID');

  // Member (not a teacher) queried as teacher
  const memberKadi = 'test_uye_00';
  const memberLogin = await request('POST', '/api/auth/login', { kadi: memberKadi, sifre: password }, {});
  // Fetch member id from response
  const memberId = memberLogin.body?.user?.id;
  if (memberId) {
    const rMemberAsTeacher = await request('GET', `/api/new/teachers/${memberId}/map`, null, jar);
    assert('Non-teacher user as teacher → 404', rMemberAsTeacher.status === 404, `status=${rMemberAsTeacher.status}`);
  }

  // ── 5. Teacher options list ───────────────────────────────────────────────────
  section('5. Teacher options list');
  const rOpts = await request('GET', '/api/new/teachers/options', null, jar);
  assertEqual('Status 200', rOpts.status, 200);
  // data.items holds the teacher list for this endpoint
  const optItems = rOpts.body?.data?.items ?? rOpts.body?.items ?? [];
  assert('teachers array present', Array.isArray(optItems), `keys=${JSON.stringify(Object.keys(rOpts.body?.data ?? {}))}`);
  const optHandles = optItems.map(t => t.kadi);
  assert(`${T1.kadi} in options`, optHandles.includes(T1.kadi));
  assert(`${T2.kadi} in options`, optHandles.includes(T2.kadi));

  // ── Summary ───────────────────────────────────────────────────────────────────
  section('Summary');
  const total = passed + failed;
  console.log(`  ${passed}/${total} passed${failed > 0 ? `  (${failed} failed)` : ''}\n`);
  process.exit(failed > 0 ? 1 : 0);
}

run().catch(err => {
  console.error('\n❌ Unexpected error:', err.message);
  process.exit(1);
});
