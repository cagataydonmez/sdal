import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import Database from 'better-sqlite3';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const projectDir = path.resolve(__dirname, '..');
const bundledDefaultDbPath = path.resolve(projectDir, 'db/sdal.sqlite');
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
  if (hasWritableDir('/app/data')) return '/app/data/sdal.sqlite';
  if (hasWritableDir('/data')) return '/data/sdal.sqlite';
  return legacyDefaultDbPath;
}

const dbPath = resolveDbPath();
let db = null;

function fileHasTable(filePath, tableName) {
  if (!filePath || !tableName || !fs.existsSync(filePath)) return false;
  let tmp = null;
  try {
    tmp = new Database(filePath, { readonly: true, fileMustExist: true });
    const row = tmp.prepare(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?"
    ).get(tableName);
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

export function getDb() {
  if (db) return db;
  const dir = path.dirname(dbPath);
  fs.mkdirSync(dir, { recursive: true });

  const requireExisting = String(process.env.SDAL_DB_REQUIRE_EXISTING || '').toLowerCase() === 'true';
  const bootstrap = String(process.env.SDAL_DB_BOOTSTRAP_PATH || '').trim();
  const bootstrapPath = (() => {
    if (bootstrap) return toAbsolutePath(bootstrap);
    if (fs.existsSync(bundledDefaultDbPath)) return bundledDefaultDbPath;
    if (fs.existsSync(legacyDefaultDbPath)) return legacyDefaultDbPath;
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
