import crypto from 'crypto';
import path from 'path';

export function registerProfileSelfServiceRoutes(app, {
  requireAuth,
  sqlGet,
  sqlGetAsync,
  sqlAll,
  sqlRun,
  sqlRunAsync,
  buildVersionedCacheKey,
  cacheNamespaces,
  getCacheJson,
  setCacheJson,
  profileCacheTtlSeconds,
  normalizeCohortValue,
  hasValidGraduationYear,
  minGraduationYear,
  maxGraduationYear,
  getTableColumnSetAsync,
  getColumnType,
  toDbFlagForColumn,
  toDbNumericFlag,
  toTruthyFlag,
  writeAppLog,
  isE2EHarnessRequest,
  getCurrentUser,
  normalizeEmail,
  validateEmail,
  resolvePublicBaseUrl,
  escapeHtml,
  queueEmailDelivery,
  uploadRateLimit,
  requestAttachmentUpload,
  validateUploadedFileSafety,
  cleanupUploadedFile,
  enforceUploadQuota,
  verifyPassword,
  hashPassword,
  photoUpload,
  processDiskImageUpload,
  uploadImagePresets,
  mapLegacyUrl,
  invalidateCacheNamespace
}) {
  app.get('/api/profile', async (req, res) => {
    if (!req.session.userId) return res.status(401).send('Login required');
    const cacheKey = await buildVersionedCacheKey(cacheNamespaces.profile, [
      `user:${Number(req.session.userId || 0)}`
    ]);
    const cached = await getCacheJson(cacheKey);
    if (cached && cached.user) {
      return res.json(cached);
    }
    const user = sqlGet(`
      SELECT id, kadi, isim, soyisim, email, mezuniyetyili, sehir, meslek, websitesi, universite,
             dogumgun, dogumay, dogumyil, mailkapali, imza, resim, ilkbd,
             sirket, unvan, uzmanlik, linkedin_url, universite_bolum, mentor_opt_in, mentor_konulari,
             kvkk_consent_at, directory_consent_at
      FROM uyeler WHERE id = ?`, [req.session.userId]);
    if (user) {
      user.kvkk_consent = Boolean(user.kvkk_consent_at);
      user.directory_consent = Boolean(user.directory_consent_at);
    }
    const responsePayload = { user };
    await setCacheJson(cacheKey, responsePayload, profileCacheTtlSeconds);
    res.json(responsePayload);
  });

  app.put('/api/profile', async (req, res) => {
    if (!req.session.userId) return res.status(401).send('Login required');
    try {
      const isim = String(req.body.isim || '').trim();
      const soyisim = String(req.body.soyisim || '').trim();
      if (!isim) return res.status(400).send('İsmini girmedin');
      if (isim.length > 20) return res.status(400).send('İsim 20 karakterden fazla olmamalıdır.');
      if (!soyisim) return res.status(400).send('Soyismini girmedin');
      if (soyisim.length > 20) return res.status(400).send('Soyisim 20 karakterden fazla olmamalıdır.');

      const sehir = String(req.body.sehir || '');
      const meslek = String(req.body.meslek || '');
      const websitesi = String(req.body.websitesi || '');
      const universite = String(req.body.universite || '');
      const mezuniyetyili = normalizeCohortValue(req.body.mezuniyetyili);
      const kvkkConsent = Boolean(req.body.kvkk_consent);
      const directoryConsent = Boolean(req.body.directory_consent);
      const sirket = String(req.body.sirket || '').trim();
      const unvan = String(req.body.unvan || '').trim();
      const uzmanlik = String(req.body.uzmanlik || '').trim();
      const linkedinUrl = String(req.body.linkedin_url || '').trim();
      const universiteBolum = String(req.body.universite_bolum || '').trim();
      const mentorOptIn = Boolean(req.body.mentor_opt_in);
      const mentorKonulari = String(req.body.mentor_konulari || '').trim();
      const dogumgun = parseInt(req.body.dogumgun || '0', 10) || 0;
      const dogumay = parseInt(req.body.dogumay || '0', 10) || 0;
      const dogumyil = parseInt(req.body.dogumyil || '0', 10) || 0;
      const mailkapali = String(req.body.mailkapali || '0') === '1';
      const imza = String(req.body.imza || '');

      if (!hasValidGraduationYear(mezuniyetyili)) {
        return res.status(400).send(`Mezuniyet yılı ${minGraduationYear}-${maxGraduationYear} aralığında olmalı veya Öğretmen seçilmelidir.`);
      }

      const legacyCols = await getTableColumnSetAsync('uyeler');
      const modernCols = await getTableColumnSetAsync('users');
      const targetTable = modernCols.size ? 'users' : 'uyeler';
      const targetCols = targetTable === 'users' ? modernCols : legacyCols;
      const current = targetTable === 'users'
        ? await sqlGetAsync(
          `SELECT id,
                  oauth_provider,
                  COALESCE(is_verified, FALSE) AS verified,
                  graduation_year AS mezuniyetyili,
                  COALESCE(is_profile_initialized, FALSE) AS ilkbd,
                  privacy_consent_at AS kvkk_consent_at,
                  directory_consent_at
             FROM users
            WHERE id = ?`,
          [req.session.userId]
        )
        : await sqlGetAsync(
          `SELECT id,
                  oauth_provider,
                  COALESCE(verified, 0) AS verified,
                  mezuniyetyili,
                  COALESCE(ilkbd, 0) AS ilkbd,
                  kvkk_consent_at,
                  directory_consent_at
             FROM uyeler
            WHERE id = ?`,
          [req.session.userId]
        );
      const nextIlkbd = current && current.ilkbd === 0 ? true : Boolean(current?.ilkbd ?? true);
      const isOAuthUser = Boolean(String(current?.oauth_provider || '').trim());
      const nextKvkkConsent = Boolean(current?.kvkk_consent_at) || kvkkConsent;
      const nextDirectoryConsent = Boolean(current?.directory_consent_at) || directoryConsent;
      if (isOAuthUser && !nextKvkkConsent) {
        return res.status(400).send('Sosyal üyelik için KVKK Aydınlatma Metni onayı zorunludur.');
      }
      if (isOAuthUser && !nextDirectoryConsent) {
        return res.status(400).send('Sosyal üyelik için Mezun Rehberi açık rıza onayı zorunludur.');
      }

      if (Number(current?.verified || 0) === 1 && String(current?.mezuniyetyili || '') !== mezuniyetyili) {
        return res.status(403).json({
          error: 'GRADUATION_YEAR_LOCKED',
          message: 'Doğrulanmış üyelerde mezuniyet yılı değiştirilemez. Yönetim talebi oluşturun.',
          requestUrl: '/new/requests?category=graduation_year_change'
        });
      }

      const setClauses = [];
      const params = [];
      const pushSet = (column, value) => {
        if (!targetCols.has(String(column || '').toLowerCase())) return;
        setClauses.push(`${column} = ?`);
        params.push(value);
      };

      if (targetTable === 'users') {
        pushSet('first_name', isim);
        pushSet('last_name', soyisim);
        pushSet('city', sehir);
        pushSet('profession', meslek);
        pushSet('website_url', websitesi);
        pushSet('university_name', universite);
        pushSet('graduation_year', mezuniyetyili);
        pushSet('birth_day', dogumgun);
        pushSet('birth_month', dogumay);
        pushSet('birth_year', dogumyil);
        pushSet('is_email_hidden', toDbFlagForColumn('users', 'is_email_hidden', mailkapali));
        pushSet('signature', imza);
        pushSet('is_profile_initialized', toDbFlagForColumn('users', 'is_profile_initialized', nextIlkbd));
        pushSet('company_name', sirket);
        pushSet('job_title', unvan);
        pushSet('expertise', uzmanlik);
        pushSet('linkedin_url', linkedinUrl);
        pushSet('university_department', universiteBolum);
        pushSet('is_mentor_opted_in', toDbFlagForColumn('users', 'is_mentor_opted_in', mentorOptIn));
        pushSet('mentor_topics', mentorKonulari);
      } else {
        pushSet('isim', isim);
        pushSet('soyisim', soyisim);
        pushSet('sehir', sehir);
        pushSet('meslek', meslek);
        pushSet('websitesi', websitesi);
        pushSet('universite', universite);
        pushSet('mezuniyetyili', mezuniyetyili);
        pushSet('dogumgun', dogumgun);
        pushSet('dogumay', dogumay);
        pushSet('dogumyil', dogumyil);
        pushSet('mailkapali', toDbFlagForColumn('uyeler', 'mailkapali', mailkapali));
        pushSet('imza', imza);
        pushSet('ilkbd', toDbFlagForColumn('uyeler', 'ilkbd', nextIlkbd));
        pushSet('sirket', sirket);
        pushSet('unvan', unvan);
        pushSet('uzmanlik', uzmanlik);
        pushSet('linkedin_url', linkedinUrl);
        pushSet('universite_bolum', universiteBolum);
        pushSet('mentor_opt_in', toDbFlagForColumn('uyeler', 'mentor_opt_in', mentorOptIn));
        pushSet('mentor_konulari', mentorKonulari);
      }

      const nowIso = new Date().toISOString();
      const kvkkColumn = targetTable === 'users' ? 'privacy_consent_at' : 'kvkk_consent_at';
      const directoryColumn = 'directory_consent_at';
      const appendConsentUpdate = (column, consentProvided) => {
        if (!targetCols.has(column)) return;
        const currentValue = current?.[column] ?? null;
        const hasCurrentValue = currentValue !== null && currentValue !== undefined && String(currentValue).trim() !== '';
        const type = String(getColumnType(targetTable, column) || '').toLowerCase();
        if (type === 'boolean') {
          pushSet(column, hasCurrentValue ? toDbFlagForColumn(targetTable, column, currentValue) : toDbFlagForColumn(targetTable, column, consentProvided));
          return;
        }
        if (type.includes('int') || type === 'numeric' || type === 'real' || type === 'double precision') {
          pushSet(column, hasCurrentValue ? Number(toTruthyFlag(currentValue)) : toDbNumericFlag(consentProvided));
          return;
        }
        if (consentProvided && !hasCurrentValue) {
          pushSet(column, nowIso);
        }
      };
      appendConsentUpdate(kvkkColumn, kvkkConsent);
      appendConsentUpdate(directoryColumn, directoryConsent);

      if (targetCols.has('updated_at')) {
        pushSet('updated_at', nowIso);
      }
      if (!setClauses.length) {
        throw new Error('profile_update_no_columns');
      }
      params.push(req.session.userId);
      await sqlRunAsync(`UPDATE ${targetTable} SET ${setClauses.join(', ')} WHERE id = ?`, params);
      invalidateCacheNamespace(cacheNamespaces.profile);
      res.json({ ok: true });
    } catch (err) {
      writeAppLog('error', 'profile_update_failed', {
        userId: req.session?.userId || null,
        message: err?.message || 'unknown_error',
        stack: String(err?.stack || '').slice(0, 1200)
      });
      console.error('[profile_update_failed]', {
        userId: req.session?.userId || null,
        message: err?.message || 'unknown_error'
      });
      if (isE2EHarnessRequest(req)) {
        return res.status(500).json({
          ok: false,
          error: 'profile_update_failed',
          message: err?.message || 'unknown_error'
        });
      }
      return res.status(500).send('Profil güncellenirken bir hata oluştu.');
    }
  });

  app.post('/api/profile/email-change/request', requireAuth, async (req, res) => {
    const user = getCurrentUser(req);
    const nextEmail = normalizeEmail(req.body?.email);
    if (!nextEmail) return res.status(400).send('Yeni e-posta adresi gerekli.');
    if (!validateEmail(nextEmail)) return res.status(400).send('E-mail adresi doğru görünmüyor.');
    if (String(user?.email || '').toLowerCase() === nextEmail.toLowerCase()) {
      return res.status(400).send('Mevcut e-posta ile aynı adresi girdiniz.');
    }
    const duplicate = sqlGet('SELECT id FROM uyeler WHERE lower(email) = lower(?) AND id != ?', [nextEmail, req.session.userId]);
    if (duplicate) return res.status(400).send('Bu e-posta adresi başka bir üyede kayıtlı.');

    sqlRun('UPDATE email_change_requests SET status = ? WHERE user_id = ? AND status = ?', ['replaced', req.session.userId, 'pending']);
    const token = crypto.randomBytes(32).toString('hex');
    const now = new Date();
    const expiresAt = new Date(now.getTime() + 1000 * 60 * 60 * 24);
    sqlRun(
      `INSERT INTO email_change_requests
      (user_id, current_email, new_email, token, status, created_at, expires_at, ip, user_agent)
      VALUES (?, ?, ?, ?, 'pending', ?, ?, ?, ?)`,
      [req.session.userId, user.email || '', nextEmail, token, now.toISOString(), expiresAt.toISOString(), req.ip || '', req.headers['user-agent'] || '']
    );

    const base = resolvePublicBaseUrl(req);
    const verifyLink = `${base}/api/profile/email-change/verify?token=${encodeURIComponent(token)}`;
    const html = `<!doctype html><html><body style="font-family:Arial,sans-serif;background:#f4efe8;padding:24px;color:#1f2937;">
    <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width:600px;margin:0 auto;background:#fff;border:1px solid #e5e7eb;border-radius:12px;">
      <tr><td style="padding:20px 24px;">
        <h2 style="margin:0 0 12px;font-size:18px;">SDAL E-posta Değişikliği</h2>
        <p style="margin:0 0 12px;">Merhaba ${escapeHtml(user?.isim || user?.kadi || 'Üye')},</p>
        <p style="margin:0 0 16px;">Yeni e-posta adresini onaylamak için aşağıdaki butona tıkla:</p>
        <a href="${escapeHtml(verifyLink)}" style="display:inline-block;padding:10px 14px;border-radius:999px;background:#ff6b4a;color:#111827;text-decoration:none;font-weight:700;">E-postamı Doğrula</a>
        <p style="margin:16px 0 0;color:#6b7280;font-size:13px;">Bu link 24 saat geçerlidir.</p>
      </td></tr>
    </table>
    </body></html>`;
    await queueEmailDelivery({ to: nextEmail, subject: 'SDAL - E-posta değişikliği doğrulama', html }, { maxAttempts: 4, backoffMs: 1500 });
    res.json({ ok: true });
  });

  app.get('/api/profile/email-change/verify', (req, res) => {
    const token = String(req.query?.token || '').trim();
    if (!token) return res.status(400).send('Doğrulama tokeni eksik.');
    const row = sqlGet('SELECT * FROM email_change_requests WHERE token = ?', [token]);
    if (!row) return res.status(404).send('Doğrulama kaydı bulunamadı.');
    if (row.status !== 'pending') return res.status(400).send('Bu doğrulama linki zaten kullanılmış veya iptal edilmiş.');
    if (row.expires_at && new Date(row.expires_at).getTime() < Date.now()) {
      sqlRun('UPDATE email_change_requests SET status = ? WHERE id = ?', ['expired', row.id]);
      return res.status(400).send('Doğrulama linkinin süresi dolmuş.');
    }
    const duplicate = sqlGet('SELECT id FROM uyeler WHERE lower(email) = lower(?) AND id != ?', [row.new_email, row.user_id]);
    if (duplicate) return res.status(400).send('Bu e-posta adresi artık kullanımda olduğu için değişiklik tamamlanamadı.');
    sqlRun('UPDATE uyeler SET email = ? WHERE id = ?', [row.new_email, row.user_id]);
    sqlRun('UPDATE email_change_requests SET status = ?, verified_at = ? WHERE id = ?', ['verified', new Date().toISOString(), row.id]);
    invalidateCacheNamespace(cacheNamespaces.profile);
    return res.redirect('/new/profile?emailChanged=1');
  });

  app.get('/api/new/request-categories', requireAuth, (_req, res) => {
    const items = sqlAll('SELECT category_key, label, description FROM request_categories WHERE active = 1 ORDER BY id');
    res.json({ items });
  });

  app.get('/api/new/requests/my', requireAuth, (req, res) => {
    const items = sqlAll(
      `SELECT r.id, r.category_key, r.payload_json, r.status, r.created_at, r.reviewed_at, r.resolution_note,
              c.label AS category_label
       FROM member_requests r
       LEFT JOIN request_categories c ON c.category_key = r.category_key
       WHERE r.user_id = ?
       ORDER BY r.id DESC`,
      [req.session.userId]
    );
    res.json({ items });
  });

  app.post('/api/new/requests/upload', requireAuth, uploadRateLimit, requestAttachmentUpload.single('file'), async (req, res) => {
    if (!req.file?.path) return res.status(400).send('Dosya yüklenemedi.');
    const validation = validateUploadedFileSafety(req.file.path, { allowedMimes: ['image/jpeg', 'image/png', 'application/pdf'] });
    if (!validation.ok) {
      cleanupUploadedFile(req.file.path);
      return res.status(400).send(validation.reason || 'Dosya güvenlik kontrolünden geçemedi.');
    }
    const quotaOk = await enforceUploadQuota(req, res, {
      fileSize: Number(req.file.size || 0),
      bucket: 'request_attachment'
    });
    if (!quotaOk) {
      cleanupUploadedFile(req.file.path);
      return res.status(429).send('Günlük yükleme kotan doldu. Lütfen daha sonra tekrar dene.');
    }
    res.json({
      ok: true,
      attachment: {
        name: req.file.originalname,
        mime: validation.mime,
        size: Number(req.file.size || 0),
        url: `/uploads/request-attachments/${req.file.filename}`
      }
    });
  });

  app.post('/api/new/requests', requireAuth, (req, res) => {
    const categoryKey = String(req.body?.category_key || '').trim();
    const payload = req.body?.payload || {};
    if (!categoryKey) return res.status(400).send('Talep kategorisi gerekli.');
    const category = sqlGet('SELECT category_key FROM request_categories WHERE category_key = ? AND active = 1', [categoryKey]);
    if (!category) return res.status(400).send('Geçersiz talep kategorisi.');
    const existing = sqlGet('SELECT id FROM member_requests WHERE user_id = ? AND category_key = ? AND status = ?', [req.session.userId, categoryKey, 'pending']);
    if (existing) return res.status(400).send('Bu kategori için bekleyen bir talebiniz zaten var.');
    sqlRun(
      'INSERT INTO member_requests (user_id, category_key, payload_json, status, created_at) VALUES (?, ?, ?, ?, ?)',
      [req.session.userId, categoryKey, JSON.stringify(payload || {}), 'pending', new Date().toISOString()]
    );
    res.json({ ok: true });
  });

  app.post('/api/profile/password', async (req, res) => {
    if (!req.session.userId) return res.status(401).send('Login required');
    const { eskisifre = '', yenisifre = '', yenisifretekrar = '' } = req.body || {};
    if (!eskisifre) return res.status(400).send('Şifreni değiştirebilmek için eski şifreni girmen gerekiyor');
    if (!yenisifre) return res.status(400).send('Şifreni değiştirebilmek için yeni şifreni girmen gerekiyor');
    if (!yenisifretekrar) return res.status(400).send('Şifreni değiştirebilmek için yeni şifreni tekrar girmen gerekiyor');
    if (String(yenisifre).length > 20) return res.status(400).send('Yeni şifre 20 karakterden fazla olmamalıdır.');

    const user = sqlGet('SELECT sifre FROM uyeler WHERE id = ?', [req.session.userId]);
    const verify = await verifyPassword(user?.sifre, eskisifre);
    if (!verify.ok) return res.status(400).send('Şifreni yanlış girdin');
    if (yenisifre !== yenisifretekrar) return res.status(400).send('Girdiğin şifreler birbirleriyle uyuşmuyor');

    sqlRun('UPDATE uyeler SET sifre = ? WHERE id = ?', [await hashPassword(yenisifre), req.session.userId]);
    res.json({ ok: true });
  });

  app.post('/api/profile/photo', uploadRateLimit, (req, res, next) => {
    if (!req.session.userId) return res.status(401).send('Login required');
    return next();
  }, photoUpload.single('file'), async (req, res) => {
    if (!req.file) return res.status(400).send('Fotoğraf seçilmedi');
    const processed = await processDiskImageUpload({
      req,
      res,
      file: req.file,
      bucket: 'profile_photo',
      preset: uploadImagePresets.profilePhoto,
      allowedMimes: ['image/jpeg', 'image/png', 'image/webp', 'image/gif', 'image/bmp', 'image/tiff']
    });
    if (!processed.ok) return res.status(processed.statusCode).send(processed.message);
    try {
      const filename = path.basename(processed.path || req.file.path);
      sqlRun('UPDATE uyeler SET resim = ? WHERE id = ?', [filename, req.session.userId]);
      invalidateCacheNamespace(cacheNamespaces.profile);
      res.json({ ok: true, photo: filename });
    } catch {
      res.status(500).send('Profil fotoğrafı işlenemedi.');
    }
  });

  app.get('/api/menu', (req, res) => {
    if (!req.session.userId) return res.json({ items: [] });
    const items = sqlAll('SELECT sayfaismi, sayfaurl FROM sayfalar WHERE menugorun = 1 ORDER BY sayfaismi');
    const mapped = items
      .filter((row) => !['sifrehatirla.asp', 'uyekayit.asp'].includes((row.sayfaurl || '').toLowerCase()))
      .map((row) => ({
        label: row.sayfaismi,
        url: mapLegacyUrl(row.sayfaurl),
        legacyUrl: row.sayfaurl
      }));
    res.json({ items: mapped });
  });

  app.get('/api/sidebar', (req, res) => {
    if (!req.session.userId) return res.json({ onlineUsers: [], newMembers: [], newPhotos: [], topSnake: [], topTetris: [], newMessagesCount: 0 });

    const onlineUsers = [];
    const now = Date.now();
    const onlineRows = sqlAll('SELECT id, kadi, isim, soyisim, resim, mezuniyetyili, sonislemtarih, sonislemsaat FROM uyeler WHERE online = 1 ORDER BY kadi');
    onlineRows.forEach((row) => {
      const last = row.sonislemtarih && row.sonislemsaat ? new Date(`${row.sonislemtarih} ${row.sonislemsaat}`) : null;
      if (last && now - last.getTime() > 5 * 60 * 1000) {
        sqlRun('UPDATE uyeler SET online = 0 WHERE id = ?', [row.id]);
        return;
      }
      onlineUsers.push(row);
    });

    const newMembers = sqlAll('SELECT id, kadi, isim, soyisim, resim, mezuniyetyili FROM uyeler WHERE aktiv = 1 AND yasak = 0 ORDER BY id DESC LIMIT 5');
    const newPhotos = sqlAll(`
      SELECT f.id, f.katid, f.dosyaadi, k.kategori
      FROM album_foto f
      LEFT JOIN album_kat k ON k.id = f.katid
      WHERE f.aktif = 1
      ORDER BY f.id DESC
      LIMIT 10
    `);
    const topSnake = sqlAll('SELECT isim, skor, tarih FROM oyun_yilan ORDER BY skor DESC LIMIT 5');
    const topTetris = sqlAll('SELECT isim, puan, tarih FROM oyun_tetris ORDER BY puan DESC LIMIT 5');
    const newMessagesCountRow = sqlGet('SELECT COUNT(*) AS cnt FROM gelenkutusu WHERE yeni = 1 AND kime = ? AND aktifgelen = 1', [req.session.userId]);
    const newMessagesCount = newMessagesCountRow ? newMessagesCountRow.cnt : 0;

    res.json({ onlineUsers, newMembers, newPhotos, topSnake, topTetris, newMessagesCount });
  });
}
