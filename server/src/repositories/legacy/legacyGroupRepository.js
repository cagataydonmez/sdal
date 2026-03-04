import { GroupRepository } from '../interfaces.js';

export class LegacyGroupRepository extends GroupRepository {
  constructor({ sqlGet }) {
    super();
    this.sqlGet = sqlGet;
  }

  findById(groupId) {
    return this.sqlGet('SELECT * FROM groups WHERE id = ?', [groupId]) || null;
  }

  findByName(name) {
    return this.sqlGet('SELECT * FROM groups WHERE name = ?', [name]) || null;
  }

  findMember(groupId, userId) {
    return this.sqlGet(
      'SELECT * FROM group_members WHERE group_id = ? AND user_id = ?',
      [groupId, userId]
    ) || null;
  }
}
