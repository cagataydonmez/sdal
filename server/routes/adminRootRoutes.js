import { FACTORY_RESET_CONFIRMATION } from '../src/admin/factoryResetService.js';

function asyncRoute(handler) {
  return (req, res, next) => Promise.resolve(handler(req, res, next)).catch(next);
}

function statusForError(err) {
  const status = Number(err?.statusCode || err?.status || 500);
  return status >= 400 && status < 600 ? status : 500;
}

export function registerAdminRootRoutes(app, {
  requireAuth,
  requireRootAdmin,
  rbacService,
  factoryResetService,
  factoryResetRateLimit,
  verifyPassword,
  writeAppLog,
  logAdminAction
}) {
  const rootOnly = [requireAuth, requireRootAdmin];

  app.post('/api/admin/factory-reset', factoryResetRateLimit, ...rootOnly, asyncRoute(async (req, res) => {
    const confirmation = String(req.body?.confirmation || '').trim();
    if (confirmation !== FACTORY_RESET_CONFIRMATION) {
      return res.status(400).json({
        error: 'INVALID_CONFIRMATION',
        message: `Type ${FACTORY_RESET_CONFIRMATION} to confirm.`
      });
    }

    const password = String(req.body?.password || '');
    if (!password) {
      return res.status(400).json({
        error: 'PASSWORD_REQUIRED',
        message: 'Current root admin password is required.'
      });
    }
    const passwordOk = await factoryResetService.verifyCurrentPassword(req.authUser, password, verifyPassword);
    if (!passwordOk) {
      writeAppLog('warn', 'factory_reset_password_denied', {
        userId: req.authUser?.id || null,
        ip: req.ip
      });
      return res.status(403).json({ error: 'BAD_PASSWORD', message: 'Password confirmation failed.' });
    }

    const dryRun = req.body?.dryRun === true || req.body?.dry_run === true;
    const result = await factoryResetService.performFactoryReset({
      actor: req.authUser,
      ip: req.ip,
      userAgent: String(req.headers['user-agent'] || '').slice(0, 500),
      dryRun
    });

    if (!dryRun) req.session.destroy(() => {});

    return res.json({
      ok: true,
      ...result,
      confirmationRequired: FACTORY_RESET_CONFIRMATION
    });
  }));

  app.get('/api/admin/permissions', ...rootOnly, asyncRoute(async (_req, res) => {
    await rbacService.seedDefaults();
    res.json({ permissions: await rbacService.listPermissions() });
  }));

  app.get('/api/admin/permission-groups', ...rootOnly, asyncRoute(async (_req, res) => {
    await rbacService.seedDefaults();
    res.json({ groups: await rbacService.listGroups() });
  }));

  app.post('/api/admin/permission-groups', ...rootOnly, asyncRoute(async (req, res) => {
    try {
      await rbacService.seedDefaults();
      await rbacService.createGroup({
        name: req.body?.name,
        description: req.body?.description,
        permissions: req.body?.permissions
      });
      logAdminAction(req, 'permission_group_created', { name: req.body?.name });
      res.status(201).json({ ok: true, groups: await rbacService.listGroups() });
    } catch (err) {
      res.status(statusForError(err)).json({ error: 'PERMISSION_GROUP_CREATE_FAILED', message: err?.message || 'Failed to create permission group.' });
    }
  }));

  app.put('/api/admin/permission-groups/:id', ...rootOnly, asyncRoute(async (req, res) => {
    try {
      await rbacService.updateGroup(Number(req.params.id), {
        name: req.body?.name,
        description: req.body?.description,
        permissions: req.body?.permissions
      });
      logAdminAction(req, 'permission_group_updated', { targetType: 'permission_group', targetId: req.params.id });
      res.json({ ok: true, groups: await rbacService.listGroups() });
    } catch (err) {
      res.status(statusForError(err)).json({ error: 'PERMISSION_GROUP_UPDATE_FAILED', message: err?.message || 'Failed to update permission group.' });
    }
  }));

  app.delete('/api/admin/permission-groups/:id', ...rootOnly, asyncRoute(async (req, res) => {
    try {
      await rbacService.deleteGroup(Number(req.params.id));
      logAdminAction(req, 'permission_group_deleted', { targetType: 'permission_group', targetId: req.params.id });
      res.json({ ok: true, groups: await rbacService.listGroups() });
    } catch (err) {
      res.status(statusForError(err)).json({ error: 'PERMISSION_GROUP_DELETE_FAILED', message: err?.message || 'Failed to delete permission group.' });
    }
  }));

  app.get('/api/admin/users/permissions', ...rootOnly, asyncRoute(async (req, res) => {
    await rbacService.seedDefaults();
    res.json(await rbacService.listUsersWithGroups({
      q: req.query?.q,
      page: req.query?.page,
      limit: req.query?.limit
    }));
  }));

  app.put('/api/admin/users/:id/permission-group', ...rootOnly, asyncRoute(async (req, res) => {
    try {
      await rbacService.assignUserGroup({
        userId: Number(req.params.id),
        groupId: Number(req.body?.groupId || req.body?.group_id || 0),
        assignedBy: req.authUser?.id || null
      });
      logAdminAction(req, 'user_permission_group_updated', {
        targetType: 'user',
        targetId: req.params.id,
        groupId: Number(req.body?.groupId || req.body?.group_id || 0)
      });
      res.json({ ok: true });
    } catch (err) {
      res.status(statusForError(err)).json({ error: 'USER_PERMISSION_GROUP_UPDATE_FAILED', message: err?.message || 'Failed to update user permission group.' });
    }
  }));
}
