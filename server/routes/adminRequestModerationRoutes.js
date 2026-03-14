export function registerAdminRequestModerationRoutes(app, {
  requireAdmin,
  requireModerationPermission,
  sqlGet,
  sqlAll,
  sqlRun,
  getCurrentUser,
  getModerationScopeContext,
  parseAdminListPagination,
  applyModerationScopeFilter,
  hasValidGraduationYear,
  addNotification,
  logAdminAction,
  ensureTeacherAlumniLinksTable,
  ensureTeacherAlumniLinkModerationEventsTable,
  normalizeTeacherAlumniRelationshipType,
  normalizeTeacherLinkReviewStatus,
  normalizeTeacherLinkReviewNote,
  canTransitionTeacherLinkReviewStatus,
  selectTeacherLinkMergeTarget,
  refreshTeacherLinkConfidenceScore,
  logTeacherLinkModerationEvent,
  buildTeacherLinkModerationAssessment,
  ensureCanModerateTargetUser,
  assignUserToCohort
}) {
  app.get('/api/new/admin/requests/notifications', requireAdmin, (_req, res) => {
    const categories = sqlAll(
      `SELECT c.category_key, c.label, c.description,
              COUNT(r.id) AS pending_count,
              MAX(r.created_at) AS latest_at
       FROM request_categories c
       LEFT JOIN member_requests r ON r.category_key = c.category_key AND r.status = 'pending'
       WHERE c.active = 1
       GROUP BY c.category_key, c.label, c.description
       ORDER BY pending_count DESC, c.id ASC`
    );
    res.json({ items: categories });
  });

  app.get('/api/new/admin/requests', requireModerationPermission('requests.view'), (req, res) => {
    const actor = req.authUser || getCurrentUser(req);
    const scope = getModerationScopeContext(actor);
    const { page, limit } = parseAdminListPagination(req.query, { defaultLimit: 60, maxLimit: 250 });
    const categoryKey = String(req.query.category || '').trim();
    const status = String(req.query.status || 'pending').trim();
    const q = String(req.query.q || '').trim();
    const where = ["(u.role IS NULL OR LOWER(COALESCE(u.role, 'user')) != 'root')"];
    const params = [];
    if (categoryKey) {
      where.push('r.category_key = ?');
      params.push(categoryKey);
    }
    if (status) {
      where.push('r.status = ?');
      params.push(status);
    }
    if (q) {
      where.push('(LOWER(CAST(u.kadi AS TEXT)) LIKE LOWER(?) OR LOWER(CAST(u.isim AS TEXT)) LIKE LOWER(?) OR LOWER(CAST(u.soyisim AS TEXT)) LIKE LOWER(?) OR LOWER(CAST(r.category_key AS TEXT)) LIKE LOWER(?))');
      params.push(`%${q}%`, `%${q}%`, `%${q}%`, `%${q}%`);
    }
    const scopeFilter = applyModerationScopeFilter(scope, params, 'u.mezuniyetyili');
    const whereSql = `WHERE ${where.join(' AND ')}${scopeFilter}`;

    const total = Number(sqlGet(
      `SELECT COUNT(*) AS cnt
       FROM member_requests r
       LEFT JOIN uyeler u ON u.id = r.user_id
       ${whereSql}`,
      params
    )?.cnt || 0);
    const pages = Math.max(Math.ceil(total / limit), 1);
    const safePage = Math.min(page, pages);
    const safeOffset = (safePage - 1) * limit;

    const items = sqlAll(
      `SELECT r.id, r.user_id, r.category_key, r.payload_json, r.status, r.created_at, r.reviewed_at, r.resolution_note,
              c.label AS category_label,
              u.kadi, u.isim, u.soyisim,
              reviewer.kadi AS reviewer_kadi
       FROM member_requests r
       LEFT JOIN request_categories c ON c.category_key = r.category_key
       LEFT JOIN uyeler u ON u.id = r.user_id
       LEFT JOIN uyeler reviewer ON reviewer.id = r.reviewer_id
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
        status,
        category: categoryKey || '',
        q
      }
    });
  });

  app.post('/api/new/admin/requests/:id/review', requireModerationPermission('requests.moderate'), (req, res) => {
    const status = String(req.body?.status || '').trim();
    const resolutionNote = String(req.body?.resolution_note || '').trim();
    const requestId = Number(req.params.id || 0);
    if (!requestId) return res.status(400).send('Geçersiz talep ID.');
    if (!['approved', 'rejected'].includes(status)) return res.status(400).send('Geçersiz durum.');
    const row = sqlGet(
      `SELECT r.*, u.mezuniyetyili
       FROM member_requests r
       LEFT JOIN uyeler u ON u.id = r.user_id
       WHERE r.id = ?`,
      [requestId]
    );
    if (!row) return res.status(404).send('Talep bulunamadı.');
    if (row.status !== 'pending') return res.status(400).send('Talep zaten sonuçlandırılmış.');
    const scope = getModerationScopeContext(req.authUser || getCurrentUser(req));
    if (scope.isScopedModerator) {
      const targetYear = String(row.mezuniyetyili || '').trim();
      if (!targetYear || !scope.years.includes(targetYear)) {
        return res.status(403).send('Bu talep kapsamınız dışında.');
      }
    }

    sqlRun(
      'UPDATE member_requests SET status = ?, reviewed_at = ?, reviewer_id = ?, resolution_note = ? WHERE id = ?',
      [status, new Date().toISOString(), req.session.userId, resolutionNote || null, requestId]
    );
    if (status === 'approved' && row.category_key === 'graduation_year_change') {
      let payload = {};
      try {
        payload = JSON.parse(String(row.payload_json || '{}')) || {};
      } catch {
        payload = {};
      }
      const nextYear = String(payload?.requestedGraduationYear || '').trim();
      if (hasValidGraduationYear(nextYear)) {
        sqlRun('UPDATE uyeler SET mezuniyetyili = ? WHERE id = ?', [nextYear, row.user_id]);
      }
    }
    addNotification({
      userId: row.user_id,
      type: status === 'approved' ? 'member_request_approved' : 'member_request_rejected',
      sourceUserId: req.session.userId,
      entityId: requestId,
      message: status === 'approved'
        ? 'Üye talebin sonuçlandırıldı ve onaylandı.'
        : 'Üye talebin sonuçlandırıldı ve reddedildi.'
    });
    logAdminAction(req, 'member_request_review', {
      targetType: 'member_request',
      targetId: requestId,
      userId: row.user_id,
      status
    });
    res.json({ ok: true });
  });

  app.get('/api/new/admin/teacher-network/links', requireModerationPermission('requests.view'), (req, res) => {
    ensureTeacherAlumniLinksTable();
    ensureTeacherAlumniLinkModerationEventsTable();
    const actor = req.authUser || getCurrentUser(req);
    const scope = getModerationScopeContext(actor);
    const { page, limit } = parseAdminListPagination(req.query, { defaultLimit: 40, maxLimit: 200 });
    const relationshipType = normalizeTeacherAlumniRelationshipType(req.query.relationship_type);
    const reviewStatus = normalizeTeacherLinkReviewStatus(req.query.review_status);
    const q = String(req.query.q || '').trim();

    const where = [];
    const params = [];
    if (relationshipType) {
      where.push('l.relationship_type = ?');
      params.push(relationshipType);
    }
    if (reviewStatus) {
      where.push('LOWER(COALESCE(l.review_status, ?)) = ?');
      params.push('pending', reviewStatus);
    }
    if (q) {
      where.push('(LOWER(CAST(teacher.kadi AS TEXT)) LIKE LOWER(?) OR LOWER(CAST(teacher.isim AS TEXT)) LIKE LOWER(?) OR LOWER(CAST(teacher.soyisim AS TEXT)) LIKE LOWER(?) OR LOWER(CAST(alumni.kadi AS TEXT)) LIKE LOWER(?) OR LOWER(CAST(alumni.isim AS TEXT)) LIKE LOWER(?) OR LOWER(CAST(alumni.soyisim AS TEXT)) LIKE LOWER(?))');
      params.push(`%${q}%`, `%${q}%`, `%${q}%`, `%${q}%`, `%${q}%`, `%${q}%`);
    }
    const scopeFilter = applyModerationScopeFilter(scope, params, 'alumni.mezuniyetyili');
    const whereSql = where.length ? `WHERE ${where.join(' AND ')}${scopeFilter}` : `WHERE 1=1${scopeFilter}`;

    const total = Number(sqlGet(
      `SELECT COUNT(*) AS cnt
       FROM teacher_alumni_links l
       LEFT JOIN uyeler teacher ON teacher.id = l.teacher_user_id
       LEFT JOIN uyeler alumni ON alumni.id = l.alumni_user_id
       ${whereSql}`,
      params
    )?.cnt || 0);
    const pages = Math.max(Math.ceil(total / limit), 1);
    const safePage = Math.min(page, pages);
    const offset = (safePage - 1) * limit;

    const items = sqlAll(
      `SELECT l.id, l.relationship_type, l.class_year, l.notes, l.created_at, l.confidence_score,
              COALESCE(l.created_via, 'manual_alumni_link') AS created_via,
              COALESCE(l.source_surface, 'teachers_network_page') AS source_surface,
              COALESCE(l.review_status, 'pending') AS review_status,
              l.last_reviewed_by, l.review_note, l.reviewed_at, l.merged_into_link_id,
              teacher.id AS teacher_user_id, teacher.kadi AS teacher_kadi, teacher.isim AS teacher_isim, teacher.soyisim AS teacher_soyisim, teacher.verified AS teacher_verified, teacher.role AS teacher_role, teacher.mezuniyetyili AS teacher_cohort,
              alumni.id AS alumni_user_id, alumni.kadi AS alumni_kadi, alumni.isim AS alumni_isim, alumni.soyisim AS alumni_soyisim, alumni.mezuniyetyili AS alumni_mezuniyetyili, alumni.verified AS alumni_verified,
              reviewer.kadi AS reviewer_kadi, reviewer.isim AS reviewer_isim, reviewer.soyisim AS reviewer_soyisim,
              (SELECT COUNT(*) FROM teacher_alumni_links pair_link WHERE pair_link.teacher_user_id = l.teacher_user_id AND pair_link.alumni_user_id = l.alumni_user_id AND COALESCE(pair_link.review_status, 'pending') NOT IN ('rejected', 'merged')) AS active_pair_link_count,
              (SELECT COUNT(*) FROM teacher_alumni_links teacher_link WHERE teacher_link.teacher_user_id = l.teacher_user_id AND COALESCE(teacher_link.review_status, 'pending') NOT IN ('rejected', 'merged')) AS teacher_active_link_count,
              (SELECT COUNT(*) FROM teacher_alumni_link_moderation_events e WHERE e.link_id = l.id) AS moderation_event_count,
              (SELECT e.event_type FROM teacher_alumni_link_moderation_events e WHERE e.link_id = l.id ORDER BY e.created_at DESC, e.id DESC LIMIT 1) AS last_event_type,
              (SELECT e.created_at FROM teacher_alumni_link_moderation_events e WHERE e.link_id = l.id ORDER BY e.created_at DESC, e.id DESC LIMIT 1) AS last_event_at
       FROM teacher_alumni_links l
       LEFT JOIN uyeler teacher ON teacher.id = l.teacher_user_id
       LEFT JOIN uyeler alumni ON alumni.id = l.alumni_user_id
       LEFT JOIN uyeler reviewer ON reviewer.id = l.last_reviewed_by
       ${whereSql}
       ORDER BY l.id DESC
       LIMIT ? OFFSET ?`,
      [...params, limit, offset]
    );

    const decoratedItems = items.map((item) => ({
      ...item,
      moderation_assessment: buildTeacherLinkModerationAssessment(item)
    }));

    res.json({
      items: decoratedItems,
      meta: {
        page: safePage,
        pages,
        total,
        limit,
        q,
        relationship_type: relationshipType || '',
        review_status: reviewStatus || ''
      }
    });
  });

  app.post('/api/new/admin/teacher-network/links/:id/review', requireModerationPermission('requests.moderate'), (req, res) => {
    ensureTeacherAlumniLinksTable();
    ensureTeacherAlumniLinkModerationEventsTable();
    const linkId = Number(req.params.id || 0);
    const reviewStatus = normalizeTeacherLinkReviewStatus(req.body?.status);
    const reviewNote = normalizeTeacherLinkReviewNote(req.body?.note);
    const requestedMergeTargetId = Number(req.body?.merge_into_link_id || 0);
    const actor = req.authUser || getCurrentUser(req);
    if (!linkId) return res.status(400).send('Geçersiz teacher network link ID.');
    if (!reviewStatus) return res.status(400).send('Geçersiz review status.');

    const row = sqlGet(
      `SELECT l.id, l.teacher_user_id, l.alumni_user_id, COALESCE(l.review_status, 'pending') AS review_status, alumni.mezuniyetyili
       FROM teacher_alumni_links l
       LEFT JOIN uyeler alumni ON alumni.id = l.alumni_user_id
       WHERE l.id = ?`,
      [linkId]
    );
    if (!row) return res.status(404).send('Teacher network link bulunamadı.');
    if (!canTransitionTeacherLinkReviewStatus(row.review_status, reviewStatus) && row.review_status !== reviewStatus) {
      return res.status(409).send('Bu teacher network kaydı seçilen review durumuna geçirilemez.');
    }

    const scope = getModerationScopeContext(actor);
    if (scope.isScopedModerator) {
      const targetYear = String(row.mezuniyetyili || '').trim();
      if (!targetYear || !scope.years.includes(targetYear)) {
        return res.status(403).send('Bu kayıt kapsamınız dışında.');
      }
    }

    let mergeTargetId = null;
    if (reviewStatus === 'merged') {
      const mergeTarget = selectTeacherLinkMergeTarget(linkId, row.teacher_user_id, row.alumni_user_id, requestedMergeTargetId);
      if (!mergeTarget) {
        return res.status(409).send('Bu kaydı birleştirmek için aynı öğretmen-mezun eşleşmesinde aktif bir hedef kayıt bulunamadı.');
      }
      mergeTargetId = Number(mergeTarget.id || 0);
    }
    const reviewedAt = new Date().toISOString();
    sqlRun(
      `UPDATE teacher_alumni_links
       SET review_status = ?,
           last_reviewed_by = ?,
           review_note = ?,
           reviewed_at = ?,
           merged_into_link_id = ?
       WHERE id = ?`,
      [reviewStatus, actor?.id || null, reviewNote || null, reviewedAt, mergeTargetId, linkId]
    );
    const confidenceScore = refreshTeacherLinkConfidenceScore(linkId);
    const affectedSiblingIds = sqlAll(
      `SELECT id
       FROM teacher_alumni_links
       WHERE teacher_user_id = ?
         AND alumni_user_id = ?
         AND id <> ?
         AND COALESCE(review_status, 'pending') NOT IN ('rejected', 'merged')`,
      [row.teacher_user_id, row.alumni_user_id, linkId]
    ) || [];
    for (const sibling of affectedSiblingIds) {
      refreshTeacherLinkConfidenceScore(sibling?.id);
    }
    logTeacherLinkModerationEvent({
      linkId,
      actorUserId: actor?.id || null,
      eventType: reviewStatus === 'merged' ? 'teacher_link_merged' : 'teacher_link_reviewed',
      fromStatus: row.review_status,
      toStatus: reviewStatus,
      note: reviewNote,
      mergeTargetId
    });

    logAdminAction(req, 'teacher_network_link_review', {
      targetType: 'teacher_network_link',
      targetId: linkId,
      reviewStatus,
      alumniUserId: Number(row.alumni_user_id || 0),
      mergeTargetId,
      reviewedAt
    });

    const reviewNotificationType = reviewStatus === 'confirmed'
      ? 'teacher_link_review_confirmed'
      : reviewStatus === 'flagged'
        ? 'teacher_link_review_flagged'
        : reviewStatus === 'rejected'
          ? 'teacher_link_review_rejected'
          : reviewStatus === 'merged'
            ? 'teacher_link_review_merged'
            : '';
    if (reviewNotificationType && Number(row.alumni_user_id || 0) > 0) {
      addNotification({
        userId: Number(row.alumni_user_id),
        type: reviewNotificationType,
        sourceUserId: Number(actor?.id || 0) || null,
        entityId: linkId,
        message: reviewStatus === 'confirmed'
          ? 'Eklediğin öğretmen bağlantısı moderasyon tarafından onaylandı.'
          : reviewStatus === 'flagged'
            ? 'Eklediğin öğretmen bağlantısı ek inceleme için işaretlendi.'
            : reviewStatus === 'rejected'
              ? 'Eklediğin öğretmen bağlantısı reddedildi.'
              : 'Eklediğin öğretmen bağlantısı benzer bir kayıt ile birleştirildi.'
      });
    }

    res.json({
      ok: true,
      status: reviewStatus,
      id: linkId,
      confidence_score: confidenceScore,
      review_note: reviewNote,
      reviewed_at: reviewedAt,
      merged_into_link_id: mergeTargetId
    });
  });

  app.post('/api/new/admin/verify', requireAdmin, (req, res) => {
    const userId = Number(req.body?.userId || 0);
    const value = String(req.body?.verified || '0') === '1' ? 1 : 0;
    if (!userId) return res.status(400).send('User ID gerekli.');
    const target = ensureCanModerateTargetUser(req, res, userId);
    if (!target) return;
    sqlRun('UPDATE uyeler SET verified = ?, verification_status = ? WHERE id = ?', [value, value === 1 ? 'verified' : 'pending', userId]);

    if (value === 1) {
      assignUserToCohort(userId);
    }

    logAdminAction(req, 'user_verify_toggle', {
      targetType: 'user',
      targetId: userId,
      verified: value === 1
    });
    res.json({ ok: true });
  });
}
