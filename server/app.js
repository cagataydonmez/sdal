import express from 'express';
import path from 'path';
import Database from 'better-sqlite3';
import cookieParser from 'cookie-parser';
import morgan from 'morgan';
import { sqlGet, sqlAll, sqlRun, sqlGetAsync, sqlAllAsync, sqlRunAsync, dbPath, getDb, closeDbConnection, resetDbConnection, dbDriver, configureDbInstrumentation } from './db.js';
import { mapLegacyUrl } from './legacyRoutes.js';
import fs from 'fs';
import os from 'os';
import { execFileSync } from 'child_process';
import crypto from 'crypto';
import { promisify } from 'util';
import sharp from 'sharp';
import { metinDuzenle } from './textFormat.js';
import multer from 'multer';
import { WebSocketServer } from 'ws';
import { processUpload, deleteImageRecord, getImageVariants, getImageVariantsBatch, loadMediaSettings } from './media/uploadPipeline.js';
import { SpacesStorageProvider, getStorageProvider } from './media/storageProvider.js';
import { getDirname } from './config/paths.js';
import { isProd, port, uploadsDir, legacyDir, ONLINE_HEARTBEAT_MS } from './config/env.js';
import { sessionMiddleware } from './middleware/session.js';
import { presenceMiddleware, toLocalDateParts } from './middleware/presence.js';
import { requestLoggingMiddleware } from './middleware/requestLogging.js';
import { registerStaticUploads } from './middleware/staticUploads.js';
import { registerLegacyStatics } from './routes/staticLegacy.js';
import { createPhase1DomainLayer } from './src/bootstrap/createPhase1DomainLayer.js';
import { checkPostgresHealth, closePostgresPool, getPostgresPoolState, isPostgresConfigured } from './src/infra/postgresPool.js';
import { checkRedisHealth, closeRedisClient, getRedisState, isRedisConfigured } from './src/infra/redisClient.js';
import { buildVersionedCacheKey, bumpCacheNamespaceVersion, getCacheJson, setCacheJson } from './src/infra/performanceCache.js';
import { createRealtimeBus } from './src/infra/realtimeBus.js';
import { createJobQueue } from './src/infra/jobQueue.js';
import { createMailSender } from './src/infra/mailSender.js';
import { consumeUploadQuota } from './src/infra/uploadQuota.js';
import { createRateLimitMiddleware } from './src/http/middleware/rateLimit.js';
import { createIdempotencyMiddleware } from './src/http/middleware/idempotency.js';
import { pgQuery } from './src/infra/postgresPool.js';
import {
  buildMemberTrustBadges,
  buildScoredNetworkSuggestion,
  createPeerMap,
  getPeerOverlapCount,
  mapNetworkSuggestionForApi,
  networkSuggestionDefaultParams,
  networkSuggestionDefaultVariants,
  normalizeNetworkSuggestionParams,
  sortNetworkSuggestions
} from './src/services/networkSuggestionService.js';

const __dirname = getDirname(import.meta.url);

const app = express();
app.set('trust proxy', true);
app.locals.dbDriver = dbDriver;

app.use(morgan('dev'));
app.use(cookieParser());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));
const sessionParser = sessionMiddleware({ isProd });
app.use(sessionParser);
app.use(presenceMiddleware({ sqlRun, sqlRunAsync, onlineHeartbeatMs: ONLINE_HEARTBEAT_MS }));
app.use(requestLoggingMiddleware({ writeAppLog, writeLegacyLog }));
registerLegacyStatics(app, legacyDir);
registerStaticUploads(app, uploadsDir);
app.use('/uploads', express.static(uploadsDir, {
  setHeaders(res, filePath) {
    const rel = path.relative(uploadsDir, filePath).split(path.sep).join('/').toLowerCase();
    if (rel.startsWith('verification-proofs/') || rel.startsWith('request-attachments/')) {
      res.setHeader('Cache-Control', 'private, no-store');
      res.setHeader('X-Robots-Tag', 'noindex, nofollow, noarchive');
    }
    res.setHeader('X-Content-Type-Options', 'nosniff');
  }
}));

// Ensure new images directory exists
const imagesDir = path.join(uploadsDir, 'images');
if (!fs.existsSync(imagesDir)) {
  fs.mkdirSync(imagesDir, { recursive: true });
}

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
const verificationProofDir = path.join(uploadsDir, 'verification-proofs');
if (!fs.existsSync(verificationProofDir)) {
  fs.mkdirSync(verificationProofDir, { recursive: true });
}
const requestAttachmentDir = path.join(uploadsDir, 'request-attachments');
if (!fs.existsSync(requestAttachmentDir)) {
  fs.mkdirSync(requestAttachmentDir, { recursive: true });
}

let chatWss = null;
let messengerWss = null;
let realtimeBus = null;
let backgroundJobQueue = null;
let inlineJobWorkerStarted = false;

const allowLegacyWsQueryAuth = String(process.env.WS_ALLOW_LEGACY_QUERY_AUTH || (isProd ? 'false' : 'true')).toLowerCase() === 'true';
const runInlineJobWorker = String(process.env.JOB_INLINE_WORKER || (isProd ? 'false' : 'true')).toLowerCase() === 'true';
const jobQueueNamespace = String(process.env.JOB_QUEUE_NAMESPACE || 'sdal:jobs:main').trim() || 'sdal:jobs:main';
backgroundJobQueue = createJobQueue({ namespace: jobQueueNamespace, logger: console });

const EICAR_SIGNATURE = 'X5O!P%@AP[4\\PZX54(P^)7CC)7}$EICAR-STANDARD-ANTIVIRUS-TEST-FILE!$H+H*';
const BLOCKED_EXECUTABLE_SIGNATURES = [
  Buffer.from([0x4d, 0x5a]), // MZ
  Buffer.from([0x7f, 0x45, 0x4c, 0x46]), // ELF
  Buffer.from([0xcf, 0xfa, 0xed, 0xfe]), // Mach-O
  Buffer.from([0xca, 0xfe, 0xba, 0xbe]) // Java class
];

function bufferStartsWith(buffer, signature) {
  if (!Buffer.isBuffer(buffer) || !Buffer.isBuffer(signature)) return false;
  if (buffer.length < signature.length) return false;
  return buffer.subarray(0, signature.length).equals(signature);
}

function detectMimeByMagicBytes(filePath) {
  if (!filePath || !fs.existsSync(filePath)) return '';
  const bytes = fs.readFileSync(filePath);
  if (bytes.length >= 3 && bufferStartsWith(bytes, Buffer.from([0xff, 0xd8, 0xff]))) return 'image/jpeg';
  if (bytes.length >= 8 && bufferStartsWith(bytes, Buffer.from([0x89, 0x50, 0x4e, 0x47]))) return 'image/png';
  if (bytes.length >= 12 && bytes.subarray(0, 4).toString('ascii') === 'RIFF' && bytes.subarray(8, 12).toString('ascii') === 'WEBP') return 'image/webp';
  if (bytes.length >= 6 && (bytes.subarray(0, 6).toString('ascii') === 'GIF87a' || bytes.subarray(0, 6).toString('ascii') === 'GIF89a')) return 'image/gif';
  if (bytes.length >= 2 && bytes[0] === 0x42 && bytes[1] === 0x4d) return 'image/bmp';
  if (bytes.length >= 4 && (
    bufferStartsWith(bytes, Buffer.from([0x49, 0x49, 0x2a, 0x00]))
    || bufferStartsWith(bytes, Buffer.from([0x4d, 0x4d, 0x00, 0x2a]))
  )) return 'image/tiff';
  if (bytes.length >= 12 && bytes.subarray(4, 8).toString('ascii') === 'ftyp') {
    const brand = bytes.subarray(8, 12).toString('ascii').toLowerCase();
    if (brand.startsWith('heic') || brand.startsWith('heix') || brand.startsWith('hevc') || brand.startsWith('hevx')) return 'image/heic';
    if (brand.startsWith('heif') || brand.startsWith('mif1') || brand.startsWith('msf1')) return 'image/heif';
  }
  if (bytes.length >= 4 && bufferStartsWith(bytes, Buffer.from([0x25, 0x50, 0x44, 0x46]))) return 'application/pdf';
  return '';
}

function validateUploadedFileSafety(filePath, { allowedMimes = [] } = {}) {
  if (!filePath || !fs.existsSync(filePath)) return { ok: false, reason: 'Dosya bulunamadı.' };
  const bytes = fs.readFileSync(filePath);
  const sniffedMime = detectMimeByMagicBytes(filePath);
  if (allowedMimes.length && (!sniffedMime || !allowedMimes.includes(sniffedMime))) {
    return { ok: false, reason: 'Dosya içeriği beklenen türle eşleşmiyor.' };
  }
  for (const sig of BLOCKED_EXECUTABLE_SIGNATURES) {
    if (bufferStartsWith(bytes, sig)) return { ok: false, reason: 'Yüklenen dosya yürütülebilir içerik içeriyor.' };
  }
  if (bytes.toString('latin1').includes(EICAR_SIGNATURE)) {
    return { ok: false, reason: 'Yüklenen dosya zararlı içerik testi imzası içeriyor.' };
  }
  return { ok: true, mime: sniffedMime };
}

function cleanupUploadedFile(filePath) {
  try {
    if (filePath && fs.existsSync(filePath)) fs.unlinkSync(filePath);
  } catch {
    // best effort
  }
}

const allowedImageExts = new Set(['.jpg', '.jpeg', '.png', '.gif', '.bmp', '.tif', '.tiff', '.webp', '.heic', '.heif']);
const allowedImageSafetyMimes = Object.freeze([
  'image/jpeg',
  'image/png',
  'image/webp',
  'image/gif',
  'image/bmp',
  'image/tiff',
  'image/heic',
  'image/heif'
]);
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
  limits: { fileSize: 20 * 1024 * 1024 }
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
  limits: { fileSize: 20 * 1024 * 1024 }
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
  limits: { fileSize: 20 * 1024 * 1024 }
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
  limits: { fileSize: 20 * 1024 * 1024 }
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
  limits: { fileSize: 20 * 1024 * 1024 }
});

const allowedProofExts = new Set(['.jpg', '.jpeg', '.png', '.pdf']);
const verificationProofUpload = multer({
  storage: multer.diskStorage({
    destination: (_req, _file, cb) => cb(null, verificationProofDir),
    filename: (req, file, cb) => {
      const ext = path.extname(file.originalname || '').toLowerCase();
      const stamp = `${Date.now()}_${Math.round(Math.random() * 1e9)}`;
      cb(null, `proof_${req.session.userId || 'anon'}_${stamp}${ext || '.jpg'}`);
    }
  }),
  fileFilter: (_req, file, cb) => {
    const ext = path.extname(file.originalname || '').toLowerCase();
    if (!allowedProofExts.has(ext)) {
      cb(new Error('Sadece JPG, PNG veya PDF dosyaları yükleyebilirsiniz.'));
      return;
    }
    cb(null, true);
  },
  limits: { fileSize: 10 * 1024 * 1024 }
});

const allowedRequestAttachmentExts = new Set(['.jpg', '.jpeg', '.png', '.pdf']);
const requestAttachmentUpload = multer({
  storage: multer.diskStorage({
    destination: (_req, _file, cb) => cb(null, requestAttachmentDir),
    filename: (req, file, cb) => {
      const ext = path.extname(file.originalname || '').toLowerCase();
      cb(null, `request_${req.session.userId || 'anon'}_${Date.now()}_${Math.round(Math.random() * 1e6)}${ext || '.jpg'}`);
    }
  }),
  fileFilter: (_req, file, cb) => {
    const ext = path.extname(file.originalname || '').toLowerCase();
    if (!allowedRequestAttachmentExts.has(ext)) {
      cb(new Error('Sadece JPG, PNG veya PDF yükleyebilirsiniz.'));
      return;
    }
    cb(null, true);
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
      const ext = path.extname(file.originalname || '').toLowerCase() || (dbDriver === 'postgres' ? '.dump' : '.sqlite');
      cb(null, `incoming-${Date.now()}-${Math.round(Math.random() * 1e9)}${ext}`);
    }
  }),
  limits: { fileSize: 1024 * 1024 * 1024 }
});

const mailSender = createMailSender({ isProd, logger: console });
const mailProviderStatus = mailSender.status;

const adminPassword = String(process.env.SDAL_ADMIN_PASSWORD || '').trim();
const legacyRootOverride = String(process.env.SDAL_LEGACY_ROOT_DIR || '').trim();
const legacyRoot = legacyRootOverride ? path.resolve(legacyRootOverride) : path.resolve(__dirname, '../..');
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
const isPostgresDb = dbDriver === 'postgres';
const joinUserOnPhotoOwnerExpr = isPostgresDb ? 'u.id::text = f.ekleyenid::text' : 'u.id = f.ekleyenid';
const joinUserOnPostAuthorExpr = isPostgresDb ? 'u.id::text = p.user_id::text' : 'u.id = p.user_id';

function backupTimestamp(date = new Date()) {
  const pad = (n) => String(n).padStart(2, '0');
  return `${date.getFullYear()}${pad(date.getMonth() + 1)}${pad(date.getDate())}-${pad(date.getHours())}${pad(date.getMinutes())}${pad(date.getSeconds())}`;
}

function normalizeBackupName(value) {
  const base = path.basename(String(value || ''));
  const safe = base.replace(/[^a-zA-Z0-9._-]/g, '_');
  if (!safe) return '';
  if (isPostgresDb) {
    if (!/\.(dump|sql|backup)$/i.test(safe)) return `${safe}.dump`;
    return safe;
  }
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
  const backupExtPattern = isPostgresDb
    ? /\.(dump|sql|backup)$/i
    : /\.(sqlite|db|backup|bak)$/i;
  return fs.readdirSync(dbBackupDir)
    .filter((name) => backupExtPattern.test(name))
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
  if (isPostgresDb) {
    const databaseUrl = String(process.env.DATABASE_URL || '').trim();
    if (!databaseUrl) throw new Error('DATABASE_URL eksik. PostgreSQL yedeği alınamadı.');
    const name = `sdal-backup-${backupTimestamp()}-${safeLabel}.dump`;
    const fullPath = path.join(dbBackupDir, name);
    execFileSync('pg_dump', ['--format=custom', '--file', fullPath, databaseUrl], { stdio: 'pipe' });
    const st = fs.statSync(fullPath);
    return {
      name,
      size: st.size,
      mtime: st.mtime.toISOString()
    };
  }

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
  if (isPostgresDb) {
    const databaseUrl = String(process.env.DATABASE_URL || '').trim();
    if (!databaseUrl) throw new Error('DATABASE_URL eksik. PostgreSQL geri yükleme yapılamadı.');
    const stamp = backupTimestamp();
    const uploadedName = `uploaded-${stamp}.dump`;
    const uploadedPath = path.join(dbBackupDir, uploadedName);
    fs.copyFileSync(incomingPath, uploadedPath);

    const preRestoreName = `pre-restore-${stamp}.dump`;
    const preRestorePath = path.join(dbBackupDir, preRestoreName);
    execFileSync('pg_dump', ['--format=custom', '--file', preRestorePath, databaseUrl], { stdio: 'pipe' });

    try {
      execFileSync(
        'pg_restore',
        ['--clean', '--if-exists', '--no-owner', '--no-privileges', '--dbname', databaseUrl, uploadedPath],
        { stdio: 'pipe' }
      );
    } catch (err) {
      try {
        execFileSync(
          'pg_restore',
          ['--clean', '--if-exists', '--no-owner', '--no-privileges', '--dbname', databaseUrl, preRestorePath],
          { stdio: 'pipe' }
        );
      } catch {
        // best effort rollback
      }
      throw err;
    }
    return { uploadedName, preRestoreName };
  }

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

const DB_DRIVER_VALUES = Object.freeze(['sqlite', 'postgres']);
const DB_DRIVER_SET = new Set(DB_DRIVER_VALUES);
const dbDriverSwitchEnvFile = (() => {
  const fromEnv = String(process.env.SDAL_DB_SWITCH_ENV_FILE || '').trim();
  return path.resolve(fromEnv || '/etc/sdal/sdal.env');
})();
const dbDriverSwitchChallengeTtlMs = (() => {
  const parsed = Number.parseInt(String(process.env.SDAL_DB_SWITCH_CHALLENGE_TTL_MS || ''), 10);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : 2 * 60 * 1000;
})();
const dbDriverSwitchRestartDelayMs = (() => {
  const parsed = Number.parseInt(String(process.env.SDAL_DB_SWITCH_RESTART_DELAY_MS || ''), 10);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : 1200;
})();
const dbDriverSwitchRestartCommand = String(process.env.SDAL_DB_SWITCH_RESTART_CMD || '').trim();

const dbDriverSwitchChallenges = new Map();
const dbDriverSwitchState = {
  inProgress: false,
  lastAttemptAt: null,
  lastSuccessAt: null,
  lastError: null,
  lastSwitch: null
};

function resolveDbDriverSwitchTarget(currentDriver = dbDriver) {
  return String(currentDriver || '').toLowerCase() === 'postgres' ? 'sqlite' : 'postgres';
}

function buildDbDriverSwitchConfirmText(currentDriver, targetDriver) {
  return `SWITCH ${String(currentDriver || '').toUpperCase()} -> ${String(targetDriver || '').toUpperCase()}`;
}

function buildDbDriverSwitchChallengeKey(req, targetDriver) {
  const sessionKey = String(req.sessionID || req.session?.id || req.session?.userId || req.ip || 'anon');
  return `${sessionKey}:${String(targetDriver || '').toLowerCase()}`;
}

function cleanupExpiredDbDriverSwitchChallenges(now = Date.now()) {
  for (const [key, value] of dbDriverSwitchChallenges.entries()) {
    if (!value || Number(value.expiresAt || 0) <= now) {
      dbDriverSwitchChallenges.delete(key);
    }
  }
}

function issueDbDriverSwitchChallenge(req, targetDriver) {
  cleanupExpiredDbDriverSwitchChallenges();
  const key = buildDbDriverSwitchChallengeKey(req, targetDriver);
  const token = crypto.randomBytes(24).toString('hex');
  const expiresAt = Date.now() + dbDriverSwitchChallengeTtlMs;
  dbDriverSwitchChallenges.set(key, { token, expiresAt });
  return { token, expiresAt };
}

function consumeDbDriverSwitchChallenge(req, targetDriver, token) {
  cleanupExpiredDbDriverSwitchChallenges();
  const key = buildDbDriverSwitchChallengeKey(req, targetDriver);
  const row = dbDriverSwitchChallenges.get(key);
  dbDriverSwitchChallenges.delete(key);
  if (!row) return false;
  if (!token || row.token !== token) return false;
  if (Number(row.expiresAt || 0) <= Date.now()) return false;
  return true;
}

function inspectDbDriverSwitchEnvFile() {
  const info = {
    path: dbDriverSwitchEnvFile,
    exists: false,
    readable: false,
    writable: false
  };
  try {
    info.exists = fs.existsSync(dbDriverSwitchEnvFile);
    if (!info.exists) return info;
    fs.accessSync(dbDriverSwitchEnvFile, fs.constants.R_OK);
    info.readable = true;
    fs.accessSync(dbDriverSwitchEnvFile, fs.constants.W_OK);
    info.writable = true;
    return info;
  } catch {
    return info;
  }
}

function inspectSqliteSwitchTarget(sqliteFilePath) {
  const payload = {
    ready: false,
    detail: '',
    path: sqliteFilePath,
    tableCount: 0,
    usersTableExists: false
  };

  if (!sqliteFilePath) {
    payload.detail = 'SQLite dosya yolu bulunamadı.';
    return payload;
  }
  if (!fs.existsSync(sqliteFilePath)) {
    payload.detail = `SQLite dosyası bulunamadı (${sqliteFilePath}).`;
    return payload;
  }
  if (!isSqliteFile(sqliteFilePath)) {
    payload.detail = 'SQLite dosya imzası doğrulanamadı.';
    return payload;
  }

  let tmp = null;
  try {
    tmp = new Database(sqliteFilePath, { readonly: true, fileMustExist: true });
    const tableCount = Number(tmp.prepare(
      "SELECT COUNT(*) AS cnt FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%'"
    ).get()?.cnt || 0);
    const usersTableExists = !!tmp.prepare(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name IN ('uyeler', 'users') LIMIT 1"
    ).get();
    payload.tableCount = tableCount;
    payload.usersTableExists = usersTableExists;
    if (!usersTableExists) {
      payload.detail = 'SQLite içinde beklenen kullanıcı tablosu bulunamadı (uyeler/users).';
      return payload;
    }
    payload.ready = true;
    payload.detail = 'ok';
    return payload;
  } catch (err) {
    payload.detail = err?.message || 'SQLite hedef doğrulaması başarısız.';
    return payload;
  } finally {
    try {
      tmp?.close();
    } catch {
      // no-op
    }
  }
}

async function inspectPostgresSwitchTarget() {
  const health = await checkPostgresHealth();
  const payload = {
    ready: false,
    configured: health.configured,
    latencyMs: Number(health.latencyMs || 0),
    detail: health.detail || '',
    tableCount: 0,
    usersTableExists: false
  };

  if (!health.ready) return payload;

  try {
    const tableCountResult = await pgQuery(
      "SELECT CAST(COUNT(*) AS INTEGER) AS cnt FROM information_schema.tables WHERE table_schema = 'public'"
    );
    const usersTableResult = await pgQuery(
      "SELECT CAST(COUNT(*) AS INTEGER) AS cnt FROM information_schema.tables WHERE table_schema = 'public' AND table_name IN ('uyeler', 'users')"
    );
    payload.tableCount = Number(tableCountResult.rows?.[0]?.cnt || 0);
    payload.usersTableExists = Number(usersTableResult.rows?.[0]?.cnt || 0) > 0;
    if (!payload.usersTableExists) {
      payload.detail = 'PostgreSQL şemasında beklenen kullanıcı tablosu bulunamadı (uyeler/users).';
      return payload;
    }
    payload.ready = true;
    payload.detail = 'ok';
    return payload;
  } catch (err) {
    payload.detail = err?.message || 'PostgreSQL hedef doğrulaması başarısız.';
    return payload;
  }
}

async function buildDbDriverSwitchReadiness() {
  const currentDriver = DB_DRIVER_SET.has(dbDriver) ? dbDriver : 'sqlite';
  const targetDriver = resolveDbDriverSwitchTarget(currentDriver);
  const envFile = inspectDbDriverSwitchEnvFile();
  const sqlite = inspectSqliteSwitchTarget(dbPath);
  const postgres = await inspectPostgresSwitchTarget();
  const targetState = targetDriver === 'postgres' ? postgres : sqlite;
  const blockers = [];

  if (!envFile.exists) blockers.push(`Env dosyası bulunamadı: ${envFile.path}`);
  if (!envFile.readable) blockers.push(`Env dosyası okunamıyor: ${envFile.path}`);
  if (!envFile.writable) blockers.push(`Env dosyası yazılamıyor: ${envFile.path}`);
  if (!targetState.ready) blockers.push(`Hedef ${targetDriver} hazır değil: ${targetState.detail || 'unknown'}`);

  return {
    currentDriver,
    targetDriver,
    envFile,
    sqlite,
    postgres,
    blockers
  };
}

function quoteEnvValue(value) {
  const raw = String(value ?? '');
  if (!raw) return '';
  if (/^[A-Za-z0-9_./:@%+-]+$/.test(raw)) return raw;
  return `'${raw.replace(/'/g, "'\\''")}'`;
}

function writeEnvUpdates(filePath, updates = {}) {
  const originalText = fs.readFileSync(filePath, 'utf-8');
  const newline = originalText.includes('\r\n') ? '\r\n' : '\n';
  const lines = originalText.replace(/\r\n/g, '\n').split('\n');
  const entries = Object.entries(updates).filter(([key]) => String(key || '').trim().length > 0);

  for (const [key, value] of entries) {
    const rendered = `${key}=${quoteEnvValue(value)}`;
    let updated = false;
    for (let i = 0; i < lines.length; i += 1) {
      const line = lines[i];
      if (!line || /^\s*#/.test(line)) continue;
      const eqIndex = line.indexOf('=');
      if (eqIndex <= 0) continue;
      const lineKey = line.slice(0, eqIndex).trim();
      if (lineKey !== key) continue;
      lines[i] = rendered;
      updated = true;
      break;
    }
    if (!updated) {
      lines.push(rendered);
    }
  }

  const normalized = lines.join('\n').replace(/\n+$/, '');
  const nextText = `${normalized}${newline}`;
  const tmpPath = `${filePath}.tmp-${process.pid}-${Date.now()}`;
  fs.writeFileSync(tmpPath, nextText, 'utf-8');
  fs.renameSync(tmpPath, filePath);
}

function scheduleDbDriverSwitchRestart(meta = {}) {
  if (String(process.env.NODE_ENV || '').toLowerCase() === 'test') return;
  const timer = setTimeout(() => {
    writeAppLog('info', 'db_driver_switch_restart', {
      mode: dbDriverSwitchRestartCommand ? 'custom_command' : 'api_process_exit',
      ...meta
    });
    if (dbDriverSwitchRestartCommand) {
      try {
        execFileSync('/bin/sh', ['-lc', dbDriverSwitchRestartCommand], { stdio: 'ignore' });
        return;
      } catch (err) {
        writeAppLog('error', 'db_driver_switch_restart_command_failed', {
          message: err?.message || 'unknown_error'
        });
      }
    }
    try {
      process.kill(process.pid, 'SIGTERM');
    } catch (err) {
      writeAppLog('error', 'db_driver_switch_restart_failed', {
        message: err?.message || 'unknown_error'
      });
    }
  }, dbDriverSwitchRestartDelayMs);
  if (typeof timer?.unref === 'function') timer.unref();
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

configureDbInstrumentation({
  slowQueryThresholdMs: Number(process.env.SDAL_SLOW_QUERY_MS || 200),
  onSlowQuery: (entry) => {
    writeAppLog('warn', 'db_slow_query', {
      requestId: null,
      driver: entry.driver,
      operation: entry.operation,
      durationMs: entry.durationMs,
      paramCount: entry.paramCount,
      paramPreview: entry.paramPreview,
      query: entry.query,
      error: entry.error
    });
  }
});

function envInt(name, fallback) {
  const parsed = Number.parseInt(String(process.env[name] || ''), 10);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : fallback;
}

const FEED_CACHE_TTL_SECONDS = envInt('FEED_CACHE_TTL_SECONDS', 20);
const PROFILE_CACHE_TTL_SECONDS = envInt('PROFILE_CACHE_TTL_SECONDS', 25);
const STORY_RAIL_CACHE_TTL_SECONDS = envInt('STORY_RAIL_CACHE_TTL_SECONDS', 20);
const ADMIN_SETTINGS_CACHE_TTL_SECONDS = envInt('ADMIN_SETTINGS_CACHE_TTL_SECONDS', 45);
const CONTROL_CACHE_TTL_MS = envInt('CONTROL_CACHE_TTL_MS', dbDriver === 'postgres' ? 5000 : 2000);
const ADMIN_STATS_CACHE_TTL_MS = envInt('ADMIN_STATS_CACHE_TTL_MS', dbDriver === 'postgres' ? 12000 : 5000);
const ADMIN_LIVE_CACHE_TTL_MS = envInt('ADMIN_LIVE_CACHE_TTL_MS', dbDriver === 'postgres' ? 6000 : 3000);
const ADMIN_STORAGE_CACHE_TTL_MS = envInt('ADMIN_STORAGE_CACHE_TTL_MS', dbDriver === 'postgres' ? 45000 : 15000);
const MEMBERS_NAMES_CACHE_TTL_MS = envInt('MEMBERS_NAMES_CACHE_TTL_MS', dbDriver === 'postgres' ? 30000 : 10000);
const EXPLORE_SUGGESTIONS_CACHE_TTL_MS = envInt('EXPLORE_SUGGESTIONS_CACHE_TTL_MS', dbDriver === 'postgres' ? 15000 : 5000);
const ONLINE_TRUE_SQL_EXPR = "LOWER(COALESCE(NULLIF(TRIM(CAST(online AS TEXT)), ''), '0')) IN ('1','true','evet','yes')";

const cacheNamespaces = Object.freeze({
  feed: 'feed_page',
  profile: 'profile_summary',
  stories: 'story_rail',
  adminSettings: 'admin_settings'
});

function invalidateCacheNamespace(namespace) {
  Promise.resolve(bumpCacheNamespaceVersion(namespace)).catch((err) => {
    writeAppLog('warn', 'cache_namespace_bump_failed', {
      namespace,
      message: err?.message || 'unknown_error'
    });
  });
}

async function buildFeedCacheKey(userId, query) {
  return buildVersionedCacheKey(cacheNamespaces.feed, [
    `user:${Number(userId || 0)}`,
    `feedType:${String(query?.feedType || query?.feed || '').trim() || 'main'}`,
    `scope:${String(query?.scope || '').trim() || 'all'}`,
    `filter:${String(query?.filter || query?.sort || '').trim() || 'latest'}`,
    `limit:${Math.min(Math.max(parseInt(query?.limit || '20', 10), 1), 50)}`
  ]);
}

const loginRateLimit = createRateLimitMiddleware({
  bucket: 'auth_login',
  limit: envInt('RATE_LIMIT_LOGIN_MAX', 8),
  windowSeconds: envInt('RATE_LIMIT_LOGIN_WINDOW_SECONDS', 600),
  keyGenerator: (req) => `${req.ip}:${String(req.body?.kadi || '').trim().toLowerCase() || 'anonymous'}`,
  onBlocked: (_req, res) => res.status(429).send('Çok fazla giriş denemesi. Lütfen birkaç dakika sonra tekrar dene.')
});

const chatSendRateLimit = createRateLimitMiddleware({
  bucket: 'chat_send',
  limit: envInt('RATE_LIMIT_CHAT_SEND_MAX', 30),
  windowSeconds: envInt('RATE_LIMIT_CHAT_SEND_WINDOW_SECONDS', 60),
  keyGenerator: (req) => `user:${Number(req.session?.userId || 0)}`
});

const postWriteRateLimit = createRateLimitMiddleware({
  bucket: 'post_write',
  limit: envInt('RATE_LIMIT_POST_WRITE_MAX', 20),
  windowSeconds: envInt('RATE_LIMIT_POST_WRITE_WINDOW_SECONDS', 600),
  keyGenerator: (req) => `user:${Number(req.session?.userId || 0)}`
});

const commentWriteRateLimit = createRateLimitMiddleware({
  bucket: 'comment_write',
  limit: envInt('RATE_LIMIT_COMMENT_WRITE_MAX', 30),
  windowSeconds: envInt('RATE_LIMIT_COMMENT_WRITE_WINDOW_SECONDS', 600),
  keyGenerator: (req) => `user:${Number(req.session?.userId || 0)}`
});

const uploadRateLimit = createRateLimitMiddleware({
  bucket: 'upload_write',
  limit: envInt('RATE_LIMIT_UPLOAD_MAX', 25),
  windowSeconds: envInt('RATE_LIMIT_UPLOAD_WINDOW_SECONDS', 600),
  keyGenerator: (req) => `user:${Number(req.session?.userId || 0)}:ip:${req.ip}`
});

const connectionRequestRateLimit = createRateLimitMiddleware({
  bucket: 'connection_request_write',
  limit: envInt('RATE_LIMIT_CONNECTION_REQUEST_MAX', 20),
  windowSeconds: envInt('RATE_LIMIT_CONNECTION_REQUEST_WINDOW_SECONDS', 3600),
  keyGenerator: (req) => `user:${Number(req.session?.userId || 0)}`,
  onBlocked: (_req, res, verdict) => {
    const retryAfterSeconds = Math.max(Number(verdict?.retryAfterSeconds) || 0, 1);
    const retryAfterMinutes = Math.ceil(retryAfterSeconds / 60);
    return res.status(429).json({
      code: 'CONNECTION_REQUEST_RATE_LIMITED',
      message: `Çok fazla bağlantı isteği gönderdin. Lütfen ${retryAfterMinutes} dakika sonra tekrar dene.`,
      retryAfterSeconds,
      retryAfterMinutes
    });
  }
});

const mentorshipRequestRateLimit = createRateLimitMiddleware({
  bucket: 'mentorship_request_write',
  limit: envInt('RATE_LIMIT_MENTORSHIP_REQUEST_MAX', 12),
  windowSeconds: envInt('RATE_LIMIT_MENTORSHIP_REQUEST_WINDOW_SECONDS', 3600),
  keyGenerator: (req) => `user:${Number(req.session?.userId || 0)}`,
  onBlocked: (_req, res) => res.status(429).json({
    code: 'MENTORSHIP_REQUEST_RATE_LIMITED',
    message: 'Çok fazla mentorluk isteği gönderdin. Lütfen biraz bekleyip tekrar dene.'
  })
});

const CONNECTION_REQUEST_COOLDOWN_SECONDS = envInt('CONNECTION_REQUEST_COOLDOWN_SECONDS', 48 * 60 * 60);
const MENTORSHIP_REQUEST_COOLDOWN_SECONDS = envInt('MENTORSHIP_REQUEST_COOLDOWN_SECONDS', 72 * 60 * 60);
const TEACHER_NETWORK_MIN_CLASS_YEAR = 1950;
const TEACHER_NETWORK_MAX_CLASS_YEAR = 2100;

function getMediaUploadLimitBytes() {
  try {
    const settings = loadMediaSettings(sqlGet);
    const maxUploadBytes = Number(settings?.maxUploadBytes || 0);
    if (Number.isFinite(maxUploadBytes) && maxUploadBytes > 0) return maxUploadBytes;
  } catch {
    // fallback to env default
  }
  return envInt('MEDIA_MAX_UPLOAD_BYTES', 10 * 1024 * 1024);
}

function validateUploadedImageFile(filePath, { allowedMimes = allowedImageSafetyMimes, maxBytes = null } = {}) {
  const validation = validateUploadedFileSafety(filePath, { allowedMimes });
  if (!validation.ok) return validation;
  let size = 0;
  try {
    size = fs.statSync(filePath).size || 0;
  } catch {
    return { ok: false, reason: 'Dosya boyutu doğrulanamadı.' };
  }
  const limit = Number.isFinite(Number(maxBytes)) && Number(maxBytes) > 0 ? Number(maxBytes) : getMediaUploadLimitBytes();
  if (size > limit) {
    const maxMb = (limit / (1024 * 1024)).toFixed(1);
    return { ok: false, reason: `Dosya boyutu çok büyük. Maksimum: ${maxMb} MB.` };
  }
  return { ok: true, mime: validation.mime, size };
}

async function enforceUploadQuota(req, res, { fileSize = 0, bucket = 'uploads' } = {}) {
  const currentUser = getCurrentUser(req);
  const role = getUserRole(currentUser);
  const roleMultiplier = roleAtLeast(role, 'admin')
    ? Math.max(envInt('UPLOAD_QUOTA_ADMIN_MULTIPLIER', 3), 1)
    : 1;

  const maxFiles = envInt('UPLOAD_QUOTA_MAX_FILES', 140) * roleMultiplier;
  const maxBytes = envInt('UPLOAD_QUOTA_MAX_BYTES', 350 * 1024 * 1024) * roleMultiplier;
  const windowSeconds = envInt('UPLOAD_QUOTA_WINDOW_SECONDS', 24 * 60 * 60);
  const scope = req.session?.userId
    ? `user:${Number(req.session.userId)}`
    : `ip:${String(req.ip || 'unknown')}`;

  const verdict = await consumeUploadQuota({
    bucket,
    scope,
    bytes: Math.max(Number(fileSize || 0), 0),
    maxFiles,
    maxBytes,
    windowSeconds
  });

  if (verdict.limitFiles) res.setHeader('X-Upload-Quota-Limit-Files', String(verdict.limitFiles));
  if (verdict.limitBytes) res.setHeader('X-Upload-Quota-Limit-Bytes', String(verdict.limitBytes));
  if (verdict.remainingFiles !== null) res.setHeader('X-Upload-Quota-Remaining-Files', String(verdict.remainingFiles));
  if (verdict.remainingBytes !== null) res.setHeader('X-Upload-Quota-Remaining-Bytes', String(verdict.remainingBytes));
  if (verdict.retryAfterSeconds) res.setHeader('X-Upload-Quota-Reset', String(verdict.retryAfterSeconds));

  if (verdict.allowed) return true;
  if (verdict.retryAfterSeconds) res.setHeader('Retry-After', String(verdict.retryAfterSeconds));
  return false;
}

const createPostIdempotency = createIdempotencyMiddleware({
  namespace: 'new_post_create',
  pendingTtlSeconds: envInt('IDEMPOTENCY_POST_PENDING_TTL_SECONDS', 45),
  responseTtlSeconds: envInt('IDEMPOTENCY_POST_RESPONSE_TTL_SECONDS', 240),
  scopeResolver: (req) => `user:${Number(req.session?.userId || 0)}`,
  onPending: (_req, res) => res.status(409).send('Gönderi isteği zaten işleniyor.')
});

const chatSendIdempotency = createIdempotencyMiddleware({
  namespace: 'new_chat_send',
  pendingTtlSeconds: envInt('IDEMPOTENCY_CHAT_PENDING_TTL_SECONDS', 20),
  responseTtlSeconds: envInt('IDEMPOTENCY_CHAT_RESPONSE_TTL_SECONDS', 180),
  scopeResolver: (req) => `user:${Number(req.session?.userId || 0)}`,
  onPending: (_req, res) => res.status(409).send('Mesaj gönderimi zaten işleniyor.')
});

const messengerSendIdempotency = createIdempotencyMiddleware({
  namespace: 'messenger_send',
  pendingTtlSeconds: envInt('IDEMPOTENCY_MESSENGER_PENDING_TTL_SECONDS', 25),
  responseTtlSeconds: envInt('IDEMPOTENCY_MESSENGER_RESPONSE_TTL_SECONDS', 180),
  scopeResolver: (req) => `user:${Number(req.session?.userId || 0)}:thread:${Number(req.params?.id || 0)}`,
  onPending: (_req, res) => res.status(409).send('Bu messenger isteği zaten işleniyor.')
});

async function hardDeleteUser(userId, { sqlRun, sqlGet, sqlAll, uploadsDir, writeAppLog }) {
  const runGet = async (query, params = []) => Promise.resolve(sqlGet(query, params));
  const runAll = async (query, params = []) => Promise.resolve(sqlAll(query, params));
  const runExec = async (query, params = []) => Promise.resolve(sqlRun(query, params));

  const userIdStr = String(userId);
  const user = await runGet('SELECT kadi, resim FROM uyeler WHERE id = ?', [userId]);
  if (!user) return;

  const metadataTables = [
    'posts', 'post_comments', 'post_likes', 'stories', 'story_views',
    'events', 'event_responses', 'event_comments', 'groups', 'group_members',
    'group_join_requests', 'group_invites', 'group_events', 'group_announcements',
    'album_fotoyorum', 'album_foto', 'gelenkutusu', 'sdal_messenger_messages',
    'sdal_messenger_threads', 'follows', 'notifications', 'oyun_yilan',
    'oyun_tetris', 'game_scores', 'verification_requests', 'member_engagement_scores',
    'engagement_ab_assignments', 'network_suggestion_ab_assignments', 'oauth_accounts', 'chat_messages'
  ];
  const tableColumns = new Map();
  await Promise.all(metadataTables.map(async (table) => {
    const cols = await getTableColumnSetAsync(table);
    tableColumns.set(table, cols);
  }));
  const hasTableLocal = (table) => (tableColumns.get(table)?.size || 0) > 0;
  const hasColumnLocal = (table, column) => tableColumns.get(table)?.has(String(column || '').toLowerCase()) || false;
  const getUserColumn = (table) => {
    if (hasColumnLocal(table, 'user_id')) return 'user_id';
    if (hasColumnLocal(table, 'uye_id')) return 'uye_id';
    return '';
  };

  const userColumn = {
    posts: getUserColumn('posts'),
    postComments: getUserColumn('post_comments'),
    postLikes: getUserColumn('post_likes'),
    stories: getUserColumn('stories'),
    storyViews: getUserColumn('story_views'),
    eventResponses: getUserColumn('event_responses'),
    eventComments: getUserColumn('event_comments'),
    groupMembers: getUserColumn('group_members'),
    groupJoinRequests: getUserColumn('group_join_requests'),
    notifications: getUserColumn('notifications'),
    gameScores: getUserColumn('game_scores'),
    verificationRequests: getUserColumn('verification_requests'),
    memberEngagementScores: getUserColumn('member_engagement_scores'),
    engagementAbAssignments: getUserColumn('engagement_ab_assignments'),
    networkSuggestionAbAssignments: getUserColumn('network_suggestion_ab_assignments'),
    oauthAccounts: getUserColumn('oauth_accounts'),
    chatMessages: getUserColumn('chat_messages')
  };

  if (user.resim && user.resim !== 'yok' && user.resim.trim() !== '') {
    const avatarPath = path.join(uploadsDir, 'vesikalik', user.resim);
    try {
      if (fs.existsSync(avatarPath)) fs.unlinkSync(avatarPath);
    } catch (e) {
      writeAppLog('error', 'avatar_delete_failed', { userId, path: avatarPath, error: e.message });
    }
  }

  if (hasTableLocal('posts') && userColumn.posts) {
    const userPosts = await runAll(`SELECT id, image_record_id FROM posts WHERE ${userColumn.posts} = ?`, [userId]);
    for (const p of userPosts) {
      if (p.image_record_id) {
        await deleteImageRecord(p.image_record_id, runGet, runExec, uploadsDir, writeAppLog).catch(() => {});
      }
    }
    await runExec(`DELETE FROM posts WHERE ${userColumn.posts} = ?`, [userId]);
  }
  if (hasTableLocal('post_comments') && userColumn.postComments) await runExec(`DELETE FROM post_comments WHERE ${userColumn.postComments} = ?`, [userId]);
  if (hasTableLocal('post_likes') && userColumn.postLikes) await runExec(`DELETE FROM post_likes WHERE ${userColumn.postLikes} = ?`, [userId]);

  if (hasTableLocal('stories') && userColumn.stories) {
    const userStories = await runAll(`SELECT id, image_record_id FROM stories WHERE ${userColumn.stories} = ?`, [userId]);
    for (const s of userStories) {
      if (s.image_record_id) {
        await deleteImageRecord(s.image_record_id, runGet, runExec, uploadsDir, writeAppLog).catch(() => {});
      }
    }
    await runExec(`DELETE FROM stories WHERE ${userColumn.stories} = ?`, [userId]);
  }
  if (hasTableLocal('story_views') && userColumn.storyViews) await runExec(`DELETE FROM story_views WHERE ${userColumn.storyViews} = ?`, [userId]);

  if (hasTableLocal('events')) await runExec('DELETE FROM events WHERE created_by = ?', [userId]);
  if (hasTableLocal('event_responses') && userColumn.eventResponses) await runExec(`DELETE FROM event_responses WHERE ${userColumn.eventResponses} = ?`, [userId]);
  if (hasTableLocal('event_comments') && userColumn.eventComments) await runExec(`DELETE FROM event_comments WHERE ${userColumn.eventComments} = ?`, [userId]);

  if (hasTableLocal('groups')) {
    const ownedGroups = await runAll('SELECT id FROM groups WHERE owner_id = ?', [userId]);
    for (const g of ownedGroups) {
      if (hasTableLocal('group_members')) await runExec('DELETE FROM group_members WHERE group_id = ?', [g.id]);
      if (hasTableLocal('group_join_requests')) await runExec('DELETE FROM group_join_requests WHERE group_id = ?', [g.id]);
      if (hasTableLocal('group_invites')) await runExec('DELETE FROM group_invites WHERE group_id = ?', [g.id]);
      if (hasTableLocal('group_events')) await runExec('DELETE FROM group_events WHERE group_id = ?', [g.id]);
      if (hasTableLocal('group_announcements')) await runExec('DELETE FROM group_announcements WHERE group_id = ?', [g.id]);
      await runExec('DELETE FROM groups WHERE id = ?', [g.id]);
    }
  }
  if (hasTableLocal('group_members') && userColumn.groupMembers) await runExec(`DELETE FROM group_members WHERE ${userColumn.groupMembers} = ?`, [userId]);
  if (hasTableLocal('group_join_requests') && userColumn.groupJoinRequests) await runExec(`DELETE FROM group_join_requests WHERE ${userColumn.groupJoinRequests} = ? OR reviewed_by = ?`, [userId, userId]);
  if (hasTableLocal('group_invites')) await runExec('DELETE FROM group_invites WHERE invited_user_id = ? OR invited_by = ?', [userId, userId]);

  if (hasTableLocal('album_fotoyorum') && hasTableLocal('album_foto')) {
    await runExec('DELETE FROM album_fotoyorum WHERE fotoid IN (SELECT id FROM album_foto WHERE ekleyenid = ?)', [userId]);
  }
  if (hasTableLocal('album_fotoyorum')) {
    await runExec('DELETE FROM album_fotoyorum WHERE uyeadi = ?', [user.kadi]);
  }
  if (hasTableLocal('album_foto')) await runExec('DELETE FROM album_foto WHERE ekleyenid = ?', [userId]);

  if (hasTableLocal('gelenkutusu')) await runExec('DELETE FROM gelenkutusu WHERE kime = ? OR kimden = ?', [userIdStr, userIdStr]);
  if (hasTableLocal('sdal_messenger_messages')) await runExec('DELETE FROM sdal_messenger_messages WHERE sender_id = ? OR receiver_id = ?', [userId, userId]);
  if (hasTableLocal('sdal_messenger_threads')) await runExec('DELETE FROM sdal_messenger_threads WHERE user_a_id = ? OR user_b_id = ?', [userId, userId]);

  if (hasTableLocal('follows')) await runExec('DELETE FROM follows WHERE follower_id = ? OR following_id = ?', [userId, userId]);
  if (hasTableLocal('notifications') && userColumn.notifications) await runExec(`DELETE FROM notifications WHERE ${userColumn.notifications} = ? OR source_user_id = ?`, [userId, userId]);

  if (hasTableLocal('oyun_yilan')) await runExec('DELETE FROM oyun_yilan WHERE isim = ?', [user.kadi]);
  if (hasTableLocal('oyun_tetris')) await runExec('DELETE FROM oyun_tetris WHERE isim = ?', [user.kadi]);
  if (hasTableLocal('game_scores') && userColumn.gameScores) await runExec(`DELETE FROM game_scores WHERE ${userColumn.gameScores} = ?`, [userId]);

  if (hasTableLocal('verification_requests') && userColumn.verificationRequests) {
    const proofRows = await runAll(`SELECT proof_path, proof_image_record_id FROM verification_requests WHERE ${userColumn.verificationRequests} = ?`, [userId]);
    for (const row of proofRows) {
      if (row?.proof_image_record_id) {
        await deleteImageRecord(row.proof_image_record_id, runGet, runExec, uploadsDir, writeAppLog).catch(() => {});
        continue;
      }
      const proofPath = String(row?.proof_path || '').trim();
      if (!proofPath.startsWith('/uploads/verification-proofs/')) continue;
      const relativeProof = proofPath.replace(/^\/+/, '').replace(/^uploads\//, '');
      const absoluteProof = path.join(uploadsDir, relativeProof);
      try {
        if (fs.existsSync(absoluteProof)) fs.unlinkSync(absoluteProof);
      } catch (e) {
        writeAppLog('error', 'verification_proof_delete_failed', { userId, path: absoluteProof, error: e.message });
      }
    }
    await runExec(`DELETE FROM verification_requests WHERE ${userColumn.verificationRequests} = ? OR reviewer_id = ?`, [userId, userId]);
  }
  if (hasTableLocal('member_engagement_scores') && userColumn.memberEngagementScores) await runExec(`DELETE FROM member_engagement_scores WHERE ${userColumn.memberEngagementScores} = ?`, [userId]);
  if (hasTableLocal('engagement_ab_assignments') && userColumn.engagementAbAssignments) await runExec(`DELETE FROM engagement_ab_assignments WHERE ${userColumn.engagementAbAssignments} = ?`, [userId]);
  if (hasTableLocal('network_suggestion_ab_assignments') && userColumn.networkSuggestionAbAssignments) {
    await runExec(`DELETE FROM network_suggestion_ab_assignments WHERE ${userColumn.networkSuggestionAbAssignments} = ?`, [userId]);
  }
  if (hasTableLocal('oauth_accounts') && userColumn.oauthAccounts) await runExec(`DELETE FROM oauth_accounts WHERE ${userColumn.oauthAccounts} = ?`, [userId]);
  if (hasTableLocal('chat_messages') && userColumn.chatMessages) await runExec(`DELETE FROM chat_messages WHERE ${userColumn.chatMessages} = ?`, [userId]);

  await runExec('DELETE FROM uyeler WHERE id = ?', [userId]);
  writeAppLog('info', 'member_hard_deleted', { userId, kadi: user.kadi });
}

function quoteIdentifier(value) {
  return `"${String(value || '').replace(/"/g, '""')}"`;
}

function hasColumn(table, column) {
  try {
    if (dbDriver === 'postgres') {
      const row = sqlGet(
        `SELECT column_name
         FROM information_schema.columns
         WHERE table_schema = 'public' AND table_name = ? AND column_name = ?
         LIMIT 1`,
        [String(table || '').toLowerCase(), String(column || '').toLowerCase()]
      );
      return !!row;
    }
    const safeTable = quoteIdentifier(table);
    const cols = sqlAll(`PRAGMA table_info(${safeTable})`);
    return cols.some((c) => c.name === column);
  } catch {
    return false;
  }
}

function hasTable(table) {
  try {
    const safeTable = quoteIdentifier(table);
    if (dbDriver === 'postgres') {
      const row = sqlGet(
        "SELECT table_name FROM information_schema.tables WHERE table_schema = 'public' AND table_name = ?",
        [String(table || '').toLowerCase()]
      );
      return !!row;
    }
    const cols = sqlAll(`PRAGMA table_info(${safeTable})`);
    return cols && cols.length > 0;
  } catch {
    return false;
  }
}

const DEFAULT_SUPPORT_REQUEST_CATEGORIES = [
  ['graduation_year_change', 'Mezuniyet Yılı Değişikliği', 'Doğrulanmış üyelerin mezuniyet yılı değişiklik talepleri.'],
  ['profile_data_correction', 'Profil Veri Düzeltme', 'Kişisel profil bilgilerinde manuel düzenleme talepleri.'],
  ['account_status_review', 'Hesap Durumu İncelemesi', 'Hesap erişimi/yetki/ban inceleme talepleri.'],
  ['content_moderation_appeal', 'İçerik Moderasyon İtirazı', 'Silinen veya kısıtlanan içeriklere itiraz talepleri.'],
  ['group_management_support', 'Grup Yönetim Desteği', 'Grup moderasyonu veya sahiplik desteği talepleri.'],
  ['feature_access_request', 'Özellik Erişim Talebi', 'Yeni veya kısıtlı özelliklere erişim talepleri.']
];

const MODULE_DEFINITIONS = [
  { key: 'feed', label: 'Akış' },
  { key: 'main_feed', label: 'Ana Akış (Herkese Açık)' },
  { key: 'year_feed', label: 'Yıl Akışı (Dönemim)' },
  { key: 'explore', label: 'Keşfet' },
  { key: 'following', label: 'Takip' },
  { key: 'groups', label: 'Gruplar' },
  { key: 'messages', label: 'Mesajlar' },
  { key: 'messenger', label: 'Canlı Mesajlaşma' },
  { key: 'notifications', label: 'Bildirimler' },
  { key: 'albums', label: 'Albüm/Fotolar' },
  { key: 'games', label: 'Oyunlar' },
  { key: 'events', label: 'Etkinlikler' },
  { key: 'announcements', label: 'Duyurular' },
  { key: 'jobs', label: 'İş İlanları' },
  { key: 'profile', label: 'Profil' },
  { key: 'help', label: 'Yardım' },
  { key: 'requests', label: 'Üye Talepleri' }
];

const MODERATION_ACTION_DEFINITIONS = [
  { key: 'view', label: 'Görüntüleme', description: 'Listeleme ve detay görüntüleme' },
  { key: 'toggle', label: 'Aç/Kapat', description: 'Fonksiyonu kullanıcı erişimine açıp kapatma' },
  { key: 'create', label: 'Kayıt Ekleme', description: 'Yeni kayıt veya içerik oluşturma' },
  { key: 'update', label: 'Kayıt Güncelleme', description: 'Var olan içeriği düzenleme' },
  { key: 'delete', label: 'Silme', description: 'Kayıt veya içeriği kaldırma' },
  { key: 'moderate', label: 'Moderasyon Kararı', description: 'Onaylama, reddetme, gizleme, rapor işleme' },
  { key: 'export', label: 'Dışa Aktarım', description: 'Log/kayıt verisini dışa aktarma ve raporlama' }
];

const MODERATION_RESOURCE_DEFINITIONS = [
  { key: 'users', label: 'Üyeler', description: 'Profil, hesap durumu ve rol işlemleri' },
  { key: 'groups', label: 'Gruplar', description: 'Grup içerikleri ve üyelik yönetimi' },
  { key: 'posts', label: 'Postlar', description: 'Akış gönderileri ve yorum moderasyonu' },
  { key: 'stories', label: 'Hikayeler', description: 'Story içerik denetimi' },
  { key: 'chat', label: 'Canlı Sohbet', description: 'Canlı sohbet mesaj yönetimi' },
  { key: 'messages', label: 'Mesajlar', description: 'Kullanıcılar arası özel mesaj moderasyonu' },
  { key: 'events', label: 'Etkinlikler', description: 'Etkinlik oluşturma/onay akışları' },
  { key: 'announcements', label: 'Duyurular', description: 'Duyuru içerik moderasyonu' },
  { key: 'albums', label: 'Albüm ve Fotoğraflar', description: 'Albüm/fotoğraf kayıt işlemleri' },
  { key: 'filters', label: 'İçerik Filtreleri', description: 'Yasaklı kelime ve filtre kuralları' },
  { key: 'requests', label: 'Yönetim Talepleri', description: 'Destek ve inceleme talepleri' },
  { key: 'siteControls', label: 'Site Kontrolleri', description: 'Site genel mod ve modül kontrolü' },
  { key: 'database', label: 'Veritabanı Araçları', description: 'Kayıt tarama ve yedekleme işlemleri' },
  { key: 'logs', label: 'Loglar', description: 'Sistem ve uygulama log yönetimi' }
];

const MODERATION_PERMISSION_DEFINITIONS = MODERATION_RESOURCE_DEFINITIONS.flatMap((resource) =>
  MODERATION_ACTION_DEFINITIONS.map((action) => ({
    key: `${resource.key}.${action.key}`,
    resourceKey: resource.key,
    resourceLabel: resource.label,
    actionKey: action.key,
    actionLabel: action.label,
    description: `${resource.description} • ${action.description}`
  }))
);
const MODERATION_PERMISSION_KEY_SET = new Set(MODERATION_PERMISSION_DEFINITIONS.map((item) => item.key));

function ensureRuntimeDefaults() {
  const now = new Date().toISOString();
  if (dbDriver === 'postgres') {
    sqlRun(
      `INSERT INTO site_settings (id, site_open, maintenance_message, updated_at)
       VALUES (1, TRUE, ?, ?)
       ON CONFLICT (id) DO NOTHING`,
      ['Site geçici bakım modundadır. Lütfen daha sonra tekrar deneyin.', now]
    );
    for (const def of MODULE_DEFINITIONS) {
      sqlRun(
        `INSERT INTO module_settings (module_key, is_open, updated_at)
         VALUES (?, TRUE, ?)
         ON CONFLICT (module_key) DO UPDATE SET updated_at = excluded.updated_at`,
        [def.key, now]
      );
    }
    sqlRun(
      `INSERT INTO media_settings
        (id, storage_provider, local_base_path, thumb_width, feed_width, full_width, webp_quality, max_upload_bytes, avif_enabled, updated_at)
       VALUES
        (1, 'local', ?, 200, 800, 1600, 80, 10485760, FALSE, ?)
       ON CONFLICT (id) DO NOTHING`,
      [uploadsDir, now]
    );
    for (const [categoryKey, label, description] of DEFAULT_SUPPORT_REQUEST_CATEGORIES) {
      sqlRun(
        `INSERT INTO support_request_categories (category_key, label, description, is_active, created_at, updated_at)
         VALUES (?, ?, ?, TRUE, ?, ?)
         ON CONFLICT (category_key) DO UPDATE SET
           label = excluded.label,
           description = excluded.description,
           updated_at = excluded.updated_at`,
        [categoryKey, label, description, now, now]
      );
    }
    return;
  }

  if (hasTable('request_categories')) {
    for (const [categoryKey, label, description] of DEFAULT_SUPPORT_REQUEST_CATEGORIES) {
      sqlRun(
        `INSERT INTO request_categories (category_key, label, description, active, created_at, updated_at)
         VALUES (?, ?, ?, 1, ?, ?)
         ON CONFLICT(category_key) DO UPDATE SET
           label = excluded.label,
           description = excluded.description,
           updated_at = excluded.updated_at`,
        [categoryKey, label, description, now, now]
      );
    }
  }
}

async function ensureRootBootstrapAccount() {
  const rootPassword = String(process.env.ROOT_BOOTSTRAP_PASSWORD || '').trim();
  if (!rootPassword) {
    console.warn('ROOT_BOOTSTRAP_PASSWORD missing; root bootstrap skipped.');
    return;
  }

  const now = new Date().toISOString();
  const hashed = await hashPassword(rootPassword);

  if (dbDriver === 'postgres') {
    const existingRoot = sqlGet("SELECT id FROM users WHERE lower(role) = 'root' LIMIT 1");
    if (existingRoot) return;
    const result = sqlRun(
      `INSERT INTO users
        (username, password_hash, email, first_name, last_name, activation_token, is_active, created_at, avatar_path, graduation_year, is_profile_initialized, role, legacy_admin_flag, is_verified, verification_status, updated_at)
       VALUES (?, ?, ?, ?, ?, ?, TRUE, ?, '', 0, TRUE, 'root', TRUE, TRUE, 'approved', ?)`,
      ['root', hashed, 'root@localhost', 'System', 'Root', 'root-bootstrap', now, now]
    );
    const rootId = result?.lastInsertRowid || sqlGet("SELECT id FROM users WHERE username = 'root'")?.id;
    if (rootId) {
      sqlRun(
        "UPDATE users SET role = 'root', legacy_admin_flag = TRUE, is_verified = TRUE, verification_status = 'approved', updated_at = ? WHERE id = ?",
        [now, rootId]
      );
      sqlRun(
        'INSERT INTO audit_logs (actor_user_id, action, target_type, target_id, metadata, ip, user_agent, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
        [rootId, 'root_bootstrap', 'user', String(rootId), JSON.stringify({ bootstrap: true }), null, 'system', now]
      );
    }
    return;
  }

  const existingRoot = sqlGet("SELECT id FROM uyeler WHERE lower(role) = 'root' LIMIT 1");
  if (existingRoot) return;
  const result = sqlRun(
    `INSERT INTO uyeler (kadi, sifre, email, isim, soyisim, aktivasyon, aktiv, ilktarih, resim, mezuniyetyili, ilkbd, role, admin, verified, verification_status)
     VALUES (?, ?, ?, ?, ?, ?, 1, ?, '', '0', 1, 'root', 1, 1, 'approved')`,
    ['root', hashed, 'root@localhost', 'System', 'Root', 'root-bootstrap', now]
  );
  const rootId = result?.lastInsertRowid || sqlGet("SELECT id FROM uyeler WHERE kadi = 'root'")?.id;
  if (rootId) {
    sqlRun("UPDATE uyeler SET role = 'root', admin = 1 WHERE id = ?", [rootId]);
    if (hasTable('audit_log')) {
      sqlRun(
        'INSERT INTO audit_log (actor_user_id, action, target_type, target_id, metadata, ip, user_agent, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
        [rootId, 'root_bootstrap', 'user', String(rootId), JSON.stringify({ bootstrap: true }), null, 'system', now]
      );
    }
  }
}

// --- Multer memory storage for new image pipeline ---
const imageUpload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 20 * 1024 * 1024 },
  fileFilter: (_req, file, cb) => {
    const allowed = allowedImageSafetyMimes;
    if (!allowed.includes(file.mimetype?.toLowerCase())) {
      cb(new Error('Desteklenmeyen dosya türü.'));
    } else {
      cb(null, true);
    }
  }
});

const scryptAsync = promisify(crypto.scrypt);
const PASSWORD_HASH_PREFIX = 'scrypt$';
const E2E_PASSWORD_HASH_PREFIX = 'e2e-sha256$';
const e2eHarnessEnabledForAuth = String(process.env.E2E_HARNESS_ENABLED || '').trim().toLowerCase() === 'true';

function timingSafeTextEqual(a, b) {
  const left = Buffer.from(String(a || ''), 'utf8');
  const right = Buffer.from(String(b || ''), 'utf8');
  if (!left.length || left.length !== right.length) return false;
  try {
    return crypto.timingSafeEqual(left, right);
  } catch {
    return false;
  }
}

function hashE2EPassword(password) {
  const digest = crypto.createHash('sha256').update(String(password || ''), 'utf8').digest('hex');
  return `${E2E_PASSWORD_HASH_PREFIX}${digest}`;
}
const ROLE_PRIORITY = Object.freeze({ user: 0, mod: 1, admin: 2, root: 3 });

function normalizeRole(value) {
  const role = String(value || '').trim().toLowerCase();
  return ROLE_PRIORITY[role] !== undefined ? role : 'user';
}

function roleAtLeast(role, minRole) {
  return (ROLE_PRIORITY[normalizeRole(role)] || 0) >= (ROLE_PRIORITY[normalizeRole(minRole)] || 0);
}

function getUserRole(user) {
  const explicit = normalizeRole(user?.role);
  if (explicit !== 'user') return explicit;
  if (Number(user?.admin || 0) === 1) return 'admin';
  return 'user';
}

function hasAdminRole(user) {
  return roleAtLeast(getUserRole(user), 'admin');
}

function isVerifiedMember(user) {
  if (!user) return false;
  if (Number(user.verified || 0) === 1) return true;
  const status = String(user.verification_status || '').trim().toLowerCase();
  return status === 'approved' || status === 'verified';
}

function ensureVerifiedSocialHubMember(req, res) {
  const user = getCurrentUser(req);
  if (hasAdminSession(req, user)) return true;
  if (isVerifiedMember(user)) return true;
  res.status(403).json({
    code: 'VERIFICATION_REQUIRED',
    message: 'Bu özelliği kullanmak için profil doğrulaması gerekli.'
  });
  return false;
}

function buildModeratorPermissionMap(userId) {
  const map = new Map();
  if (!userId) return map;
  const rows = sqlAll('SELECT permission_key, enabled FROM moderator_permissions WHERE user_id = ?', [userId]) || [];
  for (const row of rows) {
    const key = String(row.permission_key || '').trim();
    if (!key) continue;
    map.set(key, Number(row.enabled || 0) === 1);
  }
  return map;
}

function getModeratorPermissionSummary(userId) {
  const map = buildModeratorPermissionMap(userId);
  const assignedKeys = [];
  for (const [key, enabled] of map.entries()) {
    if (enabled && MODERATION_PERMISSION_KEY_SET.has(key)) assignedKeys.push(key);
  }
  return {
    assignedKeys: assignedKeys.sort((a, b) => a.localeCompare(b)),
    permissionMap: Object.fromEntries(Array.from(map.entries())),
    resources: MODERATION_RESOURCE_DEFINITIONS.map((resource) => ({
      ...resource,
      permissions: MODERATION_ACTION_DEFINITIONS.map((action) => {
        const key = `${resource.key}.${action.key}`;
        return {
          key,
          enabled: map.get(key) === true,
          actionKey: action.key,
          actionLabel: action.label,
          description: action.description
        };
      })
    }))
  };
}

function replaceModeratorPermissions(userId, permissionKeys = [], actorId = null) {
  if (!userId) return;
  const normalized = new Set(
    (Array.isArray(permissionKeys) ? permissionKeys : [])
      .map((item) => String(item || '').trim())
      .filter((key) => MODERATION_PERMISSION_KEY_SET.has(key))
  );
  const now = new Date().toISOString();
  sqlRun('DELETE FROM moderator_permissions WHERE user_id = ?', [userId]);
  for (const permissionKey of MODERATION_PERMISSION_KEY_SET) {
    sqlRun(
      `INSERT INTO moderator_permissions (user_id, permission_key, enabled, created_by, updated_by, created_at, updated_at)
       VALUES (?, ?, ?, ?, ?, ?, ?)`,
      [userId, permissionKey, toDbBooleanParam(normalized.has(permissionKey)), actorId || userId, actorId || userId, now, now]
    );
  }
}

async function replaceModeratorPermissionsAsync(userId, permissionKeys = [], actorId = null) {
  if (!userId) return;
  const normalized = new Set(
    (Array.isArray(permissionKeys) ? permissionKeys : [])
      .map((item) => String(item || '').trim())
      .filter((key) => MODERATION_PERMISSION_KEY_SET.has(key))
  );
  const now = new Date().toISOString();
  await sqlRunAsync('DELETE FROM moderator_permissions WHERE user_id = ?', [userId]);
  for (const permissionKey of MODERATION_PERMISSION_KEY_SET) {
    await sqlRunAsync(
      `INSERT INTO moderator_permissions (user_id, permission_key, enabled, created_by, updated_by, created_at, updated_at)
       VALUES (?, ?, ?, ?, ?, ?, ?)`,
      [userId, permissionKey, toDbBooleanParam(normalized.has(permissionKey)), actorId || userId, actorId || userId, now, now]
    );
  }
}

function userHasModerationPermission(user, permissionKey) {
  if (!permissionKey || !MODERATION_PERMISSION_KEY_SET.has(permissionKey)) return false;
  const role = getUserRole(user);
  if (role === 'root' || role === 'admin') return true;
  if (role !== 'mod' || !user?.id) return false;
  const row = sqlGet('SELECT enabled FROM moderator_permissions WHERE user_id = ? AND permission_key = ? LIMIT 1', [user.id, permissionKey]);
  return Number(row?.enabled || 0) === 1;
}

function requireModerationPermission(permissionKey) {
  return (req, res, next) => {
    const user = req.authUser || getCurrentUser(req);
    if (!user) return res.status(401).send('Login required');
    if (!userHasModerationPermission(user, permissionKey)) return res.status(403).send('Bu işlem için moderasyon yetkin yok.');
    req.authUser = user;
    return next();
  };
}

function hasAdminSession(req, user = null) {
  const targetUser = user || getCurrentUser(req);
  return hasAdminRole(targetUser);
}

async function hashPassword(password) {
  const salt = crypto.randomBytes(16).toString('hex');
  const derived = await scryptAsync(String(password), salt, 64);
  return `${PASSWORD_HASH_PREFIX}${salt}$${Buffer.from(derived).toString('hex')}`;
}

async function verifyPassword(stored, candidate) {
  const storedText = String(stored || '');
  const rawCandidate = String(candidate || '');
  if (storedText.startsWith(E2E_PASSWORD_HASH_PREFIX)) {
    if (!e2eHarnessEnabledForAuth) return { ok: false, needsRehash: false };
    const expected = storedText.slice(E2E_PASSWORD_HASH_PREFIX.length);
    const actual = crypto.createHash('sha256').update(rawCandidate, 'utf8').digest('hex');
    return { ok: timingSafeTextEqual(expected, actual), needsRehash: false };
  }
  if (!storedText.startsWith(PASSWORD_HASH_PREFIX)) {
    return { ok: storedText === rawCandidate, needsRehash: storedText === rawCandidate };
  }
  const parts = storedText.split('$');
  if (parts.length !== 3) return { ok: false, needsRehash: false };
  const [, salt, expectedHex] = parts;
  const derived = await scryptAsync(rawCandidate, salt, 64);
  const expected = Buffer.from(expectedHex, 'hex');
  const actual = Buffer.from(derived);
  if (expected.length !== actual.length) return { ok: false, needsRehash: false };
  return { ok: crypto.timingSafeEqual(expected, actual), needsRehash: false };
}

function isRootUser(user) {
  return getUserRole(user) === 'root';
}

function writeAuditLog(req, { actorUserId = null, action, targetType = null, targetId = null, metadata = {} } = {}) {
  if (!action) return;
  sqlRun(
    `INSERT INTO audit_log (actor_user_id, action, target_type, target_id, metadata, ip, user_agent, created_at)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
    [
      actorUserId,
      action,
      targetType,
      targetId,
      JSON.stringify(metadata || {}),
      req.ip || null,
      String(req.headers['user-agent'] || '').slice(0, 500) || null,
      new Date().toISOString()
    ]
  );
}

function selectCompatUserById(userId) {
  if (!userId) return null;
  if (dbDriver !== 'postgres') {
    return sqlGet('SELECT * FROM uyeler WHERE id = ?', [userId]);
  }
  return sqlGet(
    `SELECT
       id,
       username AS kadi,
       password_hash AS sifre,
       email,
       first_name AS isim,
       last_name AS soyisim,
       COALESCE(avatar_path, 'yok') AS resim,
       CASE WHEN COALESCE(is_active, true) THEN 1 ELSE 0 END AS aktiv,
       CASE WHEN COALESCE(is_banned, false) THEN 1 ELSE 0 END AS yasak,
       CASE WHEN COALESCE(is_profile_initialized, true) THEN 1 ELSE 0 END AS ilkbd,
       CASE WHEN COALESCE(legacy_admin_flag, false) THEN 1 ELSE 0 END AS admin,
       CASE WHEN COALESCE(is_verified, false) THEN 1 ELSE 0 END AS verified,
       role,
       oauth_provider,
       oauth_subject,
       CASE WHEN COALESCE(oauth_email_verified, false) THEN 1 ELSE 0 END AS oauth_email_verified,
       graduation_year AS mezuniyetyili,
       privacy_consent_at AS kvkk_consent_at,
       directory_consent_at,
       CASE WHEN COALESCE(is_online, false) THEN 1 ELSE 0 END AS online,
       profile_view_count AS hit,
       last_activity_date AS sonislemtarih,
       last_activity_time AS sonislemsaat,
       last_seen_at AS sontarih,
       previous_last_seen_at AS oncekisontarih,
       last_ip AS sonip,
       CASE WHEN COALESCE(is_album_admin, false) THEN 1 ELSE 0 END AS albumadmin,
       quick_access_ids_json AS hizliliste
     FROM users
     WHERE id = ?`,
    [userId]
  );
}

function getCurrentUser(req) {
  if (!req.session.userId) return null;
  const cacheKey = String(req.session.userId);
  if (req._currentUserCache && req._currentUserCache.key === cacheKey) {
    return req._currentUserCache.value;
  }
  const user = selectCompatUserById(req.session.userId);
  req._currentUserCache = { key: cacheKey, value: user };
  return user;
}

const MIN_GRADUATION_YEAR = 1999;
const MAX_GRADUATION_YEAR = 2100;
const TEACHER_COHORT_VALUE = 'teacher';

function normalizeCohortValue(value) {
  const raw = String(value || '').trim().toLowerCase();
  if (raw === 'teacher' || raw === 'ogretmen') return TEACHER_COHORT_VALUE;
  return String(value || '').trim();
}

function parseGraduationYear(value) {
  const year = parseInt(String(value || '').trim(), 10);
  return Number.isFinite(year) ? year : NaN;
}

function hasValidGraduationYear(value) {
  if (normalizeCohortValue(value) === TEACHER_COHORT_VALUE) return true;
  const year = parseGraduationYear(value);
  return Number.isFinite(year) && year >= MIN_GRADUATION_YEAR && year <= MAX_GRADUATION_YEAR;
}

function hasKvkkConsent(user) {
  return Boolean(user?.kvkk_consent_at);
}

function hasDirectoryConsent(user) {
  return Boolean(user?.directory_consent_at);
}

function isOAuthProfileIncomplete(user) {
  const oauthProvider = String(user?.oauth_provider || '').trim();
  if (!oauthProvider) return false;
  return !hasValidGraduationYear(user?.mezuniyetyili) || !hasKvkkConsent(user) || !hasDirectoryConsent(user);
}

async function requireAuth(req, res, next) {
  if (!req.session.userId) return res.status(401).send('Login required');
  const user = getCurrentUser(req);
  if (!user) return res.status(401).send('Login required');
  req.authUser = user;
  const writeMethod = new Set(['POST', 'PUT', 'PATCH', 'DELETE']).has(String(req.method || '').toUpperCase());
  const writeAllowedWithoutVerification = [
    '/api/profile',
    '/api/profile/password',
    '/api/profile/photo',
    '/api/new/verified/request',
    '/api/new/verified/proof',
    '/api/new/requests',
    '/api/new/requests/upload'
  ];
  if (writeMethod) {
    const user = req.authUser;
    const isVerified = isVerifiedMember(user);
    const canWriteWithoutVerification = writeAllowedWithoutVerification.some((item) => req.path === item || req.path.startsWith(`${item}/`));
    if (!isVerified && !canWriteWithoutVerification) {
      return res.status(403).json({
        error: 'VERIFICATION_REQUIRED',
        message: 'Yazma işlemleri için önce profilinizi doğrulamanız gerekiyor.',
        verificationUrl: '/new/profile/verification'
      });
    }
  }
  if (req.path.startsWith('/api/new/')) {
    const user = req.authUser;
    if (isOAuthProfileIncomplete(user)) {
      return res.status(403).json({ error: 'PROFILE_INCOMPLETE', message: 'Mezuniyet yılını (en az 1999) girmeden bu özelliği kullanamazsın.' });
    }
  }
  if (isRootUser(user) && writeMethod) {
    const allowedRootPaths = ['/admin/users/', '/admin/moderators/', '/api/admin/login', '/api/admin/logout', '/api/auth/logout'];
    const allowed = allowedRootPaths.some((prefix) => req.path.startsWith(prefix));
    if (!allowed) return res.status(403).send('ROOT hesabı normal kullanıcı işlemleri yapamaz.');
  }

  return next();
}

function requireRole(role) {
  return (req, res, next) => {
    const user = req.authUser || getCurrentUser(req);
    if (!user) return res.status(401).send('Login required');
    if (!roleAtLeast(getUserRole(user), role)) return res.status(403).send('Yetki yok.');
    req.authUser = user;
    return next();
  };
}

function requireScopedModeration(graduationYearSelector = (req) => req.body?.graduationYear ?? req.params?.graduationYear ?? req.query?.graduationYear) {
  return (req, res, next) => {
    const user = req.authUser || getCurrentUser(req);
    if (!user) return res.status(401).send('Login required');
    const role = getUserRole(user);
    if (role === 'root' || role === 'admin') return next();
    if (role !== 'mod') return res.status(403).send('Moderasyon yetkisi gerekli.');
    const graduationYear = parseGraduationYear(typeof graduationYearSelector === 'function' ? graduationYearSelector(req) : graduationYearSelector);
    if (!Number.isFinite(graduationYear)) return res.status(400).send('Geçerli mezuniyet yılı gerekli.');
    const scope = sqlGet('SELECT id FROM moderator_scopes WHERE user_id = ? AND scope_type = ? AND scope_value = ?', [user.id, 'graduation_year', String(graduationYear)]);
    if (!scope) return res.status(403).send('Bu mezuniyet yılı için moderasyon yetkin yok.');
    req.authUser = user;
    return next();
  };
}

function parseAdminListPagination(query, { defaultLimit = 50, maxLimit = 200 } = {}) {
  const page = Math.max(parseInt(query?.page || '1', 10) || 1, 1);
  const limit = Math.min(Math.max(parseInt(query?.limit || String(defaultLimit), 10) || defaultLimit, 1), maxLimit);
  const offset = (page - 1) * limit;
  return { page, limit, offset };
}

function getModeratorScopedGraduationYears(userId) {
  if (!userId) return [];
  const rows = sqlAll(
    `SELECT DISTINCT scope_value
     FROM moderator_scopes
     WHERE user_id = ? AND scope_type = 'graduation_year'
     ORDER BY scope_value ASC`,
    [userId]
  ) || [];
  return rows
    .map((row) => String(row.scope_value || '').trim())
    .filter((value) => /^\d{4}$/.test(value));
}

function getModerationScopeContext(user) {
  const role = getUserRole(user);
  if (role === 'root' || role === 'admin') {
    return { role, isScopedModerator: false, years: [] };
  }
  if (role !== 'mod') {
    return { role, isScopedModerator: false, years: [] };
  }
  const years = getModeratorScopedGraduationYears(user?.id);
  return { role, isScopedModerator: true, years };
}

function applyModerationScopeFilter(context, params, graduationYearColumnSql) {
  if (!context?.isScopedModerator) return '';
  const years = Array.isArray(context.years) ? context.years : [];
  if (!years.length) return ' AND 1 = 0';
  const placeholders = years.map(() => '?').join(', ');
  params.push(...years);
  return ` AND CAST(COALESCE(${graduationYearColumnSql}, '') AS TEXT) IN (${placeholders})`;
}

function ensureCanModerateTargetUser(req, res, targetUserId, { notFoundMessage = 'Kullanıcı bulunamadı.' } = {}) {
  const actor = req.authUser || getCurrentUser(req);
  if (!actor) {
    res.status(401).send('Login required');
    return null;
  }
  const context = getModerationScopeContext(actor);
  const target = sqlGet('SELECT id, mezuniyetyili, role FROM uyeler WHERE id = ?', [targetUserId]);
  if (!target) {
    res.status(404).send(notFoundMessage);
    return null;
  }
  if (normalizeRole(target.role) === 'root') {
    res.status(403).send('Root kullanıcıya bu işlem uygulanamaz.');
    return null;
  }
  if (!context.isScopedModerator) return target;
  const targetYear = String(target.mezuniyetyili || '').trim();
  if (!targetYear || !context.years.includes(targetYear)) {
    res.status(403).send('Bu kullanıcı mezuniyet yılı kapsamınız dışında.');
    return null;
  }
  return target;
}

let siteControlCache = { expiresAt: 0, value: null };
let moduleControlCache = { expiresAt: 0, value: null };
let adminStatsResponseCache = { expiresAt: 0, key: '', value: null };
let adminLiveResponseCache = { expiresAt: 0, key: '', value: null };
let adminStorageSnapshotCache = { expiresAt: 0, value: null };
let membersNameRowsCache = { expiresAt: 0, value: null };
const exploreSuggestionsResponseCache = new Map();

function invalidateControlSnapshots() {
  siteControlCache.expiresAt = 0;
  moduleControlCache.expiresAt = 0;
}

function readSiteControlFromDb() {
  const row = dbDriver === 'postgres'
    ? (sqlGet('SELECT site_open, maintenance_message, updated_at FROM site_settings WHERE id = 1') || {})
    : (sqlGet('SELECT site_open, maintenance_message, updated_at FROM site_controls WHERE id = 1') || {});
  const rawSiteOpen = row.site_open;
  return {
    siteOpen: rawSiteOpen === true || Number(rawSiteOpen ?? 1) === 1,
    maintenanceMessage: String(row.maintenance_message || 'Site geçici bakım modundadır. Lütfen daha sonra tekrar deneyin.'),
    updatedAt: row.updated_at || null
  };
}

function getSiteControl() {
  const now = Date.now();
  if (siteControlCache.value && siteControlCache.expiresAt > now) return siteControlCache.value;
  const next = readSiteControlFromDb();
  siteControlCache = { value: next, expiresAt: now + CONTROL_CACHE_TTL_MS };
  return next;
}

function readModuleControlMapFromDb() {
  const rows = dbDriver === 'postgres'
    ? (sqlAll('SELECT module_key, is_open FROM module_settings') || [])
    : (sqlAll('SELECT module_key, is_open FROM module_controls') || []);
  const statusMap = Object.fromEntries(rows.map((row) => {
    const raw = row.is_open;
    const isOpen = raw === true || Number(raw || 0) === 1;
    return [String(row.module_key || ''), isOpen];
  }));
  for (const def of MODULE_DEFINITIONS) {
    if (typeof statusMap[def.key] !== 'boolean') statusMap[def.key] = true;
  }
  return statusMap;
}

function getModuleControlMap() {
  const now = Date.now();
  if (moduleControlCache.value && moduleControlCache.expiresAt > now) return moduleControlCache.value;
  const next = readModuleControlMapFromDb();
  moduleControlCache = { value: next, expiresAt: now + CONTROL_CACHE_TTL_MS };
  return next;
}

async function getCachedActiveMemberNameRows() {
  const now = Date.now();
  if (membersNameRowsCache.value && membersNameRowsCache.expiresAt > now) {
    return membersNameRowsCache.value;
  }
  const rows = await sqlAllAsync(
    "SELECT isim FROM uyeler WHERE (COALESCE(CAST(aktiv AS INTEGER), 1) = 1 OR LOWER(CAST(aktiv AS TEXT)) IN ('true','evet','yes')) AND COALESCE(CAST(yasak AS INTEGER), 0) = 0 ORDER BY isim"
  );
  membersNameRowsCache = {
    value: rows,
    expiresAt: now + MEMBERS_NAMES_CACHE_TTL_MS
  };
  return rows;
}

function readExploreSuggestionsCache(cacheKey) {
  const now = Date.now();
  const cached = exploreSuggestionsResponseCache.get(cacheKey);
  if (!cached) return null;
  if (cached.expiresAt <= now) {
    exploreSuggestionsResponseCache.delete(cacheKey);
    return null;
  }
  return cached.value;
}

function writeExploreSuggestionsCache(cacheKey, value) {
  const now = Date.now();
  exploreSuggestionsResponseCache.set(cacheKey, {
    value,
    expiresAt: now + EXPLORE_SUGGESTIONS_CACHE_TTL_MS
  });
  if (exploreSuggestionsResponseCache.size > 400) {
    for (const [key, entry] of exploreSuggestionsResponseCache.entries()) {
      if (!entry || entry.expiresAt <= now) exploreSuggestionsResponseCache.delete(key);
    }
  }
}

function resolveModuleKeyByPath(pathname) {
  const pathValue = String(pathname || '');
  const mapping = [
    ['feed', ['/new', '/api/new/feed', '/api/new/posts']],
    ['explore', ['/new/explore', '/api/new/explore']],
    ['following', ['/new/following', '/api/new/follows']],
    ['groups', ['/new/groups', '/api/new/groups']],
    ['messages', ['/new/messages', '/api/new/messages']],
    ['messenger', ['/new/messenger', '/api/new/messenger']],
    ['notifications', ['/new/notifications', '/api/new/notifications']],
    ['albums', ['/new/albums', '/api/new/albums', '/api/new/photos']],
    ['games', ['/new/games', '/api/games']],
    ['events', ['/new/events', '/api/new/events']],
    ['announcements', ['/new/announcements', '/api/new/announcements']],
    ['jobs', ['/new/jobs', '/api/new/jobs']],
    ['profile', ['/new/profile', '/api/profile']],
    ['help', ['/new/help']],
    ['requests', ['/new/requests', '/api/new/requests']]
  ];

  for (const [moduleKey, prefixes] of mapping) {
    if (prefixes.some((prefix) => {
      if (prefix === '/new') return pathValue === '/new' || pathValue === '/api/new/feed';
      return pathValue === prefix || pathValue.startsWith(`${prefix}/`);
    })) {
      return moduleKey;
    }
  }
  return null;
}



app.use((req, res, next) => {
  if (!req.session?.userId) return next();
  const user = getCurrentUser(req);
  if (!user) {
    req.session.userId = null;
    req.session.adminOk = false;
    return next();
  }
  if (!toTruthyFlag(user?.yasak)) return next();
  req.session.userId = null;
  req.session.adminOk = false;
  res.clearCookie('kadi');
  res.clearCookie('admingiris');
  if (req.path.startsWith('/api/')) {
    return res.status(403).json({ error: 'ACCOUNT_BANNED', message: 'Hesabınız yasaklandığı için bu işlemi yapamazsınız.' });
  }
  return res.redirect(302, '/');
});
function canBypassSiteOrModuleLocks(req) {
  const pathValue = String(req.path || '');
  if (pathValue.startsWith('/api/admin/')) return true;
  if (pathValue.startsWith('/api/new/admin/')) return true;
  if (pathValue === '/api/admin/login' || pathValue === '/api/admin/logout') return true;
  if (pathValue === '/api/admin/session' || pathValue === '/api/session' || pathValue === '/api/site-access') return true;
  if (pathValue === '/api/auth/login' || pathValue === '/api/auth/register' || pathValue === '/api/auth/logout') return true;
  if (pathValue.startsWith('/api/new/activation') || pathValue.startsWith('/api/new/password')) return true;
  if (pathValue.startsWith('/legacy/') || pathValue.startsWith('/uploads/')) return true;
  return false;
}

app.use((req, res, next) => {
  if (canBypassSiteOrModuleLocks(req)) return next();
  const siteControl = getSiteControl();
  if (!siteControl.siteOpen) {
    const user = getCurrentUser(req);
    const isAdminBypass = hasAdminSession(req, user);
    if (!isAdminBypass) {
      if (req.path.startsWith('/api/')) {
        return res.status(503).json({
          error: 'SITE_CLOSED',
          message: siteControl.maintenanceMessage,
          siteOpen: false
        });
      }
      if (req.path.startsWith('/new')) {
        return res.status(503).send(`<html><body style="margin:0;font-family:Inter,Segoe UI,sans-serif;background:linear-gradient(120deg,#0f172a,#1e293b);color:#e2e8f0;display:grid;place-items:center;min-height:100vh;"><div style="max-width:640px;padding:32px;border-radius:18px;background:rgba(15,23,42,.82);border:1px solid rgba(148,163,184,.3);box-shadow:0 30px 60px rgba(0,0,0,.25)"><h1 style="margin:0 0 8px;font-size:30px">SDAL Modern Geçici Olarak Kapalı</h1><p style="margin:0;font-size:17px;line-height:1.6">${siteControl.maintenanceMessage}</p></div></body></html>`);
      }
      return res.status(503).send(`<html><body bgcolor="#ffffff" style="font-family:Tahoma,Arial,sans-serif;color:#333;"><table width="760" align="center" cellspacing="0" cellpadding="12" style="margin-top:80px;border:1px solid #999;background:#f3f3f3"><tr bgcolor="#224488"><td><font color="#fff" size="4"><b>SDAL Classic Bakım Modu</b></font></td></tr><tr><td><font size="3">${siteControl.maintenanceMessage}</font></td></tr></table></body></html>`);
    }
  }

  const moduleKey = resolveModuleKeyByPath(req.path);
  if (!moduleKey) return next();
  const moduleMap = getModuleControlMap();
  if (moduleMap[moduleKey]) return next();
  const user = getCurrentUser(req);
  const isAdminBypass = hasAdminSession(req, user);
  if (isAdminBypass) return next();
  if (req.path.startsWith('/api/')) {
    return res.status(403).json({ error: 'MODULE_CLOSED', moduleKey, message: 'Bu modül geçici olarak kapatıldı.' });
  }
  if (req.path.startsWith('/new')) return res.redirect(302, '/new');
  return res.redirect(302, '/');
});

function requireAdmin(req, res, next) {
  const user = req.authUser || getCurrentUser(req);
  if (!user) return res.status(401).send('Login required');
  const role = getUserRole(user);
  if (!roleAtLeast(role, 'admin')) return res.status(403).send('Admin erişimi gerekli.');
  req.authUser = user;
  req.adminUser = user;
  return next();
}

function requireAlbumAdmin(req, res, next) {
  const user = getCurrentUser(req);
  if (!user) return res.status(401).send('Login required');
  if (user.albumadmin !== 1 && !hasAdminRole(user)) return res.status(403).send('Albüm yönetimi yetkisi gerekli.');
  req.adminUser = user;
  return next();
}

function isAdminMutationPath(pathValue) {
  const path = String(pathValue || '');
  if (path.startsWith('/api/admin/')) return true;
  if (path.startsWith('/api/new/admin/')) return true;
  if (path.startsWith('/admin/')) return true;
  return false;
}

function toAuditPathTemplate(pathValue) {
  return String(pathValue || '')
    .replace(/\/\d+(?=\/|$)/g, '/:id')
    .replace(/\/[0-9a-f]{8,}(?=\/|$)/gi, '/:id');
}

app.use((req, res, next) => {
  const method = String(req.method || '').toUpperCase();
  const isMutation = ['POST', 'PUT', 'PATCH', 'DELETE'].includes(method);
  if (!isMutation || !isAdminMutationPath(req.path)) return next();

  const actorUserId = req.session?.userId || null;
  res.on('finish', () => {
    if (!actorUserId) return;
    if (res.statusCode < 200 || res.statusCode >= 400) return;
    try {
      writeAuditLog(req, {
        actorUserId,
        action: `admin_api_${method.toLowerCase()}`,
        targetType: 'endpoint',
        targetId: toAuditPathTemplate(req.path),
        metadata: {
          method,
          path: req.path,
          statusCode: res.statusCode
        }
      });
    } catch {
      // Non-blocking best-effort audit; route success should remain unaffected.
    }
  });

  return next();
});

function parseOnlineHeartbeat(row) {
  const datePart = String(row?.sonislemtarih || '').trim();
  const timePart = String(row?.sonislemsaat || '').trim();
  if (!datePart || !timePart) return null;
  const candidates = [
    `${datePart}T${timePart}`,
    `${datePart.replace(/\./g, '-')}T${timePart.replace(/\./g, ':')}`
  ];
  for (const item of candidates) {
    const ms = Date.parse(item);
    if (Number.isFinite(ms)) return ms;
  }
  return null;
}

function isRowOnlineNow(row, maxIdleMs = 10 * 60 * 1000) {
  const ts = parseOnlineHeartbeat(row);
  if (ts && Date.now() - ts <= maxIdleMs) return true;
  const raw = String(row?.online ?? '').toLowerCase();
  return raw === '1' || raw === 'true' || raw === 'evet' || raw === 'yes';
}

const ONLINE_STALE_CLEANUP_INTERVAL_MS = 45 * 1000;
let lastOnlineCleanupAtMs = 0;

function cleanupStaleOnlineUsers(maxIdleMs = 5 * 60 * 1000, { force = false } = {}) {
  const now = Date.now();
  if (!force && now - lastOnlineCleanupAtMs < ONLINE_STALE_CLEANUP_INTERVAL_MS) return;
  lastOnlineCleanupAtMs = now;

  const rows = sqlAll(
    `SELECT id, sonislemtarih, sonislemsaat
     FROM uyeler
     WHERE ${ONLINE_TRUE_SQL_EXPR}`
  );
  const staleIds = [];
  for (const row of rows) {
    const ts = parseOnlineHeartbeat(row);
    if (!ts) continue;
    if (now - ts > maxIdleMs) {
      staleIds.push(row.id);
    }
  }
  if (!staleIds.length) return;
  const placeholders = staleIds.map(() => '?').join(', ');
  const offlineValue = (dbDriver === 'postgres' && getColumnType('uyeler', 'online') === 'boolean') ? 'FALSE' : '0';
  sqlRun(`UPDATE uyeler SET online = ${offlineValue} WHERE id IN (${placeholders})`, staleIds);
}

async function cleanupStaleOnlineUsersAsync(maxIdleMs = 5 * 60 * 1000, { force = false } = {}) {
  const now = Date.now();
  if (!force && now - lastOnlineCleanupAtMs < ONLINE_STALE_CLEANUP_INTERVAL_MS) return;
  lastOnlineCleanupAtMs = now;

  const rows = await sqlAllAsync(
    `SELECT id, sonislemtarih, sonislemsaat
     FROM uyeler
     WHERE ${ONLINE_TRUE_SQL_EXPR}`
  );
  const staleIds = [];
  for (const row of rows) {
    const ts = parseOnlineHeartbeat(row);
    if (!ts) continue;
    if (now - ts > maxIdleMs) staleIds.push(row.id);
  }
  if (!staleIds.length) return;
  const placeholders = staleIds.map(() => '?').join(', ');
  const offlineValue = (dbDriver === 'postgres' && getColumnType('uyeler', 'online') === 'boolean') ? 'FALSE' : '0';
  await sqlRunAsync(`UPDATE uyeler SET online = ${offlineValue} WHERE id IN (${placeholders})`, staleIds);
}

function toNumericUserIdOrNull(value) {
  const normalized = normalizeUserId(value);
  const numeric = Number(normalized);
  return Number.isFinite(numeric) ? Math.trunc(numeric) : null;
}

function listOnlineMembers({ limit = 12, excludeUserId = null } = {}) {
  cleanupStaleOnlineUsers();
  const safeLimit = Math.min(Math.max(Number(limit) || 12, 1), 100);
  const normalizedExcludeUserId = toNumericUserIdOrNull(excludeUserId);
  const rows = sqlAll(
    `SELECT u.id, u.kadi, u.isim, u.soyisim, u.resim, u.mezuniyetyili, u.sonislemtarih, u.sonislemsaat, u.online,
            COALESCE(es.score, 0) AS engagement_score
     FROM uyeler u
     LEFT JOIN member_engagement_scores es ON es.user_id = u.id
     WHERE (? IS NULL OR CAST(u.id AS INTEGER) <> CAST(? AS INTEGER))
       AND (u.role IS NULL OR LOWER(u.role) != 'root')
       AND ${ONLINE_TRUE_SQL_EXPR}
     ORDER BY COALESCE(es.score, 0) DESC, u.id DESC
     LIMIT ?`,
    [normalizedExcludeUserId, normalizedExcludeUserId, Math.max(safeLimit * 5, 24)]
  );
  return rows.filter((row) => isRowOnlineNow(row)).slice(0, safeLimit).map((row) => ({
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

async function listOnlineMembersAsync({ limit = 12, excludeUserId = null } = {}) {
  try {
    await cleanupStaleOnlineUsersAsync();
  } catch (err) {
    writeAppLog('warn', 'online_members_cleanup_failed', {
      message: err?.message || 'unknown_error'
    });
  }
  const safeLimit = Math.min(Math.max(Number(limit) || 12, 1), 100);
  const normalizedExcludeUserId = toNumericUserIdOrNull(excludeUserId);
  let rows = [];
  try {
    rows = await sqlAllAsync(
      `SELECT u.id, u.kadi, u.isim, u.soyisim, u.resim, u.mezuniyetyili, u.sonislemtarih, u.sonislemsaat, u.online,
              COALESCE(es.score, 0) AS engagement_score
       FROM uyeler u
       LEFT JOIN member_engagement_scores es ON es.user_id = u.id
       WHERE (? IS NULL OR CAST(u.id AS INTEGER) <> CAST(? AS INTEGER))
         AND (u.role IS NULL OR LOWER(u.role) != 'root')
         AND ${ONLINE_TRUE_SQL_EXPR}
       ORDER BY COALESCE(es.score, 0) DESC, u.id DESC
       LIMIT ?`,
      [normalizedExcludeUserId, normalizedExcludeUserId, Math.max(safeLimit * 5, 24)]
    );
  } catch (err) {
    writeAppLog('warn', 'online_members_query_fallback', {
      message: err?.message || 'unknown_error'
    });
    rows = await sqlAllAsync(
      `SELECT u.id, u.kadi, u.isim, u.soyisim, u.resim, u.mezuniyetyili, u.sonislemtarih, u.sonislemsaat, u.online,
              0 AS engagement_score
       FROM uyeler u
       WHERE (? IS NULL OR CAST(u.id AS INTEGER) <> CAST(? AS INTEGER))
         AND (u.role IS NULL OR LOWER(CAST(u.role AS TEXT)) != 'root')
         AND ${ONLINE_TRUE_SQL_EXPR}
       ORDER BY u.id DESC
       LIMIT ?`,
      [normalizedExcludeUserId, normalizedExcludeUserId, Math.max(safeLimit * 5, 24)]
    );
  }
  return rows.filter((row) => isRowOnlineNow(row)).slice(0, safeLimit).map((row) => ({
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
  if (hasAdminSession(req, user)) return true;
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
  writeAuditLog(req, {
    actorUserId: req.session?.userId || null,
    action,
    targetType: details?.targetType || null,
    targetId: details?.targetId != null ? String(details.targetId) : null,
    metadata: details
  });
}

const NOTIFICATION_PREFERENCE_CATEGORY_KEYS = Object.freeze([
  'social',
  'messaging',
  'groups',
  'events',
  'networking',
  'jobs',
  'system'
]);

const NOTIFICATION_EXPERIMENT_DEFAULTS = Object.freeze({
  sort_order: {
    key: 'sort_order',
    label: 'Sort order',
    description: 'Priority-first vs recent-first ordering on inbox surfaces.',
    status: 'active',
    variants: ['priority', 'recent']
  },
  cta_wording: {
    key: 'cta_wording',
    label: 'CTA wording',
    description: 'Action-first vs neutral call-to-action copy on notification cards.',
    status: 'active',
    variants: ['action', 'neutral']
  },
  inbox_layout: {
    key: 'inbox_layout',
    label: 'Inbox layout',
    description: 'Grouped sections vs flat feed layout for notifications page.',
    status: 'active',
    variants: ['grouped', 'flat']
  }
});

const NOTIFICATION_GOVERNANCE_CHECKLIST = Object.freeze([
  { key: 'target_required', label: 'Canonical target zorunlu', description: 'Yeni notification type doğrudan çözülebilir bir target üretmeli.' },
  { key: 'analytics_required', label: 'Analytics zorunlu', description: 'Impression, open ve gerekiyorsa action eventleri izlenmeli.' },
  { key: 'dedupe_required', label: 'Dedupe kuralı', description: 'Burst veya tekrar eden eventler için suppress/collapse kuralı tanımlanmalı.' },
  { key: 'priority_defined', label: 'Priority tanımı', description: 'Type için informational, important veya actionable seviyesi açık olmalı.' },
  { key: 'category_defined', label: 'Category tanımı', description: 'Type inbox bilgi mimarisindeki bir category altında yer almalı.' }
]);

const NOTIFICATION_DEDUPE_RULES = Object.freeze({
  like: { windowSeconds: 900, compareMessage: false },
  follow: { windowSeconds: 1800, compareMessage: false },
  comment: { windowSeconds: 300, compareMessage: false },
  event_reminder: { windowSeconds: 6 * 60 * 60, compareMessage: false },
  event_starts_soon: { windowSeconds: 6 * 60 * 60, compareMessage: false },
  event_invite: { windowSeconds: 2 * 60 * 60, compareMessage: false },
  group_invite: { windowSeconds: 2 * 60 * 60, compareMessage: false },
  group_invite_accepted: { windowSeconds: 30 * 60, compareMessage: false },
  group_invite_rejected: { windowSeconds: 30 * 60, compareMessage: false }
});

function ensureNotificationPreferencesTable() {
  sqlRun(`
    CREATE TABLE IF NOT EXISTS notification_user_preferences (
      user_id INTEGER PRIMARY KEY,
      social_enabled INTEGER NOT NULL DEFAULT 1,
      messaging_enabled INTEGER NOT NULL DEFAULT 1,
      groups_enabled INTEGER NOT NULL DEFAULT 1,
      events_enabled INTEGER NOT NULL DEFAULT 1,
      networking_enabled INTEGER NOT NULL DEFAULT 1,
      jobs_enabled INTEGER NOT NULL DEFAULT 1,
      system_enabled INTEGER NOT NULL DEFAULT 1,
      quiet_mode_enabled INTEGER NOT NULL DEFAULT 0,
      quiet_mode_start TEXT,
      quiet_mode_end TEXT,
      updated_at TEXT NOT NULL
    )
  `);
  sqlRun('CREATE INDEX IF NOT EXISTS idx_notification_preferences_updated ON notification_user_preferences (updated_at DESC)');
}

function ensureNotificationExperimentConfigsTable() {
  sqlRun(`
    CREATE TABLE IF NOT EXISTS notification_experiment_configs (
      experiment_key TEXT PRIMARY KEY,
      label TEXT,
      description TEXT,
      status TEXT NOT NULL DEFAULT 'active',
      variants_json TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )
  `);
  sqlRun('CREATE INDEX IF NOT EXISTS idx_notification_experiments_updated ON notification_experiment_configs (updated_at DESC)');
  const now = new Date().toISOString();
  for (const experiment of Object.values(NOTIFICATION_EXPERIMENT_DEFAULTS)) {
    sqlRun(
      `INSERT OR IGNORE INTO notification_experiment_configs
         (experiment_key, label, description, status, variants_json, updated_at)
       VALUES (?, ?, ?, ?, ?, ?)`,
      [
        experiment.key,
        experiment.label,
        experiment.description,
        experiment.status,
        JSON.stringify(experiment.variants),
        now
      ]
    );
  }
}

function readNotificationExperimentConfigs() {
  ensureNotificationExperimentConfigsTable();
  return (sqlAll(
    `SELECT experiment_key, label, description, status, variants_json, updated_at
     FROM notification_experiment_configs
     ORDER BY experiment_key ASC`
  ) || []).map((row) => {
    let variants = [];
    try {
      const parsed = JSON.parse(String(row.variants_json || '[]'));
      variants = Array.isArray(parsed) ? parsed : [];
    } catch {
      variants = [];
    }
    if (!variants.length) {
      variants = [...(NOTIFICATION_EXPERIMENT_DEFAULTS[row.experiment_key]?.variants || ['control'])];
    }
    return {
      key: String(row.experiment_key || '').trim(),
      label: String(row.label || '').trim(),
      description: String(row.description || '').trim(),
      status: String(row.status || 'active').trim().toLowerCase() === 'paused' ? 'paused' : 'active',
      variants: variants.map((item) => String(item || '').trim()).filter(Boolean),
      updated_at: row.updated_at || null
    };
  });
}

function getNotificationExperimentAssignments(userId) {
  const safeUserId = Number(userId || 0);
  const configs = readNotificationExperimentConfigs();
  const assignments = {};
  for (const config of configs) {
    const fallback = String(config.variants?.[0] || 'control');
    if (config.status !== 'active' || !safeUserId || !Array.isArray(config.variants) || config.variants.length < 2) {
      assignments[config.key] = fallback;
      continue;
    }
    const bucket = Math.abs((safeUserId * 31) + String(config.key || '').length) % config.variants.length;
    assignments[config.key] = String(config.variants[bucket] || fallback);
  }
  return assignments;
}

function defaultNotificationPreferenceRow(userId = null) {
  return {
    user_id: Number(userId || 0) || null,
    social_enabled: 1,
    messaging_enabled: 1,
    groups_enabled: 1,
    events_enabled: 1,
    networking_enabled: 1,
    jobs_enabled: 1,
    system_enabled: 1,
    quiet_mode_enabled: 0,
    quiet_mode_start: null,
    quiet_mode_end: null,
    updated_at: null
  };
}

function readNotificationPreferenceRow(userId) {
  const safeUserId = Number(userId || 0);
  ensureNotificationPreferencesTable();
  if (!safeUserId) return defaultNotificationPreferenceRow();
  const row = sqlGet('SELECT * FROM notification_user_preferences WHERE user_id = ?', [safeUserId]) || {};
  return {
    ...defaultNotificationPreferenceRow(safeUserId),
    ...row
  };
}

function mapNotificationPreferenceResponse(row) {
  const safeRow = row || defaultNotificationPreferenceRow();
  const categories = {};
  for (const key of NOTIFICATION_PREFERENCE_CATEGORY_KEYS) {
    categories[key] = Number(safeRow?.[`${key}_enabled`] ?? 1) === 1;
  }
  return {
    categories,
    quiet_mode: {
      enabled: Number(safeRow?.quiet_mode_enabled || 0) === 1,
      start: safeRow?.quiet_mode_start || null,
      end: safeRow?.quiet_mode_end || null
    },
    high_priority_override: true,
    updated_at: safeRow?.updated_at || null
  };
}

function isNotificationHighPriority(type) {
  const priority = getNotificationPriority(type);
  return priority === 'actionable' || priority === 'critical' || priority === 'important';
}

function shouldSuppressNotificationByPreference(userId, type) {
  const safeUserId = Number(userId || 0);
  if (!safeUserId) return false;
  const category = getNotificationCategory(type);
  if (!NOTIFICATION_PREFERENCE_CATEGORY_KEYS.includes(category)) return false;
  if (isNotificationHighPriority(type)) return false;
  const prefs = readNotificationPreferenceRow(safeUserId);
  return Number(prefs?.[`${category}_enabled`] ?? 1) !== 1;
}

function getNotificationDedupeRule(type) {
  return NOTIFICATION_DEDUPE_RULES[String(type || '').trim().toLowerCase()] || null;
}

function findRecentDuplicateNotification({ userId, type, sourceUserId = null, entityId = null, message = '' } = {}) {
  const rule = getNotificationDedupeRule(type);
  const safeUserId = Number(userId || 0);
  if (!rule || !safeUserId || !hasTable('notifications')) return null;
  const sinceIso = new Date(Date.now() - (Number(rule.windowSeconds || 0) * 1000)).toISOString();
  const compareMessage = rule.compareMessage === true;
  const query = `SELECT id, created_at
     FROM notifications
     WHERE user_id = ?
       AND LOWER(TRIM(COALESCE(type, ''))) = LOWER(?)
       AND COALESCE(source_user_id, 0) = COALESCE(?, 0)
       AND COALESCE(entity_id, 0) = COALESCE(?, 0)
       AND ${compareMessage ? "COALESCE(message, '') = COALESCE(?, '')" : '1 = 1'}
       AND COALESCE(CASE WHEN CAST(created_at AS TEXT) = '' THEN NULL ELSE created_at END, '1970-01-01T00:00:00.000Z') >= ?
     ORDER BY id DESC
     LIMIT 1`;
  const params = compareMessage
    ? [safeUserId, type, Number(sourceUserId || 0) || null, Number(entityId || 0) || null, String(message || ''), sinceIso]
    : [safeUserId, type, Number(sourceUserId || 0) || null, Number(entityId || 0) || null, sinceIso];
  return sqlGet(query, params) || null;
}

function addNotification({ userId, type, sourceUserId, entityId, message }) {
  const normalizedType = sanitizePlainUserText(String(type || '').trim().toLowerCase(), 120);
  const safeUserId = Number(userId || 0) || null;
  const safeSourceUserId = Number(sourceUserId || 0) || null;
  const safeEntityId = Number(entityId || 0) || null;
  const now = new Date().toISOString();
  if (!safeUserId) {
    logNotificationDeliveryAudit({
      notificationType: normalizedType,
      userId: null,
      sourceUserId: safeSourceUserId,
      entityId: safeEntityId,
      deliveryStatus: 'skipped',
      skipReason: 'missing_user_id',
      createdAt: now
    });
    return null;
  }
  if (shouldSuppressNotificationByPreference(safeUserId, normalizedType)) {
    logNotificationDeliveryAudit({
      notificationType: normalizedType,
      userId: safeUserId,
      sourceUserId: safeSourceUserId,
      entityId: safeEntityId,
      deliveryStatus: 'skipped',
      skipReason: 'category_disabled',
      createdAt: now
    });
    return null;
  }
  const duplicateNotification = findRecentDuplicateNotification({
    userId: safeUserId,
    type: normalizedType,
    sourceUserId: safeSourceUserId,
    entityId: safeEntityId,
    message
  });
  if (duplicateNotification) {
    logNotificationDeliveryAudit({
      notificationId: Number(duplicateNotification.id || 0) || null,
      notificationType: normalizedType,
      userId: safeUserId,
      sourceUserId: safeSourceUserId,
      entityId: safeEntityId,
      deliveryStatus: 'skipped',
      skipReason: 'deduped_recent_duplicate',
      createdAt: now
    });
    return Number(duplicateNotification.id || 0) || null;
  }
  try {
    const result = sqlRun(
      'INSERT INTO notifications (user_id, type, source_user_id, entity_id, message, created_at) VALUES (?, ?, ?, ?, ?, ?)',
      [safeUserId, normalizedType, safeSourceUserId, safeEntityId, message || '', now]
    );
    const notificationId = Number(result?.lastInsertRowid || 0) || null;
    if (shouldAuditNotificationDelivery(normalizedType)) {
      logNotificationDeliveryAudit({
        notificationId,
        notificationType: normalizedType,
        userId: safeUserId,
        sourceUserId: safeSourceUserId,
        entityId: safeEntityId,
        deliveryStatus: 'inserted',
        createdAt: now
      });
    }
    return notificationId;
  } catch (err) {
    logNotificationDeliveryAudit({
      notificationType: normalizedType,
      userId: safeUserId,
      sourceUserId: safeSourceUserId,
      entityId: safeEntityId,
      deliveryStatus: 'failed',
      errorMessage: err?.message || 'notification_insert_failed',
      createdAt: now
    });
    throw err;
  }
}

const NOTIFICATION_DELIVERY_AUDIT_TYPES = new Set([
  'group_join_request',
  'group_join_approved',
  'group_join_rejected',
  'group_invite',
  'group_invite_accepted',
  'group_invite_rejected',
  'group_role_changed',
  'event_invite',
  'event_response',
  'event_reminder',
  'event_starts_soon',
  'connection_request',
  'connection_accepted',
  'mentorship_request',
  'mentorship_accepted',
  'teacher_network_linked',
  'teacher_link_review_confirmed',
  'teacher_link_review_flagged',
  'teacher_link_review_rejected',
  'teacher_link_review_merged',
  'job_application',
  'job_application_reviewed',
  'job_application_accepted',
  'job_application_rejected',
  'verification_approved',
  'verification_rejected',
  'member_request_approved',
  'member_request_rejected',
  'announcement_approved',
  'announcement_rejected'
]);

function shouldAuditNotificationDelivery(type) {
  return NOTIFICATION_DELIVERY_AUDIT_TYPES.has(String(type || '').trim().toLowerCase());
}

function ensureNotificationDeliveryAuditTable() {
  sqlRun(`
    CREATE TABLE IF NOT EXISTS notification_delivery_audit (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      notification_id INTEGER,
      user_id INTEGER,
      source_user_id INTEGER,
      entity_id INTEGER,
      notification_type TEXT,
      delivery_status TEXT NOT NULL,
      skip_reason TEXT,
      error_message TEXT,
      created_at TEXT NOT NULL
    )
  `);
  sqlRun('CREATE INDEX IF NOT EXISTS idx_notification_delivery_audit_created ON notification_delivery_audit (created_at DESC)');
  sqlRun('CREATE INDEX IF NOT EXISTS idx_notification_delivery_audit_type ON notification_delivery_audit (notification_type, created_at DESC)');
}

function logNotificationDeliveryAudit({
  notificationId = null,
  userId = null,
  sourceUserId = null,
  entityId = null,
  notificationType = '',
  deliveryStatus = '',
  skipReason = '',
  errorMessage = '',
  createdAt = null
} = {}) {
  ensureNotificationDeliveryAuditTable();
  sqlRun(
    `INSERT INTO notification_delivery_audit
       (notification_id, user_id, source_user_id, entity_id, notification_type, delivery_status, skip_reason, error_message, created_at)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
    [
      Number(notificationId || 0) || null,
      Number(userId || 0) || null,
      Number(sourceUserId || 0) || null,
      Number(entityId || 0) || null,
      sanitizePlainUserText(String(notificationType || '').trim().toLowerCase(), 120) || null,
      sanitizePlainUserText(String(deliveryStatus || '').trim().toLowerCase(), 40) || 'unknown',
      sanitizePlainUserText(String(skipReason || '').trim().toLowerCase(), 120) || null,
      sanitizePlainUserText(String(errorMessage || '').trim(), 500) || null,
      createdAt || new Date().toISOString()
    ]
  );
}

const NOTIFICATION_TELEMETRY_EVENT_NAMES = new Set(['impression', 'open', 'action', 'landed', 'bounce', 'no_action']);

function normalizeNotificationTelemetryEventName(value) {
  const normalized = String(value || '').trim().toLowerCase();
  return NOTIFICATION_TELEMETRY_EVENT_NAMES.has(normalized) ? normalized : '';
}

function normalizeNotificationTelemetrySurface(value) {
  return sanitizePlainUserText(String(value || '').trim().toLowerCase(), 80) || 'unknown';
}

function normalizeNotificationTelemetryActionKind(value) {
  return sanitizePlainUserText(String(value || '').trim().toLowerCase(), 120) || '';
}

function ensureNotificationTelemetryEventsTable() {
  sqlRun(`
    CREATE TABLE IF NOT EXISTS notification_telemetry_events (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id INTEGER,
      notification_id INTEGER,
      event_name TEXT NOT NULL,
      notification_type TEXT,
      surface TEXT,
      action_kind TEXT,
      created_at TEXT NOT NULL
    )
  `);
  sqlRun('CREATE INDEX IF NOT EXISTS idx_notification_telemetry_user_created ON notification_telemetry_events (user_id, created_at DESC)');
  sqlRun('CREATE INDEX IF NOT EXISTS idx_notification_telemetry_notification ON notification_telemetry_events (notification_id, created_at DESC)');
}

function recordNotificationTelemetryEvent({
  userId = null,
  notificationId = null,
  eventName = '',
  notificationType = '',
  surface = '',
  actionKind = '',
  createdAt = null
} = {}) {
  const normalizedEventName = normalizeNotificationTelemetryEventName(eventName);
  if (!normalizedEventName) return false;
  ensureNotificationTelemetryEventsTable();
  sqlRun(
    `INSERT INTO notification_telemetry_events
       (user_id, notification_id, event_name, notification_type, surface, action_kind, created_at)
     VALUES (?, ?, ?, ?, ?, ?, ?)`,
    [
      Number(userId || 0) || null,
      Number(notificationId || 0) || null,
      normalizedEventName,
      sanitizePlainUserText(String(notificationType || '').trim().toLowerCase(), 120) || null,
      normalizeNotificationTelemetrySurface(surface),
      normalizeNotificationTelemetryActionKind(actionKind) || null,
      createdAt || new Date().toISOString()
    ]
  );
  return true;
}

const NOTIFICATION_CATEGORY_MAP = Object.freeze({
  like: 'social',
  comment: 'social',
  mention_post: 'social',
  mention_photo: 'social',
  photo_comment: 'social',
  follow: 'social',
  mention_message: 'messaging',
  mention_group: 'groups',
  group_join_request: 'groups',
  group_join_approved: 'groups',
  group_join_rejected: 'groups',
  group_invite: 'groups',
  group_invite_accepted: 'groups',
  group_invite_rejected: 'groups',
  group_role_changed: 'groups',
  mention_event: 'events',
  event_comment: 'events',
  event_invite: 'events',
  event_response: 'events',
  event_reminder: 'events',
  event_starts_soon: 'events',
  connection_request: 'networking',
  connection_accepted: 'networking',
  mentorship_request: 'networking',
  mentorship_accepted: 'networking',
  teacher_network_linked: 'networking',
  teacher_link_review_confirmed: 'networking',
  teacher_link_review_flagged: 'networking',
  teacher_link_review_rejected: 'networking',
  teacher_link_review_merged: 'networking',
  job_application: 'jobs',
  job_application_reviewed: 'jobs',
  job_application_accepted: 'jobs',
  job_application_rejected: 'jobs',
  verification_approved: 'system',
  verification_rejected: 'system',
  member_request_approved: 'system',
  member_request_rejected: 'system',
  announcement_approved: 'system',
  announcement_rejected: 'system'
});

const NOTIFICATION_PRIORITY_MAP = Object.freeze({
  like: 'informational',
  comment: 'important',
  mention_post: 'important',
  mention_photo: 'important',
  photo_comment: 'important',
  follow: 'informational',
  mention_message: 'important',
  mention_group: 'important',
  group_join_request: 'actionable',
  group_join_approved: 'important',
  group_join_rejected: 'important',
  group_invite: 'actionable',
  group_invite_accepted: 'important',
  group_invite_rejected: 'important',
  group_role_changed: 'important',
  mention_event: 'important',
  event_comment: 'important',
  event_invite: 'important',
  event_response: 'important',
  event_reminder: 'important',
  event_starts_soon: 'important',
  connection_request: 'actionable',
  connection_accepted: 'important',
  mentorship_request: 'actionable',
  mentorship_accepted: 'important',
  teacher_network_linked: 'important',
  teacher_link_review_confirmed: 'important',
  teacher_link_review_flagged: 'important',
  teacher_link_review_rejected: 'important',
  teacher_link_review_merged: 'important',
  job_application: 'actionable',
  job_application_reviewed: 'important',
  job_application_accepted: 'important',
  job_application_rejected: 'important',
  verification_approved: 'important',
  verification_rejected: 'important',
  member_request_approved: 'important',
  member_request_rejected: 'important',
  announcement_approved: 'important',
  announcement_rejected: 'important'
});

function getNotificationCategory(type) {
  return NOTIFICATION_CATEGORY_MAP[String(type || '').trim().toLowerCase()] || 'system';
}

function getNotificationPriority(type) {
  return NOTIFICATION_PRIORITY_MAP[String(type || '').trim().toLowerCase()] || 'informational';
}

const NOTIFICATION_ACTIONABLE_TYPES = Object.freeze(
  Object.entries(NOTIFICATION_PRIORITY_MAP)
    .filter(([, priority]) => priority === 'actionable' || priority === 'critical')
    .map(([type]) => type)
);

function isNotificationActionable(type) {
  const priority = getNotificationPriority(type);
  return priority === 'critical' || priority === 'actionable';
}

function ensureNotificationIndexes() {
  if (!hasTable('notifications')) return;
  try {
    sqlRun('CREATE INDEX IF NOT EXISTS idx_notifications_user_id_desc ON notifications (user_id, id DESC)');
  } catch {}
  try {
    sqlRun('CREATE INDEX IF NOT EXISTS idx_notifications_user_read_id ON notifications (user_id, read_at, id DESC)');
  } catch {}
}

function buildNotificationSortBucketSql(alias = 'n') {
  const actionableTypeSql = NOTIFICATION_ACTIONABLE_TYPES.map((type) => `'${type}'`).join(', ');
  return `CASE
    WHEN ${alias}.read_at IS NULL AND LOWER(TRIM(COALESCE(${alias}.type, ''))) IN (${actionableTypeSql}) THEN 0
    WHEN ${alias}.read_at IS NULL THEN 1
    WHEN LOWER(TRIM(COALESCE(${alias}.type, ''))) IN (${actionableTypeSql}) THEN 2
    ELSE 3
  END`;
}

function normalizeNotificationSortMode(sortMode = 'priority') {
  const mode = String(sortMode || 'priority').trim().toLowerCase();
  return mode === 'priority' ? 'priority' : 'recent';
}

function buildNotificationOrderSql(sortMode = 'priority', alias = 'n') {
  const mode = normalizeNotificationSortMode(sortMode);
  if (mode !== 'priority' || NOTIFICATION_ACTIONABLE_TYPES.length === 0) {
    return `ORDER BY ${alias}.id DESC`;
  }
  return `ORDER BY
    ${buildNotificationSortBucketSql(alias)} ASC,
    ${alias}.id DESC`;
}

function computeNotificationSortBucket(row) {
  const type = String(row?.type || '').trim().toLowerCase();
  const actionable = isNotificationActionable(type);
  if (!row?.read_at && actionable) return 0;
  if (!row?.read_at) return 1;
  if (actionable) return 2;
  return 3;
}

function parseNotificationCursor(rawCursor, sortMode = 'priority') {
  const raw = String(rawCursor || '').trim();
  if (!raw) return null;
  const mode = normalizeNotificationSortMode(sortMode);
  if (mode === 'priority' && raw.includes(':')) {
    const [bucketPart, idPart] = raw.split(':');
    const bucket = parseInt(bucketPart || '', 10);
    const id = parseInt(idPart || '', 10);
    if (Number.isFinite(bucket) && Number.isFinite(id) && id > 0) {
      return { bucket, id };
    }
  }
  const id = parseInt(raw, 10);
  if (!Number.isFinite(id) || id <= 0) return null;
  return { bucket: null, id };
}

function buildNotificationCursor(row, sortMode = 'priority') {
  const id = Number(row?.id || 0);
  if (!id) return null;
  const mode = normalizeNotificationSortMode(sortMode);
  if (mode !== 'priority') return String(id);
  return `${computeNotificationSortBucket(row)}:${id}`;
}

function buildNotificationTarget(row) {
  const notificationId = Number(row?.id || 0);
  const entityId = Number(row?.entity_id || 0);
  const sourceUserId = Number(row?.source_user_id || 0);
  const type = String(row?.type || '').trim().toLowerCase();
  const pushNotificationParam = (value) => `${value}${value.includes('?') ? '&' : '?'}notification=${notificationId}`;

  if ((type === 'like' || type === 'comment' || type === 'mention_post') && entityId) {
    const href = `/new?post=${entityId}&notification=${notificationId}`;
    return {
      href,
      route: '/new',
      entity_type: 'post',
      entity_id: entityId,
      context: { post: entityId, notification: notificationId }
    };
  }

  if (type === 'mention_photo' || type === 'photo_comment') {
    const href = entityId
      ? `/new/albums/photo/${entityId}?notification=${notificationId}`
      : `/new/notifications?notification=${notificationId}`;
    return {
      href,
      route: entityId ? `/new/albums/photo/${entityId}` : '/new/notifications',
      entity_type: 'photo',
      entity_id: entityId || null,
      context: { photo: entityId || null, notification: notificationId }
    };
  }

  if (type === 'mention_message') {
    const href = entityId
      ? `/new/messages/${entityId}?notification=${notificationId}`
      : `/new/messages?notification=${notificationId}`;
    return {
      href,
      route: entityId ? `/new/messages/${entityId}` : '/new/messages',
      entity_type: 'message',
      entity_id: entityId || null,
      context: { message: entityId || null, notification: notificationId }
    };
  }

  if (type === 'mention_group' && entityId) {
    const href = `/new/groups/${entityId}?tab=posts&notification=${notificationId}`;
    return {
      href,
      route: `/new/groups/${entityId}`,
      entity_type: 'group',
      entity_id: entityId,
      context: { tab: 'posts', notification: notificationId }
    };
  }

  if (type === 'group_join_request' && entityId) {
    const href = `/new/groups/${entityId}?tab=requests&notification=${notificationId}`;
    return {
      href,
      route: `/new/groups/${entityId}`,
      entity_type: 'group',
      entity_id: entityId,
      context: { tab: 'requests', notification: notificationId }
    };
  }

  if ((type === 'group_join_approved' || type === 'group_join_rejected') && entityId) {
    const href = `/new/groups/${entityId}?tab=members&notification=${notificationId}`;
    return {
      href,
      route: `/new/groups/${entityId}`,
      entity_type: 'group',
      entity_id: entityId,
      context: { tab: 'members', notification: notificationId }
    };
  }

  if (type === 'group_invite' && entityId) {
    const href = `/new/groups/${entityId}?tab=invite&notification=${notificationId}`;
    return {
      href,
      route: `/new/groups/${entityId}`,
      entity_type: 'group',
      entity_id: entityId,
      context: { tab: 'invite', notification: notificationId }
    };
  }

  if ((type === 'group_invite_accepted' || type === 'group_invite_rejected' || type === 'group_role_changed') && entityId) {
    const href = `/new/groups/${entityId}?tab=members&notification=${notificationId}`;
    return {
      href,
      route: `/new/groups/${entityId}`,
      entity_type: 'group',
      entity_id: entityId,
      context: { tab: 'members', notification: notificationId }
    };
  }

  if ((type === 'mention_event' || type === 'event_comment') && entityId) {
    const href = `/new/events?event=${entityId}&focus=comments&notification=${notificationId}`;
    return {
      href,
      route: '/new/events',
      entity_type: 'event',
      entity_id: entityId,
      context: { event: entityId, focus: 'comments', notification: notificationId }
    };
  }

  if (type === 'event_invite' && entityId) {
    const href = `/new/events?event=${entityId}&focus=response&notification=${notificationId}`;
    return {
      href,
      route: '/new/events',
      entity_type: 'event',
      entity_id: entityId,
      context: { event: entityId, focus: 'response', notification: notificationId }
    };
  }

  if (type === 'event_response' && entityId) {
    const href = `/new/events?event=${entityId}&focus=response&notification=${notificationId}`;
    return {
      href,
      route: '/new/events',
      entity_type: 'event',
      entity_id: entityId,
      context: { event: entityId, focus: 'response', notification: notificationId }
    };
  }

  if ((type === 'event_reminder' || type === 'event_starts_soon') && entityId) {
    const href = `/new/events?event=${entityId}&focus=details&notification=${notificationId}`;
    return {
      href,
      route: '/new/events',
      entity_type: 'event',
      entity_id: entityId,
      context: { event: entityId, focus: 'details', notification: notificationId }
    };
  }

  if (type === 'follow' && sourceUserId) {
    const href = `/new/members/${sourceUserId}?notification=${notificationId}&context=follow`;
    return {
      href,
      route: `/new/members/${sourceUserId}`,
      entity_type: 'user',
      entity_id: sourceUserId,
      context: { member: sourceUserId, notification: notificationId, context: 'follow' }
    };
  }

  if (type === 'connection_request') {
    const href = `/new/network/hub?section=incoming-connections${entityId ? `&request=${entityId}` : ''}&notification=${notificationId}`;
    return {
      href,
      route: '/new/network/hub',
      entity_type: 'connection_request',
      entity_id: entityId || null,
      context: { section: 'incoming-connections', request: entityId || null, notification: notificationId }
    };
  }

  if (type === 'connection_accepted') {
    const href = sourceUserId
      ? `/new/members/${sourceUserId}?notification=${notificationId}&context=connection_accepted`
      : `/new/network/hub?section=outgoing-connections&notification=${notificationId}`;
    return {
      href,
      route: sourceUserId ? `/new/members/${sourceUserId}` : '/new/network/hub',
      entity_type: sourceUserId ? 'user' : 'connection_request',
      entity_id: sourceUserId || entityId || null,
      context: sourceUserId
        ? { member: sourceUserId, notification: notificationId, context: 'connection_accepted' }
        : { section: 'outgoing-connections', notification: notificationId }
    };
  }

  if (type === 'mentorship_request') {
    const href = `/new/network/hub?section=incoming-mentorship${entityId ? `&request=${entityId}` : ''}&notification=${notificationId}`;
    return {
      href,
      route: '/new/network/hub',
      entity_type: 'mentorship_request',
      entity_id: entityId || null,
      context: { section: 'incoming-mentorship', request: entityId || null, notification: notificationId }
    };
  }

  if (type === 'mentorship_accepted') {
    const href = sourceUserId
      ? `/new/members/${sourceUserId}?notification=${notificationId}&context=mentorship_accepted`
      : `/new/network/hub?section=outgoing-mentorship&notification=${notificationId}`;
    return {
      href,
      route: sourceUserId ? `/new/members/${sourceUserId}` : '/new/network/hub',
      entity_type: sourceUserId ? 'user' : 'mentorship_request',
      entity_id: sourceUserId || entityId || null,
      context: sourceUserId
        ? { member: sourceUserId, notification: notificationId, context: 'mentorship_accepted' }
        : { section: 'outgoing-mentorship', notification: notificationId }
    };
  }

  if (type === 'teacher_network_linked') {
    const href = `/new/network/hub?section=teacher-notifications&notification=${notificationId}${entityId ? `&link=${entityId}` : ''}`;
    return {
      href,
      route: '/new/network/hub',
      entity_type: 'teacher_link',
      entity_id: entityId || null,
      context: { section: 'teacher-notifications', notification: notificationId, link: entityId || null }
    };
  }

  if (
    type === 'teacher_link_review_confirmed'
    || type === 'teacher_link_review_flagged'
    || type === 'teacher_link_review_rejected'
    || type === 'teacher_link_review_merged'
  ) {
    const reviewStatus = type.replace('teacher_link_review_', '');
    const href = `/new/network/teachers?notification=${notificationId}${entityId ? `&link=${entityId}` : ''}&review=${reviewStatus}`;
    return {
      href,
      route: '/new/network/teachers',
      entity_type: 'teacher_link',
      entity_id: entityId || null,
      context: { notification: notificationId, link: entityId || null, review: reviewStatus }
    };
  }

  if (type === 'job_application' && entityId) {
    const href = `/new/jobs?job=${entityId}&tab=applications&notification=${notificationId}`;
    return {
      href,
      route: '/new/jobs',
      entity_type: 'job',
      entity_id: entityId,
      context: { job: entityId, tab: 'applications', notification: notificationId }
    };
  }

  if (
    (type === 'job_application_reviewed' || type === 'job_application_accepted' || type === 'job_application_rejected')
    && entityId
  ) {
    ensureJobApplicationsTable();
    const applicationRow = sqlGet('SELECT id, job_id FROM job_applications WHERE id = ?', [entityId]);
    const jobId = Number(applicationRow?.job_id || 0);
    const href = jobId
      ? `/new/jobs?job=${jobId}&focus=my-application&application=${entityId}&notification=${notificationId}`
      : `/new/jobs?notification=${notificationId}`;
    return {
      href,
      route: '/new/jobs',
      entity_type: 'job_application',
      entity_id: entityId,
      context: { job: jobId || null, application: entityId, focus: 'my-application', notification: notificationId }
    };
  }

  if ((type === 'verification_approved' || type === 'verification_rejected')) {
    const status = type.replace('verification_', '');
    const href = `/new/profile/verification?notification=${notificationId}&status=${status}`;
    return {
      href,
      route: '/new/profile/verification',
      entity_type: 'verification_request',
      entity_id: entityId || null,
      context: { notification: notificationId, status }
    };
  }

  if ((type === 'member_request_approved' || type === 'member_request_rejected') && entityId) {
    const status = type.replace('member_request_', '');
    const href = `/new/requests?request=${entityId}&notification=${notificationId}&status=${status}`;
    return {
      href,
      route: '/new/requests',
      entity_type: 'member_request',
      entity_id: entityId,
      context: { request: entityId, notification: notificationId, status }
    };
  }

  if ((type === 'announcement_approved' || type === 'announcement_rejected') && entityId) {
    const status = type.replace('announcement_', '');
    const href = `/new/announcements?announcement=${entityId}&notification=${notificationId}&status=${status}`;
    return {
      href,
      route: '/new/announcements',
      entity_type: 'announcement',
      entity_id: entityId,
      context: { announcement: entityId, notification: notificationId, status }
    };
  }

  const href = pushNotificationParam('/new');
  return {
    href,
    route: '/new',
    entity_type: '',
    entity_id: entityId || null,
    context: { notification: notificationId }
  };
}

function buildNotificationActions(row) {
  const target = buildNotificationTarget(row);
  const type = String(row?.type || '').trim().toLowerCase();
  const actions = [{
    kind: 'open',
    label: 'Aç',
    href: target.href
  }];

  if (type === 'group_invite' && String(row?.invite_status || 'pending') === 'pending' && Number(row?.entity_id || 0) > 0) {
    actions.push(
      {
        kind: 'accept_group_invite',
        label: 'Kabul Et',
        method: 'POST',
        endpoint: `/api/new/groups/${Number(row.entity_id)}/invitations/respond`,
        body: { action: 'accept' }
      },
      {
        kind: 'reject_group_invite',
        label: 'Reddet',
        method: 'POST',
        endpoint: `/api/new/groups/${Number(row.entity_id)}/invitations/respond`,
        body: { action: 'reject' }
      }
    );
  }

  if (type === 'connection_request' && String(row?.request_status || 'pending') === 'pending' && Number(row?.entity_id || 0) > 0) {
    actions.push(
      {
        kind: 'accept_connection_request',
        label: 'Kabul Et',
        method: 'POST',
        endpoint: `/api/new/connections/accept/${Number(row.entity_id)}`,
        body: { source_surface: 'notifications_page' }
      },
      {
        kind: 'ignore_connection_request',
        label: 'Yoksay',
        method: 'POST',
        endpoint: `/api/new/connections/ignore/${Number(row.entity_id)}`,
        body: { source_surface: 'notifications_page' }
      }
    );
  }

  if (type === 'mentorship_request' && String(row?.request_status || 'requested') === 'requested' && Number(row?.entity_id || 0) > 0) {
    actions.push(
      {
        kind: 'accept_mentorship_request',
        label: 'Kabul Et',
        method: 'POST',
        endpoint: `/api/new/mentorship/accept/${Number(row.entity_id)}`,
        body: { source_surface: 'notifications_page' }
      },
      {
        kind: 'decline_mentorship_request',
        label: 'Reddet',
        method: 'POST',
        endpoint: `/api/new/mentorship/decline/${Number(row.entity_id)}`,
        body: { source_surface: 'notifications_page' }
      }
    );
  }

  if (type === 'teacher_network_linked' && !row?.read_at) {
    actions.push({
      kind: 'mark_teacher_notifications_read',
      label: 'Okundu yap',
      method: 'POST',
      endpoint: '/api/new/network/inbox/teacher-links/read',
      body: { source_surface: 'notifications_page' }
    });
  }

  return actions;
}

async function enrichNotificationRows(rows, userId) {
  const safeRows = Array.isArray(rows) ? rows : [];
  const inviteEntityIds = Array.from(
    new Set(
      safeRows
        .filter((row) => String(row?.type || '') === 'group_invite' && Number(row?.entity_id || 0) > 0)
        .map((row) => Number(row.entity_id))
    )
  );
  const inviteStatusMap = new Map();
  const connectionRequestIds = Array.from(
    new Set(
      safeRows
        .filter((row) => String(row?.type || '') === 'connection_request' && Number(row?.entity_id || 0) > 0)
        .map((row) => Number(row.entity_id))
    )
  );
  const mentorshipRequestIds = Array.from(
    new Set(
      safeRows
        .filter((row) => String(row?.type || '') === 'mentorship_request' && Number(row?.entity_id || 0) > 0)
        .map((row) => Number(row.entity_id))
    )
  );
  const connectionStatusMap = new Map();
  const mentorshipStatusMap = new Map();
  if (inviteEntityIds.length > 0) {
    const inviteRows = await sqlAllAsync(
      `SELECT group_id, status, id
       FROM group_invites
       WHERE invited_user_id = ?
         AND group_id IN (${inviteEntityIds.map(() => '?').join(',')})
       ORDER BY id DESC`,
      [userId, ...inviteEntityIds]
    );
    for (const inviteRow of inviteRows) {
      const groupId = Number(inviteRow.group_id || 0);
      if (!groupId || inviteStatusMap.has(groupId)) continue;
      inviteStatusMap.set(groupId, String(inviteRow.status || 'pending'));
    }
  }

  if (connectionRequestIds.length > 0) {
    const connectionRows = await sqlAllAsync(
      `SELECT id, status
       FROM connection_requests
       WHERE id IN (${connectionRequestIds.map(() => '?').join(',')})`,
      connectionRequestIds
    );
    for (const connectionRow of connectionRows) {
      connectionStatusMap.set(Number(connectionRow.id || 0), String(connectionRow.status || 'pending'));
    }
  }

  if (mentorshipRequestIds.length > 0) {
    const mentorshipRows = await sqlAllAsync(
      `SELECT id, status
       FROM mentorship_requests
       WHERE id IN (${mentorshipRequestIds.map(() => '?').join(',')})`,
      mentorshipRequestIds
    );
    for (const mentorshipRow of mentorshipRows) {
      mentorshipStatusMap.set(Number(mentorshipRow.id || 0), String(mentorshipRow.status || 'requested'));
    }
  }

  return safeRows.map((row) => {
    const inviteStatus = String(row?.type || '') === 'group_invite' && row?.entity_id
      ? (inviteStatusMap.get(Number(row.entity_id || 0)) || 'pending')
      : undefined;
    const requestStatus = String(row?.type || '') === 'connection_request'
      ? (connectionStatusMap.get(Number(row?.entity_id || 0)) || '')
      : String(row?.type || '') === 'mentorship_request'
        ? (mentorshipStatusMap.get(Number(row?.entity_id || 0)) || '')
        : '';
    const baseRow = {
      ...row,
      ...(inviteStatus ? { invite_status: inviteStatus } : {}),
      ...(requestStatus ? { request_status: requestStatus } : {})
    };
    const category = getNotificationCategory(baseRow?.type);
    const priority = getNotificationPriority(baseRow?.type);
    return {
      ...baseRow,
      category,
      priority,
      is_actionable: isNotificationActionable(baseRow?.type),
      target: buildNotificationTarget(baseRow),
      actions: buildNotificationActions(baseRow)
    };
  });
}

async function enqueueBackgroundJob(type, payload, options = {}) {
  if (!backgroundJobQueue || !type) return { ok: false, backend: 'none', jobId: null };
  try {
    return await backgroundJobQueue.enqueue(type, payload, options);
  } catch (err) {
    writeAppLog('warn', 'background_job_enqueue_failed', {
      type,
      message: err?.message || 'unknown_error'
    });
    return { ok: false, backend: 'error', jobId: null };
  }
}

function notifyMentionsSync({ text, sourceUserId, entityId, type = 'mention', message = 'Senden bahsetti.', allowedUserIds = null }) {
  const ids = findMentionUserIds(text, sourceUserId);
  const allowed = Array.isArray(allowedUserIds) ? new Set(allowedUserIds.map((v) => String(normalizeUserId(v)))) : null;
  for (const userId of ids) {
    if (allowed && !allowed.has(String(normalizeUserId(userId)))) continue;
    addNotification({ userId, type, sourceUserId, entityId, message });
  }
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

function toDbBooleanParam(value) {
  const bool = toTruthyFlag(value);
  return dbDriver === 'postgres' ? bool : (bool ? 1 : 0);
}

function toDbNumericFlag(value) {
  return toTruthyFlag(value) ? 1 : 0;
}

const columnTypeCache = new Map();
const tableColumnSetCache = new Map();

function getColumnType(table, column) {
  const key = `${String(table || '').toLowerCase()}.${String(column || '').toLowerCase()}`;
  if (columnTypeCache.has(key)) return columnTypeCache.get(key);
  let type = '';
  try {
    if (dbDriver === 'postgres') {
      const row = sqlGet(
        `SELECT data_type
         FROM information_schema.columns
         WHERE table_schema = 'public' AND table_name = ? AND column_name = ?
         LIMIT 1`,
        [String(table || '').toLowerCase(), String(column || '').toLowerCase()]
      );
      type = String(row?.data_type || '').toLowerCase();
    } else {
      const safeTable = quoteIdentifier(table);
      const cols = sqlAll(`PRAGMA table_info(${safeTable})`);
      const found = cols.find((c) => String(c.name || '').toLowerCase() === String(column || '').toLowerCase());
      type = String(found?.type || '').toLowerCase();
    }
  } catch {
    type = '';
  }
  columnTypeCache.set(key, type);
  return type;
}

function toDbFlagForColumn(table, column, value) {
  const bool = toTruthyFlag(value);
  if (dbDriver !== 'postgres') return bool ? 1 : 0;
  const type = getColumnType(table, column);
  if (type === 'boolean') return bool;
  if (type.includes('int') || type === 'numeric' || type === 'real' || type === 'double precision') {
    return bool ? 1 : 0;
  }
  // last-resort literal accepted by PostgreSQL boolean and numeric parsers
  return bool ? '1' : '0';
}

async function getTableColumnSetAsync(table) {
  const tableName = String(table || '').toLowerCase();
  if (!tableName) return new Set();
  const cacheKey = `${dbDriver}:${tableName}`;
  const cached = tableColumnSetCache.get(cacheKey);
  if (cached) return new Set(cached);

  let set = new Set();
  try {
    if (dbDriver === 'postgres') {
      const rows = await sqlAllAsync(
        `SELECT column_name
         FROM information_schema.columns
         WHERE table_schema = 'public' AND table_name = ?`,
        [tableName]
      );
      set = new Set((rows || []).map((r) => String(r.column_name || '').toLowerCase()).filter(Boolean));
    } else {
      const safeTable = quoteIdentifier(tableName);
      const rows = await sqlAllAsync(`PRAGMA table_info(${safeTable})`);
      set = new Set((rows || []).map((r) => String(r.name || '').toLowerCase()).filter(Boolean));
    }
  } catch {
    set = new Set();
  }
  tableColumnSetCache.set(cacheKey, Array.from(set));
  return set;
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
        toDbBooleanParam(cfg.enabled),
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

function ensureNetworkSuggestionAbConfigRows() {
  ensureNetworkSuggestionAbTables();
  const now = new Date().toISOString();
  for (const [variant, cfg] of Object.entries(networkSuggestionDefaultVariants)) {
    const existing = sqlGet('SELECT variant FROM network_suggestion_ab_config WHERE variant = ?', [variant]);
    if (existing) continue;
    sqlRun(
      `INSERT INTO network_suggestion_ab_config
       (variant, name, description, traffic_pct, enabled, params_json, updated_at)
       VALUES (?, ?, ?, ?, ?, ?, ?)`,
      [
        variant,
        cfg.name,
        cfg.description,
        cfg.trafficPct,
        toDbBooleanParam(cfg.enabled),
        JSON.stringify(cfg.params),
        now
      ]
    );
  }
}

function getNetworkSuggestionAbConfigs() {
  ensureNetworkSuggestionAbConfigRows();
  const rows = sqlAll(
    `SELECT variant, name, description, traffic_pct, enabled, params_json, updated_at
     FROM network_suggestion_ab_config
     ORDER BY variant ASC`
  );
  const items = [];
  for (const row of rows) {
    const variant = String(row.variant || '').trim().toUpperCase();
    const fallback = networkSuggestionDefaultVariants[variant]?.params || networkSuggestionDefaultParams;
    let parsed = {};
    try {
      parsed = row.params_json ? JSON.parse(row.params_json) : {};
    } catch {
      parsed = {};
    }
    items.push({
      variant,
      name: String(row.name || networkSuggestionDefaultVariants[variant]?.name || variant),
      description: String(row.description || networkSuggestionDefaultVariants[variant]?.description || ''),
      trafficPct: clamp(Number(row.traffic_pct || 0), 0, 100),
      enabled: Number(row.enabled || 0) === 1 ? 1 : 0,
      params: normalizeNetworkSuggestionParams(parsed, fallback),
      updatedAt: row.updated_at || null
    });
  }
  if (!items.length) {
    return Object.entries(networkSuggestionDefaultVariants).map(([variant, cfg]) => ({
      variant,
      name: cfg.name,
      description: cfg.description,
      trafficPct: cfg.trafficPct,
      enabled: cfg.enabled,
      params: normalizeNetworkSuggestionParams(cfg.params, networkSuggestionDefaultParams),
      updatedAt: null
    }));
  }
  return items;
}

function getAssignedNetworkSuggestionVariant(userId) {
  const safeUserId = Number(userId || 0);
  const configs = getNetworkSuggestionAbConfigs();
  const enabledVariants = new Set(
    configs
      .filter((cfg) => Number(cfg.enabled || 0) === 1 && Number(cfg.trafficPct || 0) > 0)
      .map((cfg) => cfg.variant)
  );
  const existing = safeUserId
    ? sqlGet('SELECT variant FROM network_suggestion_ab_assignments WHERE user_id = ?', [safeUserId])
    : null;
  let variant = String(existing?.variant || '').trim().toUpperCase();
  if (!variant || !enabledVariants.has(variant)) {
    variant = chooseVariantForUser(safeUserId, configs);
    if (safeUserId > 0) {
      const now = new Date().toISOString();
      if (existing) {
        sqlRun(
          `UPDATE network_suggestion_ab_assignments
           SET variant = ?, updated_at = ?
           WHERE user_id = ?`,
          [variant, now, safeUserId]
        );
      } else {
        sqlRun(
          `INSERT INTO network_suggestion_ab_assignments (user_id, variant, assigned_at, updated_at)
           VALUES (?, ?, ?, ?)`,
          [safeUserId, variant, now, now]
        );
      }
    }
  }
  const config = configs.find((item) => item.variant === variant) || {
    variant: 'A',
    name: networkSuggestionDefaultVariants.A.name,
    description: networkSuggestionDefaultVariants.A.description,
    trafficPct: networkSuggestionDefaultVariants.A.trafficPct,
    enabled: networkSuggestionDefaultVariants.A.enabled,
    params: { ...networkSuggestionDefaultParams },
    updatedAt: null
  };
  return { variant: config.variant, config, configs };
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
  enqueueBackgroundJob('notification.mentions', {
    text: text || '',
    sourceUserId: sourceUserId || null,
    entityId: entityId || null,
    type: type || 'mention',
    message: message || 'Senden bahsetti.',
    allowedUserIds: Array.isArray(allowedUserIds) ? allowedUserIds : null
  }, {
    maxAttempts: 3,
    backoffMs: 1200
  }).then((result) => {
    if (!result?.ok || (result.backend === 'memory' && !inlineJobWorkerStarted)) {
      notifyMentionsSync({ text, sourceUserId, entityId, type, message, allowedUserIds });
    }
  }).catch(() => {
    notifyMentionsSync({ text, sourceUserId, entityId, type, message, allowedUserIds });
  });
}

async function queueEmailDelivery(payload, { maxAttempts = 4, backoffMs = 1500, delayMs = 0 } = {}) {
  const result = await enqueueBackgroundJob('mail.send', {
    to: payload?.to || '',
    subject: payload?.subject || '',
    html: payload?.html || '',
    from: payload?.from || null,
    timeoutMs: Number(payload?.timeoutMs || process.env.MAIL_SEND_TIMEOUT_MS || 8000)
  }, {
    maxAttempts,
    backoffMs,
    delayMs
  });

  if (!result?.ok || (result.backend === 'memory' && !inlineJobWorkerStarted)) {
    await sendMailWithTimeout(payload);
  }
  return result;
}

function getBackgroundJobHandlers() {
  return {
    'notification.mentions': async (payload) => {
      notifyMentionsSync({
        text: payload?.text || '',
        sourceUserId: payload?.sourceUserId || null,
        entityId: payload?.entityId || null,
        type: payload?.type || 'mention',
        message: payload?.message || 'Senden bahsetti.',
        allowedUserIds: Array.isArray(payload?.allowedUserIds) ? payload.allowedUserIds : null
      });
    },
    'mail.send': async (payload) => {
      await sendMailWithTimeout({
        to: payload?.to || '',
        subject: payload?.subject || '',
        html: payload?.html || '',
        from: payload?.from || null
      }, Number(payload?.timeoutMs || process.env.MAIL_SEND_TIMEOUT_MS || 8000));
    }
  };
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

function messengerPair(user1, user2) {
  const a = Number(normalizeUserId(user1) || 0);
  const b = Number(normalizeUserId(user2) || 0);
  if (!a || !b || a === b) return null;
  return a < b ? { userA: a, userB: b } : { userA: b, userB: a };
}

function getMessengerThreadForUser(threadId, userId) {
  const thread = sqlGet('SELECT * FROM sdal_messenger_threads WHERE id = ?', [threadId]);
  if (!thread) return null;
  if (!sameUserId(thread.user_a_id, userId) && !sameUserId(thread.user_b_id, userId)) return null;
  return thread;
}

function markMessengerMessagesDelivered(threadId, receiverId) {
  const now = new Date().toISOString();
  const result = sqlRun(
    `UPDATE sdal_messenger_messages
     SET delivered_at = COALESCE(delivered_at, ?)
     WHERE CAST(thread_id AS INTEGER) = CAST(? AS INTEGER)
       AND CAST(receiver_id AS INTEGER) = CAST(? AS INTEGER)
       AND delivered_at IS NULL
       AND COALESCE(CAST(deleted_by_receiver AS INTEGER), 0) = 0`,
    [now, threadId, receiverId]
  );
  return {
    deliveredAt: now,
    changed: Number(result?.changes || 0)
  };
}

function broadcastMessengerEvent(userIds, payload) {
  try {
    if (!payload) return;
    broadcastMessengerEventLocal(userIds, payload);
    Promise.resolve(realtimeBus?.publishMessenger?.(userIds, payload)).catch(() => {});
  } catch {
    // ignore ws publish errors
  }
}

function broadcastMessengerEventLocal(userIds, payload) {
  try {
    if (!payload || !messengerWss || !messengerWss.clients) return;
    const targets = new Set(
      (userIds || [])
        .map((id) => Number(id || 0))
        .filter((id) => id > 0)
    );
    if (!targets.size) return;
    const outgoing = JSON.stringify(payload);
    messengerWss.clients.forEach((client) => {
      if (client.readyState !== 1) return;
      const clientUserId = Number(client.sdalUserId || 0);
      if (!clientUserId || !targets.has(clientUserId)) return;
      client.send(outgoing);
    });
  } catch {
    // ignore ws publish errors
  }
}

function ensureMessengerThread(userId, peerId) {
  const pair = messengerPair(userId, peerId);
  if (!pair) return null;
  let thread = sqlGet(
    'SELECT * FROM sdal_messenger_threads WHERE user_a_id = ? AND user_b_id = ?',
    [pair.userA, pair.userB]
  );
  if (thread) return thread;
  const now = new Date().toISOString();
  const result = sqlRun(
    `INSERT INTO sdal_messenger_threads (user_a_id, user_b_id, created_at, updated_at, last_message_at)
     VALUES (?, ?, ?, ?, ?)`,
    [pair.userA, pair.userB, now, now, now]
  );
  const id = result?.lastInsertRowid;
  thread = sqlGet('SELECT * FROM sdal_messenger_threads WHERE id = ?', [id]);
  return thread || null;
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

function base64Url(input) {
  return Buffer.from(input)
    .toString('base64')
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=+$/g, '');
}

function randomState(size = 32) {
  return base64Url(crypto.randomBytes(size));
}

const mobileOAuthTokens = new Map();

function issueMobileOAuthToken(userId) {
  const token = randomState(36);
  const expiresAt = Date.now() + 5 * 60 * 1000;
  mobileOAuthTokens.set(token, { userId: Number(userId || 0), expiresAt });
  return token;
}

function consumeMobileOAuthToken(token) {
  const key = String(token || '').trim();
  if (!key) return null;
  const row = mobileOAuthTokens.get(key);
  if (!row) return null;
  mobileOAuthTokens.delete(key);
  if (!row.userId || row.expiresAt < Date.now()) return null;
  return Number(row.userId);
}

function normalizeHandleSeed(value) {
  return String(value || '')
    .normalize('NFKD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/[^a-zA-Z0-9_]/g, '')
    .toLowerCase();
}

function uniqueUsernameFromSeed(seed) {
  const base = normalizeHandleSeed(seed).slice(0, 12) || 'uye';
  for (let i = 0; i < 20; i += 1) {
    const suffix = String(Math.floor(1000 + Math.random() * 9000));
    const candidate = `${base}${suffix}`.slice(0, 15);
    const exists = sqlGet('SELECT id FROM uyeler WHERE kadi = ?', [candidate]);
    if (!exists) return candidate;
  }
  return `uye${Date.now().toString().slice(-8)}`.slice(0, 15);
}

function getOAuthProviderConfig(provider, req) {
  const p = String(provider || '').toLowerCase();
  const commonBase = resolvePublicBaseUrl(req);
  if (p === 'google') {
    const clientId = String(
      process.env.GOOGLE_OAUTH_CLIENT_ID
      || process.env.GOOGLE_CLIENT_ID
      || process.env.OAUTH_GOOGLE_CLIENT_ID
      || ''
    ).trim();
    const clientSecret = String(
      process.env.GOOGLE_OAUTH_CLIENT_SECRET
      || process.env.GOOGLE_CLIENT_SECRET
      || process.env.OAUTH_GOOGLE_CLIENT_SECRET
      || ''
    ).trim();
    const redirectUri = String(process.env.GOOGLE_OAUTH_REDIRECT_URI || '').trim() || `${commonBase}/api/auth/oauth/google/callback`;
    return {
      provider: 'google',
      title: 'Google',
      enabled: !!(clientId && clientSecret),
      clientId,
      clientSecret,
      redirectUri,
      authUrl: 'https://accounts.google.com/o/oauth2/v2/auth',
      tokenUrl: 'https://oauth2.googleapis.com/token',
      userInfoUrl: 'https://openidconnect.googleapis.com/v1/userinfo',
      scope: 'openid email profile'
    };
  }
  if (p === 'x') {
    const clientId = String(
      process.env.X_OAUTH_CLIENT_ID
      || process.env.TWITTER_OAUTH_CLIENT_ID
      || process.env.TWITTER_CLIENT_ID
      || process.env.OAUTH_X_CLIENT_ID
      || ''
    ).trim();
    const clientSecret = String(
      process.env.X_OAUTH_CLIENT_SECRET
      || process.env.TWITTER_OAUTH_CLIENT_SECRET
      || process.env.TWITTER_CLIENT_SECRET
      || process.env.OAUTH_X_CLIENT_SECRET
      || ''
    ).trim();
    const redirectUri = String(process.env.X_OAUTH_REDIRECT_URI || '').trim() || `${commonBase}/api/auth/oauth/x/callback`;
    return {
      provider: 'x',
      title: 'X',
      enabled: !!(clientId && clientSecret),
      clientId,
      clientSecret,
      redirectUri,
      authUrl: 'https://twitter.com/i/oauth2/authorize',
      tokenUrl: 'https://api.twitter.com/2/oauth2/token',
      userInfoUrl: 'https://api.twitter.com/2/users/me',
      scope: 'users.read tweet.read'
    };
  }
  return null;
}

function getEnabledOAuthProviders(req, { includeDisabled = false } = {}) {
  const providers = ['google', 'x']
    .map((provider) => getOAuthProviderConfig(provider, req))
    .filter(Boolean);
  return providers
    .filter((cfg) => includeDisabled ? true : cfg.enabled)
    .map((cfg) => ({
      provider: cfg.provider,
      title: cfg.title,
      enabled: Boolean(cfg.enabled),
      startUrl: `/api/auth/oauth/${cfg.provider}/start`
    }));
}

function sanitizeOAuthReturnTo(value, fallback = '/new/login') {
  const out = String(value || '').trim();
  if (!out.startsWith('/')) return fallback;
  if (out.startsWith('//')) return fallback;
  if (out.includes('\r') || out.includes('\n')) return fallback;
  return out;
}

function withOAuthError(pathname, code) {
  const safePath = sanitizeOAuthReturnTo(pathname, '/new/login');
  const sep = safePath.includes('?') ? '&' : '?';
  return `${safePath}${sep}oauth=${encodeURIComponent(String(code || 'failed'))}`;
}

function oauthLoginToSuccessPath(loginPath) {
  const safePath = sanitizeOAuthReturnTo(loginPath, '/new/login');
  if (safePath.endsWith('/login')) {
    const root = safePath.slice(0, -'/login'.length);
    return root || '/';
  }
  return '/new';
}

async function oauthFetchToken(config, code, verifier) {
  if (config.provider === 'google') {
    const body = new URLSearchParams({
      grant_type: 'authorization_code',
      code,
      client_id: config.clientId,
      client_secret: config.clientSecret,
      redirect_uri: config.redirectUri
    });
    const resp = await fetch(config.tokenUrl, {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: body.toString()
    });
    if (!resp.ok) throw new Error(`Google token failed (${resp.status})`);
    const json = await resp.json();
    return String(json.access_token || '');
  }
  if (config.provider === 'x') {
    const body = new URLSearchParams({
      grant_type: 'authorization_code',
      code,
      client_id: config.clientId,
      redirect_uri: config.redirectUri,
      code_verifier: verifier || ''
    });
    const basic = Buffer.from(`${config.clientId}:${config.clientSecret}`).toString('base64');
    const resp = await fetch(config.tokenUrl, {
      method: 'POST',
      headers: {
        Authorization: `Basic ${basic}`,
        'Content-Type': 'application/x-www-form-urlencoded'
      },
      body: body.toString()
    });
    if (!resp.ok) throw new Error(`X token failed (${resp.status})`);
    const json = await resp.json();
    return String(json.access_token || '');
  }
  throw new Error('Unsupported provider');
}

async function oauthFetchProfile(config, accessToken) {
  if (config.provider === 'google') {
    const resp = await fetch(config.userInfoUrl, {
      headers: { Authorization: `Bearer ${accessToken}` }
    });
    if (!resp.ok) throw new Error(`Google profile failed (${resp.status})`);
    const json = await resp.json();
    return {
      providerUserId: String(json.sub || ''),
      email: normalizeEmail(json.email || ''),
      emailVerified: !!json.email_verified,
      firstName: String(json.given_name || '').trim(),
      lastName: String(json.family_name || '').trim(),
      displayName: String(json.name || '').trim(),
      usernameSeed: String(json.name || json.email || json.sub || ''),
      raw: json
    };
  }
  if (config.provider === 'x') {
    const params = new URLSearchParams({ 'user.fields': 'name,username,profile_image_url' });
    const resp = await fetch(`${config.userInfoUrl}?${params.toString()}`, {
      headers: { Authorization: `Bearer ${accessToken}` }
    });
    if (!resp.ok) throw new Error(`X profile failed (${resp.status})`);
    const json = await resp.json();
    const data = json?.data || {};
    return {
      providerUserId: String(data.id || ''),
      email: '',
      emailVerified: false,
      firstName: String(data.name || '').trim(),
      lastName: '',
      displayName: String(data.name || '').trim(),
      usernameSeed: String(data.username || data.name || data.id || ''),
      raw: json
    };
  }
  throw new Error('Unsupported provider');
}

function applyUserSession(req, user) {
  const now = new Date();
  const localParts = toLocalDateParts(now);
  const prevDate = user.sonislemtarih && user.sonislemsaat ? `${user.sonislemtarih} ${user.sonislemsaat}` : null;

  // Presence update should never block successful login.
  try {
    if (hasTable('uyeler')) {
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
        [now.toISOString(), prevDate || now.toISOString(), localParts.date, localParts.time, req.ip, user.id]
      );
    } else if (hasTable('users')) {
      const lastSeenAt = now.toISOString();
      const previousLastSeenAt = prevDate || lastSeenAt;
      sqlRun(
        `UPDATE users
         SET is_online = ?,
             profile_view_count = COALESCE(profile_view_count, 0) + 1,
             last_seen_at = ?,
             previous_last_seen_at = ?,
             last_activity_date = ?,
             last_activity_time = ?,
             last_ip = ?,
             updated_at = ?
         WHERE id = ?`,
        [true, lastSeenAt, previousLastSeenAt, localParts.date, localParts.time, req.ip, lastSeenAt, user.id]
      );
    }
  } catch (err) {
    writeAppLog('warn', 'apply_user_session_presence_update_failed', {
      userId: user?.id || null,
      dbDriver,
      error: err?.message || String(err)
    });
  }

  req.session.userId = user.id;
}

function findOrCreateOAuthUser({ provider, profile }) {
  const providerUserId = String(profile.providerUserId || '').trim();
  if (!providerUserId) throw new Error('OAuth provider user id missing');

  const nowIso = new Date().toISOString();
  const existingByAccount = sqlGet(
    `SELECT u.*
     FROM oauth_accounts oa
     JOIN uyeler u ON u.id = oa.user_id
     WHERE oa.provider = ? AND oa.provider_user_id = ?`,
    [provider, providerUserId]
  );
  let user = existingByAccount || null;
  if (!user && profile.email) {
    user = sqlGet('SELECT * FROM uyeler WHERE lower(email) = lower(?)', [profile.email]);
  }
  if (!user) {
    const firstName = String(profile.firstName || '').trim() || 'SDAL';
    const lastName = String(profile.lastName || '').trim() || 'Üye';
    const email = profile.email || `${provider}_${providerUserId}@oauth.local`;
    const kadi = uniqueUsernameFromSeed(profile.usernameSeed || email);
    const result = sqlRun(
      `INSERT INTO uyeler (kadi, sifre, email, isim, soyisim, aktivasyon, aktiv, ilktarih, resim, mezuniyetyili, ilkbd, verified, oauth_provider, oauth_subject, oauth_email_verified, verification_status)
       VALUES (?, ?, ?, ?, ?, ?, 1, ?, 'yok', '0', 1, 0, ?, ?, ?, 'pending')`,
      [
        kadi,
        randomState(18),
        email,
        firstName.slice(0, 20),
        lastName.slice(0, 20),
        createActivation(),
        nowIso,
        provider,
        providerUserId,
        profile.emailVerified ? 1 : 0
      ]
    );
    const userId = result?.lastInsertRowid || sqlGet('SELECT id FROM uyeler WHERE kadi = ?', [kadi])?.id;
    user = sqlGet('SELECT * FROM uyeler WHERE id = ?', [userId]);
  }

  const existingAccount = sqlGet('SELECT id, user_id FROM oauth_accounts WHERE provider = ? AND provider_user_id = ?', [provider, providerUserId]);
  if (existingAccount) {
    sqlRun(
      'UPDATE oauth_accounts SET user_id = ?, email = ?, profile_json = ?, updated_at = ? WHERE id = ?',
      [user.id, profile.email || '', JSON.stringify(profile.raw || {}), nowIso, existingAccount.id]
    );
  } else {
    sqlRun(
      `INSERT INTO oauth_accounts (user_id, provider, provider_user_id, email, profile_json, created_at, updated_at)
       VALUES (?, ?, ?, ?, ?, ?, ?)`,
      [user.id, provider, providerUserId, profile.email || '', JSON.stringify(profile.raw || {}), nowIso, nowIso]
    );
  }

  sqlRun(
    'UPDATE uyeler SET oauth_provider = ?, oauth_subject = ?, oauth_email_verified = ? WHERE id = ?',
    [provider, providerUserId, profile.emailVerified ? 1 : 0, user.id]
  );

  return user;
}

async function sendMail(payload) {
  return mailSender.sendMail(payload);
}

async function sendMailWithTimeout(payload, timeoutMs = Number(process.env.MAIL_SEND_TIMEOUT_MS || 8000)) {
  return mailSender.sendMailWithTimeout(payload, timeoutMs);
}

function normalizeEmail(email) {
  return String(email || '').trim();
}

function validateEmail(email) {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(normalizeEmail(email));
}

const e2eHarnessEnabled = String(process.env.E2E_HARNESS_ENABLED || '').trim().toLowerCase() === 'true';
const e2eHarnessToken = String(process.env.E2E_HARNESS_TOKEN || '').trim();
const e2eHarnessRoleSet = new Set(['user', 'mod', 'admin']);

function constantTimeEquals(a, b) {
  const left = Buffer.from(String(a || ''), 'utf8');
  const right = Buffer.from(String(b || ''), 'utf8');
  if (!left.length || left.length !== right.length) return false;
  try {
    return crypto.timingSafeEqual(left, right);
  } catch {
    return false;
  }
}

function isE2EHarnessRequest(req) {
  if (!e2eHarnessEnabled || !e2eHarnessToken) return false;
  const candidate = String(
    req.get('x-e2e-token')
    || req.body?.e2e_token
    || req.query?.e2e_token
    || ''
  ).trim();
  return constantTimeEquals(candidate, e2eHarnessToken);
}

function normalizeE2ERole(value) {
  const role = String(value || '').trim().toLowerCase();
  if (!e2eHarnessRoleSet.has(role)) return 'user';
  return role;
}

function parseE2EModerationPermissionKeys(raw) {
  if (!Array.isArray(raw)) return [];
  const unique = new Set();
  for (const item of raw) {
    const key = String(item || '').trim();
    if (!key || !MODERATION_PERMISSION_KEY_SET.has(key)) continue;
    unique.add(key);
  }
  return Array.from(unique);
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

const bannedWordsCache = {
  words: [],
  expiresAt: 0
};

function normalizeBannedWord(word) {
  return String(word || '').trim().toLocaleLowerCase('tr-TR');
}

function getBannedWords() {
  const now = Date.now();
  if (bannedWordsCache.expiresAt > now) return bannedWordsCache.words;
  try {
    const rows = sqlAll('SELECT kufur FROM filtre');
    const unique = new Set();
    for (const row of rows) {
      const normalized = normalizeBannedWord(row?.kufur);
      if (normalized) unique.add(normalized);
    }
    bannedWordsCache.words = Array.from(unique).sort((a, b) => b.length - a.length);
  } catch {
    bannedWordsCache.words = [];
  }
  bannedWordsCache.expiresAt = now + 30 * 1000;
  return bannedWordsCache.words;
}

function invalidateBannedWordsCache() {
  bannedWordsCache.words = [];
  bannedWordsCache.expiresAt = 0;
}

function escapeRegExp(value) {
  return String(value || '').replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

function censorBannedWords(text) {
  let value = String(text ?? '');
  if (!value) return value;
  const words = getBannedWords();
  if (!words.length) return value;
  for (const word of words) {
    const pattern = new RegExp(`(^|[^\\p{L}\\p{N}_])(${escapeRegExp(word)})(?=[^\\p{L}\\p{N}_]|$)`, 'giu');
    value = value.replace(pattern, (_full, prefix, matched) => {
      const stars = '*'.repeat(Array.from(String(matched || '')).length);
      return `${prefix}${stars}`;
    });
  }
  return value;
}

function formatUserText(text) {
  return metinDuzenle(censorBannedWords(text));
}

function sanitizePlainUserText(text, maxLength = null) {
  const masked = censorBannedWords(String(text ?? ''));
  if (typeof maxLength === 'number') return masked.slice(0, maxLength);
  return masked;
}

function filterKufur(text) {
  try {
    const bannedWords = getBannedWords();
    if (!bannedWords.length) return null;
    const words = String(text || '')
      .toLocaleLowerCase('tr-TR')
      .split(/\\s+/)
      .filter(Boolean);
    for (const banned of bannedWords) {
      if (words.includes(banned)) {
        return banned;
      }
    }
    return null;
  } catch {
    return null;
  }
}

const legacyMediaDir = path.resolve(__dirname, '../frontend-classic/public/legacy');

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

const uploadImagePresets = Object.freeze({
  profilePhoto: { width: 960, height: 960, fit: 'inside', quality: 86, background: '#ffffff' },
  albumPhoto: { width: 2200, height: 2200, fit: 'inside', quality: 86, background: '#ffffff' },
  postImage: { width: 1900, height: 1900, fit: 'inside', quality: 84, background: '#ffffff' },
  groupCover: { width: 1800, height: 1000, fit: 'contain', quality: 84, background: '#f4f1ec' },
  eventImage: { width: 1900, height: 1900, fit: 'inside', quality: 84, background: '#ffffff' },
  announcementImage: { width: 1900, height: 1900, fit: 'inside', quality: 84, background: '#ffffff' }
});

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

async function processDiskImageUpload({
  req,
  res,
  file,
  bucket,
  preset,
  filter,
  allowedMimes = allowedImageSafetyMimes
}) {
  if (!file?.path) {
    return { ok: false, statusCode: 400, message: 'Görsel seçilmedi.' };
  }

  const validation = validateUploadedImageFile(file.path, {
    allowedMimes,
    maxBytes: getMediaUploadLimitBytes()
  });
  if (!validation.ok) {
    cleanupUploadedFile(file.path);
    return { ok: false, statusCode: 400, message: validation.reason || 'Dosya güvenlik kontrolünden geçemedi.' };
  }

  const quotaOk = await enforceUploadQuota(req, res, {
    fileSize: validation.size || file.size || 0,
    bucket
  });
  if (!quotaOk) {
    cleanupUploadedFile(file.path);
    return {
      ok: false,
      statusCode: 429,
      message: 'Günlük yükleme kotan doldu. Lütfen daha sonra tekrar dene.'
    };
  }

  let finalPath = file.path;
  if (filter) {
    try {
      await applyImageFilter(finalPath, filter);
    } catch {
      // keep original if filter fails
    }
  }
  if (preset) {
    try {
      finalPath = await optimizeUploadedImage(finalPath, preset);
    } catch {
      // keep original path
    }
  }

  const outputExt = path.extname(finalPath || '').toLowerCase();
  const outputMime = outputExt === '.webp' ? 'image/webp' : validation.mime;

  return {
    ok: true,
    path: finalPath,
    url: toUploadUrl(finalPath),
    mime: outputMime || validation.mime,
    originalMime: validation.mime,
    size: validation.size || file.size || 0
  };
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
  const bins = ['df', '/bin/df', '/usr/bin/df'];
  for (const bin of bins) {
    try {
      const output = execFileSync(bin, ['-kP', String(targetPath || '')], {
        encoding: 'utf8',
        stdio: ['ignore', 'pipe', 'ignore']
      });
      const lines = String(output || '').trim().split('\n');
      if (lines.length < 2) continue;
      const parts = lines[1].trim().split(/\s+/);
      if (parts.length < 6) continue;
      const totalKb = Number(parts[1] || 0);
      const usedKb = Number(parts[2] || 0);
      const freeKb = Number(parts[3] || 0);
      if (!Number.isFinite(totalKb) || totalKb <= 0) continue;
      return {
        totalBytes: Math.max(0, totalKb * 1024),
        usedBytes: Math.max(0, usedKb * 1024),
        freeBytes: Math.max(0, freeKb * 1024),
        source: 'df'
      };
    } catch {
      // try next path
    }
  }
  return null;
}

function getDiskMetrics(targetPath) {
  const statfs = safeStatfs(targetPath);
  if (statfs) {
    const blockSize = Number(statfs.bsize || statfs.frsize || 0);
    const totalBytes = Number(statfs.blocks || 0) * blockSize;
    const freeBlocks = Number(statfs.bavail || statfs.bfree || 0);
    const freeBytes = freeBlocks * blockSize;
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
  const primary = safeDf(targetPath);
  if (primary) return primary;
  return safeDf('/');
}

let cpuSample = {
  at: 0,
  total: 0,
  idle: 0,
  value: null
};

function readProcCpuSnapshot() {
  try {
    const content = fs.readFileSync('/proc/stat', 'utf8');
    const line = String(content || '')
      .split('\n')
      .find((entry) => entry.startsWith('cpu '));
    if (!line) return null;
    const parts = line.trim().split(/\s+/).slice(1).map((v) => Number(v || 0));
    if (!parts.length || parts.some((v) => !Number.isFinite(v))) return null;
    const idle = Number(parts[3] || 0) + Number(parts[4] || 0);
    const total = parts.reduce((sum, v) => sum + Number(v || 0), 0);
    if (!Number.isFinite(total) || total <= 0) return null;
    return { total, idle };
  } catch {
    return null;
  }
}

function readCpuSnapshot() {
  const procSnapshot = readProcCpuSnapshot();
  if (procSnapshot) return procSnapshot;
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
  if (!Number.isFinite(load1) || load1 < 0) return null;
  const loadPct = Math.min(100, Math.max(0, (load1 / cpuCount) * 100));
  return Number(loadPct.toFixed(2));
}

function readAdminStorageSnapshot() {
  const now = Date.now();
  if (adminStorageSnapshotCache.value && adminStorageSnapshotCache.expiresAt > now) {
    return adminStorageSnapshotCache.value;
  }

  const uploadStats = walkDirStats(uploadsDir);
  const dbSizeBytes = (() => {
    if (isPostgresDb) {
      try {
        const row = sqlGet('SELECT pg_database_size(current_database())::bigint AS size');
        const size = Number(row?.size || 0);
        return Number.isFinite(size) && size > 0 ? size : 0;
      } catch {
        return 0;
      }
    }
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

  const snapshot = {
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

  adminStorageSnapshotCache = {
    value: snapshot,
    expiresAt: now + ADMIN_STORAGE_CACHE_TTL_MS
  };
  return snapshot;
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
  res.setHeader('Cache-Control', 'public, max-age=3600, stale-while-revalidate=86400');
  res.setHeader('Vary', 'Accept-Encoding');
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
      const localParts = toLocalDateParts(new Date());
      sqlRun('UPDATE uyeler SET sonislemtarih = ?, sonislemsaat = ?, sonip = ?, online = 1 WHERE id = ?', [
        localParts.date,
        localParts.time,
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
  const rows = sqlAll("SELECT id, kadi FROM uyeler WHERE online = 1 AND (role IS NULL OR LOWER(role) != 'root') ORDER BY kadi");
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
  const rows = sqlAll("SELECT id, kadi, resim, mezuniyetyili, isim, soyisim, sonislemtarih, sonislemsaat, online FROM uyeler WHERE online = 1 AND (role IS NULL OR LOWER(role) != 'root') ORDER BY kadi");
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
  const yorum = formatUserText(req.body.yorum || '');
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

const phase1Domain = createPhase1DomainLayer({
  sqlGet,
  sqlAll,
  sqlRun,
  sqlGetAsync,
  sqlAllAsync,
  sqlRunAsync,
  isPostgresDb,
  joinUserOnPostAuthorExpr,
  normalizeRole,
  roleAtLeast,
  getUserRole,
  hasAdminRole,
  verifyPassword,
  hashPassword,
  applyUserSession,
  enrichWithVariants,
  getImageVariants,
  getImageVariantsBatch,
  uploadsDir,
  getModuleControlMap,
  formatUserText,
  isFormattedContentEmpty,
  getCurrentUser,
  notifyMentions,
  addNotification,
  scheduleEngagementRecalculation,
  invalidateFeedCache: () => invalidateCacheNamespace(cacheNamespaces.feed),
  canManageChatMessage,
  broadcastChatMessage,
  broadcastChatUpdate,
  broadcastChatDelete,
  buildFeedCacheKey,
  getCacheJson,
  setCacheJson,
  feedCacheTtlSeconds: FEED_CACHE_TTL_SECONDS,
  replaceModeratorPermissions,
  moderationPermissionKeys: MODERATION_PERMISSION_KEY_SET,
  writeAuditLog
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

async function healthHandler(req, res) {
  const startedAt = Date.now();

  let dbCheck = {
    configured: true,
    ready: false,
    detail: '',
    latencyMs: 0
  };

  if (dbDriver === 'postgres') {
    dbCheck = await checkPostgresHealth();
  } else {
    try {
      const dbStartedAt = Date.now();
      const row = sqlGet('SELECT 1 AS ok');
      dbCheck = {
        configured: true,
        ready: Number(row?.ok || 0) === 1,
        detail: 'ok',
        latencyMs: Date.now() - dbStartedAt
      };
    } catch (err) {
      dbCheck = {
        configured: true,
        ready: false,
        detail: err?.message || 'sqlite check failed',
        latencyMs: Date.now() - startedAt
      };
    }
  }

  const redisCheck = await checkRedisHealth();
  const redisRequired = isRedisConfigured();
  const overallOk = dbCheck.ready && (!redisRequired || redisCheck.ready);

  res.status(overallOk ? 200 : 503).json({
    ok: overallOk,
    dbPath,
    dbDriver,
    dbReady: dbCheck.ready,
    redisReady: redisCheck.ready,
    timestamp: new Date().toISOString(),
    version: process.env.npm_package_version || '0.1.0',
    uptimeSec: Math.floor(process.uptime()),
    durationMs: Date.now() - startedAt,
    checks: {
      db: dbCheck,
      redis: redisCheck,
      realtime: realtimeBus?.getState?.() || { started: false, enabled: false },
      jobs: backgroundJobQueue?.getState?.() || { started: false }
    },
    runtime: {
      postgres: getPostgresPoolState(),
      redis: getRedisState(),
      realtime: realtimeBus?.getState?.() || { started: false, enabled: false },
      jobs: backgroundJobQueue?.getState?.() || { started: false },
      postgresConfigured: isPostgresConfigured(),
      redisConfigured: redisRequired
    }
  });
}

app.get('/health', healthHandler);
app.get('/api/health', healthHandler);

app.get('/api/captcha', (req, res) => {
  issueCaptcha(req, res);
});

app.get('/api/site-access', (req, res) => {
  const pathValue = String(req.query.path || req.path || '').trim();
  const moduleKey = resolveModuleKeyByPath(pathValue);
  const modules = getModuleControlMap();
  const site = getSiteControl();
  res.json({
    siteOpen: site.siteOpen,
    maintenanceMessage: site.maintenanceMessage,
    modules,
    moduleKey,
    moduleOpen: moduleKey ? !!modules[moduleKey] : true
  });
});

app.get('/api/session', (req, res) => {
  if (!req.session.userId) {
    return res.json({ user: null });
  }
  const current = getCurrentUser(req);
  const user = current
    ? {
      id: current.id,
      kadi: current.kadi,
      isim: current.isim,
      soyisim: current.soyisim,
      photo: current.resim,
      admin: current.admin,
      role: current.role,
      verified: current.verified,
      mezuniyetyili: current.mezuniyetyili,
      oauth_provider: current.oauth_provider,
      kvkk_consent_at: current.kvkk_consent_at,
      directory_consent_at: current.directory_consent_at
    }
    : null;
  if (!user) return res.json({ user: null });
  const state = isOAuthProfileIncomplete(user) ? 'incomplete' : 'active';
  const role = getUserRole(user);
  const moderationPermissionKeys = role === 'mod' ? getModeratorPermissionSummary(user.id).assignedKeys : [];
  res.json({ user: { ...user, role, admin: roleAtLeast(role, 'admin') ? 1 : 0, state, moderationPermissionKeys } });
});

app.get('/api/auth/oauth/providers', (req, res) => {
  res.json({ providers: getEnabledOAuthProviders(req, { includeDisabled: true }) });
});

app.get('/api/auth/oauth/:provider/start', (req, res) => {
  const config = getOAuthProviderConfig(req.params.provider, req);
  if (!config || !config.enabled) return res.status(404).send('OAuth provider aktif değil.');

  const state = randomState();
  req.session.oauthState = state;
  req.session.oauthProvider = config.provider;
  req.session.oauthNative = String(req.query.native || '') === '1' ? 1 : 0;
  req.session.oauthReturnTo = sanitizeOAuthReturnTo(req.query.returnTo, '/new/login');

  if (config.provider === 'x') {
    const verifier = base64Url(crypto.randomBytes(32));
    const challenge = base64Url(crypto.createHash('sha256').update(verifier).digest());
    req.session.oauthPkceVerifier = verifier;
    const params = new URLSearchParams({
      response_type: 'code',
      client_id: config.clientId,
      redirect_uri: config.redirectUri,
      scope: config.scope,
      state,
      code_challenge: challenge,
      code_challenge_method: 'S256'
    });
    return res.redirect(`${config.authUrl}?${params.toString()}`);
  }

  const params = new URLSearchParams({
    response_type: 'code',
    client_id: config.clientId,
    redirect_uri: config.redirectUri,
    scope: config.scope,
    state
  });
  res.redirect(`${config.authUrl}?${params.toString()}`);
});

app.get('/api/auth/oauth/:provider/callback', async (req, res) => {
  const config = getOAuthProviderConfig(req.params.provider, req);
  const isNative = Number(req.session.oauthNative || 0) === 1;
  const loginRedirectPath = sanitizeOAuthReturnTo(req.session.oauthReturnTo, '/new/login');
  if (!config || !config.enabled) {
    return res.redirect(isNative ? 'sdalnative://oauth-callback?oauth=disabled' : withOAuthError(loginRedirectPath, 'disabled'));
  }
  const state = String(req.query.state || '');
  const code = String(req.query.code || '');
  if (!code || !state) return res.redirect(isNative ? 'sdalnative://oauth-callback?oauth=invalid' : withOAuthError(loginRedirectPath, 'invalid'));
  if (state !== String(req.session.oauthState || '') || config.provider !== String(req.session.oauthProvider || '')) {
    return res.redirect(isNative ? 'sdalnative://oauth-callback?oauth=state' : withOAuthError(loginRedirectPath, 'state'));
  }

  try {
    const accessToken = await oauthFetchToken(config, code, String(req.session.oauthPkceVerifier || ''));
    const profile = await oauthFetchProfile(config, accessToken);
    const user = findOrCreateOAuthUser({ provider: config.provider, profile });
    if (!user || user.yasak === 1) {
      return res.redirect(isNative ? 'sdalnative://oauth-callback?oauth=blocked' : withOAuthError(loginRedirectPath, 'blocked'));
    }
    if (user.aktiv === 0) {
      sqlRun('UPDATE uyeler SET aktiv = 1 WHERE id = ?', [user.id]);
      user.aktiv = 1;
    }
    if (isNative) {
      const token = issueMobileOAuthToken(user.id);
      res.redirect(`sdalnative://oauth-callback?token=${encodeURIComponent(token)}`);
    } else {
      applyUserSession(req, user);
      res.cookie('uyegiris', 'evet');
      res.cookie('uyeid', String(user.id));
      res.cookie('kadi', user.kadi);
      res.redirect(oauthLoginToSuccessPath(loginRedirectPath));
    }
  } catch (err) {
    console.error('OAuth callback error:', config.provider, err);
    res.redirect(isNative ? 'sdalnative://oauth-callback?oauth=failed' : withOAuthError(loginRedirectPath, 'failed'));
  } finally {
    req.session.oauthState = null;
    req.session.oauthProvider = null;
    req.session.oauthPkceVerifier = null;
    req.session.oauthNative = null;
    req.session.oauthReturnTo = null;
  }
});

app.post('/api/auth/oauth/mobile/exchange', (req, res) => {
  const token = String(req.body?.token || '').trim();
  const userId = consumeMobileOAuthToken(token);
  if (!userId) return res.status(400).send('OAuth token gecersiz veya suresi dolmus.');
  const user = sqlGet('SELECT * FROM uyeler WHERE id = ?', [userId]);
  if (!user || user.yasak === 1) return res.status(400).send('Kullanici gecersiz.');
  applyUserSession(req, user);
  res.cookie('uyegiris', 'evet');
  res.cookie('uyeid', String(user.id));
  res.cookie('kadi', user.kadi);
  res.json({ ok: true, user: { id: user.id, kadi: user.kadi, isim: user.isim, soyisim: user.soyisim } });
});

app.post('/api/auth/login', loginRateLimit, phase1Domain.controllers.auth.login);

app.post('/api/auth/logout', phase1Domain.controllers.auth.logout);

app.get('/api/admin/session', (req, res) => {
  if (!req.session.userId) return res.json({ user: null, adminOk: false });
  const user = sqlGet('SELECT id, kadi, isim, soyisim, admin, albumadmin, role FROM uyeler WHERE id = ?', [req.session.userId]);
  if (!user) return res.json({ user: null, adminOk: false });
  const role = getUserRole(user);
  const moderationPermissionKeys = role === 'mod' ? getModeratorPermissionSummary(user.id).assignedKeys : [];
  res.json({ user: { ...user, role, admin: hasAdminRole(user) ? 1 : 0, moderationPermissionKeys }, adminOk: roleAtLeast(role, 'admin') ? true : !!req.session.adminOk });
});

app.get('/api/admin/root-status', requireAdmin, (_req, res) => {
  const rootUser = sqlGet("SELECT id, kadi, ilktarih, role FROM uyeler WHERE LOWER(COALESCE(role, '')) = 'root' ORDER BY id ASC LIMIT 1");
  res.json({
    hasRoot: !!rootUser,
    rootUser: rootUser || null,
    bootstrapPasswordConfigured: Boolean(String(process.env.ROOT_BOOTSTRAP_PASSWORD || '').trim())
  });
});


app.post('/admin/users/:id/role', requireAuth, requireRole('admin'), phase1Domain.controllers.admin.updateUserRole);

app.post('/admin/moderators/:id/scopes', requireAuth, requireRole('admin'), (req, res) => {
  const actor = req.authUser;
  const targetId = Number(req.params.id || 0);
  const years = Array.isArray(req.body?.graduationYears) ? req.body.graduationYears : [];
  if (!targetId) return res.status(400).send('Geçersiz kullanıcı.');
  if (!years.length) return res.status(400).send('En az bir mezuniyet yılı gerekli.');
  const target = sqlGet('SELECT id, role FROM uyeler WHERE id = ?', [targetId]);
  if (!target) return res.status(404).send('Kullanıcı bulunamadı.');
  if (normalizeRole(target.role) === 'root') return res.status(400).send('Root için kapsam atanamaz.');
  const normalizedYears = Array.from(new Set(years.map(parseGraduationYear).filter((y) => Number.isFinite(y) && y >= MIN_GRADUATION_YEAR && y <= MAX_GRADUATION_YEAR)));
  if (!normalizedYears.length) return res.status(400).send('Geçerli mezuniyet yılı bulunamadı.');
  sqlRun('UPDATE uyeler SET role = ?, admin = 0 WHERE id = ?', ['mod', targetId]);
  const created = [];
  for (const year of normalizedYears) {
    sqlRun(`INSERT INTO moderator_scopes (user_id, scope_type, scope_value, graduation_year, created_by, created_at)
      VALUES (?, 'graduation_year', ?, ?, ?, ?)
      ON CONFLICT(user_id, scope_type, scope_value) DO NOTHING`, [targetId, String(year), year, actor.id, new Date().toISOString()]);
    created.push(year);
  }
  writeAuditLog(req, { actorUserId: actor.id, action: 'moderator_scope_assigned', targetType: 'user', targetId: String(targetId), metadata: { graduationYears: created } });
  res.json({ ok: true, userId: targetId, scopes: created });
});

app.post('/admin/moderation/check/:graduationYear', requireAuth, requireScopedModeration((req) => req.params.graduationYear), (req, res) => {
  res.json({ ok: true, graduationYear: Number(req.params.graduationYear) });
});

app.get('/admin/moderators', requireAuth, requireRole('admin'), (_req, res) => {
  const rows = sqlAll(
    `SELECT u.id, u.kadi, u.isim, u.soyisim, u.role, ms.scope_value AS graduation_year
     FROM uyeler u
     LEFT JOIN moderator_scopes ms ON ms.user_id = u.id AND ms.scope_type = 'graduation_year'
     WHERE LOWER(COALESCE(u.role, 'user')) = 'mod' AND (u.role IS NULL OR LOWER(u.role) != 'root')
     ORDER BY u.id ASC, ms.scope_value ASC`
  );
  const map = new Map();
  for (const row of rows) {
    if (!map.has(row.id)) map.set(row.id, { id: row.id, kadi: row.kadi, isim: row.isim, soyisim: row.soyisim, role: row.role, graduationYears: [] });
    if (row.graduation_year) map.get(row.id).graduationYears.push(Number(row.graduation_year));
  }
  res.json({ moderators: Array.from(map.values()) });
});

app.get('/api/admin/moderation/permissions/catalog', requireAuth, requireRole('admin'), (_req, res) => {
  res.json({
    actions: MODERATION_ACTION_DEFINITIONS,
    resources: MODERATION_RESOURCE_DEFINITIONS,
    permissions: MODERATION_PERMISSION_DEFINITIONS
  });
});

app.get('/api/admin/moderation/permissions/:userId', requireAuth, requireRole('admin'), (req, res) => {
  const userId = Number(req.params.userId || 0);
  if (!userId) return res.status(400).send('Geçersiz kullanıcı.');
  const target = sqlGet('SELECT id, kadi, isim, soyisim, role, resim, mezuniyetyili, email FROM uyeler WHERE id = ?', [userId]);
  if (!target) return res.status(404).send('Kullanıcı bulunamadı.');
  const summary = getModeratorPermissionSummary(userId);
  res.json({
    user: { ...target, role: getUserRole(target) },
    ...summary
  });
});

app.put('/api/admin/moderation/permissions/:userId', requireAuth, requireRole('admin'), (req, res) => {
  const actor = req.authUser;
  const userId = Number(req.params.userId || 0);
  if (!userId) return res.status(400).send('Geçersiz kullanıcı.');
  const target = sqlGet('SELECT id, role FROM uyeler WHERE id = ?', [userId]);
  if (!target) return res.status(404).send('Kullanıcı bulunamadı.');
  if (normalizeRole(target.role) === 'root') return res.status(400).send('Root kullanıcı için moderasyon yetkisi tanımlanamaz.');

  const payload = req.body || {};
  const permissionMap = payload.permissions && typeof payload.permissions === 'object' ? payload.permissions : null;
  const permissionKeys = Array.isArray(payload.permissionKeys) ? payload.permissionKeys : null;
  const updates = new Map();

  if (permissionMap) {
    for (const [key, enabled] of Object.entries(permissionMap)) {
      const normalizedKey = String(key || '').trim();
      if (!MODERATION_PERMISSION_KEY_SET.has(normalizedKey)) continue;
      updates.set(normalizedKey, !!enabled);
    }
  }

  if (permissionKeys) {
    const normalized = new Set(permissionKeys.map((item) => String(item || '').trim()).filter((item) => MODERATION_PERMISSION_KEY_SET.has(item)));
    for (const key of MODERATION_PERMISSION_KEY_SET) {
      updates.set(key, normalized.has(key));
    }
  }

  if (!updates.size) return res.status(400).send('En az bir geçerli yetki anahtarı gerekli.');

  const now = new Date().toISOString();
  sqlRun('UPDATE uyeler SET role = ?, admin = 0 WHERE id = ?', ['mod', userId]);
  for (const [permissionKey, enabled] of updates.entries()) {
    sqlRun(
      `INSERT INTO moderator_permissions (user_id, permission_key, enabled, created_by, updated_by, created_at, updated_at)
       VALUES (?, ?, ?, ?, ?, ?, ?)
       ON CONFLICT(user_id, permission_key)
       DO UPDATE SET enabled = excluded.enabled, updated_by = excluded.updated_by, updated_at = excluded.updated_at`,
      [userId, permissionKey, toDbBooleanParam(enabled), actor.id, actor.id, now, now]
    );
  }

  writeAuditLog(req, {
    actorUserId: actor.id,
    action: 'moderator_permissions_updated',
    targetType: 'user',
    targetId: String(userId),
    metadata: { updatedCount: updates.size }
  });

  const summary = getModeratorPermissionSummary(userId);
  res.json({ ok: true, userId, ...summary });
});

app.get('/api/admin/moderation/my-permissions', requireAuth, (req, res) => {
  const user = req.authUser || getCurrentUser(req);
  if (!user) return res.status(401).send('Login required');
  const role = getUserRole(user);
  if (role === 'root' || role === 'admin') {
    return res.json({ role, isSuperModerator: true, permissionKeys: Array.from(MODERATION_PERMISSION_KEY_SET).sort((a, b) => a.localeCompare(b)) });
  }
  if (role !== 'mod') {
    return res.json({ role, isSuperModerator: false, permissionKeys: [] });
  }
  const summary = getModeratorPermissionSummary(user.id);
  res.json({ role, isSuperModerator: false, permissionKeys: summary.assignedKeys, permissionMap: summary.permissionMap });
});


app.post('/api/admin/login', (req, res) => {
  const user = getCurrentUser(req);
  if (!user) {
    writeLegacyLog('error', 'admin_login_denied', { reason: 'unauthenticated', ip: req.ip });
    writeAppLog('warn', 'admin_login_denied', { reason: 'unauthenticated', ip: req.ip });
    return res.status(401).send('Login required');
  }
  if (!hasAdminRole(user)) {
    writeLegacyLog('error', 'admin_login_denied', { reason: 'not_admin', userId: user.id, ip: req.ip });
    writeAppLog('warn', 'admin_login_denied', { reason: 'not_admin', userId: user.id, ip: req.ip });
    return res.status(403).send('Admin erişimi gerekli.');
  }
  const password = String(req.body?.password || '');
  if (!password) return res.status(400).send('Şifre girmedin.');
  if (!adminPassword || password !== adminPassword) {
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

app.get('/api/admin/site-controls', requireAdmin, async (_req, res) => {
  const cacheKey = await buildVersionedCacheKey(cacheNamespaces.adminSettings, ['site_controls']);
  const cached = await getCacheJson(cacheKey);
  if (cached && cached.modules) return res.json(cached);
  const site = getSiteControl();
  const modules = getModuleControlMap();
  const payload = {
    siteOpen: site.siteOpen,
    maintenanceMessage: site.maintenanceMessage,
    updatedAt: site.updatedAt,
    modules,
    moduleDefinitions: MODULE_DEFINITIONS
  };
  await setCacheJson(cacheKey, payload, ADMIN_SETTINGS_CACHE_TTL_SECONDS);
  res.json(payload);
});

app.put('/api/admin/site-controls', requireAdmin, (req, res) => {
  const updates = req.body || {};
  const now = new Date().toISOString();
  if (updates.siteOpen !== undefined || updates.maintenanceMessage !== undefined) {
    const nextOpen = updates.siteOpen === undefined ? getSiteControl().siteOpen : !!updates.siteOpen;
    const nextMessage = String(updates.maintenanceMessage || getSiteControl().maintenanceMessage || '').slice(0, 1200);
    if (dbDriver === 'postgres') {
      sqlRun('UPDATE site_settings SET site_open = ?, maintenance_message = ?, updated_at = ? WHERE id = 1', [nextOpen ? true : false, nextMessage, now]);
    } else {
      sqlRun('UPDATE site_controls SET site_open = ?, maintenance_message = ?, updated_at = ? WHERE id = 1', [nextOpen ? 1 : 0, nextMessage, now]);
    }
  }
  if (updates.modules && typeof updates.modules === 'object') {
    for (const def of MODULE_DEFINITIONS) {
      if (updates.modules[def.key] === undefined) continue;
      if (dbDriver === 'postgres') {
        sqlRun(
          `INSERT INTO module_settings (module_key, is_open, updated_at)
           VALUES (?, ?, ?)
           ON CONFLICT(module_key) DO UPDATE SET is_open = excluded.is_open, updated_at = excluded.updated_at`,
          [def.key, updates.modules[def.key] ? true : false, now]
        );
      } else {
        sqlRun(
          `INSERT INTO module_controls (module_key, is_open, updated_at)
           VALUES (?, ?, ?)
           ON CONFLICT(module_key) DO UPDATE SET is_open = excluded.is_open, updated_at = excluded.updated_at`,
          [def.key, updates.modules[def.key] ? 1 : 0, now]
        );
      }
    }
  }
  invalidateControlSnapshots();
  invalidateCacheNamespace(cacheNamespaces.adminSettings);
  const site = getSiteControl();
  res.json({ ok: true, siteOpen: site.siteOpen, maintenanceMessage: site.maintenanceMessage, modules: getModuleControlMap() });
});

// --- Admin Media Settings Endpoints ---

app.get('/api/admin/media-settings', requireAdmin, async (_req, res) => {
  const cacheKey = await buildVersionedCacheKey(cacheNamespaces.adminSettings, ['media_settings']);
  const cached = await getCacheJson(cacheKey);
  if (cached && cached.settings) return res.json(cached);
  const settings = sqlGet('SELECT * FROM media_settings WHERE id = 1');
  const spacesConfigured = !!(process.env.SPACES_KEY && process.env.SPACES_SECRET && process.env.SPACES_BUCKET && process.env.SPACES_ENDPOINT);
  const payload = {
    settings: settings || {},
    spacesConfigured,
    spacesRegion: process.env.SPACES_REGION || '',
    spacesBucket: process.env.SPACES_BUCKET || '',
    spacesEndpoint: process.env.SPACES_ENDPOINT || ''
  };
  await setCacheJson(cacheKey, payload, ADMIN_SETTINGS_CACHE_TTL_SECONDS);
  res.json(payload);
});

app.put('/api/admin/media-settings', requireAdmin, (req, res) => {
  const {
    storage_provider,
    thumb_width,
    feed_width,
    full_width,
    webp_quality,
    max_upload_bytes,
    avif_enabled
  } = req.body || {};

  // Validate provider switch
  if (storage_provider === 'spaces') {
    const hasKeys = !!(process.env.SPACES_KEY && process.env.SPACES_SECRET && process.env.SPACES_BUCKET && process.env.SPACES_ENDPOINT);
    if (!hasKeys) {
      return res.status(400).json({ error: 'Spaces ortam değişkenleri ayarlanmamış. SPACES_KEY, SPACES_SECRET, SPACES_BUCKET, SPACES_ENDPOINT gerekli.' });
    }
  }

  const updates = {};
  if (storage_provider && (storage_provider === 'local' || storage_provider === 'spaces')) updates.storage_provider = storage_provider;
  if (thumb_width && Number(thumb_width) >= 50 && Number(thumb_width) <= 1000) updates.thumb_width = Number(thumb_width);
  if (feed_width && Number(feed_width) >= 200 && Number(feed_width) <= 2000) updates.feed_width = Number(feed_width);
  if (full_width && Number(full_width) >= 400 && Number(full_width) <= 4000) updates.full_width = Number(full_width);
  if (webp_quality && Number(webp_quality) >= 10 && Number(webp_quality) <= 100) updates.webp_quality = Number(webp_quality);
  if (max_upload_bytes && Number(max_upload_bytes) >= 1048576 && Number(max_upload_bytes) <= 52428800) updates.max_upload_bytes = Number(max_upload_bytes);
  if (avif_enabled !== undefined) {
    updates.avif_enabled = dbDriver === 'postgres' ? !!avif_enabled : (avif_enabled ? 1 : 0);
  }

  const setClauses = Object.keys(updates).map((k) => `${k} = ?`);
  const params = Object.values(updates);
  if (setClauses.length > 0) {
    setClauses.push('updated_at = ?');
    params.push(new Date().toISOString());
    params.push(1); // WHERE id = 1
    sqlRun(`UPDATE media_settings SET ${setClauses.join(', ')} WHERE id = ?`, params);
  }

  writeAppLog('info', 'media_settings_updated', { userId: req.session?.userId, changes: updates });
  invalidateCacheNamespace(cacheNamespaces.adminSettings);
  const updated = sqlGet('SELECT * FROM media_settings WHERE id = 1');
  res.json({ ok: true, settings: updated });
});

app.post('/api/admin/media-settings/test', requireAdmin, async (_req, res) => {
  const settings = sqlGet('SELECT * FROM media_settings WHERE id = 1');
  if (!settings || settings.storage_provider !== 'spaces') {
    return res.json({ ok: true, message: 'Yerel depolama aktif, test gerekmez.' });
  }

  try {
    const provider = getStorageProvider(settings, uploadsDir);
    if (provider instanceof SpacesStorageProvider) {
      const result = await provider.testConnection();
      return res.json(result);
    }
    res.json({ ok: true, message: 'Yerel depolama aktif.' });
  } catch (err) {
    res.json({ ok: false, error: err?.message || 'Bağlantı testi başarısız.' });
  }
});

// --- Standalone Image Upload Endpoint ---

app.post('/api/upload-image', requireAuth, uploadRateLimit, imageUpload.single('image'), async (req, res) => {
  if (!req.file) return res.status(400).send('Görsel seçilmedi.');
  try {
    const quotaOk = await enforceUploadQuota(req, res, {
      fileSize: Number(req.file.size || 0),
      bucket: 'generic_image'
    });
    if (!quotaOk) return res.status(429).send('Günlük yükleme kotan doldu. Lütfen daha sonra tekrar dene.');

    const entityType = String(req.body?.entityType || 'misc');
    const entityId = req.body?.entityId || '0';
    const result = await processUpload({
      buffer: req.file.buffer,
      mimeType: req.file.mimetype,
      userId: req.session.userId,
      entityType,
      entityId,
      sqlGet,
      sqlRun,
      uploadsDir,
      writeAppLog
    });
    res.json(result);
  } catch (err) {
    writeAppLog('error', 'upload_image_failed', {
      userId: req.session?.userId || null,
      message: err?.message || 'unknown'
    });
    const status = err?.message?.includes('Desteklenmeyen') || err?.message?.includes('boyut') ? 400 : 500;
    return res.status(status).send(err?.message || 'Görsel yükleme başarısız.');
  }
});

// --- Helper: enrich a post/story row with image variants ---
function enrichWithVariants(row) {
  if (!row) return row;
  if (row.image_record_id) {
    const variants = getImageVariants(row.image_record_id, sqlGet, uploadsDir);
    if (variants) {
      row.variants = {
        thumbUrl: variants.thumbUrl,
        feedUrl: variants.feedUrl,
        fullUrl: variants.fullUrl
      };
    }
  }
  return row;
}

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
  const limit = Math.min(Math.max(parseInt(rawQuery.limit || '20', 10), 1), 100);
  const page = Math.max(parseInt(rawQuery.page || '1', 10), 1);
  const offset = (page - 1) * limit;
  const activeExpr = "(COALESCE(CAST(u.aktiv AS INTEGER), 0) = 1 OR LOWER(CAST(u.aktiv AS TEXT)) IN ('true','evet','yes'))";
  const bannedExpr = "(COALESCE(CAST(u.yasak AS INTEGER), 0) = 1 OR LOWER(CAST(u.yasak AS TEXT)) IN ('true','evet','yes'))";
  const onlineExpr = "(COALESCE(CAST(u.online AS INTEGER), 0) = 1 OR LOWER(CAST(u.online AS TEXT)) IN ('true','evet','yes'))";

  const whereParts = [];
  whereParts.push("(u.role IS NULL OR LOWER(COALESCE(u.role, 'user')) != 'root')");
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
            u.mezuniyetyili, u.email, u.admin, u.role,
            CASE
              WHEN CAST(COALESCE(u.mezuniyetyili, 0) AS INTEGER) BETWEEN 1999 AND 2030 THEN 1
              ELSE 0
            END AS has_graduation_info,
            COALESCE(es.score, 0) AS engagement_score,
            es.updated_at AS engagement_updated_at
     FROM uyeler u
     LEFT JOIN member_engagement_scores es ON es.user_id = u.id
     ${where}
     ORDER BY ${orderBy}
     LIMIT ? OFFSET ?`,
    [...params, limit, offset]
  );

  return {
    users,
    meta: {
      total,
      returned: users.length,
      page,
      pages: Math.max(Math.ceil(total / limit), 1),
      limit,
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
  const userId = Number(req.params.id || 0);
  if (!userId) return res.status(400).send('Geçersiz kullanıcı ID.');
  const actorRole = getUserRole(req.authUser || req.adminUser);
  const targetRole = normalizeRole(sqlGet('SELECT role FROM uyeler WHERE id = ?', [userId])?.role);
  if (targetRole === 'root' && actorRole !== 'root') {
    return res.status(403).send('Root kullanıcı detayına erişemezsiniz.');
  }
  const user = sqlGet(
    `SELECT u.id, u.kadi, u.isim, u.soyisim, u.email, u.aktiv, u.yasak, u.online, u.sontarih,
            u.resim, u.verified, u.mezuniyetyili, u.admin, u.role, u.universite, u.sehir, u.meslek,
            u.websitesi, u.imza, u.mailkapali, u.aktivasyon, u.verification_status,
            COALESCE(es.score, 0) AS engagement_score, es.updated_at AS engagement_updated_at,
            CASE
              WHEN CAST(COALESCE(u.mezuniyetyili, 0) AS INTEGER) BETWEEN 1999 AND 2030 THEN 1
              ELSE 0
            END AS has_graduation_info
     FROM uyeler u
     LEFT JOIN member_engagement_scores es ON es.user_id = u.id
     WHERE u.id = ?`,
    [userId]
  );
  if (!user) return res.status(404).send('Böyle bir üye bulunmamaktadır.');
  res.json({ user });
});

async function handleMemberDelete(req, res) {
  const userId = Number(req.params.id || 0);
  if (!userId) return res.status(400).send('Geçersiz kullanıcı ID.');
  const user = sqlGet('SELECT id, kadi, role FROM uyeler WHERE id = ?', [userId]);
  if (!user) return res.status(404).send('Böyle bir üye bulunmamaktadır.');
  const actorRole = getUserRole(req.authUser || req.adminUser);
  if (normalizeRole(user.role) === 'root' && actorRole !== 'root') {
    return res.status(403).send('Root kullanıcı silinemez.');
  }

  // Don't allow deleting self through this endpoint to prevent accidents
  if (Number(user.id) === Number(req.session.userId)) {
    return res.status(403).send('Kendi hesabınızı bu panelden silemezsiniz.');
  }

  try {
    await hardDeleteUser(user.id, { sqlRun, sqlGet, sqlAll, uploadsDir, writeAppLog });
    res.json({ ok: true, message: `@${user.kadi} ve tüm verileri başarıyla silindi.` });
  } catch (err) {
    console.error('Hard delete failed:', err);
    res.status(500).send(err?.message || 'Kullanıcı silinirken bir hata oluştu.');
  }
}

app.delete('/api/admin/users/:id', requireAdmin, handleMemberDelete);
app.delete('/api/new/admin/members/:id', requireAdmin, handleMemberDelete);

app.put('/api/new/admin/users/:id/graduation-year', requireAdmin, (req, res) => {
  const userId = Number(req.params.id || 0);
  if (!userId) return res.status(400).send('Geçersiz kullanıcı ID.');
  const target = sqlGet('SELECT id, role, mezuniyetyili FROM uyeler WHERE id = ?', [userId]);
  if (!target) return res.status(404).send('Böyle bir üye bulunmamaktadır.');
  const actorRole = getUserRole(req.authUser || req.adminUser);
  if (normalizeRole(target.role) === 'root' && actorRole !== 'root') {
    return res.status(403).send('Root kullanıcının mezuniyet yılı değiştirilemez.');
  }
  const nextYear = normalizeCohortValue(req.body?.mezuniyetyili);
  if (!hasValidGraduationYear(nextYear)) {
    return res.status(400).send(`Mezuniyet yılı ${MIN_GRADUATION_YEAR}-${MAX_GRADUATION_YEAR} aralığında olmalı veya Öğretmen seçilmelidir.`);
  }
  sqlRun('UPDATE uyeler SET mezuniyetyili = ? WHERE id = ?', [nextYear, userId]);
  logAdminAction(req, 'user_graduation_year_updated', {
    targetType: 'user',
    targetId: userId,
    previous: String(target.mezuniyetyili || ''),
    next: nextYear
  });
  res.json({ ok: true, userId, mezuniyetyili: nextYear });
});

app.put('/api/admin/users/:id', requireAdmin, (req, res) => {
  const target = sqlGet('SELECT * FROM uyeler WHERE id = ?', [req.params.id]);
  if (!target) return res.status(404).send('Böyle bir üye bulunmamaktadır.');
  const actorRole = getUserRole(req.authUser || req.adminUser);
  if (normalizeRole(target.role) === 'root' && actorRole !== 'root') {
    return res.status(403).send('Root kullanıcıyı düzenleyemezsiniz.');
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
    verified: Number(payload.verified),
    mezuniyetyili: String(payload.mezuniyetyili || '').trim(),
    universite: String(payload.universite || '').trim(),
    dogumgun: String(payload.dogumgun || '').trim(),
    dogumay: String(payload.dogumay || '').trim(),
    dogumyil: String(payload.dogumyil || '').trim(),
    resim: String(payload.resim || '').trim() || 'yok'
  };

  if (!fields.isim) return res.status(400).send('İsmini girmedin.');
  if (!fields.soyisim) return res.status(400).send('Soyisim girmedin.');
  if (!fields.aktivasyon) return res.status(400).send('Aktivasyon Kodu girmedin.');
  if (!fields.email) return res.status(400).send('E-mail girmedin.');
  if (!validateEmail(fields.email)) return res.status(400).send('E-mail adresi doğru görünmüyor.');
  const numericFields = ['aktiv', 'yasak', 'ilkbd', 'mailkapali', 'hit', 'verified'];
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
         dogumgun = ?, dogumay = ?, dogumyil = ?, verified = ?, resim = ?
     WHERE id = ?`,
    [
      fields.isim, fields.soyisim, fields.aktivasyon, fields.email, fields.aktiv, fields.yasak, fields.ilkbd,
      fields.websitesi, fields.imza, fields.meslek, fields.sehir, fields.mailkapali, fields.hit,
      fields.mezuniyetyili, fields.universite, fields.dogumgun, fields.dogumay, fields.dogumyil,
      fields.verified, fields.resim, target.id
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
  await queueEmailDelivery({ to, subject, html, from }, { maxAttempts: 4, backoffMs: 1500 });
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
    await queueEmailDelivery({ to: row.email, subject, html, from }, { maxAttempts: 4, backoffMs: 1500 });
  }
  res.json({ ok: true, count: recipients.length });
});

app.get('/api/admin/album/categories', requireAlbumAdmin, (_req, res) => {
  const cats = sqlAll('SELECT * FROM album_kat ORDER BY aktif DESC');
  const countRows = sqlAll(
    `SELECT katid,
            SUM(CASE WHEN aktif = 1 THEN 1 ELSE 0 END) AS active_count,
            SUM(CASE WHEN aktif = 0 THEN 1 ELSE 0 END) AS inactive_count
     FROM album_foto
     GROUP BY katid`
  );
  const countMap = new Map(countRows.map((row) => [String(row.katid), {
    activeCount: Number(row.active_count || 0),
    inactiveCount: Number(row.inactive_count || 0)
  }]));
  const counts = {};
  for (const cat of cats) {
    const mapped = countMap.get(String(cat.id)) || { activeCount: 0, inactiveCount: 0 };
    counts[cat.id] = mapped;
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
  const uploaderIds = Array.from(
    new Set(
      photos
        .map((photo) => Number(photo.ekleyenid || 0))
        .filter((id) => Number.isInteger(id) && id > 0)
    )
  );
  const photoIds = Array.from(
    new Set(
      photos
        .map((photo) => Number(photo.id || 0))
        .filter((id) => Number.isInteger(id) && id > 0)
    )
  );
  const uploaderRows = uploaderIds.length
    ? sqlAll(
      `SELECT id, kadi
       FROM uyeler
       WHERE id IN (${uploaderIds.map(() => '?').join(',')})`,
      uploaderIds
    )
    : [];
  const commentRows = photoIds.length
    ? sqlAll(
      `SELECT fotoid, COUNT(*) AS c
       FROM album_fotoyorum
       WHERE fotoid IN (${photoIds.map(() => '?').join(',')})
       GROUP BY fotoid`,
      photoIds
    )
    : [];
  const userMap = {};
  for (const user of uploaderRows) {
    userMap[user.id] = user.kadi;
  }
  const commentCountMap = new Map(
    commentRows.map((row) => [String(row.fotoid), Number(row.c || 0)])
  );
  const commentCounts = {};
  for (const photo of photos) {
    commentCounts[photo.id] = commentCountMap.get(String(photo.id)) || 0;
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
  const baslik = sanitizePlainUserText(String(req.body?.baslik || '').trim(), 255);
  const aciklama = formatUserText(req.body?.aciklama || '');
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


app.post('/api/register/preview', async (req, res) => {
  try {
    if (req.session.userId) return res.status(400).send('Zaten giriş yaptınız.');
    const e2eMode = isE2EHarnessRequest(req);
    const {
      kadi = '',
      sifre = '',
      sifre2 = '',
      email = '',
      isim = '',
      soyisim = '',
      mezuniyetyili = '0',
      gkodu = '',
      kvkk_consent = false,
      directory_consent = false
    } = req.body || {};
    const cleanKadi = String(kadi || '').trim();
    const cleanEmail = normalizeEmail(email);
    const cleanIsim = String(isim || '').trim();
    const cleanSoyisim = String(soyisim || '').trim();

    const cleanCaptcha = String(gkodu || '').trim();
    if (!e2eMode) {
      if (!/^\d+$/.test(cleanCaptcha)) {
        return res.status(400).send('Güvenlik kodu sadece sayı olmalıdır.');
      }
      if (String(req.session.captcha || '') !== cleanCaptcha) {
        return res.status(400).send('Güvenlik kodu yanlış girildi.');
      }
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
    const cohortValue = normalizeCohortValue(mezuniyetyili);
    if (cohortValue === '0' || !cohortValue) return res.status(400).send('Bir mezuniyet yılı veya Öğretmen seçmeniz gerekmektedir.');
    const parsedYear = parseGraduationYear(cohortValue);
    if (!hasValidGraduationYear(cohortValue) || (Number.isFinite(parsedYear) && parsedYear > new Date().getFullYear())) {
      return res.status(400).send('Geçerli bir mezuniyet yılı veya Öğretmen seçmeniz gerekmektedir.');
    }
    if (!e2eMode) {
      if (!kvkk_consent) return res.status(400).send('KVKK Aydınlatma Metni\'ni okumanız ve onaylamanız gerekmektedir.');
      if (!directory_consent) return res.status(400).send('Mezun Rehberi açık rıza onayı gerekmektedir.');
    }
    if (!cleanIsim) return res.status(400).send('İsmini girmedin.');
    if (String(cleanIsim).length > 20) return res.status(400).send('İsim 20 karakterden fazla olmamalıdır.');
    if (!cleanSoyisim) return res.status(400).send('Soyismini girmedin.');
    if (String(cleanSoyisim).length > 20) return res.status(400).send('Soyisim 20 karakterden fazla olmamalıdır.');

    const existingUser = await sqlGetAsync('SELECT id FROM uyeler WHERE kadi = ?', [cleanKadi]);
    if (existingUser) return res.status(400).send('Girdiğiniz kullanıcı adı zaten kayıtlıdır.');
    const existingMail = await sqlGetAsync('SELECT id FROM uyeler WHERE lower(email) = lower(?)', [cleanEmail]);
    if (existingMail) return res.status(400).send('Girdiğiniz e-mail adresi zaten kayıtlıdır.');

    res.json({
      ok: true,
      fields: { kadi: cleanKadi, email: cleanEmail, mezuniyetyili: cohortValue, isim: cleanIsim, soyisim: cleanSoyisim }
    });
  } catch (err) {
    writeAppLog('error', 'register_preview_failed', {
      message: err?.message || 'unknown_error',
      stack: String(err?.stack || '').slice(0, 1200)
    });
    return res.status(500).send('Beklenmeyen bir hata oluştu.');
  }
});

app.post('/api/register/check', async (req, res) => {
  try {
    if (req.session.userId) return res.status(400).send('Zaten giriş yaptınız.');
    const { kadi = '', email = '' } = req.body || {};
    const cleanKadi = String(kadi || '').trim();
    const cleanEmail = normalizeEmail(email);

    if (!cleanKadi && !cleanEmail) {
      return res.status(400).send('Kontrol için kullanıcı adı veya e-mail girilmelidir.');
    }

    let kadiExists = false;
    let emailExists = false;
    if (cleanKadi) {
      const existingUser = await sqlGetAsync('SELECT id FROM uyeler WHERE kadi = ?', [cleanKadi]);
      kadiExists = Boolean(existingUser);
    }
    if (cleanEmail && validateEmail(cleanEmail)) {
      const existingMail = await sqlGetAsync('SELECT id FROM uyeler WHERE lower(email) = lower(?)', [cleanEmail]);
      emailExists = Boolean(existingMail);
    }

    res.json({ ok: true, kadiExists, emailExists });
  } catch (err) {
    writeAppLog('error', 'register_check_failed', {
      message: err?.message || 'unknown_error',
      stack: String(err?.stack || '').slice(0, 1200)
    });
    return res.status(500).send('Beklenmeyen bir hata oluştu.');
  }
});

app.post('/api/register', async (req, res) => {
  try {
    if (req.session.userId) return res.status(400).send('Zaten giriş yaptınız.');
    const e2eMode = isE2EHarnessRequest(req);
    const {
      kadi = '',
      sifre = '',
      sifre2 = '',
      email = '',
      isim = '',
      soyisim = '',
      mezuniyetyili = '0',
      gkodu = '',
      kvkk_consent = false,
      directory_consent = false,
      role: requestedRole = 'user',
      moderationPermissionKeys = []
    } = req.body || {};
    const cleanKadi = String(kadi || '').trim();
    const cleanEmail = normalizeEmail(email);
    const cleanIsim = String(isim || '').trim();
    const cleanSoyisim = String(soyisim || '').trim();
    const traceE2E = (step, meta = {}) => {
      if (!e2eMode) return;
      writeAppLog('info', 'register_e2e_step', {
        step,
        kadi: cleanKadi,
        email: cleanEmail,
        ip: req.ip,
        ...meta
      });
    };

  const cleanCaptcha = String(gkodu || '').trim();
  if (!e2eMode) {
    if (!/^\d+$/.test(cleanCaptcha)) return res.status(400).send('Güvenlik kodu sadece sayı olmalıdır.');
    if (String(req.session.captcha || '') !== cleanCaptcha) return res.status(400).send('Güvenlik kodu yanlış girildi.');
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
  const cohortValue = normalizeCohortValue(mezuniyetyili);
  if (cohortValue === '0' || !cohortValue) return res.status(400).send('Bir mezuniyet yılı veya Öğretmen seçmeniz gerekmektedir.');
  if (!e2eMode) {
    if (!kvkk_consent) return res.status(400).send('KVKK Aydınlatma Metni\'ni okumanız ve onaylamanız gerekmektedir.');
    if (!directory_consent) return res.status(400).send('Mezun Rehberi açık rıza onayı gerekmektedir.');
  }
  if (!cleanIsim) return res.status(400).send('İsmini girmedin.');
  if (String(cleanIsim).length > 20) return res.status(400).send('İsim 20 karakterden fazla olmamalıdır.');
  if (!cleanSoyisim) return res.status(400).send('Soyismini girmedin.');
  if (String(cleanSoyisim).length > 20) return res.status(400).send('Soyisim 20 karakterden fazla olmamalıdır.');

    traceE2E('before_duplicate_checks');
    const existingUser = await sqlGetAsync('SELECT id FROM uyeler WHERE kadi = ?', [cleanKadi]);
    if (existingUser) return res.status(400).send('Girdiğiniz kullanıcı adı zaten kayıtlıdır.');
    const existingMail = await sqlGetAsync('SELECT id FROM uyeler WHERE lower(email) = lower(?)', [cleanEmail]);
    if (existingMail) return res.status(400).send('Girdiğiniz e-mail adresi zaten kayıtlıdır.');
    traceE2E('after_duplicate_checks');

  const parsedYear = parseGraduationYear(cohortValue);
  if (!hasValidGraduationYear(cohortValue) || (Number.isFinite(parsedYear) && parsedYear > new Date().getFullYear())) {
    return res.status(400).send('Geçerli bir mezuniyet yılı veya Öğretmen seçmeniz gerekmektedir.');
  }

  const e2eRole = e2eMode ? normalizeE2ERole(requestedRole) : 'user';
  const e2eIsAdmin = e2eMode && roleAtLeast(e2eRole, 'admin');
  const e2eIsVerified = e2eMode;
  const e2eIsActive = e2eMode;
  const e2eRequestedModerationKeys = e2eMode ? parseE2EModerationPermissionKeys(moderationPermissionKeys) : [];
  const e2eModerationKeys = e2eMode
    ? (e2eRequestedModerationKeys.length
      ? e2eRequestedModerationKeys
      : Array.from(MODERATION_PERMISSION_KEY_SET))
    : [];

  const aktivasyon = createActivation();
  const now = new Date().toISOString();
    traceE2E('before_insert');
    const result = await sqlRunAsync(
    `INSERT INTO uyeler (kadi, sifre, email, isim, soyisim, aktivasyon, aktiv, ilktarih, resim, mezuniyetyili, ilkbd, verification_status, kvkk_consent_at, directory_consent_at, verified, role, admin)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'yok', ?, ?, ?, ?, ?, ?, ?, ?)`,
    [
      cleanKadi,
      (e2eMode ? hashE2EPassword(sifre) : await hashPassword(sifre)),
      cleanEmail,
      cleanIsim,
      cleanSoyisim,
      aktivasyon,
      toDbBooleanParam(e2eIsActive),
      now,
      cohortValue,
      toDbBooleanParam(false),
      e2eIsVerified ? 'verified' : 'pending',
      now,
      now,
      toDbBooleanParam(e2eIsVerified),
      e2eRole,
      toDbBooleanParam(e2eIsAdmin)
    ]
  );
    const newId = result?.lastInsertRowid;
    traceE2E('after_insert', { userId: Number(newId || 0) });

    if (e2eMode && e2eRole === 'mod' && newId) {
      traceE2E('before_mod_permissions');
      await replaceModeratorPermissionsAsync(newId, e2eModerationKeys, newId);
      traceE2E('after_mod_permissions');
    }

    const welcome = await sqlGetAsync('SELECT id FROM uyeler WHERE id = 1');
    if (welcome && !e2eMode) {
      await sqlRunAsync(
      `INSERT INTO gelenkutusu (kime, kimden, aktifgelen, aktifgiden, yeni, konu, mesaj, tarih)
       VALUES (?, 1, 1, 1, 1, 'Hoşgeldiniz!', ?, ?)`,
      [String(newId), 'Sdal.org - Süleyman Demirel Anadolu Lisesi Mezunları Web Sitesine hoşgeldiniz!<br><br>Bu <b>mesaj paneli</b> sayesinde diğer üyeler ile haberleşebilirsiniz.<br><br>Hoşça vakit geçirmeniz dileğiyle...<br><b><i>sdal.org</b></i>', now]
      );
    }

    let mailSent = false;
    let mailQueued = false;
    if (!e2eMode) {
      const publicBaseUrl = resolvePublicBaseUrl(req);
      const activationLink = `${publicBaseUrl}/aktivet?id=${newId}&akt=${aktivasyon}`;
      const html = buildActivationEmailHtml({
        siteBase: publicBaseUrl,
        activationLink,
        user: { kadi: cleanKadi, isim: cleanIsim, soyisim: cleanSoyisim }
      });

      queueEmailDelivery(
        { to: cleanEmail, subject: 'SDAL.ORG - Üyelik Başvurusu', html, timeoutMs: Number(process.env.MAIL_SEND_TIMEOUT_MS || 8000) },
        { maxAttempts: 4, backoffMs: 1500 }
      ).catch((err) => {
        console.error('Register activation mail send failed:', err);
      });
      mailSent = true;
      mailQueued = true;
    }

    traceE2E('before_response');
    res.json({
      ok: true,
      mailSent,
      mailQueued,
      message: e2eMode
        ? 'E2E kayıt tamamlandı. Hesap aktif ve doğrulanmış olarak oluşturuldu.'
        : 'Kayıt tamamlandı. Aktivasyon e-postası gönderim kuyruğuna alındı.',
      e2e: e2eMode ? {
        userId: Number(newId || 0),
        active: true,
        verified: true,
        role: e2eRole,
        moderationPermissionCount: e2eRole === 'mod' ? e2eModerationKeys.length : 0
      } : undefined
    });
  } catch (err) {
    writeAppLog('error', 'register_failed', {
      message: err?.message || 'unknown_error',
      stack: String(err?.stack || '').slice(0, 2000)
    });
    return res.status(500).send('Kayıt sırasında beklenmeyen bir hata oluştu.');
  }
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
  const email = normalizeEmail(req.body?.email);
  if (!email) return res.status(400).send('E-mail adresini girmedin.');
  if (!validateEmail(email)) return res.status(400).send('E-mail adresi doğru görünmüyor.');
  const user = sqlGet('SELECT * FROM uyeler WHERE lower(email) = lower(?)', [email]);
  if (!user) return res.status(404).send('Bu e-mail adresiyle kayıtlı bir kullanıcı bulunamadı.');
  if (Number(user.aktiv || 0) === 1) return res.status(400).send('Bu hesap zaten aktif edildi.');
  const publicBaseUrl = resolvePublicBaseUrl(req);
  const activationLink = `${publicBaseUrl}/aktivet?id=${user.id}&akt=${user.aktivasyon}`;
  const html = buildActivationEmailHtml({
    siteBase: publicBaseUrl,
    activationLink,
    user
  });
  await queueEmailDelivery({ to: user.email, subject: 'SDAL - Aktivasyon', html }, { maxAttempts: 4, backoffMs: 1200 });
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
  await queueEmailDelivery({ to: user.email, subject: 'SDAL.ORG - ŞİFRE HATIRLAMA', html }, { maxAttempts: 4, backoffMs: 1200 });
  res.json({ ok: true });
});

app.post('/api/mail/test', async (req, res) => {
  const fallback = process.env.MAIL_FROM || process.env.SMTP_FROM || process.env.MAIL_SMTP_USER || process.env.SMTP_USER || '';
  const candidates = extractEmails(req.body?.to || fallback);
  if (!candidates.length) return res.status(400).send('Test e-mail adresi eksik.');
  const invalid = candidates.find((value) => !validateEmail(value));
  if (invalid) return res.status(400).send('E-mail adresi doğru görünmüyor.');
  const to = candidates.join(', ');
  try {
    await queueEmailDelivery({
      to,
      subject: 'SDAL SMTP Test',
      html: 'Bu bir SMTP test e-postasıdır.'
    }, { maxAttempts: 2, backoffMs: 1000 });
    const runtimeMailStatus = typeof mailSender.getStatus === 'function' ? mailSender.getStatus() : mailProviderStatus;
    res.json({
      ok: true,
      to,
      provider: runtimeMailStatus?.provider || mailProviderStatus.provider,
      mock: !runtimeMailStatus?.configured,
      configured: !!runtimeMailStatus?.configured
    });
  } catch (err) {
    console.error('SMTP test error:', err);
    res.status(500).send('SMTP test başarısız.');
  }
});

app.post('/api/mail/webhooks/brevo', (req, res) => {
  const expectedToken = String(process.env.MAIL_WEBHOOK_SHARED_SECRET || '').trim();
  const presentedToken = String(req.get('x-sdal-webhook-token') || req.get('x-mailin-custom') || '').trim();
  if (expectedToken && presentedToken !== expectedToken) {
    writeAppLog('warn', 'mail_webhook_rejected', {
      provider: 'brevo',
      reason: 'invalid_shared_secret',
      ip: req.ip || ''
    });
    return res.status(401).json({ ok: false, error: 'unauthorized' });
  }

  const payload = req.body;
  const events = Array.isArray(payload) ? payload : (payload ? [payload] : []);

  for (const item of events) {
    if (!item || typeof item !== 'object') continue;
    const eventType = String(item.event || item.type || 'unknown');
    const email = String(item.email || item.recipient || '');
    const messageId = String(item['message-id'] || item.messageId || item.id || '');
    const reason = String(item.reason || item.response || '');
    const level = ['hard_bounce', 'soft_bounce', 'blocked', 'spam'].includes(eventType) ? 'warn' : 'info';
    writeAppLog(level, 'mail_webhook_event', {
      provider: 'brevo',
      eventType,
      email,
      messageId,
      reason
    });
  }

  res.json({ ok: true, received: events.length });
});

app.get('/kvkk', (_req, res) => {
  res.type('html').send(`<!doctype html>
<html lang="tr">
<head><meta charset="utf-8" /><meta name="viewport" content="width=device-width,initial-scale=1" /><title>SDAL KVKK Aydınlatma Metni</title></head>
<body style="font-family:Arial,sans-serif;line-height:1.6;max-width:920px;margin:24px auto;padding:0 16px;color:#1f2937">
<h1>SDAL Platformu KVKK Aydınlatma Metni</h1>
<p><b>Veri Sorumlusu:</b> SDAL mezun platformu yöneticileri ("SDAL"). Bu metin 6698 sayılı Kişisel Verilerin Korunması Kanunu m.10 kapsamında bilgilendirme amacıyla hazırlanmıştır.</p>
<h2>1. İşlenen Kişisel Veriler</h2><p>Kimlik ve iletişim (ad, soyad, e-posta), hesap bilgileri (kullanıcı adı, mezuniyet yılı, profil fotoğrafı), kullanım/veri güvenliği kayıtları (IP, oturum, işlem kayıtları), isteğe bağlı profil alanları ve üyeler arası mesajlaşma içerikleri.</p>
<h2>2. İşleme Amaçları</h2><p>Üyelik hesabının kurulması ve yönetimi, mezunlar arası iletişim, platform güvenliğinin sağlanması, kötüye kullanımın önlenmesi, yasal yükümlülüklerin yerine getirilmesi, teknik destek ve topluluk yönetimi süreçlerinin yürütülmesi.</p>
<h2>3. Hukuki Sebepler</h2><p>KVKK m.5/2-c (sözleşmenin kurulması/ifası), m.5/2-ç (hukuki yükümlülük), m.5/2-f (meşru menfaat) ve gerekli hallerde açık rıza (m.5/1) kapsamında işleme yapılır.</p>
<h2>4. Aktarım</h2><p>Kişisel veriler; barındırma, e-posta, güvenlik ve yedekleme hizmeti sağlayıcılarına, sadece hizmetin gerektirdiği ölçüde aktarılabilir. Kanunen yetkili kamu kurumlarına hukuki zorunluluk halinde paylaşım yapılabilir.</p>
<h2>5. Saklama Süreleri</h2><p>Veriler ilgili mevzuat, uyuşmazlık zamanaşımı ve platform operasyon ihtiyaçlarına göre gerekli süre boyunca saklanır; süresi dolan veriler silinir, yok edilir veya anonimleştirilir.</p>
<h2>6. Haklarınız</h2><p>KVKK m.11 kapsamındaki; işlenip işlenmediğini öğrenme, bilgi talep etme, düzeltme, silme/yok etme, aktarılan tarafları öğrenme, itiraz ve zarar halinde tazminat talep haklarınızı kullanabilirsiniz.</p>
<p>Başvuru ve talepler için: <a href="mailto:kvkk@sdal.org">kvkk@sdal.org</a></p>
<hr /><p>Bu metin, platform süreçlerindeki değişikliklere göre güncellenebilir. Güncel metin her zaman bu bağlantıda yayımlanır.</p>
</body></html>`);
});

app.get('/kvkk/acik-riza', (_req, res) => {
  res.type('html').send(`<!doctype html>
<html lang="tr">
<head><meta charset="utf-8" /><meta name="viewport" content="width=device-width,initial-scale=1" /><title>SDAL Mezun Rehberi Açık Rıza Metni</title></head>
<body style="font-family:Arial,sans-serif;line-height:1.6;max-width:920px;margin:24px auto;padding:0 16px;color:#1f2937">
<h1>SDAL Mezun Rehberi Açık Rıza Metni</h1>
<p>Bu açık rıza; ad-soyad, mezuniyet yılı, okul/üniversite ve profilde paylaştığınız sınırlı mesleki bilgilerin, yalnızca SDAL üyelerine açık Mezun Rehberi alanında görüntülenmesine ilişkindir.</p>
<ul><li>Rıza vermeniz üyelik sözleşmesinin zorunlu unsuru değildir; ancak ilgili rehber özelliğinin çalışması için gereklidir.</li><li>Rızanızı dilediğiniz zaman profil ve destek kanalları üzerinden geri alabilirsiniz.</li><li>Geri alma, geri alma öncesi hukuka uygun işleme faaliyetlerini etkilemez.</li></ul>
<p>İrtibat: <a href="mailto:kvkk@sdal.org">kvkk@sdal.org</a></p>
</body></html>`);
});

app.get('/api/profile', async (req, res) => {
  if (!req.session.userId) return res.status(401).send('Login required');
  const cacheKey = await buildVersionedCacheKey(cacheNamespaces.profile, [
    `user:${Number(req.session.userId || 0)}`
  ]);
  const cached = await getCacheJson(cacheKey);
  if (cached && cached.user) {
    return res.json(cached);
  }
  const user = sqlGet(`
    SELECT id, kadi, isim, soyisim, email, mezuniyetyili, sehir, meslek, websitesi, universite,
           dogumgun, dogumay, dogumyil, mailkapali, imza, resim, ilkbd,
           sirket, unvan, uzmanlik, linkedin_url, universite_bolum, mentor_opt_in, mentor_konulari,
           kvkk_consent_at, directory_consent_at
    FROM uyeler WHERE id = ?`, [req.session.userId]);
  if (user) {
    user.kvkk_consent = Boolean(user.kvkk_consent_at);
    user.directory_consent = Boolean(user.directory_consent_at);
  }
  const responsePayload = { user };
  await setCacheJson(cacheKey, responsePayload, PROFILE_CACHE_TTL_SECONDS);
  res.json(responsePayload);
});

app.put('/api/profile', async (req, res) => {
  if (!req.session.userId) return res.status(401).send('Login required');
  try {
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
    const mezuniyetyili = normalizeCohortValue(req.body.mezuniyetyili);
    const kvkkConsent = Boolean(req.body.kvkk_consent);
    const directoryConsent = Boolean(req.body.directory_consent);
    const sirket = String(req.body.sirket || '').trim();
    const unvan = String(req.body.unvan || '').trim();
    const uzmanlik = String(req.body.uzmanlik || '').trim();
    const linkedinUrl = String(req.body.linkedin_url || '').trim();
    const universiteBolum = String(req.body.universite_bolum || '').trim();
    const mentorOptIn = Boolean(req.body.mentor_opt_in);
    const mentorKonulari = String(req.body.mentor_konulari || '').trim();
    const dogumgun = parseInt(req.body.dogumgun || '0', 10) || 0;
    const dogumay = parseInt(req.body.dogumay || '0', 10) || 0;
    const dogumyil = parseInt(req.body.dogumyil || '0', 10) || 0;
    const mailkapali = String(req.body.mailkapali || '0') === '1';
    const imza = String(req.body.imza || '');

    if (!hasValidGraduationYear(mezuniyetyili)) {
      return res.status(400).send(`Mezuniyet yılı ${MIN_GRADUATION_YEAR}-${MAX_GRADUATION_YEAR} aralığında olmalı veya Öğretmen seçilmelidir.`);
    }

    const legacyCols = await getTableColumnSetAsync('uyeler');
    const modernCols = await getTableColumnSetAsync('users');
    const targetTable = modernCols.size ? 'users' : 'uyeler';
    const targetCols = targetTable === 'users' ? modernCols : legacyCols;
    const current = targetTable === 'users'
      ? await sqlGetAsync(
        `SELECT id,
                oauth_provider,
                COALESCE(is_verified, FALSE) AS verified,
                graduation_year AS mezuniyetyili,
                COALESCE(is_profile_initialized, FALSE) AS ilkbd,
                privacy_consent_at AS kvkk_consent_at,
                directory_consent_at
           FROM users
          WHERE id = ?`,
        [req.session.userId]
      )
      : await sqlGetAsync(
        `SELECT id,
                oauth_provider,
                COALESCE(verified, 0) AS verified,
                mezuniyetyili,
                COALESCE(ilkbd, 0) AS ilkbd,
                kvkk_consent_at,
                directory_consent_at
           FROM uyeler
          WHERE id = ?`,
        [req.session.userId]
      );
    const nextIlkbd = current && current.ilkbd === 0 ? true : Boolean(current?.ilkbd ?? true);
    const isOAuthUser = Boolean(String(current?.oauth_provider || '').trim());
    const nextKvkkConsent = Boolean(current?.kvkk_consent_at) || kvkkConsent;
    const nextDirectoryConsent = Boolean(current?.directory_consent_at) || directoryConsent;
    if (isOAuthUser && !nextKvkkConsent) {
      return res.status(400).send('Sosyal üyelik için KVKK Aydınlatma Metni onayı zorunludur.');
    }
    if (isOAuthUser && !nextDirectoryConsent) {
      return res.status(400).send('Sosyal üyelik için Mezun Rehberi açık rıza onayı zorunludur.');
    }

    if (Number(current?.verified || 0) === 1 && String(current?.mezuniyetyili || '') !== mezuniyetyili) {
      return res.status(403).json({
        error: 'GRADUATION_YEAR_LOCKED',
        message: 'Doğrulanmış üyelerde mezuniyet yılı değiştirilemez. Yönetim talebi oluşturun.',
        requestUrl: '/new/requests?category=graduation_year_change'
      });
    }

    const setClauses = [];
    const params = [];
    const pushSet = (column, value) => {
      if (!targetCols.has(String(column || '').toLowerCase())) return;
      setClauses.push(`${column} = ?`);
      params.push(value);
    };

    if (targetTable === 'users') {
      pushSet('first_name', isim);
      pushSet('last_name', soyisim);
      pushSet('city', sehir);
      pushSet('profession', meslek);
      pushSet('website_url', websitesi);
      pushSet('university_name', universite);
      pushSet('graduation_year', mezuniyetyili);
      pushSet('birth_day', dogumgun);
      pushSet('birth_month', dogumay);
      pushSet('birth_year', dogumyil);
      pushSet('is_email_hidden', toDbFlagForColumn('users', 'is_email_hidden', mailkapali));
      pushSet('signature', imza);
      pushSet('is_profile_initialized', toDbFlagForColumn('users', 'is_profile_initialized', nextIlkbd));
      pushSet('company_name', sirket);
      pushSet('job_title', unvan);
      pushSet('expertise', uzmanlik);
      pushSet('linkedin_url', linkedinUrl);
      pushSet('university_department', universiteBolum);
      pushSet('is_mentor_opted_in', toDbFlagForColumn('users', 'is_mentor_opted_in', mentorOptIn));
      pushSet('mentor_topics', mentorKonulari);
    } else {
      pushSet('isim', isim);
      pushSet('soyisim', soyisim);
      pushSet('sehir', sehir);
      pushSet('meslek', meslek);
      pushSet('websitesi', websitesi);
      pushSet('universite', universite);
      pushSet('mezuniyetyili', mezuniyetyili);
      pushSet('dogumgun', dogumgun);
      pushSet('dogumay', dogumay);
      pushSet('dogumyil', dogumyil);
      pushSet('mailkapali', toDbFlagForColumn('uyeler', 'mailkapali', mailkapali));
      pushSet('imza', imza);
      pushSet('ilkbd', toDbFlagForColumn('uyeler', 'ilkbd', nextIlkbd));
      pushSet('sirket', sirket);
      pushSet('unvan', unvan);
      pushSet('uzmanlik', uzmanlik);
      pushSet('linkedin_url', linkedinUrl);
      pushSet('universite_bolum', universiteBolum);
      pushSet('mentor_opt_in', toDbFlagForColumn('uyeler', 'mentor_opt_in', mentorOptIn));
      pushSet('mentor_konulari', mentorKonulari);
    }

    const nowIso = new Date().toISOString();
    const kvkkColumn = targetTable === 'users' ? 'privacy_consent_at' : 'kvkk_consent_at';
    const directoryColumn = 'directory_consent_at';
    const appendConsentUpdate = (column, consentProvided) => {
      if (!targetCols.has(column)) return;
      const currentValue = current?.[column] ?? null;
      const hasCurrentValue = currentValue !== null && currentValue !== undefined && String(currentValue).trim() !== '';
      const type = String(getColumnType(targetTable, column) || '').toLowerCase();
      if (type === 'boolean') {
        pushSet(column, hasCurrentValue ? toDbFlagForColumn(targetTable, column, currentValue) : toDbFlagForColumn(targetTable, column, consentProvided));
        return;
      }
      if (type.includes('int') || type === 'numeric' || type === 'real' || type === 'double precision') {
        pushSet(column, hasCurrentValue ? Number(toTruthyFlag(currentValue)) : toDbNumericFlag(consentProvided));
        return;
      }
      if (consentProvided && !hasCurrentValue) {
        pushSet(column, nowIso);
      }
    };
    appendConsentUpdate(kvkkColumn, kvkkConsent);
    appendConsentUpdate(directoryColumn, directoryConsent);

    if (targetCols.has('updated_at')) {
      pushSet('updated_at', nowIso);
    }
    if (!setClauses.length) {
      throw new Error('profile_update_no_columns');
    }
    params.push(req.session.userId);
    await sqlRunAsync(`UPDATE ${targetTable} SET ${setClauses.join(', ')} WHERE id = ?`, params);
    invalidateCacheNamespace(cacheNamespaces.profile);
    res.json({ ok: true });
  } catch (err) {
    writeAppLog('error', 'profile_update_failed', {
      userId: req.session?.userId || null,
      message: err?.message || 'unknown_error',
      stack: String(err?.stack || '').slice(0, 1200)
    });
    console.error('[profile_update_failed]', {
      userId: req.session?.userId || null,
      message: err?.message || 'unknown_error'
    });
    if (isE2EHarnessRequest(req)) {
      return res.status(500).json({
        ok: false,
        error: 'profile_update_failed',
        message: err?.message || 'unknown_error'
      });
    }
    return res.status(500).send('Profil güncellenirken bir hata oluştu.');
  }
});

app.post('/api/profile/email-change/request', requireAuth, async (req, res) => {
  const user = getCurrentUser(req);
  const nextEmail = normalizeEmail(req.body?.email);
  if (!nextEmail) return res.status(400).send('Yeni e-posta adresi gerekli.');
  if (!validateEmail(nextEmail)) return res.status(400).send('E-mail adresi doğru görünmüyor.');
  if (String(user?.email || '').toLowerCase() === nextEmail.toLowerCase()) {
    return res.status(400).send('Mevcut e-posta ile aynı adresi girdiniz.');
  }
  const duplicate = sqlGet('SELECT id FROM uyeler WHERE lower(email) = lower(?) AND id != ?', [nextEmail, req.session.userId]);
  if (duplicate) return res.status(400).send('Bu e-posta adresi başka bir üyede kayıtlı.');

  sqlRun('UPDATE email_change_requests SET status = ? WHERE user_id = ? AND status = ?', ['replaced', req.session.userId, 'pending']);
  const token = crypto.randomBytes(32).toString('hex');
  const now = new Date();
  const expiresAt = new Date(now.getTime() + 1000 * 60 * 60 * 24);
  sqlRun(
    `INSERT INTO email_change_requests
    (user_id, current_email, new_email, token, status, created_at, expires_at, ip, user_agent)
    VALUES (?, ?, ?, ?, 'pending', ?, ?, ?, ?)`,
    [req.session.userId, user.email || '', nextEmail, token, now.toISOString(), expiresAt.toISOString(), req.ip || '', req.headers['user-agent'] || '']
  );

  const base = resolvePublicBaseUrl(req);
  const verifyLink = `${base}/api/profile/email-change/verify?token=${encodeURIComponent(token)}`;
  const html = `<!doctype html><html><body style="font-family:Arial,sans-serif;background:#f4efe8;padding:24px;color:#1f2937;">
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width:600px;margin:0 auto;background:#fff;border:1px solid #e5e7eb;border-radius:12px;">
    <tr><td style="padding:20px 24px;">
      <h2 style="margin:0 0 12px;font-size:18px;">SDAL E-posta Değişikliği</h2>
      <p style="margin:0 0 12px;">Merhaba ${escapeHtml(user?.isim || user?.kadi || 'Üye')},</p>
      <p style="margin:0 0 16px;">Yeni e-posta adresini onaylamak için aşağıdaki butona tıkla:</p>
      <a href="${escapeHtml(verifyLink)}" style="display:inline-block;padding:10px 14px;border-radius:999px;background:#ff6b4a;color:#111827;text-decoration:none;font-weight:700;">E-postamı Doğrula</a>
      <p style="margin:16px 0 0;color:#6b7280;font-size:13px;">Bu link 24 saat geçerlidir.</p>
    </td></tr>
  </table>
  </body></html>`;
  await queueEmailDelivery({ to: nextEmail, subject: 'SDAL - E-posta değişikliği doğrulama', html }, { maxAttempts: 4, backoffMs: 1500 });
  res.json({ ok: true });
});

app.get('/api/profile/email-change/verify', (req, res) => {
  const token = String(req.query?.token || '').trim();
  if (!token) return res.status(400).send('Doğrulama tokeni eksik.');
  const row = sqlGet('SELECT * FROM email_change_requests WHERE token = ?', [token]);
  if (!row) return res.status(404).send('Doğrulama kaydı bulunamadı.');
  if (row.status !== 'pending') return res.status(400).send('Bu doğrulama linki zaten kullanılmış veya iptal edilmiş.');
  if (row.expires_at && new Date(row.expires_at).getTime() < Date.now()) {
    sqlRun('UPDATE email_change_requests SET status = ? WHERE id = ?', ['expired', row.id]);
    return res.status(400).send('Doğrulama linkinin süresi dolmuş.');
  }
  const duplicate = sqlGet('SELECT id FROM uyeler WHERE lower(email) = lower(?) AND id != ?', [row.new_email, row.user_id]);
  if (duplicate) return res.status(400).send('Bu e-posta adresi artık kullanımda olduğu için değişiklik tamamlanamadı.');
  sqlRun('UPDATE uyeler SET email = ? WHERE id = ?', [row.new_email, row.user_id]);
  sqlRun('UPDATE email_change_requests SET status = ?, verified_at = ? WHERE id = ?', ['verified', new Date().toISOString(), row.id]);
  invalidateCacheNamespace(cacheNamespaces.profile);
  return res.redirect('/new/profile?emailChanged=1');
});

app.get('/api/new/request-categories', requireAuth, (_req, res) => {
  const items = sqlAll('SELECT category_key, label, description FROM request_categories WHERE active = 1 ORDER BY id');
  res.json({ items });
});

app.get('/api/new/requests/my', requireAuth, (req, res) => {
  const items = sqlAll(
    `SELECT r.id, r.category_key, r.payload_json, r.status, r.created_at, r.reviewed_at, r.resolution_note,
            c.label AS category_label
     FROM member_requests r
     LEFT JOIN request_categories c ON c.category_key = r.category_key
     WHERE r.user_id = ?
     ORDER BY r.id DESC`,
    [req.session.userId]
  );
  res.json({ items });
});


app.post('/api/new/requests/upload', requireAuth, uploadRateLimit, requestAttachmentUpload.single('file'), async (req, res) => {
  if (!req.file?.path) return res.status(400).send('Dosya yüklenemedi.');
  const validation = validateUploadedFileSafety(req.file.path, { allowedMimes: ['image/jpeg', 'image/png', 'application/pdf'] });
  if (!validation.ok) {
    cleanupUploadedFile(req.file.path);
    return res.status(400).send(validation.reason || 'Dosya güvenlik kontrolünden geçemedi.');
  }
  const quotaOk = await enforceUploadQuota(req, res, {
    fileSize: Number(req.file.size || 0),
    bucket: 'request_attachment'
  });
  if (!quotaOk) {
    cleanupUploadedFile(req.file.path);
    return res.status(429).send('Günlük yükleme kotan doldu. Lütfen daha sonra tekrar dene.');
  }
  res.json({
    ok: true,
    attachment: {
      name: req.file.originalname,
      mime: validation.mime,
      size: Number(req.file.size || 0),
      url: `/uploads/request-attachments/${req.file.filename}`
    }
  });
});

app.post('/api/new/requests', requireAuth, (req, res) => {
  const categoryKey = String(req.body?.category_key || '').trim();
  const payload = req.body?.payload || {};
  if (!categoryKey) return res.status(400).send('Talep kategorisi gerekli.');
  const category = sqlGet('SELECT category_key FROM request_categories WHERE category_key = ? AND active = 1', [categoryKey]);
  if (!category) return res.status(400).send('Geçersiz talep kategorisi.');
  const existing = sqlGet('SELECT id FROM member_requests WHERE user_id = ? AND category_key = ? AND status = ?', [req.session.userId, categoryKey, 'pending']);
  if (existing) return res.status(400).send('Bu kategori için bekleyen bir talebiniz zaten var.');
  sqlRun(
    'INSERT INTO member_requests (user_id, category_key, payload_json, status, created_at) VALUES (?, ?, ?, ?, ?)',
    [req.session.userId, categoryKey, JSON.stringify(payload || {}), 'pending', new Date().toISOString()]
  );
  res.json({ ok: true });
});

app.post('/api/profile/password', async (req, res) => {
  if (!req.session.userId) return res.status(401).send('Login required');
  const { eskisifre = '', yenisifre = '', yenisifretekrar = '' } = req.body || {};
  if (!eskisifre) return res.status(400).send('Şifreni değiştirebilmek için eski şifreni girmen gerekiyor');
  if (!yenisifre) return res.status(400).send('Şifreni değiştirebilmek için yeni şifreni girmen gerekiyor');
  if (!yenisifretekrar) return res.status(400).send('Şifreni değiştirebilmek için yeni şifreni tekrar girmen gerekiyor');
  if (String(yenisifre).length > 20) return res.status(400).send('Yeni şifre 20 karakterden fazla olmamalıdır.');

  const user = sqlGet('SELECT sifre FROM uyeler WHERE id = ?', [req.session.userId]);
  const verify = await verifyPassword(user?.sifre, eskisifre);
  if (!verify.ok) return res.status(400).send('Şifreni yanlış girdin');
  if (yenisifre !== yenisifretekrar) return res.status(400).send('Girdiğin şifreler birbirleriyle uyuşmuyor');

  sqlRun('UPDATE uyeler SET sifre = ? WHERE id = ?', [await hashPassword(yenisifre), req.session.userId]);
  res.json({ ok: true });
});

app.post('/api/profile/photo', uploadRateLimit, (req, res, next) => {
  if (!req.session.userId) return res.status(401).send('Login required');
  return next();
}, photoUpload.single('file'), async (req, res) => {
  if (!req.file) return res.status(400).send('Fotoğraf seçilmedi');
  const processed = await processDiskImageUpload({
    req,
    res,
    file: req.file,
    bucket: 'profile_photo',
    preset: uploadImagePresets.profilePhoto,
    allowedMimes: ['image/jpeg', 'image/png', 'image/webp', 'image/gif', 'image/bmp', 'image/tiff']
  });
  if (!processed.ok) return res.status(processed.statusCode).send(processed.message);
  try {
    const filename = path.basename(processed.path || req.file.path);
    sqlRun('UPDATE uyeler SET resim = ? WHERE id = ?', [filename, req.session.userId]);
    invalidateCacheNamespace(cacheNamespaces.profile);
    res.json({ ok: true, photo: filename });
  } catch {
    res.status(500).send('Profil fotoğrafı işlenemedi.');
  }
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

app.get('/api/members', async (req, res) => {
  try {
    if (!req.session.userId) return res.status(401).send('Login required');
    ensureTeacherAlumniLinksTable();
    const page = Math.max(parseInt(req.query.page || '1', 10), 1);
    const pageSize = Math.min(Math.max(parseInt(req.query.pageSize || '10', 10), 1), 50);
    const term = req.query.term ? String(req.query.term).replace(/'/g, '') : '';
    const gradYear = parseInt(String(req.query.gradYear || '0'), 10) || 0;
    const location = req.query.location ? String(req.query.location).trim().toLowerCase() : '';
    const profession = req.query.profession ? String(req.query.profession).trim().toLowerCase() : '';
    const expertise = req.query.expertise ? String(req.query.expertise).trim().toLowerCase() : '';
    const title = req.query.title ? String(req.query.title).trim().toLowerCase() : '';
    const mentorsOnly = String(req.query.mentors || '').trim() === '1';
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
    if (location) {
      whereParts.push('LOWER(sehir) LIKE ?');
      params.push(`%${location}%`);
    }
    if (profession) {
      whereParts.push('LOWER(meslek) LIKE ?');
      params.push(`%${profession}%`);
    }
    if (expertise) {
      whereParts.push('LOWER(uzmanlik) LIKE ?');
      params.push(`%${expertise}%`);
    }
    if (title) {
      whereParts.push('LOWER(unvan) LIKE ?');
      params.push(`%${title}%`);
    }
    if (mentorsOnly) {
      whereParts.push('COALESCE(CAST(mentor_opt_in AS INTEGER), 0) = 1');
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

    const totalRow = await sqlGetAsync(`SELECT COUNT(*) AS cnt FROM uyeler WHERE ${where}`, params);
    const total = totalRow ? totalRow.cnt : 0;
    const pages = Math.max(Math.ceil(total / pageSize), 1);
    const safePage = Math.min(page, pages);
    const offset = (safePage - 1) * pageSize;
    const [rows, rangeRows] = await Promise.all([
      sqlAllAsync(
        `SELECT u.id, u.kadi, u.isim, u.soyisim, u.email, u.mailkapali, u.mezuniyetyili, u.dogumgun, u.dogumay, u.dogumyil,
                u.sehir, u.universite, u.meslek, u.websitesi, u.imza, u.resim, u.online, u.sontarih, u.verified,
                u.sirket, u.unvan, u.uzmanlik, u.linkedin_url, u.universite_bolum, u.mentor_opt_in, u.mentor_konulari,
                u.role,
                CASE WHEN EXISTS (
                  SELECT 1
                  FROM teacher_alumni_links tal
                  WHERE tal.teacher_user_id = u.id OR tal.alumni_user_id = u.id
                ) THEN 1 ELSE 0 END AS teacher_network_member
         FROM uyeler u
         LEFT JOIN member_engagement_scores es ON es.user_id = u.id
         WHERE ${where}
         ORDER BY ${orderBy}
         LIMIT ? OFFSET ?`,
        [...params, pageSize, offset]
      ),
      term ? Promise.resolve([]) : getCachedActiveMemberNameRows()
    ]);

    const ranges = [];
    for (let i = 0; i < rangeRows.length; i += pageSize) {
      const start = rangeRows[i]?.isim ? rangeRows[i].isim.slice(0, 2) : '--';
      const end = rangeRows[Math.min(i + pageSize - 1, rangeRows.length - 1)]?.isim?.slice(0, 2) || '--';
      ranges.push({ start, end });
    }

    const rowsWithTrustBadges = rows.map((row) => ({
      ...row,
      trust_badges: buildMemberTrustBadges(row)
    }));

    return res.json({ rows: rowsWithTrustBadges, page: safePage, pages, total, ranges, pageSize, term, filters: { gradYear, verifiedOnly, withPhoto, onlineOnly, relation, sort, mentorsOnly } });
  } catch (err) {
    console.error('members.list failed:', err);
    return res.status(500).send('Beklenmeyen bir hata oluştu.');
  }
});

app.get('/api/members/:id', async (req, res) => {
  try {
    if (!req.session.userId) return res.status(401).send('Login required');
    const row = await sqlGetAsync(
      `SELECT id, kadi, isim, soyisim, email, mailkapali, mezuniyetyili, dogumgun, dogumay, dogumyil,
              sehir, universite, meslek, websitesi, imza, resim, online, sontarih,
              sirket, unvan, uzmanlik, linkedin_url, universite_bolum, mentor_opt_in, mentor_konulari
       FROM uyeler
       WHERE id = ?`,
      [req.params.id]
    );
    if (!row) return res.status(404).send('Üye bulunamadı');
    return res.json({ row });
  } catch (err) {
    console.error('members.detail failed:', err);
    return res.status(500).send('Beklenmeyen bir hata oluştu.');
  }
});

app.get('/api/messages', async (req, res) => {
  try {
    if (!req.session.userId) return res.status(401).send('Login required');
    const box = req.query.box === 'outbox' ? 'outbox' : 'inbox';
    const page = Math.max(parseInt(req.query.page || '1', 10), 1);
    const pageSize = Math.min(Math.max(parseInt(req.query.pageSize || '5', 10), 1), 50);
    const where = box === 'inbox'
      ? 'CAST(kime AS INTEGER) = CAST(? AS INTEGER) AND aktifgelen = 1'
      : 'CAST(kimden AS INTEGER) = CAST(? AS INTEGER) AND aktifgiden = 1';
    const totalRow = await sqlGetAsync(`SELECT COUNT(*) AS cnt FROM gelenkutusu WHERE ${where}`, [req.session.userId]);
    const total = totalRow ? totalRow.cnt : 0;
    const pages = Math.max(Math.ceil(total / pageSize), 1);
    const safePage = Math.min(page, pages);
    const offset = (safePage - 1) * pageSize;

    const rows = await sqlAllAsync(
      `SELECT g.*, u1.kadi AS kimden_kadi, u1.resim AS kimden_resim, u2.kadi AS kime_kadi, u2.resim AS kime_resim
       FROM gelenkutusu g
       LEFT JOIN uyeler u1 ON u1.id = g.kimden
       LEFT JOIN uyeler u2 ON u2.id = g.kime
       WHERE ${where}
       ORDER BY g.tarih DESC
       LIMIT ? OFFSET ?`,
      [req.session.userId, pageSize, offset]
    );

    return res.json({ rows, page: safePage, pages, total, box, pageSize });
  } catch (err) {
    console.error('messages.list failed:', err);
    return res.status(500).send('Beklenmeyen bir hata oluştu.');
  }
});

app.get('/api/messages/recipients', async (req, res) => {
  try {
    if (!req.session.userId) return res.status(401).send('Login required');
    const q = String(req.query.q || '').trim().replace(/^@+/, '').replace(/'/g, '');
    const limit = Math.min(Math.max(parseInt(req.query.limit || '12', 10), 1), 50);
    if (!q) return res.json({ items: [] });
    const term = `%${q}%`;
    const rows = await sqlAllAsync(
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
    return res.json({ items: rows });
  } catch (err) {
    console.error('messages.recipients failed:', err);
    return res.status(500).send('Beklenmeyen bir hata oluştu.');
  }
});

app.get('/api/messages/:id', async (req, res) => {
  try {
    if (!req.session.userId) return res.status(401).send('Login required');
    const row = await sqlGetAsync('SELECT * FROM gelenkutusu WHERE id = ?', [req.params.id]);
    if (!row) return res.status(404).send('Mesaj bulunamadı');
    if (!sameUserId(row.kime, req.session.userId) && !sameUserId(row.kimden, req.session.userId)) {
      return res.status(403).send('Yetkisiz');
    }
    const [sender, receiver] = await Promise.all([
      sqlGetAsync('SELECT id, kadi, resim FROM uyeler WHERE id = ?', [normalizeUserId(row.kimden)]),
      sqlGetAsync('SELECT id, kadi, resim FROM uyeler WHERE id = ?', [normalizeUserId(row.kime)])
    ]);

    if (sameUserId(row.kime, req.session.userId) && Number(row.yeni || 0) === 1) {
      await sqlRunAsync('UPDATE gelenkutusu SET yeni = 0 WHERE id = ?', [row.id]);
    }

    return res.json({ row, sender, receiver });
  } catch (err) {
    console.error('messages.detail failed:', err);
    return res.status(500).send('Beklenmeyen bir hata oluştu.');
  }
});

app.post('/api/messages', async (req, res) => {
  try {
    if (!req.session.userId) return res.status(401).send('Login required');
    const { kime, konu, mesaj } = req.body || {};
    const recipientId = toNumericUserIdOrNull(kime);
    if (!recipientId) return res.status(400).send('Alıcı seçilmedi');
    const subject = (konu && String(konu).trim())
      ? sanitizePlainUserText(String(konu).trim(), 50)
      : 'Konusuz';
    const body = (mesaj && String(mesaj).trim()) ? formatUserText(String(mesaj)) : 'Sistem Bilgisi : [b]Boş Mesaj Gönderildi![/b]';
    const now = new Date().toISOString();

    const result = await sqlRunAsync(
      `INSERT INTO gelenkutusu (kime, kimden, aktifgelen, konu, mesaj, yeni, tarih, aktifgiden)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        recipientId,
        req.session.userId,
        toDbFlagForColumn('gelenkutusu', 'aktifgelen', true),
        subject,
        body,
        toDbFlagForColumn('gelenkutusu', 'yeni', true),
        now,
        toDbFlagForColumn('gelenkutusu', 'aktifgiden', true)
      ]
    );
    notifyMentions({
      text: req.body?.mesaj || '',
      sourceUserId: req.session.userId,
      entityId: result?.lastInsertRowid,
      type: 'mention_message',
      message: 'Mesajda senden bahsetti.',
      allowedUserIds: [recipientId]
    });

    return res.status(201).json({ ok: true });
  } catch (err) {
    writeAppLog('error', 'messages_create_failed', {
      userId: req.session?.userId || null,
      message: err?.message || 'unknown_error',
      stack: String(err?.stack || '').slice(0, 1000)
    });
    return res.status(500).send('Mesaj gönderilirken bir hata oluştu.');
  }
});

app.delete('/api/messages/:id', async (req, res) => {
  try {
    if (!req.session.userId) return res.status(401).send('Login required');
    const row = await sqlGetAsync('SELECT * FROM gelenkutusu WHERE id = ?', [req.params.id]);
    if (!row) return res.status(404).send('Mesaj bulunamadı');
    if (!sameUserId(row.kime, req.session.userId) && !sameUserId(row.kimden, req.session.userId)) {
      return res.status(403).send('Yetkisiz');
    }
    if (sameUserId(row.kime, req.session.userId)) {
      await sqlRunAsync('UPDATE gelenkutusu SET aktifgelen = ? WHERE id = ?', [toDbFlagForColumn('gelenkutusu', 'aktifgelen', false), row.id]);
    }
    if (sameUserId(row.kimden, req.session.userId)) {
      await sqlRunAsync('UPDATE gelenkutusu SET aktifgiden = ? WHERE id = ?', [toDbFlagForColumn('gelenkutusu', 'aktifgiden', false), row.id]);
    }
    return res.status(204).send();
  } catch (err) {
    writeAppLog('error', 'messages_delete_failed', {
      userId: req.session?.userId || null,
      messageId: req.params?.id || null,
      message: err?.message || 'unknown_error',
      stack: String(err?.stack || '').slice(0, 1000)
    });
    return res.status(500).send('Mesaj silinirken bir hata oluştu.');
  }
});

app.get('/api/sdal-messenger/contacts', requireAuth, (req, res) => {
  const q = String(req.query.q || '').trim().replace(/^@+/, '').replace(/'/g, '');
  const limit = Math.min(Math.max(parseInt(req.query.limit || '20', 10), 1), 80);
  if (!q) return res.json({ items: [] });
  const term = `%${q}%`;
  const rows = sqlAll(
    `SELECT id, kadi, isim, soyisim, resim, verified
     FROM uyeler
     WHERE CAST(id AS INTEGER) <> CAST(? AS INTEGER)
       AND COALESCE(CAST(yasak AS INTEGER), 0) = 0
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
    [req.session.userId, term, term, term, term, limit]
  );
  res.json({ items: rows });
});

app.post('/api/sdal-messenger/threads', requireAuth, (req, res) => {
  const peerId = normalizeUserId(req.body?.userId);
  if (!peerId) return res.status(400).send('Kullanıcı seçilmedi.');
  if (sameUserId(peerId, req.session.userId)) return res.status(400).send('Kendinle mesajlaşamazsın.');
  const peer = sqlGet('SELECT id, kadi, isim, soyisim, resim, verified FROM uyeler WHERE id = ?', [peerId]);
  if (!peer) return res.status(404).send('Kullanıcı bulunamadı.');
  const thread = ensureMessengerThread(req.session.userId, peerId);
  if (!thread) return res.status(500).send('Sohbet oluşturulamadı.');
  res.status(201).json({ ok: true, threadId: thread.id });
});

app.get('/api/sdal-messenger/threads', requireAuth, (req, res) => {
  const limit = Math.min(Math.max(parseInt(req.query.limit || '40', 10), 1), 100);
  const offset = Math.max(parseInt(req.query.offset || '0', 10), 0);
  const q = String(req.query.q || '').trim();
  const term = q ? `%${q.toLowerCase()}%` : null;
  const userId = req.session.userId;
  const deliveredNow = new Date().toISOString();
  sqlRun(
    `UPDATE sdal_messenger_messages
     SET delivered_at = COALESCE(delivered_at, ?)
     WHERE CAST(receiver_id AS INTEGER) = CAST(? AS INTEGER)
       AND delivered_at IS NULL
       AND COALESCE(CAST(deleted_by_receiver AS INTEGER), 0) = 0`,
    [deliveredNow, userId]
  );

  const filterParams = [];
  let filterSql = '';
  if (term) {
    filterSql = `
      AND (
        LOWER(COALESCE(u.kadi, '')) LIKE ?
        OR LOWER(COALESCE(u.isim, '')) LIKE ?
        OR LOWER(COALESCE(u.soyisim, '')) LIKE ?
      )
    `;
    filterParams.push(term, term, term);
  }
  const queryParams = [
    userId, // unread_count
    userId, // peer selector
    userId, // last message visible if sender
    userId, // last message visible if receiver
    userId, // thread user_a check
    userId, // thread user_b check
    ...filterParams,
    limit,
    offset
  ];

  const rows = sqlAll(
    `SELECT
       t.id,
       t.user_a_id,
       t.user_b_id,
       t.last_message_at,
       t.updated_at,
       u.id AS peer_id,
       u.kadi AS peer_kadi,
       u.isim AS peer_isim,
       u.soyisim AS peer_soyisim,
       u.resim AS peer_resim,
       u.verified AS peer_verified,
       lm.id AS last_message_id,
       lm.body AS last_message_body,
       lm.created_at AS last_message_created_at,
       lm.sender_id AS last_message_sender_id,
       lm.client_written_at AS last_message_client_written_at,
       lm.server_received_at AS last_message_server_received_at,
       lm.delivered_at AS last_message_delivered_at,
       lm.read_at AS last_message_read_at,
       (
         SELECT COUNT(*)
         FROM sdal_messenger_messages um
         WHERE um.thread_id = t.id
           AND CAST(um.receiver_id AS INTEGER) = CAST(? AS INTEGER)
           AND um.read_at IS NULL
           AND COALESCE(CAST(um.deleted_by_receiver AS INTEGER), 0) = 0
       ) AS unread_count
     FROM sdal_messenger_threads t
     LEFT JOIN uyeler u
       ON CAST(u.id AS INTEGER) = CASE
         WHEN CAST(t.user_a_id AS INTEGER) = CAST(? AS INTEGER) THEN CAST(t.user_b_id AS INTEGER)
         ELSE CAST(t.user_a_id AS INTEGER)
       END
     LEFT JOIN sdal_messenger_messages lm
       ON CAST(lm.id AS INTEGER) = (
         SELECT CAST(mm.id AS INTEGER)
         FROM sdal_messenger_messages mm
         WHERE CAST(mm.thread_id AS INTEGER) = CAST(t.id AS INTEGER)
           AND (
             (CAST(mm.sender_id AS INTEGER) = CAST(? AS INTEGER) AND COALESCE(CAST(mm.deleted_by_sender AS INTEGER), 0) = 0)
             OR
             (CAST(mm.receiver_id AS INTEGER) = CAST(? AS INTEGER) AND COALESCE(CAST(mm.deleted_by_receiver AS INTEGER), 0) = 0)
           )
         ORDER BY mm.created_at DESC, CAST(mm.id AS INTEGER) DESC
         LIMIT 1
       )
     WHERE (
       CAST(t.user_a_id AS INTEGER) = CAST(? AS INTEGER)
       OR CAST(t.user_b_id AS INTEGER) = CAST(? AS INTEGER)
     )
     ${filterSql}
     ORDER BY COALESCE(lm.created_at, t.last_message_at, t.updated_at, t.created_at) DESC
     LIMIT ? OFFSET ?`,
    queryParams
  );

  const items = rows.map((row) => ({
    id: row.id,
    peer: {
      id: row.peer_id,
      kadi: row.peer_kadi,
      isim: row.peer_isim,
      soyisim: row.peer_soyisim,
      resim: row.peer_resim,
      verified: Number(row.peer_verified || 0) === 1
    },
    lastMessage: row.last_message_id ? {
      id: row.last_message_id,
      body: row.last_message_body,
      createdAt: row.last_message_created_at,
      senderId: row.last_message_sender_id,
      clientWrittenAt: row.last_message_client_written_at,
      serverReceivedAt: row.last_message_server_received_at,
      deliveredAt: row.last_message_delivered_at,
      readAt: row.last_message_read_at
    } : null,
    unreadCount: Number(row.unread_count || 0)
  }));

  res.json({ items, limit, offset, hasMore: items.length === limit });
});

app.get('/api/sdal-messenger/threads/:id/messages', requireAuth, (req, res) => {
  const thread = getMessengerThreadForUser(req.params.id, req.session.userId);
  if (!thread) return res.status(404).send('Sohbet bulunamadı.');
  const delivered = markMessengerMessagesDelivered(thread.id, req.session.userId);
  if (delivered.changed > 0) {
    broadcastMessengerEvent([thread.user_a_id, thread.user_b_id], {
      type: 'messenger:delivered',
      threadId: Number(thread.id),
      byUserId: Number(req.session.userId),
      deliveredAt: delivered.deliveredAt
    });
  }
  const limit = Math.min(Math.max(parseInt(req.query.limit || '60', 10), 1), 120);
  const beforeId = parseInt(req.query.beforeId || '0', 10) || 0;
  const params = [thread.id, req.session.userId, req.session.userId];
  let beforeSql = '';
  if (beforeId > 0) {
    beforeSql = 'AND CAST(m.id AS INTEGER) < CAST(? AS INTEGER)';
    params.push(beforeId);
  }
  params.push(limit);

  const items = sqlAll(
    `SELECT
       m.id,
       m.thread_id AS threadId,
       m.sender_id AS senderId,
       m.receiver_id AS receiverId,
       CASE WHEN CAST(m.sender_id AS INTEGER) = CAST(? AS INTEGER) THEN 1 ELSE 0 END AS isMine,
       m.body,
       COALESCE(m.client_written_at, m.created_at) AS clientWrittenAt,
       COALESCE(m.server_received_at, m.created_at) AS serverReceivedAt,
       m.delivered_at AS deliveredAt,
       m.created_at AS createdAt,
       m.read_at AS readAt,
       u.kadi, u.isim, u.soyisim, u.resim, u.verified
     FROM sdal_messenger_messages m
     LEFT JOIN uyeler u ON CAST(u.id AS INTEGER) = CAST(m.sender_id AS INTEGER)
     WHERE CAST(m.thread_id AS INTEGER) = CAST(? AS INTEGER)
       AND (
         (CAST(m.sender_id AS INTEGER) = CAST(? AS INTEGER) AND COALESCE(CAST(m.deleted_by_sender AS INTEGER), 0) = 0)
         OR
         (CAST(m.receiver_id AS INTEGER) = CAST(? AS INTEGER) AND COALESCE(CAST(m.deleted_by_receiver AS INTEGER), 0) = 0)
       )
       ${beforeSql}
     ORDER BY m.created_at DESC, CAST(m.id AS INTEGER) DESC
     LIMIT ?`,
    [req.session.userId, ...params]
  ).reverse();

  res.json({ items });
});

app.post('/api/sdal-messenger/threads/:id/messages', requireAuth, messengerSendIdempotency, (req, res) => {
  const thread = getMessengerThreadForUser(req.params.id, req.session.userId);
  if (!thread) return res.status(404).send('Sohbet bulunamadı.');
  const text = sanitizePlainUserText(String(req.body?.text || '').trim(), 4000);
  if (!text) return res.status(400).send('Mesaj boş olamaz.');
  const clientWrittenAtRaw = String(req.body?.clientWrittenAt || '').trim();
  const clientWrittenAt = clientWrittenAtRaw || null;
  const receiverId = sameUserId(thread.user_a_id, req.session.userId) ? thread.user_b_id : thread.user_a_id;
  const now = new Date().toISOString();
  const result = sqlRun(
    `INSERT INTO sdal_messenger_messages
      (thread_id, sender_id, receiver_id, body, client_written_at, server_received_at, delivered_at, created_at, read_at, deleted_by_sender, deleted_by_receiver)
     VALUES (?, ?, ?, ?, ?, ?, NULL, ?, NULL, 0, 0)`,
    [thread.id, req.session.userId, receiverId, text, clientWrittenAt, now, now]
  );
  sqlRun(
    'UPDATE sdal_messenger_threads SET updated_at = ?, last_message_at = ? WHERE id = ?',
    [now, now, thread.id]
  );
  const id = result?.lastInsertRowid;
  const item = sqlGet(
    `SELECT
       m.id,
       m.thread_id AS threadId,
       m.sender_id AS senderId,
       m.receiver_id AS receiverId,
       CASE WHEN CAST(m.sender_id AS INTEGER) = CAST(? AS INTEGER) THEN 1 ELSE 0 END AS isMine,
       m.body,
       COALESCE(m.client_written_at, m.created_at) AS clientWrittenAt,
       COALESCE(m.server_received_at, m.created_at) AS serverReceivedAt,
       m.delivered_at AS deliveredAt,
       m.created_at AS createdAt,
       m.read_at AS readAt,
       u.kadi, u.isim, u.soyisim, u.resim, u.verified
     FROM sdal_messenger_messages m
     LEFT JOIN uyeler u ON CAST(u.id AS INTEGER) = CAST(m.sender_id AS INTEGER)
     WHERE m.id = ?`,
    [req.session.userId, id]
  );
  if (item) {
    broadcastMessengerEvent([thread.user_a_id, thread.user_b_id], {
      type: 'messenger:new',
      threadId: Number(thread.id),
      item
    });
  }
  res.status(201).json({ ok: true, item });
});

app.post('/api/sdal-messenger/threads/:id/read', requireAuth, (req, res) => {
  const thread = getMessengerThreadForUser(req.params.id, req.session.userId);
  if (!thread) return res.status(404).send('Sohbet bulunamadı.');
  const now = new Date().toISOString();
  const result = sqlRun(
    `UPDATE sdal_messenger_messages
     SET read_at = ?,
         delivered_at = COALESCE(delivered_at, ?)
     WHERE CAST(thread_id AS INTEGER) = CAST(? AS INTEGER)
       AND CAST(receiver_id AS INTEGER) = CAST(? AS INTEGER)
       AND read_at IS NULL
       AND COALESCE(CAST(deleted_by_receiver AS INTEGER), 0) = 0`,
    [now, now, thread.id, req.session.userId]
  );
  if (Number(result?.changes || 0) > 0) {
    broadcastMessengerEvent([thread.user_a_id, thread.user_b_id], {
      type: 'messenger:read',
      threadId: Number(thread.id),
      byUserId: Number(req.session.userId),
      readAt: now
    });
  }
  res.json({ ok: true });
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
  const baslik = sanitizePlainUserText(String(req.body?.baslik || '').trim(), 255);
  const aciklama = formatUserText(req.body?.aciklama || '');

  if (!baslik) return res.status(400).send('Yüklemek üzere olduğun fotoğraf için bir başlık girmen gerekiyor.');
  if (!kat) return res.status(400).send('Kategori seçmelisin.');
  const category = sqlGet('SELECT * FROM album_kat WHERE id = ? AND aktif = 1', [kat]);
  if (!category) return res.status(400).send('Seçtiğin kategori bulunamadı.');
  if (!req.file?.filename) return res.status(400).send('Geçerli bir resim dosyası girmedin.');

  const processed = await processDiskImageUpload({
    req,
    res,
    file: req.file,
    bucket: 'album_photo',
    preset: uploadImagePresets.albumPhoto
  });
  if (!processed.ok) return res.status(processed.statusCode).send(processed.message);

  const storedFilename = path.basename(processed.path || req.file.path);

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
  const yorum = formatUserText(yorumRaw);
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
app.get('/api/new/feed', requireAuth, phase1Domain.controllers.feed.getFeed);

app.post('/api/new/posts', requireAuth, createPostIdempotency, postWriteRateLimit, phase1Domain.controllers.posts.createPost);

app.post('/api/new/posts/upload', requireAuth, uploadRateLimit, postUpload.single('image'), async (req, res) => {
  const content = formatUserText(req.body?.content || '');
  const filter = req.body?.filter || '';
  const groupId = req.body?.group_id || null;
  let processedUpload = null;
  if (req.file?.path) {
    processedUpload = await processDiskImageUpload({
      req,
      res,
      file: req.file,
      bucket: groupId ? 'group_post_image' : 'post_image',
      preset: uploadImagePresets.postImage,
      filter
    });
    if (!processedUpload.ok) return res.status(processedUpload.statusCode).send(processedUpload.message);
  }
  const image = processedUpload?.url || null;
  if (isFormattedContentEmpty(content) && !image) return res.status(400).send('İçerik boş olamaz.');
  const now = new Date().toISOString();

  // Also generate variants via new pipeline (if file buffer or file exists)
  let imageRecordId = null;
  let variants = null;
  try {
    const fileBuffer = processedUpload?.path && fs.existsSync(processedUpload.path)
      ? fs.readFileSync(processedUpload.path)
      : null;
    if (fileBuffer) {
      const uploadResult = await processUpload({
        buffer: fileBuffer,
        mimeType: processedUpload?.mime || req.file?.mimetype || 'image/jpeg',
        userId: req.session.userId,
        entityType: 'post',
        entityId: '0', // will be updated after insert
        sqlGet,
        sqlRun,
        uploadsDir,
        writeAppLog
      });
      imageRecordId = uploadResult.imageId;
      variants = uploadResult.variants;
    }
  } catch (err) {
    writeAppLog('error', 'post_variant_generation_failed', { message: err?.message });
    // Non-fatal: the legacy single image is still saved
  }

  const result = sqlRun('INSERT INTO posts (user_id, content, image, image_record_id, created_at, group_id) VALUES (?, ?, ?, ?, ?, ?)', [
    req.session.userId,
    content,
    image,
    imageRecordId,
    now,
    groupId
  ]);

  // Update the image record with the actual post ID
  const postId = result?.lastInsertRowid;
  if (imageRecordId && postId) {
    try {
      sqlRun('UPDATE image_records SET entity_id = ? WHERE id = ?', [postId, imageRecordId]);
    } catch { /* best effort */ }
  }

  notifyMentions({
    text: req.body?.content || '',
    sourceUserId: req.session.userId,
    entityId: postId,
    type: 'mention_post',
    message: 'Gönderide senden bahsetti.'
  });
  scheduleEngagementRecalculation('post_created');
  invalidateCacheNamespace(cacheNamespaces.feed);
  res.json({ ok: true, id: postId, image, variants });
});


function canManagePost(req, postRow) {
  if (!postRow) return false;
  if (sameUserId(postRow.user_id, req.session.userId)) return true;
  const currentUser = getCurrentUser(req);
  if (hasAdminSession(req, currentUser)) return true;
  if (getUserRole(currentUser) !== 'mod') return false;
  const groupId = Number(postRow.group_id || 0);
  if (!groupId) return false;
  const groupRow = sqlGet('SELECT id, name FROM groups WHERE id = ?', [groupId]);
  const groupName = String(groupRow?.name || '');
  const match = groupName.match(/^(\d{4})\s+Mezunları$/);
  if (!match) return false;
  const year = parseInt(match[1], 10);
  if (!Number.isFinite(year)) return false;
  const scope = sqlGet('SELECT id FROM moderator_scopes WHERE user_id = ? AND scope_type = ? AND scope_value = ?', [currentUser.id, 'graduation_year', String(year)]);
  return !!scope;
}

function deletePostById(postId) {
  // Clean up image variants if present
  const post = sqlGet('SELECT image_record_id FROM posts WHERE id = ?', [postId]);
  if (post?.image_record_id) {
    deleteImageRecord(post.image_record_id, sqlGet, sqlRun, uploadsDir, writeAppLog).catch(() => {});
  }
  sqlRun('DELETE FROM post_likes WHERE post_id = ?', [postId]);
  sqlRun('DELETE FROM post_comments WHERE post_id = ?', [postId]);
  sqlRun('DELETE FROM notifications WHERE type IN (?, ?) AND entity_id = ?', ['like', 'comment', postId]);
  sqlRun('DELETE FROM posts WHERE id = ?', [postId]);
}

app.patch('/api/new/posts/:id', requireAuth, (req, res) => {
  const postId = Number(req.params.id || 0);
  if (!postId) return res.status(400).send('Geçersiz gönderi ID.');
  const postRow = sqlGet('SELECT id, user_id, image, group_id FROM posts WHERE id = ?', [postId]);
  if (!postRow) return res.status(404).send('Gönderi bulunamadı.');
  if (!canManagePost(req, postRow)) return res.status(403).send('Bu gönderiyi düzenleme yetkin yok.');
  const content = formatUserText(req.body?.content || '');
  if (isFormattedContentEmpty(content) && !postRow.image) return res.status(400).send('İçerik boş olamaz.');
  sqlRun('UPDATE posts SET content = ? WHERE id = ?', [content, postId]);
  scheduleEngagementRecalculation('post_updated');
  invalidateCacheNamespace(cacheNamespaces.feed);
  const item = sqlGet(
    `SELECT p.id, p.user_id, p.content, p.image, p.created_at,
            u.kadi, u.isim, u.soyisim, u.resim, u.verified
     FROM posts p
     LEFT JOIN uyeler u ON u.id = p.user_id
     WHERE p.id = ?`,
    [postId]
  );
  res.json({
    ok: true,
    item: item ? {
      id: item.id,
      content: item.content,
      image: item.image,
      createdAt: item.created_at,
      author: {
        id: item.user_id,
        kadi: item.kadi,
        isim: item.isim,
        soyisim: item.soyisim,
        resim: item.resim,
        verified: item.verified
      }
    } : null
  });
});

app.post('/api/new/posts/:id/edit', requireAuth, (req, res) => {
  const postId = Number(req.params.id || 0);
  if (!postId) return res.status(400).send('Geçersiz gönderi ID.');
  const postRow = sqlGet('SELECT id, user_id, image, group_id FROM posts WHERE id = ?', [postId]);
  if (!postRow) return res.status(404).send('Gönderi bulunamadı.');
  if (!canManagePost(req, postRow)) return res.status(403).send('Bu gönderiyi düzenleme yetkin yok.');
  const content = formatUserText(req.body?.content || '');
  if (isFormattedContentEmpty(content) && !postRow.image) return res.status(400).send('İçerik boş olamaz.');
  sqlRun('UPDATE posts SET content = ? WHERE id = ?', [content, postId]);
  scheduleEngagementRecalculation('post_updated');
  invalidateCacheNamespace(cacheNamespaces.feed);
  const item = sqlGet(
    `SELECT p.id, p.user_id, p.content, p.image, p.created_at,
            u.kadi, u.isim, u.soyisim, u.resim, u.verified
     FROM posts p
     LEFT JOIN uyeler u ON u.id = p.user_id
     WHERE p.id = ?`,
    [postId]
  );
  res.json({
    ok: true,
    item: item ? {
      id: item.id,
      content: item.content,
      image: item.image,
      createdAt: item.created_at,
      author: {
        id: item.user_id,
        kadi: item.kadi,
        isim: item.isim,
        soyisim: item.soyisim,
        resim: item.resim,
        verified: item.verified
      }
    } : null
  });
});

app.delete('/api/new/posts/:id', requireAuth, (req, res) => {
  const postId = Number(req.params.id || 0);
  if (!postId) return res.status(400).send('Geçersiz gönderi ID.');
  const postRow = sqlGet('SELECT id, user_id, group_id FROM posts WHERE id = ?', [postId]);
  if (!postRow) return res.status(404).send('Gönderi bulunamadı.');
  if (!canManagePost(req, postRow)) return res.status(403).send('Bu gönderiyi silme yetkin yok.');
  deletePostById(postId);
  scheduleEngagementRecalculation('post_deleted');
  invalidateCacheNamespace(cacheNamespaces.feed);
  res.json({ ok: true });
});

app.post('/api/new/posts/:id/delete', requireAuth, (req, res) => {
  const postId = Number(req.params.id || 0);
  if (!postId) return res.status(400).send('Geçersiz gönderi ID.');
  const postRow = sqlGet('SELECT id, user_id, group_id FROM posts WHERE id = ?', [postId]);
  if (!postRow) return res.status(404).send('Gönderi bulunamadı.');
  if (!canManagePost(req, postRow)) return res.status(403).send('Bu gönderiyi silme yetkin yok.');
  deletePostById(postId);
  scheduleEngagementRecalculation('post_deleted');
  invalidateCacheNamespace(cacheNamespaces.feed);
  res.json({ ok: true });
});

app.post('/api/new/posts/:id/like', requireAuth, phase1Domain.controllers.posts.toggleLike);

app.get('/api/new/posts/:id/comments', requireAuth, phase1Domain.controllers.posts.listComments);

app.post('/api/new/posts/:id/comments', requireAuth, commentWriteRateLimit, phase1Domain.controllers.posts.createComment);

app.get('/api/new/notifications', requireAuth, async (req, res) => {
  try {
    ensureNotificationIndexes();
    const limit = Math.min(Math.max(parseInt(req.query.limit || '20', 10), 1), 100);
    const sort = normalizeNotificationSortMode(req.query.sort || 'priority');
    const cursor = parseNotificationCursor(req.query.cursor || '', sort);

    const whereParts = ['n.user_id = ?'];
    const params = [req.session.userId];
    if (cursor?.id > 0 && sort === 'priority' && Number.isFinite(cursor.bucket)) {
      const bucketSql = buildNotificationSortBucketSql('n');
      whereParts.push(`(${bucketSql} > ? OR (${bucketSql} = ? AND n.id < ?))`);
      params.push(cursor.bucket, cursor.bucket, cursor.id);
    } else if (cursor?.id > 0) {
      whereParts.push('n.id < ?');
      params.push(cursor.id);
    }

    const rows = await sqlAllAsync(
      `SELECT n.id, n.type, n.entity_id, n.source_user_id, n.message, n.read_at, n.created_at,
              u.kadi, u.isim, u.soyisim, u.resim, u.verified
       FROM notifications n
       LEFT JOIN uyeler u ON u.id = n.source_user_id
       WHERE ${whereParts.join(' AND ')}
       ${buildNotificationOrderSql(sort)}
       LIMIT ?`,
      [...params, limit + 1]
    );
    const slice = rows.slice(0, limit);
    const items = await enrichNotificationRows(slice, req.session.userId);
    const nextCursor = rows.length > limit ? buildNotificationCursor(slice[slice.length - 1], sort) : null;
    res.json(apiSuccessEnvelope(
      'NOTIFICATIONS_LIST_OK',
      'Bildirimler listelendi.',
      { items, hasMore: rows.length > limit, next_cursor: nextCursor },
      { items, hasMore: rows.length > limit, next_cursor: nextCursor }
    ));
  } catch (err) {
    console.error('notifications.list failed:', err);
    res.status(500).send('Beklenmeyen bir hata oluştu.');
  }
});

app.get('/api/new/notifications/unread', requireAuth, async (req, res) => {
  try {
    ensureNotificationIndexes();
    const row = await sqlGetAsync('SELECT COUNT(*) AS cnt FROM notifications WHERE user_id = ? AND read_at IS NULL', [req.session.userId]);
    res.json({ count: Number(row?.cnt || 0) });
  } catch (err) {
    console.error('notifications.unread failed:', err);
    res.status(500).send('Beklenmeyen bir hata oluştu.');
  }
});

app.post('/api/new/notifications/read', requireAuth, async (req, res) => {
  try {
    await sqlRunAsync('UPDATE notifications SET read_at = ? WHERE user_id = ? AND read_at IS NULL', [
      new Date().toISOString(),
      req.session.userId
    ]);
    res.json({ ok: true });
  } catch (err) {
    console.error('notifications.read failed:', err);
    res.status(500).send('Beklenmeyen bir hata oluştu.');
  }
});

app.post('/api/new/notifications/bulk-read', requireAuth, async (req, res) => {
  try {
    const ids = Array.isArray(req.body?.ids)
      ? Array.from(new Set(req.body.ids.map((value) => Number(value)).filter((value) => Number.isFinite(value) && value > 0)))
      : [];
    const now = new Date().toISOString();
    let result = null;
    if (ids.length > 0) {
      result = await sqlRunAsync(
        `UPDATE notifications
         SET read_at = COALESCE(read_at, ?)
         WHERE user_id = ?
           AND id IN (${ids.map(() => '?').join(',')})`,
        [now, req.session.userId, ...ids]
      );
    } else {
      result = await sqlRunAsync(
        'UPDATE notifications SET read_at = COALESCE(read_at, ?) WHERE user_id = ? AND read_at IS NULL',
        [now, req.session.userId]
      );
    }
    return res.json(apiSuccessEnvelope(
      'NOTIFICATIONS_BULK_READ_OK',
      'Bildirimler okundu olarak işaretlendi.',
      { updated: Number(result?.changes || 0) },
      { updated: Number(result?.changes || 0) }
    ));
  } catch (err) {
    console.error('notifications.bulkRead failed:', err);
    return sendApiError(res, 500, 'NOTIFICATIONS_BULK_READ_FAILED', 'Beklenmeyen bir hata oluştu.');
  }
});

app.post('/api/new/notifications/:id/read', requireAuth, async (req, res) => {
  try {
    const notificationId = Number(req.params.id || 0);
    if (!notificationId) return sendApiError(res, 400, 'INVALID_NOTIFICATION_ID', 'Geçersiz bildirim kimliği.');
    const row = await sqlGetAsync(
      `SELECT n.id, n.user_id, n.type, n.entity_id, n.source_user_id, n.message, n.read_at, n.created_at,
              u.kadi, u.isim, u.soyisim, u.resim, u.verified
       FROM notifications n
       LEFT JOIN uyeler u ON u.id = n.source_user_id
       WHERE n.id = ? AND n.user_id = ?`,
      [notificationId, req.session.userId]
    );
    if (!row) return sendApiError(res, 404, 'NOTIFICATION_NOT_FOUND', 'Bildirim bulunamadı.');
    const now = new Date().toISOString();
    if (!row.read_at) {
      await sqlRunAsync('UPDATE notifications SET read_at = ? WHERE id = ? AND user_id = ?', [now, notificationId, req.session.userId]);
    }
    const [item] = await enrichNotificationRows([{ ...row, read_at: row.read_at || now }], req.session.userId);
    return res.json(apiSuccessEnvelope(
      'NOTIFICATION_MARKED_READ',
      'Bildirim okundu olarak işaretlendi.',
      { item },
      { item }
    ));
  } catch (err) {
    console.error('notifications.readOne failed:', err);
    return sendApiError(res, 500, 'NOTIFICATION_MARK_READ_FAILED', 'Beklenmeyen bir hata oluştu.');
  }
});

app.post('/api/new/notifications/:id/open', requireAuth, async (req, res) => {
  try {
    const notificationId = Number(req.params.id || 0);
    if (!notificationId) return sendApiError(res, 400, 'INVALID_NOTIFICATION_ID', 'Geçersiz bildirim kimliği.');
    const row = await sqlGetAsync(
      `SELECT n.id, n.user_id, n.type, n.entity_id, n.source_user_id, n.message, n.read_at, n.created_at,
              u.kadi, u.isim, u.soyisim, u.resim, u.verified
       FROM notifications n
       LEFT JOIN uyeler u ON u.id = n.source_user_id
       WHERE n.id = ? AND n.user_id = ?`,
      [notificationId, req.session.userId]
    );
    if (!row) return sendApiError(res, 404, 'NOTIFICATION_NOT_FOUND', 'Bildirim bulunamadı.');
    const now = new Date().toISOString();
    if (!row.read_at) {
      await sqlRunAsync('UPDATE notifications SET read_at = ? WHERE id = ? AND user_id = ?', [now, notificationId, req.session.userId]);
    }
    const [item] = await enrichNotificationRows([{ ...row, read_at: row.read_at || now }], req.session.userId);
    return res.json(apiSuccessEnvelope(
      'NOTIFICATION_OPENED',
      'Bildirim açıldı.',
      { item, target: item?.target || null },
      { item, target: item?.target || null }
    ));
  } catch (err) {
    console.error('notifications.open failed:', err);
    return sendApiError(res, 500, 'NOTIFICATION_OPEN_FAILED', 'Beklenmeyen bir hata oluştu.');
  }
});

app.post('/api/new/notifications/telemetry', requireAuth, async (req, res) => {
  try {
    const rawEvents = Array.isArray(req.body?.events) ? req.body.events : [req.body];
    const accepted = [];
    for (const rawEvent of rawEvents) {
      const notificationId = Number(rawEvent?.notification_id || 0);
      const eventName = normalizeNotificationTelemetryEventName(rawEvent?.event_name);
      if (!eventName) continue;
      let notificationType = sanitizePlainUserText(String(rawEvent?.notification_type || '').trim().toLowerCase(), 120);
      if (notificationId > 0) {
        const notificationRow = await sqlGetAsync(
          'SELECT id, type FROM notifications WHERE id = ? AND user_id = ?',
          [notificationId, req.session.userId]
        );
        if (!notificationRow) continue;
        if (!notificationType) notificationType = String(notificationRow.type || '').trim().toLowerCase();
      }
      const didRecord = recordNotificationTelemetryEvent({
        userId: req.session.userId,
        notificationId: notificationId || null,
        eventName,
        notificationType,
        surface: rawEvent?.surface,
        actionKind: rawEvent?.action_kind
      });
      if (didRecord) accepted.push({
        notification_id: notificationId || null,
        event_name: eventName
      });
    }
    return res.json(apiSuccessEnvelope(
      'NOTIFICATION_TELEMETRY_RECORDED',
      'Notification telemetry kaydedildi.',
      { accepted_count: accepted.length, items: accepted },
      { accepted_count: accepted.length, items: accepted }
    ));
  } catch (err) {
    console.error('notifications.telemetry failed:', err);
    return sendApiError(res, 500, 'NOTIFICATION_TELEMETRY_FAILED', 'Beklenmeyen bir hata oluştu.');
  }
});

app.get('/api/new/notifications/preferences', requireAuth, (req, res) => {
  try {
    const row = readNotificationPreferenceRow(req.session.userId);
    const preferences = mapNotificationPreferenceResponse(row);
    return res.json(apiSuccessEnvelope(
      'NOTIFICATION_PREFERENCES_OK',
      'Bildirim tercihleri hazır.',
      {
        preferences,
        experiments: {
          assignments: getNotificationExperimentAssignments(req.session.userId),
          configs: readNotificationExperimentConfigs()
        }
      },
      {
        preferences,
        experiments: {
          assignments: getNotificationExperimentAssignments(req.session.userId),
          configs: readNotificationExperimentConfigs()
        }
      }
    ));
  } catch (err) {
    console.error('notifications.preferences.get failed:', err);
    return sendApiError(res, 500, 'NOTIFICATION_PREFERENCES_GET_FAILED', 'Beklenmeyen bir hata oluştu.');
  }
});

app.put('/api/new/notifications/preferences', requireAuth, (req, res) => {
  try {
    ensureNotificationPreferencesTable();
    const userId = Number(req.session?.userId || 0);
    const current = readNotificationPreferenceRow(userId);
    const patch = req.body?.categories && typeof req.body.categories === 'object' ? req.body.categories : {};
    const quietMode = req.body?.quiet_mode && typeof req.body.quiet_mode === 'object' ? req.body.quiet_mode : {};
    const nextRow = {
      ...current,
      updated_at: new Date().toISOString()
    };
    for (const key of NOTIFICATION_PREFERENCE_CATEGORY_KEYS) {
      if (Object.prototype.hasOwnProperty.call(patch, key)) {
        nextRow[`${key}_enabled`] = patch[key] ? 1 : 0;
      }
    }
    if (Object.prototype.hasOwnProperty.call(quietMode, 'enabled')) {
      nextRow.quiet_mode_enabled = quietMode.enabled ? 1 : 0;
    }
    if (Object.prototype.hasOwnProperty.call(quietMode, 'start')) {
      nextRow.quiet_mode_start = quietMode.start ? String(quietMode.start).trim() : null;
    }
    if (Object.prototype.hasOwnProperty.call(quietMode, 'end')) {
      nextRow.quiet_mode_end = quietMode.end ? String(quietMode.end).trim() : null;
    }
    sqlRun(
      `INSERT INTO notification_user_preferences
         (user_id, social_enabled, messaging_enabled, groups_enabled, events_enabled, networking_enabled, jobs_enabled, system_enabled, quiet_mode_enabled, quiet_mode_start, quiet_mode_end, updated_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
       ON CONFLICT(user_id) DO UPDATE SET
         social_enabled = excluded.social_enabled,
         messaging_enabled = excluded.messaging_enabled,
         groups_enabled = excluded.groups_enabled,
         events_enabled = excluded.events_enabled,
         networking_enabled = excluded.networking_enabled,
         jobs_enabled = excluded.jobs_enabled,
         system_enabled = excluded.system_enabled,
         quiet_mode_enabled = excluded.quiet_mode_enabled,
         quiet_mode_start = excluded.quiet_mode_start,
         quiet_mode_end = excluded.quiet_mode_end,
         updated_at = excluded.updated_at`,
      [
        userId,
        Number(nextRow.social_enabled || 0),
        Number(nextRow.messaging_enabled || 0),
        Number(nextRow.groups_enabled || 0),
        Number(nextRow.events_enabled || 0),
        Number(nextRow.networking_enabled || 0),
        Number(nextRow.jobs_enabled || 0),
        Number(nextRow.system_enabled || 0),
        Number(nextRow.quiet_mode_enabled || 0),
        nextRow.quiet_mode_start || null,
        nextRow.quiet_mode_end || null,
        nextRow.updated_at
      ]
    );
    const preferences = mapNotificationPreferenceResponse(nextRow);
    return res.json(apiSuccessEnvelope(
      'NOTIFICATION_PREFERENCES_UPDATED',
      'Bildirim tercihleri güncellendi.',
      { preferences },
      { preferences }
    ));
  } catch (err) {
    console.error('notifications.preferences.update failed:', err);
    return sendApiError(res, 500, 'NOTIFICATION_PREFERENCES_UPDATE_FAILED', 'Beklenmeyen bir hata oluştu.');
  }
});

app.get('/api/new/admin/notifications/governance', requireAdmin, (_req, res) => {
  try {
    const inventory = Object.keys(NOTIFICATION_CATEGORY_MAP).sort().map((type) => ({
      type,
      category: getNotificationCategory(type),
      priority: getNotificationPriority(type),
      has_dedupe_rule: Boolean(getNotificationDedupeRule(type))
    }));
    return res.json(apiSuccessEnvelope(
      'ADMIN_NOTIFICATIONS_GOVERNANCE_OK',
      'Notification governance policy hazır.',
      {
        checklist: NOTIFICATION_GOVERNANCE_CHECKLIST,
        inventory
      },
      {
        checklist: NOTIFICATION_GOVERNANCE_CHECKLIST,
        inventory
      }
    ));
  } catch (err) {
    console.error('admin.notifications.governance failed:', err);
    return sendApiError(res, 500, 'ADMIN_NOTIFICATIONS_GOVERNANCE_FAILED', 'Beklenmeyen bir hata oluştu.');
  }
});

app.get('/api/new/admin/notifications/experiments', requireAdmin, (_req, res) => {
  try {
    const configs = readNotificationExperimentConfigs();
    return res.json(apiSuccessEnvelope(
      'ADMIN_NOTIFICATIONS_EXPERIMENTS_OK',
      'Notification experiment ayarları hazır.',
      { items: configs },
      { items: configs }
    ));
  } catch (err) {
    console.error('admin.notifications.experiments.list failed:', err);
    return sendApiError(res, 500, 'ADMIN_NOTIFICATIONS_EXPERIMENTS_FAILED', 'Beklenmeyen bir hata oluştu.');
  }
});

app.put('/api/new/admin/notifications/experiments/:key', requireAdmin, (req, res) => {
  try {
    ensureNotificationExperimentConfigsTable();
    const experimentKey = String(req.params.key || '').trim();
    const existing = readNotificationExperimentConfigs().find((item) => item.key === experimentKey);
    if (!existing) {
      return sendApiError(res, 404, 'ADMIN_NOTIFICATIONS_EXPERIMENT_NOT_FOUND', 'Experiment bulunamadı.');
    }
    const status = String(req.body?.status || existing.status).trim().toLowerCase() === 'paused' ? 'paused' : 'active';
    const rawVariants = Array.isArray(req.body?.variants)
      ? req.body.variants
      : String(req.body?.variants || '').split(',');
    const variants = rawVariants.map((item) => String(item || '').trim()).filter(Boolean);
    const safeVariants = variants.length ? variants : existing.variants;
    sqlRun(
      `UPDATE notification_experiment_configs
       SET status = ?, variants_json = ?, updated_at = ?
       WHERE experiment_key = ?`,
      [status, JSON.stringify(safeVariants), new Date().toISOString(), experimentKey]
    );
    const item = readNotificationExperimentConfigs().find((row) => row.key === experimentKey) || existing;
    return res.json(apiSuccessEnvelope(
      'ADMIN_NOTIFICATIONS_EXPERIMENT_UPDATED',
      'Notification experiment ayarı güncellendi.',
      { item },
      { item }
    ));
  } catch (err) {
    console.error('admin.notifications.experiments.update failed:', err);
    return sendApiError(res, 500, 'ADMIN_NOTIFICATIONS_EXPERIMENT_UPDATE_FAILED', 'Beklenmeyen bir hata oluştu.');
  }
});

app.get('/api/new/admin/notifications/ops', requireAdmin, async (req, res) => {
  try {
    ensureNotificationDeliveryAuditTable();
    ensureNotificationTelemetryEventsTable();
    ensureNotificationPreferencesTable();
    const windowDays = parseNetworkWindowDays(req.query.window);
    const sinceIso = toIsoThreshold(windowDays);
    const day1Iso = new Date(Date.now() - (24 * 60 * 60 * 1000)).toISOString();
    const day7Iso = new Date(Date.now() - (7 * 24 * 60 * 60 * 1000)).toISOString();

    const [deliveryRows, telemetryRows, unreadRows, noisyRows, quietModeRow] = await Promise.all([
      sqlAllAsync(
        `SELECT notification_type, delivery_status, COUNT(*) AS cnt
         FROM notification_delivery_audit
         WHERE created_at >= ?
         GROUP BY notification_type, delivery_status
         ORDER BY cnt DESC, notification_type ASC`,
        [sinceIso]
      ),
      sqlAllAsync(
        `SELECT COALESCE(surface, 'unknown') AS surface, event_name, COUNT(*) AS cnt
         FROM notification_telemetry_events
         WHERE created_at >= ?
         GROUP BY COALESCE(surface, 'unknown'), event_name
         ORDER BY surface ASC, event_name ASC`,
        [sinceIso]
      ),
      sqlAllAsync(
        `SELECT type,
                COUNT(*) AS unread_count,
                SUM(CASE WHEN created_at < ? THEN 1 ELSE 0 END) AS older_than_1d,
                SUM(CASE WHEN created_at < ? THEN 1 ELSE 0 END) AS older_than_7d
         FROM notifications
         WHERE read_at IS NULL
         GROUP BY type
         ORDER BY unread_count DESC, type ASC
         LIMIT 20`,
        [day1Iso, day7Iso]
      ),
      sqlAllAsync(
        `SELECT type, COUNT(*) AS cnt
         FROM notifications
         WHERE created_at >= ?
         GROUP BY type
         ORDER BY cnt DESC, type ASC
         LIMIT 10`,
        [sinceIso]
      ),
      sqlGetAsync('SELECT COUNT(*) AS cnt FROM notification_user_preferences WHERE quiet_mode_enabled = 1')
    ]);

    const deliverySummary = { inserted: 0, skipped: 0, failed: 0 };
    const typeMap = new Map();
    for (const row of deliveryRows || []) {
      const type = String(row?.notification_type || 'unknown').trim();
      const status = String(row?.delivery_status || 'unknown').trim();
      const count = Number(row?.cnt || 0);
      if (deliverySummary[status] != null) deliverySummary[status] += count;
      const current = typeMap.get(type) || { type, inserted: 0, skipped: 0, failed: 0 };
      if (current[status] != null) current[status] += count;
      typeMap.set(type, current);
    }

    const surfaceMap = new Map();
    for (const row of telemetryRows || []) {
      const surface = String(row?.surface || 'unknown').trim() || 'unknown';
      const eventName = String(row?.event_name || 'unknown').trim();
      const count = Number(row?.cnt || 0);
      const current = surfaceMap.get(surface) || {
        surface,
        impression: 0,
        open: 0,
        action: 0,
        landed: 0,
        bounce: 0,
        no_action: 0
      };
      if (current[eventName] != null) current[eventName] += count;
      surfaceMap.set(surface, current);
    }

    const surfaceConversion = Array.from(surfaceMap.values()).map((item) => ({
      ...item,
      open_rate: item.impression > 0 ? Number((item.open / item.impression).toFixed(4)) : 0,
      action_rate: item.impression > 0 ? Number((item.action / item.impression).toFixed(4)) : 0,
      bounce_rate: item.landed > 0 ? Number((item.bounce / item.landed).toFixed(4)) : 0,
      no_action_rate: item.landed > 0 ? Number((item.no_action / item.landed).toFixed(4)) : 0
    })).sort((a, b) => String(a.surface).localeCompare(String(b.surface)));

    const unreadAging = (unreadRows || []).map((row) => ({
      type: String(row?.type || '').trim(),
      category: getNotificationCategory(row?.type),
      unread_count: Number(row?.unread_count || 0),
      older_than_1d: Number(row?.older_than_1d || 0),
      older_than_7d: Number(row?.older_than_7d || 0)
    }));

    const alerts = [];
    for (const surface of surfaceConversion) {
      if (Number(surface.bounce_rate || 0) >= 0.25) {
        alerts.push({ code: 'bounce_rate_high', severity: 'high', surface: surface.surface, message: `${surface.surface} yüzeyinde bounce rate yükseldi.` });
      }
      if (Number(surface.no_action_rate || 0) >= 0.4) {
        alerts.push({ code: 'no_action_rate_high', severity: 'medium', surface: surface.surface, message: `${surface.surface} yüzeyinde no-action oranı yüksek.` });
      }
    }
    if (Number(deliverySummary.failed || 0) > 0) {
      alerts.push({ code: 'critical_insert_failures', severity: 'high', message: 'Notification delivery audit içinde failed insert kayıtları var.' });
    }

    return res.json(apiSuccessEnvelope(
      'ADMIN_NOTIFICATIONS_OPS_OK',
      'Notification operations verileri hazır.',
      {
        window: `${windowDays}d`,
        since: sinceIso,
        delivery_summary: deliverySummary,
        delivery_by_type: Array.from(typeMap.values()).sort((a, b) => (Number(b.failed || 0) - Number(a.failed || 0)) || String(a.type).localeCompare(String(b.type))),
        noisy_types: (noisyRows || []).map((row) => ({
          type: String(row?.type || '').trim(),
          category: getNotificationCategory(row?.type),
          count: Number(row?.cnt || 0)
        })),
        unread_aging: unreadAging,
        surface_conversion: surfaceConversion,
        quiet_mode_enabled_users: Number(quietModeRow?.cnt || 0),
        alerts
      },
      {
        window: `${windowDays}d`,
        since: sinceIso,
        delivery_summary: deliverySummary,
        delivery_by_type: Array.from(typeMap.values()).sort((a, b) => (Number(b.failed || 0) - Number(a.failed || 0)) || String(a.type).localeCompare(String(b.type))),
        noisy_types: (noisyRows || []).map((row) => ({
          type: String(row?.type || '').trim(),
          category: getNotificationCategory(row?.type),
          count: Number(row?.cnt || 0)
        })),
        unread_aging: unreadAging,
        surface_conversion: surfaceConversion,
        quiet_mode_enabled_users: Number(quietModeRow?.cnt || 0),
        alerts
      }
    ));
  } catch (err) {
    console.error('admin.notifications.ops failed:', err);
    return sendApiError(res, 500, 'ADMIN_NOTIFICATIONS_OPS_FAILED', 'Beklenmeyen bir hata oluştu.');
  }
});

app.post('/api/new/translate', async (req, res) => {
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

app.get('/api/new/stories', requireAuth, async (req, res) => {
  try {
    const nowMs = Date.now();
    const nowIso = new Date(nowMs).toISOString();
    const limit = Math.min(Math.max(parseInt(req.query.limit || '60', 10), 1), 120);
    const cursor = Math.max(parseInt(req.query.cursor || '0', 10), 0);
    const cacheKey = await buildVersionedCacheKey(cacheNamespaces.stories, [
      `user:${Number(req.session.userId || 0)}`,
      `limit:${limit}`,
      `cursor:${cursor || 0}`
    ]);
    const cached = await getCacheJson(cacheKey);
    if (cached && Array.isArray(cached.items)) {
      res.setHeader('X-Has-More', cached.hasMore ? '1' : '0');
      return res.json({ items: cached.items });
    }

    const whereParts = ['(s.expires_at IS NULL OR s.expires_at > ?)'];
    const params = [nowIso];
    if (cursor > 0) {
      whereParts.push('s.id < ?');
      params.push(cursor);
    }
    const rows = await sqlAllAsync(
      `SELECT s.id, s.user_id, s.image, s.image_record_id, s.caption, s.created_at, s.expires_at,
              u.kadi, u.isim, u.soyisim, u.resim, u.verified
       FROM stories s
       LEFT JOIN uyeler u ON u.id = s.user_id
       WHERE ${whereParts.join(' AND ')}
       ORDER BY s.id DESC
       LIMIT ?`,
      [...params, limit + 1]
    );
    const viewed = await sqlAllAsync('SELECT story_id FROM story_views WHERE user_id = ?', [req.session.userId]);
    const viewedSet = new Set(viewed.map((v) => Number(v.story_id)));
    const variantsMap = await getImageVariantsBatch(
      rows.slice(0, limit).map((row) => row.image_record_id).filter(Boolean),
      sqlAllAsync,
      uploadsDir
    );
    const items = rows
      .slice(0, limit)
      .map((r) => {
        const timing = storyTiming(r, nowMs);
        const item = {
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
        if (r.image_record_id) {
          const variants = variantsMap.get(String(r.image_record_id));
          if (variants) item.variants = { thumbUrl: variants.thumbUrl, feedUrl: variants.feedUrl, fullUrl: variants.fullUrl };
        }
        return item;
      })
      .filter((story) => !story.isExpired);
    const hasMore = rows.length > limit;
    const responsePayload = { items };
    res.setHeader('X-Has-More', hasMore ? '1' : '0');
    await setCacheJson(cacheKey, { items, hasMore }, STORY_RAIL_CACHE_TTL_SECONDS);
    return res.json(responsePayload);
  } catch (err) {
    console.error('GET /api/new/stories failed:', err);
    return res.status(500).send('Beklenmeyen bir hata oluştu.');
  }
});

app.get('/api/new/stories/mine', requireAuth, async (req, res) => {
  try {
    const rows = await sqlAllAsync(
      `SELECT s.id, s.image, s.image_record_id, s.caption, s.created_at, s.expires_at,
              COUNT(v.id) AS view_count
       FROM stories s
       LEFT JOIN story_views v ON v.story_id = s.id
       WHERE s.user_id = ?
       GROUP BY s.id
       ORDER BY s.created_at DESC`,
      [req.session.userId]
    );
    const nowMs = Date.now();
    const variantsMap = await getImageVariantsBatch(
      rows.map((row) => row.image_record_id).filter(Boolean),
      sqlAllAsync,
      uploadsDir
    );
    return res.json({
      items: rows.map((row) => {
        const timing = storyTiming(row, nowMs);
        const item = {
          id: row.id,
          image: row.image,
          caption: row.caption,
          createdAt: timing.createdAt,
          expiresAt: timing.expiresAt,
          isExpired: timing.isExpired,
          viewCount: Number(row.view_count || 0)
        };
        if (row.image_record_id) {
          const variants = variantsMap.get(String(row.image_record_id));
          if (variants) item.variants = { thumbUrl: variants.thumbUrl, feedUrl: variants.feedUrl, fullUrl: variants.fullUrl };
        }
        return item;
      })
    });
  } catch (err) {
    console.error('GET /api/new/stories/mine failed:', err);
    return res.status(500).send('Beklenmeyen bir hata oluştu.');
  }
});

app.get('/api/new/stories/user/:id', requireAuth, async (req, res) => {
  try {
    const userId = Number(req.params.id || 0);
    if (!Number.isInteger(userId) || userId <= 0) return res.status(400).send('Geçersiz üye kimliği.');
    const includeExpired = String(req.query.includeExpired || '0') === '1';
    const nowMs = Date.now();
    const nowIso = new Date(nowMs).toISOString();

    const rows = await sqlAllAsync(
      `SELECT s.id, s.user_id, s.image, s.image_record_id, s.caption, s.created_at, s.expires_at,
              u.kadi, u.isim, u.soyisim, u.resim, u.verified
       FROM stories s
       LEFT JOIN uyeler u ON u.id = s.user_id
       WHERE s.user_id = ?
         AND (? = 1 OR s.expires_at IS NULL OR s.expires_at > ?)
       ORDER BY s.created_at DESC`,
      [userId, includeExpired ? 1 : 0, nowIso]
    );

    const viewed = await sqlAllAsync('SELECT story_id FROM story_views WHERE user_id = ?', [req.session.userId]);
    const viewedSet = new Set(viewed.map((v) => Number(v.story_id)));
    const variantsMap = await getImageVariantsBatch(
      rows.map((row) => row.image_record_id).filter(Boolean),
      sqlAllAsync,
      uploadsDir
    );
    const items = rows.map((r) => {
      const timing = storyTiming(r, nowMs);
      const item = {
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
      if (r.image_record_id) {
        const variants = variantsMap.get(String(r.image_record_id));
        if (variants) item.variants = { thumbUrl: variants.thumbUrl, feedUrl: variants.feedUrl, fullUrl: variants.fullUrl };
      }
      return item;
    });

    return res.json({ items });
  } catch (err) {
    console.error('GET /api/new/stories/user/:id failed:', err);
    return res.status(500).send('Beklenmeyen bir hata oluştu.');
  }
});

app.post('/api/new/stories/upload', requireAuth, uploadRateLimit, storyUpload.single('image'), async (req, res) => {
  if (!req.file) return res.status(400).send('Görsel seçilmedi.');
  try {
    const validation = validateUploadedImageFile(req.file.path, {
      allowedMimes: allowedImageSafetyMimes,
      maxBytes: getMediaUploadLimitBytes()
    });
    if (!validation.ok) {
      cleanupUploadedFile(req.file.path);
      return res.status(400).send(validation.reason);
    }
    const quotaOk = await enforceUploadQuota(req, res, {
      fileSize: validation.size || req.file.size || 0,
      bucket: 'story_image'
    });
    if (!quotaOk) {
      cleanupUploadedFile(req.file.path);
      return res.status(429).send('Günlük yükleme kotan doldu. Lütfen daha sonra tekrar dene.');
    }

    const caption = formatUserText(req.body?.caption || '');
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

    // Also generate variants via new pipeline
    let imageRecordId = null;
    let variants = null;
    try {
      const storyBuffer = fs.readFileSync(outputPath);
      const uploadResult = await processUpload({
        buffer: storyBuffer,
        mimeType: 'image/webp',
        userId: req.session.userId,
        entityType: 'story',
        entityId: '0',
        sqlGet,
        sqlRun,
        uploadsDir,
        writeAppLog
      });
      imageRecordId = uploadResult.imageId;
      variants = uploadResult.variants;
    } catch (err) {
      writeAppLog('error', 'story_variant_generation_failed', { message: err?.message });
    }

    const result = sqlRun('INSERT INTO stories (user_id, image, image_record_id, caption, created_at, expires_at) VALUES (?, ?, ?, ?, ?, ?)', [
      req.session.userId,
      image,
      imageRecordId,
      caption,
      now.toISOString(),
      expires.toISOString()
    ]);

    const storyId = result?.lastInsertRowid;
    if (imageRecordId && storyId) {
      try {
        sqlRun('UPDATE image_records SET entity_id = ? WHERE id = ?', [storyId, imageRecordId]);
      } catch { /* best effort */ }
    }

    scheduleEngagementRecalculation('story_created');
    invalidateCacheNamespace(cacheNamespaces.stories);
    res.json({ ok: true, id: storyId, image, variants });
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
  const caption = formatUserText(req.body?.caption || '');
  sqlRun('UPDATE stories SET caption = ? WHERE id = ?', [caption, storyId]);
  invalidateCacheNamespace(cacheNamespaces.stories);
  res.json({ ok: true });
}

function deleteStory(req, res) {
  const storyId = parseStoryId(req.params.id);
  if (!storyId) return res.status(400).send('Geçersiz hikaye kimliği.');
  const story = sqlGet('SELECT id, image_record_id FROM stories WHERE id = ? AND user_id = ?', [storyId, req.session.userId]);
  if (!story) return res.status(404).send('Hikaye bulunamadı.');
  // Clean up image variants if present
  if (story.image_record_id) {
    deleteImageRecord(story.image_record_id, sqlGet, sqlRun, uploadsDir, writeAppLog).catch(() => {});
  }
  sqlRun('DELETE FROM story_views WHERE story_id = ?', [storyId]);
  sqlRun('DELETE FROM stories WHERE id = ?', [storyId]);
  invalidateCacheNamespace(cacheNamespaces.stories);
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
  invalidateCacheNamespace(cacheNamespaces.stories);
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
    invalidateCacheNamespace(cacheNamespaces.stories);
  }
  res.json({ ok: true });
});



function normalizeMentorshipStatus(value) {
  const raw = String(value || '').trim().toLowerCase();
  if (raw === 'requested' || raw === 'accepted' || raw === 'declined' || raw === 'cancelled') return raw;
  return '';
}

function normalizeConnectionStatus(value) {
  const raw = String(value || '').trim().toLowerCase();
  if (raw === 'pending' || raw === 'accepted' || raw === 'ignored') return raw;
  return '';
}

function normalizeTeacherAlumniRelationshipType(value) {
  const raw = String(value || '').trim().toLowerCase();
  if (raw === 'taught_in_class' || raw === 'mentor' || raw === 'advisor') return raw;
  return '';
}

function normalizeTeacherLinkCreatedVia(value) {
  const raw = String(value || '').trim().toLowerCase();
  if (raw === 'manual_alumni_link' || raw === 'admin_review_update' || raw === 'import') return raw;
  return 'manual_alumni_link';
}

function normalizeTeacherLinkSourceSurface(value) {
  const raw = String(value || '').trim().toLowerCase();
  if (raw === 'teachers_network_page' || raw === 'member_detail_page' || raw === 'network_hub' || raw === 'admin_panel') return raw;
  return 'teachers_network_page';
}

function normalizeTeacherLinkReviewStatus(value) {
  const raw = String(value || '').trim().toLowerCase();
  if (raw === 'pending' || raw === 'confirmed' || raw === 'flagged' || raw === 'rejected' || raw === 'merged') return raw;
  return '';
}

const NETWORKING_TELEMETRY_CLIENT_EVENT_NAMES = new Set([
  'network_hub_viewed',
  'network_hub_suggestions_loaded',
  'network_explore_viewed',
  'network_explore_suggestions_loaded',
  'teacher_network_viewed'
]);

const NETWORKING_TELEMETRY_ACTION_EVENT_NAMES = new Set([
  'connection_requested',
  'connection_accepted',
  'connection_ignored',
  'connection_cancelled',
  'mentorship_requested',
  'mentorship_accepted',
  'mentorship_declined',
  'teacher_link_created',
  'teacher_links_read',
  'follow_created',
  'follow_removed'
]);

const NETWORKING_DAILY_SUMMARY_REBUILD_INTERVAL_MS = 60 * 1000;
let networkingDailySummaryRefreshPromise = null;

function normalizeNetworkingTelemetryEventName(value, { allowClientEvents = true, allowActionEvents = true } = {}) {
  const raw = String(value || '').trim().toLowerCase();
  if (!raw) return '';
  if (allowClientEvents && NETWORKING_TELEMETRY_CLIENT_EVENT_NAMES.has(raw)) return raw;
  if (allowActionEvents && NETWORKING_TELEMETRY_ACTION_EVENT_NAMES.has(raw)) return raw;
  return '';
}

function normalizeNetworkingTelemetrySourceSurface(value) {
  const raw = String(value || '').trim().toLowerCase();
  if (raw === 'network_hub' || raw === 'explore_page' || raw === 'teachers_network_page' || raw === 'member_detail_page' || raw === 'admin_panel' || raw === 'server_action') return raw;
  return 'server_action';
}

function normalizeNetworkingTelemetryEntityType(value) {
  const raw = String(value || '').trim().toLowerCase();
  if (raw === 'user' || raw === 'connection_request' || raw === 'mentorship_request' || raw === 'teacher_link' || raw === 'suggestion_batch' || raw === 'notification') return raw;
  return '';
}

function normalizeTeacherLinkReviewNote(value) {
  return String(value || '').trim().slice(0, 500);
}

function normalizeBooleanFlag(value) {
  const raw = String(value ?? '').trim().toLowerCase();
  return raw === '1' || raw === 'true' || raw === 'yes' || raw === 'on';
}

function parseTeacherNetworkClassYear(value) {
  const raw = String(value ?? '').trim();
  if (!raw) return { provided: false, value: null, valid: true };
  if (!/^\d{4}$/.test(raw)) return { provided: true, value: null, valid: false };
  const year = Number.parseInt(raw, 10);
  const valid = Number.isFinite(year) && year >= TEACHER_NETWORK_MIN_CLASS_YEAR && year <= TEACHER_NETWORK_MAX_CLASS_YEAR;
  return { provided: true, value: valid ? year : null, valid };
}

function calculateCooldownRemainingSeconds(timestampValue, cooldownSeconds) {
  const cooldown = Number(cooldownSeconds || 0);
  if (!Number.isFinite(cooldown) || cooldown <= 0) return 0;
  const fromMs = toDateMs(timestampValue);
  if (fromMs === null) return 0;
  const remainingMs = fromMs + cooldown * 1000 - Date.now();
  return remainingMs > 0 ? Math.ceil(remainingMs / 1000) : 0;
}

function apiSuccessEnvelope(code, message, data = null, legacy = null) {
  const payload = { ok: true, code, message, data };
  if (legacy && typeof legacy === 'object') Object.assign(payload, legacy);
  return payload;
}

function apiErrorEnvelope(code, message, data = null, legacy = null) {
  const payload = { ok: false, code, message, data };
  if (legacy && typeof legacy === 'object') Object.assign(payload, legacy);
  return payload;
}

function sendApiError(res, statusCode, code, message, data = null, legacy = null) {
  return res.status(statusCode).json(apiErrorEnvelope(code, message, data, legacy));
}

function ensureConnectionRequestsTable() {
  sqlRun(`
    CREATE TABLE IF NOT EXISTS connection_requests (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      sender_id INTEGER NOT NULL,
      receiver_id INTEGER NOT NULL,
      status TEXT DEFAULT 'pending',
      created_at TEXT,
      updated_at TEXT,
      responded_at TEXT,
      UNIQUE(sender_id, receiver_id)
    )
  `);
  if (!hasColumn('connection_requests', 'responded_at')) {
    try {
      sqlRun('ALTER TABLE connection_requests ADD COLUMN responded_at TEXT');
    } catch {
      // no-op; column may already exist in concurrent boot paths
    }
  }
  sqlRun('CREATE INDEX IF NOT EXISTS idx_connection_requests_sender ON connection_requests (sender_id, updated_at DESC)');
  sqlRun('CREATE INDEX IF NOT EXISTS idx_connection_requests_receiver ON connection_requests (receiver_id, updated_at DESC)');
}

function ensureMentorshipRequestsTable() {
  sqlRun(`
    CREATE TABLE IF NOT EXISTS mentorship_requests (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      requester_id INTEGER NOT NULL,
      mentor_id INTEGER NOT NULL,
      status TEXT DEFAULT 'requested',
      focus_area TEXT,
      message TEXT,
      created_at TEXT,
      updated_at TEXT,
      responded_at TEXT,
      UNIQUE(requester_id, mentor_id)
    )
  `);
  if (!hasColumn('mentorship_requests', 'responded_at')) {
    try {
      sqlRun('ALTER TABLE mentorship_requests ADD COLUMN responded_at TEXT');
    } catch {
      // no-op; column may already exist in concurrent boot paths
    }
  }
  sqlRun('CREATE INDEX IF NOT EXISTS idx_mentorship_requests_requester ON mentorship_requests (requester_id, updated_at DESC)');
  sqlRun('CREATE INDEX IF NOT EXISTS idx_mentorship_requests_mentor ON mentorship_requests (mentor_id, updated_at DESC)');
}

function ensureTeacherAlumniLinksTable() {
  sqlRun(`
    CREATE TABLE IF NOT EXISTS teacher_alumni_links (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      teacher_user_id INTEGER NOT NULL,
      alumni_user_id INTEGER NOT NULL,
      relationship_type TEXT NOT NULL,
      class_year INTEGER,
      notes TEXT,
      confidence_score REAL NOT NULL DEFAULT 1.0,
      created_via TEXT NOT NULL DEFAULT 'manual_alumni_link',
      source_surface TEXT NOT NULL DEFAULT 'teachers_network_page',
      last_reviewed_by INTEGER,
      review_status TEXT NOT NULL DEFAULT 'pending',
      review_note TEXT,
      reviewed_at TEXT,
      merged_into_link_id INTEGER,
      created_by INTEGER,
      created_at TEXT NOT NULL,
      UNIQUE(teacher_user_id, alumni_user_id, relationship_type, class_year)
    )
  `);
  if (!hasColumn('teacher_alumni_links', 'created_via')) {
    try {
      sqlRun("ALTER TABLE teacher_alumni_links ADD COLUMN created_via TEXT NOT NULL DEFAULT 'manual_alumni_link'");
    } catch {
      // no-op
    }
  }
  if (!hasColumn('teacher_alumni_links', 'source_surface')) {
    try {
      sqlRun("ALTER TABLE teacher_alumni_links ADD COLUMN source_surface TEXT NOT NULL DEFAULT 'teachers_network_page'");
    } catch {
      // no-op
    }
  }
  if (!hasColumn('teacher_alumni_links', 'last_reviewed_by')) {
    try {
      sqlRun('ALTER TABLE teacher_alumni_links ADD COLUMN last_reviewed_by INTEGER');
    } catch {
      // no-op
    }
  }
  if (!hasColumn('teacher_alumni_links', 'review_status')) {
    try {
      sqlRun("ALTER TABLE teacher_alumni_links ADD COLUMN review_status TEXT NOT NULL DEFAULT 'pending'");
    } catch {
      // no-op
    }
  }
  if (!hasColumn('teacher_alumni_links', 'review_note')) {
    try {
      sqlRun('ALTER TABLE teacher_alumni_links ADD COLUMN review_note TEXT');
    } catch {
      // no-op
    }
  }
  if (!hasColumn('teacher_alumni_links', 'reviewed_at')) {
    try {
      sqlRun('ALTER TABLE teacher_alumni_links ADD COLUMN reviewed_at TEXT');
    } catch {
      // no-op
    }
  }
  if (!hasColumn('teacher_alumni_links', 'merged_into_link_id')) {
    try {
      sqlRun('ALTER TABLE teacher_alumni_links ADD COLUMN merged_into_link_id INTEGER');
    } catch {
      // no-op
    }
  }
  sqlRun('CREATE INDEX IF NOT EXISTS idx_teacher_alumni_links_alumni ON teacher_alumni_links (alumni_user_id, created_at DESC)');
  sqlRun('CREATE INDEX IF NOT EXISTS idx_teacher_alumni_links_teacher ON teacher_alumni_links (teacher_user_id, created_at DESC)');
  sqlRun('CREATE INDEX IF NOT EXISTS idx_teacher_alumni_links_review_status ON teacher_alumni_links (review_status, created_at DESC)');
}

function ensureTeacherAlumniLinkModerationEventsTable() {
  sqlRun(`
    CREATE TABLE IF NOT EXISTS teacher_alumni_link_moderation_events (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      link_id INTEGER NOT NULL,
      actor_user_id INTEGER,
      event_type TEXT NOT NULL,
      from_status TEXT,
      to_status TEXT,
      note TEXT,
      merge_target_id INTEGER,
      created_at TEXT NOT NULL
    )
  `);
  sqlRun('CREATE INDEX IF NOT EXISTS idx_teacher_link_moderation_events_link ON teacher_alumni_link_moderation_events (link_id, created_at DESC)');
}

function ensureNetworkingTelemetryEventsTable() {
  sqlRun(`
    CREATE TABLE IF NOT EXISTS networking_telemetry_events (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id INTEGER,
      event_name TEXT NOT NULL,
      source_surface TEXT NOT NULL DEFAULT 'server_action',
      target_user_id INTEGER,
      entity_type TEXT,
      entity_id INTEGER,
      metadata_json TEXT,
      created_at TEXT NOT NULL
    )
  `);
  sqlRun('CREATE INDEX IF NOT EXISTS idx_networking_telemetry_event_name ON networking_telemetry_events (event_name, created_at DESC)');
  sqlRun('CREATE INDEX IF NOT EXISTS idx_networking_telemetry_user_id ON networking_telemetry_events (user_id, created_at DESC)');
}

function ensureMemberNetworkingDailySummaryTable() {
  sqlRun(`
    CREATE TABLE IF NOT EXISTS member_networking_daily_summary (
      user_id INTEGER NOT NULL,
      date TEXT NOT NULL,
      cohort TEXT,
      connections_requested INTEGER NOT NULL DEFAULT 0,
      connections_accepted INTEGER NOT NULL DEFAULT 0,
      connections_pending INTEGER NOT NULL DEFAULT 0,
      connections_ignored INTEGER NOT NULL DEFAULT 0,
      connections_declined INTEGER NOT NULL DEFAULT 0,
      connections_cancelled INTEGER NOT NULL DEFAULT 0,
      mentorship_requested INTEGER NOT NULL DEFAULT 0,
      mentorship_accepted INTEGER NOT NULL DEFAULT 0,
      mentorship_declined INTEGER NOT NULL DEFAULT 0,
      teacher_links_created INTEGER NOT NULL DEFAULT 0,
      teacher_links_read INTEGER NOT NULL DEFAULT 0,
      follow_created INTEGER NOT NULL DEFAULT 0,
      follow_removed INTEGER NOT NULL DEFAULT 0,
      hub_views INTEGER NOT NULL DEFAULT 0,
      hub_suggestion_loads INTEGER NOT NULL DEFAULT 0,
      explore_views INTEGER NOT NULL DEFAULT 0,
      explore_suggestion_loads INTEGER NOT NULL DEFAULT 0,
      teacher_network_views INTEGER NOT NULL DEFAULT 0,
      updated_at TEXT NOT NULL,
      PRIMARY KEY (user_id, date)
    )
  `);
  sqlRun('CREATE INDEX IF NOT EXISTS idx_member_networking_daily_summary_date ON member_networking_daily_summary (date DESC)');
  sqlRun('CREATE INDEX IF NOT EXISTS idx_member_networking_daily_summary_cohort ON member_networking_daily_summary (cohort, date DESC)');
}

function ensureNetworkingSummaryMetaTable() {
  sqlRun(`
    CREATE TABLE IF NOT EXISTS networking_summary_meta (
      key TEXT PRIMARY KEY,
      value TEXT,
      updated_at TEXT NOT NULL
    )
  `);
}

function ensureNetworkSuggestionAbTables() {
  sqlRun(`
    CREATE TABLE IF NOT EXISTS network_suggestion_ab_config (
      variant TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      description TEXT,
      traffic_pct INTEGER NOT NULL DEFAULT 0,
      enabled INTEGER NOT NULL DEFAULT 1,
      params_json TEXT,
      updated_at TEXT NOT NULL
    )
  `);
  sqlRun(`
    CREATE TABLE IF NOT EXISTS network_suggestion_ab_assignments (
      user_id INTEGER PRIMARY KEY,
      variant TEXT NOT NULL,
      assigned_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )
  `);
  sqlRun('CREATE INDEX IF NOT EXISTS idx_network_suggestion_ab_assignments_variant ON network_suggestion_ab_assignments (variant, updated_at DESC)');
  sqlRun(`
    CREATE TABLE IF NOT EXISTS network_suggestion_ab_change_log (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      action_type TEXT NOT NULL DEFAULT 'apply',
      related_change_id INTEGER,
      actor_user_id INTEGER,
      recommendation_index INTEGER,
      cohort TEXT,
      window_days INTEGER,
      payload_json TEXT,
      before_snapshot_json TEXT,
      after_snapshot_json TEXT,
      created_at TEXT NOT NULL,
      rolled_back_at TEXT,
      rollback_change_id INTEGER
    )
  `);
  sqlRun('CREATE INDEX IF NOT EXISTS idx_network_suggestion_ab_change_log_created_at ON network_suggestion_ab_change_log (created_at DESC)');
}

function toSummaryDateKey(value) {
  const raw = String(value || '').trim();
  if (!raw) return '';
  return raw.slice(0, 10);
}

function incrementNetworkingDailySummaryMetric(bucket, key, delta = 1) {
  const metricKey = String(key || '').trim();
  if (!metricKey) return;
  bucket[metricKey] = Math.max(0, Number(bucket[metricKey] || 0) + Number(delta || 0));
}

async function rebuildMemberNetworkingDailySummary() {
  ensureConnectionRequestsTable();
  ensureMentorshipRequestsTable();
  ensureTeacherAlumniLinksTable();
  ensureNetworkingTelemetryEventsTable();
  ensureMemberNetworkingDailySummaryTable();
  ensureNetworkingSummaryMetaTable();

  const [userRows, connectionRows, mentorshipRows, teacherLinkRows, telemetryRows] = await Promise.all([
    sqlAllAsync(`SELECT id, LOWER(COALESCE(NULLIF(CAST(mezuniyetyili AS TEXT), ''), 'unknown')) AS cohort FROM uyeler`),
    sqlAllAsync(`SELECT sender_id AS user_id, status, created_at FROM connection_requests WHERE COALESCE(TRIM(created_at), '') <> ''`),
    sqlAllAsync(`SELECT requester_id AS user_id, status, created_at FROM mentorship_requests WHERE COALESCE(TRIM(created_at), '') <> ''`),
    sqlAllAsync(`SELECT COALESCE(created_by, alumni_user_id) AS user_id, created_at FROM teacher_alumni_links WHERE COALESCE(TRIM(created_at), '') <> ''`),
    sqlAllAsync(`SELECT user_id, event_name, created_at FROM networking_telemetry_events WHERE COALESCE(TRIM(created_at), '') <> ''`)
  ]);

  const cohortMap = new Map();
  for (const row of userRows || []) {
    cohortMap.set(Number(row?.id || 0), String(row?.cohort || 'unknown').trim().toLowerCase() || 'unknown');
  }

  const summaryMap = new Map();
  function getBucket(userId, dateKey) {
    const safeUserId = Number(userId || 0);
    if (!safeUserId || !dateKey) return null;
    const mapKey = `${safeUserId}:${dateKey}`;
    if (!summaryMap.has(mapKey)) {
      summaryMap.set(mapKey, {
        user_id: safeUserId,
        date: dateKey,
        cohort: cohortMap.get(safeUserId) || 'unknown',
        connections_requested: 0,
        connections_accepted: 0,
        connections_pending: 0,
        connections_ignored: 0,
        connections_declined: 0,
        connections_cancelled: 0,
        mentorship_requested: 0,
        mentorship_accepted: 0,
        mentorship_declined: 0,
        teacher_links_created: 0,
        teacher_links_read: 0,
        follow_created: 0,
        follow_removed: 0,
        hub_views: 0,
        hub_suggestion_loads: 0,
        explore_views: 0,
        explore_suggestion_loads: 0,
        teacher_network_views: 0
      });
    }
    return summaryMap.get(mapKey);
  }

  for (const row of connectionRows || []) {
    const bucket = getBucket(row?.user_id, toSummaryDateKey(row?.created_at));
    if (!bucket) continue;
    incrementNetworkingDailySummaryMetric(bucket, 'connections_requested', 1);
    const status = String(row?.status || '').trim().toLowerCase();
    if (status === 'accepted') incrementNetworkingDailySummaryMetric(bucket, 'connections_accepted', 1);
    else if (status === 'pending') incrementNetworkingDailySummaryMetric(bucket, 'connections_pending', 1);
    else if (status === 'ignored') incrementNetworkingDailySummaryMetric(bucket, 'connections_ignored', 1);
    else if (status === 'declined') incrementNetworkingDailySummaryMetric(bucket, 'connections_declined', 1);
    else if (status === 'cancelled') incrementNetworkingDailySummaryMetric(bucket, 'connections_cancelled', 1);
  }

  for (const row of mentorshipRows || []) {
    const bucket = getBucket(row?.user_id, toSummaryDateKey(row?.created_at));
    if (!bucket) continue;
    incrementNetworkingDailySummaryMetric(bucket, 'mentorship_requested', 1);
    const status = String(row?.status || '').trim().toLowerCase();
    if (status === 'accepted') incrementNetworkingDailySummaryMetric(bucket, 'mentorship_accepted', 1);
    else if (status === 'declined') incrementNetworkingDailySummaryMetric(bucket, 'mentorship_declined', 1);
  }

  for (const row of teacherLinkRows || []) {
    const bucket = getBucket(row?.user_id, toSummaryDateKey(row?.created_at));
    if (!bucket) continue;
    incrementNetworkingDailySummaryMetric(bucket, 'teacher_links_created', 1);
  }

  for (const row of telemetryRows || []) {
    const bucket = getBucket(row?.user_id, toSummaryDateKey(row?.created_at));
    if (!bucket) continue;
    const eventName = String(row?.event_name || '').trim().toLowerCase();
    if (eventName === 'teacher_links_read') incrementNetworkingDailySummaryMetric(bucket, 'teacher_links_read', 1);
    else if (eventName === 'follow_created') incrementNetworkingDailySummaryMetric(bucket, 'follow_created', 1);
    else if (eventName === 'follow_removed') incrementNetworkingDailySummaryMetric(bucket, 'follow_removed', 1);
    else if (eventName === 'network_hub_viewed') incrementNetworkingDailySummaryMetric(bucket, 'hub_views', 1);
    else if (eventName === 'network_hub_suggestions_loaded') incrementNetworkingDailySummaryMetric(bucket, 'hub_suggestion_loads', 1);
    else if (eventName === 'network_explore_viewed') incrementNetworkingDailySummaryMetric(bucket, 'explore_views', 1);
    else if (eventName === 'network_explore_suggestions_loaded') incrementNetworkingDailySummaryMetric(bucket, 'explore_suggestion_loads', 1);
    else if (eventName === 'teacher_network_viewed') incrementNetworkingDailySummaryMetric(bucket, 'teacher_network_views', 1);
  }

  sqlRun('DELETE FROM member_networking_daily_summary');
  const now = new Date().toISOString();
  for (const row of summaryMap.values()) {
    sqlRun(
      `INSERT INTO member_networking_daily_summary (
         user_id, date, cohort, connections_requested, connections_accepted, connections_pending,
         connections_ignored, connections_declined, connections_cancelled, mentorship_requested,
         mentorship_accepted, mentorship_declined, teacher_links_created, teacher_links_read,
         follow_created, follow_removed, hub_views, hub_suggestion_loads, explore_views,
         explore_suggestion_loads, teacher_network_views, updated_at
       ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        row.user_id,
        row.date,
        row.cohort,
        row.connections_requested,
        row.connections_accepted,
        row.connections_pending,
        row.connections_ignored,
        row.connections_declined,
        row.connections_cancelled,
        row.mentorship_requested,
        row.mentorship_accepted,
        row.mentorship_declined,
        row.teacher_links_created,
        row.teacher_links_read,
        row.follow_created,
        row.follow_removed,
        row.hub_views,
        row.hub_suggestion_loads,
        row.explore_views,
        row.explore_suggestion_loads,
        row.teacher_network_views,
        now
      ]
    );
  }

  sqlRun(
    `INSERT INTO networking_summary_meta (key, value, updated_at)
     VALUES ('member_networking_daily_summary:last_rebuilt_at', ?, ?)
     ON CONFLICT(key) DO UPDATE SET value = excluded.value, updated_at = excluded.updated_at`,
    [now, now]
  );

  return { lastRebuiltAt: now, rows: summaryMap.size };
}

async function refreshMemberNetworkingDailySummaryIfStale() {
  ensureNetworkingSummaryMetaTable();
  ensureMemberNetworkingDailySummaryTable();
  const lastRebuiltAt = sqlGet(
    "SELECT value FROM networking_summary_meta WHERE key = 'member_networking_daily_summary:last_rebuilt_at'"
  )?.value || '';
  const lastRebuiltMs = toDateMs(lastRebuiltAt);
  const hasRows = Number(sqlGet('SELECT COUNT(*) AS cnt FROM member_networking_daily_summary')?.cnt || 0) > 0;
  const isFresh = hasRows && lastRebuiltMs !== null && (Date.now() - lastRebuiltMs) < NETWORKING_DAILY_SUMMARY_REBUILD_INTERVAL_MS;
  if (isFresh) {
    return { lastRebuiltAt, rows: Number(sqlGet('SELECT COUNT(*) AS cnt FROM member_networking_daily_summary')?.cnt || 0), skipped: true };
  }
  if (!networkingDailySummaryRefreshPromise) {
    networkingDailySummaryRefreshPromise = rebuildMemberNetworkingDailySummary()
      .finally(() => {
        networkingDailySummaryRefreshPromise = null;
      });
  }
  return networkingDailySummaryRefreshPromise;
}

function buildNetworkingAnalyticsAlerts(summaryTotals, mentorDemandRows = [], mentorSupplyRows = []) {
  const alerts = [];
  const connectionsRequested = Number(summaryTotals?.connections_requested || 0);
  const connectionsAccepted = Number(summaryTotals?.connections_accepted || 0);
  const mentorshipRequested = Number(summaryTotals?.mentorship_requested || 0);
  const mentorshipAccepted = Number(summaryTotals?.mentorship_accepted || 0);
  const teacherLinksCreated = Number(summaryTotals?.teacher_links_created || 0);
  const teacherLinksRead = Number(summaryTotals?.teacher_links_read || 0);
  const hubViews = Number(summaryTotals?.hub_views || 0);
  const exploreViews = Number(summaryTotals?.explore_views || 0);
  const activationActions = connectionsRequested + mentorshipRequested + teacherLinksCreated;
  const connectionAcceptanceRate = connectionsRequested > 0 ? connectionsAccepted / connectionsRequested : 0;
  const mentorshipAcceptanceRate = mentorshipRequested > 0 ? mentorshipAccepted / mentorshipRequested : 0;
  const teacherLinkReadRate = teacherLinksCreated > 0 ? teacherLinksRead / teacherLinksCreated : 1;

  if (connectionsRequested >= 3 && connectionAcceptanceRate < 0.35) {
    alerts.push({
      code: 'connection_acceptance_low',
      severity: 'high',
      title: 'Connection acceptance rate is low',
      description: 'Bağlantı istekleri gönderiliyor ama kabul oranı beklenen seviyenin altında kaldı.',
      metric: Number((connectionAcceptanceRate * 100).toFixed(2))
    });
  }

  if (mentorshipRequested >= 2 && mentorshipAcceptanceRate < 0.25) {
    alerts.push({
      code: 'mentorship_acceptance_low',
      severity: 'medium',
      title: 'Mentorship acceptance rate is low',
      description: 'Mentorluk talep hacmi var ancak kabul oranı zayıf görünüyor.',
      metric: Number((mentorshipAcceptanceRate * 100).toFixed(2))
    });
  }

  if (teacherLinksCreated >= 1 && teacherLinkReadRate < 0.5) {
    alerts.push({
      code: 'teacher_link_reads_lagging',
      severity: teacherLinksRead === 0 ? 'high' : 'medium',
      title: 'Teacher link read rate is lagging',
      description: 'Öğretmen bağı üretiliyor fakat bildirimlerin okunma oranı düşük; trust feedback görünürlüğü zayıf olabilir.',
      metric: Number((teacherLinkReadRate * 100).toFixed(2))
    });
  }

  const mentorSupplyMap = new Map(
    (mentorSupplyRows || []).map((row) => [String(row?.cohort || '').trim().toLowerCase(), Number(row?.count || 0)])
  );
  const demandGap = (mentorDemandRows || [])
    .map((row) => {
      const cohort = String(row?.cohort || '').trim().toLowerCase();
      const demand = Number(row?.count || 0);
      const supply = Number(mentorSupplyMap.get(cohort) || 0);
      return { cohort, demand, supply, gap: demand - supply };
    })
    .sort((a, b) => b.gap - a.gap)[0];
  if (demandGap && demandGap.gap >= 2) {
    alerts.push({
      code: 'mentor_supply_gap',
      severity: 'medium',
      title: 'Mentor supply is behind demand',
      description: `${demandGap.cohort} cohortunda mentorluk talebi arzın önüne geçti.`,
      metric: demandGap.gap,
      cohort: demandGap.cohort
    });
  }

  if ((hubViews + exploreViews) >= 10 && activationActions === 0) {
    alerts.push({
      code: 'networking_activation_low',
      severity: 'medium',
      title: 'Visibility is not turning into networking actions',
      description: 'Hub ve Explore görüntüleniyor fakat bağlantı, mentorluk veya teacher-link aksiyonları oluşmuyor.',
      metric: hubViews + exploreViews
    });
  }

  return alerts;
}

function parseTelemetryMetadataJson(value) {
  if (!value) return {};
  try {
    const parsed = JSON.parse(String(value || '{}'));
    return parsed && typeof parsed === 'object' ? parsed : {};
  } catch {
    return {};
  }
}

function resolveNetworkSuggestionVariant(value, fallback = 'A') {
  const raw = String(value || fallback || 'A').trim().toUpperCase();
  return raw || 'A';
}

function rateFromCounts(numerator, denominator) {
  const top = Number(numerator || 0);
  const bottom = Number(denominator || 0);
  if (bottom <= 0) return 0;
  return Number((top / bottom).toFixed(4));
}

function parseJsonValue(value, fallback = null) {
  if (!value) return fallback;
  try {
    return JSON.parse(String(value));
  } catch {
    return fallback;
  }
}

function snapshotNetworkSuggestionConfigs(configs = [], variants = []) {
  const variantSet = new Set((variants || []).map((variant) => resolveNetworkSuggestionVariant(variant)));
  return (configs || [])
    .filter((cfg) => variantSet.has(resolveNetworkSuggestionVariant(cfg.variant)))
    .map((cfg) => ({
      variant: resolveNetworkSuggestionVariant(cfg.variant),
      name: String(cfg.name || ''),
      description: String(cfg.description || ''),
      trafficPct: Number(cfg.trafficPct || 0),
      enabled: Number(cfg.enabled || 0) === 1 ? 1 : 0,
      params: { ...(cfg.params || {}) },
      updatedAt: cfg.updatedAt || null
    }))
    .sort((a, b) => String(a.variant).localeCompare(String(b.variant)));
}

function listNetworkSuggestionAbRecentChanges(limit = 8) {
  ensureNetworkSuggestionAbTables();
  const rows = sqlAll(
    `SELECT id, action_type, related_change_id, actor_user_id, recommendation_index, cohort, window_days,
            payload_json, before_snapshot_json, after_snapshot_json, created_at, rolled_back_at, rollback_change_id
     FROM network_suggestion_ab_change_log
     ORDER BY id DESC
     LIMIT ?`,
    [Math.min(Math.max(Number(limit || 8), 1), 20)]
  );
  return rows.map((row) => ({
    id: Number(row.id || 0),
    action_type: String(row.action_type || 'apply'),
    related_change_id: Number(row.related_change_id || 0) || null,
    actor_user_id: Number(row.actor_user_id || 0) || null,
    recommendation_index: Number(row.recommendation_index || 0),
    cohort: String(row.cohort || 'all'),
    window_days: Number(row.window_days || 30),
    payload: parseJsonValue(row.payload_json, {}) || {},
    before_snapshot: parseJsonValue(row.before_snapshot_json, []) || [],
    after_snapshot: parseJsonValue(row.after_snapshot_json, []) || [],
    created_at: row.created_at || null,
    rolled_back_at: row.rolled_back_at || null,
    rollback_change_id: Number(row.rollback_change_id || 0) || null
  }));
}

function pickPrimaryRecommendationVariant(change) {
  return resolveNetworkSuggestionVariant(
    change?.payload?.variant
      || change?.after_snapshot?.[0]?.variant
      || change?.before_snapshot?.[0]?.variant
      || 'A'
  );
}

function toWindowShiftIso(value, daysDelta) {
  const baseMs = toDateMs(value);
  if (baseMs === null) return '';
  return new Date(baseMs + Number(daysDelta || 0) * 24 * 60 * 60 * 1000).toISOString();
}

function buildVariantDelta(beforeRow = {}, afterRow = {}) {
  const beforeActivation = Number(beforeRow?.activation_rate || 0);
  const afterActivation = Number(afterRow?.activation_rate || 0);
  const beforeConnection = Number(beforeRow?.connection_request_rate || 0);
  const afterConnection = Number(afterRow?.connection_request_rate || 0);
  const beforeMentorship = Number(beforeRow?.mentorship_request_rate || 0);
  const afterMentorship = Number(afterRow?.mentorship_request_rate || 0);
  const beforeTeacher = Number(beforeRow?.teacher_link_create_rate || 0);
  const afterTeacher = Number(afterRow?.teacher_link_create_rate || 0);

  const weightedBefore = beforeActivation * 0.55 + beforeConnection * 0.2 + beforeMentorship * 0.15 + beforeTeacher * 0.1;
  const weightedAfter = afterActivation * 0.55 + afterConnection * 0.2 + afterMentorship * 0.15 + afterTeacher * 0.1;
  const weightedDelta = Number((weightedAfter - weightedBefore).toFixed(4));

  let status = 'neutral';
  if (Number(afterRow?.exposure_users || 0) < 1 || Number(beforeRow?.exposure_users || 0) < 1) {
    status = 'insufficient_data';
  } else if (weightedDelta >= 0.03) {
    status = 'positive';
  } else if (weightedDelta <= -0.03) {
    status = 'negative';
  }

  return {
    status,
    weighted_delta: weightedDelta,
    exposure_users_delta: Number(afterRow?.exposure_users || 0) - Number(beforeRow?.exposure_users || 0),
    activation_rate_delta: Number((afterActivation - beforeActivation).toFixed(4)),
    connection_request_rate_delta: Number((afterConnection - beforeConnection).toFixed(4)),
    mentorship_request_rate_delta: Number((afterMentorship - beforeMentorship).toFixed(4)),
    teacher_link_create_rate_delta: Number((afterTeacher - beforeTeacher).toFixed(4))
  };
}

async function evaluateNetworkSuggestionChange(change) {
  if (!change || String(change.action_type || '') !== 'apply') return null;
  const variant = pickPrimaryRecommendationVariant(change);
  const windowDays = Math.max(1, Number(change.window_days || 30));
  const beforeSinceIso = toWindowShiftIso(change.created_at, -windowDays);
  const afterUntilIso = change.rolled_back_at || toWindowShiftIso(change.created_at, windowDays) || new Date().toISOString();
  const effectiveAfterUntilIso = toDateMs(afterUntilIso) !== null && toDateMs(afterUntilIso) < Date.now()
    ? afterUntilIso
    : new Date().toISOString();

  const [beforeDataset, afterDataset] = await Promise.all([
    getNetworkSuggestionExperimentDataset({
      sinceIso: beforeSinceIso,
      untilIso: change.created_at,
      cohort: change.cohort || 'all'
    }),
    getNetworkSuggestionExperimentDataset({
      sinceIso: change.created_at,
      untilIso: effectiveAfterUntilIso,
      cohort: change.cohort || 'all'
    })
  ]);

  const configs = getNetworkSuggestionAbConfigs();
  const beforePerformance = buildNetworkSuggestionExperimentAnalytics({
    exposureRows: beforeDataset.exposureRows,
    actionRows: beforeDataset.actionRows,
    configs,
    assignmentCounts: beforeDataset.assignmentCounts
  });
  const afterPerformance = buildNetworkSuggestionExperimentAnalytics({
    exposureRows: afterDataset.exposureRows,
    actionRows: afterDataset.actionRows,
    configs,
    assignmentCounts: afterDataset.assignmentCounts
  });
  const beforeRow = beforePerformance.variants.find((row) => resolveNetworkSuggestionVariant(row.variant) === variant) || { variant };
  const afterRow = afterPerformance.variants.find((row) => resolveNetworkSuggestionVariant(row.variant) === variant) || { variant };
  const delta = buildVariantDelta(beforeRow, afterRow);

  return {
    variant,
    window_days: windowDays,
    before: beforeRow,
    after: afterRow,
    delta,
    status: delta.status
  };
}

async function listNetworkSuggestionAbRecentChangesWithEvaluation(limit = 8) {
  const changes = listNetworkSuggestionAbRecentChanges(limit);
  const enriched = await Promise.all(changes.map(async (change) => ({
    ...change,
    evaluation: await evaluateNetworkSuggestionChange(change)
  })));
  return enriched;
}

function buildNetworkSuggestionExperimentAnalytics({
  exposureRows = [],
  actionRows = [],
  configs = [],
  assignmentCounts = []
} = {}) {
  const variantMetaMap = new Map((configs || []).map((cfg) => [String(cfg.variant || '').trim().toUpperCase(), cfg]));
  const variants = new Map();

  function ensureVariantBucket(variantKey) {
    const variant = resolveNetworkSuggestionVariant(variantKey);
    if (!variants.has(variant)) {
      const meta = variantMetaMap.get(variant) || {};
      variants.set(variant, {
        variant,
        name: String(meta.name || variant),
        description: String(meta.description || ''),
        traffic_pct: Number(meta.trafficPct || 0),
        enabled: Number(meta.enabled || 0) === 1 ? 1 : 0,
        assignment_count: 0,
        exposure_user_ids: new Set(),
        exposed_user_ids: new Set(),
        activated_user_ids: new Set(),
        follow_user_ids: new Set(),
        connection_user_ids: new Set(),
        mentorship_user_ids: new Set(),
        teacher_link_user_ids: new Set(),
        exposure_events: 0,
        suggestion_impressions: 0,
        action_events: 0,
        actions: {
          follow_created: 0,
          connection_requested: 0,
          mentorship_requested: 0,
          teacher_link_created: 0
        }
      });
    }
    return variants.get(variant);
  }

  for (const cfg of configs || []) {
    ensureVariantBucket(cfg?.variant);
  }

  for (const row of assignmentCounts || []) {
    const bucket = ensureVariantBucket(row?.variant);
    bucket.assignment_count = Number(row?.cnt || 0);
  }

  const exposureTimelineByUser = new Map();
  for (const row of exposureRows || []) {
    const userId = Number(row?.user_id || 0);
    if (!userId) continue;
    const metadata = parseTelemetryMetadataJson(row?.metadata_json);
    const variant = resolveNetworkSuggestionVariant(
      metadata.experiment_variant || metadata.network_suggestion_variant || row?.assigned_variant || 'A'
    );
    const bucket = ensureVariantBucket(variant);
    const suggestionCount = Math.max(0, Number(metadata.suggestion_count || 0));
    const ts = toDateMs(row?.created_at);
    bucket.exposure_events += 1;
    bucket.suggestion_impressions += suggestionCount;
    bucket.exposure_user_ids.add(userId);

    if (!exposureTimelineByUser.has(userId)) exposureTimelineByUser.set(userId, []);
    exposureTimelineByUser.get(userId).push({
      variant,
      ts: ts === null ? Number.MIN_SAFE_INTEGER : ts
    });
  }

  for (const timeline of exposureTimelineByUser.values()) {
    timeline.sort((a, b) => Number(a.ts || 0) - Number(b.ts || 0));
  }

  for (const row of actionRows || []) {
    const userId = Number(row?.user_id || 0);
    if (!userId) continue;
    const timeline = exposureTimelineByUser.get(userId);
    if (!timeline?.length) continue;
    const actionTs = toDateMs(row?.created_at);
    const comparableTs = actionTs === null ? Number.MAX_SAFE_INTEGER : actionTs;
    let attributedExposure = null;
    for (const exposure of timeline) {
      if (Number(exposure.ts || 0) <= comparableTs) attributedExposure = exposure;
      else break;
    }
    if (!attributedExposure) continue;
    const bucket = ensureVariantBucket(attributedExposure.variant);
    const eventName = normalizeNetworkingTelemetryEventName(row?.event_name);
    if (!['follow_created', 'connection_requested', 'mentorship_requested', 'teacher_link_created'].includes(eventName)) continue;
    bucket.action_events += 1;
    bucket.activated_user_ids.add(userId);
    bucket.exposed_user_ids.add(userId);
    bucket.actions[eventName] = Number(bucket.actions[eventName] || 0) + 1;
    if (eventName === 'follow_created') bucket.follow_user_ids.add(userId);
    else if (eventName === 'connection_requested') bucket.connection_user_ids.add(userId);
    else if (eventName === 'mentorship_requested') bucket.mentorship_user_ids.add(userId);
    else if (eventName === 'teacher_link_created') bucket.teacher_link_user_ids.add(userId);
  }

  for (const bucket of variants.values()) {
    for (const userId of bucket.exposure_user_ids) {
      bucket.exposed_user_ids.add(userId);
    }
  }

  const variantRows = Array.from(variants.values()).map((bucket) => {
    const exposureUsers = bucket.exposed_user_ids.size;
    const activatedUsers = bucket.activated_user_ids.size;
    return {
      variant: bucket.variant,
      name: bucket.name,
      description: bucket.description,
      traffic_pct: bucket.traffic_pct,
      enabled: bucket.enabled,
      assignment_count: bucket.assignment_count,
      exposure_users: exposureUsers,
      exposure_events: bucket.exposure_events,
      suggestion_impressions: bucket.suggestion_impressions,
      activated_users: activatedUsers,
      activation_rate: rateFromCounts(activatedUsers, exposureUsers),
      action_events: bucket.action_events,
      follow_created: Number(bucket.actions.follow_created || 0),
      follow_conversion_rate: rateFromCounts(bucket.follow_user_ids.size, exposureUsers),
      connection_requested: Number(bucket.actions.connection_requested || 0),
      connection_request_rate: rateFromCounts(bucket.connection_user_ids.size, exposureUsers),
      mentorship_requested: Number(bucket.actions.mentorship_requested || 0),
      mentorship_request_rate: rateFromCounts(bucket.mentorship_user_ids.size, exposureUsers),
      teacher_link_created: Number(bucket.actions.teacher_link_created || 0),
      teacher_link_create_rate: rateFromCounts(bucket.teacher_link_user_ids.size, exposureUsers)
    };
  }).sort((a, b) => {
    if (Number(b.activation_rate || 0) !== Number(a.activation_rate || 0)) return Number(b.activation_rate || 0) - Number(a.activation_rate || 0);
    if (Number(b.activated_users || 0) !== Number(a.activated_users || 0)) return Number(b.activated_users || 0) - Number(a.activated_users || 0);
    return String(a.variant || '').localeCompare(String(b.variant || ''));
  });

  const leadingVariant = variantRows.find((row) => Number(row.exposure_users || 0) > 0) || null;
  const totalExposureUsers = variantRows.reduce((sum, row) => sum + Number(row.exposure_users || 0), 0);
  const totalExposureEvents = variantRows.reduce((sum, row) => sum + Number(row.exposure_events || 0), 0);

  return {
    assignment_counts: (assignmentCounts || []).map((row) => ({
      variant: resolveNetworkSuggestionVariant(row?.variant),
      count: Number(row?.cnt || 0)
    })),
    total_exposure_users: totalExposureUsers,
    total_exposure_events: totalExposureEvents,
    leading_variant: leadingVariant
      ? {
          variant: leadingVariant.variant,
          activation_rate: leadingVariant.activation_rate,
          activated_users: leadingVariant.activated_users
        }
      : null,
    variants: variantRows
  };
}

const NETWORK_SUGGESTION_APPLY_MIN_EXPOSURE_USERS = 2;
const NETWORK_SUGGESTION_APPLY_COOLDOWN_MS = 10 * 60 * 1000;
const NETWORK_SUGGESTION_APPLY_CONFIRMATION_TOKEN = 'apply';

function buildNetworkSuggestionRecommendationGuardrails(recommendation, performanceByVariant, recentChanges = []) {
  const blockers = [];
  let minimumExposureUsers = 0;
  const touchedVariants = new Set();

  if (recommendation?.patch) touchedVariants.add(resolveNetworkSuggestionVariant(recommendation.variant));
  if (recommendation?.trafficPatch && typeof recommendation.trafficPatch === 'object') {
    for (const variantKey of Object.keys(recommendation.trafficPatch)) {
      touchedVariants.add(resolveNetworkSuggestionVariant(variantKey));
    }
  }

  for (const variant of touchedVariants) {
    const perf = performanceByVariant.get(variant);
    const exposureUsers = Number(perf?.exposure_users || 0);
    minimumExposureUsers = minimumExposureUsers === 0 ? exposureUsers : Math.min(minimumExposureUsers, exposureUsers);
  }

  if (minimumExposureUsers < NETWORK_SUGGESTION_APPLY_MIN_EXPOSURE_USERS) {
    blockers.push(`Minimum ${NETWORK_SUGGESTION_APPLY_MIN_EXPOSURE_USERS} exposure user gereklidir.`);
  }

  const lastApply = (recentChanges || []).find((row) => row?.action_type === 'apply' && !row?.rolled_back_at);
  const lastApplyMs = toDateMs(lastApply?.created_at);
  const cooldownRemainingMs = lastApplyMs !== null
    ? Math.max(0, NETWORK_SUGGESTION_APPLY_COOLDOWN_MS - (Date.now() - lastApplyMs))
    : 0;
  if (cooldownRemainingMs > 0) {
    blockers.push(`Cooldown aktif. Yaklaşık ${Math.ceil(cooldownRemainingMs / 60_000)} dakika bekleyin.`);
  }

  return {
    confirmation_required: true,
    confirmation_token: NETWORK_SUGGESTION_APPLY_CONFIRMATION_TOKEN,
    minimum_exposure_users: NETWORK_SUGGESTION_APPLY_MIN_EXPOSURE_USERS,
    observed_minimum_exposure_users: minimumExposureUsers,
    cooldown_active: cooldownRemainingMs > 0,
    cooldown_remaining_seconds: Math.ceil(cooldownRemainingMs / 1000),
    can_apply: blockers.length === 0,
    blockers
  };
}

function buildNetworkSuggestionAbRecommendations(configs = [], performance = [], recentChanges = []) {
  const perfMap = new Map((performance || []).map((row) => [resolveNetworkSuggestionVariant(row?.variant), row]));
  const configMap = new Map((configs || []).map((cfg) => [resolveNetworkSuggestionVariant(cfg?.variant), cfg]));
  const baseline = perfMap.get('A') || performance?.[0] || null;
  const recommendations = [];

  for (const cfg of (configs || [])) {
    const variant = resolveNetworkSuggestionVariant(cfg?.variant);
    const perf = perfMap.get(variant);
    if (!perf) continue;
    if (Number(perf.exposure_users || 0) < 1) continue;

    const p = cfg.params || networkSuggestionDefaultParams;
    const patch = {};
    const reasons = [];
    const confidenceParts = [];

    if (baseline && baseline.variant !== variant && Number(baseline.exposure_users || 0) >= 1) {
      const baselineActivation = Math.max(Number(baseline.activation_rate || 0), 0.01);
      const baselineConnection = Math.max(Number(baseline.connection_request_rate || 0), 0.01);
      const baselineMentorship = Math.max(Number(baseline.mentorship_request_rate || 0), 0.01);
      const baselineTeacher = Math.max(Number(baseline.teacher_link_create_rate || 0), 0.01);

      const activationDelta = (Number(perf.activation_rate || 0) - baselineActivation) / baselineActivation;
      const connectionDelta = (Number(perf.connection_request_rate || 0) - baselineConnection) / baselineConnection;
      const mentorshipDelta = (Number(perf.mentorship_request_rate || 0) - baselineMentorship) / baselineMentorship;
      const teacherDelta = (Number(perf.teacher_link_create_rate || 0) - baselineTeacher) / baselineTeacher;

      if (activationDelta < -0.12) {
        patch.secondDegreeWeight = round2(p.secondDegreeWeight * 1.06);
        patch.sharedGroupWeight = round2(p.sharedGroupWeight * 1.08);
        if (Number(p.engagementWeight || 0) > 0.12) patch.engagementWeight = round2(p.engagementWeight * 0.9);
        reasons.push(`Aktivasyon oranı baseline'ın gerisinde (${round2(activationDelta * 100)}%).`);
        confidenceParts.push(Math.min(0.35, Math.abs(activationDelta)));
      } else if (activationDelta > 0.1) {
        reasons.push(`Aktivasyon oranı baseline'ın üzerinde (${round2(activationDelta * 100)}%).`);
        confidenceParts.push(Math.min(0.28, activationDelta));
      }

      if (connectionDelta > 0.12) {
        patch.secondDegreeWeight = round2((patch.secondDegreeWeight || p.secondDegreeWeight) * 1.04);
        patch.maxSecondDegreeBonus = round2((patch.maxSecondDegreeBonus || p.maxSecondDegreeBonus) * 1.03);
        reasons.push('Bağlantı isteği dönüşümü güçlü; graph yakınlığı biraz daha öne çıkarılabilir.');
        confidenceParts.push(Math.min(0.2, connectionDelta));
      }

      if (mentorshipDelta > 0.12) {
        patch.directMentorshipBonus = round2((patch.directMentorshipBonus || p.directMentorshipBonus) * 1.05);
        patch.mentorshipOverlapWeight = round2((patch.mentorshipOverlapWeight || p.mentorshipOverlapWeight) * 1.04);
        reasons.push('Mentorluk talebi üretimi güçlü; mentorluk sinyalleri korunup hafif artırılabilir.');
        confidenceParts.push(Math.min(0.2, mentorshipDelta));
      }

      if (teacherDelta > 0.12) {
        patch.directTeacherBonus = round2((patch.directTeacherBonus || p.directTeacherBonus) * 1.05);
        patch.teacherOverlapWeight = round2((patch.teacherOverlapWeight || p.teacherOverlapWeight) * 1.04);
        reasons.push('Teacher network aksiyonları güçlü; öğretmen yakınlığı sinyali biraz daha artırılabilir.');
        confidenceParts.push(Math.min(0.2, teacherDelta));
      }
    }

    if (Number(perf.follow_conversion_rate || 0) > 0.2 && Number(perf.connection_request_rate || 0) < 0.08) {
      patch.secondDegreeWeight = round2((patch.secondDegreeWeight || p.secondDegreeWeight) * 1.04);
      patch.sharedGroupWeight = round2((patch.sharedGroupWeight || p.sharedGroupWeight) * 1.04);
      reasons.push('Follow dönüşümü var ama daha derin networking aksiyonları düşük; graph sinyalleri hafif güçlendirilebilir.');
      confidenceParts.push(0.12);
    }

    const normalizedPatch = normalizeNetworkSuggestionParams(
      { ...p, ...patch },
      networkSuggestionDefaultVariants[variant]?.params || networkSuggestionDefaultParams
    );
    const finalPatch = {};
    for (const key of Object.keys(p)) {
      if (Number(normalizedPatch[key]) !== Number(p[key])) finalPatch[key] = normalizedPatch[key];
    }
    if (!Object.keys(finalPatch).length) continue;

    const sampleFactor = Math.min(1, Number(perf.exposure_users || 0) / 40);
    const confidence = round2(clamp(0.18 + confidenceParts.reduce((sum, value) => sum + value, 0) + sampleFactor * 0.32, 0, 0.9));
    const recommendation = {
      variant,
      confidence,
      reasons: reasons.slice(0, 4),
      patch: finalPatch
    };
    recommendation.guardrails = buildNetworkSuggestionRecommendationGuardrails(recommendation, perfMap, recentChanges);
    recommendations.push(recommendation);
  }

  const activeConfigs = (configs || []).filter((cfg) => Number(cfg.enabled || 0) === 1);
  if (activeConfigs.length >= 2) {
    const scored = activeConfigs
      .map((cfg) => {
        const perf = perfMap.get(resolveNetworkSuggestionVariant(cfg.variant));
        if (!perf || Number(perf.exposure_users || 0) < 1) return null;
        const quality = Number(perf.activation_rate || 0) * 0.55
          + Number(perf.connection_request_rate || 0) * 0.2
          + Number(perf.mentorship_request_rate || 0) * 0.15
          + Number(perf.teacher_link_create_rate || 0) * 0.1;
        return { variant: resolveNetworkSuggestionVariant(cfg.variant), quality, exposureUsers: Number(perf.exposure_users || 0) };
      })
      .filter(Boolean)
      .sort((a, b) => Number(b.quality || 0) - Number(a.quality || 0));

    if (scored.length >= 2 && Number(scored[0].quality || 0) > Number(scored[1].quality || 0) * 1.08) {
      const winner = configMap.get(scored[0].variant);
      const loser = configMap.get(scored[scored.length - 1].variant);
      if (winner && loser) {
        const recommendation = {
          variant: scored[0].variant,
          confidence: round2(clamp(0.24 + Math.min(0.35, Number(scored[0].quality || 0) - Number(scored[1].quality || 0)), 0, 0.82)),
          reasons: [`${scored[0].variant} varyantı recommendation quality metriğinde daha güçlü performans gösteriyor.`],
          trafficPatch: {
            [scored[0].variant]: clamp(Number(winner.trafficPct || 0) + 5, 0, 100),
            [scored[scored.length - 1].variant]: clamp(Number(loser.trafficPct || 0) - 5, 0, 100)
          }
        };
        recommendation.guardrails = buildNetworkSuggestionRecommendationGuardrails(recommendation, perfMap, recentChanges);
        recommendations.push(recommendation);
      }
    }
  }

  return recommendations;
}

async function getNetworkSuggestionExperimentDataset({ sinceIso, untilIso = '', cohort = 'all' } = {}) {
  ensureNetworkingTelemetryEventsTable();
  ensureNetworkSuggestionAbTables();
  const includeCohort = String(cohort || 'all').trim().toLowerCase() !== 'all';
  const normalizedCohort = normalizeCohortValue(cohort);
  const includeUpperBound = Boolean(untilIso);
  const telemetryCohortSql = includeCohort
    ? "AND LOWER(COALESCE(NULLIF(CAST(u.mezuniyetyili AS TEXT), ''), 'unknown')) = LOWER(?)"
    : '';
  const telemetryUpperSql = includeUpperBound ? 'AND e.created_at < ?' : '';
  const telemetryParams = includeCohort
    ? (includeUpperBound ? [sinceIso, untilIso, normalizedCohort] : [sinceIso, normalizedCohort])
    : (includeUpperBound ? [sinceIso, untilIso] : [sinceIso]);
  const assignmentParams = includeCohort ? [normalizedCohort] : [];
  const assignmentWhere = includeCohort
    ? "WHERE LOWER(COALESCE(NULLIF(CAST(u.mezuniyetyili AS TEXT), ''), 'unknown')) = LOWER(?)"
    : '';

  const [exposureRows, actionRows, assignmentCounts] = await Promise.all([
    sqlAllAsync(
      `SELECT e.user_id, e.event_name, e.metadata_json, e.created_at, a.variant AS assigned_variant
       FROM networking_telemetry_events e
       LEFT JOIN network_suggestion_ab_assignments a ON a.user_id = e.user_id
       LEFT JOIN uyeler u ON u.id = e.user_id
       WHERE e.created_at >= ?
         ${telemetryUpperSql}
         AND e.event_name IN ('network_hub_suggestions_loaded', 'network_explore_suggestions_loaded')
         ${telemetryCohortSql}
       ORDER BY e.user_id ASC, e.created_at ASC`,
      telemetryParams
    ),
    sqlAllAsync(
      `SELECT e.user_id, e.event_name, e.metadata_json, e.created_at, a.variant AS assigned_variant
       FROM networking_telemetry_events e
       LEFT JOIN network_suggestion_ab_assignments a ON a.user_id = e.user_id
       LEFT JOIN uyeler u ON u.id = e.user_id
       WHERE e.created_at >= ?
         ${telemetryUpperSql}
         AND e.event_name IN ('follow_created', 'connection_requested', 'mentorship_requested', 'teacher_link_created')
         ${telemetryCohortSql}
       ORDER BY e.user_id ASC, e.created_at ASC`,
      telemetryParams
    ),
    sqlAllAsync(
      `SELECT a.variant, COUNT(*) AS cnt
       FROM network_suggestion_ab_assignments a
       LEFT JOIN uyeler u ON u.id = a.user_id
       ${assignmentWhere}
       GROUP BY a.variant
       ORDER BY a.variant ASC`,
      assignmentParams
    )
  ]);

  return { exposureRows, actionRows, assignmentCounts };
}

function recordNetworkingTelemetryEvent({
  userId = null,
  eventName = '',
  sourceSurface = 'server_action',
  targetUserId = null,
  entityType = '',
  entityId = null,
  metadata = null,
  createdAt = null
} = {}) {
  const normalizedEventName = normalizeNetworkingTelemetryEventName(eventName);
  if (!normalizedEventName) return;
  ensureNetworkingTelemetryEventsTable();
  let metadataJson = null;
  if (metadata && typeof metadata === 'object') {
    try {
      metadataJson = JSON.stringify(metadata).slice(0, 4000);
    } catch {
      metadataJson = null;
    }
  }
  sqlRun(
    `INSERT INTO networking_telemetry_events
       (user_id, event_name, source_surface, target_user_id, entity_type, entity_id, metadata_json, created_at)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
    [
      Number(userId || 0) || null,
      normalizedEventName,
      normalizeNetworkingTelemetrySourceSurface(sourceSurface),
      Number(targetUserId || 0) || null,
      normalizeNetworkingTelemetryEntityType(entityType) || null,
      Number(entityId || 0) || null,
      metadataJson,
      createdAt || new Date().toISOString()
    ]
  );
}

function clampTeacherLinkConfidenceScore(value) {
  const numeric = Number(value || 0);
  if (!Number.isFinite(numeric)) return 0.05;
  return Math.max(0.05, Math.min(0.99, numeric));
}

function roundTeacherLinkConfidenceScore(value) {
  return Number(clampTeacherLinkConfidenceScore(value).toFixed(2));
}

function computeTeacherLinkConfidenceScore(row, duplicateProximityCount = 0) {
  let score = 0.52;
  const createdVia = normalizeTeacherLinkCreatedVia(row?.created_via);
  const sourceSurface = normalizeTeacherLinkSourceSurface(row?.source_surface);
  const reviewStatus = normalizeTeacherLinkReviewStatus(row?.review_status) || 'pending';
  const teacherRole = String(row?.teacher_role || '').trim().toLowerCase();
  const teacherCohort = normalizeCohortValue(row?.teacher_cohort);

  if (createdVia === 'manual_alumni_link') score += 0.08;
  if (createdVia === 'import') score += 0.03;

  if (sourceSurface === 'member_detail_page') score += 0.08;
  else if (sourceSurface === 'teachers_network_page') score += 0.04;
  else if (sourceSurface === 'network_hub') score += 0.03;

  if (Number(row?.teacher_verified || 0) === 1 || teacherRole === 'teacher' || teacherCohort === TEACHER_COHORT_VALUE || roleAtLeast(teacherRole, 'admin')) {
    score += 0.16;
  }
  if (Number(row?.alumni_verified || 0) === 1) score += 0.06;
  if (row?.class_year !== null && row?.class_year !== undefined && String(row.class_year).trim() !== '') score += 0.05;
  if (String(row?.notes || '').trim().length >= 12) score += 0.04;
  if (String(row?.relationship_type || '').trim().toLowerCase() === 'mentor') score += 0.05;

  if (reviewStatus === 'confirmed') score += 0.18;
  if (reviewStatus === 'flagged') score -= 0.28;

  const duplicatePenalty = Math.min(0.25, Math.max(0, Number(duplicateProximityCount || 0)) * 0.09);
  score -= duplicatePenalty;

  return roundTeacherLinkConfidenceScore(score);
}

function isTeacherLinkActiveStatus(value) {
  const status = normalizeTeacherLinkReviewStatus(value) || 'pending';
  return status !== 'rejected' && status !== 'merged';
}

function canTransitionTeacherLinkReviewStatus(currentStatus, nextStatus) {
  const current = normalizeTeacherLinkReviewStatus(currentStatus) || 'pending';
  const next = normalizeTeacherLinkReviewStatus(nextStatus);
  if (!next) return false;
  const allowedTransitions = {
    pending: ['confirmed', 'flagged', 'rejected', 'merged'],
    confirmed: ['pending', 'flagged', 'rejected', 'merged'],
    flagged: ['pending', 'confirmed', 'rejected', 'merged'],
    rejected: ['pending', 'confirmed', 'flagged'],
    merged: ['pending', 'confirmed', 'flagged']
  };
  return allowedTransitions[current]?.includes(next) || false;
}

function selectTeacherLinkMergeTarget(linkId, teacherUserId, alumniUserId, requestedTargetId = 0) {
  const safeLinkId = Number(linkId || 0);
  const safeTeacherUserId = Number(teacherUserId || 0);
  const safeAlumniUserId = Number(alumniUserId || 0);
  const safeRequestedTargetId = Number(requestedTargetId || 0);
  if (!safeLinkId || !safeTeacherUserId || !safeAlumniUserId) return null;

  if (safeRequestedTargetId > 0 && safeRequestedTargetId !== safeLinkId) {
    return sqlGet(
      `SELECT id, review_status
       FROM teacher_alumni_links
       WHERE id = ?
         AND teacher_user_id = ?
         AND alumni_user_id = ?
         AND COALESCE(review_status, 'pending') NOT IN ('rejected', 'merged')
       LIMIT 1`,
      [safeRequestedTargetId, safeTeacherUserId, safeAlumniUserId]
    ) || null;
  }

  return sqlGet(
    `SELECT id, review_status
     FROM teacher_alumni_links
     WHERE teacher_user_id = ?
       AND alumni_user_id = ?
       AND id <> ?
       AND COALESCE(review_status, 'pending') NOT IN ('rejected', 'merged')
     ORDER BY CASE WHEN COALESCE(review_status, 'pending') = 'confirmed' THEN 0 ELSE 1 END ASC,
              COALESCE(confidence_score, 0) DESC,
              COALESCE(CASE WHEN CAST(created_at AS TEXT) = '' THEN NULL ELSE created_at END, '1970-01-01T00:00:00.000Z') DESC,
              id DESC
     LIMIT 1`,
    [safeTeacherUserId, safeAlumniUserId, safeLinkId]
  ) || null;
}

function logTeacherLinkModerationEvent({ linkId, actorUserId = null, eventType, fromStatus = '', toStatus = '', note = '', mergeTargetId = null }) {
  const safeLinkId = Number(linkId || 0);
  const safeMergeTargetId = Number(mergeTargetId || 0) || null;
  const safeEventType = String(eventType || '').trim().slice(0, 64);
  if (!safeLinkId || !safeEventType) return;
  ensureTeacherAlumniLinkModerationEventsTable();
  sqlRun(
    `INSERT INTO teacher_alumni_link_moderation_events
       (link_id, actor_user_id, event_type, from_status, to_status, note, merge_target_id, created_at)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
    [
      safeLinkId,
      Number(actorUserId || 0) || null,
      safeEventType,
      normalizeTeacherLinkReviewStatus(fromStatus) || null,
      normalizeTeacherLinkReviewStatus(toStatus) || null,
      normalizeTeacherLinkReviewNote(note) || null,
      safeMergeTargetId,
      new Date().toISOString()
    ]
  );
}

function buildTeacherLinkModerationAssessment(row) {
  const reviewStatus = normalizeTeacherLinkReviewStatus(row?.review_status) || 'pending';
  const confidenceScore = Number(row?.confidence_score || 0);
  const noteLength = String(row?.notes || '').trim().length;
  const classYearPresent = row?.class_year !== null && row?.class_year !== undefined && String(row.class_year).trim() !== '';
  const duplicateActiveCount = Math.max(0, Number(row?.active_pair_link_count || 0) - 1);
  const teacherVerified = Number(row?.teacher_verified || 0) === 1;
  const alumniVerified = Number(row?.alumni_verified || 0) === 1;
  const createdVia = normalizeTeacherLinkCreatedVia(row?.created_via);
  const sourceSurface = normalizeTeacherLinkSourceSurface(row?.source_surface);

  const riskSignals = [];
  const positiveSignals = [];
  let riskScore = 0;

  if (confidenceScore < 0.45) {
    riskSignals.push({ code: 'low_confidence', label: 'Confidence score is low', severity: 'high' });
    riskScore += 3;
  } else if (confidenceScore < 0.65) {
    riskSignals.push({ code: 'medium_confidence', label: 'Confidence score needs review', severity: 'medium' });
    riskScore += 1;
  } else {
    positiveSignals.push({ code: 'healthy_confidence', label: 'Confidence score is strong' });
  }

  if (!classYearPresent) {
    riskSignals.push({ code: 'missing_class_year', label: 'Class year is missing', severity: 'medium' });
    riskScore += 1;
  } else {
    positiveSignals.push({ code: 'class_year_present', label: 'Class year is provided' });
  }

  if (noteLength === 0) {
    riskSignals.push({ code: 'missing_notes', label: 'No supporting note was added', severity: 'high' });
    riskScore += 2;
  } else if (noteLength < 12) {
    riskSignals.push({ code: 'short_notes', label: 'Supporting note is very short', severity: 'medium' });
    riskScore += 1;
  } else {
    positiveSignals.push({ code: 'detailed_notes', label: 'Supporting note adds context' });
  }

  if (duplicateActiveCount > 0) {
    riskSignals.push({ code: 'duplicate_active_pair', label: 'Another active link exists for the same teacher-alumni pair', severity: 'high' });
    riskScore += 3;
  } else {
    positiveSignals.push({ code: 'single_active_pair_record', label: 'No competing active duplicate exists' });
  }

  if (teacherVerified) positiveSignals.push({ code: 'teacher_verified', label: 'Teacher account is verified' });
  else {
    riskSignals.push({ code: 'teacher_unverified', label: 'Teacher account is not verified', severity: 'medium' });
    riskScore += 1;
  }

  if (alumniVerified) positiveSignals.push({ code: 'alumni_verified', label: 'Alumni account is verified' });
  else {
    riskSignals.push({ code: 'alumni_unverified', label: 'Alumni account is not verified', severity: 'medium' });
    riskScore += 1;
  }

  if (createdVia === 'import') {
    riskSignals.push({ code: 'imported_record', label: 'Record came from import flow', severity: 'medium' });
    riskScore += 1;
  } else {
    positiveSignals.push({ code: 'manual_submission', label: 'Record was submitted manually' });
  }

  if (sourceSurface === 'member_detail_page') {
    positiveSignals.push({ code: 'contextual_source_surface', label: 'Created from a contextual member detail flow' });
  }

  if (reviewStatus === 'flagged') {
    riskSignals.push({ code: 'previously_flagged', label: 'Record is already flagged', severity: 'high' });
    riskScore += 2;
  }

  const riskLevel = riskScore >= 6 ? 'high' : riskScore >= 3 ? 'medium' : 'low';
  let recommendedAction = 'keep_pending';
  let recommendationLabel = 'Keep pending';
  let decisionHint = 'Needs another moderation pass.';

  if (reviewStatus === 'merged') {
    recommendedAction = 'keep_merged';
    recommendationLabel = 'Keep merged';
    decisionHint = 'This record is already merged into another active link.';
  } else if (reviewStatus === 'rejected') {
    recommendedAction = 'keep_rejected';
    recommendationLabel = 'Keep rejected';
    decisionHint = 'This record is already removed from the active graph.';
  } else if (duplicateActiveCount > 0) {
    recommendedAction = 'merge';
    recommendationLabel = 'Merge';
    decisionHint = 'A duplicate active pair exists. Prefer merging instead of keeping two active claims.';
  } else if (confidenceScore >= 0.75 && teacherVerified && alumniVerified && (classYearPresent || noteLength >= 12)) {
    recommendedAction = 'confirm';
    recommendationLabel = 'Confirm';
    decisionHint = 'Core trust signals are present and the record looks safe to confirm.';
  } else if (riskLevel === 'high' && (!classYearPresent || noteLength === 0)) {
    recommendedAction = 'reject';
    recommendationLabel = 'Reject';
    decisionHint = 'Critical trust signals are missing. Reject unless stronger evidence is provided.';
  } else if (riskLevel === 'high' || confidenceScore < 0.55 || reviewStatus === 'flagged') {
    recommendedAction = 'flag';
    recommendationLabel = 'Flag';
    decisionHint = 'Signals are weak or conflicting. Escalate for closer review.';
  }

  return {
    risk_level: riskLevel,
    risk_score: riskScore,
    duplicate_active_count: duplicateActiveCount,
    recommended_action: recommendedAction,
    recommended_action_label: recommendationLabel,
    decision_hint: decisionHint,
    risk_signals: riskSignals,
    positive_signals: positiveSignals
  };
}

function refreshTeacherLinkConfidenceScore(linkId) {
  const safeLinkId = Number(linkId || 0);
  if (!safeLinkId) return 0;
  const row = sqlGet(
    `SELECT l.id, l.teacher_user_id, l.alumni_user_id, l.relationship_type, l.class_year, l.notes,
            COALESCE(l.created_via, 'manual_alumni_link') AS created_via,
            COALESCE(l.source_surface, 'teachers_network_page') AS source_surface,
            COALESCE(l.review_status, 'pending') AS review_status,
            teacher.verified AS teacher_verified,
            teacher.role AS teacher_role,
            teacher.mezuniyetyili AS teacher_cohort,
            alumni.verified AS alumni_verified
     FROM teacher_alumni_links l
     LEFT JOIN uyeler teacher ON teacher.id = l.teacher_user_id
     LEFT JOIN uyeler alumni ON alumni.id = l.alumni_user_id
     WHERE l.id = ?`,
    [safeLinkId]
  );
  if (!row) return 0;

  const duplicateProximityCount = Number(sqlGet(
    `SELECT COUNT(*) AS cnt
     FROM teacher_alumni_links
     WHERE teacher_user_id = ?
       AND alumni_user_id = ?
       AND id <> ?
       AND COALESCE(review_status, 'pending') NOT IN ('rejected', 'merged')`,
    [row.teacher_user_id, row.alumni_user_id, safeLinkId]
  )?.cnt || 0);

  const nextScore = computeTeacherLinkConfidenceScore(row, duplicateProximityCount);
  sqlRun('UPDATE teacher_alumni_links SET confidence_score = ? WHERE id = ?', [nextScore, safeLinkId]);
  return nextScore;
}

function listTeacherLinkPairDuplicates(alumniUserId, teacherUserId) {
  const safeAlumniUserId = Number(alumniUserId || 0);
  const safeTeacherUserId = Number(teacherUserId || 0);
  if (!safeAlumniUserId || !safeTeacherUserId) return [];
  return sqlAll(
    `SELECT id, relationship_type, class_year, notes, created_at,
            COALESCE(review_status, 'pending') AS review_status,
            confidence_score
     FROM teacher_alumni_links
     WHERE alumni_user_id = ?
       AND teacher_user_id = ?
       AND COALESCE(review_status, 'pending') NOT IN ('rejected', 'merged')
     ORDER BY COALESCE(CASE WHEN CAST(created_at AS TEXT) = '' THEN NULL ELSE created_at END, '1970-01-01T00:00:00.000Z') DESC, id DESC`,
    [safeAlumniUserId, safeTeacherUserId]
  ) || [];
}

function ensureJobApplicationsTable() {
  sqlRun(`
    CREATE TABLE IF NOT EXISTS job_applications (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      job_id INTEGER NOT NULL,
      applicant_id INTEGER NOT NULL,
      cover_letter TEXT,
      status TEXT NOT NULL DEFAULT 'pending',
      reviewed_at TEXT,
      reviewed_by INTEGER,
      decision_note TEXT,
      created_at TEXT NOT NULL,
      UNIQUE(job_id, applicant_id)
    )
  `);
  if (!hasColumn('job_applications', 'status')) {
    try {
      sqlRun("ALTER TABLE job_applications ADD COLUMN status TEXT NOT NULL DEFAULT 'pending'");
    } catch {}
  }
  if (!hasColumn('job_applications', 'reviewed_at')) {
    try {
      sqlRun('ALTER TABLE job_applications ADD COLUMN reviewed_at TEXT');
    } catch {}
  }
  if (!hasColumn('job_applications', 'reviewed_by')) {
    try {
      sqlRun('ALTER TABLE job_applications ADD COLUMN reviewed_by INTEGER');
    } catch {}
  }
  if (!hasColumn('job_applications', 'decision_note')) {
    try {
      sqlRun('ALTER TABLE job_applications ADD COLUMN decision_note TEXT');
    } catch {}
  }
  sqlRun('CREATE INDEX IF NOT EXISTS idx_job_applications_job ON job_applications (job_id, created_at DESC)');
  sqlRun('CREATE INDEX IF NOT EXISTS idx_job_applications_applicant ON job_applications (applicant_id, created_at DESC)');
}

app.post('/api/new/connections/request/:id', requireAuth, connectionRequestRateLimit, (req, res) => {
  if (!ensureVerifiedSocialHubMember(req, res)) return;
  ensureConnectionRequestsTable();
  const senderId = Number(req.session?.userId || 0);
  const receiverId = Number(req.params.id || 0);
  if (!senderId || !receiverId) return sendApiError(res, 400, 'INVALID_USER_ID', 'Geçersiz kullanıcı kimliği.');
  if (senderId === receiverId) return sendApiError(res, 400, 'SELF_CONNECTION_NOT_ALLOWED', 'Kendine bağlantı isteği gönderemezsin.');

  const receiver = sqlGet('SELECT id FROM uyeler WHERE id = ?', [receiverId]);
  if (!receiver) return sendApiError(res, 404, 'MEMBER_NOT_FOUND', 'Üye bulunamadı.');

  const existingFollow = sqlGet('SELECT id FROM follows WHERE follower_id = ? AND following_id = ?', [senderId, receiverId]);
  const reverseFollow = sqlGet('SELECT id FROM follows WHERE follower_id = ? AND following_id = ?', [receiverId, senderId]);
  if (existingFollow && reverseFollow) {
    return sendApiError(res, 409, 'ALREADY_CONNECTED', 'Bu üye ile zaten bağlantısınız.');
  }

  const outgoingPending = sqlGet(
    `SELECT id
     FROM connection_requests
     WHERE sender_id = ?
       AND receiver_id = ?
       AND LOWER(TRIM(COALESCE(status, ''))) = 'pending'
     ORDER BY COALESCE(CASE WHEN CAST(updated_at AS TEXT) = '' THEN NULL ELSE updated_at END, created_at) DESC, id DESC
     LIMIT 1`,
    [senderId, receiverId]
  );
  if (outgoingPending) {
    return sendApiError(res, 409, 'REQUEST_ALREADY_PENDING', 'Bu üyeye zaten bekleyen bir bağlantı isteği gönderdiniz.');
  }

  const incomingPending = sqlGet(
    `SELECT id
     FROM connection_requests
     WHERE sender_id = ?
       AND receiver_id = ?
       AND LOWER(TRIM(COALESCE(status, ''))) = 'pending'
     ORDER BY COALESCE(CASE WHEN CAST(updated_at AS TEXT) = '' THEN NULL ELSE updated_at END, created_at) DESC, id DESC
     LIMIT 1`,
    [receiverId, senderId]
  );
  if (incomingPending) {
    return sendApiError(res, 409, 'REQUEST_PENDING_FROM_TARGET', 'Bu üyeden bekleyen bir bağlantı isteğiniz var. Kabul edebilirsiniz.');
  }

  const latestOutgoing = sqlGet(
    `SELECT id, status, updated_at, responded_at
     FROM connection_requests
     WHERE sender_id = ? AND receiver_id = ?
     ORDER BY COALESCE(CASE WHEN CAST(updated_at AS TEXT) = '' THEN NULL ELSE updated_at END, created_at) DESC, id DESC
     LIMIT 1`,
    [senderId, receiverId]
  );
  const latestOutgoingStatus = String(latestOutgoing?.status || '').toLowerCase();
  if (latestOutgoing && latestOutgoingStatus === 'ignored') {
    const remainingSeconds = calculateCooldownRemainingSeconds(
      latestOutgoing.responded_at || latestOutgoing.updated_at,
      CONNECTION_REQUEST_COOLDOWN_SECONDS
    );
    if (remainingSeconds > 0) {
      res.setHeader('Retry-After', String(remainingSeconds));
      return sendApiError(
        res,
        429,
        'REQUEST_COOLDOWN_ACTIVE',
        'Bu üyeye tekrar bağlantı isteği göndermek için biraz beklemelisin.',
        { retry_after_seconds: remainingSeconds },
        { retry_after_seconds: remainingSeconds }
      );
    }
  }

  const now = new Date().toISOString();
  let requestId = 0;
  if (latestOutgoing) {
    sqlRun('UPDATE connection_requests SET status = ?, updated_at = ?, responded_at = NULL WHERE id = ?', ['pending', now, latestOutgoing.id]);
    requestId = Number(latestOutgoing.id || 0);
  } else {
    const result = sqlRun(
      'INSERT INTO connection_requests (sender_id, receiver_id, status, created_at, updated_at) VALUES (?, ?, ?, ?, ?)',
      [senderId, receiverId, 'pending', now, now]
    );
    requestId = Number(result?.lastInsertRowid || 0);
  }

  addNotification({
    userId: receiverId,
    type: 'connection_request',
    sourceUserId: senderId,
    entityId: requestId,
    message: 'Sana bir bağlantı isteği gönderdi.'
  });
  recordNetworkingTelemetryEvent({
    userId: senderId,
    eventName: 'connection_requested',
    sourceSurface: req.body?.source_surface,
    targetUserId: receiverId,
    entityType: 'connection_request',
    entityId: requestId
  });

  return res.json(apiSuccessEnvelope(
    'CONNECTION_REQUEST_CREATED',
    'Yeni bağlantı isteği gönderildi.',
    { status: 'pending', request_id: requestId },
    { status: 'pending', request_id: requestId }
  ));
});

app.get('/api/new/connections/requests', requireAuth, async (req, res) => {
  ensureConnectionRequestsTable();
  const userId = Number(req.session?.userId || 0);
  const status = normalizeConnectionStatus(req.query.status) || 'pending';
  const direction = String(req.query.direction || 'incoming').trim().toLowerCase() === 'outgoing' ? 'outgoing' : 'incoming';
  const limit = Math.min(Math.max(parseInt(req.query.limit || '30', 10), 1), 100);
  const offset = Math.max(parseInt(req.query.offset || '0', 10), 0);

  const whereClause = direction === 'incoming' ? 'cr.receiver_id = ?' : 'cr.sender_id = ?';
  const joinClause = direction === 'incoming'
    ? 'LEFT JOIN uyeler u ON u.id = cr.sender_id'
    : 'LEFT JOIN uyeler u ON u.id = cr.receiver_id';

  try {
    const rows = await sqlAllAsync(
      `SELECT cr.id, cr.sender_id, cr.receiver_id, cr.status, cr.created_at, cr.updated_at, cr.responded_at,
              u.kadi, u.isim, u.soyisim, u.resim, u.verified
       FROM connection_requests cr
       ${joinClause}
       WHERE ${whereClause} AND cr.status = ?
       ORDER BY COALESCE(CASE WHEN CAST(cr.updated_at AS TEXT) = '' THEN NULL ELSE cr.updated_at END, cr.created_at) DESC, cr.id DESC
       LIMIT ? OFFSET ?`,
      [userId, status, limit, offset]
    );
    const payload = { items: rows, hasMore: rows.length === limit, direction, status };
    return res.json(apiSuccessEnvelope('CONNECTION_REQUESTS_LIST_OK', 'Bağlantı istekleri listelendi.', payload, payload));
  } catch (err) {
    console.error('connections.requests failed:', err);
    return sendApiError(res, 500, 'CONNECTION_REQUESTS_LIST_FAILED', 'Beklenmeyen bir hata oluştu.');
  }
});

app.post('/api/new/connections/accept/:id', requireAuth, (req, res) => {
  ensureConnectionRequestsTable();
  const requestId = Number(req.params.id || 0);
  const currentUserId = Number(req.session?.userId || 0);
  if (!requestId || !currentUserId) return sendApiError(res, 400, 'INVALID_CONNECTION_REQUEST_ID', 'Geçersiz istek kimliği.');

  const row = sqlGet('SELECT id, sender_id, receiver_id, status FROM connection_requests WHERE id = ?', [requestId]);
  if (!row) return sendApiError(res, 404, 'CONNECTION_REQUEST_NOT_FOUND', 'Bağlantı isteği bulunamadı.');
  if (Number(row.receiver_id) !== currentUserId) return sendApiError(res, 403, 'CONNECTION_REQUEST_FORBIDDEN', 'Bu bağlantı isteğini yönetemezsiniz.');
  if (String(row.status || '').toLowerCase() !== 'pending') return sendApiError(res, 409, 'CONNECTION_REQUEST_NOT_PENDING', 'Bağlantı isteği artık beklemede değil.');

  const now = new Date().toISOString();
  sqlRun('UPDATE connection_requests SET status = ?, updated_at = ?, responded_at = ? WHERE id = ?', ['accepted', now, now, requestId]);

  const senderId = Number(row.sender_id);
  const receiverId = Number(row.receiver_id);

  const senderToReceiver = sqlGet('SELECT id FROM follows WHERE follower_id = ? AND following_id = ?', [senderId, receiverId]);
  if (!senderToReceiver) {
    sqlRun('INSERT INTO follows (follower_id, following_id, created_at) VALUES (?, ?, ?)', [senderId, receiverId, now]);
  }
  const receiverToSender = sqlGet('SELECT id FROM follows WHERE follower_id = ? AND following_id = ?', [receiverId, senderId]);
  if (!receiverToSender) {
    sqlRun('INSERT INTO follows (follower_id, following_id, created_at) VALUES (?, ?, ?)', [receiverId, senderId, now]);
  }

  addNotification({
    userId: senderId,
    type: 'connection_accepted',
    sourceUserId: receiverId,
    entityId: requestId,
    message: 'Bağlantı isteğini kabul etti.'
  });
  recordNetworkingTelemetryEvent({
    userId: receiverId,
    eventName: 'connection_accepted',
    sourceSurface: req.body?.source_surface,
    targetUserId: senderId,
    entityType: 'connection_request',
    entityId: requestId
  });

  exploreSuggestionsResponseCache.clear();
  scheduleEngagementRecalculation('follow_changed');
  invalidateCacheNamespace(cacheNamespaces.feed);

  return res.json(apiSuccessEnvelope(
    'CONNECTION_REQUEST_ACCEPTED',
    'Bağlantı isteği kabul edildi.',
    { status: 'accepted', request_id: requestId },
    { status: 'accepted', request_id: requestId }
  ));
});

app.post('/api/new/connections/ignore/:id', requireAuth, (req, res) => {
  ensureConnectionRequestsTable();
  const requestId = Number(req.params.id || 0);
  const currentUserId = Number(req.session?.userId || 0);
  if (!requestId || !currentUserId) return sendApiError(res, 400, 'INVALID_CONNECTION_REQUEST_ID', 'Geçersiz istek kimliği.');

  const row = sqlGet('SELECT id, sender_id, receiver_id, status FROM connection_requests WHERE id = ?', [requestId]);
  if (!row) return sendApiError(res, 404, 'CONNECTION_REQUEST_NOT_FOUND', 'Bağlantı isteği bulunamadı.');
  if (Number(row.receiver_id) !== currentUserId) return sendApiError(res, 403, 'CONNECTION_REQUEST_FORBIDDEN', 'Bu bağlantı isteğini yönetemezsiniz.');
  if (String(row.status || '').toLowerCase() !== 'pending') return sendApiError(res, 409, 'CONNECTION_REQUEST_NOT_PENDING', 'Bağlantı isteği artık beklemede değil.');

  const now = new Date().toISOString();
  sqlRun('UPDATE connection_requests SET status = ?, updated_at = ?, responded_at = ? WHERE id = ?', ['ignored', now, now, requestId]);
  recordNetworkingTelemetryEvent({
    userId: currentUserId,
    eventName: 'connection_ignored',
    sourceSurface: req.body?.source_surface,
    targetUserId: Number(row.sender_id || 0),
    entityType: 'connection_request',
    entityId: requestId
  });
  return res.json(apiSuccessEnvelope(
    'CONNECTION_REQUEST_IGNORED',
    'Bağlantı isteği yok sayıldı.',
    { status: 'ignored', request_id: requestId },
    { status: 'ignored', request_id: requestId }
  ));
});

app.post('/api/new/connections/cancel/:id', requireAuth, (req, res) => {
  ensureConnectionRequestsTable();
  const requestId = Number(req.params.id || 0);
  const currentUserId = Number(req.session?.userId || 0);
  if (!requestId || !currentUserId) return sendApiError(res, 400, 'INVALID_CONNECTION_REQUEST_ID', 'Geçersiz istek kimliği.');

  const row = sqlGet('SELECT id, sender_id, receiver_id, status FROM connection_requests WHERE id = ?', [requestId]);
  if (!row) return sendApiError(res, 404, 'CONNECTION_REQUEST_NOT_FOUND', 'Bağlantı isteği bulunamadı.');
  if (Number(row.sender_id) !== currentUserId) return sendApiError(res, 403, 'CONNECTION_REQUEST_CANCEL_FORBIDDEN', 'Bu bağlantı isteğini geri çekemezsiniz.');
  if (String(row.status || '').toLowerCase() !== 'pending') return sendApiError(res, 409, 'CONNECTION_REQUEST_NOT_PENDING', 'Bağlantı isteği artık beklemede değil.');

  const now = new Date().toISOString();
  sqlRun('UPDATE connection_requests SET status = ?, updated_at = ?, responded_at = ? WHERE id = ?', ['cancelled', now, now, requestId]);
  recordNetworkingTelemetryEvent({
    userId: currentUserId,
    eventName: 'connection_cancelled',
    sourceSurface: req.body?.source_surface,
    targetUserId: Number(row.receiver_id || 0),
    entityType: 'connection_request',
    entityId: requestId
  });
  return res.json(apiSuccessEnvelope(
    'CONNECTION_REQUEST_CANCELLED',
    'Bağlantı isteği geri çekildi.',
    { status: 'cancelled', request_id: requestId },
    { status: 'cancelled', request_id: requestId }
  ));
});


app.post('/api/new/mentorship/request/:id', requireAuth, mentorshipRequestRateLimit, (req, res) => {
  if (!ensureVerifiedSocialHubMember(req, res)) return;
  ensureMentorshipRequestsTable();
  const requesterId = Number(req.session?.userId || 0);
  const mentorId = Number(req.params.id || 0);
  if (!requesterId || !mentorId) return sendApiError(res, 400, 'INVALID_USER_ID', 'Geçersiz kullanıcı kimliği.');
  if (requesterId === mentorId) return sendApiError(res, 400, 'SELF_MENTORSHIP_NOT_ALLOWED', 'Kendine mentorluk isteği gönderemezsin.');

  const mentor = sqlGet('SELECT id, mentor_opt_in FROM uyeler WHERE id = ?', [mentorId]);
  if (!mentor) return sendApiError(res, 404, 'MENTOR_NOT_FOUND', 'Mentor bulunamadı.');
  if (Number(mentor.mentor_opt_in || 0) !== 1) {
    return sendApiError(res, 409, 'MENTOR_NOT_AVAILABLE', 'Seçilen üye mentorluk taleplerini kabul etmiyor.');
  }

  const focusArea = String(req.body?.focus_area || '').trim().slice(0, 120);
  const message = String(req.body?.message || '').trim().slice(0, 2000);
  const now = new Date().toISOString();

  const existing = sqlGet(
    'SELECT id, status, updated_at, responded_at FROM mentorship_requests WHERE requester_id = ? AND mentor_id = ?',
    [requesterId, mentorId]
  );
  const existingStatus = String(existing?.status || '').toLowerCase();
  if (existing && existingStatus === 'requested') {
    return sendApiError(res, 409, 'REQUEST_ALREADY_PENDING', 'Bu mentor için zaten bekleyen bir talebin var.');
  }
  if (existing && existingStatus === 'accepted') {
    return sendApiError(res, 409, 'REQUEST_ALREADY_ACCEPTED', 'Bu mentor ile aktif bir mentorluk bağlantın var.');
  }
  if (existing && existingStatus === 'declined') {
    const remainingSeconds = calculateCooldownRemainingSeconds(
      existing.responded_at || existing.updated_at,
      MENTORSHIP_REQUEST_COOLDOWN_SECONDS
    );
    if (remainingSeconds > 0) {
      res.setHeader('Retry-After', String(remainingSeconds));
      return sendApiError(
        res,
        429,
        'MENTORSHIP_COOLDOWN_ACTIVE',
        'Aynı mentora tekrar istek göndermeden önce biraz beklemelisin.',
        { retry_after_seconds: remainingSeconds },
        { retry_after_seconds: remainingSeconds }
      );
    }
  }

  if (existing) {
    sqlRun(
      'UPDATE mentorship_requests SET status = ?, focus_area = ?, message = ?, updated_at = ?, responded_at = NULL WHERE id = ?',
      ['requested', focusArea, message, now, existing.id]
    );
  } else {
    sqlRun(
      `INSERT INTO mentorship_requests (requester_id, mentor_id, status, focus_area, message, created_at, updated_at)
       VALUES (?, ?, 'requested', ?, ?, ?, ?)`,
      [requesterId, mentorId, focusArea, message, now, now]
    );
  }

  const mentorshipRequestId = Number(existing?.id || sqlGet(
    'SELECT id FROM mentorship_requests WHERE requester_id = ? AND mentor_id = ?',
    [requesterId, mentorId]
  )?.id || 0);
  addNotification({
    userId: mentorId,
    type: 'mentorship_request',
    sourceUserId: requesterId,
    entityId: mentorshipRequestId,
    message: 'Sana bir mentorluk isteği gönderdi.'
  });
  recordNetworkingTelemetryEvent({
    userId: requesterId,
    eventName: 'mentorship_requested',
    sourceSurface: req.body?.source_surface,
    targetUserId: mentorId,
    entityType: 'mentorship_request',
    entityId: mentorshipRequestId,
    metadata: {
      focus_area: focusArea || '',
      has_message: message.length > 0
    }
  });

  return res.json(apiSuccessEnvelope(
    'MENTORSHIP_REQUEST_CREATED',
    'Mentorluk talebi gönderildi.',
    { status: 'requested' },
    { status: 'requested' }
  ));
});

app.get('/api/new/mentorship/requests', requireAuth, async (req, res) => {
  ensureMentorshipRequestsTable();
  const userId = Number(req.session?.userId || 0);
  const status = normalizeMentorshipStatus(req.query.status) || 'requested';
  const direction = String(req.query.direction || 'incoming').trim().toLowerCase() === 'outgoing' ? 'outgoing' : 'incoming';
  const limit = Math.min(Math.max(parseInt(req.query.limit || '30', 10), 1), 100);
  const offset = Math.max(parseInt(req.query.offset || '0', 10), 0);

  const whereClause = direction === 'incoming' ? 'mr.mentor_id = ?' : 'mr.requester_id = ?';
  const joinClause = direction === 'incoming'
    ? 'LEFT JOIN uyeler u ON u.id = mr.requester_id'
    : 'LEFT JOIN uyeler u ON u.id = mr.mentor_id';

  try {
    const rows = await sqlAllAsync(
      `SELECT mr.id, mr.requester_id, mr.mentor_id, mr.status, mr.focus_area, mr.message, mr.created_at, mr.updated_at, mr.responded_at,
              u.kadi, u.isim, u.soyisim, u.resim, u.verified
       FROM mentorship_requests mr
       ${joinClause}
       WHERE ${whereClause} AND mr.status = ?
       ORDER BY COALESCE(CASE WHEN CAST(mr.updated_at AS TEXT) = '' THEN NULL ELSE mr.updated_at END, mr.created_at) DESC, mr.id DESC
       LIMIT ? OFFSET ?`,
      [userId, status, limit, offset]
    );
    const payload = { items: rows, hasMore: rows.length === limit, direction, status };
    return res.json(apiSuccessEnvelope('MENTORSHIP_REQUESTS_LIST_OK', 'Mentorluk talepleri listelendi.', payload, payload));
  } catch (err) {
    console.error('mentorship.requests failed:', err);
    return sendApiError(res, 500, 'MENTORSHIP_REQUESTS_LIST_FAILED', 'Beklenmeyen bir hata oluştu.');
  }
});

app.post('/api/new/mentorship/accept/:id', requireAuth, (req, res) => {
  ensureMentorshipRequestsTable();
  const requestId = Number(req.params.id || 0);
  const currentUserId = Number(req.session?.userId || 0);
  if (!requestId || !currentUserId) return sendApiError(res, 400, 'INVALID_MENTORSHIP_REQUEST_ID', 'Geçersiz istek kimliği.');

  const row = sqlGet('SELECT id, requester_id, mentor_id, status FROM mentorship_requests WHERE id = ?', [requestId]);
  if (!row) return sendApiError(res, 404, 'MENTORSHIP_REQUEST_NOT_FOUND', 'Mentorluk isteği bulunamadı.');
  if (Number(row.mentor_id) !== currentUserId) return sendApiError(res, 403, 'MENTORSHIP_REQUEST_FORBIDDEN', 'Bu mentorluk isteğini yönetemezsiniz.');
  if (String(row.status || '').toLowerCase() !== 'requested') return sendApiError(res, 409, 'MENTORSHIP_REQUEST_NOT_PENDING', 'Mentorluk isteği artık beklemede değil.');

  const now = new Date().toISOString();
  sqlRun('UPDATE mentorship_requests SET status = ?, updated_at = ?, responded_at = ? WHERE id = ?', ['accepted', now, now, requestId]);

  addNotification({
    userId: Number(row.requester_id),
    type: 'mentorship_accepted',
    sourceUserId: currentUserId,
    entityId: requestId,
    message: 'Mentorluk isteğini kabul etti.'
  });
  recordNetworkingTelemetryEvent({
    userId: currentUserId,
    eventName: 'mentorship_accepted',
    sourceSurface: req.body?.source_surface,
    targetUserId: Number(row.requester_id || 0),
    entityType: 'mentorship_request',
    entityId: requestId
  });

  return res.json(apiSuccessEnvelope(
    'MENTORSHIP_REQUEST_ACCEPTED',
    'Mentorluk talebi kabul edildi.',
    { status: 'accepted', request_id: requestId },
    { status: 'accepted', request_id: requestId }
  ));
});

app.post('/api/new/mentorship/decline/:id', requireAuth, (req, res) => {
  ensureMentorshipRequestsTable();
  const requestId = Number(req.params.id || 0);
  const currentUserId = Number(req.session?.userId || 0);
  if (!requestId || !currentUserId) return sendApiError(res, 400, 'INVALID_MENTORSHIP_REQUEST_ID', 'Geçersiz istek kimliği.');

  const row = sqlGet('SELECT id, requester_id, mentor_id, status FROM mentorship_requests WHERE id = ?', [requestId]);
  if (!row) return sendApiError(res, 404, 'MENTORSHIP_REQUEST_NOT_FOUND', 'Mentorluk isteği bulunamadı.');
  if (Number(row.mentor_id) !== currentUserId) return sendApiError(res, 403, 'MENTORSHIP_REQUEST_FORBIDDEN', 'Bu mentorluk isteğini yönetemezsiniz.');
  if (String(row.status || '').toLowerCase() !== 'requested') return sendApiError(res, 409, 'MENTORSHIP_REQUEST_NOT_PENDING', 'Mentorluk isteği artık beklemede değil.');

  const now = new Date().toISOString();
  sqlRun('UPDATE mentorship_requests SET status = ?, updated_at = ?, responded_at = ? WHERE id = ?', ['declined', now, now, requestId]);
  recordNetworkingTelemetryEvent({
    userId: currentUserId,
    eventName: 'mentorship_declined',
    sourceSurface: req.body?.source_surface,
    targetUserId: Number(row.requester_id || 0),
    entityType: 'mentorship_request',
    entityId: requestId
  });
  return res.json(apiSuccessEnvelope(
    'MENTORSHIP_REQUEST_DECLINED',
    'Mentorluk talebi reddedildi.',
    { status: 'declined', request_id: requestId },
    { status: 'declined', request_id: requestId }
  ));
});

app.get('/api/new/network/inbox', requireAuth, async (req, res) => {
  try {
    const userId = Number(req.session?.userId || 0);
    const limit = Math.min(Math.max(parseInt(req.query.limit || '12', 10), 1), 50);
    const teacherLinkLimit = Math.min(Math.max(parseInt(req.query.teacher_limit || String(limit), 10), 1), 50);
    const inbox = await buildNetworkInboxPayload(userId, { limit, teacherLinkLimit });
    return res.json(apiSuccessEnvelope('NETWORK_INBOX_OK', 'Networking inbox hazır.', { inbox }, { inbox }));
  } catch (err) {
    console.error('network.inbox failed:', err);
    return sendApiError(res, 500, 'NETWORK_INBOX_FAILED', 'Beklenmeyen bir hata oluştu.');
  }
});

function parseNetworkWindowDays(raw) {
  const value = String(raw || '30d').trim().toLowerCase();
  if (value === '7d') return 7;
  if (value === '90d') return 90;
  return 30;
}

function toIsoThreshold(days) {
  return new Date(Date.now() - days * 24 * 60 * 60 * 1000).toISOString();
}

function createEmptyNetworkInboxPayload() {
  return {
    connections: {
      incoming: [],
      outgoing: [],
      counts: {
        incoming_pending: 0,
        outgoing_pending: 0
      }
    },
    mentorship: {
      incoming: [],
      outgoing: [],
      counts: {
        incoming_requested: 0,
        outgoing_requested: 0
      }
    },
    teacherLinks: {
      events: [],
      count: 0,
      unread_count: 0
    }
  };
}

function createEmptyNetworkMetricsPayload(windowDays = 30) {
  return {
    window: `${windowDays}d`,
    since: toIsoThreshold(windowDays),
    metrics: {
      connections: {
        requested: 0,
        accepted: 0,
        pending_incoming: 0,
        pending_outgoing: 0
      },
      mentorship: {
        requested: 0,
        accepted: 0
      },
      teacherLinks: {
        created: 0
      },
      time_to_first_network_success_days: null
    }
  };
}

function createEmptyExploreSuggestionsPayload(variant = 'A') {
  return {
    items: [],
    hasMore: false,
    total: 0,
    experiment_variant: variant
  };
}

async function safeNetworkSection(label, fallbackValue, callback) {
  try {
    return await callback();
  } catch (err) {
    console.error(`network.section.${label} failed:`, err);
    return typeof fallbackValue === 'function' ? fallbackValue() : fallbackValue;
  }
}

async function buildNetworkInboxPayload(userId, { limit = 12, teacherLinkLimit = limit } = {}) {
  ensureConnectionRequestsTable();
  ensureMentorshipRequestsTable();
  ensureTeacherAlumniLinksTable();
  if (!hasTable('uyeler')) return createEmptyNetworkInboxPayload();
  const hasNotifications = hasTable('notifications');

  const [incomingConnections, outgoingConnections, incomingMentorship, outgoingMentorship, teacherLinkEvents] = await Promise.all([
    sqlAllAsync(
      `SELECT cr.id, cr.sender_id, cr.receiver_id, cr.status, cr.created_at, cr.updated_at, cr.responded_at,
              u.kadi, u.isim, u.soyisim, u.resim, u.verified
       FROM connection_requests cr
       LEFT JOIN uyeler u ON u.id = cr.sender_id
       WHERE cr.receiver_id = ? AND LOWER(TRIM(COALESCE(cr.status, ''))) = 'pending'
       ORDER BY COALESCE(CASE WHEN CAST(cr.updated_at AS TEXT) = '' THEN NULL ELSE cr.updated_at END, cr.created_at) DESC, cr.id DESC
       LIMIT ?`,
      [userId, limit]
    ),
    sqlAllAsync(
      `SELECT cr.id, cr.sender_id, cr.receiver_id, cr.status, cr.created_at, cr.updated_at, cr.responded_at,
              u.kadi, u.isim, u.soyisim, u.resim, u.verified
       FROM connection_requests cr
       LEFT JOIN uyeler u ON u.id = cr.receiver_id
       WHERE cr.sender_id = ? AND LOWER(TRIM(COALESCE(cr.status, ''))) = 'pending'
       ORDER BY COALESCE(CASE WHEN CAST(cr.updated_at AS TEXT) = '' THEN NULL ELSE cr.updated_at END, cr.created_at) DESC, cr.id DESC
       LIMIT ?`,
      [userId, limit]
    ),
    sqlAllAsync(
      `SELECT mr.id, mr.requester_id, mr.mentor_id, mr.status, mr.focus_area, mr.message, mr.created_at, mr.updated_at, mr.responded_at,
              u.kadi, u.isim, u.soyisim, u.resim, u.verified
       FROM mentorship_requests mr
       LEFT JOIN uyeler u ON u.id = mr.requester_id
       WHERE mr.mentor_id = ? AND LOWER(TRIM(COALESCE(mr.status, ''))) = 'requested'
       ORDER BY COALESCE(CASE WHEN CAST(mr.updated_at AS TEXT) = '' THEN NULL ELSE mr.updated_at END, mr.created_at) DESC, mr.id DESC
       LIMIT ?`,
      [userId, limit]
    ),
    sqlAllAsync(
      `SELECT mr.id, mr.requester_id, mr.mentor_id, mr.status, mr.focus_area, mr.message, mr.created_at, mr.updated_at, mr.responded_at,
              u.kadi, u.isim, u.soyisim, u.resim, u.verified
       FROM mentorship_requests mr
       LEFT JOIN uyeler u ON u.id = mr.mentor_id
       WHERE mr.requester_id = ? AND LOWER(TRIM(COALESCE(mr.status, ''))) = 'requested'
       ORDER BY COALESCE(CASE WHEN CAST(mr.updated_at AS TEXT) = '' THEN NULL ELSE mr.updated_at END, mr.created_at) DESC, mr.id DESC
       LIMIT ?`,
      [userId, limit]
    ),
    hasNotifications
      ? sqlAllAsync(
      `SELECT n.id, n.type, n.source_user_id, n.entity_id, n.message, n.read_at, n.created_at,
              u.kadi, u.isim, u.soyisim, u.resim, u.verified
       FROM notifications n
       LEFT JOIN uyeler u ON u.id = n.source_user_id
       WHERE n.user_id = ? AND n.type = 'teacher_network_linked'
       ORDER BY COALESCE(CASE WHEN CAST(n.created_at AS TEXT) = '' THEN NULL ELSE n.created_at END, '1970-01-01T00:00:00.000Z') DESC, n.id DESC
       LIMIT ?`,
      [userId, teacherLinkLimit]
    )
      : Promise.resolve([])
  ]);

  return {
    connections: {
      incoming: incomingConnections,
      outgoing: outgoingConnections,
      counts: {
        incoming_pending: incomingConnections.length,
        outgoing_pending: outgoingConnections.length
      }
    },
    mentorship: {
      incoming: incomingMentorship,
      outgoing: outgoingMentorship,
      counts: {
        incoming_requested: incomingMentorship.length,
        outgoing_requested: outgoingMentorship.length
      }
    },
    teacherLinks: {
      events: teacherLinkEvents,
      count: teacherLinkEvents.length,
      unread_count: teacherLinkEvents.reduce((sum, item) => (item.read_at ? sum : sum + 1), 0)
    }
  };
}

async function buildNetworkMetricsPayload(userId, windowDays) {
  ensureConnectionRequestsTable();
  ensureMentorshipRequestsTable();
  ensureTeacherAlumniLinksTable();
  if (!hasTable('uyeler')) return createEmptyNetworkMetricsPayload(windowDays);

  const sinceIso = toIsoThreshold(windowDays);

  const [
    userRow,
    pendingIncoming,
    pendingOutgoing,
    requestedConnections,
    acceptedConnections,
    mentorshipRequested,
    mentorshipAccepted,
    teacherLinksCreated,
    firstAcceptedConnection,
    firstAcceptedMentorship
  ] = await Promise.all([
    sqlGetAsync('SELECT ilktarih FROM uyeler WHERE id = ?', [userId]),
    sqlGetAsync("SELECT CAST(COUNT(*) AS INTEGER) AS count FROM connection_requests WHERE receiver_id = ? AND LOWER(TRIM(COALESCE(status, ''))) = 'pending'", [userId]),
    sqlGetAsync("SELECT CAST(COUNT(*) AS INTEGER) AS count FROM connection_requests WHERE sender_id = ? AND LOWER(TRIM(COALESCE(status, ''))) = 'pending'", [userId]),
    sqlGetAsync(
      `SELECT CAST(COUNT(*) AS INTEGER) AS count
       FROM connection_requests
       WHERE sender_id = ?
         AND (
           created_at >= ?
           OR LOWER(TRIM(COALESCE(status, ''))) = 'pending'
         )`,
      [userId, sinceIso]
    ),
    sqlGetAsync(
      `SELECT CAST(COUNT(*) AS INTEGER) AS count
       FROM connection_requests
       WHERE LOWER(TRIM(COALESCE(status, ''))) = 'accepted'
         AND (sender_id = ? OR receiver_id = ?)
         AND COALESCE(CASE WHEN CAST(responded_at AS TEXT) = '' THEN NULL ELSE responded_at END, CASE WHEN CAST(updated_at AS TEXT) = '' THEN NULL ELSE updated_at END, created_at) >= ?`,
      [userId, userId, sinceIso]
    ),
    sqlGetAsync('SELECT CAST(COUNT(*) AS INTEGER) AS count FROM mentorship_requests WHERE requester_id = ? AND created_at >= ?', [userId, sinceIso]),
    sqlGetAsync(
      `SELECT CAST(COUNT(*) AS INTEGER) AS count
       FROM mentorship_requests
       WHERE LOWER(TRIM(COALESCE(status, ''))) = 'accepted'
         AND (requester_id = ? OR mentor_id = ?)
         AND COALESCE(CASE WHEN CAST(responded_at AS TEXT) = '' THEN NULL ELSE responded_at END, CASE WHEN CAST(updated_at AS TEXT) = '' THEN NULL ELSE updated_at END, created_at) >= ?`,
      [userId, userId, sinceIso]
    ),
    sqlGetAsync('SELECT CAST(COUNT(*) AS INTEGER) AS count FROM teacher_alumni_links WHERE created_by = ? AND created_at >= ?', [userId, sinceIso]),
    sqlGetAsync(
      `SELECT COALESCE(CASE WHEN CAST(responded_at AS TEXT) = '' THEN NULL ELSE responded_at END, CASE WHEN CAST(updated_at AS TEXT) = '' THEN NULL ELSE updated_at END, created_at) AS at
       FROM connection_requests
       WHERE LOWER(TRIM(COALESCE(status, ''))) = 'accepted' AND (sender_id = ? OR receiver_id = ?)
       ORDER BY at ASC, id ASC
       LIMIT 1`,
      [userId, userId]
    ),
    sqlGetAsync(
      `SELECT COALESCE(CASE WHEN CAST(responded_at AS TEXT) = '' THEN NULL ELSE responded_at END, CASE WHEN CAST(updated_at AS TEXT) = '' THEN NULL ELSE updated_at END, created_at) AS at
       FROM mentorship_requests
       WHERE LOWER(TRIM(COALESCE(status, ''))) = 'accepted' AND (requester_id = ? OR mentor_id = ?)
       ORDER BY at ASC, id ASC
       LIMIT 1`,
      [userId, userId]
    )
  ]);

  const successCandidates = [firstAcceptedConnection?.at, firstAcceptedMentorship?.at]
    .map((value) => new Date(String(value || '')).getTime())
    .filter((value) => Number.isFinite(value) && value > 0);
  const firstSuccessAt = successCandidates.length ? new Date(Math.min(...successCandidates)).toISOString() : null;
  const registrationAtMs = new Date(String(userRow?.ilktarih || '')).getTime();
  const timeToFirstNetworkSuccessDays = firstSuccessAt && Number.isFinite(registrationAtMs) && registrationAtMs > 0
    ? Math.max(0, Math.round((new Date(firstSuccessAt).getTime() - registrationAtMs) / (24 * 60 * 60 * 1000)))
    : null;

  return {
    window: `${windowDays}d`,
    since: sinceIso,
    metrics: {
      connections: {
        requested: Number(requestedConnections?.count || 0),
        accepted: Number(acceptedConnections?.count || 0),
        pending_incoming: Number(pendingIncoming?.count || 0),
        pending_outgoing: Number(pendingOutgoing?.count || 0)
      },
      mentorship: {
        requested: Number(mentorshipRequested?.count || 0),
        accepted: Number(mentorshipAccepted?.count || 0)
      },
      teacherLinks: {
        created: Number(teacherLinksCreated?.count || 0)
      },
      time_to_first_network_success_days: timeToFirstNetworkSuccessDays
    }
  };
}

async function buildPendingConnectionMaps(userId, { limit = 100 } = {}) {
  ensureConnectionRequestsTable();
  if (!hasTable('connection_requests')) {
    return { incoming: {}, outgoing: {} };
  }
  const [incomingRows, outgoingRows] = await Promise.all([
    sqlAllAsync(
      `SELECT id, sender_id
       FROM connection_requests
       WHERE receiver_id = ? AND LOWER(TRIM(COALESCE(status, ''))) = 'pending'
       ORDER BY COALESCE(CASE WHEN CAST(updated_at AS TEXT) = '' THEN NULL ELSE updated_at END, created_at) DESC, id DESC
       LIMIT ?`,
      [userId, limit]
    ),
    sqlAllAsync(
      `SELECT id, receiver_id
       FROM connection_requests
       WHERE sender_id = ? AND LOWER(TRIM(COALESCE(status, ''))) = 'pending'
       ORDER BY COALESCE(CASE WHEN CAST(updated_at AS TEXT) = '' THEN NULL ELSE updated_at END, created_at) DESC, id DESC
       LIMIT ?`,
      [userId, limit]
    )
  ]);

  const incoming = {};
  for (const row of incomingRows) {
    const senderId = Number(row?.sender_id || 0);
    if (!senderId) continue;
    incoming[senderId] = Number(row?.id || 0);
  }

  const outgoing = {};
  for (const row of outgoingRows) {
    const receiverId = Number(row?.receiver_id || 0);
    if (!receiverId) continue;
    outgoing[receiverId] = Number(row?.id || 0);
  }

  return { incoming, outgoing };
}

async function buildExploreSuggestionsPayload(userId, { limit = 12, offset = 0 } = {}) {
  const safeUserId = Number(userId || 0);
  const safeLimit = Math.min(Math.max(parseInt(limit || '12', 10), 1), 40);
  const safeOffset = Math.max(parseInt(offset || '0', 10), 0);
  const experiment = getAssignedNetworkSuggestionVariant(safeUserId);
  const configVersion = String(experiment?.config?.updatedAt || 'default');
  const cacheKey = `${safeUserId}:${safeLimit}:${safeOffset}:${experiment.variant}:${configVersion}`;
  const cached = readExploreSuggestionsCache(cacheKey);
  if (cached) return cached;

  if (!hasTable('uyeler')) return createEmptyExploreSuggestionsPayload(experiment.variant);
  const hasFollows = hasTable('follows');
  const hasMentorOptIn = hasColumn('uyeler', 'mentor_opt_in');
  const hasOnline = hasColumn('uyeler', 'online');
  const me = await sqlGetAsync(
    `SELECT id, mezuniyetyili, sehir, universite, meslek
     FROM uyeler
     WHERE id = ?`,
    [safeUserId]
  );
  if (!me) return { items: [], hasMore: false, total: 0, experiment_variant: experiment.variant };
  const hasEngagementScores = hasTable('member_engagement_scores');

  const [iFollowFollowers, followsMe, candidates] = await Promise.all([
    hasFollows
      ? sqlAllAsync(
      `SELECT f2.following_id AS user_id, COUNT(*) AS cnt
       FROM follows f1
       JOIN follows f2 ON f2.follower_id = f1.following_id
       WHERE f1.follower_id = ?
       GROUP BY f2.following_id`,
      [safeUserId]
    )
      : Promise.resolve([]),
    hasFollows ? sqlAllAsync('SELECT follower_id FROM follows WHERE following_id = ?', [safeUserId]) : Promise.resolve([]),
    sqlAllAsync(
      `SELECT u.id, u.kadi, u.isim, u.soyisim, u.resim, u.verified, u.mezuniyetyili, u.sehir, u.universite, u.meslek, ${hasOnline ? 'u.online' : '0'} AS online,
              u.role, ${hasMentorOptIn ? 'u.mentor_opt_in' : '0'} AS mentor_opt_in,
              ${hasEngagementScores ? 'COALESCE(es.score, 0)' : '0'} AS engagement_score
       FROM uyeler u
       ${hasEngagementScores ? 'LEFT JOIN member_engagement_scores es ON es.user_id = u.id' : ''}
       WHERE COALESCE(CAST(u.aktiv AS INTEGER), 1) = 1
         AND COALESCE(CAST(u.yasak AS INTEGER), 0) = 0
         AND u.id != ?
         ${hasFollows ? `AND NOT EXISTS (
           SELECT 1
           FROM follows f
           WHERE f.follower_id = ?
             AND f.following_id = u.id
         )` : ''}`,
      hasFollows ? [safeUserId, safeUserId] : [safeUserId]
    )
  ]);

  const secondDegreeMap = new Map(iFollowFollowers.map((r) => [Number(r.user_id), Number(r.cnt || 0)]));
  const followsMeSet = new Set(followsMe.map((r) => Number(r.follower_id)));
  const candidateIds = candidates.map((row) => Number(row.id)).filter((id) => id > 0);
  const hasGroupMembers = hasTable('group_members');
  const hasMentorshipRequests = hasTable('mentorship_requests');
  const hasTeacherLinks = hasTable('teacher_alumni_links');

  const [sharedGroupsRows, mentorshipRows, teacherLinkRows] = await Promise.all([
    hasGroupMembers && candidateIds.length
      ? sqlAllAsync(
        `SELECT gm.user_id AS candidate_id, COUNT(*) AS shared_count
         FROM group_members gm
         JOIN group_members mine ON mine.group_id = gm.group_id
         WHERE mine.user_id = ?
           AND gm.user_id IN (${candidateIds.map(() => '?').join(',')})
         GROUP BY gm.user_id`,
        [safeUserId, ...candidateIds]
      )
      : Promise.resolve([]),
    hasMentorshipRequests
      ? sqlAllAsync(
        `SELECT requester_id, mentor_id
         FROM mentorship_requests
         WHERE status = 'accepted'
           AND (
             requester_id = ?
             OR mentor_id = ?
             OR requester_id IN (${[safeUserId, ...candidateIds].map(() => '?').join(',')})
             OR mentor_id IN (${[safeUserId, ...candidateIds].map(() => '?').join(',')})
           )`,
        [safeUserId, safeUserId, safeUserId, ...candidateIds, safeUserId, ...candidateIds]
      )
      : Promise.resolve([]),
    hasTeacherLinks
      ? sqlAllAsync(
        `SELECT teacher_user_id, alumni_user_id
         FROM teacher_alumni_links
         WHERE teacher_user_id = ?
            OR alumni_user_id = ?
            OR teacher_user_id IN (${[safeUserId, ...candidateIds].map(() => '?').join(',')})
            OR alumni_user_id IN (${[safeUserId, ...candidateIds].map(() => '?').join(',')})`,
        [safeUserId, safeUserId, safeUserId, ...candidateIds, safeUserId, ...candidateIds]
      )
      : Promise.resolve([])
  ]);

  const sharedGroupsMap = new Map(sharedGroupsRows.map((row) => [Number(row.candidate_id), Number(row.shared_count || 0)]));
  const mentorshipPeersMap = createPeerMap(mentorshipRows, 'requester_id', 'mentor_id');
  const teacherPeersMap = createPeerMap(teacherLinkRows, 'teacher_user_id', 'alumni_user_id');

  const scored = [];
  for (const c of candidates) {
    const cid = Number(c.id);
    if (!cid) continue;
    const secondDegree = secondDegreeMap.get(cid) || 0;
    const sharedGroups = sharedGroupsMap.get(cid) || 0;
    const mentorshipOverlap = getPeerOverlapCount(mentorshipPeersMap, safeUserId, cid);
    const hasDirectMentorshipLink = mentorshipPeersMap.get(safeUserId)?.has(cid);
    const teacherOverlap = getPeerOverlapCount(teacherPeersMap, safeUserId, cid);
    const hasDirectTeacherLink = teacherPeersMap.get(safeUserId)?.has(cid);
    scored.push(buildScoredNetworkSuggestion(c, {
      viewer: me,
      secondDegree,
      followsViewer: followsMeSet.has(cid),
      sharedGroups,
      mentorshipOverlap,
      hasDirectMentorshipLink,
      teacherOverlap,
      hasDirectTeacherLink,
      params: experiment.config.params
    }));
  }

  const sortedScored = sortNetworkSuggestions(scored);
  const items = sortedScored.slice(safeOffset, safeOffset + safeLimit).map(mapNetworkSuggestionForApi);
  const payload = {
    items,
    hasMore: safeOffset + items.length < sortedScored.length,
    total: sortedScored.length,
    experiment_variant: experiment.variant
  };
  writeExploreSuggestionsCache(cacheKey, payload);
  return payload;
}

async function buildNetworkHubPayload(userId, { windowDays = 30, limit = 12, teacherLinkLimit = limit, suggestionLimit = 8 } = {}) {
  const [inbox, metricsBundle, discovery, connectionMaps] = await Promise.all([
    safeNetworkSection('inbox', createEmptyNetworkInboxPayload, () => buildNetworkInboxPayload(userId, { limit, teacherLinkLimit })),
    safeNetworkSection('metrics', () => createEmptyNetworkMetricsPayload(windowDays), () => buildNetworkMetricsPayload(userId, windowDays)),
    safeNetworkSection('discovery', () => createEmptyExploreSuggestionsPayload(getAssignedNetworkSuggestionVariant(userId).variant), () => buildExploreSuggestionsPayload(userId, { limit: suggestionLimit, offset: 0 })),
    safeNetworkSection('connection_maps', { incoming: {}, outgoing: {} }, () => buildPendingConnectionMaps(userId, { limit: 100 }))
  ]);

  return {
    window: metricsBundle.window,
    since: metricsBundle.since,
    inbox,
    metrics: metricsBundle.metrics,
    discovery: {
      suggestions: discovery.items || [],
      hasMore: Boolean(discovery.hasMore),
      total: Number(discovery.total || 0),
      experiment_variant: String(discovery.experiment_variant || 'A'),
      connection_maps: connectionMaps
    },
    counts: {
      actionable:
        Number(inbox.connections?.counts?.incoming_pending || 0)
        + Number(inbox.mentorship?.counts?.incoming_requested || 0)
        + Number(inbox.teacherLinks?.unread_count || 0)
    }
  };
}

app.get('/api/new/network/hub', requireAuth, async (req, res) => {
  try {
    const userId = Number(req.session?.userId || 0);
    const limit = Math.min(Math.max(parseInt(req.query.limit || '12', 10), 1), 50);
    const teacherLinkLimit = Math.min(Math.max(parseInt(req.query.teacher_limit || String(limit), 10), 1), 50);
    const suggestionLimit = Math.min(Math.max(parseInt(req.query.suggestion_limit || '8', 10), 1), 20);
    const windowDays = parseNetworkWindowDays(req.query.window);
    const hub = await buildNetworkHubPayload(userId, { windowDays, limit, teacherLinkLimit, suggestionLimit });
    return res.json({
      ok: true,
      code: 'NETWORK_HUB_BOOTSTRAP_OK',
      message: 'Networking hub bootstrap hazir.',
      data: { hub }
    });
  } catch (err) {
    console.error('network.hub failed:', err);
    return res.status(500).json({
      ok: false,
      code: 'NETWORK_HUB_BOOTSTRAP_FAILED',
      message: 'Networking hub verileri hazirlanamadi.',
      data: null
    });
  }
});

app.get('/api/new/network/metrics', requireAuth, async (req, res) => {
  try {
    const userId = Number(req.session?.userId || 0);
    const windowDays = parseNetworkWindowDays(req.query.window);
    const payload = await buildNetworkMetricsPayload(userId, windowDays);
    return res.json(apiSuccessEnvelope('NETWORK_METRICS_OK', 'Networking metrikleri hazır.', payload, payload));
  } catch (err) {
    console.error('network.metrics failed:', err);
    return sendApiError(res, 500, 'NETWORK_METRICS_FAILED', 'Beklenmeyen bir hata oluştu.');
  }
});

app.post('/api/new/network/inbox/teacher-links/read', requireAuth, async (req, res) => {
  try {
    const result = await sqlRunAsync(
      `UPDATE notifications
       SET read_at = COALESCE(read_at, ?)
       WHERE user_id = ?
         AND type = 'teacher_network_linked'`,
      [new Date().toISOString(), req.session.userId]
    );
    const updated = Number(result?.changes || 0);
    if (updated > 0) {
      recordNetworkingTelemetryEvent({
        userId: req.session.userId,
        eventName: 'teacher_links_read',
        sourceSurface: req.body?.source_surface,
        entityType: 'notification',
        metadata: { updated }
      });
    }
    return res.json(apiSuccessEnvelope(
      'NETWORK_TEACHER_LINKS_MARKED_READ',
      'Öğretmen ağı bildirimleri okundu olarak işaretlendi.',
      { updated },
      { updated }
    ));
  } catch (err) {
    console.error('network.inbox.teacher-links.read failed:', err);
    return sendApiError(res, 500, 'NETWORK_TEACHER_LINKS_MARK_READ_FAILED', 'Beklenmeyen bir hata oluştu.');
  }
});

app.post('/api/new/network/telemetry', requireAuth, async (req, res) => {
  try {
    const userId = Number(req.session?.userId || 0);
    const eventName = normalizeNetworkingTelemetryEventName(req.body?.event_name, { allowClientEvents: true, allowActionEvents: false });
    if (!eventName) {
      return sendApiError(res, 400, 'INVALID_NETWORKING_TELEMETRY_EVENT', 'Geçersiz networking telemetry olayı.');
    }
    recordNetworkingTelemetryEvent({
      userId,
      eventName,
      sourceSurface: req.body?.source_surface,
      targetUserId: req.body?.target_user_id,
      entityType: req.body?.entity_type,
      entityId: req.body?.entity_id,
      metadata: req.body?.metadata && typeof req.body.metadata === 'object' ? req.body.metadata : null
    });
    return res.json(apiSuccessEnvelope(
      'NETWORKING_TELEMETRY_RECORDED',
      'Networking telemetry kaydedildi.',
      { recorded: true, event_name: eventName },
      { recorded: true, event_name: eventName }
    ));
  } catch (err) {
    console.error('network.telemetry.record failed:', err);
    return sendApiError(res, 500, 'NETWORKING_TELEMETRY_RECORD_FAILED', 'Beklenmeyen bir hata oluştu.');
  }
});

app.get('/api/new/admin/network/analytics', requireAdmin, async (req, res) => {
  try {
    ensureConnectionRequestsTable();
    ensureMentorshipRequestsTable();
    ensureTeacherAlumniLinksTable();
    ensureNetworkingTelemetryEventsTable();
    ensureMemberNetworkingDailySummaryTable();
    ensureNetworkSuggestionAbTables();

    const windowDays = parseNetworkWindowDays(req.query.window);
    const sinceIso = toIsoThreshold(windowDays);
    const sinceDate = toSummaryDateKey(sinceIso);
    const cohort = normalizeCohortValue(req.query.cohort);
    const includeCohort = cohort && cohort !== 'all';
    const summaryRefresh = await refreshMemberNetworkingDailySummaryIfStale();

    const summaryWhere = ['s.date >= ?'];
    const summaryParams = [sinceDate];
    if (includeCohort) {
      summaryWhere.push('LOWER(COALESCE(s.cohort, ?)) = LOWER(?)');
      summaryParams.push('unknown', cohort);
    }
    const summaryWhereSql = `WHERE ${summaryWhere.join(' AND ')}`;

    const [summaryTotals, topCohorts, mentorSupplyRows, mentorDemandRows, experimentDataset] = await Promise.all([
      sqlGetAsync(
        `SELECT
            CAST(COALESCE(SUM(s.connections_requested), 0) AS INTEGER) AS connections_requested,
            CAST(COALESCE(SUM(s.connections_accepted), 0) AS INTEGER) AS connections_accepted,
            CAST(COALESCE(SUM(s.connections_pending), 0) AS INTEGER) AS connections_pending,
            CAST(COALESCE(SUM(s.connections_ignored), 0) AS INTEGER) AS connections_ignored,
            CAST(COALESCE(SUM(s.connections_declined), 0) AS INTEGER) AS connections_declined,
            CAST(COALESCE(SUM(s.connections_cancelled), 0) AS INTEGER) AS connections_cancelled,
            CAST(COALESCE(SUM(s.mentorship_requested), 0) AS INTEGER) AS mentorship_requested,
            CAST(COALESCE(SUM(s.mentorship_accepted), 0) AS INTEGER) AS mentorship_accepted,
            CAST(COALESCE(SUM(s.mentorship_declined), 0) AS INTEGER) AS mentorship_declined,
            CAST(COALESCE(SUM(s.teacher_links_created), 0) AS INTEGER) AS teacher_links_created,
            CAST(COALESCE(SUM(s.teacher_links_read), 0) AS INTEGER) AS teacher_links_read,
            CAST(COALESCE(SUM(s.follow_created), 0) AS INTEGER) AS follow_created,
            CAST(COALESCE(SUM(s.follow_removed), 0) AS INTEGER) AS follow_removed,
            CAST(COALESCE(SUM(s.hub_views), 0) AS INTEGER) AS hub_views,
            CAST(COALESCE(SUM(s.hub_suggestion_loads), 0) AS INTEGER) AS hub_suggestion_loads,
            CAST(COALESCE(SUM(s.explore_views), 0) AS INTEGER) AS explore_views,
            CAST(COALESCE(SUM(s.explore_suggestion_loads), 0) AS INTEGER) AS explore_suggestion_loads,
            CAST(COALESCE(SUM(s.teacher_network_views), 0) AS INTEGER) AS teacher_network_views
         FROM member_networking_daily_summary s
         ${summaryWhereSql}`,
        summaryParams
      ),
      sqlAllAsync(
        `SELECT LOWER(COALESCE(s.cohort, 'unknown')) AS cohort,
                CAST(COALESCE(SUM(s.connections_requested + s.mentorship_requested), 0) AS INTEGER) AS actions
         FROM member_networking_daily_summary s
         ${summaryWhereSql}
         GROUP BY LOWER(COALESCE(s.cohort, 'unknown'))
         ORDER BY actions DESC, cohort ASC
         LIMIT 5`,
        summaryParams
      ),
      sqlAllAsync(
        `SELECT LOWER(COALESCE(NULLIF(CAST(mezuniyetyili AS TEXT), ''), 'unknown')) AS cohort,
                CAST(COUNT(*) AS INTEGER) AS count
         FROM uyeler
         WHERE mentor_opt_in = 1
         GROUP BY cohort
         ORDER BY count DESC, cohort ASC
         LIMIT 10`
      ),
      sqlAllAsync(
        `SELECT LOWER(COALESCE(s.cohort, 'unknown')) AS cohort,
                CAST(COALESCE(SUM(s.mentorship_requested), 0) AS INTEGER) AS count
         FROM member_networking_daily_summary s
         ${summaryWhereSql}
         GROUP BY LOWER(COALESCE(s.cohort, 'unknown'))
         HAVING CAST(COALESCE(SUM(s.mentorship_requested), 0) AS INTEGER) > 0
         ORDER BY count DESC, cohort ASC
         LIMIT 10`,
        summaryParams
      ),
      getNetworkSuggestionExperimentDataset({ sinceIso, cohort })
    ]);

    const requested = Number(summaryTotals?.connections_requested || 0);
    const accepted = Number(summaryTotals?.connections_accepted || 0);
    const analyticsAlerts = buildNetworkingAnalyticsAlerts(summaryTotals, mentorDemandRows, mentorSupplyRows);
    const experimentConfigs = getNetworkSuggestionAbConfigs();
    const recentSuggestionChanges = await listNetworkSuggestionAbRecentChangesWithEvaluation(6);
    const suggestionExperiment = buildNetworkSuggestionExperimentAnalytics({
      exposureRows: experimentDataset.exposureRows,
      actionRows: experimentDataset.actionRows,
      configs: experimentConfigs,
      assignmentCounts: experimentDataset.assignmentCounts
    });
    suggestionExperiment.recent_changes = recentSuggestionChanges;
    suggestionExperiment.recommendations = buildNetworkSuggestionAbRecommendations(
      experimentConfigs,
      suggestionExperiment.variants,
      suggestionExperiment.recent_changes || []
    );

    return res.json({
      window: `${windowDays}d`,
      since: sinceIso,
      summary: {
        source: 'member_networking_daily_summary',
        granularity: 'day',
        last_rebuilt_at: summaryRefresh?.lastRebuiltAt || null,
        rebuilt_rows: Number(summaryRefresh?.rows || 0),
        skipped_refresh: Boolean(summaryRefresh?.skipped)
      },
      cohort: includeCohort ? cohort : 'all',
      networking: {
        connections: {
          requested,
          accepted,
          acceptance_rate: requested > 0 ? Number((accepted / requested).toFixed(4)) : 0,
          pending: Number(summaryTotals?.connections_pending || 0),
          ignored: Number(summaryTotals?.connections_ignored || 0),
          declined: Number(summaryTotals?.connections_declined || 0),
          cancelled: Number(summaryTotals?.connections_cancelled || 0)
        },
        mentorship: {
          requested: Number(summaryTotals?.mentorship_requested || 0),
          accepted: Number(summaryTotals?.mentorship_accepted || 0),
          declined: Number(summaryTotals?.mentorship_declined || 0)
        },
        teacher_links: {
          created: Number(summaryTotals?.teacher_links_created || 0)
        },
        telemetry: {
          frontend: {
            hub_views: Number(summaryTotals?.hub_views || 0),
            hub_suggestion_loads: Number(summaryTotals?.hub_suggestion_loads || 0),
            explore_views: Number(summaryTotals?.explore_views || 0),
            explore_suggestion_loads: Number(summaryTotals?.explore_suggestion_loads || 0),
            teacher_network_views: Number(summaryTotals?.teacher_network_views || 0)
          },
          actions: {
            connection_requested: Number(summaryTotals?.connections_requested || 0),
            connection_accepted: Number(summaryTotals?.connections_accepted || 0),
            connection_ignored: Number(summaryTotals?.connections_ignored || 0),
            connection_cancelled: Number(summaryTotals?.connections_cancelled || 0),
            mentorship_requested: Number(summaryTotals?.mentorship_requested || 0),
            mentorship_accepted: Number(summaryTotals?.mentorship_accepted || 0),
            mentorship_declined: Number(summaryTotals?.mentorship_declined || 0),
            teacher_link_created: Number(summaryTotals?.teacher_links_created || 0),
            teacher_links_read: Number(summaryTotals?.teacher_links_read || 0),
            follow_created: Number(summaryTotals?.follow_created || 0),
            follow_removed: Number(summaryTotals?.follow_removed || 0)
          },
          top_events: [
            { event_name: 'connection_requested', count: Number(summaryTotals?.connections_requested || 0) },
            { event_name: 'connection_accepted', count: Number(summaryTotals?.connections_accepted || 0) },
            { event_name: 'connection_ignored', count: Number(summaryTotals?.connections_ignored || 0) },
            { event_name: 'connection_cancelled', count: Number(summaryTotals?.connections_cancelled || 0) },
            { event_name: 'mentorship_requested', count: Number(summaryTotals?.mentorship_requested || 0) },
            { event_name: 'mentorship_accepted', count: Number(summaryTotals?.mentorship_accepted || 0) },
            { event_name: 'mentorship_declined', count: Number(summaryTotals?.mentorship_declined || 0) },
            { event_name: 'teacher_link_created', count: Number(summaryTotals?.teacher_links_created || 0) },
            { event_name: 'teacher_links_read', count: Number(summaryTotals?.teacher_links_read || 0) },
            { event_name: 'follow_created', count: Number(summaryTotals?.follow_created || 0) },
            { event_name: 'follow_removed', count: Number(summaryTotals?.follow_removed || 0) },
            { event_name: 'network_hub_viewed', count: Number(summaryTotals?.hub_views || 0) },
            { event_name: 'network_hub_suggestions_loaded', count: Number(summaryTotals?.hub_suggestion_loads || 0) },
            { event_name: 'network_explore_viewed', count: Number(summaryTotals?.explore_views || 0) },
            { event_name: 'network_explore_suggestions_loaded', count: Number(summaryTotals?.explore_suggestion_loads || 0) },
            { event_name: 'teacher_network_viewed', count: Number(summaryTotals?.teacher_network_views || 0) }
          ].filter((item) => item.count > 0)
            .sort((a, b) => Number(b.count || 0) - Number(a.count || 0) || String(a.event_name).localeCompare(String(b.event_name)))
        },
        alerts: analyticsAlerts,
        experiments: {
          network_suggestions: suggestionExperiment
        },
        top_active_graduation_years: topCohorts,
        mentor_supply_vs_demand: {
          supply: mentorSupplyRows,
          demand: mentorDemandRows
        }
      }
    });
  } catch (err) {
    console.error('admin.network.analytics failed:', err);
    return res.status(500).send('Beklenmeyen bir hata oluştu.');
  }
});

app.get('/api/new/teachers/network', requireAuth, async (req, res) => {
  try {
    ensureTeacherAlumniLinksTable();
    const userId = Number(req.session?.userId || 0);
    const direction = String(req.query.direction || 'my_teachers').trim().toLowerCase() === 'my_students' ? 'my_students' : 'my_teachers';
    const relationshipType = normalizeTeacherAlumniRelationshipType(req.query.relationship_type);
    const classYear = parseTeacherNetworkClassYear(req.query.class_year);
    if (classYear.provided && !classYear.valid) {
      return sendApiError(
        res,
        400,
        'INVALID_CLASS_YEAR',
        `Sınıf yılı ${TEACHER_NETWORK_MIN_CLASS_YEAR}-${TEACHER_NETWORK_MAX_CLASS_YEAR} aralığında olmalıdır.`
      );
    }
    const limit = Math.min(Math.max(parseInt(req.query.limit || '30', 10), 1), 100);
    const offset = Math.max(parseInt(req.query.offset || '0', 10), 0);

    const where = [];
    const params = [];
    if (direction === 'my_students') {
      where.push('l.teacher_user_id = ?');
      params.push(userId);
    } else {
      where.push('l.alumni_user_id = ?');
      params.push(userId);
    }
    if (relationshipType) {
      where.push('l.relationship_type = ?');
      params.push(relationshipType);
    }
    if (classYear.value !== null) {
      where.push('l.class_year = ?');
      params.push(classYear.value);
    }
    where.push("COALESCE(l.review_status, 'pending') NOT IN ('rejected', 'merged')");

    const joinSql = direction === 'my_students'
      ? 'LEFT JOIN uyeler u ON u.id = l.alumni_user_id'
      : 'LEFT JOIN uyeler u ON u.id = l.teacher_user_id';

    const rows = await sqlAllAsync(
      `SELECT l.id, l.teacher_user_id, l.alumni_user_id, l.relationship_type, l.class_year, l.notes, l.confidence_score, l.created_at,
              COALESCE(l.created_via, 'manual_alumni_link') AS created_via,
              COALESCE(l.source_surface, 'teachers_network_page') AS source_surface,
              COALESCE(l.review_status, 'pending') AS review_status,
              l.last_reviewed_by,
              u.kadi, u.isim, u.soyisim, u.resim, u.verified, u.role
       FROM teacher_alumni_links l
       ${joinSql}
       WHERE ${where.join(' AND ')}
       ORDER BY COALESCE(CASE WHEN CAST(l.created_at AS TEXT) = '' THEN NULL ELSE l.created_at END, '1970-01-01T00:00:00.000Z') DESC, l.id DESC
       LIMIT ? OFFSET ?`,
      [...params, limit, offset]
    );

    const payload = { items: rows, direction, hasMore: rows.length === limit };
    return res.json(apiSuccessEnvelope('TEACHER_NETWORK_LIST_OK', 'Öğretmen ağı kayıtları listelendi.', payload, payload));
  } catch (err) {
    console.error('teachers.network.list failed:', err);
    return sendApiError(res, 500, 'TEACHER_NETWORK_LIST_FAILED', 'Beklenmeyen bir hata oluştu.');
  }
});

app.get('/api/new/teachers/options', requireAuth, async (req, res) => {
  try {
    ensureTeacherAlumniLinksTable();
    const alumniUserId = Number(req.session?.userId || 0);
    const term = String(req.query.term || '').trim();
    const limit = Math.min(Math.max(parseInt(req.query.limit || '20', 10), 1), 50);
    const includeId = Math.max(parseInt(req.query.include_id || '0', 10), 0);
    const params = [];
    let whereSql = "WHERE COALESCE(CAST(u.aktiv AS INTEGER), 1) = 1 AND COALESCE(CAST(u.yasak AS INTEGER), 0) = 0 AND (LOWER(COALESCE(u.role, '')) = 'teacher' OR LOWER(COALESCE(u.mezuniyetyili, '')) IN ('teacher', 'ogretmen'))";
    if (term) {
      whereSql += ' AND (LOWER(CAST(u.kadi AS TEXT)) LIKE LOWER(?) OR LOWER(CAST(u.isim AS TEXT)) LIKE LOWER(?) OR LOWER(CAST(u.soyisim AS TEXT)) LIKE LOWER(?))';
      params.push(`%${term}%`, `%${term}%`, `%${term}%`);
    }
    let rows = await sqlAllAsync(
      `SELECT u.id, u.kadi, u.isim, u.soyisim, u.mezuniyetyili, u.resim,
              (SELECT COUNT(*) FROM teacher_alumni_links l WHERE l.teacher_user_id = u.id AND COALESCE(l.review_status, 'pending') NOT IN ('rejected', 'merged')) AS student_count,
              (SELECT COUNT(*) FROM teacher_alumni_links l WHERE l.teacher_user_id = u.id AND l.alumni_user_id = ? AND COALESCE(l.review_status, 'pending') NOT IN ('rejected', 'merged')) AS existing_link_count,
              (SELECT GROUP_CONCAT(DISTINCT l.relationship_type) FROM teacher_alumni_links l WHERE l.teacher_user_id = u.id AND l.alumni_user_id = ? AND COALESCE(l.review_status, 'pending') NOT IN ('rejected', 'merged')) AS existing_relationship_types,
              (SELECT GROUP_CONCAT(DISTINCT CAST(COALESCE(l.class_year, '') AS TEXT)) FROM teacher_alumni_links l WHERE l.teacher_user_id = u.id AND l.alumni_user_id = ? AND COALESCE(l.review_status, 'pending') NOT IN ('rejected', 'merged')) AS existing_class_years
       FROM uyeler u
       ${whereSql}
       ORDER BY student_count DESC, u.kadi COLLATE NOCASE ASC
       LIMIT ?`,
      [alumniUserId, alumniUserId, alumniUserId, ...params, limit]
    );

    if (includeId > 0 && !rows.some((row) => Number(row?.id || 0) === includeId)) {
      const selectedRow = await sqlGetAsync(
        `SELECT u.id, u.kadi, u.isim, u.soyisim, u.mezuniyetyili, u.resim,
                (SELECT COUNT(*) FROM teacher_alumni_links l WHERE l.teacher_user_id = u.id AND COALESCE(l.review_status, 'pending') NOT IN ('rejected', 'merged')) AS student_count,
                (SELECT COUNT(*) FROM teacher_alumni_links l WHERE l.teacher_user_id = u.id AND l.alumni_user_id = ? AND COALESCE(l.review_status, 'pending') NOT IN ('rejected', 'merged')) AS existing_link_count,
                (SELECT GROUP_CONCAT(DISTINCT l.relationship_type) FROM teacher_alumni_links l WHERE l.teacher_user_id = u.id AND l.alumni_user_id = ? AND COALESCE(l.review_status, 'pending') NOT IN ('rejected', 'merged')) AS existing_relationship_types,
                (SELECT GROUP_CONCAT(DISTINCT CAST(COALESCE(l.class_year, '') AS TEXT)) FROM teacher_alumni_links l WHERE l.teacher_user_id = u.id AND l.alumni_user_id = ? AND COALESCE(l.review_status, 'pending') NOT IN ('rejected', 'merged')) AS existing_class_years
         FROM uyeler u
         WHERE u.id = ?
           AND COALESCE(CAST(u.aktiv AS INTEGER), 1) = 1
           AND COALESCE(CAST(u.yasak AS INTEGER), 0) = 0
           AND (LOWER(COALESCE(u.role, '')) = 'teacher' OR LOWER(COALESCE(u.mezuniyetyili, '')) IN ('teacher', 'ogretmen'))
         LIMIT 1`,
        [alumniUserId, alumniUserId, alumniUserId, includeId]
      );
      if (selectedRow) rows = [selectedRow, ...rows].slice(0, limit);
    }

    const payload = { items: rows };
    return res.json(apiSuccessEnvelope('TEACHER_OPTIONS_OK', 'Öğretmen seçenekleri hazır.', payload, payload));
  } catch (err) {
    console.error('teachers.options failed:', err);
    return sendApiError(res, 500, 'TEACHER_OPTIONS_FAILED', 'Beklenmeyen bir hata oluştu.');
  }
});

app.post('/api/new/teachers/network/link/:teacherId', requireAuth, (req, res) => {
  try {
    if (!ensureVerifiedSocialHubMember(req, res)) return;
    ensureTeacherAlumniLinksTable();
    const alumniUserId = Number(req.session?.userId || 0);
    const teacherUserId = Number(req.params.teacherId || 0);
    if (!alumniUserId || !teacherUserId) return sendApiError(res, 400, 'INVALID_USER_ID', 'Geçersiz kullanıcı kimliği.');
    if (alumniUserId === teacherUserId) return sendApiError(res, 400, 'SELF_TEACHER_LINK_NOT_ALLOWED', 'Kendiniz için öğretmen bağlantısı ekleyemezsiniz.');

    const teacher = sqlGet('SELECT id, role, mezuniyetyili FROM uyeler WHERE id = ?', [teacherUserId]);
    if (!teacher) return sendApiError(res, 404, 'TEACHER_NOT_FOUND', 'Öğretmen bulunamadı.');
    const teacherRole = String(teacher.role || '').trim().toLowerCase();
    const teacherCohort = normalizeCohortValue(teacher.mezuniyetyili);
    const teacherTargetAllowed = teacherRole === 'teacher'
      || teacherCohort === TEACHER_COHORT_VALUE
      || roleAtLeast(teacherRole, 'admin');
    if (!teacherTargetAllowed) {
      return sendApiError(res, 409, 'INVALID_TEACHER_TARGET', 'Seçilen kullanıcı öğretmen ağına eklenebilir bir öğretmen hesabı değil.');
    }

    const relationshipType = normalizeTeacherAlumniRelationshipType(req.body?.relationship_type || 'taught_in_class') || 'taught_in_class';
    const classYear = parseTeacherNetworkClassYear(req.body?.class_year);
    if (classYear.provided && !classYear.valid) {
      return sendApiError(
        res,
        400,
        'INVALID_CLASS_YEAR',
        `Sınıf yılı ${TEACHER_NETWORK_MIN_CLASS_YEAR}-${TEACHER_NETWORK_MAX_CLASS_YEAR} aralığında olmalıdır.`
      );
    }
    const notes = String(req.body?.notes || '').trim().slice(0, 500);
    const createdVia = normalizeTeacherLinkCreatedVia(req.body?.created_via);
    const sourceSurface = normalizeTeacherLinkSourceSurface(req.body?.source_surface);
    const confirmSimilar = normalizeBooleanFlag(req.body?.confirm_similar);
    const now = new Date().toISOString();

    const pairLinks = listTeacherLinkPairDuplicates(alumniUserId, teacherUserId);
    const exactDuplicate = pairLinks.find((item) => (
      String(item?.relationship_type || '').trim().toLowerCase() === relationshipType
      && Number(item?.class_year ?? -1) === Number(classYear.value ?? -1)
    ));
    if (exactDuplicate) {
      return sendApiError(
        res,
        409,
        'RELATIONSHIP_ALREADY_EXISTS',
        'Bu öğretmen bağlantısı zaten kayıtlı.',
        { duplicates: pairLinks.slice(0, 5) },
        { duplicates: pairLinks.slice(0, 5) }
      );
    }

    if (pairLinks.length > 0 && !confirmSimilar) {
      return sendApiError(
        res,
        409,
        'SIMILAR_RELATIONSHIP_EXISTS',
        'Aynı öğretmen için benzer bir bağlantın zaten var. Devam etmeden önce mevcut kayıtları kontrol et.',
        {
          similar_links: pairLinks.slice(0, 5),
          requires_confirmation: true
        },
        {
          similar_links: pairLinks.slice(0, 5),
          requires_confirmation: true
        }
      );
    }

    const result = sqlRun(
      `INSERT INTO teacher_alumni_links
        (teacher_user_id, alumni_user_id, relationship_type, class_year, notes, confidence_score, created_via, source_surface, review_status, created_by, created_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [teacherUserId, alumniUserId, relationshipType, classYear.value, notes, 0.5, createdVia, sourceSurface, 'pending', alumniUserId, now]
    );
    const linkId = Number(result?.lastInsertRowid || 0);
    const confidenceScore = linkId ? refreshTeacherLinkConfidenceScore(linkId) : 0.5;

    addNotification({
      userId: teacherUserId,
      type: 'teacher_network_linked',
      sourceUserId: alumniUserId,
      entityId: linkId,
      message: 'Seni öğretmen ağına ekledi.'
    });
    recordNetworkingTelemetryEvent({
      userId: alumniUserId,
      eventName: 'teacher_link_created',
      sourceSurface,
      targetUserId: teacherUserId,
      entityType: 'teacher_link',
      entityId: linkId,
      metadata: {
        relationship_type: relationshipType,
        has_class_year: classYear.value !== null,
        review_status: 'pending'
      }
    });

    return res.json(apiSuccessEnvelope(
      'TEACHER_NETWORK_LINK_CREATED',
      'Öğretmen bağlantısı başarıyla kaydedildi.',
      {
        status: 'linked',
        relationship_type: relationshipType,
        class_year: classYear.value,
        confidence_score: confidenceScore,
        audit: {
          created_via: createdVia,
          source_surface: sourceSurface,
          review_status: 'pending',
          last_reviewed_by: null
        }
      },
      {
        status: 'linked',
        relationship_type: relationshipType,
        class_year: classYear.value,
        confidence_score: confidenceScore,
        created_via: createdVia,
        source_surface: sourceSurface,
        review_status: 'pending',
        last_reviewed_by: null
      }
    ));
  } catch (err) {
    console.error('teachers.network.link failed:', err);
    return sendApiError(res, 500, 'TEACHER_NETWORK_LINK_FAILED', 'Beklenmeyen bir hata oluştu.');
  }
});

app.post('/api/new/follow/:id', requireAuth, (req, res) => {
  const targetId = req.params.id;
  if (String(targetId) === String(req.session.userId)) return res.status(400).send('Kendini takip edemezsin.');
  const existing = sqlGet('SELECT id FROM follows WHERE follower_id = ? AND following_id = ?', [req.session.userId, targetId]);
  if (existing) {
    sqlRun('DELETE FROM follows WHERE id = ?', [existing.id]);
    recordNetworkingTelemetryEvent({
      userId: req.session.userId,
      eventName: 'follow_removed',
      sourceSurface: req.body?.source_surface,
      targetUserId: targetId,
      entityType: 'user',
      entityId: targetId
    });
    exploreSuggestionsResponseCache.clear();
    scheduleEngagementRecalculation('follow_changed');
    invalidateCacheNamespace(cacheNamespaces.feed);
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
  recordNetworkingTelemetryEvent({
    userId: req.session.userId,
    eventName: 'follow_created',
    sourceSurface: req.body?.source_surface,
    targetUserId: targetId,
    entityType: 'user',
    entityId: targetId
  });
  exploreSuggestionsResponseCache.clear();
  scheduleEngagementRecalculation('follow_changed');
  invalidateCacheNamespace(cacheNamespaces.feed);
  return res.json({ ok: true, following: true });
});

app.get('/api/new/follows', requireAuth, async (req, res) => {
  try {
    const limit = Math.min(Math.max(parseInt(req.query.limit || '30', 10), 1), 100);
    const offset = Math.max(parseInt(req.query.offset || '0', 10), 0);
    const sort = String(req.query.sort || 'engagement').trim().toLowerCase();
    const orderBy = sort === 'followed_at'
      ? 'COALESCE(NULLIF(f.created_at, \'\'), datetime(\'now\')) DESC, f.id DESC'
      : 'COALESCE(es.score, 0) DESC, COALESCE(NULLIF(f.created_at, \'\'), datetime(\'now\')) DESC, f.id DESC';
    const rows = await sqlAllAsync(
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
  } catch (err) {
    console.error('follows.list failed:', err);
    res.status(500).send('Beklenmeyen bir hata oluştu.');
  }
});

function escapeSqlLikeTerm(value) {
  return String(value || '').replace(/[\\%_]/g, '\\$&');
}

app.get('/api/new/admin/follows/:userId', requireAdmin, async (req, res) => {
  const targetUserId = Number(req.params.userId || 0);
  if (!Number.isInteger(targetUserId) || targetUserId <= 0) return res.status(400).send('Geçersiz üye kimliği.');
  const limit = Math.min(Math.max(parseInt(req.query.limit || '40', 10), 1), 200);
  const offset = Math.max(parseInt(req.query.offset || '0', 10), 0);

  try {
    const user = await sqlGetAsync('SELECT id, kadi, isim, soyisim FROM uyeler WHERE id = ?', [targetUserId]);
    if (!user) return res.status(404).send('Üye bulunamadı.');

  const follows = await sqlAllAsync(
    `SELECT f.id, f.following_id, f.created_at AS followed_at,
            u.kadi, u.isim, u.soyisim, u.resim, u.verified
     FROM follows f
     LEFT JOIN uyeler u ON u.id = f.following_id
     WHERE f.follower_id = ?
     ORDER BY COALESCE(NULLIF(f.created_at, ''), datetime('now')) DESC, f.id DESC
     LIMIT ? OFFSET ?`,
    [targetUserId, limit, offset]
  );

  const followTargets = follows
    .map((row) => ({
      followingId: Number(row.following_id || 0),
      kadi: String(row.kadi || '').trim()
    }))
    .filter((target) => Number.isInteger(target.followingId) && target.followingId > 0);
  const followingIds = Array.from(new Set(followTargets.map((target) => target.followingId)));
  const quoteTargets = followTargets
    .filter((target) => Boolean(target.kadi))
    .map((target) => ({
      followingId: target.followingId,
      needle: `%@${escapeSqlLikeTerm(target.kadi)}%`
    }));

  const messageCountMap = new Map();
  const recentMessagesMap = new Map();
  const postQuoteCountMap = new Map();
  const commentQuoteCountMap = new Map();
  const recentQuotesMap = new Map();

  if (followingIds.length > 0) {
    const messageCountRows = await sqlAllAsync(
      `SELECT CAST(kime AS INTEGER) AS following_id, COUNT(*) AS cnt
       FROM gelenkutusu
       WHERE CAST(kimden AS INTEGER) = CAST(? AS INTEGER)
         AND CAST(kime AS INTEGER) IN (${followingIds.map(() => '?').join(',')})
       GROUP BY CAST(kime AS INTEGER)`,
      [targetUserId, ...followingIds]
    );
    for (const row of messageCountRows) {
      messageCountMap.set(Number(row.following_id || 0), Number(row.cnt || 0));
    }

    const recentMessageRows = await sqlAllAsync(
      `SELECT following_id, id, konu, mesaj, tarih
       FROM (
         SELECT CAST(kime AS INTEGER) AS following_id,
                id,
                konu,
                mesaj,
                tarih,
                ROW_NUMBER() OVER (PARTITION BY CAST(kime AS INTEGER) ORDER BY id DESC) AS rn
         FROM gelenkutusu
         WHERE CAST(kimden AS INTEGER) = CAST(? AS INTEGER)
           AND CAST(kime AS INTEGER) IN (${followingIds.map(() => '?').join(',')})
       ) ranked
       WHERE rn <= 3
       ORDER BY following_id ASC, id DESC`,
      [targetUserId, ...followingIds]
    );
    for (const row of recentMessageRows) {
      const followingId = Number(row.following_id || 0);
      if (!recentMessagesMap.has(followingId)) recentMessagesMap.set(followingId, []);
      recentMessagesMap.get(followingId).push({
        id: row.id,
        konu: row.konu,
        mesaj: row.mesaj,
        tarih: row.tarih
      });
    }
  }

  if (quoteTargets.length > 0) {
    const valuesSql = quoteTargets.map(() => '(?, ?)').join(', ');
    const valuesParams = quoteTargets.flatMap((target) => [target.followingId, target.needle]);

    const postQuoteCountRows = await sqlAllAsync(
      `WITH targets(following_id, needle) AS (VALUES ${valuesSql})
       SELECT t.following_id, COUNT(p.id) AS cnt
       FROM targets t
       LEFT JOIN posts p
         ON p.user_id = ?
        AND LOWER(COALESCE(p.content, '')) LIKE LOWER(t.needle) ESCAPE '\\'
       GROUP BY t.following_id`,
      [...valuesParams, targetUserId]
    );
    for (const row of postQuoteCountRows) {
      postQuoteCountMap.set(Number(row.following_id || 0), Number(row.cnt || 0));
    }

    const commentQuoteCountRows = await sqlAllAsync(
      `WITH targets(following_id, needle) AS (VALUES ${valuesSql})
       SELECT t.following_id, COUNT(c.id) AS cnt
       FROM targets t
       LEFT JOIN post_comments c
         ON c.user_id = ?
        AND LOWER(COALESCE(c.comment, '')) LIKE LOWER(t.needle) ESCAPE '\\'
       GROUP BY t.following_id`,
      [...valuesParams, targetUserId]
    );
    for (const row of commentQuoteCountRows) {
      commentQuoteCountMap.set(Number(row.following_id || 0), Number(row.cnt || 0));
    }

    const recentQuoteRows = await sqlAllAsync(
      `WITH targets(following_id, needle) AS (VALUES ${valuesSql}),
            ranked AS (
              SELECT t.following_id,
                     p.id,
                     p.content,
                     p.created_at,
                     ROW_NUMBER() OVER (PARTITION BY t.following_id ORDER BY p.id DESC) AS rn
              FROM targets t
              JOIN posts p
                ON p.user_id = ?
               AND LOWER(COALESCE(p.content, '')) LIKE LOWER(t.needle) ESCAPE '\\'
            )
       SELECT following_id, id, content, created_at, 'post' AS source
       FROM ranked
       WHERE rn <= 3
       ORDER BY following_id ASC, id DESC`,
      [...valuesParams, targetUserId]
    );
    for (const row of recentQuoteRows) {
      const followingId = Number(row.following_id || 0);
      if (!recentQuotesMap.has(followingId)) recentQuotesMap.set(followingId, []);
      recentQuotesMap.get(followingId).push({
        id: row.id,
        content: row.content,
        created_at: row.created_at,
        source: row.source
      });
    }
  }

  const items = follows.map((row) => {
    const followingId = Number(row.following_id || 0);
    const quoteCount = Number(postQuoteCountMap.get(followingId) || 0) + Number(commentQuoteCountMap.get(followingId) || 0);
    return {
      ...row,
      messageCount: Number(messageCountMap.get(followingId) || 0),
      quoteCount,
      recentMessages: recentMessagesMap.get(followingId) || [],
      recentQuotes: recentQuotesMap.get(followingId) || []
    };
  });

    res.json({
      user,
      items,
      hasMore: items.length === limit
    });
  } catch (err) {
    console.error('admin.follows.list failed:', err);
    res.status(500).send('Beklenmeyen bir hata oluştu.');
  }
});

app.get('/api/new/explore/suggestions', requireAuth, async (req, res) => {
  try {
    const payload = await buildExploreSuggestionsPayload(req.session.userId, {
      limit: req.query.limit || '12',
      offset: req.query.offset || '0'
    });
    return res.json(apiSuccessEnvelope('EXPLORE_SUGGESTIONS_OK', 'Önerilen mezun kartları hazır.', payload, payload));
  } catch (err) {
    console.error('explore.suggestions failed:', err);
    return sendApiError(res, 500, 'EXPLORE_SUGGESTIONS_FAILED', 'Beklenmeyen bir hata oluştu.');
  }
});

app.get('/api/new/messages/unread', requireAuth, async (req, res) => {
  const row = await sqlGetAsync(
    'SELECT COUNT(*) AS cnt FROM gelenkutusu WHERE kime = ? AND aktifgelen = 1 AND yeni = 1',
    [req.session.userId]
  );
  res.json({ count: row?.cnt || 0 });
});

app.get('/api/new/online-members', requireAuth, async (req, res) => {
  try {
    const limit = Math.min(Math.max(parseInt(req.query.limit || '12', 10), 1), 80);
    const items = await listOnlineMembersAsync({
      limit,
      excludeUserId: String(req.query.excludeSelf || '1') === '1' ? req.session.userId : null
    });
    res.setHeader('Cache-Control', 'no-store');
    res.json({ items, count: items.length, now: new Date().toISOString() });
  } catch (err) {
    console.error('GET /api/new/online-members failed:', err);
    writeAppLog('error', 'online_members_failed', {
      message: err?.message || 'unknown_error',
      stack: String(err?.stack || '').slice(0, 1000)
    });
    // Degrade gracefully instead of returning 500 on mixed legacy schemas.
    res.setHeader('Cache-Control', 'no-store');
    res.json({ items: [], count: 0, now: new Date().toISOString(), degraded: true });
  }
});

app.get('/api/new/groups', requireAuth, (req, res) => {
  const limit = Math.min(Math.max(parseInt(req.query.limit || '20', 10), 1), 100);
  const offset = Math.max(parseInt(req.query.offset || '0', 10), 0);
  const cursor = Math.max(parseInt(req.query.cursor || '0', 10), 0);
  const whereParts = [];
  const whereParams = [];
  if (cursor > 0) {
    whereParts.push('id < ?');
    whereParams.push(cursor);
  }
  const whereSql = whereParts.length ? `WHERE ${whereParts.join(' AND ')}` : '';
  const groups = sqlAll(
    `SELECT *
     FROM groups
     ${whereSql}
     ORDER BY id DESC
     LIMIT ? OFFSET ?`,
    [...whereParams, limit + 1, cursor > 0 ? 0 : offset]
  );
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
  const isAdmin = hasAdminRole(user);
  const countMap = new Map(memberCounts.map((c) => [c.group_id, c.cnt]));
  const memberMap = new Map(membership.map((m) => [m.group_id, m.role]));
  const pendingSet = new Set(pending.map((p) => p.group_id));
  const inviteSet = new Set(invites.map((v) => v.group_id));
  const slice = groups.slice(0, limit);
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
    hasMore: groups.length > limit
  });
});

app.post('/api/new/groups', requireAuth, (req, res) => {
  const name = sanitizePlainUserText(String(req.body?.name || '').trim(), 120);
  if (!name) return res.status(400).send('Grup adı gerekli.');
  const description = formatUserText(req.body?.description || '');
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
  const isAdmin = hasAdminRole(user);
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
    `SELECT id, invited_user_id, invited_by, status
     FROM group_invites
     WHERE group_id = ? AND invited_user_id = ? AND status = 'pending'`,
    [groupId, req.session.userId]
  );
  if (!invite) return res.status(404).send('Bekleyen davet bulunamadı.');
  const group = sqlGet('SELECT id, name FROM groups WHERE id = ?', [groupId]);

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

  if (Number(invite.invited_by || 0) > 0 && !sameUserId(invite.invited_by, req.session.userId)) {
    addNotification({
      userId: invite.invited_by,
      type: action === 'accept' ? 'group_invite_accepted' : 'group_invite_rejected',
      sourceUserId: req.session.userId,
      entityId: Number(groupId || 0),
      message: action === 'accept'
        ? `${group?.name || 'Grup'} davetini kabul etti.`
        : `${group?.name || 'Grup'} davetini reddetti.`
    });
  }

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

app.post('/api/new/groups/:id/cover', requireAuth, uploadRateLimit, groupUpload.single('image'), async (req, res) => {
  if (!req.file) return res.status(400).send('Görsel seçilmedi.');
  const group = sqlGet('SELECT * FROM groups WHERE id = ?', [req.params.id]);
  if (!group) return res.status(404).send('Grup bulunamadı.');
  if (!isGroupManager(req, req.params.id)) {
    return res.status(403).send('Yetki yok.');
  }
  const processed = await processDiskImageUpload({
    req,
    res,
    file: req.file,
    bucket: 'group_cover',
    preset: uploadImagePresets.groupCover
  });
  if (!processed.ok) return res.status(processed.statusCode).send(processed.message);
  const image = processed.url || `/uploads/groups/${req.file.filename}`;
  sqlRun('UPDATE groups SET cover_image = ? WHERE id = ?', [image, req.params.id]);
  res.json({ ok: true, image });
});

app.post('/api/new/groups/:id/role', requireAuth, (req, res) => {
  const group = sqlGet('SELECT * FROM groups WHERE id = ?', [req.params.id]);
  if (!group) return res.status(404).send('Grup bulunamadı.');
  const member = sqlGet('SELECT role FROM group_members WHERE group_id = ? AND user_id = ?', [req.params.id, req.session.userId]);
  const user = getCurrentUser(req);
  const isAdmin = hasAdminSession(req, user);
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
  if (!sameUserId(targetId, req.session.userId)) {
    addNotification({
      userId: targetId,
      type: 'group_role_changed',
      sourceUserId: req.session.userId,
      entityId: Number(req.params.id || 0),
      message: `${group.name || 'Grup'} grubundaki rolün ${role} olarak güncellendi.`
    });
  }
  res.json({ ok: true });
});

app.get('/api/new/groups/:id', requireAuth, (req, res) => {
  const groupId = req.params.id;
  const group = sqlGet('SELECT * FROM groups WHERE id = ?', [groupId]);
  if (!group) return res.status(404).send('Grup bulunamadı.');
  const user = getCurrentUser(req);
  const isAdmin = hasAdminRole(user);
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
  if (!hasAdminRole(user) && !getGroupMember(groupId, req.session.userId)) {
    return res.status(403).send('Bu grup özel. Paylaşım için onaylı üyelik gerekli.');
  }
  const content = formatUserText(req.body?.content || '');
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

app.post('/api/new/groups/:id/posts/upload', requireAuth, uploadRateLimit, postUpload.single('image'), async (req, res) => {
  const groupId = req.params.id;
  const group = sqlGet('SELECT id FROM groups WHERE id = ?', [groupId]);
  if (!group) return res.status(404).send('Grup bulunamadı.');
  const user = getCurrentUser(req);
  if (!hasAdminRole(user) && !getGroupMember(groupId, req.session.userId)) {
    return res.status(403).send('Bu grup özel. Paylaşım için onaylı üyelik gerekli.');
  }
  const content = formatUserText(req.body?.content || '');
  const contentRaw = String(req.body?.content || '');
  const filter = req.body?.filter || '';
  let processedUpload = null;
  if (req.file?.path) {
    processedUpload = await processDiskImageUpload({
      req,
      res,
      file: req.file,
      bucket: 'group_post_image',
      preset: uploadImagePresets.postImage,
      filter
    });
    if (!processedUpload.ok) return res.status(processedUpload.statusCode).send(processedUpload.message);
  }
  const image = processedUpload?.url || null;
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
  if (!hasAdminRole(user) && !getGroupMember(groupId, req.session.userId)) {
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
  const title = sanitizePlainUserText(String(req.body?.title || '').trim(), 180);
  if (!title) return res.status(400).send('Başlık gerekli.');
  const now = new Date().toISOString();
  const result = sqlRun(
    `INSERT INTO group_events (group_id, title, description, location, starts_at, ends_at, created_at, created_by)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
    [
      groupId,
      title,
      formatUserText(req.body?.description || ''),
      sanitizePlainUserText(String(req.body?.location || '').trim(), 180),
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
  if (!hasAdminRole(user) && !getGroupMember(groupId, req.session.userId)) {
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
  const title = sanitizePlainUserText(String(req.body?.title || '').trim(), 180);
  const body = formatUserText(req.body?.body || '');
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

async function createEventRecord(req, { image = null } = {}) {
  const title = sanitizePlainUserText(String(req.body?.title || '').trim(), 180);
  const descriptionRaw = String(req.body?.description ?? req.body?.body ?? '');
  const location = sanitizePlainUserText(String(req.body?.location || '').trim(), 180);
  const startsAt = String(req.body?.starts_at ?? req.body?.date ?? '');
  const endsAt = String(req.body?.ends_at || '');
  if (!title) return { error: 'Başlık gerekli.' };
  const user = getCurrentUser(req);
  const isAdmin = hasAdminSession(req, user);
  const now = new Date().toISOString();
  const eventCols = await getTableColumnSetAsync('events');
  const columns = [];
  const values = [];
  const addColumn = (column, value) => {
    if (!eventCols.has(String(column || '').toLowerCase())) return;
    columns.push(column);
    values.push(value);
  };

  addColumn('title', title);
  addColumn('description', formatUserText(descriptionRaw));
  addColumn('location', location);
  addColumn('starts_at', startsAt ? startsAt : null);
  addColumn('ends_at', endsAt ? endsAt : null);
  addColumn('image', image || null);
  addColumn('created_at', now);
  addColumn('created_by', req.session.userId);
  addColumn('approved', toDbFlagForColumn('events', 'approved', isAdmin));
  addColumn('approved_by', isAdmin ? req.session.userId : null);
  addColumn('approved_at', isAdmin ? now : null);
  addColumn('show_response_counts', toDbFlagForColumn('events', 'show_response_counts', true));
  addColumn('show_attendee_names', toDbFlagForColumn('events', 'show_attendee_names', false));
  addColumn('show_decliner_names', toDbFlagForColumn('events', 'show_decliner_names', false));

  if (!columns.length || !columns.includes('title')) {
    throw new Error('events_table_missing_required_columns');
  }
  const placeholders = columns.map(() => '?').join(', ');
  const result = await sqlRunAsync(
    `INSERT INTO events (${columns.join(', ')}) VALUES (${placeholders})`,
    values
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
  const isAdmin = hasAdminSession(req, user);
  const limit = Math.min(Math.max(parseInt(req.query.limit || '20', 10), 1), 100);
  const offset = Math.max(parseInt(req.query.offset || '0', 10), 0);
  const orderExpr = dbDriver === 'postgres'
    ? 'COALESCE(e.starts_at, e.created_at)'
    : "COALESCE(NULLIF(e.starts_at, ''), e.created_at)";
  const rows = sqlAll(
    `SELECT e.*, u.kadi AS creator_kadi
     FROM events e
     LEFT JOIN uyeler u ON u.id = e.created_by
     ${isAdmin ? '' : "WHERE (COALESCE(CAST(e.approved AS INTEGER), 1) = 1 OR LOWER(CAST(e.approved AS TEXT)) IN ('true','evet','yes'))"}
     ORDER BY ${orderExpr} ASC, e.id DESC
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

app.post('/api/new/events', requireAuth, async (req, res) => {
  try {
    const created = await createEventRecord(req, { image: req.body?.image || null });
    if (created.error) return res.status(400).send(created.error);
    return res.json(created);
  } catch (err) {
    writeAppLog('error', 'event_create_failed', {
      userId: req.session?.userId || null,
      message: err?.message || 'unknown_error',
      stack: String(err?.stack || '').slice(0, 1000)
    });
    return res.status(500).send('Etkinlik kaydı sırasında beklenmeyen bir hata oluştu.');
  }
});

app.post('/api/new/events/upload', requireAuth, uploadRateLimit, postUpload.single('image'), async (req, res) => {
  try {
    let processedUpload = null;
    if (req.file?.path) {
      processedUpload = await processDiskImageUpload({
        req,
        res,
        file: req.file,
        bucket: 'event_image',
        preset: uploadImagePresets.eventImage
      });
      if (!processedUpload.ok) return res.status(processedUpload.statusCode).send(processedUpload.message);
    }
    const created = await createEventRecord(req, { image: processedUpload?.url || null });
    if (created.error) return res.status(400).send(created.error);
    return res.json(created);
  } catch (err) {
    writeAppLog('error', 'event_upload_create_failed', {
      userId: req.session?.userId || null,
      message: err?.message || 'unknown_error',
      stack: String(err?.stack || '').slice(0, 1000)
    });
    return res.status(500).send('Etkinlik yükleme sırasında beklenmeyen bir hata oluştu.');
  }
});

app.post('/api/new/events/:id/approve', requireAdmin, async (req, res) => {
  const approved = String(req.body?.approved || '1') === '1';
  await sqlRunAsync(
    'UPDATE events SET approved = ?, approved_by = ?, approved_at = ? WHERE id = ?',
    [toDbFlagForColumn('events', 'approved', approved), req.session.userId, new Date().toISOString(), req.params.id]
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
      type: 'event_response',
      sourceUserId: req.session.userId,
      entityId: req.params.id,
      message: response === 'attend' ? 'Etkinliğine katılacağını belirtti.' : 'Etkinliğine katılamayacağını belirtti.'
    });
  }
  const canSeePrivate = sameUserId(event.created_by, req.session.userId);
  const bundle = getEventResponseBundle(event, req.session.userId, canSeePrivate);
  res.json({ ok: true, myResponse: bundle.myResponse, counts: bundle.counts });
});

app.post('/api/new/events/:id/response-visibility', requireAuth, async (req, res) => {
  const event = await sqlGetAsync('SELECT id, created_by FROM events WHERE id = ?', [req.params.id]);
  if (!event) return res.status(404).send('Etkinlik bulunamadı.');
  const user = getCurrentUser(req);
  const isAdmin = hasAdminSession(req, user);
  if (!sameUserId(event.created_by, req.session.userId) && !isAdmin) {
    return res.status(403).send('Sadece etkinlik sahibi ayarları değiştirebilir.');
  }
  const showCounts = Boolean(req.body?.showCounts);
  const showAttendeeNames = Boolean(req.body?.showAttendeeNames);
  const showDeclinerNames = Boolean(req.body?.showDeclinerNames);
  await sqlRunAsync(
    `UPDATE events
     SET show_response_counts = ?, show_attendee_names = ?, show_decliner_names = ?
     WHERE id = ?`,
    [
      toDbFlagForColumn('events', 'show_response_counts', showCounts),
      toDbFlagForColumn('events', 'show_attendee_names', showAttendeeNames),
      toDbFlagForColumn('events', 'show_decliner_names', showDeclinerNames),
      req.params.id
    ]
  );
  const updated = await sqlGetAsync(
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
  const comment = formatUserText(commentRaw);
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
  const event = sqlGet(
    "SELECT id, title, created_by FROM events WHERE id = ? AND (COALESCE(CAST(approved AS INTEGER), 1) = 1 OR LOWER(CAST(approved AS TEXT)) IN ('true','evet','yes'))",
    [req.params.id]
  );
  if (!event) return res.status(404).send('Etkinlik bulunamadı.');
  const user = getCurrentUser(req);
  const isAdmin = hasAdminSession(req, user);
  if (!isAdmin && !sameUserId(event.created_by, req.session.userId)) {
    return res.status(403).send('Sadece etkinlik sahibi veya admin bildirim gonderebilir.');
  }
  const mode = String(req.body?.mode || 'invite').trim().toLowerCase();
  const normalizedMode = mode === 'reminder' || mode === 'starts_soon' ? mode : 'invite';
  const targets = normalizedMode === 'invite'
    ? (sqlAll('SELECT follower_id AS user_id FROM follows WHERE following_id = ?', [req.session.userId]) || [])
    : (sqlAll(
        `SELECT DISTINCT user_id
         FROM event_responses
         WHERE event_id = ?
           AND LOWER(TRIM(COALESCE(response, ''))) = 'attend'`,
        [req.params.id]
      ) || []);
  let count = 0;
  for (const row of targets) {
    const targetUserId = Number(row?.user_id || row?.follower_id || 0);
    if (!targetUserId || sameUserId(targetUserId, req.session.userId)) continue;
    addNotification({
      userId: targetUserId,
      type: normalizedMode === 'invite' ? 'event_invite' : normalizedMode === 'reminder' ? 'event_reminder' : 'event_starts_soon',
      sourceUserId: req.session.userId,
      entityId: event.id,
      message: normalizedMode === 'invite'
        ? `Seni "${event.title}" etkinliğine davet etti.`
        : normalizedMode === 'reminder'
          ? `"${event.title}" etkinliği için hatırlatma gönderdi.`
          : `"${event.title}" etkinliği çok yakında başlıyor.`
    });
    count += 1;
  }
  res.json({ ok: true, count, mode: normalizedMode });
});

app.get('/api/new/announcements', requireAuth, (req, res) => {
  const user = getCurrentUser(req);
  const isAdmin = hasAdminSession(req, user);
  const limit = Math.min(Math.max(parseInt(req.query.limit || '20', 10), 1), 100);
  const offset = Math.max(parseInt(req.query.offset || '0', 10), 0);
  const rows = sqlAll(
    `SELECT a.*, u.kadi AS creator_kadi
     FROM announcements a
     LEFT JOIN uyeler u ON u.id = a.created_by
     ${isAdmin ? '' : "WHERE (COALESCE(CAST(a.approved AS INTEGER), 1) = 1 OR LOWER(CAST(a.approved AS TEXT)) IN ('true','evet','yes'))"}
     ORDER BY a.id DESC`
     + ' LIMIT ? OFFSET ?',
    [limit, offset]
  );
  res.json({ items: rows, hasMore: rows.length === limit });
});

app.post('/api/new/announcements', requireAuth, async (req, res) => {
  const { body, image } = req.body || {};
  const title = sanitizePlainUserText(String(req.body?.title || '').trim(), 180);
  const formattedBody = formatUserText(body || '');
  if (!title || isFormattedContentEmpty(formattedBody)) return res.status(400).send('Başlık ve içerik gerekli.');
  const user = getCurrentUser(req);
  const isAdmin = hasAdminSession(req, user);
  const now = new Date().toISOString();
  await sqlRunAsync(
    `INSERT INTO announcements (title, body, image, created_at, created_by, approved, approved_by, approved_at)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
    [
      title,
      formattedBody,
      image || null,
      now,
      req.session.userId,
      toDbFlagForColumn('announcements', 'approved', isAdmin),
      isAdmin ? req.session.userId : null,
      isAdmin ? now : null
    ]
  );
  res.json({ ok: true, pending: !isAdmin });
});

app.post('/api/new/announcements/upload', requireAuth, uploadRateLimit, postUpload.single('image'), async (req, res) => {
  const title = sanitizePlainUserText(String(req.body?.title || '').trim(), 180);
  const bodyRaw = String(req.body?.body || '');
  const body = formatUserText(bodyRaw);
  if (!title || isFormattedContentEmpty(body)) return res.status(400).send('Başlık ve içerik gerekli.');
  const user = getCurrentUser(req);
  const isAdmin = hasAdminSession(req, user);
  let processedUpload = null;
  if (req.file?.path) {
    processedUpload = await processDiskImageUpload({
      req,
      res,
      file: req.file,
      bucket: 'announcement_image',
      preset: uploadImagePresets.announcementImage
    });
    if (!processedUpload.ok) return res.status(processedUpload.statusCode).send(processedUpload.message);
  }
  const now = new Date().toISOString();
  await sqlRunAsync(
    `INSERT INTO announcements (title, body, image, created_at, created_by, approved, approved_by, approved_at)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
    [
      title,
      body,
      processedUpload?.url || null,
      now,
      req.session.userId,
      toDbFlagForColumn('announcements', 'approved', isAdmin),
      isAdmin ? req.session.userId : null,
      isAdmin ? now : null
    ]
  );
  res.json({ ok: true, pending: !isAdmin });
});

app.post('/api/new/announcements/:id/approve', requireAdmin, async (req, res) => {
  const approvedInput = Object.prototype.hasOwnProperty.call(req.body || {}, 'approved')
    ? req.body?.approved
    : '1';
  const approved = String(approvedInput) === '1';
  const announcement = await sqlGetAsync('SELECT id, created_by, title FROM announcements WHERE id = ?', [req.params.id]);
  await sqlRunAsync(
    'UPDATE announcements SET approved = ?, approved_by = ?, approved_at = ? WHERE id = ?',
    [toDbFlagForColumn('announcements', 'approved', approved), req.session.userId, new Date().toISOString(), req.params.id]
  );
  if (announcement?.created_by && !sameUserId(announcement.created_by, req.session.userId)) {
    addNotification({
      userId: announcement.created_by,
      type: approved ? 'announcement_approved' : 'announcement_rejected',
      sourceUserId: req.session.userId,
      entityId: Number(req.params.id || 0),
      message: approved
        ? `"${announcement.title || 'Duyuru'}" duyurun yayınlandı.`
        : `"${announcement.title || 'Duyuru'}" duyurun reddedildi.`
    });
  }
  res.json({ ok: true });
});

app.delete('/api/new/announcements/:id', requireAdmin, (req, res) => {
  sqlRun('DELETE FROM announcements WHERE id = ?', [req.params.id]);
  res.json({ ok: true });
});

app.get('/api/new/jobs', requireAuth, async (req, res) => {
  ensureJobApplicationsTable();
  const search = sanitizePlainUserText(String(req.query.search || '').trim(), 120).toLowerCase();
  const location = sanitizePlainUserText(String(req.query.location || '').trim(), 120).toLowerCase();
  const jobType = sanitizePlainUserText(String(req.query.job_type || '').trim(), 60).toLowerCase();
  const limit = Math.min(Math.max(parseInt(req.query.limit || '40', 10), 1), 100);
  const offset = Math.max(parseInt(req.query.offset || '0', 10), 0);

  const where = [];
  const params = [];
  if (search) {
    where.push('(LOWER(j.title) LIKE ? OR LOWER(j.company) LIKE ? OR LOWER(j.description) LIKE ?)');
    params.push(`%${search}%`, `%${search}%`, `%${search}%`);
  }
  if (location) {
    where.push('LOWER(j.location) LIKE ?');
    params.push(`%${location}%`);
  }
  if (jobType) {
    where.push('LOWER(j.job_type) = ?');
    params.push(jobType);
  }

  const rows = await sqlAllAsync(
    `SELECT j.*, u.kadi AS poster_kadi, u.isim AS poster_isim, u.soyisim AS poster_soyisim,
            ja_self.id AS my_application_id,
            ja_self.status AS my_application_status,
            ja_self.created_at AS my_application_created_at,
            ja_self.reviewed_at AS my_application_reviewed_at,
            ja_self.decision_note AS my_application_decision_note
     FROM jobs j
     LEFT JOIN uyeler u ON u.id = j.poster_id
     LEFT JOIN job_applications ja_self ON ja_self.job_id = j.id AND ja_self.applicant_id = ?
     ${where.length ? `WHERE ${where.join(' AND ')}` : ''}
     ORDER BY j.id DESC
     LIMIT ? OFFSET ?`,
    [req.session.userId, ...params, limit, offset]
  );

  res.json({ items: rows, hasMore: rows.length === limit });
});

app.post('/api/new/jobs/:id/apply', requireAuth, async (req, res) => {
  if (!ensureVerifiedSocialHubMember(req, res)) return;
  const jobId = Number(req.params.id || 0);
  if (!jobId) return res.status(400).send('Geçersiz iş ilanı kimliği.');

  ensureJobApplicationsTable();

  const job = await sqlGetAsync('SELECT id, poster_id, title FROM jobs WHERE id = ?', [jobId]);
  if (!job) return res.status(404).send('İş ilanı bulunamadı.');
  if (sameUserId(job.poster_id, req.session.userId)) {
    return res.status(409).json({ code: 'CANNOT_APPLY_OWN_JOB', message: 'Kendi ilanına başvuru yapamazsın.' });
  }

  const existing = await sqlGetAsync('SELECT id FROM job_applications WHERE job_id = ? AND applicant_id = ?', [jobId, req.session.userId]);
  if (existing) {
    return res.status(409).json({ code: 'ALREADY_APPLIED', message: 'Bu iş ilanına zaten başvuru yaptın.' });
  }

  const coverLetter = formatUserText(String(req.body?.cover_letter || ''));
  const now = new Date().toISOString();
  const result = await sqlRunAsync(
    'INSERT INTO job_applications (job_id, applicant_id, cover_letter, status, created_at) VALUES (?, ?, ?, ?, ?)',
    [jobId, req.session.userId, isFormattedContentEmpty(coverLetter) ? null : coverLetter, 'pending', now]
  );

  addNotification({
    userId: Number(job.poster_id),
    type: 'job_application',
    sourceUserId: Number(req.session.userId),
    entityId: jobId,
    message: `"${job.title || 'İş ilanı'}" ilanına yeni bir başvuru geldi.`
  });

  res.json({ ok: true, id: result?.lastInsertRowid, status: 'applied' });
});

app.get('/api/new/jobs/:id/applications', requireAuth, async (req, res) => {
  const jobId = Number(req.params.id || 0);
  if (!jobId) return res.status(400).send('Geçersiz iş ilanı kimliği.');

  ensureJobApplicationsTable();

  const user = getCurrentUser(req);
  const isAdmin = hasAdminSession(req, user);
  const job = await sqlGetAsync('SELECT id, poster_id FROM jobs WHERE id = ?', [jobId]);
  if (!job) return res.status(404).send('İş ilanı bulunamadı.');
  if (!isAdmin && !sameUserId(job.poster_id, req.session.userId)) {
    return res.status(403).send('Bu ilanın başvurularını görüntüleme yetkin yok.');
  }

  const rows = await sqlAllAsync(
    `SELECT ja.id, ja.job_id, ja.applicant_id, ja.cover_letter, ja.created_at,
            ja.status, ja.reviewed_at, ja.reviewed_by, ja.decision_note,
            u.kadi, u.isim, u.soyisim, u.sirket, u.unvan, u.linkedin_url,
            reviewer.kadi AS reviewed_by_kadi, reviewer.isim AS reviewed_by_isim, reviewer.soyisim AS reviewed_by_soyisim
     FROM job_applications ja
     LEFT JOIN uyeler u ON u.id = ja.applicant_id
     LEFT JOIN uyeler reviewer ON reviewer.id = ja.reviewed_by
     WHERE ja.job_id = ?
     ORDER BY ja.id DESC`,
    [jobId]
  );

  res.json({ items: rows });
});

app.post('/api/new/jobs/:jobId/applications/:applicationId/review', requireAuth, async (req, res) => {
  const jobId = Number(req.params.jobId || 0);
  const applicationId = Number(req.params.applicationId || 0);
  if (!jobId || !applicationId) return sendApiError(res, 400, 'INVALID_JOB_APPLICATION_ID', 'Geçersiz başvuru kimliği.');

  ensureJobApplicationsTable();

  const actor = getCurrentUser(req);
  const isAdmin = hasAdminSession(req, actor);
  const nextStatus = String(req.body?.status || '').trim().toLowerCase();
  const allowedStatuses = new Set(['reviewed', 'accepted', 'rejected']);
  if (!allowedStatuses.has(nextStatus)) {
    return sendApiError(res, 400, 'INVALID_JOB_APPLICATION_STATUS', 'Geçersiz başvuru durumu.');
  }

  const applicationRow = await sqlGetAsync(
    `SELECT ja.id, ja.job_id, ja.applicant_id, ja.status, j.poster_id, j.title
     FROM job_applications ja
     LEFT JOIN jobs j ON j.id = ja.job_id
     WHERE ja.id = ? AND ja.job_id = ?`,
    [applicationId, jobId]
  );
  if (!applicationRow) {
    return sendApiError(res, 404, 'JOB_APPLICATION_NOT_FOUND', 'İş başvurusu bulunamadı.');
  }
  if (!isAdmin && !sameUserId(applicationRow.poster_id, req.session.userId)) {
    return sendApiError(res, 403, 'JOB_APPLICATION_REVIEW_FORBIDDEN', 'Bu başvuruyu değerlendirme yetkin yok.');
  }

  const decisionNote = sanitizePlainUserText(String(req.body?.decision_note || '').trim(), 500) || null;
  const reviewedAt = new Date().toISOString();
  await sqlRunAsync(
    `UPDATE job_applications
     SET status = ?, reviewed_at = ?, reviewed_by = ?, decision_note = ?
     WHERE id = ? AND job_id = ?`,
    [nextStatus, reviewedAt, req.session.userId, decisionNote, applicationId, jobId]
  );

  let notificationType = 'job_application_reviewed';
  if (nextStatus === 'accepted') notificationType = 'job_application_accepted';
  else if (nextStatus === 'rejected') notificationType = 'job_application_rejected';
  addNotification({
    userId: Number(applicationRow.applicant_id),
    type: notificationType,
    sourceUserId: Number(req.session.userId),
    entityId: applicationId,
    message: nextStatus === 'accepted'
      ? `"${applicationRow.title || 'İş ilanı'}" başvurun kabul edildi.`
      : nextStatus === 'rejected'
        ? `"${applicationRow.title || 'İş ilanı'}" başvurun olumsuz sonuçlandı.`
        : `"${applicationRow.title || 'İş ilanı'}" başvurun inceleniyor.`
  });

  return res.json(apiSuccessEnvelope(
    'JOB_APPLICATION_REVIEWED',
    'İş başvurusu güncellendi.',
    {
      id: applicationId,
      job_id: jobId,
      status: nextStatus,
      reviewed_at: reviewedAt,
      reviewed_by: Number(req.session.userId),
      decision_note: decisionNote
    },
    {
      id: applicationId,
      job_id: jobId,
      status: nextStatus,
      reviewed_at: reviewedAt,
      reviewed_by: Number(req.session.userId),
      decision_note: decisionNote
    }
  ));
});

app.post('/api/new/jobs', requireAuth, async (req, res) => {
  if (!ensureVerifiedSocialHubMember(req, res)) return;
  const company = sanitizePlainUserText(String(req.body?.company || '').trim(), 140);
  const title = sanitizePlainUserText(String(req.body?.title || '').trim(), 180);
  const description = formatUserText(String(req.body?.description || ''));
  const location = sanitizePlainUserText(String(req.body?.location || '').trim(), 120);
  const jobType = sanitizePlainUserText(String(req.body?.job_type || '').trim(), 60);
  const link = sanitizePlainUserText(String(req.body?.link || '').trim(), 500);
  if (!company || !title || isFormattedContentEmpty(description)) {
    return res.status(400).send('Şirket, başlık ve açıklama gerekli.');
  }
  if (link && !/^https?:\/\//i.test(link)) return res.status(400).send('Link http:// veya https:// ile başlamalı.');
  const now = new Date().toISOString();
  const result = await sqlRunAsync(
    `INSERT INTO jobs (poster_id, company, title, description, location, job_type, link, created_at)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
    [req.session.userId, company, title, description, location, jobType, link || null, now]
  );
  res.json({ ok: true, id: result?.lastInsertRowid });
});

app.delete('/api/new/jobs/:id', requireAuth, (req, res) => {
  const user = getCurrentUser(req);
  const isAdmin = hasAdminSession(req, user);
  const row = sqlGet('SELECT id, poster_id FROM jobs WHERE id = ?', [req.params.id]);
  if (!row) return res.status(404).send('İş ilanı bulunamadı.');
  if (!isAdmin && !sameUserId(row.poster_id, req.session.userId)) return res.status(403).send('Bu ilanı silme yetkin yok.');
  sqlRun('DELETE FROM jobs WHERE id = ?', [req.params.id]);
  res.json({ ok: true });
});

app.get('/api/new/chat/messages', requireAuth, phase1Domain.controllers.chat.listMessages);

function broadcastChatMessage(item) {
  try {
    if (!item) return;
    const payload = {
      type: 'chat:new',
      id: item.id,
      user_id: item.user_id,
      message: item.message,
      created_at: item.created_at,
      user: {
        id: item.user_id,
        kadi: item.kadi,
        isim: item.isim,
        soyisim: item.soyisim,
        resim: item.resim,
        verified: item.verified
      }
    };
    broadcastChatEventLocal(payload);
    Promise.resolve(realtimeBus?.publishChat?.(payload)).catch(() => {});
  } catch {
    // ignore broadcast errors
  }
}

function broadcastChatUpdate(item) {
  try {
    if (!item) return;
    const payload = {
      type: 'chat:updated',
      id: item.id,
      user_id: item.user_id,
      message: item.message,
      created_at: item.created_at,
      user: {
        id: item.user_id,
        kadi: item.kadi,
        isim: item.isim,
        soyisim: item.soyisim,
        resim: item.resim,
        verified: item.verified
      }
    };
    broadcastChatEventLocal(payload);
    Promise.resolve(realtimeBus?.publishChat?.(payload)).catch(() => {});
  } catch {
    // ignore broadcast errors
  }
}

function broadcastChatDelete(messageId) {
  try {
    if (!messageId) return;
    const payload = {
      type: 'chat:deleted',
      id: Number(messageId)
    };
    broadcastChatEventLocal(payload);
    Promise.resolve(realtimeBus?.publishChat?.(payload)).catch(() => {});
  } catch {
    // ignore broadcast errors
  }
}

function broadcastChatEventLocal(payload) {
  try {
    if (!payload || !chatWss || !chatWss.clients) return;
    const outgoing = JSON.stringify(payload);
    chatWss.clients.forEach((client) => {
      if (client.readyState !== 1) return;
      if (!Number(client.sdalUserId || 0)) return;
      client.send(outgoing);
    });
  } catch {
    // ignore local broadcast errors
  }
}

function canManageChatMessage(req, messageRow) {
  if (!messageRow) return false;
  if (sameUserId(messageRow.user_id, req.session.userId)) return true;
  const currentUser = getCurrentUser(req);
  return hasAdminSession(req, currentUser);
}

app.post('/api/new/chat/send', requireAuth, chatSendIdempotency, chatSendRateLimit, phase1Domain.controllers.chat.sendMessage);

app.patch('/api/new/chat/messages/:id', requireAuth, phase1Domain.controllers.chat.updateMessage);

app.post('/api/new/chat/messages/:id/edit', requireAuth, phase1Domain.controllers.chat.updateMessage);

app.delete('/api/new/chat/messages/:id', requireAuth, phase1Domain.controllers.chat.deleteMessage);

app.post('/api/new/chat/messages/:id/delete', requireAuth, phase1Domain.controllers.chat.deleteMessage);

app.post('/api/new/verified/request', requireAuth, (req, res) => {
  const user = getCurrentUser(req);
  if (Number(user?.verified || 0) === 1) {
    return res.status(403).send('Profilin zaten doğrulanmış.');
  }
  const existing = sqlGet('SELECT id FROM verification_requests WHERE user_id = ? AND status = ?', [req.session.userId, 'pending']);
  if (existing) return res.status(400).send('Zaten bekleyen bir talebiniz var.');
  const proofPath = String(req.body?.proof_path || '').trim();
  const proofImageRecordId = String(req.body?.proof_image_record_id || '').trim();
  if (proofPath) {
    const isLegacyProof = proofPath.startsWith('/uploads/verification-proofs/');
    const isVariantProof = proofPath.startsWith('/uploads/images/') || proofPath.startsWith('/api/media/image/');
    if (!isLegacyProof && !isVariantProof) {
      return res.status(400).send('Geçersiz kanıt dosyası yolu.');
    }
  }
  if (proofImageRecordId) {
    const proofVariants = getImageVariants(proofImageRecordId, sqlGet, uploadsDir);
    if (!proofVariants) return res.status(400).send('Kanıt görseli bulunamadı.');
  }
  sqlRun('INSERT INTO verification_requests (user_id, status, proof_path, proof_image_record_id, created_at) VALUES (?, ?, ?, ?, ?)', [
    req.session.userId,
    'pending',
    proofPath || null,
    proofImageRecordId || null,
    new Date().toISOString()
  ]);
  sqlRun('UPDATE uyeler SET verification_status = ? WHERE id = ?', ['pending', req.session.userId]);
  res.json({ ok: true });
});

app.post('/api/new/verified/proof', requireAuth, uploadRateLimit, verificationProofUpload.single('proof'), async (req, res) => {
  const user = getCurrentUser(req);
  if (Number(user?.verified || 0) === 1) {
    return res.status(403).send('Profilin zaten doğrulanmış.');
  }
  if (!req.file?.filename) return res.status(400).send('Dosya yüklenemedi.');
  const uploadValidation = validateUploadedFileSafety(req.file.path, { allowedMimes: ['image/jpeg', 'image/png', 'application/pdf'] });
  if (!uploadValidation.ok) {
    cleanupUploadedFile(req.file.path);
    return res.status(400).send(uploadValidation.reason);
  }
  const maxBytes = getMediaUploadLimitBytes();
  if (Number(req.file.size || 0) > maxBytes) {
    cleanupUploadedFile(req.file.path);
    return res.status(400).send(`Dosya boyutu çok büyük. Maksimum: ${(maxBytes / (1024 * 1024)).toFixed(1)} MB.`);
  }
  const quotaOk = await enforceUploadQuota(req, res, {
    fileSize: Number(req.file.size || 0),
    bucket: 'verification_proof'
  });
  if (!quotaOk) {
    cleanupUploadedFile(req.file.path);
    return res.status(429).send('Günlük yükleme kotan doldu. Lütfen daha sonra tekrar dene.');
  }
  const ext = path.extname(req.file.filename || '').toLowerCase();
  if (ext === '.pdf') {
    return res.json({
      ok: true,
      proof_path: `/uploads/verification-proofs/${req.file.filename}`,
      proof_image_record_id: null
    });
  }

  try {
    const fileBuffer = fs.readFileSync(req.file.path);
    const uploadResult = await processUpload({
      buffer: fileBuffer,
      mimeType: req.file.mimetype || 'image/jpeg',
      userId: req.session.userId,
      entityType: 'verification_proof',
      entityId: String(req.session.userId),
      sqlGet,
      sqlRun,
      uploadsDir,
      writeAppLog
    });
    try {
      if (fs.existsSync(req.file.path)) fs.unlinkSync(req.file.path);
    } catch {
      // best effort
    }
    return res.json({
      ok: true,
      proof_path: uploadResult?.variants?.fullUrl || `/uploads/verification-proofs/${req.file.filename}`,
      proof_image_record_id: uploadResult?.imageId || null
    });
  } catch (err) {
    writeAppLog('error', 'verification_proof_variant_generation_failed', { userId: req.session.userId, message: err?.message });
    return res.json({
      ok: true,
      proof_path: `/uploads/verification-proofs/${req.file.filename}`,
      proof_image_record_id: null
    });
  }
});

app.get('/api/new/admin/verification-requests', requireModerationPermission('requests.view'), (req, res) => {
  const actor = req.authUser || getCurrentUser(req);
  const scope = getModerationScopeContext(actor);
  const { page, limit } = parseAdminListPagination(req.query, { defaultLimit: 40, maxLimit: 200 });
  const status = String(req.query.status || '').trim().toLowerCase();
  const q = String(req.query.q || '').trim();
  const params = [];
  const whereParts = [
    "(u.role IS NULL OR LOWER(COALESCE(u.role, 'user')) != 'root')"
  ];
  if (status) {
    whereParts.push("LOWER(COALESCE(r.status, '')) = ?");
    params.push(status);
  }
  if (q) {
    whereParts.push('(LOWER(CAST(u.kadi AS TEXT)) LIKE LOWER(?) OR LOWER(CAST(u.isim AS TEXT)) LIKE LOWER(?) OR LOWER(CAST(u.soyisim AS TEXT)) LIKE LOWER(?))');
    params.push(`%${q}%`, `%${q}%`, `%${q}%`);
  }
  const scopeFilter = applyModerationScopeFilter(scope, params, 'u.mezuniyetyili');
  const whereSql = `WHERE ${whereParts.join(' AND ')}${scopeFilter}`;

  const total = Number(sqlGet(
    `SELECT COUNT(*) AS cnt
     FROM verification_requests r
     LEFT JOIN uyeler u ON u.id = r.user_id
     ${whereSql}`,
    params
  )?.cnt || 0);
  const pages = Math.max(Math.ceil(total / limit), 1);
  const safePage = Math.min(page, pages);
  const safeOffset = (safePage - 1) * limit;

  const items = sqlAll(
    `SELECT r.id, r.user_id, r.status, r.proof_path, r.proof_image_record_id, r.created_at,
            u.kadi, u.isim, u.soyisim, u.mezuniyetyili, u.resim
     FROM verification_requests r
     LEFT JOIN uyeler u ON u.id = r.user_id
     ${whereSql}
     ORDER BY r.id DESC
     LIMIT ? OFFSET ?`,
    [...params, limit, safeOffset]
  );
  res.json({
    items,
    meta: {
      page: safePage,
      pages,
      limit,
      total,
      status: status || '',
      q
    }
  });
});

function assignUserToCohort(userId) {
  const user = sqlGet('SELECT id, mezuniyetyili FROM uyeler WHERE id = ?', [userId]);
  if (!user || !user.mezuniyetyili || user.mezuniyetyili === '0') return;
  const normalized = normalizeCohortValue(user.mezuniyetyili);
  const isTeacher = normalized === TEACHER_COHORT_VALUE;
  const year = parseInt(normalized, 10);
  if (!isTeacher && (isNaN(year) || year < 1960 || year > new Date().getFullYear() + 5)) return;

  const cohortName = isTeacher ? 'Öğretmenler' : `${year} Mezunları`;
  let group = sqlGet('SELECT id FROM groups WHERE name = ?', [cohortName]);
  if (!group) {
    const result = sqlRun('INSERT INTO groups (name, description, cover_image, owner_id, created_at, visibility, show_contact_hint) VALUES (?, ?, ?, ?, ?, ?, ?)', [
      cohortName,
      isTeacher ? 'SDAL öğretmenlerine özel iletişim ağı.' : `SDAL ${year} yılı mezunlarına özel iletişim ağı.`,
      '/images/cohort_default.jpg',
      1,
      new Date().toISOString(),
      'public',
      1
    ]);
    group = { id: result.lastInsertRowid };
    sqlRun('INSERT INTO group_members (group_id, user_id, role, created_at) VALUES (?, ?, ?, ?)', [
      group.id,
      1,
      'owner',
      new Date().toISOString()
    ]);
  }
  
  const isMember = sqlGet('SELECT id FROM group_members WHERE group_id = ? AND user_id = ?', [group.id, user.id]);
  if (!isMember) {
    sqlRun('INSERT INTO group_members (group_id, user_id, role, created_at) VALUES (?, ?, ?, ?)', [
      group.id,
      user.id,
      'member',
      new Date().toISOString()
    ]);
  }
}

app.post('/api/new/admin/verification-requests/:id', requireModerationPermission('requests.moderate'), (req, res) => {
  const status = req.body?.status;
  const requestId = Number(req.params.id || 0);
  if (!requestId) return res.status(400).send('Geçersiz talep ID.');
  if (!['approved', 'rejected'].includes(status)) return res.status(400).send('Geçersiz durum.');
  const row = sqlGet(
    `SELECT r.*, u.mezuniyetyili
     FROM verification_requests r
     LEFT JOIN uyeler u ON u.id = r.user_id
     WHERE r.id = ?`,
    [requestId]
  );
  if (!row) return res.status(404).send('Talep bulunamadı.');
  const scope = getModerationScopeContext(req.authUser || getCurrentUser(req));
  if (scope.isScopedModerator) {
    const targetYear = String(row.mezuniyetyili || '').trim();
    if (!targetYear || !scope.years.includes(targetYear)) {
      return res.status(403).send('Bu doğrulama talebi kapsamınız dışında.');
    }
  }
  sqlRun('UPDATE verification_requests SET status = ?, reviewed_at = ?, reviewer_id = ? WHERE id = ?', [
    status,
    new Date().toISOString(),
    req.session.userId,
    requestId
  ]);
  const newVerificationStatus = status === 'approved' ? 'verified' : 'rejected';
  sqlRun('UPDATE uyeler SET verified = ?, verification_status = ? WHERE id = ?', [status === 'approved' ? 1 : 0, newVerificationStatus, row.user_id]);
  
  if (status === 'approved') {
    assignUserToCohort(row.user_id);
  }

  addNotification({
    userId: row.user_id,
    type: status === 'approved' ? 'verification_approved' : 'verification_rejected',
    sourceUserId: req.session.userId,
    entityId: requestId,
    message: status === 'approved'
      ? 'Profil doğrulama talebin onaylandı.'
      : 'Profil doğrulama talebin reddedildi.'
  });

  logAdminAction(req, 'verification_request_review', {
    targetType: 'verification_request',
    targetId: requestId,
    userId: row.user_id,
    status
  });
  res.json({ ok: true });
});

app.get('/api/new/admin/requests/notifications', requireAdmin, (_req, res) => {
  const categories = sqlAll(
    `SELECT c.category_key, c.label, c.description,
            COUNT(r.id) AS pending_count,
            MAX(r.created_at) AS latest_at
     FROM request_categories c
     LEFT JOIN member_requests r ON r.category_key = c.category_key AND r.status = 'pending'
     WHERE c.active = 1
     GROUP BY c.category_key, c.label, c.description
     ORDER BY pending_count DESC, c.id ASC`
  );
  res.json({ items: categories });
});

app.get('/api/new/admin/requests', requireModerationPermission('requests.view'), (req, res) => {
  const actor = req.authUser || getCurrentUser(req);
  const scope = getModerationScopeContext(actor);
  const { page, limit } = parseAdminListPagination(req.query, { defaultLimit: 60, maxLimit: 250 });
  const categoryKey = String(req.query.category || '').trim();
  const status = String(req.query.status || 'pending').trim();
  const q = String(req.query.q || '').trim();
  const where = ["(u.role IS NULL OR LOWER(COALESCE(u.role, 'user')) != 'root')"];
  const params = [];
  if (categoryKey) {
    where.push('r.category_key = ?');
    params.push(categoryKey);
  }
  if (status) {
    where.push('r.status = ?');
    params.push(status);
  }
  if (q) {
    where.push('(LOWER(CAST(u.kadi AS TEXT)) LIKE LOWER(?) OR LOWER(CAST(u.isim AS TEXT)) LIKE LOWER(?) OR LOWER(CAST(u.soyisim AS TEXT)) LIKE LOWER(?) OR LOWER(CAST(r.category_key AS TEXT)) LIKE LOWER(?))');
    params.push(`%${q}%`, `%${q}%`, `%${q}%`, `%${q}%`);
  }
  const scopeFilter = applyModerationScopeFilter(scope, params, 'u.mezuniyetyili');
  const whereSql = `WHERE ${where.join(' AND ')}${scopeFilter}`;

  const total = Number(sqlGet(
    `SELECT COUNT(*) AS cnt
     FROM member_requests r
     LEFT JOIN uyeler u ON u.id = r.user_id
     ${whereSql}`,
    params
  )?.cnt || 0);
  const pages = Math.max(Math.ceil(total / limit), 1);
  const safePage = Math.min(page, pages);
  const safeOffset = (safePage - 1) * limit;

  const items = sqlAll(
    `SELECT r.id, r.user_id, r.category_key, r.payload_json, r.status, r.created_at, r.reviewed_at, r.resolution_note,
            c.label AS category_label,
            u.kadi, u.isim, u.soyisim,
            reviewer.kadi AS reviewer_kadi
     FROM member_requests r
     LEFT JOIN request_categories c ON c.category_key = r.category_key
     LEFT JOIN uyeler u ON u.id = r.user_id
     LEFT JOIN uyeler reviewer ON reviewer.id = r.reviewer_id
     ${whereSql}
     ORDER BY r.id DESC
     LIMIT ? OFFSET ?`,
    [...params, limit, safeOffset]
  );
  res.json({
    items,
    meta: {
      page: safePage,
      pages,
      limit,
      total,
      status,
      category: categoryKey || '',
      q
    }
  });
});

app.post('/api/new/admin/requests/:id/review', requireModerationPermission('requests.moderate'), (req, res) => {
  const status = String(req.body?.status || '').trim();
  const resolutionNote = String(req.body?.resolution_note || '').trim();
  const requestId = Number(req.params.id || 0);
  if (!requestId) return res.status(400).send('Geçersiz talep ID.');
  if (!['approved', 'rejected'].includes(status)) return res.status(400).send('Geçersiz durum.');
  const row = sqlGet(
    `SELECT r.*, u.mezuniyetyili
     FROM member_requests r
     LEFT JOIN uyeler u ON u.id = r.user_id
     WHERE r.id = ?`,
    [requestId]
  );
  if (!row) return res.status(404).send('Talep bulunamadı.');
  if (row.status !== 'pending') return res.status(400).send('Talep zaten sonuçlandırılmış.');
  const scope = getModerationScopeContext(req.authUser || getCurrentUser(req));
  if (scope.isScopedModerator) {
    const targetYear = String(row.mezuniyetyili || '').trim();
    if (!targetYear || !scope.years.includes(targetYear)) {
      return res.status(403).send('Bu talep kapsamınız dışında.');
    }
  }

  sqlRun(
    'UPDATE member_requests SET status = ?, reviewed_at = ?, reviewer_id = ?, resolution_note = ? WHERE id = ?',
    [status, new Date().toISOString(), req.session.userId, resolutionNote || null, requestId]
  );
  if (status === 'approved' && row.category_key === 'graduation_year_change') {
    let payload = {};
    try {
      payload = JSON.parse(String(row.payload_json || '{}')) || {};
    } catch {
      payload = {};
    }
    const nextYear = String(payload?.requestedGraduationYear || '').trim();
    if (hasValidGraduationYear(nextYear)) {
      sqlRun('UPDATE uyeler SET mezuniyetyili = ? WHERE id = ?', [nextYear, row.user_id]);
    }
  }
  addNotification({
    userId: row.user_id,
    type: status === 'approved' ? 'member_request_approved' : 'member_request_rejected',
    sourceUserId: req.session.userId,
    entityId: requestId,
    message: status === 'approved'
      ? 'Üye talebin sonuçlandırıldı ve onaylandı.'
      : 'Üye talebin sonuçlandırıldı ve reddedildi.'
  });
  logAdminAction(req, 'member_request_review', {
    targetType: 'member_request',
    targetId: requestId,
    userId: row.user_id,
    status
  });
  res.json({ ok: true });
});

app.get('/api/new/admin/teacher-network/links', requireModerationPermission('requests.view'), (req, res) => {
  ensureTeacherAlumniLinksTable();
  ensureTeacherAlumniLinkModerationEventsTable();
  const actor = req.authUser || getCurrentUser(req);
  const scope = getModerationScopeContext(actor);
  const { page, limit } = parseAdminListPagination(req.query, { defaultLimit: 40, maxLimit: 200 });
  const relationshipType = normalizeTeacherAlumniRelationshipType(req.query.relationship_type);
  const reviewStatus = normalizeTeacherLinkReviewStatus(req.query.review_status);
  const q = String(req.query.q || '').trim();

  const where = [];
  const params = [];
  if (relationshipType) {
    where.push('l.relationship_type = ?');
    params.push(relationshipType);
  }
  if (reviewStatus) {
    where.push('LOWER(COALESCE(l.review_status, ?)) = ?');
    params.push('pending', reviewStatus);
  }
  if (q) {
    where.push('(LOWER(CAST(teacher.kadi AS TEXT)) LIKE LOWER(?) OR LOWER(CAST(teacher.isim AS TEXT)) LIKE LOWER(?) OR LOWER(CAST(teacher.soyisim AS TEXT)) LIKE LOWER(?) OR LOWER(CAST(alumni.kadi AS TEXT)) LIKE LOWER(?) OR LOWER(CAST(alumni.isim AS TEXT)) LIKE LOWER(?) OR LOWER(CAST(alumni.soyisim AS TEXT)) LIKE LOWER(?))');
    params.push(`%${q}%`, `%${q}%`, `%${q}%`, `%${q}%`, `%${q}%`, `%${q}%`);
  }
  const scopeFilter = applyModerationScopeFilter(scope, params, 'alumni.mezuniyetyili');
  const whereSql = where.length ? `WHERE ${where.join(' AND ')}${scopeFilter}` : `WHERE 1=1${scopeFilter}`;

  const total = Number(sqlGet(
    `SELECT COUNT(*) AS cnt
     FROM teacher_alumni_links l
     LEFT JOIN uyeler teacher ON teacher.id = l.teacher_user_id
     LEFT JOIN uyeler alumni ON alumni.id = l.alumni_user_id
     ${whereSql}`,
    params
  )?.cnt || 0);
  const pages = Math.max(Math.ceil(total / limit), 1);
  const safePage = Math.min(page, pages);
  const offset = (safePage - 1) * limit;

  const items = sqlAll(
    `SELECT l.id, l.relationship_type, l.class_year, l.notes, l.created_at, l.confidence_score,
            COALESCE(l.created_via, 'manual_alumni_link') AS created_via,
            COALESCE(l.source_surface, 'teachers_network_page') AS source_surface,
            COALESCE(l.review_status, 'pending') AS review_status,
            l.last_reviewed_by, l.review_note, l.reviewed_at, l.merged_into_link_id,
            teacher.id AS teacher_user_id, teacher.kadi AS teacher_kadi, teacher.isim AS teacher_isim, teacher.soyisim AS teacher_soyisim, teacher.verified AS teacher_verified, teacher.role AS teacher_role, teacher.mezuniyetyili AS teacher_cohort,
            alumni.id AS alumni_user_id, alumni.kadi AS alumni_kadi, alumni.isim AS alumni_isim, alumni.soyisim AS alumni_soyisim, alumni.mezuniyetyili AS alumni_mezuniyetyili, alumni.verified AS alumni_verified,
            reviewer.kadi AS reviewer_kadi, reviewer.isim AS reviewer_isim, reviewer.soyisim AS reviewer_soyisim,
            (SELECT COUNT(*) FROM teacher_alumni_links pair_link WHERE pair_link.teacher_user_id = l.teacher_user_id AND pair_link.alumni_user_id = l.alumni_user_id AND COALESCE(pair_link.review_status, 'pending') NOT IN ('rejected', 'merged')) AS active_pair_link_count,
            (SELECT COUNT(*) FROM teacher_alumni_links teacher_link WHERE teacher_link.teacher_user_id = l.teacher_user_id AND COALESCE(teacher_link.review_status, 'pending') NOT IN ('rejected', 'merged')) AS teacher_active_link_count,
            (SELECT COUNT(*) FROM teacher_alumni_link_moderation_events e WHERE e.link_id = l.id) AS moderation_event_count,
            (SELECT e.event_type FROM teacher_alumni_link_moderation_events e WHERE e.link_id = l.id ORDER BY e.created_at DESC, e.id DESC LIMIT 1) AS last_event_type,
            (SELECT e.created_at FROM teacher_alumni_link_moderation_events e WHERE e.link_id = l.id ORDER BY e.created_at DESC, e.id DESC LIMIT 1) AS last_event_at
     FROM teacher_alumni_links l
     LEFT JOIN uyeler teacher ON teacher.id = l.teacher_user_id
     LEFT JOIN uyeler alumni ON alumni.id = l.alumni_user_id
     LEFT JOIN uyeler reviewer ON reviewer.id = l.last_reviewed_by
     ${whereSql}
     ORDER BY l.id DESC
     LIMIT ? OFFSET ?`,
    [...params, limit, offset]
  );

  const decoratedItems = items.map((item) => ({
    ...item,
    moderation_assessment: buildTeacherLinkModerationAssessment(item)
  }));

  res.json({ items: decoratedItems, meta: { page: safePage, pages, total, limit, q, relationship_type: relationshipType || '', review_status: reviewStatus || '' } });
});

app.post('/api/new/admin/teacher-network/links/:id/review', requireModerationPermission('requests.moderate'), (req, res) => {
  ensureTeacherAlumniLinksTable();
  ensureTeacherAlumniLinkModerationEventsTable();
  const linkId = Number(req.params.id || 0);
  const reviewStatus = normalizeTeacherLinkReviewStatus(req.body?.status);
  const reviewNote = normalizeTeacherLinkReviewNote(req.body?.note);
  const requestedMergeTargetId = Number(req.body?.merge_into_link_id || 0);
  const actor = req.authUser || getCurrentUser(req);
  if (!linkId) return res.status(400).send('Geçersiz teacher network link ID.');
  if (!reviewStatus) return res.status(400).send('Geçersiz review status.');

  const row = sqlGet(
    `SELECT l.id, l.teacher_user_id, l.alumni_user_id, COALESCE(l.review_status, 'pending') AS review_status, alumni.mezuniyetyili
     FROM teacher_alumni_links l
     LEFT JOIN uyeler alumni ON alumni.id = l.alumni_user_id
     WHERE l.id = ?`,
    [linkId]
  );
  if (!row) return res.status(404).send('Teacher network link bulunamadı.');
  if (!canTransitionTeacherLinkReviewStatus(row.review_status, reviewStatus) && row.review_status !== reviewStatus) {
    return res.status(409).send('Bu teacher network kaydı seçilen review durumuna geçirilemez.');
  }

  const scope = getModerationScopeContext(actor);
  if (scope.isScopedModerator) {
    const targetYear = String(row.mezuniyetyili || '').trim();
    if (!targetYear || !scope.years.includes(targetYear)) {
      return res.status(403).send('Bu kayıt kapsamınız dışında.');
    }
  }

  let mergeTargetId = null;
  if (reviewStatus === 'merged') {
    const mergeTarget = selectTeacherLinkMergeTarget(linkId, row.teacher_user_id, row.alumni_user_id, requestedMergeTargetId);
    if (!mergeTarget) {
      return res.status(409).send('Bu kaydı birleştirmek için aynı öğretmen-mezun eşleşmesinde aktif bir hedef kayıt bulunamadı.');
    }
    mergeTargetId = Number(mergeTarget.id || 0);
  }
  const reviewedAt = new Date().toISOString();
  sqlRun(
    `UPDATE teacher_alumni_links
     SET review_status = ?,
         last_reviewed_by = ?,
         review_note = ?,
         reviewed_at = ?,
         merged_into_link_id = ?
     WHERE id = ?`,
    [reviewStatus, actor?.id || null, reviewNote || null, reviewedAt, mergeTargetId, linkId]
  );
  const confidenceScore = refreshTeacherLinkConfidenceScore(linkId);
  const affectedSiblingIds = sqlAll(
    `SELECT id
     FROM teacher_alumni_links
     WHERE teacher_user_id = ?
       AND alumni_user_id = ?
       AND id <> ?
       AND COALESCE(review_status, 'pending') NOT IN ('rejected', 'merged')`,
    [row.teacher_user_id, row.alumni_user_id, linkId]
  ) || [];
  for (const sibling of affectedSiblingIds) {
    refreshTeacherLinkConfidenceScore(sibling?.id);
  }
  logTeacherLinkModerationEvent({
    linkId,
    actorUserId: actor?.id || null,
    eventType: reviewStatus === 'merged' ? 'teacher_link_merged' : 'teacher_link_reviewed',
    fromStatus: row.review_status,
    toStatus: reviewStatus,
    note: reviewNote,
    mergeTargetId
  });

  logAdminAction(req, 'teacher_network_link_review', {
    targetType: 'teacher_network_link',
    targetId: linkId,
    reviewStatus,
    alumniUserId: Number(row.alumni_user_id || 0),
    mergeTargetId,
    reviewedAt
  });

  const reviewNotificationType = reviewStatus === 'confirmed'
    ? 'teacher_link_review_confirmed'
    : reviewStatus === 'flagged'
      ? 'teacher_link_review_flagged'
      : reviewStatus === 'rejected'
        ? 'teacher_link_review_rejected'
        : reviewStatus === 'merged'
          ? 'teacher_link_review_merged'
          : '';
  if (reviewNotificationType && Number(row.alumni_user_id || 0) > 0) {
    addNotification({
      userId: Number(row.alumni_user_id),
      type: reviewNotificationType,
      sourceUserId: Number(actor?.id || 0) || null,
      entityId: linkId,
      message: reviewStatus === 'confirmed'
        ? 'Eklediğin öğretmen bağlantısı moderasyon tarafından onaylandı.'
        : reviewStatus === 'flagged'
          ? 'Eklediğin öğretmen bağlantısı ek inceleme için işaretlendi.'
          : reviewStatus === 'rejected'
            ? 'Eklediğin öğretmen bağlantısı reddedildi.'
            : 'Eklediğin öğretmen bağlantısı benzer bir kayıt ile birleştirildi.'
    });
  }

  res.json({
    ok: true,
    status: reviewStatus,
    id: linkId,
    confidence_score: confidenceScore,
    review_note: reviewNote,
    reviewed_at: reviewedAt,
    merged_into_link_id: mergeTargetId
  });
});

app.post('/api/new/admin/verify', requireAdmin, (req, res) => {
  const userId = Number(req.body?.userId || 0);
  const value = String(req.body?.verified || '0') === '1' ? 1 : 0;
  if (!userId) return res.status(400).send('User ID gerekli.');
  const target = ensureCanModerateTargetUser(req, res, userId);
  if (!target) return;
  sqlRun('UPDATE uyeler SET verified = ?, verification_status = ? WHERE id = ?', [value, value === 1 ? 'verified' : 'pending', userId]);
  
  if (value === 1) {
    assignUserToCohort(userId);
  }

  logAdminAction(req, 'user_verify_toggle', {
    targetType: 'user',
    targetId: userId,
    verified: value === 1
  });
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
  const enabledDbValue = toDbBooleanParam(enabled);
  const name = String(payload.name || '').trim() || (engagementDefaultVariants[variant]?.name || variant);
  const description = String(payload.description || '').trim() || (engagementDefaultVariants[variant]?.description || '');
  sqlRun(
    `UPDATE engagement_ab_config
     SET name = ?, description = ?, traffic_pct = ?, enabled = ?, params_json = ?, updated_at = ?
     WHERE variant = ?`,
    [name, description, trafficPct, enabledDbValue, JSON.stringify(mergedParams), new Date().toISOString(), variant]
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

app.get('/api/new/admin/network-suggestion-ab', requireAdmin, async (_req, res) => {
  try {
    const windowDays = parseNetworkWindowDays(_req.query.window);
    const sinceIso = toIsoThreshold(windowDays);
    const cohort = normalizeCohortValue(_req.query.cohort);
    const dataset = await getNetworkSuggestionExperimentDataset({ sinceIso, cohort });
    const configs = getNetworkSuggestionAbConfigs().map((cfg) => ({
      variant: cfg.variant,
      name: cfg.name,
      description: cfg.description,
      trafficPct: cfg.trafficPct,
      enabled: cfg.enabled,
      params: cfg.params,
      updatedAt: cfg.updatedAt
    }));
    const performanceBundle = buildNetworkSuggestionExperimentAnalytics({
      exposureRows: dataset.exposureRows,
      actionRows: dataset.actionRows,
      configs,
      assignmentCounts: dataset.assignmentCounts
    });
    const recentSuggestionChanges = await listNetworkSuggestionAbRecentChangesWithEvaluation(10);
    const recommendations = buildNetworkSuggestionAbRecommendations(configs, performanceBundle.variants, recentSuggestionChanges);
    const lastObservedAt = [...dataset.exposureRows, ...dataset.actionRows]
      .map((row) => row?.created_at)
      .filter(Boolean)
      .sort((a, b) => String(b).localeCompare(String(a)))[0] || null;

    res.json({
      window: `${windowDays}d`,
      since: sinceIso,
      cohort: String(cohort || 'all'),
      configs,
      performance: performanceBundle.variants,
      assignmentCounts: performanceBundle.assignment_counts,
      recommendations,
      leadingVariant: performanceBundle.leading_variant,
      recentChanges: recentSuggestionChanges,
      totals: {
        exposure_users: performanceBundle.total_exposure_users,
        exposure_events: performanceBundle.total_exposure_events
      },
      lastObservedAt
    });
  } catch (err) {
    console.error('admin.network-suggestion-ab failed:', err);
    res.status(500).send('Beklenmeyen bir hata oluştu.');
  }
});

app.post('/api/new/admin/network-suggestion-ab/apply', requireAdmin, async (req, res) => {
  try {
    const windowDays = parseNetworkWindowDays(req.body?.window || req.query?.window);
    const sinceIso = toIsoThreshold(windowDays);
    const cohort = normalizeCohortValue(req.body?.cohort || req.query?.cohort);
    const recommendationIndex = Math.max(0, parseInt(req.body?.index ?? req.body?.recommendationIndex ?? '0', 10) || 0);
    const dataset = await getNetworkSuggestionExperimentDataset({ sinceIso, cohort });
    const configs = getNetworkSuggestionAbConfigs();
    const performanceBundle = buildNetworkSuggestionExperimentAnalytics({
      exposureRows: dataset.exposureRows,
      actionRows: dataset.actionRows,
      configs,
      assignmentCounts: dataset.assignmentCounts
    });
    const recommendations = buildNetworkSuggestionAbRecommendations(configs, performanceBundle.variants, listNetworkSuggestionAbRecentChanges(10));
    const recommendation = recommendations[recommendationIndex];
    if (!recommendation) {
      return res.status(404).json({
        ok: false,
        code: 'NETWORK_SUGGESTION_RECOMMENDATION_NOT_FOUND',
        message: 'Uygulanabilir recommendation bulunamadı.',
        data: null
      });
    }
    if (!recommendation.guardrails?.can_apply) {
      return res.status(409).json({
        ok: false,
        code: 'NETWORK_SUGGESTION_RECOMMENDATION_GUARDRAIL_BLOCKED',
        message: 'Recommendation guardrail nedeniyle uygulanamıyor.',
        data: {
          recommendation_index: recommendationIndex,
          recommendation,
          guardrails: recommendation.guardrails
        }
      });
    }
    if (String(req.body?.confirmation || '').trim().toLowerCase() !== NETWORK_SUGGESTION_APPLY_CONFIRMATION_TOKEN) {
      return res.status(409).json({
        ok: false,
        code: 'NETWORK_SUGGESTION_RECOMMENDATION_CONFIRM_REQUIRED',
        message: 'Recommendation uygulamak için ikinci onay gerekli.',
        data: {
          recommendation_index: recommendationIndex,
          confirmation_token: NETWORK_SUGGESTION_APPLY_CONFIRMATION_TOKEN,
          recommendation
        }
      });
    }

    const now = new Date().toISOString();
    const touchedVariants = new Set();
    const beforeSnapshot = [];
    if (recommendation.patch && typeof recommendation.patch === 'object') {
      const variant = resolveNetworkSuggestionVariant(recommendation.variant);
      const existing = sqlGet('SELECT variant, params_json FROM network_suggestion_ab_config WHERE variant = ?', [variant]);
      if (!existing) {
        return res.status(404).json({
          ok: false,
          code: 'NETWORK_SUGGESTION_VARIANT_NOT_FOUND',
          message: 'Recommendation varyantı bulunamadı.',
          data: null
        });
      }
      beforeSnapshot.push(...snapshotNetworkSuggestionConfigs(configs, [variant]));
      let currentParams = networkSuggestionDefaultVariants[variant]?.params || networkSuggestionDefaultParams;
      try {
        currentParams = existing.params_json ? JSON.parse(existing.params_json) : currentParams;
      } catch {
        // keep defaults
      }
      const mergedParams = normalizeNetworkSuggestionParams(
        { ...currentParams, ...recommendation.patch },
        networkSuggestionDefaultVariants[variant]?.params || networkSuggestionDefaultParams
      );
      sqlRun(
        `UPDATE network_suggestion_ab_config
         SET params_json = ?, updated_at = ?
         WHERE variant = ?`,
        [JSON.stringify(mergedParams), now, variant]
      );
      touchedVariants.add(variant);
    }

    if (recommendation.trafficPatch && typeof recommendation.trafficPatch === 'object') {
      const trafficVariants = Object.keys(recommendation.trafficPatch || {}).map((variantKey) => resolveNetworkSuggestionVariant(variantKey));
      const trafficSnapshot = snapshotNetworkSuggestionConfigs(configs, trafficVariants);
      for (const row of trafficSnapshot) {
        if (!beforeSnapshot.some((item) => item.variant === row.variant)) beforeSnapshot.push(row);
      }
      for (const [variantKey, nextTraffic] of Object.entries(recommendation.trafficPatch)) {
        const variant = resolveNetworkSuggestionVariant(variantKey);
        sqlRun(
          `UPDATE network_suggestion_ab_config
           SET traffic_pct = ?, updated_at = ?
           WHERE variant = ?`,
          [clamp(Math.round(Number(nextTraffic || 0)), 0, 100), now, variant]
        );
        touchedVariants.add(variant);
      }
    }

    const afterSnapshot = snapshotNetworkSuggestionConfigs(getNetworkSuggestionAbConfigs(), Array.from(touchedVariants));
    const historyResult = sqlRun(
      `INSERT INTO network_suggestion_ab_change_log
       (action_type, related_change_id, actor_user_id, recommendation_index, cohort, window_days, payload_json,
        before_snapshot_json, after_snapshot_json, created_at, rolled_back_at, rollback_change_id)
       VALUES (?, NULL, ?, ?, ?, ?, ?, ?, ?, ?, NULL, NULL)`,
      [
        'apply',
        Number(req.session?.userId || 0) || null,
        recommendationIndex,
        String(cohort || 'all'),
        windowDays,
        JSON.stringify(recommendation),
        JSON.stringify(beforeSnapshot),
        JSON.stringify(afterSnapshot),
        now
      ]
    );
    const historyId = Number(historyResult?.lastInsertRowid || 0) || null;

    logAdminAction(req, 'network_suggestion_ab_recommendation_apply', {
      historyId,
      recommendationIndex,
      variant: recommendation.variant,
      touchedVariants: Array.from(touchedVariants),
      hasPatch: Boolean(recommendation.patch && typeof recommendation.patch === 'object'),
      hasTrafficPatch: Boolean(recommendation.trafficPatch && typeof recommendation.trafficPatch === 'object')
    });

    return res.json({
      ok: true,
      code: 'NETWORK_SUGGESTION_RECOMMENDATION_APPLIED',
      message: 'Recommendation konfigürasyona uygulandı.',
      data: {
        history_id: historyId,
        recommendation_index: recommendationIndex,
        applied: recommendation,
        touched_variants: Array.from(touchedVariants),
        before_snapshot: beforeSnapshot,
        after_snapshot: afterSnapshot
      }
    });
  } catch (err) {
    console.error('admin.network-suggestion-ab.apply failed:', err);
    return res.status(500).json({
      ok: false,
      code: 'NETWORK_SUGGESTION_RECOMMENDATION_APPLY_FAILED',
      message: 'Recommendation uygulanamadı.',
      data: null
    });
  }
});

app.post('/api/new/admin/network-suggestion-ab/rollback/:id', requireAdmin, async (req, res) => {
  try {
    ensureNetworkSuggestionAbTables();
    const changeId = Number(req.params.id || 0);
    if (!changeId) {
      return res.status(400).json({
        ok: false,
        code: 'NETWORK_SUGGESTION_ROLLBACK_ID_REQUIRED',
        message: 'Rollback için geçerli kayıt ID gerekli.',
        data: null
      });
    }
    const row = sqlGet(
      `SELECT id, action_type, payload_json, before_snapshot_json, after_snapshot_json, rolled_back_at, rollback_change_id
       FROM network_suggestion_ab_change_log
       WHERE id = ?`,
      [changeId]
    );
    if (!row) {
      return res.status(404).json({
        ok: false,
        code: 'NETWORK_SUGGESTION_CHANGE_NOT_FOUND',
        message: 'Rollback kaydı bulunamadı.',
        data: null
      });
    }
    if (String(row.action_type || '') !== 'apply') {
      return res.status(409).json({
        ok: false,
        code: 'NETWORK_SUGGESTION_ROLLBACK_ONLY_APPLY',
        message: 'Sadece apply kayıtları rollback edilebilir.',
        data: null
      });
    }
    if (row.rolled_back_at || Number(row.rollback_change_id || 0) > 0) {
      return res.status(409).json({
        ok: false,
        code: 'NETWORK_SUGGESTION_ALREADY_ROLLED_BACK',
        message: 'Bu recommendation zaten rollback edilmiş.',
        data: null
      });
    }

    const beforeSnapshot = parseJsonValue(row.before_snapshot_json, []) || [];
    const afterSnapshot = parseJsonValue(row.after_snapshot_json, []) || [];
    if (!Array.isArray(beforeSnapshot) || !beforeSnapshot.length) {
      return res.status(409).json({
        ok: false,
        code: 'NETWORK_SUGGESTION_ROLLBACK_SNAPSHOT_MISSING',
        message: 'Rollback için gerekli snapshot bulunamadı.',
        data: null
      });
    }

    const now = new Date().toISOString();
    for (const snapshot of beforeSnapshot) {
      const variant = resolveNetworkSuggestionVariant(snapshot?.variant);
      const params = normalizeNetworkSuggestionParams(
        snapshot?.params && typeof snapshot.params === 'object' ? snapshot.params : {},
        networkSuggestionDefaultVariants[variant]?.params || networkSuggestionDefaultParams
      );
      sqlRun(
        `UPDATE network_suggestion_ab_config
         SET name = ?, description = ?, traffic_pct = ?, enabled = ?, params_json = ?, updated_at = ?
         WHERE variant = ?`,
        [
          String(snapshot?.name || networkSuggestionDefaultVariants[variant]?.name || variant),
          String(snapshot?.description || networkSuggestionDefaultVariants[variant]?.description || ''),
          clamp(Math.round(Number(snapshot?.trafficPct || 0)), 0, 100),
          toDbBooleanParam(Number(snapshot?.enabled || 0) === 1),
          JSON.stringify(params),
          now,
          variant
        ]
      );
    }

    const restoredSnapshot = snapshotNetworkSuggestionConfigs(getNetworkSuggestionAbConfigs(), beforeSnapshot.map((item) => item.variant));
    const rollbackResult = sqlRun(
      `INSERT INTO network_suggestion_ab_change_log
       (action_type, related_change_id, actor_user_id, recommendation_index, cohort, window_days, payload_json,
        before_snapshot_json, after_snapshot_json, created_at, rolled_back_at, rollback_change_id)
       VALUES (?, ?, ?, NULL, ?, NULL, ?, ?, ?, ?, NULL, NULL)`,
      [
        'rollback',
        changeId,
        Number(req.session?.userId || 0) || null,
        'all',
        JSON.stringify({ source_change_id: changeId }),
        JSON.stringify(afterSnapshot),
        JSON.stringify(restoredSnapshot),
        now
      ]
    );
    const rollbackHistoryId = Number(rollbackResult?.lastInsertRowid || 0) || null;
    sqlRun(
      `UPDATE network_suggestion_ab_change_log
       SET rolled_back_at = ?, rollback_change_id = ?
       WHERE id = ?`,
      [now, rollbackHistoryId, changeId]
    );

    logAdminAction(req, 'network_suggestion_ab_recommendation_rollback', {
      changeId,
      rollbackHistoryId,
      restoredVariants: beforeSnapshot.map((item) => resolveNetworkSuggestionVariant(item.variant))
    });

    return res.json({
      ok: true,
      code: 'NETWORK_SUGGESTION_RECOMMENDATION_ROLLED_BACK',
      message: 'Recommendation değişikliği geri alındı.',
      data: {
        change_id: changeId,
        rollback_history_id: rollbackHistoryId,
        restored_snapshot: restoredSnapshot
      }
    });
  } catch (err) {
    console.error('admin.network-suggestion-ab.rollback failed:', err);
    return res.status(500).json({
      ok: false,
      code: 'NETWORK_SUGGESTION_ROLLBACK_FAILED',
      message: 'Recommendation rollback edilemedi.',
      data: null
    });
  }
});

app.put('/api/new/admin/network-suggestion-ab/:variant', requireAdmin, (req, res) => {
  const variant = String(req.params.variant || '').trim().toUpperCase();
  if (!variant) return res.status(400).send('Variant gerekli.');
  const existing = sqlGet('SELECT variant, params_json FROM network_suggestion_ab_config WHERE variant = ?', [variant]);
  if (!existing) return res.status(404).send('Variant bulunamadı.');
  let currentParams = networkSuggestionDefaultVariants[variant]?.params || networkSuggestionDefaultParams;
  try {
    currentParams = existing.params_json ? JSON.parse(existing.params_json) : currentParams;
  } catch {
    // ignore parse error and keep fallback
  }
  const payload = req.body || {};
  const mergedParams = normalizeNetworkSuggestionParams(
    payload.params && typeof payload.params === 'object'
      ? { ...currentParams, ...payload.params }
      : currentParams,
    networkSuggestionDefaultVariants[variant]?.params || networkSuggestionDefaultParams
  );
  const trafficPct = clamp(Math.round(Number(payload.trafficPct ?? payload.traffic_pct ?? 50) || 0), 0, 100);
  const enabled = String(payload.enabled ?? '1') === '1' ? 1 : 0;
  const enabledDbValue = toDbBooleanParam(enabled);
  const name = String(payload.name || '').trim() || (networkSuggestionDefaultVariants[variant]?.name || variant);
  const description = String(payload.description || '').trim() || (networkSuggestionDefaultVariants[variant]?.description || '');
  sqlRun(
    `UPDATE network_suggestion_ab_config
     SET name = ?, description = ?, traffic_pct = ?, enabled = ?, params_json = ?, updated_at = ?
     WHERE variant = ?`,
    [name, description, trafficPct, enabledDbValue, JSON.stringify(mergedParams), new Date().toISOString(), variant]
  );
  logAdminAction(req, 'network_suggestion_ab_config_update', { variant, trafficPct, enabled });
  res.json({ ok: true });
});

app.post('/api/new/admin/network-suggestion-ab/rebalance', requireAdmin, (req, res) => {
  const keepAssignments = String(req.body?.keepAssignments || '0') === '1';
  if (!keepAssignments) {
    sqlRun('DELETE FROM network_suggestion_ab_assignments');
  }
  logAdminAction(req, 'network_suggestion_ab_rebalance', { keepAssignments });
  res.json({ ok: true, keepAssignments });
});

const handleAdminDashboardSummary = async (req, res) => {
  try {
    const recentLimit = Math.min(Math.max(parseInt(req.query.recentLimit || '12', 10), 1), 80);
    const cacheKey = `recentLimit:${recentLimit}`;
    const now = Date.now();
    if (
      adminStatsResponseCache.value
      && adminStatsResponseCache.key === cacheKey
      && adminStatsResponseCache.expiresAt > now
    ) {
      return res.json(adminStatsResponseCache.value);
    }

    cleanupStaleOnlineUsersAsync().catch(() => {});

    const countBy = async (tableName, whereClause = '', params = []) => {
      if (!hasTable(tableName)) return 0;
      const row = await sqlGetAsync(
        `SELECT CAST(COUNT(*) AS INTEGER) AS cnt FROM ${tableName}${whereClause ? ` WHERE ${whereClause}` : ''}`,
        params
      );
      return Number(row?.cnt || 0);
    };

    const [
      countsRow,
      recentUsers,
      recentPosts,
      recentPhotos,
      networkFunnelRows,
      mentorshipRows,
      teacherLinkRows
    ] = await Promise.all([
      Promise.all([
        countBy('uyeler'),
        countBy('uyeler', 'aktiv = 1 AND yasak = 0'),
        countBy('uyeler', 'aktiv = 0 AND yasak = 0'),
        countBy('uyeler', 'yasak = 1'),
        countBy('posts'),
        countBy('album_foto'),
        countBy('stories'),
        countBy('groups'),
        countBy('gelenkutusu'),
        countBy('events'),
        countBy('announcements'),
        countBy('chat_messages')
      ]).then(([users, active_users, pending_users, banned_users, posts, photos, stories, groups, messages, events, announcements, chat]) => ({
        users,
        active_users,
        pending_users,
        banned_users,
        posts,
        photos,
        stories,
        groups,
        messages,
        events,
        announcements,
        chat
      })),
      hasTable('uyeler')
        ? sqlAllAsync(
          `SELECT id, kadi, isim, soyisim, resim, ilktarih
           FROM uyeler
           ORDER BY id DESC
           LIMIT ?`,
          [recentLimit]
        )
        : Promise.resolve([]),
      hasTable('posts')
        ? sqlAllAsync(
          `SELECT p.id, p.content, p.image, p.created_at, u.kadi
           FROM posts p
           LEFT JOIN uyeler u ON u.id = p.user_id
           ORDER BY p.id DESC
           LIMIT ?`,
          [recentLimit]
        )
        : Promise.resolve([]),
      hasTable('album_foto')
        ? sqlAllAsync(
          `SELECT f.id, f.dosyaadi, f.baslik, f.tarih, u.kadi
           FROM album_foto f
           LEFT JOIN uyeler u ON ${joinUserOnPhotoOwnerExpr}
           ORDER BY f.id DESC
           LIMIT ?`,
          [recentLimit]
        )
        : Promise.resolve([]),
      hasTable('connection_requests')
        ? sqlAllAsync(
          `SELECT status, CAST(COUNT(*) AS INTEGER) AS count
           FROM connection_requests
           GROUP BY status`
        )
        : Promise.resolve([]),
      hasTable('mentorship_requests')
        ? sqlAllAsync(
          `SELECT status, CAST(COUNT(*) AS INTEGER) AS count
           FROM mentorship_requests
           GROUP BY status`
        )
        : Promise.resolve([]),
      hasTable('teacher_alumni_links')
        ? sqlAllAsync(
          `SELECT relationship_type, CAST(COUNT(*) AS INTEGER) AS count
           FROM teacher_alumni_links
           GROUP BY relationship_type`
        )
        : Promise.resolve([])
    ]);

    const connectionStats = networkFunnelRows.reduce((acc, row) => {
      const key = String(row?.status || '').toLowerCase();
      if (!key) return acc;
      acc[key] = Number(row?.count || 0);
      return acc;
    }, {});
    const mentorshipStats = mentorshipRows.reduce((acc, row) => {
      const key = String(row?.status || '').toLowerCase();
      if (!key) return acc;
      acc[key] = Number(row?.count || 0);
      return acc;
    }, {});
    const teacherLinkByType = teacherLinkRows.reduce((acc, row) => {
      const key = String(row?.relationship_type || '').toLowerCase();
      if (!key) return acc;
      acc[key] = Number(row?.count || 0);
      return acc;
    }, {});

    const counts = {
      users: Number(countsRow?.users || 0),
      activeUsers: Number(countsRow?.active_users || 0),
      pendingUsers: Number(countsRow?.pending_users || 0),
      bannedUsers: Number(countsRow?.banned_users || 0),
      posts: Number(countsRow?.posts || 0),
      photos: Number(countsRow?.photos || 0),
      stories: Number(countsRow?.stories || 0),
      groups: Number(countsRow?.groups || 0),
      messages: Number(countsRow?.messages || 0),
      events: Number(countsRow?.events || 0),
      announcements: Number(countsRow?.announcements || 0),
      chat: Number(countsRow?.chat || 0)
    };
    const payload = {
      counts,
      networking: {
        connections: {
          requested: connectionStats.pending || 0,
          accepted: connectionStats.accepted || 0,
          ignored: connectionStats.ignored || 0,
          declined: connectionStats.declined || 0
        },
        mentorship: {
          requested: mentorshipStats.requested || 0,
          accepted: mentorshipStats.accepted || 0,
          declined: mentorshipStats.declined || 0
        },
        teacherLinks: {
          total: teacherLinkRows.reduce((sum, row) => sum + Number(row?.count || 0), 0),
          byRelationshipType: teacherLinkByType
        }
      },
      storage: readAdminStorageSnapshot(),
      recentUsers,
      recentPosts,
      recentPhotos
    };
    adminStatsResponseCache = {
      key: cacheKey,
      value: payload,
      expiresAt: now + ADMIN_STATS_CACHE_TTL_MS
    };
    return res.json(payload);
  } catch (err) {
    console.error('admin.stats failed:', err);
    return res.status(500).send('Beklenmeyen bir hata oluştu.');
  }
};

app.get('/api/new/admin/stats', requireAdmin, handleAdminDashboardSummary);
app.get('/api/admin/dashboard/summary', requireAdmin, handleAdminDashboardSummary);

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

const handleAdminDashboardActivity = async (req, res) => {
  try {
    const chatLimit = Math.min(Math.max(parseInt(req.query.chatLimit || '8', 10), 1), 50);
    const postLimit = Math.min(Math.max(parseInt(req.query.postLimit || '8', 10), 1), 50);
    const userLimit = Math.min(Math.max(parseInt(req.query.userLimit || '8', 10), 1), 50);
    const activityLimit = Math.min(Math.max(parseInt(req.query.activityLimit || '20', 10), 1), 120);
    const cacheKey = `chat:${chatLimit}:post:${postLimit}:user:${userLimit}:activity:${activityLimit}`;
    const now = Date.now();
    if (
      adminLiveResponseCache.value
      && adminLiveResponseCache.key === cacheKey
      && adminLiveResponseCache.expiresAt > now
    ) {
      return res.json(adminLiveResponseCache.value);
    }

    const safeRead = async (label, load, fallback) => {
      try {
        return await load();
      } catch (err) {
        console.error(`admin.live ${label} failed:`, err);
        return fallback;
      }
    };

    await safeRead('cleanup_stale_online', () => cleanupStaleOnlineUsersAsync(), null);
    const [
      onlineMembers,
      countsRow,
      chat,
      posts,
      newestUsers,
      newestPhotos
    ] = await Promise.all([
      safeRead('online_members', () => listOnlineMembersAsync({ limit: 20, excludeUserId: null }), []),
      safeRead(
        'counts',
        async () => {
          const countBy = async (tableName, whereClause = '', params = []) => {
            if (!hasTable(tableName)) return 0;
            const row = await sqlGetAsync(
              `SELECT CAST(COUNT(*) AS INTEGER) AS cnt FROM ${tableName}${whereClause ? ` WHERE ${whereClause}` : ''}`,
              params
            );
            return Number(row?.cnt || 0);
          };
          return {
            pending_verifications: await countBy('verification_requests', 'status = ?', ['pending']),
            pending_events: await countBy(
              'events',
              hasColumn('events', 'approved')
                ? "LOWER(COALESCE(NULLIF(TRIM(CAST(approved AS TEXT)), ''), '1')) IN ('0','false','hayir','no')"
                : ''
            ),
            pending_announcements: await countBy(
              'announcements',
              hasColumn('announcements', 'approved')
                ? "LOWER(COALESCE(NULLIF(TRIM(CAST(approved AS TEXT)), ''), '1')) IN ('0','false','hayir','no')"
                : ''
            ),
            pending_photos: await countBy(
              'album_foto',
              hasColumn('album_foto', 'aktif')
                ? 'aktif = 0'
                : ''
            )
          };
        },
        { pending_verifications: 0, pending_events: 0, pending_announcements: 0, pending_photos: 0 }
      ),
      safeRead(
        'chat_rows',
        () => sqlAllAsync(
          `SELECT c.id, c.created_at AS ts, u.kadi
           FROM chat_messages c
           LEFT JOIN uyeler u ON u.id = c.user_id
           ORDER BY c.id DESC
           LIMIT ?`,
          [chatLimit]
        ),
        []
      ),
      safeRead(
        'post_rows',
        () => sqlAllAsync(
          `SELECT p.id, p.content, p.image, p.created_at AS ts, u.kadi
           FROM posts p
           LEFT JOIN uyeler u ON u.id = p.user_id
           ORDER BY p.id DESC
           LIMIT ?`,
          [postLimit]
        ),
        []
      ),
      safeRead(
        'newest_users',
        () => sqlAllAsync('SELECT id, kadi, isim, soyisim, resim, ilktarih AS ts FROM uyeler ORDER BY id DESC LIMIT ?', [userLimit]),
        []
      ),
      safeRead(
        'newest_photos',
        () => sqlAllAsync(
          `SELECT f.id, f.dosyaadi, f.baslik, f.tarih, u.kadi
           FROM album_foto f
           LEFT JOIN uyeler u ON ${joinUserOnPhotoOwnerExpr}
           ORDER BY f.id DESC
           LIMIT ?`,
          [userLimit]
        ),
        []
      )
    ]);

    const counts = {
      onlineUsers: onlineMembers.length,
      pendingVerifications: Number(countsRow?.pending_verifications || 0),
      pendingEvents: Number(countsRow?.pending_events || 0),
      pendingAnnouncements: Number(countsRow?.pending_announcements || 0),
      pendingPhotos: Number(countsRow?.pending_photos || 0)
    };

    const rows = [];
    for (const item of chat) {
      rows.push({
        id: `chat-${item.id}`,
        type: 'chat',
        message: `@${item.kadi || 'üye'} canlı sohbete mesaj gönderdi.`,
        at: item.ts || null
      });
    }
    for (const item of posts) {
      rows.push({
        id: `post-${item.id}`,
        type: 'post',
        message: `@${item.kadi || 'üye'} yeni gönderi paylaştı.`,
        at: item.ts || null
      });
    }
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

    rows.sort((a, b) => new Date(b.at || 0).getTime() - new Date(a.at || 0).getTime());
    const payload = {
      counts,
      activity: rows.slice(0, activityLimit),
      onlineMembers,
      newestUsers,
      newestPosts,
      newestPhotos,
      now: new Date().toISOString()
    };
    adminLiveResponseCache = {
      key: cacheKey,
      value: payload,
      expiresAt: now + ADMIN_LIVE_CACHE_TTL_MS
    };
    return res.json(payload);
  } catch (err) {
    console.error('admin.live failed:', err);
    return res.status(500).send('Beklenmeyen bir hata oluştu.');
  }
};

app.get('/api/new/admin/live', requireAdmin, handleAdminDashboardActivity);
app.get('/api/admin/dashboard/activity', requireAdmin, handleAdminDashboardActivity);

app.get('/api/new/admin/groups', requireModerationPermission('groups.view'), (req, res) => {
  const actor = req.authUser || getCurrentUser(req);
  const scope = getModerationScopeContext(actor);
  const { page, limit } = parseAdminListPagination(req.query, { defaultLimit: 50, maxLimit: 250 });
  const q = String(req.query.q || '').trim();
  const params = [];
  const whereParts = ["(owner.role IS NULL OR LOWER(COALESCE(owner.role, 'user')) != 'root')"];
  if (q) {
    whereParts.push('(LOWER(CAST(g.name AS TEXT)) LIKE LOWER(?) OR LOWER(CAST(g.description AS TEXT)) LIKE LOWER(?) OR LOWER(CAST(owner.kadi AS TEXT)) LIKE LOWER(?))');
    params.push(`%${q}%`, `%${q}%`, `%${q}%`);
  }
  const scopeFilter = applyModerationScopeFilter(scope, params, 'owner.mezuniyetyili');
  const whereSql = `WHERE ${whereParts.join(' AND ')}${scopeFilter}`;

  const total = Number(sqlGet(
    `SELECT COUNT(*) AS cnt
     FROM groups g
     LEFT JOIN uyeler owner ON owner.id = g.owner_id
     ${whereSql}`,
    params
  )?.cnt || 0);
  const pages = Math.max(Math.ceil(total / limit), 1);
  const safePage = Math.min(page, pages);
  const safeOffset = (safePage - 1) * limit;

  const items = sqlAll(
    `SELECT g.id, g.name, g.description, g.cover_image, g.owner_id, g.created_at,
            owner.kadi AS owner_kadi, owner.mezuniyetyili AS owner_mezuniyetyili
     FROM groups g
     LEFT JOIN uyeler owner ON owner.id = g.owner_id
     ${whereSql}
     ORDER BY g.id DESC
     LIMIT ? OFFSET ?`,
    [...params, limit, safeOffset]
  );
  res.json({
    items,
    meta: {
      page: safePage,
      pages,
      limit,
      total,
      q
    }
  });
});

app.delete('/api/new/admin/groups/:id', requireModerationPermission('groups.delete'), (req, res) => {
  const groupId = Number(req.params.id || 0);
  if (!groupId) return res.status(400).send('Geçersiz grup ID.');
  const group = sqlGet('SELECT id, owner_id FROM groups WHERE id = ?', [groupId]);
  if (!group) return res.status(404).send('Grup bulunamadı.');
  const scope = getModerationScopeContext(req.authUser || getCurrentUser(req));
  if (scope.isScopedModerator) {
    if (!group.owner_id) return res.status(403).send('Sahibi olmayan gruplar için kapsam doğrulanamadı.');
    const owner = sqlGet('SELECT mezuniyetyili FROM uyeler WHERE id = ?', [group.owner_id]);
    const ownerYear = String(owner?.mezuniyetyili || '').trim();
    if (!ownerYear || !scope.years.includes(ownerYear)) {
      return res.status(403).send('Bu grup kapsamınız dışında.');
    }
  }
  sqlRun('DELETE FROM group_members WHERE group_id = ?', [groupId]);
  sqlRun('DELETE FROM group_join_requests WHERE group_id = ?', [groupId]);
  sqlRun('DELETE FROM group_invites WHERE group_id = ?', [groupId]);
  sqlRun('DELETE FROM posts WHERE group_id = ?', [groupId]);
  sqlRun('DELETE FROM group_events WHERE group_id = ?', [groupId]);
  sqlRun('DELETE FROM group_announcements WHERE group_id = ?', [groupId]);
  sqlRun('DELETE FROM groups WHERE id = ?', [groupId]);
  logAdminAction(req, 'group_delete', { targetType: 'group', targetId: groupId });
  res.json({ ok: true });
});

app.get('/api/new/admin/stories', requireModerationPermission('stories.view'), (req, res) => {
  const actor = req.authUser || getCurrentUser(req);
  const scope = getModerationScopeContext(actor);
  const { page, limit } = parseAdminListPagination(req.query, { defaultLimit: 60, maxLimit: 250 });
  const q = String(req.query.q || '').trim();
  const params = [];
  const whereParts = ["(u.role IS NULL OR LOWER(COALESCE(u.role, 'user')) != 'root')"];
  if (q) {
    whereParts.push('(LOWER(CAST(s.caption AS TEXT)) LIKE LOWER(?) OR LOWER(CAST(u.kadi AS TEXT)) LIKE LOWER(?))');
    params.push(`%${q}%`, `%${q}%`);
  }
  const scopeFilter = applyModerationScopeFilter(scope, params, 'u.mezuniyetyili');
  const whereSql = `WHERE ${whereParts.join(' AND ')}${scopeFilter}`;

  const total = Number(sqlGet(
    `SELECT COUNT(*) AS cnt
     FROM stories s
     LEFT JOIN uyeler u ON u.id = s.user_id
     ${whereSql}`,
    params
  )?.cnt || 0);
  const pages = Math.max(Math.ceil(total / limit), 1);
  const safePage = Math.min(page, pages);
  const safeOffset = (safePage - 1) * limit;

  const items = sqlAll(
    `SELECT s.id, s.user_id, s.image, s.caption, s.created_at, s.expires_at, u.kadi, u.mezuniyetyili
     FROM stories s
     LEFT JOIN uyeler u ON u.id = s.user_id
     ${whereSql}
     ORDER BY s.id DESC
     LIMIT ? OFFSET ?`,
    [...params, limit, safeOffset]
  );
  res.json({
    items,
    meta: {
      page: safePage,
      pages,
      limit,
      total,
      q
    }
  });
});

app.get('/api/new/admin/posts', requireModerationPermission('posts.view'), (req, res) => {
  const actor = req.authUser || getCurrentUser(req);
  const scope = getModerationScopeContext(actor);
  const { page, limit } = parseAdminListPagination(req.query, { defaultLimit: 80, maxLimit: 300 });
  const q = String(req.query.q || '').trim();
  const params = [];
  const whereParts = ["(u.role IS NULL OR LOWER(COALESCE(u.role, 'user')) != 'root')"];
  if (q) {
    whereParts.push('(LOWER(CAST(p.content AS TEXT)) LIKE LOWER(?) OR LOWER(CAST(u.kadi AS TEXT)) LIKE LOWER(?))');
    params.push(`%${q}%`, `%${q}%`);
  }
  const scopeFilter = applyModerationScopeFilter(scope, params, 'u.mezuniyetyili');
  const whereSql = `WHERE ${whereParts.join(' AND ')}${scopeFilter}`;

  const total = Number(sqlGet(
    `SELECT COUNT(*) AS cnt
     FROM posts p
     LEFT JOIN uyeler u ON u.id = p.user_id
     ${whereSql}`,
    params
  )?.cnt || 0);
  const pages = Math.max(Math.ceil(total / limit), 1);
  const safePage = Math.min(page, pages);
  const safeOffset = (safePage - 1) * limit;

  const items = sqlAll(
    `SELECT p.id, p.user_id, p.content, p.image, p.created_at, u.kadi, u.mezuniyetyili
     FROM posts p
     LEFT JOIN uyeler u ON u.id = p.user_id
     ${whereSql}
     ORDER BY p.id DESC
     LIMIT ? OFFSET ?`,
    [...params, limit, safeOffset]
  );
  res.json({
    items,
    meta: {
      page: safePage,
      pages,
      limit,
      total,
      q
    }
  });
});

app.delete('/api/new/admin/posts/:id', requireModerationPermission('posts.delete'), (req, res) => {
  const postId = Number(req.params.id || 0);
  if (!postId) return res.status(400).send('Geçersiz gönderi ID.');
  const post = sqlGet('SELECT id, user_id FROM posts WHERE id = ?', [postId]);
  if (!post) return res.status(404).send('Gönderi bulunamadı.');
  const target = ensureCanModerateTargetUser(req, res, post.user_id, { notFoundMessage: 'Gönderi sahibi bulunamadı.' });
  if (!target) return;
  deletePostById(postId);
  logAdminAction(req, 'post_delete', { targetType: 'post', targetId: postId, postId, userId: post.user_id });
  scheduleEngagementRecalculation('post_deleted');
  res.json({ ok: true });
});

app.delete('/api/new/admin/stories/:id', requireModerationPermission('stories.delete'), (req, res) => {
  const storyId = Number(req.params.id || 0);
  if (!storyId) return res.status(400).send('Geçersiz hikaye ID.');
  const story = sqlGet('SELECT id, user_id FROM stories WHERE id = ?', [storyId]);
  if (!story) return res.status(404).send('Hikaye bulunamadı.');
  const target = ensureCanModerateTargetUser(req, res, story.user_id, { notFoundMessage: 'Hikaye sahibi bulunamadı.' });
  if (!target) return;
  sqlRun('DELETE FROM story_views WHERE story_id = ?', [storyId]);
  sqlRun('DELETE FROM stories WHERE id = ?', [storyId]);
  logAdminAction(req, 'story_delete', { targetType: 'story', targetId: storyId, storyId, userId: story.user_id });
  res.json({ ok: true });
});

app.get('/api/new/admin/chat/messages', requireModerationPermission('chat.view'), (req, res) => {
  const actor = req.authUser || getCurrentUser(req);
  const scope = getModerationScopeContext(actor);
  const { page, limit } = parseAdminListPagination(req.query, { defaultLimit: 80, maxLimit: 300 });
  const q = String(req.query.q || '').trim();
  const params = [];
  const whereParts = ["(u.role IS NULL OR LOWER(COALESCE(u.role, 'user')) != 'root')"];
  if (q) {
    whereParts.push('(LOWER(CAST(c.message AS TEXT)) LIKE LOWER(?) OR LOWER(CAST(u.kadi AS TEXT)) LIKE LOWER(?))');
    params.push(`%${q}%`, `%${q}%`);
  }
  const scopeFilter = applyModerationScopeFilter(scope, params, 'u.mezuniyetyili');
  const whereSql = `WHERE ${whereParts.join(' AND ')}${scopeFilter}`;

  const total = Number(sqlGet(
    `SELECT COUNT(*) AS cnt
     FROM chat_messages c
     LEFT JOIN uyeler u ON u.id = c.user_id
     ${whereSql}`,
    params
  )?.cnt || 0);
  const pages = Math.max(Math.ceil(total / limit), 1);
  const safePage = Math.min(page, pages);
  const safeOffset = (safePage - 1) * limit;
  let items = sqlAll(
    `SELECT c.id, c.user_id, c.message, c.created_at, u.kadi, u.mezuniyetyili
     FROM chat_messages c
     LEFT JOIN uyeler u ON u.id = c.user_id
     ${whereSql}
     ORDER BY c.id DESC
     LIMIT ? OFFSET ?`,
    [...params, limit, safeOffset]
  );

  // Legacy shoutbox fallback for admin/root only when chat_messages table is empty.
  if (!items.length && total === 0 && !scope.isScopedModerator) {
    try {
      const fallbackParams = [];
      const fallbackWhere = [];
      if (q) {
        fallbackWhere.push('(LOWER(CAST(h.metin AS TEXT)) LIKE LOWER(?) OR LOWER(CAST(h.kadi AS TEXT)) LIKE LOWER(?))');
        fallbackParams.push(`%${q}%`, `%${q}%`);
      }
      const fallbackWhereSql = fallbackWhere.length ? `WHERE ${fallbackWhere.join(' AND ')}` : '';
      const legacyTotal = Number(sqlGet(`SELECT COUNT(*) AS cnt FROM hmes h ${fallbackWhereSql}`, fallbackParams)?.cnt || 0);
      const legacyPages = Math.max(Math.ceil(legacyTotal / limit), 1);
      const legacySafePage = Math.min(page, legacyPages);
      const legacyOffset = (legacySafePage - 1) * limit;
      items = sqlAll(
        `SELECT h.id, NULL AS user_id, h.metin AS message, h.tarih AS created_at, h.kadi, NULL AS mezuniyetyili
         FROM hmes h
         ${fallbackWhereSql}
         ORDER BY h.id DESC
         LIMIT ? OFFSET ?`,
        [...fallbackParams, limit, legacyOffset]
      );
      return res.json({
        items,
        meta: { page: legacySafePage, pages: legacyPages, limit, total: legacyTotal, q, source: 'legacy_hmes' }
      });
    } catch {
      // ignore fallback query errors
    }
  }

  res.json({
    items,
    meta: {
      page: safePage,
      pages,
      limit,
      total,
      q,
      source: 'chat_messages'
    }
  });
});

app.delete('/api/new/admin/chat/messages/:id', requireModerationPermission('chat.delete'), (req, res) => {
  const messageId = Number(req.params.id || 0);
  if (!messageId) return res.status(400).send('Geçersiz mesaj ID.');
  const message = sqlGet('SELECT id, user_id FROM chat_messages WHERE id = ?', [messageId]);
  if (!message) return res.status(404).send('Mesaj bulunamadı.');
  const target = ensureCanModerateTargetUser(req, res, message.user_id, { notFoundMessage: 'Mesaj sahibi bulunamadı.' });
  if (!target) return;
  sqlRun('DELETE FROM chat_messages WHERE id = ?', [messageId]);
  broadcastChatDelete(messageId);
  logAdminAction(req, 'chat_message_delete', { targetType: 'chat_message', targetId: messageId, messageId, userId: message.user_id });
  scheduleEngagementRecalculation('chat_message_deleted');
  res.json({ ok: true });
});

app.get('/api/new/admin/messages', requireModerationPermission('messages.view'), (req, res) => {
  const actor = req.authUser || getCurrentUser(req);
  const scope = getModerationScopeContext(actor);
  const { page, limit } = parseAdminListPagination(req.query, { defaultLimit: 80, maxLimit: 300 });
  const q = String(req.query.q || '').trim();
  const params = [];
  const whereParts = [
    "(u1.role IS NULL OR LOWER(COALESCE(u1.role, 'user')) != 'root')",
    "(u2.role IS NULL OR LOWER(COALESCE(u2.role, 'user')) != 'root')"
  ];
  if (q) {
    whereParts.push('(LOWER(CAST(g.konu AS TEXT)) LIKE LOWER(?) OR LOWER(CAST(g.mesaj AS TEXT)) LIKE LOWER(?) OR LOWER(CAST(u1.kadi AS TEXT)) LIKE LOWER(?) OR LOWER(CAST(u2.kadi AS TEXT)) LIKE LOWER(?))');
    params.push(`%${q}%`, `%${q}%`, `%${q}%`, `%${q}%`);
  }
  if (scope.isScopedModerator) {
    if (!scope.years.length) {
      whereParts.push('1 = 0');
    } else {
      const placeholders = scope.years.map(() => '?').join(', ');
      whereParts.push(`(CAST(COALESCE(u1.mezuniyetyili, '') AS TEXT) IN (${placeholders}) OR CAST(COALESCE(u2.mezuniyetyili, '') AS TEXT) IN (${placeholders}))`);
      params.push(...scope.years, ...scope.years);
    }
  }
  const whereSql = `WHERE ${whereParts.join(' AND ')}`;
  const total = Number(sqlGet(
    `SELECT COUNT(*) AS cnt
     FROM gelenkutusu g
     LEFT JOIN uyeler u1 ON u1.id = g.kimden
     LEFT JOIN uyeler u2 ON u2.id = g.kime
     ${whereSql}`,
    params
  )?.cnt || 0);
  const pages = Math.max(Math.ceil(total / limit), 1);
  const safePage = Math.min(page, pages);
  const safeOffset = (safePage - 1) * limit;
  const items = sqlAll(
    `SELECT g.id, g.konu, g.mesaj, g.tarih, g.kimden, g.kime,
            u1.kadi AS kimden_kadi, u2.kadi AS kime_kadi,
            u1.mezuniyetyili AS kimden_mezuniyetyili, u2.mezuniyetyili AS kime_mezuniyetyili
     FROM gelenkutusu g
     LEFT JOIN uyeler u1 ON u1.id = g.kimden
     LEFT JOIN uyeler u2 ON u2.id = g.kime
     ${whereSql}
     ORDER BY g.id DESC
     LIMIT ? OFFSET ?`,
    [...params, limit, safeOffset]
  );
  res.json({
    items,
    meta: {
      page: safePage,
      pages,
      limit,
      total,
      q
    }
  });
});

app.delete('/api/new/admin/messages/:id', requireModerationPermission('messages.delete'), (req, res) => {
  const messageId = Number(req.params.id || 0);
  if (!messageId) return res.status(400).send('Geçersiz mesaj ID.');
  const item = sqlGet('SELECT id, kimden, kime FROM gelenkutusu WHERE id = ?', [messageId]);
  if (!item) return res.status(404).send('Mesaj bulunamadı.');
  const scope = getModerationScopeContext(req.authUser || getCurrentUser(req));
  if (scope.isScopedModerator) {
    const sender = sqlGet('SELECT mezuniyetyili FROM uyeler WHERE id = ?', [item.kimden]);
    const recipient = sqlGet('SELECT mezuniyetyili FROM uyeler WHERE id = ?', [item.kime]);
    const senderYear = String(sender?.mezuniyetyili || '').trim();
    const recipientYear = String(recipient?.mezuniyetyili || '').trim();
    const touchesScopedYear = [senderYear, recipientYear].some((year) => year && scope.years.includes(year));
    if (!touchesScopedYear) {
      return res.status(403).send('Bu mesaj kapsamınız dışında.');
    }
  }
  sqlRun('DELETE FROM gelenkutusu WHERE id = ?', [messageId]);
  logAdminAction(req, 'inbox_message_delete', { targetType: 'direct_message', targetId: messageId, messageId });
  res.json({ ok: true });
});

app.get('/api/new/admin/filters', requireAdmin, (req, res) => {
  const { page, limit } = parseAdminListPagination(req.query, { defaultLimit: 80, maxLimit: 300 });
  const q = String(req.query.q || '').trim();
  const whereParts = ['1=1'];
  const params = [];
  if (q) {
    whereParts.push('LOWER(CAST(kufur AS TEXT)) LIKE LOWER(?)');
    params.push(`%${q}%`);
  }
  const whereSql = `WHERE ${whereParts.join(' AND ')}`;
  const total = Number(sqlGet(`SELECT COUNT(*) AS cnt FROM filtre ${whereSql}`, params)?.cnt || 0);
  const pages = Math.max(Math.ceil(total / limit), 1);
  const safePage = Math.min(page, pages);
  const safeOffset = (safePage - 1) * limit;
  const items = sqlAll(
    `SELECT id, kufur
     FROM filtre
     ${whereSql}
     ORDER BY id DESC
     LIMIT ? OFFSET ?`,
    [...params, limit, safeOffset]
  );
  res.json({
    items,
    meta: {
      page: safePage,
      pages,
      limit,
      total,
      q
    }
  });
});

app.post('/api/new/admin/filters', requireAdmin, (req, res) => {
  const kufur = normalizeBannedWord(req.body?.kufur);
  if (!kufur) return res.status(400).send('Kelime gerekli.');
  const exists = sqlGet('SELECT id FROM filtre WHERE LOWER(kufur) = LOWER(?)', [kufur]);
  if (exists?.id) return res.status(400).send('Kelime zaten var.');
  const result = sqlRun('INSERT INTO filtre (kufur) VALUES (?)', [kufur]);
  invalidateBannedWordsCache();
  logAdminAction(req, 'blocked_term_create', { targetType: 'blocked_term', targetId: result?.lastInsertRowid || null, kufur });
  res.json({ ok: true, id: result?.lastInsertRowid });
});

app.put('/api/new/admin/filters/:id', requireAdmin, (req, res) => {
  const id = Number(req.params.id || 0);
  if (!id) return res.status(400).send('Geçersiz kelime ID.');
  const kufur = normalizeBannedWord(req.body?.kufur);
  if (!kufur) return res.status(400).send('Kelime gerekli.');
  const row = sqlGet('SELECT id FROM filtre WHERE id = ?', [id]);
  if (!row) return res.status(404).send('Kelime bulunamadı.');
  const exists = sqlGet('SELECT id FROM filtre WHERE LOWER(kufur) = LOWER(?) AND id <> ?', [kufur, id]);
  if (exists?.id) return res.status(400).send('Kelime zaten var.');
  sqlRun('UPDATE filtre SET kufur = ? WHERE id = ?', [kufur, id]);
  invalidateBannedWordsCache();
  logAdminAction(req, 'blocked_term_update', { targetType: 'blocked_term', targetId: id, kufur });
  res.json({ ok: true });
});

app.delete('/api/new/admin/filters/:id', requireAdmin, (req, res) => {
  const id = Number(req.params.id || 0);
  if (!id) return res.status(400).send('Geçersiz kelime ID.');
  const exists = sqlGet('SELECT id, kufur FROM filtre WHERE id = ?', [id]);
  if (!exists) return res.status(404).send('Kelime bulunamadı.');
  sqlRun('DELETE FROM filtre WHERE id = ?', [id]);
  invalidateBannedWordsCache();
  logAdminAction(req, 'blocked_term_delete', { targetType: 'blocked_term', targetId: id, kufur: exists.kufur });
  res.json({ ok: true });
});

app.get('/api/new/admin/db/tables', requireAdmin, async (_req, res) => {
  try {
    if (dbDriver === 'postgres') {
      const rows = await sqlAllAsync(
        `SELECT t.table_name AS name,
                COALESCE(s.n_live_tup, 0)::bigint AS row_count_estimate
         FROM information_schema.tables t
         LEFT JOIN pg_stat_user_tables s
           ON s.schemaname = t.table_schema
          AND s.relname = t.table_name
         WHERE t.table_schema = 'public'
           AND t.table_type = 'BASE TABLE'
         ORDER BY t.table_name ASC`
      );
      return res.json({
        items: rows.map((r) => ({
          name: String(r.name || ''),
          rowCount: Number(r.row_count_estimate || 0)
        }))
      });
    }

    const rows = await sqlAllAsync(
      `SELECT name
       FROM sqlite_master
       WHERE type = 'table' AND name NOT LIKE 'sqlite_%'
       ORDER BY name ASC`
    );
    const tables = [];
    for (const row of rows) {
      const safeName = String(row.name || '');
      const escaped = safeName.replace(/"/g, '""');
      const count = Number((await sqlGetAsync(`SELECT COUNT(*) AS cnt FROM "${escaped}"`))?.cnt || 0);
      tables.push({ name: safeName, rowCount: count });
    }
    return res.json({ items: tables });
  } catch (err) {
    writeAppLog('error', 'admin_db_tables_failed', {
      message: err?.message || 'unknown_error',
      stack: String(err?.stack || '').slice(0, 1000)
    });
    return res.status(500).send('Tablolar listelenirken hata oluştu.');
  }
});

app.get('/api/new/admin/db/table/:name', requireAdmin, async (req, res) => {
  const tableName = String(req.params.name || '');
  const limit = Math.min(Math.max(parseInt(req.query.limit || '50', 10), 1), 200);
  const page = Math.max(parseInt(req.query.page || '1', 10), 1);
  try {
    const available = dbDriver === 'postgres'
      ? (await sqlAllAsync(
          `SELECT table_name AS name
           FROM information_schema.tables
           WHERE table_schema = 'public'
             AND table_type = 'BASE TABLE'`
        )).map((r) => String(r.name || ''))
      : (await sqlAllAsync(
          `SELECT name
           FROM sqlite_master
           WHERE type = 'table' AND name NOT LIKE 'sqlite_%'`
        )).map((r) => String(r.name || ''));

    if (!available.includes(tableName)) {
      return res.status(404).send('Tablo bulunamadı.');
    }

    const escaped = tableName.replace(/"/g, '""');
    const total = Number((await sqlGetAsync(`SELECT COUNT(*) AS cnt FROM "${escaped}"`))?.cnt || 0);
    const pages = Math.max(Math.ceil(total / limit), 1);
    const safePage = Math.min(page, pages);
    const offset = (safePage - 1) * limit;

    const columns = dbDriver === 'postgres'
      ? (await sqlAllAsync(
          `SELECT c.column_name AS name,
                  c.data_type AS type,
                  CASE WHEN c.is_nullable = 'NO' THEN 1 ELSE 0 END AS notnull,
                  CASE WHEN pk.column_name IS NULL THEN 0 ELSE 1 END AS pk
           FROM information_schema.columns c
           LEFT JOIN (
             SELECT kcu.column_name
             FROM information_schema.table_constraints tc
             JOIN information_schema.key_column_usage kcu
               ON kcu.constraint_name = tc.constraint_name
              AND kcu.table_schema = tc.table_schema
             WHERE tc.table_schema = 'public'
               AND tc.table_name = ?
               AND tc.constraint_type = 'PRIMARY KEY'
           ) pk ON pk.column_name = c.column_name
           WHERE c.table_schema = 'public'
             AND c.table_name = ?
           ORDER BY c.ordinal_position`,
          [tableName, tableName]
        )).map((c) => ({
          name: c.name,
          type: c.type,
          notnull: Number(c.notnull || 0),
          pk: Number(c.pk || 0)
        }))
      : (await sqlAllAsync(`PRAGMA table_info("${escaped}")`)).map((c) => ({
          name: c.name,
          type: c.type,
          notnull: c.notnull,
          pk: c.pk
        }));

    const rows = await sqlAllAsync(`SELECT * FROM "${escaped}" LIMIT ? OFFSET ?`, [limit, offset]);
    return res.json({
      table: tableName,
      columns,
      rows,
      total,
      page: safePage,
      pages,
      limit
    });
  } catch (err) {
    writeAppLog('error', 'admin_db_table_detail_failed', {
      table: tableName,
      message: err?.message || 'unknown_error',
      stack: String(err?.stack || '').slice(0, 1000)
    });
    return res.status(500).send('Tablo detayları okunurken hata oluştu.');
  }
});

app.get('/api/new/admin/db/backups', requireAdmin, (_req, res) => {
  res.json({
    items: listDbBackups(),
    dbPath,
    dbDriver
  });
});

app.get('/api/new/admin/db/driver/status', requireAdmin, async (req, res) => {
  try {
    const readiness = await buildDbDriverSwitchReadiness();
    const expectedConfirmText = buildDbDriverSwitchConfirmText(readiness.currentDriver, readiness.targetDriver);
    const challenge = issueDbDriverSwitchChallenge(req, readiness.targetDriver);
    const requiresSqliteDriftAck = readiness.currentDriver === 'postgres' && readiness.targetDriver === 'sqlite';
    const warnings = [];
    if (requiresSqliteDriftAck) {
      warnings.push('PostgreSQL -> SQLite geçişinde otomatik veri kopyalama yapılmaz; mevcut SQLite dosyası kullanılacaktır.');
    }
    warnings.push('Geçiş sırasında API işlemi yeniden başlatılır. Worker servisi için ayrıca restart önerilir.');

    res.json({
      currentDriver: readiness.currentDriver,
      targetDriver: readiness.targetDriver,
      expectedConfirmText,
      challengeToken: challenge.token,
      challengeExpiresAt: new Date(challenge.expiresAt).toISOString(),
      inProgress: dbDriverSwitchState.inProgress,
      switchEnabled: !dbDriverSwitchState.inProgress && readiness.blockers.length === 0,
      blockers: readiness.blockers,
      warnings,
      requiresSqliteDriftAck,
      envFile: readiness.envFile,
      sqlite: readiness.sqlite,
      postgres: readiness.postgres,
      restart: {
        mode: dbDriverSwitchRestartCommand ? 'custom_command' : 'api_process_exit',
        commandConfigured: Boolean(dbDriverSwitchRestartCommand),
        delayMs: dbDriverSwitchRestartDelayMs
      },
      lastSwitch: dbDriverSwitchState.lastSwitch,
      lastAttemptAt: dbDriverSwitchState.lastAttemptAt,
      lastSuccessAt: dbDriverSwitchState.lastSuccessAt,
      lastError: dbDriverSwitchState.lastError
    });
  } catch (err) {
    writeAppLog('error', 'db_driver_switch_status_failed', { message: err?.message || 'unknown_error' });
    res.status(500).send(err?.message || 'DB driver durumu okunamadı.');
  }
});

app.post('/api/new/admin/db/driver/switch', requireAdmin, async (req, res) => {
  if (dbDriverSwitchState.inProgress) {
    return res.status(409).send('DB driver geçişi zaten devam ediyor.');
  }

  const startedAt = new Date().toISOString();
  dbDriverSwitchState.inProgress = true;
  dbDriverSwitchState.lastAttemptAt = startedAt;
  dbDriverSwitchState.lastError = null;

  let envBackupName = '';
  let envUpdated = false;
  try {
    const readiness = await buildDbDriverSwitchReadiness();
    const targetDriver = readiness.targetDriver;
    const expectedConfirmText = buildDbDriverSwitchConfirmText(readiness.currentDriver, targetDriver);
    const requestedTarget = String(req.body?.targetDriver || '').trim().toLowerCase();
    const confirmText = String(req.body?.confirmText || '').trim();
    const challengeToken = String(req.body?.challengeToken || '').trim();
    const acknowledgeSqliteDrift = req.body?.acknowledgeSqliteDrift === true;

    if (requestedTarget && requestedTarget !== targetDriver) {
      return res.status(400).send(`Bu oturumda geçerli hedef driver ${targetDriver}.`);
    }
    if (confirmText !== expectedConfirmText) {
      return res.status(400).send(`Onay metni eşleşmedi. Beklenen: ${expectedConfirmText}`);
    }
    if (!consumeDbDriverSwitchChallenge(req, targetDriver, challengeToken)) {
      return res.status(400).send('Geçiş onayı geçersiz veya süresi dolmuş. Yenileyip tekrar deneyin.');
    }
    if (readiness.currentDriver === 'postgres' && targetDriver === 'sqlite' && !acknowledgeSqliteDrift) {
      return res.status(400).send('PostgreSQL -> SQLite geçişi için veri farklılığı onay kutusu zorunludur.');
    }
    if (readiness.blockers.length > 0) {
      return res.status(400).json({
        ok: false,
        blockers: readiness.blockers
      });
    }

    const stamp = backupTimestamp();
    envBackupName = `sdal-env-pre-driver-switch-${stamp}-${readiness.currentDriver}-to-${targetDriver}.env`;
    const envBackupPath = path.join(dbBackupDir, envBackupName);
    fs.copyFileSync(dbDriverSwitchEnvFile, envBackupPath);

    const backup = await createDbBackup(`pre-switch-${readiness.currentDriver}-to-${targetDriver}`);

    const envUpdates = { SDAL_DB_DRIVER: targetDriver };
    if (targetDriver === 'sqlite') {
      envUpdates.SDAL_DB_PATH = dbPath;
    }
    writeEnvUpdates(dbDriverSwitchEnvFile, envUpdates);
    envUpdated = true;

    const result = {
      switchedFrom: readiness.currentDriver,
      switchedTo: targetDriver,
      envFile: dbDriverSwitchEnvFile,
      envBackup: envBackupName,
      preSwitchBackup: backup?.name || null,
      requestedBy: req.session?.userId || null,
      at: new Date().toISOString()
    };
    dbDriverSwitchState.lastSwitch = result;
    dbDriverSwitchState.lastSuccessAt = result.at;
    logAdminAction(req, 'db_driver_switch', result);

    res.json({
      ok: true,
      message: `DB driver ${targetDriver} olarak güncellendi. Servis yeniden başlatılıyor.`,
      result,
      restart: {
        mode: dbDriverSwitchRestartCommand ? 'custom_command' : 'api_process_exit',
        commandConfigured: Boolean(dbDriverSwitchRestartCommand),
        delayMs: dbDriverSwitchRestartDelayMs
      },
      note: 'Worker servisi farklı process olduğu için ayrıca restart edilmesi önerilir.'
    });

    scheduleDbDriverSwitchRestart({
      switchedFrom: readiness.currentDriver,
      switchedTo: targetDriver,
      userId: req.session?.userId || null
    });
  } catch (err) {
    if (envUpdated && envBackupName) {
      try {
        fs.copyFileSync(path.join(dbBackupDir, envBackupName), dbDriverSwitchEnvFile);
      } catch {
        // best effort rollback
      }
    }
    dbDriverSwitchState.lastError = err?.message || 'unknown_error';
    writeAppLog('error', 'db_driver_switch_failed', {
      message: err?.message || 'unknown_error',
      stack: err?.stack || ''
    });
    res.status(500).send(err?.message || 'DB driver geçişi başarısız.');
  } finally {
    dbDriverSwitchState.inProgress = false;
  }
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
  const backupValidation = validateUploadedFileSafety(req.file.path, { allowedMimes: [] });
  if (!backupValidation.ok) {
    cleanupUploadedFile(req.file.path);
    return res.status(400).send(backupValidation.reason);
  }
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

app.get('/api/panolar', async (req, res) => {
  try {
    if (!req.session.userId) return res.status(401).send('Login required');
    const mkatidRaw = String(req.query.mkatid || '0');
    const mkatid = /^\d+$/.test(mkatidRaw) ? Number(mkatidRaw) : 0;
    let categoryName = 'Genel';
    if (mkatid !== 0) {
      const cat = await sqlGetAsync('SELECT * FROM mesaj_kategori WHERE id = ?', [mkatid]);
      if (!cat) {
        return res.status(400).send('Kategori bulunamadı.');
      }
      categoryName = cat.kategoriadi;
    }

    const page = Math.max(parseInt(req.query.page || '1', 10), 1);
    const pageSize = 25;
    const [user, totalRow, rows] = await Promise.all([
      sqlGetAsync('SELECT id, mezuniyetyili, oncekisontarih, admin FROM uyeler WHERE id = ?', [req.session.userId]),
      sqlGetAsync('SELECT COUNT(*) AS cnt FROM mesaj WHERE kategori = ?', [mkatid]),
      sqlAllAsync('SELECT * FROM mesaj WHERE kategori = ? ORDER BY tarih DESC LIMIT ? OFFSET ?', [mkatid, pageSize, Math.max((page - 1) * pageSize, 0)])
    ]);
    const gradName = user?.mezuniyetyili ? `${user.mezuniyetyili} Mezunları` : null;
    const gradCategory = gradName ? await sqlGetAsync('SELECT * FROM mesaj_kategori WHERE kategoriadi = ?', [gradName]) : null;

    const total = totalRow?.cnt || 0;
    const pages = Math.max(Math.ceil(total / pageSize), 1);
    const safePage = Math.min(page, pages);
    const offset = (safePage - 1) * pageSize;
    const safeRows = offset === Math.max((page - 1) * pageSize, 0)
      ? rows
      : await sqlAllAsync('SELECT * FROM mesaj WHERE kategori = ? ORDER BY tarih DESC LIMIT ? OFFSET ?', [mkatid, pageSize, offset]);

    const senderIds = Array.from(new Set(
      safeRows.map((row) => Number(row.gonderenid || 0)).filter((id) => Number.isInteger(id) && id > 0)
    ));
    const senderMap = new Map();
    if (senderIds.length > 0) {
      const placeholders = senderIds.map(() => '?').join(', ');
      const senderRows = await sqlAllAsync(
        `SELECT id, kadi, resim
         FROM uyeler
         WHERE id IN (${placeholders})`,
        senderIds
      );
      for (const sender of senderRows) {
        senderMap.set(Number(sender.id || 0), sender);
      }
    }

    const messages = safeRows.map((row) => {
      const u = senderMap.get(Number(row.gonderenid || 0)) || { id: row.gonderenid, kadi: 'Üye', resim: 'nophoto.jpg' };
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

    return res.json({
      categoryId: mkatid,
      categoryName,
      gradCategory,
      messages,
      total,
      page: safePage,
      pages,
      pageSize,
      pageList,
      canDelete: hasAdminSession(req, user)
    });
  } catch (err) {
    console.error('panolar.list failed:', err);
    return res.status(500).send('Beklenmeyen bir hata oluştu.');
  }
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
  const formatted = formatUserText(mesaj);
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

app.get('/api/quick-access', async (req, res) => {
  if (!req.session.userId) return res.status(401).send('Login required');
  const user = await sqlGetAsync('SELECT hizliliste FROM uyeler WHERE id = ?', [req.session.userId]);
  const list = String(user?.hizliliste || '0')
    .split(',')
    .map((v) => v.trim())
    .filter((v) => v && v !== '0');
  const unique = Array.from(
    new Set(
      list
        .map((id) => Number(id))
        .filter((id) => Number.isInteger(id) && id > 0)
    )
  );
  if (!unique.length) return res.json({ users: [] });
  const rows = await sqlAllAsync(
    `SELECT id, kadi, resim, mezuniyetyili, online, sonislemtarih, sonislemsaat, role
     FROM uyeler
     WHERE id IN (${unique.map(() => '?').join(',')})`,
    unique
  );
  const rowMap = new Map(rows.map((row) => [Number(row.id), row]));
  const users = unique
    .map((id) => rowMap.get(id))
    .filter((row) => row && normalizeRole(row.role) !== 'root')
    .map((row) => ({
      id: row.id,
      kadi: row.kadi,
      resim: row.resim,
      mezuniyetyili: row.mezuniyetyili,
      online: isRowOnlineNow(row) ? 1 : 0
    }));
  res.json({ users });
});

app.post('/api/quick-access/add', (req, res) => {
  if (!req.session.userId) return res.status(401).send('Login required');
  const id = String(req.body?.id || '').trim();
  if (!/^\d+$/.test(id)) return res.status(400).send('Üye bulunamadı.');
  const target = sqlGet('SELECT id, role FROM uyeler WHERE id = ?', [id]);
  if (!target || normalizeRole(target.role) === 'root') return res.status(404).send('Üye bulunamadı.');
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

// Serve modern frontend
const modernDist = path.resolve(__dirname, '../frontend-modern/dist');
if (fs.existsSync(modernDist)) {
  const hashedAssetPattern = /[._-][A-Za-z0-9_-]{6,}\.(?:js|mjs|css|png|jpg|jpeg|gif|webp|svg|woff2?|ttf)$/i;
  const modernStaticOptions = {
    etag: true,
    lastModified: true,
    setHeaders(res, filePath) {
      const normalized = String(filePath || '').replace(/\\/g, '/');
      const base = path.basename(normalized);
      if (base === 'index.html') {
        res.setHeader('Cache-Control', 'public, max-age=0, must-revalidate');
      } else if (hashedAssetPattern.test(base)) {
        res.setHeader('Cache-Control', 'public, max-age=31536000, immutable');
      } else {
        res.setHeader('Cache-Control', 'public, max-age=3600, must-revalidate');
      }
    }
  };
  app.use('/new', express.static(modernDist, modernStaticOptions));
  app.use('/sdal_new', express.static(modernDist, modernStaticOptions));
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
const clientDist = path.resolve(__dirname, '../frontend-classic/dist');
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

async function onServerStarted() {
  ensureRuntimeDefaults();
  await ensureRootBootstrapAccount();
  const usersTableName = dbDriver === 'postgres' ? 'users' : 'uyeler';
  const usersExists = dbDriver === 'postgres'
    ? !!sqlGet(
      "SELECT table_name FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'users' LIMIT 1"
    )
    : !!sqlGet(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'uyeler'"
    );
  const tableCount = dbDriver === 'postgres'
    ? (sqlGet(
      "SELECT COUNT(*) AS cnt FROM information_schema.tables WHERE table_schema = 'public'"
    )?.cnt || 0)
    : (sqlGet(
      "SELECT COUNT(*) AS cnt FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%'"
    )?.cnt || 0);
  console.log(`SDAL server running on http://localhost:${port}`);
  console.log(`[startup] dbPath=${dbPath}`);
  console.log(`[startup] cwd=${process.cwd()} node_env=${process.env.NODE_ENV || 'development'}`);
  console.log(`[startup] tables=${tableCount} ${usersTableName}_exists=${usersExists ? 'yes' : 'no'}`);
  writeLegacyLog('page', 'server_started', { port, node: process.version });
  writeAppLog('info', 'server_started', {
    port,
    node: process.version,
    dbPath,
    tableCount,
    usersTableName,
    usersExists
  });

  realtimeBus = createRealtimeBus({
    onChatEvent: (payload) => broadcastChatEventLocal(payload),
    onMessengerEvent: (userIds, payload) => broadcastMessengerEventLocal(userIds, payload),
    logger: {
      warn: (...args) => writeAppLog('warn', 'realtime_bus_warn', { args }),
      error: (...args) => writeAppLog('error', 'realtime_bus_error', { args })
    }
  });

  try {
    await realtimeBus.start();
  } catch (err) {
    writeAppLog('warn', 'realtime_bus_start_failed', { message: err?.message || 'unknown_error' });
  }

  if (runInlineJobWorker && backgroundJobQueue) {
    inlineJobWorkerStarted = true;
    writeAppLog('info', 'background_worker_started_inline', {
      queueNamespace: jobQueueNamespace
    });
    Promise.resolve(backgroundJobQueue.startWorker({
      handlers: getBackgroundJobHandlers(),
      pollTimeoutSeconds: 2
    }))
      .catch((err) => {
        inlineJobWorkerStarted = false;
        writeAppLog('warn', 'background_worker_inline_failed', {
          queueNamespace: jobQueueNamespace,
          message: err?.message || 'unknown_error'
        });
      });
  }
}

function setupProcessHandlers() {
  let shuttingDown = false;
  async function shutdown(signal) {
    if (shuttingDown) return;
    shuttingDown = true;
    try {
      await realtimeBus?.stop?.();
    } catch {
      // no-op
    }
    try {
      await backgroundJobQueue?.stopWorker?.();
    } catch {
      // no-op
    }
    try {
      await closeRedisClient();
    } catch {
      // no-op
    }
    try {
      await closePostgresPool();
    } catch {
      // no-op
    }
    try {
      closeDbConnection();
    } catch {
      // no-op
    }
    if (signal) {
      writeAppLog('info', 'process_shutdown', { signal });
    }
  }

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

  process.on('SIGINT', () => {
    shutdown('SIGINT').finally(() => process.exit(0));
  });
  process.on('SIGTERM', () => {
    shutdown('SIGTERM').finally(() => process.exit(0));
  });
  process.on('beforeExit', () => {
    shutdown('beforeExit');
  });
}

function parseWsUserIdFromQuery(req) {
  try {
    const url = new URL(req.url || '', 'http://localhost');
    const userId = Number(url.searchParams.get('userId') || 0);
    return userId > 0 ? userId : 0;
  } catch {
    return 0;
  }
}

function attachSessionToUpgradeRequest(req) {
  return new Promise((resolve) => {
    const fakeRes = {
      getHeader() { return undefined; },
      setHeader() {},
      writeHead() {},
      end() {}
    };
    try {
      sessionParser(req, fakeRes, () => resolve(req.session || null));
    } catch {
      resolve(null);
    }
  });
}

async function resolveWsUser(req) {
  const session = await attachSessionToUpgradeRequest(req);
  const sessionUserId = Number(normalizeUserId(session?.userId) || 0);
  const queryUserId = parseWsUserIdFromQuery(req);

  if (sessionUserId > 0) {
    if (queryUserId > 0 && queryUserId !== sessionUserId) {
      return { userId: 0, reason: 'session_query_mismatch' };
    }
    return { userId: sessionUserId, source: 'session' };
  }

  if (allowLegacyWsQueryAuth && queryUserId > 0) {
    writeAppLog('warn', 'ws_legacy_query_auth_used', { path: req.url || '', userId: queryUserId });
    return { userId: queryUserId, source: 'legacy_query' };
  }

  return { userId: 0, reason: 'missing_session' };
}

function attachWebSocketServers(server) {
  chatWss = new WebSocketServer({ server, path: '/ws/chat' });
  chatWss.on('connection', async (ws, req) => {
    const auth = await resolveWsUser(req);
    if (!auth.userId) {
      ws.close(1008, 'Unauthorized');
      return;
    }
    ws.sdalUserId = auth.userId;

    ws.on('message', (data) => {
      try {
        const payload = JSON.parse(String(data || '{}'));
        const userId = Number(ws.sdalUserId || 0);
        const rawMessage = String(payload?.message || '').slice(0, 5000);
        if (!userId || !rawMessage) return;
        const user = sqlGet('SELECT id, kadi, isim, soyisim, resim, verified FROM uyeler WHERE id = ?', [userId]) || null;
        if (!user?.id) return;
        const message = formatUserText(rawMessage || '');
        if (isFormattedContentEmpty(message)) return;
        const now = new Date().toISOString();
        const result = sqlRun('INSERT INTO chat_messages (user_id, message, created_at) VALUES (?, ?, ?)', [
          userId,
          message,
          now
        ]);
        scheduleEngagementRecalculation('chat_message_created');
        const item = {
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
        };
        broadcastChatMessage(item);
      } catch {
        // ignore
      }
    });
  });

  messengerWss = new WebSocketServer({ server, path: '/ws/messenger' });
  messengerWss.on('connection', async (ws, req) => {
    const auth = await resolveWsUser(req);
    if (!auth.userId) {
      ws.close(1008, 'Unauthorized');
      return;
    }
    ws.sdalUserId = auth.userId;
    try {
      ws.send(JSON.stringify({ type: 'messenger:hello', userId: auth.userId }));
    } catch {
      // ignore
    }
  });
}

export { app, port, onServerStarted, setupProcessHandlers, attachWebSocketServers };
export default app;
