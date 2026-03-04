import { MessageRepository } from '../interfaces.js';
import { toDomainMessage } from '../../domain/entities.js';

export class LegacyChatRepository extends MessageRepository {
  constructor({ sqlGet, sqlAll, sqlRun }) {
    super();
    this.sqlGet = sqlGet;
    this.sqlAll = sqlAll;
    this.sqlRun = sqlRun;
  }

  listMessages({ sinceId = 0, beforeId = 0, limit = 40 }) {
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

    const rows = this.sqlAll(
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

  findMessageById(messageId) {
    const row = this.sqlGet(
      `SELECT c.id, c.user_id, c.message, c.created_at,
              u.kadi, u.isim, u.soyisim, u.resim, u.verified
       FROM chat_messages c
       LEFT JOIN uyeler u ON u.id = c.user_id
       WHERE c.id = ?`,
      [messageId]
    );
    return toDomainMessage(row);
  }

  createMessage({ userId, body, createdAt }) {
    const result = this.sqlRun(
      'INSERT INTO chat_messages (user_id, message, created_at) VALUES (?, ?, ?)',
      [userId, body, createdAt]
    );
    return this.findMessageById(Number(result?.lastInsertRowid || 0));
  }

  updateMessage(messageId, body) {
    this.sqlRun('UPDATE chat_messages SET message = ? WHERE id = ?', [body, messageId]);
    return this.findMessageById(messageId);
  }

  deleteMessage(messageId) {
    this.sqlRun('DELETE FROM chat_messages WHERE id = ?', [messageId]);
  }
}
