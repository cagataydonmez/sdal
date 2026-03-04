import { AdminRepository } from '../interfaces.js';

export class LegacyAdminRepository extends AdminRepository {
  constructor({ sqlGet, sqlRun }) {
    super();
    this.sqlGet = sqlGet;
    this.sqlRun = sqlRun;
  }

  findUserRoleTarget(userId) {
    return this.sqlGet('SELECT id, role, admin FROM uyeler WHERE id = ?', [userId]) || null;
  }

  updateUserRole({ userId, role, admin }) {
    this.sqlRun('UPDATE uyeler SET role = ?, admin = ? WHERE id = ?', [role, admin ? 1 : 0, userId]);
  }
}
