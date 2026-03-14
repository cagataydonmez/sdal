import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import Database from 'better-sqlite3';
import { getPostgresPool, closePostgresPool, isPostgresConfigured } from '../src/infra/postgresPool.js';
import { buildMappings } from './lib/legacySqliteMappers.mjs';
import { fkChecks, SEQUENCE_TABLES } from './lib/legacySqliteMigrationChecks.mjs';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const projectRoot = path.resolve(__dirname, '../..');

function parseArgs(argv) {
  const args = {
    truncate: true,
    sqlitePath: '',
    reportPath: ''
  };

  for (let i = 0; i < argv.length; i += 1) {
    const arg = String(argv[i] || '');
    if (arg === '--no-truncate') {
      args.truncate = false;
      continue;
    }
    if (arg === '--truncate') {
      args.truncate = true;
      continue;
    }
    if (arg === '--sqlite' || arg === '--sqlite-path') {
      args.sqlitePath = String(argv[i + 1] || '').trim();
      i += 1;
      continue;
    }
    if (arg === '--report') {
      args.reportPath = String(argv[i + 1] || '').trim();
      i += 1;
      continue;
    }
  }

  return args;
}

function qident(name) {
  return `"${String(name).replace(/"/g, '""')}"`;
}

function buildInsertSql(table, columns, rowCount, onConflict) {
  const columnSql = columns.map((c) => qident(c)).join(', ');
  const valuesSql = [];
  for (let i = 0; i < rowCount; i += 1) {
    const start = i * columns.length;
    const placeholders = columns.map((_, idx) => `$${start + idx + 1}`);
    valuesSql.push(`(${placeholders.join(', ')})`);
  }
  return `INSERT INTO ${qident(table)} (${columnSql}) VALUES ${valuesSql.join(', ')} ${onConflict || ''}`.trim();
}

function tableExistsSqlite(sqlite, table) {
  const row = sqlite.prepare("SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?").get(table);
  return Boolean(row);
}

async function tableExistsPg(pgPool, table) {
  const row = await pgPool.query(
    `SELECT 1
     FROM information_schema.tables
     WHERE table_schema = 'public' AND table_name = $1
     LIMIT 1`,
    [table]
  );
  return row.rows.length > 0;
}

async function syncIdentitySequence(pgPool, table, column = 'id') {
  await pgPool.query(
    `SELECT setval(
      pg_get_serial_sequence($1, $2),
      COALESCE((SELECT MAX(${qident(column)}) FROM ${qident(table)}), 1),
      TRUE
    )`,
    [table, column]
  );
}

function mapRows(rows, map) {
  const mappedRows = [];
  const targetColumns = map.targetColumns;

  for (const row of rows) {
    const out = {};
    for (const column of targetColumns) {
      const mapper = map.map[column];
      if (typeof mapper === 'function') {
        out[column] = mapper(row);
      } else if (typeof mapper === 'string') {
        out[column] = row[mapper];
      } else {
        out[column] = null;
      }
    }
    mappedRows.push(out);
  }

  return mappedRows;
}

async function copyMapping(sqlite, pgPool, mapping, report, { truncate }) {
  const source = mapping.source;
  const target = mapping.target;
  const reportEntry = {
    source,
    target,
    sourceTableExists: true,
    targetTableExists: true,
    sourceCount: 0,
    targetCount: 0,
    insertedCount: 0,
    skipped: false,
    notes: []
  };

  const sourceExists = mapping.syntheticSource ? true : tableExistsSqlite(sqlite, source);
  reportEntry.sourceTableExists = sourceExists;
  if (!sourceExists) {
    reportEntry.skipped = true;
    reportEntry.sourceCount = 0;
    reportEntry.targetCount = Number((await pgPool.query(`SELECT COUNT(*)::bigint AS cnt FROM ${qident(target)}`)).rows[0]?.cnt || 0);
    reportEntry.notes.push('source table not found in sqlite; skipped');
    report.tables.push(reportEntry);
    return;
  }

  const targetExists = await tableExistsPg(pgPool, target);
  reportEntry.targetTableExists = targetExists;
  if (!targetExists) {
    reportEntry.skipped = true;
    reportEntry.notes.push('target table not found in postgres schema');
    report.tables.push(reportEntry);
    report.mismatches.push({
      source,
      target,
      reason: 'target_missing'
    });
    return;
  }

  const sourceRows = mapping.syntheticSource
    ? mapping.syntheticSource(sqlite)
    : sqlite.prepare(mapping.selectSql || `SELECT * FROM ${qident(source)}`).all();

  reportEntry.sourceCount = sourceRows.length;

  if (!sourceRows.length) {
    reportEntry.targetCount = Number((await pgPool.query(`SELECT COUNT(*)::bigint AS cnt FROM ${qident(target)}`)).rows[0]?.cnt || 0);
    report.tables.push(reportEntry);
    return;
  }

  const mappedRows = mapRows(sourceRows, mapping);
  const columns = mapping.targetColumns;
  const batchSize = mapping.batchSize || 500;
  const onConflict = mapping.onConflict || '';

  if (truncate && mapping.resetTarget !== false) {
    await pgPool.query(`TRUNCATE TABLE ${qident(target)} RESTART IDENTITY CASCADE`);
  }

  for (let offset = 0; offset < mappedRows.length; offset += batchSize) {
    const batch = mappedRows.slice(offset, offset + batchSize);
    const values = [];
    for (const row of batch) {
      for (const column of columns) {
        values.push(row[column]);
      }
    }
    const sql = buildInsertSql(target, columns, batch.length, onConflict);
    const result = await pgPool.query(sql, values);
    reportEntry.insertedCount += Number(result.rowCount || 0);
  }

  const targetCountRow = await pgPool.query(`SELECT COUNT(*)::bigint AS cnt FROM ${qident(target)}`);
  reportEntry.targetCount = Number(targetCountRow.rows[0]?.cnt || 0);

  if (reportEntry.sourceCount !== reportEntry.targetCount) {
    report.mismatches.push({
      source,
      target,
      sourceCount: reportEntry.sourceCount,
      targetCount: reportEntry.targetCount,
      reason: 'row_count_mismatch'
    });
  }

  report.tables.push(reportEntry);
}

async function main() {
  const args = parseArgs(process.argv.slice(2));

  if (!isPostgresConfigured()) {
    throw new Error('DATABASE_URL is required for sqlite -> modern postgres migration');
  }

  const sqlitePath = args.sqlitePath
    ? path.resolve(args.sqlitePath)
    : process.env.SQLITE_PATH
      ? path.resolve(process.env.SQLITE_PATH)
      : path.resolve(projectRoot, 'db/sdal.sqlite');

  const reportPath = args.reportPath
    ? path.resolve(args.reportPath)
    : process.env.MIGRATION_REPORT_PATH
      ? path.resolve(process.env.MIGRATION_REPORT_PATH)
      : path.resolve(projectRoot, 'migration_report.json');

  if (!fs.existsSync(sqlitePath)) {
    throw new Error(`SQLite source not found at ${sqlitePath}`);
  }

  const sqlite = new Database(sqlitePath, { readonly: true, fileMustExist: true });
  const pgPool = getPostgresPool();
  if (!pgPool) {
    throw new Error('Failed to initialize postgres pool');
  }

  const report = {
    startedAt: new Date().toISOString(),
    finishedAt: null,
    source: {
      sqlitePath
    },
    target: {
      databaseUrlHost: String(process.env.DATABASE_URL || '').replace(/:[^:@/]+@/, ':***@')
    },
    options: {
      truncate: args.truncate,
      reportPath
    },
    tables: [],
    mismatches: [],
    fkIntegrity: [],
    summary: {
      sourceRows: 0,
      targetRows: 0,
      mismatchCount: 0,
      fkViolationCount: 0
    }
  };

  try {
    const mappings = buildMappings();

    if (args.truncate) {
      const truncateTargets = mappings
        .map((m) => m.target)
        .filter((v, i, arr) => arr.indexOf(v) === i)
        .map((name) => qident(name))
        .join(', ');
      await pgPool.query(`TRUNCATE TABLE ${truncateTargets} RESTART IDENTITY CASCADE`);
    }

    for (const mapping of mappings) {
      console.log(`[data-migrate] ${mapping.source} -> ${mapping.target}`);
      await copyMapping(sqlite, pgPool, mapping, report, { truncate: false });
    }

    for (const table of SEQUENCE_TABLES) {
      try {
        await syncIdentitySequence(pgPool, table);
      } catch {
        // some tables may not have identity sequences in older pg versions/configs
      }
    }

    for (const check of fkChecks()) {
      try {
        const row = await pgPool.query(check.sql);
        const violations = Number(row.rows[0]?.violations || 0);
        report.fkIntegrity.push({ name: check.name, violations });
        if (violations > 0) {
          report.mismatches.push({
            source: 'fk_check',
            target: check.name,
            reason: 'fk_violation',
            violations
          });
        }
      } catch (err) {
        report.fkIntegrity.push({
          name: check.name,
          violations: null,
          error: err?.message || 'failed'
        });
        report.mismatches.push({
          source: 'fk_check',
          target: check.name,
          reason: 'fk_check_failed',
          error: err?.message || 'failed'
        });
      }
    }

    report.summary.sourceRows = report.tables.reduce((sum, item) => sum + Number(item.sourceCount || 0), 0);
    report.summary.targetRows = report.tables.reduce((sum, item) => sum + Number(item.targetCount || 0), 0);
    report.summary.mismatchCount = report.mismatches.length;
    report.summary.fkViolationCount = report.fkIntegrity.reduce(
      (sum, item) => sum + (Number.isFinite(item.violations) ? Number(item.violations) : 0),
      0
    );
    report.finishedAt = new Date().toISOString();

    fs.writeFileSync(reportPath, JSON.stringify(report, null, 2));

    if (report.summary.mismatchCount > 0 || report.summary.fkViolationCount > 0) {
      console.error(
        `[data-migrate] completed with issues. mismatches=${report.summary.mismatchCount} fkViolations=${report.summary.fkViolationCount}`
      );
      process.exitCode = 2;
      return;
    }

    console.log('[data-migrate] completed successfully');
    console.log(`[data-migrate] report written: ${reportPath}`);
  } finally {
    try {
      sqlite.close();
    } catch {
      // no-op
    }
    await closePostgresPool();
  }
}

main().catch(async (err) => {
  console.error('[data-migrate] failed:', err?.message || err);
  await closePostgresPool();
  process.exit(1);
});
