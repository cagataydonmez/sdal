import { UserRepository } from '../interfaces.js';
import { toDomainUser } from '../../domain/entities.js';

export class LegacyUserRepository extends UserRepository {
  constructor({ sqlGet, sqlRun }) {
    super();
    this.sqlGet = sqlGet;
    this.sqlRun = sqlRun;
    this.usersTable = null;
  }

  resolveUsersTable() {
    if (this.usersTable) return this.usersTable;
    try {
      this.sqlGet('SELECT id FROM uyeler LIMIT 1');
      this.usersTable = 'uyeler';
      return this.usersTable;
    } catch {
      this.usersTable = 'users';
      return this.usersTable;
    }
  }

  selectUserBy(whereClause, params = []) {
    const usersTable = this.resolveUsersTable();
    if (usersTable === 'uyeler') {
      return this.sqlGet(`SELECT * FROM uyeler WHERE ${whereClause}`, params);
    }
    return this.sqlGet(
      `SELECT
         id,
         username AS kadi,
         password_hash AS sifre,
         email,
         first_name AS isim,
         last_name AS soyisim,
         COALESCE(avatar_path, 'yok') AS resim,
         graduation_year AS mezuniyetyili,
         CASE WHEN COALESCE(is_active, true) THEN 1 ELSE 0 END AS aktiv,
         CASE WHEN COALESCE(is_banned, false) THEN 1 ELSE 0 END AS yasak,
         CASE WHEN COALESCE(is_profile_initialized, true) THEN 1 ELSE 0 END AS ilkbd,
         CASE WHEN COALESCE(legacy_admin_flag, false) THEN 1 ELSE 0 END AS admin,
         CASE WHEN COALESCE(is_verified, false) THEN 1 ELSE 0 END AS verified,
         role,
         oauth_provider,
         oauth_subject,
         CASE WHEN COALESCE(oauth_email_verified, false) THEN 1 ELSE 0 END AS oauth_email_verified
       FROM users
       WHERE ${whereClause}`,
      params
    );
  }

  findById(id) {
    const row = this.selectUserBy('id = ?', [id]);
    return toDomainUser(row);
  }

  findByUsername(username) {
    const usersTable = this.resolveUsersTable();
    const row = usersTable === 'uyeler'
      ? this.selectUserBy('kadi = ?', [username])
      : this.selectUserBy('lower(username) = lower(?)', [username]);
    return toDomainUser(row);
  }

  updatePasswordHash(id, passwordHash) {
    const usersTable = this.resolveUsersTable();
    if (usersTable === 'uyeler') {
      this.sqlRun('UPDATE uyeler SET sifre = ? WHERE id = ?', [passwordHash, id]);
      return;
    }
    this.sqlRun('UPDATE users SET password_hash = ? WHERE id = ?', [passwordHash, id]);
  }

  setOnlineStatus(id, online) {
    const usersTable = this.resolveUsersTable();
    if (usersTable === 'uyeler') {
      this.sqlRun('UPDATE uyeler SET online = ? WHERE id = ?', [online ? 1 : 0, id]);
      return;
    }
    this.sqlRun('UPDATE users SET is_online = ? WHERE id = ?', [online ? true : false, id]);
  }

  findGraduationYearById(id) {
    const usersTable = this.resolveUsersTable();
    const row = usersTable === 'uyeler'
      ? this.sqlGet('SELECT mezuniyetyili FROM uyeler WHERE id = ?', [id])
      : this.sqlGet('SELECT graduation_year AS mezuniyetyili FROM users WHERE id = ?', [id]);
    return row?.mezuniyetyili ? Number(row.mezuniyetyili) || null : null;
  }
}
