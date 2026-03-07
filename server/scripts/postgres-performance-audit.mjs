import os from 'node:os';
import process from 'node:process';
import pkg from 'pg';

const { Pool } = pkg;

const connectionString = String(process.env.DATABASE_URL || '').trim();
if (!connectionString) {
  console.error('[pg-audit] DATABASE_URL is required');
  process.exit(1);
}

const args = new Set(process.argv.slice(2));
const enablePgStatStatements = args.has('--enable-pg-stat-statements');
const asJson = args.has('--json');

const SETTINGS = [
  'max_connections',
  'shared_buffers',
  'effective_cache_size',
  'work_mem',
  'maintenance_work_mem',
  'random_page_cost',
  'effective_io_concurrency',
  'wal_buffers',
  'checkpoint_timeout',
  'checkpoint_completion_target',
  'default_statistics_target',
  'autovacuum',
  'autovacuum_naptime',
  'autovacuum_vacuum_scale_factor',
  'autovacuum_analyze_scale_factor'
];

const pool = new Pool({
  connectionString,
  max: 2,
  idleTimeoutMillis: 5000,
  connectionTimeoutMillis: 8000,
  statement_timeout: 15000
});

async function fetchOne(client, sql, params = []) {
  const result = await client.query(sql, params);
  return result.rows[0] || null;
}

async function fetchAll(client, sql, params = []) {
  const result = await client.query(sql, params);
  return result.rows || [];
}

async function main() {
  const client = await pool.connect();
  try {
    const startedAt = Date.now();

    const serverInfo = await fetchOne(
      client,
      `SELECT
         version() AS version,
         current_setting('server_version') AS server_version,
         current_setting('server_version_num') AS server_version_num,
         current_database() AS database_name,
         current_user AS db_user,
         pg_postmaster_start_time() AS postmaster_started_at,
         NOW() AS sampled_at`
    );

    const settings = await fetchAll(
      client,
      `SELECT name, setting, unit, source
       FROM pg_settings
       WHERE name = ANY($1::text[])
       ORDER BY name ASC`,
      [SETTINGS]
    );

    let pgStatStatementsStatus = {
      available: false,
      enabled: false,
      detail: 'extension not installed'
    };
    const installedExt = await fetchOne(
      client,
      `SELECT extname
       FROM pg_extension
       WHERE extname = 'pg_stat_statements'`
    );
    if (installedExt) {
      pgStatStatementsStatus = {
        available: true,
        enabled: true,
        detail: 'installed'
      };
    } else if (enablePgStatStatements) {
      try {
        await client.query('CREATE EXTENSION IF NOT EXISTS pg_stat_statements');
        pgStatStatementsStatus = {
          available: true,
          enabled: true,
          detail: 'created in current database'
        };
      } catch (err) {
        pgStatStatementsStatus = {
          available: false,
          enabled: false,
          detail: `create failed: ${err?.message || 'unknown_error'}`
        };
      }
    }

    const activityByState = await fetchAll(
      client,
      `SELECT
         COALESCE(state, 'unknown') AS state,
         COALESCE(wait_event_type, '') AS wait_event_type,
         COUNT(*)::bigint AS connections
       FROM pg_stat_activity
       WHERE pid <> pg_backend_pid()
       GROUP BY COALESCE(state, 'unknown'), COALESCE(wait_event_type, '')
       ORDER BY connections DESC, state ASC`
    );

    const longRunning = await fetchAll(
      client,
      `SELECT
         pid,
         usename,
         state,
         NOW() - query_start AS query_age,
         NOW() - xact_start AS xact_age,
         wait_event_type,
         wait_event,
         LEFT(query, 240) AS query
       FROM pg_stat_activity
       WHERE pid <> pg_backend_pid()
         AND query_start IS NOT NULL
       ORDER BY query_start ASC
       LIMIT 20`
    );

    let topStatements = [];
    if (pgStatStatementsStatus.enabled) {
      try {
        topStatements = await fetchAll(
          client,
          `SELECT
             queryid,
             calls,
             ROUND(total_exec_time::numeric, 2) AS total_exec_time_ms,
             ROUND(mean_exec_time::numeric, 2) AS mean_exec_time_ms,
             ROUND(stddev_exec_time::numeric, 2) AS stddev_exec_time_ms,
             rows,
             shared_blks_hit,
             shared_blks_read,
             temp_blks_read,
             temp_blks_written,
             LEFT(query, 500) AS query
           FROM pg_stat_statements
           ORDER BY total_exec_time DESC
           LIMIT 25`
        );
      } catch (err) {
        pgStatStatementsStatus = {
          available: true,
          enabled: false,
          detail: `query failed: ${err?.message || 'unknown_error'}`
        };
      }
    }

    const tableStats = await fetchAll(
      client,
      `SELECT
         relname AS table_name,
         seq_scan,
         idx_scan,
         n_live_tup,
         n_dead_tup,
         ROUND(
           CASE
             WHEN (seq_scan + idx_scan) = 0 THEN 0
             ELSE (seq_scan::numeric / (seq_scan + idx_scan)::numeric) * 100
           END
         , 2) AS seq_scan_pct
       FROM pg_stat_user_tables
       ORDER BY seq_scan DESC, n_live_tup DESC
       LIMIT 40`
    );

    const indexStats = await fetchAll(
      client,
      `SELECT
         s.relname AS table_name,
         i.relname AS index_name,
         psui.idx_scan,
         pg_size_pretty(pg_relation_size(i.oid)) AS index_size
       FROM pg_stat_user_indexes psui
       JOIN pg_index x ON x.indexrelid = psui.indexrelid
       JOIN pg_class i ON i.oid = psui.indexrelid
       JOIN pg_class s ON s.oid = psui.relid
       WHERE NOT x.indisprimary
       ORDER BY psui.idx_scan ASC, pg_relation_size(i.oid) DESC
       LIMIT 50`
    );

    const sampledAt = new Date().toISOString();
    const report = {
      sampledAt,
      host: {
        hostname: os.hostname(),
        platform: process.platform,
        arch: process.arch,
        cpus: os.cpus()?.length || 0,
        totalMemBytes: os.totalmem(),
        freeMemBytes: os.freemem(),
        uptimeSec: os.uptime(),
        loadAvg: os.loadavg()
      },
      postgres: {
        ...serverInfo,
        settings,
        pgStatStatements: pgStatStatementsStatus,
        activityByState,
        longRunning,
        topStatements,
        tableStats,
        indexStats
      },
      durationMs: Date.now() - startedAt
    };

    if (asJson) {
      console.log(JSON.stringify(report, null, 2));
      return;
    }

    console.log('[pg-audit] host');
    console.log(`  hostname=${report.host.hostname} cpus=${report.host.cpus} totalMemBytes=${report.host.totalMemBytes} loadAvg=${report.host.loadAvg.join(',')}`);
    console.log('[pg-audit] postgres');
    console.log(`  version=${report.postgres.server_version} db=${report.postgres.database_name} user=${report.postgres.db_user}`);
    console.log(`  pg_stat_statements=${report.postgres.pgStatStatements.enabled ? 'enabled' : 'disabled'} (${report.postgres.pgStatStatements.detail})`);
    console.log('[pg-audit] key settings');
    for (const row of settings) {
      const unit = row.unit ? row.unit : '';
      console.log(`  ${row.name}=${row.setting}${unit ? ` ${unit}` : ''} (source=${row.source})`);
    }
    console.log('[pg-audit] top statements by total exec time');
    for (const row of topStatements.slice(0, 10)) {
      console.log(`  calls=${row.calls} totalMs=${row.total_exec_time_ms} meanMs=${row.mean_exec_time_ms} query=${String(row.query || '').replace(/\s+/g, ' ').slice(0, 140)}`);
    }
    console.log('[pg-audit] tables with highest sequential scan ratio');
    for (const row of tableStats.slice(0, 12)) {
      console.log(`  ${row.table_name}: seq_scan=${row.seq_scan} idx_scan=${row.idx_scan} seq_scan_pct=${row.seq_scan_pct}% live=${row.n_live_tup}`);
    }
    console.log('[pg-audit] lowest-used non-primary indexes');
    for (const row of indexStats.slice(0, 15)) {
      console.log(`  ${row.table_name}.${row.index_name}: idx_scan=${row.idx_scan} size=${row.index_size}`);
    }
    console.log(`[pg-audit] done in ${report.durationMs}ms`);
  } finally {
    client.release();
  }
}

main()
  .catch((err) => {
    console.error('[pg-audit] failed:', err?.message || err);
    process.exitCode = 1;
  })
  .finally(async () => {
    await pool.end();
  });
