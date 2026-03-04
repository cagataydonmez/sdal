import { FeedRepository } from '../interfaces.js';
import { toDomainPost } from '../../domain/entities.js';

export class LegacyFeedRepository extends FeedRepository {
  constructor({ sqlAll, isPostgresDb, joinUserOnPostAuthorExpr }) {
    super();
    this.sqlAll = sqlAll;
    this.isPostgresDb = Boolean(isPostgresDb);
    this.joinUserOnPostAuthorExpr = joinUserOnPostAuthorExpr || 'u.id = p.user_id';
  }

  findFeedPage({ whereSql, whereParams, limit, offset, filter, viewerId }) {
    const orderBy = filter === 'popular'
      ? (
        this.isPostgresDb
          ? `(
              COALESCE((SELECT COUNT(*) FROM post_likes pl WHERE pl.post_id = p.id), 0) * 2.4
              + COALESCE((SELECT COUNT(*) FROM post_comments pc WHERE pc.post_id = p.id), 0) * 3.2
              + COALESCE(es.score, 0) * 0.18
            ) DESC, p.id DESC`
          : `(
              COALESCE((SELECT COUNT(*) FROM post_likes pl WHERE pl.post_id = p.id), 0) * 2.4
              + COALESCE((SELECT COUNT(*) FROM post_comments pc WHERE pc.post_id = p.id), 0) * 3.2
              + COALESCE(es.score, 0) * 0.18
              - COALESCE(MIN((julianday('now') - julianday(COALESCE(NULLIF(p.created_at, ''), datetime('now')))) * 24.0, 168), 0) * 0.22
            ) DESC, p.id DESC`
      )
      : 'p.id DESC';

    const rows = this.sqlAll(
      `SELECT p.id, p.user_id, p.content, p.image, p.image_record_id, p.created_at, p.group_id,
              u.kadi, u.isim, u.soyisim, u.resim, u.verified
       FROM posts p
       LEFT JOIN uyeler u ON ${this.joinUserOnPostAuthorExpr}
       LEFT JOIN member_engagement_scores es ON es.user_id = p.user_id
       ${whereSql}
       ORDER BY ${orderBy}
       LIMIT ? OFFSET ?`,
      [...whereParams, limit, offset]
    );

    const postIds = rows.map((row) => row.id);
    const likes = postIds.length
      ? this.sqlAll(
        `SELECT post_id, COUNT(*) as cnt
         FROM post_likes
         WHERE post_id IN (${postIds.map(() => '?').join(',')})
         GROUP BY post_id`,
        postIds
      )
      : [];

    const comments = postIds.length
      ? this.sqlAll(
        `SELECT post_id, COUNT(*) as cnt
         FROM post_comments
         WHERE post_id IN (${postIds.map(() => '?').join(',')})
         GROUP BY post_id`,
        postIds
      )
      : [];

    const liked = postIds.length
      ? this.sqlAll(
        `SELECT post_id
         FROM post_likes
         WHERE user_id = ? AND post_id IN (${postIds.map(() => '?').join(',')})`,
        [viewerId, ...postIds]
      )
      : [];

    const likeMap = new Map(likes.map((row) => [Number(row.post_id), Number(row.cnt || 0)]));
    const commentMap = new Map(comments.map((row) => [Number(row.post_id), Number(row.cnt || 0)]));
    const likedSet = new Set(liked.map((row) => Number(row.post_id)));

    return rows.map((row) => toDomainPost({
      ...row,
      like_count: likeMap.get(Number(row.id)) || 0,
      comment_count: commentMap.get(Number(row.id)) || 0,
      liked_by_viewer: likedSet.has(Number(row.id)) ? 1 : 0
    }));
  }
}
