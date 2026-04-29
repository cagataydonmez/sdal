import crypto from 'crypto';
import { execFileSync } from 'node:child_process';

function parseArgs(argv) {
  const args = {
    baseUrl: process.env.E2E_BASE_URL || 'http://127.0.0.1:8787',
    phone: process.env.E2E_PHONE || '+905065055555',
    code: process.env.AUTH_SMS_TEST_CODE || process.env.E2E_PHONE_CODE || '123456',
    dbPath: process.env.SDAL_DB_PATH || '/var/lib/sdal/data/sdal.sqlite',
    token: process.env.E2E_HARNESS_TOKEN || '',
    keepUser: false,
    allowFirebase: false
  };
  for (let i = 0; i < argv.length; i += 1) {
    const key = String(argv[i] || '');
    const next = String(argv[i + 1] || '');
    switch (key) {
      case '--base-url':
        args.baseUrl = next;
        i += 1;
        break;
      case '--phone':
        args.phone = next;
        i += 1;
        break;
      case '--code':
        args.code = next;
        i += 1;
        break;
      case '--db':
      case '--db-path':
        args.dbPath = next;
        i += 1;
        break;
      case '--token':
        args.token = next;
        i += 1;
        break;
      case '--keep-user':
        args.keepUser = true;
        break;
      case '--allow-firebase':
        args.allowFirebase = true;
        break;
      default:
        break;
    }
  }
  return args;
}

function normalizePhone(raw) {
  const compact = String(raw || '').replace(/[\s().-]/g, '');
  if (!compact) return '';
  if (compact.startsWith('+')) return compact;
  const digits = compact.replace(/\D/g, '');
  if (digits.startsWith('00')) return `+${digits.slice(2)}`;
  if (digits.startsWith('0') && digits.length === 11) return `+90${digits.slice(1)}`;
  if (digits.startsWith('90') && digits.length === 12) return `+${digits}`;
  if (digits.startsWith('5') && digits.length === 10) return `+90${digits}`;
  return `+${digits}`;
}

class HttpHarness {
  constructor(baseUrl, token) {
    this.baseUrl = String(baseUrl || '').replace(/\/+$/, '');
    this.token = token;
    this.cookies = new Map();
  }

  cookieHeader() {
    return Array.from(this.cookies.entries()).map(([key, value]) => `${key}=${value}`).join('; ');
  }

  storeCookies(headers) {
    const raw = headers.getSetCookie ? headers.getSetCookie() : [];
    const values = raw.length ? raw : String(headers.get('set-cookie') || '').split(/,(?=[^;,]+=)/);
    for (const item of values) {
      const pair = String(item || '').split(';')[0];
      const index = pair.indexOf('=');
      if (index <= 0) continue;
      this.cookies.set(pair.slice(0, index).trim(), pair.slice(index + 1).trim());
    }
  }

  async request(path, { method = 'GET', body, e2e = false, expectStatus } = {}) {
    const headers = { accept: 'application/json, text/plain, */*' };
    if (body !== undefined) headers['content-type'] = 'application/json';
    if (this.cookies.size) headers.cookie = this.cookieHeader();
    if (e2e) headers['x-e2e-token'] = this.token;
    const response = await fetch(`${this.baseUrl}${path}`, {
      method,
      headers,
      body: body === undefined ? undefined : JSON.stringify(body)
    });
    this.storeCookies(response.headers);
    const text = await response.text();
    let payload = text;
    try {
      payload = text ? JSON.parse(text) : null;
    } catch {
      // Keep plain text payloads as-is.
    }
    if (expectStatus && response.status !== expectStatus) {
      throw new Error(`${method} ${path} expected ${expectStatus}, got ${response.status}: ${text}`);
    }
    return { status: response.status, ok: response.ok, payload, text };
  }
}

function assertOk(condition, message, detail) {
  if (!condition) {
    throw new Error(detail ? `${message}: ${detail}` : message);
  }
}

function sqliteQuote(value) {
  return `'${String(value ?? '').replace(/'/g, "''")}'`;
}

function sqliteJsonRows(dbPath, sql) {
  const output = execFileSync('sqlite3', ['-json', dbPath, sql], { encoding: 'utf8' }).trim();
  return output ? JSON.parse(output) : [];
}

function sqliteExec(dbPath, sql) {
  execFileSync('sqlite3', [dbPath, sql], { stdio: 'ignore' });
}

function sqliteTableExists(dbPath, table) {
  const rows = sqliteJsonRows(
    dbPath,
    `SELECT name FROM sqlite_master WHERE type='table' AND name = ${sqliteQuote(table)} LIMIT 1`
  );
  return rows.length > 0;
}

function cleanupRows(dbPath, userId, username) {
  if (!userId) return;
  const tables = [
    ['auth_email_challenges', 'user_id'],
    ['trusted_devices', 'user_id'],
    ['phone_verification_attempts', 'user_id'],
    ['auth_audit_logs', 'user_id'],
    ['user_security_flags', 'user_id'],
    ['uyeler', 'id']
  ];
  for (const [table, column] of tables) {
    if (!sqliteTableExists(dbPath, table)) continue;
    sqliteExec(dbPath, `DELETE FROM "${table}" WHERE "${column}" = ${Number(userId)}`);
  }
  if (username) {
    sqliteExec(dbPath, `DELETE FROM uyeler WHERE kadi = ${sqliteQuote(username)}`);
  }
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  const phone = normalizePhone(args.phone);
  assertOk(args.token, 'E2E_HARNESS_TOKEN is required. Pass --token or set env.');
  assertOk(/^\+[1-9]\d{7,14}$/.test(phone), `Invalid phone: ${args.phone}`);

  const harness = new HttpHarness(args.baseUrl, args.token);
  const suffix = Date.now().toString(36).slice(-8);
  const username = `e2e${suffix}`.slice(0, 15);
  const password = `Pw${suffix}!1`.slice(0, 20);
  const email = 'cagatay.donmez@gmail.com';
  const deviceId = `e2e-${crypto.randomUUID()}`;
  const newDeviceId = `e2e-${crypto.randomUUID()}`;
  let userId = 0;

  try {
    console.log(`[auth-e2e] base=${args.baseUrl} phone=${phone} user=${username}`);

    const previewBody = {
      kadi: username,
      sifre: password,
      sifre2: password,
      email,
      isim: 'Etest',
      soyisim: 'User',
      mezuniyetyili: '2011',
      device_id: deviceId,
      kvkk_consent: true,
      directory_consent: true
    };
    const preview = await harness.request('/api/register/preview', {
      method: 'POST',
      body: previewBody,
      e2e: true,
      expectStatus: 200
    });
    assertOk(preview.payload?.ok === true, 'register preview failed', preview.text);
    console.log('[auth-e2e] register preview ok');

    const register = await harness.request('/api/register', {
      method: 'POST',
      body: previewBody,
      e2e: true,
      expectStatus: 200
    });
    assertOk(register.payload?.ok === true, 'register failed', register.text);
    userId = Number(register.payload?.memberId || register.payload?.e2e?.userId || 0);
    assertOk(userId > 0, 'register did not return user id', register.text);
    console.log(`[auth-e2e] register ok userId=${userId}`);

    const login = await harness.request('/api/auth/login', {
      method: 'POST',
      body: { kadi: username, sifre: password },
      expectStatus: 200
    });
    assertOk(Boolean(login.payload?.user || login.payload?.ok !== false), 'login failed', login.text);
    console.log('[auth-e2e] login ok');

    const phoneStart = await harness.request('/api/auth/phone/start', {
      method: 'POST',
      body: { phone_number: phone, device_id: deviceId },
      expectStatus: 200
    });
    assertOk(phoneStart.payload?.ok === true, 'phone start failed', phoneStart.text);
    if (!args.allowFirebase) {
      assertOk(phoneStart.payload?.mock_verification === true, 'phone start did not use mock_verification', phoneStart.text);
    }
    console.log(`[auth-e2e] phone start ok mock=${Boolean(phoneStart.payload?.mock_verification)}`);

    const firebaseProof = phoneStart.payload?.mock_verification
      ? `mock-phone:${phone}:${args.code}`
      : `mock-phone:${phone}:${args.code}`;
    const phoneComplete = await harness.request('/api/auth/phone/complete', {
      method: 'POST',
      body: {
        phone_number: phone,
        firebase_id_token: firebaseProof,
        device_id: deviceId,
        platform: 'ios',
        device_name: 'Auth E2E iPhone',
        app_version: 'e2e'
      },
      expectStatus: 200
    });
    assertOk(phoneComplete.payload?.ok === true && phoneComplete.payload?.phone_verified === true, 'phone complete failed', phoneComplete.text);
    assertOk(Boolean(phoneComplete.payload?.trusted_device?.id), 'trusted device not created', phoneComplete.text);
    console.log(`[auth-e2e] phone complete ok trustedDevice=${phoneComplete.payload.trusted_device.id}`);

    const deviceCheck = await harness.request('/api/auth/device/check', {
      method: 'POST',
      body: {
        device_id: deviceId,
        platform: 'ios',
        device_name: 'Auth E2E iPhone',
        app_version: 'e2e'
      },
      expectStatus: 200
    });
    assertOk(deviceCheck.payload?.trusted === true && deviceCheck.payload?.challenge_required === false, 'trusted device check failed', deviceCheck.text);
    console.log('[auth-e2e] trusted device check ok');

    await harness.request('/api/auth/logout', { method: 'POST' });
    const trustedLogin = await harness.request('/api/auth/login', {
      method: 'POST',
      body: {
        kadi: username,
        sifre: password,
        device_id: deviceId,
        platform: 'ios',
        device_name: 'Auth E2E iPhone',
        app_version: 'e2e'
      },
      expectStatus: 200
    });
    assertOk(Boolean(trustedLogin.payload?.user || trustedLogin.payload?.ok !== false), 'trusted login failed', trustedLogin.text);
    console.log('[auth-e2e] same trusted device login ok');

    await harness.request('/api/auth/logout', { method: 'POST' });
    const newDeviceLogin = await harness.request('/api/auth/login', {
      method: 'POST',
      body: {
        kadi: username,
        sifre: password,
        device_id: newDeviceId,
        platform: 'ios',
        device_name: 'Auth E2E New iPhone',
        app_version: 'e2e'
      }
    });
    assertOk(
      newDeviceLogin.status === 403 && newDeviceLogin.payload?.challenge_required === true,
      'new device did not require challenge',
      `${newDeviceLogin.status}: ${newDeviceLogin.text}`
    );
    console.log('[auth-e2e] new device challenge required ok');

    const flags = sqliteJsonRows(
      args.dbPath,
      `SELECT phone_verified_at, phone_verification_required FROM user_security_flags WHERE user_id = ${Number(userId)} LIMIT 1`
    )[0];
    assertOk(Boolean(flags?.phone_verified_at), 'db phone_verified_at missing');
    assertOk(Number(flags?.phone_verification_required || 0) === 0, 'db phone_verification_required not cleared');
    const trustedCount = Number(
      sqliteJsonRows(
        args.dbPath,
        `SELECT COUNT(*) AS cnt FROM trusted_devices WHERE user_id = ${Number(userId)} AND revoked_at IS NULL`
      )[0]?.cnt || 0
    );
    assertOk(trustedCount >= 1, 'db trusted device missing');
    console.log(`[auth-e2e] db assertions ok trustedCount=${trustedCount}`);

    console.log('[auth-e2e] PASS');
  } finally {
    if (!args.keepUser) {
      cleanupRows(args.dbPath, userId, username);
      console.log(`[auth-e2e] cleanup complete userId=${userId || 'unknown'}`);
    }
  }
}

main().catch((err) => {
  console.error('[auth-e2e] FAIL:', err?.message || err);
  process.exit(1);
});
