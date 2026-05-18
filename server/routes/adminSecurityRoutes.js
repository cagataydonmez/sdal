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
}
