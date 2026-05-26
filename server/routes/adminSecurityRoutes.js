import { getValidationRejections } from '../src/http/middleware/validate.js';

const TRACKED_SCHEMAS = [
  { route: 'POST /api/auth/login', schema: 'LoginSchema', fields: ['kadi', 'sifre'] },
  { route: 'POST /api/register/preview', schema: 'RegisterPreviewSchema', fields: ['kadi', 'sifre', 'sifre2', 'email', 'isim', 'soyisim', 'mezuniyetyili'] },
  { route: 'POST /api/register/check', schema: 'RegisterCheckSchema', fields: ['kadi', 'email'] },
];

const HELMET_HEADERS = [
  'X-Content-Type-Options',
  'X-Frame-Options',
  'Strict-Transport-Security',
  'X-DNS-Prefetch-Control',
  'X-Download-Options',
  'X-Permitted-Cross-Domain-Policies',
  'Referrer-Policy',
  'Cross-Origin-Resource-Policy',
];

function intParam(value, fallback, max) {
  const parsed = Number.parseInt(String(value ?? ''), 10);
  if (!Number.isFinite(parsed) || parsed <= 0) return fallback;
  return Math.min(parsed, max);
}

function hashPreview(value) {
  const text = String(value || '').trim();
  return text ? text.slice(0, 16) : '';
}

function parseMetadata(value) {
  if (!value) return null;
  if (typeof value === 'object') return value;
  try {
    return JSON.parse(String(value));
  } catch {
    return null;
  }
}

export function registerAdminSecurityRoutes(app, { requireAdmin, sqlGetAsync, sqlAllAsync, sqlRunAsync, logAdminAction }) {
  async function safeAll(label, sql, params = []) {
    try {
      return await sqlAllAsync(sql, params) || [];
    } catch (error) {
      console.warn(`admin.${label} failed:`, error?.message || error);
      return [];
    }
  }

  async function safeRun(label, sql, params = []) {
    try {
      return await sqlRunAsync(sql, params);
    } catch (error) {
      console.warn(`admin.${label} failed:`, error?.message || error);
      return null;
    }
  }

  function normalizeRole(value) {
    const role = String(value || 'user').trim().toLowerCase();
    return role || 'user';
  }

  function parseIssueCodes(value) {
    if (Array.isArray(value)) return value.map(String);
    return String(value || '')
      .split(',')
      .map((item) => item.trim())
      .filter(Boolean);
  }

  function supportActionLabel(action) {
    return {
      activate_account: 'Hesabı aktif et',
      unblock_account: 'Yasağı kaldır',
      clear_phone_requirement: 'Telefon zorunluluğunu kaldır',
      reset_phone_security: 'Telefon doğrulamasını sıfırla',
      clear_device_challenges: 'E-posta cihaz challenge kayıtlarını kapat',
      revoke_trusted_devices: 'Güvenilir cihazları iptal et',
      mark_profile_initialized: 'Profil onboarding tamamlandı işaretle',
      approve_verification: 'Profili manuel doğrula',
    }[action] || action;
  }

  function supportActionDescription(action) {
    return {
      activate_account: 'Aktivasyon maili/kodu takılan hesabı girişe açar.',
      unblock_account: 'Hatalı yasak veya destek sonrası açılması gereken hesabı kullanıma alır.',
      clear_phone_requirement: 'SMS/telefon doğrulama adımında kalan üyeyi ana akışa geçirir.',
      reset_phone_security: 'Kayıtlı telefon hashini temizler ve üyenin telefonu yeniden doğrulamasını sağlar.',
      clear_device_challenges: 'Yeni cihaz e-posta kodu takılan üyede açık challenge kayıtlarını tüketilmiş sayar.',
      revoke_trusted_devices: 'Şüpheli veya eski cihaz güvenlerini iptal eder; üye yeniden cihaz doğrular.',
      mark_profile_initialized: 'Profil onboarding bayrağı bozuksa ana uygulama kullanımını açar.',
      approve_verification: 'Doğrulama kaydı takılan üyeyi manuel doğrulanmış yapar.',
    }[action] || 'Destek aksiyonu uygular.';
  }

  function buildSupportActions(codes, row) {
    const actionKeys = new Set();
    if (codes.includes('activation_pending')) actionKeys.add('activate_account');
    if (codes.includes('account_banned')) actionKeys.add('unblock_account');
    if (codes.includes('phone_verification_blocked')) {
      actionKeys.add('clear_phone_requirement');
      actionKeys.add('reset_phone_security');
    }
    if (codes.includes('manual_auth_review')) actionKeys.add('clear_phone_requirement');
    if (codes.includes('device_challenge_pending')) actionKeys.add('clear_device_challenges');
    if (Number(row.active_trusted_devices || 0) > 0) actionKeys.add('revoke_trusted_devices');
    if (codes.includes('profile_onboarding_stuck')) actionKeys.add('mark_profile_initialized');
    if (codes.includes('verification_pending')) actionKeys.add('approve_verification');
    return Array.from(actionKeys).map((key) => ({
      key,
      label: supportActionLabel(key),
      description: supportActionDescription(key),
      destructive: key === 'reset_phone_security' || key === 'revoke_trusted_devices',
    }));
  }

  function buildSupportIssues(row) {
    const issues = [];
    const active = Number(row.aktiv || 0) === 1;
    const banned = Number(row.yasak || 0) === 1;
    const verified = Number(row.verified || 0) === 1;
    const profileInitialized = Number(row.ilkbd || 0) === 1;
    const phoneRequired = Number(row.phone_verification_required || 0) === 1;
    const manualReview = Number(row.manual_review_required || 0) === 1;
    const pendingChallenges = Number(row.pending_email_challenges || 0);
    const deniedSms = Number(row.denied_phone_attempts || 0);
    const verificationStatus = String(row.verification_status || '').trim().toLowerCase();

    if (!active) {
      issues.push({
        code: 'activation_pending',
        title: 'Aktivasyon takılmış',
        detail: 'Kullanıcı kayıtlı ancak hesabı aktif değil; login aktivasyon gerekli döner.',
        severity: 'high',
      });
    }
    if (banned) {
      issues.push({
        code: 'account_banned',
        title: 'Hesap yasaklı',
        detail: 'Üye normal kullanım ve login sonrası ana akışta bloke olur.',
        severity: 'critical',
      });
    }
    if (phoneRequired) {
      issues.push({
        code: 'phone_verification_blocked',
        title: 'Telefon doğrulama blokajı',
        detail: 'Üye SMS/telefon doğrulama adımını tamamlamadan uygulamaya geçemez.',
        severity: 'high',
      });
    }
    if (manualReview) {
      issues.push({
        code: 'manual_auth_review',
        title: 'Manuel auth inceleme',
        detail: String(row.suspicious_reason || '').trim() || 'Auth güvenlik bayrağı manuel inceleme istiyor.',
        severity: 'high',
      });
    }
    if (pendingChallenges > 0) {
      issues.push({
        code: 'device_challenge_pending',
        title: 'Yeni cihaz challenge açık',
        detail: `${pendingChallenges} açık e-posta cihaz challenge kaydı var.`,
        severity: 'medium',
      });
    }
    if (deniedSms >= 3) {
      issues.push({
        code: 'sms_attempt_denied',
        title: 'SMS denemeleri reddediliyor',
        detail: `${deniedSms} reddedilen telefon doğrulama denemesi var.`,
        severity: 'medium',
      });
    }
    if (!profileInitialized) {
      issues.push({
        code: 'profile_onboarding_stuck',
        title: 'Profil onboarding tamamlanmamış',
        detail: 'Üye ana kullanımda profil tamamlama akışına takılabilir.',
        severity: 'medium',
      });
    }
    if (!verified && (!verificationStatus || verificationStatus === 'pending')) {
      issues.push({
        code: 'verification_pending',
        title: 'Profil doğrulama bekliyor',
        detail: 'Doğrulama gerektiren modüller üyeyi kısıtlayabilir.',
        severity: 'low',
      });
    }
    return issues;
  }

  function severityRank(value) {
    return { critical: 4, high: 3, medium: 2, low: 1 }[String(value || '')] || 0;
  }

  /**
   * GET /api/new/admin/security/status
   * Returns validation rejection log, schema coverage, and active helmet headers.
   */
  app.get('/api/new/admin/security/status', requireAdmin, (req, res) => {
    const limit = Math.min(Number(req.query.limit) || 50, 200);
    const rejections = getValidationRejections(limit);

    const helmetHeaders = HELMET_HEADERS.map((name) => ({
      name,
      active: true, // helmet is registered globally; if the server is running, it's active
    }));

    res.json({
      helmet: {
        active: true,
        headers: helmetHeaders,
        cspDisabled: true,
        crossOriginResourcePolicy: 'same-site',
      },
      validation: {
        schemas: TRACKED_SCHEMAS,
        totalRejections: rejections.length,
        rejections,
      },
    });
  });

  /**
   * GET /api/new/admin/auth-security
   * Returns hash-only phone/device verification state for admin review.
   */
  app.get('/api/new/admin/auth-security', requireAdmin, async (req, res) => {
    const limit = intParam(req.query.limit, 25, 100);
    try {
      const [
        verifiedPhones,
        trustedDevices,
        phoneAttempts,
        auditLogs,
        emailChallenges,
        counts,
      ] = await Promise.all([
        sqlAllAsync(
          `SELECT f.user_id, u.kadi, u.isim, u.soyisim, f.phone_verified_at,
                  f.phone_verification_required, f.manual_review_required,
                  f.suspicious_reason, f.updated_at,
                  substr(f.phone_number_hash, 1, 16) AS phone_number_hash_preview
             FROM user_security_flags f
             LEFT JOIN uyeler u ON u.id = f.user_id
            WHERE f.phone_verified_at IS NOT NULL
            ORDER BY f.phone_verified_at DESC
            LIMIT ?`,
          [limit]
        ),
        sqlAllAsync(
          `SELECT d.id, d.user_id, u.kadi, u.isim, u.soyisim,
                  substr(d.device_id_hash, 1, 16) AS device_id_hash_preview,
                  d.device_name, d.platform, d.app_version, d.created_at,
                  d.last_seen_at, d.trusted_at, d.revoked_at,
                  substr(d.ip_created_hash, 1, 16) AS ip_created_hash_preview,
                  d.user_agent
             FROM trusted_devices d
             LEFT JOIN uyeler u ON u.id = d.user_id
            ORDER BY COALESCE(d.last_seen_at, d.trusted_at, d.created_at) DESC
            LIMIT ?`,
          [limit]
        ),
        sqlAllAsync(
          `SELECT a.id, a.user_id, u.kadi, u.isim, u.soyisim,
                  substr(a.phone_number_hash, 1, 16) AS phone_number_hash_preview,
                  substr(a.ip_hash, 1, 16) AS ip_hash_preview,
                  substr(a.device_id_hash, 1, 16) AS device_id_hash_preview,
                  a.status, a.reason, a.created_at
             FROM phone_verification_attempts a
             LEFT JOIN uyeler u ON u.id = a.user_id
            ORDER BY a.created_at DESC
            LIMIT ?`,
          [limit]
        ),
        sqlAllAsync(
          `SELECT l.id, l.user_id, u.kadi, u.isim, u.soyisim,
                  l.event_type, l.risk_level,
                  substr(l.ip_hash, 1, 16) AS ip_hash_preview,
                  substr(l.device_id_hash, 1, 16) AS device_id_hash_preview,
                  substr(l.phone_number_hash, 1, 16) AS phone_number_hash_preview,
                  substr(l.email_hash, 1, 16) AS email_hash_preview,
                  l.metadata, l.created_at
             FROM auth_audit_logs l
             LEFT JOIN uyeler u ON u.id = l.user_id
            ORDER BY l.created_at DESC
            LIMIT ?`,
          [limit]
        ),
        sqlAllAsync(
          `SELECT c.id, c.user_id, u.kadi, u.isim, u.soyisim,
                  substr(c.device_id_hash, 1, 16) AS device_id_hash_preview,
                  c.expires_at, c.consumed_at, c.created_at
             FROM auth_email_challenges c
             LEFT JOIN uyeler u ON u.id = c.user_id
            ORDER BY c.created_at DESC
            LIMIT ?`,
          [limit]
        ),
        sqlGetAsync(
          `SELECT
             (SELECT COUNT(*) FROM user_security_flags WHERE phone_verified_at IS NOT NULL) AS verified_phones,
             (SELECT COUNT(*) FROM trusted_devices WHERE revoked_at IS NULL) AS active_trusted_devices,
             (SELECT COUNT(*) FROM trusted_devices WHERE revoked_at IS NOT NULL) AS revoked_trusted_devices,
             (SELECT COUNT(*) FROM phone_verification_attempts) AS phone_attempts,
             (SELECT COUNT(*) FROM phone_verification_attempts WHERE status = 'denied') AS denied_phone_attempts,
             (SELECT COUNT(*) FROM auth_audit_logs) AS audit_logs,
             (SELECT COUNT(*) FROM auth_email_challenges WHERE consumed_at IS NULL) AS pending_email_challenges`
        ),
      ]);

      res.json({
        counts: counts || {},
        verifiedPhones: verifiedPhones.map((row) => ({
          ...row,
          phone_number_hash_preview: hashPreview(row.phone_number_hash_preview),
        })),
        trustedDevices: trustedDevices.map((row) => ({
          ...row,
          device_id_hash_preview: hashPreview(row.device_id_hash_preview),
          ip_created_hash_preview: hashPreview(row.ip_created_hash_preview),
        })),
        phoneAttempts: phoneAttempts.map((row) => ({
          ...row,
          phone_number_hash_preview: hashPreview(row.phone_number_hash_preview),
          ip_hash_preview: hashPreview(row.ip_hash_preview),
          device_id_hash_preview: hashPreview(row.device_id_hash_preview),
        })),
        auditLogs: auditLogs.map((row) => ({
          ...row,
          ip_hash_preview: hashPreview(row.ip_hash_preview),
          device_id_hash_preview: hashPreview(row.device_id_hash_preview),
          phone_number_hash_preview: hashPreview(row.phone_number_hash_preview),
          email_hash_preview: hashPreview(row.email_hash_preview),
          metadata: parseMetadata(row.metadata),
        })),
        emailChallenges: emailChallenges.map((row) => ({
          ...row,
          device_id_hash_preview: hashPreview(row.device_id_hash_preview),
        })),
      });
    } catch (error) {
      console.error('admin.auth-security failed:', error);
      res.status(500).json({ ok: false, message: 'Auth security snapshot could not be loaded.' });
    }
  });

  app.post('/api/new/admin/auth-security/trusted-devices/:id/revoke', requireAdmin, async (req, res) => {
    const id = Number(req.params.id || 0);
    if (!id) return res.status(400).json({ ok: false, message: 'Geçersiz cihaz kaydı.' });
    try {
      const row = await sqlGetAsync(
        `SELECT d.id, d.user_id, d.revoked_at, u.kadi
           FROM trusted_devices d
           LEFT JOIN uyeler u ON u.id = d.user_id
          WHERE d.id = ?`,
        [id]
      );
      if (!row) return res.status(404).json({ ok: false, message: 'Cihaz kaydı bulunamadı.' });
      if (row.revoked_at) return res.json({ ok: true, alreadyRevoked: true });
      const now = new Date().toISOString();
      await sqlRunAsync('UPDATE trusted_devices SET revoked_at = ? WHERE id = ?', [now, id]);
      if (typeof logAdminAction === 'function') {
        logAdminAction(req, 'trusted_device_revoked', {
          targetType: 'trusted_device',
          targetId: id,
          userId: Number(row.user_id || 0),
          handle: String(row.kadi || '')
        });
      }
      res.json({ ok: true, revokedAt: now });
    } catch (error) {
      console.error('admin.trusted-device-revoke failed:', error);
      res.status(500).json({ ok: false, message: 'Cihaz oturumu kapatılamadı.' });
    }
  });

  app.get('/api/new/admin/support-issues', requireAdmin, async (req, res) => {
    const limit = intParam(req.query.limit, 40, 100);
    const q = String(req.query.q || '').trim().toLowerCase();
    try {
      const rows = await safeAll(
        'support-issues',
        `SELECT u.id, u.kadi, u.isim, u.soyisim, u.email, u.aktiv, u.yasak, u.verified,
                u.verification_status, u.ilkbd, u.role, u.resim, u.sontarih,
                COALESCE(f.phone_verification_required, 0) AS phone_verification_required,
                COALESCE(f.manual_review_required, 0) AS manual_review_required,
                COALESCE(f.suspicious_reason, '') AS suspicious_reason,
                f.phone_verified_at,
                COALESCE(td.active_trusted_devices, 0) AS active_trusted_devices,
                COALESCE(pc.pending_email_challenges, 0) AS pending_email_challenges,
                COALESCE(pa.denied_phone_attempts, 0) AS denied_phone_attempts,
                COALESCE(al.warn_auth_events, 0) AS warn_auth_events,
                COALESCE(al.last_auth_event, '') AS last_auth_event,
                COALESCE(al.last_auth_at, '') AS last_auth_at
           FROM uyeler u
           LEFT JOIN user_security_flags f ON f.user_id = u.id
           LEFT JOIN (
             SELECT user_id, COUNT(*) AS active_trusted_devices
               FROM trusted_devices
              WHERE revoked_at IS NULL
              GROUP BY user_id
           ) td ON td.user_id = u.id
           LEFT JOIN (
             SELECT user_id, COUNT(*) AS pending_email_challenges
               FROM auth_email_challenges
              WHERE consumed_at IS NULL
              GROUP BY user_id
           ) pc ON pc.user_id = u.id
           LEFT JOIN (
             SELECT user_id, COUNT(*) AS denied_phone_attempts
               FROM phone_verification_attempts
              WHERE status = 'denied'
              GROUP BY user_id
           ) pa ON pa.user_id = u.id
           LEFT JOIN (
             SELECT l.user_id,
                    SUM(CASE WHEN l.risk_level IN ('warn', 'high', 'critical') THEN 1 ELSE 0 END) AS warn_auth_events,
                    MAX(l.event_type) AS last_auth_event,
                    MAX(l.created_at) AS last_auth_at
               FROM auth_audit_logs l
              GROUP BY l.user_id
           ) al ON al.user_id = u.id
          ORDER BY u.id DESC
          LIMIT ?`,
        [Math.max(limit * 4, limit)]
      );

      const items = rows
        .map((row) => {
          const issues = buildSupportIssues(row);
          const codes = issues.map((issue) => issue.code);
          return {
            user: {
              id: Number(row.id || 0),
              handle: String(row.kadi || ''),
              name: `${String(row.isim || '').trim()} ${String(row.soyisim || '').trim()}`.trim(),
              email: String(row.email || ''),
              avatar: String(row.resim || ''),
              role: String(row.role || 'user'),
              active: Number(row.aktiv || 0) === 1,
              banned: Number(row.yasak || 0) === 1,
              verified: Number(row.verified || 0) === 1,
              profileInitialized: Number(row.ilkbd || 0) === 1,
              verificationStatus: String(row.verification_status || ''),
              phoneVerificationRequired: Number(row.phone_verification_required || 0) === 1,
              manualReviewRequired: Number(row.manual_review_required || 0) === 1,
              phoneVerifiedAt: String(row.phone_verified_at || ''),
              activeTrustedDevices: Number(row.active_trusted_devices || 0),
              pendingEmailChallenges: Number(row.pending_email_challenges || 0),
              deniedPhoneAttempts: Number(row.denied_phone_attempts || 0),
              warnAuthEvents: Number(row.warn_auth_events || 0),
              lastAuthEvent: String(row.last_auth_event || ''),
              lastAuthAt: String(row.last_auth_at || ''),
              lastSeenAt: String(row.sontarih || ''),
            },
            issues,
            issueCodes: codes,
            actions: buildSupportActions(codes, row),
          };
        })
        .filter((item) => item.issues.length > 0)
        .filter((item) => {
          if (!q) return true;
          const haystack = [
            item.user.id,
            item.user.handle,
            item.user.name,
            item.user.email,
            item.user.verificationStatus,
            ...item.issueCodes,
            ...item.issues.map((issue) => `${issue.title} ${issue.detail}`),
          ].join(' ').toLowerCase();
          return haystack.includes(q);
        })
        .sort((a, b) => {
          const aRank = Math.max(...a.issues.map((issue) => severityRank(issue.severity)));
          const bRank = Math.max(...b.issues.map((issue) => severityRank(issue.severity)));
          if (bRank !== aRank) return bRank - aRank;
          return Number(b.user.id || 0) - Number(a.user.id || 0);
        })
        .slice(0, limit);

      const counts = {
        total: items.length,
        critical: 0,
        high: 0,
        medium: 0,
        low: 0,
        activation_pending: 0,
        account_banned: 0,
        phone_verification_blocked: 0,
        device_challenge_pending: 0,
        profile_onboarding_stuck: 0,
        verification_pending: 0,
      };
      for (const item of items) {
        const severities = new Set(item.issues.map((issue) => issue.severity));
        for (const severity of severities) counts[severity] = Number(counts[severity] || 0) + 1;
        for (const code of item.issueCodes) counts[code] = Number(counts[code] || 0) + 1;
      }

      res.json({ counts, items });
    } catch (error) {
      console.error('admin.support-issues failed:', error);
      res.status(500).json({ ok: false, message: 'Destek/edge case listesi yüklenemedi.' });
    }
  });

  app.post('/api/new/admin/support-issues/:userId/actions', requireAdmin, async (req, res) => {
    const userId = Number(req.params.userId || 0);
    const action = String(req.body?.action || '').trim();
    const reason = String(req.body?.reason || '').trim().slice(0, 500);
    if (!userId) return res.status(400).json({ ok: false, message: 'Geçersiz kullanıcı ID.' });
    const allowed = new Set([
      'activate_account',
      'unblock_account',
      'clear_phone_requirement',
      'reset_phone_security',
      'clear_device_challenges',
      'revoke_trusted_devices',
      'mark_profile_initialized',
      'approve_verification',
    ]);
    if (!allowed.has(action)) return res.status(400).json({ ok: false, message: 'Geçersiz destek aksiyonu.' });
    try {
      const target = await sqlGetAsync('SELECT id, kadi, role FROM uyeler WHERE id = ?', [userId]);
      if (!target) return res.status(404).json({ ok: false, message: 'Üye bulunamadı.' });
      if (normalizeRole(target.role) === 'root') {
        return res.status(403).json({ ok: false, message: 'Root kullanıcı destek aksiyonlarıyla değiştirilemez.' });
      }

      const now = new Date().toISOString();
      const applied = [];
      if (action === 'activate_account') {
        await sqlRunAsync('UPDATE uyeler SET aktiv = 1, aktivasyon = ? WHERE id = ?', [`admin-${Date.now()}`, userId]);
        applied.push('account_activated');
      } else if (action === 'unblock_account') {
        await sqlRunAsync('UPDATE uyeler SET yasak = 0 WHERE id = ?', [userId]);
        applied.push('account_unblocked');
      } else if (action === 'clear_phone_requirement') {
        await safeRun(
          'clear-phone-requirement',
          `INSERT INTO user_security_flags (user_id, phone_verification_required, manual_review_required, suspicious_reason, created_at, updated_at)
           VALUES (?, 0, 0, '', ?, ?)
           ON CONFLICT(user_id) DO UPDATE SET phone_verification_required = 0, manual_review_required = 0, suspicious_reason = '', updated_at = ?`,
          [userId, now, now, now]
        );
        applied.push('phone_requirement_cleared');
      } else if (action === 'reset_phone_security') {
        await safeRun(
          'reset-phone-security',
          `INSERT INTO user_security_flags (user_id, phone_verification_required, manual_review_required, phone_verified_at, phone_number_hash, suspicious_reason, created_at, updated_at)
           VALUES (?, 1, 0, NULL, NULL, '', ?, ?)
           ON CONFLICT(user_id) DO UPDATE SET phone_verification_required = 1, manual_review_required = 0, phone_verified_at = NULL, phone_number_hash = NULL, suspicious_reason = '', updated_at = ?`,
          [userId, now, now, now]
        );
        applied.push('phone_security_reset');
      } else if (action === 'clear_device_challenges') {
        await safeRun('clear-device-challenges', 'UPDATE auth_email_challenges SET consumed_at = ? WHERE user_id = ? AND consumed_at IS NULL', [now, userId]);
        applied.push('device_challenges_cleared');
      } else if (action === 'revoke_trusted_devices') {
        await safeRun('revoke-trusted-devices', 'UPDATE trusted_devices SET revoked_at = ? WHERE user_id = ? AND revoked_at IS NULL', [now, userId]);
        applied.push('trusted_devices_revoked');
      } else if (action === 'mark_profile_initialized') {
        await sqlRunAsync('UPDATE uyeler SET ilkbd = 1 WHERE id = ?', [userId]);
        applied.push('profile_initialized');
      } else if (action === 'approve_verification') {
        await sqlRunAsync("UPDATE uyeler SET verified = 1, verification_status = 'verified' WHERE id = ?", [userId]);
        applied.push('verification_approved');
      }

      if (typeof logAdminAction === 'function') {
        logAdminAction(req, 'support_issue_action', {
          targetType: 'user',
          targetId: userId,
          handle: String(target.kadi || ''),
          action,
          applied,
          reason: reason || undefined,
        });
      }
      res.json({ ok: true, userId, action, applied });
    } catch (error) {
      console.error('admin.support-issue-action failed:', error);
      res.status(500).json({ ok: false, message: 'Destek aksiyonu uygulanamadı.' });
    }
  });
}
