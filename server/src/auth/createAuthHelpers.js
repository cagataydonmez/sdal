export function createAuthHelpers({ port }) {
  function escapeHtml(value) {
    return String(value || '')
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;')
      .replace(/'/g, '&#39;');
  }

  function resolvePublicBaseUrl(req) {
    const configured = String(process.env.SDAL_BASE_URL || '').trim().replace(/\/+$/, '');
    if (configured) return configured;
    const xfProto = String(req.headers['x-forwarded-proto'] || '').split(',')[0].trim();
    const xfHost = String(req.headers['x-forwarded-host'] || '').split(',')[0].trim();
    const proto = xfProto || req.protocol || 'http';
    const host = xfHost || req.get('host') || `localhost:${port}`;
    return `${proto}://${host}`;
  }

  function _resolveEmailMeta({ siteBase, appName: appNameParam, supportEmail: supportEmailParam }) {
    const appName = String(appNameParam || 'SDAL');
    const safeBase = String(siteBase || '').replace(/\/+$/, '');
    const baseDomain = safeBase.replace(/^https?:\/\//, '') || 'sdal.org';
    const supportEmail = String(supportEmailParam || `destek@${baseDomain}`);
    return { appName, safeBase, supportEmail };
  }

  function buildActivationEmailText({ siteBase, user, appName: appNameParam, supportEmail: supportEmailParam }) {
    const { appName, safeBase, supportEmail } = _resolveEmailMeta({ siteBase, appName: appNameParam, supportEmail: supportEmailParam });
    const code = String(user?.aktivasyon || user?.activation_token || '');
    const fullName = `${user?.isim || user?.first_name || ''} ${user?.soyisim || user?.last_name || ''}`.trim()
      || (user?.kadi || user?.username ? `@${user.kadi || user.username}` : 'Üye');

    return [
      `${code} ${appName} doğrulama kodunuzdur.`,
      `${code} is your ${appName} verification code.`,
      '',
      `Merhaba ${fullName},`,
      '',
      `${appName} hesabınızı aktifleştirmek için doğrulama kodunuz:`,
      '',
      code,
      '',
      'Bu kodu kimseyle paylaşmayın.',
      '',
      `Bu e-postayı siz talep etmediyseniz lütfen ${supportEmail} adresine bildirin.`,
      safeBase
    ].join('\n');
  }

  function buildActivationEmailHtml({ siteBase, user, appName: appNameParam, supportEmail: supportEmailParam }) {
    const { appName, safeBase, supportEmail } = _resolveEmailMeta({ siteBase, appName: appNameParam, supportEmail: supportEmailParam });
    const code = escapeHtml(user?.aktivasyon || user?.activation_token || '');
    const fullName = `${user?.isim || user?.first_name || ''} ${user?.soyisim || user?.last_name || ''}`.trim()
      || (user?.kadi || user?.username ? `@${user.kadi || user.username}` : 'Üye');
    const safeName = escapeHtml(fullName);
    const safeKadi = escapeHtml(user?.kadi || user?.username || '');
    const safeSupport = escapeHtml(supportEmail);
    const safeAppName = escapeHtml(appName);
    const safeBase2 = escapeHtml(safeBase);

    return `<!doctype html>
<html lang="tr">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width,initial-scale=1" />
  <title>${safeAppName} Doğrulama Kodu</title>
</head>
<body style="margin:0;padding:20px 12px;background:#f3f4f6;font-family:Arial,sans-serif;color:#111827;">
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width:480px;margin:0 auto;">
    <tr>
      <td style="padding:0 0 6px;font-size:11px;color:#9ca3af;text-align:center;">${safeAppName} Doğrulama</td>
    </tr>
    <tr>
      <td style="background:#ffffff;border-radius:16px;overflow:hidden;border:1px solid #e5e7eb;">
        <table role="presentation" width="100%" cellpadding="0" cellspacing="0">
          <tr>
            <td style="padding:18px 24px;background:#111827;">
              <span style="font-size:18px;font-weight:800;color:#ffffff;letter-spacing:0.5px;">${safeAppName}</span>
            </td>
          </tr>
          <tr>
            <td style="padding:28px 24px 8px;">
              <p style="margin:0 0 6px;font-size:14px;color:#6b7280;">Merhaba <b style="color:#111827;">${safeName}</b>,</p>
              <p style="margin:8px 0 22px;font-size:14px;color:#374151;line-height:1.5;">
                ${safeAppName} hesabınızı aktifleştirmek için doğrulama kodunuz:
              </p>
              <table role="presentation" width="100%" cellpadding="0" cellspacing="0">
                <tr>
                  <td style="background:#f9fafb;border:1px solid #e5e7eb;border-radius:12px;padding:22px 16px;text-align:center;">
                    <div style="font-size:42px;font-weight:800;letter-spacing:10px;color:#111827;font-family:'Courier New',Courier,monospace;line-height:1;">${code}</div>
                  </td>
                </tr>
              </table>
              <p style="margin:16px 0 4px;font-size:13px;color:#374151;">
                Kodu uygulamadaki doğrulama alanına girin.
              </p>
              <p style="margin:0 0 24px;font-size:12px;font-weight:700;color:#dc2626;">
                Bu kodu kimseyle paylaşmayın.
              </p>
            </td>
          </tr>
          <tr>
            <td style="padding:12px 24px 20px;border-top:1px solid #f3f4f6;">
              <p style="margin:0 0 4px;font-size:11px;color:#9ca3af;">Kullanıcı adı: @${safeKadi}</p>
              <p style="margin:0;font-size:11px;color:#9ca3af;">
                Bu e-postayı siz talep etmediyseniz yok sayın veya
                <a href="mailto:${safeSupport}" style="color:#6b7280;">${safeSupport}</a> adresine bildirin.
              </p>
            </td>
          </tr>
        </table>
      </td>
    </tr>
    <tr>
      <td style="padding:10px 0;font-size:11px;color:#9ca3af;text-align:center;">
        <a href="${safeBase2}/" style="color:#9ca3af;text-decoration:none;">${safeBase2}</a>
      </td>
    </tr>
  </table>
</body>
</html>`;
  }

  function createActivation() {
    return String(Math.floor(100000 + Math.random() * 900000));
  }

  function normalizeEmail(email) {
    return String(email || '').trim();
  }

  function validateEmail(email) {
    return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(normalizeEmail(email));
  }

  function extractEmails(input) {
    const raw = String(input || '').trim();
    if (!raw) return [];
    const angleMatch = raw.match(/<([^>]+)>/);
    if (angleMatch) return [angleMatch[1].trim()];
    return raw
      .split(/[\s,;]+/)
      .map((value) => value.trim())
      .filter(Boolean);
  }

  return {
    escapeHtml,
    resolvePublicBaseUrl,
    buildActivationEmailHtml,
    buildActivationEmailText,
    createActivation,
    normalizeEmail,
    validateEmail,
    extractEmails
  };
}
