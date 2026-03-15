import express from 'express';
import path from 'path';
import cookieParser from 'cookie-parser';
import morgan from 'morgan';
import { sqlGet, sqlAll, sqlRun, sqlGetAsync, sqlAllAsync, sqlRunAsync, dbPath, getDb, closeDbConnection, resetDbConnection, dbDriver, configureDbInstrumentation } from './db.js';
import { mapLegacyUrl } from './legacyRoutes.js';
import fs from 'fs';
import os from 'os';
import { execFileSync } from 'child_process';
import crypto from 'crypto';
import { metinDuzenle } from './textFormat.js';
import { processUpload, deleteImageRecord, getImageVariants, getImageVariantsBatch, loadMediaSettings } from './media/uploadPipeline.js';
import { getDirname } from './config/paths.js';
import { isProd, port, uploadsDir, legacyDir, ONLINE_HEARTBEAT_MS } from './config/env.js';
import { sessionMiddleware } from './middleware/session.js';
import { presenceMiddleware, toLocalDateParts } from './middleware/presence.js';
import { requestLoggingMiddleware } from './middleware/requestLogging.js';
import { registerStaticUploads } from './middleware/staticUploads.js';
import { registerLegacyStatics } from './routes/staticLegacy.js';
import { registerLegacyUtilityRoutes } from './routes/legacyUtilityRoutes.js';
import { registerSystemRoutes } from './routes/systemRoutes.js';
import { registerAdminModerationRoutes } from './routes/adminModerationRoutes.js';
import { registerAdminOperationsRoutes } from './routes/adminOperationsRoutes.js';
import { registerAdminContentModerationRoutes } from './routes/adminContentModerationRoutes.js';
import { registerAdminDbRoutes } from './routes/adminDbRoutes.js';
import { registerAdminExperimentRoutes } from './routes/adminExperimentRoutes.js';
import { registerAdminManagementRoutes } from './routes/adminManagementRoutes.js';
import { registerAdminRequestModerationRoutes } from './routes/adminRequestModerationRoutes.js';
import { registerAccountRoutes } from './routes/accountRoutes.js';
import { registerEventJobRoutes } from './routes/eventJobRoutes.js';
import { registerGroupRoutes } from './routes/groupRoutes.js';
import { registerMemberCommunicationRoutes } from './routes/memberCommunicationRoutes.js';
import { registerMiscAppRoutes } from './routes/miscAppRoutes.js';
import { registerNetworkDiscoveryRoutes } from './routes/networkDiscoveryRoutes.js';
import { registerNetworkRequestRoutes } from './routes/networkRequestRoutes.js';
import { registerNotificationRoutes } from './routes/notificationRoutes.js';
import { registerOAuthRoutes } from './routes/oauthRoutes.js';
import { registerProfileSelfServiceRoutes } from './routes/profileSelfServiceRoutes.js';
import { registerStoryRoutes } from './routes/storyRoutes.js';
import { registerTeacherNetworkRoutes } from './routes/teacherNetworkRoutes.js';
import { createPhase1DomainLayer } from './src/bootstrap/createPhase1DomainLayer.js';
import { createDbAdminRuntime } from './src/admin/createDbAdminRuntime.js';
import { hardDeleteUser as executeHardDeleteUser } from './src/admin/hardDeleteUser.js';
import { createAdminInsightsRuntime } from './src/admin/createAdminInsightsRuntime.js';
import { createNotificationGovernanceRuntime } from './src/notifications/createNotificationGovernanceRuntime.js';
import { createNotificationPresentationRuntime } from './src/notifications/createNotificationPresentationRuntime.js';
import { createNetworkingRuntime } from './src/networking/createNetworkingRuntime.js';
import { createWebSocketRuntime } from './src/realtime/createWebSocketRuntime.js';
import { createEventChatRuntime } from './src/events/createEventChatRuntime.js';
import { createAuthRuntime } from './src/auth/createAuthRuntime.js';
import { createAuthHelpers } from './src/auth/createAuthHelpers.js';
import { checkPostgresHealth, closePostgresPool, getPostgresPoolState, isPostgresConfigured } from './src/infra/postgresPool.js';
import { checkRedisHealth, closeRedisClient, getRedisState, isRedisConfigured } from './src/infra/redisClient.js';
import { buildVersionedCacheKey, bumpCacheNamespaceVersion, getCacheJson, setCacheJson } from './src/infra/performanceCache.js';
import { createRealtimeBus } from './src/infra/realtimeBus.js';
import { createJobQueue } from './src/infra/jobQueue.js';
import { createMailSender } from './src/infra/mailSender.js';
import { createUploadSecurity } from './src/uploads/createUploadSecurity.js';
import { createMediaRuntime } from './src/uploads/createMediaRuntime.js';
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

const dbAdminRuntime = createDbAdminRuntime({
  appRootDir: __dirname,
  dbDriver,
  dbPath,
  getDb,
  closeDbConnection,
  resetDbConnection,
  checkPostgresHealth,
  pgQuery,
  writeAppLog
});
const { dbBackupIncomingDir } = dbAdminRuntime;
const {
  allowedImageSafetyMimes,
  validateUploadedFileSafety,
  cleanupUploadedFile,
  photoUpload,
  albumUpload,
  postUpload,
  storyUpload,
  groupUpload,
  verificationProofUpload,
  requestAttachmentUpload,
  dbBackupUpload,
  imageUpload
} = createUploadSecurity({
  vesikalikDir,
  albumDir,
  postDir,
  storyDir,
  groupDir,
  verificationProofDir,
  requestAttachmentDir,
  dbBackupIncomingDir,
  dbDriver
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
const isPostgresDb = dbDriver === 'postgres';
const joinUserOnPhotoOwnerExpr = isPostgresDb ? 'u.id::text = f.ekleyenid::text' : 'u.id = f.ekleyenid';
const joinUserOnPostAuthorExpr = isPostgresDb ? 'u.id::text = p.user_id::text' : 'u.id = p.user_id';

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

async function hardDeleteUser(userId, deps) {
  return executeHardDeleteUser(userId, {
    ...deps,
    getTableColumnSetAsync,
    deleteImageRecord
  });
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
        `SELECT name
         FROM (
           SELECT table_name AS name
           FROM information_schema.tables
           WHERE table_schema = 'public'
           UNION ALL
           SELECT table_name AS name
           FROM information_schema.views
           WHERE table_schema = 'public'
         ) relations
         WHERE name = ?
         LIMIT 1`,
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
      `ALTER TABLE media_settings
       ADD COLUMN IF NOT EXISTS album_uploads_require_approval BOOLEAN NOT NULL DEFAULT FALSE`
    );
    sqlRun(
      `INSERT INTO media_settings
        (id, storage_provider, local_base_path, thumb_width, feed_width, full_width, webp_quality, max_upload_bytes, avif_enabled, album_uploads_require_approval, updated_at)
       VALUES
        (1, 'local', ?, 200, 800, 1600, 80, 10485760, FALSE, FALSE, ?)
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

  sqlRun(`
    CREATE TABLE IF NOT EXISTS site_controls (
      id INTEGER PRIMARY KEY,
      site_open INTEGER DEFAULT 1,
      maintenance_message TEXT,
      updated_at TEXT
    )
  `);
  sqlRun(`
    CREATE TABLE IF NOT EXISTS module_controls (
      module_key TEXT PRIMARY KEY,
      is_open INTEGER DEFAULT 1,
      updated_at TEXT
    )
  `);
  sqlRun(`
    CREATE TABLE IF NOT EXISTS media_settings (
      id INTEGER PRIMARY KEY,
      storage_provider TEXT DEFAULT 'local',
      local_base_path TEXT,
      thumb_width INTEGER DEFAULT 200,
      feed_width INTEGER DEFAULT 800,
      full_width INTEGER DEFAULT 1600,
      webp_quality INTEGER DEFAULT 80,
      max_upload_bytes INTEGER DEFAULT 10485760,
      avif_enabled INTEGER DEFAULT 0,
      album_uploads_require_approval INTEGER DEFAULT 0,
      updated_at TEXT
    )
  `);
  if (!hasColumn('media_settings', 'album_uploads_require_approval')) {
    sqlRun('ALTER TABLE media_settings ADD COLUMN album_uploads_require_approval INTEGER DEFAULT 0');
  }
  sqlRun(
    `INSERT INTO site_controls (id, site_open, maintenance_message, updated_at)
     VALUES (1, 1, ?, ?)
     ON CONFLICT(id) DO NOTHING`,
    ['Site geçici bakım modundadır. Lütfen daha sonra tekrar deneyin.', now]
  );
  for (const def of MODULE_DEFINITIONS) {
    sqlRun(
      `INSERT INTO module_controls (module_key, is_open, updated_at)
       VALUES (?, 1, ?)
       ON CONFLICT(module_key) DO UPDATE SET updated_at = excluded.updated_at`,
      [def.key, now]
    );
  }
  sqlRun(
    `INSERT INTO media_settings
      (id, storage_provider, local_base_path, thumb_width, feed_width, full_width, webp_quality, max_upload_bytes, avif_enabled, album_uploads_require_approval, updated_at)
     VALUES
      (1, 'local', ?, 200, 800, 1600, 80, 10485760, 0, 0, ?)
     ON CONFLICT(id) DO NOTHING`,
    [uploadsDir, now]
  );

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

const {
  escapeHtml,
  resolvePublicBaseUrl,
  buildActivationEmailHtml,
  createActivation,
  normalizeEmail,
  validateEmail,
  extractEmails
} = createAuthHelpers({ port });

const {
  hashE2EPassword,
  normalizeRole,
  roleAtLeast,
  getUserRole,
  hasAdminRole,
  isVerifiedMember,
  ensureVerifiedSocialHubMember,
  buildModeratorPermissionMap,
  getModeratorPermissionSummary,
  replaceModeratorPermissions,
  replaceModeratorPermissionsAsync,
  userHasModerationPermission,
  requireModerationPermission,
  hasAdminSession,
  hashPassword,
  verifyPassword,
  isRootUser,
  selectCompatUserById,
  getCurrentUser,
  MIN_GRADUATION_YEAR,
  MAX_GRADUATION_YEAR,
  TEACHER_COHORT_VALUE,
  normalizeCohortValue,
  parseGraduationYear,
  hasValidGraduationYear,
  hasKvkkConsent,
  hasDirectoryConsent,
  isOAuthProfileIncomplete,
  requireAuth,
  requireRole,
  requireScopedModeration,
  getModeratorScopedGraduationYears,
  getModerationScopeContext,
  applyModerationScopeFilter,
  ensureCanModerateTargetUser
} = createAuthRuntime({
  dbDriver,
  sqlGet,
  sqlAll,
  sqlRun,
  sqlRunAsync,
  sqlGetAsync,
  sqlAllAsync,
  moderationActionDefinitions: MODERATION_ACTION_DEFINITIONS,
  moderationResourceDefinitions: MODERATION_RESOURCE_DEFINITIONS,
  moderationPermissionKeySet: MODERATION_PERMISSION_KEY_SET
});

const {
  getMediaUploadLimitBytes,
  validateUploadedImageFile,
  enforceUploadQuota,
  processDiskImageUpload
} = createMediaRuntime({
  sqlGet,
  loadMediaSettings,
  envInt,
  allowedImageSafetyMimes,
  validateUploadedFileSafety,
  cleanupUploadedFile,
  applyImageFilter,
  getCurrentUser,
  getUserRole,
  roleAtLeast,
  consumeUploadQuota,
  uploadsDir,
  writeAppLog
});

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

function parseAdminListPagination(query, { defaultLimit = 50, maxLimit = 200 } = {}) {
  const page = Math.max(parseInt(query?.page || '1', 10) || 1, 1);
  const limit = Math.min(Math.max(parseInt(query?.limit || String(defaultLimit), 10) || defaultLimit, 1), maxLimit);
  const offset = (page - 1) * limit;
  return { page, limit, offset };
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
  if (dbDriver !== 'postgres' && !hasTable('site_controls')) {
    return {
      siteOpen: true,
      maintenanceMessage: 'Site geçici bakım modundadır. Lütfen daha sonra tekrar deneyin.',
      updatedAt: null
    };
  }
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
  if (dbDriver !== 'postgres' && !hasTable('module_controls')) {
    return Object.fromEntries(MODULE_DEFINITIONS.map((def) => [def.key, true]));
  }
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

const notificationPresentationRuntime = createNotificationPresentationRuntime({
  sqlRun,
  sqlGet,
  sqlAllAsync,
  hasTable,
  ensureJobApplicationsTable
});
const {
  notificationTypeInventory,
  getNotificationCategory,
  getNotificationPriority,
  ensureNotificationIndexes,
  buildNotificationSortBucketSql,
  normalizeNotificationSortMode,
  buildNotificationOrderSql,
  parseNotificationCursor,
  buildNotificationCursor,
  buildNotificationTarget,
  buildNotificationActions,
  enrichNotificationRows
} = notificationPresentationRuntime;
const notificationGovernanceRuntime = createNotificationGovernanceRuntime({
  sqlRun,
  sqlGet,
  sqlAll,
  sqlRunAsync,
  sqlGetAsync,
  hasTable,
  sanitizePlainUserText,
  getNotificationCategory,
  getNotificationPriority
});
const {
  notificationPreferenceCategoryKeys,
  notificationGovernanceChecklist,
  ensureNotificationPreferencesTable,
  ensureNotificationExperimentConfigsTable,
  readNotificationExperimentConfigs,
  getNotificationExperimentAssignments,
  readNotificationPreferenceRow,
  mapNotificationPreferenceResponse,
  getNotificationDedupeRule,
  ensureNotificationDeliveryAuditTable,
  ensureNotificationTelemetryEventsTable,
  normalizeNotificationTelemetryEventName,
  recordNotificationTelemetryEvent,
  addNotification
} = notificationGovernanceRuntime;

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
  if (!ensureNetworkSuggestionAbTables() || !hasTable('network_suggestion_ab_config')) return false;
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
  return true;
}

function getNetworkSuggestionAbConfigs() {
  try {
    if (!ensureNetworkSuggestionAbConfigRows() || !hasTable('network_suggestion_ab_config')) {
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
  } catch {
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
  const canPersistAssignment = hasTable('network_suggestion_ab_assignments');
  let existing = null;
  if (safeUserId && canPersistAssignment) {
    try {
      existing = sqlGet('SELECT variant FROM network_suggestion_ab_assignments WHERE user_id = ?', [safeUserId]);
    } catch {
      existing = null;
    }
  }
  let variant = String(existing?.variant || '').trim().toUpperCase();
  if (!variant || !enabledVariants.has(variant)) {
    variant = chooseVariantForUser(safeUserId, configs);
    if (safeUserId > 0 && canPersistAssignment) {
      const now = new Date().toISOString();
      try {
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
      } catch {
        // A/B assignment persistence is optional on runtime paths; continue with in-memory choice.
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

function getSafeAssignedNetworkSuggestionVariant(userId) {
  try {
    return getAssignedNetworkSuggestionVariant(userId).variant || 'A';
  } catch {
    return 'A';
  }
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

    // Wrap all per-user writes in a single transaction to avoid per-statement commit overhead
    sqlRun('BEGIN');
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
    sqlRun('COMMIT');

    writeAppLog('info', 'engagement_scores_recalculated', {
      reason,
      users: users.length,
      variants: variantCounts,
      durationMs: Date.now() - startedAt
    });
  } catch (err) {
    try { sqlRun('ROLLBACK'); } catch { /* best effort */ }
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
    const buf = await image.jpeg({ quality: 85 }).toBuffer();
    res.type('image/jpeg');
    res.send(buf);
  } catch (err) {
    try {
      writeAppLog('warn', 'legacy_image_processing_failed', {
        filePath,
        message: err?.message || 'unknown_error'
      });
    } catch {
      // best effort logging
    }
    if (filePath && fs.existsSync(filePath)) {
      res.setHeader('Cache-Control', 'public, max-age=3600, stale-while-revalidate=86400');
      return res.sendFile(filePath);
    }
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

registerLegacyUtilityRoutes(app, {
  legacyMediaDir,
  legacyRoot,
  issueCaptcha,
  resolveMediaFile,
  sendImage,
  sendSvg,
  svgTextImage,
  parseLegacyBool,
  sqlAll,
  sqlGet,
  sqlRun,
  sqlGetAsync,
  sqlAllAsync,
  sqlRunAsync,
  toLocalDateParts,
  getCurrentUser,
  formatUserText
});

const {
  normalizeEventResponse,
  getEventResponseBundle,
  createEventRecord,
  broadcastChatMessage,
  broadcastChatUpdate,
  broadcastChatDelete,
  broadcastChatEventLocal,
  canManageChatMessage
} = createEventChatRuntime({
  sqlAll,
  sqlAllAsync,
  sqlRunAsync,
  sanitizePlainUserText,
  sameUserId,
  getCurrentUser,
  hasAdminSession,
  getTableColumnSetAsync,
  formatUserText,
  toDbFlagForColumn,
  notifyMentions,
  getChatWss: () => chatWss,
  getRealtimeBus: () => realtimeBus
});

const {
  handleEngagementAbOverview,
  handleEngagementAbUpdate,
  handleEngagementAbRebalance,
  handleAdminDashboardSummary,
  handleAdminDashboardActivity
} = createAdminInsightsRuntime({
  sqlGet,
  sqlAll,
  sqlGetAsync,
  sqlAllAsync,
  sqlRun,
  hasTable,
  hasColumn,
  joinUserOnPhotoOwnerExpr,
  readAdminStorageSnapshot,
  cleanupStaleOnlineUsersAsync,
  listOnlineMembersAsync,
  getEngagementAbConfigs,
  engagementDefaultParams,
  engagementDefaultVariants,
  normalizeEngagementParams,
  toDbBooleanParam,
  recalculateMemberEngagementScores,
  scheduleEngagementRecalculation,
  logAdminAction,
  getStatsCache: () => adminStatsResponseCache,
  setStatsCache: (value) => { adminStatsResponseCache = value; },
  getLiveCache: () => adminLiveResponseCache,
  setLiveCache: (value) => { adminLiveResponseCache = value; },
  adminStatsCacheTtlMs: ADMIN_STATS_CACHE_TTL_MS,
  adminLiveCacheTtlMs: ADMIN_LIVE_CACHE_TTL_MS
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

registerSystemRoutes(app, {
  dbDriver,
  dbPath,
  sqlGet,
  sqlGetAsync,
  checkPostgresHealth,
  checkRedisHealth,
  isPostgresConfigured,
  isRedisConfigured,
  getPostgresPoolState,
  getRedisState,
  getRealtimeBus: () => realtimeBus,
  getBackgroundJobQueue: () => backgroundJobQueue,
  issueCaptcha,
  resolveModuleKeyByPath,
  getModuleControlMap,
  getSiteControl,
  getCurrentUser,
  isOAuthProfileIncomplete,
  getUserRole,
  roleAtLeast,
  getModeratorPermissionSummary
});

registerOAuthRoutes(app, {
  sqlGet,
  sqlRun,
  sqlGetAsync,
  sqlRunAsync,
  getEnabledOAuthProviders,
  getOAuthProviderConfig,
  randomState,
  sanitizeOAuthReturnTo,
  base64Url,
  withOAuthError,
  oauthFetchToken,
  oauthFetchProfile,
  findOrCreateOAuthUser,
  issueMobileOAuthToken,
  consumeMobileOAuthToken,
  applyUserSession,
  oauthLoginToSuccessPath
});

app.post('/api/auth/login', loginRateLimit, phase1Domain.controllers.auth.login);

app.post('/api/auth/logout', phase1Domain.controllers.auth.logout);

registerAdminModerationRoutes(app, {
  sqlGet,
  sqlAll,
  sqlRun,
  sqlGetAsync,
  sqlAllAsync,
  sqlRunAsync,
  requireAdmin,
  requireAuth,
  requireRole,
  requireScopedModeration,
  phase1Domain,
  getUserRole,
  roleAtLeast,
  hasAdminRole,
  getCurrentUser,
  getModeratorPermissionSummary,
  normalizeRole,
  parseGraduationYear,
  writeAuditLog,
  writeLegacyLog,
  writeAppLog,
  adminPassword,
  MIN_GRADUATION_YEAR,
  MAX_GRADUATION_YEAR,
  MODERATION_ACTION_DEFINITIONS,
  MODERATION_RESOURCE_DEFINITIONS,
  MODERATION_PERMISSION_DEFINITIONS,
  MODERATION_PERMISSION_KEY_SET,
  toDbBooleanParam
});

registerAdminOperationsRoutes(app, {
  dbDriver,
  sqlGet,
  sqlAll,
  sqlRun,
  sqlGetAsync,
  sqlAllAsync,
  sqlRunAsync,
  uploadsDir,
  appLogsDir,
  appLogFile,
  hatalogDir,
  sayfalogDir,
  uyedetaylogDir,
  cacheNamespaces,
  ADMIN_SETTINGS_CACHE_TTL_SECONDS,
  requireAdmin,
  requireAuth,
  requireAlbumAdmin,
  uploadRateLimit,
  imageUpload,
  getCurrentUser,
  getUserRole,
  normalizeRole,
  hasValidGraduationYear,
  normalizeCohortValue,
  MIN_GRADUATION_YEAR,
  MAX_GRADUATION_YEAR,
  buildVersionedCacheKey,
  getCacheJson,
  setCacheJson,
  getSiteControl,
  getModuleControlMap,
  invalidateControlSnapshots,
  invalidateCacheNamespace,
  MODULE_DEFINITIONS,
  writeAppLog,
  processUpload,
  enforceUploadQuota,
  hardDeleteUser,
  logAdminAction,
  normalizeEmail,
  validateEmail,
  queueEmailDelivery,
  extractEmails,
  parseDateInput,
  readLogFile,
  filterLogContent,
  listLogFiles,
  sanitizePlainUserText,
  formatUserText,
  scheduleEngagementRecalculation
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
registerAdminManagementRoutes(app, {
  dbDriver,
  requireAdmin,
  requireAlbumAdmin,
  sqlGet,
  sqlAll,
  sqlRun,
  sqlGetAsync,
  sqlAllAsync,
  sqlRunAsync,
  getUserRole,
  normalizeRole,
  hardDeleteUser,
  uploadsDir,
  writeAppLog,
  normalizeCohortValue,
  hasValidGraduationYear,
  minGraduationYear: MIN_GRADUATION_YEAR,
  maxGraduationYear: MAX_GRADUATION_YEAR,
  logAdminAction,
  normalizeEmail,
  validateEmail,
  scheduleEngagementRecalculation,
  hatalogDir,
  sayfalogDir,
  uyedetaylogDir,
  appLogsDir,
  appLogFile,
  parseDateInput,
  readLogFile,
  filterLogContent,
  listLogFiles,
  queueEmailDelivery,
  extractEmails,
  sanitizePlainUserText,
  formatUserText
});


registerAccountRoutes(app, {
  sqlGet,
  sqlGetAsync,
  sqlAll,
  sqlAllAsync,
  sqlRun,
  sqlRunAsync,
  writeAppLog,
  normalizeEmail,
  validateEmail,
  normalizeCohortValue,
  parseGraduationYear,
  hasValidGraduationYear,
  filterKufur,
  isE2EHarnessRequest,
  normalizeE2ERole,
  parseE2EModerationPermissionKeys,
  roleAtLeast,
  MODERATION_PERMISSION_KEY_SET,
  replaceModeratorPermissionsAsync,
  createActivation,
  hashPassword,
  hashE2EPassword,
  toDbBooleanParam,
  resolvePublicBaseUrl,
  buildActivationEmailHtml,
  queueEmailDelivery,
  extractEmails,
  mailSender,
  mailProviderStatus,
  escapeHtml
});
registerProfileSelfServiceRoutes(app, {
  requireAuth,
  sqlGet,
  sqlGetAsync,
  sqlAll,
  sqlRun,
  sqlRunAsync,
  buildVersionedCacheKey,
  cacheNamespaces,
  getCacheJson,
  setCacheJson,
  profileCacheTtlSeconds: PROFILE_CACHE_TTL_SECONDS,
  normalizeCohortValue,
  hasValidGraduationYear,
  minGraduationYear: MIN_GRADUATION_YEAR,
  maxGraduationYear: MAX_GRADUATION_YEAR,
  getTableColumnSetAsync,
  getColumnType,
  toDbFlagForColumn,
  toDbNumericFlag,
  toTruthyFlag,
  writeAppLog,
  isE2EHarnessRequest,
  getCurrentUser,
  normalizeEmail,
  validateEmail,
  resolvePublicBaseUrl,
  escapeHtml,
  queueEmailDelivery,
  uploadRateLimit,
  requestAttachmentUpload,
  validateUploadedFileSafety,
  cleanupUploadedFile,
  enforceUploadQuota,
  verifyPassword,
  hashPassword,
  photoUpload,
  processDiskImageUpload,
  uploadImagePresets,
  mapLegacyUrl,
  invalidateCacheNamespace
});

registerMemberCommunicationRoutes(app, {
  requireAuth,
  sqlGet,
  sqlAll,
  sqlRun,
  sqlGetAsync,
  sqlAllAsync,
  sqlRunAsync,
  ensureTeacherAlumniLinksTable: (...args) => ensureTeacherAlumniLinksTable(...args),
  getCachedActiveMemberNameRows,
  buildMemberTrustBadges,
  toNumericUserIdOrNull,
  sameUserId,
  normalizeUserId,
  toDbFlagForColumn,
  sanitizePlainUserText,
  formatUserText,
  notifyMentions,
  writeAppLog,
  ensureMessengerThread,
  getMessengerThreadForUser,
  markMessengerMessagesDelivered,
  broadcastMessengerEvent,
  messengerSendIdempotency,
  albumUpload,
  processDiskImageUpload,
  loadMediaSettings,
  uploadImagePresets,
  getCurrentUser,
  addNotification
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

registerNotificationRoutes(app, {
  requireAuth,
  requireAdmin,
  sqlGetAsync,
  sqlAllAsync,
  sqlRun,
  sqlRunAsync,
  ensureNotificationIndexes,
  normalizeNotificationSortMode,
  parseNotificationCursor,
  buildNotificationSortBucketSql,
  buildNotificationOrderSql,
  enrichNotificationRows,
  buildNotificationCursor,
  apiSuccessEnvelope: (...args) => apiSuccessEnvelope(...args),
  sendApiError: (...args) => sendApiError(...args),
  normalizeNotificationTelemetryEventName,
  recordNotificationTelemetryEvent,
  readNotificationPreferenceRow,
  mapNotificationPreferenceResponse,
  getNotificationExperimentAssignments,
  readNotificationExperimentConfigs,
  ensureNotificationPreferencesTable,
  notificationPreferenceCategoryKeys,
  getNotificationCategory,
  getNotificationPriority,
  getNotificationDedupeRule,
  notificationGovernanceChecklist,
  ensureNotificationExperimentConfigsTable,
  ensureNotificationDeliveryAuditTable,
  ensureNotificationTelemetryEventsTable: (...args) => ensureNetworkingTelemetryEventsTable(...args),
  parseNetworkWindowDays: (...args) => parseNetworkWindowDays(...args),
  toIsoThreshold: (...args) => toIsoThreshold(...args),
  notificationTypeInventory
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

registerStoryRoutes(app, {
  requireAuth,
  sqlGet,
  sqlGetAsync,
  sqlAllAsync,
  sqlRun,
  sqlRunAsync,
  buildVersionedCacheKey,
  cacheNamespaces,
  getCacheJson,
  setCacheJson,
  storyRailCacheTtlSeconds: STORY_RAIL_CACHE_TTL_SECONDS,
  getImageVariantsBatch,
  uploadsDir,
  uploadRateLimit,
  storyUpload,
  validateUploadedImageFile,
  allowedImageSafetyMimes,
  getMediaUploadLimitBytes,
  cleanupUploadedFile,
  enforceUploadQuota,
  formatUserText,
  storyDir,
  processUpload,
  deleteImageRecord,
  writeAppLog,
  scheduleEngagementRecalculation,
  invalidateCacheNamespace
});



const {
  NETWORK_SUGGESTION_APPLY_CONFIRMATION_TOKEN,
  normalizeMentorshipStatus,
  normalizeConnectionStatus,
  normalizeTeacherAlumniRelationshipType,
  normalizeTeacherLinkCreatedVia,
  normalizeTeacherLinkSourceSurface,
  normalizeTeacherLinkReviewStatus,
  normalizeNetworkingTelemetryEventName,
  normalizeTeacherLinkReviewNote,
  normalizeBooleanFlag,
  parseTeacherNetworkClassYear,
  calculateCooldownRemainingSeconds,
  apiSuccessEnvelope,
  sendApiError,
  ensureConnectionRequestsTable,
  ensureMentorshipRequestsTable,
  ensureTeacherAlumniLinksTable,
  ensureTeacherAlumniLinkModerationEventsTable,
  ensureNetworkingTelemetryEventsTable,
  ensureMemberNetworkingDailySummaryTable,
  ensureNetworkingSummaryMetaTable,
  ensureNetworkSuggestionAbTables,
  toSummaryDateKey,
  refreshMemberNetworkingDailySummaryIfStale,
  buildNetworkingAnalyticsAlerts,
  resolveNetworkSuggestionVariant,
  parseJsonValue,
  snapshotNetworkSuggestionConfigs,
  listNetworkSuggestionAbRecentChanges,
  listNetworkSuggestionAbRecentChangesWithEvaluation,
  buildNetworkSuggestionExperimentAnalytics,
  buildNetworkSuggestionAbRecommendations,
  getNetworkSuggestionExperimentDataset,
  recordNetworkingTelemetryEvent,
  isTeacherLinkActiveStatus,
  canTransitionTeacherLinkReviewStatus,
  selectTeacherLinkMergeTarget,
  logTeacherLinkModerationEvent,
  buildTeacherLinkModerationAssessment,
  refreshTeacherLinkConfidenceScore,
  listTeacherLinkPairDuplicates,
  parseNetworkWindowDays,
  toIsoThreshold,
  buildOpportunityInboxPayload,
  buildNetworkInboxPayload,
  buildNetworkMetricsPayload,
  buildExploreSuggestionsPayload,
  buildNetworkHubPayload
} = createNetworkingRuntime({
  sqlGet,
  sqlAll,
  sqlRun,
  sqlGetAsync,
  sqlAllAsync,
  sqlRunAsync,
  hasColumn,
  hasTable,
  normalizeCohortValue,
  roleAtLeast,
  TEACHER_NETWORK_MIN_CLASS_YEAR,
  TEACHER_NETWORK_MAX_CLASS_YEAR,
  TEACHER_COHORT_VALUE,
  getNetworkSuggestionAbConfigs,
  getAssignedNetworkSuggestionVariant,
  getSafeAssignedNetworkSuggestionVariant,
  readExploreSuggestionsCache,
  writeExploreSuggestionsCache,
  networkSuggestionDefaultParams,
  networkSuggestionDefaultVariants,
  normalizeNetworkSuggestionParams,
  buildScoredNetworkSuggestion,
  createPeerMap,
  getPeerOverlapCount,
  mapNetworkSuggestionForApi,
  sortNetworkSuggestions
});

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

registerNetworkRequestRoutes(app, {
  requireAuth,
  connectionRequestRateLimit,
  mentorshipRequestRateLimit,
  ensureVerifiedSocialHubMember,
  ensureConnectionRequestsTable,
  ensureMentorshipRequestsTable,
  sqlGet,
  sqlGetAsync,
  sqlRun,
  sqlRunAsync,
  sqlAllAsync,
  sendApiError,
  calculateCooldownRemainingSeconds,
  connectionRequestCooldownSeconds: CONNECTION_REQUEST_COOLDOWN_SECONDS,
  mentorshipRequestCooldownSeconds: MENTORSHIP_REQUEST_COOLDOWN_SECONDS,
  addNotification,
  recordNetworkingTelemetryEvent,
  apiSuccessEnvelope,
  normalizeConnectionStatus,
  normalizeMentorshipStatus,
  clearExploreSuggestionsCache: () => exploreSuggestionsResponseCache.clear(),
  scheduleEngagementRecalculation,
  invalidateFeedCache: () => invalidateCacheNamespace(cacheNamespaces.feed),
  buildNetworkInboxPayload
});

registerNetworkDiscoveryRoutes(app, {
  requireAuth,
  requireAdmin,
  sqlRunAsync,
  sqlGetAsync,
  sqlAllAsync,
  apiSuccessEnvelope,
  sendApiError,
  normalizeNetworkingTelemetryEventName,
  recordNetworkingTelemetryEvent,
  ensureConnectionRequestsTable,
  ensureMentorshipRequestsTable,
  ensureTeacherAlumniLinksTable,
  ensureNetworkingTelemetryEventsTable,
  ensureMemberNetworkingDailySummaryTable,
  ensureNetworkSuggestionAbTables,
  parseNetworkWindowDays,
  toIsoThreshold,
  toSummaryDateKey,
  normalizeCohortValue,
  refreshMemberNetworkingDailySummaryIfStale,
  getNetworkSuggestionExperimentDataset,
  buildNetworkingAnalyticsAlerts,
  getNetworkSuggestionAbConfigs,
  listNetworkSuggestionAbRecentChangesWithEvaluation,
  buildNetworkSuggestionExperimentAnalytics,
  buildNetworkSuggestionAbRecommendations,
  buildOpportunityInboxPayload,
  buildNetworkHubPayload,
  buildNetworkMetricsPayload,
  buildExploreSuggestionsPayload
});

registerTeacherNetworkRoutes(app, {
  requireAuth,
  requireAdmin,
  sqlGet,
  sqlGetAsync,
  sqlAllAsync,
  sqlRun,
  sqlRunAsync,
  addNotification,
  recordNetworkingTelemetryEvent,
  apiSuccessEnvelope,
  sendApiError,
  ensureTeacherAlumniLinksTable,
  ensureVerifiedSocialHubMember,
  normalizeTeacherAlumniRelationshipType,
  parseTeacherNetworkClassYear,
  TEACHER_NETWORK_MIN_CLASS_YEAR,
  TEACHER_NETWORK_MAX_CLASS_YEAR,
  normalizeCohortValue,
  TEACHER_COHORT_VALUE,
  roleAtLeast,
  normalizeTeacherLinkCreatedVia,
  normalizeTeacherLinkSourceSurface,
  normalizeBooleanFlag,
  listTeacherLinkPairDuplicates,
  refreshTeacherLinkConfidenceScore,
  clearExploreSuggestionsCache: () => exploreSuggestionsResponseCache.clear(),
  scheduleEngagementRecalculation,
  invalidateFeedCache: () => invalidateCacheNamespace(cacheNamespaces.feed)
});

registerGroupRoutes(app, {
  requireAuth,
  sqlGetAsync,
  sqlAllAsync,
  sqlRunAsync,
  sqlGet,
  sqlAll,
  sqlRun,
  listOnlineMembersAsync,
  writeAppLog,
  getCurrentUser,
  hasAdminRole,
  hasAdminSession,
  normalizeGroupVisibility,
  sanitizePlainUserText,
  formatUserText,
  isFormattedContentEmpty,
  notifyMentions,
  getGroupMember,
  isGroupManager,
  addNotification,
  sameUserId,
  parseGroupVisibilityInput,
  uploadRateLimit,
  groupUpload,
  postUpload,
  processDiskImageUpload,
  uploadImagePresets
});

registerEventJobRoutes(app, {
  requireAuth,
  requireAdmin,
  uploadRateLimit,
  postUpload,
  getCurrentUser,
  hasAdminSession,
  sameUserId,
  dbDriver,
  sqlAll,
  sqlGet,
  sqlRun,
  sqlGetAsync,
  sqlRunAsync,
  sqlAllAsync,
  addNotification,
  sanitizePlainUserText,
  formatUserText,
  isFormattedContentEmpty,
  toDbFlagForColumn,
  processDiskImageUpload,
  uploadImagePresets,
  writeAppLog,
  createEventRecord,
  normalizeEventResponse,
  getEventResponseBundle,
  notifyMentions,
  ensureJobApplicationsTable,
  ensureVerifiedSocialHubMember,
  apiSuccessEnvelope,
  sendApiError
});

registerAdminRequestModerationRoutes(app, {
  requireAdmin,
  requireModerationPermission,
  sqlGet,
  sqlAll,
  sqlRun,
  sqlGetAsync,
  sqlAllAsync,
  sqlRunAsync,
  getCurrentUser,
  getModerationScopeContext,
  parseAdminListPagination,
  applyModerationScopeFilter,
  hasValidGraduationYear,
  addNotification,
  logAdminAction,
  ensureTeacherAlumniLinksTable: (...args) => ensureTeacherAlumniLinksTable(...args),
  ensureTeacherAlumniLinkModerationEventsTable: (...args) => ensureTeacherAlumniLinkModerationEventsTable(...args),
  normalizeTeacherAlumniRelationshipType,
  normalizeTeacherLinkReviewStatus,
  normalizeTeacherLinkReviewNote,
  canTransitionTeacherLinkReviewStatus,
  selectTeacherLinkMergeTarget,
  refreshTeacherLinkConfidenceScore,
  logTeacherLinkModerationEvent,
  buildTeacherLinkModerationAssessment,
  ensureCanModerateTargetUser,
  assignUserToCohort
});

registerAdminExperimentRoutes(app, {
  requireAdmin,
  sqlGet,
  sqlAll,
  sqlRun,
  sqlGetAsync,
  sqlAllAsync,
  sqlRunAsync,
  handleEngagementAbOverview,
  handleEngagementAbUpdate,
  handleEngagementAbRebalance,
  handleAdminDashboardSummary,
  handleAdminDashboardActivity,
  parseNetworkWindowDays,
  toIsoThreshold,
  normalizeCohortValue,
  getNetworkSuggestionExperimentDataset,
  getNetworkSuggestionAbConfigs,
  buildNetworkSuggestionExperimentAnalytics,
  listNetworkSuggestionAbRecentChanges,
  listNetworkSuggestionAbRecentChangesWithEvaluation,
  buildNetworkSuggestionAbRecommendations,
  NETWORK_SUGGESTION_APPLY_CONFIRMATION_TOKEN,
  resolveNetworkSuggestionVariant,
  parseJsonValue,
  snapshotNetworkSuggestionConfigs,
  ensureNetworkSuggestionAbTables,
  networkSuggestionDefaultParams,
  networkSuggestionDefaultVariants,
  normalizeNetworkSuggestionParams,
  toDbBooleanParam,
  logAdminAction,
  recalculateMemberEngagementScores
});

registerAdminContentModerationRoutes(app, {
  requireAdmin,
  requireModerationPermission,
  sqlGet,
  sqlAll,
  sqlRun,
  sqlGetAsync,
  sqlAllAsync,
  sqlRunAsync,
  getCurrentUser,
  getModerationScopeContext,
  parseAdminListPagination,
  applyModerationScopeFilter,
  addNotification,
  logAdminAction,
  assignUserToCohort,
  ensureCanModerateTargetUser,
  deletePostById,
  scheduleEngagementRecalculation,
  broadcastChatDelete,
  normalizeBannedWord,
  invalidateBannedWordsCache
});

app.get('/api/new/chat/messages', requireAuth, phase1Domain.controllers.chat.listMessages);

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

registerAdminDbRoutes(app, {
  dbDriver,
  dbPath,
  requireAdmin,
  dbBackupUpload,
  validateUploadedFileSafety,
  cleanupUploadedFile,
  logAdminAction,
  writeAppLog,
  runtime: dbAdminRuntime
});

registerMiscAppRoutes(app, {
  appRootDir: __dirname,
  sqlGet,
  sqlAll,
  sqlRun,
  sqlGetAsync,
  sqlAllAsync,
  sqlRunAsync,
  requireAdmin,
  hasAdminSession,
  formatUserText,
  normalizeRole,
  isRowOnlineNow,
  mapLegacyUrl
});

app.use((err, req, res, next) => {
  if (err && (err.type === 'entity.parse.failed' || err.type === 'entity.too.large' || err.code === 'LIMIT_FILE_SIZE' || err.code === 'LIMIT_UNEXPECTED_FILE')) {
    return res.status(400).send(err.message || 'Hata');
  }
  return next(err);
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

const { attachWebSocketServers } = createWebSocketRuntime({
  sessionParser,
  normalizeUserId,
  allowLegacyWsQueryAuth,
  writeAppLog,
  sqlGet,
  sqlGetAsync,
  formatUserText,
  isFormattedContentEmpty,
  sqlRun,
  sqlRunAsync,
  scheduleEngagementRecalculation,
  broadcastChatMessage,
  setChatWss: (value) => { chatWss = value; },
  setMessengerWss: (value) => { messengerWss = value; }
});

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

export { app, port, onServerStarted, setupProcessHandlers, attachWebSocketServers };
export default app;
