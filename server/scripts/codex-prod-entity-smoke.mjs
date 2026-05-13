import { sqlGetAsync, sqlAllAsync, sqlRunAsync } from '../db.js';

const baseUrl = process.env.SDAL_BASE_URL || `http://127.0.0.1:${process.env.PORT || 8787}`;
const testUser = process.env.CODEX_TEST_USER || 'codex_test_user';
const testPassword = process.env.CODEX_TEST_PASSWORD || 'CodexTest123!';

async function ensureColumn(table, definition) {
  const exists = await sqlGetAsync("SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?", [table]);
  if (!exists) return false;
  const name = definition.split(/\s+/)[0];
  const columns = await sqlAllAsync(`PRAGMA table_info(${table})`);
  if (columns.some((column) => column.name === name)) return false;
  await sqlRunAsync(`ALTER TABLE ${table} ADD COLUMN ${definition}`);
  console.log(`schema added ${table}.${name}`);
  return true;
}

async function ensureSchema() {
  const common = [
    "show_in_feed INTEGER DEFAULT 1",
    "publication_status TEXT DEFAULT 'published'",
    "approval_status TEXT DEFAULT 'not_required'",
    'review_note TEXT',
    'reviewed_by INTEGER',
    'reviewed_at TEXT',
    'published_at TEXT',
  ];
  const specs = {
    events: [
      'image TEXT',
      'created_by INTEGER',
      'approved INTEGER DEFAULT 1',
      'approved_by INTEGER',
      'approved_at TEXT',
      'allow_comments INTEGER DEFAULT 1',
      'allow_likes INTEGER DEFAULT 1',
      'show_response_counts INTEGER DEFAULT 1',
      'show_attendee_names INTEGER DEFAULT 0',
      'show_decliner_names INTEGER DEFAULT 0',
      ...common,
    ],
    announcements: [
      'image TEXT',
      'created_by INTEGER',
      'approved INTEGER DEFAULT 1',
      'approved_by INTEGER',
      'approved_at TEXT',
      'allow_comments INTEGER DEFAULT 1',
      'allow_likes INTEGER DEFAULT 1',
      ...common,
    ],
    jobs: ['work_mode TEXT', 'image TEXT', ...common],
    posts: common,
    group_events: common,
    group_announcements: common,
  };
  for (const [table, definitions] of Object.entries(specs)) {
    for (const definition of definitions) await ensureColumn(table, definition);
  }
  await sqlRunAsync(`CREATE TABLE IF NOT EXISTS content_approval_settings (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    entity_type TEXT NOT NULL,
    group_id INTEGER,
    approval_required INTEGER NOT NULL DEFAULT 0,
    updated_at TEXT NOT NULL,
    updated_by INTEGER,
    UNIQUE(entity_type, group_id)
  )`);
  for (const type of ['event', 'announcement', 'job', 'group_event', 'group_announcement', 'group_post']) {
    await sqlRunAsync(
      'INSERT OR IGNORE INTO content_approval_settings (entity_type, group_id, approval_required, updated_at) VALUES (?, NULL, 0, ?)',
      [type, new Date().toISOString()],
    );
  }
}

async function ensureTestUser() {
  const now = new Date().toISOString();
  const row = await sqlGetAsync('SELECT id FROM uyeler WHERE kadi = ?', [testUser]);
  if (row?.id) {
    await sqlRunAsync(
      "UPDATE uyeler SET sifre = ?, aktiv = 1, verified = 1, verification_status = 'approved', role = 'user', admin = 0, mezuniyetyili = '2010', ilkbd = 1 WHERE id = ?",
      [testPassword, row.id],
    );
    return row.id;
  }
  const result = await sqlRunAsync(
    `INSERT INTO uyeler (kadi, sifre, email, isim, soyisim, aktivasyon, aktiv, ilktarih, resim, mezuniyetyili, ilkbd, role, admin, verified, verification_status)
     VALUES (?, ?, ?, 'Codex', 'Test', 'codex-test', 1, ?, '', '2010', 1, 'user', 0, 1, 'approved')`,
    [testUser, testPassword, `${testUser}@example.com`, now],
  );
  return Number(result?.lastInsertRowid || 0);
}

function mergeCookie(previous, response) {
  const setCookie = response.headers.getSetCookie ? response.headers.getSetCookie() : [];
  const parts = new Map();
  for (const chunk of previous.split(';').map((part) => part.trim()).filter(Boolean)) {
    const [key, ...value] = chunk.split('=');
    parts.set(key, value.join('='));
  }
  for (const raw of setCookie) {
    const first = raw.split(';')[0];
    const [key, ...value] = first.split('=');
    parts.set(key, value.join('='));
  }
  return [...parts.entries()].map(([key, value]) => `${key}=${value}`).join('; ');
}

async function request(method, path, body, cookie = '') {
  const response = await fetch(`${baseUrl}${path}`, {
    method,
    headers: {
      'content-type': 'application/json',
      ...(cookie ? { cookie } : {}),
    },
    body: body == null ? undefined : JSON.stringify(body),
  });
  const text = await response.text();
  let data = text;
  try {
    data = JSON.parse(text);
  } catch {}
  return { status: response.status, ok: response.ok, data, cookie: mergeCookie(cookie, response) };
}

async function main() {
  await ensureSchema();
  await ensureTestUser();

  let cookie = '';
  const login = await request('POST', '/api/auth/login', { kadi: testUser, sifre: testPassword }, cookie);
  cookie = login.cookie;
  console.log('login', login.status, login.data?.ok ?? login.data);
  if (!login.ok) process.exit(2);

  const stamp = Date.now();
  const event = await request('POST', '/api/new/events', {
    title: `Codex etkinlik testi ${stamp}`,
    description: 'Codex smoke test etkinlik açıklaması',
    location: 'Codex',
    starts_at: '2026-05-20T10:00:00.000Z',
    ends_at: '2026-05-20T12:00:00.000Z',
    show_in_feed: '1',
    publish: '1',
  }, cookie);
  console.log('event', event.status, event.data);

  const announcement = await request('POST', '/api/new/announcements', {
    title: `Codex duyuru testi ${stamp}`,
    body: 'Codex smoke test duyuru içeriği',
    show_in_feed: '1',
    publish: '1',
  }, cookie);
  console.log('announcement', announcement.status, announcement.data);

  const job = await request('POST', '/api/new/jobs', {
    company: 'Codex Test',
    title: `Codex iş ilanı testi ${stamp}`,
    description: 'Codex smoke test iş açıklaması',
    location: 'Remote',
    job_type: 'Tam zamanlı',
    work_mode: 'remote',
    link: 'https://example.com',
    show_in_feed: '1',
    publish: '1',
  }, cookie);
  console.log('job', job.status, job.data);

  const failures = [event, announcement, job].filter((item) => !item.ok);
  if (failures.length) process.exit(3);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
