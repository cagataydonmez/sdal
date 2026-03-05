import { ensureRedisConnection, getRedisClient, isRedisConfigured } from './redisClient.js';

const memoryCache = new Map();
const memoryNamespaceVersions = new Map();

function toPositiveInt(value, fallback) {
  const parsed = Number.parseInt(String(value ?? ''), 10);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : fallback;
}

function getNowMs() {
  return Date.now();
}

function memoryGet(key) {
  const entry = memoryCache.get(key);
  if (!entry) return null;
  if (entry.expiresAtMs <= getNowMs()) {
    memoryCache.delete(key);
    return null;
  }
  return entry.value;
}

function memorySet(key, value, ttlSeconds) {
  memoryCache.set(key, {
    value,
    expiresAtMs: getNowMs() + (toPositiveInt(ttlSeconds, 30) * 1000)
  });
}

function memoryDel(key) {
  memoryCache.delete(key);
}

function getMemoryNamespaceVersion(namespace) {
  const key = String(namespace || 'default').trim() || 'default';
  if (!memoryNamespaceVersions.has(key)) {
    memoryNamespaceVersions.set(key, 1);
  }
  return Number(memoryNamespaceVersions.get(key) || 1);
}

function bumpMemoryNamespaceVersion(namespace) {
  const key = String(namespace || 'default').trim() || 'default';
  const next = getMemoryNamespaceVersion(key) + 1;
  memoryNamespaceVersions.set(key, next);
  return next;
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

function cacheValueKey(rawKey) {
  return `sdal:cache:value:${String(rawKey || '')}`;
}

function cacheNamespaceKey(namespace) {
  return `sdal:cache:nsver:${String(namespace || 'default').trim() || 'default'}`;
}

export async function getCacheJson(rawKey) {
  const key = String(rawKey || '').trim();
  if (!key) return null;

  const redis = await getReadyRedisClient();
  if (redis) {
    try {
      const text = await redis.get(cacheValueKey(key));
      if (!text) return null;
      return JSON.parse(text);
    } catch {
      // fallback to memory cache
    }
  }

  return memoryGet(key);
}

export async function setCacheJson(rawKey, value, ttlSeconds = 30) {
  const key = String(rawKey || '').trim();
  if (!key) return;

  const safeTtl = toPositiveInt(ttlSeconds, 30);
  const redis = await getReadyRedisClient();
  if (redis) {
    try {
      await redis.set(cacheValueKey(key), JSON.stringify(value), { EX: safeTtl });
      return;
    } catch {
      // fallback to memory cache
    }
  }

  memorySet(key, value, safeTtl);
}

export async function deleteCacheKey(rawKey) {
  const key = String(rawKey || '').trim();
  if (!key) return;

  const redis = await getReadyRedisClient();
  if (redis) {
    try {
      await redis.del(cacheValueKey(key));
    } catch {
      // best effort
    }
  }

  memoryDel(key);
}

export async function getCacheNamespaceVersion(namespace) {
  const ns = String(namespace || 'default').trim() || 'default';
  const redis = await getReadyRedisClient();
  if (redis) {
    try {
      const key = cacheNamespaceKey(ns);
      const current = await redis.get(key);
      if (!current) {
        await redis.set(key, '1');
        return 1;
      }
      return Math.max(Number.parseInt(String(current), 10) || 1, 1);
    } catch {
      // fallback to memory namespace version
    }
  }

  return getMemoryNamespaceVersion(ns);
}

export async function bumpCacheNamespaceVersion(namespace) {
  const ns = String(namespace || 'default').trim() || 'default';
  const redis = await getReadyRedisClient();
  if (redis) {
    try {
      const next = await redis.incr(cacheNamespaceKey(ns));
      return Math.max(Number(next) || 1, 1);
    } catch {
      // fallback to memory namespace version
    }
  }

  return bumpMemoryNamespaceVersion(ns);
}

export async function buildVersionedCacheKey(namespace, parts = []) {
  const version = await getCacheNamespaceVersion(namespace);
  const suffix = (Array.isArray(parts) ? parts : [parts])
    .map((part) => String(part ?? '').trim())
    .join(':');
  return `${String(namespace || 'default')}:v${version}:${suffix}`;
}

setInterval(() => {
  const now = getNowMs();
  for (const [key, entry] of memoryCache.entries()) {
    if (!entry || entry.expiresAtMs <= now) {
      memoryCache.delete(key);
    }
  }
}, 30 * 1000);
