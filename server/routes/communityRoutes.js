export function registerCommunityRoutes(app, {
  requireAuth,
  requireAdmin,
  uploadRateLimit,
  postUpload,
  listOnlineMembersAsync,
  getCurrentUser,
  hasAdminSession,
  sameUserId,
  dbDriver,
  sqlGetAsync,
  sqlRunAsync,
  sqlAllAsync,
  addNotification,
  sanitizePlainUserText,
  formatUserText,
  isFormattedContentEmpty,
  toDbFlagForColumn,
  processDiskImageUpload,
  uploadImagePresets,
  writeAppLog,
  createEventRecord,
  createEntityFeedPost,
  normalizeEventResponse,
  getEventResponseBundle,
  notifyMentions
}) {
  app.get('/api/new/online-members', requireAuth, async (req, res) => {
    try {
      const limit = Math.min(Math.max(parseInt(req.query.limit || '12', 10), 1), 80);
      const items = await listOnlineMembersAsync({
        limit,
        excludeUserId: String(req.query.excludeSelf || '1') === '1' ? req.session.userId : null
      });
      res.setHeader('Cache-Control', 'no-store');
      res.json({ items, count: items.length, now: new Date().toISOString() });
    } catch (err) {
      console.error('GET /api/new/online-members failed:', err);
      writeAppLog('error', 'online_members_failed', {
        message: err?.message || 'unknown_error',
        stack: String(err?.stack || '').slice(0, 1000)
      });
      res.setHeader('Cache-Control', 'no-store');
      res.json({ items: [], count: 0, now: new Date().toISOString(), degraded: true });
    }
  });

  app.get('/api/new/events', requireAuth, async (req, res) => {
    try {
      const user = getCurrentUser(req);
      const isAdmin = hasAdminSession(req, user);
      const limit = Math.min(Math.max(parseInt(req.query.limit || '20', 10), 1), 100);
      const offset = Math.max(parseInt(req.query.offset || '0', 10), 0);
      const orderExpr = dbDriver === 'postgres'
        ? 'COALESCE(e.starts_at, e.created_at)'
        : "COALESCE(NULLIF(e.starts_at, ''), e.created_at)";
      const rows = await sqlAllAsync(
        `SELECT e.*, u.kadi AS creator_kadi
         FROM events e
         LEFT JOIN uyeler u ON u.id = e.created_by
         ${isAdmin ? '' : "WHERE (COALESCE(CAST(e.approved AS INTEGER), 1) = 1 OR LOWER(CAST(e.approved AS TEXT)) IN ('true','evet','yes'))"}
         ORDER BY ${orderExpr} ASC, e.id DESC
         LIMIT ? OFFSET ?`,
        [limit, offset]
      );

      const items = await Promise.all(rows.map(async (row) => {
        const canSeePrivate = isAdmin || sameUserId(row.created_by, req.session.userId);
        const bundle = await getEventResponseBundle(row, req.session.userId, canSeePrivate);
        return {
          ...row,
          response_counts: bundle.counts,
          my_response: bundle.myResponse,
          attendees: bundle.attendees,
          decliners: bundle.decliners,
          response_visibility: bundle.visibility,
          can_manage_responses: canSeePrivate
        };
      }));

      res.json({ items, hasMore: rows.length === limit });
    } catch (err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.post('/api/new/events', requireAuth, async (req, res) => {
    try {
      const created = await createEventRecord(req, { image: req.body?.image || null });
      if (created.error) return res.status(400).send(created.error);
      return res.json(created);
    } catch (err) {
      writeAppLog('error', 'event_create_failed', {
        userId: req.session?.userId || null,
        message: err?.message || 'unknown_error',
        stack: String(err?.stack || '').slice(0, 1000)
      });
      return res.status(500).send('Etkinlik kaydı sırasında beklenmeyen bir hata oluştu.');
    }
  });

  app.post('/api/new/events/upload', requireAuth, uploadRateLimit, postUpload.single('image'), async (req, res) => {
    try {
      let processedUpload = null;
      if (req.file?.path) {
        processedUpload = await processDiskImageUpload({
          req,
          res,
          file: req.file,
          bucket: 'event_image',
          preset: uploadImagePresets.eventImage
        });
        if (!processedUpload.ok) return res.status(processedUpload.statusCode).send(processedUpload.message);
      }
      const created = await createEventRecord(req, { image: processedUpload?.url || null });
      if (created.error) return res.status(400).send(created.error);
      return res.json(created);
    } catch (err) {
      writeAppLog('error', 'event_upload_create_failed', {
        userId: req.session?.userId || null,
        message: err?.message || 'unknown_error',
        stack: String(err?.stack || '').slice(0, 1000)
      });
      return res.status(500).send('Etkinlik yükleme sırasında beklenmeyen bir hata oluştu.');
    }
  });

  app.post('/api/new/events/:id/approve', requireAdmin, async (req, res) => {
    try {
      const approved = String(req.body?.approved || '1') === '1';
      const now = new Date().toISOString();
      await sqlRunAsync(
        'UPDATE events SET approved = ?, approved_by = ?, approved_at = ? WHERE id = ?',
        [toDbFlagForColumn('events', 'approved', approved), req.session.userId, now, req.params.id]
      );
      if (approved && createEntityFeedPost) {
        const ev = await sqlGetAsync('SELECT id, title, description, created_by FROM events WHERE id = ?', [req.params.id]);
        if (ev) {
          createEntityFeedPost({
            entityType: 'event',
            entityId: Number(ev.id),
            title: ev.title || '',
            excerpt: ev.description || '',
            groupId: null,
            userId: ev.created_by,
            createdAt: now
          }).catch(() => {});
        }
      }
      res.json({ ok: true });
    } catch (err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.delete('/api/new/events/:id', requireAdmin, async (req, res) => {
    try {
      await sqlRunAsync('DELETE FROM event_comments WHERE event_id = ?', [req.params.id]);
      await sqlRunAsync('DELETE FROM event_responses WHERE event_id = ?', [req.params.id]);
      await sqlRunAsync('DELETE FROM events WHERE id = ?', [req.params.id]);
      res.json({ ok: true });
    } catch (err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  async function _handleEventRespond(req, res, response) {
    try {
      const event = await sqlGetAsync('SELECT * FROM events WHERE id = ?', [req.params.id]);
      if (!event) return res.status(404).send('Etkinlik bulunamadı.');
      if (Number(event.approved || 1) !== 1) return res.status(400).send('Etkinlik henüz yayında değil.');
      const now = new Date().toISOString();
      const existing = await sqlGetAsync('SELECT id FROM event_responses WHERE event_id = ? AND user_id = ?', [req.params.id, req.session.userId]);
      if (existing) {
        await sqlRunAsync('UPDATE event_responses SET response = ?, updated_at = ? WHERE id = ?', [response, now, existing.id]);
      } else {
        await sqlRunAsync(
          'INSERT INTO event_responses (event_id, user_id, response, created_at, updated_at) VALUES (?, ?, ?, ?, ?)',
          [req.params.id, req.session.userId, response, now, now]
        );
      }
      if (event.created_by && !sameUserId(event.created_by, req.session.userId)) {
        addNotification({
          userId: event.created_by,
          type: 'event_response',
          sourceUserId: req.session.userId,
          entityId: req.params.id,
          message: response === 'attend' ? 'Etkinliğine katılacağını belirtti.' : 'Etkinliğine katılamayacağını belirtti.'
        });
      }
      const canSeePrivate = sameUserId(event.created_by, req.session.userId);
      const bundle = await getEventResponseBundle(event, req.session.userId, canSeePrivate);
      return res.json({ ok: true, myResponse: bundle.myResponse, counts: bundle.counts });
    } catch (err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  }

  app.post('/api/new/events/:id/respond', requireAuth, async (req, res) => {
    const response = normalizeEventResponse(req.body?.response);
    if (!response) return res.status(400).send('Geçersiz yanıt.');
    return _handleEventRespond(req, res, response);
  });

  // Flutter-compatible aliases: no request body required
  app.post('/api/new/events/:id/attend', requireAuth, (req, res) =>
    _handleEventRespond(req, res, 'attend')
  );
  app.post('/api/new/events/:id/decline', requireAuth, (req, res) =>
    _handleEventRespond(req, res, 'decline')
  );

  app.post('/api/new/events/:id/response-visibility', requireAuth, async (req, res) => {
    try {
      const event = await sqlGetAsync('SELECT id, created_by FROM events WHERE id = ?', [req.params.id]);
      if (!event) return res.status(404).send('Etkinlik bulunamadı.');
      const user = getCurrentUser(req);
      const isAdmin = hasAdminSession(req, user);
      if (!sameUserId(event.created_by, req.session.userId) && !isAdmin) {
        return res.status(403).send('Sadece etkinlik sahibi ayarları değiştirebilir.');
      }
      const showCounts = Boolean(req.body?.showCounts);
      const showAttendeeNames = Boolean(req.body?.showAttendeeNames);
      const showDeclinerNames = Boolean(req.body?.showDeclinerNames);
      await sqlRunAsync(
        `UPDATE events
         SET show_response_counts = ?, show_attendee_names = ?, show_decliner_names = ?
         WHERE id = ?`,
        [
          toDbFlagForColumn('events', 'show_response_counts', showCounts),
          toDbFlagForColumn('events', 'show_attendee_names', showAttendeeNames),
          toDbFlagForColumn('events', 'show_decliner_names', showDeclinerNames),
          req.params.id
        ]
      );
      const updated = await sqlGetAsync(
        'SELECT show_response_counts, show_attendee_names, show_decliner_names FROM events WHERE id = ?',
        [req.params.id]
      );
      res.json({
        ok: true,
        visibility: {
          showCounts: Number(updated?.show_response_counts || 0) === 1,
          showAttendeeNames: Number(updated?.show_attendee_names || 0) === 1,
          showDeclinerNames: Number(updated?.show_decliner_names || 0) === 1
        }
      });
    } catch (err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.get('/api/new/events/:id/comments', requireAuth, async (req, res) => {
    try {
      const rows = await sqlAllAsync(
        `SELECT c.id, c.comment, c.created_at, u.id AS user_id, u.kadi, u.isim, u.soyisim, u.resim, u.verified
         FROM event_comments c
         LEFT JOIN uyeler u ON u.id = c.user_id
         WHERE c.event_id = ?
         ORDER BY c.id DESC`,
        [req.params.id]
      );
      res.json({ items: rows });
    } catch (err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.post('/api/new/events/:id/comments', requireAuth, async (req, res) => {
    try {
      const event = await sqlGetAsync('SELECT * FROM events WHERE id = ?', [req.params.id]);
      if (!event) return res.status(404).send('Etkinlik bulunamadı.');
      const commentRaw = req.body?.comment || '';
      const comment = formatUserText(commentRaw);
      if (isFormattedContentEmpty(comment)) return res.status(400).send('Yorum boş olamaz.');
      const now = new Date().toISOString();
      await sqlRunAsync('INSERT INTO event_comments (event_id, user_id, comment, created_at) VALUES (?, ?, ?, ?)', [
        req.params.id,
        req.session.userId,
        comment,
        now
      ]);
      if (event.created_by && !sameUserId(event.created_by, req.session.userId)) {
        addNotification({
          userId: event.created_by,
          type: 'event_comment',
          sourceUserId: req.session.userId,
          entityId: req.params.id,
          message: 'Etkinliğine yorum yaptı.'
        });
      }
      notifyMentions({
        text: commentRaw,
        sourceUserId: req.session.userId,
        entityId: req.params.id,
        type: 'mention_event',
        message: 'Etkinlik yorumunda senden bahsetti.'
      });
      res.json({ ok: true });
    } catch (err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.post('/api/new/events/:id/notify', requireAuth, async (req, res) => {
    try {
      const event = await sqlGetAsync(
        "SELECT id, title, created_by FROM events WHERE id = ? AND (COALESCE(CAST(approved AS INTEGER), 1) = 1 OR LOWER(CAST(approved AS TEXT)) IN ('true','evet','yes'))",
        [req.params.id]
      );
      if (!event) return res.status(404).send('Etkinlik bulunamadı.');
      const user = getCurrentUser(req);
      const isAdmin = hasAdminSession(req, user);
      if (!isAdmin && !sameUserId(event.created_by, req.session.userId)) {
        return res.status(403).send('Sadece etkinlik sahibi veya admin bildirim gonderebilir.');
      }
      const mode = String(req.body?.mode || 'invite').trim().toLowerCase();
      const normalizedMode = mode === 'reminder' || mode === 'starts_soon' ? mode : 'invite';
      const targets = normalizedMode === 'invite'
        ? (await sqlAllAsync('SELECT follower_id AS user_id FROM follows WHERE following_id = ?', [req.session.userId]) || [])
        : (await sqlAllAsync(
            `SELECT DISTINCT user_id
             FROM event_responses
             WHERE event_id = ?
               AND LOWER(TRIM(COALESCE(response, ''))) = 'attend'`,
            [req.params.id]
          ) || []);
      let count = 0;
      for (const row of targets) {
        const targetUserId = Number(row?.user_id || row?.follower_id || 0);
        if (!targetUserId || sameUserId(targetUserId, req.session.userId)) continue;
        addNotification({
          userId: targetUserId,
          type: normalizedMode === 'invite' ? 'event_invite' : normalizedMode === 'reminder' ? 'event_reminder' : 'event_starts_soon',
          sourceUserId: req.session.userId,
          entityId: event.id,
          message: normalizedMode === 'invite'
            ? `Seni "${event.title}" etkinliğine davet etti.`
            : normalizedMode === 'reminder'
              ? `"${event.title}" etkinliği için hatırlatma gönderdi.`
              : `"${event.title}" etkinliği çok yakında başlıyor.`
        });
        count += 1;
      }
      res.json({ ok: true, count, mode: normalizedMode });
    } catch (err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.get('/api/new/announcements', requireAuth, async (req, res) => {
    try {
      const user = getCurrentUser(req);
      const isAdmin = hasAdminSession(req, user);
      const limit = Math.min(Math.max(parseInt(req.query.limit || '20', 10), 1), 100);
      const offset = Math.max(parseInt(req.query.offset || '0', 10), 0);
      const rows = await sqlAllAsync(
        `SELECT a.*, u.kadi AS creator_kadi
         FROM announcements a
         LEFT JOIN uyeler u ON u.id = a.created_by
         ${isAdmin ? '' : "WHERE (COALESCE(CAST(a.approved AS INTEGER), 1) = 1 OR LOWER(CAST(a.approved AS TEXT)) IN ('true','evet','yes'))"}
         ORDER BY a.id DESC`
         + ' LIMIT ? OFFSET ?',
        [limit, offset]
      );
      res.json({ items: rows, hasMore: rows.length === limit });
    } catch (err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.post('/api/new/announcements', requireAuth, async (req, res) => {
    try {
      const { body, image } = req.body || {};
      const title = sanitizePlainUserText(String(req.body?.title || '').trim(), 180);
      const formattedBody = formatUserText(body || '');
      if (!title || isFormattedContentEmpty(formattedBody)) return res.status(400).send('Başlık ve içerik gerekli.');
      const user = getCurrentUser(req);
      const isAdmin = hasAdminSession(req, user);
      const now = new Date().toISOString();
      const groupId = req.body?.group_id ? Number(req.body.group_id) : null;
      const result = await sqlRunAsync(
        `INSERT INTO announcements (title, body, image, created_at, created_by, approved, approved_by, approved_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
        [
          title,
          formattedBody,
          image || null,
          now,
          req.session.userId,
          toDbFlagForColumn('announcements', 'approved', isAdmin),
          isAdmin ? req.session.userId : null,
          isAdmin ? now : null
        ]
      );
      if (isAdmin && createEntityFeedPost) {
        createEntityFeedPost({
          entityType: 'announcement',
          entityId: Number(result?.lastInsertRowid || 0),
          title,
          excerpt: body || '',
          groupId,
          userId: req.session.userId,
          createdAt: now
        }).catch(() => {});
      }
      res.json({ ok: true, pending: !isAdmin });
    } catch (err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.post('/api/new/announcements/upload', requireAuth, uploadRateLimit, postUpload.single('image'), async (req, res) => {
    try {
      const title = sanitizePlainUserText(String(req.body?.title || '').trim(), 180);
      const bodyRaw = String(req.body?.body || '');
      const body = formatUserText(bodyRaw);
      if (!title || isFormattedContentEmpty(body)) return res.status(400).send('Başlık ve içerik gerekli.');
      const user = getCurrentUser(req);
      const isAdmin = hasAdminSession(req, user);
      let processedUpload = null;
      if (req.file?.path) {
        processedUpload = await processDiskImageUpload({
          req,
          res,
          file: req.file,
          bucket: 'announcement_image',
          preset: uploadImagePresets.announcementImage
        });
        if (!processedUpload.ok) return res.status(processedUpload.statusCode).send(processedUpload.message);
      }
      const now = new Date().toISOString();
      const groupId = req.body?.group_id ? Number(req.body.group_id) : null;
      const result = await sqlRunAsync(
        `INSERT INTO announcements (title, body, image, created_at, created_by, approved, approved_by, approved_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
        [
          title,
          body,
          processedUpload?.url || null,
          now,
          req.session.userId,
          toDbFlagForColumn('announcements', 'approved', isAdmin),
          isAdmin ? req.session.userId : null,
          isAdmin ? now : null
        ]
      );
      if (isAdmin && createEntityFeedPost) {
        createEntityFeedPost({
          entityType: 'announcement',
          entityId: Number(result?.lastInsertRowid || 0),
          title,
          excerpt: bodyRaw,
          groupId,
          userId: req.session.userId,
          createdAt: now
        }).catch(() => {});
      }
      res.json({ ok: true, pending: !isAdmin });
    } catch (err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.post('/api/new/announcements/:id/approve', requireAdmin, async (req, res) => {
    try {
      const approvedInput = Object.prototype.hasOwnProperty.call(req.body || {}, 'approved')
        ? req.body?.approved
        : '1';
      const approved = String(approvedInput) === '1';
      const now = new Date().toISOString();
      const announcement = await sqlGetAsync('SELECT id, created_by, title, body FROM announcements WHERE id = ?', [req.params.id]);
      await sqlRunAsync(
        'UPDATE announcements SET approved = ?, approved_by = ?, approved_at = ? WHERE id = ?',
        [toDbFlagForColumn('announcements', 'approved', approved), req.session.userId, now, req.params.id]
      );
      if (announcement?.created_by && !sameUserId(announcement.created_by, req.session.userId)) {
        addNotification({
          userId: announcement.created_by,
          type: approved ? 'announcement_approved' : 'announcement_rejected',
          sourceUserId: req.session.userId,
          entityId: Number(req.params.id || 0),
          message: approved
            ? `"${announcement.title || 'Duyuru'}" duyurun yayınlandı.`
            : `"${announcement.title || 'Duyuru'}" duyurun reddedildi.`
        });
      }
      if (approved && announcement && createEntityFeedPost) {
        createEntityFeedPost({
          entityType: 'announcement',
          entityId: Number(announcement.id),
          title: announcement.title || '',
          excerpt: announcement.body || '',
          groupId: null,
          userId: announcement.created_by,
          createdAt: now
        }).catch(() => {});
      }
      res.json({ ok: true });
    } catch (err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.delete('/api/new/announcements/:id', requireAdmin, async (req, res) => {
    try {
      await sqlRunAsync('DELETE FROM announcements WHERE id = ?', [req.params.id]);
      res.json({ ok: true });
    } catch (err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  // ── Single event detail ───────────────────────────────────────────────────
  app.get('/api/new/events/:id', requireAuth, async (req, res) => {
    try {
      const user = getCurrentUser(req);
      const isAdmin = hasAdminSession(req, user);
      const row = await sqlGetAsync(
        `SELECT e.*, u.kadi AS creator_kadi FROM events e LEFT JOIN uyeler u ON u.id = e.created_by WHERE e.id = ?`,
        [req.params.id]
      );
      if (!row) return res.status(404).send('Etkinlik bulunamadı.');
      const approved = Number(row.approved ?? 1) === 1 || String(row.approved).toLowerCase() === 'true';
      if (!approved && !isAdmin) return res.status(403).send('Etkinlik yayında değil.');
      const canSeePrivate = isAdmin || sameUserId(row.created_by, req.session.userId);
      const bundle = await getEventResponseBundle(row, req.session.userId, canSeePrivate);
      const comments = await sqlAllAsync(
        `SELECT c.id, c.comment, c.created_at, u.id AS user_id, u.kadi, u.isim, u.soyisim, u.resim, u.verified
         FROM event_comments c LEFT JOIN uyeler u ON u.id = c.user_id
         WHERE c.event_id = ? ORDER BY c.id ASC`,
        [req.params.id]
      );
      const likeCount = (await sqlGetAsync('SELECT COUNT(*) AS cnt FROM entity_reactions WHERE entity_type = ? AND entity_id = ?', ['event', req.params.id]))?.cnt || 0;
      const liked = !!(await sqlGetAsync('SELECT id FROM entity_reactions WHERE entity_type = ? AND entity_id = ? AND user_id = ?', ['event', req.params.id, req.session.userId]));
      res.json({
        ...row,
        response_counts: bundle.counts,
        my_response: bundle.myResponse,
        response_visibility: bundle.visibility,
        can_manage_responses: canSeePrivate,
        comments,
        like_count: likeCount,
        liked,
        allow_comments: Number(row.allow_comments ?? 1),
        allow_likes: Number(row.allow_likes ?? 1),
      });
    } catch (err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  // ── Edit event ────────────────────────────────────────────────────────────
  app.patch('/api/new/events/:id', requireAuth, async (req, res) => {
    try {
      const user = getCurrentUser(req);
      const isAdmin = hasAdminSession(req, user);
      const row = await sqlGetAsync('SELECT id, created_by FROM events WHERE id = ?', [req.params.id]);
      if (!row) return res.status(404).send('Etkinlik bulunamadı.');
      if (!isAdmin && !sameUserId(row.created_by, req.session.userId)) return res.status(403).send('Bu etkinliği düzenleme yetkin yok.');

      const updates = [];
      const updateParams = [];
      if (req.body.title !== undefined && req.body.title !== null) {
        updates.push('title = ?');
        updateParams.push(String(req.body.title).trim());
      }
      if (req.body.description !== undefined && req.body.description !== null) {
        updates.push('description = ?');
        updateParams.push(String(req.body.description).trim());
      }
      if (req.body.location !== undefined && req.body.location !== null) {
        updates.push('location = ?');
        updateParams.push(String(req.body.location).trim());
      }
      if (req.body.startsAt !== undefined && req.body.startsAt !== null) {
        updates.push('starts_at = ?');
        updateParams.push(String(req.body.startsAt).trim());
      }
      if (req.body.endsAt !== undefined && req.body.endsAt !== null) {
        updates.push('ends_at = ?');
        updateParams.push(String(req.body.endsAt).trim());
      }
      if (req.body.image !== undefined) {
        updates.push('image = ?');
        updateParams.push(req.body.image || null);
      }

      if (updates.length === 0) return res.status(400).send('Güncellenecek alan yok.');

      updateParams.push(req.params.id);
      await sqlRunAsync(`UPDATE events SET ${updates.join(', ')} WHERE id = ?`, updateParams);

      const updated = await sqlGetAsync('SELECT * FROM events WHERE id = ?', [req.params.id]);
      res.json({ ok: true, ...updated });
    } catch (err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  // ── Like/unlike event ─────────────────────────────────────────────────────
  app.post('/api/new/events/:id/like', requireAuth, async (req, res) => {
    try {
      const event = await sqlGetAsync('SELECT id, created_by, allow_likes FROM events WHERE id = ?', [req.params.id]);
      if (!event) return res.status(404).send('Etkinlik bulunamadı.');
      if (Number(event.allow_likes ?? 1) === 0) return res.status(403).send('Bu etkinlik için beğeni kapalı.');
      const existing = await sqlGetAsync('SELECT id FROM entity_reactions WHERE entity_type = ? AND entity_id = ? AND user_id = ?', ['event', req.params.id, req.session.userId]);
      if (existing) {
        await sqlRunAsync('DELETE FROM entity_reactions WHERE id = ?', [existing.id]);
      } else {
        await sqlRunAsync('INSERT INTO entity_reactions (user_id, entity_type, entity_id, created_at) VALUES (?, ?, ?, ?)', [req.session.userId, 'event', req.params.id, new Date().toISOString()]);
        if (event.created_by && !sameUserId(event.created_by, req.session.userId)) {
          addNotification({ userId: event.created_by, type: 'event_like', sourceUserId: req.session.userId, entityId: req.params.id, message: 'Etkinliğini beğendi.' });
        }
      }
      const likeCount = (await sqlGetAsync('SELECT COUNT(*) AS cnt FROM entity_reactions WHERE entity_type = ? AND entity_id = ?', ['event', req.params.id]))?.cnt || 0;
      res.json({ ok: true, liked: !existing, likeCount });
    } catch (err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  // ── Toggle allow_comments / allow_likes on event ──────────────────────────
  app.post('/api/new/events/:id/interactions', requireAuth, async (req, res) => {
    try {
      const event = await sqlGetAsync('SELECT id, created_by FROM events WHERE id = ?', [req.params.id]);
      if (!event) return res.status(404).send('Etkinlik bulunamadı.');
      const user = getCurrentUser(req);
      if (!hasAdminSession(req, user) && !sameUserId(event.created_by, req.session.userId)) return res.status(403).send('Yetki yok.');
      const allowComments = req.body?.allowComments != null ? (req.body.allowComments ? 1 : 0) : undefined;
      const allowLikes = req.body?.allowLikes != null ? (req.body.allowLikes ? 1 : 0) : undefined;
      if (allowComments !== undefined) await sqlRunAsync('UPDATE events SET allow_comments = ? WHERE id = ?', [allowComments, req.params.id]);
      if (allowLikes !== undefined) await sqlRunAsync('UPDATE events SET allow_likes = ? WHERE id = ?', [allowLikes, req.params.id]);
      res.json({ ok: true });
    } catch (err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  // ── Single announcement detail ─────────────────────────────────────────────
  app.get('/api/new/announcements/:id', requireAuth, async (req, res) => {
    try {
      const user = getCurrentUser(req);
      const isAdmin = hasAdminSession(req, user);
      const row = await sqlGetAsync(
        `SELECT a.*, u.kadi AS creator_kadi FROM announcements a LEFT JOIN uyeler u ON u.id = a.created_by WHERE a.id = ?`,
        [req.params.id]
      );
      if (!row) return res.status(404).send('Duyuru bulunamadı.');
      const approved = Number(row.approved ?? 1) === 1 || String(row.approved).toLowerCase() === 'true';
      if (!approved && !isAdmin) return res.status(403).send('Duyuru yayında değil.');
      const comments = await sqlAllAsync(
        `SELECT c.id, c.comment, c.created_at, u.id AS user_id, u.kadi, u.isim, u.soyisim, u.resim, u.verified
         FROM announcement_comments c LEFT JOIN uyeler u ON u.id = c.user_id
         WHERE c.announcement_id = ? ORDER BY c.id ASC`,
        [req.params.id]
      );
      const likeCount = (await sqlGetAsync('SELECT COUNT(*) AS cnt FROM entity_reactions WHERE entity_type = ? AND entity_id = ?', ['announcement', req.params.id]))?.cnt || 0;
      const liked = !!(await sqlGetAsync('SELECT id FROM entity_reactions WHERE entity_type = ? AND entity_id = ? AND user_id = ?', ['announcement', req.params.id, req.session.userId]));
      res.json({ ...row, comments, like_count: likeCount, liked, allow_comments: Number(row.allow_comments ?? 1), allow_likes: Number(row.allow_likes ?? 1) });
    } catch (err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  // ── Announcement comments ─────────────────────────────────────────────────
  app.get('/api/new/announcements/:id/comments', requireAuth, async (req, res) => {
    try {
      const rows = await sqlAllAsync(
        `SELECT c.id, c.comment, c.created_at, u.id AS user_id, u.kadi, u.isim, u.soyisim, u.resim, u.verified
         FROM announcement_comments c LEFT JOIN uyeler u ON u.id = c.user_id
         WHERE c.announcement_id = ? ORDER BY c.id ASC`,
        [req.params.id]
      );
      res.json({ items: rows });
    } catch (err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.post('/api/new/announcements/:id/comments', requireAuth, async (req, res) => {
    try {
      const ann = await sqlGetAsync('SELECT id, created_by, allow_comments FROM announcements WHERE id = ?', [req.params.id]);
      if (!ann) return res.status(404).send('Duyuru bulunamadı.');
      if (Number(ann.allow_comments ?? 1) === 0) return res.status(403).send('Bu duyuru için yorum kapalı.');
      const comment = formatUserText(req.body?.comment || '');
      if (isFormattedContentEmpty(comment)) return res.status(400).send('Yorum boş olamaz.');
      const now = new Date().toISOString();
      await sqlRunAsync('INSERT INTO announcement_comments (announcement_id, user_id, comment, created_at) VALUES (?, ?, ?, ?)', [req.params.id, req.session.userId, comment, now]);
      if (ann.created_by && !sameUserId(ann.created_by, req.session.userId)) {
        addNotification({ userId: ann.created_by, type: 'announcement_comment', sourceUserId: req.session.userId, entityId: req.params.id, message: 'Duyuruya yorum yaptı.' });
      }
      res.json({ ok: true });
    } catch (err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  // ── Edit announcement ─────────────────────────────────────────────────────
  app.patch('/api/new/announcements/:id', requireAuth, async (req, res) => {
    try {
      const user = getCurrentUser(req);
      const isAdmin = hasAdminSession(req, user);
      const row = await sqlGetAsync('SELECT id, created_by FROM announcements WHERE id = ?', [req.params.id]);
      if (!row) return res.status(404).send('Duyuru bulunamadı.');
      if (!isAdmin && !sameUserId(row.created_by, req.session.userId)) return res.status(403).send('Bu duyuruyu düzenleme yetkin yok.');

      const updates = [];
      const updateParams = [];
      if (req.body.title !== undefined && req.body.title !== null) {
        updates.push('title = ?');
        updateParams.push(String(req.body.title).trim());
      }
      if (req.body.body !== undefined && req.body.body !== null) {
        updates.push('body = ?');
        updateParams.push(String(req.body.body).trim());
      }
      if (req.body.image !== undefined) {
        updates.push('image = ?');
        updateParams.push(req.body.image || null);
      }

      if (updates.length === 0) return res.status(400).send('Güncellenecek alan yok.');

      updateParams.push(req.params.id);
      await sqlRunAsync(`UPDATE announcements SET ${updates.join(', ')} WHERE id = ?`, updateParams);

      const updated = await sqlGetAsync('SELECT * FROM announcements WHERE id = ?', [req.params.id]);
      res.json({ ok: true, ...updated });
    } catch (err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  // ── Like/unlike announcement ──────────────────────────────────────────────
  app.post('/api/new/announcements/:id/like', requireAuth, async (req, res) => {
    try {
      const ann = await sqlGetAsync('SELECT id, created_by, allow_likes FROM announcements WHERE id = ?', [req.params.id]);
      if (!ann) return res.status(404).send('Duyuru bulunamadı.');
      if (Number(ann.allow_likes ?? 1) === 0) return res.status(403).send('Bu duyuru için beğeni kapalı.');
      const existing = await sqlGetAsync('SELECT id FROM entity_reactions WHERE entity_type = ? AND entity_id = ? AND user_id = ?', ['announcement', req.params.id, req.session.userId]);
      if (existing) {
        await sqlRunAsync('DELETE FROM entity_reactions WHERE id = ?', [existing.id]);
      } else {
        await sqlRunAsync('INSERT INTO entity_reactions (user_id, entity_type, entity_id, created_at) VALUES (?, ?, ?, ?)', [req.session.userId, 'announcement', req.params.id, new Date().toISOString()]);
        if (ann.created_by && !sameUserId(ann.created_by, req.session.userId)) {
          addNotification({ userId: ann.created_by, type: 'announcement_like', sourceUserId: req.session.userId, entityId: req.params.id, message: 'Duyurunu beğendi.' });
        }
      }
      const likeCount = (await sqlGetAsync('SELECT COUNT(*) AS cnt FROM entity_reactions WHERE entity_type = ? AND entity_id = ?', ['announcement', req.params.id]))?.cnt || 0;
      res.json({ ok: true, liked: !existing, likeCount });
    } catch (err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  // ── Toggle interactions on announcement ───────────────────────────────────
  app.post('/api/new/announcements/:id/interactions', requireAuth, async (req, res) => {
    try {
      const ann = await sqlGetAsync('SELECT id, created_by FROM announcements WHERE id = ?', [req.params.id]);
      if (!ann) return res.status(404).send('Duyuru bulunamadı.');
      const user = getCurrentUser(req);
      if (!hasAdminSession(req, user) && !sameUserId(ann.created_by, req.session.userId)) return res.status(403).send('Yetki yok.');
      const allowComments = req.body?.allowComments != null ? (req.body.allowComments ? 1 : 0) : undefined;
      const allowLikes = req.body?.allowLikes != null ? (req.body.allowLikes ? 1 : 0) : undefined;
      if (allowComments !== undefined) await sqlRunAsync('UPDATE announcements SET allow_comments = ? WHERE id = ?', [allowComments, req.params.id]);
      if (allowLikes !== undefined) await sqlRunAsync('UPDATE announcements SET allow_likes = ? WHERE id = ?', [allowLikes, req.params.id]);
      res.json({ ok: true });
    } catch (err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });
}
