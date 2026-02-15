import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import Database from 'better-sqlite3';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const projectDir = path.resolve(__dirname, '..');
const legacyDefaultDbPath = path.resolve(projectDir, '../db/sdal.sqlite');

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

  // Railway/containers: prefer mounted volume if present.
  if (hasWritableDir('/data')) return '/data/sdal.sqlite';
  return legacyDefaultDbPath;
}

const dbPath = resolveDbPath();
let db = null;

export function getDb() {
  if (db) return db;
  const dir = path.dirname(dbPath);
  fs.mkdirSync(dir, { recursive: true });

  const requireExisting = String(process.env.SDAL_DB_REQUIRE_EXISTING || '').toLowerCase() === 'true';
  const bootstrap = String(process.env.SDAL_DB_BOOTSTRAP_PATH || '').trim();
  const bootstrapPath = bootstrap ? toAbsolutePath(bootstrap) : '';

  if (!fs.existsSync(dbPath) && bootstrapPath && fs.existsSync(bootstrapPath)) {
    fs.copyFileSync(bootstrapPath, dbPath);
    console.log(`[db] bootstrapped sqlite from ${bootstrapPath} -> ${dbPath}`);
  }

  if (!fs.existsSync(dbPath) && requireExisting) {
    throw new Error(`SQLite database not found at ${dbPath} (SDAL_DB_REQUIRE_EXISTING=true)`);
  }

  if (
    process.env.NODE_ENV === 'production'
    && !String(process.env.SDAL_DB_PATH || '').trim()
    && !dbPath.startsWith('/data/')
  ) {
    console.warn(
      `[db] WARNING: DB path is ${dbPath}. This may be ephemeral on deploy. ` +
      'Set SDAL_DB_PATH to a persistent volume path (e.g. /data/sdal.sqlite).'
    );
  }

  db = new Database(dbPath, { readonly: false });
  try { db.pragma('journal_mode = WAL'); } catch {}
  try { db.pragma('synchronous = NORMAL'); } catch {}
  try { db.pragma('busy_timeout = 5000'); } catch {}
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
  const conn = safeGetDb();
  if (!conn) return null;
  return conn.prepare(query).get(params);
}

export function sqlAll(query, params = []) {
  const conn = safeGetDb();
  if (!conn) return [];
  return conn.prepare(query).all(params);
}

export function sqlRun(query, params = []) {
  const conn = safeGetDb();
  if (!conn) return null;
  return conn.prepare(query).run(params);
}

export function closeDbConnection() {
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

export { dbPath };
