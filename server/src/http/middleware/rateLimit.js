import { ensureRedisConnection, getRedisClient, isRedisConfigured } from '../../infra/redisClient.js';

const memoryBuckets = new Map();

function toPositiveInt(value, fallback) {
  const parsed = Number.parseInt(String(value ?? ''), 10);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : fallback;
}

function nowSeconds() {
  return Math.floor(Date.now() / 1000);
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

async function checkRedisRateLimit({ key, limit, windowSeconds }) {
  const redis = await getReadyRedisClient();
  if (!redis) return null;

  const currentWindow = Math.floor(nowSeconds() / windowSeconds);
  const redisKey = `sdal:rl:${key}:${currentWindow}`;

  try {
    const hitCount = Number(await redis.incr(redisKey));
    if (hitCount === 1) {
      await redis.expire(redisKey, windowSeconds + 1);
    }
    const ttl = Math.max(Number(await redis.ttl(redisKey)) || 0, 1);
    return {
      allowed: hitCount <= limit,
      remaining: Math.max(limit - hitCount, 0),
      retryAfterSeconds: ttl,
      limit
    };
  } catch {
    return null;
  }
}

function checkMemoryRateLimit({ key, limit, windowSeconds }) {
  const bucketKey = String(key || 'unknown');
  const ts = nowSeconds();
  const windowStart = ts - (ts % windowSeconds);
  const fullKey = `${bucketKey}:${windowStart}`;

  let entry = memoryBuckets.get(fullKey);
  if (!entry) {
    entry = { count: 0, expiresAt: windowStart + windowSeconds + 1 };
    memoryBuckets.set(fullKey, entry);
  }

  entry.count += 1;

  return {
    allowed: entry.count <= limit,
    remaining: Math.max(limit - entry.count, 0),
    retryAfterSeconds: Math.max(entry.expiresAt - ts, 1),
    limit
  };
}

export async function evaluateRateLimit({ bucket, key, limit, windowSeconds }) {
  const safeLimit = toPositiveInt(limit, 10);
  const safeWindowSeconds = toPositiveInt(windowSeconds, 60);
  const mergedKey = `${String(bucket || 'default')}:${String(key || 'unknown')}`;

  const redisResult = await checkRedisRateLimit({
    key: mergedKey,
    limit: safeLimit,
    windowSeconds: safeWindowSeconds
  });

  if (redisResult) return redisResult;

  return checkMemoryRateLimit({
    key: mergedKey,
    limit: safeLimit,
    windowSeconds: safeWindowSeconds
  });
}

export function createRateLimitMiddleware({
  bucket,
  limit,
  windowSeconds,
  keyGenerator,
  onBlocked
}) {
  const safeBucket = String(bucket || 'default');
  const safeLimit = toPositiveInt(limit, 10);
  const safeWindowSeconds = toPositiveInt(windowSeconds, 60);

  return async function rateLimitMiddleware(req, res, next) {
    try {
      const key = typeof keyGenerator === 'function'
        ? keyGenerator(req)
        : (req?.ip || req?.session?.userId || 'unknown');

      const verdict = await evaluateRateLimit({
        bucket: safeBucket,
        key,
        limit: safeLimit,
        windowSeconds: safeWindowSeconds
      });

      res.setHeader('X-RateLimit-Limit', String(verdict.limit));
      res.setHeader('X-RateLimit-Remaining', String(verdict.remaining));

      if (verdict.allowed) return next();

      res.setHeader('Retry-After', String(verdict.retryAfterSeconds));
      if (typeof onBlocked === 'function') {
        return onBlocked(req, res, verdict);
      }
      return res.status(429).send('Çok fazla istek. Lütfen biraz bekleyip tekrar deneyin.');
    } catch {
      return next();
    }
  };
}

setInterval(() => {
  const ts = nowSeconds();
  for (const [key, entry] of memoryBuckets.entries()) {
    if (!entry || Number(entry.expiresAt || 0) <= ts) {
      memoryBuckets.delete(key);
    }
  }
}, 30 * 1000);
