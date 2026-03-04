import { PostRepository } from '../interfaces.js';
import { toDomainComment, toDomainPost } from '../../domain/entities.js';

export class LegacyPostRepository extends PostRepository {
  constructor({ sqlGet, sqlAll, sqlRun }) {
    super();
    this.sqlGet = sqlGet;
    this.sqlAll = sqlAll;
    this.sqlRun = sqlRun;
  }

  createPost({ authorId, content, imageUrl, groupId, createdAt }) {
    const result = this.sqlRun(
      'INSERT INTO posts (user_id, content, image, created_at, group_id) VALUES (?, ?, ?, ?, ?)',
      [authorId, content, imageUrl, createdAt, groupId]
    );
    const postId = Number(result?.lastInsertRowid || 0);
    return this.findById(postId);
  }

  findById(postId) {
    const row = this.sqlGet('SELECT * FROM posts WHERE id = ?', [postId]);
    return toDomainPost(row);
  }

  listComments(postId) {
    const rows = this.sqlAll(
      `SELECT c.id, c.post_id, c.user_id, c.comment, c.created_at,
              u.kadi, u.isim, u.soyisim, u.resim, u.verified
       FROM post_comments c
       LEFT JOIN uyeler u ON u.id = c.user_id
       WHERE c.post_id = ?
       ORDER BY c.id DESC`,
      [postId]
    );
    return rows.map((row) => toDomainComment(row));
  }

  createComment({ postId, authorId, body, createdAt }) {
    const result = this.sqlRun(
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

  findLike(postId, userId) {
    return this.sqlGet('SELECT id FROM post_likes WHERE post_id = ? AND user_id = ?', [postId, userId]) || null;
  }

  deleteLikeById(likeId) {
    this.sqlRun('DELETE FROM post_likes WHERE id = ?', [likeId]);
  }

  createLike({ postId, userId, createdAt }) {
    this.sqlRun(
      'INSERT INTO post_likes (post_id, user_id, created_at) VALUES (?, ?, ?)',
      [postId, userId, createdAt]
    );
  }
}
