export function registerMemberDirectoryRoutes(app, {
  sqlGetAsync,
  sqlAllAsync,
  ensureTeacherAlumniLinksTable,
  getCachedActiveMemberNameRows,
  buildMemberTrustBadges
}) {
  app.get('/api/members', async (req, res) => {
    try {
      if (!req.session.userId) return res.status(401).send('Login required');
      ensureTeacherAlumniLinksTable();
      const page = Math.max(parseInt(req.query.page || '1', 10), 1);
      const pageSize = Math.min(Math.max(parseInt(req.query.pageSize || '10', 10), 1), 50);
      const term = req.query.term ? String(req.query.term).replace(/'/g, '') : '';
      const gradYear = parseInt(String(req.query.gradYear || '0'), 10) || 0;
      const location = req.query.location ? String(req.query.location).trim().toLowerCase() : '';
      const profession = req.query.profession ? String(req.query.profession).trim().toLowerCase() : '';
      const expertise = req.query.expertise ? String(req.query.expertise).trim().toLowerCase() : '';
      const title = req.query.title ? String(req.query.title).trim().toLowerCase() : '';
      const mentorsOnly = String(req.query.mentors || '').trim() === '1';
      const verifiedOnly = String(req.query.verified || '').trim() === '1';
      const withPhoto = String(req.query.withPhoto || '').trim() === '1';
      const onlineOnly = String(req.query.online || '').trim() === '1';
      const relation = String(req.query.relation || '').trim();
      const excludeSelf = String(req.query.excludeSelf || '').trim() === '1';
      const sort = String(req.query.sort || 'recommended').trim();
      const whereParts = [
        'COALESCE(CAST(aktiv AS INTEGER), 1) = 1',
        'COALESCE(CAST(yasak AS INTEGER), 0) = 0'
      ];
      const params = [];
      if (excludeSelf) {
        whereParts.push('id != ?');
        params.push(req.session.userId);
      }
      if (term) {
        whereParts.push('(LOWER(kadi) LIKE LOWER(?) OR LOWER(isim) LIKE LOWER(?) OR LOWER(soyisim) LIKE LOWER(?) OR LOWER(meslek) LIKE LOWER(?) OR LOWER(email) LIKE LOWER(?))');
        params.push(...Array(5).fill(`%${term}%`));
      }
      if (gradYear > 0) {
        whereParts.push('CAST(COALESCE(mezuniyetyili, 0) AS INTEGER) = ?');
        params.push(gradYear);
      }
      if (location) {
        whereParts.push('LOWER(sehir) LIKE ?');
        params.push(`%${location}%`);
      }
      if (profession) {
        whereParts.push('LOWER(meslek) LIKE ?');
        params.push(`%${profession}%`);
      }
      if (expertise) {
        whereParts.push('LOWER(uzmanlik) LIKE ?');
        params.push(`%${expertise}%`);
      }
      if (title) {
        whereParts.push('LOWER(unvan) LIKE ?');
        params.push(`%${title}%`);
      }
      if (mentorsOnly) {
        whereParts.push('COALESCE(CAST(mentor_opt_in AS INTEGER), 0) = 1');
      }
      if (verifiedOnly) {
        whereParts.push('COALESCE(CAST(verified AS INTEGER), 0) = 1');
      }
      if (withPhoto) {
        whereParts.push("resim IS NOT NULL AND TRIM(CAST(resim AS TEXT)) != '' AND LOWER(TRIM(CAST(resim AS TEXT))) != 'yok'");
      }
      if (onlineOnly) {
        whereParts.push('COALESCE(CAST(online AS INTEGER), 0) = 1');
      }
      if (relation === 'following') {
        whereParts.push('id IN (SELECT following_id FROM follows WHERE follower_id = ?)');
        params.push(req.session.userId);
      }
      if (relation === 'not_following') {
        whereParts.push('id NOT IN (SELECT following_id FROM follows WHERE follower_id = ?)');
        params.push(req.session.userId);
      }
      const where = whereParts.join(' AND ');
      const orderByMap = {
        name: 'u.isim ASC, u.soyisim ASC',
        recent: 'u.id DESC',
        online: 'COALESCE(CAST(u.online AS INTEGER), 0) DESC, u.isim ASC',
        year: 'CAST(COALESCE(u.mezuniyetyili, 0) AS INTEGER) DESC, u.isim ASC',
        engagement: 'COALESCE(es.score, 0) DESC, u.id DESC',
        recommended: 'COALESCE(es.score, 0) DESC, COALESCE(CAST(u.online AS INTEGER), 0) DESC, COALESCE(CAST(u.verified AS INTEGER), 0) DESC, u.id DESC'
      };
      const orderBy = orderByMap[sort] || orderByMap.name;

      const totalRow = await sqlGetAsync(`SELECT COUNT(*) AS cnt FROM uyeler WHERE ${where}`, params);
      const total = totalRow ? totalRow.cnt : 0;
      const pages = Math.max(Math.ceil(total / pageSize), 1);
      const safePage = Math.min(page, pages);
      const offset = (safePage - 1) * pageSize;
      const [rows, rangeRows] = await Promise.all([
        sqlAllAsync(
          `SELECT u.id, u.kadi, u.isim, u.soyisim, u.email, u.mailkapali, u.mezuniyetyili, u.dogumgun, u.dogumay, u.dogumyil,
                  u.sehir, u.universite, u.meslek, u.websitesi, u.imza, u.resim, u.online, u.sontarih, u.verified,
                  u.sirket, u.unvan, u.uzmanlik, u.linkedin_url, u.universite_bolum, u.mentor_opt_in, u.mentor_konulari,
                  u.role,
                  CASE WHEN EXISTS (
                    SELECT 1
                    FROM follows f
                    WHERE f.follower_id = ?
                      AND f.following_id = u.id
                  ) THEN 1 ELSE 0 END AS following,
                  CASE WHEN EXISTS (
                    SELECT 1
                    FROM teacher_alumni_links tal
                    WHERE tal.teacher_user_id = u.id OR tal.alumni_user_id = u.id
                  ) THEN 1 ELSE 0 END AS teacher_network_member
           FROM uyeler u
           LEFT JOIN member_engagement_scores es ON es.user_id = u.id
           WHERE ${where}
           ORDER BY ${orderBy}
           LIMIT ? OFFSET ?`,
          [req.session.userId, ...params, pageSize, offset]
        ),
        term ? Promise.resolve([]) : getCachedActiveMemberNameRows()
      ]);

      const ranges = [];
      for (let i = 0; i < rangeRows.length; i += pageSize) {
        const start = rangeRows[i]?.isim ? rangeRows[i].isim.slice(0, 2) : '--';
        const end = rangeRows[Math.min(i + pageSize - 1, rangeRows.length - 1)]?.isim?.slice(0, 2) || '--';
        ranges.push({ start, end });
      }

      const rowsWithTrustBadges = rows.map((row) => ({
        ...row,
        following: Number(row?.following || 0) > 0,
        trust_badges: buildMemberTrustBadges(row)
      }));

      return res.json({
        rows: rowsWithTrustBadges,
        page: safePage,
        pages,
        total,
        ranges,
        pageSize,
        term,
        filters: { gradYear, verifiedOnly, withPhoto, onlineOnly, relation, sort, mentorsOnly }
      });
    } catch (err) {
      console.error('members.list failed:', err);
      return res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.get('/api/members/latest', async (req, res) => {
    try {
      if (!req.session.userId) return res.status(401).send('Login required');
      const limit = Math.min(Math.max(parseInt(req.query.limit || '100', 10), 1), 200);
      const rows = await sqlAllAsync(
        `SELECT id, kadi, isim, soyisim, resim, mezuniyetyili, ilktarih, verified, role,
                CASE WHEN EXISTS (
                  SELECT 1 FROM follows f
                  WHERE f.follower_id = ? AND f.following_id = uyeler.id
                ) THEN 1 ELSE 0 END AS following
         FROM uyeler
         WHERE aktiv = 1 AND yasak = 0
         ORDER BY id DESC
         LIMIT ?`,
        [req.session.userId, limit]
      );
      res.json({ items: rows.map((row) => ({ ...row, following: Number(row?.following || 0) > 0 })) });
    } catch (err) {
      console.error('members.latest failed:', err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.get('/api/members/:id', async (req, res) => {
    try {
      if (!req.session.userId) return res.status(401).send('Login required');
      const row = await sqlGetAsync(
        `SELECT id, kadi, isim, soyisim, email, mailkapali, mezuniyetyili, dogumgun, dogumay, dogumyil,
                sehir, universite, meslek, websitesi, imza, resim, online, sontarih, verified, role,
                sirket, unvan, uzmanlik, linkedin_url, universite_bolum, mentor_opt_in, mentor_konulari,
                CASE WHEN EXISTS (
                  SELECT 1
                  FROM follows f
                  WHERE f.follower_id = ?
                    AND f.following_id = uyeler.id
                ) THEN 1 ELSE 0 END AS following
         FROM uyeler
         WHERE id = ?`,
        [req.session.userId, req.params.id]
      );
      if (!row) return res.status(404).send('Üye bulunamadı');
      return res.json({
        row: {
          ...row,
          following: Number(row?.following || 0) > 0
        }
      });
    } catch (err) {
      console.error('members.detail failed:', err);
      return res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });
}
