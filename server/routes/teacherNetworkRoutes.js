function escapeSqlLikeTerm(value) {
  return String(value || '').replace(/[\\%_]/g, '\\$&');
}

export function registerTeacherNetworkRoutes(app, {
  requireAuth,
  requireAdmin,
  sqlGet,
  sqlGetAsync,
  sqlAllAsync,
  sqlRun,
  addNotification,
  recordNetworkingTelemetryEvent,
  apiSuccessEnvelope,
  sendApiError,
  ensureTeacherAlumniLinksTable,
  ensureVerifiedSocialHubMember,
  normalizeTeacherAlumniRelationshipType,
  parseTeacherNetworkClassYear,
  TEACHER_NETWORK_MIN_CLASS_YEAR,
  TEACHER_NETWORK_MAX_CLASS_YEAR,
  normalizeCohortValue,
  TEACHER_COHORT_VALUE,
  roleAtLeast,
  normalizeTeacherLinkCreatedVia,
  normalizeTeacherLinkSourceSurface,
  normalizeBooleanFlag,
  listTeacherLinkPairDuplicates,
  refreshTeacherLinkConfidenceScore,
  clearExploreSuggestionsCache,
  scheduleEngagementRecalculation,
  invalidateFeedCache
}) {
  app.get('/api/new/teachers/network', requireAuth, async (req, res) => {
    try {
      ensureTeacherAlumniLinksTable();
      const userId = Number(req.session?.userId || 0);
      const direction = String(req.query.direction || 'my_teachers').trim().toLowerCase() === 'my_students' ? 'my_students' : 'my_teachers';
      const relationshipType = normalizeTeacherAlumniRelationshipType(req.query.relationship_type);
      const classYear = parseTeacherNetworkClassYear(req.query.class_year);
      if (classYear.provided && !classYear.valid) {
        return sendApiError(
          res,
          400,
          'INVALID_CLASS_YEAR',
          `Sınıf yılı ${TEACHER_NETWORK_MIN_CLASS_YEAR}-${TEACHER_NETWORK_MAX_CLASS_YEAR} aralığında olmalıdır.`
        );
      }
      const limit = Math.min(Math.max(parseInt(req.query.limit || '30', 10), 1), 100);
      const offset = Math.max(parseInt(req.query.offset || '0', 10), 0);

      const where = [];
      const params = [];
      if (direction === 'my_students') {
        where.push('l.teacher_user_id = ?');
        params.push(userId);
      } else {
        where.push('l.alumni_user_id = ?');
        params.push(userId);
      }
      if (relationshipType) {
        where.push('l.relationship_type = ?');
        params.push(relationshipType);
      }
      if (classYear.value !== null) {
        where.push('l.class_year = ?');
        params.push(classYear.value);
      }
      where.push("COALESCE(l.review_status, 'pending') NOT IN ('rejected', 'merged')");

      const joinSql = direction === 'my_students'
        ? 'LEFT JOIN uyeler u ON u.id = l.alumni_user_id'
        : 'LEFT JOIN uyeler u ON u.id = l.teacher_user_id';

      const rows = await sqlAllAsync(
        `SELECT l.id, l.teacher_user_id, l.alumni_user_id, l.relationship_type, l.class_year, l.notes, l.confidence_score, l.created_at,
                COALESCE(l.created_via, 'manual_alumni_link') AS created_via,
                COALESCE(l.source_surface, 'teachers_network_page') AS source_surface,
                COALESCE(l.review_status, 'pending') AS review_status,
                l.last_reviewed_by,
                u.kadi, u.isim, u.soyisim, u.resim, u.verified, u.role
         FROM teacher_alumni_links l
         ${joinSql}
         WHERE ${where.join(' AND ')}
         ORDER BY COALESCE(CASE WHEN CAST(l.created_at AS TEXT) = '' THEN NULL ELSE l.created_at END, '1970-01-01T00:00:00.000Z') DESC, l.id DESC
         LIMIT ? OFFSET ?`,
        [...params, limit, offset]
      );

      const payload = { items: rows, direction, hasMore: rows.length === limit };
      return res.json(apiSuccessEnvelope('TEACHER_NETWORK_LIST_OK', 'Öğretmen ağı kayıtları listelendi.', payload, payload));
    } catch (err) {
      console.error('teachers.network.list failed:', err);
      return sendApiError(res, 500, 'TEACHER_NETWORK_LIST_FAILED', 'Beklenmeyen bir hata oluştu.');
    }
  });

  app.get('/api/new/teachers/options', requireAuth, async (req, res) => {
    try {
      ensureTeacherAlumniLinksTable();
      const alumniUserId = Number(req.session?.userId || 0);
      const term = String(req.query.term || '').trim();
      const limit = Math.min(Math.max(parseInt(req.query.limit || '20', 10), 1), 50);
      const includeId = Math.max(parseInt(req.query.include_id || '0', 10), 0);
      const params = [];
      let whereSql = "WHERE COALESCE(CAST(u.aktiv AS INTEGER), 1) = 1 AND COALESCE(CAST(u.yasak AS INTEGER), 0) = 0 AND (LOWER(COALESCE(u.role, '')) = 'teacher' OR LOWER(COALESCE(u.mezuniyetyili, '')) IN ('teacher', 'ogretmen'))";
      if (term) {
        whereSql += ' AND (LOWER(CAST(u.kadi AS TEXT)) LIKE LOWER(?) OR LOWER(CAST(u.isim AS TEXT)) LIKE LOWER(?) OR LOWER(CAST(u.soyisim AS TEXT)) LIKE LOWER(?))';
        params.push(`%${term}%`, `%${term}%`, `%${term}%`);
      }
      let rows = await sqlAllAsync(
        `SELECT u.id, u.kadi, u.isim, u.soyisim, u.mezuniyetyili, u.resim,
                (SELECT COUNT(*) FROM teacher_alumni_links l WHERE l.teacher_user_id = u.id AND COALESCE(l.review_status, 'pending') NOT IN ('rejected', 'merged')) AS student_count,
                (SELECT COUNT(*) FROM teacher_alumni_links l WHERE l.teacher_user_id = u.id AND l.alumni_user_id = ? AND COALESCE(l.review_status, 'pending') NOT IN ('rejected', 'merged')) AS existing_link_count,
                (SELECT GROUP_CONCAT(DISTINCT l.relationship_type) FROM teacher_alumni_links l WHERE l.teacher_user_id = u.id AND l.alumni_user_id = ? AND COALESCE(l.review_status, 'pending') NOT IN ('rejected', 'merged')) AS existing_relationship_types,
                (SELECT GROUP_CONCAT(DISTINCT CAST(COALESCE(l.class_year, '') AS TEXT)) FROM teacher_alumni_links l WHERE l.teacher_user_id = u.id AND l.alumni_user_id = ? AND COALESCE(l.review_status, 'pending') NOT IN ('rejected', 'merged')) AS existing_class_years
         FROM uyeler u
         ${whereSql}
         ORDER BY student_count DESC, u.kadi COLLATE NOCASE ASC
         LIMIT ?`,
        [alumniUserId, alumniUserId, alumniUserId, ...params, limit]
      );

      if (includeId > 0 && !rows.some((row) => Number(row?.id || 0) === includeId)) {
        const selectedRow = await sqlGetAsync(
          `SELECT u.id, u.kadi, u.isim, u.soyisim, u.mezuniyetyili, u.resim,
                  (SELECT COUNT(*) FROM teacher_alumni_links l WHERE l.teacher_user_id = u.id AND COALESCE(l.review_status, 'pending') NOT IN ('rejected', 'merged')) AS student_count,
                  (SELECT COUNT(*) FROM teacher_alumni_links l WHERE l.teacher_user_id = u.id AND l.alumni_user_id = ? AND COALESCE(l.review_status, 'pending') NOT IN ('rejected', 'merged')) AS existing_link_count,
                  (SELECT GROUP_CONCAT(DISTINCT l.relationship_type) FROM teacher_alumni_links l WHERE l.teacher_user_id = u.id AND l.alumni_user_id = ? AND COALESCE(l.review_status, 'pending') NOT IN ('rejected', 'merged')) AS existing_relationship_types,
                  (SELECT GROUP_CONCAT(DISTINCT CAST(COALESCE(l.class_year, '') AS TEXT)) FROM teacher_alumni_links l WHERE l.teacher_user_id = u.id AND l.alumni_user_id = ? AND COALESCE(l.review_status, 'pending') NOT IN ('rejected', 'merged')) AS existing_class_years
           FROM uyeler u
           WHERE u.id = ?
             AND COALESCE(CAST(u.aktiv AS INTEGER), 1) = 1
             AND COALESCE(CAST(u.yasak AS INTEGER), 0) = 0
             AND (LOWER(COALESCE(u.role, '')) = 'teacher' OR LOWER(COALESCE(u.mezuniyetyili, '')) IN ('teacher', 'ogretmen'))
           LIMIT 1`,
          [alumniUserId, alumniUserId, alumniUserId, includeId]
        );
        if (selectedRow) rows = [selectedRow, ...rows].slice(0, limit);
      }

      const payload = { items: rows };
      return res.json(apiSuccessEnvelope('TEACHER_OPTIONS_OK', 'Öğretmen seçenekleri hazır.', payload, payload));
    } catch (err) {
      console.error('teachers.options failed:', err);
      return sendApiError(res, 500, 'TEACHER_OPTIONS_FAILED', 'Beklenmeyen bir hata oluştu.');
    }
  });

  app.post('/api/new/teachers/network/link/:teacherId', requireAuth, async (req, res) => {
    try {
      if (!ensureVerifiedSocialHubMember(req, res)) return;
      ensureTeacherAlumniLinksTable();
      const alumniUserId = Number(req.session?.userId || 0);
      const teacherUserId = Number(req.params.teacherId || 0);
      if (!alumniUserId || !teacherUserId) return sendApiError(res, 400, 'INVALID_USER_ID', 'Geçersiz kullanıcı kimliği.');
      if (alumniUserId === teacherUserId) return sendApiError(res, 400, 'SELF_TEACHER_LINK_NOT_ALLOWED', 'Kendiniz için öğretmen bağlantısı ekleyemezsiniz.');

      const teacher = await sqlGetAsync('SELECT id, role, mezuniyetyili FROM uyeler WHERE id = ?', [teacherUserId]);
      if (!teacher) return sendApiError(res, 404, 'TEACHER_NOT_FOUND', 'Öğretmen bulunamadı.');
      const teacherRole = String(teacher.role || '').trim().toLowerCase();
      const teacherCohort = normalizeCohortValue(teacher.mezuniyetyili);
      const teacherTargetAllowed = teacherRole === 'teacher'
        || teacherCohort === TEACHER_COHORT_VALUE
        || roleAtLeast(teacherRole, 'admin');
      if (!teacherTargetAllowed) {
        return sendApiError(res, 409, 'INVALID_TEACHER_TARGET', 'Seçilen kullanıcı öğretmen ağına eklenebilir bir öğretmen hesabı değil.');
      }

      const relationshipType = normalizeTeacherAlumniRelationshipType(req.body?.relationship_type || 'taught_in_class') || 'taught_in_class';
      const classYear = parseTeacherNetworkClassYear(req.body?.class_year);
      if (classYear.provided && !classYear.valid) {
        return sendApiError(
          res,
          400,
          'INVALID_CLASS_YEAR',
          `Sınıf yılı ${TEACHER_NETWORK_MIN_CLASS_YEAR}-${TEACHER_NETWORK_MAX_CLASS_YEAR} aralığında olmalıdır.`
        );
      }
      const notes = String(req.body?.notes || '').trim().slice(0, 500);
      const createdVia = normalizeTeacherLinkCreatedVia(req.body?.created_via);
      const sourceSurface = normalizeTeacherLinkSourceSurface(req.body?.source_surface);
      const confirmSimilar = normalizeBooleanFlag(req.body?.confirm_similar);
      const now = new Date().toISOString();

      const pairLinks = listTeacherLinkPairDuplicates(alumniUserId, teacherUserId);
      const exactDuplicate = pairLinks.find((item) => (
        String(item?.relationship_type || '').trim().toLowerCase() === relationshipType
        && Number(item?.class_year ?? -1) === Number(classYear.value ?? -1)
      ));
      if (exactDuplicate) {
        return sendApiError(
          res,
          409,
          'RELATIONSHIP_ALREADY_EXISTS',
          'Bu öğretmen bağlantısı zaten kayıtlı.',
          { duplicates: pairLinks.slice(0, 5) },
          { duplicates: pairLinks.slice(0, 5) }
        );
      }

      if (pairLinks.length > 0 && !confirmSimilar) {
        return sendApiError(
          res,
          409,
          'SIMILAR_RELATIONSHIP_EXISTS',
          'Aynı öğretmen için benzer bir bağlantın zaten var. Devam etmeden önce mevcut kayıtları kontrol et.',
          {
            similar_links: pairLinks.slice(0, 5),
            requires_confirmation: true
          },
          {
            similar_links: pairLinks.slice(0, 5),
            requires_confirmation: true
          }
        );
      }

      const result = await sqlRunAsync(
        `INSERT INTO teacher_alumni_links
          (teacher_user_id, alumni_user_id, relationship_type, class_year, notes, confidence_score, created_via, source_surface, review_status, created_by, created_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
        [teacherUserId, alumniUserId, relationshipType, classYear.value, notes, 0.5, createdVia, sourceSurface, 'pending', alumniUserId, now]
      );
      const linkId = Number(result?.lastInsertRowid || 0);
      const confidenceScore = linkId ? refreshTeacherLinkConfidenceScore(linkId) : 0.5;

      addNotification({
        userId: teacherUserId,
        type: 'teacher_network_linked',
        sourceUserId: alumniUserId,
        entityId: linkId,
        message: 'Seni öğretmen ağına ekledi.'
      });
      recordNetworkingTelemetryEvent({
        userId: alumniUserId,
        eventName: 'teacher_link_created',
        sourceSurface,
        targetUserId: teacherUserId,
        entityType: 'teacher_link',
        entityId: linkId,
        metadata: {
          relationship_type: relationshipType,
          has_class_year: classYear.value !== null,
          review_status: 'pending'
        }
      });

      return res.json(apiSuccessEnvelope(
        'TEACHER_NETWORK_LINK_CREATED',
        'Öğretmen bağlantısı başarıyla kaydedildi.',
        {
          status: 'linked',
          relationship_type: relationshipType,
          class_year: classYear.value,
          confidence_score: confidenceScore,
          audit: {
            created_via: createdVia,
            source_surface: sourceSurface,
            review_status: 'pending',
            last_reviewed_by: null
          }
        },
        {
          status: 'linked',
          relationship_type: relationshipType,
          class_year: classYear.value,
          confidence_score: confidenceScore,
          created_via: createdVia,
          source_surface: sourceSurface,
          review_status: 'pending',
          last_reviewed_by: null
        }
      ));
    } catch (err) {
      console.error('teachers.network.link failed:', err);
      return sendApiError(res, 500, 'TEACHER_NETWORK_LINK_FAILED', 'Beklenmeyen bir hata oluştu.');
    }
  });

  app.post('/api/new/follow/:id', requireAuth, async (req, res) => {
    try {
      const targetId = req.params.id;
      if (String(targetId) === String(req.session.userId)) return res.status(400).send('Kendini takip edemezsin.');
      const existing = await sqlGetAsync('SELECT id FROM follows WHERE follower_id = ? AND following_id = ?', [req.session.userId, targetId]);
      if (existing) {
        await sqlRunAsync('DELETE FROM follows WHERE id = ?', [existing.id]);
        recordNetworkingTelemetryEvent({
          userId: req.session.userId,
          eventName: 'follow_removed',
          sourceSurface: req.body?.source_surface,
          targetUserId: targetId,
          entityType: 'user',
          entityId: targetId
        });
        clearExploreSuggestionsCache();
        scheduleEngagementRecalculation('follow_changed');
        invalidateFeedCache();
        return res.json({ ok: true, following: false });
      }

      await sqlRunAsync('INSERT INTO follows (follower_id, following_id, created_at) VALUES (?, ?, ?)', [
        req.session.userId,
        targetId,
        new Date().toISOString()
      ]);
      addNotification({
        userId: Number(targetId),
        type: 'follow',
        sourceUserId: req.session.userId,
        entityId: targetId,
        message: 'Seni takip etmeye başladı.'
      });
      recordNetworkingTelemetryEvent({
        userId: req.session.userId,
        eventName: 'follow_created',
        sourceSurface: req.body?.source_surface,
        targetUserId: targetId,
        entityType: 'user',
        entityId: targetId
      });
      clearExploreSuggestionsCache();
      scheduleEngagementRecalculation('follow_changed');
      invalidateFeedCache();
      return res.json({ ok: true, following: true });
    } catch (err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.get('/api/new/follows', requireAuth, async (req, res) => {
    try {
      const limit = Math.min(Math.max(parseInt(req.query.limit || '30', 10), 1), 100);
      const offset = Math.max(parseInt(req.query.offset || '0', 10), 0);
      const sort = String(req.query.sort || 'engagement').trim().toLowerCase();
      const orderBy = sort === 'followed_at'
        ? 'COALESCE(NULLIF(f.created_at, \'\'), datetime(\'now\')) DESC, f.id DESC'
        : 'COALESCE(es.score, 0) DESC, COALESCE(NULLIF(f.created_at, \'\'), datetime(\'now\')) DESC, f.id DESC';
      const rows = await sqlAllAsync(
        `SELECT f.following_id, f.created_at AS followed_at, u.kadi, u.isim, u.soyisim, u.resim,
                COALESCE(es.score, 0) AS engagement_score
         FROM follows f
         LEFT JOIN uyeler u ON u.id = f.following_id
         LEFT JOIN member_engagement_scores es ON es.user_id = f.following_id
         WHERE f.follower_id = ?
         ORDER BY ${orderBy}
         LIMIT ? OFFSET ?`,
        [req.session.userId, limit, offset]
      );
      res.json({ items: rows, hasMore: rows.length === limit });
    } catch (err) {
      console.error('follows.list failed:', err);
      res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.get('/api/new/admin/follows/:userId', requireAdmin, async (req, res) => {
    const targetUserId = Number(req.params.userId || 0);
    if (!Number.isInteger(targetUserId) || targetUserId <= 0) return res.status(400).send('Geçersiz üye kimliği.');
    const limit = Math.min(Math.max(parseInt(req.query.limit || '40', 10), 1), 200);
    const offset = Math.max(parseInt(req.query.offset || '0', 10), 0);

    try {
      const user = await sqlGetAsync('SELECT id, kadi, isim, soyisim FROM uyeler WHERE id = ?', [targetUserId]);
      if (!user) return res.status(404).send('Üye bulunamadı.');

      const follows = await sqlAllAsync(
        `SELECT f.id, f.following_id, f.created_at AS followed_at,
                u.kadi, u.isim, u.soyisim, u.resim, u.verified
         FROM follows f
         LEFT JOIN uyeler u ON u.id = f.following_id
         WHERE f.follower_id = ?
         ORDER BY COALESCE(NULLIF(f.created_at, ''), datetime('now')) DESC, f.id DESC
         LIMIT ? OFFSET ?`,
        [targetUserId, limit, offset]
      );

      const followTargets = follows
        .map((row) => ({
          followingId: Number(row.following_id || 0),
          kadi: String(row.kadi || '').trim()
        }))
        .filter((target) => Number.isInteger(target.followingId) && target.followingId > 0);
      const followingIds = Array.from(new Set(followTargets.map((target) => target.followingId)));
      const quoteTargets = followTargets
        .filter((target) => Boolean(target.kadi))
        .map((target) => ({
          followingId: target.followingId,
          needle: `%@${escapeSqlLikeTerm(target.kadi)}%`
        }));

      const messageCountMap = new Map();
      const recentMessagesMap = new Map();
      const postQuoteCountMap = new Map();
      const commentQuoteCountMap = new Map();
      const recentQuotesMap = new Map();

      if (followingIds.length > 0) {
        const messageCountRows = await sqlAllAsync(
          `SELECT CAST(kime AS INTEGER) AS following_id, COUNT(*) AS cnt
           FROM gelenkutusu
           WHERE CAST(kimden AS INTEGER) = CAST(? AS INTEGER)
             AND CAST(kime AS INTEGER) IN (${followingIds.map(() => '?').join(',')})
           GROUP BY CAST(kime AS INTEGER)`,
          [targetUserId, ...followingIds]
        );
        for (const row of messageCountRows) {
          messageCountMap.set(Number(row.following_id || 0), Number(row.cnt || 0));
        }

        const recentMessageRows = await sqlAllAsync(
          `SELECT following_id, id, konu, mesaj, tarih
           FROM (
             SELECT CAST(kime AS INTEGER) AS following_id,
                    id,
                    konu,
                    mesaj,
                    tarih,
                    ROW_NUMBER() OVER (PARTITION BY CAST(kime AS INTEGER) ORDER BY id DESC) AS rn
             FROM gelenkutusu
             WHERE CAST(kimden AS INTEGER) = CAST(? AS INTEGER)
               AND CAST(kime AS INTEGER) IN (${followingIds.map(() => '?').join(',')})
           ) ranked
           WHERE rn <= 3
           ORDER BY following_id ASC, id DESC`,
          [targetUserId, ...followingIds]
        );
        for (const row of recentMessageRows) {
          const followingId = Number(row.following_id || 0);
          if (!recentMessagesMap.has(followingId)) recentMessagesMap.set(followingId, []);
          recentMessagesMap.get(followingId).push({
            id: row.id,
            konu: row.konu,
            mesaj: row.mesaj,
            tarih: row.tarih
          });
        }
      }

      if (quoteTargets.length > 0) {
        const valuesSql = quoteTargets.map(() => '(?, ?)').join(', ');
        const valuesParams = quoteTargets.flatMap((target) => [target.followingId, target.needle]);

        const postQuoteCountRows = await sqlAllAsync(
          `WITH targets(following_id, needle) AS (VALUES ${valuesSql})
           SELECT t.following_id, COUNT(p.id) AS cnt
           FROM targets t
           LEFT JOIN posts p
             ON p.user_id = ?
            AND LOWER(COALESCE(p.content, '')) LIKE LOWER(t.needle) ESCAPE '\\'
           GROUP BY t.following_id`,
          [...valuesParams, targetUserId]
        );
        for (const row of postQuoteCountRows) {
          postQuoteCountMap.set(Number(row.following_id || 0), Number(row.cnt || 0));
        }

        const commentQuoteCountRows = await sqlAllAsync(
          `WITH targets(following_id, needle) AS (VALUES ${valuesSql})
           SELECT t.following_id, COUNT(c.id) AS cnt
           FROM targets t
           LEFT JOIN post_comments c
             ON c.user_id = ?
            AND LOWER(COALESCE(c.comment, '')) LIKE LOWER(t.needle) ESCAPE '\\'
           GROUP BY t.following_id`,
          [...valuesParams, targetUserId]
        );
        for (const row of commentQuoteCountRows) {
          commentQuoteCountMap.set(Number(row.following_id || 0), Number(row.cnt || 0));
        }

        const recentQuoteRows = await sqlAllAsync(
          `WITH targets(following_id, needle) AS (VALUES ${valuesSql}),
                ranked AS (
                  SELECT t.following_id,
                         p.id,
                         p.content,
                         p.created_at,
                         ROW_NUMBER() OVER (PARTITION BY t.following_id ORDER BY p.id DESC) AS rn
                  FROM targets t
                  JOIN posts p
                    ON p.user_id = ?
                   AND LOWER(COALESCE(p.content, '')) LIKE LOWER(t.needle) ESCAPE '\\'
                )
           SELECT following_id, id, content, created_at, 'post' AS source
           FROM ranked
           WHERE rn <= 3
           ORDER BY following_id ASC, id DESC`,
          [...valuesParams, targetUserId]
        );
        for (const row of recentQuoteRows) {
          const followingId = Number(row.following_id || 0);
          if (!recentQuotesMap.has(followingId)) recentQuotesMap.set(followingId, []);
          recentQuotesMap.get(followingId).push({
            id: row.id,
            content: row.content,
            created_at: row.created_at,
            source: row.source
          });
        }
      }

      const items = follows.map((row) => {
        const followingId = Number(row.following_id || 0);
        const quoteCount = Number(postQuoteCountMap.get(followingId) || 0) + Number(commentQuoteCountMap.get(followingId) || 0);
        return {
          ...row,
          messageCount: Number(messageCountMap.get(followingId) || 0),
          quoteCount,
          recentMessages: recentMessagesMap.get(followingId) || [],
          recentQuotes: recentQuotesMap.get(followingId) || []
        };
      });

      res.json({
        user,
        items,
        hasMore: items.length === limit
      });
    } catch (err) {
      console.error('admin.follows.list failed:', err);
      res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });
}
