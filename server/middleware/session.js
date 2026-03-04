import session from 'express-session';
import { RedisStore } from 'connect-redis';
import { ensureRedisConnection, getRedisClient, isRedisConfigured } from '../src/infra/redisClient.js';

export function sessionMiddleware({ isProd }) {
  const options = {
    secret: process.env.SDAL_SESSION_SECRET || 'sdal-dev-secret',
    resave: false,
    saveUninitialized: false,
    rolling: true,
    cookie: {
      maxAge: 1000 * 60 * 60 * 2,
      httpOnly: true,
      sameSite: 'lax',
      secure: isProd
    }
  };

  if (isRedisConfigured()) {
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
