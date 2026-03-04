import { UserRepository } from '../interfaces.js';
import { toDomainUser } from '../../domain/entities.js';

export class LegacyUserRepository extends UserRepository {
  constructor({ sqlGet, sqlRun }) {
    super();
    this.sqlGet = sqlGet;
    this.sqlRun = sqlRun;
  }

  findById(id) {
    const row = this.sqlGet('SELECT * FROM uyeler WHERE id = ?', [id]);
    return toDomainUser(row);
  }

  findByUsername(username) {
    const row = this.sqlGet('SELECT * FROM uyeler WHERE kadi = ?', [username]);
    return toDomainUser(row);
  }

  updatePasswordHash(id, passwordHash) {
    this.sqlRun('UPDATE uyeler SET sifre = ? WHERE id = ?', [passwordHash, id]);
  }

  setOnlineStatus(id, online) {
    this.sqlRun('UPDATE uyeler SET online = ? WHERE id = ?', [online ? 1 : 0, id]);
  }

  findGraduationYearById(id) {
    const row = this.sqlGet('SELECT mezuniyetyili FROM uyeler WHERE id = ?', [id]);
    return row?.mezuniyetyili ? Number(row.mezuniyetyili) || null : null;
  }
}
