import session from 'express-session';
import { RedisStore } from 'connect-redis';
import { ensureRedisConnection, getRedisClient, isRedisConfigured } from '../src/infra/redisClient.js';

function parseBoolean(value, fallback) {
  const normalized = String(value ?? '').trim().toLowerCase();
  if (!normalized) return fallback;
  if (['1', 'true', 'yes', 'on'].includes(normalized)) return true;
  if (['0', 'false', 'no', 'off'].includes(normalized)) return false;
  return fallback;
}

export function sessionMiddleware({ isProd }) {
  const forceSecureCookie = parseBoolean(process.env.SDAL_SESSION_COOKIE_SECURE, isProd);
  const sessionStoreMode = String(process.env.SDAL_SESSION_STORE || 'auto').trim().toLowerCase();
  const options = {
    secret: process.env.SDAL_SESSION_SECRET || 'sdal-dev-secret',
    resave: false,
    saveUninitialized: false,
    rolling: true,
    cookie: {
      maxAge: 1000 * 60 * 60 * 2,
      httpOnly: true,
      sameSite: 'lax',
      secure: forceSecureCookie
    }
  };

  const shouldUseRedisStore = sessionStoreMode === 'redis' || (sessionStoreMode !== 'memory' && isRedisConfigured());
  if (shouldUseRedisStore) {
    const redisClient = getRedisClient();
    if (redisClient) {
      ensureRedisConnection().catch((err) => {
        console.error('[session] redis connect failed, session store may be unavailable:', err?.message || err);
      });
      options.store = new RedisStore({
        client: redisClient,
        prefix: String(process.env.REDIS_SESSION_PREFIX || 'sdal:sess:')
      });
    }
  }

  return session(options);
}
