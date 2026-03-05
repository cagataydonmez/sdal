import 'dotenv/config';
import { sqlAll, sqlRun, closeDbConnection } from './db.js';
import { isProd } from './config/env.js';
import { createMailSender } from './src/infra/mailSender.js';
import { createJobQueue } from './src/infra/jobQueue.js';
import { closeRedisClient } from './src/infra/redisClient.js';

const queue = createJobQueue({
  namespace: String(process.env.JOB_QUEUE_NAMESPACE || 'sdal:jobs:main')
});

const mailSender = createMailSender({ isProd, logger: console });

function normalizeUserId(value) {
  if (value === null || value === undefined) return null;
  const raw = String(value).trim();
  const n = Number(raw);
  if (Number.isFinite(n)) return Math.trunc(n);
  const leadingInt = raw.match(/^-?\d+/);
  if (leadingInt) return parseInt(leadingInt[0], 10);
  const cleaned = raw.replace(/\.0+$/, '');
  return cleaned || null;
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
  for (const user of users) {
    if (!user?.kadi) continue;
    if (!handles.has(String(user.kadi).toLowerCase())) continue;
    if (excludeUserId && String(normalizeUserId(user.id)) === String(normalizeUserId(excludeUserId))) continue;
    ids.push(Number(user.id));
  }
  return Array.from(new Set(ids));
}

function addNotification({ userId, type, sourceUserId, entityId, message }) {
  if (!userId) return;
  sqlRun(
    'INSERT INTO notifications (user_id, type, source_user_id, entity_id, message, created_at) VALUES (?, ?, ?, ?, ?, ?)',
    [userId, type, sourceUserId || null, entityId || null, message || '', new Date().toISOString()]
  );
}

const handlers = {
  'notification.mentions': async (payload) => {
    const ids = findMentionUserIds(payload?.text || '', payload?.sourceUserId || null);
    const allowed = Array.isArray(payload?.allowedUserIds)
      ? new Set(payload.allowedUserIds.map((v) => String(normalizeUserId(v))))
      : null;

    for (const userId of ids) {
      if (allowed && !allowed.has(String(normalizeUserId(userId)))) continue;
      addNotification({
        userId,
        type: payload?.type || 'mention',
        sourceUserId: payload?.sourceUserId || null,
        entityId: payload?.entityId || null,
        message: payload?.message || 'Senden bahsetti.'
      });
    }
  },

  'mail.send': async (payload) => {
    await mailSender.sendMailWithTimeout({
      to: payload?.to,
      subject: payload?.subject,
      html: payload?.html,
      from: payload?.from
    }, Number(payload?.timeoutMs || 8000));
  }
};

let shuttingDown = false;

async function shutdown(signal) {
  if (shuttingDown) return;
  shuttingDown = true;
  console.log(`[worker] shutting down (${signal || 'unknown'})`);
  try {
    await queue.stopWorker();
  } catch {
    // no-op
  }
  try {
    await closeRedisClient();
  } catch {
    // no-op
  }
  try {
    closeDbConnection();
  } catch {
    // no-op
  }
}

process.on('SIGINT', () => {
  shutdown('SIGINT').finally(() => process.exit(0));
});

process.on('SIGTERM', () => {
  shutdown('SIGTERM').finally(() => process.exit(0));
});

process.on('unhandledRejection', (reason) => {
  const msg = reason instanceof Error ? reason.message : String(reason || 'unknown');
  console.error('[worker] unhandled rejection:', msg);
});

process.on('uncaughtException', (err) => {
  console.error('[worker] uncaught exception:', err?.message || err);
});

console.log('[worker] starting queue worker');
await queue.startWorker({ handlers });
