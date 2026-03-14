export function registerAccountRoutes(app, deps) {
  const {
    sqlGet,
    sqlGetAsync,
    sqlRun,
    sqlRunAsync,
    writeAppLog,
    normalizeEmail,
    validateEmail,
    normalizeCohortValue,
    parseGraduationYear,
    hasValidGraduationYear,
    filterKufur,
    isE2EHarnessRequest,
    normalizeE2ERole,
    parseE2EModerationPermissionKeys,
    roleAtLeast,
    MODERATION_PERMISSION_KEY_SET,
    replaceModeratorPermissionsAsync,
    createActivation,
    hashPassword,
    hashE2EPassword,
    toDbBooleanParam,
    resolvePublicBaseUrl,
    buildActivationEmailHtml,
    queueEmailDelivery,
    extractEmails,
    mailSender,
    mailProviderStatus,
    escapeHtml
  } = deps;
  const validateMail = validateEmail;

  app.post('/api/register/preview', async (req, res) => {
    try {
      if (req.session.userId) return res.status(400).send('Zaten giriş yaptınız.');
      const e2eMode = isE2EHarnessRequest(req);
      const {
        kadi = '',
        sifre = '',
        sifre2 = '',
        email = '',
        isim = '',
        soyisim = '',
        mezuniyetyili = '0',
        gkodu = '',
        kvkk_consent = false,
        directory_consent = false
      } = req.body || {};
      const cleanKadi = String(kadi || '').trim();
      const cleanEmail = normalizeEmail(email);
      const cleanIsim = String(isim || '').trim();
      const cleanSoyisim = String(soyisim || '').trim();

      const cleanCaptcha = String(gkodu || '').trim();
      if (!e2eMode) {
        if (!/^\d+$/.test(cleanCaptcha)) {
          return res.status(400).send('Güvenlik kodu sadece sayı olmalıdır.');
        }
        if (String(req.session.captcha || '') !== cleanCaptcha) {
          return res.status(400).send('Güvenlik kodu yanlış girildi.');
        }
      }
      if (!cleanKadi) return res.status(400).send('Kullanıcı adını girmedin.');
      if (String(cleanKadi).length > 15) return res.status(400).send('Kullanıcı adı 15 karakterden fazla olmamalıdır.');
      const kufur = filterKufur(cleanKadi);
      if (kufur) return res.status(400).send(`Girdiğiniz kullanıcı adı uygun olmayan bir kelime içeriyor. (${kufur})`);
      if (!sifre) return res.status(400).send('Şifreni girmedin.');
      if (String(sifre).length > 20) return res.status(400).send('Şifre 20 karakterden fazla olmamalıdır.');
      if (sifre !== sifre2) return res.status(400).send('Girdiğin şifreler birbirleriyle uyuşmuyor.');
      if (!cleanEmail) return res.status(400).send('Email adresini girmedin.');
      if (String(cleanEmail).length > 50) return res.status(400).send('E-mail adresi 50 karakterden fazla olmamalıdır.');
      if (!validateEmail(cleanEmail)) return res.status(400).send('E-mail adresi doğru görünmüyor.');
      const cohortValue = normalizeCohortValue(mezuniyetyili);
      if (cohortValue === '0' || !cohortValue) return res.status(400).send('Bir mezuniyet yılı veya Öğretmen seçmeniz gerekmektedir.');
      const parsedYear = parseGraduationYear(cohortValue);
      if (!hasValidGraduationYear(cohortValue) || (Number.isFinite(parsedYear) && parsedYear > new Date().getFullYear())) {
        return res.status(400).send('Geçerli bir mezuniyet yılı veya Öğretmen seçmeniz gerekmektedir.');
      }
      if (!e2eMode) {
        if (!kvkk_consent) return res.status(400).send('KVKK Aydınlatma Metni\'ni okumanız ve onaylamanız gerekmektedir.');
        if (!directory_consent) return res.status(400).send('Mezun Rehberi açık rıza onayı gerekmektedir.');
      }
      if (!cleanIsim) return res.status(400).send('İsmini girmedin.');
      if (String(cleanIsim).length > 20) return res.status(400).send('İsim 20 karakterden fazla olmamalıdır.');
      if (!cleanSoyisim) return res.status(400).send('Soyismini girmedin.');
      if (String(cleanSoyisim).length > 20) return res.status(400).send('Soyisim 20 karakterden fazla olmamalıdır.');

      const existingUser = await sqlGetAsync('SELECT id FROM uyeler WHERE kadi = ?', [cleanKadi]);
      if (existingUser) return res.status(400).send('Girdiğiniz kullanıcı adı zaten kayıtlıdır.');
      const existingMail = await sqlGetAsync('SELECT id FROM uyeler WHERE lower(email) = lower(?)', [cleanEmail]);
      if (existingMail) return res.status(400).send('Girdiğiniz e-mail adresi zaten kayıtlıdır.');

      res.json({
        ok: true,
        fields: { kadi: cleanKadi, email: cleanEmail, mezuniyetyili: cohortValue, isim: cleanIsim, soyisim: cleanSoyisim }
      });
    } catch (err) {
      writeAppLog('error', 'register_preview_failed', {
        message: err?.message || 'unknown_error',
        stack: String(err?.stack || '').slice(0, 1200)
      });
      return res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.post('/api/register/check', async (req, res) => {
    try {
      if (req.session.userId) return res.status(400).send('Zaten giriş yaptınız.');
      const { kadi = '', email = '' } = req.body || {};
      const cleanKadi = String(kadi || '').trim();
      const cleanEmail = normalizeEmail(email);

      if (!cleanKadi && !cleanEmail) {
        return res.status(400).send('Kontrol için kullanıcı adı veya e-mail girilmelidir.');
      }

      let kadiExists = false;
      let emailExists = false;
      if (cleanKadi) {
        const existingUser = await sqlGetAsync('SELECT id FROM uyeler WHERE kadi = ?', [cleanKadi]);
        kadiExists = Boolean(existingUser);
      }
      if (cleanEmail && validateEmail(cleanEmail)) {
        const existingMail = await sqlGetAsync('SELECT id FROM uyeler WHERE lower(email) = lower(?)', [cleanEmail]);
        emailExists = Boolean(existingMail);
      }

      res.json({ ok: true, kadiExists, emailExists });
    } catch (err) {
      writeAppLog('error', 'register_check_failed', {
        message: err?.message || 'unknown_error',
        stack: String(err?.stack || '').slice(0, 1200)
      });
      return res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.post('/api/register', async (req, res) => {
    try {
      if (req.session.userId) return res.status(400).send('Zaten giriş yaptınız.');
      const e2eMode = isE2EHarnessRequest(req);
      const {
        kadi = '',
        sifre = '',
        sifre2 = '',
        email = '',
        isim = '',
        soyisim = '',
        mezuniyetyili = '0',
        gkodu = '',
        kvkk_consent = false,
        directory_consent = false,
        role: requestedRole = 'user',
        moderationPermissionKeys = []
      } = req.body || {};
      const cleanKadi = String(kadi || '').trim();
      const cleanEmail = normalizeEmail(email);
      const cleanIsim = String(isim || '').trim();
      const cleanSoyisim = String(soyisim || '').trim();
      const traceE2E = (step, meta = {}) => {
        if (!e2eMode) return;
        writeAppLog('info', 'register_e2e_step', {
          step,
          kadi: cleanKadi,
          email: cleanEmail,
          ip: req.ip,
          ...meta
        });
      };

      const cleanCaptcha = String(gkodu || '').trim();
      if (!e2eMode) {
        if (!/^\d+$/.test(cleanCaptcha)) return res.status(400).send('Güvenlik kodu sadece sayı olmalıdır.');
        if (String(req.session.captcha || '') !== cleanCaptcha) return res.status(400).send('Güvenlik kodu yanlış girildi.');
      }
      if (!cleanKadi) return res.status(400).send('Kullanıcı adını girmedin.');
      if (String(cleanKadi).length > 15) return res.status(400).send('Kullanıcı adı 15 karakterden fazla olmamalıdır.');
      const kufur = filterKufur(cleanKadi);
      if (kufur) return res.status(400).send(`Girdiğiniz kullanıcı adı uygun olmayan bir kelime içeriyor. (${kufur})`);
      if (!sifre) return res.status(400).send('Şifreni girmedin.');
      if (String(sifre).length > 20) return res.status(400).send('Şifre 20 karakterden fazla olmamalıdır.');
      if (sifre !== sifre2) return res.status(400).send('Girdiğin şifreler birbirleriyle uyuşmuyor.');
      if (!cleanEmail) return res.status(400).send('Email adresini girmedin.');
      if (String(cleanEmail).length > 50) return res.status(400).send('E-mail adresi 50 karakterden fazla olmamalıdır.');
      if (!validateEmail(cleanEmail)) return res.status(400).send('E-mail adresi doğru görünmüyor.');
      const cohortValue = normalizeCohortValue(mezuniyetyili);
      if (cohortValue === '0' || !cohortValue) return res.status(400).send('Bir mezuniyet yılı veya Öğretmen seçmeniz gerekmektedir.');
      if (!e2eMode) {
        if (!kvkk_consent) return res.status(400).send('KVKK Aydınlatma Metni\'ni okumanız ve onaylamanız gerekmektedir.');
        if (!directory_consent) return res.status(400).send('Mezun Rehberi açık rıza onayı gerekmektedir.');
      }
      if (!cleanIsim) return res.status(400).send('İsmini girmedin.');
      if (String(cleanIsim).length > 20) return res.status(400).send('İsim 20 karakterden fazla olmamalıdır.');
      if (!cleanSoyisim) return res.status(400).send('Soyismini girmedin.');
      if (String(cleanSoyisim).length > 20) return res.status(400).send('Soyisim 20 karakterden fazla olmamalıdır.');

      traceE2E('before_duplicate_checks');
      const existingUser = await sqlGetAsync('SELECT id FROM uyeler WHERE kadi = ?', [cleanKadi]);
      if (existingUser) return res.status(400).send('Girdiğiniz kullanıcı adı zaten kayıtlıdır.');
      const existingMail = await sqlGetAsync('SELECT id FROM uyeler WHERE lower(email) = lower(?)', [cleanEmail]);
      if (existingMail) return res.status(400).send('Girdiğiniz e-mail adresi zaten kayıtlıdır.');
      traceE2E('after_duplicate_checks');

      const parsedYear = parseGraduationYear(cohortValue);
      if (!hasValidGraduationYear(cohortValue) || (Number.isFinite(parsedYear) && parsedYear > new Date().getFullYear())) {
        return res.status(400).send('Geçerli bir mezuniyet yılı veya Öğretmen seçmeniz gerekmektedir.');
      }

      const e2eRole = e2eMode ? normalizeE2ERole(requestedRole) : 'user';
      const e2eIsAdmin = e2eMode && roleAtLeast(e2eRole, 'admin');
      const e2eIsVerified = e2eMode;
      const e2eIsActive = e2eMode;
      const e2eRequestedModerationKeys = e2eMode ? parseE2EModerationPermissionKeys(moderationPermissionKeys) : [];
      const e2eModerationKeys = e2eMode
        ? (e2eRequestedModerationKeys.length ? e2eRequestedModerationKeys : Array.from(MODERATION_PERMISSION_KEY_SET))
        : [];

      const aktivasyon = createActivation();
      const now = new Date().toISOString();
      traceE2E('before_insert');
      const result = await sqlRunAsync(
        `INSERT INTO uyeler (kadi, sifre, email, isim, soyisim, aktivasyon, aktiv, ilktarih, resim, mezuniyetyili, ilkbd, verification_status, kvkk_consent_at, directory_consent_at, verified, role, admin)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'yok', ?, ?, ?, ?, ?, ?, ?, ?)`,
        [
          cleanKadi,
          (e2eMode ? hashE2EPassword(sifre) : await hashPassword(sifre)),
          cleanEmail,
          cleanIsim,
          cleanSoyisim,
          aktivasyon,
          toDbBooleanParam(e2eIsActive),
          now,
          cohortValue,
          toDbBooleanParam(false),
          e2eIsVerified ? 'verified' : 'pending',
          now,
          now,
          toDbBooleanParam(e2eIsVerified),
          e2eRole,
          toDbBooleanParam(e2eIsAdmin)
        ]
      );
      const newId = result?.lastInsertRowid;
      traceE2E('after_insert', { userId: Number(newId || 0) });

      if (e2eMode && e2eRole === 'mod' && newId) {
        traceE2E('before_mod_permissions');
        await replaceModeratorPermissionsAsync(newId, e2eModerationKeys, newId);
        traceE2E('after_mod_permissions');
      }

      const welcome = await sqlGetAsync('SELECT id FROM uyeler WHERE id = 1');
      if (welcome && !e2eMode) {
        await sqlRunAsync(
          `INSERT INTO gelenkutusu (kime, kimden, aktifgelen, aktifgiden, yeni, konu, mesaj, tarih)
           VALUES (?, 1, 1, 1, 1, 'Hoşgeldiniz!', ?, ?)`,
          [String(newId), 'Sdal.org - Süleyman Demirel Anadolu Lisesi Mezunları Web Sitesine hoşgeldiniz!<br><br>Bu <b>mesaj paneli</b> sayesinde diğer üyeler ile haberleşebilirsiniz.<br><br>Hoşça vakit geçirmeniz dileğiyle...<br><b><i>sdal.org</b></i>', now]
        );
      }

      let mailSent = false;
      let mailQueued = false;
      if (!e2eMode) {
        const publicBaseUrl = resolvePublicBaseUrl(req);
        const activationLink = `${publicBaseUrl}/aktivet?id=${newId}&akt=${aktivasyon}`;
        const html = buildActivationEmailHtml({
          siteBase: publicBaseUrl,
          activationLink,
          user: { kadi: cleanKadi, isim: cleanIsim, soyisim: cleanSoyisim }
        });

        queueEmailDelivery(
          { to: cleanEmail, subject: 'SDAL.ORG - Üyelik Başvurusu', html, timeoutMs: Number(process.env.MAIL_SEND_TIMEOUT_MS || 8000) },
          { maxAttempts: 4, backoffMs: 1500 }
        ).catch((err) => {
          console.error('Register activation mail send failed:', err);
        });
        mailSent = true;
        mailQueued = true;
      }

      traceE2E('before_response');
      res.json({
        ok: true,
        mailSent,
        mailQueued,
        message: e2eMode
          ? 'E2E kayıt tamamlandı. Hesap aktif ve doğrulanmış olarak oluşturuldu.'
          : 'Kayıt tamamlandı. Aktivasyon e-postası gönderim kuyruğuna alındı.',
        e2e: e2eMode ? {
          userId: Number(newId || 0),
          active: true,
          verified: true,
          role: e2eRole,
          moderationPermissionCount: e2eRole === 'mod' ? e2eModerationKeys.length : 0
        } : undefined
      });
    } catch (err) {
      writeAppLog('error', 'register_failed', {
        message: err?.message || 'unknown_error',
        stack: String(err?.stack || '').slice(0, 2000)
      });
      return res.status(500).send('Kayıt sırasında beklenmeyen bir hata oluştu.');
    }
  });

  app.get('/api/activate', (req, res) => {
    const id = req.query.id;
    const akt = req.query.akt;
    if (!id || !akt) return res.status(400).send('Aktivasyon kodu eksik');
    const user = sqlGet('SELECT * FROM uyeler WHERE id = ?', [id]);
    if (!user) return res.status(404).send('Böyle bir kullanıcı kayıtlı değil');
    if (user.aktiv === 1) return res.status(400).send('Aktivasyon zaten tamamlanmış');
    if (user.aktivasyon !== akt) return res.status(400).send('Aktivasyon kodu yanlış');
    const newAkt = createActivation();
    sqlRun('UPDATE uyeler SET aktiv = 1, aktivasyon = ? WHERE id = ?', [newAkt, id]);
    res.json({ ok: true, kadi: user.kadi });
  });

  app.post('/api/activation/resend', async (req, res) => {
    const email = normalizeEmail(req.body?.email);
    if (!email) return res.status(400).send('E-mail adresini girmedin.');
    if (!validateEmail(email)) return res.status(400).send('E-mail adresi doğru görünmüyor.');
    const user = sqlGet('SELECT * FROM uyeler WHERE lower(email) = lower(?)', [email]);
    if (!user) return res.status(404).send('Bu e-mail adresiyle kayıtlı bir kullanıcı bulunamadı.');
    if (Number(user.aktiv || 0) === 1) return res.status(400).send('Bu hesap zaten aktif edildi.');
    const publicBaseUrl = resolvePublicBaseUrl(req);
    const activationLink = `${publicBaseUrl}/aktivet?id=${user.id}&akt=${user.aktivasyon}`;
    const html = buildActivationEmailHtml({
      siteBase: publicBaseUrl,
      activationLink,
      user
    });
    await queueEmailDelivery({ to: user.email, subject: 'SDAL - Aktivasyon', html }, { maxAttempts: 4, backoffMs: 1200 });
    res.json({ ok: true });
  });

  app.post('/api/password-reset', async (req, res) => {
    const { kadi, email } = req.body || {};
    let user = null;
    if (kadi) user = sqlGet('SELECT * FROM uyeler WHERE kadi = ?', [kadi]);
    if (!user && email) user = sqlGet('SELECT * FROM uyeler WHERE email = ?', [email]);
    if (!user) return res.status(404).send('Böyle bir kullanıcı kayıtlı değil');

    const publicBaseUrl = resolvePublicBaseUrl(req);
    const html = `<!doctype html><html><body style="font-family:Arial,sans-serif;background:#f4efe8;padding:24px;color:#1f2937;">
      <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width:600px;margin:0 auto;background:#fff;border:1px solid #e5e7eb;border-radius:12px;">
        <tr><td style="padding:20px 24px;">
          <h2 style="margin:0 0 12px;font-size:18px;">SDAL Hesap Bilgilendirmesi</h2>
          <p style="margin:0 0 12px;">Merhaba <b>${escapeHtml(user.isim)} ${escapeHtml(user.soyisim)}</b>,</p>
          <p style="margin:0 0 12px;">Güvenlik nedeniyle e-posta ile şifre paylaşmıyoruz.</p>
          <p style="margin:0 0 16px;">Kullanıcı adın: <b>@${escapeHtml(user.kadi)}</b></p>
          <a href="${escapeHtml(publicBaseUrl)}/new/password-reset" style="display:inline-block;padding:10px 14px;border-radius:999px;background:#ff6b4a;color:#111827;text-decoration:none;font-weight:700;">Şifremi Sıfırla</a>
        </td></tr>
      </table>
    </body></html>`;
    await queueEmailDelivery({ to: user.email, subject: 'SDAL.ORG - ŞİFRE HATIRLAMA', html }, { maxAttempts: 4, backoffMs: 1200 });
    res.json({ ok: true });
  });

  app.post('/api/mail/test', async (req, res) => {
    const fallback = process.env.MAIL_FROM || process.env.SMTP_FROM || process.env.MAIL_SMTP_USER || process.env.SMTP_USER || '';
    const candidates = extractEmails(req.body?.to || fallback);
    if (!candidates.length) return res.status(400).send('Test e-mail adresi eksik.');
    const invalid = candidates.find((value) => !validateMail(value));
    if (invalid) return res.status(400).send('E-mail adresi doğru görünmüyor.');
    const to = candidates.join(', ');
    try {
      await queueEmailDelivery({
        to,
        subject: 'SDAL SMTP Test',
        html: 'Bu bir SMTP test e-postasıdır.'
      }, { maxAttempts: 2, backoffMs: 1000 });
      const runtimeMailStatus = typeof mailSender.getStatus === 'function' ? mailSender.getStatus() : mailProviderStatus;
      res.json({
        ok: true,
        to,
        provider: runtimeMailStatus?.provider || mailProviderStatus.provider,
        mock: !runtimeMailStatus?.configured,
        configured: !!runtimeMailStatus?.configured
      });
    } catch (err) {
      console.error('SMTP test error:', err);
      res.status(500).send('SMTP test başarısız.');
    }
  });

  app.post('/api/mail/webhooks/brevo', (req, res) => {
    const expectedToken = String(process.env.MAIL_WEBHOOK_SHARED_SECRET || '').trim();
    const presentedToken = String(req.get('x-sdal-webhook-token') || req.get('x-mailin-custom') || '').trim();
    if (expectedToken && presentedToken !== expectedToken) {
      writeAppLog('warn', 'mail_webhook_rejected', {
        provider: 'brevo',
        reason: 'invalid_shared_secret',
        ip: req.ip || ''
      });
      return res.status(401).json({ ok: false, error: 'unauthorized' });
    }

    const payload = req.body;
    const events = Array.isArray(payload) ? payload : (payload ? [payload] : []);

    for (const item of events) {
      if (!item || typeof item !== 'object') continue;
      const eventType = String(item.event || item.type || 'unknown');
      const email = String(item.email || item.recipient || '');
      const messageId = String(item['message-id'] || item.messageId || item.id || '');
      const reason = String(item.reason || item.response || '');
      const level = ['hard_bounce', 'soft_bounce', 'blocked', 'spam'].includes(eventType) ? 'warn' : 'info';
      writeAppLog(level, 'mail_webhook_event', {
        provider: 'brevo',
        eventType,
        email,
        messageId,
        reason
      });
    }

    res.json({ ok: true, received: events.length });
  });

  app.get('/kvkk', (_req, res) => {
    res.type('html').send(`<!doctype html>
<html lang="tr">
<head><meta charset="utf-8" /><meta name="viewport" content="width=device-width,initial-scale=1" /><title>SDAL KVKK Aydınlatma Metni</title></head>
<body style="font-family:Arial,sans-serif;line-height:1.6;max-width:920px;margin:24px auto;padding:0 16px;color:#1f2937">
<h1>SDAL Platformu KVKK Aydınlatma Metni</h1>
<p><b>Veri Sorumlusu:</b> SDAL mezun platformu yöneticileri ("SDAL"). Bu metin 6698 sayılı Kişisel Verilerin Korunması Kanunu m.10 kapsamında bilgilendirme amacıyla hazırlanmıştır.</p>
<h2>1. İşlenen Kişisel Veriler</h2><p>Kimlik ve iletişim (ad, soyad, e-posta), hesap bilgileri (kullanıcı adı, mezuniyet yılı, profil fotoğrafı), kullanım/veri güvenliği kayıtları (IP, oturum, işlem kayıtları), isteğe bağlı profil alanları ve üyeler arası mesajlaşma içerikleri.</p>
<h2>2. İşleme Amaçları</h2><p>Üyelik hesabının kurulması ve yönetimi, mezunlar arası iletişim, platform güvenliğinin sağlanması, kötüye kullanımın önlenmesi, yasal yükümlülüklerin yerine getirilmesi, teknik destek ve topluluk yönetimi süreçlerinin yürütülmesi.</p>
<h2>3. Hukuki Sebepler</h2><p>KVKK m.5/2-c (sözleşmenin kurulması/ifası), m.5/2-ç (hukuki yükümlülük), m.5/2-f (meşru menfaat) ve gerekli hallerde açık rıza (m.5/1) kapsamında işleme yapılır.</p>
<h2>4. Aktarım</h2><p>Kişisel veriler; barındırma, e-posta, güvenlik ve yedekleme hizmeti sağlayıcılarına, sadece hizmetin gerektirdiği ölçüde aktarılabilir. Kanunen yetkili kamu kurumlarına hukuki zorunluluk halinde paylaşım yapılabilir.</p>
<h2>5. Saklama Süreleri</h2><p>Veriler ilgili mevzuat, uyuşmazlık zamanaşımı ve platform operasyon ihtiyaçlarına göre gerekli süre boyunca saklanır; süresi dolan veriler silinir, yok edilir veya anonimleştirilir.</p>
<h2>6. Haklarınız</h2><p>KVKK m.11 kapsamındaki; işlenip işlenmediğini öğrenme, bilgi talep etme, düzeltme, silme/yok etme, aktarılan tarafları öğrenme, itiraz ve zarar halinde tazminat talep haklarınızı kullanabilirsiniz.</p>
<p>Başvuru ve talepler için: <a href="mailto:kvkk@sdal.org">kvkk@sdal.org</a></p>
<hr /><p>Bu metin, platform süreçlerindeki değişikliklere göre güncellenebilir. Güncel metin her zaman bu bağlantıda yayımlanır.</p>
</body></html>`);
  });

  app.get('/kvkk/acik-riza', (_req, res) => {
    res.type('html').send(`<!doctype html>
<html lang="tr">
<head><meta charset="utf-8" /><meta name="viewport" content="width=device-width,initial-scale=1" /><title>SDAL Mezun Rehberi Açık Rıza Metni</title></head>
<body style="font-family:Arial,sans-serif;line-height:1.6;max-width:920px;margin:24px auto;padding:0 16px;color:#1f2937">
<h1>SDAL Mezun Rehberi Açık Rıza Metni</h1>
<p>Bu açık rıza; ad-soyad, mezuniyet yılı, okul/üniversite ve profilde paylaştığınız sınırlı mesleki bilgilerin, yalnızca SDAL üyelerine açık Mezun Rehberi alanında görüntülenmesine ilişkindir.</p>
<ul><li>Rıza vermeniz üyelik sözleşmesinin zorunlu unsuru değildir; ancak ilgili rehber özelliğinin çalışması için gereklidir.</li><li>Rızanızı dilediğiniz zaman profil ve destek kanalları üzerinden geri alabilirsiniz.</li><li>Geri alma, geri alma öncesi hukuka uygun işleme faaliyetlerini etkilemez.</li></ul>
<p>İrtibat: <a href="mailto:kvkk@sdal.org">kvkk@sdal.org</a></p>
</body></html>`);
  });
}
