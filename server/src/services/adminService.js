import { HttpError } from '../shared/httpError.js';

export class AdminService {
  constructor({ adminRepository, rolePolicy }) {
    this.adminRepository = adminRepository;
    this.rolePolicy = rolePolicy;
  }

  updateUserRole({ actorRole, targetId, requestedRole }) {
    if (!targetId) {
      throw new HttpError(400, 'Geçersiz kullanıcı.');
    }

    const nextRole = this.rolePolicy.normalizeRole(requestedRole);
    const assignableRoles = actorRole === 'root' ? ['admin', 'mod', 'user'] : ['mod', 'user'];
    if (!assignableRoles.includes(nextRole)) {
      throw new HttpError(400, 'Bu rolü atama yetkiniz yok.');
    }

    const target = this.adminRepository.findUserRoleTarget(targetId);
    if (!target) {
      throw new HttpError(404, 'Kullanıcı bulunamadı.');
    }

    const targetRole = this.rolePolicy.normalizeRole(target.role);
    if (targetRole === 'root') {
      throw new HttpError(400, 'Root rolü değiştirilemez.');
    }
    if (actorRole !== 'root' && targetRole === 'admin') {
      throw new HttpError(403, 'Admin hesabın rolünü sadece root değiştirebilir.');
    }

    this.adminRepository.updateUserRole({
      userId: targetId,
      role: nextRole,
      admin: nextRole === 'admin'
    });

    return {
      userId: targetId,
      nextRole,
      previousRole: targetRole
    };
  }
}
