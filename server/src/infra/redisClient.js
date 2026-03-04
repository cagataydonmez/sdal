import { createClient } from 'redis';

let redisClient = null;
let redisConnectPromise = null;
let redisReady = false;
let redisLastError = null;
let redisLastReadyAt = null;

function parseRedisNumber(name, fallback) {
  const value = Number(process.env[name]);
  return Number.isFinite(value) && value > 0 ? Math.floor(value) : fallback;
}

function buildReconnectStrategy() {
  const maxRetryDelayMs = parseRedisNumber('REDIS_RETRY_MAX_DELAY_MS', 5_000);
  return (retries) => Math.min(retries * 100, maxRetryDelayMs);
}

export function isRedisConfigured() {
  return Boolean(String(process.env.REDIS_URL || '').trim());
}

export function getRedisClient() {
  if (redisClient) return redisClient;
  const redisUrl = String(process.env.REDIS_URL || '').trim();
  if (!redisUrl) return null;

  redisClient = createClient({
    url: redisUrl,
    socket: {
      connectTimeout: parseRedisNumber('REDIS_CONNECT_TIMEOUT_MS', 4_000),
      keepAlive: parseRedisNumber('REDIS_KEEPALIVE_MS', 5_000),
      reconnectStrategy: buildReconnectStrategy()
    },
    pingInterval: parseRedisNumber('REDIS_PING_INTERVAL_MS', 30_000)
  });

  redisClient.on('ready', () => {
    redisReady = true;
    redisLastError = null;
    redisLastReadyAt = new Date().toISOString();
  });

  redisClient.on('end', () => {
    redisReady = false;
  });

  redisClient.on('error', (err) => {
    redisReady = false;
    redisLastError = err;
    console.error('[redis] client error:', err?.message || err);
  });

  return redisClient;
}

export function ensureRedisConnection() {
  const client = getRedisClient();
  if (!client) return Promise.resolve(null);

  if (client.isOpen) {
    redisReady = client.isReady;
    return Promise.resolve(client);
  }

  if (!redisConnectPromise) {
    redisConnectPromise = client.connect()
      .then(() => {
        redisReady = client.isReady;
        return client;
      })
      .finally(() => {
        redisConnectPromise = null;
      });
  }

  return redisConnectPromise;
}

export async function checkRedisHealth() {
  const startedAt = Date.now();
  if (!isRedisConfigured()) {
    return {
      configured: false,
      ready: false,
      latencyMs: 0,
      detail: 'REDIS_URL is not set'
    };
  }

  try {
    const client = getRedisClient();
    if (!client) {
      return {
        configured: true,
        ready: false,
        latencyMs: Date.now() - startedAt,
        detail: 'client initialization failed'
      };
    }

    await ensureRedisConnection();
    const pong = await client.ping();
    return {
      configured: true,
      ready: String(pong || '').toUpperCase() === 'PONG',
      latencyMs: Date.now() - startedAt,
      detail: pong || 'no pong'
    };
  } catch (err) {
    return {
      configured: true,
      ready: false,
      latencyMs: Date.now() - startedAt,
      detail: err?.message || 'unknown error'
    };
  }
}

export function getRedisState() {
  const client = redisClient;
  return {
    configured: isRedisConfigured(),
    initialized: Boolean(client),
    open: Boolean(client?.isOpen),
    ready: redisReady && Boolean(client?.isReady),
    lastReadyAt: redisLastReadyAt,
    lastError: redisLastError ? String(redisLastError.message || redisLastError) : null
  };
}

export async function closeRedisClient() {
  if (!redisClient) return;
  try {
    if (redisClient.isOpen) {
      await redisClient.quit();
    }
  } catch {
    // no-op
  } finally {
    redisClient = null;
    redisConnectPromise = null;
    redisReady = false;
  }
}
