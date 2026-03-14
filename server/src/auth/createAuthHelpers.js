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

  function buildActivationEmailHtml({ siteBase, activationLink, user }) {
    const safeBase = String(siteBase || '').replace(/\/+$/, '');
    const safeActivation = String(activationLink || '');
    const fullName = `${user?.isim || ''} ${user?.soyisim || ''}`.trim() || (user?.kadi ? `@${user.kadi}` : 'Üye');
    const safeName = escapeHtml(fullName);
    const safeKadi = escapeHtml(user?.kadi || '');
    const safeLink = escapeHtml(safeActivation);
    return `<!doctype html>
<html>
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width,initial-scale=1" />
  <title>SDAL Aktivasyon</title>
</head>
<body style="margin:0;padding:24px;background:#f4efe8;font-family:Arial,sans-serif;color:#1f2937;">
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width:640px;margin:0 auto;background:#ffffff;border-radius:16px;overflow:hidden;border:1px solid #e5e7eb;">
    <tr>
      <td style="padding:20px 24px;background:linear-gradient(135deg,#111827 0%, #2b3444 100%);color:#fff;">
        <div style="font-size:20px;font-weight:700;letter-spacing:0.3px;">SDAL</div>
        <div style="opacity:0.85;font-size:13px;margin-top:4px;">Hesap Aktivasyonu</div>
      </td>
    </tr>
    <tr>
      <td style="padding:24px;">
        <p style="margin:0 0 12px;font-size:16px;">Merhaba <b>${safeName}</b>,</p>
        <p style="margin:0 0 16px;line-height:1.5;">Üyelik işlemini tamamlamak için aşağıdaki düğmeyi kullanabilirsin.</p>
        <p style="margin:0 0 18px;">
          <a href="${safeActivation}" target="_blank" rel="noreferrer" style="display:inline-block;padding:12px 18px;background:#ff6b4a;color:#111827;text-decoration:none;border-radius:999px;font-weight:700;">Hesabı Aktifleştir</a>
        </p>
        <p style="margin:0 0 8px;color:#6b7280;font-size:13px;">Kullanıcı adı: <b style="color:#111827">@${safeKadi}</b></p>
        <p style="margin:0 0 6px;color:#6b7280;font-size:13px;">Buton çalışmazsa bağlantıyı kopyala:</p>
        <p style="margin:0;font-size:12px;word-break:break-all;"><a href="${safeActivation}" target="_blank" rel="noreferrer" style="color:#2563eb;">${safeLink}</a></p>
      </td>
    </tr>
    <tr>
      <td style="padding:16px 24px;background:#f9fafb;color:#6b7280;font-size:12px;">
        SDAL hesabını sen açmadıysan bu e-postayı yok sayabilirsin.<br/>
        <a href="${escapeHtml(safeBase)}/" target="_blank" rel="noreferrer" style="color:#4b5563;">${escapeHtml(safeBase)}</a>
      </td>
    </tr>
  </table>
</body>
</html>`;
  }

  function createActivation() {
    const chars = 'abdefghijklmoprstuvyzABDEFGHIKLMOPRSTUVYZ';
    let out = 'SdAl';
    for (let i = 0; i < 20; i += 1) {
      const idx = Math.floor(Math.random() * chars.length);
      out += chars[idx];
    }
    return out;
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
    createActivation,
    normalizeEmail,
    validateEmail,
    extractEmails
  };
}
