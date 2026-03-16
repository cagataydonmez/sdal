/**
 * db-sync.mjs — Bidirectional PostgreSQL ↔ SQLite data copy tool
 *
 * Automatically discovers matching tables and columns between the two
 * databases and upserts data with no warnings about schema differences.
 * Only the intersection of tables/columns is used; everything else is
 * silently ignored.
 *
 * Usage:
 *   node scripts/db-sync.mjs --direction sqlite-to-pg   [options]
 *   node scripts/db-sync.mjs --direction pg-to-sqlite   [options]
 *
 * Options:
 *   --direction <sqlite-to-pg|pg-to-sqlite>  (required)
 *   --sqlite <path>          SQLite file path (auto-detected from env if omitted)
 *   --tables <t1,t2,...>     Sync only these tables (comma-separated)
 *   --skip <t1,t2,...>       Additional tables to skip beyond schema_migrations
 *   --replace                Truncate destination tables before inserting
 *                            (default: upsert — existing rows are updated)
 *   --dry-run                Show row counts without writing anything
 *   --batch <n>              Rows per INSERT batch (default: 200)
 *
 * Environment:
 *   DATABASE_URL             PostgreSQL connection string (required)
 *   SDAL_DB_PATH             Explicit SQLite path
 *   SDAL_DB_DIR              Directory containing sdal.sqlite
 */

import path from 'path';
import fs from 'fs';
import { fileURLToPath } from 'url';
import Database from 'better-sqlite3';
import pkg from 'pg';

const { Client } = pkg;
const __dirname = path.dirname(fileURLToPath(import.meta.url));

// ─── argument parsing ─────────────────────────────────────────────────────────

function parseArgs(argv) {
  const args = {
    direction: '',
    sqlitePath: '',
    tables: null,
    skip: [],
    replace: false,   // default: upsert
    dryRun: false,
    batch: 200,
  };
  for (let i = 0; i < argv.length; i++) {
    const a = String(argv[i] || '');
    if (a === '--direction') { args.direction = String(argv[++i] || '').trim(); continue; }
    if (a === '--sqlite')    { args.sqlitePath = String(argv[++i] || '').trim(); continue; }
    if (a === '--tables')    { args.tables = String(argv[++i] || '').split(',').map(s => s.trim()).filter(Boolean); continue; }
    if (a === '--skip')      { args.skip = String(argv[++i] || '').split(',').map(s => s.trim()).filter(Boolean); continue; }
    if (a === '--replace')   { args.replace = true; continue; }
    if (a === '--dry-run')   { args.dryRun = true; continue; }
    if (a === '--batch')     { args.batch = Math.max(1, parseInt(argv[++i], 10) || 200); continue; }
  }
  return args;
}

// ─── helpers ──────────────────────────────────────────────────────────────────

function qident(name) {
  return `"${String(name).replace(/"/g, '""')}"`;
}

function resolveSqlitePath(explicit) {
  if (explicit) return path.resolve(explicit);
  const candidates = [
    process.env.SDAL_DB_PATH,
    process.env.SDAL_DB_DIR ? path.join(process.env.SDAL_DB_DIR, 'sdal.sqlite') : null,
    '/app/data/sdal.sqlite',
    '/data/sdal.sqlite',
    path.resolve(__dirname, '../../db/sdal.sqlite'),
  ];
  for (const c of candidates) {
    if (c && fs.existsSync(c)) return c;
  }
  return path.resolve(__dirname, '../../db/sdal.sqlite');
}

// ─── schema discovery ─────────────────────────────────────────────────────────

function getSqliteTables(sqlite) {
  return sqlite
    .prepare("SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' ORDER BY name")
    .all()
    .map(r => r.name);
}

async function getPgTables(client) {
  const { rows } = await client.query(
    "SELECT table_name FROM information_schema.tables WHERE table_schema='public' AND table_type='BASE TABLE' ORDER BY table_name"
  );
  return rows.map(r => r.table_name);
}

// Returns Map<tableName, colInfo[]> for all tables in one query
async function getPgColumnsAll(client) {
  const { rows } = await client.query(
    `SELECT table_name, column_name, data_type
     FROM information_schema.columns
     WHERE table_schema='public'
     ORDER BY table_name, ordinal_position`
  );
  const map = new Map();
  for (const r of rows) {
    if (!map.has(r.table_name)) map.set(r.table_name, []);
    map.get(r.table_name).push({ name: r.column_name, type: r.data_type });
  }
  return map;
}

// Returns Map<tableName, pkColName[]> for all tables in one query
async function getPgPrimaryKeysAll(client) {
  const { rows } = await client.query(
    `SELECT tc.table_name, kcu.column_name
     FROM information_schema.table_constraints tc
     JOIN information_schema.key_column_usage kcu
       ON tc.constraint_name = kcu.constraint_name
       AND tc.table_schema = kcu.table_schema
       AND tc.table_name = kcu.table_name
     WHERE tc.constraint_type = 'PRIMARY KEY'
       AND tc.table_schema = 'public'
     ORDER BY tc.table_name, kcu.ordinal_position`
  );
  const map = new Map();
  for (const r of rows) {
    if (!map.has(r.table_name)) map.set(r.table_name, []);
    map.get(r.table_name).push(r.column_name);
  }
  return map;
}

function getSqliteColumnsAndPks(sqlite, table) {
  const rows = sqlite.prepare(`PRAGMA table_info(${qident(table)})`).all();
  const cols = rows.map(r => ({ name: r.name, type: String(r.type || '').toUpperCase() }));
  const pks = rows.filter(r => Number(r.pk) > 0).map(r => r.name);
  return { cols, pks };
}

// ─── FK topological sort ──────────────────────────────────────────────────────

async function getPgFkEdges(client) {
  const { rows } = await client.query(`
    SELECT tc.table_name AS child, ccu.table_name AS parent
    FROM information_schema.table_constraints tc
    JOIN information_schema.referential_constraints rc
      ON tc.constraint_name = rc.constraint_name
      AND tc.constraint_schema = rc.constraint_schema
    JOIN information_schema.constraint_column_usage ccu
      ON rc.unique_constraint_name = ccu.constraint_name
      AND rc.unique_constraint_schema = ccu.constraint_schema
    WHERE tc.constraint_type = 'FOREIGN KEY'
      AND tc.constraint_schema = 'public'
  `);
  return rows;
}

function topoSort(tables, fkEdges) {
  const set = new Set(tables);
  const deps = new Map(tables.map(t => [t, new Set()]));
  for (const { child, parent } of fkEdges) {
    if (set.has(child) && set.has(parent) && child !== parent) deps.get(child).add(parent);
  }
  const childrenOf = new Map(tables.map(t => [t, []]));
  for (const [child, parents] of deps) {
    for (const p of parents) childrenOf.get(p).push(child);
  }
  const inDegree = new Map(tables.map(t => [t, deps.get(t).size]));
  const queue = tables.filter(t => inDegree.get(t) === 0);
  const result = [];
  while (queue.length) {
    const t = queue.shift();
    result.push(t);
    for (const c of childrenOf.get(t)) {
      const d = inDegree.get(c) - 1;
      inDegree.set(c, d);
      if (d === 0) queue.push(c);
    }
  }
  for (const t of tables) if (!result.includes(t)) result.push(t);
  return result;
}

// ─── value converters ─────────────────────────────────────────────────────────

function pgValueToSqlite(val, pgType) {
  if (val === null || val === undefined) return null;
  const t = String(pgType || '').toLowerCase();
  if (t === 'boolean') return val ? 1 : 0;
  if (val instanceof Date) return val.toISOString();
  if (t === 'json' || t === 'jsonb') return typeof val === 'string' ? val : JSON.stringify(val);
  if (Array.isArray(val)) return JSON.stringify(val);
  if (typeof val === 'object') return JSON.stringify(val);
  return val;
}

function sqliteValueToPg(val, pgType) {
  if (val === null || val === undefined) return null;
  const t = String(pgType || '').toLowerCase();
  if (t === 'boolean') {
    if (typeof val === 'number') return val !== 0;
    if (typeof val === 'string') return val === '1' || val.toLowerCase() === 'true';
    return Boolean(val);
  }
  if (t === 'json' || t === 'jsonb') {
    if (typeof val === 'string') { try { return JSON.parse(val); } catch { return val; } }
    return val;
  }
  return val;
}

// ─── upsert SQL builders ──────────────────────────────────────────────────────

// Builds: INSERT INTO t (cols) VALUES (...) ON CONFLICT (pks) DO UPDATE SET non_pk=EXCLUDED.non_pk
// Falls back to ON CONFLICT DO NOTHING if no PK is known
function buildPgUpsertSql(table, cols, pkCols) {
  const colSql = cols.map(qident).join(', ');
  const pkSet = new Set(pkCols);
  const updateCols = cols.filter(c => !pkSet.has(c));

  if (!pkCols.length) {
    return (values) =>
      `INSERT INTO ${qident(table)} (${colSql}) VALUES ${values} ON CONFLICT DO NOTHING`;
  }

  const conflictCols = pkCols.map(qident).join(', ');

  if (!updateCols.length) {
    // All columns are part of the PK — just skip duplicates
    return (values) =>
      `INSERT INTO ${qident(table)} (${colSql}) VALUES ${values} ON CONFLICT (${conflictCols}) DO NOTHING`;
  }

  const updateSql = updateCols.map(c => `${qident(c)} = EXCLUDED.${qident(c)}`).join(', ');
  return (values) =>
    `INSERT INTO ${qident(table)} (${colSql}) VALUES ${values} ON CONFLICT (${conflictCols}) DO UPDATE SET ${updateSql}`;
}

// ─── copy: SQLite → PostgreSQL ────────────────────────────────────────────────

async function copySqliteToPg(sqlite, client, table, sharedCols, pgColMap, pgPks, batchSize, replace, dryRun) {
  const rows = sqlite
    .prepare(`SELECT ${sharedCols.map(qident).join(', ')} FROM ${qident(table)}`)
    .all();

  if (dryRun) return rows.length;

  if (replace) {
    await client.query(`TRUNCATE TABLE ${qident(table)} RESTART IDENTITY CASCADE`);
  }

  if (!rows.length) return 0;

  const buildSql = replace
    ? (values) => `INSERT INTO ${qident(table)} (${sharedCols.map(qident).join(', ')}) VALUES ${values}`
    : buildPgUpsertSql(table, sharedCols, pgPks.filter(pk => sharedCols.includes(pk)));

  let copied = 0;
  for (let start = 0; start < rows.length; start += batchSize) {
    const batch = rows.slice(start, start + batchSize);
    const values = [];
    const placeholderGroups = [];
    for (const row of batch) {
      const offset = values.length;
      const rowVals = sharedCols.map(c => sqliteValueToPg(row[c], pgColMap.get(c)?.type || ''));
      placeholderGroups.push(`(${rowVals.map((_, i) => `$${offset + i + 1}`).join(', ')})`);
      values.push(...rowVals);
    }
    await client.query(buildSql(placeholderGroups.join(', ')), values);
    copied += batch.length;
  }
  return copied;
}

// ─── copy: PostgreSQL → SQLite ────────────────────────────────────────────────

async function copyPgToSqlite(sqlite, client, table, sharedCols, pgColMap, batchSize, replace, dryRun) {
  const { rows } = await client.query(
    `SELECT ${sharedCols.map(qident).join(', ')} FROM ${qident(table)}`
  );

  if (dryRun) return rows.length;

  if (replace) {
    sqlite.prepare(`DELETE FROM ${qident(table)}`).run();
  }

  if (!rows.length) return 0;

  const colSql = sharedCols.map(qident).join(', ');
  const ph = sharedCols.map(() => '?').join(', ');
  // INSERT OR REPLACE handles PK-based upsert for SQLite
  const insertSql = replace
    ? `INSERT INTO ${qident(table)} (${colSql}) VALUES (${ph})`
    : `INSERT OR REPLACE INTO ${qident(table)} (${colSql}) VALUES (${ph})`;
  const stmt = sqlite.prepare(insertSql);

  let copied = 0;
  const insertBatch = sqlite.transaction(batch => {
    for (const row of batch) {
      stmt.run(sharedCols.map(c => pgValueToSqlite(row[c], pgColMap.get(c)?.type || '')));
      copied++;
    }
  });

  for (let start = 0; start < rows.length; start += batchSize) {
    insertBatch(rows.slice(start, start + batchSize));
  }
  return copied;
}

// ─── sequence reset after SQLite→PG copy ─────────────────────────────────────

async function resetPgSequences(client, tables) {
  for (const table of tables) {
    try {
      const { rows } = await client.query(
        `SELECT column_name FROM information_schema.columns
         WHERE table_schema='public' AND table_name=$1
           AND (column_default LIKE 'nextval%' OR identity_generation IS NOT NULL)`,
        [table]
      );
      for (const { column_name } of rows) {
        await client.query(
          `SELECT setval(pg_get_serial_sequence($1,$2),
             COALESCE((SELECT MAX(${qident(column_name)}) FROM ${qident(table)}), 0)+1, false)`,
          [table, column_name]
        );
      }
    } catch { /* non-fatal */ }
  }
}

// ─── main ─────────────────────────────────────────────────────────────────────

const args = parseArgs(process.argv.slice(2));

if (!args.direction || !['sqlite-to-pg', 'pg-to-sqlite'].includes(args.direction)) {
  console.error('Usage: node scripts/db-sync.mjs --direction <sqlite-to-pg|pg-to-sqlite> [options]');
  console.error('  --sqlite <path>      SQLite file (auto-detected if omitted)');
  console.error('  --tables <t1,t2,...> Only these tables');
  console.error('  --skip <t1,t2,...>   Skip these tables');
  console.error('  --replace            Truncate before insert instead of upsert');
  console.error('  --dry-run            Preview row counts without writing');
  console.error('  --batch <n>          Insert batch size (default: 200)');
  process.exit(1);
}

const databaseUrl = String(process.env.DATABASE_URL || '').trim();
if (!databaseUrl) {
  console.error('[db-sync] DATABASE_URL is required');
  process.exit(1);
}

const sqlitePath = resolveSqlitePath(args.sqlitePath);

// schema_migrations tracks per-DB state — always exclude
const SKIP = new Set(['schema_migrations', ...args.skip]);

let sqlite;
try {
  sqlite = new Database(sqlitePath, {
    readonly: args.direction === 'sqlite-to-pg',
    fileMustExist: true,
  });
  sqlite.pragma('journal_mode = WAL');
} catch (err) {
  console.error(`[db-sync] Cannot open SQLite at ${sqlitePath}: ${err.message}`);
  process.exit(1);
}

const client = new Client({ connectionString: databaseUrl });
try {
  await client.connect();
} catch (err) {
  console.error(`[db-sync] Cannot connect to PostgreSQL: ${err.message}`);
  sqlite.close();
  process.exit(1);
}

try {
  // Fetch all schema metadata in parallel
  const [sqliteTables, pgTables, pgColsAll, pgPksAll, fkEdges] = await Promise.all([
    Promise.resolve(getSqliteTables(sqlite)),
    getPgTables(client),
    getPgColumnsAll(client),
    getPgPrimaryKeysAll(client),
    getPgFkEdges(client),
  ]);

  const sqliteSet = new Set(sqliteTables);
  const pgSet = new Set(pgTables);

  // Only sync tables present in both databases
  let toSync = sqliteTables.filter(t => pgSet.has(t) && !SKIP.has(t));

  if (args.tables) {
    const requested = new Set(args.tables);
    toSync = toSync.filter(t => requested.has(t));
  }

  if (!toSync.length) {
    console.log('[db-sync] No matching tables found.');
    process.exit(0);
  }

  const sorted = topoSort(toSync, fkEdges);
  const mode = args.replace ? 'replace' : 'upsert';
  const label = args.dryRun ? 'dry-run' : mode;

  console.log(`[db-sync] ${args.direction}  •  ${sorted.length} tables  •  ${label}  •  batch=${args.batch}`);
  console.log('');

  if (args.direction === 'pg-to-sqlite') {
    sqlite.pragma('foreign_keys = OFF');
  }

  const errors = [];
  let totalRows = 0;

  for (const table of sorted) {
    const pgCols = pgColsAll.get(table) || [];
    const { cols: sqliteCols } = getSqliteColumnsAndPks(sqlite, table);

    const sqliteColSet = new Set(sqliteCols.map(c => c.name));
    const pgColMap = new Map(pgCols.map(c => [c.name, c]));

    // Intersection of columns present in both databases
    const sharedCols = pgCols.filter(c => sqliteColSet.has(c.name)).map(c => c.name);

    if (!sharedCols.length) continue; // nothing to sync for this table

    const pgPks = pgPksAll.get(table) || [];

    try {
      let rowCount;
      if (args.direction === 'sqlite-to-pg') {
        rowCount = await copySqliteToPg(sqlite, client, table, sharedCols, pgColMap, pgPks, args.batch, args.replace, args.dryRun);
      } else {
        rowCount = await copyPgToSqlite(sqlite, client, table, sharedCols, pgColMap, args.batch, args.replace, args.dryRun);
      }
      totalRows += rowCount;
      console.log(`  ${table.padEnd(42)} ${String(rowCount).padStart(7)} rows`);
    } catch (err) {
      errors.push({ table, error: err.message });
      console.error(`  ${table.padEnd(42)} ERROR: ${err.message}`);
    }
  }

  if (args.direction === 'pg-to-sqlite') {
    sqlite.pragma('foreign_keys = ON');
  }

  if (args.direction === 'sqlite-to-pg' && !args.dryRun) {
    await resetPgSequences(client, sorted);
  }

  console.log('');
  console.log(`[db-sync] done — ${sorted.length} tables, ${totalRows} rows${args.dryRun ? ' (dry run)' : ''}`);

  if (errors.length) process.exitCode = 1;

} finally {
  try { sqlite.close(); } catch {}
  try { await client.end(); } catch {}
}
