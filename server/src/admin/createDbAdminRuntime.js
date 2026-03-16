import fs from 'fs';
import path from 'path';
import Database from 'better-sqlite3';
import crypto from 'crypto';
import { execFileSync } from 'child_process';

export function createDbAdminRuntime({
  appRootDir,
  dbDriver,
  dbPath,
  getDb,
  closeDbConnection,
  resetDbConnection,
  checkPostgresHealth,
  pgQuery,
  getPgPool,
  writeAppLog
}) {
  const isPostgresDb = dbDriver === 'postgres';
  const dbBackupIncomingDir = path.resolve(appRootDir, '../tmp/db-backup-upload');
  if (!fs.existsSync(dbBackupIncomingDir)) {
    fs.mkdirSync(dbBackupIncomingDir, { recursive: true });
  }

  const dbBackupDir = path.join(path.dirname(dbPath), 'backups');
  if (!fs.existsSync(dbBackupDir)) {
    fs.mkdirSync(dbBackupDir, { recursive: true });
  }

  const DB_DRIVER_SET = new Set(['sqlite', 'postgres']);
  const dbDriverSwitchEnvFile = (() => {
    const fromEnv = String(process.env.SDAL_DB_SWITCH_ENV_FILE || '').trim();
    return path.resolve(fromEnv || '/etc/sdal/sdal.env');
  })();
  const dbDriverSwitchChallengeTtlMs = (() => {
    const parsed = Number.parseInt(String(process.env.SDAL_DB_SWITCH_CHALLENGE_TTL_MS || ''), 10);
    return Number.isFinite(parsed) && parsed > 0 ? parsed : 2 * 60 * 1000;
  })();
  const dbDriverSwitchRestartDelayMs = (() => {
    const parsed = Number.parseInt(String(process.env.SDAL_DB_SWITCH_RESTART_DELAY_MS || ''), 10);
    return Number.isFinite(parsed) && parsed > 0 ? parsed : 1200;
  })();
  const dbDriverSwitchRestartCommand = String(process.env.SDAL_DB_SWITCH_RESTART_CMD || '').trim();
  const dbDriverSwitchChallenges = new Map();
  const dbDriverSwitchState = {
    inProgress: false,
    lastAttemptAt: null,
    lastSuccessAt: null,
    lastError: null,
    lastSwitch: null
  };

  function backupTimestamp(date = new Date()) {
    const pad = (n) => String(n).padStart(2, '0');
    return `${date.getFullYear()}${pad(date.getMonth() + 1)}${pad(date.getDate())}-${pad(date.getHours())}${pad(date.getMinutes())}${pad(date.getSeconds())}`;
  }

  function normalizeBackupName(value) {
    const base = path.basename(String(value || ''));
    const safe = base.replace(/[^a-zA-Z0-9._-]/g, '_');
    if (!safe) return '';
    if (isPostgresDb) {
      if (!/\.(dump|sql|backup)$/i.test(safe)) return `${safe}.dump`;
      return safe;
    }
    if (!safe.endsWith('.sqlite')) return `${safe}.sqlite`;
    return safe;
  }

  function resolveBackupPath(fileName) {
    const safeName = normalizeBackupName(fileName);
    if (!safeName) return null;
    return path.join(dbBackupDir, safeName);
  }

  function isSqliteHeader(buffer) {
    if (!buffer || buffer.length < 16) return false;
    const signature = Buffer.from('SQLite format 3\u0000', 'utf-8');
    return buffer.subarray(0, 16).equals(signature);
  }

  function isSqliteFile(filePath) {
    if (!filePath || !fs.existsSync(filePath)) return false;
    const fd = fs.openSync(filePath, 'r');
    try {
      const header = Buffer.alloc(16);
      const bytes = fs.readSync(fd, header, 0, 16, 0);
      if (bytes < 16) return false;
      return isSqliteHeader(header);
    } finally {
      fs.closeSync(fd);
    }
  }

  function listDbBackups() {
    if (!fs.existsSync(dbBackupDir)) return [];
    const backupExtPattern = isPostgresDb ? /\.(dump|sql|backup)$/i : /\.(sqlite|db|backup|bak)$/i;
    return fs.readdirSync(dbBackupDir)
      .filter((name) => backupExtPattern.test(name))
      .map((name) => {
        const fullPath = path.join(dbBackupDir, name);
        const st = fs.statSync(fullPath);
        return {
          name,
          size: st.size,
          mtime: st.mtime.toISOString()
        };
      })
      .sort((a, b) => new Date(b.mtime).getTime() - new Date(a.mtime).getTime());
  }

  async function createDbBackup(label = 'manual') {
    const safeLabel = String(label || 'manual').replace(/[^a-zA-Z0-9_-]/g, '_').slice(0, 32) || 'manual';
    if (isPostgresDb) {
      const databaseUrl = String(process.env.DATABASE_URL || '').trim();
      if (!databaseUrl) throw new Error('DATABASE_URL eksik. PostgreSQL yedeği alınamadı.');
      const name = `sdal-backup-${backupTimestamp()}-${safeLabel}.dump`;
      const fullPath = path.join(dbBackupDir, name);
      execFileSync('pg_dump', ['--format=custom', '--file', fullPath, databaseUrl], { stdio: 'pipe' });
      const st = fs.statSync(fullPath);
      return {
        name,
        size: st.size,
        mtime: st.mtime.toISOString()
      };
    }

    const name = `sdal-backup-${backupTimestamp()}-${safeLabel}.sqlite`;
    const fullPath = path.join(dbBackupDir, name);
    const db = getDb();
    try {
      db.pragma('wal_checkpoint(FULL)');
    } catch {
      // no-op
    }
    await db.backup(fullPath);
    const st = fs.statSync(fullPath);
    return {
      name,
      size: st.size,
      mtime: st.mtime.toISOString()
    };
  }

  function restoreDbFromUploadedFile(incomingPath) {
    if (isPostgresDb) {
      const databaseUrl = String(process.env.DATABASE_URL || '').trim();
      if (!databaseUrl) throw new Error('DATABASE_URL eksik. PostgreSQL geri yükleme yapılamadı.');
      const stamp = backupTimestamp();
      const uploadedName = `uploaded-${stamp}.dump`;
      const uploadedPath = path.join(dbBackupDir, uploadedName);
      fs.copyFileSync(incomingPath, uploadedPath);

      const preRestoreName = `pre-restore-${stamp}.dump`;
      const preRestorePath = path.join(dbBackupDir, preRestoreName);
      execFileSync('pg_dump', ['--format=custom', '--file', preRestorePath, databaseUrl], { stdio: 'pipe' });

      try {
        execFileSync(
          'pg_restore',
          ['--clean', '--if-exists', '--no-owner', '--no-privileges', '--dbname', databaseUrl, uploadedPath],
          { stdio: 'pipe' }
        );
      } catch (err) {
        try {
          execFileSync(
            'pg_restore',
            ['--clean', '--if-exists', '--no-owner', '--no-privileges', '--dbname', databaseUrl, preRestorePath],
            { stdio: 'pipe' }
          );
        } catch {
          // best effort rollback
        }
        throw err;
      }
      return { uploadedName, preRestoreName };
    }

    if (!isSqliteFile(incomingPath)) {
      throw new Error('Yüklenen dosya geçerli bir SQLite yedeği değil.');
    }

    const stamp = backupTimestamp();
    const uploadedName = `uploaded-${stamp}.sqlite`;
    const uploadedPath = path.join(dbBackupDir, uploadedName);
    fs.copyFileSync(incomingPath, uploadedPath);

    const preRestoreName = `pre-restore-${stamp}.sqlite`;
    const preRestorePath = path.join(dbBackupDir, preRestoreName);
    if (fs.existsSync(dbPath)) {
      fs.copyFileSync(dbPath, preRestorePath);
    }

    const tmpPath = `${dbPath}.restore.${Date.now()}.tmp`;
    fs.copyFileSync(uploadedPath, tmpPath);
    closeDbConnection();
    try {
      fs.renameSync(tmpPath, dbPath);
    } catch (err) {
      if (fs.existsSync(preRestorePath)) {
        fs.copyFileSync(preRestorePath, dbPath);
      }
      throw err;
    } finally {
      try {
        if (fs.existsSync(tmpPath)) fs.unlinkSync(tmpPath);
      } catch {
        // no-op
      }
      resetDbConnection();
    }

    return { uploadedName, preRestoreName };
  }

  function resolveDbDriverSwitchTarget(currentDriver = dbDriver) {
    return String(currentDriver || '').toLowerCase() === 'postgres' ? 'sqlite' : 'postgres';
  }

  function buildDbDriverSwitchConfirmText(currentDriver, targetDriver) {
    return `SWITCH ${String(currentDriver || '').toUpperCase()} -> ${String(targetDriver || '').toUpperCase()}`;
  }

  function buildDbDriverSwitchChallengeKey(req, targetDriver) {
    const sessionKey = String(req.sessionID || req.session?.id || req.session?.userId || req.ip || 'anon');
    return `${sessionKey}:${String(targetDriver || '').toLowerCase()}`;
  }

  function cleanupExpiredDbDriverSwitchChallenges(now = Date.now()) {
    for (const [key, value] of dbDriverSwitchChallenges.entries()) {
      if (!value || Number(value.expiresAt || 0) <= now) {
        dbDriverSwitchChallenges.delete(key);
      }
    }
  }

  function issueDbDriverSwitchChallenge(req, targetDriver) {
    cleanupExpiredDbDriverSwitchChallenges();
    const key = buildDbDriverSwitchChallengeKey(req, targetDriver);
    const token = crypto.randomBytes(24).toString('hex');
    const expiresAt = Date.now() + dbDriverSwitchChallengeTtlMs;
    dbDriverSwitchChallenges.set(key, { token, expiresAt });
    return { token, expiresAt };
  }

  function consumeDbDriverSwitchChallenge(req, targetDriver, token) {
    cleanupExpiredDbDriverSwitchChallenges();
    const key = buildDbDriverSwitchChallengeKey(req, targetDriver);
    const row = dbDriverSwitchChallenges.get(key);
    dbDriverSwitchChallenges.delete(key);
    if (!row) return false;
    if (!token || row.token !== token) return false;
    if (Number(row.expiresAt || 0) <= Date.now()) return false;
    return true;
  }

  function inspectDbDriverSwitchEnvFile() {
    const info = {
      path: dbDriverSwitchEnvFile,
      exists: false,
      readable: false,
      writable: false
    };
    try {
      info.exists = fs.existsSync(dbDriverSwitchEnvFile);
      if (!info.exists) return info;
      fs.accessSync(dbDriverSwitchEnvFile, fs.constants.R_OK);
      info.readable = true;
      fs.accessSync(dbDriverSwitchEnvFile, fs.constants.W_OK);
      info.writable = true;
      return info;
    } catch {
      return info;
    }
  }

  function inspectSqliteSwitchTarget(sqliteFilePath) {
    const payload = {
      ready: false,
      detail: '',
      path: sqliteFilePath,
      tableCount: 0,
      usersTableExists: false
    };

    if (!sqliteFilePath) {
      payload.detail = 'SQLite dosya yolu bulunamadı.';
      return payload;
    }
    if (!fs.existsSync(sqliteFilePath)) {
      payload.detail = `SQLite dosyası bulunamadı (${sqliteFilePath}).`;
      return payload;
    }
    if (!isSqliteFile(sqliteFilePath)) {
      payload.detail = 'SQLite dosya imzası doğrulanamadı.';
      return payload;
    }

    let tmp = null;
    try {
      tmp = new Database(sqliteFilePath, { readonly: true, fileMustExist: true });
      const tableCount = Number(tmp.prepare(
        "SELECT COUNT(*) AS cnt FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%'"
      ).get()?.cnt || 0);
      const usersTableExists = !!tmp.prepare(
        "SELECT name FROM sqlite_master WHERE type = 'table' AND name IN ('uyeler', 'users') LIMIT 1"
      ).get();
      payload.tableCount = tableCount;
      payload.usersTableExists = usersTableExists;
      if (!usersTableExists) {
        payload.detail = 'SQLite içinde beklenen kullanıcı tablosu bulunamadı (uyeler/users).';
        return payload;
      }
      payload.ready = true;
      payload.detail = 'ok';
      return payload;
    } catch (err) {
      payload.detail = err?.message || 'SQLite hedef doğrulaması başarısız.';
      return payload;
    } finally {
      try {
        tmp?.close();
      } catch {
        // no-op
      }
    }
  }

  async function inspectPostgresSwitchTarget() {
    const health = await checkPostgresHealth();
    const payload = {
      ready: false,
      configured: health.configured,
      latencyMs: Number(health.latencyMs || 0),
      detail: health.detail || '',
      tableCount: 0,
      usersTableExists: false
    };

    if (!health.ready) return payload;

    try {
      const tableCountResult = await pgQuery(
        "SELECT CAST(COUNT(*) AS INTEGER) AS cnt FROM information_schema.tables WHERE table_schema = 'public'"
      );
      const usersTableResult = await pgQuery(
        "SELECT CAST(COUNT(*) AS INTEGER) AS cnt FROM information_schema.tables WHERE table_schema = 'public' AND table_name IN ('uyeler', 'users')"
      );
      payload.tableCount = Number(tableCountResult.rows?.[0]?.cnt || 0);
      payload.usersTableExists = Number(usersTableResult.rows?.[0]?.cnt || 0) > 0;
      if (!payload.usersTableExists) {
        payload.detail = 'PostgreSQL şemasında beklenen kullanıcı tablosu bulunamadı (uyeler/users).';
        return payload;
      }
      payload.ready = true;
      payload.detail = 'ok';
      return payload;
    } catch (err) {
      payload.detail = err?.message || 'PostgreSQL hedef doğrulaması başarısız.';
      return payload;
    }
  }

  async function buildDbDriverSwitchReadiness() {
    const currentDriver = DB_DRIVER_SET.has(dbDriver) ? dbDriver : 'sqlite';
    const targetDriver = resolveDbDriverSwitchTarget(currentDriver);
    const envFile = inspectDbDriverSwitchEnvFile();
    const sqlite = inspectSqliteSwitchTarget(dbPath);
    const postgres = await inspectPostgresSwitchTarget();
    const targetState = targetDriver === 'postgres' ? postgres : sqlite;
    const blockers = [];

    if (!envFile.exists) blockers.push(`Env dosyası bulunamadı: ${envFile.path}`);
    if (!envFile.readable) blockers.push(`Env dosyası okunamıyor: ${envFile.path}`);
    if (!envFile.writable) blockers.push(`Env dosyası yazılamıyor: ${envFile.path}`);
    if (!targetState.ready) blockers.push(`Hedef ${targetDriver} hazır değil: ${targetState.detail || 'unknown'}`);

    return {
      currentDriver,
      targetDriver,
      envFile,
      sqlite,
      postgres,
      blockers
    };
  }

  function quoteEnvValue(value) {
    const raw = String(value ?? '');
    if (!raw) return '';
    if (/^[A-Za-z0-9_./:@%+-]+$/.test(raw)) return raw;
    return `'${raw.replace(/'/g, "'\\''")}'`;
  }

  function writeEnvUpdates(filePath, updates = {}) {
    const originalText = fs.readFileSync(filePath, 'utf-8');
    const newline = originalText.includes('\r\n') ? '\r\n' : '\n';
    const lines = originalText.replace(/\r\n/g, '\n').split('\n');
    const entries = Object.entries(updates).filter(([key]) => String(key || '').trim().length > 0);

    for (const [key, value] of entries) {
      const rendered = `${key}=${quoteEnvValue(value)}`;
      let updated = false;
      for (let i = 0; i < lines.length; i += 1) {
        const line = lines[i];
        if (!line || /^\s*#/.test(line)) continue;
        const eqIndex = line.indexOf('=');
        if (eqIndex <= 0) continue;
        const lineKey = line.slice(0, eqIndex).trim();
        if (lineKey !== key) continue;
        lines[i] = rendered;
        updated = true;
        break;
      }
      if (!updated) {
        lines.push(rendered);
      }
    }

    const normalized = lines.join('\n').replace(/\n+$/, '');
    const nextText = `${normalized}${newline}`;
    const tmpPath = `${filePath}.tmp-${process.pid}-${Date.now()}`;
    fs.writeFileSync(tmpPath, nextText, 'utf-8');
    fs.renameSync(tmpPath, filePath);
  }

  function pgTypeToSqlite(pgType) {
    const t = String(pgType || '').toLowerCase();
    if (t.includes('int') || t === 'bigint' || t === 'smallint' || t === 'integer' || t === 'serial' || t === 'bigserial') return 'INTEGER';
    if (t === 'real' || t.includes('float') || t.includes('double') || t.includes('numeric') || t.includes('decimal')) return 'REAL';
    if (t === 'boolean' || t === 'bool') return 'INTEGER';
    if (t === 'bytea') return 'BLOB';
    return 'TEXT';
  }

  function mapPgDefaultForSqlite(pgDefault) {
    if (pgDefault == null) return null;
    const d = String(pgDefault).trim();
    // Drop sequence defaults (identity columns)
    if (/nextval\(/i.test(d)) return null;
    // Map boolean literals
    if (d.toLowerCase() === 'true') return '1';
    if (d.toLowerCase() === 'false') return '0';
    // Map now() / CURRENT_TIMESTAMP variants
    if (/\bnow\(\)/i.test(d) || /current_timestamp/i.test(d)) return 'CURRENT_TIMESTAMP';
    // Simple quoted strings and numbers pass through
    if (/^'.*'$/.test(d) || /^-?\d+(\.\d+)?$/.test(d)) return d;
    return null;
  }

  function pgValueForSqlite(val) {
    if (val === null || val === undefined) return null;
    if (typeof val === 'boolean') return val ? 1 : 0;
    if (val instanceof Date) return val.toISOString();
    if (typeof val === 'object') return JSON.stringify(val);
    return val;
  }

  async function copyDbDataAcrossDrivers(sourceDriver, targetDriver) {
    if (sourceDriver === targetDriver) throw new Error('Source and target drivers must be different.');
    if (sourceDriver !== 'sqlite' && sourceDriver !== 'postgres') throw new Error(`Unknown source driver: ${sourceDriver}`);
    if (targetDriver !== 'sqlite' && targetDriver !== 'postgres') throw new Error(`Unknown target driver: ${targetDriver}`);

    const BATCH_SIZE = 500;
    const stats = { tables: 0, rows: 0, errors: [] };

    if (sourceDriver === 'sqlite' && targetDriver === 'postgres') {
      const pool = getPgPool ? getPgPool() : null;
      if (!pool) throw new Error('PostgreSQL pool not available. Set DATABASE_URL.');

      const sqliteDb = new Database(dbPath, { readonly: true, fileMustExist: true });
      try {
        const tables = sqliteDb.prepare(
          "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' ORDER BY rowid"
        ).all().map(r => r.name);

        for (const table of tables) {
          try {
            const rows = sqliteDb.prepare(`SELECT * FROM "${table}"`).all();
            if (rows.length === 0) { stats.tables++; continue; }

            const columns = Object.keys(rows[0]);
            const colList = columns.map(c => `"${c}"`).join(', ');

            for (let i = 0; i < rows.length; i += BATCH_SIZE) {
              const batch = rows.slice(i, i + BATCH_SIZE);
              const client = await pool.connect();
              try {
                await client.query('BEGIN');
                try { await client.query('SET LOCAL session_replication_role = replica'); } catch { /* best effort */ }
                for (const row of batch) {
                  const vals = columns.map(c => row[c]);
                  const placeholders = vals.map((_, idx) => `$${idx + 1}`).join(', ');
                  await client.query(
                    `INSERT INTO "${table}" (${colList}) VALUES (${placeholders}) ON CONFLICT DO NOTHING`,
                    vals
                  );
                }
                await client.query('COMMIT');
                stats.rows += batch.length;
              } catch (batchErr) {
                await client.query('ROLLBACK').catch(() => {});
                throw batchErr;
              } finally {
                client.release();
              }
            }
            stats.tables++;
          } catch (tableErr) {
            stats.errors.push({ table, message: tableErr?.message || 'unknown' });
          }
        }

        // Reset PG sequences to avoid ID collisions after copy
        try {
          const seqResult = await pgQuery(`
            SELECT s.relname AS sequence_name, t.relname AS table_name, a.attname AS column_name
            FROM pg_class s
            JOIN pg_depend d ON d.objid = s.oid
            JOIN pg_class t ON t.oid = d.refobjid
            JOIN pg_attribute a ON a.attrelid = t.oid AND a.attnum = d.refobjsubid
            WHERE s.relkind = 'S' AND d.deptype = 'a'
              AND t.relnamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public')
          `);
          for (const seq of (seqResult.rows || [])) {
            try {
              await pgQuery(
                `SELECT setval($1, COALESCE((SELECT MAX("${seq.column_name}") FROM "${seq.table_name}"), 1))`,
                [seq.sequence_name]
              );
            } catch { /* best effort */ }
          }
        } catch { /* best effort */ }

      } finally {
        sqliteDb.close();
      }

    } else if (sourceDriver === 'postgres' && targetDriver === 'sqlite') {
      const tablesResult = await pgQuery(
        "SELECT table_name FROM information_schema.tables WHERE table_schema = 'public' AND table_type = 'BASE TABLE' ORDER BY table_name"
      );
      const tables = tablesResult.rows.map(r => r.table_name);

      // Fetch all column definitions from PostgreSQL upfront
      const colDefsResult = await pgQuery(
        `SELECT table_name, column_name, data_type, is_nullable, column_default
         FROM information_schema.columns
         WHERE table_schema = 'public' AND table_name = ANY($1)
         ORDER BY table_name, ordinal_position`,
        [tables]
      );
      const pgColsByTable = {};
      for (const row of colDefsResult.rows) {
        if (!pgColsByTable[row.table_name]) pgColsByTable[row.table_name] = [];
        pgColsByTable[row.table_name].push(row);
      }

      const sqliteDb = new Database(dbPath, { fileMustExist: true });
      try {
        sqliteDb.pragma('foreign_keys = OFF');
        sqliteDb.pragma('journal_mode = WAL');

        for (const table of tables) {
          try {
            // Sync SQLite schema before inserting: create table or add missing columns
            const pgCols = pgColsByTable[table] || [];
            if (pgCols.length > 0) {
              const sqliteTableRow = sqliteDb.prepare(
                "SELECT name FROM sqlite_master WHERE type='table' AND name=?"
              ).get(table);

              if (!sqliteTableRow) {
                // Create the table in SQLite with mapped column types
                const colDefs = pgCols.map(col => {
                  const sqliteType = pgTypeToSqlite(col.data_type);
                  const nullable = col.is_nullable === 'YES' ? '' : ' NOT NULL';
                  const mappedDefault = col.column_default != null ? mapPgDefaultForSqlite(col.column_default) : null;
                  const def = mappedDefault != null ? ` DEFAULT ${mappedDefault}` : '';
                  return `"${col.column_name}" ${sqliteType}${nullable}${def}`;
                });
                sqliteDb.exec(`CREATE TABLE IF NOT EXISTS "${table}" (${colDefs.join(', ')})`);
              } else {
                // Add any columns that are in PostgreSQL but missing from SQLite
                const existingCols = sqliteDb.prepare(`PRAGMA table_info("${table}")`).all();
                const existingColNames = new Set(existingCols.map(c => c.name));
                for (const col of pgCols) {
                  if (!existingColNames.has(col.column_name)) {
                    const sqliteType = pgTypeToSqlite(col.data_type);
                    // ALTER TABLE ADD COLUMN in SQLite cannot be NOT NULL without a default,
                    // so we always add new columns as nullable here (data will be filled by copy).
                    try {
                      sqliteDb.exec(`ALTER TABLE "${table}" ADD COLUMN "${col.column_name}" ${sqliteType}`);
                    } catch { /* column may already exist via race, ignore */ }
                  }
                }
              }
            }

            const rowsResult = await pgQuery(`SELECT * FROM "${table}"`);
            const rows = rowsResult.rows;
            if (rows.length === 0) { stats.tables++; continue; }

            const columns = Object.keys(rows[0]);
            const colList = columns.map(c => `"${c}"`).join(', ');
            const placeholders = columns.map(() => '?').join(', ');

            const stmt = sqliteDb.prepare(`INSERT OR IGNORE INTO "${table}" (${colList}) VALUES (${placeholders})`);
            const insertBatch = sqliteDb.transaction((batch) => {
              for (const row of batch) {
                stmt.run(columns.map(c => pgValueForSqlite(row[c])));
              }
            });

            for (let i = 0; i < rows.length; i += BATCH_SIZE) {
              insertBatch(rows.slice(i, i + BATCH_SIZE));
              stats.rows += Math.min(BATCH_SIZE, rows.length - i);
            }
            stats.tables++;
          } catch (tableErr) {
            stats.errors.push({ table, message: tableErr?.message || 'unknown' });
          }
        }
      } finally {
        try { sqliteDb.pragma('foreign_keys = ON'); } catch { /* no-op */ }
        sqliteDb.close();
      }
    }

    return stats;
  }

  function scheduleDbDriverSwitchRestart(meta = {}) {
    if (String(process.env.NODE_ENV || '').toLowerCase() === 'test') return;
    const timer = setTimeout(() => {
      writeAppLog('info', 'db_driver_switch_restart', {
        mode: dbDriverSwitchRestartCommand ? 'custom_command' : 'api_process_exit',
        ...meta
      });
      if (dbDriverSwitchRestartCommand) {
        try {
          execFileSync('/bin/sh', ['-lc', dbDriverSwitchRestartCommand], { stdio: 'ignore' });
          return;
        } catch (err) {
          writeAppLog('error', 'db_driver_switch_restart_command_failed', {
            message: err?.message || 'unknown_error'
          });
        }
      }
      try {
        process.kill(process.pid, 'SIGTERM');
      } catch (err) {
        writeAppLog('error', 'db_driver_switch_restart_failed', {
          message: err?.message || 'unknown_error'
        });
      }
    }, dbDriverSwitchRestartDelayMs);
    if (typeof timer?.unref === 'function') timer.unref();
  }

  return {
    dbBackupIncomingDir,
    dbBackupDir,
    dbDriverSwitchEnvFile,
    dbDriverSwitchRestartDelayMs,
    dbDriverSwitchRestartCommand,
    dbDriverSwitchState,
    backupTimestamp,
    listDbBackups,
    createDbBackup,
    restoreDbFromUploadedFile,
    resolveBackupPath,
    buildDbDriverSwitchReadiness,
    buildDbDriverSwitchConfirmText,
    issueDbDriverSwitchChallenge,
    consumeDbDriverSwitchChallenge,
    writeEnvUpdates,
    scheduleDbDriverSwitchRestart,
    copyDbDataAcrossDrivers
  };
}
