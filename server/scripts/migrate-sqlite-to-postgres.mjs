import path from 'path';
import Database from 'better-sqlite3';
import pkg from 'pg';

const { Client } = pkg;

const sqlitePath = process.env.SQLITE_PATH
  ? path.resolve(process.env.SQLITE_PATH)
  : path.resolve(process.cwd(), '../db/sdal.sqlite');
const databaseUrl = String(process.env.DATABASE_URL || '').trim();

if (!databaseUrl) {
  console.error('DATABASE_URL is required');
  process.exit(1);
}

const sqlite = new Database(sqlitePath, { readonly: true, fileMustExist: true });
const client = new Client({ connectionString: databaseUrl });

function mapSqliteType(type) {
  const t = String(type || '').toUpperCase();
  if (t.includes('INT')) return 'BIGINT';
  if (t.includes('REAL') || t.includes('FLOA') || t.includes('DOUB') || t.includes('NUM')) return 'DOUBLE PRECISION';
  if (t.includes('BLOB')) return 'BYTEA';
  return 'TEXT';
}

function qident(name) {
  return `"${String(name).replace(/"/g, '""')}"`;
}

function placeholders(count, offset = 0) {
  return Array.from({ length: count }, (_, i) => `$${i + 1 + offset}`).join(', ');
}

async function ensureTable(table) {
  const cols = sqlite.prepare(`PRAGMA table_info(${qident(table)})`).all();
  if (!cols.length) return null;
  const parts = cols.map((c) => {
    const isPk = Number(c.pk || 0) > 0;
    const base = `${qident(c.name)} ${mapSqliteType(c.type)}`;
    if (isPk && String(c.type || '').toUpperCase().includes('INT')) {
      return `${qident(c.name)} BIGINT PRIMARY KEY`;
    }
    if (isPk) return `${base} PRIMARY KEY`;
    if (Number(c.notnull || 0) > 0) return `${base} NOT NULL`;
    return base;
  });
  const ddl = `CREATE TABLE IF NOT EXISTS ${qident(table)} (${parts.join(', ')})`;
  await client.query(ddl);
  return cols.map((c) => c.name);
}

async function copyTable(table, columns) {
  if (!columns?.length) return;
  const sel = sqlite.prepare(`SELECT ${columns.map(qident).join(', ')} FROM ${qident(table)}`);
  const rows = sel.all();
  if (!rows.length) return;

  await client.query(`TRUNCATE TABLE ${qident(table)} RESTART IDENTITY CASCADE`);

  const colSql = columns.map(qident).join(', ');
  const valueRows = [];
  const values = [];
  for (const row of rows) {
    const rowValues = columns.map((c) => row[c]);
    valueRows.push(`(${placeholders(rowValues.length, values.length)})`);
    values.push(...rowValues);
    if (valueRows.length >= 300) {
      const sql = `INSERT INTO ${qident(table)} (${colSql}) VALUES ${valueRows.join(', ')}`;
      await client.query(sql, values);
      valueRows.length = 0;
      values.length = 0;
    }
  }
  if (valueRows.length) {
    const sql = `INSERT INTO ${qident(table)} (${colSql}) VALUES ${valueRows.join(', ')}`;
    await client.query(sql, values);
  }
}

try {
  await client.connect();
  const tables = sqlite
    .prepare("SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%' ORDER BY name")
    .all()
    .map((r) => r.name)
    .filter(Boolean);

  for (const table of tables) {
    process.stdout.write(`[pg-migrate] ${table} ... `);
    const columns = await ensureTable(table);
    await copyTable(table, columns);
    process.stdout.write('ok\n');
  }
  console.log('[pg-migrate] completed');
} catch (err) {
  console.error('[pg-migrate] failed:', err?.message || err);
  process.exitCode = 1;
} finally {
  try { sqlite.close(); } catch {}
  try { await client.end(); } catch {}
}
