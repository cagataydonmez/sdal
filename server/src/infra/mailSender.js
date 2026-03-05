import nodemailer from 'nodemailer';

export function createMailSender({ isProd = false, logger = console } = {}) {
  let mailTransportPromise = null;

  function resolveMailProviderStatus() {
    const hasResend = Boolean(process.env.RESEND_API_KEY);
    const hasSmtpHost = Boolean(process.env.SMTP_HOST);
    const explicitMock = String(process.env.MAIL_ALLOW_MOCK || '').toLowerCase() === 'true';
    const mockAllowed = explicitMock || !isProd;
    const sender = process.env.RESEND_FROM || process.env.SMTP_FROM || 'sdal@sdal.org';

    if (hasResend) {
      return { provider: 'resend', configured: true, mockAllowed, sender };
    }
    if (hasSmtpHost) {
      return { provider: 'smtp', configured: true, mockAllowed, sender };
    }
    return { provider: 'none', configured: false, mockAllowed, sender };
  }

  async function getMailTransport() {
    if (mailTransportPromise) return mailTransportPromise;
    mailTransportPromise = (async () => {
      const host = process.env.SMTP_HOST;
      if (!host) return null;
      const port = Number(process.env.SMTP_PORT || 587);
      const secure = (process.env.SMTP_SECURE || '').toLowerCase() === 'true' || port === 465;
      return nodemailer.createTransport({
        host,
        port,
        secure,
        auth: process.env.SMTP_USER ? { user: process.env.SMTP_USER, pass: process.env.SMTP_PASS } : undefined,
        tls: process.env.SMTP_TLS_REJECT_UNAUTHORIZED
          ? { rejectUnauthorized: (process.env.SMTP_TLS_REJECT_UNAUTHORIZED || '').toLowerCase() !== 'false' }
          : undefined
      });
    })();
    return mailTransportPromise;
  }

  const status = resolveMailProviderStatus();
  if (!status.configured) {
    const message = 'Mail provider config missing: set RESEND_API_KEY or SMTP_HOST. In production, mail send will fail unless MAIL_ALLOW_MOCK=true.';
    if (status.mockAllowed) {
      logger.warn?.(message);
    } else {
      logger.error?.(message);
    }
  }

  async function sendMail({ to, subject, html, from }) {
    const sender = from || status.sender;

    if (status.provider === 'resend') {
      const recipients = Array.isArray(to)
        ? to
        : String(to || '')
            .split(',')
            .map((v) => v.trim())
            .filter(Boolean);

      if (!recipients.length) {
        if (status.mockAllowed) {
          logger.log?.('MAIL (mock):', { to, subject });
          return;
        }
        throw new Error('Mail recipients missing');
      }

      const resp = await fetch('https://api.resend.com/emails', {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${process.env.RESEND_API_KEY}`,
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({ from: sender, to: recipients, subject, html })
      });

      if (!resp.ok) {
        const text = await resp.text().catch(() => '');
        logger.error?.('Resend send error:', resp.status, text);
        throw new Error('Resend send failed');
      }
      return;
    }

    const transport = await getMailTransport();
    if (!transport) {
      if (status.mockAllowed) {
        logger.log?.('MAIL (mock):', { to, subject });
        return;
      }
      throw new Error('Mail provider not configured');
    }

    await transport.sendMail({ from: sender, to, subject, html });
  }

  async function sendMailWithTimeout(payload, timeoutMs = Number(process.env.MAIL_SEND_TIMEOUT_MS || 8000)) {
    const safeTimeoutMs = Number.isFinite(timeoutMs) && timeoutMs > 0 ? timeoutMs : 8000;
    let timer = null;
    try {
      await Promise.race([
        sendMail(payload),
        new Promise((_, reject) => {
          timer = setTimeout(() => reject(new Error('Mail send timeout')), safeTimeoutMs);
        })
      ]);
    } finally {
      if (timer) clearTimeout(timer);
    }
  }

  return {
    status,
    sendMail,
    sendMailWithTimeout
  };
}
