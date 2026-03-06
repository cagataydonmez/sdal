import fs from 'fs';
import path from 'path';
import { execFileSync } from 'child_process';
import { fileURLToPath } from 'url';
import Database from 'better-sqlite3';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const projectDir = path.resolve(__dirname, '..');
const bundledDefaultDbPath = path.resolve(projectDir, 'db/sdal.sqlite');

const dbDriver = String(process.env.SDAL_DB_DRIVER || '').trim().toLowerCase() || (process.env.DATABASE_URL ? 'postgres' : 'sqlite');

function toAbsolutePath(p) {
  if (!p) return '';
  return path.isAbsolute(p) ? p : path.resolve(projectDir, p);
}

function hasWritableDir(dir) {
  try {
    if (!fs.existsSync(dir)) return false;
    fs.accessSync(dir, fs.constants.R_OK | fs.constants.W_OK);
    return true;
  } catch {
    return false;
  }
}

function resolveDbPath() {
  const explicit = String(process.env.SDAL_DB_PATH || '').trim();
  if (explicit) return toAbsolutePath(explicit);

  const dirFromEnv = String(process.env.SDAL_DB_DIR || '').trim();
  if (dirFromEnv) return path.join(toAbsolutePath(dirFromEnv), 'sdal.sqlite');

  if (hasWritableDir('/app/data')) return '/app/data/sdal.sqlite';
  if (hasWritableDir('/data')) return '/data/sdal.sqlite';
  return bundledDefaultDbPath;
}

const dbPath = resolveDbPath();
const postgresUrl = String(process.env.DATABASE_URL || '').trim();
let db = null;
let slowQueryThresholdMs = Math.max(parseInt(process.env.SDAL_SLOW_QUERY_MS || '200', 10) || 200, 0);

let slowQueryLogger = (entry) => {
  const compactSql = String(entry?.query || '').replace(/\s+/g, ' ').trim().slice(0, 280);
  const suffix = entry?.error ? ` error=${entry.error}` : '';
  console.warn(
    `[db][slow] driver=${entry.driver} op=${entry.operation} durationMs=${entry.durationMs} ` +
    `params=${entry.paramCount} sql="${compactSql}"${suffix}`
  );
};

function safeParamPreview(value) {
  if (value === null || value === undefined) return value;
  if (typeof value === 'number' || typeof value === 'boolean') return value;
  if (value instanceof Date) return value.toISOString();
  if (Buffer.isBuffer(value)) return `<buffer:${value.length}>`;
  const text = String(value);
  if (text.length > 100) return `${text.slice(0, 100)}…`;
  return text;
}

function logSlowQuery(operation, query, params, durationMs, error = null) {
  if (durationMs < slowQueryThresholdMs) return;
  try {
    slowQueryLogger({
      driver: dbDriver,
      operation,
      durationMs,
      query: String(query || ''),
      paramCount: Array.isArray(params) ? params.length : 0,
      paramPreview: Array.isArray(params) ? params.slice(0, 5).map((v) => safeParamPreview(v)) : [],
      error: error ? String(error.message || error) : null
    });
  } catch {
    // logging must never break query flow
  }
}

function withQueryTiming(operation, query, params, execute) {
  const startedAt = Date.now();
  let error = null;
  try {
    return execute();
  } catch (err) {
    error = err;
    throw err;
  } finally {
    logSlowQuery(operation, query, params, Date.now() - startedAt, error);
  }
}

function fileHasTable(filePath, tableName) {
  if (!filePath || !tableName || !fs.existsSync(filePath)) return false;
  let tmp = null;
  try {
    tmp = new Database(filePath, { readonly: true, fileMustExist: true });
    const row = tmp.prepare("SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?").get(tableName);
    return !!row;
  } catch {
    return false;
  } finally {
    try {
      if (tmp) tmp.close();
    } catch {
      // no-op
    }
  }
}

function initSqlite() {
  const dir = path.dirname(dbPath);
  fs.mkdirSync(dir, { recursive: true });

  const requireExisting = String(process.env.SDAL_DB_REQUIRE_EXISTING || '').toLowerCase() === 'true';
  const bootstrap = String(process.env.SDAL_DB_BOOTSTRAP_PATH || '').trim();
  const bootstrapPath = (() => {
    if (bootstrap) return toAbsolutePath(bootstrap);
    if (fs.existsSync(bundledDefaultDbPath)) return bundledDefaultDbPath;
    return '';
  })();
  const requiredTable = String(process.env.SDAL_DB_REQUIRED_TABLE || 'uyeler').trim();
  const autoRepairMissingSchema = String(process.env.SDAL_DB_AUTO_REPAIR_MISSING_SCHEMA || '').toLowerCase() !== 'false';

  if (!fs.existsSync(dbPath) && bootstrapPath && fs.existsSync(bootstrapPath)) {
    fs.copyFileSync(bootstrapPath, dbPath);
    console.log(`[db] bootstrapped sqlite from ${bootstrapPath} -> ${dbPath}`);
  }

  if (
    autoRepairMissingSchema
    && fs.existsSync(dbPath)
    && bootstrapPath
    && fs.existsSync(bootstrapPath)
    && requiredTable
    && !fileHasTable(dbPath, requiredTable)
    && fileHasTable(bootstrapPath, requiredTable)
  ) {
    const stamp = new Date().toISOString().replace(/[:.]/g, '-');
    const brokenBackupPath = `${dbPath}.broken-${stamp}.sqlite`;
    fs.copyFileSync(dbPath, brokenBackupPath);
    fs.copyFileSync(bootstrapPath, dbPath);
    console.warn(
      `[db] auto-repair applied: missing required table "${requiredTable}" in ${dbPath}. ` +
      `Previous file backed up to ${brokenBackupPath}, replaced from ${bootstrapPath}`
    );
  }

  if (!fs.existsSync(dbPath) && requireExisting) {
    throw new Error(`SQLite database not found at ${dbPath} (SDAL_DB_REQUIRE_EXISTING=true)`);
  }

  if (
    process.env.NODE_ENV === 'production'
    && !String(process.env.SDAL_DB_PATH || '').trim()
    && !dbPath.startsWith('/data/')
    && !dbPath.startsWith('/app/data/')
  ) {
    console.warn(
      `[db] WARNING: DB path is ${dbPath}. This may be ephemeral on deploy. ` +
      'Set SDAL_DB_PATH to a persistent volume path (e.g. /app/data/sdal.sqlite or /data/sdal.sqlite).'
    );
  }

  db = new Database(dbPath, { readonly: false });
  try { db.pragma('journal_mode = WAL'); } catch {}
  try { db.pragma('synchronous = NORMAL'); } catch {}
  try { db.pragma('busy_timeout = 5000'); } catch {}
}

function pgEscape(value) {
  if (value === null || value === undefined) return 'NULL';
  if (typeof value === 'number') return Number.isFinite(value) ? String(value) : 'NULL';
  if (typeof value === 'boolean') return value ? 'TRUE' : 'FALSE';
  if (value instanceof Date) return `'${value.toISOString().replace(/'/g, "''")}'`;
  if (Buffer.isBuffer(value)) return `'\\x${value.toString('hex')}'`;
  return `'${String(value).replace(/'/g, "''")}'`;
}

function injectParams(sql, params = []) {
  let idx = 0;
  return String(sql || '').replace(/\?/g, () => pgEscape(params[idx++]));
}

function normalizePgSql(sql) {
  return String(sql || '')
    .replace(/datetime\(\s*'now'\s*\)/gi, 'CURRENT_TIMESTAMP')
    .replace(/timestamp\(\s*'now'\s*\)/gi, 'CURRENT_TIMESTAMP')
    .replace(/\bdate\(\s*'now'\s*\)/gi, 'CURRENT_DATE')
    .replace(/\bAUTOINCREMENT\b/gi, '')
    .replace(/\bINTEGER\s+PRIMARY\s+KEY\b/gi, 'BIGSERIAL PRIMARY KEY')
    .replace(/\bDATETIME\b/gi, 'TIMESTAMP')
    .replace(/\bIFNULL\s*\(/gi, 'COALESCE(')
    .replace(/COALESCE\(\s*([a-zA-Z_][a-zA-Z0-9_.]*)\s*,\s*1\s*\)\s*=\s*0/gi, 'COALESCE($1, TRUE) = FALSE')
    .replace(/COALESCE\(\s*([a-zA-Z_][a-zA-Z0-9_.]*)\s*,\s*1\s*\)\s*=\s*1/gi, 'COALESCE($1, TRUE) = TRUE')
    .replace(/COALESCE\(\s*([a-zA-Z_][a-zA-Z0-9_.]*)\s*,\s*0\s*\)\s*=\s*0/gi, 'COALESCE($1, FALSE) = FALSE')
    .replace(/COALESCE\(\s*([a-zA-Z_][a-zA-Z0-9_.]*)\s*,\s*0\s*\)\s*=\s*1/gi, 'COALESCE($1, FALSE) = TRUE')
    .replace(
      /COALESCE\(\s*NULLIF\(\s*([a-zA-Z_][a-zA-Z0-9_.]*)\s*,\s*''\s*\)\s*,\s*CURRENT_TIMESTAMP\s*\)/gi,
      'COALESCE($1, CURRENT_TIMESTAMP)'
    )
    .replace(
      /LEFT\s+JOIN\s+uyeler\s+([a-zA-Z_][a-zA-Z0-9_]*)\s+ON\s+\1\.id\s*=\s*([a-zA-Z_][a-zA-Z0-9_.]*)/gi,
      'LEFT JOIN uyeler $1 ON $1.id::text = $2::text'
    );
}

function runPsqlQuery(sql) {
  if (!postgresUrl) throw new Error('DATABASE_URL is required for postgres driver');
  const trimmed = String(sql || '').trim().replace(/;\s*$/, '');
  const wrapped = (() => {
    if (/^(INSERT|UPDATE|DELETE)\b/i.test(trimmed)) {
      const dml = /\bRETURNING\b/i.test(trimmed) ? trimmed : `${trimmed} RETURNING *`;
      return `WITH t AS (${dml}) SELECT COALESCE(json_agg(row_to_json(t)), '[]'::json)::text FROM t;`;
    }
    return `SELECT COALESCE(json_agg(row_to_json(t)), '[]'::json)::text FROM (${trimmed}) t;`;
  })();
  const out = execFileSync('psql', ['-X', '-A', '-t', postgresUrl, '-c', wrapped], { encoding: 'utf8' }).trim();
  if (!out) return [];
  try {
    return JSON.parse(out);
  } catch {
    return [];
  }
}

function runPsqlExec(sql) {
  if (!postgresUrl) throw new Error('DATABASE_URL is required for postgres driver');
  const out = execFileSync('psql', ['-X', postgresUrl, '-c', sql], { encoding: 'utf8' });
  const lines = String(out || '').trim().split('\n').map((l) => l.trim()).filter(Boolean);
  const tag = lines[lines.length - 1] || '';
  let changes = 0;
  const m = tag.match(/^(INSERT|UPDATE|DELETE)\s+\d+\s+(\d+)$/i) || tag.match(/^(UPDATE|DELETE)\s+(\d+)$/i);
  if (m) changes = Number(m[m.length - 1]) || 0;
  return { changes };
}

function runPsqlInsertReturningId(sql) {
  if (!postgresUrl) throw new Error('DATABASE_URL is required for postgres driver');
  const wrapped = `
    WITH inserted AS (
      ${sql}
      RETURNING id
    )
    SELECT COALESCE(json_agg(row_to_json(inserted)), '[]'::json)::text
    FROM inserted
  `;
  const out = execFileSync('psql', ['-X', '-A', '-t', postgresUrl, '-c', wrapped], { encoding: 'utf8' }).trim();
  if (!out) return [];
  try {
    return JSON.parse(out);
  } catch {
    return [];
  }
}

function rewriteSqliteMetaForPg(sql) {
  const text = String(sql || '').trim();
  const pragma = text.match(/^PRAGMA\s+table_info\((.+)\)\s*;?$/i);
  if (pragma) {
    const rawTable = String(pragma[1] || '').trim().replace(/^["'`]|["'`]$/g, '');
    const table = rawTable.replace(/"/g, '');
    return `
      SELECT
        column_name AS name,
        CASE
          WHEN data_type IN ('integer', 'bigint', 'smallint') THEN 'INTEGER'
          WHEN data_type IN ('real', 'double precision', 'numeric') THEN 'REAL'
          ELSE 'TEXT'
        END AS type,
        CASE WHEN is_nullable = 'NO' THEN 1 ELSE 0 END AS notnull,
        column_default AS dflt_value,
        COALESCE((
          SELECT 1
          FROM information_schema.key_column_usage k
          JOIN information_schema.table_constraints t
            ON t.constraint_name = k.constraint_name
           AND t.table_schema = k.table_schema
          WHERE t.constraint_type = 'PRIMARY KEY'
            AND k.table_schema = 'public'
            AND k.table_name = c.table_name
            AND k.column_name = c.column_name
          LIMIT 1
        ), 0) AS pk
      FROM information_schema.columns c
      WHERE c.table_schema = 'public' AND c.table_name = '${table.replace(/'/g, "''")}'
      ORDER BY ordinal_position
    `;
  }

  if (text.includes('sqlite_master')) {
    const relationSource = `
      SELECT table_name AS name
      FROM information_schema.tables
      WHERE table_schema = 'public'
      UNION
      SELECT table_name AS name
      FROM information_schema.views
      WHERE table_schema = 'public'
    `;

    const withNameFilter = /\bname\s*=\s*(\?|"[^"]+"|'[^']+')/i.exec(text);
    const nameWhere = withNameFilter ? ` WHERE name = ${withNameFilter[1]}` : '';

    if (/COUNT\(\*\)\s+AS\s+cnt/i.test(text)) {
      return `
        SELECT COUNT(*)::int AS cnt
        FROM (${relationSource}) AS sqlite_master
        ${nameWhere}
      `;
    }
    if (/type\s*=\s*'table'/i.test(text)) {
      return `
        SELECT name
        FROM (${relationSource}) AS sqlite_master
        ${nameWhere}
      `;
    }
  }
  return text;
}

export function getDb() {
  if (dbDriver === 'postgres') {
    if (!postgresUrl) throw new Error('DATABASE_URL is required when SDAL_DB_DRIVER=postgres');
    return { driver: 'postgres', url: postgresUrl };
  }
  if (!db) initSqlite();
  return db;
}

export function safeGetDb() {
  try {
    return getDb();
  } catch {
    return null;
  }
}

export function sqlGet(query, params = []) {
  return withQueryTiming('sqlGet', query, params, () => {
    const conn = safeGetDb();
    if (!conn) return null;
    if (dbDriver !== 'postgres') return conn.prepare(query).get(params);
    const rewritten = rewriteSqliteMetaForPg(query);
    const sql = normalizePgSql(injectParams(rewritten, params));
    const rows = runPsqlQuery(sql);
    return rows[0] || null;
  });
}

export function sqlAll(query, params = []) {
  return withQueryTiming('sqlAll', query, params, () => {
    const conn = safeGetDb();
    if (!conn) return [];
    if (dbDriver !== 'postgres') return conn.prepare(query).all(params);
    const rewritten = rewriteSqliteMetaForPg(query);
    const sql = normalizePgSql(injectParams(rewritten, params));
    return runPsqlQuery(sql);
  });
}

export function sqlRun(query, params = []) {
  return withQueryTiming('sqlRun', query, params, () => {
    const conn = safeGetDb();
    if (!conn) return null;
    if (dbDriver !== 'postgres') return conn.prepare(query).run(params);

    const rewritten = rewriteSqliteMetaForPg(query);
    let sql = normalizePgSql(injectParams(rewritten, params));
    if (/^\s*INSERT\s+INTO/i.test(sql) && !/\bRETURNING\b/i.test(sql)) {
      try {
        const rows = runPsqlInsertReturningId(sql);
        return {
          changes: rows.length,
          lastInsertRowid: rows[0]?.id ?? null
        };
      } catch {
        // fallback below
      }
    }
    const result = runPsqlExec(sql);
    return {
      changes: Number(result?.changes || 0),
      lastInsertRowid: null
    };
  });
}

export function configureDbInstrumentation(options = {}) {
  const threshold = Number(options.slowQueryThresholdMs);
  if (Number.isFinite(threshold) && threshold >= 0) {
    slowQueryThresholdMs = Math.floor(threshold);
  }
  if (typeof options.onSlowQuery === 'function') {
    slowQueryLogger = options.onSlowQuery;
  }
}

export function closeDbConnection() {
  if (dbDriver === 'postgres') return;
  if (!db) return;
  try {
    db.close();
  } catch {
    // no-op
  } finally {
    db = null;
  }
}

export function resetDbConnection() {
  closeDbConnection();
  return getDb();
}

export { dbPath, dbDriver };
