import fs from 'fs';
import path from 'path';
import { SpacesStorageProvider, getStorageProvider } from '../media/storageProvider.js';

export function registerAdminOperationsRoutes(app, deps) {
  const {
    dbDriver,
    sqlGet,
    sqlAll,
    sqlRun,
    sqlGetAsync,
    sqlAllAsync,
    sqlRunAsync,
    uploadsDir,
    appLogsDir,
    appLogFile,
    hatalogDir,
    sayfalogDir,
    uyedetaylogDir,
    cacheNamespaces,
    ADMIN_SETTINGS_CACHE_TTL_SECONDS,
    requireAdmin,
    requireAuth,
    requireAlbumAdmin,
    uploadRateLimit,
    imageUpload,
    getCurrentUser,
    getUserRole,
    normalizeRole,
    hasValidGraduationYear,
    normalizeCohortValue,
    MIN_GRADUATION_YEAR,
    MAX_GRADUATION_YEAR,
    buildVersionedCacheKey,
    getCacheJson,
    setCacheJson,
    getSiteControl,
    getModuleControlMap,
    normalizeModuleMenuVisibility,
    normalizeModuleMenuOrder,
    invalidateControlSnapshots,
    invalidateCacheNamespace,
    MODULE_DEFINITIONS,
    writeAppLog,
    processUpload,
    enforceUploadQuota,
    hardDeleteUser,
    logAdminAction,
    normalizeEmail,
    validateEmail,
    queueEmailDelivery,
    extractEmails,
    parseDateInput,
    readLogFile,
    filterLogContent,
    listLogFiles,
    sanitizePlainUserText,
    formatUserText,
    scheduleEngagementRecalculation,
    applyUserGraduationYearChange,
    authSecurity
  } = deps;

  const albumActivePredicate = dbDriver === 'postgres' ? 'aktif IS TRUE' : 'aktif = 1';
  const albumInactivePredicate = dbDriver === 'postgres' ? 'aktif IS FALSE' : 'aktif = 0';
  const albumActiveParam = (value) => (dbDriver === 'postgres' ? !!value : (value ? 1 : 0));

  async function queryAdminUsers(rawQuery = {}) {
    const filter = String(rawQuery.filter || 'all').trim();
    const q = String(rawQuery.q || '').trim();
    const withPhoto = String(rawQuery.photo || rawQuery.res || '').trim() === '1';
    const verifiedOnly = String(rawQuery.verified || '').trim() === '1';
    const onlineOnly = String(rawQuery.online || '').trim() === '1';
    const adminOnly = String(rawQuery.admin || '').trim() === '1';
    const userId = Number(rawQuery.userId || rawQuery.user_id || 0);
    const cohort = String(rawQuery.cohort || rawQuery.graduationYear || '').trim();
    const minScoreRaw = String(rawQuery.minScore ?? rawQuery.min_score ?? '').trim();
    const maxScoreRaw = String(rawQuery.maxScore ?? rawQuery.max_score ?? '').trim();
    const minScore = minScoreRaw === '' ? NaN : Number(minScoreRaw);
    const maxScore = maxScoreRaw === '' ? NaN : Number(maxScoreRaw);
    const limit = Math.min(Math.max(parseInt(rawQuery.limit || '20', 10), 1), 100);
    const page = Math.max(parseInt(rawQuery.page || '1', 10), 1);
    const offset = (page - 1) * limit;
    const activeExpr = "(COALESCE(CAST(u.aktiv AS INTEGER), 0) = 1 OR COALESCE(LOWER(CAST(u.aktiv AS TEXT)), '') IN ('true','evet','yes'))";
    const bannedExpr = "(COALESCE(CAST(u.yasak AS INTEGER), 0) = 1 OR COALESCE(LOWER(CAST(u.yasak AS TEXT)), '') IN ('true','evet','yes'))";
    const onlineExpr = "(COALESCE(CAST(u.online AS INTEGER), 0) = 1 OR COALESCE(LOWER(CAST(u.online AS TEXT)), '') IN ('true','evet','yes'))";

    const actorRole = getUserRole(rawQuery.authUser || rawQuery.currentUser || {});
    const whereParts = [];
    if (actorRole !== 'root') {
      whereParts.push("(u.role IS NULL OR LOWER(COALESCE(u.role, 'user')) != 'root')");
    }
    const params = [];
    if (filter === 'active') whereParts.push(`${activeExpr} AND NOT ${bannedExpr}`);
    if (filter === 'pending') whereParts.push(`NOT ${activeExpr} AND NOT ${bannedExpr}`);
    if (filter === 'banned') whereParts.push(`${bannedExpr}`);
    if (filter === 'online') whereParts.push(`${onlineExpr}`);
    if (q) {
      whereParts.push('(LOWER(CAST(u.kadi AS TEXT)) LIKE LOWER(?) OR LOWER(CAST(u.isim AS TEXT)) LIKE LOWER(?) OR LOWER(CAST(u.soyisim AS TEXT)) LIKE LOWER(?) OR LOWER(CAST(u.email AS TEXT)) LIKE LOWER(?))');
      params.push(`%${q}%`, `%${q}%`, `%${q}%`, `%${q}%`);
    }
    if (userId) {
      whereParts.push('u.id = ?');
      params.push(userId);
    }
    if (cohort) {
      whereParts.push("CAST(COALESCE(u.mezuniyetyili, '') AS TEXT) = ?");
      params.push(cohort);
    }
    if (withPhoto) {
      whereParts.push("u.resim IS NOT NULL AND TRIM(CAST(u.resim AS TEXT)) != '' AND LOWER(TRIM(CAST(u.resim AS TEXT))) != 'yok'");
    }
    if (verifiedOnly) {
      whereParts.push("COALESCE(CAST(u.verified AS INTEGER), 0) = 1");
    }
    if (onlineOnly) {
      whereParts.push(onlineExpr);
    }
    if (adminOnly) {
      whereParts.push("COALESCE(CAST(u.admin AS INTEGER), 0) = 1");
    }
    if (Number.isFinite(minScore)) {
      whereParts.push('COALESCE(es.score, 0) >= ?');
      params.push(minScore);
    }
    if (Number.isFinite(maxScore)) {
      whereParts.push('COALESCE(es.score, 0) <= ?');
      params.push(maxScore);
    }
    const where = whereParts.length ? `WHERE ${whereParts.join(' AND ')}` : '';
    let sort = String(rawQuery.sort || '').trim();
    if (!sort) {
      sort = filter === 'recent' ? 'recent' : 'engagement_desc';
    }
    const sortMap = {
      name: 'u.kadi COLLATE NOCASE ASC',
      recent: 'COALESCE(u.sontarih, u.sonislemtarih, "") DESC, u.id DESC',
      online: `${onlineExpr} DESC, COALESCE(es.score, 0) DESC, u.kadi COLLATE NOCASE ASC`,
      engagement_desc: 'COALESCE(es.score, 0) DESC, u.id DESC',
      engagement_asc: 'COALESCE(es.score, 0) ASC, u.id DESC'
    };
    const orderBy = sortMap[sort] || sortMap.engagement_desc;

    const total = (await sqlGetAsync(
      `SELECT COUNT(*) AS cnt
       FROM uyeler u
       LEFT JOIN member_engagement_scores es ON es.user_id = u.id
       ${where}`,
      params
    ))?.cnt || 0;

    const users = await sqlAllAsync(
      `SELECT u.id, u.kadi, u.isim, u.soyisim, u.aktiv, u.yasak, u.online, u.sontarih, u.resim, u.verified,
              u.mezuniyetyili, u.email, u.admin, u.role,
              CASE
                WHEN CAST(COALESCE(u.mezuniyetyili, 0) AS INTEGER) BETWEEN 1999 AND 2030 THEN 1
                ELSE 0
              END AS has_graduation_info,
              COALESCE(es.score, 0) AS engagement_score,
              es.updated_at AS engagement_updated_at
       FROM uyeler u
       LEFT JOIN member_engagement_scores es ON es.user_id = u.id
       ${where}
       ORDER BY ${orderBy}
       LIMIT ? OFFSET ?`,
      [...params, limit, offset]
    );

    return {
      users,
      meta: {
        total,
        returned: users.length,
        page,
        pages: Math.max(Math.ceil(total / limit), 1),
        limit,
        filter,
        sort,
        withPhoto,
        verifiedOnly,
        onlineOnly,
        adminOnly,
        minScore: Number.isFinite(minScore) ? minScore : null,
        maxScore: Number.isFinite(maxScore) ? maxScore : null,
        q: q || ''
      }
    };
  }

  const isPostgres = dbDriver === 'postgres';
  const dateText = (expr) => isPostgres ? `COALESCE(${expr}::text, '')` : `COALESCE(${expr}, '')`;
  const previewText = (value, max = 220) => String(value || '')
    .replace(/\s+/g, ' ')
    .trim()
    .slice(0, max);
  const plainText = (value) => String(value || '')
    .replace(/<br\s*\/?>/gi, '\n')
    .replace(/<\/p>/gi, '\n')
    .replace(/<[^>]+>/g, '')
    .replace(/&nbsp;/g, ' ')
    .replace(/&amp;/g, '&')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .trim();
  const albumMediaUrl = (fileName, width = 900) => {
    const clean = String(fileName || '').trim();
    if (!clean) return '';
    const params = new URLSearchParams();
    params.set('width', String(width));
    params.set('file', clean);
    return `/api/media/kucukresim?${params.toString()}`;
  };

  async function safeAll(label, sql, params = []) {
    try {
      return await sqlAllAsync(sql, params) || [];
    } catch (err) {
      writeAppLog?.('warn', 'admin_member_journey_query_failed', {
        label,
        message: err?.message || String(err)
      });
      return [];
    }
  }

  async function safeGet(label, sql, params = []) {
    try {
      return await sqlGetAsync(sql, params) || null;
    } catch (err) {
      writeAppLog?.('warn', 'admin_member_journey_query_failed', {
        label,
        message: err?.message || String(err)
      });
      return null;
    }
  }

  async function firstSafeRows(label, variants) {
    for (const variant of variants) {
      const rows = await safeAll(label, variant.sql, variant.params);
      if (rows.length) return rows;
    }
    return [];
  }

  async function firstSafeGet(label, variants) {
    for (const variant of variants) {
      const row = await safeGet(label, variant.sql, variant.params);
      if (row) return row;
    }
    return null;
  }

  function safeJsonParse(value) {
    if (!value) return {};
    if (typeof value === 'object') return value;
    try {
      return JSON.parse(String(value));
    } catch {
      return {};
    }
  }

  function boolish(value) {
    return value === true || Number(value || 0) === 1 || ['true', 'evet', 'yes'].includes(String(value || '').toLowerCase());
  }

  function normalizeJourneyUser(row) {
    const firstName = String(row?.isim || row?.first_name || '').trim();
    const lastName = String(row?.soyisim || row?.last_name || '').trim();
    return {
      id: Number(row?.id || 0),
      handle: String(row?.kadi || row?.handle || '').trim(),
      name: `${firstName} ${lastName}`.trim(),
      email: String(row?.email || '').trim(),
      avatar: String(row?.resim || row?.avatar || '').trim(),
      role: String(row?.role || 'user').trim(),
      graduationYear: String(row?.mezuniyetyili || row?.graduation_year || '').trim(),
      university: String(row?.universite || '').trim(),
      city: String(row?.sehir || '').trim(),
      profession: String(row?.meslek || '').trim(),
      website: String(row?.websitesi || '').trim(),
      signature: plainText(row?.imza || ''),
      active: boolish(row?.aktiv),
      banned: boolish(row?.yasak),
      online: boolish(row?.online),
      verified: boolish(row?.verified),
      profileInitialized: boolish(row?.ilkbd ?? row?.is_profile_initialized),
      verificationStatus: String(row?.verification_status || '').trim(),
      activationToken: String(row?.aktivasyon || '').trim(),
      createdAt: String(row?.ilktarih || row?.created_at || '').trim(),
      lastSeenAt: String(row?.sontarih || row?.last_seen_at || '').trim(),
      lastActivityDate: String(row?.sonislemtarih || '').trim(),
      lastActivityTime: String(row?.sonislemsaat || '').trim(),
      profileViewCount: Number(row?.hit || row?.profile_view_count || 0)
    };
  }

  function journeyEntry({
    id = 0,
    type,
    title,
    text = '',
    createdAt = '',
    meta = '',
    route = '',
    imageUrl = '',
    lightboxUrl = '',
    actor = '',
    direction = ''
  }) {
    return {
      id: Number(id || 0),
      type: String(type || ''),
      title: String(title || ''),
      text: plainText(text),
      createdAt: String(createdAt || ''),
      meta: String(meta || ''),
      route: String(route || ''),
      imageUrl: String(imageUrl || ''),
      lightboxUrl: String(lightboxUrl || imageUrl || ''),
      actor: String(actor || ''),
      direction: String(direction || '')
    };
  }

  function sortEntriesDescending(items) {
    return [...items].sort((left, right) => {
      const rightTime = new Date(right.createdAt || 0).getTime();
      const leftTime = new Date(left.createdAt || 0).getTime();
      return (Number.isFinite(rightTime) ? rightTime : 0) - (Number.isFinite(leftTime) ? leftTime : 0);
    });
  }

  async function readAdminMemberJourney(userId) {
    const userRow = await firstSafeGet('member_journey_user', [
      {
        sql: `SELECT id, kadi, isim, soyisim, email, aktiv, yasak, online, sontarih, sonislemtarih,
                     sonislemsaat, resim, verified, mezuniyetyili, admin, role, universite, sehir,
                     meslek, websitesi, imza, mailkapali, aktivasyon, verification_status,
                     ilktarih, ilkbd, hit
              FROM uyeler
              WHERE id = ?`,
        params: [userId]
      },
      {
        sql: `SELECT id, kadi, isim, soyisim, email, aktiv, yasak, online, sontarih,
                     resim, verified, mezuniyetyili, admin, role, activation_token AS aktivasyon,
                     verification_status, created_at AS ilktarih, is_profile_initialized AS ilkbd
              FROM users
              WHERE id = ?`,
        params: [userId]
      }
    ]);
    const user = normalizeJourneyUser(userRow);
    if (!user.id) return null;

    const [
      posts,
      comments,
      postLikes,
      albumPhotos,
      albumComments,
      albumLikes,
      messages,
      directMessages,
      follows,
      followers,
      connectionRequests,
      mentorshipRequests,
      teacherLinks,
      networkingTelemetry,
      memberRequests,
      verificationRequests,
      notifications,
      notificationTelemetry,
      pushDevices,
      pushDeliveries,
      audit,
      activity,
      sessions
    ] = await Promise.all([
      firstSafeRows('member_journey_posts', [
        { sql: `SELECT id, ${dateText('created_at')} AS created_at, COALESCE(content, '') AS text, COALESCE(image_url, '') AS image_url FROM posts WHERE author_id = ? ORDER BY created_at DESC LIMIT 80`, params: [userId] },
        { sql: `SELECT id, ${dateText('created_at')} AS created_at, COALESCE(content, '') AS text, COALESCE(image, '') AS image_url FROM posts WHERE user_id = ? ORDER BY created_at DESC LIMIT 80`, params: [userId] },
        { sql: `SELECT id, ${dateText('tarih')} AS created_at, COALESCE(metin, '') AS text, COALESCE(resim, '') AS image_url FROM yazilar WHERE uyeid = ? ORDER BY id DESC LIMIT 80`, params: [userId] }
      ]),
      firstSafeRows('member_journey_comments', [
        { sql: `SELECT c.id, c.post_id, p.author_id AS owner_user_id, ${dateText('c.created_at')} AS created_at, COALESCE(c.body, '') AS text, COALESCE(p.content, '') AS target_text FROM post_comments c LEFT JOIN posts p ON p.id = c.post_id WHERE c.author_id = ? ORDER BY c.created_at DESC LIMIT 100`, params: [userId] },
        { sql: `SELECT c.id, c.post_id, p.user_id AS owner_user_id, ${dateText('c.created_at')} AS created_at, COALESCE(c.comment, '') AS text, COALESCE(p.content, '') AS target_text FROM post_comments c LEFT JOIN posts p ON p.id = c.post_id WHERE c.user_id = ? ORDER BY c.created_at DESC LIMIT 100`, params: [userId] }
      ]),
      firstSafeRows('member_journey_post_likes', [
        { sql: `SELECT r.id, r.post_id, p.author_id AS owner_user_id, ${dateText('r.created_at')} AS created_at, COALESCE(r.reaction_type, 'like') AS reaction_type, COALESCE(p.content, '') AS target_text FROM post_reactions r LEFT JOIN posts p ON p.id = r.post_id WHERE r.user_id = ? ORDER BY r.created_at DESC LIMIT 100`, params: [userId] },
        { sql: `SELECT r.id, r.post_id, p.user_id AS owner_user_id, ${dateText('r.created_at')} AS created_at, 'like' AS reaction_type, COALESCE(p.content, '') AS target_text FROM post_likes r LEFT JOIN posts p ON p.id = r.post_id WHERE r.user_id = ? ORDER BY r.created_at DESC LIMIT 100`, params: [userId] }
      ]),
      firstSafeRows('member_journey_album_photos', [
        { sql: `SELECT id, ${dateText('created_at')} AS created_at, COALESCE(title, '') AS title, COALESCE(description, '') AS description, COALESCE(file_name, '') AS file_name, COALESCE(view_count, 0) AS view_count FROM album_photos WHERE uploaded_by_user_id = ? ORDER BY created_at DESC LIMIT 80`, params: [userId] },
        { sql: `SELECT id, ${dateText('tarih')} AS created_at, COALESCE(baslik, '') AS title, COALESCE(aciklama, '') AS description, COALESCE(dosyaadi, '') AS file_name, COALESCE(hit, 0) AS view_count FROM album_foto WHERE CAST(ekleyenid AS INTEGER) = CAST(? AS INTEGER) ORDER BY id DESC LIMIT 80`, params: [userId] }
      ]),
      firstSafeRows('member_journey_album_comments', [
        { sql: `SELECT c.id, c.photo_id, ${dateText('c.created_at')} AS created_at, COALESCE(c.comment_body, '') AS text, COALESCE(p.title, '') AS target_text, COALESCE(p.file_name, '') AS file_name FROM album_photo_comments c LEFT JOIN album_photos p ON p.id = c.photo_id WHERE c.author_user_id = ? ORDER BY c.created_at DESC LIMIT 100`, params: [userId] },
        { sql: `SELECT c.id, c.fotoid AS photo_id, ${dateText('c.tarih')} AS created_at, COALESCE(c.yorum, '') AS text, COALESCE(p.baslik, '') AS target_text, COALESCE(p.dosyaadi, '') AS file_name FROM album_fotoyorum c LEFT JOIN album_foto p ON p.id = c.fotoid WHERE CAST(c.uyeid AS INTEGER) = CAST(? AS INTEGER) ORDER BY c.id DESC LIMIT 100`, params: [userId] }
      ]),
      firstSafeRows('member_journey_album_likes', [
        { sql: `SELECT l.id, l.photo_id, ${dateText('l.created_at')} AS created_at, COALESCE(p.title, '') AS target_text, COALESCE(p.file_name, '') AS file_name FROM album_photo_likes l LEFT JOIN album_photos p ON p.id = l.photo_id WHERE l.user_id = ? ORDER BY l.created_at DESC LIMIT 100`, params: [userId] },
        { sql: `SELECT l.id, l.photo_id, ${dateText('l.created_at')} AS created_at, COALESCE(p.baslik, '') AS target_text, COALESCE(p.dosyaadi, '') AS file_name FROM album_photo_likes l LEFT JOIN album_foto p ON p.id = l.photo_id WHERE l.user_id = ? ORDER BY l.created_at DESC LIMIT 100`, params: [userId] }
      ]),
      firstSafeRows('member_journey_messages', [
        { sql: `SELECT m.id, 'thread' AS source, m.conversation_id, m.sender_id, m.recipient_id, CASE WHEN m.sender_id = ? THEN m.recipient_id ELSE m.sender_id END AS peer_user_id, COALESCE(u.kadi, '') AS peer_handle, COALESCE(u.isim, '') AS peer_first_name, COALESCE(u.soyisim, '') AS peer_last_name, COALESCE(u.resim, '') AS peer_avatar, ${dateText('m.created_at')} AS created_at, COALESCE(m.body, '') AS body_text FROM conversation_messages m LEFT JOIN uyeler u ON u.id = CASE WHEN m.sender_id = ? THEN m.recipient_id ELSE m.sender_id END WHERE m.sender_id = ? OR m.recipient_id = ? ORDER BY m.created_at DESC LIMIT 120`, params: [userId, userId, userId, userId] },
        { sql: `SELECT m.id, 'messenger' AS source, m.thread_id AS conversation_id, m.sender_id, m.receiver_id AS recipient_id, CASE WHEN CAST(m.sender_id AS INTEGER) = CAST(? AS INTEGER) THEN m.receiver_id ELSE m.sender_id END AS peer_user_id, COALESCE(u.kadi, '') AS peer_handle, COALESCE(u.isim, '') AS peer_first_name, COALESCE(u.soyisim, '') AS peer_last_name, COALESCE(u.resim, '') AS peer_avatar, ${dateText('m.created_at')} AS created_at, COALESCE(m.body, '') AS body_text FROM sdal_messenger_messages m LEFT JOIN uyeler u ON CAST(u.id AS INTEGER) = CAST(CASE WHEN CAST(m.sender_id AS INTEGER) = CAST(? AS INTEGER) THEN m.receiver_id ELSE m.sender_id END AS INTEGER) WHERE CAST(m.sender_id AS INTEGER) = CAST(? AS INTEGER) OR CAST(m.receiver_id AS INTEGER) = CAST(? AS INTEGER) ORDER BY m.created_at DESC LIMIT 120`, params: [userId, userId, userId, userId] }
      ]),
      safeAll('member_journey_direct_messages',
        `SELECT m.id, 'direct' AS source, 0 AS conversation_id, m.sender_id, m.recipient_id,
                CASE WHEN m.sender_id = ? THEN m.recipient_id ELSE m.sender_id END AS peer_user_id,
                COALESCE(u.kadi, '') AS peer_handle, COALESCE(u.isim, '') AS peer_first_name,
                COALESCE(u.soyisim, '') AS peer_last_name, COALESCE(u.resim, '') AS peer_avatar,
                ${dateText('m.created_at')} AS created_at, COALESCE(m.body_html, '') AS body_text
         FROM direct_messages m
         LEFT JOIN uyeler u ON u.id = CASE WHEN m.sender_id = ? THEN m.recipient_id ELSE m.sender_id END
         WHERE m.sender_id = ? OR m.recipient_id = ?
         ORDER BY m.created_at DESC LIMIT 120`, [userId, userId, userId, userId]),
      firstSafeRows('member_journey_follows', [
        { sql: `SELECT f.id, f.following_id AS target_user_id, ${dateText('f.created_at')} AS created_at, COALESCE(u.kadi, '') AS target_handle, COALESCE(u.isim, '') AS target_first_name, COALESCE(u.soyisim, '') AS target_last_name, COALESCE(u.resim, '') AS target_avatar FROM user_follows f LEFT JOIN uyeler u ON u.id = f.following_id WHERE f.follower_id = ? ORDER BY f.created_at DESC LIMIT 100`, params: [userId] },
        { sql: `SELECT f.id, f.following_id AS target_user_id, ${dateText('f.created_at')} AS created_at, COALESCE(u.kadi, '') AS target_handle, COALESCE(u.isim, '') AS target_first_name, COALESCE(u.soyisim, '') AS target_last_name, COALESCE(u.resim, '') AS target_avatar FROM follows f LEFT JOIN uyeler u ON u.id = f.following_id WHERE f.follower_id = ? ORDER BY f.created_at DESC LIMIT 100`, params: [userId] }
      ]),
      firstSafeRows('member_journey_followers', [
        { sql: `SELECT f.id, f.follower_id AS source_user_id, ${dateText('f.created_at')} AS created_at, COALESCE(u.kadi, '') AS source_handle, COALESCE(u.isim, '') AS source_first_name, COALESCE(u.soyisim, '') AS source_last_name, COALESCE(u.resim, '') AS source_avatar FROM user_follows f LEFT JOIN uyeler u ON u.id = f.follower_id WHERE f.following_id = ? ORDER BY f.created_at DESC LIMIT 100`, params: [userId] },
        { sql: `SELECT f.id, f.follower_id AS source_user_id, ${dateText('f.created_at')} AS created_at, COALESCE(u.kadi, '') AS source_handle, COALESCE(u.isim, '') AS source_first_name, COALESCE(u.soyisim, '') AS source_last_name, COALESCE(u.resim, '') AS source_avatar FROM follows f LEFT JOIN uyeler u ON u.id = f.follower_id WHERE f.following_id = ? ORDER BY f.created_at DESC LIMIT 100`, params: [userId] }
      ]),
      safeAll('member_journey_connection_requests',
        `SELECT cr.id, cr.sender_id, cr.receiver_id, COALESCE(cr.status, 'pending') AS status,
                ${dateText('cr.created_at')} AS created_at, ${dateText('cr.updated_at')} AS updated_at,
                ${dateText('cr.responded_at')} AS responded_at,
                CASE WHEN CAST(cr.sender_id AS INTEGER) = CAST(? AS INTEGER) THEN cr.receiver_id ELSE cr.sender_id END AS peer_user_id,
                COALESCE(u.kadi, '') AS peer_handle, COALESCE(u.isim, '') AS peer_first_name,
                COALESCE(u.soyisim, '') AS peer_last_name, COALESCE(u.resim, '') AS peer_avatar
         FROM connection_requests cr
         LEFT JOIN uyeler u ON CAST(u.id AS INTEGER) = CAST(CASE WHEN CAST(cr.sender_id AS INTEGER) = CAST(? AS INTEGER) THEN cr.receiver_id ELSE cr.sender_id END AS INTEGER)
         WHERE CAST(cr.sender_id AS INTEGER) = CAST(? AS INTEGER) OR CAST(cr.receiver_id AS INTEGER) = CAST(? AS INTEGER)
         ORDER BY COALESCE(cr.updated_at, cr.created_at) DESC LIMIT 100`, [userId, userId, userId, userId]),
      safeAll('member_journey_mentorship_requests',
        `SELECT mr.id, mr.requester_id, mr.mentor_id, COALESCE(mr.status, 'requested') AS status,
                COALESCE(mr.focus_area, '') AS focus_area, COALESCE(mr.message, '') AS message,
                ${dateText('mr.created_at')} AS created_at, ${dateText('mr.updated_at')} AS updated_at,
                ${dateText('mr.responded_at')} AS responded_at,
                CASE WHEN CAST(mr.requester_id AS INTEGER) = CAST(? AS INTEGER) THEN mr.mentor_id ELSE mr.requester_id END AS peer_user_id,
                COALESCE(u.kadi, '') AS peer_handle, COALESCE(u.isim, '') AS peer_first_name,
                COALESCE(u.soyisim, '') AS peer_last_name, COALESCE(u.resim, '') AS peer_avatar
         FROM mentorship_requests mr
         LEFT JOIN uyeler u ON CAST(u.id AS INTEGER) = CAST(CASE WHEN CAST(mr.requester_id AS INTEGER) = CAST(? AS INTEGER) THEN mr.mentor_id ELSE mr.requester_id END AS INTEGER)
         WHERE CAST(mr.requester_id AS INTEGER) = CAST(? AS INTEGER) OR CAST(mr.mentor_id AS INTEGER) = CAST(? AS INTEGER)
         ORDER BY COALESCE(mr.updated_at, mr.created_at) DESC LIMIT 100`, [userId, userId, userId, userId]),
      safeAll('member_journey_teacher_links',
        `SELECT l.id, l.teacher_user_id, l.alumni_user_id, COALESCE(l.relationship_type, '') AS relationship_type,
                COALESCE(CAST(l.class_year AS TEXT), '') AS class_year, COALESCE(l.notes, '') AS notes,
                COALESCE(l.confidence_score, 0) AS confidence_score, COALESCE(l.review_status, '') AS review_status,
                ${dateText('l.created_at')} AS created_at,
                CASE WHEN CAST(l.teacher_user_id AS INTEGER) = CAST(? AS INTEGER) THEN l.alumni_user_id ELSE l.teacher_user_id END AS peer_user_id,
                COALESCE(u.kadi, '') AS peer_handle, COALESCE(u.isim, '') AS peer_first_name,
                COALESCE(u.soyisim, '') AS peer_last_name, COALESCE(u.resim, '') AS peer_avatar
         FROM teacher_alumni_links l
         LEFT JOIN uyeler u ON CAST(u.id AS INTEGER) = CAST(CASE WHEN CAST(l.teacher_user_id AS INTEGER) = CAST(? AS INTEGER) THEN l.alumni_user_id ELSE l.teacher_user_id END AS INTEGER)
         WHERE CAST(l.teacher_user_id AS INTEGER) = CAST(? AS INTEGER) OR CAST(l.alumni_user_id AS INTEGER) = CAST(? AS INTEGER)
         ORDER BY l.created_at DESC LIMIT 100`, [userId, userId, userId, userId]),
      safeAll('member_journey_networking_telemetry',
        `SELECT id, COALESCE(event_name, '') AS event_name, COALESCE(source_surface, '') AS source_surface,
                COALESCE(target_user_id, 0) AS target_user_id, COALESCE(entity_type, '') AS entity_type,
                COALESCE(entity_id, 0) AS entity_id, metadata_json, ${dateText('created_at')} AS created_at
         FROM networking_telemetry_events
         WHERE user_id = ?
         ORDER BY created_at DESC LIMIT 120`, [userId]),
      firstSafeRows('member_journey_member_requests', [
        { sql: `SELECT id, category_key, payload_json, status, ${dateText('created_at')} AS created_at, ${dateText('reviewed_at')} AS reviewed_at, COALESCE(resolution_note, '') AS resolution_note FROM member_requests WHERE user_id = ? ORDER BY created_at DESC LIMIT 80`, params: [userId] },
        { sql: `SELECT id, category_key, payload_json, status, ${dateText('created_at')} AS created_at, ${dateText('reviewed_at')} AS reviewed_at, COALESCE(resolution_note, '') AS resolution_note FROM support_requests WHERE user_id = ? ORDER BY created_at DESC LIMIT 80`, params: [userId] }
      ]),
      firstSafeRows('member_journey_verification_requests', [
        { sql: `SELECT id, COALESCE(request_type, 'member_verification') AS request_type, COALESCE(status, '') AS status, ${dateText('created_at')} AS created_at, ${dateText('reviewed_at')} AS reviewed_at, COALESCE(reviewer_note, '') AS reviewer_note FROM verification_requests WHERE user_id = ? ORDER BY created_at DESC LIMIT 80`, params: [userId] },
        { sql: `SELECT id, COALESCE(request_type, 'member_verification') AS request_type, COALESCE(status, '') AS status, ${dateText('created_at')} AS created_at, ${dateText('reviewed_at')} AS reviewed_at, COALESCE(reviewer_note, '') AS reviewer_note FROM identity_verification_requests WHERE user_id = ? ORDER BY created_at DESC LIMIT 80`, params: [userId] },
        { sql: `SELECT id, 'member_verification' AS request_type, COALESCE(status, '') AS status, ${dateText('created_at')} AS created_at, ${dateText('reviewed_at')} AS reviewed_at, '' AS reviewer_note FROM identity_verification_requests WHERE user_id = ? ORDER BY created_at DESC LIMIT 80`, params: [userId] }
      ]),
      safeAll('member_journey_notifications',
        `SELECT id, COALESCE(type, '') AS type, COALESCE(source_user_id, 0) AS source_user_id, COALESCE(entity_id, 0) AS entity_id, COALESCE(message, '') AS message, ${dateText('created_at')} AS created_at, ${dateText('read_at')} AS read_at
         FROM notifications
         WHERE user_id = ?
         ORDER BY id DESC LIMIT 100`, [userId]),
      safeAll('member_journey_notification_telemetry',
        `SELECT id, COALESCE(notification_id, 0) AS notification_id, COALESCE(event_name, '') AS event_name, COALESCE(notification_type, '') AS notification_type, COALESCE(surface, '') AS surface, COALESCE(action_kind, '') AS action_kind, ${dateText('created_at')} AS created_at
         FROM notification_telemetry_events
         WHERE user_id = ?
         ORDER BY created_at DESC LIMIT 80`, [userId]),
      firstSafeRows('member_journey_push_devices', [
        { sql: `SELECT id, COALESCE(platform, '') AS platform, COALESCE(device_name, '') AS device_name, COALESCE(app_version, '') AS app_version, COALESCE(enabled, 0) AS enabled, ${dateText('created_at')} AS created_at, ${dateText('updated_at')} AS updated_at FROM notification_push_devices WHERE user_id = ? ORDER BY updated_at DESC LIMIT 20`, params: [userId] },
        { sql: `SELECT id, COALESCE(platform, '') AS platform, COALESCE(installation_id, '') AS device_name, COALESCE(app_version, '') AS app_version, COALESCE(enabled, 0) AS enabled, ${dateText('created_at')} AS created_at, ${dateText('updated_at')} AS updated_at FROM notification_push_devices WHERE user_id = ? ORDER BY updated_at DESC LIMIT 20`, params: [userId] }
      ]),
      safeAll('member_journey_push_deliveries',
        `SELECT id, COALESCE(notification_id, 0) AS notification_id, COALESCE(device_id, 0) AS device_id,
                COALESCE(platform, '') AS platform, COALESCE(notification_type, '') AS notification_type,
                COALESCE(delivery_status, '') AS delivery_status, COALESCE(skip_reason, '') AS skip_reason,
                COALESCE(error_message, '') AS error_message, ${dateText('created_at')} AS created_at
         FROM notification_push_delivery_audit
         WHERE user_id = ?
         ORDER BY created_at DESC LIMIT 80`, [userId]),
      safeAll('member_journey_audit',
        `SELECT id, COALESCE(actor_user_id, 0) AS actor_user_id, COALESCE(action, '') AS action, COALESCE(target_type, '') AS target_type, COALESCE(target_id, '') AS target_id, metadata, ${dateText('created_at')} AS created_at
         FROM audit_log
         WHERE target_type = 'user' AND CAST(target_id AS TEXT) = CAST(? AS TEXT)
         ORDER BY id DESC LIMIT 100`, [userId]),
      safeAll('member_journey_activity',
        `SELECT id, COALESCE(event_type, '') AS event_type, COALESCE(target_type, '') AS target_type, COALESCE(target_id, '') AS target_id, metadata, ${dateText('occurred_at')} AS occurred_at
         FROM user_activity_events
         WHERE actor_user_id = ? AND event_type NOT IN ('session_start', 'session_end')
         ORDER BY occurred_at DESC LIMIT 180`, [userId]),
      safeAll('member_journey_sessions',
        `SELECT id, COALESCE(event_type, '') AS event_type, COALESCE(target_type, '') AS target_type, COALESCE(target_id, '') AS target_id, metadata, ${dateText('occurred_at')} AS occurred_at
         FROM user_activity_events
         WHERE actor_user_id = ? AND event_type IN ('session_start', 'session_end')
         ORDER BY occurred_at DESC LIMIT 120`, [userId])
    ]);

    const sections = {
      registration: [
        journeyEntry({
          type: 'registration',
          title: 'Kayıt oluşturuldu',
          text: user.email,
          createdAt: user.createdAt,
          meta: user.activationToken ? 'Aktivasyon kodu var' : 'Aktivasyon kodu yok'
        }),
        journeyEntry({
          type: 'profile',
          title: user.profileInitialized ? 'Profil ilk kurulumu tamam' : 'Profil ilk kurulumu eksik',
          text: [user.city, user.profession, user.university].filter(Boolean).join(' · '),
          createdAt: user.lastSeenAt || user.createdAt,
          meta: user.verificationStatus
        })
      ].filter((item) => item.createdAt || item.text || item.meta),
      requests: [
        ...memberRequests.map((row) => journeyEntry({
          id: row.id,
          type: 'member_request',
          title: row.category_key || 'Üye talebi',
          text: previewText(JSON.stringify(safeJsonParse(row.payload_json)), 240),
          createdAt: row.created_at,
          meta: [row.status, row.resolution_note].filter(Boolean).join(' · ')
        })),
        ...verificationRequests.map((row) => journeyEntry({
          id: row.id,
          type: 'verification',
          title: row.request_type || 'Profil doğrulama',
          text: row.reviewer_note || '',
          createdAt: row.created_at,
          meta: [row.status, row.reviewed_at].filter(Boolean).join(' · ')
        }))
      ],
      content: [
        ...posts.map((row) => journeyEntry({
          id: row.id,
          type: 'post',
          title: 'Post',
          text: row.text,
          createdAt: row.created_at,
          imageUrl: row.image_url,
          lightboxUrl: row.image_url,
          route: `/posts/${Number(row.id || 0)}`
        })),
        ...comments.map((row) => journeyEntry({
          id: row.id,
          type: 'comment',
          title: `Post yorumu #${Number(row.post_id || 0)}`,
          text: row.text,
          createdAt: row.created_at,
          meta: previewText(row.target_text, 140),
          route: `/posts/${Number(row.post_id || 0)}`
        })),
        ...postLikes.map((row) => journeyEntry({
          id: row.id,
          type: 'post_like',
          title: `Post beğenisi #${Number(row.post_id || 0)}`,
          text: previewText(row.target_text, 180),
          createdAt: row.created_at,
          meta: row.reaction_type || 'like',
          route: `/posts/${Number(row.post_id || 0)}`
        }))
      ],
      media: [
        ...albumPhotos.map((row) => journeyEntry({
          id: row.id,
          type: 'album_photo',
          title: row.title || 'Albüm fotoğrafı',
          text: row.description || row.file_name,
          createdAt: row.created_at,
          meta: `${Number(row.view_count || 0)} görüntüleme`,
          imageUrl: albumMediaUrl(row.file_name, 700),
          lightboxUrl: albumMediaUrl(row.file_name, 2200),
          route: `/albums/photo/${Number(row.id || 0)}`
        })),
        ...albumComments.map((row) => journeyEntry({
          id: row.id,
          type: 'album_comment',
          title: `Fotoğraf yorumu #${Number(row.photo_id || 0)}`,
          text: row.text,
          createdAt: row.created_at,
          meta: previewText(row.target_text, 120),
          imageUrl: albumMediaUrl(row.file_name, 700),
          lightboxUrl: albumMediaUrl(row.file_name, 2200),
          route: `/albums/photo/${Number(row.photo_id || 0)}`
        })),
        ...albumLikes.map((row) => journeyEntry({
          id: row.id,
          type: 'album_like',
          title: `Fotoğraf beğenisi #${Number(row.photo_id || 0)}`,
          text: previewText(row.target_text, 120),
          createdAt: row.created_at,
          imageUrl: albumMediaUrl(row.file_name, 700),
          lightboxUrl: albumMediaUrl(row.file_name, 2200),
          route: `/albums/photo/${Number(row.photo_id || 0)}`
        }))
      ],
      messaging: [...messages, ...directMessages].map((row) => {
        const peerLabel = [row.peer_first_name, row.peer_last_name].filter(Boolean).join(' ').trim() || (row.peer_handle ? `@${row.peer_handle}` : `Üye #${row.peer_user_id || 0}`);
        const sent = Number(row.sender_id || 0) === Number(userId);
        return journeyEntry({
          id: row.id,
          type: 'message',
          title: peerLabel,
          text: row.body_text,
          createdAt: row.created_at,
          meta: row.source || '',
          imageUrl: row.peer_avatar,
          actor: peerLabel,
          direction: sent ? 'sent' : 'received'
        });
      }),
      network: [
        ...follows.map((row) => {
          const label = [row.target_first_name, row.target_last_name].filter(Boolean).join(' ').trim() || (row.target_handle ? `@${row.target_handle}` : `Üye #${row.target_user_id || 0}`);
          return journeyEntry({
            id: row.id,
            type: 'follow',
            title: label,
            text: 'Takip ediyor',
            createdAt: row.created_at,
            imageUrl: row.target_avatar,
            route: `/members/${Number(row.target_user_id || 0)}`,
            direction: 'out'
          });
        }),
        ...followers.map((row) => {
          const label = [row.source_first_name, row.source_last_name].filter(Boolean).join(' ').trim() || (row.source_handle ? `@${row.source_handle}` : `Üye #${row.source_user_id || 0}`);
          return journeyEntry({
            id: row.id,
            type: 'follower',
            title: label,
            text: 'Bu üyeyi takip ediyor',
            createdAt: row.created_at,
            imageUrl: row.source_avatar,
            route: `/members/${Number(row.source_user_id || 0)}`,
            direction: 'in'
          });
        }),
        ...connectionRequests.map((row) => {
          const label = [row.peer_first_name, row.peer_last_name].filter(Boolean).join(' ').trim() || (row.peer_handle ? `@${row.peer_handle}` : `Üye #${row.peer_user_id || 0}`);
          const sent = Number(row.sender_id || 0) === Number(userId);
          return journeyEntry({
            id: row.id,
            type: 'connection_request',
            title: label,
            text: sent ? 'Bağlantı isteği gönderdi' : 'Bağlantı isteği aldı',
            createdAt: row.updated_at || row.responded_at || row.created_at,
            meta: row.status || 'pending',
            imageUrl: row.peer_avatar,
            route: `/members/${Number(row.peer_user_id || 0)}`,
            direction: sent ? 'out' : 'in'
          });
        }),
        ...mentorshipRequests.map((row) => {
          const label = [row.peer_first_name, row.peer_last_name].filter(Boolean).join(' ').trim() || (row.peer_handle ? `@${row.peer_handle}` : `Üye #${row.peer_user_id || 0}`);
          const sent = Number(row.requester_id || 0) === Number(userId);
          return journeyEntry({
            id: row.id,
            type: 'mentorship_request',
            title: label,
            text: [sent ? 'Mentorluk talebi gönderdi' : 'Mentorluk talebi aldı', row.focus_area, row.message].filter(Boolean).join(' · '),
            createdAt: row.updated_at || row.responded_at || row.created_at,
            meta: row.status || 'requested',
            imageUrl: row.peer_avatar,
            route: `/members/${Number(row.peer_user_id || 0)}`,
            direction: sent ? 'out' : 'in'
          });
        }),
        ...teacherLinks.map((row) => {
          const label = [row.peer_first_name, row.peer_last_name].filter(Boolean).join(' ').trim() || (row.peer_handle ? `@${row.peer_handle}` : `Üye #${row.peer_user_id || 0}`);
          const asTeacher = Number(row.teacher_user_id || 0) === Number(userId);
          return journeyEntry({
            id: row.id,
            type: 'teacher_link',
            title: label,
            text: [asTeacher ? 'Öğretmen ağı öğretmen tarafı' : 'Öğretmen ağı mezun tarafı', row.relationship_type, row.notes].filter(Boolean).join(' · '),
            createdAt: row.created_at,
            meta: [row.review_status, row.class_year ? `${row.class_year}. sınıf` : '', row.confidence_score ? `güven ${Math.round(Number(row.confidence_score || 0) * 100)}%` : ''].filter(Boolean).join(' · '),
            imageUrl: row.peer_avatar,
            route: `/members/${Number(row.peer_user_id || 0)}`,
            direction: asTeacher ? 'teacher' : 'alumni'
          });
        }),
        ...networkingTelemetry.map((row) => journeyEntry({
          id: row.id,
          type: 'networking_telemetry',
          title: row.event_name || 'Networking olayı',
          text: [row.source_surface, row.entity_type, row.entity_id ? `#${row.entity_id}` : ''].filter(Boolean).join(' · '),
          createdAt: row.created_at,
          meta: previewText(JSON.stringify(safeJsonParse(row.metadata_json)), 180),
          route: row.target_user_id ? `/members/${Number(row.target_user_id || 0)}` : ''
        }))
      ],
      notifications: [
        ...notifications.map((row) => journeyEntry({
          id: row.id,
          type: 'notification',
          title: row.type || 'Bildirim',
          text: row.message,
          createdAt: row.created_at,
          meta: row.read_at ? `Okundu ${row.read_at}` : 'Okunmadı'
        })),
        ...notificationTelemetry.map((row) => journeyEntry({
          id: row.id,
          type: 'notification_telemetry',
          title: row.event_name || 'Bildirim etkileşimi',
          text: [row.notification_type, row.surface, row.action_kind].filter(Boolean).join(' · '),
          createdAt: row.created_at,
          meta: row.notification_id ? `Bildirim #${row.notification_id}` : ''
        })),
        ...pushDevices.map((row) => journeyEntry({
          id: row.id,
          type: 'push_device',
          title: row.device_name || row.platform || 'Push cihazı',
          text: [row.platform, row.app_version].filter(Boolean).join(' · '),
          createdAt: row.updated_at || row.created_at,
          meta: boolish(row.enabled) ? 'Aktif' : 'Pasif'
        })),
        ...pushDeliveries.map((row) => journeyEntry({
          id: row.id,
          type: 'push_delivery',
          title: row.delivery_status || 'Push teslimatı',
          text: [row.platform, row.notification_type, row.skip_reason, row.error_message].filter(Boolean).join(' · '),
          createdAt: row.created_at,
          meta: row.notification_id ? `Bildirim #${row.notification_id}` : ''
        }))
      ],
      audit: audit.map((row) => journeyEntry({
        id: row.id,
        type: 'audit',
        title: row.action || 'Admin işlemi',
        text: previewText(JSON.stringify(safeJsonParse(row.metadata)), 240),
        createdAt: row.created_at,
        meta: row.actor_user_id ? `Admin #${row.actor_user_id}` : ''
      })),
      activity: [
        ...activity.map((row) => journeyEntry({
          id: row.id,
          type: 'activity',
          title: row.event_type || 'Aktivite',
          text: [row.target_type, row.target_id].filter(Boolean).join(' #'),
          createdAt: row.occurred_at,
          meta: previewText(JSON.stringify(safeJsonParse(row.metadata)), 180)
        })),
        ...sessions.map((row) => journeyEntry({
          id: row.id,
          type: 'session',
          title: row.event_type === 'session_end' ? 'Oturum kapandı' : 'Oturum başladı',
          text: [row.target_type, row.target_id].filter(Boolean).join(' #'),
          createdAt: row.occurred_at,
          meta: previewText(JSON.stringify(safeJsonParse(row.metadata)), 180)
        }))
      ]
    };

    for (const key of Object.keys(sections)) {
      sections[key] = sortEntriesDescending(sections[key]);
    }

    const timeline = sortEntriesDescending(Object.values(sections).flat()).slice(0, 260);
    const media = sortEntriesDescending([
      ...sections.media,
      ...sections.content.filter((item) => item.imageUrl)
    ]).filter((item) => item.imageUrl).slice(0, 80);

    return {
      user,
      summary: {
        posts: posts.length,
        comments: comments.length + albumComments.length,
        postLikes: postLikes.length,
        albumPhotos: albumPhotos.length,
        albumLikes: albumLikes.length,
        messages: messages.length + directMessages.length,
        follows: follows.length,
        followers: followers.length,
        connections: connectionRequests.length,
        mentorship: mentorshipRequests.length,
        teacherLinks: teacherLinks.length,
        networkTelemetry: networkingTelemetry.length,
        requests: memberRequests.length + verificationRequests.length,
        notifications: notifications.length,
        pushDevices: pushDevices.length,
        pushDeliveries: pushDeliveries.length,
        audit: audit.length,
        activity: activity.length,
        sessions: sessions.filter((row) => row.event_type === 'session_start').length,
        media: media.length
      },
      sections,
      timeline,
      media
    };
  }

  async function handleMemberDelete(req, res) {
    try {
      const userId = Number(req.params.id || 0);
      if (!userId) return res.status(400).send('Geçersiz kullanıcı ID.');
      const user = await sqlGetAsync('SELECT id, kadi, role FROM uyeler WHERE id = ?', [userId]);
      if (!user) return res.status(404).send('Böyle bir üye bulunmamaktadır.');
      const actorRole = getUserRole(req.authUser || req.adminUser);
      if (normalizeRole(user.role) === 'root' && actorRole !== 'root') {
        return res.status(403).send('Root kullanıcı silinemez.');
      }
      if (Number(user.id) === Number(req.session.userId)) {
        return res.status(403).send('Kendi hesabınızı bu panelden silemezsiniz.');
      }

      await hardDeleteUser(user.id, { sqlRun, sqlGet, sqlAll, uploadsDir, writeAppLog });
      logAdminAction(req, 'user_hard_delete', { targetType: 'user', targetId: String(user.id), handle: user.kadi, role: user.role });
      res.json({ ok: true, message: `@${user.kadi} ve tüm verileri başarıyla silindi.` });
    } catch (err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  }

  app.get('/api/admin/site-controls', requireAdmin, async (_req, res) => {
    try {
      const cacheKey = await buildVersionedCacheKey(cacheNamespaces.adminSettings, ['site_controls']);
      const cached = await getCacheJson(cacheKey);
      if (cached && cached.modules) return res.json(cached);
      const site = getSiteControl();
      const modules = getModuleControlMap();
      let defaultLandingPage = '';
      try {
        const settingsRow = dbDriver === 'postgres'
          ? await sqlGetAsync('SELECT default_landing_page FROM site_settings WHERE id = 1')
          : await sqlGetAsync('SELECT default_landing_page FROM site_controls WHERE id = 1');
        defaultLandingPage = String(settingsRow?.default_landing_page || '');
      } catch { /* column may not exist yet on older deployments */ }
      const payload = {
        siteOpen: site.siteOpen,
        maintenanceMessage: site.maintenanceMessage,
        updatedAt: site.updatedAt,
        defaultLandingPage: defaultLandingPage || site.defaultLandingPage || '',
        menuVisibility: site.menuVisibility || normalizeModuleMenuVisibility(null),
        moduleMenuOrder: site.moduleMenuOrder || normalizeModuleMenuOrder(null),
        activeTheme: site.activeTheme || 'kor',
        modules,
        moduleDefinitions: MODULE_DEFINITIONS
      };
      await setCacheJson(cacheKey, payload, ADMIN_SETTINGS_CACHE_TTL_SECONDS);
      res.json(payload);
    } catch (err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.put('/api/admin/site-controls', requireAdmin, async (req, res) => {
    try {
      const updates = req.body || {};
      const now = new Date().toISOString();
      const currentSite = getSiteControl();
      if (updates.siteOpen !== undefined || updates.maintenanceMessage !== undefined) {
        const nextOpen = updates.siteOpen === undefined ? currentSite.siteOpen : !!updates.siteOpen;
        const nextMessage = String(updates.maintenanceMessage || currentSite.maintenanceMessage || '').slice(0, 1200);
        if (dbDriver === 'postgres') {
          await sqlRunAsync('UPDATE site_settings SET site_open = ?, maintenance_message = ?, updated_at = ? WHERE id = 1', [nextOpen ? true : false, nextMessage, now]);
        } else {
          await sqlRunAsync('UPDATE site_controls SET site_open = ?, maintenance_message = ?, updated_at = ? WHERE id = 1', [nextOpen ? 1 : 0, nextMessage, now]);
        }
      }
      if (updates.defaultLandingPage !== undefined) {
        const nextLanding = String(updates.defaultLandingPage || '').slice(0, 500);
        try {
          if (dbDriver === 'postgres') {
            await sqlRunAsync('UPDATE site_settings SET default_landing_page = ? WHERE id = 1', [nextLanding]);
          } else {
            await sqlRunAsync('UPDATE site_controls SET default_landing_page = ? WHERE id = 1', [nextLanding]);
          }
        } catch { /* column may not exist yet on older deployments */ }
      }
      if (updates.menuVisibility !== undefined) {
        const nextMenuVisibility = JSON.stringify(normalizeModuleMenuVisibility(updates.menuVisibility));
        try {
          if (dbDriver === 'postgres') {
            await sqlRunAsync('UPDATE site_settings SET menu_visibility_json = ? WHERE id = 1', [nextMenuVisibility]);
          } else {
            await sqlRunAsync('UPDATE site_controls SET menu_visibility_json = ? WHERE id = 1', [nextMenuVisibility]);
          }
        } catch { /* column may not exist yet on older deployments */ }
      }
      if (updates.moduleMenuOrder !== undefined) {
        const nextModuleMenuOrder = JSON.stringify(normalizeModuleMenuOrder(updates.moduleMenuOrder));
        try {
          if (dbDriver === 'postgres') {
            await sqlRunAsync('UPDATE site_settings SET menu_order_json = ? WHERE id = 1', [nextModuleMenuOrder]);
          } else {
            await sqlRunAsync('UPDATE site_controls SET menu_order_json = ? WHERE id = 1', [nextModuleMenuOrder]);
          }
        } catch { /* column may not exist yet on older deployments */ }
      }
      if (updates.activeTheme !== undefined) {
        const validThemes = new Set(['kor', 'atlas', 'vibe', 'zinc', 'ember', 'mist']);
        const nextTheme = String(updates.activeTheme || 'kor').toLowerCase().trim();
        const safeTheme = validThemes.has(nextTheme) ? nextTheme : 'kor';
        try {
          if (dbDriver === 'postgres') {
            await sqlRunAsync('UPDATE site_settings SET active_theme = ? WHERE id = 1', [safeTheme]);
          } else {
            await sqlRunAsync('UPDATE site_controls SET active_theme = ? WHERE id = 1', [safeTheme]);
          }
        } catch { /* column may not exist yet on older deployments */ }
      }
      if (updates.modules && typeof updates.modules === 'object') {
        for (const def of MODULE_DEFINITIONS) {
          if (updates.modules[def.key] === undefined) continue;
          if (dbDriver === 'postgres') {
            await sqlRunAsync(
              `INSERT INTO module_settings (module_key, is_open, updated_at)
               VALUES (?, ?, ?)
               ON CONFLICT(module_key) DO UPDATE SET is_open = excluded.is_open, updated_at = excluded.updated_at`,
              [def.key, updates.modules[def.key] ? true : false, now]
            );
          } else {
            await sqlRunAsync(
              `INSERT INTO module_controls (module_key, is_open, updated_at)
               VALUES (?, ?, ?)
               ON CONFLICT(module_key) DO UPDATE SET is_open = excluded.is_open, updated_at = excluded.updated_at`,
              [def.key, updates.modules[def.key] ? 1 : 0, now]
            );
          }
        }
      }
      invalidateControlSnapshots();
      invalidateCacheNamespace(cacheNamespaces.adminSettings);
      const site = getSiteControl();
      res.json({
        ok: true,
        siteOpen: site.siteOpen,
        maintenanceMessage: site.maintenanceMessage,
        defaultLandingPage: site.defaultLandingPage || '',
        menuVisibility: site.menuVisibility || normalizeModuleMenuVisibility(null),
        moduleMenuOrder: site.moduleMenuOrder || normalizeModuleMenuOrder(null),
        activeTheme: site.activeTheme || 'kor',
        modules: getModuleControlMap()
      });
    } catch (err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.get('/api/admin/media-settings', requireAdmin, async (_req, res) => {
    try {
      const cacheKey = await buildVersionedCacheKey(cacheNamespaces.adminSettings, ['media_settings']);
      const cached = await getCacheJson(cacheKey);
      if (cached && cached.settings) return res.json(cached);
      const settings = await sqlGetAsync('SELECT * FROM media_settings WHERE id = 1');
      const spacesConfigured = !!(process.env.SPACES_KEY && process.env.SPACES_SECRET && process.env.SPACES_BUCKET && process.env.SPACES_ENDPOINT);
      const payload = {
        settings: settings || {},
        spacesConfigured,
        spacesRegion: process.env.SPACES_REGION || '',
        spacesBucket: process.env.SPACES_BUCKET || '',
        spacesEndpoint: process.env.SPACES_ENDPOINT || ''
      };
      await setCacheJson(cacheKey, payload, ADMIN_SETTINGS_CACHE_TTL_SECONDS);
      res.json(payload);
    } catch (err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.put('/api/admin/media-settings', requireAdmin, async (req, res) => {
    try {
      const {
        storage_provider,
        thumb_width,
        feed_width,
        full_width,
        webp_quality,
        max_upload_bytes,
        avif_enabled,
        album_uploads_require_approval
      } = req.body || {};

      if (storage_provider === 'spaces') {
        const hasKeys = !!(process.env.SPACES_KEY && process.env.SPACES_SECRET && process.env.SPACES_BUCKET && process.env.SPACES_ENDPOINT);
        if (!hasKeys) {
          return res.status(400).json({ error: 'Spaces ortam değişkenleri ayarlanmamış. SPACES_KEY, SPACES_SECRET, SPACES_BUCKET, SPACES_ENDPOINT gerekli.' });
        }
      }

      const updates = {};
      if (storage_provider && (storage_provider === 'local' || storage_provider === 'spaces')) updates.storage_provider = storage_provider;
      if (thumb_width && Number(thumb_width) >= 50 && Number(thumb_width) <= 1000) updates.thumb_width = Number(thumb_width);
      if (feed_width && Number(feed_width) >= 200 && Number(feed_width) <= 2000) updates.feed_width = Number(feed_width);
      if (full_width && Number(full_width) >= 400 && Number(full_width) <= 4000) updates.full_width = Number(full_width);
      if (webp_quality && Number(webp_quality) >= 10 && Number(webp_quality) <= 100) updates.webp_quality = Number(webp_quality);
      if (max_upload_bytes && Number(max_upload_bytes) >= 1048576 && Number(max_upload_bytes) <= 52428800) updates.max_upload_bytes = Number(max_upload_bytes);
      if (avif_enabled !== undefined) {
        updates.avif_enabled = dbDriver === 'postgres' ? !!avif_enabled : (avif_enabled ? 1 : 0);
      }
      if (album_uploads_require_approval !== undefined) {
        updates.album_uploads_require_approval = dbDriver === 'postgres'
          ? !!album_uploads_require_approval
          : (album_uploads_require_approval ? 1 : 0);
      }

      const setClauses = Object.keys(updates).map((key) => `${key} = ?`);
      const params = Object.values(updates);
      if (setClauses.length > 0) {
        setClauses.push('updated_at = ?');
        params.push(new Date().toISOString());
        params.push(1);
        await sqlRunAsync(`UPDATE media_settings SET ${setClauses.join(', ')} WHERE id = ?`, params);
      }

      writeAppLog('info', 'media_settings_updated', { userId: req.session?.userId, changes: updates });
      invalidateCacheNamespace(cacheNamespaces.adminSettings);
      const updated = await sqlGetAsync('SELECT * FROM media_settings WHERE id = 1');
      res.json({ ok: true, settings: updated });
    } catch (err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.post('/api/admin/media-settings/test', requireAdmin, async (_req, res) => {
    try {
      const settings = await sqlGetAsync('SELECT * FROM media_settings WHERE id = 1');
      if (!settings || settings.storage_provider !== 'spaces') {
        return res.json({ ok: true, message: 'Yerel depolama aktif, test gerekmez.' });
      }

      try {
        const provider = getStorageProvider(settings, uploadsDir);
        if (provider instanceof SpacesStorageProvider) {
          const result = await provider.testConnection();
          return res.json(result);
        }
        res.json({ ok: true, message: 'Yerel depolama aktif.' });
      } catch (err) {
        res.json({ ok: false, error: err?.message || 'Bağlantı testi başarısız.' });
      }
    } catch (err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.get('/api/admin/auth-settings', requireAdmin, async (_req, res) => {
    try {
      if (!authSecurity?.readAuthSecuritySettings) {
        return res.status(503).json({ ok: false, message: 'Auth ayarları kullanılamıyor.' });
      }
      const settings = await authSecurity.readAuthSecuritySettings();
      res.json({ ok: true, settings });
    } catch (err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.put('/api/admin/auth-settings', requireAdmin, async (req, res) => {
    try {
      if (!authSecurity?.updateAuthSecuritySettings) {
        return res.status(503).json({ ok: false, message: 'Auth ayarları kullanılamıyor.' });
      }
      const settings = await authSecurity.updateAuthSecuritySettings({
        smsVerificationEnabled: !!req.body?.smsVerificationEnabled
      });
      writeAppLog('info', 'auth_settings_updated', {
        userId: req.session?.userId,
        smsVerificationEnabled: settings.smsVerificationEnabled
      });
      res.json({ ok: true, settings });
    } catch (err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.post('/api/upload-image', requireAuth, uploadRateLimit, imageUpload.single('image'), async (req, res) => {
    if (!req.file) return res.status(400).send('Görsel seçilmedi.');
    try {
      const quotaOk = await enforceUploadQuota(req, res, {
        fileSize: Number(req.file.size || 0),
        bucket: 'generic_image'
      });
      if (!quotaOk) return res.status(429).send('Günlük yükleme kotan doldu. Lütfen daha sonra tekrar dene.');

      const entityType = String(req.body?.entityType || 'misc');
      const entityId = req.body?.entityId || '0';
      const result = await processUpload({
        buffer: req.file.buffer,
        mimeType: req.file.mimetype,
        userId: req.session.userId,
        entityType,
        entityId,
        sqlGet,
        sqlRun,
        uploadsDir,
        writeAppLog
      });
      res.json(result);
    } catch (err) {
      writeAppLog('error', 'upload_image_failed', {
        userId: req.session?.userId || null,
        message: err?.message || 'unknown'
      });
      const status = err?.message?.includes('Desteklenmeyen') || err?.message?.includes('boyut') ? 400 : 500;
      return res.status(status).send(err?.message || 'Görsel yükleme başarısız.');
    }
  });

  app.get('/api/admin/users/lists', requireAdmin, async (req, res) => {
    try {
      res.json(await queryAdminUsers({
        ...req.query,
        currentUser: req.authUser || req.adminUser
      }));
    } catch (err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.get('/api/admin/users/search', requireAdmin, async (req, res) => {
    try {
      const query = String(req.query.q || '').trim();
      const onlyWithPhoto = String(req.query.res || '') === '1';
      if (!query && !onlyWithPhoto) return res.status(400).send('Aranacak anahtar kelime girmedin.');
      const result = await queryAdminUsers({
        ...req.query,
        currentUser: req.authUser || req.adminUser,
        q: query,
        photo: onlyWithPhoto ? '1' : req.query.photo,
        filter: 'all',
        limit: req.query.limit || 800,
        sort: req.query.sort || 'engagement_desc'
      });
      res.json(result);
    } catch (err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  async function handleMemberJourney(req, res) {
    try {
      const userId = Number(req.params.id || 0);
      if (!userId) return res.status(400).send('Geçersiz kullanıcı ID.');
      const target = await sqlGetAsync('SELECT id, role FROM uyeler WHERE id = ?', [userId]);
      if (!target) return res.status(404).send('Böyle bir üye bulunmamaktadır.');
      const actorRole = getUserRole(req.authUser || req.adminUser);
      if (normalizeRole(target.role) === 'root' && actorRole !== 'root') {
        return res.status(403).send('Root kullanıcı yolculuğuna erişemezsiniz.');
      }
      const snapshot = await readAdminMemberJourney(userId);
      if (!snapshot) return res.status(404).send('Böyle bir üye bulunmamaktadır.');
      logAdminAction(req, 'member_journey_viewed', {
        targetType: 'user',
        targetId: String(userId)
      });
      res.json(snapshot);
    } catch (err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  }

  app.get('/api/admin/members/:id/journey', requireAdmin, handleMemberJourney);
  app.get('/api/admin/users/:id/journey', requireAdmin, handleMemberJourney);

  app.get('/api/admin/users/:id', requireAdmin, async (req, res) => {
    try {
      const userId = Number(req.params.id || 0);
      if (!userId) return res.status(400).send('Geçersiz kullanıcı ID.');
      const actorRole = getUserRole(req.authUser || req.adminUser);
      const targetRole = normalizeRole((await sqlGetAsync('SELECT role FROM uyeler WHERE id = ?', [userId]))?.role);
      if (targetRole === 'root' && actorRole !== 'root') {
        return res.status(403).send('Root kullanıcı detayına erişemezsiniz.');
      }
      const user = await sqlGetAsync(
        `SELECT u.id, u.kadi, u.isim, u.soyisim, u.email, u.aktiv, u.yasak, u.online, u.sontarih,
                u.resim, u.verified, u.mezuniyetyili, u.admin, u.role, u.universite, u.sehir, u.meslek,
                u.websitesi, u.imza, u.mailkapali, u.aktivasyon, u.verification_status,
                COALESCE(es.score, 0) AS engagement_score, es.updated_at AS engagement_updated_at,
                CASE
                  WHEN CAST(COALESCE(u.mezuniyetyili, 0) AS INTEGER) BETWEEN 1999 AND 2030 THEN 1
                  ELSE 0
                END AS has_graduation_info
         FROM uyeler u
         LEFT JOIN member_engagement_scores es ON es.user_id = u.id
         WHERE u.id = ?`,
        [userId]
      );
      if (!user) return res.status(404).send('Böyle bir üye bulunmamaktadır.');
      res.json({ user });
    } catch (err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.delete('/api/admin/users/:id', requireAdmin, handleMemberDelete);
  app.delete('/api/new/admin/members/:id', requireAdmin, handleMemberDelete);

  app.put('/api/new/admin/users/:id/graduation-year', requireAdmin, async (req, res) => {
    try {
      const userId = Number(req.params.id || 0);
      if (!userId) return res.status(400).send('Geçersiz kullanıcı ID.');
      const target = await sqlGetAsync('SELECT id, role, mezuniyetyili FROM uyeler WHERE id = ?', [userId]);
      if (!target) return res.status(404).send('Böyle bir üye bulunmamaktadır.');
      const actorRole = getUserRole(req.authUser || req.adminUser);
      if (normalizeRole(target.role) === 'root' && actorRole !== 'root') {
        return res.status(403).send('Root kullanıcının mezuniyet yılı değiştirilemez.');
      }
      const nextYear = normalizeCohortValue(req.body?.mezuniyetyili);
      if (!hasValidGraduationYear(nextYear)) {
        return res.status(400).send(`Mezuniyet yılı ${MIN_GRADUATION_YEAR}-${MAX_GRADUATION_YEAR} aralığında olmalı veya Öğretmen seçilmelidir.`);
      }
      const reason = String(req.body?.reason || '').trim().slice(0, 500);
      if (typeof applyUserGraduationYearChange === 'function') {
        applyUserGraduationYearChange(userId, nextYear, {
          previousYear: target.mezuniyetyili
        });
      } else {
        await sqlRunAsync('UPDATE uyeler SET mezuniyetyili = ? WHERE id = ?', [nextYear, userId]);
      }
      logAdminAction(req, 'user_graduation_year_updated', {
        targetType: 'user',
        targetId: userId,
        previous: String(target.mezuniyetyili || ''),
        next: nextYear,
        reason: reason || undefined
      });
      res.json({ ok: true, userId, mezuniyetyili: nextYear });
    } catch (err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.put('/api/admin/users/:id', requireAdmin, async (req, res) => {
    try {
      const target = await sqlGetAsync('SELECT * FROM uyeler WHERE id = ?', [req.params.id]);
      if (!target) return res.status(404).send('Böyle bir üye bulunmamaktadır.');
      const actorRole = getUserRole(req.authUser || req.adminUser);
      if (normalizeRole(target.role) === 'root' && actorRole !== 'root') {
        return res.status(403).send('Root kullanıcıyı düzenleyemezsiniz.');
      }
      const payload = req.body || {};
      const sifre = String(payload.sifre || '');
      const fields = {
        isim: String(payload.isim || '').trim(),
        soyisim: String(payload.soyisim || '').trim(),
        aktivasyon: String(payload.aktivasyon || '').trim(),
        email: normalizeEmail(payload.email),
        aktiv: Number(payload.aktiv),
        yasak: Number(payload.yasak),
        ilkbd: Number(payload.ilkbd),
        websitesi: String(payload.websitesi || '').trim(),
        imza: String(payload.imza || ''),
        meslek: String(payload.meslek || '').trim(),
        sehir: String(payload.sehir || '').trim(),
        mailkapali: Number(payload.mailkapali),
        hit: Number(payload.hit),
        verified: Number(payload.verified),
        mezuniyetyili: String(payload.mezuniyetyili || '').trim(),
        universite: String(payload.universite || '').trim(),
        dogumgun: String(payload.dogumgun || '').trim(),
        dogumay: String(payload.dogumay || '').trim(),
        dogumyil: String(payload.dogumyil || '').trim(),
        resim: String(payload.resim || '').trim() || 'yok'
      };

      if (!fields.isim) return res.status(400).send('İsmini girmedin.');
      if (!fields.soyisim) return res.status(400).send('Soyisim girmedin.');
      if (!fields.aktivasyon) return res.status(400).send('Aktivasyon Kodu girmedin.');
      if (!fields.email) return res.status(400).send('E-mail girmedin.');
      if (!validateEmail(fields.email)) return res.status(400).send('E-mail adresi doğru görünmüyor.');
      const numericFields = ['aktiv', 'yasak', 'ilkbd', 'mailkapali', 'hit', 'verified'];
      for (const key of numericFields) {
        if (Number.isNaN(fields[key])) return res.status(400).send(`${key} bir sayı olmalıdır.`);
      }

      if (String(req.adminUser.id) === '1') {
        if (!sifre) return res.status(400).send('Şifre girmedin.');
        await sqlRunAsync('UPDATE uyeler SET sifre = ? WHERE id = ?', [sifre, target.id]);
      }

      await sqlRunAsync(
        `UPDATE uyeler
         SET isim = ?, soyisim = ?, aktivasyon = ?, email = ?, aktiv = ?, yasak = ?, ilkbd = ?, websitesi = ?,
             imza = ?, meslek = ?, sehir = ?, mailkapali = ?, hit = ?, mezuniyetyili = ?, universite = ?,
             dogumgun = ?, dogumay = ?, dogumyil = ?, verified = ?, resim = ?
         WHERE id = ?`,
        [
          fields.isim, fields.soyisim, fields.aktivasyon, fields.email, fields.aktiv, fields.yasak, fields.ilkbd,
          fields.websitesi, fields.imza, fields.meslek, fields.sehir, fields.mailkapali, fields.hit,
          fields.mezuniyetyili, fields.universite, fields.dogumgun, fields.dogumay, fields.dogumyil,
          fields.verified, fields.resim, target.id
        ]
      );
      if (
        typeof applyUserGraduationYearChange === 'function'
        && normalizeCohortValue(target.mezuniyetyili) !== normalizeCohortValue(fields.mezuniyetyili)
      ) {
        applyUserGraduationYearChange(target.id, fields.mezuniyetyili, {
          previousYear: target.mezuniyetyili
        });
      }
      scheduleEngagementRecalculation('admin_user_updated');
      res.json({ ok: true });
    } catch (err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.get('/api/admin/pages', requireAdmin, async (_req, res) => {
    try {
      const pages = await sqlAllAsync('SELECT * FROM sayfalar ORDER BY sayfaismi');
      res.json({ pages });
    } catch (err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.post('/api/admin/pages', requireAdmin, async (req, res) => {
    try {
      const body = req.body || {};
      const sayfaismi = String(body.sayfaismi || '').trim();
      const sayfaurl = String(body.sayfaurl || '').trim();
      const babaid = String(body.babaid || '0').trim();
      const menugorun = Number(body.menugorun);
      const yonlendir = Number(body.yonlendir);
      const mozellik = Number(body.mozellik);
      const resim = String(body.resim || '').trim();
      if (!sayfaismi) return res.status(400).send('Sayfa ismini girmedin.');
      if (!sayfaurl) return res.status(400).send('Sayfa adresini girmedin.');
      if (Number.isNaN(Number(babaid))) return res.status(400).send('BabaID bir sayı olmalıdır.');
      if (!resim) return res.status(400).send('Resim girmedin. Eğer resim yoksa yok yazmalısın.');
      await sqlRunAsync(
        `INSERT INTO sayfalar (sayfaismi, sayfaurl, babaid, menugorun, yonlendir, mozellik, resim)
         VALUES (?, ?, ?, ?, ?, ?, ?)`,
        [sayfaismi, sayfaurl, Number(babaid), menugorun, yonlendir, mozellik, resim]
      );
      res.json({ ok: true });
    } catch (err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.put('/api/admin/pages/:id', requireAdmin, async (req, res) => {
    try {
      const body = req.body || {};
      const sayfaismi = String(body.sayfaismi || '').trim();
      const sayfaurl = String(body.sayfaurl || '').trim();
      const babaid = String(body.babaid || '0').trim();
      const menugorun = Number(body.menugorun);
      const yonlendir = Number(body.yonlendir);
      const mozellik = Number(body.mozellik);
      const resim = String(body.resim || '').trim();
      if (!sayfaismi) return res.status(400).send('Sayfa ismini girmedin.');
      if (!sayfaurl) return res.status(400).send('Sayfa adresini girmedin.');
      if (Number.isNaN(Number(babaid))) return res.status(400).send('BabaID bir sayı olmalıdır.');
      if (!resim) return res.status(400).send('Resim girmedin. Eğer resim yoksa yok yazmalısın.');
      await sqlRunAsync(
        `UPDATE sayfalar SET sayfaismi = ?, sayfaurl = ?, babaid = ?, menugorun = ?, yonlendir = ?, mozellik = ?, resim = ?
         WHERE id = ?`,
        [sayfaismi, sayfaurl, Number(babaid), menugorun, yonlendir, mozellik, resim, req.params.id]
      );
      res.json({ ok: true });
    } catch (err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.delete('/api/admin/pages/:id', requireAdmin, async (req, res) => {
    try {
      await sqlRunAsync('DELETE FROM sayfalar WHERE id = ?', [req.params.id]);
      res.json({ ok: true });
    } catch (err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.get('/api/admin/logs', requireAdmin, (req, res) => {
    try {
      const type = String(req.query.type || 'error');
      const file = req.query.file;
      const map = {
        error: hatalogDir,
        page: sayfalogDir,
        member: uyedetaylogDir,
        app: appLogsDir
      };
      const dir = map[type] || hatalogDir;
      if (type === 'app' && !fs.existsSync(appLogFile)) {
        fs.writeFileSync(appLogFile, '', 'utf-8');
      }
      const from = parseDateInput(req.query.from || req.query.date_from);
      const to = parseDateInput(req.query.to || req.query.date_to);
      if (file) {
        const content = readLogFile(dir, file);
        if (!content) return res.status(404).send('Dosya Bulunamadı!');
        const filtered = filterLogContent(content, req.query || {});
        return res.json({
          file,
          content: filtered.content,
          total: filtered.total,
          matched: filtered.matched,
          returned: filtered.returned,
          offset: filtered.offset,
          limit: filtered.limit
        });
      }
      let files = listLogFiles(dir);
      if (from || to) {
        files = files.filter((fileItem) => {
          const d = new Date(fileItem.mtime);
          if (from && d < from) return false;
          if (to && d > to) return false;
          return true;
        });
      }
      res.json({ files });
    } catch (err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.post('/api/admin/email/send', requireAdmin, async (req, res) => {
    try {
      const { to, from, subject, html } = req.body || {};
      if (!to) return res.status(400).send('E-Mailin kime gideceğini girmedin.');
      if (!from) return res.status(400).send('E-Mailin kimden gideceğini girmedin.');
      if (!subject) return res.status(400).send('E-Mailin konusunu girmedin.');
      if (!html) return res.status(400).send('E-Mailin metnini girmedin.');
      await queueEmailDelivery({ to, subject, html, from }, { maxAttempts: 4, backoffMs: 1500 });
      res.json({ ok: true });
    } catch (err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.get('/api/admin/email/categories', requireAdmin, async (_req, res) => {
    try {
      const rows = await sqlAllAsync('SELECT * FROM email_kategori ORDER BY id DESC');
      res.json({ categories: rows });
    } catch (err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.post('/api/admin/email/categories', requireAdmin, async (req, res) => {
    try {
      const ad = String(req.body?.ad || '').trim();
      const tur = String(req.body?.tur || '').trim();
      const deger = String(req.body?.deger || '').trim();
      const aciklama = String(req.body?.aciklama || '').trim();
      if (!ad) return res.status(400).send('Kategori adı girmedin.');
      if (!tur) return res.status(400).send('Kategori türü girmedin.');
      await sqlRunAsync('INSERT INTO email_kategori (ad, tur, deger, aciklama) VALUES (?, ?, ?, ?)', [ad, tur, deger, aciklama]);
      res.json({ ok: true });
    } catch (err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.put('/api/admin/email/categories/:id', requireAdmin, async (req, res) => {
    try {
      const ad = String(req.body?.ad || '').trim();
      const tur = String(req.body?.tur || '').trim();
      const deger = String(req.body?.deger || '').trim();
      const aciklama = String(req.body?.aciklama || '').trim();
      if (!ad) return res.status(400).send('Kategori adı girmedin.');
      if (!tur) return res.status(400).send('Kategori türü girmedin.');
      await sqlRunAsync('UPDATE email_kategori SET ad = ?, tur = ?, deger = ?, aciklama = ? WHERE id = ?', [ad, tur, deger, aciklama, req.params.id]);
      res.json({ ok: true });
    } catch (err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.delete('/api/admin/email/categories/:id', requireAdmin, async (req, res) => {
    try {
      await sqlRunAsync('DELETE FROM email_kategori WHERE id = ?', [req.params.id]);
      res.json({ ok: true });
    } catch (err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.get('/api/admin/email/templates', requireAdmin, async (_req, res) => {
    try {
      const rows = await sqlAllAsync('SELECT * FROM email_sablon ORDER BY id DESC');
      res.json({ templates: rows });
    } catch (err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.post('/api/admin/email/templates', requireAdmin, async (req, res) => {
    try {
      const ad = String(req.body?.ad || '').trim();
      const konu = String(req.body?.konu || '').trim();
      const icerik = String(req.body?.icerik || '').trim();
      if (!ad) return res.status(400).send('Şablon adı girmedin.');
      if (!konu) return res.status(400).send('Konu girmedin.');
      if (!icerik) return res.status(400).send('İçerik girmedin.');
      await sqlRunAsync('INSERT INTO email_sablon (ad, konu, icerik, olusturma) VALUES (?, ?, ?, ?)', [ad, konu, icerik, new Date().toISOString()]);
      res.json({ ok: true });
    } catch (err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.put('/api/admin/email/templates/:id', requireAdmin, async (req, res) => {
    try {
      const ad = String(req.body?.ad || '').trim();
      const konu = String(req.body?.konu || '').trim();
      const icerik = String(req.body?.icerik || '').trim();
      if (!ad) return res.status(400).send('Şablon adı girmedin.');
      if (!konu) return res.status(400).send('Konu girmedin.');
      if (!icerik) return res.status(400).send('İçerik girmedin.');
      await sqlRunAsync('UPDATE email_sablon SET ad = ?, konu = ?, icerik = ? WHERE id = ?', [ad, konu, icerik, req.params.id]);
      res.json({ ok: true });
    } catch (err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.delete('/api/admin/email/templates/:id', requireAdmin, async (req, res) => {
    try {
      await sqlRunAsync('DELETE FROM email_sablon WHERE id = ?', [req.params.id]);
      res.json({ ok: true });
    } catch (err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.post('/api/admin/email/bulk', requireAdmin, async (req, res) => {
    try {
      const { categoryId, subject, html, from } = req.body || {};
      if (!categoryId) return res.status(400).send('Kategori seçmelisin.');
      if (!subject) return res.status(400).send('Konu girmedin.');
      if (!html) return res.status(400).send('İçerik girmedin.');

      const cat = await sqlGetAsync('SELECT * FROM email_kategori WHERE id = ?', [categoryId]);
      if (!cat) return res.status(400).send('Kategori bulunamadı.');

      let recipients = [];
      if (cat.tur === 'all') {
        recipients = await sqlAllAsync('SELECT email FROM uyeler WHERE email IS NOT NULL AND email <> ""');
      } else if (cat.tur === 'active') {
        recipients = await sqlAllAsync('SELECT email FROM uyeler WHERE aktiv = 1 AND yasak = 0 AND email IS NOT NULL AND email <> ""');
      } else if (cat.tur === 'pending') {
        recipients = await sqlAllAsync('SELECT email FROM uyeler WHERE aktiv = 0 AND yasak = 0 AND email IS NOT NULL AND email <> ""');
      } else if (cat.tur === 'banned') {
        recipients = await sqlAllAsync('SELECT email FROM uyeler WHERE yasak = 1 AND email IS NOT NULL AND email <> ""');
      } else if (cat.tur === 'year') {
        recipients = await sqlAllAsync('SELECT email FROM uyeler WHERE mezuniyetyili = ? AND email IS NOT NULL AND email <> ""', [cat.deger]);
      } else if (cat.tur === 'custom') {
        recipients = extractEmails(cat.deger).map((email) => ({ email }));
      }

      if (!recipients.length) return res.status(400).send('Gönderilecek e-mail bulunamadı.');
      for (const row of recipients) {
        if (!row.email || !validateEmail(row.email)) continue;
        await queueEmailDelivery({ to: row.email, subject, html, from }, { maxAttempts: 4, backoffMs: 1500 });
      }
      res.json({ ok: true, count: recipients.length });
    } catch (err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.get('/api/admin/album/categories', requireAlbumAdmin, async (_req, res) => {
    try {
      const cats = await sqlAllAsync('SELECT * FROM album_kat ORDER BY aktif DESC');
      const countRows = await sqlAllAsync(
        `SELECT katid,
                SUM(CASE WHEN ${albumActivePredicate} THEN 1 ELSE 0 END) AS active_count,
                SUM(CASE WHEN ${albumInactivePredicate} THEN 1 ELSE 0 END) AS inactive_count
         FROM album_foto
         GROUP BY katid`
      );
      const countMap = new Map(countRows.map((row) => [String(row.katid), {
        activeCount: Number(row.active_count || 0),
        inactiveCount: Number(row.inactive_count || 0)
      }]));
      const counts = {};
      for (const cat of cats) {
        counts[cat.id] = countMap.get(String(cat.id)) || { activeCount: 0, inactiveCount: 0 };
      }
      res.json({ categories: cats, counts });
    } catch (err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.post('/api/admin/album/categories', requireAlbumAdmin, async (req, res) => {
    try {
      const kategori = String(req.body?.kategori || '').trim();
      const aciklama = String(req.body?.aciklama || '').trim();
      const aktif = albumActiveParam(req.body?.aktif);
      if (!kategori) return res.status(400).send('Kategori girmedin.');
      if (!aciklama) return res.status(400).send('Açıklama girmedin.');
      const existing = await sqlGetAsync('SELECT id FROM album_kat WHERE kategori = ?', [kategori]);
      if (existing) return res.status(400).send('Girdiğin kategori ismi zaten kayıtlı.');
      await sqlRunAsync(
        'INSERT INTO album_kat (kategori, aciklama, ilktarih, aktif) VALUES (?, ?, ?, ?)',
        [kategori, aciklama, new Date().toISOString(), aktif]
      );
      res.json({ ok: true });
    } catch (err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.put('/api/admin/album/categories/:id', requireAlbumAdmin, async (req, res) => {
    try {
      const kategori = String(req.body?.kategori || '').trim();
      const aciklama = String(req.body?.aciklama || '').trim();
      const aktif = albumActiveParam(req.body?.aktif);
      if (!kategori) return res.status(400).send('Bir kategori adı girmedin.');
      if (!aciklama) return res.status(400).send('Bir açıklama girmedin.');
      const dup = await sqlGetAsync('SELECT id, kategori FROM album_kat WHERE kategori = ?', [kategori]);
      if (dup && String(dup.id) !== String(req.params.id)) {
        return res.status(400).send('Böyle bir kategori zaten kayıtlı!');
      }
      await sqlRunAsync('UPDATE album_kat SET kategori = ?, aciklama = ?, aktif = ? WHERE id = ?', [kategori, aciklama, aktif, req.params.id]);
      res.json({ ok: true });
    } catch (err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.delete('/api/admin/album/categories/:id', requireAlbumAdmin, async (req, res) => {
    try {
      const hasPhotos = await sqlGetAsync('SELECT id FROM album_foto WHERE katid = ? LIMIT 1', [req.params.id]);
      if (hasPhotos) return res.status(400).send('Kategori boş değil. Önce fotoğrafları silmelisiniz.');
      await sqlRunAsync('DELETE FROM album_kat WHERE id = ?', [req.params.id]);
      res.json({ ok: true });
    } catch (err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.get('/api/admin/album/photos', requireAlbumAdmin, async (req, res) => {
    try {
      const krt = String(req.query.krt || '');
      const kid = String(req.query.kid || '');
      const diz = String(req.query.diz || '');
      const q = String(req.query.q || '').trim();
      const userId = Number(req.query.userId || req.query.user_id || 0);
      const cohort = String(req.query.cohort || req.query.graduationYear || '').trim();
      const whereParts = [];
      let params = [];
      if (krt === 'onaybekleyen') {
        whereParts.push(albumInactivePredicate);
      } else if (krt === 'kategori' && kid) {
        whereParts.push('f.katid = ?');
        params.push(kid);
      }
      if (userId) {
        whereParts.push('CAST(f.ekleyenid AS INTEGER) = CAST(? AS INTEGER)');
        params.push(userId);
      }
      if (cohort) {
        whereParts.push("CAST(COALESCE(u.mezuniyetyili, '') AS TEXT) = ?");
        params.push(cohort);
      }
      if (q) {
        whereParts.push('(LOWER(CAST(f.baslik AS TEXT)) LIKE LOWER(?) OR LOWER(CAST(f.aciklama AS TEXT)) LIKE LOWER(?) OR LOWER(CAST(u.kadi AS TEXT)) LIKE LOWER(?))');
        params.push(`%${q}%`, `%${q}%`, `%${q}%`);
      }
      const where = whereParts.length ? `WHERE ${whereParts.join(' AND ')}` : '';
      const orderMap = {
        baslikartan: 'baslik',
        baslikazalan: 'baslik DESC',
        acikartan: 'aciklama',
        acikazalan: 'aciklama DESC',
        aktifartan: 'aktif',
        aktifazalan: 'aktif DESC',
        ekleyenartan: 'ekleyenid',
        ekleyenazalan: 'ekleyenid DESC',
        tarihartan: 'tarih',
        tarihazalan: 'tarih DESC',
        hitartan: 'hit',
        hitazalan: 'hit DESC'
      };
      const orderBy = orderMap[diz] || 'aktif DESC';
      const photos = await sqlAllAsync(
        `SELECT f.*, u.kadi AS uploader_kadi, u.isim AS uploader_isim, u.soyisim AS uploader_soyisim,
                u.resim AS uploader_resim, u.mezuniyetyili AS uploader_mezuniyetyili
         FROM album_foto f
         LEFT JOIN uyeler u ON CAST(u.id AS INTEGER) = CAST(f.ekleyenid AS INTEGER)
         ${where}
         ORDER BY f.${orderBy}`,
        params
      );
      const categories = await sqlAllAsync('SELECT * FROM album_kat');
      const uploaderIds = Array.from(new Set(photos.map((photo) => Number(photo.ekleyenid || 0)).filter((id) => Number.isInteger(id) && id > 0)));
      const photoIds = Array.from(new Set(photos.map((photo) => Number(photo.id || 0)).filter((id) => Number.isInteger(id) && id > 0)));
      const uploaderRows = uploaderIds.length
        ? await sqlAllAsync(
          `SELECT id, kadi, isim, soyisim, resim, mezuniyetyili
           FROM uyeler
           WHERE id IN (${uploaderIds.map(() => '?').join(',')})`,
          uploaderIds
        )
        : [];
      const commentRows = photoIds.length
        ? await sqlAllAsync(
          `SELECT fotoid, COUNT(*) AS c
           FROM album_fotoyorum
           WHERE fotoid IN (${photoIds.map(() => '?').join(',')})
           GROUP BY fotoid`,
          photoIds
        )
        : [];
      const userMap = {};
      for (const user of uploaderRows) {
        userMap[user.id] = user.kadi;
      }
      const commentCountMap = new Map(commentRows.map((row) => [String(row.fotoid), Number(row.c || 0)]));
      const commentCounts = {};
      for (const photo of photos) {
        commentCounts[photo.id] = commentCountMap.get(String(photo.id)) || 0;
      }
      res.json({ photos, categories, userMap, commentCounts });
    } catch (err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.post('/api/admin/album/photos/bulk', requireAlbumAdmin, async (req, res) => {
    try {
      const { ids = [], action } = req.body || {};
      if (!Array.isArray(ids) || !ids.length) return res.status(400).send('Fotoğraf seçmelisiniz.');
      const safeIds = ids.map((id) => Number(id)).filter((id) => Number.isFinite(id) && id > 0);
      if (!safeIds.length) return res.status(400).send('Geçerli fotoğraf ID bulunamadı.');
      if (action === 'sil') {
        const placeholders = safeIds.map(() => '?').join(',');
        const photos = await sqlAllAsync(`SELECT id, dosyaadi FROM album_foto WHERE id IN (${placeholders})`, safeIds);
        for (const photo of photos) {
          if (!photo.dosyaadi) continue;
          const filePath = path.join(uploadsDir, 'album', photo.dosyaadi);
          if (fs.existsSync(filePath)) {
            try { fs.unlinkSync(filePath); } catch {}
          }
        }
        await sqlRunAsync(`DELETE FROM album_fotoyorum WHERE fotoid IN (${placeholders})`, safeIds);
        await sqlRunAsync(`DELETE FROM album_foto WHERE id IN (${placeholders})`, safeIds);
        return res.json({ ok: true, deleted: photos.length });
      }
      const activeValue = albumActiveParam(action !== 'deaktiv');
      const placeholders = safeIds.map(() => '?').join(',');
      await sqlRunAsync(`UPDATE album_foto SET aktif = ? WHERE id IN (${placeholders})`, [activeValue, ...safeIds]);
      res.json({ ok: true });
    } catch (err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.put('/api/admin/album/photos/:id', requireAlbumAdmin, async (req, res) => {
    try {
      const baslik = sanitizePlainUserText(String(req.body?.baslik || '').trim(), 255);
      const aciklama = formatUserText(req.body?.aciklama || '');
      const aktif = albumActiveParam(req.body?.aktif);
      const katid = String(req.body?.katid || '').trim();
      await sqlRunAsync(
        'UPDATE album_foto SET baslik = ?, aciklama = ?, aktif = ?, katid = ? WHERE id = ?',
        [baslik, aciklama, aktif, katid, req.params.id]
      );
      res.json({ ok: true });
    } catch (err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.delete('/api/admin/album/photos/:id', requireAlbumAdmin, async (req, res) => {
    try {
      const photo = await sqlGetAsync('SELECT * FROM album_foto WHERE id = ?', [req.params.id]);
      if (!photo) return res.status(404).send('Böyle bir fotoğraf yok.');
      const albumDir = path.join(uploadsDir, 'album');
      const filePath = path.join(albumDir, photo.dosyaadi || '');
      if (photo.dosyaadi && fs.existsSync(filePath)) {
        try { fs.unlinkSync(filePath); } catch {}
      }
      await sqlRunAsync('DELETE FROM album_fotoyorum WHERE fotoid = ?', [req.params.id]);
      await sqlRunAsync('DELETE FROM album_foto WHERE id = ?', [req.params.id]);
      res.json({ ok: true });
    } catch (err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.get('/api/admin/album/photos/:id/comments', requireAlbumAdmin, async (req, res) => {
    try {
      const comments = await sqlAllAsync('SELECT * FROM album_fotoyorum WHERE fotoid = ?', [req.params.id]);
      res.json({ comments });
    } catch (err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.delete('/api/admin/album/photos/:id/comments/:commentId', requireAlbumAdmin, async (req, res) => {
    try {
      await sqlRunAsync('DELETE FROM album_fotoyorum WHERE id = ?', [req.params.commentId]);
      res.json({ ok: true });
    } catch (err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.get('/api/admin/tournament', requireAdmin, async (_req, res) => {
    try {
      const teams = await sqlAllAsync('SELECT * FROM takimlar ORDER BY tarih DESC');
      res.json({ teams });
    } catch (err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.delete('/api/admin/tournament/:id', requireAdmin, async (req, res) => {
    try {
      await sqlRunAsync('DELETE FROM takimlar WHERE id = ?', [req.params.id]);
      res.json({ ok: true });
    } catch (err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });
}
