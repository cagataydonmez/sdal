import { isHttpError } from '../../shared/httpError.js';

export function createAdminController({
  adminService,
  rolePolicy,
  replaceModeratorPermissions,
  moderationPermissionKeys,
  writeAuditLog
}) {
  function updateUserRole(req, res) {
    try {
      const actorRole = rolePolicy.getUserRole(req.authUser);
      const targetId = Number(req.params.id || 0);
      const result = adminService.updateUserRole({
        actorRole,
        targetId,
        requestedRole: req.body?.role
      });

      if (result.nextRole === 'admin') {
        replaceModeratorPermissions(result.userId, Array.from(moderationPermissionKeys), req.authUser.id);
      } else if (result.nextRole === 'mod') {
        const previousRoleWasAdmin = rolePolicy.roleAtLeast(result.previousRole, 'admin');
        if (previousRoleWasAdmin) {
          replaceModeratorPermissions(result.userId, [], req.authUser.id);
        }
      } else {
        replaceModeratorPermissions(result.userId, [], req.authUser.id);
      }

      writeAuditLog(req, {
        actorUserId: req.authUser.id,
        action: 'role_changed',
        targetType: 'user',
        targetId: String(result.userId),
        metadata: { previousRole: result.previousRole, nextRole: result.nextRole }
      });

      return res.json({ ok: true, userId: result.userId, role: result.nextRole });
    } catch (err) {
      if (isHttpError(err)) return res.status(err.statusCode).send(err.message);
      console.error('admin.updateUserRole failed:', err);
      return res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  }

  return { updateUserRole };
}
