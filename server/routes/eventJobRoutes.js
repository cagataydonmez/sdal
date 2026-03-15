export function registerEventJobRoutes(app, {
  requireAuth,
  requireAdmin,
  uploadRateLimit,
  postUpload,
  getCurrentUser,
  hasAdminSession,
  sameUserId,
  dbDriver,
  sqlAll,
  sqlGet,
  sqlRun,
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
  normalizeEventResponse,
  getEventResponseBundle,
  notifyMentions,
  ensureJobApplicationsTable,
  ensureVerifiedSocialHubMember,
  apiSuccessEnvelope,
  sendApiError
}) {
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
      await sqlRunAsync(
        'UPDATE events SET approved = ?, approved_by = ?, approved_at = ? WHERE id = ?',
        [toDbFlagForColumn('events', 'approved', approved), req.session.userId, new Date().toISOString(), req.params.id]
      );
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

  app.post('/api/new/events/:id/respond', requireAuth, async (req, res) => {
    try {
      const event = await sqlGetAsync('SELECT * FROM events WHERE id = ?', [req.params.id]);
      if (!event) return res.status(404).send('Etkinlik bulunamadı.');
      if (Number(event.approved || 1) !== 1) return res.status(400).send('Etkinlik henüz yayında değil.');
      const response = normalizeEventResponse(req.body?.response);
      if (!response) return res.status(400).send('Geçersiz yanıt.');
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
      res.json({ ok: true, myResponse: bundle.myResponse, counts: bundle.counts });
    } catch (err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

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
      await sqlRunAsync(
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
      await sqlRunAsync(
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
      const announcement = await sqlGetAsync('SELECT id, created_by, title FROM announcements WHERE id = ?', [req.params.id]);
      await sqlRunAsync(
        'UPDATE announcements SET approved = ?, approved_by = ?, approved_at = ? WHERE id = ?',
        [toDbFlagForColumn('announcements', 'approved', approved), req.session.userId, new Date().toISOString(), req.params.id]
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

  app.get('/api/new/jobs', requireAuth, async (req, res) => {
    ensureJobApplicationsTable();
    const search = sanitizePlainUserText(String(req.query.search || '').trim(), 120).toLowerCase();
    const location = sanitizePlainUserText(String(req.query.location || '').trim(), 120).toLowerCase();
    const jobType = sanitizePlainUserText(String(req.query.job_type || '').trim(), 60).toLowerCase();
    const limit = Math.min(Math.max(parseInt(req.query.limit || '40', 10), 1), 100);
    const offset = Math.max(parseInt(req.query.offset || '0', 10), 0);

    const where = [];
    const params = [];
    if (search) {
      where.push('(LOWER(j.title) LIKE ? OR LOWER(j.company) LIKE ? OR LOWER(j.description) LIKE ?)');
      params.push(`%${search}%`, `%${search}%`, `%${search}%`);
    }
    if (location) {
      where.push('LOWER(j.location) LIKE ?');
      params.push(`%${location}%`);
    }
    if (jobType) {
      where.push('LOWER(j.job_type) = ?');
      params.push(jobType);
    }

    const rows = await sqlAllAsync(
      `SELECT j.*, u.kadi AS poster_kadi, u.isim AS poster_isim, u.soyisim AS poster_soyisim,
              ja_self.id AS my_application_id,
              ja_self.status AS my_application_status,
              ja_self.created_at AS my_application_created_at,
              ja_self.reviewed_at AS my_application_reviewed_at,
              ja_self.decision_note AS my_application_decision_note
       FROM jobs j
       LEFT JOIN uyeler u ON u.id = j.poster_id
       LEFT JOIN job_applications ja_self ON ja_self.job_id = j.id AND ja_self.applicant_id = ?
       ${where.length ? `WHERE ${where.join(' AND ')}` : ''}
       ORDER BY j.id DESC
       LIMIT ? OFFSET ?`,
      [req.session.userId, ...params, limit, offset]
    );

    res.json({ items: rows, hasMore: rows.length === limit });
  });

  app.post('/api/new/jobs/:id/apply', requireAuth, async (req, res) => {
    if (!ensureVerifiedSocialHubMember(req, res)) return;
    const jobId = Number(req.params.id || 0);
    if (!jobId) return res.status(400).send('Geçersiz iş ilanı kimliği.');

    ensureJobApplicationsTable();

    const job = await sqlGetAsync('SELECT id, poster_id, title FROM jobs WHERE id = ?', [jobId]);
    if (!job) return res.status(404).send('İş ilanı bulunamadı.');
    if (sameUserId(job.poster_id, req.session.userId)) {
      return res.status(409).json({ code: 'CANNOT_APPLY_OWN_JOB', message: 'Kendi ilanına başvuru yapamazsın.' });
    }

    const existing = await sqlGetAsync('SELECT id FROM job_applications WHERE job_id = ? AND applicant_id = ?', [jobId, req.session.userId]);
    if (existing) {
      return res.status(409).json({ code: 'ALREADY_APPLIED', message: 'Bu iş ilanına zaten başvuru yaptın.' });
    }

    const coverLetter = formatUserText(String(req.body?.cover_letter || ''));
    const now = new Date().toISOString();
    const result = await sqlRunAsync(
      'INSERT INTO job_applications (job_id, applicant_id, cover_letter, status, created_at) VALUES (?, ?, ?, ?, ?)',
      [jobId, req.session.userId, isFormattedContentEmpty(coverLetter) ? null : coverLetter, 'pending', now]
    );

    addNotification({
      userId: Number(job.poster_id),
      type: 'job_application',
      sourceUserId: Number(req.session.userId),
      entityId: jobId,
      message: `"${job.title || 'İş ilanı'}" ilanına yeni bir başvuru geldi.`
    });

    res.json({ ok: true, id: result?.lastInsertRowid, status: 'applied' });
  });

  app.get('/api/new/jobs/:id/applications', requireAuth, async (req, res) => {
    const jobId = Number(req.params.id || 0);
    if (!jobId) return res.status(400).send('Geçersiz iş ilanı kimliği.');

    ensureJobApplicationsTable();

    const user = getCurrentUser(req);
    const isAdmin = hasAdminSession(req, user);
    const job = await sqlGetAsync('SELECT id, poster_id FROM jobs WHERE id = ?', [jobId]);
    if (!job) return res.status(404).send('İş ilanı bulunamadı.');
    if (!isAdmin && !sameUserId(job.poster_id, req.session.userId)) {
      return res.status(403).send('Bu ilanın başvurularını görüntüleme yetkin yok.');
    }

    const rows = await sqlAllAsync(
      `SELECT ja.id, ja.job_id, ja.applicant_id, ja.cover_letter, ja.created_at,
              ja.status, ja.reviewed_at, ja.reviewed_by, ja.decision_note,
              u.kadi, u.isim, u.soyisim, u.sirket, u.unvan, u.linkedin_url,
              reviewer.kadi AS reviewed_by_kadi, reviewer.isim AS reviewed_by_isim, reviewer.soyisim AS reviewed_by_soyisim
       FROM job_applications ja
       LEFT JOIN uyeler u ON u.id = ja.applicant_id
       LEFT JOIN uyeler reviewer ON reviewer.id = ja.reviewed_by
       WHERE ja.job_id = ?
       ORDER BY ja.id DESC`,
      [jobId]
    );

    res.json({ items: rows });
  });

  app.post('/api/new/jobs/:jobId/applications/:applicationId/review', requireAuth, async (req, res) => {
    const jobId = Number(req.params.jobId || 0);
    const applicationId = Number(req.params.applicationId || 0);
    if (!jobId || !applicationId) return sendApiError(res, 400, 'INVALID_JOB_APPLICATION_ID', 'Geçersiz başvuru kimliği.');

    ensureJobApplicationsTable();

    const actor = getCurrentUser(req);
    const isAdmin = hasAdminSession(req, actor);
    const nextStatus = String(req.body?.status || '').trim().toLowerCase();
    const allowedStatuses = new Set(['reviewed', 'accepted', 'rejected']);
    if (!allowedStatuses.has(nextStatus)) {
      return sendApiError(res, 400, 'INVALID_JOB_APPLICATION_STATUS', 'Geçersiz başvuru durumu.');
    }

    const applicationRow = await sqlGetAsync(
      `SELECT ja.id, ja.job_id, ja.applicant_id, ja.status, j.poster_id, j.title
       FROM job_applications ja
       LEFT JOIN jobs j ON j.id = ja.job_id
       WHERE ja.id = ? AND ja.job_id = ?`,
      [applicationId, jobId]
    );
    if (!applicationRow) {
      return sendApiError(res, 404, 'JOB_APPLICATION_NOT_FOUND', 'İş başvurusu bulunamadı.');
    }
    if (!isAdmin && !sameUserId(applicationRow.poster_id, req.session.userId)) {
      return sendApiError(res, 403, 'JOB_APPLICATION_REVIEW_FORBIDDEN', 'Bu başvuruyu değerlendirme yetkin yok.');
    }

    const decisionNote = sanitizePlainUserText(String(req.body?.decision_note || '').trim(), 500) || null;
    const reviewedAt = new Date().toISOString();
    await sqlRunAsync(
      `UPDATE job_applications
       SET status = ?, reviewed_at = ?, reviewed_by = ?, decision_note = ?
       WHERE id = ? AND job_id = ?`,
      [nextStatus, reviewedAt, req.session.userId, decisionNote, applicationId, jobId]
    );

    let notificationType = 'job_application_reviewed';
    if (nextStatus === 'accepted') notificationType = 'job_application_accepted';
    else if (nextStatus === 'rejected') notificationType = 'job_application_rejected';
    addNotification({
      userId: Number(applicationRow.applicant_id),
      type: notificationType,
      sourceUserId: Number(req.session.userId),
      entityId: applicationId,
      message: nextStatus === 'accepted'
        ? `"${applicationRow.title || 'İş ilanı'}" başvurun kabul edildi.`
        : nextStatus === 'rejected'
          ? `"${applicationRow.title || 'İş ilanı'}" başvurun olumsuz sonuçlandı.`
          : `"${applicationRow.title || 'İş ilanı'}" başvurun inceleniyor.`
    });

    return res.json(apiSuccessEnvelope(
      'JOB_APPLICATION_REVIEWED',
      'İş başvurusu güncellendi.',
      {
        id: applicationId,
        job_id: jobId,
        status: nextStatus,
        reviewed_at: reviewedAt,
        reviewed_by: Number(req.session.userId),
        decision_note: decisionNote
      },
      {
        id: applicationId,
        job_id: jobId,
        status: nextStatus,
        reviewed_at: reviewedAt,
        reviewed_by: Number(req.session.userId),
        decision_note: decisionNote
      }
    ));
  });

  app.post('/api/new/jobs', requireAuth, async (req, res) => {
    if (!ensureVerifiedSocialHubMember(req, res)) return;
    const company = sanitizePlainUserText(String(req.body?.company || '').trim(), 140);
    const title = sanitizePlainUserText(String(req.body?.title || '').trim(), 180);
    const description = formatUserText(String(req.body?.description || ''));
    const location = sanitizePlainUserText(String(req.body?.location || '').trim(), 120);
    const jobType = sanitizePlainUserText(String(req.body?.job_type || '').trim(), 60);
    const link = sanitizePlainUserText(String(req.body?.link || '').trim(), 500);
    if (!company || !title || isFormattedContentEmpty(description)) {
      return res.status(400).send('Şirket, başlık ve açıklama gerekli.');
    }
    if (link && !/^https?:\/\//i.test(link)) return res.status(400).send('Link http:// veya https:// ile başlamalı.');
    const now = new Date().toISOString();
    const result = await sqlRunAsync(
      `INSERT INTO jobs (poster_id, company, title, description, location, job_type, link, created_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
      [req.session.userId, company, title, description, location, jobType, link || null, now]
    );
    res.json({ ok: true, id: result?.lastInsertRowid });
  });

  app.delete('/api/new/jobs/:id', requireAuth, async (req, res) => {
    try {
      const user = getCurrentUser(req);
      const isAdmin = hasAdminSession(req, user);
      const row = await sqlGetAsync('SELECT id, poster_id FROM jobs WHERE id = ?', [req.params.id]);
      if (!row) return res.status(404).send('İş ilanı bulunamadı.');
      if (!isAdmin && !sameUserId(row.poster_id, req.session.userId)) return res.status(403).send('Bu ilanı silme yetkin yok.');
      await sqlRunAsync('DELETE FROM jobs WHERE id = ?', [req.params.id]);
      res.json({ ok: true });
    } catch (err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });
}
