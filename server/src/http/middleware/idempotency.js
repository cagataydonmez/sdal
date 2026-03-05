import crypto from 'crypto';
import { ensureRedisConnection, getRedisClient, isRedisConfigured } from '../../infra/redisClient.js';

const memoryStore = new Map();

function toPositiveInt(value, fallback) {
  const parsed = Number.parseInt(String(value ?? ''), 10);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : fallback;
}

function nowMs() {
  return Date.now();
}

function stableHash(input) {
  return crypto.createHash('sha256').update(String(input || '')).digest('hex');
}

function cleanupMemoryStore() {
  const now = nowMs();
  for (const [key, entry] of memoryStore.entries()) {
    if (!entry || Number(entry.expiresAt || 0) <= now) {
      memoryStore.delete(key);
    }
  }
}

async function getReadyRedisClient() {
  if (!isRedisConfigured()) return null;
  const client = getRedisClient();
  if (!client) return null;
  try {
    await ensureRedisConnection();
  } catch {
    return null;
  }
  return client.isReady ? client : null;
}

function parseStoredRecord(raw) {
  if (!raw) return null;
  try {
    return JSON.parse(String(raw));
  } catch {
    return null;
  }
}

async function loadRecord(storeKey) {
  const redis = await getReadyRedisClient();
  if (redis) {
    const raw = await redis.get(storeKey);
    return parseStoredRecord(raw);
  }

  cleanupMemoryStore();
  const entry = memoryStore.get(storeKey);
  if (!entry) return null;
  return entry.value;
}

async function saveProcessing(storeKey, pendingTtlSeconds) {
  const redis = await getReadyRedisClient();
  const value = {
    state: 'processing',
    at: new Date().toISOString()
  };

  if (redis) {
    const result = await redis.set(storeKey, JSON.stringify(value), {
      NX: true,
      EX: pendingTtlSeconds
    });
    return result === 'OK';
  }

  cleanupMemoryStore();
  if (memoryStore.has(storeKey)) return false;
  memoryStore.set(storeKey, {
    expiresAt: nowMs() + pendingTtlSeconds * 1000,
    value
  });
  return true;
}

async function saveCompleted(storeKey, record, responseTtlSeconds) {
  const redis = await getReadyRedisClient();
  if (redis) {
    await redis.set(storeKey, JSON.stringify(record), {
      EX: responseTtlSeconds
    });
    return;
  }

  memoryStore.set(storeKey, {
    expiresAt: nowMs() + responseTtlSeconds * 1000,
    value: record
  });
}

async function clearRecord(storeKey) {
  const redis = await getReadyRedisClient();
  if (redis) {
    await redis.del(storeKey);
    return;
  }
  memoryStore.delete(storeKey);
}

function replayStoredResponse(res, record) {
  res.setHeader('X-Idempotent-Replay', '1');
  const statusCode = Number(record?.statusCode || 200);
  if (record?.bodyType === 'json') {
    return res.status(statusCode).json(record.body ?? null);
  }
  if (record?.bodyType === 'text') {
    return res.status(statusCode).send(String(record.body ?? ''));
  }
  return res.sendStatus(statusCode);
}

function defaultKeyExtractor(req) {
  const header = req.get('idempotency-key') || req.get('x-idempotency-key');
  if (header) return String(header).trim();
  const bodyKey = req.body?.idempotencyKey || req.body?.idempotency_key;
  return bodyKey ? String(bodyKey).trim() : '';
}

export function createIdempotencyMiddleware({
  namespace = 'default',
  pendingTtlSeconds = 30,
  responseTtlSeconds = 180,
  keyExtractor = defaultKeyExtractor,
  scopeResolver,
  onPending
} = {}) {
  const safePendingTtl = toPositiveInt(pendingTtlSeconds, 30);
  const safeResponseTtl = toPositiveInt(responseTtlSeconds, 180);

  return async function idempotencyMiddleware(req, res, next) {
    const idempotencyKey = String(keyExtractor(req) || '').trim();
    if (!idempotencyKey) return next();

    const scope = typeof scopeResolver === 'function'
      ? String(scopeResolver(req) || 'anonymous')
      : String(req.session?.userId || req.ip || 'anonymous');

    const keyBase = `${namespace}:${req.method}:${req.path}:${scope}:${idempotencyKey}`;
    const storeKey = `sdal:idem:${stableHash(keyBase)}`;

    try {
      const existing = await loadRecord(storeKey);
      if (existing?.state === 'completed') {
        return replayStoredResponse(res, existing);
      }
      if (existing?.state === 'processing') {
        if (typeof onPending === 'function') {
          return onPending(req, res);
        }
        return res.status(409).send('Bu istek zaten işleniyor.');
      }

      const acquired = await saveProcessing(storeKey, safePendingTtl);
      if (!acquired) {
        const raced = await loadRecord(storeKey);
        if (raced?.state === 'completed') return replayStoredResponse(res, raced);
        return res.status(409).send('Bu istek zaten işleniyor.');
      }

      let bodyType = null;
      let bodyValue = undefined;

      const originalJson = res.json.bind(res);
      const originalSend = res.send.bind(res);

      res.json = (payload) => {
        bodyType = 'json';
        bodyValue = payload;
        return originalJson(payload);
      };

      res.send = (payload) => {
        if (!bodyType) {
          if (typeof payload === 'string') {
            bodyType = 'text';
            bodyValue = payload;
          } else if (payload !== undefined) {
            bodyType = 'json';
            bodyValue = payload;
          }
        }
        return originalSend(payload);
      };

      res.on('finish', () => {
        if (res.statusCode >= 500) {
          clearRecord(storeKey).catch(() => {});
          return;
        }

        const completed = {
          state: 'completed',
          statusCode: res.statusCode,
          bodyType,
          body: bodyValue,
          completedAt: new Date().toISOString()
        };

        saveCompleted(storeKey, completed, safeResponseTtl).catch(() => {});
      });

      return next();
    } catch {
      return next();
    }
  };
}

setInterval(cleanupMemoryStore, 30 * 1000);
