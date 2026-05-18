// Postgres uses `user_follows` (table) + `follows` view.
// SQLite uses `follows` (table) — `user_follows` does not exist.
// connection_requests is created by ensureConnectionRequestsTable() at networking runtime startup,
// but may be absent on fresh SQLite installs; we call ensure here to guarantee it.

export function registerAdminNetworkingRoutes(app, {
  dbDriver,
  requireAdmin,
  sqlAllAsync,
  sqlRunAsync,
  parseAdminListPagination,
  normalizeCohortValue,
  logAdminAction,
  ensureConnectionRequestsTable,
}) {
  const isPostgres = dbDriver === 'postgres';

  // On SQLite, connection_requests may not exist yet — create it safely.
  if (!isPostgres) {
    try { ensureConnectionRequestsTable(); } catch { /* ignore on startup */ }
  }

  // Primary follows table per driver.
  const followsTable = isPostgres ? 'user_follows' : 'follows';
  // Fallback for Postgres: `follows` is a view of `user_follows`; for SQLite: only `follows` exists.
  const followsFallback = isPostgres ? 'follows' : null;

  async function safeAll(sql, params = []) {
    try {
      return (await sqlAllAsync(sql, params)) || [];
    } catch {
      return [];
    }
  }

  // Try primary table, then fallback if primary returns empty or fails.
  async function queryFollows(buildFn, filters) {
    const primary = buildFn(followsTable, filters);
    const rows = await safeAll(primary.sql, primary.params);
    if (rows.length > 0 || !followsFallback) return rows;
    const fallback = buildFn(followsFallback, filters);
    return safeAll(fallback.sql, fallback.params);
  }

  async function countFollowsQuery(filters) {
    const { q, userId, cohort } = filters;
    const where = [];
    const params = [];
    if (userId) {
      where.push('(uf.follower_id = ? OR uf.following_id = ?)');
      params.push(userId, userId);
    }
    if (cohort) {
      const c = normalizeCohortValue(cohort);
      if (c) {
        where.push('(CAST(fr.mezuniyetyili AS TEXT) = ? OR CAST(fi.mezuniyetyili AS TEXT) = ?)');
        params.push(c, c);
      }
    }
    if (q) {
      where.push('(fr.kadi LIKE ? OR fi.kadi LIKE ? OR fr.isim LIKE ? OR fi.isim LIKE ?)');
      const like = `%${q}%`;
      params.push(like, like, like, like);
    }
    const whereClause = where.length ? `WHERE ${where.join(' AND ')}` : '';
    const countSql = (tbl) => `
      SELECT COUNT(*) AS cnt
      FROM ${tbl} uf
      LEFT JOIN uyeler fr ON fr.id = uf.follower_id
      LEFT JOIN uyeler fi ON fi.id = uf.following_id
      ${whereClause}
    `;
    const rows = await safeAll(countSql(followsTable), params);
    const n = Number(rows[0]?.cnt ?? 0);
    // If primary has 0 AND it succeeded (not a missing-table error), return 0 directly.
    // Use fallback only if followsFallback is set (Postgres where `follows` view may differ).
    if (n > 0 || !followsFallback) return n;
    const fb = await safeAll(countSql(followsFallback), params);
    return Number(fb[0]?.cnt ?? 0);
  }

  function buildFollowsListQuery(tableName, { q, userId, cohort, limit, offset }) {
    const where = [];
    const params = [];
    if (userId) {
      where.push('(uf.follower_id = ? OR uf.following_id = ?)');
      params.push(userId, userId);
    }
    if (cohort) {
      const c = normalizeCohortValue(cohort);
      if (c) {
        where.push('(CAST(fr.mezuniyetyili AS TEXT) = ? OR CAST(fi.mezuniyetyili AS TEXT) = ?)');
        params.push(c, c);
      }
    }
    if (q) {
      where.push('(fr.kadi LIKE ? OR fi.kadi LIKE ? OR fr.isim LIKE ? OR fi.isim LIKE ?)');
      const like = `%${q}%`;
      params.push(like, like, like, like);
    }
    const whereClause = where.length ? `WHERE ${where.join(' AND ')}` : '';
    const sql = `
      SELECT
        uf.id,
        uf.follower_id,
        uf.following_id,
        COALESCE(fr.kadi,     '') AS follower_kadi,
        COALESCE(fr.isim,     '') AS follower_isim,
        COALESCE(fr.soyisim,  '') AS follower_soyisim,
        COALESCE(fr.resim,    '') AS follower_resim,
        CAST(COALESCE(fr.mezuniyetyili, 0) AS TEXT) AS follower_cohort,
        COALESCE(fi.kadi,     '') AS following_kadi,
        COALESCE(fi.isim,     '') AS following_isim,
        COALESCE(fi.soyisim,  '') AS following_soyisim,
        COALESCE(uf.created_at, '') AS created_at
      FROM ${tableName} uf
      LEFT JOIN uyeler fr ON fr.id = uf.follower_id
      LEFT JOIN uyeler fi ON fi.id = uf.following_id
      ${whereClause}
      ORDER BY uf.created_at DESC
      LIMIT ? OFFSET ?
    `;
    params.push(limit, offset);
    return { sql, params };
  }

  // GET /api/new/admin/follows
  app.get('/api/new/admin/follows', requireAdmin, async (req, res) => {
    try {
      const { page, limit } = parseAdminListPagination(req.query, { defaultLimit: 40, maxLimit: 200 });
      const offset = (page - 1) * limit;
      const q = String(req.query.q || '').trim();
      const userId = Number(req.query.userId || req.query.user_id || 0);
      const cohort = String(req.query.cohort || '').trim();
      const filters = { q, userId, cohort, limit, offset };

      const [rows, total] = await Promise.all([
        queryFollows(buildFollowsListQuery, filters),
        countFollowsQuery(filters),
      ]);

      const items = rows.map((r) => ({
        id: r.id,
        follower_id: r.follower_id,
        following_id: r.following_id,
        kadi: r.follower_kadi,
        isim: r.follower_isim,
        soyisim: r.follower_soyisim,
        resim: r.follower_resim,
        title: `@${r.follower_kadi || r.follower_isim || r.follower_id} → @${r.following_kadi || r.following_isim || r.following_id}`,
        message: r.follower_cohort && r.follower_cohort !== '0' ? `Cohort ${r.follower_cohort}` : '',
        created_at: r.created_at,
      }));

      res.json({ total, items, page, limit });
    } catch (err) {
      console.error('[adminNetworking] follows GET error:', err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  // DELETE /api/new/admin/follows/:id
  // Tries primary table first; falls back to secondary if primary table is missing.
  app.delete('/api/new/admin/follows/:id', requireAdmin, async (req, res) => {
    try {
      const id = Number(req.params.id || 0);
      if (!id) return res.status(400).json({ error: 'Geçersiz ID.' });

      const tables = followsFallback
        ? [followsTable, followsFallback]
        : [followsTable];

      let deleted = false;
      for (const tbl of tables) {
        try {
          await sqlRunAsync(`DELETE FROM ${tbl} WHERE id = ?`, [id]);
          deleted = true;
          break;
        } catch {
          // Table may not exist on this driver; try next.
        }
      }

      if (!deleted) return res.status(404).json({ error: 'Kayıt bulunamadı.' });

      // logAdminAction expects (req, action, details) — non-fatal if it throws.
      try { logAdminAction(req, 'follow_deleted', { targetType: 'follow', targetId: id }); } catch { /* non-fatal */ }

      res.json({ ok: true });
    } catch (err) {
      console.error('[adminNetworking] follows DELETE error:', err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  // GET /api/new/admin/connections
  // connection_requests is guaranteed by ensureConnectionRequestsTable above on SQLite.
  // On Postgres it exists via migration 005.
  app.get('/api/new/admin/connections', requireAdmin, async (req, res) => {
    try {
      if (!isPostgres) {
        // Re-ensure on each request for SQLite in case the table was not created at boot.
        try { ensureConnectionRequestsTable(); } catch { /* ignore */ }
      }

      const { page, limit } = parseAdminListPagination(req.query, { defaultLimit: 40, maxLimit: 200 });
      const offset = (page - 1) * limit;
      const q = String(req.query.q || '').trim();
      const userId = Number(req.query.userId || req.query.user_id || 0);
      const cohort = String(req.query.cohort || '').trim();
      const status = String(req.query.status || '').trim();

      const where = [];
      const params = [];
      if (userId) {
        where.push('(cr.sender_id = ? OR cr.receiver_id = ?)');
        params.push(userId, userId);
      }
      if (cohort) {
        const c = normalizeCohortValue(cohort);
        if (c) {
          where.push('(CAST(su.mezuniyetyili AS TEXT) = ? OR CAST(ru.mezuniyetyili AS TEXT) = ?)');
          params.push(c, c);
        }
      }
      if (status) {
        where.push('cr.status = ?');
        params.push(status);
      }
      if (q) {
        where.push('(su.kadi LIKE ? OR ru.kadi LIKE ? OR su.isim LIKE ? OR ru.isim LIKE ?)');
        const like = `%${q}%`;
        params.push(like, like, like, like);
      }

      const whereClause = where.length ? `WHERE ${where.join(' AND ')}` : '';
      const joinClause = `
        FROM connection_requests cr
        LEFT JOIN uyeler su ON su.id = cr.sender_id
        LEFT JOIN uyeler ru ON ru.id = cr.receiver_id
        ${whereClause}
      `;

      const [rows, countRow] = await Promise.all([
        safeAll(
          `SELECT
             cr.id, cr.sender_id, cr.receiver_id,
             COALESCE(cr.status, 'pending') AS status,
             COALESCE(cr.created_at, '') AS created_at,
             COALESCE(su.kadi,    '') AS sender_kadi,
             COALESCE(su.isim,    '') AS sender_isim,
             COALESCE(su.soyisim, '') AS sender_soyisim,
             COALESCE(su.resim,   '') AS sender_resim,
             COALESCE(ru.kadi,    '') AS receiver_kadi,
             COALESCE(ru.isim,    '') AS receiver_isim,
             COALESCE(ru.soyisim, '') AS receiver_soyisim
           ${joinClause}
           ORDER BY cr.created_at DESC
           LIMIT ? OFFSET ?`,
          [...params, limit, offset]
        ),
        safeAll(`SELECT COUNT(*) AS cnt ${joinClause}`, params),
      ]);

      const total = Number(countRow[0]?.cnt ?? 0);
      const items = rows.map((r) => ({
        id: r.id,
        sender_id: r.sender_id,
        receiver_id: r.receiver_id,
        status: r.status,
        kadi: r.sender_kadi,
        isim: r.sender_isim,
        soyisim: r.sender_soyisim,
        resim: r.sender_resim,
        title: `@${r.sender_kadi || r.sender_id} → @${r.receiver_kadi || r.receiver_id}`,
        message: r.status,
        created_at: r.created_at,
      }));

      res.json({ total, items, page, limit });
    } catch (err) {
      console.error('[adminNetworking] connections GET error:', err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });
}
