import { ensureRedisConnection, getRedisClient, isRedisConfigured } from './redisClient.js';

const memoryBuckets = new Map();

function nowSeconds() {
  return Math.floor(Date.now() / 1000);
}

function toPositiveInt(value, fallback) {
  const parsed = Number.parseInt(String(value ?? ''), 10);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : fallback;
}

function clampNonNegativeInt(value) {
  const parsed = Number.parseInt(String(value ?? ''), 10);
  if (!Number.isFinite(parsed)) return 0;
  return Math.max(parsed, 0);
}

function cleanupMemoryBuckets() {
  const now = nowSeconds();
  for (const [key, entry] of memoryBuckets.entries()) {
    if (!entry || Number(entry.expiresAt || 0) <= now) {
      memoryBuckets.delete(key);
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

async function consumeWithRedis({ bucket, scope, bytes, maxFiles, maxBytes, windowSeconds }) {
  const client = await getReadyRedisClient();
  if (!client) return null;

  const safeBucket = String(bucket || 'uploads');
  const safeScope = String(scope || 'anon');
  const safeBytes = clampNonNegativeInt(bytes);
  const safeWindowSeconds = toPositiveInt(windowSeconds, 86_400);
  const windowKey = Math.floor(nowSeconds() / safeWindowSeconds);
  const filesKey = `sdal:quota:${safeBucket}:${safeScope}:${windowKey}:files`;
  const bytesKey = `sdal:quota:${safeBucket}:${safeScope}:${windowKey}:bytes`;

  const filesUsed = Number(await client.incr(filesKey));
  if (filesUsed === 1) await client.expire(filesKey, safeWindowSeconds + 1);

  const bytesUsed = Number(await client.incrBy(bytesKey, safeBytes));
  if (safeBytes > 0 && bytesUsed === safeBytes) await client.expire(bytesKey, safeWindowSeconds + 1);

  const filesExceeded = maxFiles > 0 && filesUsed > maxFiles;
  const bytesExceeded = maxBytes > 0 && bytesUsed > maxBytes;

  if (filesExceeded || bytesExceeded) {
    await client.decr(filesKey);
    if (safeBytes > 0) await client.decrBy(bytesKey, safeBytes);
    const retryAfterSeconds = Math.max(Number(await client.ttl(filesKey)) || 1, 1);
    return {
      allowed: false,
      backend: 'redis',
      filesUsed: Math.max(filesUsed - 1, 0),
      bytesUsed: Math.max(bytesUsed - safeBytes, 0),
      remainingFiles: maxFiles > 0 ? Math.max(maxFiles - (filesUsed - 1), 0) : null,
      remainingBytes: maxBytes > 0 ? Math.max(maxBytes - (bytesUsed - safeBytes), 0) : null,
      retryAfterSeconds
    };
  }

  const retryAfterSeconds = Math.max(Number(await client.ttl(filesKey)) || safeWindowSeconds, 1);
  return {
    allowed: true,
    backend: 'redis',
    filesUsed,
    bytesUsed,
    remainingFiles: maxFiles > 0 ? Math.max(maxFiles - filesUsed, 0) : null,
    remainingBytes: maxBytes > 0 ? Math.max(maxBytes - bytesUsed, 0) : null,
    retryAfterSeconds
  };
}

function consumeWithMemory({ bucket, scope, bytes, maxFiles, maxBytes, windowSeconds }) {
  cleanupMemoryBuckets();

  const safeBucket = String(bucket || 'uploads');
  const safeScope = String(scope || 'anon');
  const safeBytes = clampNonNegativeInt(bytes);
  const safeWindowSeconds = toPositiveInt(windowSeconds, 86_400);
  const windowKey = Math.floor(nowSeconds() / safeWindowSeconds);
  const key = `${safeBucket}:${safeScope}:${windowKey}`;

  let entry = memoryBuckets.get(key);
  if (!entry) {
    entry = {
      files: 0,
      bytes: 0,
      expiresAt: (windowKey + 1) * safeWindowSeconds
    };
    memoryBuckets.set(key, entry);
  }

  entry.files += 1;
  entry.bytes += safeBytes;

  const filesExceeded = maxFiles > 0 && entry.files > maxFiles;
  const bytesExceeded = maxBytes > 0 && entry.bytes > maxBytes;

  if (filesExceeded || bytesExceeded) {
    entry.files -= 1;
    entry.bytes -= safeBytes;
    return {
      allowed: false,
      backend: 'memory',
      filesUsed: entry.files,
      bytesUsed: entry.bytes,
      remainingFiles: maxFiles > 0 ? Math.max(maxFiles - entry.files, 0) : null,
      remainingBytes: maxBytes > 0 ? Math.max(maxBytes - entry.bytes, 0) : null,
      retryAfterSeconds: Math.max(entry.expiresAt - nowSeconds(), 1)
    };
  }

  return {
    allowed: true,
    backend: 'memory',
    filesUsed: entry.files,
    bytesUsed: entry.bytes,
    remainingFiles: maxFiles > 0 ? Math.max(maxFiles - entry.files, 0) : null,
    remainingBytes: maxBytes > 0 ? Math.max(maxBytes - entry.bytes, 0) : null,
    retryAfterSeconds: Math.max(entry.expiresAt - nowSeconds(), 1)
  };
}

export async function consumeUploadQuota({
  bucket = 'uploads',
  scope,
  bytes = 0,
  maxFiles = 0,
  maxBytes = 0,
  windowSeconds = 86_400
}) {
  const safeScope = String(scope || '').trim();
  if (!safeScope) {
    return {
      allowed: true,
      backend: 'none',
      filesUsed: 0,
      bytesUsed: 0,
      remainingFiles: null,
      remainingBytes: null,
      retryAfterSeconds: 0
    };
  }

  const safeMaxFiles = clampNonNegativeInt(maxFiles);
  const safeMaxBytes = clampNonNegativeInt(maxBytes);
  if (safeMaxFiles === 0 && safeMaxBytes === 0) {
    return {
      allowed: true,
      backend: 'disabled',
      filesUsed: 0,
      bytesUsed: 0,
      remainingFiles: null,
      remainingBytes: null,
      retryAfterSeconds: 0
    };
  }

  const redisVerdict = await consumeWithRedis({
    bucket,
    scope: safeScope,
    bytes,
    maxFiles: safeMaxFiles,
    maxBytes: safeMaxBytes,
    windowSeconds
  });

  if (redisVerdict) {
    return {
      ...redisVerdict,
      limitFiles: safeMaxFiles || null,
      limitBytes: safeMaxBytes || null,
      windowSeconds: toPositiveInt(windowSeconds, 86_400)
    };
  }

  const memoryVerdict = consumeWithMemory({
    bucket,
    scope: safeScope,
    bytes,
    maxFiles: safeMaxFiles,
    maxBytes: safeMaxBytes,
    windowSeconds
  });

  return {
    ...memoryVerdict,
    limitFiles: safeMaxFiles || null,
    limitBytes: safeMaxBytes || null,
    windowSeconds: toPositiveInt(windowSeconds, 86_400)
  };
}

setInterval(cleanupMemoryBuckets, 60 * 1000);
