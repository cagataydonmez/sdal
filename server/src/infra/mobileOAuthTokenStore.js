import crypto from 'crypto';
import { ensureRedisConnection, getRedisClient, isRedisConfigured } from './redisClient.js';

const memoryStore = new Map();
const DEFAULT_TTL_SECONDS = 5 * 60;
const TOKEN_NAMESPACE = 'sdal:oauth:mobile';

function base64Url(input) {
  return Buffer.from(input)
    .toString('base64')
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=+$/g, '');
}

function randomToken(size = 36) {
  return base64Url(crypto.randomBytes(size));
}

function nowMs() {
  return Date.now();
}

function toPositiveInt(value, fallback) {
  const parsed = Number.parseInt(String(value ?? ''), 10);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : fallback;
}

function buildTokenKey(token) {
  return `${TOKEN_NAMESPACE}:${String(token || '').trim()}`;
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

export async function issueMobileOAuthToken(userId, { ttlSeconds = DEFAULT_TTL_SECONDS } = {}) {
  const safeUserId = Number(userId || 0);
  if (!safeUserId) return '';

  const safeTtl = toPositiveInt(ttlSeconds, DEFAULT_TTL_SECONDS);
  const token = randomToken(36);
  const storeKey = buildTokenKey(token);
  const record = {
    userId: safeUserId,
    issuedAt: new Date().toISOString()
  };

  const redis = await getReadyRedisClient();
  if (redis) {
    await redis.set(storeKey, JSON.stringify(record), { EX: safeTtl });
    return token;
  }

  cleanupMemoryStore();
  memoryStore.set(storeKey, {
    expiresAt: nowMs() + safeTtl * 1000,
    value: record
  });
  return token;
}

export async function consumeMobileOAuthToken(token) {
  const key = String(token || '').trim();
  if (!key) return null;
  const storeKey = buildTokenKey(key);

  const redis = await getReadyRedisClient();
  if (redis) {
    let raw = null;
    if (typeof redis.getDel === 'function') {
      raw = await redis.getDel(storeKey);
    } else {
      raw = await redis.get(storeKey);
      if (raw) await redis.del(storeKey);
    }
    const record = parseStoredRecord(raw);
    const safeUserId = Number(record?.userId || 0);
    return safeUserId > 0 ? safeUserId : null;
  }

  cleanupMemoryStore();
  const entry = memoryStore.get(storeKey);
  if (!entry) return null;
  memoryStore.delete(storeKey);
  if (Number(entry.expiresAt || 0) <= nowMs()) return null;
  const safeUserId = Number(entry.value?.userId || 0);
  return safeUserId > 0 ? safeUserId : null;
}

const cleanupTimer = setInterval(cleanupMemoryStore, 30 * 1000);
cleanupTimer.unref?.();
