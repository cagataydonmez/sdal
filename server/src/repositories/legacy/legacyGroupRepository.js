import { GroupRepository } from '../interfaces.js';

export class LegacyGroupRepository extends GroupRepository {
  constructor({ sqlGet, sqlGetAsync, isPostgresDb }) {
    super();
    this.sqlGet = sqlGet;
    this.sqlGetAsync = sqlGetAsync;
    this.isPostgresDb = Boolean(isPostgresDb);
  }

  async queryGet(query, params = []) {
    if (this.isPostgresDb && typeof this.sqlGetAsync === 'function') return this.sqlGetAsync(query, params);
    return this.sqlGet(query, params);
  }

  async findById(groupId) {
    return await this.queryGet('SELECT * FROM groups WHERE id = ?', [groupId]) || null;
  }

  async findByName(name) {
    return await this.queryGet('SELECT * FROM groups WHERE name = ?', [name]) || null;
  }

  async findMember(groupId, userId) {
    return await this.queryGet(
      'SELECT * FROM group_members WHERE group_id = ? AND user_id = ?',
      [groupId, userId]
    ) || null;
  }
}
