import fs from 'fs';
import path from 'path';
import Database from 'better-sqlite3';

const dbPath = process.env.SDAL_DB_PATH || path.resolve('../db/sdal.sqlite');
let db = null;

export function getDb() {
  if (db) return db;
  if (!fs.existsSync(dbPath)) {
    throw new Error(`SQLite database not found at ${dbPath}`);
  }
  db = new Database(dbPath, { readonly: false });
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

export { dbPath };
