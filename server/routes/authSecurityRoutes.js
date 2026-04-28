import crypto from 'crypto';
import { z } from 'zod';

const GENERIC_AUTH_MESSAGE = 'Bu işlemi doğrulayamadık. Lütfen daha sonra tekrar deneyin.';
const GENERIC_COOLDOWN_MESSAGE = 'Çok fazla deneme yapıldı. Lütfen daha sonra tekrar deneyin.';

const DeviceSchema = z.object({
  device_id: z.string().min(16).max(128),
  platform: z.enum(['ios', 'android']).catch('android'),
  device_name: z.string().max(120).optional().default(''),
  app_version: z.string().max(64).optional().default('')
});

const PhoneStartSchema = z.object({
  phone_number: z.string().min(7).max(32),
  device_id: z.string().min(16).max(128).optional().default('')
});

const PhoneCompleteSchema = PhoneStartSchema.extend({
  firebase_id_token: z.string().min(20),
  platform: z.enum(['ios', 'android']).catch('android'),
  device_name: z.string().max(120).optional().default(''),
  app_version: z.string().max(64).optional().default('')
});

const EmailChallengeSchema = DeviceSchema.extend({
  code: z.string().min(4).max(12)
});

function intEnv(name, fallback) {
  const parsed = parseInt(process.env[name] || '', 10);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : fallback;
}

function boolEnv(name, fallback = false) {
  const raw = String(process.env[name] ?? '').trim().toLowerCase();
  if (!raw) return fallback;
  return ['1', 'true', 'yes', 'evet'].includes(raw);
}

function csvEnv(name) {
  return String(process.env[name] || '')
    .split(',')
    .map((item) => item.trim())
    .filter(Boolean);
}

function sha256(value, pepper) {
  return crypto.createHmac('sha256', pepper).update(String(value || ''), 'utf8').digest('hex');
}

function normalizePhoneNumber(raw) {
  const compact = String(raw || '').replace(/[\s().-]/g, '');
  if (!compact) return '';
  if (compact.startsWith('+')) {
    return /^\+[1-9]\d{7,14}$/.test(compact) ? compact : '';
  }
  const digits = compact.replace(/\D/g, '');
  let normalized = '';
  if (digits.startsWith('00')) {
    normalized = `+${digits.slice(2)}`;
  } else if (digits.startsWith('0') && digits.length === 11) {
    normalized = `+90${digits.slice(1)}`;
  } else if (digits.startsWith('90') && digits.length === 12) {
    normalized = `+${digits}`;
  } else if (digits.startsWith('5') && digits.length === 10) {
    normalized = `+90${digits}`;
  } else {
    normalized = `+${digits}`;
  }
  if (!/^\+[1-9]\d{7,14}$/.test(normalized)) return '';
  return normalized;
}

function normalizeIp(ip) {
  return String(ip || '').replace(/^::ffff:/, '').trim();
}

function hourAgoIso(hours = 1) {
  return new Date(Date.now() - hours * 60 * 60 * 1000).toISOString();
}

function secondsUntil(iso, cooldownSeconds) {
  const at = Date.parse(iso || '');
  if (!Number.isFinite(at)) return cooldownSeconds;
  return Math.max(1, Math.ceil((at + cooldownSeconds * 1000 - Date.now()) / 1000));
}

function safeJson(value) {
  try {
    return JSON.stringify(value ?? {});
  } catch {
    return '{}';
  }
}

export function createAuthSecurityRuntime({
  dbDriver,
  sqlGetAsync,
  sqlAllAsync,
  sqlRunAsync,
  writeAppLog,
  queueEmailDelivery,
  resolvePublicBaseUrl,
  escapeHtml,
  applyUserSession,
  selectCompatUserByIdAsync,
  requireAuth
}) {
  const pepper = String(process.env.AUTH_DEVICE_HASH_PEPPER || process.env.SDAL_SESSION_SECRET || '').trim();
  const config = {
    smsMinIntervalSeconds: intEnv('AUTH_SMS_MIN_INTERVAL_SECONDS', 60),
    smsPhoneHourlyLimit: intEnv('AUTH_SMS_PHONE_HOURLY_LIMIT', 3),
    smsUserDailyLimit: intEnv('AUTH_SMS_USER_DAILY_LIMIT', 3),
    smsIpHourlyLimit: intEnv('AUTH_SMS_IP_HOURLY_LIMIT', 10),
    smsIpDailyLimit: intEnv('AUTH_SMS_IP_DAILY_LIMIT', 30),
    authDeviceHourlyLimit: intEnv('AUTH_DEVICE_HOURLY_LIMIT', 5),
    signupIpHourlyLimit: intEnv('AUTH_SIGNUP_IP_HOURLY_LIMIT', 20),
    blockDisposableEmails: boolEnv('AUTH_BLOCK_DISPOSABLE_EMAILS', false),
    firebasePhoneMock: boolEnv('AUTH_FIREBASE_PHONE_MOCK', false),
    smsTestCode: String(process.env.AUTH_SMS_TEST_CODE || '').trim(),
    smsRateLimitBypassPhones: csvEnv('AUTH_SMS_RATE_LIMIT_BYPASS_PHONES')
      .map(normalizePhoneNumber)
      .filter(Boolean)
  };

  async function ensureSchema() {
    const idColumn = dbDriver === 'postgres' ? 'BIGSERIAL PRIMARY KEY' : 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const nowDefault = 'CURRENT_TIMESTAMP';
    await sqlRunAsync(`CREATE TABLE IF NOT EXISTS trusted_devices (
      id ${idColumn},
      user_id INTEGER NOT NULL,
      device_id_hash TEXT NOT NULL,
      device_name TEXT,
      platform TEXT NOT NULL,
      app_version TEXT,
      created_at TEXT NOT NULL DEFAULT ${nowDefault},
      last_seen_at TEXT NOT NULL DEFAULT ${nowDefault},
      trusted_at TEXT NOT NULL DEFAULT ${nowDefault},
      revoked_at TEXT,
      ip_created_hash TEXT,
      user_agent TEXT,
      device_info TEXT
    )`);
    await sqlRunAsync('CREATE UNIQUE INDEX IF NOT EXISTS idx_trusted_devices_user_hash_active ON trusted_devices (user_id, device_id_hash, revoked_at)');
    await sqlRunAsync('CREATE INDEX IF NOT EXISTS idx_trusted_devices_user ON trusted_devices (user_id)');
    await sqlRunAsync('CREATE INDEX IF NOT EXISTS idx_trusted_devices_hash ON trusted_devices (device_id_hash)');
    await sqlRunAsync(`CREATE TABLE IF NOT EXISTS phone_verification_attempts (
      id ${idColumn},
      user_id INTEGER,
      phone_number_hash TEXT NOT NULL,
      ip_hash TEXT,
      device_id_hash TEXT,
      status TEXT NOT NULL,
      reason TEXT,
      created_at TEXT NOT NULL DEFAULT ${nowDefault}
    )`);
    await sqlRunAsync('CREATE INDEX IF NOT EXISTS idx_phone_attempts_phone_created ON phone_verification_attempts (phone_number_hash, created_at)');
    await sqlRunAsync('CREATE INDEX IF NOT EXISTS idx_phone_attempts_user_created ON phone_verification_attempts (user_id, created_at)');
    await sqlRunAsync('CREATE INDEX IF NOT EXISTS idx_phone_attempts_ip_created ON phone_verification_attempts (ip_hash, created_at)');
    await sqlRunAsync('CREATE INDEX IF NOT EXISTS idx_phone_attempts_device_created ON phone_verification_attempts (device_id_hash, created_at)');
    await sqlRunAsync(`CREATE TABLE IF NOT EXISTS auth_rate_limits (
      id ${idColumn},
      scope TEXT NOT NULL,
      key_hash TEXT NOT NULL,
      action TEXT NOT NULL,
      created_at TEXT NOT NULL DEFAULT ${nowDefault}
    )`);
    await sqlRunAsync('CREATE INDEX IF NOT EXISTS idx_auth_rate_limits_scope_key_created ON auth_rate_limits (scope, key_hash, created_at)');
    await sqlRunAsync(`CREATE TABLE IF NOT EXISTS auth_audit_logs (
      id ${idColumn},
      user_id INTEGER,
      event_type TEXT NOT NULL,
      risk_level TEXT NOT NULL DEFAULT 'info',
      ip_hash TEXT,
      device_id_hash TEXT,
      phone_number_hash TEXT,
      email_hash TEXT,
      metadata TEXT,
      created_at TEXT NOT NULL DEFAULT ${nowDefault}
    )`);
    await sqlRunAsync('CREATE INDEX IF NOT EXISTS idx_auth_audit_logs_event_created ON auth_audit_logs (event_type, created_at)');
    await sqlRunAsync(`CREATE TABLE IF NOT EXISTS user_security_flags (
      user_id INTEGER PRIMARY KEY,
      phone_verified_at TEXT,
      phone_number_hash TEXT,
      phone_verification_required INTEGER NOT NULL DEFAULT 0,
      manual_review_required INTEGER NOT NULL DEFAULT 0,
      suspicious_reason TEXT,
      created_at TEXT NOT NULL DEFAULT ${nowDefault},
      updated_at TEXT NOT NULL DEFAULT ${nowDefault}
    )`);
    await sqlRunAsync(`CREATE TABLE IF NOT EXISTS auth_email_challenges (
      id ${idColumn},
      user_id INTEGER NOT NULL,
      device_id_hash TEXT NOT NULL,
      code_hash TEXT NOT NULL,
      expires_at TEXT NOT NULL,
      consumed_at TEXT,
      created_at TEXT NOT NULL DEFAULT ${nowDefault}
    )`);
    await sqlRunAsync('CREATE INDEX IF NOT EXISTS idx_auth_email_challenges_user_device ON auth_email_challenges (user_id, device_id_hash, created_at)');
    if (!pepper) {
      writeAppLog?.('warn', 'auth_security_missing_hash_pepper', { message: 'AUTH_DEVICE_HASH_PEPPER is not configured' });
    }
  }

  function hashDeviceId(deviceId) {
    return sha256(deviceId, pepper || 'dev-missing-pepper');
  }

  function hashPhone(phone) {
    return sha256(phone, pepper || 'dev-missing-pepper');
  }

  function hashIp(ip) {
    return sha256(normalizeIp(ip), pepper || 'dev-missing-pepper');
  }

  async function audit({ userId = null, eventType, riskLevel = 'info', req, deviceIdHash = '', phoneHash = '', email = '', metadata = {} }) {
    await sqlRunAsync(
      `INSERT INTO auth_audit_logs (user_id, event_type, risk_level, ip_hash, device_id_hash, phone_number_hash, email_hash, metadata, created_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [userId, eventType, riskLevel, hashIp(req?.ip), deviceIdHash || null, phoneHash || null, email ? sha256(String(email).toLowerCase(), pepper || 'dev-missing-pepper') : null, safeJson(metadata), new Date().toISOString()]
    );
  }

  async function countSince(table, whereSql, params, sinceIso) {
    const row = await sqlGetAsync(`SELECT COUNT(*) AS cnt FROM ${table} WHERE ${whereSql} AND created_at >= ?`, [...params, sinceIso]);
    return Number(row?.cnt || 0);
  }

  async function denySms(req, userId, reason, retryAfterSeconds, phoneHash, deviceHash) {
    await sqlRunAsync(
      `INSERT INTO phone_verification_attempts (user_id, phone_number_hash, ip_hash, device_id_hash, status, reason, created_at)
       VALUES (?, ?, ?, ?, 'denied', ?, ?)`,
      [userId, phoneHash, hashIp(req.ip), deviceHash || null, reason, new Date().toISOString()]
    );
    await audit({ userId, eventType: 'sms_attempt_denied', riskLevel: 'warn', req, deviceIdHash: deviceHash, phoneHash, metadata: { reason, retryAfterSeconds } });
    return { allowed: false, retry_after_seconds: retryAfterSeconds, message: GENERIC_COOLDOWN_MESSAGE };
  }

  async function checkSmsAllowed(req, userId, phone, deviceId = '') {
    const phoneHash = hashPhone(phone);
    const ipHash = hashIp(req.ip);
    const deviceHash = deviceId ? hashDeviceId(deviceId) : '';
    if (config.smsRateLimitBypassPhones.includes(phone)) {
      await sqlRunAsync(
        `INSERT INTO phone_verification_attempts (user_id, phone_number_hash, ip_hash, device_id_hash, status, reason, created_at)
         VALUES (?, ?, ?, ?, 'allowed', 'test_bypass', ?)`,
        [userId, phoneHash, ipHash, deviceHash || null, new Date().toISOString()]
      );
      await audit({ userId, eventType: 'sms_attempt_test_bypass', req, deviceIdHash: deviceHash, phoneHash });
      return {
        allowed: true,
        phone_number: phone,
        retry_after_seconds: 0,
        mock_verification: shouldUseMockPhoneVerification(phone)
      };
    }
    const latest = await sqlGetAsync(
      `SELECT created_at FROM phone_verification_attempts
       WHERE phone_number_hash = ? AND status = 'allowed'
       ORDER BY created_at DESC LIMIT 1`,
      [phoneHash]
    );
    if (latest?.created_at && Date.now() - Date.parse(latest.created_at) < config.smsMinIntervalSeconds * 1000) {
      return denySms(req, userId, 'phone_cooldown', secondsUntil(latest.created_at, config.smsMinIntervalSeconds), phoneHash, deviceHash);
    }
    const phoneHourly = await countSince('phone_verification_attempts', "phone_number_hash = ? AND status = 'allowed'", [phoneHash], hourAgoIso(1));
    if (phoneHourly >= config.smsPhoneHourlyLimit) {
      return denySms(req, userId, 'phone_hourly_limit', 3600, phoneHash, deviceHash);
    }
    const userDaily = await countSince('phone_verification_attempts', "user_id = ? AND status = 'allowed'", [userId], hourAgoIso(24));
    if (userDaily >= config.smsUserDailyLimit) {
      return denySms(req, userId, 'user_daily_limit', 86400, phoneHash, deviceHash);
    }
    const ipHourly = await countSince('phone_verification_attempts', "ip_hash = ? AND status = 'allowed'", [ipHash], hourAgoIso(1));
    if (ipHourly >= config.smsIpHourlyLimit) {
      return denySms(req, userId, 'ip_hourly_limit', 3600, phoneHash, deviceHash);
    }
    const ipDaily = await countSince('phone_verification_attempts', "ip_hash = ? AND status = 'allowed'", [ipHash], hourAgoIso(24));
    if (ipDaily >= config.smsIpDailyLimit) {
      return denySms(req, userId, 'ip_daily_limit', 86400, phoneHash, deviceHash);
    }
    if (deviceHash) {
      const deviceHourly = await countSince('phone_verification_attempts', "device_id_hash = ? AND status = 'allowed'", [deviceHash], hourAgoIso(1));
      if (deviceHourly >= config.authDeviceHourlyLimit) {
        return denySms(req, userId, 'device_hourly_limit', 3600, phoneHash, deviceHash);
      }
    }
    const existingPhone = await sqlGetAsync(
      'SELECT user_id FROM user_security_flags WHERE phone_number_hash = ? AND phone_verified_at IS NOT NULL AND user_id <> ? LIMIT 1',
      [phoneHash, userId]
    );
    if (existingPhone) {
      return denySms(req, userId, 'phone_already_used', 86400, phoneHash, deviceHash);
    }
    await sqlRunAsync(
      `INSERT INTO phone_verification_attempts (user_id, phone_number_hash, ip_hash, device_id_hash, status, created_at)
       VALUES (?, ?, ?, ?, 'allowed', ?)`,
      [userId, phoneHash, ipHash, deviceHash || null, new Date().toISOString()]
    );
    return { allowed: true, phone_number: phone, retry_after_seconds: 0 };
  }

  function shouldUseMockPhoneVerification(normalizedPhone) {
    return Boolean(config.firebasePhoneMock && config.smsRateLimitBypassPhones.includes(normalizedPhone));
  }

  async function verifyFirebasePhoneToken(idToken, normalizedPhone) {
    if (config.firebasePhoneMock && String(idToken).startsWith('mock-phone:')) {
      const proof = String(idToken).slice('mock-phone:'.length);
      const separatorIndex = proof.lastIndexOf(':');
      const proofPhone = separatorIndex >= 0 ? proof.slice(0, separatorIndex) : proof;
      const proofCode = separatorIndex >= 0 ? proof.slice(separatorIndex + 1) : '';
      return (
        shouldUseMockPhoneVerification(normalizedPhone) &&
        proofPhone === normalizedPhone &&
        (!config.smsTestCode || proofCode === config.smsTestCode)
      );
    }
    try {
      const [{ initializeApp, cert, getApps }, { getAuth }] = await Promise.all([
        import('firebase-admin/app'),
        import('firebase-admin/auth')
      ]);
      if (!getApps().length) {
        const serviceAccountJson = String(process.env.FCM_SERVICE_ACCOUNT_JSON || '').trim();
        const serviceAccountFile = String(process.env.FCM_SERVICE_ACCOUNT_FILE || '').trim();
        let options = { projectId: process.env.FCM_PROJECT_ID };
        if (serviceAccountJson) {
          options = { credential: cert(JSON.parse(serviceAccountJson)) };
        } else if (serviceAccountFile) {
          const fs = (await import('fs')).default;
          options = { credential: cert(JSON.parse(fs.readFileSync(serviceAccountFile, 'utf8'))) };
        }
        initializeApp(options);
      }
      const decoded = await getAuth().verifyIdToken(idToken, true);
      return String(decoded.phone_number || '') === normalizedPhone;
    } catch (err) {
      writeAppLog?.('warn', 'firebase_phone_token_verify_failed', { message: err?.message || String(err) });
      return false;
    }
  }

  async function trustDevice({ userId, req, device, challengeId = null }) {
    const now = new Date().toISOString();
    const deviceHash = hashDeviceId(device.device_id);
    const existing = await sqlGetAsync(
      'SELECT id FROM trusted_devices WHERE user_id = ? AND device_id_hash = ? AND revoked_at IS NULL LIMIT 1',
      [userId, deviceHash]
    );
    if (existing) {
      await sqlRunAsync(
        'UPDATE trusted_devices SET last_seen_at = ?, device_name = ?, platform = ?, app_version = ?, user_agent = ?, device_info = ? WHERE id = ?',
        [now, device.device_name || '', device.platform, device.app_version || '', req.get?.('user-agent') || '', safeJson(device), existing.id]
      );
      return { id: Number(existing.id), trusted: true };
    }
    const result = await sqlRunAsync(
      `INSERT INTO trusted_devices (user_id, device_id_hash, device_name, platform, app_version, created_at, last_seen_at, trusted_at, ip_created_hash, user_agent, device_info)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [userId, deviceHash, device.device_name || '', device.platform, device.app_version || '', now, now, now, hashIp(req.ip), req.get?.('user-agent') || '', safeJson({ ...device, challengeId })]
    );
    await audit({ userId, eventType: 'device_trusted', req, deviceIdHash: deviceHash, metadata: { platform: device.platform, challengeId } });
    return { id: Number(result?.lastInsertRowid || result?.lastID || 0), trusted: true };
  }

  async function isDeviceTrusted(userId, deviceId, req, metadata = {}) {
    if (!deviceId) return false;
    const deviceHash = hashDeviceId(deviceId);
    const row = await sqlGetAsync(
      'SELECT id FROM trusted_devices WHERE user_id = ? AND device_id_hash = ? AND revoked_at IS NULL LIMIT 1',
      [userId, deviceHash]
    );
    if (!row) return false;
    await sqlRunAsync('UPDATE trusted_devices SET last_seen_at = ?, device_name = COALESCE(?, device_name), platform = COALESCE(?, platform), app_version = COALESCE(?, app_version) WHERE id = ?', [
      new Date().toISOString(),
      metadata.device_name || null,
      metadata.platform || null,
      metadata.app_version || null,
      row.id
    ]);
    await audit({ userId, eventType: 'device_trusted_login', req, deviceIdHash: deviceHash });
    return true;
  }

  async function createEmailChallenge({ req, user, device }) {
    const deviceHash = hashDeviceId(device.device_id);
    const attempts = await countSince('auth_rate_limits', "scope = 'device' AND key_hash = ? AND action = 'email_challenge'", [deviceHash], hourAgoIso(1));
    if (attempts >= config.authDeviceHourlyLimit) {
      await audit({ userId: user.id, eventType: 'device_challenge_denied', riskLevel: 'warn', req, deviceIdHash: deviceHash, metadata: { reason: 'device_hourly_limit' } });
      return { ok: false, retry_after_seconds: 3600 };
    }
    await sqlRunAsync('INSERT INTO auth_rate_limits (scope, key_hash, action, created_at) VALUES (?, ?, ?, ?)', ['device', deviceHash, 'email_challenge', new Date().toISOString()]);
    const code = String(crypto.randomInt(100000, 999999));
    const codeHash = sha256(code, pepper || 'dev-missing-pepper');
    const expiresAt = new Date(Date.now() + 10 * 60 * 1000).toISOString();
    const result = await sqlRunAsync(
      'INSERT INTO auth_email_challenges (user_id, device_id_hash, code_hash, expires_at, created_at) VALUES (?, ?, ?, ?, ?)',
      [user.id, deviceHash, codeHash, expiresAt, new Date().toISOString()]
    );
    const publicBaseUrl = resolvePublicBaseUrl(req);
    const html = `<!doctype html><html><body style="font-family:Arial,sans-serif">
      <p>New device verification code:</p>
      <p style="font-size:24px;font-weight:700;letter-spacing:3px">${escapeHtml(code)}</p>
      <p>This code expires in 10 minutes. If this was not you, ignore this email.</p>
      <p>${escapeHtml(publicBaseUrl)}</p>
    </body></html>`;
    await queueEmailDelivery({ to: user.email, subject: 'SDAL device verification code', html }, { maxAttempts: 3, backoffMs: 1200 });
    await audit({ userId: user.id, eventType: 'device_challenge_sent', req, deviceIdHash: deviceHash });
    req.session.pendingDeviceChallenge = {
      challengeId: Number(result?.lastInsertRowid || result?.lastID || 0),
      userId: user.id,
      device
    };
    return { ok: true };
  }

  async function completeEmailChallenge(req, res) {
    const parsed = EmailChallengeSchema.safeParse(req.body || {});
    if (!parsed.success) return res.status(400).json({ ok: false, message: GENERIC_AUTH_MESSAGE });
    const pending = req.session.pendingDeviceChallenge || {};
    const userId = Number(pending.userId || 0);
    if (!userId) return res.status(401).json({ ok: false, code: 'CHALLENGE_REQUIRED', message: 'Bu cihazı doğrulayamadık. Lütfen e-posta ile doğrulayın.' });
    const device = parsed.data;
    const deviceHash = hashDeviceId(device.device_id);
    const row = await sqlGetAsync(
      `SELECT id, code_hash, expires_at FROM auth_email_challenges
       WHERE user_id = ? AND device_id_hash = ? AND consumed_at IS NULL
       ORDER BY created_at DESC LIMIT 1`,
      [userId, deviceHash]
    );
    if (!row || Date.parse(row.expires_at) < Date.now() || row.code_hash !== sha256(parsed.data.code.trim(), pepper || 'dev-missing-pepper')) {
      await audit({ userId, eventType: 'device_challenge_failed', riskLevel: 'warn', req, deviceIdHash: deviceHash });
      return res.status(400).json({ ok: false, message: 'Kod geçersiz veya oturum süresi doldu.' });
    }
    await sqlRunAsync('UPDATE auth_email_challenges SET consumed_at = ? WHERE id = ?', [new Date().toISOString(), row.id]);
    await trustDevice({ userId, req, device, challengeId: row.id });
    const user = await selectCompatUserByIdAsync(userId);
    if (!user) return res.status(401).json({ ok: false, message: GENERIC_AUTH_MESSAGE });
    applyUserSession(req, user);
    delete req.session.pendingDeviceChallenge;
    await new Promise((resolve) => req.session.save(resolve));
    return res.json({ ok: true, trusted: true });
  }

  async function markSignupCreated(req, { userId, email, deviceId = '' }) {
    await sqlRunAsync(
      `INSERT INTO user_security_flags (user_id, phone_verification_required, created_at, updated_at)
       VALUES (?, 1, ?, ?)
       ON CONFLICT(user_id) DO UPDATE SET phone_verification_required = 1, updated_at = ?`,
      [userId, new Date().toISOString(), new Date().toISOString(), new Date().toISOString()]
    ).catch(async () => {
      await sqlRunAsync('INSERT OR IGNORE INTO user_security_flags (user_id, phone_verification_required, created_at, updated_at) VALUES (?, 1, ?, ?)', [userId, new Date().toISOString(), new Date().toISOString()]);
    });
    await audit({ userId, eventType: 'signup_created_security_pending', req, email, deviceIdHash: deviceId ? hashDeviceId(deviceId) : '' });
  }

  async function isPhoneVerificationPending(userId) {
    if (!userId) return false;
    const row = await sqlGetAsync(
      'SELECT phone_verification_required, phone_verified_at FROM user_security_flags WHERE user_id = ? LIMIT 1',
      [userId]
    );
    return Boolean(row && Number(row.phone_verification_required || 0) === 1 && !row.phone_verified_at);
  }

  async function checkSignupAllowed(req, { email = '', deviceId = '' } = {}) {
    const ipHash = hashIp(req.ip);
    const ipHourly = await countSince('auth_rate_limits', "scope = 'ip' AND key_hash = ? AND action = 'signup'", [ipHash], hourAgoIso(1));
    await sqlRunAsync('INSERT INTO auth_rate_limits (scope, key_hash, action, created_at) VALUES (?, ?, ?, ?)', ['ip', ipHash, 'signup', new Date().toISOString()]);
    if (ipHourly >= config.signupIpHourlyLimit) {
      await audit({ eventType: 'signup_denied', riskLevel: 'warn', req, email, deviceIdHash: deviceId ? hashDeviceId(deviceId) : '', metadata: { reason: 'ip_hourly_limit' } });
      return { ok: false, message: GENERIC_COOLDOWN_MESSAGE };
    }
    if (deviceId) {
      const deviceHash = hashDeviceId(deviceId);
      const deviceHourly = await countSince('auth_rate_limits', "scope = 'device' AND key_hash = ? AND action = 'signup'", [deviceHash], hourAgoIso(1));
      await sqlRunAsync('INSERT INTO auth_rate_limits (scope, key_hash, action, created_at) VALUES (?, ?, ?, ?)', ['device', deviceHash, 'signup', new Date().toISOString()]);
      if (deviceHourly >= config.authDeviceHourlyLimit) {
        await audit({ eventType: 'signup_denied', riskLevel: 'warn', req, email, deviceIdHash: deviceHash, metadata: { reason: 'device_hourly_limit' } });
        return { ok: false, message: GENERIC_COOLDOWN_MESSAGE };
      }
    }
    if (config.blockDisposableEmails && isDisposableEmail(email)) {
      await audit({ eventType: 'signup_denied', riskLevel: 'warn', req, email, metadata: { reason: 'disposable_email' } });
      return { ok: false, message: GENERIC_AUTH_MESSAGE };
    }
    return { ok: true };
  }

  function registerRoutes(app) {
    app.post('/api/auth/phone/start', requireAuth, async (req, res) => {
      const parsed = PhoneStartSchema.safeParse(req.body || {});
      if (!parsed.success) return res.status(400).json({ ok: false, message: GENERIC_AUTH_MESSAGE });
      const phone = normalizePhoneNumber(parsed.data.phone_number);
      if (!phone) return res.status(400).json({ ok: false, message: GENERIC_AUTH_MESSAGE });
      const allowed = await checkSmsAllowed(req, req.session.userId, phone, parsed.data.device_id);
      return res.status(allowed.allowed ? 200 : 429).json({ ok: allowed.allowed, ...allowed });
    });

    app.post('/api/auth/phone/complete', requireAuth, async (req, res) => {
      const parsed = PhoneCompleteSchema.safeParse(req.body || {});
      if (!parsed.success) return res.status(400).json({ ok: false, message: GENERIC_AUTH_MESSAGE });
      const phone = normalizePhoneNumber(parsed.data.phone_number);
      if (!phone) return res.status(400).json({ ok: false, message: GENERIC_AUTH_MESSAGE });
      const verified = await verifyFirebasePhoneToken(parsed.data.firebase_id_token, phone);
      if (!verified) {
        await audit({ userId: req.session.userId, eventType: 'sms_complete_failed', riskLevel: 'warn', req, phoneHash: hashPhone(phone), deviceIdHash: hashDeviceId(parsed.data.device_id) });
        return res.status(400).json({ ok: false, message: 'Kod geçersiz veya oturum süresi doldu.' });
      }
      const now = new Date().toISOString();
      const phoneHash = hashPhone(phone);
      const updated = await sqlRunAsync(
        'UPDATE user_security_flags SET phone_verified_at = ?, phone_number_hash = ?, phone_verification_required = 0, updated_at = ? WHERE user_id = ?',
        [now, phoneHash, now, req.session.userId]
      );
      if (!updated || Number(updated.changes || 0) === 0) {
        await sqlRunAsync(
          `INSERT INTO user_security_flags (user_id, phone_verified_at, phone_number_hash, phone_verification_required, created_at, updated_at)
           VALUES (?, ?, ?, 0, ?, ?)`,
          [req.session.userId, now, phoneHash, now, now]
        );
      }
      const trusted = await trustDevice({ userId: req.session.userId, req, device: parsed.data });
      return res.json({ ok: true, phone_verified: true, trusted_device: trusted });
    });

    app.post('/api/auth/device/check', requireAuth, async (req, res) => {
      const parsed = DeviceSchema.safeParse(req.body || {});
      if (!parsed.success) return res.status(400).json({ ok: false, trusted: false, challenge_required: true });
      const trusted = await isDeviceTrusted(req.session.userId, parsed.data.device_id, req, parsed.data);
      return res.json({ ok: true, trusted, challenge_required: !trusted });
    });

    app.post('/api/auth/device/trust', requireAuth, async (req, res) => {
      const parsed = DeviceSchema.safeParse(req.body || {});
      if (!parsed.success) return res.status(400).json({ ok: false, message: GENERIC_AUTH_MESSAGE });
      const trusted = await trustDevice({ userId: req.session.userId, req, device: parsed.data });
      return res.json({ ok: true, ...trusted });
    });

    app.post('/api/auth/device/challenge/complete', completeEmailChallenge);

    app.post('/api/auth/device/revoke', requireAuth, async (req, res) => {
      const id = Number(req.body?.trusted_device_id || 0);
      if (!id) return res.status(400).json({ ok: false, message: GENERIC_AUTH_MESSAGE });
      await sqlRunAsync('UPDATE trusted_devices SET revoked_at = ? WHERE id = ? AND user_id = ?', [new Date().toISOString(), id, req.session.userId]);
      await audit({ userId: req.session.userId, eventType: 'device_revoked', req, metadata: { trustedDeviceId: id } });
      return res.json({ ok: true });
    });
  }

  return {
    ensureSchema,
    registerRoutes,
    isDeviceTrusted,
    createEmailChallenge,
    checkSignupAllowed,
    markSignupCreated,
    isPhoneVerificationPending
  };
}

function isDisposableEmail(email) {
  const domain = String(email || '').toLowerCase().split('@').pop() || '';
  return new Set(['mailinator.com', '10minutemail.com', 'guerrillamail.com', 'tempmail.com', 'yopmail.com']).has(domain);
}
