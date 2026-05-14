import { getCacheJson, setCacheJson } from '../src/infra/performanceCache.js';
import { createRateLimitMiddleware } from '../src/http/middleware/rateLimit.js';
import {
  APPROVAL_STATUS,
  PUBLICATION_STATUS,
  buildInitialContentState,
  canSeeContent,
  publicQuery,
  wantsPublish,
  wantsShowInFeed
} from '../src/shared/contentState.js';

const opportunityEndpointRateLimit = createRateLimitMiddleware({
  bucket: 'heavy_opportunities',
  limit: 15,
  windowSeconds: 60,
  keyGenerator: (req) => String(req.session?.userId || req.ip || 'unknown')
});

export function registerOpportunityRoutes(app, {
  requireAuth,
  sqlGetAsync,
  sqlRunAsync,
  sqlAllAsync,
  apiSuccessEnvelope,
  sendApiError,
  getCurrentUser,
  hasAdminSession,
  sameUserId,
  addNotification,
  sanitizePlainUserText,
  formatUserText,
  isFormattedContentEmpty,
  ensureJobApplicationsTable,
  ensureVerifiedSocialHubMember,
  buildOpportunityInboxPayload,
  uploadRateLimit,
  postUpload,
  processDiskImageUpload,
  uploadImagePresets,
  createEntityFeedPost,
  invalidateFeedCache
}) {
  app.get('/api/new/opportunities', requireAuth, opportunityEndpointRateLimit, async (req, res) => {
    try {
      const userId = Number(req.session?.userId || 0);
      const limit = Math.min(Math.max(parseInt(req.query.limit || '20', 10), 1), 40);
      const cursor = String(req.query.cursor || '').trim();
      const tab = String(req.query.tab || 'all').trim().toLowerCase();

      const cacheKey = `opp-inbox:${userId}:${tab}:${cursor}:${limit}`;
      const cached = await getCacheJson(cacheKey);
      if (cached) {
        return res.json(apiSuccessEnvelope(
          'OPPORTUNITY_INBOX_OK',
          'Fırsat merkezi hazır.',
          { opportunities: cached },
          { opportunities: cached }
        ));
      }

      const opportunities = await buildOpportunityInboxPayload(userId, { limit, cursor, tab });
      await setCacheJson(cacheKey, opportunities, 15);
      return res.json(apiSuccessEnvelope(
        'OPPORTUNITY_INBOX_OK',
        'Fırsat merkezi hazır.',
        { opportunities },
        { opportunities }
      ));
    } catch (err) {
      console.error('opportunity.inbox failed:', err);
      return sendApiError(res, 500, 'OPPORTUNITY_INBOX_FAILED', 'Fırsat merkezi verileri hazırlanamadı.');
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
    const currentUser = getCurrentUser(req);
    const isAdmin = hasAdminSession(req, currentUser);
    const status = String(req.query.status || '').trim().toLowerCase();
    const publishedFilter = Object.prototype.hasOwnProperty.call(req.query || {}, 'published')
      ? String(req.query.published || '') === '1'
      : null;
    if (status === 'published' || publishedFilter === true) {
      where.push(publicQuery('j').replace(/j\.approved/g, 'TRUE'));
    } else if (status === 'drafts' || publishedFilter === false) {
      where.push('j.poster_id = ?');
      where.push("COALESCE(j.publication_status, CASE WHEN COALESCE(j.show_in_feed, 1) = 1 THEN 'published' ELSE 'draft' END) != 'published'");
      params.push(req.session.userId);
    } else if (status === 'pending' && isAdmin) {
      where.push("COALESCE(j.approval_status, 'not_required') = 'pending'");
    } else if (!isAdmin) {
      where.push(`(${publicQuery('j').replace(/j\.approved/g, 'TRUE')} OR j.poster_id = ?)`);
      params.push(req.session.userId);
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
       ORDER BY COALESCE(NULLIF(CAST(j.published_at AS TEXT), ''), j.created_at) DESC, j.id DESC
       LIMIT ? OFFSET ?`,
      [req.session.userId, ...params, limit, offset]
    );

    res.json({ items: rows, hasMore: rows.length === limit });
  });

  app.post('/api/new/jobs/upload', requireAuth, uploadRateLimit, postUpload.single('image'), async (req, res) => {
    if (!ensureVerifiedSocialHubMember(req, res)) return;
    ensureJobApplicationsTable();
    try {
      const company = sanitizePlainUserText(String(req.body?.company || '').trim(), 140);
      const title = sanitizePlainUserText(String(req.body?.title || '').trim(), 180);
      const description = formatUserText(String(req.body?.description || ''));
      const location = sanitizePlainUserText(String(req.body?.location || '').trim(), 120);
      const jobType = sanitizePlainUserText(String(req.body?.job_type || '').trim(), 60);
      const workMode = sanitizePlainUserText(String(req.body?.work_mode || '').trim(), 60);
      const link = sanitizePlainUserText(String(req.body?.link || '').trim(), 500);
      if (!company || !title || isFormattedContentEmpty(description)) {
        return res.status(400).send('Şirket, başlık ve açıklama gerekli.');
      }
      if (link && !/^https?:\/\//i.test(link)) return res.status(400).send('Link http:// veya https:// ile başlamalı.');
      let imageUrl = null;
      if (req.file?.path) {
        const processedUpload = await processDiskImageUpload({
          req, res, file: req.file, bucket: 'job_image', preset: uploadImagePresets.jobImage
        });
        if (!processedUpload.ok) return res.status(processedUpload.statusCode).send(processedUpload.message);
        imageUrl = processedUpload.url;
      }
      const now = new Date().toISOString();
      const contentState = await buildInitialContentState({
        sqlGetAsync,
        entityType: 'job',
        body: req.body,
        actorIsTrusted: hasAdminSession(req, getCurrentUser(req))
      });
      const result = await sqlRunAsync(
        `INSERT INTO jobs (poster_id, company, title, description, location, job_type, work_mode, link, image, created_at, show_in_feed, publication_status, approval_status, published_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
        [
          req.session.userId,
          company,
          title,
          description,
          location,
          jobType,
          workMode || null,
          link || null,
          imageUrl,
          now,
          contentState.showInFeed ? 1 : 0,
          contentState.publicationStatus,
          contentState.approvalStatus,
          contentState.publicationStatus === PUBLICATION_STATUS.PUBLISHED ? now : null
        ]
      );
      const newJobId = Number(result?.lastInsertRowid || 0);
      invalidateFeedCache?.();
      return res.json({ ok: true, id: newJobId, pending: contentState.approvalStatus === APPROVAL_STATUS.PENDING, publication_status: contentState.publicationStatus, approval_status: contentState.approvalStatus });
    } catch (err) {
      console.error('jobs.upload failed:', err);
      if (!res.headersSent) return res.status(500).send('İş ilanı oluşturulamadı.');
    }
  });

  app.get('/api/new/jobs/:id', requireAuth, async (req, res) => {
    ensureJobApplicationsTable();
    const jobId = Number(req.params.id || 0);
    if (!jobId) return res.status(400).json({ error: 'Geçersiz iş ilanı kimliği.' });

    const row = await sqlGetAsync(
      `SELECT j.*, u.kadi AS poster_kadi, u.isim AS poster_isim, u.soyisim AS poster_soyisim,
              ja_self.id AS my_application_id,
              ja_self.status AS my_application_status,
              ja_self.created_at AS my_application_created_at,
              ja_self.reviewed_at AS my_application_reviewed_at,
              ja_self.decision_note AS my_application_decision_note
       FROM jobs j
       LEFT JOIN uyeler u ON u.id = j.poster_id
       LEFT JOIN job_applications ja_self ON ja_self.job_id = j.id AND ja_self.applicant_id = ?
       WHERE j.id = ?`,
      [req.session.userId, jobId]
    );

    if (!row) return res.status(404).json({ error: 'İş ilanı bulunamadı.' });
    const user = getCurrentUser(req);
    const isAdmin = hasAdminSession(req, user);
    if (!canSeeContent(row, { actorId: req.session.userId, isAdmin })) {
      return res.status(403).send('İş ilanı yayında değil.');
    }
    res.json(row);
  });

  app.patch('/api/new/jobs/:id', requireAuth, async (req, res) => {
    try {
      const user = getCurrentUser(req);
      const isAdmin = hasAdminSession(req, user);
      const row = await sqlGetAsync('SELECT id, poster_id, publication_status FROM jobs WHERE id = ?', [req.params.id]);
      if (!row) return res.status(404).send('İş ilanı bulunamadı.');
      if (!isAdmin && !sameUserId(row.poster_id, req.session.userId)) return res.status(403).send('Bu ilanı düzenleme yetkin yok.');

      const updates = [];
      const updateParams = [];
      if (req.body.title !== undefined && req.body.title !== null) {
        updates.push('title = ?');
        updateParams.push(String(req.body.title).trim());
      }
      if (req.body.company !== undefined && req.body.company !== null) {
        updates.push('company = ?');
        updateParams.push(String(req.body.company).trim());
      }
      if (req.body.description !== undefined && req.body.description !== null) {
        updates.push('description = ?');
        updateParams.push(String(req.body.description).trim());
      }
      if (req.body.location !== undefined && req.body.location !== null) {
        updates.push('location = ?');
        updateParams.push(String(req.body.location).trim());
      }
      if (req.body.job_type !== undefined && req.body.job_type !== null) {
        updates.push('job_type = ?');
        updateParams.push(String(req.body.job_type).trim());
      }
      if (req.body.work_mode !== undefined && req.body.work_mode !== null) {
        updates.push('work_mode = ?');
        updateParams.push(String(req.body.work_mode).trim());
      }
      if (req.body.link !== undefined && req.body.link !== null) {
        updates.push('link = ?');
        updateParams.push(String(req.body.link).trim());
      }
      if (req.body.image !== undefined) {
        updates.push('image = ?');
        updateParams.push(req.body.image || null);
      }
      if (req.body.show_in_feed !== undefined || req.body.showInFeed !== undefined) {
        updates.push('show_in_feed = ?');
        updateParams.push(wantsShowInFeed(req.body) ? 1 : 0);
      }
      if (req.body.publish !== undefined || req.body.published !== undefined) {
        const publish = wantsPublish(req.body);
        updates.push('publication_status = ?');
        updates.push('published_at = ?');
        const now = new Date().toISOString();
        updateParams.push(publish ? PUBLICATION_STATUS.PUBLISHED : PUBLICATION_STATUS.DRAFT);
        updateParams.push(publish ? now : null);
        if (publish && row.publication_status !== PUBLICATION_STATUS.PUBLISHED) {
          updates.push('created_at = ?');
          updateParams.push(now);
        }
      }

      if (updates.length === 0) return res.status(400).send('Güncellenecek alan yok.');

      updates.push('updated_at = ?');
      updateParams.push(new Date().toISOString());
      updateParams.push(req.params.id);
      await sqlRunAsync(`UPDATE jobs SET ${updates.join(', ')} WHERE id = ?`, updateParams);

      const updated = await sqlGetAsync('SELECT * FROM jobs WHERE id = ?', [req.params.id]);
      invalidateFeedCache?.();
      res.json({ ok: true, ...updated });
    } catch (err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.post('/api/new/jobs/:id/upload', requireAuth, uploadRateLimit, postUpload.single('image'), async (req, res) => {
    if (!ensureVerifiedSocialHubMember(req, res)) return;
    try {
      const user = getCurrentUser(req);
      const isAdmin = hasAdminSession(req, user);
      const row = await sqlGetAsync('SELECT id, poster_id FROM jobs WHERE id = ?', [req.params.id]);
      if (!row) return res.status(404).send('İş ilanı bulunamadı.');
      if (!isAdmin && !sameUserId(row.poster_id, req.session.userId)) return res.status(403).send('Bu ilanı düzenleme yetkin yok.');
      let imageUrl = null;
      if (req.file?.path) {
        const processedUpload = await processDiskImageUpload({
          req, res, file: req.file, bucket: 'job_image', preset: uploadImagePresets.jobImage
        });
        if (!processedUpload.ok) return res.status(processedUpload.statusCode).send(processedUpload.message);
        imageUrl = processedUpload.url;
      }
      await sqlRunAsync(
        `UPDATE jobs
         SET company = ?, title = ?, description = ?, location = ?, job_type = ?, work_mode = ?, link = ?,
             image = ?, show_in_feed = ?, updated_at = ?
         WHERE id = ?`,
        [
          sanitizePlainUserText(String(req.body?.company || '').trim(), 140),
          sanitizePlainUserText(String(req.body?.title || '').trim(), 180),
          formatUserText(String(req.body?.description || '')),
          sanitizePlainUserText(String(req.body?.location || '').trim(), 120),
          sanitizePlainUserText(String(req.body?.job_type || '').trim(), 60),
          sanitizePlainUserText(String(req.body?.work_mode || '').trim(), 60) || null,
          sanitizePlainUserText(String(req.body?.link || '').trim(), 500) || null,
          imageUrl || req.body?.image || null,
          wantsShowInFeed(req.body) ? 1 : 0,
          new Date().toISOString(),
          req.params.id
        ]
      );
      const updated = await sqlGetAsync('SELECT * FROM jobs WHERE id = ?', [req.params.id]);
      invalidateFeedCache?.();
      res.json({ ok: true, ...updated });
    } catch (err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
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
    const cvLink = sanitizePlainUserText(String(req.body?.cv_link || '').trim(), 500) || null;
    const contactChannel = sanitizePlainUserText(String(req.body?.contact_channel || '').trim(), 40) || null;
    const contactValue = sanitizePlainUserText(String(req.body?.contact_value || '').trim(), 200) || null;
    const city = sanitizePlainUserText(String(req.body?.city || '').trim(), 100) || null;
    const now = new Date().toISOString();
    const result = await sqlRunAsync(
      'INSERT INTO job_applications (job_id, applicant_id, cover_letter, cv_link, contact_channel, contact_value, city, status, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
      [jobId, req.session.userId, isFormattedContentEmpty(coverLetter) ? null : coverLetter, cvLink, contactChannel, contactValue, city, 'pending', now]
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
      `SELECT ja.id, ja.job_id, ja.applicant_id, ja.cover_letter, ja.cv_link,
              ja.contact_channel, ja.contact_value, ja.city,
              ja.created_at, ja.status, ja.reviewed_at, ja.reviewed_by, ja.decision_note,
              u.kadi, u.isim, u.soyisim, u.resim, u.sirket, u.unvan,
              reviewer.kadi AS reviewed_by_kadi
       FROM job_applications ja
       LEFT JOIN uyeler u ON u.id = ja.applicant_id
       LEFT JOIN uyeler reviewer ON reviewer.id = ja.reviewed_by
       WHERE ja.job_id = ?
       ORDER BY ja.id DESC`,
      [jobId]
    );

    res.json({ items: rows });
  });

  app.get('/api/new/jobs/:jobId/applications/:applicationId', requireAuth, async (req, res) => {
    const jobId = Number(req.params.jobId || 0);
    const applicationId = Number(req.params.applicationId || 0);
    if (!jobId || !applicationId) return res.status(400).send('Geçersiz başvuru kimliği.');

    ensureJobApplicationsTable();

    const user = getCurrentUser(req);
    const isAdmin = hasAdminSession(req, user);
    const job = await sqlGetAsync('SELECT id, poster_id FROM jobs WHERE id = ?', [jobId]);
    if (!job) return res.status(404).send('İş ilanı bulunamadı.');
    const isPoster = isAdmin || sameUserId(job.poster_id, req.session.userId);

    const row = await sqlGetAsync(
      `SELECT ja.id, ja.job_id, ja.applicant_id, ja.cover_letter, ja.cv_link,
              ja.contact_channel, ja.contact_value, ja.city,
              ja.created_at, ja.status, ja.reviewed_at, ja.reviewed_by, ja.decision_note,
              u.kadi, u.isim, u.soyisim, u.resim, u.sirket, u.unvan
       FROM job_applications ja
       LEFT JOIN uyeler u ON u.id = ja.applicant_id
       WHERE ja.id = ? AND ja.job_id = ?`,
      [applicationId, jobId]
    );
    if (!row) return res.status(404).send('Başvuru bulunamadı.');

    const isOwnApplication = sameUserId(row.applicant_id, req.session.userId);
    if (!isPoster && !isOwnApplication) return res.status(403).send('Bu başvuruyu görüntüleme yetkin yok.');

    if (isPoster && row.status === 'pending') {
      await sqlRunAsync(
        `UPDATE job_applications SET status = 'reviewed', reviewed_at = ?, reviewed_by = ? WHERE id = ?`,
        [new Date().toISOString(), req.session.userId, applicationId]
      );
      row.status = 'reviewed';
      addNotification({
        userId: Number(row.applicant_id),
        type: 'job_application_reviewed',
        sourceUserId: Number(req.session.userId),
        entityId: applicationId,
        message: `Başvurunuz incelendi.`
      });
    }

    res.json(row);
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
    ensureJobApplicationsTable();
    const company = sanitizePlainUserText(String(req.body?.company || '').trim(), 140);
    const title = sanitizePlainUserText(String(req.body?.title || '').trim(), 180);
    const description = formatUserText(String(req.body?.description || ''));
    const location = sanitizePlainUserText(String(req.body?.location || '').trim(), 120);
    const jobType = sanitizePlainUserText(String(req.body?.job_type || '').trim(), 60);
    const workMode = sanitizePlainUserText(String(req.body?.work_mode || '').trim(), 60);
    const link = sanitizePlainUserText(String(req.body?.link || '').trim(), 500);
    if (!company || !title || isFormattedContentEmpty(description)) {
      return res.status(400).send('Şirket, başlık ve açıklama gerekli.');
    }
    if (link && !/^https?:\/\//i.test(link)) return res.status(400).send('Link http:// veya https:// ile başlamalı.');
    const now = new Date().toISOString();
    const contentState = await buildInitialContentState({
      sqlGetAsync,
      entityType: 'job',
      body: req.body,
      actorIsTrusted: hasAdminSession(req, getCurrentUser(req))
    });
    const result = await sqlRunAsync(
      `INSERT INTO jobs (poster_id, company, title, description, location, job_type, work_mode, link, created_at, show_in_feed, publication_status, approval_status, published_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        req.session.userId,
        company,
        title,
        description,
        location,
        jobType,
        workMode || null,
        link || null,
        now,
        contentState.showInFeed ? 1 : 0,
        contentState.publicationStatus,
        contentState.approvalStatus,
        contentState.publicationStatus === PUBLICATION_STATUS.PUBLISHED ? now : null
      ]
    );
    const newJobId = Number(result?.lastInsertRowid || 0);
    invalidateFeedCache?.();
    res.json({ ok: true, id: newJobId, pending: contentState.approvalStatus === APPROVAL_STATUS.PENDING, publication_status: contentState.publicationStatus, approval_status: contentState.approvalStatus });
  });

  app.delete('/api/new/jobs/:id', requireAuth, async (req, res) => {
    try {
      const user = getCurrentUser(req);
      const isAdmin = hasAdminSession(req, user);
      const row = await sqlGetAsync('SELECT id, poster_id FROM jobs WHERE id = ?', [req.params.id]);
      if (!row) return res.status(404).send('İş ilanı bulunamadı.');
      if (!isAdmin && !sameUserId(row.poster_id, req.session.userId)) return res.status(403).send('Bu ilanı silme yetkin yok.');
      await sqlRunAsync('DELETE FROM jobs WHERE id = ?', [req.params.id]);
      invalidateFeedCache?.();
      res.json({ ok: true });
    } catch (err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.post('/api/new/jobs/:id/like', requireAuth, async (req, res) => {
    try {
      const job = await sqlGetAsync('SELECT id, poster_id FROM jobs WHERE id = ?', [req.params.id]);
      if (!job) return res.status(404).send('İş ilanı bulunamadı.');
      const existing = await sqlGetAsync('SELECT id FROM entity_reactions WHERE entity_type = ? AND entity_id = ? AND user_id = ?', ['job', req.params.id, req.session.userId]);
      if (existing) {
        await sqlRunAsync('DELETE FROM entity_reactions WHERE id = ?', [existing.id]);
      } else {
        await sqlRunAsync('INSERT INTO entity_reactions (user_id, entity_type, entity_id, created_at) VALUES (?, ?, ?, ?)', [req.session.userId, 'job', req.params.id, new Date().toISOString()]);
        if (job.poster_id && !sameUserId(job.poster_id, req.session.userId)) {
          addNotification({ userId: job.poster_id, type: 'job_like', sourceUserId: req.session.userId, entityId: req.params.id, message: 'İş ilanını beğendi.' });
        }
      }
      const likeCount = (await sqlGetAsync('SELECT COUNT(*) AS cnt FROM entity_reactions WHERE entity_type = ? AND entity_id = ?', ['job', req.params.id]))?.cnt || 0;
      res.json({ ok: true, liked: !existing, likeCount });
    } catch (err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });
}
