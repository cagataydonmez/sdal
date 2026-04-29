function parseArgs(argv) {
  const args = {
    phone: process.env.E2E_PHONE || '',
    expectRealSms: true
  };
  for (let i = 0; i < argv.length; i += 1) {
    const key = String(argv[i] || '');
    const next = String(argv[i + 1] || '');
    if (key === '--phone') {
      args.phone = next;
      i += 1;
    } else if (key === '--test-number') {
      args.expectRealSms = false;
    }
  }
  return args;
}

function normalizePhone(raw) {
  const compact = String(raw || '').replace(/[\s().-]/g, '');
  if (!compact) return '';
  if (compact.startsWith('+')) return /^\+[1-9]\d{7,14}$/.test(compact) ? compact : '';
  const digits = compact.replace(/\D/g, '');
  let normalized = '';
  if (digits.startsWith('00')) normalized = `+${digits.slice(2)}`;
  else if (digits.startsWith('0') && digits.length === 11) normalized = `+90${digits.slice(1)}`;
  else if (digits.startsWith('90') && digits.length === 12) normalized = `+${digits}`;
  else if (digits.startsWith('5') && digits.length === 10) normalized = `+90${digits}`;
  else normalized = `+${digits}`;
  return /^\+[1-9]\d{7,14}$/.test(normalized) ? normalized : '';
}

function csvEnv(name) {
  return String(process.env[name] || '')
    .split(',')
    .map((item) => item.trim())
    .filter(Boolean)
    .map(normalizePhone)
    .filter(Boolean);
}

function maskPhone(phone) {
  return phone.replace(/^(\+\d{2})(\d{3})(\d+)(\d{2})$/, '$1$2***$4');
}

function pass(label) {
  console.log(`[PASS] ${label}`);
}

function warn(label) {
  console.log(`[WARN] ${label}`);
}

function fail(label) {
  console.log(`[FAIL] ${label}`);
  process.exitCode = 1;
}

const args = parseArgs(process.argv.slice(2));
const phone = normalizePhone(args.phone);

console.log('[firebase-phone-diagnostics]');
if (!phone) {
  fail(`Invalid phone input: ${args.phone || '<empty>'}`);
  process.exit();
}
console.log(`phone_input=${args.phone}`);
console.log(`phone_normalized=${phone}`);
console.log(`phone_masked=${maskPhone(phone)}`);

const mock = String(process.env.AUTH_FIREBASE_PHONE_MOCK || '').trim().toLowerCase() === 'true';
if (mock) fail('AUTH_FIREBASE_PHONE_MOCK=true. Real Firebase SMS cannot run while backend mock mode is enabled.');
else pass('AUTH_FIREBASE_PHONE_MOCK=false');

const bypassPhones = csvEnv('AUTH_SMS_RATE_LIMIT_BYPASS_PHONES');
if (bypassPhones.includes(phone)) {
  warn('Phone is in AUTH_SMS_RATE_LIMIT_BYPASS_PHONES. Backend will not rate-limit it.');
  if (args.expectRealSms) {
    warn('If this same phone is also listed in Firebase Console test numbers, Firebase will NOT send a real SMS. Remove it there for real SMS testing.');
  }
} else {
  warn('Phone is not in AUTH_SMS_RATE_LIMIT_BYPASS_PHONES. Backend SMS anti-abuse limits may block repeated tests.');
}

if (process.env.FCM_PROJECT_ID) pass(`FCM_PROJECT_ID=${process.env.FCM_PROJECT_ID}`);
else fail('FCM_PROJECT_ID is missing.');

if (process.env.FCM_SERVICE_ACCOUNT_JSON || process.env.FCM_SERVICE_ACCOUNT_FILE) {
  pass('Firebase Admin credentials are configured for backend token verification.');
} else {
  fail('Firebase Admin credentials are missing. /api/auth/phone/complete cannot verify Firebase ID tokens.');
}

console.log('');
console.log('What this script can verify: backend/env readiness and common real-SMS blockers.');
console.log('What it cannot verify: iOS Firebase Phone Auth APNs/reCAPTCHA app-verification, because Firebase only issues real SMS from the client SDK after device app verification.');
console.log('');
console.log('For real SMS testing on iPhone:');
console.log('1. Firebase Console > Authentication > Sign-in method > Phone must be enabled.');
console.log(`2. Remove ${phone} from Firebase test phone numbers if you expect a real SMS.`);
console.log('3. Do not run the app with --dart-define=FIREBASE_PHONE_AUTH_TEST_MODE=true.');
console.log('4. If app shows an error, copy the [phone-auth] firebase verification failed code.');
