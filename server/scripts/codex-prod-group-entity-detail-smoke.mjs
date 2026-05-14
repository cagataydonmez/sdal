import { sqlGetAsync, sqlRunAsync } from '../db.js';

const baseUrl = process.env.SDAL_BASE_URL || `http://127.0.0.1:${process.env.PORT || 8787}`;
const username = process.env.CODEX_TEST_USER || 'cxgrpdet';
const viewerUsername = process.env.CODEX_TEST_VIEWER || 'cxgrpvw';
const password = process.env.CODEX_TEST_PASSWORD || 'CodexTest123!';

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
  return {
    status: response.status,
    ok: response.ok,
    data,
    cookie: mergeCookie(cookie, response),
  };
}

async function ensureTestUser(kadi, suffix) {
  const now = new Date().toISOString();
  const existing = await sqlGetAsync('SELECT id FROM uyeler WHERE kadi = ?', [kadi]);
  if (existing?.id) {
    await sqlRunAsync(
      "UPDATE uyeler SET sifre = ?, aktiv = 1, verified = 1, verification_status = 'approved', role = 'user', admin = 0, mezuniyetyili = '2010', ilkbd = 1 WHERE id = ?",
      [password, existing.id],
    );
    return Number(existing.id);
  }
  const result = await sqlRunAsync(
    `INSERT INTO uyeler (kadi, sifre, email, isim, soyisim, aktivasyon, aktiv, ilktarih, resim, mezuniyetyili, ilkbd, role, admin, verified, verification_status)
     VALUES (?, ?, ?, 'Codex', 'GroupDetail', 'codex-test', 1, ?, '', '2010', 1, 'user', 0, 1, 'approved')`,
    [kadi, password, `${kadi}-${suffix}@example.com`, now],
  );
  return Number(result?.lastInsertRowid || 0);
}

async function cleanup(userId, groupId) {
  if (groupId) {
    await sqlRunAsync('DELETE FROM entity_comments WHERE entity_type IN (?, ?) AND entity_id IN (SELECT id FROM group_events WHERE group_id = ? UNION SELECT id FROM group_announcements WHERE group_id = ?)', ['group_event', 'group_announcement', groupId, groupId]).catch(() => {});
    await sqlRunAsync('DELETE FROM entity_reactions WHERE entity_type IN (?, ?) AND entity_id IN (SELECT id FROM group_events WHERE group_id = ? UNION SELECT id FROM group_announcements WHERE group_id = ?)', ['group_event', 'group_announcement', groupId, groupId]).catch(() => {});
    await sqlRunAsync('DELETE FROM group_events WHERE group_id = ?', [groupId]).catch(() => {});
    await sqlRunAsync('DELETE FROM group_announcements WHERE group_id = ?', [groupId]).catch(() => {});
    await sqlRunAsync('DELETE FROM group_members WHERE group_id = ?', [groupId]).catch(() => {});
    await sqlRunAsync('DELETE FROM groups WHERE id = ?', [groupId]).catch(() => {});
  }
  if (userId) await sqlRunAsync('DELETE FROM uyeler WHERE id = ?', [userId]).catch(() => {});
}

async function main() {
  let userId = 0;
  let viewerId = 0;
  let groupId = 0;
  try {
    userId = await ensureTestUser(username, 'owner');
    viewerId = await ensureTestUser(viewerUsername, 'viewer');
    const login = await request('POST', '/api/auth/login', { kadi: username, sifre: password });
    if (!login.ok) throw new Error(`login failed ${login.status}: ${JSON.stringify(login.data)}`);
    const cookie = login.cookie;
    const viewerLogin = await request('POST', '/api/auth/login', { kadi: viewerUsername, sifre: password });
    if (!viewerLogin.ok) throw new Error(`viewer login failed ${viewerLogin.status}: ${JSON.stringify(viewerLogin.data)}`);
    const viewerCookie = viewerLogin.cookie;

    const stamp = Date.now();
    const group = await request('POST', '/api/new/groups', {
      name: `Codex Grup Detay ${stamp}`,
      description: 'Codex grup detay smoke',
    }, cookie);
    if (!group.ok) throw new Error(`group create failed ${group.status}: ${JSON.stringify(group.data)}`);
    groupId = Number(group.data?.id || 0);
    if (!groupId) throw new Error(`group id missing: ${JSON.stringify(group.data)}`);
    await sqlRunAsync(
      "UPDATE groups SET is_cohort_group = 1, cohort_year = '2010', visibility = 'members_only' WHERE id = ?",
      [groupId],
    );

    const event = await request('POST', `/api/new/groups/${groupId}/events`, {
      title: `Codex grup etkinlik ${stamp}`,
      description: 'Codex grup etkinlik açıklaması',
      location: 'Codex',
      starts_at: '2026-05-20T10:00:00.000Z',
      ends_at: '2026-05-20T12:00:00.000Z',
      show_in_feed: '1',
      publish: '1',
    }, cookie);
    if (!event.ok) throw new Error(`event create failed ${event.status}: ${JSON.stringify(event.data)}`);
    const eventId = Number(event.data?.id || 0);

    const announcement = await request('POST', `/api/new/groups/${groupId}/announcements`, {
      title: `Codex grup duyuru ${stamp}`,
      body: 'Codex grup duyuru içeriği',
      show_in_feed: '1',
      publish: '1',
    }, cookie);
    if (!announcement.ok) throw new Error(`announcement create failed ${announcement.status}: ${JSON.stringify(announcement.data)}`);
    const announcementId = Number(announcement.data?.id || 0);

    const posts = await request('GET', `/api/new/groups/${groupId}/posts?limit=20&offset=0`, null, cookie);
    if (!posts.ok) throw new Error(`group posts failed ${posts.status}: ${JSON.stringify(posts.data)}`);
    const postItems = Array.isArray(posts.data?.items) ? posts.data.items : [];
    const eventPost = postItems.find((item) => item.post_type === 'group_event' && Number(item.entity_id) === eventId);
    const announcementPost = postItems.find((item) => item.post_type === 'group_announcement' && Number(item.entity_id) === announcementId);
    if (!eventPost) throw new Error(`group event missing in group feed: ${JSON.stringify(postItems)}`);
    if (!announcementPost) throw new Error(`group announcement missing in group feed: ${JSON.stringify(postItems)}`);

    const eventDetail = await request('GET', `/api/new/groups/${groupId}/events/${eventId}`, null, cookie);
    const announcementDetail = await request('GET', `/api/new/groups/${groupId}/announcements/${announcementId}`, null, cookie);
    if (!eventDetail.ok) throw new Error(`event detail failed ${eventDetail.status}: ${JSON.stringify(eventDetail.data)}`);
    if (!announcementDetail.ok) throw new Error(`announcement detail failed ${announcementDetail.status}: ${JSON.stringify(announcementDetail.data)}`);
    const viewerEventDetail = await request('GET', `/api/new/groups/${groupId}/events/${eventId}`, null, viewerCookie);
    const viewerAnnouncementDetail = await request('GET', `/api/new/groups/${groupId}/announcements/${announcementId}`, null, viewerCookie);
    if (!viewerEventDetail.ok) throw new Error(`cohort viewer event detail failed ${viewerEventDetail.status}: ${JSON.stringify(viewerEventDetail.data)}`);
    if (!viewerAnnouncementDetail.ok) throw new Error(`cohort viewer announcement detail failed ${viewerAnnouncementDetail.status}: ${JSON.stringify(viewerAnnouncementDetail.data)}`);

    console.log(JSON.stringify({
      ok: true,
      userId,
      viewerId,
      groupId,
      eventId,
      announcementId,
      eventPostRoute: `/groups/${groupId}/events/${eventId}`,
      announcementPostRoute: `/groups/${groupId}/announcements/${announcementId}`,
      eventDetailTitle: eventDetail.data?.title,
      announcementDetailTitle: announcementDetail.data?.title,
      cohortViewerEventDetailTitle: viewerEventDetail.data?.title,
      cohortViewerAnnouncementDetailTitle: viewerAnnouncementDetail.data?.title,
    }, null, 2));
  } finally {
    await cleanup(userId, groupId);
    if (viewerId) await sqlRunAsync('DELETE FROM uyeler WHERE id = ?', [viewerId]).catch(() => {});
  }
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
