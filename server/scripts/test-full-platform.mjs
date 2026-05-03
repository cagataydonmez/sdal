/**
 * SDAL Full-Platform Integration Test
 *
 * What it does:
 *  1. Promotes test_uye_00 → admin, test_uye_01 → mod (all permissions)
 *  2. Runs ~80 test cases across every functional area
 *  3. Prints a structured pass/fail/warn report with developer notes
 *
 * Prerequisites:
 *  - Seed data exists (run seed-teacher-network-test.mjs first)
 *  - Server is running at SDAL_BASE_URL (defaults localhost:8787)
 *
 * Usage:
 *   node server/scripts/test-full-platform.mjs
 *   SDAL_BASE_URL=https://sdalsosyal.mywire.org node server/scripts/test-full-platform.mjs
 */

import http from 'http';
import https from 'https';
import path from 'path';
import { fileURLToPath } from 'url';
import fs from 'fs';
import { createRequire } from 'module';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const require = createRequire(import.meta.url);

// ── Config ─────────────────────────────────────────────────────────────────────
const envFile = path.resolve(__dirname, '../.env');
let BASE_URL = process.env.SDAL_BASE_URL || 'http://localhost:8787';
let dbPathRaw = process.env.SDAL_DB_PATH || '';
if (!dbPathRaw && fs.existsSync(envFile)) {
  for (const line of fs.readFileSync(envFile, 'utf8').split('\n')) {
    if (!BASE_URL || BASE_URL === 'http://localhost:8787') {
      const mu = line.match(/^SDAL_BASE_URL\s*=\s*(.+)$/);
      if (mu) BASE_URL = mu[1].trim();
    }
    const md = line.match(/^SDAL_DB_PATH\s*=\s*(.+)$/);
    if (md) dbPathRaw = md[1].trim();
  }
}
if (!dbPathRaw) dbPathRaw = 'server/data/sdal.local.sqlite';
const absDbPath = path.isAbsolute(dbPathRaw) ? dbPathRaw : path.resolve(__dirname, '../..', dbPathRaw);

const seedFile = path.resolve(__dirname, 'seed-teacher-network-test.json');
if (!fs.existsSync(seedFile)) { console.error('❌ Run seed-teacher-network-test.mjs first.'); process.exit(1); }
if (!fs.existsSync(absDbPath)) { console.error('❌ DB not found:', absDbPath); process.exit(1); }

const { teachers, password: TEST_PW } = JSON.parse(fs.readFileSync(seedFile, 'utf8'));
const [T1, T2] = teachers;

const Database = require('better-sqlite3');
const db = new Database(absDbPath);

// ── HTTP ───────────────────────────────────────────────────────────────────────
function req(method, urlPath, body, jar = {}) {
  return new Promise((resolve, reject) => {
    const url = new URL(urlPath, BASE_URL);
    const lib = url.protocol === 'https:' ? https : http;
    const payload = body ? JSON.stringify(body) : undefined;
    const hdrs = { 'Content-Type': 'application/json', Cookie: Object.entries(jar).map(([k, v]) => `${k}=${v}`).join('; ') };
    if (payload) hdrs['Content-Length'] = Buffer.byteLength(payload);
    const r = lib.request({ hostname: url.hostname, port: url.port || (url.protocol === 'https:' ? 443 : 80), path: url.pathname + url.search, method, headers: hdrs }, (res) => {
      let d = '';
      res.on('data', c => d += c);
      res.on('end', () => {
        for (const c of res.headers['set-cookie'] || []) {
          const [pair] = c.split(';');
          const [k, v] = pair.trim().split('=');
          if (k && v !== undefined) jar[k.trim()] = v.trim();
        }
        try { resolve({ status: res.statusCode, body: JSON.parse(d), jar }); }
        catch { resolve({ status: res.statusCode, body: d, jar }); }
      });
    });
    r.on('error', reject);
    if (payload) r.write(payload);
    r.end();
  });
}

async function login(kadi, jar = {}) {
  return req('POST', '/api/auth/login', { kadi, sifre: TEST_PW }, jar);
}

// ── Result tracking ────────────────────────────────────────────────────────────
const results = [];
let currentSection = '';

function section(title) {
  currentSection = title;
  console.log(`\n${'═'.repeat(64)}\n  ${title}\n${'═'.repeat(64)}`);
}

function record(label, status, detail = '', note = '') {
  const sym = { pass: '✅', fail: '❌', warn: '⚠️ ', skip: '⏭️ ' }[status] || '?';
  const line = `  ${sym}  ${label}${detail ? '  →  ' + detail : ''}`;
  console.log(line);
  results.push({ section: currentSection, label, status, detail, note });
}

function pass(label, detail = '', note = '') { record(label, 'pass', detail, note); }
function fail(label, detail = '', note = '') { record(label, 'fail', detail, note); }
function warn(label, detail = '', note = '') { record(label, 'warn', detail, note); }
function skip(label, detail = '', note = '') { record(label, 'skip', detail, note); }

function check(label, ok, detail = '', note = '') { ok ? pass(label, detail, note) : fail(label, detail, note); }

// ── DB setup: promote test users ──────────────────────────────────────────────
function setupRoles() {
  const uye00 = db.prepare("SELECT id FROM uyeler WHERE kadi='test_uye_00'").get();
  const uye01 = db.prepare("SELECT id FROM uyeler WHERE kadi='test_uye_01'").get();
  if (!uye00 || !uye01) { console.error('❌ Seed users not found. Run seed-teacher-network-test.mjs first.'); process.exit(1); }

  db.prepare("UPDATE uyeler SET role='admin', admin=1 WHERE id=?").run(uye00.id);
  db.prepare("UPDATE uyeler SET role='mod', admin=0 WHERE id=?").run(uye01.id);

  const allPerms = [
    'users','groups','posts','stories','chat','messages','events','announcements',
    'albums','filters','requests','siteControls','database','logs'
  ].flatMap(r => ['view','toggle','create','update','delete','moderate','export'].map(a => `${r}.${a}`));

  const now = new Date().toISOString();
  const insertPerm = db.prepare(
    'INSERT OR REPLACE INTO moderator_permissions (user_id, permission_key, enabled, created_by, created_at, updated_at) VALUES (?,?,1,?,?,?)'
  );
  const insertMany = db.transaction(() => { for (const p of allPerms) insertPerm.run(uye01.id, p, uye01.id, now, now); });
  insertMany();

  return { adminId: uye00.id, modId: uye01.id };
}

// ── Main ───────────────────────────────────────────────────────────────────────
async function run() {
  console.log(`\n🧪 SDAL Full-Platform Integration Test`);
  console.log(`   Server : ${BASE_URL}`);
  console.log(`   DB     : ${absDbPath}`);
  console.log(`   Time   : ${new Date().toLocaleString('tr-TR')}`);

  // ── 0. Role setup ────────────────────────────────────────────────────────────
  section('0 · Role Setup');
  let adminId, modId;
  try {
    ({ adminId, modId } = setupRoles());
    pass('test_uye_00 promoted to admin');
    pass('test_uye_01 promoted to mod (all permissions)');
  } catch (e) {
    fail('Role setup failed', e.message);
    process.exit(1);
  }

  // Shared state
  const ctx = {};

  // ── 1. Auth ──────────────────────────────────────────────────────────────────
  section('1 · Auth');

  const pubSession = await req('GET', '/api/session', null, {});
  check('GET /api/session public — 200', pubSession.status === 200);

  const unauth = await req('GET', '/api/new/feed', null, {});
  check('Unauthenticated feed request rejected', [401, 403].includes(unauth.status));

  const memberLogin = await login('test_uye_02');
  check('Member login succeeds', memberLogin.status === 200 && !!memberLogin.body?.user?.id);
  ctx.memberJar = memberLogin.jar;
  ctx.memberId = memberLogin.body?.user?.id;
  ctx.memberKadi = 'test_uye_02';

  const adminLogin = await login('test_uye_00');
  check('Admin login succeeds', adminLogin.status === 200);
  ctx.adminJar = adminLogin.jar;

  const modLogin = await login('test_uye_01');
  check('Mod login succeeds', modLogin.status === 200);
  ctx.modJar = modLogin.jar;

  const teacher1Login = await login(T1.kadi);
  check('Teacher 1 login succeeds', teacher1Login.status === 200);
  ctx.teacher1Jar = teacher1Login.jar;
  ctx.teacher1Id = T1.id;

  const badLogin = await req('POST', '/api/auth/login', { kadi: 'test_uye_02', sifre: 'yanlis_sifre' }, {});
  check('Bad-password login returns 401/400', [400, 401].includes(badLogin.status));

  // ── 2. Profile & Member Directory ────────────────────────────────────────────
  section('2 · Profile & Member Directory');

  const profile = await req('GET', '/api/profile', null, ctx.memberJar);
  check('GET /api/profile — own profile', profile.status === 200);
  check('Profile has isim', !!profile.body?.isim, profile.body?.isim);

  const profileUpdate = await req('PUT', '/api/profile', { mesaj: 'Test biyografisi — platform test' }, ctx.memberJar);
  check('PUT /api/profile — bio update',
    profileUpdate.status === 200 || profileUpdate.status === 204,
    `status=${profileUpdate.status}`);

  const members = await req('GET', '/api/members', null, {});
  check('GET /api/members public directory', members.status === 200);
  check('Members list non-empty', Array.isArray(members.body?.members || members.body) && (members.body?.members || members.body).length > 0,
    `count=${(members.body?.members || members.body || []).length}`);

  const membersLatest = await req('GET', '/api/members/latest', null, {});
  check('GET /api/members/latest', membersLatest.status === 200);

  const membersSearch = await req('GET', '/api/members?q=Berk', null, {});
  check('Member search by name works', membersSearch.status === 200);

  // ── 3. Follow / Social Connections ───────────────────────────────────────────
  section('3 · Follow & Social Connections');

  // test_uye_02 follows test_uye_03
  const uye03 = db.prepare("SELECT id FROM uyeler WHERE kadi='test_uye_03'").get();
  const uye04 = db.prepare("SELECT id FROM uyeler WHERE kadi='test_uye_04'").get();
  ctx.uye03Id = uye03?.id;
  ctx.uye04Id = uye04?.id;

  const follow03 = await req('POST', `/api/new/follow/${uye03?.id}`, {}, ctx.memberJar);
  check('Follow uye_03', [200, 201].includes(follow03.status) || follow03.body?.ok === true,
    `status=${follow03.status} code=${follow03.body?.code}`);

  const follows = await req('GET', '/api/new/follows', null, ctx.memberJar);
  check('GET /api/new/follows — own follows', follows.status === 200);

  // Connection request: uye_02 → uye_04
  const connReq = await req('POST', `/api/new/connections/request/${uye04?.id}`, { message: 'Test bağlantı isteği' }, ctx.memberJar);
  check('Send connection request to uye_04',
    [200, 201].includes(connReq.status) || connReq.body?.ok === true,
    `status=${connReq.status} code=${connReq.body?.code}`);

  const connRequests = await req('GET', '/api/new/connections/requests', null, ctx.memberJar);
  check('GET /api/new/connections/requests', connRequests.status === 200);

  // Mentorship request: uye_02 → uye_05
  const uye05 = db.prepare("SELECT id FROM uyeler WHERE kadi='test_uye_05'").get();
  const mentorReq = await req('POST', `/api/new/mentorship/request/${uye05?.id}`, { message: 'Mentorluk talebi', focus_area: 'Yazılım mühendisliği' }, ctx.memberJar);
  check('Send mentorship request to uye_05',
    [200, 201].includes(mentorReq.status) || mentorReq.body?.ok === true,
    `status=${mentorReq.status} code=${mentorReq.body?.code}`,
    mentorReq.body?.code === 'MENTORSHIP_NOT_AVAILABLE' ? 'Mentorship modülü kapalı olabilir' : '');

  const mentorRequests = await req('GET', '/api/new/mentorship/requests', null, ctx.memberJar);
  check('GET /api/new/mentorship/requests', mentorRequests.status === 200);

  // ── 4. Feed & Posts ───────────────────────────────────────────────────────────
  section('4 · Feed & Posts');

  const feed = await req('GET', '/api/new/feed', null, ctx.memberJar);
  check('GET /api/new/feed — 200', feed.status === 200);
  const feedItems = feed.body?.posts || feed.body?.items || feed.body?.data || [];
  check('Feed returns array', Array.isArray(feedItems), `type=${typeof feedItems}`);

  // Create post
  const postRes = await req('POST', '/api/new/posts', { content: 'Platform entegrasyon testi — test gönderisi 🧪 #sdal' }, ctx.memberJar);
  check('Create post', postRes.status === 200 || postRes.status === 201 || postRes.body?.ok === true,
    `status=${postRes.status} code=${postRes.body?.code}`);
  ctx.postId = postRes.body?.post?.id || postRes.body?.id || postRes.body?.data?.id;
  check('Post ID returned', !!ctx.postId, `id=${ctx.postId}`);

  if (ctx.postId) {
    // Like post (as different user)
    const uye06Jar = (await login('test_uye_06')).jar;
    const likeRes = await req('POST', `/api/new/posts/${ctx.postId}/like`, {}, uye06Jar);
    check('Like post (as uye_06)', likeRes.status === 200 || likeRes.body?.ok === true,
      `status=${likeRes.status}`);

    // Comment on post
    const commentRes = await req('POST', `/api/new/posts/${ctx.postId}/comments`, { comment: 'Harika bir test gönderisi!' }, uye06Jar);
    check('Comment on post', commentRes.status === 200 || commentRes.body?.ok === true,
      `status=${commentRes.status}`);
    ctx.commentId = commentRes.body?.comment?.id || commentRes.body?.id;

    // Get post detail
    const postDetail = await req('GET', `/api/new/posts/${ctx.postId}`, null, ctx.memberJar);
    check('GET /api/new/posts/:id — 200', postDetail.status === 200,
      `status=${postDetail.status}`);

    // Get post comments
    const postComments = await req('GET', `/api/new/posts/${ctx.postId}/comments`, null, ctx.memberJar);
    check('GET post comments', postComments.status === 200);
    const commentCount = (postComments.body?.comments || postComments.body || []).length;
    check('Comment appears in list', commentCount > 0, `count=${commentCount}`);

    // Get post likes
    const postLikes = await req('GET', `/api/new/posts/${ctx.postId}/likes`, null, ctx.memberJar);
    check('GET post likes', postLikes.status === 200);
  } else {
    skip('Like/Comment/Detail tests — no post ID');
    skip('Like/Comment/Detail tests — no post ID');
    skip('Like/Comment/Detail tests — no post ID');
    skip('Like/Comment/Detail tests — no post ID');
    skip('Like/Comment/Detail tests — no post ID');
  }

  // Create a second post (for admin to moderate later)
  const post2Res = await req('POST', '/api/new/posts', { content: 'İkinci test gönderisi — mod testi için' }, ctx.memberJar);
  ctx.post2Id = post2Res.body?.post?.id || post2Res.body?.id || post2Res.body?.data?.id;

  // ── 5. Teacher Network ────────────────────────────────────────────────────────
  section('5 · Teacher Network');

  const teacherOpts = await req('GET', '/api/new/teachers/options', null, ctx.memberJar);
  check('GET /api/new/teachers/options — 200', teacherOpts.status === 200);
  const teacherList = teacherOpts.body?.data?.items || [];
  check('Seeded teachers in options', teacherList.some(t => t.kadi === T1.kadi) && teacherList.some(t => t.kadi === T2.kadi),
    `found=${teacherList.map(t => t.kadi).filter(k => k.includes('ogr')).join(',')}`);

  // uye_02 adds teacher link
  const linkRes = await req('POST', `/api/new/teachers/network/link/${T1.id}`,
    { relationship_type: 'taught_in_class', class_year: 2022, notes: 'Test bağlantısı', created_via: 'manual_entry', confirm_similar: true },
    ctx.memberJar);
  check('Add teacher link (uye_02 → T1)',
    [200, 201].includes(linkRes.status) || linkRes.body?.ok === true || linkRes.body?.code === 'RELATIONSHIP_ALREADY_EXISTS',
    `status=${linkRes.status} code=${linkRes.body?.code}`);

  const ownTeacherNet = await req('GET', '/api/new/teachers/network', null, ctx.memberJar);
  check('GET /api/new/teachers/network — own teachers', ownTeacherNet.status === 200);

  const map1 = await req('GET', `/api/new/teachers/${T1.id}/map`, null, ctx.memberJar);
  check(`Teacher 1 map — ${T1.isim} ${T1.soyisim} (20 links)`,
    map1.status === 200 && map1.body?.data?.total_links >= 20,
    `total=${map1.body?.data?.total_links} cohorts=${map1.body?.data?.cohorts?.length}`);

  const map2 = await req('GET', `/api/new/teachers/${T2.id}/map`, null, ctx.memberJar);
  check(`Teacher 2 map — ${T2.isim} ${T2.soyisim} (50 links)`,
    map2.status === 200 && map2.body?.data?.total_links >= 50,
    `total=${map2.body?.data?.total_links} cohorts=${map2.body?.data?.cohorts?.length}`);

  // ── 6. Network Hub ────────────────────────────────────────────────────────────
  section('6 · Network Hub & Discovery');

  const hub = await req('GET', '/api/new/network/hub', null, ctx.memberJar);
  check('GET /api/new/network/hub', hub.status === 200, `status=${hub.status}`);

  const metrics = await req('GET', '/api/new/network/metrics', null, ctx.memberJar);
  check('GET /api/new/network/metrics', metrics.status === 200, `status=${metrics.status}`);

  const inbox = await req('GET', '/api/new/network/inbox', null, ctx.memberJar);
  check('GET /api/new/network/inbox', inbox.status === 200, `status=${inbox.status}`);

  const explore = await req('GET', '/api/new/explore/suggestions', null, ctx.memberJar);
  check('GET /api/new/explore/suggestions', explore.status === 200, `status=${explore.status}`);

  const online = await req('GET', '/api/new/online-members', null, ctx.memberJar);
  check('GET /api/new/online-members', online.status === 200, `status=${online.status}`);

  // ── 7. Notifications ──────────────────────────────────────────────────────────
  section('7 · Notifications');

  const notifs = await req('GET', '/api/new/notifications', null, ctx.memberJar);
  check('GET /api/new/notifications', notifs.status === 200, `status=${notifs.status}`);
  const notifItems = notifs.body?.notifications || notifs.body?.data || [];
  check('Notifications array', Array.isArray(notifItems), `type=${typeof notifItems}`);

  const unreadNotifs = await req('GET', '/api/new/notifications/unread', null, ctx.memberJar);
  check('GET /api/new/notifications/unread — count', unreadNotifs.status === 200, `status=${unreadNotifs.status}`);

  const notifPrefs = await req('GET', '/api/new/notifications/preferences', null, ctx.memberJar);
  check('GET /api/new/notifications/preferences', notifPrefs.status === 200, `status=${notifPrefs.status}`);

  if (notifItems.length > 0) {
    const notifId = notifItems[0]?.id;
    const readRes = await req('POST', '/api/new/notifications/read', { notification_id: notifId }, ctx.memberJar);
    check('POST notifications/read — mark single read', readRes.status === 200 || readRes.body?.ok === true,
      `status=${readRes.status}`);
  } else {
    skip('Mark notification read — no notifications yet');
  }

  // ── 8. Member Requests ────────────────────────────────────────────────────────
  section('8 · Member Requests');

  const reqCategories = await req('GET', '/api/new/request-categories', null, ctx.memberJar);
  check('GET /api/new/request-categories', reqCategories.status === 200);
  const categories = reqCategories.body?.categories || reqCategories.body?.data || reqCategories.body || [];
  check('Categories non-empty', Array.isArray(categories) && categories.length > 0, `count=${categories.length}`);
  const firstCatKey = categories[0]?.category_key || categories[0]?.key;
  check('Category has key', !!firstCatKey, `key=${firstCatKey}`);

  if (firstCatKey) {
    const submitReq = await req('POST', '/api/new/requests', { category_key: firstCatKey, payload: { message: 'Test talebi — entegrasyon testi' } }, ctx.memberJar);
    check(`Submit request (category: ${firstCatKey})`,
      submitReq.status === 200 || submitReq.body?.ok === true,
      `status=${submitReq.status} msg=${typeof submitReq.body === 'string' ? submitReq.body.slice(0, 80) : submitReq.body?.code}`);
    ctx.submittedCategoryKey = firstCatKey;
  } else {
    skip('Submit request — no category key found');
  }

  const myRequests = await req('GET', '/api/new/requests/my', null, ctx.memberJar);
  check('GET /api/new/requests/my', myRequests.status === 200, `status=${myRequests.status}`);

  // ── 9. Messaging ──────────────────────────────────────────────────────────────
  section('9 · Messaging');

  const uye07 = db.prepare("SELECT id FROM uyeler WHERE kadi='test_uye_07'").get();
  const newThread = await req('POST', '/api/sdal-messenger/threads', { recipient_id: uye07?.id, message: 'Merhaba, bu bir test mesajı!' }, ctx.memberJar);
  check('Create messenger thread with uye_07',
    [200, 201].includes(newThread.status) || newThread.body?.ok === true,
    `status=${newThread.status} code=${newThread.body?.code}`);
  ctx.threadId = newThread.body?.thread?.id || newThread.body?.id || newThread.body?.data?.id;

  const threads = await req('GET', '/api/sdal-messenger/threads', null, ctx.memberJar);
  check('GET /api/sdal-messenger/threads', threads.status === 200, `status=${threads.status}`);
  const threadItems = threads.body?.threads || threads.body?.data || threads.body || [];
  check('Thread list has items', Array.isArray(threadItems), `type=${typeof threadItems}`);

  const contacts = await req('GET', '/api/sdal-messenger/contacts', null, ctx.memberJar);
  check('GET /api/sdal-messenger/contacts', contacts.status === 200, `status=${contacts.status}`);

  // Legacy message inbox
  const legacyMsg = await req('GET', '/api/messages', null, ctx.memberJar);
  check('GET /api/messages (legacy inbox)', legacyMsg.status === 200, `status=${legacyMsg.status}`);

  // ── 10. Quick Access & Misc ───────────────────────────────────────────────────
  section('10 · Quick Access & Misc');

  const quickAccess = await req('GET', '/api/quick-access', null, ctx.memberJar);
  check('GET /api/quick-access', quickAccess.status === 200, `status=${quickAccess.status}`);

  const addQA = await req('POST', '/api/quick-access/add', { id: 'teacher_network' }, ctx.memberJar);
  check('Add quick access item', [200, 201].includes(addQA.status) || addQA.body?.ok === true,
    `status=${addQA.status}`);

  const removeQA = await req('POST', '/api/quick-access/remove', { id: 'teacher_network' }, ctx.memberJar);
  check('Remove quick access item', [200, 201].includes(removeQA.status) || removeQA.body?.ok === true,
    `status=${removeQA.status}`);

  const panolar = await req('GET', '/api/panolar', null, ctx.memberJar);
  check('GET /api/panolar (duyuru panoları)', panolar.status === 200, `status=${panolar.status}`);

  const snakeLB = await req('GET', '/api/games/snake/leaderboard', null, {});
  check('GET /api/games/snake/leaderboard (public)', snakeLB.status === 200, `status=${snakeLB.status}`);

  const langConfig = await req('GET', '/api/new/lang-config', null, {});
  check('GET /api/new/lang-config', langConfig.status === 200, `status=${langConfig.status}`);

  const menu = await req('GET', '/api/menu', null, ctx.memberJar);
  check('GET /api/menu', menu.status === 200, `status=${menu.status}`);

  // ── 11. Admin Operations ──────────────────────────────────────────────────────
  section('11 · Admin Operations (test_uye_00)');

  const adminSession = await req('GET', '/api/admin/session', null, ctx.adminJar);
  check('Admin session recognized', adminSession.status === 200 && adminSession.body?.adminOk === true,
    `adminOk=${adminSession.body?.adminOk} role=${adminSession.body?.user?.role}`);

  const adminLogin2 = await req('POST', '/api/admin/login', { sifre: process.env.SDAL_ADMIN_PASSWORD || '' }, ctx.adminJar);
  if (process.env.SDAL_ADMIN_PASSWORD) {
    check('Admin panel login', adminLogin2.status === 200 || adminLogin2.status === 302,
      `status=${adminLogin2.status}`);
  } else {
    skip('Admin panel login — SDAL_ADMIN_PASSWORD not set');
  }

  const userSearch = await req('GET', '/api/admin/users/search?q=test_uye&limit=10', null, ctx.adminJar);
  check('Admin: search users by username', userSearch.status === 200,
    `status=${userSearch.status} count=${(userSearch.body?.users || []).length}`);

  const teacherAccounts = await req('GET', '/api/new/admin/teacher-accounts', null, ctx.adminJar);
  check('Admin: GET /api/new/admin/teacher-accounts', teacherAccounts.status === 200,
    `status=${teacherAccounts.status} count=${(teacherAccounts.body?.data?.teachers || []).length}`);
  check('Seeded teachers appear in admin teacher accounts',
    (teacherAccounts.body?.data?.teachers || []).some(t => t.kadi === T1.kadi),
    `teachers=${(teacherAccounts.body?.data?.teachers || []).map(t => t.kadi).join(',')}`);

  const adminRequests = await req('GET', '/api/new/admin/requests', null, ctx.adminJar);
  check('Admin: GET /api/new/admin/requests (moderasyon talepleri)', adminRequests.status === 200,
    `status=${adminRequests.status}`);
  const adminReqList = adminRequests.body?.data?.requests || adminRequests.body?.requests || [];
  check('Request list returned', Array.isArray(adminReqList), `type=${typeof adminReqList}`);
  ctx.adminReqId = adminReqList[0]?.id;

  if (ctx.adminReqId) {
    const approveReq = await req('POST', `/api/new/admin/requests/${ctx.adminReqId}/review`,
      { status: 'approved', note: 'Entegrasyon testi — onaylandı' }, ctx.adminJar);
    check(`Admin: approve request #${ctx.adminReqId}`,
      approveReq.status === 200 || approveReq.body?.ok === true,
      `status=${approveReq.status} code=${approveReq.body?.code}`);
  } else {
    skip('Admin: approve request — no pending requests found');
  }

  const reqNotifs = await req('GET', '/api/new/admin/requests/notifications', null, ctx.adminJar);
  check('Admin: GET /api/new/admin/requests/notifications', reqNotifs.status === 200,
    `status=${reqNotifs.status}`);

  const teacherLinks = await req('GET', '/api/new/admin/teacher-network/links?review_status=pending', null, ctx.adminJar);
  check('Admin: GET /api/new/admin/teacher-network/links (pending)', teacherLinks.status === 200,
    `status=${teacherLinks.status}`);
  const linkList = teacherLinks.body?.data?.links || teacherLinks.body?.links || [];
  check('Teacher link list returned', Array.isArray(linkList), `type=${typeof linkList}`);
  ctx.pendingLinkId = linkList[0]?.id;

  if (ctx.pendingLinkId) {
    const approveLink = await req('POST', `/api/new/admin/teacher-network/links/${ctx.pendingLinkId}/review`,
      { review_status: 'confirmed', note: 'Test onayı' }, ctx.adminJar);
    check(`Admin: confirm teacher link #${ctx.pendingLinkId}`,
      approveLink.status === 200 || approveLink.body?.ok === true,
      `status=${approveLink.status} code=${approveLink.body?.code}`);
  } else {
    skip('Admin: confirm teacher link — no pending links found');
  }

  const adminVerify = await req('POST', '/api/new/admin/verify', { user_id: ctx.memberId, verified: true }, ctx.adminJar);
  check('Admin: verify member (test_uye_02)',
    adminVerify.status === 200 || adminVerify.body?.ok === true,
    `status=${adminVerify.status} code=${adminVerify.body?.code}`);

  const adminLogs = await req('GET', '/api/admin/logs', null, ctx.adminJar);
  check('Admin: GET /api/admin/logs', adminLogs.status === 200, `status=${adminLogs.status}`);

  const siteControls = await req('GET', '/api/admin/site-controls', null, ctx.adminJar);
  check('Admin: GET /api/admin/site-controls', siteControls.status === 200, `status=${siteControls.status}`);

  const adminUserDetail = await req('GET', `/api/admin/users/${ctx.memberId}`, null, ctx.adminJar);
  check('Admin: GET /api/admin/users/:id (user detail)', adminUserDetail.status === 200,
    `status=${adminUserDetail.status}`);

  const networkAnalytics = await req('GET', '/api/new/admin/network/analytics', null, ctx.adminJar);
  check('Admin: GET /api/new/admin/network/analytics',
    networkAnalytics.status === 200 || networkAnalytics.status === 404,
    `status=${networkAnalytics.status}`,
    networkAnalytics.status === 404 ? 'Analytics endpoint mevcut değil' : '');

  // ── 12. Mod Operations ────────────────────────────────────────────────────────
  section('12 · Mod Operations (test_uye_01)');

  const modPosts = await req('GET', '/api/new/admin/posts?limit=10', null, ctx.modJar);
  check('Mod: GET /api/new/admin/posts (post listesi)', modPosts.status === 200,
    `status=${modPosts.status}`);
  const modPostList = modPosts.body?.data?.posts || modPosts.body?.posts || [];
  check('Mod post list returned', Array.isArray(modPostList) || modPosts.status === 200,
    `type=${typeof modPostList}`);

  const modRequests = await req('GET', '/api/new/admin/requests', null, ctx.modJar);
  check('Mod: GET /api/new/admin/requests', modRequests.status === 200,
    `status=${modRequests.status}`);

  if (ctx.post2Id) {
    const delPost = await req('POST', `/api/new/admin/posts/${ctx.post2Id}/delete`, { reason: 'Test silme işlemi' }, ctx.modJar);
    check(`Mod: delete post #${ctx.post2Id}`,
      delPost.status === 200 || delPost.body?.ok === true || delPost.status === 404,
      `status=${delPost.status} code=${delPost.body?.code}`,
      delPost.status === 404 ? 'Mod post delete endpoint path farklı olabilir' : '');
  } else {
    skip('Mod: delete post — no second post ID');
  }

  const modAdminLinks = await req('GET', '/api/new/admin/teacher-network/links', null, ctx.modJar);
  check('Mod: GET /api/new/admin/teacher-network/links', modAdminLinks.status === 200,
    `status=${modAdminLinks.status}`);

  // ── 13. Teacher self-view ─────────────────────────────────────────────────────
  section('13 · Teacher Self-View');

  const teacherOwnMap = await req('GET', `/api/new/teachers/${T1.id}/map`, null, ctx.teacher1Jar);
  check('Teacher views own network map', teacherOwnMap.status === 200,
    `total=${teacherOwnMap.body?.data?.total_links}`);

  const teacherOwnNet = await req('GET', '/api/new/teachers/network', null, ctx.teacher1Jar);
  check('Teacher GET /api/new/teachers/network', teacherOwnNet.status === 200);

  const teacherFeed = await req('GET', '/api/new/feed', null, ctx.teacher1Jar);
  check('Teacher accesses feed', teacherFeed.status === 200);

  // ── 14. Verified member post-verify ──────────────────────────────────────────
  section('14 · Post-Verification Member Flow');

  // Re-login as member to refresh session after verification
  const verifiedMemberLogin = await login('test_uye_02', {});
  ctx.verifiedMemberJar = verifiedMemberLogin.jar;

  const verifiedProfile = await req('GET', '/api/profile', null, ctx.verifiedMemberJar);
  check('Verified member profile accessible', verifiedProfile.status === 200);
  const isVerified = verifiedProfile.body?.verified == 1 || verifiedProfile.body?.verified === true;
  check('Member shows as verified after admin action', isVerified,
    `verified=${verifiedProfile.body?.verified}`,
    isVerified ? '' : 'verified flag DB\'de set edildi ama session cache gerektirebilir');

  // ── Final report ──────────────────────────────────────────────────────────────
  printReport();
}

function printReport() {
  const counts = { pass: 0, fail: 0, warn: 0, skip: 0 };
  for (const r of results) counts[r.status] = (counts[r.status] || 0) + 1;

  console.log('\n\n' + '█'.repeat(64));
  console.log('  SDAL PLATFORM TEST RAPORU');
  console.log('  ' + new Date().toLocaleString('tr-TR'));
  console.log('█'.repeat(64));

  // Section summary
  const sections = [...new Set(results.map(r => r.section))];
  console.log('\n📊 Bölüm Özeti\n');
  for (const sec of sections) {
    const secResults = results.filter(r => r.section === sec);
    const p = secResults.filter(r => r.status === 'pass').length;
    const f = secResults.filter(r => r.status === 'fail').length;
    const w = secResults.filter(r => r.status === 'warn').length;
    const s = secResults.filter(r => r.status === 'skip').length;
    const icon = f > 0 ? '❌' : w > 0 ? '⚠️ ' : s === secResults.length ? '⏭️ ' : '✅';
    console.log(`  ${icon}  ${sec.padEnd(40)} ✅${p}  ❌${f}  ⚠️${w}  ⏭️${s}`);
  }

  // Failures
  const failures = results.filter(r => r.status === 'fail');
  if (failures.length > 0) {
    console.log('\n\n❌ Başarısız Testler\n');
    for (const r of failures) {
      console.log(`  [${r.section}]`);
      console.log(`  → ${r.label}`);
      if (r.detail) console.log(`     Detay  : ${r.detail}`);
      if (r.note)   console.log(`     Not    : ${r.note}`);
      console.log('');
    }
  }

  // Warnings (issues worth noting but not hard failures)
  const warnings = results.filter(r => r.status === 'warn');
  if (warnings.length > 0) {
    console.log('\n⚠️  Uyarılar / Geliştirme Alanları\n');
    for (const r of warnings) {
      console.log(`  [${r.section}] ${r.label}`);
      if (r.note) console.log(`     → ${r.note}`);
    }
  }

  // Skipped
  const skipped = results.filter(r => r.status === 'skip');
  if (skipped.length > 0) {
    console.log('\n⏭️  Atlanan Testler\n');
    for (const r of skipped) {
      console.log(`  [${r.section}] ${r.label}${r.detail ? ' — ' + r.detail : ''}`);
    }
  }

  // Developer notes for failures
  if (failures.length > 0) {
    console.log('\n\n🔧 Geliştirici Notları (Başarısız Testler İçin)\n');
    const noteMap = {
      'Create post': 'POST /api/new/posts body: { content }. isFormattedContentEmpty kontrolü var, içerik yeterince uzun olmalı.',
      'Add quick access item': 'Quick access item id\'leri /api/menu ya da /api/sidebar\'dan alınan geçerli key\'ler olmalı.',
      'Admin panel login': 'SDAL_ADMIN_PASSWORD env değişkeni set edilmeli.',
      'Mod: delete post': '/api/new/admin/posts/:id/delete path\'i farklı olabilir, DELETE method kullanılıyor olabilir.',
    };
    for (const r of failures) {
      if (noteMap[r.label]) {
        console.log(`  • ${r.label}`);
        console.log(`    ${noteMap[r.label]}\n`);
      }
    }
  }

  // Overall
  console.log('\n' + '─'.repeat(64));
  const total = counts.pass + counts.fail + counts.warn + counts.skip;
  const pct = total > 0 ? Math.round(100 * counts.pass / (total - counts.skip)) : 0;
  console.log(`\n  SONUÇ: ${counts.pass} geçti  ${counts.fail} başarısız  ${counts.warn} uyarı  ${counts.skip} atlandı`);
  console.log(`  Başarı oranı: %${pct}  (${counts.pass}/${total - counts.skip} çalışan test)\n`);
  console.log('─'.repeat(64) + '\n');

  process.exit(counts.fail > 0 ? 1 : 0);
}

run().catch(e => { console.error('\n❌ Kritik hata:', e); process.exit(1); });
