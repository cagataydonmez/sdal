import { UserRepository } from '../interfaces.js';
import { toDomainUser } from '../../domain/entities.js';

export class LegacyUserRepository extends UserRepository {
  constructor({ sqlGet, sqlRun, sqlGetAsync, sqlRunAsync, isPostgresDb }) {
    super();
    this.sqlGet = sqlGet;
    this.sqlRun = sqlRun;
    this.sqlGetAsync = sqlGetAsync;
    this.sqlRunAsync = sqlRunAsync;
    this.isPostgresDb = Boolean(isPostgresDb);
    this.usersTable = null;
  }

  async queryGet(query, params = []) {
    if (this.isPostgresDb && typeof this.sqlGetAsync === 'function') return this.sqlGetAsync(query, params);
    return this.sqlGet(query, params);
  }

  async queryRun(query, params = []) {
    if (this.isPostgresDb && typeof this.sqlRunAsync === 'function') return this.sqlRunAsync(query, params);
    return this.sqlRun(query, params);
  }

  async resolveUsersTable() {
    if (this.usersTable) return this.usersTable;
    try {
      await this.queryGet('SELECT id FROM users LIMIT 1');
      this.usersTable = 'users';
      return this.usersTable;
    } catch {
      this.usersTable = 'uyeler';
      return this.usersTable;
    }
  }

  async selectUserBy(whereClause, params = []) {
    const usersTable = await this.resolveUsersTable();
    if (usersTable === 'uyeler') {
      return this.queryGet(`SELECT * FROM uyeler WHERE ${whereClause}`, params);
    }
    return this.queryGet(
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

  async findById(id) {
    const row = await this.selectUserBy('id = ?', [id]);
    return toDomainUser(row);
  }

  async findByUsername(username) {
    const usersTable = await this.resolveUsersTable();
    const row = usersTable === 'uyeler'
      ? await this.selectUserBy('kadi = ?', [username])
      : await this.selectUserBy('lower(username) = lower(?)', [username]);
    return toDomainUser(row);
  }

  async updatePasswordHash(id, passwordHash) {
    const usersTable = await this.resolveUsersTable();
    if (usersTable === 'uyeler') {
      await this.queryRun('UPDATE uyeler SET sifre = ? WHERE id = ?', [passwordHash, id]);
      return;
    }
    await this.queryRun('UPDATE users SET password_hash = ? WHERE id = ?', [passwordHash, id]);
  }

  async setOnlineStatus(id, online) {
    const usersTable = await this.resolveUsersTable();
    if (usersTable === 'uyeler') {
      await this.queryRun('UPDATE uyeler SET online = ? WHERE id = ?', [online ? 1 : 0, id]);
      return;
    }
    await this.queryRun('UPDATE users SET is_online = ? WHERE id = ?', [online ? true : false, id]);
  }

  async findGraduationYearById(id) {
    const usersTable = await this.resolveUsersTable();
    const row = usersTable === 'uyeler'
      ? await this.queryGet('SELECT mezuniyetyili FROM uyeler WHERE id = ?', [id])
      : await this.queryGet('SELECT graduation_year AS mezuniyetyili FROM users WHERE id = ?', [id]);
    return row?.mezuniyetyili ? Number(row.mezuniyetyili) || null : null;
  }
}
