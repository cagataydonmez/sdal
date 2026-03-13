import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import Database from 'better-sqlite3';

const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'sdal-phase2-network-metrics-'));
const bootstrapPath = path.join(tmpDir, 'bootstrap.sqlite');
const runtimeDbPath = path.join(tmpDir, 'runtime.sqlite');
const sourceDb = path.resolve(process.cwd(), '../db/sdal.sqlite');
fs.copyFileSync(sourceDb, bootstrapPath);

const bootstrapDb = new Database(bootstrapPath);
bootstrapDb.exec(`
  CREATE TABLE IF NOT EXISTS connection_requests (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    sender_id INTEGER,
    receiver_id INTEGER,
    status TEXT,
    created_at TEXT,
    updated_at TEXT,
    responded_at TEXT,
    UNIQUE(sender_id, receiver_id)
  );
  CREATE TABLE IF NOT EXISTS mentorship_requests (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    requester_id INTEGER,
    mentor_id INTEGER,
    status TEXT DEFAULT 'requested',
    focus_area TEXT,
    message TEXT,
    created_at TEXT,
    updated_at TEXT,
    responded_at TEXT
  );
  CREATE TABLE IF NOT EXISTS teacher_alumni_links (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    teacher_user_id INTEGER,
    alumni_user_id INTEGER,
    relationship_type TEXT,
    class_year TEXT,
    notes TEXT,
    confidence_score REAL NOT NULL DEFAULT 1.0,
    created_by INTEGER,
    created_at TEXT,
    UNIQUE(teacher_user_id, alumni_user_id, relationship_type, class_year)
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
`);
const nowTs = new Date().toISOString();
bootstrapDb
  .prepare('INSERT OR IGNORE INTO site_controls (id, site_open, maintenance_message, updated_at) VALUES (1, 1, ?, ?)')
  .run('Site geçici bakım modundadır. Lütfen daha sonra tekrar deneyin.', nowTs);
for (const moduleKey of ['feed', 'main_feed', 'year_feed', 'explore', 'following', 'groups', 'messages', 'messenger', 'notifications', 'albums', 'games', 'events', 'announcements', 'jobs', 'profile', 'help', 'requests']) {
  bootstrapDb
    .prepare('INSERT OR IGNORE INTO module_controls (module_key, is_open, updated_at) VALUES (?, 1, ?)')
    .run(moduleKey, nowTs);
}
bootstrapDb.close();

process.env.SDAL_DB_PATH = runtimeDbPath;
process.env.SDAL_DB_BOOTSTRAP_PATH = bootstrapPath;
process.env.SDAL_SESSION_SECRET = 'phase2-network-metrics-secret';
process.env.SDAL_ADMIN_PASSWORD = 'AdminPanel!123';
process.env.ROOT_BOOTSTRAP_PASSWORD = 'RootPass!123';
process.env.MAIL_ALLOW_MOCK = 'true';
process.env.SDAL_LEGACY_ROOT_DIR = tmpDir;
process.env.REDIS_URL = '';
process.env.JOB_INLINE_WORKER = 'true';

const { default: app, onServerStarted } = await import('../../app.js');
const { sqlRun, sqlGet } = await import('../../db.js');
await onServerStarted();

function seedUser(username, password, role = 'user', admin = 0, year = '2011') {
  const now = new Date().toISOString();
  sqlRun(
    `INSERT INTO uyeler (kadi, sifre, email, isim, soyisim, aktivasyon, aktiv, ilktarih, mezuniyetyili, ilkbd, admin, role, verified, verification_status, mentor_opt_in)
     VALUES (?, ?, ?, ?, ?, ?, 1, ?, ?, 1, ?, ?, 1, 'approved', 0)`,
    [username, password, `${username}@example.com`, username, 'Metrics', `${username}-act`, now, year, admin, role]
  );
  return Number(sqlGet('SELECT id FROM uyeler WHERE kadi = ?', [username]).id);
}

const meId = seedUser('phase2_metrics_me', 'phase2-pass-me', 'user', 0, '2011');
const otherId = seedUser('phase2_metrics_other', 'phase2-pass-other', 'user', 0, '2012');
const mentorId = seedUser('phase2_metrics_mentor', 'phase2-pass-mentor', 'teacher', 0, 'teacher');
const adminId = seedUser('phase2_metrics_admin', 'phase2-pass-admin', 'admin', 1, '2005');

const server = app.listen(0, '127.0.0.1');
await new Promise((resolve, reject) => {
  server.once('listening', resolve);
  server.once('error', reject);
});
const baseUrl = `http://127.0.0.1:${server.address().port}`;

async function request(pathname, { method = 'GET', cookie = '', body = null } = {}) {
  const res = await fetch(`${baseUrl}${pathname}`, {
    method,
    headers: {
      ...(cookie ? { cookie } : {}),
      ...(body ? { 'content-type': 'application/json' } : {})
    },
    body: body ? JSON.stringify(body) : undefined
  });
  const text = await res.text();
  let data = null;
  if (text) {
    try { data = JSON.parse(text); } catch { data = text; }
  }
  return { res, data };
}

async function login(kadi, sifre) {
  const out = await request('/api/auth/login', { method: 'POST', body: { kadi, sifre } });
  assert.equal(out.res.status, 200);
  const rawCookies = typeof out.res.headers.getSetCookie === 'function' ? out.res.headers.getSetCookie() : [out.res.headers.get('set-cookie')].filter(Boolean);
  return rawCookies.map((row) => String(row || '').split(';')[0]).join('; ');
}

try {
  const cookieMe = await login('phase2_metrics_me', 'phase2-pass-me');
  const cookieAdmin = await login('phase2_metrics_admin', 'phase2-pass-admin');
  const now = new Date().toISOString();

  sqlRun('UPDATE uyeler SET ilktarih = ? WHERE id = ?', ['2026-01-01T00:00:00.000Z', meId]);

  sqlRun('INSERT INTO connection_requests (sender_id, receiver_id, status, created_at, updated_at, responded_at) VALUES (?, ?, ?, ?, ?, ?)', [meId, otherId, 'accepted', now, now, now]);
  sqlRun('INSERT INTO connection_requests (sender_id, receiver_id, status, created_at, updated_at) VALUES (?, ?, ?, ?, ?)', [otherId, meId, 'pending', now, now]);

  sqlRun(
    `INSERT INTO mentorship_requests (requester_id, mentor_id, status, focus_area, message, created_at, updated_at, responded_at)
     VALUES (?, ?, 'accepted', 'career', 'yardim', ?, ?, ?)` ,
    [meId, mentorId, now, now, now]
  );

  sqlRun(
    `INSERT INTO teacher_alumni_links (teacher_user_id, alumni_user_id, relationship_type, class_year, notes, created_by, created_at)
     VALUES (?, ?, 'student', '2011', 'test', ?, ?)`,
    [mentorId, meId, meId, now]
  );

  const metrics = await request('/api/new/network/metrics?window=30d', { cookie: cookieMe });
  assert.equal(metrics.res.status, 200);
  assert.equal(metrics.data?.ok, true);
  assert.equal(metrics.data?.code, 'NETWORK_METRICS_OK');
  assert.equal(metrics.data?.data?.window, '30d');
  assert.equal(metrics.data?.window, '30d');
  assert.equal(metrics.data?.metrics?.connections?.requested, 1);
  assert.equal(metrics.data?.metrics?.connections?.accepted, 1);
  assert.equal(metrics.data?.metrics?.connections?.pending_incoming, 1);
  assert.equal(metrics.data?.metrics?.mentorship?.accepted, 1);
  assert.equal(metrics.data?.metrics?.teacherLinks?.created, 1);

  const hubViewTelemetry = await request('/api/new/network/telemetry', {
    method: 'POST',
    cookie: cookieMe,
    body: {
      event_name: 'network_hub_viewed',
      source_surface: 'network_hub',
      metadata: { window: '30d' }
    }
  });
  assert.equal(hubViewTelemetry.res.status, 200);
  assert.equal(hubViewTelemetry.data?.ok, true);

  const teacherViewTelemetry = await request('/api/new/network/telemetry', {
    method: 'POST',
    cookie: cookieMe,
    body: {
      event_name: 'teacher_network_viewed',
      source_surface: 'teachers_network_page'
    }
  });
  assert.equal(teacherViewTelemetry.res.status, 200);

  const exploreSuggestions = await request('/api/new/explore/suggestions?limit=12&offset=0', { cookie: cookieMe });
  assert.equal(exploreSuggestions.res.status, 200);
  assert.equal(exploreSuggestions.data?.ok, true);
  const experimentVariant = String(exploreSuggestions.data?.data?.experiment_variant || exploreSuggestions.data?.experiment_variant || 'A');

  const exploreSuggestionTelemetry = await request('/api/new/network/telemetry', {
    method: 'POST',
    cookie: cookieMe,
    body: {
      event_name: 'network_explore_suggestions_loaded',
      source_surface: 'explore_page',
      metadata: {
        suggestion_count: Array.isArray(exploreSuggestions.data?.data?.items) ? exploreSuggestions.data.data.items.length : 0,
        experiment_variant: experimentVariant
      }
    }
  });
  assert.equal(exploreSuggestionTelemetry.res.status, 200);

  sqlRun(
    `INSERT OR REPLACE INTO network_suggestion_ab_assignments (user_id, variant, assigned_at, updated_at)
     VALUES (?, 'B', ?, ?)`,
    [otherId, now, now]
  );
  sqlRun(
    `INSERT OR REPLACE INTO network_suggestion_ab_assignments (user_id, variant, assigned_at, updated_at)
     VALUES (?, 'A', ?, ?)`,
    [mentorId, now, now]
  );
  sqlRun(
    `INSERT INTO networking_telemetry_events (user_id, event_name, source_surface, metadata_json, created_at)
     VALUES (?, 'network_explore_suggestions_loaded', 'explore_page', ?, ?)`,
    [otherId, JSON.stringify({ suggestion_count: 6, experiment_variant: 'B' }), now]
  );
  sqlRun(
    `INSERT INTO networking_telemetry_events (user_id, event_name, source_surface, metadata_json, created_at)
     VALUES (?, 'network_explore_suggestions_loaded', 'explore_page', ?, ?)`,
    [mentorId, JSON.stringify({ suggestion_count: 5, experiment_variant: 'A' }), now]
  );
  sqlRun(
    `INSERT INTO networking_telemetry_events (user_id, event_name, source_surface, target_user_id, created_at)
     VALUES (?, 'connection_requested', 'explore_page', ?, ?)`,
    [otherId, meId, now]
  );
  sqlRun(
    `INSERT INTO networking_telemetry_events (user_id, event_name, source_surface, target_user_id, created_at)
     VALUES (?, 'mentorship_requested', 'explore_page', ?, ?)`,
    [otherId, mentorId, now]
  );

  const followCreated = await request(`/api/new/follow/${otherId}`, {
    method: 'POST',
    cookie: cookieMe,
    body: { source_surface: 'explore_page' }
  });
  assert.equal(followCreated.res.status, 200);
  assert.equal(followCreated.data?.following, true);

  const followRemoved = await request(`/api/new/follow/${otherId}`, {
    method: 'POST',
    cookie: cookieMe,
    body: { source_surface: 'explore_page' }
  });
  assert.equal(followRemoved.res.status, 200);
  assert.equal(followRemoved.data?.following, false);

  const analytics = await request('/api/new/admin/network/analytics?window=30d', { cookie: cookieAdmin });
  assert.equal(analytics.res.status, 200);
  assert.equal(analytics.data?.window, '30d');
  assert.equal(analytics.data?.summary?.source, 'member_networking_daily_summary');
  assert.equal(analytics.data?.summary?.granularity, 'day');
  assert.equal(typeof analytics.data?.summary?.last_rebuilt_at, 'string');
  assert.equal(analytics.data?.networking?.connections?.accepted >= 1, true);
  assert.equal(typeof analytics.data?.networking?.connections?.acceptance_rate, 'number');
  assert.equal(analytics.data?.networking?.telemetry?.frontend?.hub_views, 1);
  assert.equal(analytics.data?.networking?.telemetry?.frontend?.teacher_network_views, 1);
  assert.equal(analytics.data?.networking?.telemetry?.actions?.follow_created, 1);
  assert.equal(analytics.data?.networking?.telemetry?.actions?.follow_removed, 1);
  assert.equal(Array.isArray(analytics.data?.networking?.telemetry?.top_events), true);
  assert.equal(Array.isArray(analytics.data?.networking?.alerts), true);
  assert.equal(Array.isArray(analytics.data?.networking?.experiments?.network_suggestions?.variants), true);
  assert.equal(analytics.data?.networking?.experiments?.network_suggestions?.variants.some((row) => row.variant === experimentVariant), true);
  assert.equal(typeof analytics.data?.networking?.experiments?.network_suggestions?.leading_variant?.variant, 'string');
  assert.equal(Array.isArray(analytics.data?.networking?.experiments?.network_suggestions?.recommendations), true);
  assert.equal(analytics.data?.networking?.alerts.some((item) => item.code === 'teacher_link_reads_lagging'), true);
  assert.equal(Array.isArray(analytics.data?.networking?.top_active_graduation_years), true);

  const suggestionAb = await request('/api/new/admin/network-suggestion-ab?window=30d', { cookie: cookieAdmin });
  assert.equal(suggestionAb.res.status, 200);
  assert.equal(suggestionAb.data?.window, '30d');
  assert.equal(Array.isArray(suggestionAb.data?.configs), true);
  assert.equal(Array.isArray(suggestionAb.data?.performance), true);
  assert.equal(Array.isArray(suggestionAb.data?.recommendations), true);
  assert.equal(Array.isArray(suggestionAb.data?.recentChanges), true);
  assert.equal(suggestionAb.data?.performance.some((row) => row.variant === 'B'), true);
  if (suggestionAb.data?.recommendations.length > 0) {
    assert.equal(typeof suggestionAb.data.recommendations[0]?.confidence, 'number');
    assert.equal(typeof suggestionAb.data.recommendations[0]?.guardrails?.confirmation_required, 'boolean');
    const beforeVariantA = suggestionAb.data.configs.find((row) => row.variant === 'A');
    const beforeVariantB = suggestionAb.data.configs.find((row) => row.variant === 'B');
    const applyWithoutConfirmation = await request('/api/new/admin/network-suggestion-ab/apply', {
      method: 'POST',
      cookie: cookieAdmin,
      body: { index: 0, window: '30d', cohort: 'all' }
    });
    assert.equal(applyWithoutConfirmation.res.status, 409);
    assert.equal(applyWithoutConfirmation.data?.code, 'NETWORK_SUGGESTION_RECOMMENDATION_CONFIRM_REQUIRED');

    const applyRecommendation = await request('/api/new/admin/network-suggestion-ab/apply', {
      method: 'POST',
      cookie: cookieAdmin,
      body: { index: 0, window: '30d', cohort: 'all', confirmation: 'apply' }
    });
    assert.equal(applyRecommendation.res.status, 200);
    assert.equal(applyRecommendation.data?.ok, true);
    assert.equal(applyRecommendation.data?.code, 'NETWORK_SUGGESTION_RECOMMENDATION_APPLIED');
    assert.equal(typeof applyRecommendation.data?.data?.history_id, 'number');
    assert.equal(Array.isArray(applyRecommendation.data?.data?.touched_variants), true);
    assert.equal(applyRecommendation.data?.data?.touched_variants.length >= 1, true);
    assert.equal(Array.isArray(applyRecommendation.data?.data?.before_snapshot), true);
    assert.equal(Array.isArray(applyRecommendation.data?.data?.after_snapshot), true);

    const suggestionAbAfter = await request('/api/new/admin/network-suggestion-ab?window=30d', { cookie: cookieAdmin });
    assert.equal(suggestionAbAfter.res.status, 200);
    if (suggestionAbAfter.data?.recommendations?.length > 0) {
      assert.equal(suggestionAbAfter.data.recommendations.some((row) => row.guardrails?.cooldown_active === true), true);
    }
    const afterVariantA = suggestionAbAfter.data?.configs?.find((row) => row.variant === 'A');
    const afterVariantB = suggestionAbAfter.data?.configs?.find((row) => row.variant === 'B');
    const changedVariant = applyRecommendation.data?.data?.touched_variants?.[0];
    if (changedVariant === 'A') {
      assert.notDeepEqual(afterVariantA, beforeVariantA);
    } else if (changedVariant === 'B') {
      assert.notDeepEqual(afterVariantB, beforeVariantB);
    }

    const rollbackRecommendation = await request(`/api/new/admin/network-suggestion-ab/rollback/${applyRecommendation.data?.data?.history_id}`, {
      method: 'POST',
      cookie: cookieAdmin,
      body: {}
    });
    assert.equal(rollbackRecommendation.res.status, 200);
    assert.equal(rollbackRecommendation.data?.ok, true);
    assert.equal(rollbackRecommendation.data?.code, 'NETWORK_SUGGESTION_RECOMMENDATION_ROLLED_BACK');
    assert.equal(Array.isArray(rollbackRecommendation.data?.data?.restored_snapshot), true);

    const suggestionAbRolledBack = await request('/api/new/admin/network-suggestion-ab?window=30d', { cookie: cookieAdmin });
    assert.equal(suggestionAbRolledBack.res.status, 200);
    const rolledBackVariantA = suggestionAbRolledBack.data?.configs?.find((row) => row.variant === 'A');
    const rolledBackVariantB = suggestionAbRolledBack.data?.configs?.find((row) => row.variant === 'B');
    if (changedVariant === 'A') {
      assert.deepEqual({ ...rolledBackVariantA, updatedAt: null }, { ...beforeVariantA, updatedAt: null });
    } else if (changedVariant === 'B') {
      assert.deepEqual({ ...rolledBackVariantB, updatedAt: null }, { ...beforeVariantB, updatedAt: null });
    }
    assert.equal(suggestionAbRolledBack.data?.recentChanges.some((row) => Number(row.id) === Number(applyRecommendation.data?.data?.history_id) && typeof row.rolled_back_at === 'string'), true);
  }
  assert.equal(typeof suggestionAb.data?.leadingVariant?.variant, 'string');

  const cohortScoped = await request('/api/new/admin/network/analytics?window=30d&cohort=2011', { cookie: cookieAdmin });
  assert.equal(cohortScoped.res.status, 200);
  assert.equal(cohortScoped.data?.cohort, '2011');
  assert.equal(cohortScoped.data?.networking?.telemetry?.frontend?.hub_views, 1);
  assert.equal(typeof cohortScoped.data?.summary?.last_rebuilt_at, 'string');

  const summaryRows = Number(sqlGet('SELECT COUNT(*) AS cnt FROM member_networking_daily_summary')?.cnt || 0);
  assert.equal(summaryRows >= 1, true);
  const suggestionAssignment = sqlGet('SELECT variant FROM network_suggestion_ab_assignments WHERE user_id = ?', [meId]);
  assert.equal(suggestionAssignment?.variant, experimentVariant);

  console.log('phase2 network metrics/analytics tests passed');
} finally {
  await new Promise((resolve) => server.close(resolve));
}
