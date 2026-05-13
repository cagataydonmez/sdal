import { sqlRunAsync, sqlGetAsync } from '../db.js';

const baseUrl = process.env.SDAL_BASE_URL || `http://127.0.0.1:${process.env.PORT || 8787}`;
const username = 'codex_test_user';
const password = 'CodexTest123!';

function mergeCookie(previous, response) {
  const setCookies = response.headers.getSetCookie ? response.headers.getSetCookie() : [];
  const fallback = response.headers.get('set-cookie');
  const parts = new Map();
  for (const chunk of previous.split(';').map((part) => part.trim()).filter(Boolean)) {
    const [key, ...value] = chunk.split('=');
    parts.set(key, value.join('='));
  }
  for (const raw of (setCookies.length ? setCookies : fallback ? [fallback] : [])) {
    const first = raw.split(';')[0];
    const [key, ...value] = first.split('=');
    parts.set(key, value.join('='));
  }
  return [...parts.entries()].map(([key, value]) => `${key}=${value}`).join('; ');
}

async function request(method, path, body, cookie = '') {
  const response = await fetch(`${baseUrl}${path}`, {
    method,
    headers: { 'content-type': 'application/json', ...(cookie ? { cookie } : {}) },
    body: body == null ? undefined : JSON.stringify(body),
  });
  const text = await response.text();
  let data = text;
  try {
    data = JSON.parse(text);
  } catch {}
  return { status: response.status, text, data, cookie: mergeCookie(cookie, response) };
}

async function main() {
  const now = new Date().toISOString();
  await sqlRunAsync('DELETE FROM uyeler WHERE kadi = ?', [username]);
  await sqlRunAsync(
    `INSERT INTO uyeler (kadi, sifre, email, isim, soyisim, aktivasyon, aktiv, ilktarih, resim, mezuniyetyili, ilkbd, role, admin, verified, verification_status)
     VALUES (?, ?, ?, 'Codex', 'Test', 'codex-test', 1, ?, '', '2010', 1, 'user', 0, 1, 'approved')`,
    [username, password, `${username}@example.com`, now],
  );
  const login = await request('POST', '/api/auth/login', { kadi: username, sifre: password });
  if (login.status !== 200) {
    console.log(JSON.stringify({ login: login.status, body: login.data }, null, 2));
    process.exit(2);
  }
  const create = await request('POST', '/api/new/events', {
    title: `Codex feed visible event ${Date.now()}`,
    description: 'Codex feed body',
    location: 'Codex',
    starts_at: '2026-05-20T10:00:00.000Z',
    ends_at: '2026-05-20T12:00:00.000Z',
    show_in_feed: '1',
    publish: '1',
  }, login.cookie);
  const published = await request('GET', '/api/new/events?limit=5&offset=0&status=published', null, login.cookie);
  const drafts = await request('GET', '/api/new/events?limit=5&offset=0&status=drafts', null, login.cookie);
  const feed = await request('GET', '/api/new/feed?limit=20&offset=0&feedType=main&filter=latest', null, login.cookie);
  const eventId = create.data.id;
  console.log(JSON.stringify({
    create: create.status,
    publishedStatus: published.status,
    draftsStatus: drafts.status,
    feedStatus: feed.status,
    publishedBody: published.data,
    draftsBody: drafts.data,
    feedKeys: feed.data && typeof feed.data === 'object' ? Object.keys(feed.data) : feed.data,
    eventId,
    publishedHasEvent: (published.data.items || []).some((item) => Number(item.id) === Number(eventId)),
    draftsHasEvent: (drafts.data.items || []).some((item) => Number(item.id) === Number(eventId)),
    feedHasEvent: (feed.data.items || []).some((item) => {
      const type = item.postType || item.post_type;
      const id = item.entityId ?? item.entity_id;
      return type === 'event' && Number(id) === Number(eventId);
    }),
  }, null, 2));
  const user = await sqlGetAsync('SELECT id FROM uyeler WHERE kadi = ?', [username]);
  if (user?.id) {
    await sqlRunAsync('DELETE FROM events WHERE created_by = ?', [user.id]);
    await sqlRunAsync('DELETE FROM uyeler WHERE id = ?', [user.id]);
  }
}

main().catch(async (error) => {
  console.error(error);
  const user = await sqlGetAsync('SELECT id FROM uyeler WHERE kadi = ?', [username]).catch(() => null);
  if (user?.id) {
    await sqlRunAsync('DELETE FROM events WHERE created_by = ?', [user.id]).catch(() => {});
    await sqlRunAsync('DELETE FROM uyeler WHERE id = ?', [user.id]).catch(() => {});
  }
  process.exit(1);
});
