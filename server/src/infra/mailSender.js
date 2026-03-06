import nodemailer from 'nodemailer';

export function createMailSender({ isProd = false, logger = console } = {}) {
  let mailTransportPromise = null;
  const defaultTimeoutMs = toPositiveInt(process.env.MAIL_SEND_TIMEOUT_MS, 8_000);
  const defaultMaxRetries = toNonNegativeInt(process.env.MAIL_SEND_MAX_RETRIES, 2);
  const defaultRetryBackoffMs = toPositiveInt(process.env.MAIL_SEND_RETRY_BACKOFF_MS, 1_200);

  function normalizeBool(value, fallback = false) {
    const raw = String(value ?? '').trim().toLowerCase();
    if (!raw) return fallback;
    if (['1', 'true', 'yes', 'y', 'on'].includes(raw)) return true;
    if (['0', 'false', 'no', 'n', 'off'].includes(raw)) return false;
    return fallback;
  }

  function toPositiveInt(value, fallback) {
    const n = Number.parseInt(String(value ?? ''), 10);
    return Number.isFinite(n) && n > 0 ? n : fallback;
  }

  function toNonNegativeInt(value, fallback) {
    const n = Number.parseInt(String(value ?? ''), 10);
    return Number.isFinite(n) && n >= 0 ? n : fallback;
  }

  function wait(ms) {
    return new Promise((resolve) => setTimeout(resolve, ms));
  }

  function nowMs() {
    return Date.now();
  }

  function parseRecipients(to) {
    if (Array.isArray(to)) {
      return to
        .map((value) => String(value || '').trim())
        .filter(Boolean);
    }

    return String(to || '')
      .split(/[;,]/)
      .map((value) => value.trim())
      .filter(Boolean);
  }

  function parseSender(fromValue, fallback) {
    const raw = String(fromValue || fallback || '').trim();
    if (!raw) {
      return { email: '', name: '' };
    }
    const angle = raw.match(/^\s*"?([^"<]*)"?\s*<([^>]+)>\s*$/);
    if (angle) {
      return {
        name: String(angle[1] || '').trim(),
        email: String(angle[2] || '').trim()
      };
    }
    return { email: raw, name: '' };
  }

  function createMailError(message, {
    code = 'MAIL_SEND_FAILED',
    retryable = true,
    statusCode = null,
    cause = null
  } = {}) {
    const err = new Error(message || 'Mail send failed');
    err.name = 'MailSendError';
    err.code = code;
    err.retryable = retryable;
    if (statusCode !== null && statusCode !== undefined) err.statusCode = Number(statusCode);
    if (cause) err.cause = cause;
    return err;
  }

  function classifyRetryableError(err) {
    if (!err) return true;
    if (err.retryable === false) return false;

    const code = String(err.code || '').toUpperCase();
    if (['MAIL_CONFIG_MISSING', 'MAIL_RECIPIENT_MISSING', 'EENVELOPE', 'EAUTH', 'MAIL_PROVIDER_DISABLED'].includes(code)) {
      return false;
    }

    const statusCode = Number(err.statusCode || 0);
    if (statusCode >= 400 && statusCode < 500 && statusCode !== 429) return false;
    return true;
  }

  function resolveMailProviderStatus() {
    const providerPref = String(process.env.MAIL_PROVIDER || 'auto').trim().toLowerCase();
    const hasResend = Boolean(process.env.RESEND_API_KEY);
    const hasBrevoApi = Boolean(process.env.BREVO_API_KEY || process.env.MAIL_BREVO_API_KEY);
    const smtpHost = String(process.env.MAIL_SMTP_HOST || process.env.SMTP_HOST || '').trim();
    const hasSmtpHost = Boolean(smtpHost);
    const explicitMock = String(process.env.MAIL_ALLOW_MOCK || '').toLowerCase() === 'true';
    const mockAllowed = explicitMock || !isProd;
    const sender = process.env.MAIL_FROM || process.env.RESEND_FROM || process.env.MAIL_SMTP_FROM || process.env.SMTP_FROM || 'sdal@sdal.org';

    const prefersBrevo = providerPref === 'brevo';
    const smtpConfigured = hasSmtpHost || prefersBrevo;
    const providerFromPreference = (() => {
      if (providerPref === 'mock') return 'mock';
      if (providerPref === 'resend') return 'resend';
      if (providerPref === 'brevo_api' || providerPref === 'brevo-api' || providerPref === 'brevoapi') return 'brevo_api';
      if (providerPref === 'smtp' || providerPref === 'brevo') return 'smtp';
      if (providerPref === 'none') return 'none';
      return null;
    })();

    const selectedProvider = (() => {
      if (providerFromPreference) return providerFromPreference;
      if (hasResend) return 'resend';
      if (hasBrevoApi) return 'brevo_api';
      if (smtpConfigured) return 'smtp';
      return mockAllowed ? 'mock' : 'none';
    })();

    const configured = (() => {
      if (selectedProvider === 'mock') return true;
      if (selectedProvider === 'resend') return hasResend;
      if (selectedProvider === 'brevo_api') return hasBrevoApi;
      if (selectedProvider === 'smtp') return smtpConfigured;
      return false;
    })();

    return {
      provider: selectedProvider,
      configured,
      mockAllowed,
      sender,
      providerPreference: providerPref || 'auto',
      retry: {
        timeoutMs: defaultTimeoutMs,
        maxRetries: defaultMaxRetries,
        backoffMs: defaultRetryBackoffMs
      }
    };
  }

  function resolveSmtpConfig(providerStatus) {
    const isBrevoPreset = providerStatus.providerPreference === 'brevo';
    const host = String(
      process.env.MAIL_SMTP_HOST
      || process.env.SMTP_HOST
      || (isBrevoPreset ? 'smtp-relay.brevo.com' : '')
    ).trim();
    const port = toPositiveInt(process.env.MAIL_SMTP_PORT || process.env.SMTP_PORT, 587);
    const secure = normalizeBool(
      process.env.MAIL_SMTP_SECURE ?? process.env.SMTP_SECURE,
      port === 465
    );
    const user = String(process.env.MAIL_SMTP_USER || process.env.SMTP_USER || '').trim();
    const pass = String(process.env.MAIL_SMTP_PASS || process.env.SMTP_PASS || '').trim();
    const tlsRejectUnauthorized = normalizeBool(
      process.env.MAIL_SMTP_TLS_REJECT_UNAUTHORIZED ?? process.env.SMTP_TLS_REJECT_UNAUTHORIZED,
      true
    );

    return {
      host,
      port,
      secure,
      auth: user ? { user, pass } : undefined,
      tls: { rejectUnauthorized: tlsRejectUnauthorized }
    };
  }

  async function getMailTransport(providerStatus) {
    if (mailTransportPromise) return mailTransportPromise;
    mailTransportPromise = (async () => {
      const smtp = resolveSmtpConfig(providerStatus);
      const host = smtp.host;
      if (!host) return null;
      return nodemailer.createTransport({
        host,
        port: smtp.port,
        secure: smtp.secure,
        auth: smtp.auth,
        tls: smtp.tls
      });
    })();
    return mailTransportPromise;
  }

  const status = resolveMailProviderStatus();
  if (!status.configured) {
    const message = 'Mail provider config missing: set MAIL_PROVIDER and corresponding SMTP/API vars. In production, mail send fails unless MAIL_ALLOW_MOCK=true.';
    if (status.mockAllowed) {
      logger.warn?.(message);
    } else {
      logger.error?.(message);
    }
  }

  async function sendWithResend({ to, subject, html, from }, providerStatus) {
    const sender = from || providerStatus.sender;
    const recipients = parseRecipients(to);
    if (!recipients.length) {
      throw createMailError('Mail recipients missing', { code: 'MAIL_RECIPIENT_MISSING', retryable: false });
    }

    const resp = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${process.env.RESEND_API_KEY}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({ from: sender, to: recipients, subject, html })
    });

    const responseText = await resp.text().catch(() => '');
    if (!resp.ok) {
      throw createMailError('Resend send failed', {
        code: 'MAIL_RESEND_HTTP',
        retryable: resp.status >= 500 || resp.status === 429,
        statusCode: resp.status,
        cause: responseText
      });
    }

    return {
      provider: 'resend',
      acceptedCount: recipients.length,
      response: responseText
    };
  }

  async function sendWithSmtp({ to, subject, html, from }, providerStatus) {
    const sender = from || providerStatus.sender;
    const recipients = parseRecipients(to);
    if (!recipients.length) {
      throw createMailError('Mail recipients missing', { code: 'MAIL_RECIPIENT_MISSING', retryable: false });
    }

    const transport = await getMailTransport(providerStatus);
    if (!transport) {
      throw createMailError('SMTP transport is not configured', { code: 'MAIL_CONFIG_MISSING', retryable: false });
    }

    const info = await transport.sendMail({ from: sender, to: recipients, subject, html });
    return {
      provider: 'smtp',
      acceptedCount: Array.isArray(info?.accepted) ? info.accepted.length : recipients.length,
      rejectedCount: Array.isArray(info?.rejected) ? info.rejected.length : 0,
      messageId: info?.messageId || null
    };
  }

  async function sendWithBrevoApi({ to, subject, html, from }, providerStatus) {
    const senderRaw = from || providerStatus.sender;
    const sender = parseSender(senderRaw, providerStatus.sender);
    const recipients = parseRecipients(to);
    const apiKey = String(process.env.BREVO_API_KEY || process.env.MAIL_BREVO_API_KEY || '').trim();
    if (!apiKey) {
      throw createMailError('Brevo API key missing', { code: 'MAIL_CONFIG_MISSING', retryable: false });
    }
    if (!sender.email) {
      throw createMailError('Mail sender missing', { code: 'MAIL_CONFIG_MISSING', retryable: false });
    }
    if (!recipients.length) {
      throw createMailError('Mail recipients missing', { code: 'MAIL_RECIPIENT_MISSING', retryable: false });
    }

    const response = await fetch('https://api.brevo.com/v3/smtp/email', {
      method: 'POST',
      headers: {
        'api-key': apiKey,
        Accept: 'application/json',
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        sender: sender.name ? { name: sender.name, email: sender.email } : { email: sender.email },
        to: recipients.map((email) => ({ email })),
        subject: String(subject || ''),
        htmlContent: String(html || '')
      })
    });

    const responseText = await response.text().catch(() => '');
    if (!response.ok) {
      throw createMailError('Brevo API send failed', {
        code: 'MAIL_BREVO_API_HTTP',
        retryable: response.status >= 500 || response.status === 429,
        statusCode: response.status,
        cause: responseText
      });
    }

    return {
      provider: 'brevo_api',
      acceptedCount: recipients.length,
      response: responseText
    };
  }

  async function sendMail({ to, subject, html, from }) {
    const runtimeStatus = resolveMailProviderStatus();
    const sender = from || runtimeStatus.sender;

    if (runtimeStatus.provider === 'resend') {
      return sendWithResend({ to, subject, html, from: sender }, runtimeStatus);
    }
    if (runtimeStatus.provider === 'brevo_api') {
      return sendWithBrevoApi({ to, subject, html, from: sender }, runtimeStatus);
    }
    if (runtimeStatus.provider === 'smtp') {
      return sendWithSmtp({ to, subject, html, from: sender }, runtimeStatus);
    }
    if (runtimeStatus.provider === 'mock' || runtimeStatus.mockAllowed) {
      logger.info?.('[mail] mock send', {
        provider: runtimeStatus.provider,
        toCount: parseRecipients(to).length,
        subjectLength: String(subject || '').length
      });
      return { provider: 'mock', acceptedCount: parseRecipients(to).length };
    }
    throw createMailError('Mail provider is not configured', {
      code: 'MAIL_CONFIG_MISSING',
      retryable: false
    });
  }

  async function runSendWithTimeout(payload, timeoutMs) {
    let timer = null;
    try {
      return await Promise.race([
        sendMail(payload),
        new Promise((_, reject) => {
          timer = setTimeout(() => {
            reject(createMailError('Mail send timeout', {
              code: 'MAIL_TIMEOUT',
              retryable: true
            }));
          }, timeoutMs);
        })
      ]);
    } catch (err) {
      if (err?.name === 'MailSendError') throw err;
      throw createMailError(err?.message || 'Mail send failure', {
        code: err?.code || 'MAIL_SEND_FAILED',
        retryable: classifyRetryableError(err),
        statusCode: err?.statusCode,
        cause: err
      });
    } finally {
      if (timer) {
        clearTimeout(timer);
      }
    }
  }

  async function sendMailWithTimeout(payload, timeoutMs = defaultTimeoutMs, retryOptions = {}) {
    const safeTimeoutMs = toPositiveInt(timeoutMs, defaultTimeoutMs);
    const maxRetries = toNonNegativeInt(retryOptions.maxRetries, defaultMaxRetries);
    const retryBackoffMs = toPositiveInt(retryOptions.backoffMs, defaultRetryBackoffMs);
    const attemptsLimit = maxRetries + 1;
    const startedAt = nowMs();

    let attempt = 0;
    while (attempt < attemptsLimit) {
      attempt += 1;
      try {
        const result = await runSendWithTimeout(payload, safeTimeoutMs);
        logger.info?.('[mail] send success', {
          provider: result?.provider || status.provider,
          attempt,
          attemptsLimit,
          durationMs: nowMs() - startedAt,
          toCount: parseRecipients(payload?.to).length
        });
        return result;
      } catch (err) {
        const retryable = classifyRetryableError(err);
        const isFinal = !retryable || attempt >= attemptsLimit;
        const logFn = isFinal ? logger.error : logger.warn;
        const runtimeStatus = resolveMailProviderStatus();
        logFn?.('[mail] send failure', {
          provider: runtimeStatus.provider,
          attempt,
          attemptsLimit,
          retryable,
          code: err?.code || 'MAIL_SEND_FAILED',
          statusCode: err?.statusCode || null,
          message: err?.message || 'unknown error'
        });

        if (isFinal) throw err;
        const delayMs = Math.min(retryBackoffMs * (2 ** (attempt - 1)), 15_000);
        await wait(delayMs);
      }
    }
  }

  return {
    status,
    getStatus: resolveMailProviderStatus,
    sendMail,
    sendMailWithTimeout
  };
}
