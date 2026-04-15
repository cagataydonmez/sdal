import { PostRepository } from '../interfaces.js';
import { toDomainComment, toDomainPost } from '../../domain/entities.js';

export class LegacyPostRepository extends PostRepository {
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

  async createPost({ authorId, content, imageUrl, groupId, createdAt }) {
    const result = await this.queryRun(
      'INSERT INTO posts (user_id, content, image, created_at, group_id) VALUES (?, ?, ?, ?, ?)',
      [authorId, content, imageUrl, createdAt, groupId]
    );
    const postId = Number(result?.lastInsertRowid || 0);
    return this.findById(postId);
  }

  async findById(postId) {
    const row = await this.queryGet('SELECT * FROM posts WHERE id = ?', [postId]);
    return toDomainPost(row);
  }

  async listComments({ postId, limit = 50, beforeId = 0 }) {
    const whereParts = ['c.post_id = ?'];
    const params = [postId];
    if (beforeId > 0) {
      whereParts.push('c.id < ?');
      params.push(beforeId);
    }

    const safeLimit = Math.min(Math.max(parseInt(limit, 10) || 50, 1), 100);
    const rows = await this.queryAll(
      `SELECT c.id, c.post_id, c.user_id, c.comment, c.created_at, c.updated_at,
              u.kadi, u.isim, u.soyisim, u.resim, u.verified
       FROM post_comments c
       LEFT JOIN uyeler u ON u.id = c.user_id
       WHERE ${whereParts.join(' AND ')}
       ORDER BY c.id DESC
       LIMIT ?`,
      [...params, safeLimit + 1]
    );
    const pageRows = rows.slice(0, safeLimit);
    return {
      items: pageRows.map((row) => toDomainComment(row)),
      hasMore: rows.length > safeLimit,
      nextCursor: rows.length > safeLimit ? Number(pageRows[pageRows.length - 1]?.id || 0) : 0
    };
  }

  async createComment({ postId, authorId, body, createdAt }) {
    const result = await this.queryRun(
      'INSERT INTO post_comments (post_id, user_id, comment, created_at) VALUES (?, ?, ?, ?)',
      [postId, authorId, body, createdAt]
    );
    return {
      id: Number(result?.lastInsertRowid || 0),
      postId: Number(postId),
      authorId: Number(authorId),
      body,
      createdAt
    };
  }

  async findCommentById(commentId) {
    const row = await this.queryGet(
      `SELECT c.id, c.post_id, c.user_id, c.comment, c.created_at, c.updated_at,
              u.kadi, u.isim, u.soyisim, u.resim, u.verified
       FROM post_comments c
       LEFT JOIN uyeler u ON u.id = c.user_id
       WHERE c.id = ?`,
      [commentId]
    );
    return toDomainComment(row);
  }

  async deleteCommentById(commentId) {
    await this.queryRun('DELETE FROM post_comments WHERE id = ?', [commentId]);
  }

  async findLike(postId, userId) {
    return await this.queryGet('SELECT id FROM post_likes WHERE post_id = ? AND user_id = ?', [postId, userId]) || null;
  }

  async deleteLikeById(likeId) {
    await this.queryRun('DELETE FROM post_likes WHERE id = ?', [likeId]);
  }

  async createLike({ postId, userId, createdAt }) {
    await this.queryRun(
      'INSERT INTO post_likes (post_id, user_id, created_at) VALUES (?, ?, ?)',
      [postId, userId, createdAt]
    );
  }

  async updateCommentById(commentId, body, updatedAt) {
    await this.queryRun(
      'UPDATE post_comments SET comment = ?, updated_at = ? WHERE id = ?',
      [body, updatedAt, commentId]
    );
    return this.findCommentById(commentId);
  }

  async listLikes(postId) {
    const rows = await this.queryAll(
      `SELECT u.id, u.kadi, u.isim, u.soyisim, u.resim, u.mezuniyetyili
       FROM post_likes pl
       JOIN uyeler u ON u.id = pl.user_id
       WHERE pl.post_id = ?
       ORDER BY pl.created_at DESC
       LIMIT 100`,
      [postId]
    );
    return rows.map((r) => ({
      id: Number(r.id),
      username: String(r.kadi || ''),
      firstName: String(r.isim || ''),
      lastName: String(r.soyisim || ''),
      avatarUrl: r.resim || null,
      graduationYear: r.mezuniyetyili ? String(r.mezuniyetyili) : null
    }));
  }
}
