import { buildVerificationApprovalEmail } from '../src/infra/verificationEmailTemplates.js';
import { APPROVAL_STATUS, PUBLICATION_STATUS } from '../src/shared/contentState.js';

const TEACHER_COHORT_VALUE = '9999';
const MODERATION_LOCK_TTL_MS = 2 * 60 * 1000;
const moderationLocks = new Map();

function isTeacherCohort(mezuniyetyili) {
  const raw = String(mezuniyetyili || '').trim().toLowerCase();
  return raw === TEACHER_COHORT_VALUE || raw === 'teacher' || raw === 'ogretmen' || raw === 'öğretmen';
}

function ensureVerificationTypeSettingsTable(sqlRun, dbDriver) {
  sqlRun(`
    CREATE TABLE IF NOT EXISTS verification_type_settings (
      type TEXT PRIMARY KEY,
      verification_required ${dbDriver === 'postgres' ? 'BOOLEAN' : 'INTEGER'} NOT NULL DEFAULT ${dbDriver === 'postgres' ? 'TRUE' : '1'},
      updated_at TEXT NOT NULL,
      updated_by INTEGER
    )
  `);
  const now = new Date().toISOString();
  sqlRun(
    `INSERT INTO verification_type_settings (type, verification_required, updated_at)
     VALUES ('alumni', ${dbDriver === 'postgres' ? 'TRUE' : '1'}, ?)
     ON CONFLICT(type) DO NOTHING`,
    [now]
  );
  sqlRun(
    `INSERT INTO verification_type_settings (type, verification_required, updated_at)
     VALUES ('teacher', ${dbDriver === 'postgres' ? 'TRUE' : '1'}, ?)
     ON CONFLICT(type) DO NOTHING`,
    [now]
  );
}

export function registerAdminContentModerationRoutes(app, {
  dbDriver,
  requireAdmin,
  requireModerationPermission,
  sqlGet,
  sqlAll,
  sqlRun,
  sqlGetAsync,
  sqlAllAsync,
  sqlRunAsync,
  getTableColumnSetAsync,
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
  invalidateBannedWordsCache,
  queueEmailDelivery
}) {
  const contentTypeMap = {
    event: { table: 'events', ownerColumn: 'created_by', titleColumn: 'title', bodyColumn: 'description', imageColumn: 'image' },
    announcement: { table: 'announcements', ownerColumn: 'created_by', titleColumn: 'title', bodyColumn: 'body', imageColumn: 'image' },
    job: { table: 'jobs', ownerColumn: 'poster_id', titleColumn: 'title', bodyColumn: 'description', imageColumn: 'image' },
    group_event: { table: 'group_events', ownerColumn: 'created_by', titleColumn: 'title', bodyColumn: 'description', imageColumn: 'image' },
    group_announcement: { table: 'group_announcements', ownerColumn: 'created_by', titleColumn: 'title', bodyColumn: 'body', imageColumn: 'image' },
    group_post: { table: 'posts', ownerColumn: 'user_id', titleColumn: 'content', bodyColumn: 'content', imageColumn: 'image' }
  };

  function normalizeModerationEntityType(value) {
    return String(value || '').trim().toLowerCase().replace(/[^a-z0-9_:-]+/g, '_');
  }

  function privateUploadUrl(kind, filename) {
    const safeName = String(filename || '').trim().split('/').pop();
    if (!safeName) return '';
    return `/api/private/uploads/${encodeURIComponent(kind)}/${encodeURIComponent(safeName)}`;
  }

  function normalizePrivateUploadUrl(value) {
    const text = String(value || '').trim();
    const match = text.match(/^\/uploads\/(verification-proofs|request-attachments)\/([^/?#]+)/);
    if (!match) return text;
    return privateUploadUrl(match[1], decodeURIComponent(match[2]));
  }

  function moderationLockKey(entityType, entityId) {
    return `${normalizeModerationEntityType(entityType)}:${Number(entityId || 0)}`;
  }

  function pruneModerationLocks(nowMs = Date.now()) {
    for (const [key, lock] of moderationLocks.entries()) {
      if (!lock?.expiresAtMs || lock.expiresAtMs <= nowMs) moderationLocks.delete(key);
    }
  }

  function actorLockLabel(req) {
    const user = req.authUser || getCurrentUser(req) || {};
    const name = `${String(user.isim || user.firstName || '').trim()} ${String(user.soyisim || user.lastName || '').trim()}`.trim();
    return name || String(user.username || user.kadi || user.handle || '').trim() || `Admin #${req.session?.userId || ''}`.trim();
  }

  app.post('/api/new/admin/moderation/locks', requireModerationPermission('posts.view'), async (req, res) => {
    const entityType = normalizeModerationEntityType(req.body?.entityType || req.body?.entity_type || req.body?.type);
    const entityId = Number(req.body?.entityId || req.body?.entity_id || req.body?.id || 0);
    if (!entityType || !entityId) return res.status(400).json({ ok: false, message: 'Geçersiz moderasyon kaydı.' });
    pruneModerationLocks();
    const key = moderationLockKey(entityType, entityId);
    const actorId = Number(req.session?.userId || req.authUser?.id || 0);
    const existing = moderationLocks.get(key);
    const nowMs = Date.now();
    if (existing && Number(existing.actorId || 0) !== actorId) {
      return res.status(409).json({
        ok: false,
        locked: true,
        lock: {
          entityType,
          entityId,
          moderatorId: existing.actorId,
          moderatorName: existing.actorName,
          lockedAt: existing.lockedAt,
          expiresAt: existing.expiresAt
        }
      });
    }
    const lockedAt = new Date(nowMs).toISOString();
    const expiresAt = new Date(nowMs + MODERATION_LOCK_TTL_MS).toISOString();
    const lock = {
      actorId,
      actorName: actorLockLabel(req),
      lockedAt,
      expiresAt,
      expiresAtMs: nowMs + MODERATION_LOCK_TTL_MS
    };
    moderationLocks.set(key, lock);
    res.json({
      ok: true,
      locked: true,
      lock: {
        entityType,
        entityId,
        moderatorId: actorId,
        moderatorName: lock.actorName,
        lockedAt,
        expiresAt
      }
    });
  });

  app.delete('/api/new/admin/moderation/locks/:entityType/:entityId', requireModerationPermission('posts.view'), async (req, res) => {
    const key = moderationLockKey(req.params.entityType, req.params.entityId);
    moderationLocks.delete(key);
    res.json({ ok: true });
  });

  app.post('/api/new/admin/moderation/escalations', requireModerationPermission('posts.moderate'), async (req, res) => {
    const entityType = normalizeModerationEntityType(req.body?.entityType || req.body?.entity_type || req.body?.type);
    const entityId = Number(req.body?.entityId || req.body?.entity_id || req.body?.id || 0);
    const policyCategory = String(req.body?.policyCategory || req.body?.policy_category || '').trim();
    const reason = String(req.body?.reason || req.body?.note || '').trim();
    if (!entityType || !entityId) return res.status(400).json({ ok: false, message: 'Geçersiz moderasyon kaydı.' });
    if (!policyCategory) return res.status(400).json({ ok: false, message: 'Politika kategorisi zorunlu.' });
    if (reason.length < 8) return res.status(400).json({ ok: false, message: 'Eskale gerekçesi en az 8 karakter olmalı.' });
    logAdminAction(req, 'moderation_escalated', {
      targetType: entityType,
      targetId: entityId,
      policyCategory,
      reason
    });
    res.status(201).json({ ok: true, escalated: true });
  });

  app.post('/api/new/admin/moderation/:entityType/:entityId/resolve', requireModerationPermission('posts.moderate'), async (req, res) => {
    const entityType = normalizeModerationEntityType(req.params.entityType);
    const entityId = Number(req.params.entityId || 0);
    const policyCategory = String(req.body?.policyCategory || req.body?.policy_category || '').trim();
    const reason = String(req.body?.reason || req.body?.note || '').trim();
    if (!entityType || !entityId) return res.status(400).json({ ok: false, message: 'Geçersiz moderasyon kaydı.' });
    if (!policyCategory) return res.status(400).json({ ok: false, message: 'Politika kategorisi zorunlu.' });
    if (reason.length < 8) return res.status(400).json({ ok: false, message: 'Kapatma gerekçesi en az 8 karakter olmalı.' });
    logAdminAction(req, 'moderation_resolved_without_action', {
      targetType: entityType,
      targetId: entityId,
      policyCategory,
      reason
    });
    moderationLocks.delete(moderationLockKey(entityType, entityId));
    res.json({ ok: true, resolved: true });
  });

  app.patch('/api/new/admin/moderation/:entityType/:entityId/author-status', requireModerationPermission('users.moderate'), async (req, res) => {
    const entityType = normalizeModerationEntityType(req.params.entityType);
    const entityId = Number(req.params.entityId || 0);
    const status = String(req.body?.status || '').trim().toLowerCase();
    const reason = String(req.body?.reason || '').trim().slice(0, 500);
    if (!entityType || !entityId) return res.status(400).json({ ok: false, message: 'Geçersiz moderasyon kaydı.' });
    if (!['active', 'suspended'].includes(status)) return res.status(400).json({ ok: false, message: 'Geçersiz kullanıcı durumu.' });
    if (status === 'suspended' && reason.length < 8) return res.status(400).json({ ok: false, message: 'Askıya alma gerekçesi en az 8 karakter olmalı.' });
    const ownerLookup = {
      post: { table: 'posts', ownerExpr: 'user_id' },
      comment: { table: 'post_comments', ownerExpr: 'COALESCE(author_id, user_id)' },
      story: { table: 'stories', ownerExpr: 'user_id' },
      job: { table: 'jobs', ownerExpr: 'poster_id' },
      event: { table: 'events', ownerExpr: 'created_by' },
      announcement: { table: 'announcements', ownerExpr: 'created_by' }
    };
    const config = ownerLookup[entityType];
    if (!config) return res.status(400).json({ ok: false, message: 'Desteklenmeyen içerik tipi.' });
    try {
      const row = await sqlGetAsync(`SELECT id, ${config.ownerExpr} AS user_id FROM ${config.table} WHERE id = ?`, [entityId]);
      if (!row) return res.status(404).json({ ok: false, message: 'İçerik bulunamadı.' });
      const userId = Number(row.user_id || 0);
      if (!userId) return res.status(404).json({ ok: false, message: 'İçerik sahibi bulunamadı.' });
      const target = ensureCanModerateTargetUser(req, res, userId, { notFoundMessage: 'İçerik sahibi bulunamadı.' });
      if (!target) return;
      const nextBanned = status === 'suspended' ? 1 : 0;
      await sqlRunAsync('UPDATE uyeler SET yasak = ? WHERE id = ?', [nextBanned, userId]);
      logAdminAction(req, status === 'suspended' ? 'moderation_author_suspended' : 'moderation_author_unsuspended', {
        targetType: 'user',
        targetId: userId,
        entityType,
        entityId,
        reason
      });
      res.json({ ok: true, userId, status });
    } catch (err) {
      console.error(err);
      if (!res.headersSent) res.status(500).json({ ok: false, message: 'Kullanıcı durumu güncellenemedi.' });
    }
  });

  function ensureContentApprovalSettingsTable() {
    sqlRun(`
      CREATE TABLE IF NOT EXISTS content_approval_settings (
        id ${dbDriver === 'postgres' ? 'BIGINT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY' : 'INTEGER PRIMARY KEY AUTOINCREMENT'},
        entity_type TEXT NOT NULL,
        group_id INTEGER,
        approval_required ${dbDriver === 'postgres' ? 'BOOLEAN' : 'INTEGER'} NOT NULL DEFAULT ${dbDriver === 'postgres' ? 'FALSE' : '0'},
        updated_at TEXT NOT NULL,
        updated_by INTEGER,
        UNIQUE(entity_type, group_id)
      )
    `);
    const now = new Date().toISOString();
    for (const type of ['event', 'announcement', 'job', 'group_event', 'group_announcement', 'group_post']) {
      sqlRun(
        `INSERT INTO content_approval_settings (entity_type, group_id, approval_required, updated_at)
         VALUES (?, NULL, ${dbDriver === 'postgres' ? 'FALSE' : '0'}, ?)
         ON CONFLICT(entity_type, group_id) DO NOTHING`,
        [type, now]
      );
    }
  }

  async function reviewContent({ req, res, entityType, entityId, groupId = null }) {
    const config = contentTypeMap[entityType];
    if (!config || !Number(entityId || 0)) return res.status(400).send('Geçersiz içerik tipi.');
    const row = await sqlGetAsync(`SELECT * FROM ${config.table} WHERE id = ?`, [entityId]);
    if (!row) return res.status(404).send('İçerik bulunamadı.');
    const action = String(req.body?.action || req.body?.status || '').trim().toLowerCase();
    const note = String(req.body?.note || req.body?.review_note || '').trim();
    const now = new Date().toISOString();
    let publicationStatus = PUBLICATION_STATUS.PENDING;
    let approvalStatus = APPROVAL_STATUS.PENDING;
    let legacyApproved = false;
    if (action === 'approve' || action === 'approved') {
      publicationStatus = PUBLICATION_STATUS.PUBLISHED;
      approvalStatus = APPROVAL_STATUS.APPROVED;
      legacyApproved = true;
    } else if (action === 'reject' || action === 'rejected') {
      publicationStatus = PUBLICATION_STATUS.UNPUBLISHED;
      approvalStatus = APPROVAL_STATUS.REJECTED;
    } else if (action === 'request_changes' || action === 'changes_requested') {
      publicationStatus = PUBLICATION_STATUS.DRAFT;
      approvalStatus = APPROVAL_STATUS.CHANGES_REQUESTED;
    } else {
      return res.status(400).send('Geçersiz işlem.');
    }
    const columns = await getTableColumnSetAsync(config.table);
    const updates = [
      'publication_status = ?',
      'approval_status = ?',
      'review_note = ?',
      'reviewed_by = ?',
      'reviewed_at = ?',
      'published_at = ?'
    ];
    const params = [publicationStatus, approvalStatus, note || null, req.session.userId, now, legacyApproved ? now : null];
    if (columns.has('approved')) {
      updates.push('approved = ?');
      params.push(dbDriver === 'postgres' ? legacyApproved : (legacyApproved ? 1 : 0));
    }
    if (columns.has('approved_by')) {
      updates.push('approved_by = ?');
      params.push(legacyApproved ? req.session.userId : null);
    }
    if (columns.has('approved_at')) {
      updates.push('approved_at = ?');
      params.push(legacyApproved ? now : null);
    }
    params.push(entityId);
    await sqlRunAsync(`UPDATE ${config.table} SET ${updates.join(', ')} WHERE id = ?`, params);
    const ownerId = Number(row[config.ownerColumn] || 0);
    if (ownerId) {
      addNotification({
        userId: ownerId,
        type: `${entityType}_${approvalStatus}`,
        sourceUserId: req.session.userId,
        entityId,
        message: action === 'approve' || action === 'approved'
          ? 'İçeriğin onaylandı ve yayınlandı.'
          : action === 'request_changes' || action === 'changes_requested'
            ? 'İçeriğin için değişiklik istendi.'
            : 'İçeriğin reddedildi.'
      });
    }
    logAdminAction(req, 'content_review', { targetType: entityType, targetId: entityId, groupId, action, note });
    return res.json({ ok: true, publication_status: publicationStatus, approval_status: approvalStatus });
  }

  app.get('/api/new/admin/verification-requests', requireModerationPermission('requests.view'), async (req, res) => {
    try {
      const verificationRequestsTable = dbDriver === 'postgres' ? 'identity_verification_requests' : 'verification_requests';
      const verificationColumns = typeof getTableColumnSetAsync === 'function'
        ? await getTableColumnSetAsync(verificationRequestsTable)
        : new Set();
      const optionalVerificationColumn = (column, fallback = "''") =>
        verificationColumns.has(column) ? `r.${column}` : `${fallback} AS ${column}`;
      const proofImageSelect = dbDriver === 'postgres'
        ? 'r.proof_media_asset_id AS proof_image_record_id'
        : optionalVerificationColumn('proof_image_record_id');
      const actor = req.authUser || getCurrentUser(req);
      const scope = getModerationScopeContext(actor);
      const { page, limit } = parseAdminListPagination(req.query, { defaultLimit: 40, maxLimit: 200 });
      const status = String(req.query.status || '').trim().toLowerCase();
      const q = String(req.query.q || '').trim();
      const userId = Number(req.query.userId || req.query.user_id || 0);
      const cohort = String(req.query.cohort || req.query.graduationYear || '').trim();
      const params = [];
      const whereParts = [
        "(u.role IS NULL OR LOWER(COALESCE(u.role, 'user')) != 'root')"
      ];
      if (status) {
        whereParts.push("LOWER(COALESCE(r.status, '')) = ?");
        params.push(status);
      }
      if (userId) {
        whereParts.push('r.user_id = ?');
        params.push(userId);
      }
      if (cohort) {
        whereParts.push("CAST(COALESCE(u.mezuniyetyili, '') AS TEXT) = ?");
        params.push(cohort);
      }
      if (q) {
        whereParts.push('(LOWER(CAST(u.kadi AS TEXT)) LIKE LOWER(?) OR LOWER(CAST(u.isim AS TEXT)) LIKE LOWER(?) OR LOWER(CAST(u.soyisim AS TEXT)) LIKE LOWER(?))');
        params.push(`%${q}%`, `%${q}%`, `%${q}%`);
      }
      const scopeFilter = applyModerationScopeFilter(scope, params, 'u.mezuniyetyili');
      const whereSql = `WHERE ${whereParts.join(' AND ')}${scopeFilter}`;

      const total = Number((await sqlGetAsync(
        `SELECT COUNT(*) AS cnt
         FROM ${verificationRequestsTable} r
         LEFT JOIN uyeler u ON u.id = r.user_id
         ${whereSql}`,
        params
      ))?.cnt || 0);
      const pages = Math.max(Math.ceil(total / limit), 1);
      const safePage = Math.min(page, pages);
      const safeOffset = (safePage - 1) * limit;

      const items = await sqlAllAsync(
        `SELECT r.id, r.user_id, r.status,
                ${optionalVerificationColumn('request_type')},
                ${optionalVerificationColumn('proof_path')},
                ${proofImageSelect},
                ${optionalVerificationColumn('created_at')},
                u.kadi, u.isim, u.soyisim, u.mezuniyetyili, u.resim
         FROM ${verificationRequestsTable} r
         LEFT JOIN uyeler u ON u.id = r.user_id
         ${whereSql}
         ORDER BY r.id DESC
         LIMIT ? OFFSET ?`,
        [...params, limit, safeOffset]
      );
      res.json({
        items: items.map((item) => ({
          ...item,
          proof_path: normalizePrivateUploadUrl(item.proof_path)
        })),
        meta: {
          page: safePage,
          pages,
          limit,
          total,
          status: status || '',
          q
        }
      });
    } catch (err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.post('/api/new/admin/verification-requests/:id', requireModerationPermission('requests.moderate'), async (req, res) => {
    try {
      const verificationRequestsTable = dbDriver === 'postgres' ? 'identity_verification_requests' : 'verification_requests';
      const status = req.body?.status;
      const requestId = Number(req.params.id || 0);
      if (!requestId) return res.status(400).send('Geçersiz talep ID.');
      if (!['approved', 'rejected'].includes(status)) return res.status(400).send('Geçersiz durum.');
      const row = await sqlGetAsync(
        `SELECT r.*, u.mezuniyetyili, u.email, u.isim
         FROM ${verificationRequestsTable} r
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
      await sqlRunAsync(`UPDATE ${verificationRequestsTable} SET status = ?, reviewed_at = ?, reviewer_id = ? WHERE id = ?`, [
        status,
        new Date().toISOString(),
        req.session.userId,
        requestId
      ]);
      const newVerificationStatus = status === 'approved' ? 'verified' : 'rejected';
      await sqlRunAsync('UPDATE uyeler SET verified = ?, verification_status = ? WHERE id = ?', [status === 'approved' ? 1 : 0, newVerificationStatus, row.user_id]);

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

      if (status === 'approved') {
        _sendVerificationApprovalEmail({ row, queueEmailDelivery }).catch(() => {});
      }

      logAdminAction(req, 'verification_request_review', {
        targetType: 'verification_request',
        targetId: requestId,
        userId: row.user_id,
        status
      });
      res.json({ ok: true });
    } catch (err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.post('/api/new/admin/verification-requests/:id/resend-notification', requireModerationPermission('requests.moderate'), async (req, res) => {
    try {
      const verificationRequestsTable = dbDriver === 'postgres' ? 'identity_verification_requests' : 'verification_requests';
      const requestId = Number(req.params.id || 0);
      if (!requestId) return res.status(400).send('Geçersiz talep ID.');
      const row = await sqlGetAsync(
        `SELECT r.*, u.mezuniyetyili, u.email, u.isim
         FROM ${verificationRequestsTable} r
         LEFT JOIN uyeler u ON u.id = r.user_id
         WHERE r.id = ?`,
        [requestId]
      );
      if (!row) return res.status(404).send('Talep bulunamadı.');
      if (row.status !== 'approved') return res.status(400).send('Yalnızca onaylanmış talepler için bildirim gönderilebilir.');

      addNotification({
        userId: row.user_id,
        type: 'verification_approved',
        sourceUserId: req.session.userId,
        entityId: requestId,
        message: 'Profil doğrulama talebin onaylandı.'
      });

      await _sendVerificationApprovalEmail({ row, queueEmailDelivery });

      logAdminAction(req, 'verification_notification_resend', {
        targetType: 'verification_request',
        targetId: requestId,
        userId: row.user_id
      });
      res.json({ ok: true });
    } catch (err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.get('/api/new/admin/verification-settings', requireAdmin, async (req, res) => {
    try {
      ensureVerificationTypeSettingsTable(sqlRun, dbDriver);
      const execAll = sqlAllAsync || ((...a) => Promise.resolve(sqlAll(...a)));
      const rows = await execAll('SELECT type, verification_required, updated_at FROM verification_type_settings ORDER BY type');
      const settings = {};
      for (const row of rows) {
        settings[row.type] = {
          verificationRequired: row.verification_required === true || Number(row.verification_required || 0) === 1,
          updatedAt: row.updated_at || null
        };
      }
      res.json({ settings });
    } catch (err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.put('/api/new/admin/verification-settings', requireAdmin, async (req, res) => {
    try {
      ensureVerificationTypeSettingsTable(sqlRun, dbDriver);
      const type = String(req.body?.type || '').trim().toLowerCase();
      if (!['alumni', 'teacher'].includes(type)) return res.status(400).send('Geçersiz doğrulama tipi. alumni veya teacher olmalı.');
      const verificationRequired = req.body?.verification_required;
      if (verificationRequired === undefined || verificationRequired === null) return res.status(400).send('verification_required alanı gerekli.');
      const boolVal = verificationRequired === true || Number(verificationRequired) === 1 || String(verificationRequired).toLowerCase() === 'true';
      const dbBool = dbDriver === 'postgres' ? boolVal : (boolVal ? 1 : 0);
      const now = new Date().toISOString();
      await sqlRunAsync(
        `INSERT INTO verification_type_settings (type, verification_required, updated_at, updated_by)
         VALUES (?, ?, ?, ?)
         ON CONFLICT(type) DO UPDATE SET verification_required = ?, updated_at = ?, updated_by = ?`,
        [type, dbBool, now, req.session.userId, dbBool, now, req.session.userId]
      );
      logAdminAction(req, 'verification_settings_update', {
        targetType: 'verification_settings',
        type,
        verificationRequired: boolVal
      });
      res.json({ ok: true, type, verificationRequired: boolVal });
    } catch (err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.get('/api/new/admin/content-approval-settings', requireAdmin, async (_req, res) => {
    try {
      ensureContentApprovalSettingsTable();
      const rows = await sqlAllAsync('SELECT entity_type, group_id, approval_required, updated_at FROM content_approval_settings ORDER BY entity_type, group_id');
      res.json({
        settings: rows.map((row) => ({
          entityType: row.entity_type,
          groupId: row.group_id,
          approvalRequired: row.approval_required === true || Number(row.approval_required || 0) === 1,
          updatedAt: row.updated_at || null
        }))
      });
    } catch (err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.put('/api/new/admin/content-approval-settings', requireAdmin, async (req, res) => {
    try {
      ensureContentApprovalSettingsTable();
      const entityType = String(req.body?.entity_type || req.body?.entityType || '').trim().toLowerCase();
      if (!['event', 'announcement', 'job', 'group_event', 'group_announcement', 'group_post'].includes(entityType)) {
        return res.status(400).send('Geçersiz içerik tipi.');
      }
      const groupId = req.body?.group_id || req.body?.groupId ? Number(req.body?.group_id || req.body?.groupId) : null;
      const approvalRequired = req.body?.approval_required === true
        || req.body?.approvalRequired === true
        || String(req.body?.approval_required ?? req.body?.approvalRequired ?? '').trim() === '1';
      const dbBool = dbDriver === 'postgres' ? approvalRequired : (approvalRequired ? 1 : 0);
      const now = new Date().toISOString();
      await sqlRunAsync(
        'DELETE FROM content_approval_settings WHERE entity_type = ? AND COALESCE(group_id, 0) = COALESCE(?, 0)',
        [entityType, groupId]
      );
      await sqlRunAsync(
        `INSERT INTO content_approval_settings (entity_type, group_id, approval_required, updated_at, updated_by)
         VALUES (?, ?, ?, ?, ?)`,
        [entityType, groupId, dbBool, now, req.session.userId]
      );
      logAdminAction(req, 'content_approval_settings_update', { entityType, groupId, approvalRequired });
      res.json({ ok: true, entityType, groupId, approvalRequired });
    } catch (err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.get('/api/new/admin/content-approvals', requireAdmin, async (req, res) => {
    try {
      const type = String(req.query.type || '').trim().toLowerCase();
      const wantedTypes = type && contentTypeMap[type] ? [type] : ['event', 'announcement', 'job', 'group_event', 'group_announcement', 'group_post'];
      const status = String(req.query.status || 'pending').trim().toLowerCase();
      const q = String(req.query.q || '').trim();
      const userId = Number(req.query.userId || req.query.user_id || 0);
      const cohort = String(req.query.cohort || req.query.graduationYear || '').trim();
      const items = [];
      for (const entityType of wantedTypes) {
        const config = contentTypeMap[entityType];
        const params = [];
        const whereParts = [];
        if (status && status !== 'all') {
          whereParts.push("LOWER(COALESCE(t.approval_status, 'not_required')) = ?");
          params.push(status);
        }
        if (userId) {
          whereParts.push(`t.${config.ownerColumn} = ?`);
          params.push(userId);
        }
        if (cohort) {
          whereParts.push("CAST(COALESCE(u.mezuniyetyili, '') AS TEXT) = ?");
          params.push(cohort);
        }
        if (q) {
          whereParts.push(`(LOWER(CAST(t.${config.titleColumn} AS TEXT)) LIKE LOWER(?) OR LOWER(CAST(t.${config.bodyColumn} AS TEXT)) LIKE LOWER(?) OR LOWER(CAST(u.kadi AS TEXT)) LIKE LOWER(?))`);
          params.push(`%${q}%`, `%${q}%`, `%${q}%`);
        }
        const whereSql = whereParts.length ? `WHERE ${whereParts.join(' AND ')}` : '';
        const rows = await sqlAllAsync(
          `SELECT t.id, t.${config.ownerColumn} AS owner_id, t.${config.titleColumn} AS title, t.${config.bodyColumn} AS body,
                  t.${config.imageColumn} AS image, t.created_at, t.publication_status, t.approval_status, t.review_note,
                  u.kadi, u.isim, u.soyisim, u.resim, u.mezuniyetyili
           FROM ${config.table} t
           LEFT JOIN uyeler u ON u.id = t.${config.ownerColumn}
           ${whereSql}
           ORDER BY t.id DESC
           LIMIT 50`,
          params
        );
        items.push(...rows.map((row) => ({ ...row, entity_type: entityType })));
      }
      items.sort((a, b) => String(b.created_at || '').localeCompare(String(a.created_at || '')));
      res.json({ items });
    } catch (err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.post('/api/new/admin/content-approvals/:type/:id/review', requireAdmin, async (req, res) => {
    try {
      return reviewContent({
        req,
        res,
        entityType: String(req.params.type || '').trim().toLowerCase(),
        entityId: Number(req.params.id || 0)
      });
    } catch (err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.post('/api/new/admin/users/:userId/verify', requireModerationPermission('requests.moderate'), async (req, res) => {
    try {
      const verificationRequestsTable = dbDriver === 'postgres' ? 'identity_verification_requests' : 'verification_requests';
      const userId = Number(req.params.userId || 0);
      if (!userId) return res.status(400).send('Geçersiz üye ID.');
      const user = await sqlGetAsync('SELECT id, mezuniyetyili, email, isim, verified FROM uyeler WHERE id = ?', [userId]);
      if (!user) return res.status(404).send('Üye bulunamadı.');
      if (Number(user.verified || 0) === 1) return res.status(400).send('Bu üye zaten doğrulanmış.');

      const scope = getModerationScopeContext(req.authUser || getCurrentUser(req));
      if (scope.isScopedModerator) {
        const targetYear = String(user.mezuniyetyili || '').trim();
        if (!targetYear || !scope.years.includes(targetYear)) {
          return res.status(403).send('Bu üye kapsamınız dışında.');
        }
      }

      await sqlRunAsync('UPDATE uyeler SET verified = ?, verification_status = ? WHERE id = ?', [
        dbDriver === 'postgres' ? true : 1,
        'verified',
        userId
      ]);
      assignUserToCohort(userId);

      const now = new Date().toISOString();
      const insertResult = await sqlRunAsync(
        `INSERT INTO ${verificationRequestsTable} (user_id, status, reviewed_at, reviewer_id, created_at)
         VALUES (?, 'approved', ?, ?, ?)`,
        [userId, now, req.session.userId, now]
      );
      const newRequestId = Number(insertResult?.lastInsertRowid || insertResult?.rows?.[0]?.id || 0) || null;

      addNotification({
        userId,
        type: 'verification_approved',
        sourceUserId: req.session.userId,
        entityId: newRequestId,
        message: 'Profil doğrulama talebin onaylandı.'
      });

      _sendVerificationApprovalEmail({ row: { ...user, user_id: userId }, queueEmailDelivery }).catch(() => {});

      logAdminAction(req, 'verification_manual_approve', {
        targetType: 'user',
        targetId: userId,
        userId
      });
      res.json({ ok: true });
    } catch (err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.get('/api/new/admin/groups', requireModerationPermission('groups.view'), async (req, res) => {
    try {
      const actor = req.authUser || getCurrentUser(req);
      const scope = getModerationScopeContext(actor);
      const { page, limit } = parseAdminListPagination(req.query, { defaultLimit: 50, maxLimit: 250 });
      const q = String(req.query.q || '').trim();
      const userId = Number(req.query.userId || req.query.user_id || 0);
      const cohort = String(req.query.cohort || req.query.graduationYear || '').trim();
      const params = [];
      const whereParts = ["(owner.role IS NULL OR LOWER(COALESCE(owner.role, 'user')) != 'root')"];
      if (userId) {
        whereParts.push('g.owner_id = ?');
        params.push(userId);
      }
      if (cohort) {
        whereParts.push("CAST(COALESCE(owner.mezuniyetyili, '') AS TEXT) = ?");
        params.push(cohort);
      }
      if (q) {
        whereParts.push('(LOWER(CAST(g.name AS TEXT)) LIKE LOWER(?) OR LOWER(CAST(g.description AS TEXT)) LIKE LOWER(?) OR LOWER(CAST(owner.kadi AS TEXT)) LIKE LOWER(?))');
        params.push(`%${q}%`, `%${q}%`, `%${q}%`);
      }
      const scopeFilter = applyModerationScopeFilter(scope, params, 'owner.mezuniyetyili');
      const whereSql = `WHERE ${whereParts.join(' AND ')}${scopeFilter}`;

      const total = Number((await sqlGetAsync(
        `SELECT COUNT(*) AS cnt
         FROM groups g
         LEFT JOIN uyeler owner ON owner.id = g.owner_id
         ${whereSql}`,
        params
      ))?.cnt || 0);
      const pages = Math.max(Math.ceil(total / limit), 1);
      const safePage = Math.min(page, pages);
      const safeOffset = (safePage - 1) * limit;

      const items = await sqlAllAsync(
        `SELECT g.id, g.name, g.description, g.cover_image, g.owner_id, g.created_at,
                owner.kadi AS owner_kadi, owner.isim AS owner_isim, owner.soyisim AS owner_soyisim,
                owner.resim AS owner_resim, owner.mezuniyetyili AS owner_mezuniyetyili
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
    } catch (err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.delete('/api/new/admin/groups/:id', requireModerationPermission('groups.delete'), async (req, res) => {
    try {
      const groupId = Number(req.params.id || 0);
      if (!groupId) return res.status(400).send('Geçersiz grup ID.');
      const group = await sqlGetAsync('SELECT id, owner_id FROM groups WHERE id = ?', [groupId]);
      if (!group) return res.status(404).send('Grup bulunamadı.');
      const scope = getModerationScopeContext(req.authUser || getCurrentUser(req));
      if (scope.isScopedModerator) {
        if (!group.owner_id) return res.status(403).send('Sahibi olmayan gruplar için kapsam doğrulanamadı.');
        const owner = await sqlGetAsync('SELECT mezuniyetyili FROM uyeler WHERE id = ?', [group.owner_id]);
        const ownerYear = String(owner?.mezuniyetyili || '').trim();
        if (!ownerYear || !scope.years.includes(ownerYear)) {
          return res.status(403).send('Bu grup kapsamınız dışında.');
        }
      }
      await sqlRunAsync('DELETE FROM group_members WHERE group_id = ?', [groupId]);
      await sqlRunAsync('DELETE FROM group_join_requests WHERE group_id = ?', [groupId]);
      await sqlRunAsync('DELETE FROM group_invites WHERE group_id = ?', [groupId]);
      await sqlRunAsync('DELETE FROM posts WHERE group_id = ?', [groupId]);
      await sqlRunAsync('DELETE FROM group_events WHERE group_id = ?', [groupId]);
      await sqlRunAsync('DELETE FROM group_announcements WHERE group_id = ?', [groupId]);
      await sqlRunAsync('DELETE FROM groups WHERE id = ?', [groupId]);
      logAdminAction(req, 'group_delete', { targetType: 'group', targetId: groupId });
      res.json({ ok: true });
    } catch (err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.get('/api/new/admin/stories', requireModerationPermission('stories.view'), async (req, res) => {
    try {
      const actor = req.authUser || getCurrentUser(req);
      const scope = getModerationScopeContext(actor);
      const { page, limit } = parseAdminListPagination(req.query, { defaultLimit: 60, maxLimit: 250 });
      const q = String(req.query.q || '').trim();
      const userId = Number(req.query.userId || req.query.user_id || 0);
      const cohort = String(req.query.cohort || req.query.graduationYear || '').trim();
      const params = [];
      const whereParts = ["(u.role IS NULL OR LOWER(COALESCE(u.role, 'user')) != 'root')"];
      if (userId) {
        whereParts.push('s.user_id = ?');
        params.push(userId);
      }
      if (cohort) {
        whereParts.push("CAST(COALESCE(u.mezuniyetyili, '') AS TEXT) = ?");
        params.push(cohort);
      }
      if (q) {
        whereParts.push('(LOWER(CAST(s.caption AS TEXT)) LIKE LOWER(?) OR LOWER(CAST(u.kadi AS TEXT)) LIKE LOWER(?))');
        params.push(`%${q}%`, `%${q}%`);
      }
      const scopeFilter = applyModerationScopeFilter(scope, params, 'u.mezuniyetyili');
      const whereSql = `WHERE ${whereParts.join(' AND ')}${scopeFilter}`;

      const total = Number((await sqlGetAsync(
        `SELECT COUNT(*) AS cnt
         FROM stories s
         LEFT JOIN uyeler u ON u.id = s.user_id
         ${whereSql}`,
        params
      ))?.cnt || 0);
      const pages = Math.max(Math.ceil(total / limit), 1);
      const safePage = Math.min(page, pages);
      const safeOffset = (safePage - 1) * limit;

      const items = await sqlAllAsync(
        `SELECT s.id, s.user_id, s.image, s.caption, s.created_at, s.expires_at,
                u.kadi, u.mezuniyetyili, u.isim, u.soyisim, u.resim
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
    } catch (err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.get('/api/new/admin/posts', requireModerationPermission('posts.view'), async (req, res) => {
    try {
      const actor = req.authUser || getCurrentUser(req);
      const scope = getModerationScopeContext(actor);
      const { page, limit } = parseAdminListPagination(req.query, { defaultLimit: 80, maxLimit: 300 });
      const q = String(req.query.q || '').trim();
      const userId = Number(req.query.userId || req.query.user_id || 0);
      const cohort = String(req.query.cohort || req.query.graduationYear || '').trim();
      const params = [];
      const whereParts = ["(u.role IS NULL OR LOWER(COALESCE(u.role, 'user')) != 'root')"];
      if (userId) {
        whereParts.push('p.user_id = ?');
        params.push(userId);
      }
      if (cohort) {
        whereParts.push("CAST(COALESCE(u.mezuniyetyili, '') AS TEXT) = ?");
        params.push(cohort);
      }
      if (q) {
        whereParts.push('(LOWER(CAST(p.content AS TEXT)) LIKE LOWER(?) OR LOWER(CAST(u.kadi AS TEXT)) LIKE LOWER(?))');
        params.push(`%${q}%`, `%${q}%`);
      }
      const scopeFilter = applyModerationScopeFilter(scope, params, 'u.mezuniyetyili');
      const whereSql = `WHERE ${whereParts.join(' AND ')}${scopeFilter}`;

      const total = Number((await sqlGetAsync(
        `SELECT COUNT(*) AS cnt
         FROM posts p
         LEFT JOIN uyeler u ON u.id = p.user_id
         ${whereSql}`,
        params
      ))?.cnt || 0);
      const pages = Math.max(Math.ceil(total / limit), 1);
      const safePage = Math.min(page, pages);
      const safeOffset = (safePage - 1) * limit;

      const items = await sqlAllAsync(
        `SELECT p.id, p.user_id, p.content, p.image, p.created_at,
                u.kadi, u.mezuniyetyili, u.isim, u.soyisim, u.resim, u.verified
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
    } catch (err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.get('/api/new/admin/comments', requireModerationPermission('posts.view'), async (req, res) => {
    try {
      const actor = req.authUser || getCurrentUser(req);
      const scope = getModerationScopeContext(actor);
      const { page, limit } = parseAdminListPagination(req.query, { defaultLimit: 80, maxLimit: 300 });
      const q = String(req.query.q || '').trim();
      const userId = Number(req.query.userId || req.query.user_id || 0);
      const cohort = String(req.query.cohort || req.query.graduationYear || '').trim();
      const params = [];
      const whereParts = ["(u.role IS NULL OR LOWER(COALESCE(u.role, 'user')) != 'root')"];
      if (userId) {
        whereParts.push('COALESCE(c.author_id, c.user_id) = ?');
        params.push(userId);
      }
      if (cohort) {
        whereParts.push("CAST(COALESCE(u.mezuniyetyili, '') AS TEXT) = ?");
        params.push(cohort);
      }
      if (q) {
        whereParts.push('(LOWER(CAST(COALESCE(c.body, c.comment) AS TEXT)) LIKE LOWER(?) OR LOWER(CAST(u.kadi AS TEXT)) LIKE LOWER(?))');
        params.push(`%${q}%`, `%${q}%`);
      }
      const scopeFilter = applyModerationScopeFilter(scope, params, 'u.mezuniyetyili');
      const whereSql = `WHERE ${whereParts.join(' AND ')}${scopeFilter}`;

      const total = Number((await sqlGetAsync(
        `SELECT COUNT(*) AS cnt
         FROM post_comments c
         LEFT JOIN uyeler u ON u.id = COALESCE(c.author_id, c.user_id)
         ${whereSql}`,
        params
      ))?.cnt || 0);
      const pages = Math.max(Math.ceil(total / limit), 1);
      const safePage = Math.min(page, pages);
      const safeOffset = (safePage - 1) * limit;

      const items = await sqlAllAsync(
        `SELECT c.id, c.post_id, COALESCE(c.author_id, c.user_id) AS user_id,
                COALESCE(c.body, c.comment) AS body, c.created_at,
                u.kadi, u.mezuniyetyili, u.isim, u.soyisim, u.resim
         FROM post_comments c
         LEFT JOIN uyeler u ON u.id = COALESCE(c.author_id, c.user_id)
         ${whereSql}
         ORDER BY c.id DESC
         LIMIT ? OFFSET ?`,
        [...params, limit, safeOffset]
      );
      res.json({
        items,
        meta: { page: safePage, pages, limit, total, q }
      });
    } catch (err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.delete('/api/new/admin/comments/:id', requireModerationPermission('posts.delete'), async (req, res) => {
    try {
      const commentId = Number(req.params.id || 0);
      if (!commentId) return res.status(400).send('Geçersiz yorum ID.');
      const comment = await sqlGetAsync('SELECT id, COALESCE(author_id, user_id) AS user_id FROM post_comments WHERE id = ?', [commentId]);
      if (!comment) return res.status(404).send('Yorum bulunamadı.');
      const target = ensureCanModerateTargetUser(req, res, comment.user_id, { notFoundMessage: 'Yorum sahibi bulunamadı.' });
      if (!target) return;
      const reason = String(req.body?.reason || '').trim().slice(0, 500);
      await sqlRunAsync('DELETE FROM post_comments WHERE id = ?', [commentId]);
      logAdminAction(req, 'comment_delete', { targetType: 'comment', targetId: commentId, commentId, userId: comment.user_id, ...(reason && { reason }) });
      res.json({ ok: true });
    } catch (err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.delete('/api/new/admin/posts/:id', requireModerationPermission('posts.delete'), async (req, res) => {
    try {
      const postId = Number(req.params.id || 0);
      if (!postId) return res.status(400).send('Geçersiz gönderi ID.');
      const post = await sqlGetAsync('SELECT id, user_id FROM posts WHERE id = ?', [postId]);
      if (!post) return res.status(404).send('Gönderi bulunamadı.');
      const target = ensureCanModerateTargetUser(req, res, post.user_id, { notFoundMessage: 'Gönderi sahibi bulunamadı.' });
      if (!target) return;
      const reason = String(req.body?.reason || '').trim().slice(0, 500);
      deletePostById(postId);
      logAdminAction(req, 'post_delete', { targetType: 'post', targetId: postId, postId, userId: post.user_id, ...(reason && { reason }) });
      scheduleEngagementRecalculation('post_deleted');
      res.json({ ok: true });
    } catch (err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.delete('/api/new/admin/stories/:id', requireModerationPermission('stories.delete'), async (req, res) => {
    try {
      const storyId = Number(req.params.id || 0);
      if (!storyId) return res.status(400).send('Geçersiz hikaye ID.');
      const story = await sqlGetAsync('SELECT id, user_id FROM stories WHERE id = ?', [storyId]);
      if (!story) return res.status(404).send('Hikaye bulunamadı.');
      const target = ensureCanModerateTargetUser(req, res, story.user_id, { notFoundMessage: 'Hikaye sahibi bulunamadı.' });
      if (!target) return;
      const reason = String(req.body?.reason || '').trim().slice(0, 500);
      await sqlRunAsync('DELETE FROM story_views WHERE story_id = ?', [storyId]);
      await sqlRunAsync('DELETE FROM stories WHERE id = ?', [storyId]);
      logAdminAction(req, 'story_delete', { targetType: 'story', targetId: storyId, storyId, userId: story.user_id, ...(reason && { reason }) });
      res.json({ ok: true });
    } catch (err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.get('/api/new/admin/chat/messages', requireModerationPermission('chat.view'), async (req, res) => {
    try {
      const actor = req.authUser || getCurrentUser(req);
      const scope = getModerationScopeContext(actor);
      const { page, limit } = parseAdminListPagination(req.query, { defaultLimit: 80, maxLimit: 300 });
      const q = String(req.query.q || '').trim();
      const userId = Number(req.query.userId || req.query.user_id || 0);
      const cohort = String(req.query.cohort || req.query.graduationYear || '').trim();
      const params = [];
      const whereParts = ["(u.role IS NULL OR LOWER(COALESCE(u.role, 'user')) != 'root')"];
      if (userId) {
        whereParts.push('c.user_id = ?');
        params.push(userId);
      }
      if (cohort) {
        whereParts.push("CAST(COALESCE(u.mezuniyetyili, '') AS TEXT) = ?");
        params.push(cohort);
      }
      if (q) {
        whereParts.push('(LOWER(CAST(c.message AS TEXT)) LIKE LOWER(?) OR LOWER(CAST(u.kadi AS TEXT)) LIKE LOWER(?))');
        params.push(`%${q}%`, `%${q}%`);
      }
      const scopeFilter = applyModerationScopeFilter(scope, params, 'u.mezuniyetyili');
      const whereSql = `WHERE ${whereParts.join(' AND ')}${scopeFilter}`;

      const total = Number((await sqlGetAsync(
        `SELECT COUNT(*) AS cnt
         FROM chat_messages c
         LEFT JOIN uyeler u ON u.id = c.user_id
         ${whereSql}`,
        params
      ))?.cnt || 0);
      const pages = Math.max(Math.ceil(total / limit), 1);
      const safePage = Math.min(page, pages);
      const safeOffset = (safePage - 1) * limit;
      let items = await sqlAllAsync(
        `SELECT c.id, c.user_id, c.message, c.created_at,
                u.kadi, u.isim, u.soyisim, u.resim, u.mezuniyetyili
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
          const legacyTotal = Number((await sqlGetAsync(`SELECT COUNT(*) AS cnt FROM hmes h ${fallbackWhereSql}`, fallbackParams))?.cnt || 0);
          const legacyPages = Math.max(Math.ceil(legacyTotal / limit), 1);
          const legacySafePage = Math.min(page, legacyPages);
          const legacyOffset = (legacySafePage - 1) * limit;
          items = await sqlAllAsync(
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
    } catch (err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.delete('/api/new/admin/chat/messages/:id', requireModerationPermission('chat.delete'), async (req, res) => {
    try {
      const messageId = Number(req.params.id || 0);
      if (!messageId) return res.status(400).send('Geçersiz mesaj ID.');
      const message = await sqlGetAsync('SELECT id, user_id FROM chat_messages WHERE id = ?', [messageId]);
      if (!message) return res.status(404).send('Mesaj bulunamadı.');
      const target = ensureCanModerateTargetUser(req, res, message.user_id, { notFoundMessage: 'Mesaj sahibi bulunamadı.' });
      if (!target) return;
      await sqlRunAsync('DELETE FROM chat_messages WHERE id = ?', [messageId]);
      broadcastChatDelete(messageId);
      logAdminAction(req, 'chat_message_delete', { targetType: 'chat_message', targetId: messageId, messageId, userId: message.user_id });
      scheduleEngagementRecalculation('chat_message_deleted');
      res.json({ ok: true });
    } catch (err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.get('/api/new/admin/messages', requireModerationPermission('messages.view'), async (req, res) => {
    try {
      const actor = req.authUser || getCurrentUser(req);
      const scope = getModerationScopeContext(actor);
      const { page, limit } = parseAdminListPagination(req.query, { defaultLimit: 80, maxLimit: 300 });
      const q = String(req.query.q || '').trim();
      const userId = Number(req.query.userId || req.query.user_id || 0);
      const cohort = String(req.query.cohort || req.query.graduationYear || '').trim();
      const params = [];
      const whereParts = [
        "(u1.role IS NULL OR LOWER(COALESCE(u1.role, 'user')) != 'root')",
        "(u2.role IS NULL OR LOWER(COALESCE(u2.role, 'user')) != 'root')"
      ];
      if (userId) {
        whereParts.push('(CAST(g.kimden AS INTEGER) = CAST(? AS INTEGER) OR CAST(g.kime AS INTEGER) = CAST(? AS INTEGER))');
        params.push(userId, userId);
      }
      if (cohort) {
        whereParts.push("(CAST(COALESCE(u1.mezuniyetyili, '') AS TEXT) = ? OR CAST(COALESCE(u2.mezuniyetyili, '') AS TEXT) = ?)");
        params.push(cohort, cohort);
      }
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
      const total = Number((await sqlGetAsync(
        `SELECT COUNT(*) AS cnt
         FROM gelenkutusu g
         LEFT JOIN uyeler u1 ON u1.id = g.kimden
         LEFT JOIN uyeler u2 ON u2.id = g.kime
         ${whereSql}`,
        params
      ))?.cnt || 0);
      const pages = Math.max(Math.ceil(total / limit), 1);
      const safePage = Math.min(page, pages);
      const safeOffset = (safePage - 1) * limit;
      const items = await sqlAllAsync(
        `SELECT g.id, g.konu, g.mesaj, g.tarih, g.kimden, g.kime,
                u1.kadi AS kimden_kadi, u2.kadi AS kime_kadi,
                u1.isim AS kimden_isim, u1.soyisim AS kimden_soyisim, u1.resim AS kimden_resim,
                u2.isim AS kime_isim, u2.soyisim AS kime_soyisim, u2.resim AS kime_resim,
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
    } catch (err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.delete('/api/new/admin/messages/:id', requireModerationPermission('messages.delete'), async (req, res) => {
    try {
      const messageId = Number(req.params.id || 0);
      if (!messageId) return res.status(400).send('Geçersiz mesaj ID.');
      const item = await sqlGetAsync('SELECT id, kimden, kime FROM gelenkutusu WHERE id = ?', [messageId]);
      if (!item) return res.status(404).send('Mesaj bulunamadı.');
      const scope = getModerationScopeContext(req.authUser || getCurrentUser(req));
      if (scope.isScopedModerator) {
        const sender = await sqlGetAsync('SELECT mezuniyetyili FROM uyeler WHERE id = ?', [item.kimden]);
        const recipient = await sqlGetAsync('SELECT mezuniyetyili FROM uyeler WHERE id = ?', [item.kime]);
        const senderYear = String(sender?.mezuniyetyili || '').trim();
        const recipientYear = String(recipient?.mezuniyetyili || '').trim();
        const touchesScopedYear = [senderYear, recipientYear].some((year) => year && scope.years.includes(year));
        if (!touchesScopedYear) {
          return res.status(403).send('Bu mesaj kapsamınız dışında.');
        }
      }
      await sqlRunAsync('DELETE FROM gelenkutusu WHERE id = ?', [messageId]);
      logAdminAction(req, 'inbox_message_delete', { targetType: 'direct_message', targetId: messageId, messageId });
      res.json({ ok: true });
    } catch (err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.get('/api/new/admin/filters', requireAdmin, async (req, res) => {
    try {
      const { page, limit } = parseAdminListPagination(req.query, { defaultLimit: 80, maxLimit: 300 });
      const q = String(req.query.q || '').trim();
      const whereParts = ['1=1'];
      const params = [];
      if (q) {
        whereParts.push('LOWER(CAST(kufur AS TEXT)) LIKE LOWER(?)');
        params.push(`%${q}%`);
      }
      const whereSql = `WHERE ${whereParts.join(' AND ')}`;
      const total = Number((await sqlGetAsync(`SELECT COUNT(*) AS cnt FROM filtre ${whereSql}`, params))?.cnt || 0);
      const pages = Math.max(Math.ceil(total / limit), 1);
      const safePage = Math.min(page, pages);
      const safeOffset = (safePage - 1) * limit;
      const items = await sqlAllAsync(
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
    } catch (err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.post('/api/new/admin/filters', requireAdmin, async (req, res) => {
    try {
      const kufur = normalizeBannedWord(req.body?.kufur);
      if (!kufur) return res.status(400).send('Kelime gerekli.');
      const exists = await sqlGetAsync('SELECT id FROM filtre WHERE LOWER(kufur) = LOWER(?)', [kufur]);
      if (exists?.id) return res.status(400).send('Kelime zaten var.');
      const result = await sqlRunAsync('INSERT INTO filtre (kufur) VALUES (?)', [kufur]);
      invalidateBannedWordsCache();
      logAdminAction(req, 'blocked_term_create', { targetType: 'blocked_term', targetId: result?.lastInsertRowid || null, kufur });
      res.json({ ok: true, id: result?.lastInsertRowid });
    } catch (err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.put('/api/new/admin/filters/:id', requireAdmin, async (req, res) => {
    try {
      const id = Number(req.params.id || 0);
      if (!id) return res.status(400).send('Geçersiz kelime ID.');
      const kufur = normalizeBannedWord(req.body?.kufur);
      if (!kufur) return res.status(400).send('Kelime gerekli.');
      const row = await sqlGetAsync('SELECT id FROM filtre WHERE id = ?', [id]);
      if (!row) return res.status(404).send('Kelime bulunamadı.');
      const exists = await sqlGetAsync('SELECT id FROM filtre WHERE LOWER(kufur) = LOWER(?) AND id <> ?', [kufur, id]);
      if (exists?.id) return res.status(400).send('Kelime zaten var.');
      await sqlRunAsync('UPDATE filtre SET kufur = ? WHERE id = ?', [kufur, id]);
      invalidateBannedWordsCache();
      logAdminAction(req, 'blocked_term_update', { targetType: 'blocked_term', targetId: id, kufur });
      res.json({ ok: true });
    } catch (err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.delete('/api/new/admin/filters/:id', requireAdmin, async (req, res) => {
    try {
      const id = Number(req.params.id || 0);
      if (!id) return res.status(400).send('Geçersiz kelime ID.');
      const exists = await sqlGetAsync('SELECT id, kufur FROM filtre WHERE id = ?', [id]);
      if (!exists) return res.status(404).send('Kelime bulunamadı.');
      await sqlRunAsync('DELETE FROM filtre WHERE id = ?', [id]);
      invalidateBannedWordsCache();
      logAdminAction(req, 'blocked_term_delete', { targetType: 'blocked_term', targetId: id, kufur: exists.kufur });
      res.json({ ok: true });
    } catch (err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });
}

async function _sendVerificationApprovalEmail({ row, queueEmailDelivery }) {
  if (typeof queueEmailDelivery !== 'function') return;
  const email = String(row?.email || '').trim();
  if (!email) return;
  const firstName = String(row?.isim || '').trim();
  const teacher = isTeacherCohort(row?.mezuniyetyili);
  const emailPayload = buildVerificationApprovalEmail({ isTeacher: teacher, firstName });
  await queueEmailDelivery({ to: email, subject: emailPayload.subject, html: emailPayload.html, text: emailPayload.text });
}
