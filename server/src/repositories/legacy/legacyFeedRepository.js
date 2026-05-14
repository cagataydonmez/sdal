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

  async findFeedPage({ whereSql, whereParams, limit, offset, cursorId = 0, filter, viewerId, feedType = 'main', groupId = null }) {
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
    const fetchLimit = Math.max(limit * 3, limit);
    const params = cursorId > 0
      ? [viewerId, ...whereParams, cursorId, fetchLimit, offset]
      : [viewerId, ...whereParams, fetchLimit, offset];

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

    const postItems = rows.map((row) => toDomainPost({ ...row }));
    const virtualItems = await this.findVirtualEntityFeedItems({ feedType, groupId, viewerId, limit: fetchLimit });
    const merged = [...postItems, ...virtualItems]
      .sort((a, b) => {
        const ad = Date.parse(a.createdAt || '') || Number(a.id || 0);
        const bd = Date.parse(b.createdAt || '') || Number(b.id || 0);
        if (bd !== ad) return bd - ad;
        return Number(b.id || 0) - Number(a.id || 0);
      });
    return merged.slice(0, limit);
  }

  async findVirtualEntityFeedItems({ feedType, groupId, viewerId, limit }) {
    const query = typeof this.sqlAllAsync === 'function'
      ? (...args) => this.sqlAllAsync(...args)
      : (...args) => this.sqlAll(...args);
    const rows = [];
    const publicWhere = (alias, approvedColumn = true) => {
      const approvedExpr = approvedColumn
        ? `CASE WHEN LOWER(COALESCE(CAST(${alias}.approved AS TEXT), 'true')) IN ('1','true','evet','yes') THEN 'published' ELSE 'pending_publication' END`
        : "'published'";
      return `COALESCE(${alias}.publication_status, ${approvedExpr}) = 'published'
        AND COALESCE(${alias}.approval_status, 'not_required') NOT IN ('pending', 'rejected', 'changes_requested')
        AND COALESCE(${alias}.show_in_feed, 1) != 0`;
    };
    const clean = (value) => String(value || '').replace(/<[^>]+>/g, '').trim();
    const makeContent = (label, title, body, extra = '') =>
      [label ? `${label}: ${title || ''}` : title, clean(body), extra].filter(Boolean).join('\n\n');

    if (feedType === 'main') {
      const [events, announcements, jobs] = await Promise.all([
        query(
          `SELECT e.id, e.title, e.description, e.location, e.starts_at,
                  COALESCE(NULLIF(CAST(e.published_at AS TEXT), ''), e.created_at) AS created_at,
                  e.updated_at, e.created_by AS user_id,
                  e.image, u.kadi, u.isim, u.soyisim, u.resim, u.verified,
                  COALESCE(er.like_count, 0) AS like_count,
                  COALESCE(ec.comment_count, 0) AS comment_count,
                  CASE WHEN vl.entity_id IS NULL THEN 0 ELSE 1 END AS liked_by_viewer
           FROM events e
           LEFT JOIN uyeler u ON u.id = e.created_by
           LEFT JOIN (SELECT entity_id, COUNT(*) AS like_count FROM entity_reactions WHERE entity_type = 'event' GROUP BY entity_id) er ON er.entity_id = e.id
           LEFT JOIN (SELECT event_id, COUNT(*) AS comment_count FROM event_comments GROUP BY event_id) ec ON ec.event_id = e.id
           LEFT JOIN (SELECT entity_id FROM entity_reactions WHERE entity_type = 'event' AND user_id = ?) vl ON vl.entity_id = e.id
           WHERE ${publicWhere('e', true)}
           ORDER BY COALESCE(NULLIF(CAST(e.published_at AS TEXT), ''), e.created_at) DESC, e.id DESC LIMIT ?`,
          [viewerId, limit]
        ),
        query(
          `SELECT a.id, a.title, a.body,
                  COALESCE(NULLIF(CAST(a.published_at AS TEXT), ''), a.created_at) AS created_at,
                  a.updated_at, a.created_by AS user_id,
                  a.image, u.kadi, u.isim, u.soyisim, u.resim, u.verified,
                  COALESCE(er.like_count, 0) AS like_count,
                  COALESCE(ac.comment_count, 0) AS comment_count,
                  CASE WHEN vl.entity_id IS NULL THEN 0 ELSE 1 END AS liked_by_viewer
           FROM announcements a
           LEFT JOIN uyeler u ON u.id = a.created_by
           LEFT JOIN (SELECT entity_id, COUNT(*) AS like_count FROM entity_reactions WHERE entity_type = 'announcement' GROUP BY entity_id) er ON er.entity_id = a.id
           LEFT JOIN (SELECT announcement_id, COUNT(*) AS comment_count FROM announcement_comments GROUP BY announcement_id) ac ON ac.announcement_id = a.id
           LEFT JOIN (SELECT entity_id FROM entity_reactions WHERE entity_type = 'announcement' AND user_id = ?) vl ON vl.entity_id = a.id
           WHERE ${publicWhere('a', true)}
           ORDER BY COALESCE(NULLIF(CAST(a.published_at AS TEXT), ''), a.created_at) DESC, a.id DESC LIMIT ?`,
          [viewerId, limit]
        ),
        query(
          `SELECT j.id, j.title, j.company, j.description, j.location,
                  COALESCE(NULLIF(CAST(j.published_at AS TEXT), ''), j.created_at) AS created_at,
                  j.updated_at, j.poster_id AS user_id,
                  j.image, u.kadi, u.isim, u.soyisim, u.resim, u.verified,
                  COALESCE(er.like_count, 0) AS like_count,
                  0 AS comment_count,
                  CASE WHEN vl.entity_id IS NULL THEN 0 ELSE 1 END AS liked_by_viewer
           FROM jobs j
           LEFT JOIN uyeler u ON u.id = j.poster_id
           LEFT JOIN (SELECT entity_id, COUNT(*) AS like_count FROM entity_reactions WHERE entity_type = 'job' GROUP BY entity_id) er ON er.entity_id = j.id
           LEFT JOIN (SELECT entity_id FROM entity_reactions WHERE entity_type = 'job' AND user_id = ?) vl ON vl.entity_id = j.id
           WHERE ${publicWhere('j', false)}
           ORDER BY COALESCE(NULLIF(CAST(j.published_at AS TEXT), ''), j.created_at) DESC, j.id DESC LIMIT ?`,
          [viewerId, limit]
        )
      ]);
      rows.push(
        ...events.map((e) => ({ ...e, id: 1000000000 + Number(e.id), entity_id: e.id, post_type: 'event', content: makeContent('📅 Etkinlik', e.title, e.description, [e.location, e.starts_at].filter(Boolean).join(' · ')) })),
        ...announcements.map((a) => ({ ...a, id: 1100000000 + Number(a.id), entity_id: a.id, post_type: 'announcement', content: makeContent('📢 Duyuru', a.title, a.body) })),
        ...jobs.map((j) => ({ ...j, id: 1200000000 + Number(j.id), entity_id: j.id, post_type: 'job', content: makeContent('💼 İş İlanı', [j.company, j.title].filter(Boolean).join(' · '), j.description, j.location || '') }))
      );
    } else if (groupId != null) {
      const [events, announcements] = await Promise.all([
        query(
          `SELECT e.id, e.title, e.description, e.location, e.starts_at,
                  COALESCE(NULLIF(CAST(e.published_at AS TEXT), ''), e.created_at) AS created_at,
                  e.updated_at, e.created_by AS user_id,
                  e.image, u.kadi, u.isim, u.soyisim, u.resim, u.verified,
                  COALESCE(er.like_count, 0) AS like_count,
                  COALESCE(ec.comment_count, 0) AS comment_count,
                  CASE WHEN vl.entity_id IS NULL THEN 0 ELSE 1 END AS liked_by_viewer
           FROM group_events e
           LEFT JOIN uyeler u ON u.id = e.created_by
           LEFT JOIN (SELECT entity_id, COUNT(*) AS like_count FROM entity_reactions WHERE entity_type = 'group_event' GROUP BY entity_id) er ON er.entity_id = e.id
           LEFT JOIN (SELECT entity_id, COUNT(*) AS comment_count FROM entity_comments WHERE entity_type = 'group_event' GROUP BY entity_id) ec ON ec.entity_id = e.id
           LEFT JOIN (SELECT entity_id FROM entity_reactions WHERE entity_type = 'group_event' AND user_id = ?) vl ON vl.entity_id = e.id
           WHERE e.group_id = ? AND ${publicWhere('e', false)}
           ORDER BY COALESCE(NULLIF(CAST(e.published_at AS TEXT), ''), e.created_at) DESC, e.id DESC LIMIT ?`,
          [viewerId, groupId, limit]
        ),
        query(
          `SELECT a.id, a.title, a.body,
                  COALESCE(NULLIF(CAST(a.published_at AS TEXT), ''), a.created_at) AS created_at,
                  a.updated_at, a.created_by AS user_id,
                  a.image, u.kadi, u.isim, u.soyisim, u.resim, u.verified,
                  COALESCE(er.like_count, 0) AS like_count,
                  COALESCE(ec.comment_count, 0) AS comment_count,
                  CASE WHEN vl.entity_id IS NULL THEN 0 ELSE 1 END AS liked_by_viewer
           FROM group_announcements a
           LEFT JOIN uyeler u ON u.id = a.created_by
           LEFT JOIN (SELECT entity_id, COUNT(*) AS like_count FROM entity_reactions WHERE entity_type = 'group_announcement' GROUP BY entity_id) er ON er.entity_id = a.id
           LEFT JOIN (SELECT entity_id, COUNT(*) AS comment_count FROM entity_comments WHERE entity_type = 'group_announcement' GROUP BY entity_id) ec ON ec.entity_id = a.id
           LEFT JOIN (SELECT entity_id FROM entity_reactions WHERE entity_type = 'group_announcement' AND user_id = ?) vl ON vl.entity_id = a.id
           WHERE a.group_id = ? AND ${publicWhere('a', false)}
           ORDER BY COALESCE(NULLIF(CAST(a.published_at AS TEXT), ''), a.created_at) DESC, a.id DESC LIMIT ?`,
          [viewerId, groupId, limit]
        )
      ]);
      rows.push(
        ...events.map((e) => ({ ...e, group_id: groupId, id: 1300000000 + Number(e.id), entity_id: e.id, post_type: 'group_event', content: makeContent('📅 Etkinlik', e.title, e.description, [e.location, e.starts_at].filter(Boolean).join(' · ')) })),
        ...announcements.map((a) => ({ ...a, group_id: groupId, id: 1400000000 + Number(a.id), entity_id: a.id, post_type: 'group_announcement', content: makeContent('📢 Duyuru', a.title, a.body) }))
      );
    }

    return rows.map((row) => toDomainPost(row));
  }
}
