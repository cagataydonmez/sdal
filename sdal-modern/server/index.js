import 'dotenv/config';
import express from 'express';
import path from 'path';
import { fileURLToPath } from 'url';
import session from 'express-session';
import cookieParser from 'cookie-parser';
import morgan from 'morgan';
import { sqlGet, sqlAll, sqlRun, dbPath, getDb, closeDbConnection, resetDbConnection } from './db.js';
import { mapLegacyUrl } from './legacyRoutes.js';
import fs from 'fs';
import os from 'os';
import { execFileSync } from 'child_process';
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

const ONLINE_HEARTBEAT_MS = 45 * 1000;
app.use((req, _res, next) => {
  if (!req.session?.userId) return next();
  const nowMs = Date.now();
  const prev = Number(req.session._presenceUpdatedAt || 0);
  if (prev && nowMs - prev < ONLINE_HEARTBEAT_MS) return next();
  req.session._presenceUpdatedAt = nowMs;
  try {
    const now = new Date(nowMs);
    sqlRun('UPDATE uyeler SET sonislemtarih = ?, sonislemsaat = ?, sonip = ?, online = 1 WHERE id = ?', [
      now.toISOString().slice(0, 10),
      now.toTimeString().slice(0, 8),
      req.ip,
      req.session.userId
    ]);
  } catch {
    // presence update is best effort
  }
  return next();
});

app.use((req, res, next) => {
  const start = Date.now();
  res.on('finish', () => {
    const durationMs = Date.now() - start;
    const meta = {
      method: req.method,
      path: req.path,
      status: res.statusCode,
      durationMs,
      userId: req.session?.userId || null,
      ip: req.ip
    };

    if (req.path.startsWith('/api/')) {
      writeAppLog('info', 'http_request', meta);
    }

    // Hata logları: 4xx/5xx taleplerin tamamı
    if (res.statusCode >= 400) {
      writeLegacyLog('error', 'http_error', {
        ...meta,
        query: req.originalUrl?.includes('?') ? req.originalUrl.split('?')[1] : ''
      });
    }

    // Üye logları: kimliği belli kullanıcıların yazma işlemleri
    const isWrite = req.method === 'POST' || req.method === 'PUT' || req.method === 'PATCH' || req.method === 'DELETE';
    if (req.session?.userId && req.path.startsWith('/api/') && isWrite) {
      writeLegacyLog('member', 'member_activity', meta);
    }

    // Sayfa logları: HTML sayfa görüntülemeleri
    const accept = String(req.headers.accept || '');
    const wantsHtml = accept.includes('text/html');
    const isPageView = req.method === 'GET'
      && !req.path.startsWith('/api/')
      && !req.path.startsWith('/uploads/')
      && !req.path.startsWith('/legacy/')
      && !req.path.startsWith('/smiley/')
      && wantsHtml
      && res.statusCode < 400;
    if (isPageView) {
      writeLegacyLog('page', 'page_view', {
        path: req.path,
        query: req.originalUrl?.includes('?') ? req.originalUrl.split('?')[1] : '',
        userId: req.session?.userId || null,
        ip: req.ip,
        referer: req.headers.referer || '',
        ua: req.headers['user-agent'] || ''
      });
    }
  });
  next();
});

const legacyDir = path.resolve(__dirname, '../client/public/legacy');
app.use('/legacy', express.static(legacyDir));
app.use('/smiley', express.static(path.join(legacyDir, 'smiley')));

const uploadsDir = path.resolve(__dirname, String(process.env.SDAL_UPLOADS_DIR || '../uploads'));
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

const dbBackupIncomingDir = path.resolve(__dirname, '../tmp/db-backup-upload');
if (!fs.existsSync(dbBackupIncomingDir)) {
  fs.mkdirSync(dbBackupIncomingDir, { recursive: true });
}
const dbBackupUpload = multer({
  storage: multer.diskStorage({
    destination: (_req, _file, cb) => cb(null, dbBackupIncomingDir),
    filename: (_req, file, cb) => {
      const ext = path.extname(file.originalname || '').toLowerCase() || '.sqlite';
      cb(null, `incoming-${Date.now()}-${Math.round(Math.random() * 1e9)}${ext}`);
    }
  }),
  limits: { fileSize: 1024 * 1024 * 1024 }
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
for (const dir of [hatalogDir, sayfalogDir, uyedetaylogDir]) {
  if (!fs.existsSync(dir)) {
    fs.mkdirSync(dir, { recursive: true });
  }
}
const appLogsDir = path.resolve(__dirname, '../logs');
if (!fs.existsSync(appLogsDir)) {
  fs.mkdirSync(appLogsDir, { recursive: true });
}
const appLogFile = path.join(appLogsDir, 'app.log');
if (!fs.existsSync(appLogFile)) {
  fs.writeFileSync(appLogFile, '', 'utf-8');
}
const dbBackupDir = path.join(path.dirname(dbPath), 'backups');
if (!fs.existsSync(dbBackupDir)) {
  fs.mkdirSync(dbBackupDir, { recursive: true });
}

function backupTimestamp(date = new Date()) {
  const pad = (n) => String(n).padStart(2, '0');
  return `${date.getFullYear()}${pad(date.getMonth() + 1)}${pad(date.getDate())}-${pad(date.getHours())}${pad(date.getMinutes())}${pad(date.getSeconds())}`;
}

function normalizeBackupName(value) {
  const base = path.basename(String(value || ''));
  const safe = base.replace(/[^a-zA-Z0-9._-]/g, '_');
  if (!safe) return '';
  if (!safe.endsWith('.sqlite')) return `${safe}.sqlite`;
  return safe;
}

function resolveBackupPath(fileName) {
  const safeName = normalizeBackupName(fileName);
  if (!safeName) return null;
  return path.join(dbBackupDir, safeName);
}

function isSqliteHeader(buffer) {
  if (!buffer || buffer.length < 16) return false;
  const signature = Buffer.from('SQLite format 3\u0000', 'utf-8');
  return buffer.subarray(0, 16).equals(signature);
}

function isSqliteFile(filePath) {
  if (!filePath || !fs.existsSync(filePath)) return false;
  const fd = fs.openSync(filePath, 'r');
  try {
    const header = Buffer.alloc(16);
    const bytes = fs.readSync(fd, header, 0, 16, 0);
    if (bytes < 16) return false;
    return isSqliteHeader(header);
  } finally {
    fs.closeSync(fd);
  }
}

function listDbBackups() {
  if (!fs.existsSync(dbBackupDir)) return [];
  return fs.readdirSync(dbBackupDir)
    .filter((name) => /\.(sqlite|db|backup|bak)$/i.test(name))
    .map((name) => {
      const fullPath = path.join(dbBackupDir, name);
      const st = fs.statSync(fullPath);
      return {
        name,
        size: st.size,
        mtime: st.mtime.toISOString()
      };
    })
    .sort((a, b) => new Date(b.mtime).getTime() - new Date(a.mtime).getTime());
}

async function createDbBackup(label = 'manual') {
  const safeLabel = String(label || 'manual').replace(/[^a-zA-Z0-9_-]/g, '_').slice(0, 32) || 'manual';
  const name = `sdal-backup-${backupTimestamp()}-${safeLabel}.sqlite`;
  const fullPath = path.join(dbBackupDir, name);
  const db = getDb();
  try { db.pragma('wal_checkpoint(FULL)'); } catch {}
  await db.backup(fullPath);
  const st = fs.statSync(fullPath);
  return {
    name,
    size: st.size,
    mtime: st.mtime.toISOString()
  };
}

function restoreDbFromUploadedFile(incomingPath) {
  if (!isSqliteFile(incomingPath)) {
    throw new Error('Yüklenen dosya geçerli bir SQLite yedeği değil.');
  }
  const stamp = backupTimestamp();
  const uploadedName = `uploaded-${stamp}.sqlite`;
  const uploadedPath = path.join(dbBackupDir, uploadedName);
  fs.copyFileSync(incomingPath, uploadedPath);

  const preRestoreName = `pre-restore-${stamp}.sqlite`;
  const preRestorePath = path.join(dbBackupDir, preRestoreName);
  if (fs.existsSync(dbPath)) {
    fs.copyFileSync(dbPath, preRestorePath);
  }

  const tmpPath = `${dbPath}.restore.${Date.now()}.tmp`;
  fs.copyFileSync(uploadedPath, tmpPath);
  closeDbConnection();
  try {
    fs.renameSync(tmpPath, dbPath);
  } catch (err) {
    if (fs.existsSync(preRestorePath)) {
      fs.copyFileSync(preRestorePath, dbPath);
    }
    throw err;
  } finally {
    try {
      if (fs.existsSync(tmpPath)) fs.unlinkSync(tmpPath);
    } catch {
      // no-op
    }
    resetDbConnection();
  }
  return { uploadedName, preRestoreName };
}

function writeAppLog(level, event, meta = {}) {
  try {
    const row = {
      ts: new Date().toISOString(),
      level: String(level || 'info'),
      event: String(event || 'app_event'),
      ...meta
    };
    fs.appendFileSync(appLogFile, `${JSON.stringify(row)}\n`, 'utf-8');
  } catch {
    // Do not crash request flow on logging failure
  }
}

function writeLegacyLog(type, activity, meta = {}) {
  try {
    const map = {
      error: hatalogDir,
      page: sayfalogDir,
      member: uyedetaylogDir
    };
    const dir = map[type];
    if (!dir) return;
    const day = new Date().toISOString().slice(0, 10);
    const file = path.join(dir, `${day}.log`);
    const timestamp = new Date().toISOString();
    const pairs = Object.entries(meta || {})
      .filter(([, v]) => v !== undefined && v !== null && String(v) !== '')
      .map(([k, v]) => `${k}=${String(v).replace(/\s+/g, ' ').slice(0, 300)}`);
    const line = `[${timestamp}] activity=${activity}${pairs.length ? ` | ${pairs.join(' | ')}` : ''}\n`;
    fs.appendFileSync(file, line, 'utf-8');
  } catch {
    // Legacy log writing must never break request flow.
  }
}

function ensureSchemaMigrationsTable() {
  sqlRun(`CREATE TABLE IF NOT EXISTS schema_migrations (
    name TEXT PRIMARY KEY,
    applied_at TEXT
  )`);
}

function quoteIdentifier(value) {
  return `"${String(value || '').replace(/"/g, '""')}"`;
}

function hasColumn(table, column) {
  try {
    const safeTable = quoteIdentifier(table);
    const cols = sqlAll(`PRAGMA table_info(${safeTable})`);
    return cols.some((c) => c.name === column);
  } catch {
    return false;
  }
}

function hasMigration(name) {
  ensureSchemaMigrationsTable();
  return !!sqlGet('SELECT name FROM schema_migrations WHERE name = ?', [name]);
}

function runMigration(name, apply) {
  ensureSchemaMigrationsTable();
  if (hasMigration(name)) return;

  const db = getDb();
  const tx = db.transaction(() => {
    apply();
    sqlRun(
      'INSERT INTO schema_migrations (name, applied_at) VALUES (?, ?)',
      [name, new Date().toISOString()]
    );
  });

  tx();
}

// Pattern for future schema changes:
// runMigration('2026_02_add_users_timezone', () => {
//   if (!hasColumn('uyeler', 'timezone')) {
//     sqlRun("ALTER TABLE uyeler ADD COLUMN timezone TEXT DEFAULT 'Europe/Istanbul'");
//   }
// });
function migrateAddColumn(table, column, ddl) {
  runMigration(`add_column:${table}.${column}`, () => {
    if (!hasColumn(table, column)) {
      sqlRun(ddl);
    }
  });
}

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

migrateAddColumn('uyeler', 'verified', 'ALTER TABLE uyeler ADD COLUMN verified INTEGER DEFAULT 0');
migrateAddColumn('posts', 'group_id', 'ALTER TABLE posts ADD COLUMN group_id INTEGER');
migrateAddColumn('events', 'approved', 'ALTER TABLE events ADD COLUMN approved INTEGER DEFAULT 1');
migrateAddColumn('events', 'created_by', 'ALTER TABLE events ADD COLUMN created_by INTEGER');
migrateAddColumn('events', 'approved_by', 'ALTER TABLE events ADD COLUMN approved_by INTEGER');
migrateAddColumn('events', 'approved_at', 'ALTER TABLE events ADD COLUMN approved_at TEXT');
migrateAddColumn('events', 'image', 'ALTER TABLE events ADD COLUMN image TEXT');
migrateAddColumn('events', 'show_response_counts', 'ALTER TABLE events ADD COLUMN show_response_counts INTEGER DEFAULT 1');
migrateAddColumn('events', 'show_attendee_names', 'ALTER TABLE events ADD COLUMN show_attendee_names INTEGER DEFAULT 0');
migrateAddColumn('events', 'show_decliner_names', 'ALTER TABLE events ADD COLUMN show_decliner_names INTEGER DEFAULT 0');
migrateAddColumn('announcements', 'approved', 'ALTER TABLE announcements ADD COLUMN approved INTEGER DEFAULT 1');
migrateAddColumn('announcements', 'created_by', 'ALTER TABLE announcements ADD COLUMN created_by INTEGER');
migrateAddColumn('announcements', 'approved_by', 'ALTER TABLE announcements ADD COLUMN approved_by INTEGER');
migrateAddColumn('announcements', 'approved_at', 'ALTER TABLE announcements ADD COLUMN approved_at TEXT');
migrateAddColumn('announcements', 'image', 'ALTER TABLE announcements ADD COLUMN image TEXT');

sqlRun(`CREATE TABLE IF NOT EXISTS event_comments (
  id INTEGER PRIMARY KEY,
  event_id INTEGER,
  user_id INTEGER,
  comment TEXT,
  created_at TEXT
)`);
sqlRun(`CREATE TABLE IF NOT EXISTS event_responses (
  id INTEGER PRIMARY KEY,
  event_id INTEGER,
  user_id INTEGER,
  response TEXT,
  created_at TEXT,
  updated_at TEXT
)`);

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
migrateAddColumn('groups', 'visibility', "ALTER TABLE groups ADD COLUMN visibility TEXT DEFAULT 'public'");
migrateAddColumn('groups', 'show_contact_hint', 'ALTER TABLE groups ADD COLUMN show_contact_hint INTEGER DEFAULT 0');
sqlRun(`CREATE TABLE IF NOT EXISTS group_members (
  id INTEGER PRIMARY KEY,
  group_id INTEGER,
  user_id INTEGER,
  role TEXT,
  created_at TEXT
)`);
sqlRun(`CREATE TABLE IF NOT EXISTS group_join_requests (
  id INTEGER PRIMARY KEY,
  group_id INTEGER,
  user_id INTEGER,
  status TEXT,
  created_at TEXT,
  reviewed_at TEXT,
  reviewed_by INTEGER
)`);
sqlRun(`CREATE TABLE IF NOT EXISTS group_invites (
  id INTEGER PRIMARY KEY,
  group_id INTEGER,
  invited_user_id INTEGER,
  invited_by INTEGER,
  status TEXT,
  created_at TEXT,
  responded_at TEXT
)`);
sqlRun(`CREATE TABLE IF NOT EXISTS group_events (
  id INTEGER PRIMARY KEY,
  group_id INTEGER,
  title TEXT,
  description TEXT,
  location TEXT,
  starts_at TEXT,
  ends_at TEXT,
  created_at TEXT,
  created_by INTEGER
)`);
sqlRun(`CREATE TABLE IF NOT EXISTS group_announcements (
  id INTEGER PRIMARY KEY,
  group_id INTEGER,
  title TEXT,
  body TEXT,
  created_at TEXT,
  created_by INTEGER
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
sqlRun(`CREATE TABLE IF NOT EXISTS game_scores (
  id INTEGER PRIMARY KEY,
  game_key TEXT,
  name TEXT,
  score INTEGER,
  created_at TEXT
)`);
sqlRun(`CREATE TABLE IF NOT EXISTS member_engagement_scores (
  user_id INTEGER PRIMARY KEY,
  ab_variant TEXT DEFAULT 'A',
  score REAL DEFAULT 0,
  raw_score REAL DEFAULT 0,
  creator_score REAL DEFAULT 0,
  engagement_received_score REAL DEFAULT 0,
  community_score REAL DEFAULT 0,
  network_score REAL DEFAULT 0,
  quality_score REAL DEFAULT 0,
  penalty_score REAL DEFAULT 0,
  posts_30d INTEGER DEFAULT 0,
  posts_7d INTEGER DEFAULT 0,
  likes_received_30d INTEGER DEFAULT 0,
  comments_received_30d INTEGER DEFAULT 0,
  likes_given_30d INTEGER DEFAULT 0,
  comments_given_30d INTEGER DEFAULT 0,
  followers_count INTEGER DEFAULT 0,
  following_count INTEGER DEFAULT 0,
  follows_gained_30d INTEGER DEFAULT 0,
  follows_given_30d INTEGER DEFAULT 0,
  stories_30d INTEGER DEFAULT 0,
  story_views_received_30d INTEGER DEFAULT 0,
  chat_messages_30d INTEGER DEFAULT 0,
  last_activity_at TEXT,
  updated_at TEXT
)`);
sqlRun(`CREATE TABLE IF NOT EXISTS engagement_ab_config (
  variant TEXT PRIMARY KEY,
  name TEXT,
  description TEXT,
  traffic_pct INTEGER DEFAULT 50,
  enabled INTEGER DEFAULT 1,
  params_json TEXT,
  updated_at TEXT
)`);
sqlRun(`CREATE TABLE IF NOT EXISTS engagement_ab_assignments (
  user_id INTEGER PRIMARY KEY,
  variant TEXT,
  assigned_at TEXT,
  updated_at TEXT
)`);
sqlRun('CREATE INDEX IF NOT EXISTS idx_posts_user_created ON posts (user_id, created_at)');
sqlRun('CREATE INDEX IF NOT EXISTS idx_post_likes_post_created ON post_likes (post_id, created_at)');
sqlRun('CREATE INDEX IF NOT EXISTS idx_post_likes_user_created ON post_likes (user_id, created_at)');
sqlRun('CREATE INDEX IF NOT EXISTS idx_post_comments_post_created ON post_comments (post_id, created_at)');
sqlRun('CREATE INDEX IF NOT EXISTS idx_post_comments_user_created ON post_comments (user_id, created_at)');
sqlRun('CREATE INDEX IF NOT EXISTS idx_follows_following_created ON follows (following_id, created_at)');
sqlRun('CREATE INDEX IF NOT EXISTS idx_follows_follower_created ON follows (follower_id, created_at)');
sqlRun('CREATE INDEX IF NOT EXISTS idx_event_responses_event_user ON event_responses (event_id, user_id)');
sqlRun('CREATE UNIQUE INDEX IF NOT EXISTS idx_event_responses_unique_event_user ON event_responses (event_id, user_id)');
sqlRun('CREATE INDEX IF NOT EXISTS idx_stories_user_created ON stories (user_id, created_at)');
sqlRun('CREATE INDEX IF NOT EXISTS idx_story_views_story_created ON story_views (story_id, created_at)');
sqlRun('CREATE INDEX IF NOT EXISTS idx_member_engagement_score ON member_engagement_scores (score DESC)');
sqlRun('CREATE INDEX IF NOT EXISTS idx_member_engagement_updated ON member_engagement_scores (updated_at DESC)');
sqlRun('CREATE INDEX IF NOT EXISTS idx_member_engagement_variant ON member_engagement_scores (ab_variant, score DESC)');
sqlRun('CREATE INDEX IF NOT EXISTS idx_engagement_ab_assignments_variant ON engagement_ab_assignments (variant)');
migrateAddColumn('member_engagement_scores', 'ab_variant', "ALTER TABLE member_engagement_scores ADD COLUMN ab_variant TEXT DEFAULT 'A'");

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

function parseOnlineHeartbeat(row) {
  const datePart = String(row?.sonislemtarih || '').trim();
  const timePart = String(row?.sonislemsaat || '').trim();
  if (!datePart || !timePart) return null;
  const ms = Date.parse(`${datePart}T${timePart}`);
  return Number.isFinite(ms) ? ms : null;
}

function cleanupStaleOnlineUsers(maxIdleMs = 5 * 60 * 1000) {
  const rows = sqlAll('SELECT id, sonislemtarih, sonislemsaat FROM uyeler WHERE online = 1');
  const now = Date.now();
  for (const row of rows) {
    const ts = parseOnlineHeartbeat(row);
    if (!ts) continue;
    if (now - ts > maxIdleMs) {
      sqlRun('UPDATE uyeler SET online = 0 WHERE id = ?', [row.id]);
    }
  }
}

function listOnlineMembers({ limit = 12, excludeUserId = null } = {}) {
  cleanupStaleOnlineUsers();
  const safeLimit = Math.min(Math.max(Number(limit) || 12, 1), 100);
  const rows = sqlAll(
    `SELECT u.id, u.kadi, u.isim, u.soyisim, u.resim, u.mezuniyetyili, u.sonislemtarih, u.sonislemsaat,
            COALESCE(es.score, 0) AS engagement_score
     FROM uyeler u
     LEFT JOIN member_engagement_scores es ON es.user_id = u.id
     WHERE COALESCE(CAST(u.online AS INTEGER), 0) = 1
       AND (? IS NULL OR u.id != ?)
     ORDER BY COALESCE(es.score, 0) DESC, u.id DESC
     LIMIT ?`,
    [excludeUserId || null, excludeUserId || null, safeLimit]
  );
  return rows.map((row) => ({
    id: row.id,
    kadi: row.kadi,
    isim: row.isim,
    soyisim: row.soyisim,
    resim: row.resim,
    mezuniyetyili: row.mezuniyetyili,
    online: 1,
    engagement_score: Number(row.engagement_score || 0),
    lastSeenAt: row.sonislemtarih && row.sonislemsaat ? `${row.sonislemtarih}T${row.sonislemsaat}` : null
  }));
}

function getGroupMember(groupId, userId) {
  if (!groupId || !userId) return null;
  return sqlGet('SELECT id, role FROM group_members WHERE group_id = ? AND user_id = ?', [groupId, userId]);
}

function normalizeGroupVisibility(value) {
  const raw = String(value || 'public').trim().toLowerCase();
  if (['members_only', 'member_only', 'members', 'private', 'invited_only', 'invite_only'].includes(raw)) {
    return 'members_only';
  }
  return 'public';
}

function parseGroupVisibilityInput(value) {
  const raw = String(value || '').trim().toLowerCase();
  if (['public', 'open'].includes(raw)) return 'public';
  if (['members_only', 'member_only', 'members', 'private', 'invited_only', 'invite_only'].includes(raw)) {
    return 'members_only';
  }
  return null;
}

function isGroupManager(req, groupId) {
  const user = getCurrentUser(req);
  if (!user) return false;
  if (user.admin === 1 && req.session?.adminOk) return true;
  const member = getGroupMember(groupId, req.session.userId);
  return !!member && (member.role === 'owner' || member.role === 'moderator');
}

function logAdminAction(req, action, details = {}) {
  writeLegacyLog('member', action, {
    userId: req.session?.userId || null,
    ip: req.ip,
    ...details
  });
  writeAppLog('info', 'admin_action', {
    action,
    adminUserId: req.session?.userId || null,
    details
  });
}

function addNotification({ userId, type, sourceUserId, entityId, message }) {
  if (!userId) return;
  sqlRun(
    'INSERT INTO notifications (user_id, type, source_user_id, entity_id, message, created_at) VALUES (?, ?, ?, ?, ?, ?)',
    [userId, type, sourceUserId || null, entityId || null, message || '', new Date().toISOString()]
  );
}

const engagementDefaultParams = Object.freeze({
  receivedLikeWeight: 1,
  receivedCommentWeight: 2.4,
  receivedStoryViewWeight: 0.35,
  creatorPostWeight: 1.6,
  creatorRecentPostWeight: 2.2,
  creatorStoryWeight: 1,
  communityLikeWeight: 1,
  communityCommentWeight: 1.8,
  communityFollowWeight: 0.85,
  communityChatWeight: 0.45,
  networkFollowerWeight: 1.2,
  networkFollowGainWeight: 2.4,
  scaleReceived: 7.5,
  scaleCreator: 6.2,
  scaleCommunity: 5.3,
  scaleNetwork: 4.5,
  capReceived: 36,
  capCreator: 22,
  capCommunity: 19,
  capNetwork: 16,
  qualityVerifiedBonus: 2.5,
  qualityOnlineBonus: 1,
  qualityPhotoBonus: 1,
  qualityFieldBonus: 0.6,
  penaltyBanned: 70,
  penaltyInactive: 18,
  penaltyLowQualityPost: 8,
  penaltyAggressiveFollow: 6,
  penaltyLowFollowerRatio: 4,
  recency1d: 1.08,
  recency7d: 1.04,
  recency30d: 1,
  recency90d: 0.92,
  recency180d: 0.84,
  recencyOld: 0.76
});

const engagementDefaultVariants = Object.freeze({
  A: {
    name: 'Baseline',
    description: 'Denge odakli temel agirlik seti',
    trafficPct: 50,
    enabled: 1,
    params: { ...engagementDefaultParams }
  },
  B: {
    name: 'Growth',
    description: 'Yorum/follow etkisi daha yuksek deney seti',
    trafficPct: 50,
    enabled: 1,
    params: {
      ...engagementDefaultParams,
      receivedCommentWeight: 2.8,
      creatorRecentPostWeight: 2.5,
      networkFollowGainWeight: 2.8,
      scaleReceived: 7.9,
      scaleCommunity: 5.8,
      capReceived: 38
    }
  }
});

const engagementParamBounds = Object.freeze({
  receivedLikeWeight: [0, 5],
  receivedCommentWeight: [0, 8],
  receivedStoryViewWeight: [0, 3],
  creatorPostWeight: [0, 5],
  creatorRecentPostWeight: [0, 6],
  creatorStoryWeight: [0, 4],
  communityLikeWeight: [0, 5],
  communityCommentWeight: [0, 8],
  communityFollowWeight: [0, 5],
  communityChatWeight: [0, 3],
  networkFollowerWeight: [0, 5],
  networkFollowGainWeight: [0, 8],
  scaleReceived: [0, 15],
  scaleCreator: [0, 15],
  scaleCommunity: [0, 15],
  scaleNetwork: [0, 15],
  capReceived: [0, 100],
  capCreator: [0, 100],
  capCommunity: [0, 100],
  capNetwork: [0, 100],
  qualityVerifiedBonus: [0, 10],
  qualityOnlineBonus: [0, 6],
  qualityPhotoBonus: [0, 6],
  qualityFieldBonus: [0, 3],
  penaltyBanned: [0, 100],
  penaltyInactive: [0, 50],
  penaltyLowQualityPost: [0, 30],
  penaltyAggressiveFollow: [0, 30],
  penaltyLowFollowerRatio: [0, 20],
  recency1d: [0.2, 2],
  recency7d: [0.2, 2],
  recency30d: [0.2, 2],
  recency90d: [0.2, 2],
  recency180d: [0.2, 2],
  recencyOld: [0.2, 2]
});

function clamp(value, min, max) {
  if (!Number.isFinite(value)) return min;
  if (value < min) return min;
  if (value > max) return max;
  return value;
}

function asCountMap(rows, idField = 'user_id', valueField = 'cnt') {
  const out = new Map();
  for (const row of rows || []) {
    const key = Number(row?.[idField] || 0);
    if (!key) continue;
    const count = Number(row?.[valueField] || 0);
    out.set(key, Number.isFinite(count) ? count : 0);
  }
  return out;
}

function asLastAtMap(rows, idField = 'user_id', valueField = 'last_at') {
  const out = new Map();
  for (const row of rows || []) {
    const key = Number(row?.[idField] || 0);
    if (!key) continue;
    const value = row?.[valueField];
    if (!value) continue;
    out.set(key, value);
  }
  return out;
}

function toTruthyFlag(value) {
  if (value === true) return true;
  if (value === false || value === null || value === undefined) return false;
  if (Number(value) === 1) return true;
  const raw = String(value || '').trim().toLowerCase();
  return raw === '1' || raw === 'true' || raw === 'evet' || raw === 'yes';
}

function toDateMs(value) {
  if (!value) return null;
  const ms = new Date(String(value)).getTime();
  return Number.isFinite(ms) ? ms : null;
}

function pickLatestDateIso(...values) {
  let bestMs = null;
  let bestIso = null;
  for (const value of values) {
    const ms = toDateMs(value);
    if (ms === null) continue;
    if (bestMs === null || ms > bestMs) {
      bestMs = ms;
      bestIso = new Date(ms).toISOString();
    }
  }
  return bestIso;
}

function normalizeEngagementParams(raw, fallback = engagementDefaultParams) {
  const src = (raw && typeof raw === 'object') ? raw : {};
  const out = {};
  for (const [key, fallbackValue] of Object.entries(fallback)) {
    const val = Number(src[key]);
    const range = engagementParamBounds[key];
    if (!range) {
      out[key] = Number.isFinite(val) ? val : fallbackValue;
      continue;
    }
    if (!Number.isFinite(val)) {
      out[key] = fallbackValue;
      continue;
    }
    out[key] = clamp(val, range[0], range[1]);
  }
  return out;
}

function ensureEngagementAbConfigRows() {
  const now = new Date().toISOString();
  for (const [variant, cfg] of Object.entries(engagementDefaultVariants)) {
    const existing = sqlGet('SELECT variant FROM engagement_ab_config WHERE variant = ?', [variant]);
    if (existing) continue;
    sqlRun(
      `INSERT INTO engagement_ab_config
       (variant, name, description, traffic_pct, enabled, params_json, updated_at)
       VALUES (?, ?, ?, ?, ?, ?, ?)`,
      [
        variant,
        cfg.name,
        cfg.description,
        cfg.trafficPct,
        cfg.enabled,
        JSON.stringify(cfg.params),
        now
      ]
    );
  }
}

function getEngagementAbConfigs() {
  ensureEngagementAbConfigRows();
  const rows = sqlAll(
    `SELECT variant, name, description, traffic_pct, enabled, params_json, updated_at
     FROM engagement_ab_config
     ORDER BY variant ASC`
  );
  const items = [];
  for (const row of rows) {
    const variant = String(row.variant || '').toUpperCase();
    const fallback = engagementDefaultVariants[variant]?.params || engagementDefaultParams;
    let parsed = {};
    try {
      parsed = row.params_json ? JSON.parse(row.params_json) : {};
    } catch {
      parsed = {};
    }
    items.push({
      variant,
      name: String(row.name || engagementDefaultVariants[variant]?.name || variant),
      description: String(row.description || engagementDefaultVariants[variant]?.description || ''),
      trafficPct: clamp(Number(row.traffic_pct || 0), 0, 100),
      enabled: Number(row.enabled || 0) === 1 ? 1 : 0,
      params: normalizeEngagementParams(parsed, fallback),
      updatedAt: row.updated_at || null
    });
  }
  if (!items.length) {
    return Object.entries(engagementDefaultVariants).map(([variant, cfg]) => ({
      variant,
      name: cfg.name,
      description: cfg.description,
      trafficPct: cfg.trafficPct,
      enabled: cfg.enabled,
      params: normalizeEngagementParams(cfg.params, engagementDefaultParams),
      updatedAt: null
    }));
  }
  return items;
}

function hashUserSlot(userId) {
  const text = String(userId || '');
  let hash = 0;
  for (let i = 0; i < text.length; i += 1) {
    hash = (hash * 31 + text.charCodeAt(i)) % 1000003;
  }
  return Math.abs(hash % 100);
}

function chooseVariantForUser(userId, configs) {
  const enabled = (configs || []).filter((c) => c.enabled === 1 && c.trafficPct > 0);
  if (!enabled.length) return 'A';
  const totalTraffic = enabled.reduce((sum, c) => sum + Number(c.trafficPct || 0), 0);
  if (totalTraffic <= 0) return enabled[0]?.variant || 'A';
  const slot = hashUserSlot(userId);
  let cursor = 0;
  for (const cfg of enabled) {
    const span = Math.round((Number(cfg.trafficPct || 0) / totalTraffic) * 100);
    cursor += Math.max(span, 0);
    if (slot < cursor) return cfg.variant;
  }
  return enabled[enabled.length - 1]?.variant || 'A';
}

let engagementRecalcRunning = false;
let engagementRecalcTimer = null;

function recalculateMemberEngagementScores(reason = 'scheduled') {
  if (engagementRecalcRunning) return;
  engagementRecalcRunning = true;
  const startedAt = Date.now();
  try {
    const nowIso = new Date().toISOString();
    const since30 = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000).toISOString();
    const since7 = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000).toISOString();

    const users = sqlAll(
      `SELECT id, kadi, aktiv, yasak, verified, resim, mezuniyetyili, universite, sehir, meslek,
              online, sontarih, sonislemtarih, sonislemsaat
       FROM uyeler`
    );

    const posts30Rows = sqlAll(
      `SELECT user_id, COUNT(*) AS cnt,
              SUM(CASE WHEN created_at >= ? THEN 1 ELSE 0 END) AS recent7,
              MAX(created_at) AS last_at
       FROM posts
       WHERE user_id IS NOT NULL AND created_at >= ?
       GROUP BY user_id`,
      [since7, since30]
    );
    const likesReceived30Rows = sqlAll(
      `SELECT p.user_id, COUNT(*) AS cnt, MAX(l.created_at) AS last_at
       FROM post_likes l
       JOIN posts p ON p.id = l.post_id
       WHERE l.created_at >= ?
       GROUP BY p.user_id`,
      [since30]
    );
    const commentsReceived30Rows = sqlAll(
      `SELECT p.user_id, COUNT(*) AS cnt, MAX(c.created_at) AS last_at
       FROM post_comments c
       JOIN posts p ON p.id = c.post_id
       WHERE c.created_at >= ?
       GROUP BY p.user_id`,
      [since30]
    );
    const likesGiven30Rows = sqlAll(
      `SELECT user_id, COUNT(*) AS cnt, MAX(created_at) AS last_at
       FROM post_likes
       WHERE created_at >= ?
       GROUP BY user_id`,
      [since30]
    );
    const commentsGiven30Rows = sqlAll(
      `SELECT user_id, COUNT(*) AS cnt, MAX(created_at) AS last_at
       FROM post_comments
       WHERE created_at >= ?
       GROUP BY user_id`,
      [since30]
    );
    const followsGained30Rows = sqlAll(
      `SELECT following_id AS user_id, COUNT(*) AS cnt, MAX(created_at) AS last_at
       FROM follows
       WHERE created_at >= ?
       GROUP BY following_id`,
      [since30]
    );
    const followsGiven30Rows = sqlAll(
      `SELECT follower_id AS user_id, COUNT(*) AS cnt, MAX(created_at) AS last_at
       FROM follows
       WHERE created_at >= ?
       GROUP BY follower_id`,
      [since30]
    );
    const followersRows = sqlAll('SELECT following_id AS user_id, COUNT(*) AS cnt FROM follows GROUP BY following_id');
    const followingRows = sqlAll('SELECT follower_id AS user_id, COUNT(*) AS cnt FROM follows GROUP BY follower_id');
    const stories30Rows = sqlAll(
      `SELECT user_id, COUNT(*) AS cnt, MAX(created_at) AS last_at
       FROM stories
       WHERE created_at >= ?
       GROUP BY user_id`,
      [since30]
    );
    const storyViewsReceived30Rows = sqlAll(
      `SELECT s.user_id, COUNT(*) AS cnt, MAX(v.created_at) AS last_at
       FROM story_views v
       JOIN stories s ON s.id = v.story_id
       WHERE v.created_at >= ?
       GROUP BY s.user_id`,
      [since30]
    );
    const chatMessages30Rows = sqlAll(
      `SELECT user_id, COUNT(*) AS cnt, MAX(created_at) AS last_at
       FROM chat_messages
       WHERE created_at >= ?
       GROUP BY user_id`,
      [since30]
    );

    const posts30Map = asCountMap(posts30Rows);
    const posts7Map = new Map(posts30Rows.map((r) => [Number(r.user_id || 0), Number(r.recent7 || 0)]));
    const likesReceived30Map = asCountMap(likesReceived30Rows);
    const commentsReceived30Map = asCountMap(commentsReceived30Rows);
    const likesGiven30Map = asCountMap(likesGiven30Rows);
    const commentsGiven30Map = asCountMap(commentsGiven30Rows);
    const followsGained30Map = asCountMap(followsGained30Rows);
    const followsGiven30Map = asCountMap(followsGiven30Rows);
    const followersMap = asCountMap(followersRows);
    const followingMap = asCountMap(followingRows);
    const stories30Map = asCountMap(stories30Rows);
    const storyViewsReceived30Map = asCountMap(storyViewsReceived30Rows);
    const chatMessages30Map = asCountMap(chatMessages30Rows);
    const postsLastMap = asLastAtMap(posts30Rows);
    const likesReceivedLastMap = asLastAtMap(likesReceived30Rows);
    const commentsReceivedLastMap = asLastAtMap(commentsReceived30Rows);
    const likesGivenLastMap = asLastAtMap(likesGiven30Rows);
    const commentsGivenLastMap = asLastAtMap(commentsGiven30Rows);
    const followsGainedLastMap = asLastAtMap(followsGained30Rows);
    const followsGivenLastMap = asLastAtMap(followsGiven30Rows);
    const storiesLastMap = asLastAtMap(stories30Rows);
    const storyViewsLastMap = asLastAtMap(storyViewsReceived30Rows);
    const chatMessagesLastMap = asLastAtMap(chatMessages30Rows);
    const abConfigs = getEngagementAbConfigs();
    const abParamsByVariant = new Map(abConfigs.map((cfg) => [cfg.variant, cfg.params]));
    const assignmentRows = sqlAll('SELECT user_id, variant FROM engagement_ab_assignments');
    const assignmentMap = new Map(
      assignmentRows
        .map((r) => [Number(r.user_id || 0), String(r.variant || '').toUpperCase()])
        .filter(([uid, variant]) => uid > 0 && variant)
    );
    const variantCounts = {};

    sqlRun('DELETE FROM member_engagement_scores WHERE user_id NOT IN (SELECT id FROM uyeler)');
    sqlRun('DELETE FROM engagement_ab_assignments WHERE user_id NOT IN (SELECT id FROM uyeler)');
    for (const user of users) {
      const uid = Number(user?.id || 0);
      if (!uid) continue;
      let abVariant = assignmentMap.get(uid);
      if (!abVariant || !abParamsByVariant.has(abVariant)) {
        abVariant = chooseVariantForUser(uid, abConfigs);
        assignmentMap.set(uid, abVariant);
        sqlRun(
          `INSERT INTO engagement_ab_assignments (user_id, variant, assigned_at, updated_at)
           VALUES (?, ?, ?, ?)
           ON CONFLICT(user_id) DO UPDATE SET
             variant = excluded.variant,
             updated_at = excluded.updated_at`,
          [uid, abVariant, nowIso, nowIso]
        );
      }
      const p = abParamsByVariant.get(abVariant) || engagementDefaultParams;
      variantCounts[abVariant] = (variantCounts[abVariant] || 0) + 1;

      const posts30 = Number(posts30Map.get(uid) || 0);
      const posts7 = Number(posts7Map.get(uid) || 0);
      const likesReceived30 = Number(likesReceived30Map.get(uid) || 0);
      const commentsReceived30 = Number(commentsReceived30Map.get(uid) || 0);
      const likesGiven30 = Number(likesGiven30Map.get(uid) || 0);
      const commentsGiven30 = Number(commentsGiven30Map.get(uid) || 0);
      const followsGained30 = Number(followsGained30Map.get(uid) || 0);
      const followsGiven30 = Number(followsGiven30Map.get(uid) || 0);
      const followersCount = Number(followersMap.get(uid) || 0);
      const followingCount = Number(followingMap.get(uid) || 0);
      const stories30 = Number(stories30Map.get(uid) || 0);
      const storyViewsReceived30 = Number(storyViewsReceived30Map.get(uid) || 0);
      const chatMessages30 = Number(chatMessages30Map.get(uid) || 0);

      const interactionsReceived =
        likesReceived30 * p.receivedLikeWeight
        + commentsReceived30 * p.receivedCommentWeight
        + storyViewsReceived30 * p.receivedStoryViewWeight;
      const creatorActivity =
        posts30 * p.creatorPostWeight
        + posts7 * p.creatorRecentPostWeight
        + stories30 * p.creatorStoryWeight;
      const communityActions =
        likesGiven30 * p.communityLikeWeight
        + commentsGiven30 * p.communityCommentWeight
        + followsGiven30 * p.communityFollowWeight
        + chatMessages30 * p.communityChatWeight;
      const networkGrowth =
        followersCount * p.networkFollowerWeight
        + followsGained30 * p.networkFollowGainWeight;

      const engagementReceivedScore = Math.min(p.capReceived, Math.log1p(interactionsReceived) * p.scaleReceived);
      const creatorScore = Math.min(p.capCreator, Math.log1p(creatorActivity) * p.scaleCreator);
      const communityScore = Math.min(p.capCommunity, Math.log1p(communityActions) * p.scaleCommunity);
      const networkScore = Math.min(p.capNetwork, Math.log1p(networkGrowth) * p.scaleNetwork);

      let qualityScore = 0;
      if (toTruthyFlag(user?.verified)) qualityScore += p.qualityVerifiedBonus;
      if (toTruthyFlag(user?.online)) qualityScore += p.qualityOnlineBonus;
      if (user?.resim && String(user.resim).trim() && String(user.resim).trim().toLowerCase() !== 'yok') qualityScore += p.qualityPhotoBonus;
      if (String(user?.mezuniyetyili || '').trim()) qualityScore += p.qualityFieldBonus;
      if (String(user?.universite || '').trim()) qualityScore += p.qualityFieldBonus;
      if (String(user?.sehir || '').trim()) qualityScore += p.qualityFieldBonus;
      if (String(user?.meslek || '').trim()) qualityScore += p.qualityFieldBonus;

      let penaltyScore = 0;
      if (toTruthyFlag(user?.yasak)) penaltyScore += p.penaltyBanned;
      if (!toTruthyFlag(user?.aktiv)) penaltyScore += p.penaltyInactive;
      if (posts30 >= 8 && likesReceived30 + commentsReceived30 <= 2) penaltyScore += p.penaltyLowQualityPost;
      if (followsGiven30 >= 120 && followsGained30 <= 3) penaltyScore += p.penaltyAggressiveFollow;
      if (followingCount > 0 && followersCount / followingCount < 0.03 && followingCount >= 150) penaltyScore += p.penaltyLowFollowerRatio;

      const legacyLast = user?.sonislemtarih && user?.sonislemsaat
        ? `${user.sonislemtarih} ${user.sonislemsaat}`
        : user?.sontarih;
      const lastActivityAt = pickLatestDateIso(
        postsLastMap.get(uid),
        likesReceivedLastMap.get(uid),
        commentsReceivedLastMap.get(uid),
        likesGivenLastMap.get(uid),
        commentsGivenLastMap.get(uid),
        followsGainedLastMap.get(uid),
        followsGivenLastMap.get(uid),
        storiesLastMap.get(uid),
        storyViewsLastMap.get(uid),
        chatMessagesLastMap.get(uid),
        legacyLast
      );

      const rawScore = creatorScore + engagementReceivedScore + communityScore + networkScore + qualityScore - penaltyScore;
      const nowMs = Date.now();
      const lastMs = toDateMs(lastActivityAt);
      const daysSinceLast = lastMs === null ? 365 : (nowMs - lastMs) / (24 * 60 * 60 * 1000);
      let recencyFactor = 1;
      if (daysSinceLast <= 1) recencyFactor = p.recency1d;
      else if (daysSinceLast <= 7) recencyFactor = p.recency7d;
      else if (daysSinceLast <= 30) recencyFactor = p.recency30d;
      else if (daysSinceLast <= 90) recencyFactor = p.recency90d;
      else if (daysSinceLast <= 180) recencyFactor = p.recency180d;
      else recencyFactor = p.recencyOld;
      const score = clamp(rawScore * recencyFactor, 0, 100);

      sqlRun(
        `INSERT INTO member_engagement_scores (
          user_id, ab_variant, score, raw_score, creator_score, engagement_received_score, community_score, network_score,
          quality_score, penalty_score, posts_30d, posts_7d, likes_received_30d, comments_received_30d,
          likes_given_30d, comments_given_30d, followers_count, following_count, follows_gained_30d,
          follows_given_30d, stories_30d, story_views_received_30d, chat_messages_30d, last_activity_at, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(user_id) DO UPDATE SET
          ab_variant = excluded.ab_variant,
          score = excluded.score,
          raw_score = excluded.raw_score,
          creator_score = excluded.creator_score,
          engagement_received_score = excluded.engagement_received_score,
          community_score = excluded.community_score,
          network_score = excluded.network_score,
          quality_score = excluded.quality_score,
          penalty_score = excluded.penalty_score,
          posts_30d = excluded.posts_30d,
          posts_7d = excluded.posts_7d,
          likes_received_30d = excluded.likes_received_30d,
          comments_received_30d = excluded.comments_received_30d,
          likes_given_30d = excluded.likes_given_30d,
          comments_given_30d = excluded.comments_given_30d,
          followers_count = excluded.followers_count,
          following_count = excluded.following_count,
          follows_gained_30d = excluded.follows_gained_30d,
          follows_given_30d = excluded.follows_given_30d,
          stories_30d = excluded.stories_30d,
          story_views_received_30d = excluded.story_views_received_30d,
          chat_messages_30d = excluded.chat_messages_30d,
          last_activity_at = excluded.last_activity_at,
          updated_at = excluded.updated_at`,
        [
          uid,
          abVariant,
          Number(score.toFixed(2)),
          Number(rawScore.toFixed(2)),
          Number(creatorScore.toFixed(2)),
          Number(engagementReceivedScore.toFixed(2)),
          Number(communityScore.toFixed(2)),
          Number(networkScore.toFixed(2)),
          Number(qualityScore.toFixed(2)),
          Number(penaltyScore.toFixed(2)),
          posts30,
          posts7,
          likesReceived30,
          commentsReceived30,
          likesGiven30,
          commentsGiven30,
          followersCount,
          followingCount,
          followsGained30,
          followsGiven30,
          stories30,
          storyViewsReceived30,
          chatMessages30,
          lastActivityAt || null,
          nowIso
        ]
      );
    }

    writeAppLog('info', 'engagement_scores_recalculated', {
      reason,
      users: users.length,
      variants: variantCounts,
      durationMs: Date.now() - startedAt
    });
  } catch (err) {
    writeAppLog('error', 'engagement_scores_recalculate_failed', {
      reason,
      message: err?.message || 'unknown_error'
    });
  } finally {
    engagementRecalcRunning = false;
  }
}

function scheduleEngagementRecalculation(reason = 'activity') {
  if (engagementRecalcTimer || engagementRecalcRunning) return;
  engagementRecalcTimer = setTimeout(() => {
    engagementRecalcTimer = null;
    recalculateMemberEngagementScores(reason);
  }, 15000);
}

function findMentionUserIds(text, excludeUserId = null) {
  const raw = String(text || '');
  const handles = new Set();
  const regex = /@([a-zA-Z0-9._-]{2,20})/g;
  let m;
  while ((m = regex.exec(raw)) !== null) {
    if (m[1]) handles.add(m[1].toLowerCase());
  }
  if (!handles.size) return [];
  const users = sqlAll(
    `SELECT id, kadi
     FROM uyeler
     WHERE COALESCE(CAST(yasak AS INTEGER), 0) = 0
       AND (
         aktiv IS NULL
         OR CAST(aktiv AS INTEGER) = 1
         OR LOWER(CAST(aktiv AS TEXT)) IN ('true', 'evet')
       )`
  );
  const ids = [];
  for (const u of users) {
    if (!u?.kadi) continue;
    if (!handles.has(String(u.kadi).toLowerCase())) continue;
    if (excludeUserId && sameUserId(u.id, excludeUserId)) continue;
    ids.push(Number(u.id));
  }
  return Array.from(new Set(ids));
}

function notifyMentions({ text, sourceUserId, entityId, type = 'mention', message = 'Senden bahsetti.', allowedUserIds = null }) {
  const ids = findMentionUserIds(text, sourceUserId);
  const allowed = Array.isArray(allowedUserIds) ? new Set(allowedUserIds.map((v) => String(normalizeUserId(v)))) : null;
  for (const userId of ids) {
    if (allowed && !allowed.has(String(normalizeUserId(userId)))) continue;
    addNotification({ userId, type, sourceUserId, entityId, message });
  }
}

function isFormattedContentEmpty(value) {
  const plain = String(value || '')
    .replace(/<[^>]+>/g, ' ')
    .replace(/&nbsp;/gi, ' ')
    .replace(/\s+/g, ' ')
    .trim();
  return !plain;
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

function parseDateInput(value) {
  if (!value) return null;
  const d = new Date(String(value));
  if (Number.isNaN(d.getTime())) return null;
  return d;
}

function parseLegacyMeta(text) {
  const out = {};
  const parts = String(text || '').split(' | ');
  for (const part of parts) {
    const idx = part.indexOf('=');
    if (idx <= 0) continue;
    const key = part.slice(0, idx).trim();
    const val = part.slice(idx + 1).trim();
    if (!key) continue;
    out[key] = val;
  }
  return out;
}

function parseLogLine(line) {
  const raw = String(line || '');
  const trimmed = raw.trim();
  if (!trimmed) return null;

  // JSONL (app logs)
  if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
    try {
      const obj = JSON.parse(trimmed);
      const ts = obj.ts || obj.timestamp || obj.created_at || null;
      return {
        raw,
        ts: ts ? new Date(ts) : null,
        activity: obj.event || obj.activity || '',
        userId: obj.userId || obj.adminUserId || obj.details?.userId || null,
        text: trimmed.toLowerCase()
      };
    } catch {
      // fall through
    }
  }

  // Legacy format: [ISO] activity=name | key=val | ...
  const m = trimmed.match(/^\[([^\]]+)\]\s+activity=([^\s|]+)(?:\s+\|\s+(.+))?$/);
  if (m) {
    const ts = parseDateInput(m[1]);
    const activity = m[2] || '';
    const meta = parseLegacyMeta(m[3] || '');
    return {
      raw,
      ts,
      activity,
      userId: meta.userId || meta.adminUserId || null,
      text: trimmed.toLowerCase()
    };
  }

  return {
    raw,
    ts: null,
    activity: '',
    userId: null,
    text: trimmed.toLowerCase()
  };
}

function lineMatchesFilters(entry, filters) {
  if (!entry) return false;
  if (filters.q && !entry.text.includes(filters.q)) return false;
  if (filters.activity && String(entry.activity || '').toLowerCase() !== filters.activity) return false;
  if (filters.userId && String(entry.userId || '') !== filters.userId) return false;
  if (filters.from && entry.ts && entry.ts < filters.from) return false;
  if (filters.to && entry.ts && entry.ts > filters.to) return false;
  if ((filters.from || filters.to) && !entry.ts && (filters.activity || filters.userId)) return false;
  return true;
}

function filterLogContent(content, query) {
  const rawLines = String(content || '').split('\n').filter((line) => String(line).trim() !== '');
  const q = String(query.q || '').trim().toLowerCase();
  const activity = String(query.activity || '').trim().toLowerCase();
  const userId = String(query.userId || query.user_id || '').trim();
  const from = parseDateInput(query.from || query.date_from);
  const to = parseDateInput(query.to || query.date_to);
  const limit = Math.min(Math.max(parseInt(query.limit || '500', 10), 1), 10000);
  const offset = Math.max(parseInt(query.offset || '0', 10), 0);

  const filters = { q, activity, userId, from, to };
  const parsed = rawLines.map(parseLogLine).filter(Boolean);
  const matched = parsed.filter((line) => lineMatchesFilters(line, filters));
  const sliced = matched.slice(offset, offset + limit);

  return {
    content: sliced.map((line) => line.raw).join('\n'),
    total: rawLines.length,
    matched: matched.length,
    returned: sliced.length,
    offset,
    limit
  };
}

function normalizeUserId(value) {
  if (value === null || value === undefined) return null;
  const raw = String(value).trim();
  const n = Number(raw);
  if (Number.isFinite(n)) return Math.trunc(n);
  // SQLite CAST can coerce leading digits from mixed strings (e.g. "12abc" -> 12).
  // Mirror that behavior so auth checks match query filters.
  const leadingInt = raw.match(/^-?\d+/);
  if (leadingInt) return parseInt(leadingInt[0], 10);
  const cleaned = raw.replace(/\.0+$/, '');
  return cleaned || null;
}

function sameUserId(a, b) {
  const aa = normalizeUserId(a);
  const bb = normalizeUserId(b);
  return aa !== null && bb !== null && String(aa) === String(bb);
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

async function optimizeUploadedImage(filePath, {
  width = 1600,
  height = 1600,
  fit = 'inside',
  quality = 84,
  background = '#121212'
} = {}) {
  if (!filePath || !fs.existsSync(filePath)) return filePath;
  const parsed = path.parse(filePath);
  const outputPath = path.join(parsed.dir, `${parsed.name}.webp`);
  await sharp(filePath)
    .rotate()
    .resize(width || null, height || null, {
      fit,
      withoutEnlargement: true,
      background
    })
    .webp({ quality, effort: 4 })
    .toFile(outputPath);
  if (outputPath !== filePath && fs.existsSync(filePath)) {
    try {
      fs.unlinkSync(filePath);
    } catch {
      // ignore cleanup errors
    }
  }
  return outputPath;
}

function toUploadUrl(filePath) {
  if (!filePath) return null;
  const rel = path.relative(uploadsDir, filePath).split(path.sep).join('/');
  return `/uploads/${rel}`;
}

function walkDirStats(rootDir) {
  const stack = [rootDir];
  let files = 0;
  let bytes = 0;
  while (stack.length) {
    const dir = stack.pop();
    if (!dir || !fs.existsSync(dir)) continue;
    const entries = fs.readdirSync(dir, { withFileTypes: true });
    for (const entry of entries) {
      const abs = path.join(dir, entry.name);
      if (entry.isDirectory()) {
        stack.push(abs);
        continue;
      }
      if (!entry.isFile()) continue;
      files += 1;
      try {
        bytes += fs.statSync(abs).size || 0;
      } catch {
        // ignore unreadable files
      }
    }
  }
  return { files, bytes };
}

function bytesToMb(value) {
  return Number(((Number(value) || 0) / (1024 * 1024)).toFixed(2));
}

function safeStatfs(targetPath) {
  try {
    return fs.statfsSync(targetPath);
  } catch {
    return null;
  }
}

function safeDf(targetPath) {
  try {
    const output = execFileSync('df', ['-kP', String(targetPath || '')], {
      encoding: 'utf8',
      stdio: ['ignore', 'pipe', 'ignore']
    });
    const lines = String(output || '').trim().split('\n');
    if (lines.length < 2) return null;
    const parts = lines[1].trim().split(/\s+/);
    if (parts.length < 6) return null;
    const totalKb = Number(parts[1] || 0);
    const usedKb = Number(parts[2] || 0);
    const freeKb = Number(parts[3] || 0);
    if (!Number.isFinite(totalKb) || totalKb <= 0) return null;
    return {
      totalBytes: Math.max(0, totalKb * 1024),
      usedBytes: Math.max(0, usedKb * 1024),
      freeBytes: Math.max(0, freeKb * 1024),
      source: 'df'
    };
  } catch {
    return null;
  }
}

function getDiskMetrics(targetPath) {
  const statfs = safeStatfs(targetPath);
  if (statfs) {
    const totalBytes = Number(statfs.blocks || 0) * Number(statfs.bsize || 0);
    const freeBytes = Number(statfs.bavail || 0) * Number(statfs.bsize || 0);
    if (Number.isFinite(totalBytes) && totalBytes > 0) {
      const usedBytes = Math.max(0, totalBytes - Math.max(0, freeBytes));
      return {
        totalBytes,
        usedBytes,
        freeBytes: Math.max(0, freeBytes),
        source: 'statfs'
      };
    }
  }
  return safeDf(targetPath);
}

let cpuSample = {
  at: 0,
  total: 0,
  idle: 0,
  value: null
};

function readCpuSnapshot() {
  const cpus = os.cpus?.() || [];
  if (!cpus.length) return null;
  let total = 0;
  let idle = 0;
  for (const cpu of cpus) {
    const times = cpu?.times || {};
    const user = Number(times.user || 0);
    const nice = Number(times.nice || 0);
    const sys = Number(times.sys || 0);
    const irq = Number(times.irq || 0);
    const idleTime = Number(times.idle || 0);
    total += user + nice + sys + irq + idleTime;
    idle += idleTime;
  }
  return { total, idle };
}

function sampleCpuUsagePercent() {
  const now = Date.now();
  const snap = readCpuSnapshot();
  if (snap) {
    if (cpuSample.at > 0) {
      const totalDiff = snap.total - cpuSample.total;
      const idleDiff = snap.idle - cpuSample.idle;
      if (totalDiff > 0) {
        const busyRatio = 1 - (idleDiff / totalDiff);
        const pct = Math.min(100, Math.max(0, busyRatio * 100));
        cpuSample = { at: now, total: snap.total, idle: snap.idle, value: Number(pct.toFixed(2)) };
        return cpuSample.value;
      }
    }
    cpuSample = { at: now, total: snap.total, idle: snap.idle, value: cpuSample.value };
    if (cpuSample.value !== null) return cpuSample.value;
  }
  const loads = os.loadavg?.() || [];
  const cpuCount = Math.max((os.cpus?.() || []).length, 1);
  const load1 = Number(loads[0] || 0);
  if (!Number.isFinite(load1) || load1 <= 0) return null;
  const loadPct = Math.min(100, Math.max(0, (load1 / cpuCount) * 100));
  return Number(loadPct.toFixed(2));
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
  if (!user) {
    writeLegacyLog('error', 'admin_login_denied', { reason: 'unauthenticated', ip: req.ip });
    writeAppLog('warn', 'admin_login_denied', { reason: 'unauthenticated', ip: req.ip });
    return res.status(401).send('Login required');
  }
  if (user.admin !== 1) {
    writeLegacyLog('error', 'admin_login_denied', { reason: 'not_admin', userId: user.id, ip: req.ip });
    writeAppLog('warn', 'admin_login_denied', { reason: 'not_admin', userId: user.id, ip: req.ip });
    return res.status(403).send('Admin erişimi gerekli.');
  }
  const password = String(req.body?.password || '');
  if (!password) return res.status(400).send('Şifre girmedin.');
  if (password !== adminPassword) {
    writeLegacyLog('error', 'admin_login_denied', { reason: 'bad_password', userId: user.id, ip: req.ip });
    writeAppLog('warn', 'admin_login_denied', { reason: 'bad_password', userId: user.id, ip: req.ip });
    return res.status(400).send('Şifre yanlış.');
  }
  req.session.adminOk = true;
  res.cookie('admingiris', 'evet');
  writeLegacyLog('member', 'admin_login_success', { userId: user.id, ip: req.ip });
  writeAppLog('info', 'admin_login_success', { userId: user.id, ip: req.ip });
  res.json({ ok: true });
});

app.post('/api/admin/logout', (req, res) => {
  writeLegacyLog('member', 'admin_logout', { userId: req.session?.userId || null, ip: req.ip });
  writeAppLog('info', 'admin_logout', { userId: req.session?.userId || null, ip: req.ip });
  req.session.adminOk = false;
  res.clearCookie('admingiris');
  res.json({ ok: true });
});

function queryAdminUsers(rawQuery = {}) {
  const filter = String(rawQuery.filter || 'all').trim();
  const q = String(rawQuery.q || '').trim();
  const withPhoto = String(rawQuery.photo || rawQuery.res || '').trim() === '1';
  const verifiedOnly = String(rawQuery.verified || '').trim() === '1';
  const onlineOnly = String(rawQuery.online || '').trim() === '1';
  const adminOnly = String(rawQuery.admin || '').trim() === '1';
  const minScoreRaw = String(rawQuery.minScore ?? rawQuery.min_score ?? '').trim();
  const maxScoreRaw = String(rawQuery.maxScore ?? rawQuery.max_score ?? '').trim();
  const minScore = minScoreRaw === '' ? NaN : Number(minScoreRaw);
  const maxScore = maxScoreRaw === '' ? NaN : Number(maxScoreRaw);
  const limit = Math.min(Math.max(parseInt(rawQuery.limit || '500', 10), 1), 2000);
  const activeExpr = "(COALESCE(CAST(u.aktiv AS INTEGER), 0) = 1 OR LOWER(CAST(u.aktiv AS TEXT)) IN ('true','evet','yes'))";
  const bannedExpr = "(COALESCE(CAST(u.yasak AS INTEGER), 0) = 1 OR LOWER(CAST(u.yasak AS TEXT)) IN ('true','evet','yes'))";
  const onlineExpr = "(COALESCE(CAST(u.online AS INTEGER), 0) = 1 OR LOWER(CAST(u.online AS TEXT)) IN ('true','evet','yes'))";

  const whereParts = [];
  const params = [];
  if (filter === 'active') whereParts.push(`${activeExpr} AND NOT ${bannedExpr}`);
  if (filter === 'pending') whereParts.push(`NOT ${activeExpr} AND NOT ${bannedExpr}`);
  if (filter === 'banned') whereParts.push(`${bannedExpr}`);
  if (filter === 'online') whereParts.push(`${onlineExpr}`);
  if (q) {
    whereParts.push('(LOWER(CAST(u.kadi AS TEXT)) LIKE LOWER(?) OR LOWER(CAST(u.isim AS TEXT)) LIKE LOWER(?) OR LOWER(CAST(u.soyisim AS TEXT)) LIKE LOWER(?) OR LOWER(CAST(u.email AS TEXT)) LIKE LOWER(?))');
    params.push(`%${q}%`, `%${q}%`, `%${q}%`, `%${q}%`);
  }
  if (withPhoto) {
    whereParts.push("u.resim IS NOT NULL AND TRIM(CAST(u.resim AS TEXT)) != '' AND LOWER(TRIM(CAST(u.resim AS TEXT))) != 'yok'");
  }
  if (verifiedOnly) {
    whereParts.push("COALESCE(CAST(u.verified AS INTEGER), 0) = 1");
  }
  if (onlineOnly) {
    whereParts.push(onlineExpr);
  }
  if (adminOnly) {
    whereParts.push("COALESCE(CAST(u.admin AS INTEGER), 0) = 1");
  }
  if (Number.isFinite(minScore)) {
    whereParts.push('COALESCE(es.score, 0) >= ?');
    params.push(minScore);
  }
  if (Number.isFinite(maxScore)) {
    whereParts.push('COALESCE(es.score, 0) <= ?');
    params.push(maxScore);
  }
  const where = whereParts.length ? `WHERE ${whereParts.join(' AND ')}` : '';
  let sort = String(rawQuery.sort || '').trim();
  if (!sort) {
    sort = filter === 'recent' ? 'recent' : 'engagement_desc';
  }
  const sortMap = {
    name: 'u.kadi COLLATE NOCASE ASC',
    recent: 'COALESCE(u.sontarih, u.sonislemtarih, "") DESC, u.id DESC',
    online: `${onlineExpr} DESC, COALESCE(es.score, 0) DESC, u.kadi COLLATE NOCASE ASC`,
    engagement_desc: 'COALESCE(es.score, 0) DESC, u.id DESC',
    engagement_asc: 'COALESCE(es.score, 0) ASC, u.id DESC'
  };
  const orderBy = sortMap[sort] || sortMap.engagement_desc;

  const total = sqlGet(
    `SELECT COUNT(*) AS cnt
     FROM uyeler u
     LEFT JOIN member_engagement_scores es ON es.user_id = u.id
     ${where}`,
    params
  )?.cnt || 0;

  const users = sqlAll(
    `SELECT u.id, u.kadi, u.isim, u.soyisim, u.aktiv, u.yasak, u.online, u.sontarih, u.resim, u.verified,
            u.mezuniyetyili, u.email, u.admin,
            COALESCE(es.score, 0) AS engagement_score,
            es.updated_at AS engagement_updated_at
     FROM uyeler u
     LEFT JOIN member_engagement_scores es ON es.user_id = u.id
     ${where}
     ORDER BY ${orderBy}
     LIMIT ?`,
    [...params, limit]
  );

  return {
    users,
    meta: {
      total,
      returned: users.length,
      filter,
      sort,
      withPhoto,
      verifiedOnly,
      onlineOnly,
      adminOnly,
      minScore: Number.isFinite(minScore) ? minScore : null,
      maxScore: Number.isFinite(maxScore) ? maxScore : null,
      q: q || ''
    }
  };
}

app.get('/api/admin/users/lists', requireAdmin, (req, res) => {
  res.json(queryAdminUsers(req.query));
});

app.get('/api/admin/users/search', requireAdmin, (req, res) => {
  const query = String(req.query.q || '').trim();
  const onlyWithPhoto = String(req.query.res || '') === '1';
  if (!query && !onlyWithPhoto) return res.status(400).send('Aranacak anahtar kelime girmedin.');
  const result = queryAdminUsers({
    ...req.query,
    q: query,
    photo: onlyWithPhoto ? '1' : req.query.photo,
    filter: 'all',
    limit: req.query.limit || 800,
    sort: req.query.sort || 'engagement_desc'
  });
  res.json(result);
});

app.get('/api/admin/users/:id', requireAdmin, (req, res) => {
  const user = sqlGet(
    `SELECT u.*, COALESCE(es.score, 0) AS engagement_score, es.updated_at AS engagement_updated_at
     FROM uyeler u
     LEFT JOIN member_engagement_scores es ON es.user_id = u.id
     WHERE u.id = ?`,
    [req.params.id]
  );
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
  scheduleEngagementRecalculation('admin_user_updated');
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
    member: uyedetaylogDir,
    app: appLogsDir
  };
  const dir = map[type] || hatalogDir;
  if (type === 'app' && !fs.existsSync(appLogFile)) {
    fs.writeFileSync(appLogFile, '', 'utf-8');
  }
  const from = parseDateInput(req.query.from || req.query.date_from);
  const to = parseDateInput(req.query.to || req.query.date_to);
  if (file) {
    const content = readLogFile(dir, file);
    if (!content) return res.status(404).send('Dosya Bulunamadı!');
    const filtered = filterLogContent(content, req.query || {});
    return res.json({
      file,
      content: filtered.content,
      total: filtered.total,
      matched: filtered.matched,
      returned: filtered.returned,
      offset: filtered.offset,
      limit: filtered.limit
    });
  }
  let files = listLogFiles(dir);
  if (from || to) {
    files = files.filter((f) => {
      const d = new Date(f.mtime);
      if (from && d < from) return false;
      if (to && d > to) return false;
      return true;
    });
  }
  res.json({ files });
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
  if (!Array.isArray(ids) || !ids.length) return res.status(400).send('Fotoğraf seçmelisiniz.');
  if (action === 'sil') {
    for (const id of ids) {
      const photo = sqlGet('SELECT * FROM album_foto WHERE id = ?', [id]);
      if (!photo) continue;
      const filePath = path.join(uploadsDir, 'album', photo.dosyaadi || '');
      if (photo.dosyaadi && fs.existsSync(filePath)) {
        try { fs.unlinkSync(filePath); } catch {}
      }
      sqlRun('DELETE FROM album_fotoyorum WHERE fotoid = ?', [id]);
      sqlRun('DELETE FROM album_foto WHERE id = ?', [id]);
    }
    return res.json({ ok: true, deleted: ids.length });
  }
  const activeValue = action === 'deaktiv' ? 0 : 1;
  for (const id of ids) {
    sqlRun('UPDATE album_foto SET aktif = ? WHERE id = ?', [activeValue, id]);
  }
  res.json({ ok: true });
});

app.put('/api/admin/album/photos/:id', requireAlbumAdmin, (req, res) => {
  const baslik = String(req.body?.baslik || '').trim();
  const aciklama = metinDuzenle(req.body?.aciklama || '');
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
  (async () => {
    const optimizedPath = await optimizeUploadedImage(req.file.path, {
      width: 960,
      height: 960,
      fit: 'inside',
      quality: 86,
      background: '#ffffff'
    });
    const filename = path.basename(optimizedPath || req.file.path);
    sqlRun('UPDATE uyeler SET resim = ? WHERE id = ?', [filename, req.session.userId]);
    res.json({ ok: true, photo: filename });
  })().catch(() => {
    res.status(500).send('Profil fotoğrafı işlenemedi.');
  });
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
  const gradYear = parseInt(String(req.query.gradYear || '0'), 10) || 0;
  const verifiedOnly = String(req.query.verified || '').trim() === '1';
  const withPhoto = String(req.query.withPhoto || '').trim() === '1';
  const onlineOnly = String(req.query.online || '').trim() === '1';
  const relation = String(req.query.relation || '').trim();
  const excludeSelf = String(req.query.excludeSelf || '').trim() === '1';
  const sort = String(req.query.sort || 'recommended').trim();
  const whereParts = [
    `COALESCE(CAST(aktiv AS INTEGER), 1) = 1`,
    `COALESCE(CAST(yasak AS INTEGER), 0) = 0`
  ];
  const params = [];
  if (excludeSelf) {
    whereParts.push('id != ?');
    params.push(req.session.userId);
  }
  if (term) {
    whereParts.push('(LOWER(kadi) LIKE LOWER(?) OR LOWER(isim) LIKE LOWER(?) OR LOWER(soyisim) LIKE LOWER(?) OR LOWER(meslek) LIKE LOWER(?) OR LOWER(email) LIKE LOWER(?))');
    params.push(...Array(5).fill(`%${term}%`));
  }
  if (gradYear > 0) {
    whereParts.push('CAST(COALESCE(mezuniyetyili, 0) AS INTEGER) = ?');
    params.push(gradYear);
  }
  if (verifiedOnly) {
    whereParts.push('COALESCE(CAST(verified AS INTEGER), 0) = 1');
  }
  if (withPhoto) {
    whereParts.push("resim IS NOT NULL AND TRIM(CAST(resim AS TEXT)) != '' AND LOWER(TRIM(CAST(resim AS TEXT))) != 'yok'");
  }
  if (onlineOnly) {
    whereParts.push('COALESCE(CAST(online AS INTEGER), 0) = 1');
  }
  if (relation === 'following') {
    whereParts.push('id IN (SELECT following_id FROM follows WHERE follower_id = ?)');
    params.push(req.session.userId);
  }
  if (relation === 'not_following') {
    whereParts.push('id NOT IN (SELECT following_id FROM follows WHERE follower_id = ?)');
    params.push(req.session.userId);
  }
  const where = whereParts.join(' AND ');
  const orderByMap = {
    name: 'u.isim ASC, u.soyisim ASC',
    recent: 'u.id DESC',
    online: 'COALESCE(CAST(u.online AS INTEGER), 0) DESC, u.isim ASC',
    year: 'CAST(COALESCE(u.mezuniyetyili, 0) AS INTEGER) DESC, u.isim ASC',
    engagement: 'COALESCE(es.score, 0) DESC, u.id DESC',
    recommended: 'COALESCE(es.score, 0) DESC, COALESCE(CAST(u.online AS INTEGER), 0) DESC, COALESCE(CAST(u.verified AS INTEGER), 0) DESC, u.id DESC'
  };
  const orderBy = orderByMap[sort] || orderByMap.name;

  const totalRow = sqlGet(`SELECT COUNT(*) AS cnt FROM uyeler WHERE ${where}`, params);
  const total = totalRow ? totalRow.cnt : 0;
  const pages = Math.max(Math.ceil(total / pageSize), 1);
  const safePage = Math.min(page, pages);
  const offset = (safePage - 1) * pageSize;
  const rows = sqlAll(`
    SELECT u.id, u.kadi, u.isim, u.soyisim, u.email, u.mailkapali, u.mezuniyetyili, u.dogumgun, u.dogumay, u.dogumyil,
           u.sehir, u.universite, u.meslek, u.websitesi, u.imza, u.resim, u.online, u.sontarih, u.verified
    FROM uyeler u
    LEFT JOIN member_engagement_scores es ON es.user_id = u.id
    WHERE ${where}
    ORDER BY ${orderBy}
    LIMIT ? OFFSET ?
  `, [...params, pageSize, offset]);

  const rangeRows = term ? [] : sqlAll('SELECT isim FROM uyeler WHERE aktiv = 1 AND yasak = 0 ORDER BY isim');
  const ranges = [];
  for (let i = 0; i < rangeRows.length; i += pageSize) {
    const start = rangeRows[i]?.isim ? rangeRows[i].isim.slice(0, 2) : '--';
    const end = rangeRows[Math.min(i + pageSize - 1, rangeRows.length - 1)]?.isim?.slice(0, 2) || '--';
    ranges.push({ start, end });
  }

  res.json({ rows, page: safePage, pages, total, ranges, pageSize, term, filters: { gradYear, verifiedOnly, withPhoto, onlineOnly, relation, sort } });
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
  const where = box === 'inbox'
    ? 'CAST(kime AS INTEGER) = CAST(? AS INTEGER) AND aktifgelen = 1'
    : 'CAST(kimden AS INTEGER) = CAST(? AS INTEGER) AND aktifgiden = 1';
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
  const q = String(req.query.q || '').trim().replace(/^@+/, '').replace(/'/g, '');
  const limit = Math.min(Math.max(parseInt(req.query.limit || '12', 10), 1), 50);
  if (!q) return res.json({ items: [] });
  const term = `%${q}%`;
  const rows = sqlAll(
    `SELECT id, kadi, isim, soyisim, resim, verified
     FROM uyeler
     WHERE COALESCE(CAST(yasak AS INTEGER), 0) = 0
       AND (
         aktiv IS NULL
         OR CAST(aktiv AS INTEGER) = 1
         OR LOWER(CAST(aktiv AS TEXT)) IN ('true', 'evet')
       )
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
  if (!sameUserId(row.kime, req.session.userId) && !sameUserId(row.kimden, req.session.userId)) {
    return res.status(403).send('Yetkisiz');
  }
  const sender = sqlGet('SELECT id, kadi, resim FROM uyeler WHERE id = ?', [normalizeUserId(row.kimden)]);
  const receiver = sqlGet('SELECT id, kadi, resim FROM uyeler WHERE id = ?', [normalizeUserId(row.kime)]);

  if (sameUserId(row.kime, req.session.userId) && row.yeni === 1) {
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

  const result = sqlRun(
    `INSERT INTO gelenkutusu (kime, kimden, aktifgelen, konu, mesaj, yeni, tarih, aktifgiden)
     VALUES (?, ?, 1, ?, ?, 1, ?, 1)`,
    [kime, req.session.userId, subject, body, now]
  );
  notifyMentions({
    text: req.body?.mesaj || '',
    sourceUserId: req.session.userId,
    entityId: result?.lastInsertRowid,
    type: 'mention_message',
    message: 'Mesajda senden bahsetti.',
    allowedUserIds: [kime]
  });

  res.status(201).json({ ok: true });
});

app.delete('/api/messages/:id', (req, res) => {
  if (!req.session.userId) return res.status(401).send('Login required');
  const row = sqlGet('SELECT * FROM gelenkutusu WHERE id = ?', [req.params.id]);
  if (!row) return res.status(404).send('Mesaj bulunamadı');
  if (!sameUserId(row.kime, req.session.userId) && !sameUserId(row.kimden, req.session.userId)) {
    return res.status(403).send('Yetkisiz');
  }
  if (sameUserId(row.kime, req.session.userId)) {
    sqlRun('UPDATE gelenkutusu SET aktifgelen = 0 WHERE id = ?', [row.id]);
  }
  if (sameUserId(row.kimden, req.session.userId)) {
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
}, async (req, res) => {
  const kat = String(req.body?.kat || '').trim();
  const baslik = String(req.body?.baslik || '').trim();
  const aciklama = metinDuzenle(req.body?.aciklama || '');

  if (!baslik) return res.status(400).send('Yüklemek üzere olduğun fotoğraf için bir başlık girmen gerekiyor.');
  if (!kat) return res.status(400).send('Kategori seçmelisin.');
  const category = sqlGet('SELECT * FROM album_kat WHERE id = ? AND aktif = 1', [kat]);
  if (!category) return res.status(400).send('Seçtiğin kategori bulunamadı.');
  if (!req.file?.filename) return res.status(400).send('Geçerli bir resim dosyası girmedin.');

  let storedFilename = req.file.filename;
  try {
    const optimizedPath = await optimizeUploadedImage(req.file.path, {
      width: 2200,
      height: 2200,
      fit: 'inside',
      quality: 86,
      background: '#ffffff'
    });
    storedFilename = path.basename(optimizedPath || req.file.path);
  } catch {
    // fallback to original upload
  }

  sqlRun('UPDATE album_kat SET sonekleme = ?, sonekleyen = ? WHERE id = ?', [new Date().toISOString(), req.session.userId, category.id]);
  sqlRun(
    `INSERT INTO album_foto (dosyaadi, katid, baslik, aciklama, aktif, ekleyenid, tarih, hit)
     VALUES (?, ?, ?, ?, 0, ?, ?, 0)`,
    [storedFilename, String(category.id), baslik, aciklama, req.session.userId, new Date().toISOString()]
  );

  res.json({ ok: true, file: storedFilename, categoryId: category.id });
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
  const comments = sqlAll(
    `SELECT c.id, c.uyeadi, c.yorum, c.tarih,
            u.id AS user_id, u.kadi, u.verified, u.resim, u.isim, u.soyisim
     FROM album_fotoyorum c
     LEFT JOIN uyeler u ON LOWER(u.kadi) = LOWER(c.uyeadi)
     WHERE c.fotoid = ?
     ORDER BY c.id DESC`,
    [row.id]
  );
  res.json({ row, category, comments });
});

app.get('/api/photos/:id/comments', (req, res) => {
  if (!req.session.userId) return res.status(401).send('Login required');
  const comments = sqlAll(
    `SELECT c.id, c.uyeadi, c.yorum, c.tarih,
            u.id AS user_id, u.kadi, u.verified, u.resim, u.isim, u.soyisim
     FROM album_fotoyorum c
     LEFT JOIN uyeler u ON LOWER(u.kadi) = LOWER(c.uyeadi)
     WHERE c.fotoid = ?
     ORDER BY c.id DESC`,
    [req.params.id]
  );
  res.json({ comments });
});

app.post('/api/photos/:id/comments', (req, res) => {
  if (!req.session.userId) return res.status(401).send('Login required');
  const photo = sqlGet('SELECT id, ekleyenid, aktif FROM album_foto WHERE id = ?', [req.params.id]);
  if (!photo) return res.status(404).send('Fotoğraf bulunamadı');
  if (Number(photo.aktif || 0) !== 1) return res.status(400).send('Fotoğraf yoruma açık değil');
  const yorumRaw = String(req.body?.yorum || '');
  const yorum = metinDuzenle(yorumRaw);
  if (!yorum) return res.status(400).send('Yorum girmedin');
  const user = getCurrentUser(req);
  sqlRun('INSERT INTO album_fotoyorum (fotoid, uyeadi, yorum, tarih) VALUES (?, ?, ?, ?)', [
    photo.id,
    user?.kadi || 'Misafir',
    yorum,
    new Date().toISOString()
  ]);
  const ownerId = normalizeUserId(photo.ekleyenid);
  if (ownerId && !sameUserId(ownerId, req.session.userId)) {
    addNotification({
      userId: ownerId,
      type: 'photo_comment',
      sourceUserId: req.session.userId,
      entityId: photo.id,
      message: 'Fotoğrafına yorum yaptı.'
    });
  }
  notifyMentions({
    text: yorumRaw,
    sourceUserId: req.session.userId,
    entityId: photo.id,
    type: 'mention_photo',
    message: 'Fotoğraf yorumunda senden bahsetti.'
  });
  res.json({ ok: true });
});

// Modern (sdal_new) social APIs
app.get('/api/new/feed', requireAuth, (req, res) => {
  const limit = Math.min(Math.max(parseInt(req.query.limit || '20', 10), 1), 50);
  const offset = Math.max(parseInt(req.query.offset || '0', 10), 0);
  const scope = String(req.query.scope || 'all');
  let where = 'WHERE p.group_id IS NULL';
  const params = [];
  if (scope === 'following') {
    where = 'WHERE p.group_id IS NULL AND (p.user_id = ? OR p.user_id IN (SELECT following_id FROM follows WHERE follower_id = ?))';
    params.push(req.session.userId, req.session.userId);
  }
  const orderBy = scope === 'popular'
    ? `(
        COALESCE((SELECT COUNT(*) FROM post_likes pl WHERE pl.post_id = p.id), 0) * 2.4
        + COALESCE((SELECT COUNT(*) FROM post_comments pc WHERE pc.post_id = p.id), 0) * 3.2
        + COALESCE(es.score, 0) * 0.18
        - COALESCE(MIN((julianday('now') - julianday(COALESCE(NULLIF(p.created_at, ''), datetime('now')))) * 24.0, 168), 0) * 0.22
      ) DESC, p.id DESC`
    : `(
        COALESCE(es.score, 0) * 0.72
        - COALESCE(MIN((julianday('now') - julianday(COALESCE(NULLIF(p.created_at, ''), datetime('now')))) * 24.0, 72), 0) * 0.45
        + CASE WHEN p.user_id = ? THEN 4 ELSE 0 END
      ) DESC, p.id DESC`;
  const queryParams = scope === 'popular'
    ? [...params, limit, offset]
    : [...params, req.session.userId, limit, offset];
  const rows = sqlAll(
    `SELECT p.id, p.user_id, p.content, p.image, p.created_at, p.group_id,
            u.kadi, u.isim, u.soyisim, u.resim, u.verified
     FROM posts p
     LEFT JOIN uyeler u ON u.id = p.user_id
     LEFT JOIN member_engagement_scores es ON es.user_id = p.user_id
     ${where}
     ORDER BY ${orderBy}
     LIMIT ? OFFSET ?`,
    queryParams
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
    })),
    hasMore: rows.length === limit
  });
});

app.post('/api/new/posts', requireAuth, (req, res) => {
  const content = metinDuzenle(req.body?.content || '');
  const image = req.body?.image || null;
  const groupId = req.body?.group_id || null;
  if (isFormattedContentEmpty(content) && !image) return res.status(400).send('İçerik boş olamaz.');
  const now = new Date().toISOString();
  const result = sqlRun('INSERT INTO posts (user_id, content, image, created_at, group_id) VALUES (?, ?, ?, ?, ?)', [
    req.session.userId,
    content,
    image,
    now,
    groupId
  ]);
  notifyMentions({
    text: req.body?.content || '',
    sourceUserId: req.session.userId,
    entityId: result?.lastInsertRowid,
    type: 'mention_post',
    message: 'Gönderide senden bahsetti.'
  });
  scheduleEngagementRecalculation('post_created');
  res.json({ ok: true, id: result?.lastInsertRowid });
});

app.post('/api/new/posts/upload', requireAuth, postUpload.single('image'), async (req, res) => {
  const content = metinDuzenle(req.body?.content || '');
  const filter = req.body?.filter || '';
  const groupId = req.body?.group_id || null;
  let finalImagePath = req.file?.path || null;
  if (finalImagePath && filter) {
    try {
      await applyImageFilter(finalImagePath, filter);
    } catch {
      // ignore filter errors
    }
  }
  if (finalImagePath) {
    try {
      finalImagePath = await optimizeUploadedImage(finalImagePath, {
        width: 1900,
        height: 1900,
        fit: 'inside',
        quality: 84,
        background: '#ffffff'
      });
    } catch {
      // fallback to original path
    }
  }
  const image = finalImagePath ? toUploadUrl(finalImagePath) : null;
  if (isFormattedContentEmpty(content) && !image) return res.status(400).send('İçerik boş olamaz.');
  const now = new Date().toISOString();
  const result = sqlRun('INSERT INTO posts (user_id, content, image, created_at, group_id) VALUES (?, ?, ?, ?, ?)', [
    req.session.userId,
    content,
    image,
    now,
    groupId
  ]);
  notifyMentions({
    text: req.body?.content || '',
    sourceUserId: req.session.userId,
    entityId: result?.lastInsertRowid,
    type: 'mention_post',
    message: 'Gönderide senden bahsetti.'
  });
  scheduleEngagementRecalculation('post_created');
  res.json({ ok: true, id: result?.lastInsertRowid, image });
});

app.post('/api/new/posts/:id/like', requireAuth, (req, res) => {
  const postId = req.params.id;
  const postRow = sqlGet('SELECT id, user_id, group_id FROM posts WHERE id = ?', [postId]);
  if (!postRow) return res.status(404).send('Gönderi bulunamadı.');
  if (postRow.group_id) {
    const user = getCurrentUser(req);
    if (user?.admin !== 1) {
      const member = getGroupMember(postRow.group_id, req.session.userId);
      if (!member) return res.status(403).send('Bu grup içeriğine erişim için üyelik gerekli.');
    }
  }
  const existing = sqlGet('SELECT id FROM post_likes WHERE post_id = ? AND user_id = ?', [postId, req.session.userId]);
  if (existing) {
    sqlRun('DELETE FROM post_likes WHERE id = ?', [existing.id]);
    scheduleEngagementRecalculation('post_like_changed');
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
  scheduleEngagementRecalculation('post_like_changed');
  return res.json({ ok: true, liked: true });
});

app.get('/api/new/posts/:id/comments', requireAuth, (req, res) => {
  const post = sqlGet('SELECT id, group_id FROM posts WHERE id = ?', [req.params.id]);
  if (!post) return res.status(404).send('Gönderi bulunamadı.');
  if (post.group_id) {
    const user = getCurrentUser(req);
    if (user?.admin !== 1) {
      const member = getGroupMember(post.group_id, req.session.userId);
      if (!member) return res.status(403).send('Bu grup içeriğine erişim için üyelik gerekli.');
    }
  }
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
  const postTarget = sqlGet('SELECT id, user_id, group_id FROM posts WHERE id = ?', [req.params.id]);
  if (!postTarget) return res.status(404).send('Gönderi bulunamadı.');
  if (postTarget.group_id) {
    const user = getCurrentUser(req);
    if (user?.admin !== 1) {
      const member = getGroupMember(postTarget.group_id, req.session.userId);
      if (!member) return res.status(403).send('Bu grup içeriğine erişim için üyelik gerekli.');
    }
  }
  const comment = metinDuzenle(req.body?.comment || '');
  if (isFormattedContentEmpty(comment)) return res.status(400).send('Yorum boş olamaz.');
  const now = new Date().toISOString();
  sqlRun('INSERT INTO post_comments (post_id, user_id, comment, created_at) VALUES (?, ?, ?, ?)', [
    req.params.id,
    req.session.userId,
    comment,
    now
  ]);
  if (postTarget && postTarget.user_id !== req.session.userId) {
    addNotification({
      userId: postTarget.user_id,
      type: 'comment',
      sourceUserId: req.session.userId,
      entityId: req.params.id,
      message: 'Gönderine yorum yaptı.'
    });
  }
  notifyMentions({
    text: req.body?.comment || '',
    sourceUserId: req.session.userId,
    entityId: req.params.id,
    type: 'mention_post',
    message: 'Yorumda senden bahsetti.'
  });
  scheduleEngagementRecalculation('post_comment_created');
  res.json({ ok: true });
});

app.get('/api/new/notifications', requireAuth, (req, res) => {
  const limit = Math.min(Math.max(parseInt(req.query.limit || '20', 10), 1), 100);
  const offset = Math.max(parseInt(req.query.offset || '0', 10), 0);
  const rows = sqlAll(
    `SELECT n.id, n.type, n.entity_id, n.source_user_id, n.message, n.read_at, n.created_at,
            u.kadi, u.isim, u.soyisim, u.resim, u.verified
     FROM notifications n
     LEFT JOIN uyeler u ON u.id = n.source_user_id
     WHERE n.user_id = ?
     ORDER BY n.id DESC
     LIMIT ? OFFSET ?`,
    [req.session.userId, limit, offset]
  );
  const items = rows.map((row) => {
    if (row.type !== 'group_invite' || !row.entity_id) {
      return row;
    }
    const invite = sqlGet(
      `SELECT status
       FROM group_invites
       WHERE group_id = ? AND invited_user_id = ?
       ORDER BY id DESC
       LIMIT 1`,
      [row.entity_id, req.session.userId]
    );
    return {
      ...row,
      invite_status: String(invite?.status || 'pending')
    };
  });
  res.json({ items, hasMore: items.length === limit });
});

app.post('/api/new/notifications/read', requireAuth, (req, res) => {
  sqlRun('UPDATE notifications SET read_at = ? WHERE user_id = ? AND read_at IS NULL', [
    new Date().toISOString(),
    req.session.userId
  ]);
  res.json({ ok: true });
});

app.post('/api/new/translate', requireAuth, async (req, res) => {
  const text = String(req.body?.text || '').trim();
  const target = String(req.body?.target || 'tr').trim().toLowerCase();
  const source = String(req.body?.source || 'auto').trim().toLowerCase();
  const supported = new Set(['tr', 'en', 'de', 'fr']);
  if (typeof fetch !== 'function') return res.status(501).send('Sunucu çeviri servisini desteklemiyor.');
  if (!supported.has(target)) return res.status(400).send('Hedef dil desteklenmiyor.');
  if (!text) return res.json({ translatedText: '', sourceLanguage: source || 'auto' });
  const sliced = text.slice(0, 5000);
  try {
    const params = new URLSearchParams({
      client: 'gtx',
      sl: source || 'auto',
      tl: target,
      dt: 't',
      q: sliced
    });
    const response = await fetch(`https://translate.googleapis.com/translate_a/single?${params.toString()}`, {
      method: 'GET',
      headers: { 'User-Agent': 'SDAL-New/1.0' }
    });
    if (!response.ok) return res.status(502).send('Çeviri servisine erişilemedi.');
    const payload = await response.json();
    const segments = Array.isArray(payload?.[0]) ? payload[0] : [];
    const translatedText = segments.map((seg) => (Array.isArray(seg) ? String(seg[0] || '') : '')).join('');
    if (!translatedText) return res.status(502).send('Çeviri sonucu alınamadı.');
    return res.json({
      translatedText,
      sourceLanguage: String(payload?.[2] || source || 'auto')
    });
  } catch (err) {
    writeAppLog('warn', 'translate_failed', {
      userId: req.session?.userId || null,
      target,
      message: err?.message || 'unknown_error'
    });
    return res.status(502).send('Çeviri servisine ulaşılamadı.');
  }
});

const STORY_TTL_MS = 24 * 60 * 60 * 1000;

function parseIsoMs(value) {
  const ms = Date.parse(String(value || ''));
  return Number.isFinite(ms) ? ms : null;
}

function storyTiming(row, nowMs = Date.now()) {
  const createdMs = parseIsoMs(row.created_at) ?? nowMs;
  const expiresMs = parseIsoMs(row.expires_at) ?? (createdMs + STORY_TTL_MS);
  return {
    createdAt: row.created_at || new Date(createdMs).toISOString(),
    expiresAt: new Date(expiresMs).toISOString(),
    isExpired: expiresMs <= nowMs
  };
}

function parseStoryId(value) {
  const storyId = Number(value);
  if (!Number.isInteger(storyId) || storyId <= 0) return null;
  return storyId;
}

app.get('/api/new/stories', requireAuth, (req, res) => {
  const nowMs = Date.now();
  const nowIso = new Date(nowMs).toISOString();
  const rows = sqlAll(
    `SELECT s.id, s.user_id, s.image, s.caption, s.created_at, s.expires_at,
            u.kadi, u.isim, u.soyisim, u.resim, u.verified
     FROM stories s
     LEFT JOIN uyeler u ON u.id = s.user_id
     WHERE s.expires_at IS NULL OR s.expires_at > ?
     ORDER BY s.created_at DESC`,
    [nowIso]
  );
  const viewed = sqlAll('SELECT story_id FROM story_views WHERE user_id = ?', [req.session.userId]);
  const viewedSet = new Set(viewed.map((v) => Number(v.story_id)));
  const items = rows
    .map((r) => {
      const timing = storyTiming(r, nowMs);
      return {
        id: r.id,
        image: r.image,
        caption: r.caption,
        createdAt: timing.createdAt,
        expiresAt: timing.expiresAt,
        isExpired: timing.isExpired,
        author: {
          id: r.user_id,
          kadi: r.kadi,
          isim: r.isim,
          soyisim: r.soyisim,
          resim: r.resim,
          verified: r.verified
        },
        viewed: viewedSet.has(Number(r.id))
      };
    })
    .filter((story) => !story.isExpired);
  res.json({ items });
});

app.get('/api/new/stories/mine', requireAuth, (req, res) => {
  const rows = sqlAll(
    `SELECT s.id, s.image, s.caption, s.created_at, s.expires_at,
            COUNT(v.id) AS view_count
     FROM stories s
     LEFT JOIN story_views v ON v.story_id = s.id
     WHERE s.user_id = ?
     GROUP BY s.id
     ORDER BY s.created_at DESC`,
    [req.session.userId]
  );
  const nowMs = Date.now();
  res.json({
    items: rows.map((row) => {
      const timing = storyTiming(row, nowMs);
      return {
        id: row.id,
        image: row.image,
        caption: row.caption,
        createdAt: timing.createdAt,
        expiresAt: timing.expiresAt,
        isExpired: timing.isExpired,
        viewCount: Number(row.view_count || 0)
      };
    })
  });
});

app.get('/api/new/stories/user/:id', requireAuth, (req, res) => {
  const userId = Number(req.params.id || 0);
  if (!Number.isInteger(userId) || userId <= 0) return res.status(400).send('Geçersiz üye kimliği.');
  const includeExpired = String(req.query.includeExpired || '0') === '1';
  const nowMs = Date.now();
  const nowIso = new Date(nowMs).toISOString();

  const rows = sqlAll(
    `SELECT s.id, s.user_id, s.image, s.caption, s.created_at, s.expires_at,
            u.kadi, u.isim, u.soyisim, u.resim, u.verified
     FROM stories s
     LEFT JOIN uyeler u ON u.id = s.user_id
     WHERE s.user_id = ?
       AND (? = 1 OR s.expires_at IS NULL OR s.expires_at > ?)
     ORDER BY s.created_at DESC`,
    [userId, includeExpired ? 1 : 0, nowIso]
  );

  const viewed = sqlAll('SELECT story_id FROM story_views WHERE user_id = ?', [req.session.userId]);
  const viewedSet = new Set(viewed.map((v) => Number(v.story_id)));
  const items = rows.map((r) => {
    const timing = storyTiming(r, nowMs);
    return {
      id: r.id,
      image: r.image,
      caption: r.caption,
      createdAt: timing.createdAt,
      expiresAt: timing.expiresAt,
      isExpired: timing.isExpired,
      author: {
        id: r.user_id,
        kadi: r.kadi,
        isim: r.isim,
        soyisim: r.soyisim,
        resim: r.resim,
        verified: r.verified
      },
      viewed: viewedSet.has(Number(r.id))
    };
  });

  res.json({ items });
});

app.post('/api/new/stories/upload', requireAuth, storyUpload.single('image'), async (req, res) => {
  if (!req.file) return res.status(400).send('Görsel seçilmedi.');
  try {
    const caption = metinDuzenle(req.body?.caption || '');
    const outputName = `story_${req.session.userId}_${Date.now()}.webp`;
    const outputPath = path.join(storyDir, outputName);

    // Story media standard: keep full image visible on 9:16 canvas (no cropping).
    await sharp(req.file.path)
      .rotate()
      .resize(1080, 1920, { fit: 'contain', background: '#0b0f16', withoutEnlargement: true })
      .webp({ quality: 82, effort: 4 })
      .toFile(outputPath);

    try {
      if (req.file.path !== outputPath && fs.existsSync(req.file.path)) fs.unlinkSync(req.file.path);
    } catch {
      // no-op
    }

    const image = `/uploads/stories/${outputName}`;
    const now = new Date();
    const expires = new Date(now.getTime() + STORY_TTL_MS);
    const result = sqlRun('INSERT INTO stories (user_id, image, caption, created_at, expires_at) VALUES (?, ?, ?, ?, ?)', [
      req.session.userId,
      image,
      caption,
      now.toISOString(),
      expires.toISOString()
    ]);
    scheduleEngagementRecalculation('story_created');
    res.json({ ok: true, id: result?.lastInsertRowid, image });
  } catch (err) {
    writeAppLog('error', 'story_upload_failed', {
      userId: req.session?.userId || null,
      message: err?.message || 'unknown_error'
    });
    return res.status(500).send('Hikaye yükleme sırasında hata oluştu.');
  }
});

function updateStoryCaption(req, res) {
  const storyId = parseStoryId(req.params.id);
  if (!storyId) return res.status(400).send('Geçersiz hikaye kimliği.');
  const story = sqlGet('SELECT id FROM stories WHERE id = ? AND user_id = ?', [storyId, req.session.userId]);
  if (!story) return res.status(404).send('Hikaye bulunamadı.');
  const caption = metinDuzenle(req.body?.caption || '');
  sqlRun('UPDATE stories SET caption = ? WHERE id = ?', [caption, storyId]);
  res.json({ ok: true });
}

function deleteStory(req, res) {
  const storyId = parseStoryId(req.params.id);
  if (!storyId) return res.status(400).send('Geçersiz hikaye kimliği.');
  const story = sqlGet('SELECT id FROM stories WHERE id = ? AND user_id = ?', [storyId, req.session.userId]);
  if (!story) return res.status(404).send('Hikaye bulunamadı.');
  sqlRun('DELETE FROM story_views WHERE story_id = ?', [storyId]);
  sqlRun('DELETE FROM stories WHERE id = ?', [storyId]);
  res.json({ ok: true });
}

app.patch('/api/new/stories/:id', requireAuth, updateStoryCaption);
app.delete('/api/new/stories/:id', requireAuth, deleteStory);
app.post('/api/new/stories/:id/edit', requireAuth, updateStoryCaption);
app.post('/api/new/stories/:id/delete', requireAuth, deleteStory);
app.post('/api/new/stories/:id', requireAuth, updateStoryCaption);
app.post('/api/new/stories/:id/remove', requireAuth, deleteStory);

app.post('/api/new/stories/:id/repost', requireAuth, (req, res) => {
  const storyId = parseStoryId(req.params.id);
  if (!storyId) return res.status(400).send('Geçersiz hikaye kimliği.');
  const story = sqlGet('SELECT id, user_id, image, caption, created_at, expires_at FROM stories WHERE id = ?', [storyId]);
  if (!story || Number(story.user_id) !== Number(req.session.userId)) {
    return res.status(404).send('Hikaye bulunamadı.');
  }
  const timing = storyTiming(story);
  if (!timing.isExpired) {
    return res.status(400).send('Sadece süresi dolan hikayeler yeniden paylaşılabilir.');
  }
  const now = new Date();
  const expires = new Date(now.getTime() + STORY_TTL_MS);
  const result = sqlRun(
    'INSERT INTO stories (user_id, image, caption, created_at, expires_at) VALUES (?, ?, ?, ?, ?)',
    [req.session.userId, story.image, story.caption || '', now.toISOString(), expires.toISOString()]
  );
  scheduleEngagementRecalculation('story_created');
  res.json({ ok: true, id: result?.lastInsertRowid, image: story.image });
});

app.post('/api/new/stories/:id/view', requireAuth, (req, res) => {
  const storyId = parseStoryId(req.params.id);
  if (!storyId) return res.status(400).send('Geçersiz hikaye kimliği.');
  const story = sqlGet('SELECT id, created_at, expires_at FROM stories WHERE id = ?', [storyId]);
  if (!story) return res.status(404).send('Hikaye bulunamadı.');
  const timing = storyTiming(story);
  if (timing.isExpired) return res.status(400).send('Hikaye süresi dolmuş.');
  const existing = sqlGet('SELECT id FROM story_views WHERE story_id = ? AND user_id = ?', [storyId, req.session.userId]);
  if (!existing) {
    sqlRun('INSERT INTO story_views (story_id, user_id, created_at) VALUES (?, ?, ?)', [
      storyId,
      req.session.userId,
      new Date().toISOString()
    ]);
    scheduleEngagementRecalculation('story_viewed');
  }
  res.json({ ok: true });
});

app.post('/api/new/follow/:id', requireAuth, (req, res) => {
  const targetId = req.params.id;
  if (String(targetId) === String(req.session.userId)) return res.status(400).send('Kendini takip edemezsin.');
  const existing = sqlGet('SELECT id FROM follows WHERE follower_id = ? AND following_id = ?', [req.session.userId, targetId]);
  if (existing) {
    sqlRun('DELETE FROM follows WHERE id = ?', [existing.id]);
    scheduleEngagementRecalculation('follow_changed');
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
  scheduleEngagementRecalculation('follow_changed');
  return res.json({ ok: true, following: true });
});

app.get('/api/new/follows', requireAuth, (req, res) => {
  const limit = Math.min(Math.max(parseInt(req.query.limit || '30', 10), 1), 100);
  const offset = Math.max(parseInt(req.query.offset || '0', 10), 0);
  const sort = String(req.query.sort || 'engagement').trim().toLowerCase();
  const orderBy = sort === 'followed_at'
    ? 'COALESCE(NULLIF(f.created_at, \'\'), datetime(\'now\')) DESC, f.id DESC'
    : 'COALESCE(es.score, 0) DESC, COALESCE(NULLIF(f.created_at, \'\'), datetime(\'now\')) DESC, f.id DESC';
  const rows = sqlAll(
    `SELECT f.following_id, f.created_at AS followed_at, u.kadi, u.isim, u.soyisim, u.resim,
            COALESCE(es.score, 0) AS engagement_score
     FROM follows f
     LEFT JOIN uyeler u ON u.id = f.following_id
     LEFT JOIN member_engagement_scores es ON es.user_id = f.following_id
     WHERE f.follower_id = ?
     ORDER BY ${orderBy}
     LIMIT ? OFFSET ?`,
    [req.session.userId, limit, offset]
  );
  res.json({ items: rows, hasMore: rows.length === limit });
});

app.get('/api/new/admin/follows/:userId', requireAdmin, (req, res) => {
  const targetUserId = Number(req.params.userId || 0);
  if (!Number.isInteger(targetUserId) || targetUserId <= 0) return res.status(400).send('Geçersiz üye kimliği.');
  const limit = Math.min(Math.max(parseInt(req.query.limit || '40', 10), 1), 200);
  const offset = Math.max(parseInt(req.query.offset || '0', 10), 0);

  const user = sqlGet('SELECT id, kadi, isim, soyisim FROM uyeler WHERE id = ?', [targetUserId]);
  if (!user) return res.status(404).send('Üye bulunamadı.');

  const follows = sqlAll(
    `SELECT f.id, f.following_id, f.created_at AS followed_at,
            u.kadi, u.isim, u.soyisim, u.resim, u.verified
     FROM follows f
     LEFT JOIN uyeler u ON u.id = f.following_id
     WHERE f.follower_id = ?
     ORDER BY COALESCE(NULLIF(f.created_at, ''), datetime('now')) DESC, f.id DESC
     LIMIT ? OFFSET ?`,
    [targetUserId, limit, offset]
  );

  const items = follows.map((row) => {
    const targetKadi = String(row.kadi || '').trim();
    const messageCount = sqlGet(
      'SELECT COUNT(*) AS cnt FROM gelenkutusu WHERE kimden = ? AND kime = ?',
      [targetUserId, row.following_id]
    )?.cnt || 0;
    const quoteCount = targetKadi
      ? (
        (sqlGet('SELECT COUNT(*) AS cnt FROM posts WHERE user_id = ? AND LOWER(COALESCE(content, \'\')) LIKE LOWER(?)', [
          targetUserId,
          `%@${targetKadi}%`
        ])?.cnt || 0)
        + (sqlGet('SELECT COUNT(*) AS cnt FROM post_comments WHERE user_id = ? AND LOWER(COALESCE(comment, \'\')) LIKE LOWER(?)', [
          targetUserId,
          `%@${targetKadi}%`
        ])?.cnt || 0)
      )
      : 0;
    const recentMessages = sqlAll(
      `SELECT id, konu, mesaj, tarih
       FROM gelenkutusu
       WHERE kimden = ? AND kime = ?
       ORDER BY id DESC
       LIMIT 3`,
      [targetUserId, row.following_id]
    );
    const recentQuotes = targetKadi
      ? sqlAll(
        `SELECT id, content, created_at, 'post' AS source
         FROM posts
         WHERE user_id = ? AND LOWER(COALESCE(content, '')) LIKE LOWER(?)
         ORDER BY id DESC
         LIMIT 3`,
        [targetUserId, `%@${targetKadi}%`]
      )
      : [];
    return {
      ...row,
      messageCount: Number(messageCount || 0),
      quoteCount: Number(quoteCount || 0),
      recentMessages,
      recentQuotes
    };
  });

  res.json({
    user,
    items,
    hasMore: items.length === limit
  });
});

app.get('/api/new/explore/suggestions', requireAuth, (req, res) => {
  const limit = Math.min(Math.max(parseInt(req.query.limit || '12', 10), 1), 40);
  const offset = Math.max(parseInt(req.query.offset || '0', 10), 0);
  const me = sqlGet(
    `SELECT id, mezuniyetyili, sehir, universite, meslek
     FROM uyeler
     WHERE id = ?`,
    [req.session.userId]
  );
  if (!me) return res.json({ items: [] });

  const followed = sqlAll('SELECT following_id FROM follows WHERE follower_id = ?', [req.session.userId]);
  const followedSet = new Set(followed.map((r) => Number(r.following_id)));

  const iFollowFollowers = sqlAll(
    `SELECT f2.following_id AS user_id, COUNT(*) AS cnt
     FROM follows f1
     JOIN follows f2 ON f2.follower_id = f1.following_id
     WHERE f1.follower_id = ?
     GROUP BY f2.following_id`,
    [req.session.userId]
  );
  const secondDegreeMap = new Map(iFollowFollowers.map((r) => [Number(r.user_id), Number(r.cnt || 0)]));

  const followsMe = sqlAll('SELECT follower_id FROM follows WHERE following_id = ?', [req.session.userId]);
  const followsMeSet = new Set(followsMe.map((r) => Number(r.follower_id)));
  const engagementRows = sqlAll('SELECT user_id, score FROM member_engagement_scores');
  const engagementMap = new Map(engagementRows.map((r) => [Number(r.user_id), Number(r.score || 0)]));

  const candidates = sqlAll(
    `SELECT id, kadi, isim, soyisim, resim, verified, mezuniyetyili, sehir, universite, meslek, online
     FROM uyeler
     WHERE COALESCE(CAST(aktiv AS INTEGER), 1) = 1
       AND COALESCE(CAST(yasak AS INTEGER), 0) = 0
       AND id != ?`,
    [req.session.userId]
  );

  const scored = [];
  for (const c of candidates) {
    const cid = Number(c.id);
    if (!cid) continue;
    if (followedSet.has(cid)) continue;
    let score = 0;
    const reasons = [];

    const secondDegree = secondDegreeMap.get(cid) || 0;
    if (secondDegree > 0) {
      score += Math.min(secondDegree * 18, 54);
      reasons.push(`${secondDegree} ortak baglanti`);
    }

    if (Number(c.mezuniyetyili || 0) > 0 && String(c.mezuniyetyili) === String(me.mezuniyetyili || '')) {
      score += 22;
      reasons.push('Ayni mezuniyet yili');
    }
    if (me.sehir && c.sehir && String(me.sehir).trim() && String(me.sehir).trim().toLowerCase() === String(c.sehir).trim().toLowerCase()) {
      score += 8;
      reasons.push('Ayni sehir');
    }
    if (me.universite && c.universite && String(me.universite).trim() && String(me.universite).trim().toLowerCase() === String(c.universite).trim().toLowerCase()) {
      score += 8;
      reasons.push('Ayni universite');
    }
    if (me.meslek && c.meslek && String(me.meslek).trim() && String(me.meslek).trim().toLowerCase() === String(c.meslek).trim().toLowerCase()) {
      score += 5;
      reasons.push('Benzer meslek');
    }
    if (followsMeSet.has(cid)) {
      score += 10;
      reasons.push('Seni takip ediyor');
    }
    const engagementScore = Number(engagementMap.get(cid) || 0);
    if (engagementScore > 0) {
      score += Math.min(20, engagementScore * 0.2);
      if (engagementScore >= 70) reasons.push('Toplulukta aktif');
    }
    if (Number(c.verified || 0) === 1) score += 2;
    if (Number(c.online || 0) === 1) score += 1;

    scored.push({
      ...c,
      score,
      reasons: reasons.slice(0, 3)
    });
  }

  scored.sort((a, b) => {
    if (b.score !== a.score) return b.score - a.score;
    if (Number(b.online || 0) !== Number(a.online || 0)) return Number(b.online || 0) - Number(a.online || 0);
    if (Number(b.verified || 0) !== Number(a.verified || 0)) return Number(b.verified || 0) - Number(a.verified || 0);
    return Number(b.id || 0) - Number(a.id || 0);
  });

  const items = scored.slice(offset, offset + limit).map((u) => ({
    id: u.id,
    kadi: u.kadi,
    isim: u.isim,
    soyisim: u.soyisim,
    resim: u.resim,
    verified: u.verified,
    mezuniyetyili: u.mezuniyetyili,
    online: u.online,
    reasons: u.reasons
  }));
  res.json({ items, hasMore: offset + items.length < scored.length, total: scored.length });
});

app.get('/api/new/messages/unread', requireAuth, (req, res) => {
  const row = sqlGet(
    'SELECT COUNT(*) AS cnt FROM gelenkutusu WHERE kime = ? AND aktifgelen = 1 AND yeni = 1',
    [req.session.userId]
  );
  res.json({ count: row?.cnt || 0 });
});

app.get('/api/new/online-members', requireAuth, (req, res) => {
  const limit = Math.min(Math.max(parseInt(req.query.limit || '12', 10), 1), 80);
  const items = listOnlineMembers({
    limit,
    excludeUserId: String(req.query.excludeSelf || '1') === '1' ? req.session.userId : null
  });
  res.json({ items, count: items.length, now: new Date().toISOString() });
});

app.get('/api/new/groups', requireAuth, (req, res) => {
  const limit = Math.min(Math.max(parseInt(req.query.limit || '20', 10), 1), 100);
  const offset = Math.max(parseInt(req.query.offset || '0', 10), 0);
  const groups = sqlAll('SELECT * FROM groups ORDER BY id DESC');
  const memberCounts = sqlAll('SELECT group_id, COUNT(*) AS cnt FROM group_members GROUP BY group_id');
  const membership = sqlAll('SELECT group_id, role FROM group_members WHERE user_id = ?', [req.session.userId]);
  const pending = sqlAll(
    `SELECT group_id
     FROM group_join_requests
     WHERE user_id = ? AND status = 'pending'`,
    [req.session.userId]
  );
  const invites = sqlAll(
    `SELECT group_id
     FROM group_invites
     WHERE invited_user_id = ? AND status = 'pending'`,
    [req.session.userId]
  );
  const user = getCurrentUser(req);
  const isAdmin = user?.admin === 1;
  const countMap = new Map(memberCounts.map((c) => [c.group_id, c.cnt]));
  const memberMap = new Map(membership.map((m) => [m.group_id, m.role]));
  const pendingSet = new Set(pending.map((p) => p.group_id));
  const inviteSet = new Set(invites.map((v) => v.group_id));
  const slice = groups.slice(offset, offset + limit);
  res.json({
    items: slice.map((g) => ({
      ...g,
      visibility: normalizeGroupVisibility(g.visibility),
      show_contact_hint: Number(g.show_contact_hint || 0),
      members: countMap.get(g.id) || 0,
      joined: memberMap.has(g.id),
      pending: pendingSet.has(g.id),
      invited: inviteSet.has(g.id),
      myRole: memberMap.get(g.id) || null,
      membershipStatus: memberMap.has(g.id) ? 'member' : (inviteSet.has(g.id) ? 'invited' : (pendingSet.has(g.id) ? 'pending' : 'none'))
    })),
    hasMore: offset + slice.length < groups.length
  });
});

app.post('/api/new/groups', requireAuth, (req, res) => {
  const name = String(req.body?.name || '').trim();
  if (!name) return res.status(400).send('Grup adı gerekli.');
  const description = metinDuzenle(req.body?.description || '');
  const now = new Date().toISOString();
  const result = sqlRun('INSERT INTO groups (name, description, cover_image, owner_id, created_at, visibility) VALUES (?, ?, ?, ?, ?, ?)', [
    name,
    description,
    req.body?.cover_image || null,
    req.session.userId,
    now,
    'public'
  ]);
  const groupId = result?.lastInsertRowid;
  sqlRun('INSERT INTO group_members (group_id, user_id, role, created_at) VALUES (?, ?, ?, ?)', [
    groupId,
    req.session.userId,
    'owner',
    now
  ]);
  notifyMentions({
    text: description,
    sourceUserId: req.session.userId,
    entityId: groupId,
    type: 'mention_group',
    message: 'Yeni grup açıklamasında senden bahsetti.'
  });
  res.json({ ok: true, id: groupId });
});

app.post('/api/new/groups/:id/join', requireAuth, (req, res) => {
  const groupId = req.params.id;
  const group = sqlGet('SELECT id, name, visibility FROM groups WHERE id = ?', [groupId]);
  if (!group) return res.status(404).send('Grup bulunamadı.');
  const user = getCurrentUser(req);
  const isAdmin = user?.admin === 1;
  const pendingInvite = sqlGet(
    `SELECT id
     FROM group_invites
     WHERE group_id = ? AND invited_user_id = ? AND status = 'pending'`,
    [groupId, req.session.userId]
  );

  const existingMember = getGroupMember(groupId, req.session.userId);
  if (existingMember) {
    if (existingMember.role === 'owner') return res.status(400).send('Grup sahibi gruptan ayrılamaz.');
    sqlRun('DELETE FROM group_members WHERE group_id = ? AND user_id = ?', [groupId, req.session.userId]);
    return res.json({ ok: true, joined: false, pending: false, membershipStatus: 'none' });
  }

  if (pendingInvite) {
    sqlRun('INSERT INTO group_members (group_id, user_id, role, created_at) VALUES (?, ?, ?, ?)', [
      groupId,
      req.session.userId,
      'member',
      new Date().toISOString()
    ]);
    sqlRun('UPDATE group_invites SET status = ?, responded_at = ? WHERE id = ?', ['accepted', new Date().toISOString(), pendingInvite.id]);
    sqlRun('DELETE FROM group_join_requests WHERE group_id = ? AND user_id = ? AND status = ?', [groupId, req.session.userId, 'pending']);
    return res.json({ ok: true, joined: true, pending: false, invited: false, membershipStatus: 'member' });
  }

  const existingRequest = sqlGet(
    `SELECT id
     FROM group_join_requests
     WHERE group_id = ? AND user_id = ? AND status = 'pending'`,
    [groupId, req.session.userId]
  );
  if (existingRequest) {
    sqlRun('DELETE FROM group_join_requests WHERE id = ?', [existingRequest.id]);
    return res.json({ ok: true, joined: false, pending: false, invited: false, membershipStatus: 'none' });
  }

  sqlRun(
    `INSERT INTO group_join_requests (group_id, user_id, status, created_at)
     VALUES (?, ?, 'pending', ?)`,
    [groupId, req.session.userId, new Date().toISOString()]
  );

  const managers = sqlAll(
    `SELECT user_id
     FROM group_members
     WHERE group_id = ? AND role IN ('owner', 'moderator')`,
    [groupId]
  );
  for (const manager of managers) {
    if (Number(manager.user_id) === Number(req.session.userId)) continue;
    addNotification({
      userId: Number(manager.user_id),
      type: 'group_join_request',
      sourceUserId: req.session.userId,
      entityId: Number(groupId),
      message: `${group.name} grubuna katılım isteği gönderdi.`
    });
  }

  return res.json({ ok: true, joined: false, pending: true, invited: false, membershipStatus: 'pending' });
});

app.get('/api/new/groups/:id/requests', requireAuth, (req, res) => {
  const groupId = req.params.id;
  const group = sqlGet('SELECT id FROM groups WHERE id = ?', [groupId]);
  if (!group) return res.status(404).send('Grup bulunamadı.');
  if (!isGroupManager(req, groupId)) return res.status(403).send('Yetki yok.');
  const rows = sqlAll(
    `SELECT r.id, r.group_id, r.user_id, r.status, r.created_at,
            u.kadi, u.isim, u.soyisim, u.resim, u.verified
     FROM group_join_requests r
     LEFT JOIN uyeler u ON u.id = r.user_id
     WHERE r.group_id = ? AND r.status = 'pending'
     ORDER BY r.id DESC`,
    [groupId]
  );
  return res.json({ items: rows });
});

app.post('/api/new/groups/:id/requests/:requestId', requireAuth, (req, res) => {
  const groupId = req.params.id;
  const requestId = req.params.requestId;
  const action = String(req.body?.action || '').toLowerCase();
  if (!['approve', 'reject'].includes(action)) return res.status(400).send('Geçersiz işlem.');
  const group = sqlGet('SELECT id, name FROM groups WHERE id = ?', [groupId]);
  if (!group) return res.status(404).send('Grup bulunamadı.');
  if (!isGroupManager(req, groupId)) return res.status(403).send('Yetki yok.');

  const requestRow = sqlGet(
    `SELECT id, user_id, status
     FROM group_join_requests
     WHERE id = ? AND group_id = ?`,
    [requestId, groupId]
  );
  if (!requestRow) return res.status(404).send('Katılım isteği bulunamadı.');
  if (requestRow.status !== 'pending') return res.status(400).send('İstek zaten sonuçlandırılmış.');

  if (action === 'approve') {
    const alreadyMember = getGroupMember(groupId, requestRow.user_id);
    if (!alreadyMember) {
      sqlRun('INSERT INTO group_members (group_id, user_id, role, created_at) VALUES (?, ?, ?, ?)', [
        groupId,
        requestRow.user_id,
        'member',
        new Date().toISOString()
      ]);
    }
  }

  sqlRun(
    `UPDATE group_join_requests
     SET status = ?, reviewed_at = ?, reviewed_by = ?
     WHERE id = ?`,
    [action === 'approve' ? 'approved' : 'rejected', new Date().toISOString(), req.session.userId, requestId]
  );

  addNotification({
    userId: Number(requestRow.user_id),
    type: action === 'approve' ? 'group_join_approved' : 'group_join_rejected',
    sourceUserId: req.session.userId,
    entityId: Number(groupId),
    message: action === 'approve'
      ? `${group.name} grubuna katılım isteğin onaylandı.`
      : `${group.name} grubuna katılım isteğin reddedildi.`
  });

  return res.json({ ok: true, status: action === 'approve' ? 'approved' : 'rejected' });
});

app.get('/api/new/groups/:id/invitations', requireAuth, (req, res) => {
  const groupId = req.params.id;
  const group = sqlGet('SELECT id FROM groups WHERE id = ?', [groupId]);
  if (!group) return res.status(404).send('Grup bulunamadı.');
  if (!isGroupManager(req, groupId)) return res.status(403).send('Yetki yok.');
  const rows = sqlAll(
    `SELECT i.id, i.group_id, i.invited_user_id, i.invited_by, i.status, i.created_at, i.responded_at,
            u.kadi, u.isim, u.soyisim, u.resim, u.verified
     FROM group_invites i
     LEFT JOIN uyeler u ON u.id = i.invited_user_id
     WHERE i.group_id = ? AND i.status = 'pending'
     ORDER BY i.id DESC`,
    [groupId]
  );
  return res.json({ items: rows });
});

app.post('/api/new/groups/:id/invitations', requireAuth, (req, res) => {
  const groupId = req.params.id;
  const group = sqlGet('SELECT id, name FROM groups WHERE id = ?', [groupId]);
  if (!group) return res.status(404).send('Grup bulunamadı.');
  if (!isGroupManager(req, groupId)) return res.status(403).send('Yetki yok.');
  const idsRaw = Array.isArray(req.body?.userIds) ? req.body.userIds : [];
  const userIds = Array.from(new Set(idsRaw.map((v) => Number(v)).filter((v) => Number.isFinite(v) && v > 0)));
  if (!userIds.length) return res.status(400).send('En az bir üye seçmelisin.');
  let sent = 0;
  for (const userId of userIds) {
    if (sameUserId(userId, req.session.userId)) continue;
    const alreadyMember = getGroupMember(groupId, userId);
    if (alreadyMember) continue;
    const existingPending = sqlGet(
      `SELECT id
       FROM group_invites
       WHERE group_id = ? AND invited_user_id = ? AND status = 'pending'`,
      [groupId, userId]
    );
    if (existingPending) continue;
    sqlRun(
      `INSERT INTO group_invites (group_id, invited_user_id, invited_by, status, created_at)
       VALUES (?, ?, ?, 'pending', ?)`,
      [groupId, userId, req.session.userId, new Date().toISOString()]
    );
    addNotification({
      userId,
      type: 'group_invite',
      sourceUserId: req.session.userId,
      entityId: Number(groupId),
      message: `${group.name} grubuna davet edildin.`
    });
    sent += 1;
  }
  return res.json({ ok: true, sent });
});

app.post('/api/new/groups/:id/invitations/respond', requireAuth, (req, res) => {
  const groupId = req.params.id;
  const action = String(req.body?.action || '').toLowerCase();
  if (!['accept', 'reject'].includes(action)) return res.status(400).send('Geçersiz işlem.');
  const invite = sqlGet(
    `SELECT id, invited_user_id, status
     FROM group_invites
     WHERE group_id = ? AND invited_user_id = ? AND status = 'pending'`,
    [groupId, req.session.userId]
  );
  if (!invite) return res.status(404).send('Bekleyen davet bulunamadı.');

  if (action === 'accept') {
    const alreadyMember = getGroupMember(groupId, req.session.userId);
    if (!alreadyMember) {
      sqlRun('INSERT INTO group_members (group_id, user_id, role, created_at) VALUES (?, ?, ?, ?)', [
        groupId,
        req.session.userId,
        'member',
        new Date().toISOString()
      ]);
    }
  }

  sqlRun('UPDATE group_invites SET status = ?, responded_at = ? WHERE id = ?', [
    action === 'accept' ? 'accepted' : 'rejected',
    new Date().toISOString(),
    invite.id
  ]);

  return res.json({ ok: true, status: action === 'accept' ? 'accepted' : 'rejected' });
});

app.post('/api/new/groups/:id/settings', requireAuth, (req, res) => {
  const groupId = req.params.id;
  if (!isGroupManager(req, groupId)) return res.status(403).send('Yetki yok.');
  const hasVisibility = typeof req.body?.visibility !== 'undefined';
  const hasShowHint = typeof req.body?.showContactHint !== 'undefined';
  if (!hasVisibility && !hasShowHint) return res.status(400).send('Ayar verisi bulunamadı.');

  let visibility = null;
  if (hasVisibility) {
    visibility = parseGroupVisibilityInput(req.body?.visibility);
    if (!visibility) return res.status(400).send('Geçersiz görünürlük.');
  }
  const showContactHint = hasShowHint && req.body?.showContactHint ? 1 : 0;

  if (hasVisibility && hasShowHint) {
    sqlRun('UPDATE groups SET visibility = ?, show_contact_hint = ? WHERE id = ?', [visibility, showContactHint, groupId]);
  } else if (hasVisibility) {
    sqlRun('UPDATE groups SET visibility = ? WHERE id = ?', [visibility, groupId]);
  } else {
    sqlRun('UPDATE groups SET show_contact_hint = ? WHERE id = ?', [showContactHint, groupId]);
  }

  const row = sqlGet('SELECT visibility, show_contact_hint FROM groups WHERE id = ?', [groupId]);
  return res.json({
    ok: true,
    visibility: normalizeGroupVisibility(row?.visibility),
    showContactHint: Number(row?.show_contact_hint || 0) === 1
  });
});

app.post('/api/new/groups/:id/cover', requireAuth, groupUpload.single('image'), async (req, res) => {
  if (!req.file) return res.status(400).send('Görsel seçilmedi.');
  const group = sqlGet('SELECT * FROM groups WHERE id = ?', [req.params.id]);
  if (!group) return res.status(404).send('Grup bulunamadı.');
  if (!isGroupManager(req, req.params.id)) {
    return res.status(403).send('Yetki yok.');
  }
  let finalPath = req.file.path;
  try {
    finalPath = await optimizeUploadedImage(req.file.path, {
      width: 1800,
      height: 1000,
      fit: 'contain',
      quality: 84,
      background: '#f4f1ec'
    });
  } catch {
    // keep original upload
  }
  const image = toUploadUrl(finalPath) || `/uploads/groups/${req.file.filename}`;
  sqlRun('UPDATE groups SET cover_image = ? WHERE id = ?', [image, req.params.id]);
  res.json({ ok: true, image });
});

app.post('/api/new/groups/:id/role', requireAuth, (req, res) => {
  const group = sqlGet('SELECT * FROM groups WHERE id = ?', [req.params.id]);
  if (!group) return res.status(404).send('Grup bulunamadı.');
  const member = sqlGet('SELECT role FROM group_members WHERE group_id = ? AND user_id = ?', [req.params.id, req.session.userId]);
  const user = getCurrentUser(req);
  const isAdmin = user?.admin === 1 && req.session?.adminOk;
  if (!isAdmin && (!member || member.role !== 'owner')) {
    return res.status(403).send('Yetki yok.');
  }
  const targetId = req.body?.userId;
  const role = req.body?.role;
  if (!targetId || !['member', 'moderator', 'owner'].includes(role)) {
    return res.status(400).send('Geçersiz rol.');
  }
  const targetMember = sqlGet('SELECT id FROM group_members WHERE group_id = ? AND user_id = ?', [req.params.id, targetId]);
  if (!targetMember) return res.status(404).send('Üye bulunamadı.');
  sqlRun('UPDATE group_members SET role = ? WHERE group_id = ? AND user_id = ?', [role, req.params.id, targetId]);
  res.json({ ok: true });
});

app.get('/api/new/groups/:id', requireAuth, (req, res) => {
  const groupId = req.params.id;
  const group = sqlGet('SELECT * FROM groups WHERE id = ?', [groupId]);
  if (!group) return res.status(404).send('Grup bulunamadı.');
  const user = getCurrentUser(req);
  const isAdmin = user?.admin === 1;
  const member = getGroupMember(groupId, req.session.userId);
  const invite = sqlGet(
    `SELECT id, status
     FROM group_invites
     WHERE group_id = ? AND invited_user_id = ? AND status = 'pending'`,
    [groupId, req.session.userId]
  );
  const pending = sqlGet(
    `SELECT id
     FROM group_join_requests
     WHERE group_id = ? AND user_id = ? AND status = 'pending'`,
    [groupId, req.session.userId]
  );
  const membersOnly = normalizeGroupVisibility(group.visibility) === 'members_only';
  const groupManagers = sqlAll(
    `SELECT m.user_id AS id, m.role, u.kadi, u.isim, u.soyisim, u.resim, u.verified
     FROM group_members m
     LEFT JOIN uyeler u ON u.id = m.user_id
     WHERE m.group_id = ? AND m.role IN ('owner', 'moderator')
     ORDER BY CASE WHEN m.role = 'owner' THEN 0 ELSE 1 END, m.id ASC`,
    [groupId]
  );
  const showContactHint = Number(group.show_contact_hint || 0) === 1;

  if (membersOnly && !isAdmin && !member) {
    const memberCount = sqlGet('SELECT COUNT(*) AS cnt FROM group_members WHERE group_id = ?', [groupId])?.cnt || 0;
    return res.status(403).json({
      message: 'Bu grup özel. İçerikleri görmek için owner/moderatör onayı ile üye olmalısın.',
      membershipStatus: invite ? 'invited' : (pending ? 'pending' : 'none'),
      group: {
        id: group.id,
        name: group.name,
        description: group.description,
        cover_image: group.cover_image,
        members: memberCount,
        visibility: normalizeGroupVisibility(group.visibility),
        show_contact_hint: showContactHint ? 1 : 0
      },
      managers: showContactHint ? groupManagers : []
    });
  }
  const members = sqlAll(
    `SELECT u.id, u.kadi, u.isim, u.soyisim, u.resim, u.verified, m.role
     FROM group_members m
     LEFT JOIN uyeler u ON u.id = m.user_id
     WHERE m.group_id = ?`,
    [groupId]
  );
  const rawPosts = sqlAll(
    `SELECT p.id, p.content, p.image, p.created_at,
            u.id as user_id, u.kadi, u.isim, u.soyisim, u.resim, u.verified
     FROM posts p
     LEFT JOIN uyeler u ON u.id = p.user_id
     WHERE p.group_id = ?
     ORDER BY p.id DESC`,
    [groupId]
  );
  const postIds = rawPosts.map((p) => p.id);
  const likes = postIds.length
    ? sqlAll(`SELECT post_id, COUNT(*) AS cnt FROM post_likes WHERE post_id IN (${postIds.map(() => '?').join(',')}) GROUP BY post_id`, postIds)
    : [];
  const comments = postIds.length
    ? sqlAll(`SELECT post_id, COUNT(*) AS cnt FROM post_comments WHERE post_id IN (${postIds.map(() => '?').join(',')}) GROUP BY post_id`, postIds)
    : [];
  const liked = postIds.length
    ? sqlAll(`SELECT post_id FROM post_likes WHERE user_id = ? AND post_id IN (${postIds.map(() => '?').join(',')})`, [req.session.userId, ...postIds])
    : [];
  const likeMap = new Map(likes.map((l) => [l.post_id, l.cnt]));
  const commentMap = new Map(comments.map((c) => [c.post_id, c.cnt]));
  const likedSet = new Set(liked.map((l) => l.post_id));
  const canReviewRequests = isGroupManager(req, groupId);
  const joinRequests = canReviewRequests
    ? sqlAll(
      `SELECT r.id, r.group_id, r.user_id, r.status, r.created_at,
              u.kadi, u.isim, u.soyisim, u.resim, u.verified
       FROM group_join_requests r
       LEFT JOIN uyeler u ON u.id = r.user_id
       WHERE r.group_id = ? AND r.status = 'pending'
       ORDER BY r.id DESC`,
      [groupId]
    )
    : [];
  const groupEvents = sqlAll(
    `SELECT e.id, e.group_id, e.title, e.description, e.location, e.starts_at, e.ends_at, e.created_at, e.created_by, u.kadi AS creator_kadi
     FROM group_events e
     LEFT JOIN uyeler u ON u.id = e.created_by
     WHERE e.group_id = ?
     ORDER BY COALESCE(e.starts_at, e.created_at) ASC, e.id DESC
     LIMIT 50`,
    [groupId]
  );
  const groupAnnouncements = sqlAll(
    `SELECT a.id, a.group_id, a.title, a.body, a.created_at, a.created_by, u.kadi AS creator_kadi
     FROM group_announcements a
     LEFT JOIN uyeler u ON u.id = a.created_by
     WHERE a.group_id = ?
     ORDER BY a.id DESC
     LIMIT 50`,
    [groupId]
  );
  const pendingInvites = canReviewRequests
    ? sqlAll(
      `SELECT i.id, i.group_id, i.invited_user_id, i.invited_by, i.status, i.created_at,
              u.kadi, u.isim, u.soyisim, u.resim, u.verified
       FROM group_invites i
       LEFT JOIN uyeler u ON u.id = i.invited_user_id
       WHERE i.group_id = ? AND i.status = 'pending'
       ORDER BY i.id DESC`,
      [groupId]
    )
    : [];
  return res.json({
    group: {
      ...group,
      visibility: normalizeGroupVisibility(group.visibility),
      show_contact_hint: showContactHint ? 1 : 0
    },
    members,
    managers: groupManagers,
    membershipStatus: member ? 'member' : (invite ? 'invited' : (pending ? 'pending' : 'none')),
    myRole: member?.role || (isAdmin ? 'admin' : null),
    canReviewRequests,
    joinRequests,
    pendingInvites,
    groupEvents,
    groupAnnouncements,
    posts: rawPosts.map((p) => ({
      ...p,
      likeCount: likeMap.get(p.id) || 0,
      commentCount: commentMap.get(p.id) || 0,
      liked: likedSet.has(p.id)
    }))
  });
});

app.post('/api/new/groups/:id/posts', requireAuth, (req, res) => {
  const groupId = req.params.id;
  const group = sqlGet('SELECT id FROM groups WHERE id = ?', [groupId]);
  if (!group) return res.status(404).send('Grup bulunamadı.');
  const user = getCurrentUser(req);
  if (user?.admin !== 1 && !getGroupMember(groupId, req.session.userId)) {
    return res.status(403).send('Bu grup özel. Paylaşım için onaylı üyelik gerekli.');
  }
  const content = metinDuzenle(req.body?.content || '');
  const contentRaw = String(req.body?.content || '');
  if (isFormattedContentEmpty(content)) return res.status(400).send('İçerik boş olamaz.');
  const now = new Date().toISOString();
  sqlRun('INSERT INTO posts (user_id, content, image, created_at, group_id) VALUES (?, ?, ?, ?, ?)', [
    req.session.userId,
    content,
    null,
    now,
    groupId
  ]);
  notifyMentions({
    text: contentRaw,
    sourceUserId: req.session.userId,
    entityId: groupId,
    type: 'mention_group',
    message: 'Grup paylaşımında senden bahsetti.'
  });
  res.json({ ok: true });
});

app.post('/api/new/groups/:id/posts/upload', requireAuth, postUpload.single('image'), async (req, res) => {
  const groupId = req.params.id;
  const group = sqlGet('SELECT id FROM groups WHERE id = ?', [groupId]);
  if (!group) return res.status(404).send('Grup bulunamadı.');
  const user = getCurrentUser(req);
  if (user?.admin !== 1 && !getGroupMember(groupId, req.session.userId)) {
    return res.status(403).send('Bu grup özel. Paylaşım için onaylı üyelik gerekli.');
  }
  const content = metinDuzenle(req.body?.content || '');
  const contentRaw = String(req.body?.content || '');
  const filter = req.body?.filter || '';
  let finalImagePath = req.file?.path || null;
  if (finalImagePath && filter) {
    try { await applyImageFilter(finalImagePath, filter); } catch {}
  }
  if (finalImagePath) {
    try {
      finalImagePath = await optimizeUploadedImage(finalImagePath, {
        width: 1900,
        height: 1900,
        fit: 'inside',
        quality: 84,
        background: '#ffffff'
      });
    } catch {
      // keep original image path
    }
  }
  const image = finalImagePath ? toUploadUrl(finalImagePath) : null;
  if (isFormattedContentEmpty(content) && !image) return res.status(400).send('İçerik boş olamaz.');
  const now = new Date().toISOString();
  sqlRun('INSERT INTO posts (user_id, content, image, created_at, group_id) VALUES (?, ?, ?, ?, ?)', [
    req.session.userId,
    content,
    image,
    now,
    groupId
  ]);
  notifyMentions({
    text: contentRaw,
    sourceUserId: req.session.userId,
    entityId: groupId,
    type: 'mention_group',
    message: 'Grup paylaşımında senden bahsetti.'
  });
  res.json({ ok: true });
});

app.get('/api/new/groups/:id/events', requireAuth, (req, res) => {
  const groupId = req.params.id;
  const group = sqlGet('SELECT id FROM groups WHERE id = ?', [groupId]);
  if (!group) return res.status(404).send('Grup bulunamadı.');
  const user = getCurrentUser(req);
  if (user?.admin !== 1 && !getGroupMember(groupId, req.session.userId)) {
    return res.status(403).send('Bu grup özel. Etkinlikler yalnızca üyelere açık.');
  }
  const rows = sqlAll(
    `SELECT e.id, e.group_id, e.title, e.description, e.location, e.starts_at, e.ends_at, e.created_at, e.created_by, u.kadi AS creator_kadi
     FROM group_events e
     LEFT JOIN uyeler u ON u.id = e.created_by
     WHERE e.group_id = ?
     ORDER BY COALESCE(e.starts_at, e.created_at) ASC, e.id DESC
     LIMIT 100`,
    [groupId]
  );
  res.json({ items: rows });
});

app.post('/api/new/groups/:id/events', requireAuth, (req, res) => {
  const groupId = req.params.id;
  const group = sqlGet('SELECT id FROM groups WHERE id = ?', [groupId]);
  if (!group) return res.status(404).send('Grup bulunamadı.');
  if (!isGroupManager(req, groupId)) return res.status(403).send('Yetki yok. Sadece owner/moderator etkinlik ekleyebilir.');
  const title = String(req.body?.title || '').trim();
  if (!title) return res.status(400).send('Başlık gerekli.');
  const now = new Date().toISOString();
  const result = sqlRun(
    `INSERT INTO group_events (group_id, title, description, location, starts_at, ends_at, created_at, created_by)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
    [
      groupId,
      title,
      metinDuzenle(req.body?.description || ''),
      String(req.body?.location || ''),
      String(req.body?.starts_at || ''),
      String(req.body?.ends_at || ''),
      now,
      req.session.userId
    ]
  );
  res.json({ ok: true, id: result?.lastInsertRowid });
});

app.delete('/api/new/groups/:id/events/:eventId', requireAuth, (req, res) => {
  const groupId = req.params.id;
  if (!isGroupManager(req, groupId)) return res.status(403).send('Yetki yok.');
  sqlRun('DELETE FROM group_events WHERE id = ? AND group_id = ?', [req.params.eventId, groupId]);
  res.json({ ok: true });
});

app.get('/api/new/groups/:id/announcements', requireAuth, (req, res) => {
  const groupId = req.params.id;
  const group = sqlGet('SELECT id FROM groups WHERE id = ?', [groupId]);
  if (!group) return res.status(404).send('Grup bulunamadı.');
  const user = getCurrentUser(req);
  if (user?.admin !== 1 && !getGroupMember(groupId, req.session.userId)) {
    return res.status(403).send('Bu grup özel. Duyurular yalnızca üyelere açık.');
  }
  const rows = sqlAll(
    `SELECT a.id, a.group_id, a.title, a.body, a.created_at, a.created_by, u.kadi AS creator_kadi
     FROM group_announcements a
     LEFT JOIN uyeler u ON u.id = a.created_by
     WHERE a.group_id = ?
     ORDER BY a.id DESC
     LIMIT 100`,
    [groupId]
  );
  res.json({ items: rows });
});

app.post('/api/new/groups/:id/announcements', requireAuth, (req, res) => {
  const groupId = req.params.id;
  const group = sqlGet('SELECT id FROM groups WHERE id = ?', [groupId]);
  if (!group) return res.status(404).send('Grup bulunamadı.');
  if (!isGroupManager(req, groupId)) return res.status(403).send('Yetki yok. Sadece owner/moderator duyuru ekleyebilir.');
  const title = String(req.body?.title || '').trim();
  const body = metinDuzenle(req.body?.body || '');
  if (!title || isFormattedContentEmpty(body)) return res.status(400).send('Başlık ve içerik gerekli.');
  const now = new Date().toISOString();
  const result = sqlRun(
    `INSERT INTO group_announcements (group_id, title, body, created_at, created_by)
     VALUES (?, ?, ?, ?, ?)`,
    [groupId, title, body, now, req.session.userId]
  );
  res.json({ ok: true, id: result?.lastInsertRowid });
});

app.delete('/api/new/groups/:id/announcements/:announcementId', requireAuth, (req, res) => {
  const groupId = req.params.id;
  if (!isGroupManager(req, groupId)) return res.status(403).send('Yetki yok.');
  sqlRun('DELETE FROM group_announcements WHERE id = ? AND group_id = ?', [req.params.announcementId, groupId]);
  res.json({ ok: true });
});

function normalizeEventResponse(value) {
  const raw = String(value || '').trim().toLowerCase();
  if (['attend', 'joined', 'join', 'going', 'yes'].includes(raw)) return 'attend';
  if (['decline', 'declined', 'no', 'reject', 'not_going'].includes(raw)) return 'decline';
  return null;
}

function getEventResponseBundle(eventRow, viewerUserId, canSeePrivate = false) {
  const eventId = Number(eventRow?.id || 0);
  if (!eventId) {
    return {
      counts: { attend: 0, decline: 0 },
      myResponse: null,
      attendees: [],
      decliners: []
    };
  }
  const rows = sqlAll(
    `SELECT er.response, er.updated_at, er.user_id, u.kadi, u.isim, u.soyisim, u.resim, u.verified
     FROM event_responses er
     LEFT JOIN uyeler u ON u.id = er.user_id
     WHERE er.event_id = ?`,
    [eventId]
  );
  const counts = { attend: 0, decline: 0 };
  const attendees = [];
  const decliners = [];
  let myResponse = null;

  for (const row of rows) {
    const response = normalizeEventResponse(row.response);
    if (!response) continue;
    counts[response] += 1;
    if (sameUserId(row.user_id, viewerUserId)) {
      myResponse = response;
    }
    const member = {
      user_id: row.user_id,
      kadi: row.kadi,
      isim: row.isim,
      soyisim: row.soyisim,
      resim: row.resim,
      verified: row.verified,
      updated_at: row.updated_at
    };
    if (response === 'attend') attendees.push(member);
    if (response === 'decline') decliners.push(member);
  }

  const showCounts = canSeePrivate || Number(eventRow?.show_response_counts ?? 1) === 1;
  const showAttendeeNames = canSeePrivate || Number(eventRow?.show_attendee_names ?? 0) === 1;
  const showDeclinerNames = canSeePrivate || Number(eventRow?.show_decliner_names ?? 0) === 1;

  return {
    counts: showCounts ? counts : null,
    myResponse,
    attendees: showAttendeeNames ? attendees : [],
    decliners: showDeclinerNames ? decliners : [],
    visibility: {
      showCounts: Number(eventRow?.show_response_counts ?? 1) === 1,
      showAttendeeNames: Number(eventRow?.show_attendee_names ?? 0) === 1,
      showDeclinerNames: Number(eventRow?.show_decliner_names ?? 0) === 1
    }
  };
}

function createEventRecord(req, { image = null } = {}) {
  const title = String(req.body?.title || '').trim();
  const descriptionRaw = String(req.body?.description ?? req.body?.body ?? '');
  const location = String(req.body?.location || '').trim();
  const startsAt = String(req.body?.starts_at ?? req.body?.date ?? '');
  const endsAt = String(req.body?.ends_at || '');
  if (!title) return { error: 'Başlık gerekli.' };
  const user = getCurrentUser(req);
  const isAdmin = user?.admin === 1 && req.session.adminOk;
  const now = new Date().toISOString();
  const result = sqlRun(
    `INSERT INTO events (title, description, location, starts_at, ends_at, image, created_at, created_by, approved, approved_by, approved_at,
                         show_response_counts, show_attendee_names, show_decliner_names)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 1, 0, 0)`,
    [
      title,
      metinDuzenle(descriptionRaw),
      location,
      startsAt,
      endsAt,
      image || null,
      now,
      req.session.userId,
      isAdmin ? 1 : 0,
      isAdmin ? req.session.userId : null,
      isAdmin ? now : null
    ]
  );
  notifyMentions({
    text: descriptionRaw,
    sourceUserId: req.session.userId,
    entityId: result?.lastInsertRowid,
    type: 'mention_event',
    message: 'Etkinlik açıklamasında senden bahsetti.'
  });
  return { ok: true, pending: !isAdmin, id: result?.lastInsertRowid };
}

app.get('/api/new/events', requireAuth, (req, res) => {
  const user = getCurrentUser(req);
  const isAdmin = user?.admin === 1 && req.session.adminOk;
  const limit = Math.min(Math.max(parseInt(req.query.limit || '20', 10), 1), 100);
  const offset = Math.max(parseInt(req.query.offset || '0', 10), 0);
  const rows = sqlAll(
    `SELECT e.*, u.kadi AS creator_kadi
     FROM events e
     LEFT JOIN uyeler u ON u.id = e.created_by
     ${isAdmin ? '' : 'WHERE COALESCE(e.approved, 1) = 1'}
     ORDER BY COALESCE(NULLIF(e.starts_at, ''), e.created_at) ASC, e.id DESC
     LIMIT ? OFFSET ?`,
    [limit, offset]
  );

  const items = rows.map((row) => {
    const canSeePrivate = isAdmin || sameUserId(row.created_by, req.session.userId);
    const bundle = getEventResponseBundle(row, req.session.userId, canSeePrivate);
    return {
      ...row,
      response_counts: bundle.counts,
      my_response: bundle.myResponse,
      attendees: bundle.attendees,
      decliners: bundle.decliners,
      response_visibility: bundle.visibility,
      can_manage_responses: canSeePrivate
    };
  });

  res.json({ items, hasMore: rows.length === limit });
});

app.post('/api/new/events', requireAuth, (req, res) => {
  const created = createEventRecord(req, { image: req.body?.image || null });
  if (created.error) return res.status(400).send(created.error);
  return res.json(created);
});

app.post('/api/new/events/upload', requireAuth, postUpload.single('image'), async (req, res) => {
  let imagePath = req.file?.path || null;
  if (imagePath) {
    try {
      imagePath = await optimizeUploadedImage(imagePath, {
        width: 1900,
        height: 1900,
        fit: 'inside',
        quality: 84,
        background: '#ffffff'
      });
    } catch {
      // keep original
    }
  }
  const created = createEventRecord(req, { image: imagePath ? toUploadUrl(imagePath) : null });
  if (created.error) return res.status(400).send(created.error);
  return res.json(created);
});

app.post('/api/new/events/:id/approve', requireAdmin, (req, res) => {
  const approved = String(req.body?.approved || '1') === '1' ? 1 : 0;
  sqlRun(
    'UPDATE events SET approved = ?, approved_by = ?, approved_at = ? WHERE id = ?',
    [approved, req.session.userId, new Date().toISOString(), req.params.id]
  );
  res.json({ ok: true });
});

app.delete('/api/new/events/:id', requireAdmin, (req, res) => {
  sqlRun('DELETE FROM event_comments WHERE event_id = ?', [req.params.id]);
  sqlRun('DELETE FROM event_responses WHERE event_id = ?', [req.params.id]);
  sqlRun('DELETE FROM events WHERE id = ?', [req.params.id]);
  res.json({ ok: true });
});

app.post('/api/new/events/:id/respond', requireAuth, (req, res) => {
  const event = sqlGet('SELECT * FROM events WHERE id = ?', [req.params.id]);
  if (!event) return res.status(404).send('Etkinlik bulunamadı.');
  if (Number(event.approved || 1) !== 1) return res.status(400).send('Etkinlik henüz yayında değil.');
  const response = normalizeEventResponse(req.body?.response);
  if (!response) return res.status(400).send('Geçersiz yanıt.');
  const now = new Date().toISOString();
  const existing = sqlGet('SELECT id FROM event_responses WHERE event_id = ? AND user_id = ?', [req.params.id, req.session.userId]);
  if (existing) {
    sqlRun('UPDATE event_responses SET response = ?, updated_at = ? WHERE id = ?', [response, now, existing.id]);
  } else {
    sqlRun(
      'INSERT INTO event_responses (event_id, user_id, response, created_at, updated_at) VALUES (?, ?, ?, ?, ?)',
      [req.params.id, req.session.userId, response, now, now]
    );
  }
  if (event.created_by && !sameUserId(event.created_by, req.session.userId)) {
    addNotification({
      userId: event.created_by,
      type: 'event_comment',
      sourceUserId: req.session.userId,
      entityId: req.params.id,
      message: response === 'attend' ? 'Etkinliğine katılacağını belirtti.' : 'Etkinliğine katılamayacağını belirtti.'
    });
  }
  const canSeePrivate = sameUserId(event.created_by, req.session.userId);
  const bundle = getEventResponseBundle(event, req.session.userId, canSeePrivate);
  res.json({ ok: true, myResponse: bundle.myResponse, counts: bundle.counts });
});

app.post('/api/new/events/:id/response-visibility', requireAuth, (req, res) => {
  const event = sqlGet('SELECT id, created_by FROM events WHERE id = ?', [req.params.id]);
  if (!event) return res.status(404).send('Etkinlik bulunamadı.');
  const user = getCurrentUser(req);
  const isAdmin = user?.admin === 1 && req.session.adminOk;
  if (!sameUserId(event.created_by, req.session.userId) && !isAdmin) {
    return res.status(403).send('Sadece etkinlik sahibi ayarları değiştirebilir.');
  }
  const showCounts = req.body?.showCounts ? 1 : 0;
  const showAttendeeNames = req.body?.showAttendeeNames ? 1 : 0;
  const showDeclinerNames = req.body?.showDeclinerNames ? 1 : 0;
  sqlRun(
    `UPDATE events
     SET show_response_counts = ?, show_attendee_names = ?, show_decliner_names = ?
     WHERE id = ?`,
    [showCounts, showAttendeeNames, showDeclinerNames, req.params.id]
  );
  const updated = sqlGet(
    'SELECT show_response_counts, show_attendee_names, show_decliner_names FROM events WHERE id = ?',
    [req.params.id]
  );
  res.json({
    ok: true,
    visibility: {
      showCounts: Number(updated?.show_response_counts || 0) === 1,
      showAttendeeNames: Number(updated?.show_attendee_names || 0) === 1,
      showDeclinerNames: Number(updated?.show_decliner_names || 0) === 1
    }
  });
});

app.get('/api/new/events/:id/comments', requireAuth, (req, res) => {
  const rows = sqlAll(
    `SELECT c.id, c.comment, c.created_at, u.id AS user_id, u.kadi, u.isim, u.soyisim, u.resim, u.verified
     FROM event_comments c
     LEFT JOIN uyeler u ON u.id = c.user_id
     WHERE c.event_id = ?
     ORDER BY c.id DESC`,
    [req.params.id]
  );
  res.json({ items: rows });
});

app.post('/api/new/events/:id/comments', requireAuth, (req, res) => {
  const event = sqlGet('SELECT * FROM events WHERE id = ?', [req.params.id]);
  if (!event) return res.status(404).send('Etkinlik bulunamadı.');
  const commentRaw = req.body?.comment || '';
  const comment = metinDuzenle(commentRaw);
  if (isFormattedContentEmpty(comment)) return res.status(400).send('Yorum boş olamaz.');
  const now = new Date().toISOString();
  sqlRun('INSERT INTO event_comments (event_id, user_id, comment, created_at) VALUES (?, ?, ?, ?)', [
    req.params.id,
    req.session.userId,
    comment,
    now
  ]);
  if (event.created_by && !sameUserId(event.created_by, req.session.userId)) {
    addNotification({
      userId: event.created_by,
      type: 'event_comment',
      sourceUserId: req.session.userId,
      entityId: req.params.id,
      message: 'Etkinliğine yorum yaptı.'
    });
  }
  notifyMentions({
    text: commentRaw,
    sourceUserId: req.session.userId,
    entityId: req.params.id,
    type: 'mention_event',
    message: 'Etkinlik yorumunda senden bahsetti.'
  });
  res.json({ ok: true });
});

app.post('/api/new/events/:id/notify', requireAuth, (req, res) => {
  const event = sqlGet('SELECT id, title FROM events WHERE id = ? AND COALESCE(approved,1) = 1', [req.params.id]);
  if (!event) return res.status(404).send('Etkinlik bulunamadı.');
  const followers = sqlAll('SELECT follower_id FROM follows WHERE following_id = ?', [req.session.userId]);
  for (const f of followers) {
    if (sameUserId(f.follower_id, req.session.userId)) continue;
    addNotification({
      userId: f.follower_id,
      type: 'event_invite',
      sourceUserId: req.session.userId,
      entityId: event.id,
      message: `Seni "${event.title}" etkinliğine davet etti.`
    });
  }
  res.json({ ok: true, count: followers.length });
});

app.get('/api/new/announcements', requireAuth, (req, res) => {
  const user = getCurrentUser(req);
  const isAdmin = user?.admin === 1 && req.session.adminOk;
  const limit = Math.min(Math.max(parseInt(req.query.limit || '20', 10), 1), 100);
  const offset = Math.max(parseInt(req.query.offset || '0', 10), 0);
  const rows = sqlAll(
    `SELECT a.*, u.kadi AS creator_kadi
     FROM announcements a
     LEFT JOIN uyeler u ON u.id = a.created_by
     ${isAdmin ? '' : 'WHERE COALESCE(a.approved, 1) = 1'}
     ORDER BY a.id DESC`
     + ' LIMIT ? OFFSET ?',
    [limit, offset]
  );
  res.json({ items: rows, hasMore: rows.length === limit });
});

app.post('/api/new/announcements', requireAuth, (req, res) => {
  const { title, body, image } = req.body || {};
  const formattedBody = metinDuzenle(body || '');
  if (!title || isFormattedContentEmpty(formattedBody)) return res.status(400).send('Başlık ve içerik gerekli.');
  const user = getCurrentUser(req);
  const isAdmin = user?.admin === 1 && req.session.adminOk;
  const now = new Date().toISOString();
  sqlRun(
    `INSERT INTO announcements (title, body, image, created_at, created_by, approved, approved_by, approved_at)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
    [title, formattedBody, image || null, now, req.session.userId, isAdmin ? 1 : 0, isAdmin ? req.session.userId : null, isAdmin ? now : null]
  );
  res.json({ ok: true, pending: !isAdmin });
});

app.post('/api/new/announcements/upload', requireAuth, postUpload.single('image'), async (req, res) => {
  const title = String(req.body?.title || '').trim();
  const bodyRaw = String(req.body?.body || '');
  const body = metinDuzenle(bodyRaw);
  if (!title || isFormattedContentEmpty(body)) return res.status(400).send('Başlık ve içerik gerekli.');
  const user = getCurrentUser(req);
  const isAdmin = user?.admin === 1 && req.session.adminOk;
  let imagePath = req.file?.path || null;
  if (imagePath) {
    try {
      imagePath = await optimizeUploadedImage(imagePath, {
        width: 1900,
        height: 1900,
        fit: 'inside',
        quality: 84,
        background: '#ffffff'
      });
    } catch {
      // keep original
    }
  }
  const now = new Date().toISOString();
  sqlRun(
    `INSERT INTO announcements (title, body, image, created_at, created_by, approved, approved_by, approved_at)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
    [
      title,
      body,
      imagePath ? toUploadUrl(imagePath) : null,
      now,
      req.session.userId,
      isAdmin ? 1 : 0,
      isAdmin ? req.session.userId : null,
      isAdmin ? now : null
    ]
  );
  res.json({ ok: true, pending: !isAdmin });
});

app.post('/api/new/announcements/:id/approve', requireAdmin, (req, res) => {
  const approved = String(req.body?.approved || '1') === '1' ? 1 : 0;
  sqlRun(
    'UPDATE announcements SET approved = ?, approved_by = ?, approved_at = ? WHERE id = ?',
    [approved, req.session.userId, new Date().toISOString(), req.params.id]
  );
  res.json({ ok: true });
});

app.delete('/api/new/announcements/:id', requireAdmin, (req, res) => {
  sqlRun('DELETE FROM announcements WHERE id = ?', [req.params.id]);
  res.json({ ok: true });
});

app.get('/api/new/chat/messages', requireAuth, (req, res) => {
  const sinceId = parseInt(req.query.sinceId || '0', 10) || 0;
  const beforeId = parseInt(req.query.beforeId || '0', 10) || 0;
  const limit = Math.min(Math.max(parseInt(req.query.limit || '40', 10), 1), 200);
  let where = 'WHERE 1=1';
  const params = [];
  if (sinceId > 0) {
    where += ' AND c.id > ?';
    params.push(sinceId);
  }
  if (beforeId > 0) {
    where += ' AND c.id < ?';
    params.push(beforeId);
  }
  const rows = sqlAll(
    `SELECT c.id, c.user_id, c.message, c.created_at, u.kadi, u.isim, u.soyisim, u.resim, u.verified
     FROM chat_messages c
     LEFT JOIN uyeler u ON u.id = c.user_id
     ${where}
     ORDER BY c.id DESC
     LIMIT ?`,
    [...params, limit]
  );
  res.json({ items: rows.reverse() });
});

app.post('/api/new/chat/send', requireAuth, (req, res) => {
  const rawMessage = String(req.body?.message || '').slice(0, 5000);
  const message = metinDuzenle(rawMessage);
  if (isFormattedContentEmpty(message)) return res.status(400).send('Mesaj boş olamaz.');
  const now = new Date().toISOString();
  const result = sqlRun('INSERT INTO chat_messages (user_id, message, created_at) VALUES (?, ?, ?)', [
    req.session.userId,
    message,
    now
  ]);
  const user = sqlGet('SELECT id, kadi, isim, soyisim, resim, verified FROM uyeler WHERE id = ?', [req.session.userId]) || null;
  res.json({
    ok: true,
    id: result?.lastInsertRowid,
    item: user ? {
      id: result?.lastInsertRowid,
      user_id: user.id,
      message,
      created_at: now,
      kadi: user.kadi,
      isim: user.isim,
      soyisim: user.soyisim,
      resim: user.resim,
      verified: user.verified
    } : null
  });
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

function buildEngagementAbPerformanceRows() {
  const rows = sqlAll(
    `SELECT COALESCE(NULLIF(ab_variant, ''), 'A') AS variant,
            COUNT(*) AS users,
            ROUND(AVG(COALESCE(score, 0)), 2) AS avg_score,
            ROUND(AVG(COALESCE(raw_score, 0)), 2) AS avg_raw_score,
            ROUND(AVG(COALESCE(posts_30d, 0)), 2) AS avg_posts_30d,
            ROUND(AVG(COALESCE(likes_received_30d, 0)), 2) AS avg_likes_received_30d,
            ROUND(AVG(COALESCE(comments_received_30d, 0)), 2) AS avg_comments_received_30d,
            ROUND(AVG(COALESCE(follows_gained_30d, 0)), 2) AS avg_follows_gained_30d,
            ROUND(AVG(COALESCE(story_views_received_30d, 0)), 2) AS avg_story_views_received_30d
     FROM member_engagement_scores
     GROUP BY COALESCE(NULLIF(ab_variant, ''), 'A')
     ORDER BY variant ASC`
  );
  return rows.map((r) => ({
    ...r,
    engagementRate: Number(((Number(r.avg_likes_received_30d || 0) + Number(r.avg_comments_received_30d || 0) * 2) / Math.max(Number(r.avg_posts_30d || 0), 1)).toFixed(2))
  }));
}

function round2(value) {
  const n = Number(value);
  if (!Number.isFinite(n)) return 0;
  return Number(n.toFixed(2));
}

function buildEngagementAbRecommendations(configs, performance) {
  const perfMap = new Map((performance || []).map((p) => [String(p.variant || '').toUpperCase(), p]));
  const configMap = new Map((configs || []).map((c) => [String(c.variant || '').toUpperCase(), c]));
  const baseline = perfMap.get('A') || performance?.[0] || null;
  const recommendations = [];

  for (const cfg of (configs || [])) {
    const variant = String(cfg.variant || '').toUpperCase();
    const perf = perfMap.get(variant);
    if (!perf) continue;
    if (Number(perf.users || 0) < 20) continue;
    const p = cfg.params || engagementDefaultParams;
    const patch = {};
    const reasons = [];
    const confidenceParts = [];

    if (baseline && baseline.variant !== variant && Number(baseline.users || 0) >= 20) {
      const baselineRate = Math.max(Number(baseline.engagementRate || 0), 0.01);
      const baselineScore = Math.max(Number(baseline.avg_score || 0), 0.01);
      const rateDelta = (Number(perf.engagementRate || 0) - baselineRate) / baselineRate;
      const scoreDelta = (Number(perf.avg_score || 0) - baselineScore) / baselineScore;

      if (rateDelta < -0.08) {
        patch.receivedCommentWeight = round2(p.receivedCommentWeight * 1.1);
        patch.scaleReceived = round2(p.scaleReceived * 1.06);
        reasons.push(`Etkileşim oranı baseline'a göre düşük (${round2(rateDelta * 100)}%).`);
        confidenceParts.push(Math.min(0.4, Math.abs(rateDelta)));
      } else if (rateDelta > 0.08 && scoreDelta > -0.03) {
        patch.receivedCommentWeight = round2(p.receivedCommentWeight * 1.04);
        patch.capReceived = round2(p.capReceived * 1.03);
        reasons.push(`Etkileşim oranı baseline'a göre yüksek (${round2(rateDelta * 100)}%).`);
        confidenceParts.push(Math.min(0.35, Math.abs(rateDelta)));
      }

      if (scoreDelta < -0.08) {
        patch.recency7d = round2(p.recency7d * 1.03);
        patch.recency30d = round2(p.recency30d * 1.02);
        patch.penaltyLowQualityPost = round2(p.penaltyLowQualityPost * 0.95);
        reasons.push(`Ortalama skor baseline'a göre düşük (${round2(scoreDelta * 100)}%).`);
        confidenceParts.push(Math.min(0.35, Math.abs(scoreDelta)));
      } else if (scoreDelta > 0.12 && rateDelta >= -0.05) {
        patch.penaltyAggressiveFollow = round2(p.penaltyAggressiveFollow * 1.05);
        reasons.push(`Ortalama skor baseline'a göre yüksek (${round2(scoreDelta * 100)}%).`);
        confidenceParts.push(Math.min(0.25, Math.abs(scoreDelta)));
      }
    }

    const postsAvg = Number(perf.avg_posts_30d || 0);
    const followsGainAvg = Number(perf.avg_follows_gained_30d || 0);
    if (postsAvg < 1.2) {
      patch.creatorRecentPostWeight = round2(p.creatorRecentPostWeight * 1.07);
      reasons.push('İçerik üretim ortalaması düşük; taze içerik sinyali artırıldı.');
      confidenceParts.push(0.14);
    }
    if (followsGainAvg < 0.5) {
      patch.networkFollowGainWeight = round2(p.networkFollowGainWeight * 1.06);
      reasons.push('Takipçi artışı düşük; network büyüme katsayısı artırıldı.');
      confidenceParts.push(0.12);
    }

    const normalizedPatch = normalizeEngagementParams(
      { ...p, ...patch },
      engagementDefaultVariants[variant]?.params || engagementDefaultParams
    );
    const finalPatch = {};
    for (const key of Object.keys(p)) {
      if (Number(normalizedPatch[key]) !== Number(p[key])) {
        finalPatch[key] = normalizedPatch[key];
      }
    }
    if (!Object.keys(finalPatch).length) continue;

    const confidenceBase = confidenceParts.reduce((s, v) => s + v, 0);
    const sampleFactor = Math.min(1, Number(perf.users || 0) / 250);
    const confidence = round2(clamp(0.25 + confidenceBase + sampleFactor * 0.35, 0, 0.95));

    recommendations.push({
      variant,
      confidence,
      reasons: reasons.slice(0, 4),
      patch: finalPatch
    });
  }

  const activeConfigs = (configs || []).filter((c) => Number(c.enabled || 0) === 1);
  if (activeConfigs.length >= 2) {
    const scored = activeConfigs
      .map((cfg) => {
        const perf = perfMap.get(cfg.variant);
        if (!perf) return null;
        const quality = Number(perf.avg_score || 0) * 0.6 + Number(perf.engagementRate || 0) * 0.4;
        return { variant: cfg.variant, quality };
      })
      .filter(Boolean)
      .sort((a, b) => b.quality - a.quality);
    if (scored.length >= 2 && scored[0].quality > scored[1].quality * 1.05) {
      const winner = configMap.get(scored[0].variant);
      const loser = configMap.get(scored[scored.length - 1].variant);
      if (winner && loser) {
        recommendations.push({
          variant: winner.variant,
          confidence: 0.62,
          reasons: [`${winner.variant} varyantı kalite metriğinde daha iyi performans gösteriyor.`],
          trafficPatch: {
            [winner.variant]: clamp(Number(winner.trafficPct || 0) + 5, 0, 100),
            [loser.variant]: clamp(Number(loser.trafficPct || 0) - 5, 0, 100)
          }
        });
      }
    }
  }

  return recommendations;
}

app.get('/api/new/admin/engagement-ab', requireAdmin, (_req, res) => {
  const configs = getEngagementAbConfigs().map((cfg) => ({
    variant: cfg.variant,
    name: cfg.name,
    description: cfg.description,
    trafficPct: cfg.trafficPct,
    enabled: cfg.enabled,
    params: cfg.params,
    updatedAt: cfg.updatedAt
  }));
  const performance = buildEngagementAbPerformanceRows();
  const recommendations = buildEngagementAbRecommendations(configs, performance);
  const assignmentCounts = sqlAll(
    `SELECT variant, COUNT(*) AS cnt
     FROM engagement_ab_assignments
     GROUP BY variant
     ORDER BY variant ASC`
  );
  const lastCalculatedAt = sqlGet('SELECT MAX(updated_at) AS ts FROM member_engagement_scores')?.ts || null;
  res.json({ configs, performance, assignmentCounts, recommendations, lastCalculatedAt });
});

app.put('/api/new/admin/engagement-ab/:variant', requireAdmin, (req, res) => {
  const variant = String(req.params.variant || '').trim().toUpperCase();
  if (!variant) return res.status(400).send('Variant gerekli.');
  const existing = sqlGet('SELECT variant, params_json FROM engagement_ab_config WHERE variant = ?', [variant]);
  if (!existing) return res.status(404).send('Variant bulunamadı.');
  let currentParams = engagementDefaultVariants[variant]?.params || engagementDefaultParams;
  try {
    currentParams = existing.params_json ? JSON.parse(existing.params_json) : currentParams;
  } catch {
    // ignore parse error and keep fallback
  }
  const payload = req.body || {};
  const mergedParams = normalizeEngagementParams(
    payload.params && typeof payload.params === 'object'
      ? { ...currentParams, ...payload.params }
      : currentParams,
    engagementDefaultVariants[variant]?.params || engagementDefaultParams
  );
  const trafficPct = clamp(Math.round(Number(payload.trafficPct ?? payload.traffic_pct ?? 50) || 0), 0, 100);
  const enabled = String(payload.enabled ?? '1') === '1' ? 1 : 0;
  const name = String(payload.name || '').trim() || (engagementDefaultVariants[variant]?.name || variant);
  const description = String(payload.description || '').trim() || (engagementDefaultVariants[variant]?.description || '');
  sqlRun(
    `UPDATE engagement_ab_config
     SET name = ?, description = ?, traffic_pct = ?, enabled = ?, params_json = ?, updated_at = ?
     WHERE variant = ?`,
    [name, description, trafficPct, enabled, JSON.stringify(mergedParams), new Date().toISOString(), variant]
  );
  logAdminAction(req, 'engagement_ab_config_update', { variant, trafficPct, enabled });
  scheduleEngagementRecalculation('engagement_ab_updated');
  res.json({ ok: true });
});

app.post('/api/new/admin/engagement-ab/rebalance', requireAdmin, (req, res) => {
  const keepAssignments = String(req.body?.keepAssignments || '0') === '1';
  if (!keepAssignments) {
    sqlRun('DELETE FROM engagement_ab_assignments');
  }
  recalculateMemberEngagementScores('admin_rebalance_ab');
  logAdminAction(req, 'engagement_ab_rebalance', { keepAssignments });
  res.json({ ok: true, keepAssignments });
});

app.get('/api/new/admin/stats', requireAdmin, (req, res) => {
  const recentLimit = Math.min(Math.max(parseInt(req.query.recentLimit || '12', 10), 1), 80);
  cleanupStaleOnlineUsers();
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
  const recentUsers = sqlAll(
    `SELECT id, kadi, isim, soyisim, resim, ilktarih
     FROM uyeler
     ORDER BY id DESC
     LIMIT ?`,
    [recentLimit]
  );
  const recentPosts = sqlAll(
    `SELECT p.id, p.content, p.image, p.created_at, u.kadi
     FROM posts p
     LEFT JOIN uyeler u ON u.id = p.user_id
     ORDER BY p.id DESC
     LIMIT ?`,
    [recentLimit]
  );
  const recentPhotos = sqlAll(
    `SELECT f.id, f.dosyaadi, f.baslik, f.tarih, u.kadi
     FROM album_foto f
     LEFT JOIN uyeler u ON u.id = f.ekleyenid
     ORDER BY f.id DESC
     LIMIT ?`,
    [recentLimit]
  );

  const uploadStats = walkDirStats(uploadsDir);
  const dbSizeBytes = (() => {
    try {
      return fs.statSync(dbPath).size || 0;
    } catch {
      return 0;
    }
  })();
  const diskMetrics = getDiskMetrics(uploadsDir) || getDiskMetrics(path.dirname(dbPath));
  const diskTotalBytes = Number(diskMetrics?.totalBytes || 0);
  const diskUsedBytes = Number(diskMetrics?.usedBytes || 0);
  const diskFreeBytes = Number(diskMetrics?.freeBytes || 0);
  const diskSupported = Number.isFinite(diskTotalBytes) && diskTotalBytes > 0;
  const diskUsedPct = diskSupported ? Number(((diskUsedBytes / diskTotalBytes) * 100).toFixed(2)) : null;
  const diskFreePct = diskSupported ? Number(((diskFreeBytes / diskTotalBytes) * 100).toFixed(2)) : null;
  const cpuUsagePct = sampleCpuUsagePercent();
  const cpuSupported = Number.isFinite(cpuUsagePct) && cpuUsagePct >= 0;

  const storage = {
    uploadedPhotoCount: Number(uploadStats.files || 0),
    uploadedPhotoSizeMb: bytesToMb(uploadStats.bytes),
    databaseSizeMb: bytesToMb(dbSizeBytes),
    diskTotalMb: diskSupported ? bytesToMb(diskTotalBytes) : null,
    diskUsedMb: diskSupported ? bytesToMb(diskUsedBytes) : null,
    diskFreeMb: diskSupported ? bytesToMb(diskFreeBytes) : null,
    diskUsedPct,
    diskFreePct,
    diskSupported,
    diskSource: diskMetrics?.source || null,
    cpuUsagePct: cpuSupported ? Number(cpuUsagePct) : null,
    cpuSupported
  };

  res.json({ counts, storage, recentUsers, recentPosts, recentPhotos });
});

app.get('/api/new/admin/engagement-scores', requireAdmin, (req, res) => {
  const q = String(req.query.q || '').trim();
  const minScoreRaw = String(req.query.minScore ?? req.query.min_score ?? '').trim();
  const maxScoreRaw = String(req.query.maxScore ?? req.query.max_score ?? '').trim();
  const minScore = minScoreRaw === '' ? NaN : Number(minScoreRaw);
  const maxScore = maxScoreRaw === '' ? NaN : Number(maxScoreRaw);
  const status = String(req.query.status || 'all').trim();
  const sort = String(req.query.sort || 'score_desc').trim();
  const variant = String(req.query.variant || '').trim().toUpperCase();
  const page = Math.max(parseInt(req.query.page || '1', 10), 1);
  const limit = Math.min(Math.max(parseInt(req.query.limit || '40', 10), 1), 200);
  const activeExpr = "(COALESCE(CAST(u.aktiv AS INTEGER), 0) = 1 OR LOWER(CAST(u.aktiv AS TEXT)) IN ('true','evet','yes'))";
  const bannedExpr = "(COALESCE(CAST(u.yasak AS INTEGER), 0) = 1 OR LOWER(CAST(u.yasak AS TEXT)) IN ('true','evet','yes'))";

  const whereParts = [];
  const params = [];
  if (q) {
    whereParts.push('(LOWER(CAST(u.kadi AS TEXT)) LIKE LOWER(?) OR LOWER(CAST(u.isim AS TEXT)) LIKE LOWER(?) OR LOWER(CAST(u.soyisim AS TEXT)) LIKE LOWER(?))');
    params.push(`%${q}%`, `%${q}%`, `%${q}%`);
  }
  if (status === 'active') whereParts.push(`${activeExpr} AND NOT ${bannedExpr}`);
  if (status === 'pending') whereParts.push(`NOT ${activeExpr} AND NOT ${bannedExpr}`);
  if (status === 'banned') whereParts.push(`${bannedExpr}`);
  if (Number.isFinite(minScore)) {
    whereParts.push('COALESCE(es.score, 0) >= ?');
    params.push(minScore);
  }
  if (Number.isFinite(maxScore)) {
    whereParts.push('COALESCE(es.score, 0) <= ?');
    params.push(maxScore);
  }
  if (variant) {
    whereParts.push("COALESCE(NULLIF(es.ab_variant, ''), 'A') = ?");
    params.push(variant);
  }
  const where = whereParts.length ? `WHERE ${whereParts.join(' AND ')}` : '';
  const sortMap = {
    score_desc: 'COALESCE(es.score, 0) DESC, u.id DESC',
    score_asc: 'COALESCE(es.score, 0) ASC, u.id DESC',
    recent_update: 'COALESCE(es.updated_at, "") DESC, u.id DESC',
    name: 'u.kadi COLLATE NOCASE ASC'
  };
  const orderBy = sortMap[sort] || sortMap.score_desc;
  const total = sqlGet(
    `SELECT COUNT(*) AS cnt
     FROM uyeler u
     LEFT JOIN member_engagement_scores es ON es.user_id = u.id
     ${where}`,
    params
  )?.cnt || 0;
  const pages = Math.max(Math.ceil(total / limit), 1);
  const safePage = Math.min(page, pages);
  const offset = (safePage - 1) * limit;

  const items = sqlAll(
    `SELECT u.id, u.kadi, u.isim, u.soyisim, u.resim, u.aktiv, u.yasak, u.online, u.verified,
            COALESCE(NULLIF(es.ab_variant, ''), 'A') AS ab_variant,
            COALESCE(es.score, 0) AS score,
            COALESCE(es.raw_score, 0) AS raw_score,
            COALESCE(es.creator_score, 0) AS creator_score,
            COALESCE(es.engagement_received_score, 0) AS engagement_received_score,
            COALESCE(es.community_score, 0) AS community_score,
            COALESCE(es.network_score, 0) AS network_score,
            COALESCE(es.quality_score, 0) AS quality_score,
            COALESCE(es.penalty_score, 0) AS penalty_score,
            COALESCE(es.posts_30d, 0) AS posts_30d,
            COALESCE(es.likes_received_30d, 0) AS likes_received_30d,
            COALESCE(es.comments_received_30d, 0) AS comments_received_30d,
            COALESCE(es.followers_count, 0) AS followers_count,
            COALESCE(es.following_count, 0) AS following_count,
            es.last_activity_at,
            es.updated_at
     FROM uyeler u
     LEFT JOIN member_engagement_scores es ON es.user_id = u.id
     ${where}
     ORDER BY ${orderBy}
     LIMIT ? OFFSET ?`,
    [...params, limit, offset]
  );

  const summary = sqlGet(
    `SELECT ROUND(AVG(COALESCE(es.score, 0)), 2) AS avgScore,
            MAX(COALESCE(es.score, 0)) AS maxScore,
            MIN(COALESCE(es.score, 0)) AS minScore
     FROM uyeler u
     LEFT JOIN member_engagement_scores es ON es.user_id = u.id`
  ) || { avgScore: 0, maxScore: 0, minScore: 0 };
  const lastCalculatedAt = sqlGet('SELECT MAX(updated_at) AS ts FROM member_engagement_scores')?.ts || null;
  res.json({
    items,
    page: safePage,
    pages,
    total,
    limit,
    sort,
    status,
    summary,
    lastCalculatedAt
  });
});

app.post('/api/new/admin/engagement-scores/recalculate', requireAdmin, (_req, res) => {
  recalculateMemberEngagementScores('admin_manual');
  const lastCalculatedAt = sqlGet('SELECT MAX(updated_at) AS ts FROM member_engagement_scores')?.ts || null;
  res.json({ ok: true, lastCalculatedAt });
});

app.get('/api/new/admin/live', requireAdmin, (req, res) => {
  cleanupStaleOnlineUsers();
  const chatLimit = Math.min(Math.max(parseInt(req.query.chatLimit || '8', 10), 1), 50);
  const postLimit = Math.min(Math.max(parseInt(req.query.postLimit || '8', 10), 1), 50);
  const userLimit = Math.min(Math.max(parseInt(req.query.userLimit || '8', 10), 1), 50);
  const activityLimit = Math.min(Math.max(parseInt(req.query.activityLimit || '20', 10), 1), 120);
  const onlineMembers = listOnlineMembers({ limit: 20, excludeUserId: null });
  const counts = {
    onlineUsers: onlineMembers.length,
    pendingVerifications: sqlGet('SELECT COUNT(*) AS cnt FROM verification_requests WHERE status = ?', ['pending'])?.cnt || 0,
    pendingEvents: sqlGet('SELECT COUNT(*) AS cnt FROM events WHERE COALESCE(approved, 1) = 0')?.cnt || 0,
    pendingAnnouncements: sqlGet('SELECT COUNT(*) AS cnt FROM announcements WHERE COALESCE(approved, 1) = 0')?.cnt || 0,
    pendingPhotos: sqlGet('SELECT COUNT(*) AS cnt FROM album_foto WHERE aktif = 0')?.cnt || 0
  };

  const rows = [];
  const chat = sqlAll(
    `SELECT c.id, c.created_at AS ts, u.kadi
     FROM chat_messages c
     LEFT JOIN uyeler u ON u.id = c.user_id
     ORDER BY c.id DESC
     LIMIT ?`,
    [chatLimit]
  );
  for (const item of chat) {
    rows.push({
      id: `chat-${item.id}`,
      type: 'chat',
      message: `@${item.kadi || 'üye'} canlı sohbete mesaj gönderdi.`,
      at: item.ts || null
    });
  }

  const posts = sqlAll(
    `SELECT p.id, p.content, p.image, p.created_at AS ts, u.kadi
     FROM posts p
     LEFT JOIN uyeler u ON u.id = p.user_id
     ORDER BY p.id DESC
     LIMIT ?`,
    [postLimit]
  );
  for (const item of posts) {
    rows.push({
      id: `post-${item.id}`,
      type: 'post',
      message: `@${item.kadi || 'üye'} yeni gönderi paylaştı.`,
      at: item.ts || null
    });
  }

  const newestUsers = sqlAll('SELECT id, kadi, isim, soyisim, resim, ilktarih AS ts FROM uyeler ORDER BY id DESC LIMIT ?', [userLimit]);
  for (const item of newestUsers) {
    rows.push({
      id: `user-${item.id}`,
      type: 'user',
      message: `@${item.kadi || 'üye'} sisteme katıldı.`,
      at: item.ts || null
    });
  }

  const newestPosts = posts.map((p) => ({
    id: p.id,
    kadi: p.kadi,
    created_at: p.ts,
    content: p.content || '',
    image: p.image || null
  }));
  const newestPhotos = sqlAll(
    `SELECT f.id, f.dosyaadi, f.baslik, f.tarih, u.kadi
     FROM album_foto f
     LEFT JOIN uyeler u ON u.id = f.ekleyenid
     ORDER BY f.id DESC
     LIMIT ?`,
    [userLimit]
  );

  rows.sort((a, b) => new Date(b.at || 0).getTime() - new Date(a.at || 0).getTime());
  res.json({
    counts,
    activity: rows.slice(0, activityLimit),
    onlineMembers,
    newestUsers,
    newestPosts,
    newestPhotos,
    now: new Date().toISOString()
  });
});

app.get('/api/new/admin/groups', requireAdmin, (req, res) => {
  const rows = sqlAll('SELECT id, name, description, cover_image, owner_id, created_at FROM groups ORDER BY id DESC');
  res.json({ items: rows });
});

app.delete('/api/new/admin/groups/:id', requireAdmin, (req, res) => {
  sqlRun('DELETE FROM group_members WHERE group_id = ?', [req.params.id]);
  sqlRun('DELETE FROM group_join_requests WHERE group_id = ?', [req.params.id]);
  sqlRun('DELETE FROM group_invites WHERE group_id = ?', [req.params.id]);
  sqlRun('DELETE FROM posts WHERE group_id = ?', [req.params.id]);
  sqlRun('DELETE FROM group_events WHERE group_id = ?', [req.params.id]);
  sqlRun('DELETE FROM group_announcements WHERE group_id = ?', [req.params.id]);
  sqlRun('DELETE FROM groups WHERE id = ?', [req.params.id]);
  res.json({ ok: true });
});

app.get('/api/new/admin/stories', requireAdmin, (req, res) => {
  let rows = sqlAll(
    `SELECT s.id, s.image, s.caption, s.created_at, s.expires_at, u.kadi
     FROM stories s LEFT JOIN uyeler u ON u.id = s.user_id
     ORDER BY s.id DESC`
  );
  if (!rows.length) {
    rows = sqlAll(
      `SELECT id, image, caption, created_at, expires_at, 'legacy' AS kadi
       FROM stories
       ORDER BY id DESC
       LIMIT 200`
    );
  }
  res.json({ items: rows });
});

app.delete('/api/new/admin/stories/:id', requireAdmin, (req, res) => {
  sqlRun('DELETE FROM story_views WHERE story_id = ?', [req.params.id]);
  sqlRun('DELETE FROM stories WHERE id = ?', [req.params.id]);
  logAdminAction(req, 'story_delete', { storyId: req.params.id });
  res.json({ ok: true });
});

app.get('/api/new/admin/chat/messages', requireAdmin, (req, res) => {
  let rows = sqlAll(
    `SELECT c.id, c.message, c.created_at, u.kadi
     FROM chat_messages c LEFT JOIN uyeler u ON u.id = c.user_id
     ORDER BY c.id DESC LIMIT 200`
  );
  if (!rows.length) {
    try {
      rows = sqlAll(
        `SELECT h.id, h.metin AS message, h.tarih AS created_at, h.kadi
         FROM hmes h
         ORDER BY h.id DESC
         LIMIT 200`
      );
    } catch {
      rows = [];
    }
  }
  res.json({ items: rows });
});

app.delete('/api/new/admin/chat/messages/:id', requireAdmin, (req, res) => {
  sqlRun('DELETE FROM chat_messages WHERE id = ?', [req.params.id]);
  logAdminAction(req, 'chat_message_delete', { messageId: req.params.id });
  res.json({ ok: true });
});

app.get('/api/new/admin/messages', requireAdmin, (req, res) => {
  const rows = sqlAll(
    `SELECT g.id, g.konu, g.mesaj, g.tarih, u1.kadi AS kimden_kadi, u2.kadi AS kime_kadi
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
  logAdminAction(req, 'inbox_message_delete', { messageId: req.params.id });
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

app.get('/api/new/admin/db/backups', requireAdmin, (_req, res) => {
  res.json({
    items: listDbBackups(),
    dbPath
  });
});

app.post('/api/new/admin/db/backups', requireAdmin, async (req, res) => {
  try {
    const label = String(req.body?.label || 'manual');
    const backup = await createDbBackup(label);
    logAdminAction(req, 'db_backup_create', { file: backup.name, size: backup.size });
    res.json({ ok: true, backup });
  } catch (err) {
    writeAppLog('error', 'db_backup_create_failed', { message: err?.message || 'unknown' });
    res.status(500).send(err?.message || 'Yedek oluşturulamadı.');
  }
});

app.get('/api/new/admin/db/backups/:name/download', requireAdmin, (req, res) => {
  const fullPath = resolveBackupPath(req.params.name || '');
  if (!fullPath || !fs.existsSync(fullPath)) return res.status(404).send('Yedek dosyası bulunamadı.');
  logAdminAction(req, 'db_backup_download', { file: path.basename(fullPath) });
  res.download(fullPath, path.basename(fullPath));
});

app.post('/api/new/admin/db/restore', requireAdmin, dbBackupUpload.single('backup'), (req, res) => {
  try {
    if (!req.file?.path) return res.status(400).send('Yedek dosyası gerekli.');
    const restored = restoreDbFromUploadedFile(req.file.path);
    logAdminAction(req, 'db_restore', {
      sourceName: String(req.file.originalname || ''),
      uploadedFile: restored.uploadedName,
      preRestoreBackup: restored.preRestoreName
    });
    res.json({ ok: true, restored });
  } catch (err) {
    writeAppLog('error', 'db_restore_failed', { message: err?.message || 'unknown' });
    res.status(500).send(err?.message || 'Geri yükleme başarısız.');
  } finally {
    try {
      if (req.file?.path && fs.existsSync(req.file.path)) fs.unlinkSync(req.file.path);
    } catch {
      // no-op
    }
  }
});

app.get('/api/album/latest', (req, res) => {
  if (!req.session.userId) return res.status(401).send('Login required');
  const limit = Math.min(Math.max(parseInt(req.query.limit || '100', 10), 1), 200);
  const offset = Math.max(parseInt(req.query.offset || '0', 10), 0);
  const rows = sqlAll(
    `SELECT f.id, f.katid, f.dosyaadi, f.tarih, f.hit, k.kategori
     FROM album_foto f
     LEFT JOIN album_kat k ON k.id = f.katid
     WHERE f.aktif = 1
     ORDER BY f.id DESC
     LIMIT ? OFFSET ?`,
    [limit, offset]
  );
  res.json({ items: rows, hasMore: rows.length === limit });
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

app.get('/api/games/arcade/:game/leaderboard', (req, res) => {
  const game = String(req.params.game || '').trim().toLowerCase();
  const allowed = new Set(['tap-rush', 'memory-pairs', 'puzzle-2048']);
  if (!allowed.has(game)) return res.status(404).send('Game not found');
  const rows = sqlAll(
    `SELECT name AS isim, score AS skor, created_at AS tarih
     FROM game_scores
     WHERE game_key = ?
     ORDER BY score DESC, created_at ASC
     LIMIT 25`,
    [game]
  );
  res.json({ rows });
});

app.post('/api/games/arcade/:game/score', (req, res) => {
  if (!req.session.userId) return res.status(401).send('Login required');
  const game = String(req.params.game || '').trim().toLowerCase();
  const allowed = new Set(['tap-rush', 'memory-pairs', 'puzzle-2048']);
  if (!allowed.has(game)) return res.status(404).send('Game not found');
  const score = Math.max(0, Math.floor(Number(req.body?.score || 0)));
  const user = sqlGet('SELECT kadi FROM uyeler WHERE id = ?', [req.session.userId]);
  const name = user?.kadi || 'Misafir';
  const existing = sqlGet('SELECT id, score FROM game_scores WHERE game_key = ? AND name = ?', [game, name]);
  if (!existing) {
    sqlRun('INSERT INTO game_scores (game_key, name, score, created_at) VALUES (?, ?, ?, ?)', [game, name, score, new Date().toISOString()]);
  } else if (score > Number(existing.score || 0)) {
    sqlRun('UPDATE game_scores SET score = ?, created_at = ? WHERE id = ?', [score, new Date().toISOString(), existing.id]);
  }
  res.json({ ok: true });
});

// Serve modern (sdal_new) frontend
const modernDist = path.resolve(__dirname, '../../sdal_new/dist');
if (fs.existsSync(modernDist)) {
  app.use('/new', express.static(modernDist));
  app.use('/sdal_new', express.static(modernDist));
  app.get('/sdal_new', (_req, res) => {
    res.redirect(302, '/new');
  });
  app.get('/sdal_new/*', (req, res) => {
    const suffix = req.path.replace(/^\/sdal_new/, '') || '/';
    res.redirect(302, `/new${suffix}`);
  });
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

app.use((err, req, res, _next) => {
  writeLegacyLog('error', 'uncaught_route_error', {
    method: req?.method || '',
    path: req?.path || '',
    userId: req?.session?.userId || null,
    ip: req?.ip || '',
    message: err?.message || 'unknown_error'
  });
  writeAppLog('error', 'uncaught_route_error', {
    method: req?.method || '',
    path: req?.path || '',
    userId: req?.session?.userId || null,
    ip: req?.ip || '',
    message: err?.message || 'unknown_error',
    stack: err?.stack || ''
  });
  if (res.headersSent) return;
  res.status(500).send('Beklenmeyen bir hata oluştu.');
});

setTimeout(() => recalculateMemberEngagementScores('startup'), 2500);
setInterval(() => recalculateMemberEngagementScores('interval_10m'), 10 * 60 * 1000);

const server = app.listen(port, () => {
  const uyelerExists = !!sqlGet(
    "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'uyeler'"
  );
  const tableCount = sqlGet(
    "SELECT COUNT(*) AS cnt FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%'"
  )?.cnt || 0;
  console.log(`SDAL server running on http://localhost:${port}`);
  console.log(`[startup] dbPath=${dbPath}`);
  console.log(`[startup] cwd=${process.cwd()} node_env=${process.env.NODE_ENV || 'development'}`);
  console.log(`[startup] tables=${tableCount} uyeler_exists=${uyelerExists ? 'yes' : 'no'}`);
  writeLegacyLog('page', 'server_started', { port, node: process.version });
  writeAppLog('info', 'server_started', {
    port,
    node: process.version,
    dbPath,
    tableCount,
    uyelerExists
  });
});

process.on('uncaughtException', (err) => {
  writeLegacyLog('error', 'uncaught_exception', { message: err?.message || 'unknown' });
  writeAppLog('error', 'uncaught_exception', { message: err?.message || 'unknown', stack: err?.stack || '' });
});

process.on('unhandledRejection', (reason) => {
  const message = reason instanceof Error ? reason.message : String(reason || 'unknown');
  const stack = reason instanceof Error ? reason.stack || '' : '';
  writeLegacyLog('error', 'unhandled_rejection', { message });
  writeAppLog('error', 'unhandled_rejection', { message, stack });
});

const wss = new WebSocketServer({ server, path: '/ws/chat' });
wss.on('connection', (ws, req) => {
  ws.on('message', (data) => {
    try {
      const payload = JSON.parse(String(data || '{}'));
      const userId = Number(payload?.userId || 0);
      const rawMessage = String(payload?.message || '').slice(0, 5000);
      if (!userId || !rawMessage) return;
      const user = sqlGet('SELECT id, kadi, isim, soyisim, resim, verified FROM uyeler WHERE id = ?', [userId]) || null;
      if (!user?.id) return;
      const message = metinDuzenle(rawMessage || '');
      if (isFormattedContentEmpty(message)) return;
      const now = new Date().toISOString();
      const result = sqlRun('INSERT INTO chat_messages (user_id, message, created_at) VALUES (?, ?, ?)', [
        userId,
        message,
        now
      ]);
      scheduleEngagementRecalculation('chat_message_created');
      const outgoing = JSON.stringify({
        id: result?.lastInsertRowid,
        user_id: user.id,
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
