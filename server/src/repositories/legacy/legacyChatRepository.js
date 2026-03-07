import { MessageRepository } from '../interfaces.js';
import { toDomainMessage } from '../../domain/entities.js';

export class LegacyChatRepository extends MessageRepository {
  constructor({ sqlGet, sqlAll, sqlRun, sqlGetAsync, sqlAllAsync, sqlRunAsync, isPostgresDb }) {
    super();
    this.sqlGet = sqlGet;
    this.sqlAll = sqlAll;
    this.sqlRun = sqlRun;
    this.sqlGetAsync = sqlGetAsync;
    this.sqlAllAsync = sqlAllAsync;
    this.sqlRunAsync = sqlRunAsync;
    this.isPostgresDb = Boolean(isPostgresDb);
  }

  async queryGet(query, params = []) {
    if (this.isPostgresDb && typeof this.sqlGetAsync === 'function') return this.sqlGetAsync(query, params);
    return this.sqlGet(query, params);
  }

  async queryAll(query, params = []) {
    if (this.isPostgresDb && typeof this.sqlAllAsync === 'function') return this.sqlAllAsync(query, params);
    return this.sqlAll(query, params);
  }

  async queryRun(query, params = []) {
    if (this.isPostgresDb && typeof this.sqlRunAsync === 'function') return this.sqlRunAsync(query, params);
    return this.sqlRun(query, params);
  }

  async listMessages({ sinceId = 0, beforeId = 0, limit = 40 }) {
    let where = 'WHERE 1=1';
    const params = [];

    if (sinceId > 0) {
      where += ' AND c.id > ?';
      params.push(sinceId);
    }
    if (beforeId > 0) {
      where += ' AND c.id < ?';
      params.push(beforeId);
    }

    const rows = await this.queryAll(
      `SELECT c.id, c.user_id, c.message, c.created_at,
              u.kadi, u.isim, u.soyisim, u.resim, u.verified
       FROM chat_messages c
       LEFT JOIN uyeler u ON u.id = c.user_id
       ${where}
       ORDER BY c.id DESC
       LIMIT ?`,
      [...params, limit]
    );

    return rows.reverse().map((row) => toDomainMessage(row));
  }

  async findMessageById(messageId) {
    const row = await this.queryGet(
      `SELECT c.id, c.user_id, c.message, c.created_at,
              u.kadi, u.isim, u.soyisim, u.resim, u.verified
       FROM chat_messages c
       LEFT JOIN uyeler u ON u.id = c.user_id
       WHERE c.id = ?`,
      [messageId]
    );
    return toDomainMessage(row);
  }

  async createMessage({ userId, body, createdAt }) {
    const result = await this.queryRun(
      'INSERT INTO chat_messages (user_id, message, created_at) VALUES (?, ?, ?)',
      [userId, body, createdAt]
    );
    return this.findMessageById(Number(result?.lastInsertRowid || 0));
  }

  async updateMessage(messageId, body) {
    await this.queryRun('UPDATE chat_messages SET message = ? WHERE id = ?', [body, messageId]);
    return this.findMessageById(messageId);
  }

  async deleteMessage(messageId) {
    await this.queryRun('DELETE FROM chat_messages WHERE id = ?', [messageId]);
  }
}
