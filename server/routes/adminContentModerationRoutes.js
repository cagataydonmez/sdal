export function registerAdminContentModerationRoutes(app, {
  requireAdmin,
  requireModerationPermission,
  sqlGet,
  sqlAll,
  sqlRun,
  getCurrentUser,
  getModerationScopeContext,
  parseAdminListPagination,
  applyModerationScopeFilter,
  addNotification,
  logAdminAction,
  assignUserToCohort,
  ensureCanModerateTargetUser,
  deletePostById,
  scheduleEngagementRecalculation,
  broadcastChatDelete,
  normalizeBannedWord,
  invalidateBannedWordsCache
}) {
  app.get('/api/new/admin/verification-requests', requireModerationPermission('requests.view'), (req, res) => {
    const actor = req.authUser || getCurrentUser(req);
    const scope = getModerationScopeContext(actor);
    const { page, limit } = parseAdminListPagination(req.query, { defaultLimit: 40, maxLimit: 200 });
    const status = String(req.query.status || '').trim().toLowerCase();
    const q = String(req.query.q || '').trim();
    const params = [];
    const whereParts = [
      "(u.role IS NULL OR LOWER(COALESCE(u.role, 'user')) != 'root')"
    ];
    if (status) {
      whereParts.push("LOWER(COALESCE(r.status, '')) = ?");
      params.push(status);
    }
    if (q) {
      whereParts.push('(LOWER(CAST(u.kadi AS TEXT)) LIKE LOWER(?) OR LOWER(CAST(u.isim AS TEXT)) LIKE LOWER(?) OR LOWER(CAST(u.soyisim AS TEXT)) LIKE LOWER(?))');
      params.push(`%${q}%`, `%${q}%`, `%${q}%`);
    }
    const scopeFilter = applyModerationScopeFilter(scope, params, 'u.mezuniyetyili');
    const whereSql = `WHERE ${whereParts.join(' AND ')}${scopeFilter}`;

    const total = Number(sqlGet(
      `SELECT COUNT(*) AS cnt
       FROM verification_requests r
       LEFT JOIN uyeler u ON u.id = r.user_id
       ${whereSql}`,
      params
    )?.cnt || 0);
    const pages = Math.max(Math.ceil(total / limit), 1);
    const safePage = Math.min(page, pages);
    const safeOffset = (safePage - 1) * limit;

    const items = sqlAll(
      `SELECT r.id, r.user_id, r.status, r.proof_path, r.proof_image_record_id, r.created_at,
              u.kadi, u.isim, u.soyisim, u.mezuniyetyili, u.resim
       FROM verification_requests r
       LEFT JOIN uyeler u ON u.id = r.user_id
       ${whereSql}
       ORDER BY r.id DESC
       LIMIT ? OFFSET ?`,
      [...params, limit, safeOffset]
    );
    res.json({
      items,
      meta: {
        page: safePage,
        pages,
        limit,
        total,
        status: status || '',
        q
      }
    });
  });

  app.post('/api/new/admin/verification-requests/:id', requireModerationPermission('requests.moderate'), (req, res) => {
    const status = req.body?.status;
    const requestId = Number(req.params.id || 0);
    if (!requestId) return res.status(400).send('Geçersiz talep ID.');
    if (!['approved', 'rejected'].includes(status)) return res.status(400).send('Geçersiz durum.');
    const row = sqlGet(
      `SELECT r.*, u.mezuniyetyili
       FROM verification_requests r
       LEFT JOIN uyeler u ON u.id = r.user_id
       WHERE r.id = ?`,
      [requestId]
    );
    if (!row) return res.status(404).send('Talep bulunamadı.');
    const scope = getModerationScopeContext(req.authUser || getCurrentUser(req));
    if (scope.isScopedModerator) {
      const targetYear = String(row.mezuniyetyili || '').trim();
      if (!targetYear || !scope.years.includes(targetYear)) {
        return res.status(403).send('Bu doğrulama talebi kapsamınız dışında.');
      }
    }
    sqlRun('UPDATE verification_requests SET status = ?, reviewed_at = ?, reviewer_id = ? WHERE id = ?', [
      status,
      new Date().toISOString(),
      req.session.userId,
      requestId
    ]);
    const newVerificationStatus = status === 'approved' ? 'verified' : 'rejected';
    sqlRun('UPDATE uyeler SET verified = ?, verification_status = ? WHERE id = ?', [status === 'approved' ? 1 : 0, newVerificationStatus, row.user_id]);

    if (status === 'approved') {
      assignUserToCohort(row.user_id);
    }

    addNotification({
      userId: row.user_id,
      type: status === 'approved' ? 'verification_approved' : 'verification_rejected',
      sourceUserId: req.session.userId,
      entityId: requestId,
      message: status === 'approved'
        ? 'Profil doğrulama talebin onaylandı.'
        : 'Profil doğrulama talebin reddedildi.'
    });

    logAdminAction(req, 'verification_request_review', {
      targetType: 'verification_request',
      targetId: requestId,
      userId: row.user_id,
      status
    });
    res.json({ ok: true });
  });

  app.get('/api/new/admin/groups', requireModerationPermission('groups.view'), (req, res) => {
    const actor = req.authUser || getCurrentUser(req);
    const scope = getModerationScopeContext(actor);
    const { page, limit } = parseAdminListPagination(req.query, { defaultLimit: 50, maxLimit: 250 });
    const q = String(req.query.q || '').trim();
    const params = [];
    const whereParts = ["(owner.role IS NULL OR LOWER(COALESCE(owner.role, 'user')) != 'root')"];
    if (q) {
      whereParts.push('(LOWER(CAST(g.name AS TEXT)) LIKE LOWER(?) OR LOWER(CAST(g.description AS TEXT)) LIKE LOWER(?) OR LOWER(CAST(owner.kadi AS TEXT)) LIKE LOWER(?))');
      params.push(`%${q}%`, `%${q}%`, `%${q}%`);
    }
    const scopeFilter = applyModerationScopeFilter(scope, params, 'owner.mezuniyetyili');
    const whereSql = `WHERE ${whereParts.join(' AND ')}${scopeFilter}`;

    const total = Number(sqlGet(
      `SELECT COUNT(*) AS cnt
       FROM groups g
       LEFT JOIN uyeler owner ON owner.id = g.owner_id
       ${whereSql}`,
      params
    )?.cnt || 0);
    const pages = Math.max(Math.ceil(total / limit), 1);
    const safePage = Math.min(page, pages);
    const safeOffset = (safePage - 1) * limit;

    const items = sqlAll(
      `SELECT g.id, g.name, g.description, g.cover_image, g.owner_id, g.created_at,
              owner.kadi AS owner_kadi, owner.mezuniyetyili AS owner_mezuniyetyili
       FROM groups g
       LEFT JOIN uyeler owner ON owner.id = g.owner_id
       ${whereSql}
       ORDER BY g.id DESC
       LIMIT ? OFFSET ?`,
      [...params, limit, safeOffset]
    );
    res.json({
      items,
      meta: {
        page: safePage,
        pages,
        limit,
        total,
        q
      }
    });
  });

  app.delete('/api/new/admin/groups/:id', requireModerationPermission('groups.delete'), (req, res) => {
    const groupId = Number(req.params.id || 0);
    if (!groupId) return res.status(400).send('Geçersiz grup ID.');
    const group = sqlGet('SELECT id, owner_id FROM groups WHERE id = ?', [groupId]);
    if (!group) return res.status(404).send('Grup bulunamadı.');
    const scope = getModerationScopeContext(req.authUser || getCurrentUser(req));
    if (scope.isScopedModerator) {
      if (!group.owner_id) return res.status(403).send('Sahibi olmayan gruplar için kapsam doğrulanamadı.');
      const owner = sqlGet('SELECT mezuniyetyili FROM uyeler WHERE id = ?', [group.owner_id]);
      const ownerYear = String(owner?.mezuniyetyili || '').trim();
      if (!ownerYear || !scope.years.includes(ownerYear)) {
        return res.status(403).send('Bu grup kapsamınız dışında.');
      }
    }
    sqlRun('DELETE FROM group_members WHERE group_id = ?', [groupId]);
    sqlRun('DELETE FROM group_join_requests WHERE group_id = ?', [groupId]);
    sqlRun('DELETE FROM group_invites WHERE group_id = ?', [groupId]);
    sqlRun('DELETE FROM posts WHERE group_id = ?', [groupId]);
    sqlRun('DELETE FROM group_events WHERE group_id = ?', [groupId]);
    sqlRun('DELETE FROM group_announcements WHERE group_id = ?', [groupId]);
    sqlRun('DELETE FROM groups WHERE id = ?', [groupId]);
    logAdminAction(req, 'group_delete', { targetType: 'group', targetId: groupId });
    res.json({ ok: true });
  });

  app.get('/api/new/admin/stories', requireModerationPermission('stories.view'), (req, res) => {
    const actor = req.authUser || getCurrentUser(req);
    const scope = getModerationScopeContext(actor);
    const { page, limit } = parseAdminListPagination(req.query, { defaultLimit: 60, maxLimit: 250 });
    const q = String(req.query.q || '').trim();
    const params = [];
    const whereParts = ["(u.role IS NULL OR LOWER(COALESCE(u.role, 'user')) != 'root')"];
    if (q) {
      whereParts.push('(LOWER(CAST(s.caption AS TEXT)) LIKE LOWER(?) OR LOWER(CAST(u.kadi AS TEXT)) LIKE LOWER(?))');
      params.push(`%${q}%`, `%${q}%`);
    }
    const scopeFilter = applyModerationScopeFilter(scope, params, 'u.mezuniyetyili');
    const whereSql = `WHERE ${whereParts.join(' AND ')}${scopeFilter}`;

    const total = Number(sqlGet(
      `SELECT COUNT(*) AS cnt
       FROM stories s
       LEFT JOIN uyeler u ON u.id = s.user_id
       ${whereSql}`,
      params
    )?.cnt || 0);
    const pages = Math.max(Math.ceil(total / limit), 1);
    const safePage = Math.min(page, pages);
    const safeOffset = (safePage - 1) * limit;

    const items = sqlAll(
      `SELECT s.id, s.user_id, s.image, s.caption, s.created_at, s.expires_at, u.kadi, u.mezuniyetyili
       FROM stories s
       LEFT JOIN uyeler u ON u.id = s.user_id
       ${whereSql}
       ORDER BY s.id DESC
       LIMIT ? OFFSET ?`,
      [...params, limit, safeOffset]
    );
    res.json({
      items,
      meta: {
        page: safePage,
        pages,
        limit,
        total,
        q
      }
    });
  });

  app.get('/api/new/admin/posts', requireModerationPermission('posts.view'), (req, res) => {
    const actor = req.authUser || getCurrentUser(req);
    const scope = getModerationScopeContext(actor);
    const { page, limit } = parseAdminListPagination(req.query, { defaultLimit: 80, maxLimit: 300 });
    const q = String(req.query.q || '').trim();
    const params = [];
    const whereParts = ["(u.role IS NULL OR LOWER(COALESCE(u.role, 'user')) != 'root')"];
    if (q) {
      whereParts.push('(LOWER(CAST(p.content AS TEXT)) LIKE LOWER(?) OR LOWER(CAST(u.kadi AS TEXT)) LIKE LOWER(?))');
      params.push(`%${q}%`, `%${q}%`);
    }
    const scopeFilter = applyModerationScopeFilter(scope, params, 'u.mezuniyetyili');
    const whereSql = `WHERE ${whereParts.join(' AND ')}${scopeFilter}`;

    const total = Number(sqlGet(
      `SELECT COUNT(*) AS cnt
       FROM posts p
       LEFT JOIN uyeler u ON u.id = p.user_id
       ${whereSql}`,
      params
    )?.cnt || 0);
    const pages = Math.max(Math.ceil(total / limit), 1);
    const safePage = Math.min(page, pages);
    const safeOffset = (safePage - 1) * limit;

    const items = sqlAll(
      `SELECT p.id, p.user_id, p.content, p.image, p.created_at, u.kadi, u.mezuniyetyili
       FROM posts p
       LEFT JOIN uyeler u ON u.id = p.user_id
       ${whereSql}
       ORDER BY p.id DESC
       LIMIT ? OFFSET ?`,
      [...params, limit, safeOffset]
    );
    res.json({
      items,
      meta: {
        page: safePage,
        pages,
        limit,
        total,
        q
      }
    });
  });

  app.delete('/api/new/admin/posts/:id', requireModerationPermission('posts.delete'), (req, res) => {
    const postId = Number(req.params.id || 0);
    if (!postId) return res.status(400).send('Geçersiz gönderi ID.');
    const post = sqlGet('SELECT id, user_id FROM posts WHERE id = ?', [postId]);
    if (!post) return res.status(404).send('Gönderi bulunamadı.');
    const target = ensureCanModerateTargetUser(req, res, post.user_id, { notFoundMessage: 'Gönderi sahibi bulunamadı.' });
    if (!target) return;
    deletePostById(postId);
    logAdminAction(req, 'post_delete', { targetType: 'post', targetId: postId, postId, userId: post.user_id });
    scheduleEngagementRecalculation('post_deleted');
    res.json({ ok: true });
  });

  app.delete('/api/new/admin/stories/:id', requireModerationPermission('stories.delete'), (req, res) => {
    const storyId = Number(req.params.id || 0);
    if (!storyId) return res.status(400).send('Geçersiz hikaye ID.');
    const story = sqlGet('SELECT id, user_id FROM stories WHERE id = ?', [storyId]);
    if (!story) return res.status(404).send('Hikaye bulunamadı.');
    const target = ensureCanModerateTargetUser(req, res, story.user_id, { notFoundMessage: 'Hikaye sahibi bulunamadı.' });
    if (!target) return;
    sqlRun('DELETE FROM story_views WHERE story_id = ?', [storyId]);
    sqlRun('DELETE FROM stories WHERE id = ?', [storyId]);
    logAdminAction(req, 'story_delete', { targetType: 'story', targetId: storyId, storyId, userId: story.user_id });
    res.json({ ok: true });
  });

  app.get('/api/new/admin/chat/messages', requireModerationPermission('chat.view'), (req, res) => {
    const actor = req.authUser || getCurrentUser(req);
    const scope = getModerationScopeContext(actor);
    const { page, limit } = parseAdminListPagination(req.query, { defaultLimit: 80, maxLimit: 300 });
    const q = String(req.query.q || '').trim();
    const params = [];
    const whereParts = ["(u.role IS NULL OR LOWER(COALESCE(u.role, 'user')) != 'root')"];
    if (q) {
      whereParts.push('(LOWER(CAST(c.message AS TEXT)) LIKE LOWER(?) OR LOWER(CAST(u.kadi AS TEXT)) LIKE LOWER(?))');
      params.push(`%${q}%`, `%${q}%`);
    }
    const scopeFilter = applyModerationScopeFilter(scope, params, 'u.mezuniyetyili');
    const whereSql = `WHERE ${whereParts.join(' AND ')}${scopeFilter}`;

    const total = Number(sqlGet(
      `SELECT COUNT(*) AS cnt
       FROM chat_messages c
       LEFT JOIN uyeler u ON u.id = c.user_id
       ${whereSql}`,
      params
    )?.cnt || 0);
    const pages = Math.max(Math.ceil(total / limit), 1);
    const safePage = Math.min(page, pages);
    const safeOffset = (safePage - 1) * limit;
    let items = sqlAll(
      `SELECT c.id, c.user_id, c.message, c.created_at, u.kadi, u.mezuniyetyili
       FROM chat_messages c
       LEFT JOIN uyeler u ON u.id = c.user_id
       ${whereSql}
       ORDER BY c.id DESC
       LIMIT ? OFFSET ?`,
      [...params, limit, safeOffset]
    );

    if (!items.length && total === 0 && !scope.isScopedModerator) {
      try {
        const fallbackParams = [];
        const fallbackWhere = [];
        if (q) {
          fallbackWhere.push('(LOWER(CAST(h.metin AS TEXT)) LIKE LOWER(?) OR LOWER(CAST(h.kadi AS TEXT)) LIKE LOWER(?))');
          fallbackParams.push(`%${q}%`, `%${q}%`);
        }
        const fallbackWhereSql = fallbackWhere.length ? `WHERE ${fallbackWhere.join(' AND ')}` : '';
        const legacyTotal = Number(sqlGet(`SELECT COUNT(*) AS cnt FROM hmes h ${fallbackWhereSql}`, fallbackParams)?.cnt || 0);
        const legacyPages = Math.max(Math.ceil(legacyTotal / limit), 1);
        const legacySafePage = Math.min(page, legacyPages);
        const legacyOffset = (legacySafePage - 1) * limit;
        items = sqlAll(
          `SELECT h.id, NULL AS user_id, h.metin AS message, h.tarih AS created_at, h.kadi, NULL AS mezuniyetyili
           FROM hmes h
           ${fallbackWhereSql}
           ORDER BY h.id DESC
           LIMIT ? OFFSET ?`,
          [...fallbackParams, limit, legacyOffset]
        );
        return res.json({
          items,
          meta: { page: legacySafePage, pages: legacyPages, limit, total: legacyTotal, q, source: 'legacy_hmes' }
        });
      } catch {
        // ignore fallback query errors
      }
    }

    res.json({
      items,
      meta: {
        page: safePage,
        pages,
        limit,
        total,
        q,
        source: 'chat_messages'
      }
    });
  });

  app.delete('/api/new/admin/chat/messages/:id', requireModerationPermission('chat.delete'), (req, res) => {
    const messageId = Number(req.params.id || 0);
    if (!messageId) return res.status(400).send('Geçersiz mesaj ID.');
    const message = sqlGet('SELECT id, user_id FROM chat_messages WHERE id = ?', [messageId]);
    if (!message) return res.status(404).send('Mesaj bulunamadı.');
    const target = ensureCanModerateTargetUser(req, res, message.user_id, { notFoundMessage: 'Mesaj sahibi bulunamadı.' });
    if (!target) return;
    sqlRun('DELETE FROM chat_messages WHERE id = ?', [messageId]);
    broadcastChatDelete(messageId);
    logAdminAction(req, 'chat_message_delete', { targetType: 'chat_message', targetId: messageId, messageId, userId: message.user_id });
    scheduleEngagementRecalculation('chat_message_deleted');
    res.json({ ok: true });
  });

  app.get('/api/new/admin/messages', requireModerationPermission('messages.view'), (req, res) => {
    const actor = req.authUser || getCurrentUser(req);
    const scope = getModerationScopeContext(actor);
    const { page, limit } = parseAdminListPagination(req.query, { defaultLimit: 80, maxLimit: 300 });
    const q = String(req.query.q || '').trim();
    const params = [];
    const whereParts = [
      "(u1.role IS NULL OR LOWER(COALESCE(u1.role, 'user')) != 'root')",
      "(u2.role IS NULL OR LOWER(COALESCE(u2.role, 'user')) != 'root')"
    ];
    if (q) {
      whereParts.push('(LOWER(CAST(g.konu AS TEXT)) LIKE LOWER(?) OR LOWER(CAST(g.mesaj AS TEXT)) LIKE LOWER(?) OR LOWER(CAST(u1.kadi AS TEXT)) LIKE LOWER(?) OR LOWER(CAST(u2.kadi AS TEXT)) LIKE LOWER(?))');
      params.push(`%${q}%`, `%${q}%`, `%${q}%`, `%${q}%`);
    }
    if (scope.isScopedModerator) {
      if (!scope.years.length) {
        whereParts.push('1 = 0');
      } else {
        const placeholders = scope.years.map(() => '?').join(', ');
        whereParts.push(`(CAST(COALESCE(u1.mezuniyetyili, '') AS TEXT) IN (${placeholders}) OR CAST(COALESCE(u2.mezuniyetyili, '') AS TEXT) IN (${placeholders}))`);
        params.push(...scope.years, ...scope.years);
      }
    }
    const whereSql = `WHERE ${whereParts.join(' AND ')}`;
    const total = Number(sqlGet(
      `SELECT COUNT(*) AS cnt
       FROM gelenkutusu g
       LEFT JOIN uyeler u1 ON u1.id = g.kimden
       LEFT JOIN uyeler u2 ON u2.id = g.kime
       ${whereSql}`,
      params
    )?.cnt || 0);
    const pages = Math.max(Math.ceil(total / limit), 1);
    const safePage = Math.min(page, pages);
    const safeOffset = (safePage - 1) * limit;
    const items = sqlAll(
      `SELECT g.id, g.konu, g.mesaj, g.tarih, g.kimden, g.kime,
              u1.kadi AS kimden_kadi, u2.kadi AS kime_kadi,
              u1.mezuniyetyili AS kimden_mezuniyetyili, u2.mezuniyetyili AS kime_mezuniyetyili
       FROM gelenkutusu g
       LEFT JOIN uyeler u1 ON u1.id = g.kimden
       LEFT JOIN uyeler u2 ON u2.id = g.kime
       ${whereSql}
       ORDER BY g.id DESC
       LIMIT ? OFFSET ?`,
      [...params, limit, safeOffset]
    );
    res.json({
      items,
      meta: {
        page: safePage,
        pages,
        limit,
        total,
        q
      }
    });
  });

  app.delete('/api/new/admin/messages/:id', requireModerationPermission('messages.delete'), (req, res) => {
    const messageId = Number(req.params.id || 0);
    if (!messageId) return res.status(400).send('Geçersiz mesaj ID.');
    const item = sqlGet('SELECT id, kimden, kime FROM gelenkutusu WHERE id = ?', [messageId]);
    if (!item) return res.status(404).send('Mesaj bulunamadı.');
    const scope = getModerationScopeContext(req.authUser || getCurrentUser(req));
    if (scope.isScopedModerator) {
      const sender = sqlGet('SELECT mezuniyetyili FROM uyeler WHERE id = ?', [item.kimden]);
      const recipient = sqlGet('SELECT mezuniyetyili FROM uyeler WHERE id = ?', [item.kime]);
      const senderYear = String(sender?.mezuniyetyili || '').trim();
      const recipientYear = String(recipient?.mezuniyetyili || '').trim();
      const touchesScopedYear = [senderYear, recipientYear].some((year) => year && scope.years.includes(year));
      if (!touchesScopedYear) {
        return res.status(403).send('Bu mesaj kapsamınız dışında.');
      }
    }
    sqlRun('DELETE FROM gelenkutusu WHERE id = ?', [messageId]);
    logAdminAction(req, 'inbox_message_delete', { targetType: 'direct_message', targetId: messageId, messageId });
    res.json({ ok: true });
  });

  app.get('/api/new/admin/filters', requireAdmin, (req, res) => {
    const { page, limit } = parseAdminListPagination(req.query, { defaultLimit: 80, maxLimit: 300 });
    const q = String(req.query.q || '').trim();
    const whereParts = ['1=1'];
    const params = [];
    if (q) {
      whereParts.push('LOWER(CAST(kufur AS TEXT)) LIKE LOWER(?)');
      params.push(`%${q}%`);
    }
    const whereSql = `WHERE ${whereParts.join(' AND ')}`;
    const total = Number(sqlGet(`SELECT COUNT(*) AS cnt FROM filtre ${whereSql}`, params)?.cnt || 0);
    const pages = Math.max(Math.ceil(total / limit), 1);
    const safePage = Math.min(page, pages);
    const safeOffset = (safePage - 1) * limit;
    const items = sqlAll(
      `SELECT id, kufur
       FROM filtre
       ${whereSql}
       ORDER BY id DESC
       LIMIT ? OFFSET ?`,
      [...params, limit, safeOffset]
    );
    res.json({
      items,
      meta: {
        page: safePage,
        pages,
        limit,
        total,
        q
      }
    });
  });

  app.post('/api/new/admin/filters', requireAdmin, (req, res) => {
    const kufur = normalizeBannedWord(req.body?.kufur);
    if (!kufur) return res.status(400).send('Kelime gerekli.');
    const exists = sqlGet('SELECT id FROM filtre WHERE LOWER(kufur) = LOWER(?)', [kufur]);
    if (exists?.id) return res.status(400).send('Kelime zaten var.');
    const result = sqlRun('INSERT INTO filtre (kufur) VALUES (?)', [kufur]);
    invalidateBannedWordsCache();
    logAdminAction(req, 'blocked_term_create', { targetType: 'blocked_term', targetId: result?.lastInsertRowid || null, kufur });
    res.json({ ok: true, id: result?.lastInsertRowid });
  });

  app.put('/api/new/admin/filters/:id', requireAdmin, (req, res) => {
    const id = Number(req.params.id || 0);
    if (!id) return res.status(400).send('Geçersiz kelime ID.');
    const kufur = normalizeBannedWord(req.body?.kufur);
    if (!kufur) return res.status(400).send('Kelime gerekli.');
    const row = sqlGet('SELECT id FROM filtre WHERE id = ?', [id]);
    if (!row) return res.status(404).send('Kelime bulunamadı.');
    const exists = sqlGet('SELECT id FROM filtre WHERE LOWER(kufur) = LOWER(?) AND id <> ?', [kufur, id]);
    if (exists?.id) return res.status(400).send('Kelime zaten var.');
    sqlRun('UPDATE filtre SET kufur = ? WHERE id = ?', [kufur, id]);
    invalidateBannedWordsCache();
    logAdminAction(req, 'blocked_term_update', { targetType: 'blocked_term', targetId: id, kufur });
    res.json({ ok: true });
  });

  app.delete('/api/new/admin/filters/:id', requireAdmin, (req, res) => {
    const id = Number(req.params.id || 0);
    if (!id) return res.status(400).send('Geçersiz kelime ID.');
    const exists = sqlGet('SELECT id, kufur FROM filtre WHERE id = ?', [id]);
    if (!exists) return res.status(404).send('Kelime bulunamadı.');
    sqlRun('DELETE FROM filtre WHERE id = ?', [id]);
    invalidateBannedWordsCache();
    logAdminAction(req, 'blocked_term_delete', { targetType: 'blocked_term', targetId: id, kufur: exists.kufur });
    res.json({ ok: true });
  });
}
