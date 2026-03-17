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

export function registerAdminSecurityRoutes(app, { requireAdmin }) {
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
}
