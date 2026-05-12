import { FeedRepository } from '../interfaces.js';
import { toDomainPost } from '../../domain/entities.js';

export class LegacyFeedRepository extends FeedRepository {
  constructor({ sqlAll, sqlAllAsync, isPostgresDb, joinUserOnPostAuthorExpr }) {
    super();
    this.sqlAll = sqlAll;
    this.sqlAllAsync = sqlAllAsync;
    this.isPostgresDb = Boolean(isPostgresDb);
    this.joinUserOnPostAuthorExpr = joinUserOnPostAuthorExpr || 'u.id = p.user_id';
  }

  async findFeedPage({ whereSql, whereParams, limit, offset, cursorId = 0, filter, viewerId }) {
    const orderBy = filter === 'popular'
      ? (
        this.isPostgresDb
          ? `(
              COALESCE(plc.like_count, 0) * 2.4
              + COALESCE(pcc.comment_count, 0) * 3.2
              + COALESCE(es.score, 0) * 0.18
            ) DESC, p.id DESC`
          : `(
              COALESCE(plc.like_count, 0) * 2.4
              + COALESCE(pcc.comment_count, 0) * 3.2
              + COALESCE(es.score, 0) * 0.18
              - COALESCE(MIN((julianday('now') - julianday(COALESCE(NULLIF(p.created_at, ''), datetime('now')))) * 24.0, 168), 0) * 0.22
            ) DESC, p.id DESC`
      )
      : 'p.id DESC';

    const whereWithCursor = cursorId > 0
      ? `${whereSql} AND p.id < ?`
      : whereSql;
    const params = cursorId > 0
      ? [viewerId, ...whereParams, cursorId, limit, offset]
      : [viewerId, ...whereParams, limit, offset];

    const esJoin = filter === 'popular'
      ? `LEFT JOIN member_engagement_scores es ON es.user_id = p.user_id`
      : '';

    const rows = this.isPostgresDb && typeof this.sqlAllAsync === 'function'
      ? await this.sqlAllAsync(
        `SELECT p.id, p.user_id, p.content, p.image, p.image_record_id, p.created_at, p.updated_at, p.group_id,
                p.post_type, p.entity_id,
                u.kadi, u.isim, u.soyisim, u.resim, u.verified,
                CASE
                  WHEN p.post_type IN ('event', 'announcement') THEN COALESCE(erc.like_count, 0)
                  ELSE COALESCE(plc.like_count, 0)
                END AS like_count,
                CASE
                  WHEN p.post_type = 'event' THEN COALESCE(ec.comment_count, 0)
                  WHEN p.post_type = 'announcement' THEN COALESCE(ac.comment_count, 0)
                  ELSE COALESCE(pcc.comment_count, 0)
                END AS comment_count,
                CASE WHEN vl.post_id IS NULL THEN 0 ELSE 1 END AS liked_by_viewer
         FROM posts p
         LEFT JOIN uyeler u ON ${this.joinUserOnPostAuthorExpr}
         ${esJoin}
         LEFT JOIN (
           SELECT post_id, COUNT(*) AS like_count
           FROM post_likes
           GROUP BY post_id
         ) plc ON plc.post_id = p.id
         LEFT JOIN (
           SELECT post_id, COUNT(*) AS comment_count
           FROM post_comments
           GROUP BY post_id
         ) pcc ON pcc.post_id = p.id
         LEFT JOIN (
           SELECT entity_type, entity_id, COUNT(*) AS like_count
           FROM entity_reactions
           GROUP BY entity_type, entity_id
         ) erc ON erc.entity_type = p.post_type AND erc.entity_id = p.entity_id
         LEFT JOIN (
           SELECT event_id, COUNT(*) AS comment_count
           FROM event_comments
           GROUP BY event_id
         ) ec ON ec.event_id = p.entity_id AND p.post_type = 'event'
         LEFT JOIN (
           SELECT announcement_id, COUNT(*) AS comment_count
           FROM announcement_comments
           GROUP BY announcement_id
         ) ac ON ac.announcement_id = p.entity_id AND p.post_type = 'announcement'
         LEFT JOIN (
           SELECT DISTINCT post_id
           FROM post_likes
           WHERE user_id = ?
         ) vl ON vl.post_id = p.id
         ${whereWithCursor}
         ORDER BY ${orderBy}
         LIMIT ? OFFSET ?`,
        params
      )
      : this.sqlAll(
      `SELECT p.id, p.user_id, p.content, p.image, p.image_record_id, p.created_at, p.updated_at, p.group_id,
              p.post_type, p.entity_id,
              u.kadi, u.isim, u.soyisim, u.resim, u.verified,
              CASE
                WHEN p.post_type IN ('event', 'announcement') THEN COALESCE(erc.like_count, 0)
                ELSE COALESCE(plc.like_count, 0)
              END AS like_count,
              CASE
                WHEN p.post_type = 'event' THEN COALESCE(ec.comment_count, 0)
                WHEN p.post_type = 'announcement' THEN COALESCE(ac.comment_count, 0)
                ELSE COALESCE(pcc.comment_count, 0)
              END AS comment_count,
              CASE WHEN vl.post_id IS NULL THEN 0 ELSE 1 END AS liked_by_viewer
       FROM posts p
       LEFT JOIN uyeler u ON ${this.joinUserOnPostAuthorExpr}
       ${esJoin}
       LEFT JOIN (
         SELECT post_id, COUNT(*) AS like_count
         FROM post_likes
         GROUP BY post_id
       ) plc ON plc.post_id = p.id
       LEFT JOIN (
         SELECT post_id, COUNT(*) AS comment_count
         FROM post_comments
         GROUP BY post_id
       ) pcc ON pcc.post_id = p.id
       LEFT JOIN (
         SELECT entity_type, entity_id, COUNT(*) AS like_count
         FROM entity_reactions
         GROUP BY entity_type, entity_id
       ) erc ON erc.entity_type = p.post_type AND erc.entity_id = p.entity_id
       LEFT JOIN (
         SELECT event_id, COUNT(*) AS comment_count
         FROM event_comments
         GROUP BY event_id
       ) ec ON ec.event_id = p.entity_id AND p.post_type = 'event'
       LEFT JOIN (
         SELECT announcement_id, COUNT(*) AS comment_count
         FROM announcement_comments
         GROUP BY announcement_id
       ) ac ON ac.announcement_id = p.entity_id AND p.post_type = 'announcement'
       LEFT JOIN (
         SELECT DISTINCT post_id
         FROM post_likes
         WHERE user_id = ?
       ) vl ON vl.post_id = p.id
       ${whereWithCursor}
       ORDER BY ${orderBy}
       LIMIT ? OFFSET ?`,
      params
    );

    return rows.map((row) => toDomainPost({
      ...row
    }));
  }
}
