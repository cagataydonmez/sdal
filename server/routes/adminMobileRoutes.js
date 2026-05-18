import {
  ADMIN_PERMISSIONS,
  assignableRolesForRole,
  buildAdminModules,
  buildEffectiveAdminPermissions,
  hasAdminPermission
} from '../src/admin/adminPermissions.js';

const ROLE_LABELS = Object.freeze({
  root: 'Süper admin',
  admin: 'Admin',
  mod: 'Moderatör',
  user: 'Üye'
});

function requireReason(req, res) {
  const reason = String(req.body?.reason || '').trim();
  if (reason.length < 8) {
    res.status(400).send('Bu işlem için en az 8 karakterlik gerekçe gerekli.');
    return null;
  }
  return reason.slice(0, 500);
}

function safeJsonParse(value, fallback = {}) {
  if (!value) return fallback;
  if (typeof value === 'object') return value;
  try {
    return JSON.parse(String(value));
  } catch {
    return fallback;
  }
}

export function registerAdminMobileRoutes(app, {
  requireAuth,
  sqlGetAsync,
  sqlAllAsync,
  sqlRunAsync,
  getCurrentUser,
  getUserRole,
  normalizeRole,
  getModeratorPermissionSummary,
  writeAuditLog,
  scheduleEngagementRecalculation,
  readAdminStorageSnapshot
}) {
  async function buildAccess(req) {
    const user = req.authUser || getCurrentUser(req);
    if (!user) return null;
    const role = getUserRole(user);
    const moderation = role === 'mod' ? getModeratorPermissionSummary(user.id) : { assignedKeys: [] };
    const permissions = buildEffectiveAdminPermissions({
      user,
      role,
      moderationPermissionKeys: moderation.assignedKeys
    });
    return {
      user,
      role,
      permissions,
      modules: buildAdminModules(permissions),
      moderationPermissionKeys: moderation.assignedKeys || []
    };
  }

  function requirePermission(permission) {
    return async (req, res, next) => {
      const access = await buildAccess(req);
      if (!access) return res.status(401).send('Login required');
      if (!hasAdminPermission(access.permissions, permission)) {
        return res.status(403).json({
          code: 'ADMIN_PERMISSION_REQUIRED',
          message: 'Bu işlem için yönetim yetkin yok.',
          permission
        });
      }
      req.adminAccess = access;
      req.authUser = access.user;
      req.adminUser = access.user;
      return next();
    };
  }

  app.get('/api/admin/permissions/me', requireAuth, async (req, res) => {
    const access = await buildAccess(req);
    if (!access || !hasAdminPermission(access.permissions, ADMIN_PERMISSIONS.ADMIN_ACCESS)) {
      return res.status(403).json({
        code: 'ADMIN_PERMISSION_REQUIRED',
        message: 'Yönetim paneline erişim yetkin yok.'
      });
    }
    return res.json({
      user: {
        id: Number(access.user.id || 0),
        kadi: String(access.user.kadi || '').trim(),
        isim: String(access.user.isim || '').trim(),
        soyisim: String(access.user.soyisim || '').trim(),
        role: access.role,
        roleLabel: ROLE_LABELS[access.role] || access.role
      },
      permissions: access.permissions,
      modules: access.modules,
      moderationPermissionKeys: access.moderationPermissionKeys,
      assignableRoles: assignableRolesForRole(access.role)
    });
  });

  app.get('/api/admin/mobile/summary', requireAuth, requirePermission(ADMIN_PERMISSIONS.ADMIN_ACCESS), async (req, res) => {
    try {
      const access = req.adminAccess;
      const canUsers = hasAdminPermission(access.permissions, ADMIN_PERMISSIONS.USERS_VIEW);
      const canModeration = hasAdminPermission(access.permissions, ADMIN_PERMISSIONS.MODERATION_VIEW);
      const canRequests = hasAdminPermission(access.permissions, ADMIN_PERMISSIONS.REQUESTS_VIEW);
      const canAudit = hasAdminPermission(access.permissions, ADMIN_PERMISSIONS.AUDIT_VIEW);
      const safeCount = async (sql, params = []) => {
        try {
          return Number((await sqlGetAsync(sql, params))?.cnt || 0);
        } catch {
          return 0;
        }
      };

      const counts = {};
      if (canUsers) {
        counts.users = await safeCount('SELECT COUNT(*) AS cnt FROM uyeler WHERE LOWER(COALESCE(role, ?)) != ?', ['user', 'root']);
        counts.suspendedUsers = await safeCount('SELECT COUNT(*) AS cnt FROM uyeler WHERE COALESCE(yasak, 0) = 1');
        counts.pendingUsers = await safeCount("SELECT COUNT(*) AS cnt FROM uyeler WHERE COALESCE(aktiv, 0) = 0 OR LOWER(COALESCE(verification_status, '')) = 'pending'");
      }
      if (canModeration) {
        counts.posts = await safeCount('SELECT COUNT(*) AS cnt FROM posts');
        counts.stories = await safeCount('SELECT COUNT(*) AS cnt FROM stories');
      }
      if (canRequests) {
        counts.requests = await safeCount("SELECT COUNT(*) AS cnt FROM member_requests WHERE LOWER(COALESCE(status, 'pending')) = 'pending'");
        const verificationTable = 'verification_requests';
        counts.verificationRequests = await safeCount(`SELECT COUNT(*) AS cnt FROM ${verificationTable} WHERE LOWER(COALESCE(status, 'pending')) = 'pending'`);
      }

      const attention = [];
      if (counts.requests > 0) attention.push({ key: 'requests', label: 'Bekleyen talepler', count: counts.requests, path: '/admin/requests', tone: 'warning' });
      if (counts.verificationRequests > 0) attention.push({ key: 'verification', label: 'Profil doğrulama', count: counts.verificationRequests, path: '/admin/requests', tone: 'warning' });
      if (counts.suspendedUsers > 0 && canUsers) attention.push({ key: 'suspended', label: 'Askıya alınmış üyeler', count: counts.suspendedUsers, path: '/admin/management', tone: 'danger' });

      const recentAudit = canAudit
        ? await sqlAllAsync(
            `SELECT l.id, l.actor_user_id, l.action, l.target_type, l.target_id, l.metadata, l.created_at,
                    u.kadi AS actor_handle, u.isim AS actor_first_name, u.soyisim AS actor_last_name
             FROM audit_log l
             LEFT JOIN uyeler u ON u.id = l.actor_user_id
             ORDER BY l.id DESC
             LIMIT 8`
          )
        : [];

      return res.json({
        counts,
        attention,
        modules: access.modules,
        system: typeof readAdminStorageSnapshot === 'function'
          ? readAdminStorageSnapshot()
          : null,
        recentAudit: recentAudit.map((row) => ({
          id: Number(row.id || 0),
          actorUserId: Number(row.actor_user_id || 0),
          actorHandle: String(row.actor_handle || '').trim(),
          actorName: `${String(row.actor_first_name || '').trim()} ${String(row.actor_last_name || '').trim()}`.trim(),
          action: String(row.action || '').trim(),
          targetType: String(row.target_type || '').trim(),
          targetId: String(row.target_id || '').trim(),
          metadata: safeJsonParse(row.metadata),
          createdAt: String(row.created_at || '').trim()
        }))
      });
    } catch (err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.get('/api/admin/audit-log', requireAuth, requirePermission(ADMIN_PERMISSIONS.AUDIT_VIEW), async (req, res) => {
    try {
      const limit = Math.max(1, Math.min(parseInt(req.query.limit || '40', 10), 100));
      const page = Math.max(1, parseInt(req.query.page || '1', 10));
      const offset = (page - 1) * limit;
      const action = String(req.query.action || '').trim();
      const targetType = String(req.query.targetType || '').trim();
      const params = [];
      const where = [];
      if (action) {
        where.push('LOWER(l.action) LIKE LOWER(?)');
        params.push(`%${action}%`);
      }
      if (targetType) {
        where.push('LOWER(COALESCE(l.target_type, ?)) = LOWER(?)');
        params.push('', targetType);
      }
      const whereSql = where.length ? `WHERE ${where.join(' AND ')}` : '';
      const total = Number((await sqlGetAsync(`SELECT COUNT(*) AS cnt FROM audit_log l ${whereSql}`, params))?.cnt || 0);
      const items = await sqlAllAsync(
        `SELECT l.id, l.actor_user_id, l.action, l.target_type, l.target_id, l.metadata, l.ip, l.user_agent, l.created_at,
                u.kadi AS actor_handle, u.isim AS actor_first_name, u.soyisim AS actor_last_name
         FROM audit_log l
         LEFT JOIN uyeler u ON u.id = l.actor_user_id
         ${whereSql}
         ORDER BY l.id DESC
         LIMIT ? OFFSET ?`,
        [...params, limit, offset]
      );
      res.json({
        items: items.map((row) => ({
          id: Number(row.id || 0),
          actorUserId: Number(row.actor_user_id || 0),
          actorHandle: String(row.actor_handle || '').trim(),
          actorName: `${String(row.actor_first_name || '').trim()} ${String(row.actor_last_name || '').trim()}`.trim(),
          action: String(row.action || '').trim(),
          targetType: String(row.target_type || '').trim(),
          targetId: String(row.target_id || '').trim(),
          metadata: safeJsonParse(row.metadata),
          ip: String(row.ip || '').trim(),
          userAgent: String(row.user_agent || '').trim(),
          createdAt: String(row.created_at || '').trim()
        })),
        meta: { page, limit, total, pages: Math.max(1, Math.ceil(total / limit)) }
      });
    } catch (err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.patch('/api/admin/users/:id/role', requireAuth, requirePermission(ADMIN_PERMISSIONS.USERS_MANAGE_ROLE), async (req, res) => {
    try {
      const targetId = Number(req.params.id || 0);
      if (!targetId) return res.status(400).send('Geçersiz kullanıcı ID.');
      if (Number(req.session.userId || 0) === targetId) return res.status(403).send('Kendi rolünüzü değiştiremezsiniz.');
      const reason = requireReason(req, res);
      if (!reason) return;

      const actorRole = req.adminAccess.role;
      const nextRole = normalizeRole(req.body?.role);
      const assignable = assignableRolesForRole(actorRole);
      if (!assignable.includes(nextRole)) return res.status(403).send('Bu rolü atama yetkiniz yok.');
      const target = await sqlGetAsync('SELECT id, kadi, role, admin FROM uyeler WHERE id = ?', [targetId]);
      if (!target) return res.status(404).send('Kullanıcı bulunamadı.');
      const previousRole = normalizeRole(target.role);
      if (previousRole === 'root' && actorRole !== 'root') return res.status(403).send('Root rolü yalnızca root tarafından değiştirilebilir.');
      if (previousRole === 'admin' && actorRole !== 'root') return res.status(403).send('Admin rolü yalnızca root tarafından değiştirilebilir.');

      await sqlRunAsync('UPDATE uyeler SET role = ?, admin = ? WHERE id = ?', [nextRole, nextRole === 'admin' || nextRole === 'root' ? 1 : 0, targetId]);
      writeAuditLog(req, {
        actorUserId: req.session.userId,
        action: 'user_role_changed',
        targetType: 'user',
        targetId: String(targetId),
        metadata: { previousRole, nextRole, reason }
      });
      scheduleEngagementRecalculation?.('admin_user_role_changed');
      res.json({ ok: true, userId: targetId, role: nextRole });
    } catch (err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.patch('/api/admin/users/:id/status', requireAuth, requirePermission(ADMIN_PERMISSIONS.USERS_MANAGE_STATUS), async (req, res) => {
    try {
      const targetId = Number(req.params.id || 0);
      if (!targetId) return res.status(400).send('Geçersiz kullanıcı ID.');
      if (Number(req.session.userId || 0) === targetId) return res.status(403).send('Kendi hesabınızı bu panelden askıya alamazsınız.');
      const reason = requireReason(req, res);
      if (!reason) return;

      const status = String(req.body?.status || '').trim().toLowerCase();
      if (!['active', 'suspended'].includes(status)) return res.status(400).send('Geçersiz durum.');
      const target = await sqlGetAsync('SELECT id, kadi, role, yasak, aktiv FROM uyeler WHERE id = ?', [targetId]);
      if (!target) return res.status(404).send('Kullanıcı bulunamadı.');
      const actorRole = req.adminAccess.role;
      const targetRole = normalizeRole(target.role);
      if (targetRole === 'root') return res.status(403).send('Root kullanıcı askıya alınamaz.');
      if (targetRole === 'admin' && actorRole !== 'root') return res.status(403).send('Admin hesabını yalnızca root askıya alabilir.');

      const nextBanned = status === 'suspended' ? 1 : 0;
      await sqlRunAsync('UPDATE uyeler SET yasak = ? WHERE id = ?', [nextBanned, targetId]);
      writeAuditLog(req, {
        actorUserId: req.session.userId,
        action: status === 'suspended' ? 'user_suspended' : 'user_unsuspended',
        targetType: 'user',
        targetId: String(targetId),
        metadata: {
          previousBanned: Number(target.yasak || 0) === 1,
          nextBanned: nextBanned === 1,
          reason
        }
      });
      res.json({ ok: true, userId: targetId, status, banned: nextBanned === 1 });
    } catch (err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.post('/api/admin/users/:id/warnings', requireAuth, requirePermission(ADMIN_PERMISSIONS.USERS_MANAGE_STATUS), async (req, res) => {
    try {
      const targetId = Number(req.params.id || 0);
      if (!targetId) return res.status(400).send('Geçersiz kullanıcı ID.');
      if (Number(req.session.userId || 0) === targetId) return res.status(403).send('Kendi hesabınıza uyarı ekleyemezsiniz.');
      const reason = requireReason(req, res);
      if (!reason) return;
      const target = await sqlGetAsync('SELECT id, kadi, role FROM uyeler WHERE id = ?', [targetId]);
      if (!target) return res.status(404).send('Kullanıcı bulunamadı.');
      const actorRole = req.adminAccess.role;
      const targetRole = normalizeRole(target.role);
      if (targetRole === 'root') return res.status(403).send('Root kullanıcıya uyarı eklenemez.');
      if (targetRole === 'admin' && actorRole !== 'root') return res.status(403).send('Admin hesabına yalnızca root uyarı ekleyebilir.');
      writeAuditLog(req, {
        actorUserId: req.session.userId,
        action: 'user_warning_added',
        targetType: 'user',
        targetId: String(targetId),
        metadata: {
          handle: String(target.kadi || ''),
          reason
        }
      });
      res.status(201).json({ ok: true, userId: targetId });
    } catch (err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });
}
