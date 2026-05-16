import { FACTORY_RESET_CONFIRMATION } from '../src/admin/factoryResetService.js';
import { TEST_DATA_AREAS, createTestDataSeeder } from '../src/admin/testDataSeederService.js';

function asyncRoute(handler) {
  return (req, res, next) => Promise.resolve(handler(req, res, next)).catch(next);
}

function statusForError(err) {
  const status = Number(err?.statusCode || err?.status || 500);
  return status >= 400 && status < 600 ? status : 500;
}

export function registerAdminRootRoutes(app, {
  dbDriver,
  sqlGet,
  sqlRun,
  sqlGetAsync,
  sqlAllAsync,
  sqlRunAsync,
  uploadsDir,
  requireAuth,
  requireRootAdmin,
  rbacService,
  factoryResetService,
  factoryResetRateLimit,
  testDataSeeder,
  hashPassword,
  processUpload,
  verifyPassword,
  writeAppLog,
  logAdminAction,
  adminPushService = null
}) {
  const rootOnly = [requireAuth, requireRootAdmin];
  const seeder = testDataSeeder || createTestDataSeeder({
    dbDriver,
    sqlGet,
    sqlRun,
    sqlGetAsync,
    sqlAllAsync,
    sqlRunAsync,
    uploadsDir,
    hashPassword,
    processUpload,
    writeAppLog
  });
  const isPostgres = dbDriver === 'postgres';
  const dateText = (expr) => isPostgres ? `COALESCE(${expr}::text, '')` : `COALESCE(${expr}, '')`;
  const limitInt = (value, fallback = 30, max = 100) => Math.min(Math.max(parseInt(value || fallback, 10) || fallback, 1), max);
  const preview = (value, max = 220) => String(value || '').replace(/\s+/g, ' ').trim().slice(0, max);

  function parseMetadata(value) {
    if (!value) return {};
    if (typeof value === 'object') return value;
    try {
      return JSON.parse(String(value));
    } catch {
      return {};
    }
  }

  async function safeAll(label, sql, params = []) {
    try {
      return await sqlAllAsync(sql, params) || [];
    } catch (err) {
      writeAppLog?.('warn', 'root_activity_query_failed', {
        label,
        message: err?.message || String(err)
      });
      return [];
    }
  }

  async function safeGet(label, sql, params = []) {
    try {
      return await sqlGetAsync(sql, params) || null;
    } catch (err) {
      writeAppLog?.('warn', 'root_activity_query_failed', {
        label,
        message: err?.message || String(err)
      });
      return null;
    }
  }

  async function firstRows(label, variants) {
    for (const variant of variants) {
      const rows = await safeAll(label, variant.sql, variant.params);
      if (rows.length) return rows;
    }
    return [];
  }

  function normalizeMember(row) {
    return {
      id: Number(row?.id || 0),
      handle: String(row?.handle || row?.kadi || ''),
      name: [row?.first_name || row?.isim, row?.last_name || row?.soyisim].filter(Boolean).join(' ').trim(),
      email: String(row?.email || ''),
      avatar: String(row?.avatar || row?.resim || ''),
      role: String(row?.role || ''),
      graduationYear: String(row?.graduation_year || row?.mezuniyetyili || ''),
      online: row?.online === true || Number(row?.online || 0) === 1 || ['true', 'evet', 'yes'].includes(String(row?.online || '').toLowerCase()),
      lastSeenAt: String(row?.last_seen_at || row?.sontarih || ''),
      lastActivityDate: String(row?.last_activity_date || row?.sonislemtarih || ''),
      lastActivityTime: String(row?.last_activity_time || row?.sonislemsaat || ''),
      profileViewCount: Number(row?.profile_view_count || row?.hit || 0)
    };
  }

  async function readRootActivityUsers(q, limit) {
    const term = String(q || '').trim().slice(0, 80);
    const like = `%${term}%`;
    return (await safeAll(
      'root_activity_users',
      `SELECT id,
              COALESCE(kadi, '') AS handle,
              COALESCE(isim, '') AS first_name,
              COALESCE(soyisim, '') AS last_name,
              COALESCE(email, '') AS email,
              COALESCE(resim, '') AS avatar,
              COALESCE(role, '') AS role,
              COALESCE(CAST(mezuniyetyili AS TEXT), '') AS graduation_year,
              COALESCE(CAST(online AS TEXT), '0') AS online,
              COALESCE(CAST(sontarih AS TEXT), '') AS last_seen_at,
              COALESCE(CAST(sonislemtarih AS TEXT), '') AS last_activity_date,
              COALESCE(CAST(sonislemsaat AS TEXT), '') AS last_activity_time,
              COALESCE(hit, 0) AS profile_view_count
       FROM uyeler
       WHERE (? = ''
          OR LOWER(COALESCE(kadi, '')) LIKE LOWER(?)
          OR LOWER(COALESCE(isim, '')) LIKE LOWER(?)
          OR LOWER(COALESCE(soyisim, '')) LIKE LOWER(?)
          OR LOWER(COALESCE(email, '')) LIKE LOWER(?))
       ORDER BY id DESC
       LIMIT ?`,
      [term, like, like, like, like, limit]
    )).map(normalizeMember);
  }

  async function readRootActivitySnapshot(userId) {
    const user = normalizeMember(await safeGet(
      'root_activity_user',
      `SELECT id, COALESCE(kadi, '') AS handle, COALESCE(isim, '') AS first_name,
              COALESCE(soyisim, '') AS last_name, COALESCE(email, '') AS email,
              COALESCE(resim, '') AS avatar, COALESCE(role, '') AS role,
              COALESCE(CAST(mezuniyetyili AS TEXT), '') AS graduation_year, COALESCE(CAST(online AS TEXT), '0') AS online,
              COALESCE(CAST(sontarih AS TEXT), '') AS last_seen_at, COALESCE(CAST(sonislemtarih AS TEXT), '') AS last_activity_date,
              COALESCE(CAST(sonislemsaat AS TEXT), '') AS last_activity_time, COALESCE(hit, 0) AS profile_view_count
       FROM uyeler WHERE id = ?`,
      [userId]
    ));
    if (!user.id) return null;

    const [posts, comments, postLikes, photos, photoComments, photoLikes, follows, messages, profileViews, photoViews, sessions, timeline] = await Promise.all([
      firstRows('root_activity_posts', [
        { sql: `SELECT id, ${dateText('created_at')} AS created_at, COALESCE(content, '') AS text, COALESCE(image_url, '') AS media_url FROM posts WHERE author_id = ? ORDER BY created_at DESC LIMIT 30`, params: [userId] },
        { sql: `SELECT id, ${dateText('tarih')} AS created_at, COALESCE(metin, '') AS text, COALESCE(resim, '') AS media_url FROM yazilar WHERE uyeid = ? ORDER BY id DESC LIMIT 30`, params: [userId] }
      ]),
      firstRows('root_activity_comments', [
        { sql: `SELECT c.id, c.post_id, p.author_id AS owner_user_id, ${dateText('c.created_at')} AS created_at, COALESCE(c.body, '') AS text, COALESCE(p.content, '') AS target_text FROM post_comments c LEFT JOIN posts p ON p.id = c.post_id WHERE c.author_id = ? ORDER BY c.created_at DESC LIMIT 40`, params: [userId] }
      ]),
      firstRows('root_activity_post_likes', [
        { sql: `SELECT r.id, r.post_id, p.author_id AS owner_user_id, ${dateText('r.created_at')} AS created_at, COALESCE(r.reaction_type, 'like') AS reaction_type, COALESCE(p.content, '') AS target_text FROM post_reactions r LEFT JOIN posts p ON p.id = r.post_id WHERE r.user_id = ? ORDER BY r.created_at DESC LIMIT 40`, params: [userId] }
      ]),
      firstRows('root_activity_photos', [
        { sql: `SELECT id, ${dateText('created_at')} AS created_at, COALESCE(title, '') AS title, COALESCE(file_name, '') AS file_name, COALESCE(view_count, 0) AS view_count FROM album_photos WHERE uploaded_by_user_id = ? ORDER BY created_at DESC LIMIT 30`, params: [userId] },
        { sql: `SELECT id, ${dateText('tarih')} AS created_at, COALESCE(baslik, '') AS title, COALESCE(dosyaadi, '') AS file_name, COALESCE(hit, 0) AS view_count FROM album_foto WHERE ekleyenid = ? ORDER BY id DESC LIMIT 30`, params: [userId] }
      ]),
      firstRows('root_activity_photo_comments', [
        { sql: `SELECT c.id, c.photo_id, p.uploaded_by_user_id AS owner_user_id, ${dateText('c.created_at')} AS created_at, COALESCE(c.comment_body, '') AS text, COALESCE(p.title, '') AS target_text FROM album_photo_comments c LEFT JOIN album_photos p ON p.id = c.photo_id WHERE c.author_user_id = ? ORDER BY c.created_at DESC LIMIT 40`, params: [userId] },
        { sql: `SELECT c.id, c.fotoid AS photo_id, p.ekleyenid AS owner_user_id, ${dateText('c.tarih')} AS created_at, COALESCE(c.yorum, '') AS text, COALESCE(p.baslik, '') AS target_text FROM album_fotoyorum c LEFT JOIN album_foto p ON p.id = c.fotoid WHERE c.uyeid = ? ORDER BY c.id DESC LIMIT 40`, params: [userId] }
      ]),
      firstRows('root_activity_photo_likes', [
        { sql: `SELECT l.id, l.photo_id, p.uploaded_by_user_id AS owner_user_id, ${dateText('l.created_at')} AS created_at, COALESCE(p.title, '') AS target_text FROM album_photo_likes l LEFT JOIN album_photos p ON p.id = l.photo_id WHERE l.user_id = ? ORDER BY l.created_at DESC LIMIT 40`, params: [userId] }
      ]),
      firstRows('root_activity_follows', [
        { sql: `SELECT f.id, f.following_id AS target_user_id, ${dateText('f.created_at')} AS created_at, COALESCE(u.kadi, '') AS target_handle, COALESCE(u.isim, '') AS target_first_name, COALESCE(u.soyisim, '') AS target_last_name FROM user_follows f LEFT JOIN uyeler u ON u.id = f.following_id WHERE f.follower_id = ? ORDER BY f.created_at DESC LIMIT 80`, params: [userId] },
        { sql: `SELECT f.id, f.following_id AS target_user_id, ${dateText('f.created_at')} AS created_at, COALESCE(u.kadi, '') AS target_handle, COALESCE(u.isim, '') AS target_first_name, COALESCE(u.soyisim, '') AS target_last_name FROM follows f LEFT JOIN uyeler u ON u.id = f.following_id WHERE f.follower_id = ? ORDER BY f.created_at DESC LIMIT 80`, params: [userId] }
      ]),
      firstRows('root_activity_messages', [
        { sql: `SELECT m.id, 'thread' AS source, m.conversation_id, m.sender_id, m.recipient_id, CASE WHEN m.sender_id = ? THEN m.recipient_id ELSE m.sender_id END AS peer_user_id, COALESCE(u.kadi, '') AS peer_handle, COALESCE(u.isim, '') AS peer_first_name, COALESCE(u.soyisim, '') AS peer_last_name, ${dateText('m.created_at')} AS created_at, SUBSTR(COALESCE(m.body, ''), 1, 240) AS body_preview FROM conversation_messages m LEFT JOIN uyeler u ON u.id = CASE WHEN m.sender_id = ? THEN m.recipient_id ELSE m.sender_id END WHERE m.sender_id = ? OR m.recipient_id = ? ORDER BY m.created_at DESC LIMIT 80`, params: [userId, userId, userId, userId] },
        { sql: `SELECT m.id, 'direct' AS source, 0 AS conversation_id, m.sender_id, m.recipient_id, CASE WHEN m.sender_id = ? THEN m.recipient_id ELSE m.sender_id END AS peer_user_id, COALESCE(u.kadi, '') AS peer_handle, COALESCE(u.isim, '') AS peer_first_name, COALESCE(u.soyisim, '') AS peer_last_name, ${dateText('m.created_at')} AS created_at, SUBSTR(COALESCE(m.body_html, ''), 1, 240) AS body_preview FROM direct_messages m LEFT JOIN uyeler u ON u.id = CASE WHEN m.sender_id = ? THEN m.recipient_id ELSE m.sender_id END WHERE m.sender_id = ? OR m.recipient_id = ? ORDER BY m.created_at DESC LIMIT 80`, params: [userId, userId, userId, userId] }
      ]),
      safeAll('root_activity_profile_views',
        `SELECT e.target_id, COUNT(*) AS count, MIN(e.occurred_at) AS first_seen_at, MAX(e.occurred_at) AS last_seen_at,
                COALESCE(u.kadi, '') AS target_handle, COALESCE(u.isim, '') AS target_first_name, COALESCE(u.soyisim, '') AS target_last_name
         FROM user_activity_events e
         LEFT JOIN uyeler u ON CAST(u.id AS TEXT) = e.target_id
         WHERE e.actor_user_id = ? AND e.event_type = 'profile_view' AND e.target_type = 'user'
         GROUP BY e.target_id, u.kadi, u.isim, u.soyisim
         ORDER BY MAX(e.occurred_at) DESC LIMIT 60`, [userId]),
      safeAll('root_activity_photo_views',
        `SELECT e.target_id, COUNT(*) AS count, MIN(e.occurred_at) AS first_seen_at, MAX(e.occurred_at) AS last_seen_at,
                COALESCE(p.title, '') AS title, COALESCE(p.file_name, '') AS file_name
         FROM user_activity_events e
         LEFT JOIN album_photos p ON CAST(p.id AS TEXT) = e.target_id
         WHERE e.actor_user_id = ? AND e.event_type = 'photo_view' AND e.target_type = 'photo'
         GROUP BY e.target_id, p.title, p.file_name
         ORDER BY MAX(e.occurred_at) DESC LIMIT 60`, [userId]),
      safeAll('root_activity_sessions',
        `SELECT id, event_type, target_type, target_id, metadata, occurred_at FROM user_activity_events WHERE actor_user_id = ? AND event_type IN ('session_start', 'session_end') ORDER BY occurred_at DESC LIMIT 120`, [userId]),
      safeAll('root_activity_timeline',
        `SELECT id, event_type, target_type, target_id, metadata, occurred_at FROM user_activity_events WHERE actor_user_id = ? ORDER BY occurred_at DESC LIMIT 100`, [userId])
    ]);

    const labels = new Map();
    const addLabel = (id, label) => {
      const key = Number(id || 0);
      const value = String(label || '').trim();
      if (key > 0 && value && !labels.has(key)) labels.set(key, value);
    };
    const scores = new Map();
    const addScore = (id, amount) => {
      const key = Number(id || 0);
      if (key > 0 && key !== userId) scores.set(key, Number(scores.get(key) || 0) + amount);
    };
    for (const item of messages) {
      addLabel(item.peer_user_id, [item.peer_first_name, item.peer_last_name].filter(Boolean).join(' ').trim() || item.peer_handle);
      addScore(item.peer_user_id, 3);
    }
    for (const item of follows) {
      addLabel(item.target_user_id, [item.target_first_name, item.target_last_name].filter(Boolean).join(' ').trim() || item.target_handle);
      addScore(item.target_user_id, 2);
    }
    for (const item of [...comments, ...postLikes, ...photoComments, ...photoLikes]) addScore(item.owner_user_id, 1);
    for (const item of profileViews) {
      addLabel(item.target_id, [item.target_first_name, item.target_last_name].filter(Boolean).join(' ').trim() || item.target_handle);
      addScore(item.target_id, Number(item.count || 0));
    }
    const topInteractions = Array.from(scores.entries())
      .sort((a, b) => b[1] - a[1])
      .slice(0, 10)
      .map(([id, score]) => ({ userId: id, label: labels.get(id) || `Üye #${id}`, score: Number(score.toFixed(1)) }));

    const sessionMinutes = estimateSessionMinutes(sessions);
    return {
      user,
      summary: {
        posts: posts.length,
        comments: comments.length + photoComments.length,
        postLikes: postLikes.length,
        photoLikes: photoLikes.length,
        profileViews: profileViews.reduce((sum, row) => sum + Number(row.count || 0), 0),
        photoViews: photoViews.reduce((sum, row) => sum + Number(row.count || 0), 0),
        follows: follows.length,
        messages: messages.length,
        sessions: sessions.filter((row) => row.event_type === 'session_start').length,
        estimatedTimeMinutes: sessionMinutes,
        topInteractionCount: topInteractions.length
      },
      sections: {
        posts: posts.map((row) => ({ id: Number(row.id || 0), title: 'Post', text: preview(row.text), createdAt: String(row.created_at || ''), meta: String(row.media_url || '') })),
        comments: [...comments, ...photoComments].map((row) => ({ id: Number(row.id || 0), title: row.photo_id ? `Fotoğraf #${row.photo_id}` : `Post #${row.post_id}`, text: preview(row.text), createdAt: String(row.created_at || ''), meta: preview(row.target_text, 120) })),
        postLikes: postLikes.map((row) => ({ id: Number(row.id || 0), title: `Post #${row.post_id}`, text: preview(row.target_text, 160), createdAt: String(row.created_at || ''), meta: String(row.reaction_type || 'like') })),
        photos: photos.map((row) => ({ id: Number(row.id || 0), title: row.title || 'Fotoğraf', text: String(row.file_name || ''), createdAt: String(row.created_at || ''), meta: `${Number(row.view_count || 0)} görüntüleme` })),
        photoLikes: photoLikes.map((row) => ({ id: Number(row.id || 0), title: `Fotoğraf #${row.photo_id}`, text: preview(row.target_text, 160), createdAt: String(row.created_at || ''), meta: 'like' })),
        messages: messages.map((row) => ({ id: Number(row.id || 0), title: labels.get(Number(row.peer_user_id || 0)) || `Üye #${row.peer_user_id || 0}`, text: preview(row.body_preview), createdAt: String(row.created_at || ''), meta: row.sender_id === userId ? 'gönderdi' : 'aldı' })),
        follows: follows.map((row) => ({ id: Number(row.id || 0), title: labels.get(Number(row.target_user_id || 0)) || `Üye #${row.target_user_id || 0}`, text: 'Takip ediyor', createdAt: String(row.created_at || ''), meta: row.target_handle ? `@${row.target_handle}` : '' })),
        profileViews: profileViews.map((row) => ({ id: Number(row.target_id || 0), title: labels.get(Number(row.target_id || 0)) || `Üye #${row.target_id || 0}`, text: `${Number(row.count || 0)} profil görüntüleme`, createdAt: String(row.last_seen_at || ''), meta: String(row.first_seen_at || '') })),
        photoViews: photoViews.map((row) => ({ id: Number(row.target_id || 0), title: row.title || `Fotoğraf #${row.target_id || 0}`, text: `${Number(row.count || 0)} fotoğraf görüntüleme`, createdAt: String(row.last_seen_at || ''), meta: row.file_name || String(row.first_seen_at || '') })),
        sessions: sessions.map((row) => ({ id: Number(row.id || 0), title: row.event_type === 'session_end' ? 'Çıkış' : 'Giriş', text: row.event_type, createdAt: String(row.occurred_at || ''), meta: String(row.target_id || '') })),
        timeline: timeline.map((row) => ({ id: Number(row.id || 0), title: String(row.event_type || ''), text: `${row.target_type || ''} ${row.target_id || ''}`.trim(), createdAt: String(row.occurred_at || ''), meta: JSON.stringify(parseMetadata(row.metadata)).slice(0, 180) })),
        topInteractions
      }
    };
  }

  function estimateSessionMinutes(rows) {
    const ordered = [...rows]
      .map((row) => ({ type: String(row.event_type || ''), at: new Date(row.occurred_at).getTime() }))
      .filter((row) => Number.isFinite(row.at))
      .sort((a, b) => a.at - b.at);
    let openStart = null;
    let total = 0;
    for (const row of ordered) {
      if (row.type === 'session_start') {
        openStart = row.at;
      } else if (row.type === 'session_end' && openStart) {
        total += Math.min(Math.max(row.at - openStart, 0), 12 * 60 * 60 * 1000);
        openStart = null;
      }
    }
    return Math.round(total / 60000);
  }

  app.get('/api/admin/root/member-activity/users', ...rootOnly, asyncRoute(async (req, res) => {
    res.json({ users: await readRootActivityUsers(req.query?.q, limitInt(req.query?.limit, 30, 80)) });
  }));

  app.get('/api/admin/root/member-activity/:userId', ...rootOnly, asyncRoute(async (req, res) => {
    const userId = Number(req.params.userId || 0);
    if (!Number.isFinite(userId) || userId <= 0) {
      return res.status(400).json({ error: 'BAD_USER_ID', message: 'Geçerli bir üye seçin.' });
    }
    const snapshot = await readRootActivitySnapshot(userId);
    if (!snapshot) return res.status(404).json({ error: 'USER_NOT_FOUND', message: 'Üye bulunamadı.' });
    logAdminAction(req, 'root_member_activity_viewed', { targetType: 'user', targetId: String(userId) });
    res.json(snapshot);
  }));

  app.post('/api/admin/factory-reset', factoryResetRateLimit, ...rootOnly, asyncRoute(async (req, res) => {
    const confirmation = String(req.body?.confirmation || '').trim();
    if (confirmation !== FACTORY_RESET_CONFIRMATION) {
      return res.status(400).json({
        error: 'INVALID_CONFIRMATION',
        message: `Type ${FACTORY_RESET_CONFIRMATION} to confirm.`
      });
    }

    const password = String(req.body?.password || '');
    if (!password) {
      return res.status(400).json({
        error: 'PASSWORD_REQUIRED',
        message: 'Current root admin password is required.'
      });
    }
    const passwordOk = await factoryResetService.verifyCurrentPassword(req.authUser, password, verifyPassword);
    if (!passwordOk) {
      writeAppLog('warn', 'factory_reset_password_denied', {
        userId: req.authUser?.id || null,
        ip: req.ip
      });
      return res.status(403).json({ error: 'BAD_PASSWORD', message: 'Password confirmation failed.' });
    }

    const dryRun = req.body?.dryRun === true || req.body?.dry_run === true;
    const result = await factoryResetService.performFactoryReset({
      actor: req.authUser,
      ip: req.ip,
      userAgent: String(req.headers['user-agent'] || '').slice(0, 500),
      dryRun
    });

    if (!dryRun) {
      req.session.destroy(() => {});
      if (adminPushService) {
        adminPushService.notifyFactoryReset({
          actorId: req.authUser?.id || null,
          actorHandle: req.authUser?.username || req.authUser?.kadi || 'bilinmeyen'
        }).catch((err) => writeAppLog('warn', 'admin_push_factory_reset_failed', { message: err?.message }));
      }
    }

    return res.json({
      ok: true,
      ...result,
      confirmationRequired: FACTORY_RESET_CONFIRMATION
    });
  }));

  app.get('/api/admin/test-data/catalog', ...rootOnly, asyncRoute(async (_req, res) => {
    res.json({
      areas: TEST_DATA_AREAS,
      defaults: Object.fromEntries(TEST_DATA_AREAS.map((area) => [area.key, area.defaultCount])),
      limits: {
        maxPerArea: 10,
        maxTotal: 90,
        cooldownMs: 15000
      }
    });
  }));

  app.post('/api/admin/test-data/run', ...rootOnly, asyncRoute(async (req, res) => {
    try {
      const result = await seeder.run({
        counts: req.body?.counts || {},
        dryRun: req.body?.dryRun === true || req.body?.dry_run === true,
        actor: req.authUser || req.adminUser
      });
      logAdminAction(req, 'test_data_seed_run', {
        runId: result.runId,
        dryRun: result.dryRun,
        errorCount: result.errors.length
      });
      res.status(result.ok ? 201 : 207).json(result);
    } catch (err) {
      const status = statusForError(err);
      writeAppLog?.('warn', 'test_data_seed_denied', {
        userId: req.authUser?.id || null,
        status,
        message: err?.message || 'unknown_error'
      });
      res.status(status).json({
        error: status === 429 ? 'TEST_DATA_SEED_COOLDOWN' : 'TEST_DATA_SEED_FAILED',
        message: err?.message || 'Test verisi olusturulamadi.'
      });
    }
  }));

  app.get('/api/admin/permissions', ...rootOnly, asyncRoute(async (_req, res) => {
    await rbacService.seedDefaults();
    res.json({ permissions: await rbacService.listPermissions() });
  }));

  app.get('/api/admin/permission-groups', ...rootOnly, asyncRoute(async (_req, res) => {
    await rbacService.seedDefaults();
    res.json({ groups: await rbacService.listGroups() });
  }));

  app.post('/api/admin/permission-groups', ...rootOnly, asyncRoute(async (req, res) => {
    try {
      await rbacService.seedDefaults();
      await rbacService.createGroup({
        name: req.body?.name,
        description: req.body?.description,
        permissions: req.body?.permissions
      });
      logAdminAction(req, 'permission_group_created', { name: req.body?.name });
      if (adminPushService) {
        adminPushService.notifyPermissionGroupChange({
          actorId: req.authUser?.id,
          actorHandle: req.authUser?.username || req.authUser?.kadi || 'bilinmeyen',
          groupName: String(req.body?.name || ''),
          action: 'oluşturdu'
        }).catch(() => {});
      }
      res.status(201).json({ ok: true, groups: await rbacService.listGroups() });
    } catch (err) {
      res.status(statusForError(err)).json({ error: 'PERMISSION_GROUP_CREATE_FAILED', message: err?.message || 'Failed to create permission group.' });
    }
  }));

  app.put('/api/admin/permission-groups/:id', ...rootOnly, asyncRoute(async (req, res) => {
    try {
      await rbacService.updateGroup(Number(req.params.id), {
        name: req.body?.name,
        description: req.body?.description,
        permissions: req.body?.permissions
      });
      logAdminAction(req, 'permission_group_updated', { targetType: 'permission_group', targetId: req.params.id });
      if (adminPushService) {
        adminPushService.notifyPermissionGroupChange({
          actorId: req.authUser?.id,
          actorHandle: req.authUser?.username || req.authUser?.kadi || 'bilinmeyen',
          groupName: String(req.body?.name || req.params.id || ''),
          action: 'güncelledi'
        }).catch(() => {});
      }
      res.json({ ok: true, groups: await rbacService.listGroups() });
    } catch (err) {
      res.status(statusForError(err)).json({ error: 'PERMISSION_GROUP_UPDATE_FAILED', message: err?.message || 'Failed to update permission group.' });
    }
  }));

  app.delete('/api/admin/permission-groups/:id', ...rootOnly, asyncRoute(async (req, res) => {
    try {
      await rbacService.deleteGroup(Number(req.params.id));
      logAdminAction(req, 'permission_group_deleted', { targetType: 'permission_group', targetId: req.params.id });
      res.json({ ok: true, groups: await rbacService.listGroups() });
    } catch (err) {
      res.status(statusForError(err)).json({ error: 'PERMISSION_GROUP_DELETE_FAILED', message: err?.message || 'Failed to delete permission group.' });
    }
  }));

  app.get('/api/admin/users/permissions', ...rootOnly, asyncRoute(async (req, res) => {
    await rbacService.seedDefaults();
    res.json(await rbacService.listUsersWithGroups({
      q: req.query?.q,
      page: req.query?.page,
      limit: req.query?.limit
    }));
  }));

  app.put('/api/admin/users/:id/permission-group', ...rootOnly, asyncRoute(async (req, res) => {
    try {
      await rbacService.assignUserGroup({
        userId: Number(req.params.id),
        groupId: Number(req.body?.groupId || req.body?.group_id || 0),
        assignedBy: req.authUser?.id || null
      });
      logAdminAction(req, 'user_permission_group_updated', {
        targetType: 'user',
        targetId: req.params.id,
        groupId: Number(req.body?.groupId || req.body?.group_id || 0)
      });
      if (adminPushService) {
        adminPushService.notifyUserPermissionChange({
          actorId: req.authUser?.id,
          actorHandle: req.authUser?.username || req.authUser?.kadi || 'bilinmeyen',
          targetHandle: String(req.body?.targetHandle || req.params.id || ''),
          groupName: String(req.body?.groupName || req.body?.groupId || '')
        }).catch(() => {});
      }
      res.json({ ok: true });
    } catch (err) {
      res.status(statusForError(err)).json({ error: 'USER_PERMISSION_GROUP_UPDATE_FAILED', message: err?.message || 'Failed to update user permission group.' });
    }
  }));
}
