import fs from 'fs';
import path from 'path';

export function registerAdminManagementRoutes(app, {
  dbDriver,
  requireAdmin,
  requireAlbumAdmin,
  sqlGet,
  sqlAll,
  sqlRun,
  sqlGetAsync,
  sqlAllAsync,
  sqlRunAsync,
  getUserRole,
  normalizeRole,
  hardDeleteUser,
  uploadsDir,
  writeAppLog,
  normalizeCohortValue,
  hasValidGraduationYear,
  minGraduationYear,
  maxGraduationYear,
  logAdminAction,
  normalizeEmail,
  validateEmail,
  scheduleEngagementRecalculation,
  hatalogDir,
  sayfalogDir,
  uyedetaylogDir,
  appLogsDir,
  appLogFile,
  parseDateInput,
  readLogFile,
  filterLogContent,
  listLogFiles,
  queueEmailDelivery,
  extractEmails,
  sanitizePlainUserText,
  formatUserText
}) {
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
    const minScoreRaw = String(rawQuery.minScore ?? rawQuery.min_score ?? '').trim();
    const maxScoreRaw = String(rawQuery.maxScore ?? rawQuery.max_score ?? '').trim();
    const minScore = minScoreRaw === '' ? NaN : Number(minScoreRaw);
    const maxScore = maxScoreRaw === '' ? NaN : Number(maxScoreRaw);
    const limit = Math.min(Math.max(parseInt(rawQuery.limit || '20', 10), 1), 100);
    const page = Math.max(parseInt(rawQuery.page || '1', 10), 1);
    const offset = (page - 1) * limit;
    const activeExpr = "(COALESCE(CAST(u.aktiv AS INTEGER), 0) = 1 OR LOWER(CAST(u.aktiv AS TEXT)) IN ('true','evet','yes'))";
    const bannedExpr = "(COALESCE(CAST(u.yasak AS INTEGER), 0) = 1 OR LOWER(CAST(u.yasak AS TEXT)) IN ('true','evet','yes'))";
    const onlineExpr = "(COALESCE(CAST(u.online AS INTEGER), 0) = 1 OR LOWER(CAST(u.online AS TEXT)) IN ('true','evet','yes'))";

    const whereParts = [];
    whereParts.push("(u.role IS NULL OR LOWER(COALESCE(u.role, 'user')) != 'root')");
    const params = [];
    if (filter === 'active') whereParts.push(`${activeExpr} AND NOT ${bannedExpr}`);
    if (filter === 'pending') whereParts.push(`NOT ${activeExpr} AND NOT ${bannedExpr}`);
    if (filter === 'banned') whereParts.push(`${bannedExpr}`);
    if (filter === 'online') whereParts.push(`${onlineExpr}`);
    if (q) {
      whereParts.push('(LOWER(CAST(u.kadi AS TEXT)) LIKE LOWER(?) OR LOWER(CAST(u.isim AS TEXT)) LIKE LOWER(?) OR LOWER(CAST(u.soyisim AS TEXT)) LIKE LOWER(?) OR LOWER(CAST(u.email AS TEXT)) LIKE LOWER(?))');
      params.push(`%${q}%`, `%${q}%`, `%${q}%`, `%${q}%`);
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

  async function handleMemberDelete(req, res) {
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

    try {
      await hardDeleteUser(user.id, { sqlRunAsync, sqlGetAsync, sqlAllAsync, uploadsDir, writeAppLog });
      res.json({ ok: true, message: `@${user.kadi} ve tüm verileri başarıyla silindi.` });
    } catch (err) {
      console.error('Hard delete failed:', err);
      res.status(500).send(err?.message || 'Kullanıcı silinirken bir hata oluştu.');
    }
  }

  app.get('/api/admin/users/lists', requireAdmin, async (req, res) => {
    try {
      res.json(await queryAdminUsers(req.query));
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
        return res.status(400).send(`Mezuniyet yılı ${minGraduationYear}-${maxGraduationYear} aralığında olmalı veya Öğretmen seçilmelidir.`);
      }
      await sqlRunAsync('UPDATE uyeler SET mezuniyetyili = ? WHERE id = ?', [nextYear, userId]);
      logAdminAction(req, 'user_graduation_year_updated', {
        targetType: 'user',
        targetId: userId,
        previous: String(target.mezuniyetyili || ''),
        next: nextYear
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
      files = files.filter((f) => {
        const d = new Date(f.mtime);
        if (from && d < from) return false;
        if (to && d > to) return false;
        return true;
      });
    }
    res.json({ files });
  });

  app.post('/api/admin/email/send', requireAdmin, async (req, res) => {
    const { to, from, subject, html } = req.body || {};
    if (!to) return res.status(400).send('E-Mailin kime gideceğini girmedin.');
    if (!from) return res.status(400).send('E-Mailin kimden gideceğini girmedin.');
    if (!subject) return res.status(400).send('E-Mailin konusunu girmedin.');
    if (!html) return res.status(400).send('E-Mailin metnini girmedin.');
    await queueEmailDelivery({ to, subject, html, from }, { maxAttempts: 4, backoffMs: 1500 });
    res.json({ ok: true });
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
        const list = extractEmails(cat.deger);
        recipients = list.map((email) => ({ email }));
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
        const mapped = countMap.get(String(cat.id)) || { activeCount: 0, inactiveCount: 0 };
        counts[cat.id] = mapped;
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
      let where = '';
      let params = [];
      if (krt === 'onaybekleyen') {
        where = `WHERE ${albumInactivePredicate}`;
      } else if (krt === 'kategori' && kid) {
        where = 'WHERE katid = ?';
        params = [kid];
      }
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
      const photos = await sqlAllAsync(`SELECT * FROM album_foto ${where} ORDER BY ${orderBy}`, params);
      const categories = await sqlAllAsync('SELECT * FROM album_kat');
      const uploaderIds = Array.from(
        new Set(
          photos
            .map((photo) => Number(photo.ekleyenid || 0))
            .filter((id) => Number.isInteger(id) && id > 0)
        )
      );
      const photoIds = Array.from(
        new Set(
          photos
            .map((photo) => Number(photo.id || 0))
            .filter((id) => Number.isInteger(id) && id > 0)
        )
      );
      const uploaderRows = uploaderIds.length
        ? await sqlAllAsync(
          `SELECT id, kadi
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
