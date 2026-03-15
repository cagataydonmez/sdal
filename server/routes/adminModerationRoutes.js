export function registerAdminModerationRoutes(app, deps) {
  const {
    sqlGet,
    sqlAll,
    sqlRun,
    sqlGetAsync,
    sqlAllAsync,
    sqlRunAsync,
    requireAdmin,
    requireAuth,
    requireRole,
    requireScopedModeration,
    phase1Domain,
    getUserRole,
    roleAtLeast,
    hasAdminRole,
    getCurrentUser,
    getModeratorPermissionSummary,
    normalizeRole,
    parseGraduationYear,
    writeAuditLog,
    writeLegacyLog,
    writeAppLog,
    adminPassword,
    MIN_GRADUATION_YEAR,
    MAX_GRADUATION_YEAR,
    MODERATION_ACTION_DEFINITIONS,
    MODERATION_RESOURCE_DEFINITIONS,
    MODERATION_PERMISSION_DEFINITIONS,
    MODERATION_PERMISSION_KEY_SET,
    toDbBooleanParam
  } = deps;

  app.get('/api/admin/session', async (req, res) => {
    try {
      if (!req.session.userId) return res.json({ user: null, adminOk: false });
      const user = await sqlGetAsync('SELECT id, kadi, isim, soyisim, admin, albumadmin, role FROM uyeler WHERE id = ?', [req.session.userId]);
      if (!user) return res.json({ user: null, adminOk: false });
      const role = getUserRole(user);
      const moderationPermissionKeys = role === 'mod' ? getModeratorPermissionSummary(user.id).assignedKeys : [];
      res.json({ user: { ...user, role, admin: hasAdminRole(user) ? 1 : 0, moderationPermissionKeys }, adminOk: roleAtLeast(role, 'admin') ? true : !!req.session.adminOk });
    } catch(err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.get('/api/admin/root-status', requireAdmin, async (_req, res) => {
    try {
      const rootUser = await sqlGetAsync("SELECT id, kadi, ilktarih, role FROM uyeler WHERE LOWER(COALESCE(role, '')) = 'root' ORDER BY id ASC LIMIT 1");
      res.json({
        hasRoot: !!rootUser,
        rootUser: rootUser || null,
        bootstrapPasswordConfigured: Boolean(String(process.env.ROOT_BOOTSTRAP_PASSWORD || '').trim())
      });
    } catch(err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.post('/admin/users/:id/role', requireAuth, requireRole('admin'), phase1Domain.controllers.admin.updateUserRole);

  app.post('/admin/moderators/:id/scopes', requireAuth, requireRole('admin'), async (req, res) => {
    try {
      const actor = req.authUser;
      const targetId = Number(req.params.id || 0);
      const years = Array.isArray(req.body?.graduationYears) ? req.body.graduationYears : [];
      if (!targetId) return res.status(400).send('Geçersiz kullanıcı.');
      if (!years.length) return res.status(400).send('En az bir mezuniyet yılı gerekli.');
      const target = await sqlGetAsync('SELECT id, role FROM uyeler WHERE id = ?', [targetId]);
      if (!target) return res.status(404).send('Kullanıcı bulunamadı.');
      if (normalizeRole(target.role) === 'root') return res.status(400).send('Root için kapsam atanamaz.');
      const normalizedYears = Array.from(new Set(years.map(parseGraduationYear).filter((y) => Number.isFinite(y) && y >= MIN_GRADUATION_YEAR && y <= MAX_GRADUATION_YEAR)));
      if (!normalizedYears.length) return res.status(400).send('Geçerli mezuniyet yılı bulunamadı.');
      await sqlRunAsync('UPDATE uyeler SET role = ?, admin = 0 WHERE id = ?', ['mod', targetId]);
      const created = [];
      for (const year of normalizedYears) {
        await sqlRunAsync(`INSERT INTO moderator_scopes (user_id, scope_type, scope_value, graduation_year, created_by, created_at)
          VALUES (?, 'graduation_year', ?, ?, ?, ?)
          ON CONFLICT(user_id, scope_type, scope_value) DO NOTHING`, [targetId, String(year), year, actor.id, new Date().toISOString()]);
        created.push(year);
      }
      writeAuditLog(req, { actorUserId: actor.id, action: 'moderator_scope_assigned', targetType: 'user', targetId: String(targetId), metadata: { graduationYears: created } });
      res.json({ ok: true, userId: targetId, scopes: created });
    } catch(err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.post('/admin/moderation/check/:graduationYear', requireAuth, requireScopedModeration((req) => req.params.graduationYear), (req, res) => {
    res.json({ ok: true, graduationYear: Number(req.params.graduationYear) });
  });

  app.get('/admin/moderators', requireAuth, requireRole('admin'), async (_req, res) => {
    try {
      const rows = await sqlAllAsync(
        `SELECT u.id, u.kadi, u.isim, u.soyisim, u.role, ms.scope_value AS graduation_year
         FROM uyeler u
         LEFT JOIN moderator_scopes ms ON ms.user_id = u.id AND ms.scope_type = 'graduation_year'
         WHERE LOWER(COALESCE(u.role, 'user')) = 'mod' AND (u.role IS NULL OR LOWER(u.role) != 'root')
         ORDER BY u.id ASC, ms.scope_value ASC`
      );
      const map = new Map();
      for (const row of rows) {
        if (!map.has(row.id)) map.set(row.id, { id: row.id, kadi: row.kadi, isim: row.isim, soyisim: row.soyisim, role: row.role, graduationYears: [] });
        if (row.graduation_year) map.get(row.id).graduationYears.push(Number(row.graduation_year));
      }
      res.json({ moderators: Array.from(map.values()) });
    } catch(err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.get('/api/admin/moderation/permissions/catalog', requireAuth, requireRole('admin'), (_req, res) => {
    res.json({
      actions: MODERATION_ACTION_DEFINITIONS,
      resources: MODERATION_RESOURCE_DEFINITIONS,
      permissions: MODERATION_PERMISSION_DEFINITIONS
    });
  });

  app.get('/api/admin/moderation/permissions/:userId', requireAuth, requireRole('admin'), async (req, res) => {
    try {
      const userId = Number(req.params.userId || 0);
      if (!userId) return res.status(400).send('Geçersiz kullanıcı.');
      const target = await sqlGetAsync('SELECT id, kadi, isim, soyisim, role, resim, mezuniyetyili, email FROM uyeler WHERE id = ?', [userId]);
      if (!target) return res.status(404).send('Kullanıcı bulunamadı.');
      const summary = getModeratorPermissionSummary(userId);
      res.json({
        user: { ...target, role: getUserRole(target) },
        ...summary
      });
    } catch(err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.put('/api/admin/moderation/permissions/:userId', requireAuth, requireRole('admin'), async (req, res) => {
    try {
      const actor = req.authUser;
      const userId = Number(req.params.userId || 0);
      if (!userId) return res.status(400).send('Geçersiz kullanıcı.');
      const target = await sqlGetAsync('SELECT id, role FROM uyeler WHERE id = ?', [userId]);
      if (!target) return res.status(404).send('Kullanıcı bulunamadı.');
      if (normalizeRole(target.role) === 'root') return res.status(400).send('Root kullanıcı için moderasyon yetkisi tanımlanamaz.');

      const payload = req.body || {};
      const permissionMap = payload.permissions && typeof payload.permissions === 'object' ? payload.permissions : null;
      const permissionKeys = Array.isArray(payload.permissionKeys) ? payload.permissionKeys : null;
      const updates = new Map();

      if (permissionMap) {
        for (const [key, enabled] of Object.entries(permissionMap)) {
          const normalizedKey = String(key || '').trim();
          if (!MODERATION_PERMISSION_KEY_SET.has(normalizedKey)) continue;
          updates.set(normalizedKey, !!enabled);
        }
      }

      if (permissionKeys) {
        const normalized = new Set(permissionKeys.map((item) => String(item || '').trim()).filter((item) => MODERATION_PERMISSION_KEY_SET.has(item)));
        for (const key of MODERATION_PERMISSION_KEY_SET) {
          updates.set(key, normalized.has(key));
        }
      }

      if (!updates.size) return res.status(400).send('En az bir geçerli yetki anahtarı gerekli.');

      const now = new Date().toISOString();
      await sqlRunAsync('UPDATE uyeler SET role = ?, admin = 0 WHERE id = ?', ['mod', userId]);
      for (const [permissionKey, enabled] of updates.entries()) {
        await sqlRunAsync(
          `INSERT INTO moderator_permissions (user_id, permission_key, enabled, created_by, updated_by, created_at, updated_at)
           VALUES (?, ?, ?, ?, ?, ?, ?)
           ON CONFLICT(user_id, permission_key)
           DO UPDATE SET enabled = excluded.enabled, updated_by = excluded.updated_by, updated_at = excluded.updated_at`,
          [userId, permissionKey, toDbBooleanParam(enabled), actor.id, actor.id, now, now]
        );
      }

      writeAuditLog(req, {
        actorUserId: actor.id,
        action: 'moderator_permissions_updated',
        targetType: 'user',
        targetId: String(userId),
        metadata: { updatedCount: updates.size }
      });

      const summary = getModeratorPermissionSummary(userId);
      res.json({ ok: true, userId, ...summary });
    } catch(err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.get('/api/admin/moderation/my-permissions', requireAuth, (req, res) => {
    const user = req.authUser || getCurrentUser(req);
    if (!user) return res.status(401).send('Login required');
    const role = getUserRole(user);
    if (role === 'root' || role === 'admin') {
      return res.json({ role, isSuperModerator: true, permissionKeys: Array.from(MODERATION_PERMISSION_KEY_SET).sort((a, b) => a.localeCompare(b)) });
    }
    if (role !== 'mod') {
      return res.json({ role, isSuperModerator: false, permissionKeys: [] });
    }
    const summary = getModeratorPermissionSummary(user.id);
    res.json({ role, isSuperModerator: false, permissionKeys: summary.assignedKeys, permissionMap: summary.permissionMap });
  });

  app.post('/api/admin/login', (req, res) => {
    const user = getCurrentUser(req);
    if (!user) {
      writeLegacyLog('error', 'admin_login_denied', { reason: 'unauthenticated', ip: req.ip });
      writeAppLog('warn', 'admin_login_denied', { reason: 'unauthenticated', ip: req.ip });
      return res.status(401).send('Login required');
    }
    if (!hasAdminRole(user)) {
      writeLegacyLog('error', 'admin_login_denied', { reason: 'not_admin', userId: user.id, ip: req.ip });
      writeAppLog('warn', 'admin_login_denied', { reason: 'not_admin', userId: user.id, ip: req.ip });
      return res.status(403).send('Admin erişimi gerekli.');
    }
    const password = String(req.body?.password || '');
    if (!password) return res.status(400).send('Şifre girmedin.');
    if (!adminPassword || password !== adminPassword) {
      writeLegacyLog('error', 'admin_login_denied', { reason: 'bad_password', userId: user.id, ip: req.ip });
      writeAppLog('warn', 'admin_login_denied', { reason: 'bad_password', userId: user.id, ip: req.ip });
      return res.status(400).send('Şifre yanlış.');
    }
    req.session.adminOk = true;
    res.cookie('admingiris', 'evet');
    writeLegacyLog('member', 'admin_login_success', { userId: user.id, ip: req.ip });
    writeAppLog('info', 'admin_login_success', { userId: user.id, ip: req.ip });
    res.json({ ok: true });
  });

  app.post('/api/admin/logout', (req, res) => {
    writeLegacyLog('member', 'admin_logout', { userId: req.session?.userId || null, ip: req.ip });
    writeAppLog('info', 'admin_logout', { userId: req.session?.userId || null, ip: req.ip });
    req.session.adminOk = false;
    res.clearCookie('admingiris');
    res.json({ ok: true });
  });
}
