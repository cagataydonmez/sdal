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
    scheduleDbDriverSwitchRestart
  };
}
