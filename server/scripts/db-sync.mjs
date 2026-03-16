/**
 * db-sync.mjs — Bidirectional PostgreSQL ↔ SQLite data copy tool
 *
 * Copies table contents between a PostgreSQL database and a SQLite database.
 * Only tables that exist in BOTH databases are synced; tables missing from
 * either side are reported but never silently skipped without notice.
 *
 * Usage:
 *   node scripts/db-sync.mjs --direction sqlite-to-pg   [options]
 *   node scripts/db-sync.mjs --direction pg-to-sqlite   [options]
 *
 * Options:
 *   --direction <sqlite-to-pg|pg-to-sqlite>  (required)
 *   --sqlite <path>          SQLite file path (auto-detected from env if omitted)
 *   --tables <t1,t2,...>     Sync only these tables (comma-separated)
 *   --skip <t1,t2,...>       Additional tables to skip
 *   --no-truncate            Append rows instead of replacing table contents
 *   --dry-run                Show what would be synced without writing anything
 *   --batch <n>              Rows per INSERT batch (default: 200)
 *
 * Environment variables:
 *   DATABASE_URL             PostgreSQL connection string (required)
 *   SDAL_DB_PATH             Explicit SQLite path
 *   SDAL_DB_DIR              Directory containing sdal.sqlite
 *
 * Notes:
 *   - schema_migrations is always skipped (each DB tracks its own migration state)
 *   - Tables in only one DB are listed in the report but not touched
 *   - Columns present in only one DB are skipped per-table; warnings are shown
 *   - For sqlite-to-pg: PG sequences are reset after the copy
 *   - For pg-to-sqlite: SQLite FK checks are disabled during the copy
 *   - Boolean values are converted between PG true/false and SQLite 1/0
 *   - JSON/JSONB values are stringified for SQLite, parsed for PG
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
    truncate: true,
    dryRun: false,
    batch: 200,
  };

  for (let i = 0; i < argv.length; i++) {
    const a = String(argv[i] || '');
    if (a === '--direction') { args.direction = String(argv[++i] || '').trim(); continue; }
    if (a === '--sqlite') { args.sqlitePath = String(argv[++i] || '').trim(); continue; }
    if (a === '--tables') {
      args.tables = String(argv[++i] || '').split(',').map(s => s.trim()).filter(Boolean);
      continue;
    }
    if (a === '--skip') {
      args.skip = String(argv[++i] || '').split(',').map(s => s.trim()).filter(Boolean);
      continue;
    }
    if (a === '--no-truncate') { args.truncate = false; continue; }
    if (a === '--dry-run') { args.dryRun = true; continue; }
    if (a === '--batch') { args.batch = Math.max(1, parseInt(argv[++i], 10) || 200); continue; }
  }

  return args;
}

function printUsage() {
  console.error('Usage: node scripts/db-sync.mjs --direction <sqlite-to-pg|pg-to-sqlite> [options]');
  console.error('');
  console.error('Options:');
  console.error('  --direction <sqlite-to-pg|pg-to-sqlite>  (required)');
  console.error('  --sqlite <path>          SQLite file path');
  console.error('  --tables <t1,t2,...>     Only sync these tables');
  console.error('  --skip <t1,t2,...>       Skip these tables (in addition to schema_migrations)');
  console.error('  --no-truncate            Append rows instead of replacing');
  console.error('  --dry-run                Preview without writing');
  console.error('  --batch <n>              Rows per INSERT batch (default: 200)');
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
  // Return last candidate even if it doesn't exist — Database() will give a clear error
  return path.resolve(__dirname, '../../db/sdal.sqlite');
}

// ─── table/column discovery ───────────────────────────────────────────────────

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

function getSqliteColumns(sqlite, table) {
  return sqlite
    .prepare(`PRAGMA table_info(${qident(table)})`)
    .all()
    .map(r => ({ name: r.name, type: String(r.type || '').toUpperCase() }));
}

async function getPgColumns(client, table) {
  const { rows } = await client.query(
    `SELECT column_name, data_type
     FROM information_schema.columns
     WHERE table_schema='public' AND table_name=$1
     ORDER BY ordinal_position`,
    [table]
  );
  return rows.map(r => ({ name: r.column_name, type: r.data_type }));
}

// ─── FK-based topological sort ────────────────────────────────────────────────

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
  return rows; // { child, parent }
}

function topoSort(tables, fkEdges) {
  const tableSet = new Set(tables);

  // Each table's set of direct dependencies (tables it must be inserted after)
  const deps = new Map(tables.map(t => [t, new Set()]));

  for (const { child, parent } of fkEdges) {
    if (tableSet.has(child) && tableSet.has(parent) && child !== parent) {
      deps.get(child).add(parent);
    }
  }

  // Reverse map: parent → children that depend on it
  const childrenOf = new Map(tables.map(t => [t, []]));
  for (const [child, parents] of deps) {
    for (const parent of parents) {
      childrenOf.get(parent).push(child);
    }
  }

  // Kahn's algorithm
  const inDegree = new Map(tables.map(t => [t, deps.get(t).size]));
  const queue = tables.filter(t => inDegree.get(t) === 0);
  const result = [];

  while (queue.length > 0) {
    const t = queue.shift();
    result.push(t);
    for (const child of childrenOf.get(t)) {
      const deg = inDegree.get(child) - 1;
      inDegree.set(child, deg);
      if (deg === 0) queue.push(child);
    }
  }

  // Append any remaining tables (cyclic refs — shouldn't happen in well-formed schemas)
  for (const t of tables) {
    if (!result.includes(t)) result.push(t);
  }

  return result;
}

// ─── value converters ─────────────────────────────────────────────────────────

// Convert a PostgreSQL value to a SQLite-compatible value
function pgValueToSqlite(val, pgType) {
  if (val === null || val === undefined) return null;
  const t = String(pgType || '').toLowerCase();

  if (t === 'boolean') return val ? 1 : 0;

  if (val instanceof Date) return val.toISOString();

  if (t === 'json' || t === 'jsonb') {
    return typeof val === 'string' ? val : JSON.stringify(val);
  }

  if (Array.isArray(val)) return JSON.stringify(val);

  if (typeof val === 'object') return JSON.stringify(val);

  return val;
}

// Convert a SQLite value to a PostgreSQL-compatible value, using the PG column type
function sqliteValueToPg(val, pgType) {
  if (val === null || val === undefined) return null;
  const t = String(pgType || '').toLowerCase();

  if (t === 'boolean') {
    if (typeof val === 'number') return val !== 0;
    if (typeof val === 'string') return val === '1' || val.toLowerCase() === 'true';
    return Boolean(val);
  }

  if (t === 'json' || t === 'jsonb') {
    if (typeof val === 'string') {
      try { return JSON.parse(val); } catch { return val; }
    }
    return val;
  }

  return val;
}

// ─── sequence reset after SQLite→PG copy ─────────────────────────────────────

async function resetPgSequences(client, tables) {
  let reset = 0;
  for (const table of tables) {
    try {
      const { rows } = await client.query(
        `SELECT column_name
         FROM information_schema.columns
         WHERE table_schema = 'public'
           AND table_name = $1
           AND (column_default LIKE 'nextval%' OR identity_generation IS NOT NULL)`,
        [table]
      );
      for (const { column_name } of rows) {
        await client.query(
          `SELECT setval(
             pg_get_serial_sequence($1, $2),
             COALESCE((SELECT MAX(${qident(column_name)}) FROM ${qident(table)}), 0) + 1,
             false
           )`,
          [table, column_name]
        );
        reset++;
      }
    } catch {
      // Non-fatal: sequence may not exist for this table/column
    }
  }
  return reset;
}

// ─── copy: SQLite → PostgreSQL ────────────────────────────────────────────────

async function copySqliteToPg(sqlite, client, table, sharedCols, pgColMap, batchSize, truncate, dryRun) {
  const rows = sqlite
    .prepare(`SELECT ${sharedCols.map(qident).join(', ')} FROM ${qident(table)}`)
    .all();

  if (dryRun) return rows.length;

  if (truncate) {
    await client.query(`TRUNCATE TABLE ${qident(table)} RESTART IDENTITY CASCADE`);
  }

  if (!rows.length) return 0;

  const colSql = sharedCols.map(qident).join(', ');
  const onConflict = truncate ? '' : ' ON CONFLICT DO NOTHING';
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

    const sql = `INSERT INTO ${qident(table)} (${colSql}) VALUES ${placeholderGroups.join(', ')}${onConflict}`;
    await client.query(sql, values);
    copied += batch.length;
  }

  return copied;
}

// ─── copy: PostgreSQL → SQLite ────────────────────────────────────────────────

async function copyPgToSqlite(sqlite, client, table, sharedCols, pgColMap, batchSize, truncate, dryRun) {
  const { rows } = await client.query(
    `SELECT ${sharedCols.map(qident).join(', ')} FROM ${qident(table)}`
  );

  if (dryRun) return rows.length;

  if (truncate) {
    sqlite.prepare(`DELETE FROM ${qident(table)}`).run();
  }

  if (!rows.length) return 0;

  const colSql = sharedCols.map(qident).join(', ');
  const ph = sharedCols.map(() => '?').join(', ');
  const insertMode = truncate ? 'INSERT' : 'INSERT OR IGNORE';
  const stmt = sqlite.prepare(`${insertMode} INTO ${qident(table)} (${colSql}) VALUES (${ph})`);

  let copied = 0;
  const insertBatch = sqlite.transaction(batch => {
    for (const row of batch) {
      const vals = sharedCols.map(c => pgValueToSqlite(row[c], pgColMap.get(c)?.type || ''));
      stmt.run(vals);
      copied++;
    }
  });

  for (let start = 0; start < rows.length; start += batchSize) {
    insertBatch(rows.slice(start, start + batchSize));
  }

  return copied;
}

// ─── main ─────────────────────────────────────────────────────────────────────

const args = parseArgs(process.argv.slice(2));

if (!args.direction || !['sqlite-to-pg', 'pg-to-sqlite'].includes(args.direction)) {
  printUsage();
  process.exit(1);
}

const databaseUrl = String(process.env.DATABASE_URL || '').trim();
if (!databaseUrl) {
  console.error('[db-sync] ERROR: DATABASE_URL environment variable is required');
  process.exit(1);
}

const sqlitePath = resolveSqlitePath(args.sqlitePath);
const redactedUrl = databaseUrl.replace(/:[^:@]+@/, ':***@');

console.log(`[db-sync] direction  : ${args.direction}`);
console.log(`[db-sync] sqlite     : ${sqlitePath}`);
console.log(`[db-sync] postgres   : ${redactedUrl}`);
console.log(`[db-sync] truncate   : ${args.truncate}`);
console.log(`[db-sync] dry-run    : ${args.dryRun}`);
console.log(`[db-sync] batch size : ${args.batch}`);
if (args.tables) console.log(`[db-sync] tables     : ${args.tables.join(', ')}`);
if (args.skip.length) console.log(`[db-sync] extra skip : ${args.skip.join(', ')}`);
console.log('');

// schema_migrations tracks per-DB migration state — never sync it
const ALWAYS_SKIP = new Set(['schema_migrations', ...args.skip]);

// Open SQLite (write access only needed for pg-to-sqlite)
let sqlite;
try {
  sqlite = new Database(sqlitePath, {
    readonly: args.direction === 'sqlite-to-pg',
    fileMustExist: true,
  });
  sqlite.pragma('journal_mode = WAL');
} catch (err) {
  console.error(`[db-sync] ERROR: Cannot open SQLite at ${sqlitePath}: ${err.message}`);
  process.exit(1);
}

const client = new Client({ connectionString: databaseUrl });
try {
  await client.connect();
} catch (err) {
  console.error(`[db-sync] ERROR: Cannot connect to PostgreSQL: ${err.message}`);
  sqlite.close();
  process.exit(1);
}

try {
  const [sqliteTables, pgTables, fkEdges] = await Promise.all([
    Promise.resolve(getSqliteTables(sqlite)),
    getPgTables(client),
    getPgFkEdges(client),
  ]);

  const sqliteSet = new Set(sqliteTables);
  const pgSet = new Set(pgTables);

  // Tables in both DBs — these are candidates for sync
  let toSync = sqliteTables.filter(t => pgSet.has(t) && !ALWAYS_SKIP.has(t));

  // If caller specified --tables, restrict to that list
  if (args.tables) {
    const requested = new Set(args.tables);
    const unknown = args.tables.filter(t => !sqliteSet.has(t) && !pgSet.has(t));
    if (unknown.length) {
      console.error(`[db-sync] ERROR: Requested tables not found in either DB: ${unknown.join(', ')}`);
      process.exit(1);
    }
    toSync = toSync.filter(t => requested.has(t));
  }

  const onlyInSqlite = sqliteTables.filter(t => !pgSet.has(t) && !ALWAYS_SKIP.has(t));
  const onlyInPg = pgTables.filter(t => !sqliteSet.has(t) && !ALWAYS_SKIP.has(t));

  if (onlyInSqlite.length) {
    console.log(`[db-sync] Tables only in SQLite (skipped): ${onlyInSqlite.join(', ')}`);
  }
  if (onlyInPg.length) {
    console.log(`[db-sync] Tables only in PG (skipped)    : ${onlyInPg.join(', ')}`);
  }
  console.log(`[db-sync] Tables to sync: ${toSync.length}`);
  console.log('');

  if (!toSync.length) {
    console.log('[db-sync] Nothing to do.');
    process.exit(0);
  }

  // Sort tables by FK dependency order (parents before children) for safe inserts
  const sorted = topoSort(toSync, fkEdges);

  const report = { copied: 0, empty: 0, skipped: 0, errors: [] };

  if (args.direction === 'pg-to-sqlite') {
    sqlite.pragma('foreign_keys = OFF');
  }

  for (const table of sorted) {
    process.stdout.write(`  ${table.padEnd(40)} `);

    try {
      const [sqliteCols, pgCols] = await Promise.all([
        Promise.resolve(getSqliteColumns(sqlite, table)),
        getPgColumns(client, table),
      ]);

      const sqliteColSet = new Set(sqliteCols.map(c => c.name));
      const pgColMap = new Map(pgCols.map(c => [c.name, c]));

      const sharedCols = pgCols.filter(c => sqliteColSet.has(c.name)).map(c => c.name);
      const missingInSqlite = pgCols.filter(c => !sqliteColSet.has(c.name)).map(c => c.name);
      const missingInPg = sqliteCols.filter(c => !pgColMap.has(c.name)).map(c => c.name);

      if (!sharedCols.length) {
        console.log('SKIP  (no common columns)');
        report.skipped++;
        continue;
      }

      let rowCount;
      if (args.direction === 'sqlite-to-pg') {
        rowCount = await copySqliteToPg(sqlite, client, table, sharedCols, pgColMap, args.batch, args.truncate, args.dryRun);
      } else {
        rowCount = await copyPgToSqlite(sqlite, client, table, sharedCols, pgColMap, args.batch, args.truncate, args.dryRun);
      }

      if (rowCount === 0) {
        report.empty++;
        process.stdout.write('ok    (0 rows)\n');
      } else {
        report.copied++;
        process.stdout.write(`ok    (${rowCount} rows)\n`);
      }

      if (missingInSqlite.length) {
        console.log(`         ^ PG-only columns (not copied): ${missingInSqlite.join(', ')}`);
      }
      if (missingInPg.length) {
        console.log(`         ^ SQLite-only columns (not copied): ${missingInPg.join(', ')}`);
      }

    } catch (err) {
      console.log(`ERROR: ${err.message}`);
      report.errors.push({ table, error: err.message });
    }
  }

  if (args.direction === 'pg-to-sqlite') {
    sqlite.pragma('foreign_keys = ON');
  }

  // After SQLite→PG copy, reset sequences so new inserts don't collide with copied IDs
  if (args.direction === 'sqlite-to-pg' && !args.dryRun) {
    process.stdout.write('\n[db-sync] Resetting PG sequences ... ');
    const count = await resetPgSequences(client, sorted);
    console.log(`ok (${count} sequence(s) reset)`);
  }

  console.log('');
  console.log(`[db-sync] Summary:`);
  console.log(`  Tables synced  : ${report.copied + report.empty}`);
  console.log(`  Rows copied    : (see per-table output above)`);
  console.log(`  Tables skipped : ${report.skipped}`);
  console.log(`  Errors         : ${report.errors.length}`);

  if (report.errors.length) {
    console.error('\n[db-sync] Errors:');
    for (const { table, error } of report.errors) {
      console.error(`  ${table}: ${error}`);
    }
    process.exitCode = 1;
  } else if (!args.dryRun) {
    console.log('\n[db-sync] Completed successfully.');
  } else {
    console.log('\n[db-sync] Dry run complete. No data was written.');
  }

} finally {
  try { sqlite.close(); } catch {}
  try { await client.end(); } catch {}
}
