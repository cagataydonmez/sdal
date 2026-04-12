function escapeSqlLikeTerm(value) {
  return String(value || '').replace(/[\\%_]/g, '\\$&');
}

function stripHtmlToPlainText(value) {
  return String(value || '')
    .replace(/<[^>]+>/g, ' ')
    .replace(/&nbsp;/gi, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

function buildMemberDisplayName(row) {
  const fullName = `${String(row?.isim || '').trim()} ${String(row?.soyisim || '').trim()}`.trim();
  if (fullName) return fullName;
  const handle = String(row?.kadi || '').trim();
  if (handle) return handle;
  return 'SDAL Üyesi';
}

function normalizeFollowDetailSection(value) {
  const normalized = String(value || '').trim().toLowerCase();
  if (['groups', 'events', 'announcements', 'jobs', 'teachers', 'following', 'photos'].includes(normalized)) {
    return normalized;
  }
  return '';
}

function toBooleanFlag(value) {
  if (value === true || value === false) return value;
  if (typeof value === 'number') return value === 1;
  const normalized = String(value || '').trim().toLowerCase();
  return ['1', 'true', 'evet', 'yes'].includes(normalized);
}

export function registerTeacherNetworkRoutes(app, {
  requireAuth,
  requireAdmin,
  sqlGet,
  sqlGetAsync,
  sqlAllAsync,
  sqlRun,
  sqlRunAsync,
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
  let followsRelation = 'follows';

  function isMissingFollowsRelationError(error) {
    const message = String(error?.message || error || '').toLowerCase();
    return (
      message.includes('no such table: follows')
      || message.includes('relation "follows" does not exist')
      || message.includes("relation 'follows' does not exist")
      || message.includes('relation follows does not exist')
    );
  }

  async function withFollowsRelation(runQuery) {
    try {
      return await runQuery(followsRelation);
    } catch (error) {
      if (followsRelation !== 'follows' || !isMissingFollowsRelationError(error)) {
        throw error;
      }
      followsRelation = 'user_follows';
      return runQuery(followsRelation);
    }
  }

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
      const existing = await withFollowsRelation((followTable) =>
        sqlGetAsync(
          `SELECT id FROM ${followTable} WHERE follower_id = ? AND following_id = ?`,
          [req.session.userId, targetId]
        )
      );
      if (existing) {
        await withFollowsRelation((followTable) =>
          sqlRunAsync(`DELETE FROM ${followTable} WHERE id = ?`, [existing.id])
        );
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

      await withFollowsRelation((followTable) =>
        sqlRunAsync(
          `INSERT INTO ${followTable} (follower_id, following_id, created_at) VALUES (?, ?, ?)`,
          [req.session.userId, targetId, new Date().toISOString()]
        )
      );
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
      const rows = await withFollowsRelation((followTable) =>
        sqlAllAsync(
          `SELECT f.following_id, f.created_at AS followed_at, u.kadi, u.isim, u.soyisim, u.resim,
                  COALESCE(es.score, 0) AS engagement_score
           FROM ${followTable} f
           LEFT JOIN uyeler u ON u.id = f.following_id
           LEFT JOIN member_engagement_scores es ON es.user_id = f.following_id
           WHERE f.follower_id = ?
           ORDER BY ${orderBy}
           LIMIT ? OFFSET ?`,
          [req.session.userId, limit, offset]
        )
      );
      res.json({ items: rows, hasMore: rows.length === limit });
    } catch (err) {
      console.error('follows.list failed:', err);
      res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.get('/api/new/follows/:memberId/details/:section', requireAuth, async (req, res) => {
    try {
      const memberId = Number(req.params.memberId || 0);
      const section = normalizeFollowDetailSection(req.params.section);
      const limit = Math.min(Math.max(parseInt(req.query.limit || '40', 10), 1), 80);
      if (!Number.isInteger(memberId) || memberId <= 0) {
        return res.status(400).send('Geçersiz üye kimliği.');
      }
      if (!section) {
        return res.status(400).send('Geçersiz detay bölümü.');
      }

      const isFollowing = await withFollowsRelation((followTable) =>
        sqlGetAsync(
          `SELECT 1 AS ok
           FROM ${followTable}
           WHERE follower_id = ? AND following_id = ?
           LIMIT 1`,
          [req.session.userId, memberId]
        )
      );
      if (!isFollowing) {
        return res.status(404).send('Takip edilen üye bulunamadı.');
      }

      const member = await sqlGetAsync(
        `SELECT id, kadi, isim, soyisim, resim, verified
         FROM uyeler
         WHERE id = ?`,
        [memberId]
      );
      if (!member) {
        return res.status(404).send('Üye bulunamadı.');
      }

      let title = '';
      let items = [];
      const nowIso = new Date().toISOString();

      if (section === 'groups') {
        title = 'Dahil olduğu gruplar';
        const rows = await sqlAllAsync(
          `SELECT g.id, g.name, g.description, g.cover_image, m.role, m.created_at
           FROM group_members m
           JOIN groups g ON g.id = m.group_id
           WHERE m.user_id = ?
           ORDER BY COALESCE(NULLIF(m.created_at, ''), '1970-01-01T00:00:00.000Z') DESC, g.id DESC
           LIMIT ?`,
          [memberId, limit]
        );
        items = rows.map((row) => ({
          id: Number(row.id || 0),
          title: String(row.name || 'Grup').trim(),
          subtitle: stripHtmlToPlainText(row.description || ''),
          meta: String(row.role || '').trim(),
          route: Number(row.id || 0) > 0 ? `/groups/${Number(row.id)}` : '',
          image: String(row.cover_image || '').trim()
        }));
      } else if (section === 'events') {
        title = 'Katılacağı etkinlikler';
        const rows = await sqlAllAsync(
          `SELECT e.id, e.title, e.description AS body, e.starts_at, e.created_at
           FROM event_responses er
           JOIN events e ON e.id = er.event_id
           WHERE er.user_id = ?
             AND LOWER(COALESCE(er.response, '')) = 'attend'
             AND (COALESCE(CAST(e.approved AS INTEGER), 1) = 1 OR LOWER(CAST(e.approved AS TEXT)) IN ('true', 'evet', 'yes'))
             AND (
               COALESCE(NULLIF(CAST(e.starts_at AS TEXT), ''), '') = ''
               OR COALESCE(NULLIF(CAST(e.starts_at AS TEXT), ''), CAST(e.created_at AS TEXT), '9999-12-31T00:00:00.000Z') >= ?
             )
           ORDER BY COALESCE(NULLIF(CAST(e.starts_at AS TEXT), ''), CAST(e.created_at AS TEXT), '9999-12-31T00:00:00.000Z') ASC, e.id DESC
           LIMIT ?`,
          [memberId, nowIso, limit]
        );
        items = rows.map((row) => ({
          id: Number(row.id || 0),
          title: String(row.title || 'Etkinlik').trim(),
          subtitle: stripHtmlToPlainText(row.body || ''),
          meta: String(row.starts_at || row.created_at || '').trim(),
          route: '',
          image: ''
        }));
      } else if (section === 'announcements') {
        title = 'Gönderdiği duyurular';
        const rows = await sqlAllAsync(
          `SELECT id, title, body, image, created_at
           FROM announcements
           WHERE created_by = ?
             AND (COALESCE(CAST(approved AS INTEGER), 1) = 1 OR LOWER(CAST(approved AS TEXT)) IN ('true', 'evet', 'yes'))
           ORDER BY id DESC
           LIMIT ?`,
          [memberId, limit]
        );
        items = rows.map((row) => ({
          id: Number(row.id || 0),
          title: String(row.title || 'Duyuru').trim(),
          subtitle: stripHtmlToPlainText(row.body || ''),
          meta: String(row.created_at || '').trim(),
          route: '',
          image: String(row.image || '').trim()
        }));
      } else if (section === 'jobs') {
        title = 'Açtığı iş ilanları';
        const rows = await sqlAllAsync(
          `SELECT id, title, company, location, job_type, created_at, link
           FROM jobs
           WHERE poster_id = ?
           ORDER BY id DESC
           LIMIT ?`,
          [memberId, limit]
        );
        items = rows.map((row) => ({
          id: Number(row.id || 0),
          title: String(row.title || 'İş ilanı').trim(),
          subtitle: [row.company, row.location].map((value) => String(value || '').trim()).filter(Boolean).join(' • '),
          meta: [row.job_type, row.created_at].map((value) => String(value || '').trim()).filter(Boolean).join(' • '),
          route: '',
          image: '',
          externalUrl: String(row.link || '').trim()
        }));
      } else if (section === 'teachers') {
        title = 'Bağlantı kurduğu öğretmenler';
        const rows = await sqlAllAsync(
          `SELECT l.id, l.relationship_type, l.class_year, l.created_at,
                  u.id AS teacher_id, u.kadi, u.isim, u.soyisim, u.resim
           FROM teacher_alumni_links l
           JOIN uyeler u ON u.id = l.teacher_user_id
           WHERE l.alumni_user_id = ?
             AND COALESCE(l.review_status, 'pending') NOT IN ('rejected', 'merged')
           ORDER BY COALESCE(NULLIF(l.created_at, ''), '1970-01-01T00:00:00.000Z') DESC, l.id DESC
           LIMIT ?`,
          [memberId, limit]
        );
        items = rows.map((row) => ({
          id: Number(row.id || 0),
          title: buildMemberDisplayName(row),
          subtitle: String(row.kadi || '').trim() ? `@${String(row.kadi).trim()}` : '',
          meta: [row.relationship_type, row.class_year, row.created_at]
            .map((value) => String(value || '').trim())
            .filter(Boolean)
            .join(' • '),
          route: Number(row.teacher_id || 0) > 0 ? `/members/${Number(row.teacher_id)}` : '',
          image: String(row.resim || '').trim()
        }));
      } else if (section === 'following') {
        title = 'Takip ettiği üyeler';
        const rows = await withFollowsRelation((followTable) =>
          sqlAllAsync(
            `SELECT f.following_id, f.created_at AS followed_at, u.kadi, u.isim, u.soyisim, u.resim
             FROM ${followTable} f
             LEFT JOIN uyeler u ON u.id = f.following_id
             WHERE f.follower_id = ?
             ORDER BY COALESCE(NULLIF(f.created_at, ''), '1970-01-01T00:00:00.000Z') DESC, f.id DESC
             LIMIT ?`,
            [memberId, limit]
          )
        );
        items = rows.map((row) => ({
          id: Number(row.following_id || 0),
          title: buildMemberDisplayName(row),
          subtitle: String(row.kadi || '').trim() ? `@${String(row.kadi).trim()}` : '',
          meta: String(row.followed_at || '').trim(),
          route: Number(row.following_id || 0) > 0 ? `/members/${Number(row.following_id)}` : '',
          image: String(row.resim || '').trim()
        }));
      } else if (section === 'photos') {
        title = 'Albüme eklediği fotoğraflar';
        const rows = await sqlAllAsync(
          `SELECT f.id, f.dosyaadi, f.baslik, f.tarih, k.kategori
           FROM album_foto f
           LEFT JOIN album_kat k ON k.id = f.katid
           WHERE f.ekleyenid = ?
             AND (COALESCE(CAST(f.aktif AS INTEGER), 0) = 1 OR LOWER(CAST(f.aktif AS TEXT)) IN ('true', 'evet', 'yes'))
           ORDER BY COALESCE(NULLIF(f.tarih, ''), '1970-01-01T00:00:00.000Z') DESC, f.id DESC
           LIMIT ?`,
          [memberId, limit]
        );
        items = rows.map((row) => ({
          id: Number(row.id || 0),
          title: String(row.baslik || 'Fotoğraf').trim(),
          subtitle: String(row.kategori || '').trim(),
          meta: String(row.tarih || '').trim(),
          route: Number(row.id || 0) > 0 ? `/albums/photo/${Number(row.id)}` : '',
          image: String(row.dosyaadi || '').trim()
        }));
      }

      return res.json({
        member: {
          id: Number(member.id || 0),
          name: buildMemberDisplayName(member),
          handle: String(member.kadi || '').trim(),
          photo: String(member.resim || '').trim(),
          verified: toBooleanFlag(member.verified)
        },
        section,
        title,
        items
      });
    } catch (err) {
      console.error('follows.details failed:', err);
      return res.status(500).send('Beklenmeyen bir hata oluştu.');
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

      const follows = await withFollowsRelation((followTable) =>
        sqlAllAsync(
          `SELECT f.id, f.following_id, f.created_at AS followed_at,
                  u.kadi, u.isim, u.soyisim, u.resim, u.verified
           FROM ${followTable} f
           LEFT JOIN uyeler u ON u.id = f.following_id
           WHERE f.follower_id = ?
           ORDER BY COALESCE(NULLIF(f.created_at, ''), datetime('now')) DESC, f.id DESC
           LIMIT ? OFFSET ?`,
          [targetUserId, limit, offset]
        )
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
