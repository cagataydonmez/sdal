import 'dotenv/config';
import express from 'express';
import path from 'path';
import { fileURLToPath } from 'url';
import session from 'express-session';
import cookieParser from 'cookie-parser';
import morgan from 'morgan';
import { sqlGet, sqlAll, sqlRun, dbPath } from './db.js';
import { mapLegacyUrl } from './legacyRoutes.js';
import fs from 'fs';
import sharp from 'sharp';
import { metinDuzenle } from './textFormat.js';
import nodemailer from 'nodemailer';
import multer from 'multer';
import { WebSocketServer } from 'ws';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const app = express();
const port = process.env.PORT || 8787;
app.set('trust proxy', true);

app.use(morgan('dev'));
app.use(cookieParser());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));
app.use(
  session({
    secret: process.env.SDAL_SESSION_SECRET || 'sdal-dev-secret',
    resave: false,
    saveUninitialized: false,
    cookie: {
      maxAge: 1000 * 60 * 60 * 2
    }
  })
);

const legacyDir = path.resolve(__dirname, '../client/public/legacy');
app.use('/legacy', express.static(legacyDir));
app.use('/smiley', express.static(path.join(legacyDir, 'smiley')));

const uploadsDir = path.resolve(__dirname, '../uploads');
app.use('/uploads', express.static(uploadsDir));
const vesikalikDir = path.join(uploadsDir, 'vesikalik');
if (!fs.existsSync(vesikalikDir)) {
  fs.mkdirSync(vesikalikDir, { recursive: true });
}
const albumDir = path.join(uploadsDir, 'album');
if (!fs.existsSync(albumDir)) {
  fs.mkdirSync(albumDir, { recursive: true });
}
const postDir = path.join(uploadsDir, 'posts');
if (!fs.existsSync(postDir)) {
  fs.mkdirSync(postDir, { recursive: true });
}
const storyDir = path.join(uploadsDir, 'stories');
if (!fs.existsSync(storyDir)) {
  fs.mkdirSync(storyDir, { recursive: true });
}
const groupDir = path.join(uploadsDir, 'groups');
if (!fs.existsSync(groupDir)) {
  fs.mkdirSync(groupDir, { recursive: true });
}

const allowedImageExts = new Set(['.jpg', '.jpeg', '.png', '.gif', '.bmp', '.tif']);
const photoUpload = multer({
  storage: multer.diskStorage({
    destination: (_req, _file, cb) => cb(null, vesikalikDir),
    filename: (req, file, cb) => {
      const ext = path.extname(file.originalname || '').toLowerCase();
      cb(null, `${req.session.userId}${ext || '.jpg'}`);
    }
  }),
  fileFilter: (_req, file, cb) => {
    const ext = path.extname(file.originalname || '').toLowerCase();
    if (!allowedImageExts.has(ext)) {
      cb(new Error('Geçerli bir resim dosyası girmediniz.'));
    } else {
      cb(null, true);
    }
  },
  limits: { fileSize: 5 * 1024 * 1024 }
});

const albumUpload = multer({
  storage: multer.diskStorage({
    destination: (_req, _file, cb) => cb(null, albumDir),
    filename: (req, file, cb) => {
      const ext = path.extname(file.originalname || '').toLowerCase();
      const now = new Date();
      const stamp = `${now.getMonth() + 1}${now.getDate()}${now.getFullYear()}${now.getHours()}${now.getMinutes()}${now.getSeconds()}`;
      cb(null, `${req.session.userId}${stamp}${ext || '.jpg'}`);
    }
  }),
  fileFilter: (_req, file, cb) => {
    const ext = path.extname(file.originalname || '').toLowerCase();
    if (!allowedImageExts.has(ext)) {
      cb(new Error('Geçerli bir resim dosyası girmedin. ( Geçerli dosya türleri : jpg,gif,png )'));
    } else {
      cb(null, true);
    }
  },
  limits: { fileSize: 5 * 1024 * 1024 }
});

const postUpload = multer({
  storage: multer.diskStorage({
    destination: (_req, _file, cb) => cb(null, postDir),
    filename: (req, file, cb) => {
      const ext = path.extname(file.originalname || '').toLowerCase();
      const now = new Date();
      const stamp = `${now.getMonth() + 1}${now.getDate()}${now.getFullYear()}${now.getHours()}${now.getMinutes()}${now.getSeconds()}`;
      cb(null, `${req.session.userId || 'anon'}_${stamp}${ext || '.jpg'}`);
    }
  }),
  fileFilter: (_req, file, cb) => {
    const ext = path.extname(file.originalname || '').toLowerCase();
    if (!allowedImageExts.has(ext)) {
      cb(new Error('Geçerli bir resim dosyası girmediniz.'));
    } else {
      cb(null, true);
    }
  },
  limits: { fileSize: 10 * 1024 * 1024 }
});

const storyUpload = multer({
  storage: multer.diskStorage({
    destination: (_req, _file, cb) => cb(null, storyDir),
    filename: (req, file, cb) => {
      const ext = path.extname(file.originalname || '').toLowerCase();
      const now = new Date();
      const stamp = `${now.getMonth() + 1}${now.getDate()}${now.getFullYear()}${now.getHours()}${now.getMinutes()}${now.getSeconds()}`;
      cb(null, `${req.session.userId || 'anon'}_${stamp}${ext || '.jpg'}`);
    }
  }),
  fileFilter: (_req, file, cb) => {
    const ext = path.extname(file.originalname || '').toLowerCase();
    if (!allowedImageExts.has(ext)) {
      cb(new Error('Geçerli bir resim dosyası girmediniz.'));
    } else {
      cb(null, true);
    }
  },
  limits: { fileSize: 10 * 1024 * 1024 }
});

const groupUpload = multer({
  storage: multer.diskStorage({
    destination: (_req, _file, cb) => cb(null, groupDir),
    filename: (req, file, cb) => {
      const ext = path.extname(file.originalname || '').toLowerCase();
      const now = new Date();
      const stamp = `${now.getMonth() + 1}${now.getDate()}${now.getFullYear()}${now.getHours()}${now.getMinutes()}${now.getSeconds()}`;
      cb(null, `group_${req.params.id || 'new'}_${stamp}${ext || '.jpg'}`);
    }
  }),
  fileFilter: (_req, file, cb) => {
    const ext = path.extname(file.originalname || '').toLowerCase();
    if (!allowedImageExts.has(ext)) {
      cb(new Error('Geçerli bir resim dosyası girmediniz.'));
    } else {
      cb(null, true);
    }
  },
  limits: { fileSize: 10 * 1024 * 1024 }
});

let mailTransportPromise = null;
function getMailTransport() {
  if (mailTransportPromise) return mailTransportPromise;
  mailTransportPromise = (async () => {
    const host = process.env.SMTP_HOST;
    if (!host) return null;
    const port = Number(process.env.SMTP_PORT || 587);
    const secure =
      (process.env.SMTP_SECURE || '').toLowerCase() === 'true' || port === 465;
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


const adminPassword = process.env.SDAL_ADMIN_PASSWORD || 'guuk';
const legacyRoot = path.resolve(__dirname, '../..');
const hatalogDir = path.join(legacyRoot, 'hatalog');
const sayfalogDir = path.join(legacyRoot, 'sayfalog');
const uyedetaylogDir = path.join(legacyRoot, 'uyedetaylog');

// Ensure admin email tables exist
sqlRun(`CREATE TABLE IF NOT EXISTS email_kategori (
  id INTEGER PRIMARY KEY,
  ad TEXT,
  tur TEXT,
  deger TEXT,
  aciklama TEXT
)`);
sqlRun(`CREATE TABLE IF NOT EXISTS email_sablon (
  id INTEGER PRIMARY KEY,
  ad TEXT,
  konu TEXT,
  icerik TEXT,
  olusturma DateTime
)`);

// Modern (sdal_new) social tables
sqlRun(`CREATE TABLE IF NOT EXISTS posts (
  id INTEGER PRIMARY KEY,
  user_id INTEGER,
  content TEXT,
  image TEXT,
  created_at TEXT
)`);
sqlRun(`CREATE TABLE IF NOT EXISTS post_comments (
  id INTEGER PRIMARY KEY,
  post_id INTEGER,
  user_id INTEGER,
  comment TEXT,
  created_at TEXT
)`);
sqlRun(`CREATE TABLE IF NOT EXISTS post_likes (
  id INTEGER PRIMARY KEY,
  post_id INTEGER,
  user_id INTEGER,
  created_at TEXT
)`);
sqlRun(`CREATE TABLE IF NOT EXISTS follows (
  id INTEGER PRIMARY KEY,
  follower_id INTEGER,
  following_id INTEGER,
  created_at TEXT
)`);
sqlRun(`CREATE TABLE IF NOT EXISTS notifications (
  id INTEGER PRIMARY KEY,
  user_id INTEGER,
  type TEXT,
  source_user_id INTEGER,
  entity_id INTEGER,
  message TEXT,
  read_at TEXT,
  created_at TEXT
)`);
sqlRun(`CREATE TABLE IF NOT EXISTS events (
  id INTEGER PRIMARY KEY,
  title TEXT,
  description TEXT,
  location TEXT,
  starts_at TEXT,
  ends_at TEXT,
  created_at TEXT
)`);
sqlRun(`CREATE TABLE IF NOT EXISTS announcements (
  id INTEGER PRIMARY KEY,
  title TEXT,
  body TEXT,
  created_at TEXT
)`);

function ensureColumn(table, column, ddl) {
  try {
    const cols = sqlAll(`PRAGMA table_info(${table})`);
    if (!cols.some((c) => c.name === column)) {
      sqlRun(ddl);
    }
  } catch {
    // ignore
  }
}

ensureColumn('uyeler', 'verified', 'ALTER TABLE uyeler ADD COLUMN verified INTEGER DEFAULT 0');
ensureColumn('posts', 'group_id', 'ALTER TABLE posts ADD COLUMN group_id INTEGER');

sqlRun(`CREATE TABLE IF NOT EXISTS stories (
  id INTEGER PRIMARY KEY,
  user_id INTEGER,
  image TEXT,
  caption TEXT,
  created_at TEXT,
  expires_at TEXT
)`);
sqlRun(`CREATE TABLE IF NOT EXISTS story_views (
  id INTEGER PRIMARY KEY,
  story_id INTEGER,
  user_id INTEGER,
  created_at TEXT
)`);
sqlRun(`CREATE TABLE IF NOT EXISTS groups (
  id INTEGER PRIMARY KEY,
  name TEXT,
  description TEXT,
  cover_image TEXT,
  owner_id INTEGER,
  created_at TEXT
)`);
sqlRun(`CREATE TABLE IF NOT EXISTS group_members (
  id INTEGER PRIMARY KEY,
  group_id INTEGER,
  user_id INTEGER,
  role TEXT,
  created_at TEXT
)`);
sqlRun(`CREATE TABLE IF NOT EXISTS chat_messages (
  id INTEGER PRIMARY KEY,
  user_id INTEGER,
  message TEXT,
  created_at TEXT
)`);
sqlRun(`CREATE TABLE IF NOT EXISTS verification_requests (
  id INTEGER PRIMARY KEY,
  user_id INTEGER,
  status TEXT,
  created_at TEXT,
  reviewed_at TEXT,
  reviewer_id INTEGER
)`);

function getCurrentUser(req) {
  if (!req.session.userId) return null;
  return sqlGet('SELECT * FROM uyeler WHERE id = ?', [req.session.userId]);
}

function requireAuth(req, res, next) {
  if (!req.session.userId) return res.status(401).send('Login required');
  return next();
}

function requireAdmin(req, res, next) {
  const user = getCurrentUser(req);
  if (!user) return res.status(401).send('Login required');
  if (user.admin !== 1) return res.status(403).send('Admin erişimi gerekli.');
  if (!req.session.adminOk) return res.status(403).send('Admin giriş gerekli.');
  req.adminUser = user;
  return next();
}

function requireAlbumAdmin(req, res, next) {
  const user = getCurrentUser(req);
  if (!user) return res.status(401).send('Login required');
  if (user.albumadmin !== 1 && user.admin !== 1) return res.status(403).send('Albüm yönetimi yetkisi gerekli.');
  if (user.admin === 1 && !req.session.adminOk) return res.status(403).send('Admin giriş gerekli.');
  req.adminUser = user;
  return next();
}

function addNotification({ userId, type, sourceUserId, entityId, message }) {
  if (!userId) return;
  sqlRun(
    'INSERT INTO notifications (user_id, type, source_user_id, entity_id, message, created_at) VALUES (?, ?, ?, ?, ?, ?)',
    [userId, type, sourceUserId || null, entityId || null, message || '', new Date().toISOString()]
  );
}

function listLogFiles(dirPath) {
  if (!fs.existsSync(dirPath)) return [];
  const entries = fs.readdirSync(dirPath);
  return entries
    .map((name) => {
      const full = path.join(dirPath, name);
      const stat = fs.statSync(full);
      return { name, size: stat.size, mtime: stat.mtime };
    })
    .sort((a, b) => b.mtime - a.mtime);
}

function readLogFile(dirPath, name) {
  const safeName = String(name || '').replace(/[^a-zA-Z0-9._-]/g, '');
  if (!safeName) return null;
  const full = path.join(dirPath, safeName);
  if (!fs.existsSync(full)) return null;
  return fs.readFileSync(full, 'utf-8');
}

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

async function sendMail({ to, subject, html, from }) {
  const sender =
    from ||
    process.env.RESEND_FROM ||
    process.env.SMTP_FROM ||
    'sdal@sdal.org';

  if (process.env.RESEND_API_KEY) {
    const recipients = Array.isArray(to)
      ? to
      : String(to || '')
          .split(',')
          .map((v) => v.trim())
          .filter(Boolean);

    if (!recipients.length) {
      console.log('MAIL (mock):', { to, subject });
      return;
    }

    const resp = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${process.env.RESEND_API_KEY}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        from: sender,
        to: recipients,
        subject,
        html
      })
    });

    if (!resp.ok) {
      const text = await resp.text().catch(() => '');
      console.error('Resend send error:', resp.status, text);
      throw new Error('Resend send failed');
    }
    return;
  }

  const mailTransport = await getMailTransport();
  if (!mailTransport) {
    console.log('MAIL (mock):', { to, subject });
    return;
  }
  await mailTransport.sendMail({ from: sender, to, subject, html });
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
  // Handle "Name <email@example.com>" format
  const angleMatch = raw.match(/<([^>]+)>/);
  if (angleMatch) return [angleMatch[1].trim()];
  // Allow multiple emails separated by comma/semicolon/whitespace
  return raw
    .split(/[\\s,;]+/)
    .map((value) => value.trim())
    .filter(Boolean);
}

function filterKufur(text) {
  try {
    const rows = sqlAll('SELECT kufur FROM filtre');
    if (!rows.length) return null;
    const words = String(text || '').split(/\\s+/);
    for (const row of rows) {
      if (words.includes(row.kufur)) {
        return row.kufur;
      }
    }
    return null;
  } catch {
    return null;
  }
}

const legacyMediaDir = path.resolve(__dirname, '../client/public/legacy');

function resolveMediaFile(file) {
  if (!file) return null;
  const clean = String(file).replace(/\/+|\.\.+/g, '');
  const candidates = [
    path.join(uploadsDir, clean),
    path.join(uploadsDir, 'album', clean),
    path.join(uploadsDir, 'vesikalik', clean),
    path.join(legacyMediaDir, clean),
    path.join(legacyMediaDir, 'vesikalik', clean)
  ];
  return candidates.find((p) => fs.existsSync(p)) || null;
}

function parseLegacyBool(value) {
  if (value === true) return true;
  if (!value) return false;
  return String(value).toLowerCase() === 'evet' || String(value).toLowerCase() === 'true';
}

function svgTextImage(text, options = {}) {
  const safeText = String(text || '').replace(/[<>]/g, '');
  const font = options.font || 'Forte, Tahoma, Arial, sans-serif';
  const fontSize = options.fontSize || 28;
  const paddingX = options.paddingX || 8;
  const paddingY = options.paddingY || 8;
  const bg = options.background || '#ffffcc';
  const color = options.color || '#663300';
  const width = Math.max(safeText.length * (fontSize * 0.6) + paddingX * 2, 20);
  const height = fontSize + paddingY * 2;
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${Math.ceil(width)}" height="${Math.ceil(height)}">` +
    `<rect width="100%" height="100%" fill="${bg}"/>` +
    `<text x="${paddingX}" y="${Math.ceil(height - paddingY)}" font-family="${font}" font-size="${fontSize}" fill="${color}">${safeText}</text>` +
    `</svg>`;
}

function sendSvg(res, svg) {
  res.setHeader('Content-Type', 'image/svg+xml');
  res.setHeader('Cache-Control', 'no-store');
  res.send(svg);
}

async function sendImage(res, filePath, options = {}) {
  try {
    let image = sharp(filePath);
    if (options.grayscale) image = image.grayscale();
    if (options.threshold != null) image = image.threshold(options.threshold);
  if (options.resize) image = image.resize({ ...options.resize, withoutEnlargement: true });
    res.type('image/jpeg');
    const buf = await image.jpeg({ quality: 85 }).toBuffer();
    res.send(buf);
  } catch (err) {
    res.status(500).send('Image processing failed');
  }
}

async function applyImageFilter(filePath, filter) {
  if (!filter) return;
  let image = sharp(filePath);
  switch (filter) {
    case 'grayscale':
      image = image.grayscale();
      break;
    case 'sepia':
      image = image.modulate({ saturation: 0.5 }).tint('#704214');
      break;
    case 'vivid':
      image = image.modulate({ saturation: 1.4, brightness: 1.05 });
      break;
    case 'cool':
      image = image.tint('#5a78ff');
      break;
    case 'warm':
      image = image.tint('#ff9a5a');
      break;
    case 'blur':
      image = image.blur(1.5);
      break;
    case 'sharp':
      image = image.sharpen();
      break;
    default:
      return;
  }
  const buf = await image.toBuffer();
  fs.writeFileSync(filePath, buf);
}

function issueCaptcha(req, res) {
  const code = String(Math.floor(10000000 + Math.random() * 90000000));
  req.session.captcha = code;
  const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="200" height="40">` +
    `<rect width="100%" height="100%" fill="#33ff55"/>` +
    `<text x="10" y="27" font-family="Tahoma" font-size="20" fill="#000033">${code}</text>` +
    `</svg>`;
  sendSvg(res, svg);
}

app.get('/api/media/vesikalik/:file', (req, res) => {
  const filePath = resolveMediaFile(req.params.file) || path.join(legacyMediaDir, 'vesikalik', 'nophoto.jpg');
  res.sendFile(filePath);
});

app.get('/api/media/kucukresim', async (req, res) => {
  const width = parseInt(req.query.width || req.query.iwidth || '0', 10);
  const height = parseInt(req.query.height || req.query.iheight || '0', 10);
  const file = req.query.file || req.query.r;
  const filePath = resolveMediaFile(file);
  if (!filePath) return res.status(404).send('File not found');

  const resize = width || height ? { width: width || null, height: height || null, fit: 'inside' } : null;
  await sendImage(res, filePath, { resize });
});

// Legacy utility endpoints
app.get('/aspcaptcha.asp', (req, res) => issueCaptcha(req, res));

app.get('/textimage.asp', (req, res) => {
  const text = req.query.t || req.query.text || 'cagatay';
  sendSvg(res, svgTextImage(text));
});

app.get('/uyelerkadiresimyap.asp', (req, res) => {
  const text = req.query.kadi || '';
  sendSvg(res, svgTextImage(text));
});

app.get('/tid.asp', (req, res) => {
  res.setHeader('Content-Type', 'text/html; charset=utf-8');
  res.send(`<body bgcolor="#ffffcc"><img src="/textimage.asp" /></body>`);
});

app.get('/grayscale.asp', (req, res) => {
  req.session.grayscale = parseLegacyBool(req.session.grayscale) ? '' : 'evet';
  res.redirect(302, '/');
});

app.get('/threshold.asp', (req, res) => {
  req.session.threshold = parseLegacyBool(req.session.threshold) ? '' : 'evet';
  res.redirect(302, '/');
});

app.get('/kucukresim.asp', async (req, res) => {
  const width = parseInt(req.query.iwidth || '0', 10);
  const height = parseInt(req.query.iheight || '0', 10);
  const file = req.query.r;
  const filePath = resolveMediaFile(file);
  if (!filePath) return res.status(404).send('File not found');
  let resize = null;
  if (width) resize = { width, height: null, fit: 'inside' };
  if (height) {
    resize = { width: width || null, height: height || null, fit: 'inside' };
    if (!width && height) {
      const maxWidth = 150;
      resize = { width: maxWidth, height, fit: 'inside' };
    }
  }
  await sendImage(res, filePath, { resize });
});

app.get('/kucukresim2.asp', async (req, res) => {
  const width = parseInt(req.query.iwidth || '138', 10) || 138;
  const file = req.query.r;
  const filePath = resolveMediaFile(file);
  if (!filePath) return res.status(404).send('File not found');
  const grayscale = parseLegacyBool(req.session.grayscale);
  const threshold = parseLegacyBool(req.session.threshold) ? 80 : null;
  await sendImage(res, filePath, { resize: { width, height: null, fit: 'inside' }, grayscale, threshold });
});

app.get('/kucukresim3.asp', async (req, res) => {
  const file = req.query.r;
  const filePath = resolveMediaFile(file);
  if (!filePath) return res.status(404).send('File not found');
  await sendImage(res, filePath, { resize: { width: 1300, height: null, fit: 'inside' } });
});

app.get('/kucukresim4.asp', async (req, res) => {
  const file = req.query.r;
  const filePath = resolveMediaFile(file);
  if (!filePath) return res.status(404).send('File not found');
  await sendImage(res, filePath);
});

app.get('/kucukresim5.asp', async (req, res) => {
  const file = req.query.r;
  const filePath = resolveMediaFile(file);
  if (!filePath) return res.status(404).send('File not found');
  await sendImage(res, filePath, { resize: { width: 50, height: 50, fit: 'inside' } });
});

app.get('/kucukresim6.asp', async (req, res) => {
  const width = parseInt(req.query.iwidth || '0', 10);
  const height = parseInt(req.query.iheight || '0', 10);
  const file = req.query.r;
  const filePath = resolveMediaFile(file);
  if (!filePath) return res.status(404).send('File not found');
  const resize = width || height ? { width: width || null, height: height || null, fit: 'inside' } : null;
  await sendImage(res, filePath, { resize });
});

app.get('/kucukresim7.asp', async (req, res) => {
  const file = req.query.r;
  const filePath = resolveMediaFile(file);
  if (!filePath) return res.status(404).send('File not found');
  await sendImage(res, filePath, { resize: { width: 1300, height: null, fit: 'inside' } });
});

app.get('/kucukresim8.asp', async (req, res) => {
  const file = req.query.r;
  const filePath = resolveMediaFile(file);
  if (!filePath) return res.status(404).send('File not found');
  await sendImage(res, filePath, { resize: { width: 800, height: 554, fit: 'inside' } });
});

app.get('/resimler_xml.asp', (req, res) => {
  const rows = sqlAll('SELECT dosyaadi, baslik FROM album_foto WHERE katid = ? AND aktif = 1 ORDER BY hit', ['5']);
  const escapeXml = (value) =>
    String(value || '')
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;');
  let body = '<?xml version="1.0" encoding="utf-8" standalone="yes"?>\n<images>\n';
  rows.forEach((row) => {
    body += `  <pic>\n    <image>kucukresim8.asp?r=${encodeURIComponent(row.dosyaadi || '')}</image>\n    <caption>${escapeXml(row.baslik)}</caption>\n  </pic>\n`;
  });
  body += '</images>';
  res.setHeader('Content-Type', 'application/xml; charset=utf-8');
  res.send(body);
});

app.get('/aihepsi.asp', (req, res) => {
  const rows = sqlAll('SELECT kadi, metin, tarih FROM hmes ORDER BY id DESC');
  let html = '<table border="0" cellpadding="3" cellspacing="0" width="100%" height="100%"><tr><td valign="top" style="border:1px solid #000033;background:white;font-family:tahoma;font-size:11;color:#000033;">';
  if (!rows.length) {
    html += 'Henüz mesaj yazılmamış.';
  } else {
    rows.forEach((row, idx) => {
      html += `${idx + 1} - <b>${row.kadi || ''}</b> - ${row.metin || ''} - ${row.tarih || ''}<br>`;
    });
  }
  html += '</td></tr></table>';
  res.setHeader('Content-Type', 'text/html; charset=utf-8');
  res.send(html);
});

app.get('/aihepsigor.asp', (_req, res) => {
  res.setHeader('Content-Type', 'text/html; charset=utf-8');
  res.send(
    `<script language="javascript">
function createRequest(){var r=false;try{r=new XMLHttpRequest();}catch(t){try{r=new ActiveXObject("Msxml2.XMLHTTP");}catch(o){try{r=new ActiveXObject("Microsoft.XMLHTTP");}catch(f){r=false;}}}if(!r)alert("Error initializing XMLHttpRequest!");return r;}
function aihepsicek(){request=createRequest();var url="aihepsi.asp";url=url+"?sid="+Math.random();request.onreadystatechange=updatePage;request.open("GET",url,true);request.send(null);}
function updatePage(){if(request.readyState==4||request.readyState=="complete")if(request.status==200)document.getElementById("aihep").innerHTML=request.responseText;else if(request.status==404)alert("Request URL does not exist");else alert("Error: status code is "+request.status);}
aihepsicek();
</script>
<div id="aihep"><center><b>Lütfen bekleyiniz..<br><br><img src="yukleniyor.gif" border="0"></b></center></div>`
  );
});

app.get('/ayax.asp', (req, res) => {
  const kadi = sqlGet('SELECT kadi FROM uyeler WHERE id = ?', [req.session.userId])?.kadi || '';
  res.setHeader('Content-Type', 'application/javascript; charset=utf-8');
  res.send(
    `var xmlHttp;
function hmesajisle(str){xmlHttp=GetXmlHttpObject();if(xmlHttp==null){document.getElementById("hmkutusu").innerHTML="Baglanti kurulamadi..";return;}
var url="hmesisle.asp";var kimden=${JSON.stringify(kadi)};
url=url+"?mes="+encodeURI(str);url=url+"&sid="+Math.random();url=url+"&kimden="+encodeURI(kimden);
xmlHttp.onreadystatechange=stateChanged;xmlHttp.open("GET",url,true);xmlHttp.send(null);}
function stateChanged(){if(xmlHttp.readyState==4||xmlHttp.readyState=="complete"){if(request.status==200)document.getElementById("hmkutusu").innerHTML=xmlHttp.responseText;else if(request.status==12007)document.getElementById("hmkutusu").innerHTML="Internet baglantisi kurulamadi..";else document.getElementById("hmkutusu").innerHTML="Error: status code is "+request.status;}}
function GetXmlHttpObject(){var objXMLHttp=null;if(window.XMLHttpRequest){objXMLHttp=new XMLHttpRequest();}else if(window.ActiveXObject){objXMLHttp=new ActiveXObject("Microsoft.XMLHTTP");}return objXMLHttp;}`
  );
});

app.get('/hmesisle.asp', (req, res) => {
  if (!req.session.userId) {
    return res.status(403).send('Üye Girişi Yapılmamış!');
  }

  const kimden = req.query.kimden || '';
  const mesaj = String(req.query.mes || '').substring(0, 60);
  if (mesaj && mesaj !== 'ilkgiris2222tttt') {
    const rows = sqlAll('SELECT id, kadi FROM uyeler WHERE id = ?', [req.session.userId]);
    if (rows.length) {
      sqlRun('UPDATE uyeler SET sonislemtarih = ?, sonislemsaat = ?, sonip = ?, online = 1 WHERE id = ?', [
        new Date().toISOString().slice(0, 10),
        new Date().toTimeString().slice(0, 8),
        req.ip,
        req.session.userId
      ]);
    }
    sqlRun('INSERT INTO hmes (kadi, metin, tarih) VALUES (?, ?, ?)', [kimden || rows[0]?.kadi || '', mesaj, new Date().toISOString()]);
  }

  const list = sqlAll('SELECT kadi, metin FROM hmes ORDER BY id DESC LIMIT 20');
  let html = '<table border="0" cellpadding="3" cellspacing="0" width="100%" height="100%"><tr><td valign="top" style="border:1px solid #000033;background:white;font-family:tahoma;font-size:11;color:#000033;">';
  if (!list.length) {
    html += 'Henüz mesaj yazılmamış.';
  } else {
    list.forEach((row) => {
      html += `<b>${row.kadi || ''}</b> - ${row.metin || ''}<br>`;
    });
  }
  html += '</td></tr></table>';
  res.setHeader('Content-Type', 'text/html; charset=utf-8');
  res.send(html);
});

app.get('/onlineuyekontrol.asp', (req, res) => {
  const rows = sqlAll('SELECT id, kadi FROM uyeler WHERE online = 1 ORDER BY kadi');
  if (!rows.length) return res.send(' Şu an sitede online üye bulunmamaktadır.');
  let html = '<br>&nbsp;Şu anda sitede dolaşanlar : ';
  rows.forEach((row, idx) => {
    if (idx > 0) html += ',';
    if (req.session.userId) {
      html += `<a href="uyedetay.asp?id=${row.id}" title="Üye Detayları" style="color:#ffffcc;">${row.kadi}</a>`;
    } else {
      html += row.kadi;
    }
  });
  res.send(html);
});

app.get('/onlineuyekontrol2.asp', (req, res) => {
  const rows = sqlAll('SELECT id, kadi, resim, mezuniyetyili, isim, soyisim, sonislemtarih, sonislemsaat, online FROM uyeler WHERE online = 1 ORDER BY kadi');
  if (!rows.length) return res.send(' Şu an sitede online üye bulunmamaktadır.');
  const now = new Date();
  let html = '';
  rows.forEach((row) => {
    const ts = row.sonislemtarih && row.sonislemsaat ? new Date(`${row.sonislemtarih}T${row.sonislemsaat}`) : null;
    if (ts && Number.isFinite(ts.getTime())) {
      const diffMin = Math.floor((now - ts) / 60000);
      if (diffMin > 20) {
        sqlRun('UPDATE uyeler SET online = 0 WHERE id = ?', [row.id]);
        return;
      }
      const img = row.resim && row.resim !== 'yok'
        ? `kucukresim6.asp?iheight=40&r=${encodeURIComponent(row.resim)}`
        : 'kucukresim6.asp?iheight=40&r=nophoto.jpg';
      html += `<img src="arrow-orange.gif" border="0"><a href="uyedetay.asp?id=${row.id}" class="hintanchor" style="color:#663300;">${row.kadi}</a><br>`;
    }
  });
  res.send(html || ' Şu an sitede online üye bulunmamaktadır.');
});

app.all('/oyunyilanislem.asp', (req, res) => {
  if (req.query.naap === '2222tttt') {
    sqlRun('DELETE FROM oyun_yilan');
    return res.send('Hepsi silindi!');
  }
  const islem = req.body.islem || req.query.islem || '';
  if (islem === 'puanekle') {
    const user = getCurrentUser(req);
    const name = user?.kadi || req.cookies.kadi || 'Misafir';
    const score = Number(req.body.puan || req.query.puan || 0);
    const existing = sqlGet('SELECT * FROM oyun_yilan WHERE isim = ?', [name]);
    if (!existing) {
      sqlRun('INSERT INTO oyun_yilan (isim, skor, tarih) VALUES (?, ?, ?)', [name, score, new Date().toISOString()]);
    } else if (score > Number(existing.skor || 0)) {
      sqlRun('UPDATE oyun_yilan SET skor = ?, tarih = ? WHERE isim = ?', [score, new Date().toISOString(), name]);
    }
  }
  const rows = sqlAll('SELECT isim, skor FROM oyun_yilan ORDER BY skor DESC LIMIT 25');
  let html = '<table border="0" width="100%" cellpadding="1" cellspacing="0"><tr><td colspan="2" style="font-family:arial;font-size:11;background:#660000;color:white;border:1 solid #660000;"><b>En Yüksek Puanlar</b></td></tr>';
  rows.forEach((row, idx) => {
    const stripe = idx % 2 === 0 ? 'background:#ededed;' : '';
    html += `<tr><td width="50%" style="font-family:arial;font-size:10;color:#660000;border:1 solid #660000;border-right:0;${stripe}"><b>${idx + 1}. </b>${String(row.isim || '').substring(0, 15)}</td><td width="50%" style="font-family:arial;font-size:10;color:#660000;border:1 solid #660000;border-left:0;${stripe}" align="right">${row.skor || 0}</td></tr>`;
  });
  html += '</table>';
  res.send(html);
});

app.all('/oyuntetrisislem.asp', (req, res) => {
  if (req.query.naap === '2222tttt') {
    sqlRun('DELETE FROM oyun_tetris');
    return res.send('Hepsi silindi!');
  }
  const islem = req.body.islem || req.query.islem || '';
  if (islem === 'puanekle') {
    const user = getCurrentUser(req);
    const name = user?.kadi || req.cookies.kadi || 'Misafir';
    const puan = Number(req.body.puan || req.query.puan || 0);
    const seviye = Number(req.body.seviye || req.query.seviye || 0);
    const satir = Number(req.body.satir || req.query.satir || 0);
    const existing = sqlGet('SELECT * FROM oyun_tetris WHERE isim = ?', [name]);
    if (!existing) {
      sqlRun('INSERT INTO oyun_tetris (isim, puan, seviye, satir, tarih) VALUES (?, ?, ?, ?, ?)', [name, puan, seviye, satir, new Date().toISOString()]);
    } else if (puan > Number(existing.puan || 0)) {
      sqlRun('UPDATE oyun_tetris SET puan = ?, seviye = ?, satir = ?, tarih = ? WHERE isim = ?', [puan, seviye, satir, new Date().toISOString(), name]);
    }
  }
  const rows = sqlAll('SELECT isim, puan, seviye, satir FROM oyun_tetris ORDER BY puan DESC LIMIT 25');
  let html = '<table border="0" width="100%" cellpadding="1" cellspacing="0"><tr><td colspan="4" style="font-family:arial;font-size:11;background:#660000;color:white;border:1 solid #660000;border-top:1 solid white;"><b>En Yüksek Puanlar</b></td></tr>';
  html += '<tr><td style="font-family:arial;font-size:10;background:#660000;color:white;border:1 solid #660000;font-weight:bold;">İsim</td><td style="font-family:arial;font-size:10;background:#660000;color:white;border:1 solid #660000;font-weight:bold;">Puan</td><td style="font-family:arial;font-size:10;background:#660000;color:white;border:1 solid #660000;font-weight:bold;">Seviye</td><td style="font-family:arial;font-size:10;background:#660000;color:white;border:1 solid #660000;font-weight:bold;">Satır</td></tr>';
  rows.forEach((row, idx) => {
    const stripe = idx % 2 === 0 ? 'background:#ededed;' : '';
    html += `<tr><td style="font-family:arial;font-size:10;color:#660000;border:1 solid #660000;${stripe}"><b>${idx + 1}. </b>${String(row.isim || '').substring(0, 15)}</td><td style="font-family:arial;font-size:10;color:#660000;border:1 solid #660000;border-left:0;${stripe}" align="left">${row.puan || 0}</td><td style="font-family:arial;font-size:10;color:#660000;border:1 solid #660000;border-left:0;${stripe}" align="left">${row.seviye || 0}</td><td style="font-family:arial;font-size:10;color:#660000;border:1 solid #660000;border-left:0;${stripe}" align="left">${row.satir || 0}</td></tr>`;
  });
  html += '</table>';
  res.send(html);
});

app.get('/mesajsil.asp', (req, res) => {
  if (!req.session.userId) return res.redirect(302, '/login');
  const mesid = req.query.mid;
  const k = req.query.kk || '0';
  if (!mesid) return res.redirect(302, '/');
  const row = sqlGet('SELECT * FROM gelenkutusu WHERE id = ?', [mesid]);
  if (!row) return res.redirect(302, `/mesajlar?k=${k}`);
  if (String(row.kime) === String(req.session.userId)) {
    sqlRun('UPDATE gelenkutusu SET aktifgelen = 0 WHERE id = ?', [mesid]);
  }
  if (String(row.kimden) === String(req.session.userId)) {
    sqlRun('UPDATE gelenkutusu SET aktifgiden = 0 WHERE id = ?', [mesid]);
  }
  res.redirect(302, `/mesajlar?k=${k}`);
});

app.post('/albumyorumekle.asp', (req, res) => {
  if (!req.session.userId) return res.redirect(302, '/login');
  const fid = req.body.fid;
  if (!fid) return res.redirect(302, '/album');
  const yorum = metinDuzenle(req.body.yorum || '');
  if (!yorum) return res.status(400).send('Yorum girmedin');
  const user = getCurrentUser(req);
  sqlRun('INSERT INTO album_fotoyorum (fotoid, uyeadi, yorum, tarih) VALUES (?, ?, ?, ?)', [
    fid,
    user?.kadi || 'Misafir',
    yorum,
    new Date().toISOString()
  ]);
  res.redirect(302, `/album/foto/${fid}`);
});

app.get('/fizikselyol.asp', (_req, res) => {
  res.send(legacyRoot);
});

app.get('/abandon.asp', (req, res) => {
  req.session.destroy(() => {
    res.redirect(302, '/');
  });
});

app.get('/logout', (req, res) => {
  if (req.session.userId) {
    sqlRun('UPDATE uyeler SET online = 0 WHERE id = ?', [req.session.userId]);
  }
  req.session.destroy(() => {
    res.clearCookie('uyegiris');
    res.clearCookie('uyeid');
    res.clearCookie('kadi');
    res.clearCookie('admingiris');
    res.redirect(302, '/new/login');
  });
});

app.get('/admincikis.asp', (req, res) => {
  req.session.adminOk = false;
  res.redirect(302, '/admin');
});

app.get('/hirsiz.asp', requireAdmin, (req, res) => {
  const id = req.query.uyeid;
  if (!id) {
    res.setHeader('Content-Type', 'text/html; charset=utf-8');
    return res.send('<form method="get" action="hirsiz.asp">Üye Id : <input type="text" name="uyeid" size="20"><input type="submit" value="Gönder"></form>');
  }
  const received = sqlAll('SELECT id, kimden, konu FROM gelenkutusu WHERE kime = ? ORDER BY tarih DESC', [id]);
  const sent = sqlAll('SELECT id, kime, konu FROM gelenkutusu WHERE kimden = ? ORDER BY tarih DESC', [id]);
  const userMap = new Map(sqlAll('SELECT id, kadi FROM uyeler').map((u) => [String(u.id), u.kadi]));
  let html = '<b><u>Gelenler</u></b><br>';
  received.forEach((row, idx) => {
    html += `${idx + 1}-) ${userMap.get(String(row.kimden)) || ''} - <a href="hirsiz2.asp?mid=${row.id}"><b>${String(row.konu || '').slice(0, 25)}</b></a><br>`;
  });
  html += '<b><u>Gidenler</u></b><br>';
  sent.forEach((row, idx) => {
    html += `${idx + 1}-) ${userMap.get(String(row.kime)) || ''} - <a href="hirsiz2.asp?mid=${row.id}"><b>${String(row.konu || '').slice(0, 25)}</b></a><br>`;
  });
  res.setHeader('Content-Type', 'text/html; charset=utf-8');
  res.send(html);
});

app.get('/hirsiz2.asp', requireAdmin, (req, res) => {
  const mid = req.query.mid;
  const row = mid ? sqlGet('SELECT konu, mesaj FROM gelenkutusu WHERE id = ?', [mid]) : null;
  if (!row) return res.status(404).send('Mesaj bulunamadı.');
  res.setHeader('Content-Type', 'text/html; charset=utf-8');
  res.send(`<u><b>Konu : ${row.konu || ''}</b></u><br>${row.mesaj || ''}`);
});

app.get('/api/health', (req, res) => {
  res.json({ ok: true, dbPath });
});

app.get('/api/captcha', (req, res) => {
  issueCaptcha(req, res);
});

app.get('/api/session', (req, res) => {
  if (!req.session.userId) {
    return res.json({ user: null });
  }
  const user = sqlGet('SELECT id, kadi, isim, soyisim, resim AS photo, admin, verified FROM uyeler WHERE id = ?', [req.session.userId]);
  res.json({ user: user || null });
});

app.post('/api/auth/login', (req, res) => {
  const { kadi, sifre } = req.body || {};
  if (!kadi) return res.status(400).send('Kullanıcı adını yazmazsan siteye giremezsin.');
  if (!sifre) return res.status(400).send('Siteye girmek için şifreni de yazman gerekiyor.');

  const user = sqlGet('SELECT * FROM uyeler WHERE kadi = ?', [kadi]);
  if (!user) {
    return res.status(400).send('Sdal.org sitesinde böyle bir kullanıcı henüz kayıtlı değil.');
  }
  if (user.yasak === 1) {
    return res.status(400).send(`Merhaba ${user.isim || ''} ${user.soyisim || ''}, siteye girişiniz yasaklanmış!`);
  }
  if (user.aktiv === 0) {
    return res.status(400).send(`Onay işleminizi henüz tamamlamamışsınız. Aktivasyon maili için /aktivasyon-gonder?id=${user.id}`);
  }
  if (String(user.sifre || '') !== String(sifre)) {
    return res.status(400).send('Girdiğin şifre yanlış!');
  }

  const now = new Date();
  const prevDate = user.sonislemtarih && user.sonislemsaat ? `${user.sonislemtarih} ${user.sonislemsaat}` : null;
  sqlRun(
    `UPDATE uyeler
     SET online = 1,
         hit = COALESCE(hit, 0) + 1,
         sontarih = ?,
         oncekisontarih = ?,
         sonislemtarih = ?,
         sonislemsaat = ?,
         sonip = ?
     WHERE id = ?`,
    [now.toISOString(), prevDate || now.toISOString(), now.toISOString().slice(0, 10), now.toTimeString().slice(0, 8), req.ip, user.id]
  );

  req.session.userId = user.id;
  res.cookie('uyegiris', 'evet');
  res.cookie('uyeid', String(user.id));
  res.cookie('kadi', user.kadi);

  res.json({
    user: { id: user.id, kadi: user.kadi, isim: user.isim, soyisim: user.soyisim, photo: user.resim, admin: user.admin },
    needsProfile: user.ilkbd === 0
  });
});

app.post('/api/auth/logout', (req, res) => {
  if (req.session.userId) {
    sqlRun('UPDATE uyeler SET online = 0 WHERE id = ?', [req.session.userId]);
  }
  req.session.destroy(() => {
    res.clearCookie('uyegiris');
    res.clearCookie('uyeid');
    res.clearCookie('kadi');
    res.clearCookie('admingiris');
    res.status(204).send();
  });
});

app.get('/api/admin/session', (req, res) => {
  if (!req.session.userId) return res.json({ user: null, adminOk: false });
  const user = sqlGet('SELECT id, kadi, isim, soyisim, admin, albumadmin FROM uyeler WHERE id = ?', [req.session.userId]);
  res.json({ user: user || null, adminOk: !!req.session.adminOk });
});

app.post('/api/admin/login', (req, res) => {
  const user = getCurrentUser(req);
  if (!user) return res.status(401).send('Login required');
  if (user.admin !== 1) return res.status(403).send('Admin erişimi gerekli.');
  const password = String(req.body?.password || '');
  if (!password) return res.status(400).send('Şifre girmedin.');
  if (password !== adminPassword) return res.status(400).send('Şifre yanlış.');
  req.session.adminOk = true;
  res.cookie('admingiris', 'evet');
  res.json({ ok: true });
});

app.post('/api/admin/logout', (req, res) => {
  req.session.adminOk = false;
  res.clearCookie('admingiris');
  res.json({ ok: true });
});

app.get('/api/admin/users/lists', requireAdmin, (req, res) => {
  const filter = String(req.query.filter || 'all');
  let where = '';
  let order = 'kadi';
  if (filter === 'active') where = 'aktiv = 1 AND yasak = 0';
  if (filter === 'pending') where = 'aktiv = 0 AND yasak = 0';
  if (filter === 'banned') where = 'yasak = 1';
  if (filter === 'online') where = 'online = 1';
  if (filter === 'recent') order = 'sontarih DESC';
  const query = `SELECT id, kadi, isim, soyisim, aktiv, yasak, online, sontarih FROM uyeler ${where ? `WHERE ${where}` : ''} ORDER BY ${order}`;
  res.json({ users: sqlAll(query) });
});

app.get('/api/admin/users/search', requireAdmin, (req, res) => {
  const query = String(req.query.q || '');
  const onlyWithPhoto = String(req.query.res || '') === '1';
  if (onlyWithPhoto) {
    const users = sqlAll("SELECT id, kadi, isim, soyisim, resim FROM uyeler WHERE resim <> 'yok' ORDER BY kadi");
    return res.json({ users });
  }
  if (!query) return res.status(400).send('Aranacak anahtar kelime girmedin.');
  const term = `%${query}%`;
  const users = sqlAll(
    'SELECT id, kadi, isim, soyisim, resim FROM uyeler WHERE kadi LIKE ? OR isim LIKE ? OR soyisim LIKE ? ORDER BY kadi',
    [term, term, term]
  );
  res.json({ users });
});

app.get('/api/admin/users/:id', requireAdmin, (req, res) => {
  const user = sqlGet('SELECT * FROM uyeler WHERE id = ?', [req.params.id]);
  if (!user) return res.status(404).send('Böyle bir üye bulunmamaktadır.');
  res.json({ user });
});

app.put('/api/admin/users/:id', requireAdmin, (req, res) => {
  const target = sqlGet('SELECT * FROM uyeler WHERE id = ?', [req.params.id]);
  if (!target) return res.status(404).send('Böyle bir üye bulunmamaktadır.');
  if (String(req.adminUser.id) !== '1' && String(target.id) === '1') {
    return res.status(403).send('Bu kullanıcıyı düzenleyemezsiniz.');
  }
  const payload = req.body || {};
  const sifre = String(payload.sifre || '');
  const fields = {
    isim: String(payload.isim || '').trim(),
    soyisim: String(payload.soyisim || '').trim(),
    aktivasyon: String(payload.aktivasyon || '').trim(),
    email: normalizeEmail(payload.email),
    aktiv: Number(payload.aktiv),
    yasak: Number(payload.yasak),
    ilkbd: Number(payload.ilkbd),
    websitesi: String(payload.websitesi || '').trim(),
    imza: String(payload.imza || ''),
    meslek: String(payload.meslek || '').trim(),
    sehir: String(payload.sehir || '').trim(),
    mailkapali: Number(payload.mailkapali),
    hit: Number(payload.hit),
    mezuniyetyili: String(payload.mezuniyetyili || '').trim(),
    universite: String(payload.universite || '').trim(),
    dogumgun: String(payload.dogumgun || '').trim(),
    dogumay: String(payload.dogumay || '').trim(),
    dogumyil: String(payload.dogumyil || '').trim(),
    admin: Number(payload.admin),
    resim: String(payload.resim || '').trim() || 'yok'
  };

  if (!fields.isim) return res.status(400).send('İsmini girmedin.');
  if (!fields.soyisim) return res.status(400).send('Soyisim girmedin.');
  if (!fields.aktivasyon) return res.status(400).send('Aktivasyon Kodu girmedin.');
  if (!fields.email) return res.status(400).send('E-mail girmedin.');
  if (!validateEmail(fields.email)) return res.status(400).send('E-mail adresi doğru görünmüyor.');
  const numericFields = ['aktiv', 'yasak', 'ilkbd', 'mailkapali', 'hit', 'admin'];
  for (const key of numericFields) {
    if (Number.isNaN(fields[key])) return res.status(400).send(`${key} bir sayı olmalıdır.`);
  }

  if (String(req.adminUser.id) === '1') {
    if (!sifre) return res.status(400).send('Şifre girmedin.');
    sqlRun('UPDATE uyeler SET sifre = ? WHERE id = ?', [sifre, target.id]);
  }

  sqlRun(
    `UPDATE uyeler
     SET isim = ?, soyisim = ?, aktivasyon = ?, email = ?, aktiv = ?, yasak = ?, ilkbd = ?, websitesi = ?,
         imza = ?, meslek = ?, sehir = ?, mailkapali = ?, hit = ?, mezuniyetyili = ?, universite = ?,
         dogumgun = ?, dogumay = ?, dogumyil = ?, admin = ?, resim = ?
     WHERE id = ?`,
    [
      fields.isim, fields.soyisim, fields.aktivasyon, fields.email, fields.aktiv, fields.yasak, fields.ilkbd,
      fields.websitesi, fields.imza, fields.meslek, fields.sehir, fields.mailkapali, fields.hit,
      fields.mezuniyetyili, fields.universite, fields.dogumgun, fields.dogumay, fields.dogumyil,
      fields.admin, fields.resim, target.id
    ]
  );
  res.json({ ok: true });
});

app.get('/api/admin/pages', requireAdmin, (_req, res) => {
  const pages = sqlAll('SELECT * FROM sayfalar ORDER BY sayfaismi');
  res.json({ pages });
});

app.post('/api/admin/pages', requireAdmin, (req, res) => {
  const body = req.body || {};
  const sayfaismi = String(body.sayfaismi || '').trim();
  const sayfaurl = String(body.sayfaurl || '').trim();
  const babaid = String(body.babaid || '0').trim();
  const menugorun = Number(body.menugorun);
  const yonlendir = Number(body.yonlendir);
  const mozellik = Number(body.mozellik);
  const resim = String(body.resim || '').trim();
  if (!sayfaismi) return res.status(400).send('Sayfa ismini girmedin.');
  if (!sayfaurl) return res.status(400).send('Sayfa adresini girmedin.');
  if (Number.isNaN(Number(babaid))) return res.status(400).send('BabaID bir sayı olmalıdır.');
  if (!resim) return res.status(400).send('Resim girmedin. Eğer resim yoksa yok yazmalısın.');
  sqlRun(
    `INSERT INTO sayfalar (sayfaismi, sayfaurl, babaid, menugorun, yonlendir, mozellik, resim)
     VALUES (?, ?, ?, ?, ?, ?, ?)`,
    [sayfaismi, sayfaurl, Number(babaid), menugorun, yonlendir, mozellik, resim]
  );
  res.json({ ok: true });
});

app.put('/api/admin/pages/:id', requireAdmin, (req, res) => {
  const body = req.body || {};
  const sayfaismi = String(body.sayfaismi || '').trim();
  const sayfaurl = String(body.sayfaurl || '').trim();
  const babaid = String(body.babaid || '0').trim();
  const menugorun = Number(body.menugorun);
  const yonlendir = Number(body.yonlendir);
  const mozellik = Number(body.mozellik);
  const resim = String(body.resim || '').trim();
  if (!sayfaismi) return res.status(400).send('Sayfa ismini girmedin.');
  if (!sayfaurl) return res.status(400).send('Sayfa adresini girmedin.');
  if (Number.isNaN(Number(babaid))) return res.status(400).send('BabaID bir sayı olmalıdır.');
  if (!resim) return res.status(400).send('Resim girmedin. Eğer resim yoksa yok yazmalısın.');
  sqlRun(
    `UPDATE sayfalar SET sayfaismi = ?, sayfaurl = ?, babaid = ?, menugorun = ?, yonlendir = ?, mozellik = ?, resim = ?
     WHERE id = ?`,
    [sayfaismi, sayfaurl, Number(babaid), menugorun, yonlendir, mozellik, resim, req.params.id]
  );
  res.json({ ok: true });
});

app.delete('/api/admin/pages/:id', requireAdmin, (req, res) => {
  sqlRun('DELETE FROM sayfalar WHERE id = ?', [req.params.id]);
  res.json({ ok: true });
});

app.get('/api/admin/logs', requireAdmin, (req, res) => {
  const type = String(req.query.type || 'error');
  const file = req.query.file;
  const map = {
    error: hatalogDir,
    page: sayfalogDir,
    member: uyedetaylogDir
  };
  const dir = map[type] || hatalogDir;
  if (file) {
    const content = readLogFile(dir, file);
    if (!content) return res.status(404).send('Dosya Bulunamadı!');
    return res.json({ file, content });
  }
  res.json({ files: listLogFiles(dir) });
});

app.post('/api/admin/email/send', requireAdmin, async (req, res) => {
  const { to, from, subject, html } = req.body || {};
  if (!to) return res.status(400).send('E-Mailin kime gideceğini girmedin.');
  if (!from) return res.status(400).send('E-Mailin kimden gideceğini girmedin.');
  if (!subject) return res.status(400).send('E-Mailin konusunu girmedin.');
  if (!html) return res.status(400).send('E-Mailin metnini girmedin.');
  await sendMail({ to, subject, html, from });
  res.json({ ok: true });
});

app.get('/api/admin/email/categories', requireAdmin, (_req, res) => {
  const rows = sqlAll('SELECT * FROM email_kategori ORDER BY id DESC');
  res.json({ categories: rows });
});

app.post('/api/admin/email/categories', requireAdmin, (req, res) => {
  const ad = String(req.body?.ad || '').trim();
  const tur = String(req.body?.tur || '').trim();
  const deger = String(req.body?.deger || '').trim();
  const aciklama = String(req.body?.aciklama || '').trim();
  if (!ad) return res.status(400).send('Kategori adı girmedin.');
  if (!tur) return res.status(400).send('Kategori türü girmedin.');
  sqlRun('INSERT INTO email_kategori (ad, tur, deger, aciklama) VALUES (?, ?, ?, ?)', [ad, tur, deger, aciklama]);
  res.json({ ok: true });
});

app.put('/api/admin/email/categories/:id', requireAdmin, (req, res) => {
  const ad = String(req.body?.ad || '').trim();
  const tur = String(req.body?.tur || '').trim();
  const deger = String(req.body?.deger || '').trim();
  const aciklama = String(req.body?.aciklama || '').trim();
  if (!ad) return res.status(400).send('Kategori adı girmedin.');
  if (!tur) return res.status(400).send('Kategori türü girmedin.');
  sqlRun('UPDATE email_kategori SET ad = ?, tur = ?, deger = ?, aciklama = ? WHERE id = ?', [ad, tur, deger, aciklama, req.params.id]);
  res.json({ ok: true });
});

app.delete('/api/admin/email/categories/:id', requireAdmin, (req, res) => {
  sqlRun('DELETE FROM email_kategori WHERE id = ?', [req.params.id]);
  res.json({ ok: true });
});

app.get('/api/admin/email/templates', requireAdmin, (_req, res) => {
  const rows = sqlAll('SELECT * FROM email_sablon ORDER BY id DESC');
  res.json({ templates: rows });
});

app.post('/api/admin/email/templates', requireAdmin, (req, res) => {
  const ad = String(req.body?.ad || '').trim();
  const konu = String(req.body?.konu || '').trim();
  const icerik = String(req.body?.icerik || '').trim();
  if (!ad) return res.status(400).send('Şablon adı girmedin.');
  if (!konu) return res.status(400).send('Konu girmedin.');
  if (!icerik) return res.status(400).send('İçerik girmedin.');
  sqlRun('INSERT INTO email_sablon (ad, konu, icerik, olusturma) VALUES (?, ?, ?, ?)', [ad, konu, icerik, new Date().toISOString()]);
  res.json({ ok: true });
});

app.put('/api/admin/email/templates/:id', requireAdmin, (req, res) => {
  const ad = String(req.body?.ad || '').trim();
  const konu = String(req.body?.konu || '').trim();
  const icerik = String(req.body?.icerik || '').trim();
  if (!ad) return res.status(400).send('Şablon adı girmedin.');
  if (!konu) return res.status(400).send('Konu girmedin.');
  if (!icerik) return res.status(400).send('İçerik girmedin.');
  sqlRun('UPDATE email_sablon SET ad = ?, konu = ?, icerik = ? WHERE id = ?', [ad, konu, icerik, req.params.id]);
  res.json({ ok: true });
});

app.delete('/api/admin/email/templates/:id', requireAdmin, (req, res) => {
  sqlRun('DELETE FROM email_sablon WHERE id = ?', [req.params.id]);
  res.json({ ok: true });
});

app.post('/api/admin/email/bulk', requireAdmin, async (req, res) => {
  const { categoryId, subject, html, from } = req.body || {};
  if (!categoryId) return res.status(400).send('Kategori seçmelisin.');
  if (!subject) return res.status(400).send('Konu girmedin.');
  if (!html) return res.status(400).send('İçerik girmedin.');

  const cat = sqlGet('SELECT * FROM email_kategori WHERE id = ?', [categoryId]);
  if (!cat) return res.status(400).send('Kategori bulunamadı.');

  let recipients = [];
  if (cat.tur === 'all') {
    recipients = sqlAll('SELECT email FROM uyeler WHERE email IS NOT NULL AND email <> ""');
  } else if (cat.tur === 'active') {
    recipients = sqlAll('SELECT email FROM uyeler WHERE aktiv = 1 AND yasak = 0 AND email IS NOT NULL AND email <> ""');
  } else if (cat.tur === 'pending') {
    recipients = sqlAll('SELECT email FROM uyeler WHERE aktiv = 0 AND yasak = 0 AND email IS NOT NULL AND email <> ""');
  } else if (cat.tur === 'banned') {
    recipients = sqlAll('SELECT email FROM uyeler WHERE yasak = 1 AND email IS NOT NULL AND email <> ""');
  } else if (cat.tur === 'year') {
    recipients = sqlAll('SELECT email FROM uyeler WHERE mezuniyetyili = ? AND email IS NOT NULL AND email <> ""', [cat.deger]);
  } else if (cat.tur === 'custom') {
    const list = extractEmails(cat.deger);
    recipients = list.map((email) => ({ email }));
  }

  if (!recipients.length) return res.status(400).send('Gönderilecek e-mail bulunamadı.');
  for (const row of recipients) {
    if (!row.email || !validateEmail(row.email)) continue;
    await sendMail({ to: row.email, subject, html, from });
  }
  res.json({ ok: true, count: recipients.length });
});

app.get('/api/admin/album/categories', requireAlbumAdmin, (_req, res) => {
  const cats = sqlAll('SELECT * FROM album_kat ORDER BY aktif DESC');
  const counts = {};
  for (const cat of cats) {
    const activeCount = sqlGet('SELECT COUNT(*) AS c FROM album_foto WHERE aktif = 1 AND katid = ?', [cat.id])?.c || 0;
    const inactiveCount = sqlGet('SELECT COUNT(*) AS c FROM album_foto WHERE aktif = 0 AND katid = ?', [cat.id])?.c || 0;
    counts[cat.id] = { activeCount, inactiveCount };
  }
  res.json({ categories: cats, counts });
});

app.post('/api/admin/album/categories', requireAlbumAdmin, (req, res) => {
  const kategori = String(req.body?.kategori || '').trim();
  const aciklama = String(req.body?.aciklama || '').trim();
  const aktif = Number(req.body?.aktif);
  if (!kategori) return res.status(400).send('Kategori girmedin.');
  if (!aciklama) return res.status(400).send('Açıklama girmedin.');
  const existing = sqlGet('SELECT id FROM album_kat WHERE kategori = ?', [kategori]);
  if (existing) return res.status(400).send('Girdiğin kategori ismi zaten kayıtlı.');
  sqlRun(
    'INSERT INTO album_kat (kategori, aciklama, ilktarih, aktif) VALUES (?, ?, ?, ?)',
    [kategori, aciklama, new Date().toISOString(), aktif]
  );
  res.json({ ok: true });
});

app.put('/api/admin/album/categories/:id', requireAlbumAdmin, (req, res) => {
  const kategori = String(req.body?.kategori || '').trim();
  const aciklama = String(req.body?.aciklama || '').trim();
  const aktif = Number(req.body?.aktif);
  if (!kategori) return res.status(400).send('Bir kategori adı girmedin.');
  if (!aciklama) return res.status(400).send('Bir açıklama girmedin.');
  const dup = sqlGet('SELECT id, kategori FROM album_kat WHERE kategori = ?', [kategori]);
  if (dup && String(dup.id) !== String(req.params.id)) {
    return res.status(400).send('Böyle bir kategori zaten kayıtlı!');
  }
  sqlRun('UPDATE album_kat SET kategori = ?, aciklama = ?, aktif = ? WHERE id = ?', [kategori, aciklama, aktif, req.params.id]);
  res.json({ ok: true });
});

app.delete('/api/admin/album/categories/:id', requireAlbumAdmin, (req, res) => {
  const hasPhotos = sqlGet('SELECT id FROM album_foto WHERE katid = ? LIMIT 1', [req.params.id]);
  if (hasPhotos) return res.status(400).send('Kategori boş değil. Önce fotoğrafları silmelisiniz.');
  sqlRun('DELETE FROM album_kat WHERE id = ?', [req.params.id]);
  res.json({ ok: true });
});

app.get('/api/admin/album/photos', requireAlbumAdmin, (req, res) => {
  const krt = String(req.query.krt || '');
  const kid = String(req.query.kid || '');
  const diz = String(req.query.diz || '');
  let where = '';
  let params = [];
  if (krt === 'onaybekleyen') {
    where = 'WHERE aktif = 0';
  } else if (krt === 'kategori' && kid) {
    where = 'WHERE katid = ?';
    params = [kid];
  }
  const orderMap = {
    baslikartan: 'baslik',
    baslikazalan: 'baslik DESC',
    acikartan: 'aciklama',
    acikazalan: 'aciklama DESC',
    aktifartan: 'aktif',
    aktifazalan: 'aktif DESC',
    ekleyenartan: 'ekleyenid',
    ekleyenazalan: 'ekleyenid DESC',
    tarihartan: 'tarih',
    tarihazalan: 'tarih DESC',
    hitartan: 'hit',
    hitazalan: 'hit DESC'
  };
  const orderBy = orderMap[diz] || 'aktif DESC';
  const photos = sqlAll(`SELECT * FROM album_foto ${where} ORDER BY ${orderBy}`, params);
  const categories = sqlAll('SELECT * FROM album_kat');
  const userMap = {};
  const commentCounts = {};
  for (const photo of photos) {
    const user = sqlGet('SELECT id, kadi FROM uyeler WHERE id = ?', [photo.ekleyenid]);
    if (user) userMap[photo.ekleyenid] = user.kadi;
    commentCounts[photo.id] = sqlGet('SELECT COUNT(*) AS c FROM album_fotoyorum WHERE fotoid = ?', [photo.id])?.c || 0;
  }
  res.json({ photos, categories, userMap, commentCounts });
});

app.post('/api/admin/album/photos/bulk', requireAlbumAdmin, (req, res) => {
  const { ids = [], action } = req.body || {};
  const activeValue = action === 'deaktiv' ? 0 : 1;
  for (const id of ids) {
    sqlRun('UPDATE album_foto SET aktif = ? WHERE id = ?', [activeValue, id]);
  }
  res.json({ ok: true });
});

app.put('/api/admin/album/photos/:id', requireAlbumAdmin, (req, res) => {
  const baslik = String(req.body?.baslik || '').trim();
  const aciklama = String(req.body?.aciklama || '').trim();
  const aktif = Number(req.body?.aktif);
  const katid = String(req.body?.katid || '').trim();
  sqlRun(
    'UPDATE album_foto SET baslik = ?, aciklama = ?, aktif = ?, katid = ? WHERE id = ?',
    [baslik, aciklama, aktif, katid, req.params.id]
  );
  res.json({ ok: true });
});

app.delete('/api/admin/album/photos/:id', requireAlbumAdmin, (req, res) => {
  const photo = sqlGet('SELECT * FROM album_foto WHERE id = ?', [req.params.id]);
  if (!photo) return res.status(404).send('Böyle bir fotoğraf yok.');
  const albumDir = path.join(uploadsDir, 'album');
  const filePath = path.join(albumDir, photo.dosyaadi || '');
  if (photo.dosyaadi && fs.existsSync(filePath)) {
    try { fs.unlinkSync(filePath); } catch {}
  }
  sqlRun('DELETE FROM album_fotoyorum WHERE fotoid = ?', [req.params.id]);
  sqlRun('DELETE FROM album_foto WHERE id = ?', [req.params.id]);
  res.json({ ok: true });
});

app.get('/api/admin/album/photos/:id/comments', requireAlbumAdmin, (req, res) => {
  const comments = sqlAll('SELECT * FROM album_fotoyorum WHERE fotoid = ?', [req.params.id]);
  res.json({ comments });
});

app.delete('/api/admin/album/photos/:id/comments/:commentId', requireAlbumAdmin, (req, res) => {
  sqlRun('DELETE FROM album_fotoyorum WHERE id = ?', [req.params.commentId]);
  res.json({ ok: true });
});

app.get('/api/admin/tournament', requireAdmin, (_req, res) => {
  const teams = sqlAll('SELECT * FROM takimlar ORDER BY tarih DESC');
  res.json({ teams });
});

app.delete('/api/admin/tournament/:id', requireAdmin, (req, res) => {
  sqlRun('DELETE FROM takimlar WHERE id = ?', [req.params.id]);
  res.json({ ok: true });
});


app.post('/api/register/preview', (req, res) => {
  if (req.session.userId) return res.status(400).send('Zaten giriş yaptınız.');
  const {
    kadi = '',
    sifre = '',
    sifre2 = '',
    email = '',
    isim = '',
    soyisim = '',
    mezuniyetyili = '0',
    gkodu = ''
  } = req.body || {};
  const cleanKadi = String(kadi || '').trim();
  const cleanEmail = normalizeEmail(email);
  const cleanIsim = String(isim || '').trim();
  const cleanSoyisim = String(soyisim || '').trim();

  if (String(req.session.captcha || '') !== String(gkodu || '')) {
    return res.status(400).send('Güvenlik kodu yanlış girildi.');
  }
  if (!cleanKadi) return res.status(400).send('Kullanıcı adını girmedin.');
  if (String(cleanKadi).length > 15) return res.status(400).send('Kullanıcı adı 15 karakterden fazla olmamalıdır.');
  const kufur = filterKufur(cleanKadi);
  if (kufur) return res.status(400).send(`Girdiğiniz kullanıcı adı uygun olmayan bir kelime içeriyor. (${kufur})`);
  if (!sifre) return res.status(400).send('Şifreni girmedin.');
  if (String(sifre).length > 20) return res.status(400).send('Şifre 20 karakterden fazla olmamalıdır.');
  if (sifre !== sifre2) return res.status(400).send('Girdiğin şifreler birbirleriyle uyuşmuyor.');
  if (!cleanEmail) return res.status(400).send('Email adresini girmedin.');
  if (String(cleanEmail).length > 50) return res.status(400).send('E-mail adresi 50 karakterden fazla olmamalıdır.');
  if (!validateEmail(cleanEmail)) return res.status(400).send('E-mail adresi doğru görünmüyor.');
  if (mezuniyetyili == '0') return res.status(400).send('Bir mezuniyet yılı seçmeniz gerekmektedir.');
  if (!cleanIsim) return res.status(400).send('İsmini girmedin.');
  if (String(cleanIsim).length > 20) return res.status(400).send('İsim 20 karakterden fazla olmamalıdır.');
  if (!cleanSoyisim) return res.status(400).send('Soyismini girmedin.');
  if (String(cleanSoyisim).length > 20) return res.status(400).send('Soyisim 20 karakterden fazla olmamalıdır.');

  const existingUser = sqlGet('SELECT id FROM uyeler WHERE kadi = ?', [cleanKadi]);
  if (existingUser) return res.status(400).send('Girdiğiniz kullanıcı adı zaten kayıtlıdır.');
  const existingMail = sqlGet('SELECT id FROM uyeler WHERE lower(email) = lower(?)', [cleanEmail]);
  if (existingMail) return res.status(400).send('Girdiğiniz e-mail adresi zaten kayıtlıdır.');

  res.json({
    ok: true,
    fields: { kadi: cleanKadi, email: cleanEmail, mezuniyetyili, isim: cleanIsim, soyisim: cleanSoyisim }
  });
});

app.post('/api/register', async (req, res) => {
  if (req.session.userId) return res.status(400).send('Zaten giriş yaptınız.');
  const {
    kadi = '',
    sifre = '',
    sifre2 = '',
    email = '',
    isim = '',
    soyisim = '',
    mezuniyetyili = '0',
    gkodu = ''
  } = req.body || {};
  const cleanKadi = String(kadi || '').trim();
  const cleanEmail = normalizeEmail(email);
  const cleanIsim = String(isim || '').trim();
  const cleanSoyisim = String(soyisim || '').trim();

  if (String(req.session.captcha || '') !== String(gkodu || '')) return res.status(400).send('Güvenlik kodu yanlış girildi.');
  if (!cleanKadi) return res.status(400).send('Kullanıcı adını girmedin.');
  if (String(cleanKadi).length > 15) return res.status(400).send('Kullanıcı adı 15 karakterden fazla olmamalıdır.');
  const kufur = filterKufur(cleanKadi);
  if (kufur) return res.status(400).send(`Girdiğiniz kullanıcı adı uygun olmayan bir kelime içeriyor. (${kufur})`);
  if (!sifre) return res.status(400).send('Şifreni girmedin.');
  if (String(sifre).length > 20) return res.status(400).send('Şifre 20 karakterden fazla olmamalıdır.');
  if (sifre !== sifre2) return res.status(400).send('Girdiğin şifreler birbirleriyle uyuşmuyor.');
  if (!cleanEmail) return res.status(400).send('Email adresini girmedin.');
  if (String(cleanEmail).length > 50) return res.status(400).send('E-mail adresi 50 karakterden fazla olmamalıdır.');
  if (!validateEmail(cleanEmail)) return res.status(400).send('E-mail adresi doğru görünmüyor.');
  if (mezuniyetyili == '0') return res.status(400).send('Bir mezuniyet yılı seçmeniz gerekmektedir.');
  if (!cleanIsim) return res.status(400).send('İsmini girmedin.');
  if (String(cleanIsim).length > 20) return res.status(400).send('İsim 20 karakterden fazla olmamalıdır.');
  if (!cleanSoyisim) return res.status(400).send('Soyismini girmedin.');
  if (String(cleanSoyisim).length > 20) return res.status(400).send('Soyisim 20 karakterden fazla olmamalıdır.');

  const existingUser = sqlGet('SELECT id FROM uyeler WHERE kadi = ?', [cleanKadi]);
  if (existingUser) return res.status(400).send('Girdiğiniz kullanıcı adı zaten kayıtlıdır.');
  const existingMail = sqlGet('SELECT id FROM uyeler WHERE lower(email) = lower(?)', [cleanEmail]);
  if (existingMail) return res.status(400).send('Girdiğiniz e-mail adresi zaten kayıtlıdır.');

  const aktivasyon = createActivation();
  const now = new Date().toISOString();
  const result = sqlRun(
    `INSERT INTO uyeler (kadi, sifre, email, isim, soyisim, aktivasyon, aktiv, ilktarih, resim, mezuniyetyili, ilkbd)
     VALUES (?, ?, ?, ?, ?, ?, 0, ?, 'yok', ?, 0)`,
    [cleanKadi, sifre, cleanEmail, cleanIsim, cleanSoyisim, aktivasyon, now, mezuniyetyili]
  );
  const newId = result?.lastInsertRowid;

  const welcome = sqlGet('SELECT id FROM uyeler WHERE id = 1');
  if (welcome) {
    sqlRun(
      `INSERT INTO gelenkutusu (kime, kimden, aktifgelen, aktifgiden, yeni, konu, mesaj, tarih)
       VALUES (?, 1, 1, 1, 1, 'Hoşgeldiniz!', ?, ?)`,
      [String(newId), 'Sdal.org - Süleyman Demirel Anadolu Lisesi Mezunları Web Sitesine hoşgeldiniz!<br><br>Bu <b>mesaj paneli</b> sayesinde diğer üyeler ile haberleşebilirsiniz.<br><br>Hoşça vakit geçirmeniz dileğiyle...<br><b><i>sdal.org</b></i>', now]
    );
  }

  const publicBaseUrl = resolvePublicBaseUrl(req);
  const activationLink = `${publicBaseUrl}/aktivet?id=${newId}&akt=${aktivasyon}`;
  const html = buildActivationEmailHtml({
    siteBase: publicBaseUrl,
    activationLink,
    user: { kadi: cleanKadi, isim: cleanIsim, soyisim: cleanSoyisim }
  });

  await sendMail({ to: cleanEmail, subject: 'SDAL.ORG - Üyelik Başvurusu', html });

  res.json({ ok: true });
});

app.get('/api/activate', (req, res) => {
  const id = req.query.id;
  const akt = req.query.akt;
  if (!id || !akt) return res.status(400).send('Aktivasyon kodu eksik');
  const user = sqlGet('SELECT * FROM uyeler WHERE id = ?', [id]);
  if (!user) return res.status(404).send('Böyle bir kullanıcı kayıtlı değil');
  if (user.aktiv === 1) return res.status(400).send('Aktivasyon zaten tamamlanmış');
  if (user.aktivasyon !== akt) return res.status(400).send('Aktivasyon kodu yanlış');
  const newAkt = createActivation();
  sqlRun('UPDATE uyeler SET aktiv = 1, aktivasyon = ? WHERE id = ?', [newAkt, id]);
  res.json({ ok: true, kadi: user.kadi });
});

app.post('/api/activation/resend', async (req, res) => {
  const { id, email } = req.body || {};
  let user = null;
  if (id) user = sqlGet('SELECT * FROM uyeler WHERE id = ?', [id]);
  if (!user && email) user = sqlGet('SELECT * FROM uyeler WHERE email = ?', [email]);
  if (!user) return res.status(404).send('Böyle bir kullanıcı kayıtlı değil');
  const publicBaseUrl = resolvePublicBaseUrl(req);
  const activationLink = `${publicBaseUrl}/aktivet?id=${user.id}&akt=${user.aktivasyon}`;
  const html = buildActivationEmailHtml({
    siteBase: publicBaseUrl,
    activationLink,
    user
  });
  await sendMail({ to: user.email, subject: 'SDAL - Aktivasyon', html });
  res.json({ ok: true });
});

app.post('/api/password-reset', async (req, res) => {
  const { kadi, email } = req.body || {};
  let user = null;
  if (kadi) user = sqlGet('SELECT * FROM uyeler WHERE kadi = ?', [kadi]);
  if (!user && email) user = sqlGet('SELECT * FROM uyeler WHERE email = ?', [email]);
  if (!user) return res.status(404).send('Böyle bir kullanıcı kayıtlı değil');

  const publicBaseUrl = resolvePublicBaseUrl(req);
  const html = `<!doctype html><html><body style="font-family:Arial,sans-serif;background:#f4efe8;padding:24px;color:#1f2937;">
    <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width:600px;margin:0 auto;background:#fff;border:1px solid #e5e7eb;border-radius:12px;">
      <tr><td style="padding:20px 24px;">
        <h2 style="margin:0 0 12px;font-size:18px;">SDAL Hesap Bilgilendirmesi</h2>
        <p style="margin:0 0 12px;">Merhaba <b>${escapeHtml(user.isim)} ${escapeHtml(user.soyisim)}</b>,</p>
        <p style="margin:0 0 12px;">Güvenlik nedeniyle e-posta ile şifre paylaşmıyoruz.</p>
        <p style="margin:0 0 16px;">Kullanıcı adın: <b>@${escapeHtml(user.kadi)}</b></p>
        <a href="${escapeHtml(publicBaseUrl)}/new/password-reset" style="display:inline-block;padding:10px 14px;border-radius:999px;background:#ff6b4a;color:#111827;text-decoration:none;font-weight:700;">Şifremi Sıfırla</a>
      </td></tr>
    </table>
  </body></html>`;
  await sendMail({ to: user.email, subject: 'SDAL.ORG - ŞİFRE HATIRLAMA', html });
  res.json({ ok: true });
});

app.post('/api/mail/test', async (req, res) => {
  const fallback = process.env.SMTP_FROM || process.env.SMTP_USER || '';
  const candidates = extractEmails(req.body?.to || fallback);
  if (!candidates.length) return res.status(400).send('Test e-mail adresi eksik.');
  const invalid = candidates.find((value) => !validateEmail(value));
  if (invalid) return res.status(400).send('E-mail adresi doğru görünmüyor.');
  const to = candidates.join(', ');
  try {
    await sendMail({
      to,
      subject: 'SDAL SMTP Test',
      html: 'Bu bir SMTP test e-postasıdır.'
    });
    res.json({ ok: true, to });
  } catch (err) {
    console.error('SMTP test error:', err);
    res.status(500).send('SMTP test başarısız.');
  }
});

app.get('/api/profile', (req, res) => {
  if (!req.session.userId) return res.status(401).send('Login required');
  const user = sqlGet(`
    SELECT id, kadi, isim, soyisim, email, mezuniyetyili, sehir, meslek, websitesi, universite,
           dogumgun, dogumay, dogumyil, mailkapali, imza, resim, ilkbd
    FROM uyeler WHERE id = ?`, [req.session.userId]);
  res.json({ user });
});

app.put('/api/profile', (req, res) => {
  if (!req.session.userId) return res.status(401).send('Login required');
  const isim = String(req.body.isim || '').trim();
  const soyisim = String(req.body.soyisim || '').trim();
  if (!isim) return res.status(400).send('İsmini girmedin');
  if (isim.length > 20) return res.status(400).send('İsim 20 karakterden fazla olmamalıdır.');
  if (!soyisim) return res.status(400).send('Soyismini girmedin');
  if (soyisim.length > 20) return res.status(400).send('Soyisim 20 karakterden fazla olmamalıdır.');

  const sehir = String(req.body.sehir || '');
  const meslek = String(req.body.meslek || '');
  const websitesi = String(req.body.websitesi || '');
  const universite = String(req.body.universite || '');
  const dogumgun = parseInt(req.body.dogumgun || '0', 10) || 0;
  const dogumay = parseInt(req.body.dogumay || '0', 10) || 0;
  const dogumyil = parseInt(req.body.dogumyil || '0', 10) || 0;
  const mailkapali = String(req.body.mailkapali || '0') === '1' ? 1 : 0;
  const imza = String(req.body.imza || '');

  const current = sqlGet('SELECT ilkbd FROM uyeler WHERE id = ?', [req.session.userId]);
  const nextIlkbd = current && current.ilkbd === 0 ? 1 : (current?.ilkbd || 1);

  sqlRun(`
    UPDATE uyeler
    SET isim = ?, soyisim = ?, sehir = ?, meslek = ?, websitesi = ?, universite = ?,
        dogumgun = ?, dogumay = ?, dogumyil = ?, mailkapali = ?, imza = ?, ilkbd = ?
    WHERE id = ?`,
    [isim, soyisim, sehir, meslek, websitesi, universite, dogumgun, dogumay, dogumyil, mailkapali, imza, nextIlkbd, req.session.userId]
  );
  res.json({ ok: true });
});

app.post('/api/profile/password', (req, res) => {
  if (!req.session.userId) return res.status(401).send('Login required');
  const { eskisifre = '', yenisifre = '', yenisifretekrar = '' } = req.body || {};
  if (!eskisifre) return res.status(400).send('Şifreni değiştirebilmek için eski şifreni girmen gerekiyor');
  if (!yenisifre) return res.status(400).send('Şifreni değiştirebilmek için yeni şifreni girmen gerekiyor');
  if (!yenisifretekrar) return res.status(400).send('Şifreni değiştirebilmek için yeni şifreni tekrar girmen gerekiyor');
  if (String(yenisifre).length > 20) return res.status(400).send('Yeni şifre 20 karakterden fazla olmamalıdır.');

  const user = sqlGet('SELECT sifre FROM uyeler WHERE id = ?', [req.session.userId]);
  if (user?.sifre !== eskisifre) return res.status(400).send('Şifreni yanlış girdin');
  if (yenisifre !== yenisifretekrar) return res.status(400).send('Girdiğin şifreler birbirleriyle uyuşmuyor');

  sqlRun('UPDATE uyeler SET sifre = ? WHERE id = ?', [yenisifre, req.session.userId]);
  res.json({ ok: true });
});

app.post('/api/profile/photo', (req, res, next) => {
  if (!req.session.userId) return res.status(401).send('Login required');
  return next();
}, photoUpload.single('file'), (req, res) => {
  if (!req.file) return res.status(400).send('Fotoğraf seçilmedi');
  const filename = req.file.filename;
  sqlRun('UPDATE uyeler SET resim = ? WHERE id = ?', [filename, req.session.userId]);
  res.json({ ok: true, photo: filename });
});

app.get('/api/menu', (req, res) => {
  if (!req.session.userId) return res.json({ items: [] });
  const items = sqlAll('SELECT sayfaismi, sayfaurl FROM sayfalar WHERE menugorun = 1 ORDER BY sayfaismi');
  const mapped = items
    .filter((row) => !['sifrehatirla.asp', 'uyekayit.asp'].includes((row.sayfaurl || '').toLowerCase()))
    .map((row) => ({
      label: row.sayfaismi,
      url: mapLegacyUrl(row.sayfaurl),
      legacyUrl: row.sayfaurl
    }));
  res.json({ items: mapped });
});

app.get('/api/sidebar', (req, res) => {
  if (!req.session.userId) return res.json({ onlineUsers: [], newMembers: [], newPhotos: [], topSnake: [], topTetris: [], newMessagesCount: 0 });

  // Online users cleanup (5 minutes)
  const onlineUsers = [];
  const now = Date.now();
  const onlineRows = sqlAll('SELECT id, kadi, isim, soyisim, resim, mezuniyetyili, sonislemtarih, sonislemsaat FROM uyeler WHERE online = 1 ORDER BY kadi');
  onlineRows.forEach((row) => {
    const last = row.sonislemtarih && row.sonislemsaat ? new Date(`${row.sonislemtarih} ${row.sonislemsaat}`) : null;
    if (last && now - last.getTime() > 5 * 60 * 1000) {
      sqlRun('UPDATE uyeler SET online = 0 WHERE id = ?', [row.id]);
      return;
    }
    onlineUsers.push(row);
  });

  const newMembers = sqlAll('SELECT id, kadi, isim, soyisim, resim, mezuniyetyili FROM uyeler WHERE aktiv = 1 AND yasak = 0 ORDER BY id DESC LIMIT 5');

  const newPhotos = sqlAll(`\n    SELECT f.id, f.katid, f.dosyaadi, k.kategori\n    FROM album_foto f\n    LEFT JOIN album_kat k ON k.id = f.katid\n    WHERE f.aktif = 1\n    ORDER BY f.id DESC\n    LIMIT 10\n  `);

  const topSnake = sqlAll('SELECT isim, skor, tarih FROM oyun_yilan ORDER BY skor DESC LIMIT 5');
  const topTetris = sqlAll('SELECT isim, puan, tarih FROM oyun_tetris ORDER BY puan DESC LIMIT 5');

  const newMessagesCountRow = sqlGet('SELECT COUNT(*) AS cnt FROM gelenkutusu WHERE yeni = 1 AND kime = ? AND aktifgelen = 1', [req.session.userId]);
  const newMessagesCount = newMessagesCountRow ? newMessagesCountRow.cnt : 0;

  res.json({ onlineUsers, newMembers, newPhotos, topSnake, topTetris, newMessagesCount });
});

app.get('/api/members', (req, res) => {
  if (!req.session.userId) return res.status(401).send('Login required');
  const page = Math.max(parseInt(req.query.page || '1', 10), 1);
  const pageSize = Math.min(Math.max(parseInt(req.query.pageSize || '10', 10), 1), 50);
  const term = req.query.term ? String(req.query.term).replace(/'/g, '') : '';
  const where = term
    ? `COALESCE(CAST(aktiv AS INTEGER), 1) = 1
       AND COALESCE(CAST(yasak AS INTEGER), 0) = 0
       AND (LOWER(kadi) LIKE LOWER(?) OR LOWER(isim) LIKE LOWER(?) OR LOWER(soyisim) LIKE LOWER(?) OR LOWER(meslek) LIKE LOWER(?) OR LOWER(email) LIKE LOWER(?))`
    : `COALESCE(CAST(aktiv AS INTEGER), 1) = 1
       AND COALESCE(CAST(yasak AS INTEGER), 0) = 0`;
  const params = term ? Array(5).fill(`%${term}%`) : [];

  const totalRow = sqlGet(`SELECT COUNT(*) AS cnt FROM uyeler WHERE ${where}`, params);
  const total = totalRow ? totalRow.cnt : 0;
  const pages = Math.max(Math.ceil(total / pageSize), 1);
  const safePage = Math.min(page, pages);
  const offset = (safePage - 1) * pageSize;
  const rows = sqlAll(`
    SELECT id, kadi, isim, soyisim, email, mailkapali, mezuniyetyili, dogumgun, dogumay, dogumyil,
           sehir, universite, meslek, websitesi, imza, resim, online, sontarih, verified
    FROM uyeler
    WHERE ${where}
    ORDER BY isim
    LIMIT ? OFFSET ?
  `, [...params, pageSize, offset]);

  const rangeRows = term ? [] : sqlAll('SELECT isim FROM uyeler WHERE aktiv = 1 AND yasak = 0 ORDER BY isim');
  const ranges = [];
  for (let i = 0; i < rangeRows.length; i += pageSize) {
    const start = rangeRows[i]?.isim ? rangeRows[i].isim.slice(0, 2) : '--';
    const end = rangeRows[Math.min(i + pageSize - 1, rangeRows.length - 1)]?.isim?.slice(0, 2) || '--';
    ranges.push({ start, end });
  }

  res.json({ rows, page: safePage, pages, total, ranges, pageSize, term });
});

app.get('/api/members/:id', (req, res) => {
  if (!req.session.userId) return res.status(401).send('Login required');
  const row = sqlGet(`
    SELECT id, kadi, isim, soyisim, email, mailkapali, mezuniyetyili, dogumgun, dogumay, dogumyil,
           sehir, universite, meslek, websitesi, imza, resim, online, sontarih
    FROM uyeler
    WHERE id = ?
  `, [req.params.id]);
  if (!row) return res.status(404).send('Üye bulunamadı');
  res.json({ row });
});

app.get('/api/messages', (req, res) => {
  if (!req.session.userId) return res.status(401).send('Login required');
  const box = req.query.box === 'outbox' ? 'outbox' : 'inbox';
  const page = Math.max(parseInt(req.query.page || '1', 10), 1);
  const pageSize = Math.min(Math.max(parseInt(req.query.pageSize || '5', 10), 1), 50);
  const where = box === 'inbox' ? 'kime = ? AND aktifgelen = 1' : 'kimden = ? AND aktifgiden = 1';
  const totalRow = sqlGet(`SELECT COUNT(*) AS cnt FROM gelenkutusu WHERE ${where}`, [req.session.userId]);
  const total = totalRow ? totalRow.cnt : 0;
  const pages = Math.max(Math.ceil(total / pageSize), 1);
  const safePage = Math.min(page, pages);
  const offset = (safePage - 1) * pageSize;

  const rows = sqlAll(`
    SELECT g.*, u1.kadi AS kimden_kadi, u1.resim AS kimden_resim, u2.kadi AS kime_kadi, u2.resim AS kime_resim
    FROM gelenkutusu g
    LEFT JOIN uyeler u1 ON u1.id = g.kimden
    LEFT JOIN uyeler u2 ON u2.id = g.kime
    WHERE ${where}
    ORDER BY g.tarih DESC
    LIMIT ? OFFSET ?
  `, [req.session.userId, pageSize, offset]);

  res.json({ rows, page: safePage, pages, total, box, pageSize });
});

app.get('/api/messages/recipients', (req, res) => {
  if (!req.session.userId) return res.status(401).send('Login required');
  const q = String(req.query.q || '').trim().replace(/'/g, '');
  const limit = Math.min(Math.max(parseInt(req.query.limit || '12', 10), 1), 50);
  if (!q) return res.json({ items: [] });
  const term = `%${q}%`;
  const rows = sqlAll(
    `SELECT id, kadi, isim, soyisim, resim, verified
     FROM uyeler
     WHERE COALESCE(CAST(yasak AS INTEGER), 0) = 0
       AND COALESCE(CAST(aktiv AS INTEGER), 1) = 1
       AND (
         LOWER(kadi) LIKE LOWER(?)
         OR LOWER(isim) LIKE LOWER(?)
         OR LOWER(soyisim) LIKE LOWER(?)
         OR LOWER(email) LIKE LOWER(?)
       )
     ORDER BY kadi ASC
     LIMIT ?`,
    [term, term, term, term, limit]
  );
  res.json({ items: rows });
});

app.get('/api/messages/:id', (req, res) => {
  if (!req.session.userId) return res.status(401).send('Login required');
  const row = sqlGet('SELECT * FROM gelenkutusu WHERE id = ?', [req.params.id]);
  if (!row) return res.status(404).send('Mesaj bulunamadı');
  if (String(row.kime) !== String(req.session.userId) && String(row.kimden) !== String(req.session.userId)) {
    return res.status(403).send('Yetkisiz');
  }
  const sender = sqlGet('SELECT id, kadi, resim FROM uyeler WHERE id = ?', [row.kimden]);
  const receiver = sqlGet('SELECT id, kadi, resim FROM uyeler WHERE id = ?', [row.kime]);

  if (String(row.kime) === String(req.session.userId) && row.yeni === 1) {
    sqlRun('UPDATE gelenkutusu SET yeni = 0 WHERE id = ?', [row.id]);
  }

  res.json({ row, sender, receiver });
});

app.post('/api/messages', (req, res) => {
  if (!req.session.userId) return res.status(401).send('Login required');
  const { kime, konu, mesaj } = req.body || {};
  if (!kime) return res.status(400).send('Alıcı seçilmedi');
  const subject = (konu && String(konu).trim()) ? String(konu).slice(0, 50) : 'Konusuz';
  const body = (mesaj && String(mesaj).trim()) ? metinDuzenle(String(mesaj)) : 'Sistem Bilgisi : [b]Boş Mesaj Gönderildi![/b]';
  const now = new Date().toISOString();

  sqlRun(
    `INSERT INTO gelenkutusu (kime, kimden, aktifgelen, konu, mesaj, yeni, tarih, aktifgiden)
     VALUES (?, ?, 1, ?, ?, 1, ?, 1)`,
    [kime, req.session.userId, subject, body, now]
  );

  res.status(201).json({ ok: true });
});

app.delete('/api/messages/:id', (req, res) => {
  if (!req.session.userId) return res.status(401).send('Login required');
  const row = sqlGet('SELECT * FROM gelenkutusu WHERE id = ?', [req.params.id]);
  if (!row) return res.status(404).send('Mesaj bulunamadı');
  if (String(row.kime) !== String(req.session.userId) && String(row.kimden) !== String(req.session.userId)) {
    return res.status(403).send('Yetkisiz');
  }
  if (String(row.kime) === String(req.session.userId)) {
    sqlRun('UPDATE gelenkutusu SET aktifgelen = 0 WHERE id = ?', [row.id]);
  }
  if (String(row.kimden) === String(req.session.userId)) {
    sqlRun('UPDATE gelenkutusu SET aktifgiden = 0 WHERE id = ?', [row.id]);
  }
  res.status(204).send();
});

app.get('/api/albums', (req, res) => {
  if (!req.session.userId) return res.status(401).send('Login required');
  const categories = sqlAll('SELECT id, kategori, aciklama FROM album_kat WHERE aktif = 1 ORDER BY id');
  const items = categories.map((cat) => {
    const countRow = sqlGet('SELECT COUNT(*) AS cnt FROM album_foto WHERE aktif = 1 AND katid = ?', [cat.id]);
    const previews = sqlAll('SELECT dosyaadi FROM album_foto WHERE aktif = 1 AND katid = ? ORDER BY id DESC LIMIT 5', [cat.id]);
    return { ...cat, count: countRow?.cnt || 0, previews: previews.map((p) => p.dosyaadi) };
  });
  res.json({ items });
});

app.get('/api/album/categories/active', (req, res) => {
  if (!req.session.userId) return res.status(401).send('Login required');
  const categories = sqlAll('SELECT id, kategori FROM album_kat WHERE aktif = 1 ORDER BY kategori');
  res.json({ categories });
});

app.post('/api/album/upload', (req, res, next) => {
  if (!req.session.userId) return res.status(401).send('Login required');
  return albumUpload.single('file')(req, res, (err) => {
    if (err) return next(err);
    next();
  });
}, (req, res) => {
  const kat = String(req.body?.kat || '').trim();
  const baslik = String(req.body?.baslik || '').trim();
  const aciklama = String(req.body?.aciklama || '').trim();

  if (!baslik) return res.status(400).send('Yüklemek üzere olduğun fotoğraf için bir başlık girmen gerekiyor.');
  if (!kat) return res.status(400).send('Kategori seçmelisin.');
  const category = sqlGet('SELECT * FROM album_kat WHERE id = ? AND aktif = 1', [kat]);
  if (!category) return res.status(400).send('Seçtiğin kategori bulunamadı.');
  if (!req.file?.filename) return res.status(400).send('Geçerli bir resim dosyası girmedin.');

  sqlRun('UPDATE album_kat SET sonekleme = ?, sonekleyen = ? WHERE id = ?', [new Date().toISOString(), req.session.userId, category.id]);
  sqlRun(
    `INSERT INTO album_foto (dosyaadi, katid, baslik, aciklama, aktif, ekleyenid, tarih, hit)
     VALUES (?, ?, ?, ?, 0, ?, ?, 0)`,
    [req.file.filename, String(category.id), baslik, aciklama, req.session.userId, new Date().toISOString()]
  );

  res.json({ ok: true, file: req.file.filename, categoryId: category.id });
});

app.get('/api/albums/:id', (req, res) => {
  if (!req.session.userId) return res.status(401).send('Login required');
  const page = Math.max(parseInt(req.query.page || '1', 10), 1);
  const pageSize = Math.min(Math.max(parseInt(req.query.pageSize || '20', 10), 1), 50);
  const category = sqlGet('SELECT id, kategori, aciklama FROM album_kat WHERE id = ? AND aktif = 1', [req.params.id]);
  if (!category) return res.status(404).send('Kategori bulunamadı');
  const totalRow = sqlGet('SELECT COUNT(*) AS cnt FROM album_foto WHERE aktif = 1 AND katid = ?', [req.params.id]);
  const total = totalRow?.cnt || 0;
  const pages = Math.max(Math.ceil(total / pageSize), 1);
  const safePage = Math.min(page, pages);
  const offset = (safePage - 1) * pageSize;
  const photos = sqlAll('SELECT id, dosyaadi, baslik, tarih FROM album_foto WHERE aktif = 1 AND katid = ? ORDER BY tarih LIMIT ? OFFSET ?', [req.params.id, pageSize, offset]);
  res.json({ category, photos, page: safePage, pages, total, pageSize });
});

app.get('/api/photos/:id', (req, res) => {
  if (!req.session.userId) return res.status(401).send('Login required');
  const row = sqlGet('SELECT id, katid, dosyaadi, baslik, aciklama, tarih FROM album_foto WHERE id = ? AND aktif = 1', [req.params.id]);
  if (!row) return res.status(404).send('Fotoğraf bulunamadı');
  const category = sqlGet('SELECT id, kategori FROM album_kat WHERE id = ?', [row.katid]);
  const comments = sqlAll('SELECT id, uyeadi, yorum, tarih FROM album_fotoyorum WHERE fotoid = ? ORDER BY id DESC', [row.id]);
  res.json({ row, category, comments });
});

app.get('/api/photos/:id/comments', (req, res) => {
  if (!req.session.userId) return res.status(401).send('Login required');
  const comments = sqlAll('SELECT id, uyeadi, yorum, tarih FROM album_fotoyorum WHERE fotoid = ? ORDER BY id DESC', [req.params.id]);
  res.json({ comments });
});

app.post('/api/photos/:id/comments', (req, res) => {
  if (!req.session.userId) return res.status(401).send('Login required');
  const yorum = metinDuzenle(req.body?.yorum || '');
  if (!yorum) return res.status(400).send('Yorum girmedin');
  const user = getCurrentUser(req);
  sqlRun('INSERT INTO album_fotoyorum (fotoid, uyeadi, yorum, tarih) VALUES (?, ?, ?, ?)', [
    req.params.id,
    user?.kadi || 'Misafir',
    yorum,
    new Date().toISOString()
  ]);
  res.json({ ok: true });
});

// Modern (sdal_new) social APIs
app.get('/api/new/feed', requireAuth, (req, res) => {
  const limit = Math.min(Math.max(parseInt(req.query.limit || '20', 10), 1), 50);
  const offset = Math.max(parseInt(req.query.offset || '0', 10), 0);
  const rows = sqlAll(
    `SELECT p.id, p.user_id, p.content, p.image, p.created_at, p.group_id,
            u.kadi, u.isim, u.soyisim, u.resim, u.verified
     FROM posts p
     LEFT JOIN uyeler u ON u.id = p.user_id
     ORDER BY p.id DESC
     LIMIT ? OFFSET ?`,
    [limit, offset]
  );
  const postIds = rows.map((r) => r.id);
  const likes = postIds.length
    ? sqlAll(`SELECT post_id, COUNT(*) as cnt FROM post_likes WHERE post_id IN (${postIds.map(() => '?').join(',')}) GROUP BY post_id`, postIds)
    : [];
  const comments = postIds.length
    ? sqlAll(`SELECT post_id, COUNT(*) as cnt FROM post_comments WHERE post_id IN (${postIds.map(() => '?').join(',')}) GROUP BY post_id`, postIds)
    : [];
  const liked = postIds.length
    ? sqlAll(`SELECT post_id FROM post_likes WHERE user_id = ? AND post_id IN (${postIds.map(() => '?').join(',')})`, [req.session.userId, ...postIds])
    : [];
  const likeMap = new Map(likes.map((l) => [l.post_id, l.cnt]));
  const commentMap = new Map(comments.map((c) => [c.post_id, c.cnt]));
  const likedSet = new Set(liked.map((l) => l.post_id));

  res.json({
    items: rows.map((r) => ({
      id: r.id,
      content: r.content,
      image: r.image,
      createdAt: r.created_at,
      author: {
        id: r.user_id,
        kadi: r.kadi,
        isim: r.isim,
        soyisim: r.soyisim,
        resim: r.resim,
        verified: r.verified
      },
      groupId: r.group_id,
      likeCount: likeMap.get(r.id) || 0,
      commentCount: commentMap.get(r.id) || 0,
      liked: likedSet.has(r.id)
    }))
  });
});

app.post('/api/new/posts', requireAuth, (req, res) => {
  const content = metinDuzenle(req.body?.content || '');
  const image = req.body?.image || null;
  const groupId = req.body?.group_id || null;
  if (!content && !image) return res.status(400).send('İçerik boş olamaz.');
  const now = new Date().toISOString();
  const result = sqlRun('INSERT INTO posts (user_id, content, image, created_at, group_id) VALUES (?, ?, ?, ?, ?)', [
    req.session.userId,
    content,
    image,
    now,
    groupId
  ]);
  res.json({ ok: true, id: result?.lastInsertRowid });
});

app.post('/api/new/posts/upload', requireAuth, postUpload.single('image'), (req, res) => {
  const content = metinDuzenle(req.body?.content || '');
  const filter = req.body?.filter || '';
  const groupId = req.body?.group_id || null;
  const image = req.file ? `/uploads/posts/${req.file.filename}` : null;
  if (!content && !image) return res.status(400).send('İçerik boş olamaz.');
  if (req.file && filter) {
    try {
      applyImageFilter(req.file.path, filter);
    } catch {
      // ignore filter errors
    }
  }
  const now = new Date().toISOString();
  const result = sqlRun('INSERT INTO posts (user_id, content, image, created_at, group_id) VALUES (?, ?, ?, ?, ?)', [
    req.session.userId,
    content,
    image,
    now,
    groupId
  ]);
  res.json({ ok: true, id: result?.lastInsertRowid, image });
});

app.post('/api/new/posts/:id/like', requireAuth, (req, res) => {
  const postId = req.params.id;
  const existing = sqlGet('SELECT id FROM post_likes WHERE post_id = ? AND user_id = ?', [postId, req.session.userId]);
  if (existing) {
    sqlRun('DELETE FROM post_likes WHERE id = ?', [existing.id]);
    return res.json({ ok: true, liked: false });
  }
  sqlRun('INSERT INTO post_likes (post_id, user_id, created_at) VALUES (?, ?, ?)', [postId, req.session.userId, new Date().toISOString()]);
  const post = sqlGet('SELECT user_id FROM posts WHERE id = ?', [postId]);
  if (post && post.user_id !== req.session.userId) {
    addNotification({
      userId: post.user_id,
      type: 'like',
      sourceUserId: req.session.userId,
      entityId: postId,
      message: 'Gönderini beğendi.'
    });
  }
  return res.json({ ok: true, liked: true });
});

app.get('/api/new/posts/:id/comments', requireAuth, (req, res) => {
  const rows = sqlAll(
    `SELECT c.id, c.comment, c.created_at, u.id AS user_id, u.kadi, u.isim, u.soyisim, u.resim
     FROM post_comments c
     LEFT JOIN uyeler u ON u.id = c.user_id
     WHERE c.post_id = ?
     ORDER BY c.id DESC`,
    [req.params.id]
  );
  res.json({ items: rows });
});

app.post('/api/new/posts/:id/comments', requireAuth, (req, res) => {
  const comment = metinDuzenle(req.body?.comment || '');
  if (!comment) return res.status(400).send('Yorum boş olamaz.');
  const now = new Date().toISOString();
  sqlRun('INSERT INTO post_comments (post_id, user_id, comment, created_at) VALUES (?, ?, ?, ?)', [
    req.params.id,
    req.session.userId,
    comment,
    now
  ]);
  const post = sqlGet('SELECT user_id FROM posts WHERE id = ?', [req.params.id]);
  if (post && post.user_id !== req.session.userId) {
    addNotification({
      userId: post.user_id,
      type: 'comment',
      sourceUserId: req.session.userId,
      entityId: req.params.id,
      message: 'Gönderine yorum yaptı.'
    });
  }
  res.json({ ok: true });
});

app.get('/api/new/notifications', requireAuth, (req, res) => {
  const rows = sqlAll(
    `SELECT n.id, n.type, n.entity_id, n.source_user_id, n.message, n.read_at, n.created_at,
            u.kadi, u.isim, u.soyisim, u.resim, u.verified
     FROM notifications n
     LEFT JOIN uyeler u ON u.id = n.source_user_id
     WHERE n.user_id = ?
     ORDER BY n.id DESC
     LIMIT 50`,
    [req.session.userId]
  );
  res.json({ items: rows });
});

app.post('/api/new/notifications/read', requireAuth, (req, res) => {
  sqlRun('UPDATE notifications SET read_at = ? WHERE user_id = ? AND read_at IS NULL', [
    new Date().toISOString(),
    req.session.userId
  ]);
  res.json({ ok: true });
});

app.get('/api/new/stories', requireAuth, (req, res) => {
  const now = new Date().toISOString();
  const rows = sqlAll(
    `SELECT s.id, s.user_id, s.image, s.caption, s.created_at, s.expires_at,
            u.kadi, u.isim, u.soyisim, u.resim, u.verified
     FROM stories s
     LEFT JOIN uyeler u ON u.id = s.user_id
     WHERE s.expires_at > ?
     ORDER BY s.created_at DESC`,
    [now]
  );
  const viewed = sqlAll('SELECT story_id FROM story_views WHERE user_id = ?', [req.session.userId]);
  const viewedSet = new Set(viewed.map((v) => v.story_id));
  res.json({
    items: rows.map((r) => ({
      id: r.id,
      image: r.image,
      caption: r.caption,
      createdAt: r.created_at,
      author: {
        id: r.user_id,
        kadi: r.kadi,
        isim: r.isim,
        soyisim: r.soyisim,
        resim: r.resim,
        verified: r.verified
      },
      viewed: viewedSet.has(r.id)
    }))
  });
});

app.post('/api/new/stories/upload', requireAuth, storyUpload.single('image'), (req, res) => {
  if (!req.file) return res.status(400).send('Görsel seçilmedi.');
  const caption = metinDuzenle(req.body?.caption || '');
  const image = `/uploads/stories/${req.file.filename}`;
  const now = new Date();
  const expires = new Date(now.getTime() + 24 * 60 * 60 * 1000);
  const result = sqlRun('INSERT INTO stories (user_id, image, caption, created_at, expires_at) VALUES (?, ?, ?, ?, ?)', [
    req.session.userId,
    image,
    caption,
    now.toISOString(),
    expires.toISOString()
  ]);
  res.json({ ok: true, id: result?.lastInsertRowid, image });
});

app.post('/api/new/stories/:id/view', requireAuth, (req, res) => {
  const existing = sqlGet('SELECT id FROM story_views WHERE story_id = ? AND user_id = ?', [req.params.id, req.session.userId]);
  if (!existing) {
    sqlRun('INSERT INTO story_views (story_id, user_id, created_at) VALUES (?, ?, ?)', [
      req.params.id,
      req.session.userId,
      new Date().toISOString()
    ]);
  }
  res.json({ ok: true });
});

app.post('/api/new/follow/:id', requireAuth, (req, res) => {
  const targetId = req.params.id;
  if (String(targetId) === String(req.session.userId)) return res.status(400).send('Kendini takip edemezsin.');
  const existing = sqlGet('SELECT id FROM follows WHERE follower_id = ? AND following_id = ?', [req.session.userId, targetId]);
  if (existing) {
    sqlRun('DELETE FROM follows WHERE id = ?', [existing.id]);
    return res.json({ ok: true, following: false });
  }
  sqlRun('INSERT INTO follows (follower_id, following_id, created_at) VALUES (?, ?, ?)', [
    req.session.userId,
    targetId,
    new Date().toISOString()
  ]);
  addNotification({
    userId: Number(targetId),
    type: 'follow',
    sourceUserId: req.session.userId,
    entityId: targetId,
    message: 'Seni takip etmeye başladı.'
  });
  return res.json({ ok: true, following: true });
});

app.get('/api/new/follows', requireAuth, (req, res) => {
  const rows = sqlAll(
    `SELECT f.following_id, u.kadi, u.isim, u.soyisim, u.resim
     FROM follows f
     LEFT JOIN uyeler u ON u.id = f.following_id
     WHERE f.follower_id = ?
     ORDER BY f.id DESC`,
    [req.session.userId]
  );
  res.json({ items: rows });
});

app.get('/api/new/messages/unread', requireAuth, (req, res) => {
  const row = sqlGet(
    'SELECT COUNT(*) AS cnt FROM gelenkutusu WHERE kime = ? AND aktifgelen = 1 AND yeni = 1',
    [req.session.userId]
  );
  res.json({ count: row?.cnt || 0 });
});

app.get('/api/new/groups', requireAuth, (req, res) => {
  const groups = sqlAll('SELECT * FROM groups ORDER BY id DESC');
  const memberCounts = sqlAll('SELECT group_id, COUNT(*) AS cnt FROM group_members GROUP BY group_id');
  const membership = sqlAll('SELECT group_id FROM group_members WHERE user_id = ?', [req.session.userId]);
  const countMap = new Map(memberCounts.map((c) => [c.group_id, c.cnt]));
  const memberSet = new Set(membership.map((m) => m.group_id));
  res.json({
    items: groups.map((g) => ({
      ...g,
      members: countMap.get(g.id) || 0,
      joined: memberSet.has(g.id)
    }))
  });
});

app.post('/api/new/groups', requireAuth, (req, res) => {
  const name = String(req.body?.name || '').trim();
  if (!name) return res.status(400).send('Grup adı gerekli.');
  const description = String(req.body?.description || '');
  const now = new Date().toISOString();
  const result = sqlRun('INSERT INTO groups (name, description, cover_image, owner_id, created_at) VALUES (?, ?, ?, ?, ?)', [
    name,
    description,
    req.body?.cover_image || null,
    req.session.userId,
    now
  ]);
  const groupId = result?.lastInsertRowid;
  sqlRun('INSERT INTO group_members (group_id, user_id, role, created_at) VALUES (?, ?, ?, ?)', [
    groupId,
    req.session.userId,
    'owner',
    now
  ]);
  res.json({ ok: true, id: groupId });
});

app.post('/api/new/groups/:id/join', requireAuth, (req, res) => {
  const groupId = req.params.id;
  const existing = sqlGet('SELECT id FROM group_members WHERE group_id = ? AND user_id = ?', [groupId, req.session.userId]);
  if (existing) {
    sqlRun('DELETE FROM group_members WHERE id = ?', [existing.id]);
    return res.json({ ok: true, joined: false });
  }
  sqlRun('INSERT INTO group_members (group_id, user_id, role, created_at) VALUES (?, ?, ?, ?)', [
    groupId,
    req.session.userId,
    'member',
    new Date().toISOString()
  ]);
  return res.json({ ok: true, joined: true });
});

app.post('/api/new/groups/:id/cover', requireAuth, groupUpload.single('image'), (req, res) => {
  if (!req.file) return res.status(400).send('Görsel seçilmedi.');
  const group = sqlGet('SELECT * FROM groups WHERE id = ?', [req.params.id]);
  if (!group) return res.status(404).send('Grup bulunamadı.');
  const member = sqlGet('SELECT role FROM group_members WHERE group_id = ? AND user_id = ?', [req.params.id, req.session.userId]);
  if (!member || (member.role !== 'owner' && member.role !== 'moderator' && !getCurrentUser(req)?.admin)) {
    return res.status(403).send('Yetki yok.');
  }
  const image = `/uploads/groups/${req.file.filename}`;
  sqlRun('UPDATE groups SET cover_image = ? WHERE id = ?', [image, req.params.id]);
  res.json({ ok: true, image });
});

app.post('/api/new/groups/:id/role', requireAuth, (req, res) => {
  const group = sqlGet('SELECT * FROM groups WHERE id = ?', [req.params.id]);
  if (!group) return res.status(404).send('Grup bulunamadı.');
  const member = sqlGet('SELECT role FROM group_members WHERE group_id = ? AND user_id = ?', [req.params.id, req.session.userId]);
  const isAdmin = getCurrentUser(req)?.admin === 1;
  if (!isAdmin && (!member || member.role !== 'owner')) {
    return res.status(403).send('Yetki yok.');
  }
  const targetId = req.body?.userId;
  const role = req.body?.role;
  if (!targetId || !['member', 'moderator', 'owner'].includes(role)) {
    return res.status(400).send('Geçersiz rol.');
  }
  sqlRun('UPDATE group_members SET role = ? WHERE group_id = ? AND user_id = ?', [role, req.params.id, targetId]);
  res.json({ ok: true });
});

app.get('/api/new/groups/:id', requireAuth, (req, res) => {
  const group = sqlGet('SELECT * FROM groups WHERE id = ?', [req.params.id]);
  if (!group) return res.status(404).send('Grup bulunamadı.');
  const members = sqlAll(
    `SELECT u.id, u.kadi, u.isim, u.soyisim, u.resim, u.verified, m.role
     FROM group_members m
     LEFT JOIN uyeler u ON u.id = m.user_id
     WHERE m.group_id = ?`,
    [req.params.id]
  );
  const posts = sqlAll(
    `SELECT p.id, p.content, p.image, p.created_at,
            u.id as user_id, u.kadi, u.isim, u.soyisim, u.resim, u.verified
     FROM posts p
     LEFT JOIN uyeler u ON u.id = p.user_id
     WHERE p.group_id = ?
     ORDER BY p.id DESC`,
    [req.params.id]
  );
  res.json({ group, members, posts });
});

app.post('/api/new/groups/:id/posts', requireAuth, (req, res) => {
  const content = metinDuzenle(req.body?.content || '');
  if (!content) return res.status(400).send('İçerik boş olamaz.');
  const now = new Date().toISOString();
  sqlRun('INSERT INTO posts (user_id, content, image, created_at, group_id) VALUES (?, ?, ?, ?, ?)', [
    req.session.userId,
    content,
    null,
    now,
    req.params.id
  ]);
  res.json({ ok: true });
});

app.post('/api/new/groups/:id/posts/upload', requireAuth, postUpload.single('image'), (req, res) => {
  const content = metinDuzenle(req.body?.content || '');
  const filter = req.body?.filter || '';
  const image = req.file ? `/uploads/posts/${req.file.filename}` : null;
  if (!content && !image) return res.status(400).send('İçerik boş olamaz.');
  if (req.file && filter) {
    try { applyImageFilter(req.file.path, filter); } catch {}
  }
  const now = new Date().toISOString();
  sqlRun('INSERT INTO posts (user_id, content, image, created_at, group_id) VALUES (?, ?, ?, ?, ?)', [
    req.session.userId,
    content,
    image,
    now,
    req.params.id
  ]);
  res.json({ ok: true });
});

app.get('/api/new/events', requireAuth, (req, res) => {
  const rows = sqlAll('SELECT * FROM events ORDER BY starts_at ASC');
  res.json({ items: rows });
});

app.post('/api/new/events', requireAdmin, (req, res) => {
  const { title, description, location, starts_at, ends_at } = req.body || {};
  if (!title) return res.status(400).send('Başlık gerekli.');
  sqlRun(
    'INSERT INTO events (title, description, location, starts_at, ends_at, created_at) VALUES (?, ?, ?, ?, ?, ?)',
    [title, description || '', location || '', starts_at || '', ends_at || '', new Date().toISOString()]
  );
  res.json({ ok: true });
});

app.delete('/api/new/events/:id', requireAdmin, (req, res) => {
  sqlRun('DELETE FROM events WHERE id = ?', [req.params.id]);
  res.json({ ok: true });
});

app.get('/api/new/announcements', requireAuth, (req, res) => {
  const rows = sqlAll('SELECT * FROM announcements ORDER BY id DESC');
  res.json({ items: rows });
});

app.post('/api/new/announcements', requireAdmin, (req, res) => {
  const { title, body } = req.body || {};
  if (!title || !body) return res.status(400).send('Başlık ve içerik gerekli.');
  sqlRun('INSERT INTO announcements (title, body, created_at) VALUES (?, ?, ?)', [title, body, new Date().toISOString()]);
  res.json({ ok: true });
});

app.delete('/api/new/announcements/:id', requireAdmin, (req, res) => {
  sqlRun('DELETE FROM announcements WHERE id = ?', [req.params.id]);
  res.json({ ok: true });
});

app.get('/api/new/chat/messages', requireAuth, (req, res) => {
  const sinceId = parseInt(req.query.sinceId || '0', 10) || 0;
  const rows = sqlAll(
    `SELECT c.id, c.message, c.created_at, u.kadi, u.isim, u.soyisim, u.resim, u.verified
     FROM chat_messages c
     LEFT JOIN uyeler u ON u.id = c.user_id
     WHERE c.id > ?
     ORDER BY c.id DESC
     LIMIT 50`,
    [sinceId]
  );
  res.json({ items: rows.reverse() });
});

app.post('/api/new/chat/send', requireAuth, (req, res) => {
  const message = metinDuzenle(req.body?.message || '');
  if (!message) return res.status(400).send('Mesaj boş olamaz.');
  const now = new Date().toISOString();
  const result = sqlRun('INSERT INTO chat_messages (user_id, message, created_at) VALUES (?, ?, ?)', [
    req.session.userId,
    message,
    now
  ]);
  res.json({ ok: true, id: result?.lastInsertRowid });
});

app.post('/api/new/verified/request', requireAuth, (req, res) => {
  const existing = sqlGet('SELECT * FROM verification_requests WHERE user_id = ? AND status = ?', [req.session.userId, 'pending']);
  if (existing) return res.status(400).send('Zaten bekleyen bir talebiniz var.');
  sqlRun('INSERT INTO verification_requests (user_id, status, created_at) VALUES (?, ?, ?)', [
    req.session.userId,
    'pending',
    new Date().toISOString()
  ]);
  res.json({ ok: true });
});

app.get('/api/new/admin/verification-requests', requireAdmin, (req, res) => {
  const rows = sqlAll(
    `SELECT r.id, r.user_id, r.status, r.created_at, u.kadi, u.isim, u.soyisim, u.resim
     FROM verification_requests r
     LEFT JOIN uyeler u ON u.id = r.user_id
     ORDER BY r.id DESC`
  );
  res.json({ items: rows });
});

app.post('/api/new/admin/verification-requests/:id', requireAdmin, (req, res) => {
  const status = req.body?.status;
  if (!['approved', 'rejected'].includes(status)) return res.status(400).send('Geçersiz durum.');
  const row = sqlGet('SELECT * FROM verification_requests WHERE id = ?', [req.params.id]);
  if (!row) return res.status(404).send('Talep bulunamadı.');
  sqlRun('UPDATE verification_requests SET status = ?, reviewed_at = ?, reviewer_id = ? WHERE id = ?', [
    status,
    new Date().toISOString(),
    req.session.userId,
    req.params.id
  ]);
  if (status === 'approved') {
    sqlRun('UPDATE uyeler SET verified = 1 WHERE id = ?', [row.user_id]);
  }
  res.json({ ok: true });
});

app.post('/api/new/admin/verify', requireAdmin, (req, res) => {
  const userId = req.body?.userId;
  const value = String(req.body?.verified || '0') === '1' ? 1 : 0;
  if (!userId) return res.status(400).send('User ID gerekli.');
  sqlRun('UPDATE uyeler SET verified = ? WHERE id = ?', [value, userId]);
  res.json({ ok: true });
});

app.get('/api/new/admin/stats', requireAdmin, (req, res) => {
  const counts = {
    users: sqlGet('SELECT COUNT(*) AS cnt FROM uyeler')?.cnt || 0,
    activeUsers: sqlGet('SELECT COUNT(*) AS cnt FROM uyeler WHERE aktiv = 1 AND yasak = 0')?.cnt || 0,
    pendingUsers: sqlGet('SELECT COUNT(*) AS cnt FROM uyeler WHERE aktiv = 0 AND yasak = 0')?.cnt || 0,
    bannedUsers: sqlGet('SELECT COUNT(*) AS cnt FROM uyeler WHERE yasak = 1')?.cnt || 0,
    posts: sqlGet('SELECT COUNT(*) AS cnt FROM posts')?.cnt || 0,
    photos: sqlGet('SELECT COUNT(*) AS cnt FROM album_foto')?.cnt || 0,
    stories: sqlGet('SELECT COUNT(*) AS cnt FROM stories')?.cnt || 0,
    groups: sqlGet('SELECT COUNT(*) AS cnt FROM groups')?.cnt || 0,
    messages: sqlGet('SELECT COUNT(*) AS cnt FROM gelenkutusu')?.cnt || 0,
    events: sqlGet('SELECT COUNT(*) AS cnt FROM events')?.cnt || 0,
    announcements: sqlGet('SELECT COUNT(*) AS cnt FROM announcements')?.cnt || 0,
    chat: sqlGet('SELECT COUNT(*) AS cnt FROM chat_messages')?.cnt || 0
  };
  const recentUsers = sqlAll('SELECT id, kadi, isim, soyisim, ilktarih FROM uyeler ORDER BY id DESC LIMIT 5');
  const recentPosts = sqlAll('SELECT id, content, created_at FROM posts ORDER BY id DESC LIMIT 5');
  const recentPhotos = sqlAll('SELECT id, dosyaadi, tarih FROM album_foto ORDER BY id DESC LIMIT 5');
  res.json({ counts, recentUsers, recentPosts, recentPhotos });
});

app.get('/api/new/admin/groups', requireAdmin, (req, res) => {
  const rows = sqlAll('SELECT id, name, description, cover_image, owner_id, created_at FROM groups ORDER BY id DESC');
  res.json({ items: rows });
});

app.delete('/api/new/admin/groups/:id', requireAdmin, (req, res) => {
  sqlRun('DELETE FROM group_members WHERE group_id = ?', [req.params.id]);
  sqlRun('DELETE FROM posts WHERE group_id = ?', [req.params.id]);
  sqlRun('DELETE FROM groups WHERE id = ?', [req.params.id]);
  res.json({ ok: true });
});

app.get('/api/new/admin/stories', requireAdmin, (req, res) => {
  const rows = sqlAll(
    `SELECT s.id, s.image, s.caption, s.created_at, s.expires_at, u.kadi
     FROM stories s LEFT JOIN uyeler u ON u.id = s.user_id
     ORDER BY s.id DESC`
  );
  res.json({ items: rows });
});

app.delete('/api/new/admin/stories/:id', requireAdmin, (req, res) => {
  sqlRun('DELETE FROM story_views WHERE story_id = ?', [req.params.id]);
  sqlRun('DELETE FROM stories WHERE id = ?', [req.params.id]);
  res.json({ ok: true });
});

app.get('/api/new/admin/chat/messages', requireAdmin, (req, res) => {
  const rows = sqlAll(
    `SELECT c.id, c.message, c.created_at, u.kadi
     FROM chat_messages c LEFT JOIN uyeler u ON u.id = c.user_id
     ORDER BY c.id DESC LIMIT 200`
  );
  res.json({ items: rows });
});

app.delete('/api/new/admin/chat/messages/:id', requireAdmin, (req, res) => {
  sqlRun('DELETE FROM chat_messages WHERE id = ?', [req.params.id]);
  res.json({ ok: true });
});

app.get('/api/new/admin/messages', requireAdmin, (req, res) => {
  const rows = sqlAll(
    `SELECT g.id, g.konu, g.tarih, u1.kadi AS kimden_kadi, u2.kadi AS kime_kadi
     FROM gelenkutusu g
     LEFT JOIN uyeler u1 ON u1.id = g.kimden
     LEFT JOIN uyeler u2 ON u2.id = g.kime
     ORDER BY g.id DESC
     LIMIT 200`
  );
  res.json({ items: rows });
});

app.delete('/api/new/admin/messages/:id', requireAdmin, (req, res) => {
  sqlRun('DELETE FROM gelenkutusu WHERE id = ?', [req.params.id]);
  res.json({ ok: true });
});

app.get('/api/new/admin/db/tables', requireAdmin, (_req, res) => {
  const rows = sqlAll(
    `SELECT name
     FROM sqlite_master
     WHERE type = 'table' AND name NOT LIKE 'sqlite_%'
     ORDER BY name ASC`
  );
  const tables = rows.map((r) => {
    const safeName = String(r.name || '');
    const escaped = safeName.replace(/"/g, '""');
    const count = sqlGet(`SELECT COUNT(*) AS cnt FROM "${escaped}"`)?.cnt || 0;
    return { name: safeName, rowCount: count };
  });
  res.json({ items: tables });
});

app.get('/api/new/admin/db/table/:name', requireAdmin, (req, res) => {
  const tableName = String(req.params.name || '');
  const limit = Math.min(Math.max(parseInt(req.query.limit || '50', 10), 1), 200);
  const page = Math.max(parseInt(req.query.page || '1', 10), 1);
  const available = sqlAll(
    `SELECT name
     FROM sqlite_master
     WHERE type = 'table' AND name NOT LIKE 'sqlite_%'`
  ).map((r) => String(r.name || ''));
  if (!available.includes(tableName)) {
    return res.status(404).send('Tablo bulunamadı.');
  }
  const escaped = tableName.replace(/"/g, '""');
  const total = sqlGet(`SELECT COUNT(*) AS cnt FROM "${escaped}"`)?.cnt || 0;
  const pages = Math.max(Math.ceil(total / limit), 1);
  const safePage = Math.min(page, pages);
  const offset = (safePage - 1) * limit;
  const columns = sqlAll(`PRAGMA table_info("${escaped}")`).map((c) => ({
    name: c.name,
    type: c.type,
    notnull: c.notnull,
    pk: c.pk
  }));
  const rows = sqlAll(`SELECT * FROM "${escaped}" LIMIT ? OFFSET ?`, [limit, offset]);
  res.json({
    table: tableName,
    columns,
    rows,
    total,
    page: safePage,
    pages,
    limit
  });
});

app.get('/api/album/latest', (req, res) => {
  if (!req.session.userId) return res.status(401).send('Login required');
  const limit = Math.min(Math.max(parseInt(req.query.limit || '100', 10), 1), 200);
  const rows = sqlAll(
    `SELECT f.id, f.katid, f.dosyaadi, f.tarih, f.hit, k.kategori
     FROM album_foto f
     LEFT JOIN album_kat k ON k.id = f.katid
     WHERE f.aktif = 1
     ORDER BY f.id DESC
     LIMIT ?`,
    [limit]
  );
  res.json({ items: rows });
});

app.get('/api/members/latest', (req, res) => {
  if (!req.session.userId) return res.status(401).send('Login required');
  const limit = Math.min(Math.max(parseInt(req.query.limit || '100', 10), 1), 200);
  const rows = sqlAll(
    `SELECT id, kadi, isim, soyisim, resim, mezuniyetyili, ilktarih
     FROM uyeler
     WHERE aktiv = 1 AND yasak = 0
     ORDER BY id DESC
     LIMIT ?`,
    [limit]
  );
  res.json({ items: rows });
});

app.post('/api/tournament/register', (req, res) => {
  if (!req.session.userId) return res.status(401).send('Login required');
  const {
    tisim,
    tktelefon,
    boyismi,
    boymezuniyet,
    ioyismi,
    ioymezuniyet,
    uoyismi,
    uoymezuniyet,
    doyismi,
    doymezuniyet
  } = req.body || {};

  if (!tisim) return res.status(400).send('Takım ismini girmen gerekiyor.');
  if (!tktelefon) return res.status(400).send('Takım kaptanının telefonunu yazman gerekiyor.');
  if (!boyismi || !ioyismi || !uoyismi || !doyismi) return res.status(400).send('Oyuncu isimlerini girmen gerekiyor.');
  if (!boymezuniyet || !ioymezuniyet || !uoymezuniyet || !doymezuniyet) return res.status(400).send('Oyuncu mezuniyetlerini girmen gerekiyor.');

  const cleanTeam = String(tisim).trim().replace(/\s+/g, '-').replace(/'/g, '');
  const cleanPhone = String(tktelefon).trim().replace(/\s+/g, '-').replace(/'/g, '');
  const now = new Date().toISOString();

  sqlRun(
    `INSERT INTO takimlar (tisim, tkid, tktelefon, boyismi, boymezuniyet, ioyismi, ioymezuniyet, uoyismi, uoymezuniyet, doyismi, doymezuniyet, tarih)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
    [
      cleanTeam,
      req.session.userId,
      cleanPhone,
      String(boyismi).trim().replace(/'/g, ''),
      String(boymezuniyet),
      String(ioyismi).trim().replace(/'/g, ''),
      String(ioymezuniyet),
      String(uoyismi).trim().replace(/'/g, ''),
      String(uoymezuniyet),
      String(doyismi).trim().replace(/'/g, ''),
      String(doymezuniyet),
      now
    ]
  );

  res.json({ ok: true });
});

app.get('/api/panolar', (req, res) => {
  if (!req.session.userId) return res.status(401).send('Login required');
  const mkatidRaw = String(req.query.mkatid || '0');
  const mkatid = /^\d+$/.test(mkatidRaw) ? Number(mkatidRaw) : 0;
  let categoryName = 'Genel';
  if (mkatid !== 0) {
    const cat = sqlGet('SELECT * FROM mesaj_kategori WHERE id = ?', [mkatid]);
    if (!cat) {
      return res.status(400).send('Kategori bulunamadı.');
    }
    categoryName = cat.kategoriadi;
  }

  const user = sqlGet('SELECT id, mezuniyetyili, oncekisontarih, admin FROM uyeler WHERE id = ?', [req.session.userId]);
  const gradName = user?.mezuniyetyili ? `${user.mezuniyetyili} Mezunları` : null;
  const gradCategory = gradName ? sqlGet('SELECT * FROM mesaj_kategori WHERE kategoriadi = ?', [gradName]) : null;

  const page = Math.max(parseInt(req.query.page || '1', 10), 1);
  const pageSize = 25;
  const totalRow = sqlGet('SELECT COUNT(*) AS cnt FROM mesaj WHERE kategori = ?', [mkatid]);
  const total = totalRow?.cnt || 0;
  const pages = Math.max(Math.ceil(total / pageSize), 1);
  const safePage = Math.min(page, pages);
  const offset = (safePage - 1) * pageSize;
  const rows = sqlAll('SELECT * FROM mesaj WHERE kategori = ? ORDER BY tarih DESC LIMIT ? OFFSET ?', [mkatid, pageSize, offset]);

  const messages = rows.map((row) => {
    const u = sqlGet('SELECT id, kadi, resim FROM uyeler WHERE id = ?', [row.gonderenid]) || { id: row.gonderenid, kadi: 'Üye', resim: 'nophoto.jpg' };
    const msgDate = row.tarih ? new Date(row.tarih) : null;
    const lastDate = user?.oncekisontarih ? new Date(user.oncekisontarih) : null;
    const diffSeconds = msgDate && lastDate ? Math.floor((msgDate.getTime() - lastDate.getTime()) / 1000) : null;
    const isNew = diffSeconds != null && diffSeconds > 0;
    return {
      id: row.id,
      mesajHtml: row.mesaj || '',
      tarih: row.tarih,
      user: u,
      diffSeconds,
      isNew
    };
  });

  const pageList = [];
  let start = safePage - 5;
  if (start < 1) start = 1;
  let end = safePage + 5;
  if (end > pages) end = pages;
  for (let i = start; i <= end; i += 1) pageList.push(i);

  res.json({
    categoryId: mkatid,
    categoryName,
    gradCategory,
    messages,
    total,
    page: safePage,
    pages,
    pageSize,
    pageList,
    canDelete: !!req.session.adminOk && user?.admin === 1
  });
});

app.post('/api/panolar', (req, res) => {
  if (!req.session.userId) return res.status(401).send('Login required');
  const mesaj = String(req.body?.mesaj || '').trim();
  let katid = String(req.body?.katid || '0');
  if (!/^\d+$/.test(katid)) katid = '0';
  if (katid !== '0') {
    const cat = sqlGet('SELECT id FROM mesaj_kategori WHERE id = ?', [katid]);
    if (!cat) katid = '0';
  }
  if (!mesaj) return res.status(400).send('Mesaj yazmadın.');
  const formatted = metinDuzenle(mesaj);
  sqlRun(
    'INSERT INTO mesaj (gonderenid, mesaj, tarih, kategori) VALUES (?, ?, ?, ?)',
    [req.session.userId, formatted, new Date().toISOString(), Number(katid)]
  );
  res.json({ ok: true });
});

app.delete('/api/panolar/:id', requireAdmin, (req, res) => {
  sqlRun('DELETE FROM mesaj WHERE id = ?', [req.params.id]);
  res.json({ ok: true });
});

app.get('/api/quick-access', (req, res) => {
  if (!req.session.userId) return res.status(401).send('Login required');
  const user = sqlGet('SELECT hizliliste FROM uyeler WHERE id = ?', [req.session.userId]);
  const list = String(user?.hizliliste || '0')
    .split(',')
    .map((v) => v.trim())
    .filter((v) => v && v !== '0');
  const unique = Array.from(new Set(list));
  const users = unique.map((id) => sqlGet('SELECT id, kadi, resim, mezuniyetyili, online FROM uyeler WHERE id = ?', [id]))
    .filter(Boolean);
  res.json({ users });
});

app.post('/api/quick-access/add', (req, res) => {
  if (!req.session.userId) return res.status(401).send('Login required');
  const id = String(req.body?.id || '').trim();
  if (!/^\d+$/.test(id)) return res.status(400).send('Üye bulunamadı.');
  const target = sqlGet('SELECT id FROM uyeler WHERE id = ?', [id]);
  if (!target) return res.status(404).send('Üye bulunamadı.');
  const row = sqlGet('SELECT hizliliste FROM uyeler WHERE id = ?', [req.session.userId]);
  const list = String(row?.hizliliste || '0')
    .split(',')
    .map((v) => v.trim())
    .filter((v) => v && v !== '0');
  if (list.includes(id)) return res.status(400).send('Bu üye zaten hızlı erişim listenizde!');
  list.push(id);
  const updated = list.length ? `0,${list.join(',')}` : '0';
  sqlRun('UPDATE uyeler SET hizliliste = ? WHERE id = ?', [updated, req.session.userId]);
  res.json({ ok: true });
});

app.post('/api/quick-access/remove', (req, res) => {
  if (!req.session.userId) return res.status(401).send('Login required');
  const id = String(req.body?.id || '').trim();
  const row = sqlGet('SELECT hizliliste FROM uyeler WHERE id = ?', [req.session.userId]);
  const list = String(row?.hizliliste || '0')
    .split(',')
    .map((v) => v.trim())
    .filter((v) => v && v !== '0' && v !== id);
  const updated = list.length ? `0,${list.join(',')}` : '0';
  sqlRun('UPDATE uyeler SET hizliliste = ? WHERE id = ?', [updated, req.session.userId]);
  res.json({ ok: true });
});

app.get('/api/games/snake/leaderboard', (req, res) => {
  const rows = sqlAll('SELECT isim, skor, tarih FROM oyun_yilan ORDER BY skor DESC LIMIT 25');
  res.json({ rows });
});

app.post('/api/games/snake/score', (req, res) => {
  if (!req.session.userId) return res.status(401).send('Login required');
  const score = Number(req.body?.score || 0);
  const user = sqlGet('SELECT kadi FROM uyeler WHERE id = ?', [req.session.userId]);
  const name = user?.kadi || 'Misafir';
  const existing = sqlGet('SELECT * FROM oyun_yilan WHERE isim = ?', [name]);
  if (!existing) {
    sqlRun('INSERT INTO oyun_yilan (isim, skor, tarih) VALUES (?, ?, ?)', [name, score, new Date().toISOString()]);
  } else if (score > Number(existing.skor || 0)) {
    sqlRun('UPDATE oyun_yilan SET skor = ?, tarih = ? WHERE isim = ?', [score, new Date().toISOString(), name]);
  }
  res.json({ ok: true });
});

app.get('/api/games/tetris/leaderboard', (req, res) => {
  const rows = sqlAll('SELECT isim, puan, tarih FROM oyun_tetris ORDER BY puan DESC LIMIT 25');
  res.json({ rows });
});

app.post('/api/games/tetris/score', (req, res) => {
  if (!req.session.userId) return res.status(401).send('Login required');
  const score = Number(req.body?.score || 0);
  const user = sqlGet('SELECT kadi FROM uyeler WHERE id = ?', [req.session.userId]);
  const name = user?.kadi || 'Misafir';
  const existing = sqlGet('SELECT * FROM oyun_tetris WHERE isim = ?', [name]);
  if (!existing) {
    sqlRun('INSERT INTO oyun_tetris (isim, puan, tarih) VALUES (?, ?, ?)', [name, score, new Date().toISOString()]);
  } else if (score > Number(existing.puan || 0)) {
    sqlRun('UPDATE oyun_tetris SET puan = ?, tarih = ? WHERE isim = ?', [score, new Date().toISOString(), name]);
  }
  res.json({ ok: true });
});

// Serve modern (sdal_new) frontend
const modernDist = path.resolve(__dirname, '../../sdal_new/dist');
if (fs.existsSync(modernDist)) {
  app.use('/new', express.static(modernDist));
  app.get('/new/*', (req, res) => {
    res.sendFile(path.join(modernDist, 'index.html'));
  });
}

app.use((err, req, res, next) => {
  if (err) return res.status(400).send(err.message || 'Hata');
  return next();
});

// Legacy .asp redirects
app.get(/\/*.asp$/i, (req, res) => {
  const legacy = path.basename(req.path);
  let target = mapLegacyUrl(legacy);

  // Map common query-based routes
  if (legacy === 'uyedetay.asp' && req.query.id) target = `/uyeler/${req.query.id}`;
  if (legacy === 'mesajgor.asp' && req.query.mid) target = `/mesajlar/${req.query.mid}?k=${req.query.kk || 0}`;
  if (legacy === 'albumkat.asp' && req.query.kat) target = `/album/${req.query.kat}`;
  if (legacy === 'aktgnd.asp' && req.query.id) target = `/aktivasyon-gonder?id=${req.query.id}`;
  if (legacy === 'aktivet.asp' && req.query.id && req.query.akt) target = `/aktivet?id=${req.query.id}&akt=${req.query.akt}`;
  if (legacy === 'fotogoster.asp' && req.query.fid) target = `/album/foto/${req.query.fid}`;
  if ((legacy === 'pano.asp' || legacy === 'panolar.asp' || legacy === 'mesajpanosu.asp') && req.query.mkatid) {
    target = `/panolar?mkatid=${req.query.mkatid}`;
  }
  if (legacy === 'hizlierisimekle.asp' && req.query.uid) target = `/hizli-erisim/ekle?uid=${req.query.uid}`;
  if (legacy === 'hizlierisimcikart.asp' && req.query.uid) target = `/hizli-erisim/cikart?uid=${req.query.uid}`;

  return res.redirect(302, target);
});

// Serve frontend build in production
const clientDist = path.resolve(__dirname, '../client/dist');
app.use(express.static(clientDist));
app.get('*', (req, res) => {
  res.sendFile(path.join(clientDist, 'index.html'));
});

const server = app.listen(port, () => {
  console.log(`SDAL server running on http://localhost:${port}`);
});

const wss = new WebSocketServer({ server, path: '/ws/chat' });
wss.on('connection', (ws, req) => {
  ws.on('message', (data) => {
    try {
      const payload = JSON.parse(String(data || '{}'));
      if (!payload || !payload.userId || !payload.message) return;
      const message = metinDuzenle(payload.message || '');
      if (!message) return;
      const now = new Date().toISOString();
      const result = sqlRun('INSERT INTO chat_messages (user_id, message, created_at) VALUES (?, ?, ?)', [
        payload.userId,
        message,
        now
      ]);
      const user = sqlGet('SELECT id, kadi, isim, soyisim, resim, verified FROM uyeler WHERE id = ?', [payload.userId]) || {};
      const outgoing = JSON.stringify({
        id: result?.lastInsertRowid,
        message,
        created_at: now,
        user: {
          id: user.id,
          kadi: user.kadi,
          isim: user.isim,
          soyisim: user.soyisim,
          resim: user.resim,
          verified: user.verified
        }
      });
      wss.clients.forEach((client) => {
        if (client.readyState === 1) client.send(outgoing);
      });
    } catch {
      // ignore
    }
  });
});
