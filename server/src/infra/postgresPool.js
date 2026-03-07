import { Pool } from 'pg';

let pgPool = null;
let poolInitError = null;

function parsePoolNumber(name, fallback) {
  const value = Number(process.env[name]);
  return Number.isFinite(value) && value > 0 ? Math.floor(value) : fallback;
}

function resolveSslConfig() {
  const sslMode = String(process.env.PGSSLMODE || '').trim().toLowerCase();
  if (!sslMode) return undefined;
  if (['disable', 'allow', 'prefer'].includes(sslMode)) return undefined;
  if (['require', 'verify-ca', 'verify-full'].includes(sslMode)) {
    const rejectUnauthorized = sslMode !== 'require';
    return { rejectUnauthorized };
  }
  return undefined;
}

export function isPostgresConfigured() {
  return Boolean(String(process.env.DATABASE_URL || '').trim());
}

export function getPostgresPool() {
  if (pgPool) return pgPool;
  const connectionString = String(process.env.DATABASE_URL || '').trim();
  if (!connectionString) return null;

  try {
    pgPool = new Pool({
      connectionString,
      max: parsePoolNumber('PGPOOL_MAX', 8),
      min: parsePoolNumber('PGPOOL_MIN', 1),
      idleTimeoutMillis: parsePoolNumber('PGPOOL_IDLE_MS', 15_000),
      connectionTimeoutMillis: parsePoolNumber('PGPOOL_CONNECT_TIMEOUT_MS', 5_000),
      statement_timeout: parsePoolNumber('PG_STATEMENT_TIMEOUT_MS', 10_000),
      query_timeout: parsePoolNumber('PG_QUERY_TIMEOUT_MS', 12_000),
      allowExitOnIdle: false,
      ssl: resolveSslConfig()
    });

    pgPool.on('error', (err) => {
      poolInitError = err;
      console.error('[pg] pool error:', err?.message || err);
    });
  } catch (err) {
    poolInitError = err;
    throw err;
  }

  return pgPool;
}

export async function pgQuery(text, params = []) {
  const pool = getPostgresPool();
  if (!pool) {
    throw new Error('PostgreSQL is not configured. Set DATABASE_URL to enable pg pool.');
  }
  return pool.query(text, params);
}

export async function withPgTransaction(run) {
  const pool = getPostgresPool();
  if (!pool) {
    throw new Error('PostgreSQL is not configured. Set DATABASE_URL to enable transactions.');
  }
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const result = await run(client);
    await client.query('COMMIT');
    return result;
  } catch (err) {
    try {
      await client.query('ROLLBACK');
    } catch {
      // best effort
    }
    throw err;
  } finally {
    client.release();
  }
}

export async function checkPostgresHealth() {
  const startedAt = Date.now();
  if (!isPostgresConfigured()) {
    return {
      configured: false,
      ready: false,
      latencyMs: 0,
      detail: 'DATABASE_URL is not set'
    };
  }

  try {
    const pool = getPostgresPool();
    if (!pool) {
      return {
        configured: true,
        ready: false,
        latencyMs: Date.now() - startedAt,
        detail: 'pool initialization failed'
      };
    }
    await pool.query('SELECT 1 AS ok');
    return {
      configured: true,
      ready: true,
      latencyMs: Date.now() - startedAt,
      detail: 'ok'
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

export async function closePostgresPool() {
  if (!pgPool) return;
  try {
    await pgPool.end();
  } catch {
    // no-op
  } finally {
    pgPool = null;
  }
}

export function getPostgresPoolState() {
  const pool = pgPool;
  return {
    configured: isPostgresConfigured(),
    initialized: Boolean(pool),
    totalCount: pool?.totalCount ?? 0,
    idleCount: pool?.idleCount ?? 0,
    waitingCount: pool?.waitingCount ?? 0,
    lastError: poolInitError ? String(poolInitError.message || poolInitError) : null
  };
}
