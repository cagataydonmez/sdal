import fs from 'fs/promises';
import path from 'path';
import os from 'os';
import { ROOT_ADMIN_USERNAME } from './rbacService.js';

export const FACTORY_RESET_CONFIRMATION = 'RESET SDAL';

const REQUIRED_UPLOAD_SUBDIRS = Object.freeze([
  'images',
  'vesikalik',
  'album',
  'posts',
  'stories',
  'groups',
  'verification-proofs',
  'request-attachments'
]);

function normalizeText(value) {
  return String(value || '').trim();
}

function toDbBooleanParam(dbDriver, value) {
  return dbDriver === 'postgres' ? Boolean(value) : (value ? 1 : 0);
}

function quoteIdent(value) {
  return `"${String(value || '').replace(/"/g, '""')}"`;
}

function rowBool(value) {
  return value === true || Number(value || 0) === 1 || ['1', 'true', 'yes', 'evet'].includes(String(value || '').trim().toLowerCase());
}

function rootPasswordFromEnv() {
  const explicit = normalizeText(process.env.ROOT_BOOTSTRAP_PASSWORD);
  if (explicit) return explicit;
  const allowDefault = String(process.env.NODE_ENV || 'development').trim().toLowerCase() !== 'production'
    || String(process.env.ALLOW_DEFAULT_ROOT_BOOTSTRAP_PASSWORD || '').trim().toLowerCase() === 'true';
  return allowDefault ? '12345' : '';
}

function assertSafeUploadDir(uploadDir, appRootDir) {
  const resolved = path.resolve(uploadDir || '');
  const home = path.resolve(os.homedir());
  const appRoot = path.resolve(appRootDir || process.cwd());
  const unsafe = new Set([
    path.parse(resolved).root,
    '/',
    home,
    appRoot,
    path.dirname(appRoot)
  ].map((item) => path.resolve(item)));

  if (!resolved || unsafe.has(resolved)) {
    throw new Error(`Unsafe upload directory refused: ${resolved}`);
  }
  const base = path.basename(resolved).toLowerCase();
  const segments = resolved.split(path.sep).filter(Boolean).map((segment) => segment.toLowerCase());
  const allowedBase = ['uploads', 'media', 'sdal-uploads', 'storage'].includes(base);
  const appOwnedSignal = base === 'uploads'
    || base === 'sdal-uploads'
    || segments.includes('sdal')
    || resolved.toLowerCase().includes(`${path.sep}sdal-`);
  if (segments.length < 2 || !allowedBase || !appOwnedSignal) {
    throw new Error(`Upload directory does not look app-owned: ${resolved}`);
  }
  return resolved;
}

async function listDeleteCandidates(uploadDir) {
  try {
    const entries = await fs.readdir(uploadDir, { withFileTypes: true });
    return entries
      .filter((entry) => !entry.name.startsWith('.'))
      .map((entry) => path.join(uploadDir, entry.name));
  } catch (err) {
    if (err?.code === 'ENOENT') return [];
    throw err;
  }
}

async function recreateUploadTree(uploadDir) {
  await fs.mkdir(uploadDir, { recursive: true });
  for (const subdir of REQUIRED_UPLOAD_SUBDIRS) {
    await fs.mkdir(path.join(uploadDir, subdir), { recursive: true });
  }
}

async function deleteUploads({ uploadDir, appRootDir, dryRun }) {
  const safeUploadDir = assertSafeUploadDir(uploadDir, appRootDir);
  const candidates = await listDeleteCandidates(safeUploadDir);
  if (!dryRun) {
    for (const candidate of candidates) {
      await fs.rm(candidate, { recursive: true, force: true });
    }
    await recreateUploadTree(safeUploadDir);
  }
  return {
    uploadDir: safeUploadDir,
    deletedEntries: candidates.map((item) => path.basename(item)),
    dryRun
  };
}

function uploadDirCandidatesFromEnv() {
  return [
    process.env.SDAL_UPLOADS_DIR,
    process.env.STORAGE_LOCAL_DIR,
    process.env.MEDIA_LOCAL_BASE_PATH
  ].map(normalizeText).filter(Boolean);
}

async function readConfiguredMediaBasePath(sqlGetAsync) {
  try {
    const row = await sqlGetAsync('SELECT local_base_path FROM media_settings WHERE id = 1');
    return normalizeText(row?.local_base_path);
  } catch {
    return '';
  }
}

async function collectUploadDirs({ uploadsDir, sqlGetAsync }) {
  const candidates = [
    uploadsDir,
    ...uploadDirCandidatesFromEnv(),
    await readConfiguredMediaBasePath(sqlGetAsync)
  ].map(normalizeText).filter(Boolean);
  return [...new Set(candidates.map((item) => path.resolve(item)))];
}

async function deleteUploadDirs({ uploadDirs, appRootDir, dryRun }) {
  const results = [];
  for (const uploadDir of uploadDirs) {
    results.push(await deleteUploads({ uploadDir, appRootDir, dryRun }));
  }
  return {
    directories: results,
    deletedEntries: results.flatMap((result) => result.deletedEntries.map((entry) => path.join(result.uploadDir, entry))),
    dryRun
  };
}

async function postgresTables(sqlAllAsync) {
  const rows = await sqlAllAsync(
    `SELECT tablename AS name
     FROM pg_tables
     WHERE schemaname = 'public'
       AND tablename <> 'schema_migrations'
     ORDER BY tablename ASC`
  );
  return (rows || []).map((row) => String(row.name || '')).filter(Boolean);
}

async function sqliteTables(sqlAllAsync) {
  const rows = await sqlAllAsync(
    "SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%' ORDER BY name ASC"
  );
  return (rows || []).map((row) => String(row.name || '')).filter(Boolean);
}

async function wipePostgres({ sqlAllAsync, sqlRunAsync, dryRun }) {
  const tables = await postgresTables(sqlAllAsync);
  if (!dryRun && tables.length) {
    await sqlRunAsync(`TRUNCATE TABLE ${tables.map(quoteIdent).join(', ')} RESTART IDENTITY CASCADE`);
  }
  return { tables, dryRun };
}

async function wipeSqlite({ sqlAllAsync, sqlRunAsync, dryRun }) {
  const tables = await sqliteTables(sqlAllAsync);
  if (!dryRun) {
    await sqlRunAsync('PRAGMA foreign_keys = OFF');
    try {
      for (const table of tables) {
        await sqlRunAsync(`DELETE FROM ${quoteIdent(table)}`);
      }
      await sqlRunAsync('DELETE FROM sqlite_sequence').catch(() => {});
    } finally {
      await sqlRunAsync('PRAGMA foreign_keys = ON');
    }
  }
  return { tables, dryRun };
}

async function createRootAdmin({
  dbDriver,
  sqlGetAsync,
  sqlRunAsync,
  hashPassword,
  rbacService
}) {
  const password = rootPasswordFromEnv();
  if (!password) {
    throw new Error('ROOT_BOOTSTRAP_PASSWORD is required in production for factory reset.');
  }
  const passwordHash = await hashPassword(password);
  const now = new Date().toISOString();

  if (dbDriver === 'postgres') {
    await sqlRunAsync(
      `INSERT INTO users
        (username, password_hash, email, first_name, last_name, activation_token, is_active,
         is_banned, is_profile_initialized, created_at, updated_at, role, legacy_admin_flag,
         is_verified, verification_status, privacy_consent_at, directory_consent_at, graduation_year)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'root', ?, ?, 'approved', ?, ?, ?)`,
      [
        ROOT_ADMIN_USERNAME,
        passwordHash,
        'cagatay.donmez@gmail.com',
        'Cagatay',
        'Donmez',
        'root-bootstrap',
        true,
        false,
        true,
        now,
        now,
        true,
        true,
        now,
        now,
        2000
      ]
    );
    const root = await sqlGetAsync('SELECT id FROM users WHERE lower(username) = lower(?) LIMIT 1', [ROOT_ADMIN_USERNAME]);
    if (root?.id) {
      await sqlRunAsync('UPDATE users SET quick_access_ids_json = ? WHERE id = ?', ['0', root.id]).catch(() => {});
    }
    await sqlRunAsync(
      `UPDATE users
       SET role = 'user', legacy_admin_flag = FALSE, updated_at = ?
       WHERE lower(username) <> lower(?) AND (role IN ('root', 'admin', 'mod') OR legacy_admin_flag = TRUE)`,
      [now, ROOT_ADMIN_USERNAME]
    );
    const adminGroup = await sqlGetAsync("SELECT id FROM permission_groups WHERE name = 'admin' LIMIT 1");
    if (root?.id && adminGroup?.id) {
      await sqlRunAsync(
        `INSERT INTO user_permission_groups (user_id, group_id, assigned_by, created_at, updated_at)
         VALUES (?, ?, ?, ?, ?)`,
        [root.id, adminGroup.id, root.id, now, now]
      );
    }
    return root;
  }

  await sqlRunAsync(
    `INSERT INTO uyeler
      (kadi, sifre, email, isim, soyisim, aktivasyon, aktiv, ilktarih, resim, mezuniyetyili,
       ilkbd, role, admin, verified, verification_status, kvkk_consent_at, directory_consent_at)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'yok', ?, ?, 'root', ?, ?, 'approved', ?, ?)`,
    [
      ROOT_ADMIN_USERNAME,
      passwordHash,
      'cagatay.donmez@gmail.com',
      'Cagatay',
      'Donmez',
      'root-bootstrap',
      toDbBooleanParam(dbDriver, true),
      now,
      '2000',
      toDbBooleanParam(dbDriver, true),
      toDbBooleanParam(dbDriver, true),
      toDbBooleanParam(dbDriver, true),
      now,
      now
    ]
  );
  const root = await sqlGetAsync('SELECT id FROM uyeler WHERE lower(kadi) = lower(?) LIMIT 1', [ROOT_ADMIN_USERNAME]);
  if (root?.id) {
    await sqlRunAsync('UPDATE uyeler SET hizliliste = ? WHERE id = ?', ['0', root.id]).catch(() => {});
  }
  await sqlRunAsync(
    `UPDATE uyeler
     SET role = 'user', admin = 0
     WHERE lower(kadi) <> lower(?) AND (role IN ('root', 'admin', 'mod') OR admin = 1)`,
    [ROOT_ADMIN_USERNAME]
  );
  const adminGroup = await sqlGetAsync("SELECT id FROM permission_groups WHERE name = 'admin' LIMIT 1");
  if (root?.id && adminGroup?.id) {
    const nowAssign = new Date().toISOString();
    await sqlRunAsync(
      `INSERT INTO user_permission_groups (user_id, group_id, assigned_by, created_at, updated_at)
       VALUES (?, ?, ?, ?, ?)`,
      [root.id, adminGroup.id, root.id, nowAssign, nowAssign]
    );
  }
  return root;
}

async function writeResetAudit({ dbDriver, sqlRunAsync, actorSnapshot, rootUserId, dryRun, uploadResult, backupResult }) {
  const now = new Date().toISOString();
  const metadata = {
    dryRun,
    actorBeforeReset: actorSnapshot,
    uploadResult,
    backup: backupResult || null
  };
  if (dbDriver === 'postgres') {
    await sqlRunAsync(
      `INSERT INTO audit_logs (actor_user_id, action, target_type, target_id, metadata, ip, user_agent, created_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
      [rootUserId || null, dryRun ? 'factory_reset_dry_run' : 'factory_reset', 'system', 'factory-reset', JSON.stringify(metadata), actorSnapshot?.ip || null, actorSnapshot?.userAgent || 'system', now]
    );
    return;
  }
  await sqlRunAsync(
    `CREATE TABLE IF NOT EXISTS audit_log (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      actor_user_id INTEGER,
      action TEXT NOT NULL,
      target_type TEXT,
      target_id TEXT,
      metadata TEXT,
      ip TEXT,
      user_agent TEXT,
      created_at TEXT
    )`
  );
  await sqlRunAsync(
    `INSERT INTO audit_log (actor_user_id, action, target_type, target_id, metadata, ip, user_agent, created_at)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
    [rootUserId || null, dryRun ? 'factory_reset_dry_run' : 'factory_reset', 'system', 'factory-reset', JSON.stringify(metadata), actorSnapshot?.ip || null, actorSnapshot?.userAgent || 'system', now]
  );
}

export function createFactoryResetService({
  dbDriver,
  appRootDir,
  uploadsDir,
  sqlAllAsync,
  sqlGetAsync,
  sqlRunAsync,
  hashPassword,
  rbacService,
  seedRuntimeDefaults,
  createDbBackup,
  clearRuntimeCaches,
  writeAppLog = () => {}
}) {
  async function performFactoryReset({ actor, ip, userAgent, dryRun = false } = {}) {
    const actorSnapshot = {
      id: actor?.id || null,
      username: actor?.kadi || actor?.username || null,
      role: actor?.role || null,
      ip,
      userAgent
    };
    writeAppLog('warn', dryRun ? 'factory_reset_dry_run_started' : 'factory_reset_started', { actor: actorSnapshot });

    const tablePlan = dbDriver === 'postgres'
      ? await postgresTables(sqlAllAsync)
      : await sqliteTables(sqlAllAsync);
    const uploadDirs = await collectUploadDirs({ uploadsDir, sqlGetAsync });
    const uploadPlan = await deleteUploadDirs({ uploadDirs, appRootDir, dryRun: true });
    if (dryRun) {
      await writeResetAudit({
        dbDriver,
        sqlRunAsync,
        actorSnapshot,
        rootUserId: actor?.id || null,
        dryRun: true,
        uploadResult: uploadPlan,
        backupResult: null
      });
      return {
        dryRun: true,
        tables: tablePlan,
        uploads: uploadPlan,
        rootUsername: ROOT_ADMIN_USERNAME
      };
    }

    if (!rootPasswordFromEnv()) {
      throw new Error('ROOT_BOOTSTRAP_PASSWORD is required in production for factory reset.');
    }

    let backupResult = null;
    if (typeof createDbBackup === 'function') {
      try {
        backupResult = await createDbBackup('pre-factory-reset');
      } catch (err) {
        backupResult = { ok: false, error: err?.message || String(err) };
        writeAppLog('error', 'factory_reset_backup_failed', backupResult);
      }
    }

    const wipeResult = dbDriver === 'postgres'
      ? await wipePostgres({ sqlAllAsync, sqlRunAsync, dryRun: false })
      : await wipeSqlite({ sqlAllAsync, sqlRunAsync, dryRun: false });

    const memberTable = dbDriver === 'postgres' ? 'users' : 'uyeler';
    const remainingRow = await sqlGetAsync(`SELECT COUNT(*) AS cnt FROM ${quoteIdent(memberTable)}`).catch(() => null);
    const remaining = Number(remainingRow?.cnt ?? remainingRow?.count ?? 0);
    if (remaining > 0) {
      throw new Error(`Wipe failed: ${remaining} row(s) still present in ${memberTable} after wipe.`);
    }

    if (typeof seedRuntimeDefaults === 'function') {
      await seedRuntimeDefaults();
    }
    await rbacService.seedDefaults();
    const root = await createRootAdmin({
      dbDriver,
      sqlGetAsync,
      sqlRunAsync,
      hashPassword,
      rbacService
    });
    const uploadResult = await deleteUploadDirs({ uploadDirs, appRootDir, dryRun: false });
    if (typeof clearRuntimeCaches === 'function') {
      await clearRuntimeCaches();
    }
    await writeResetAudit({
      dbDriver,
      sqlRunAsync,
      actorSnapshot,
      rootUserId: root?.id || null,
      dryRun: false,
      uploadResult,
      backupResult
    });

    writeAppLog('warn', 'factory_reset_completed', {
      actor: actorSnapshot,
      rootUserId: root?.id || null,
      tableCount: wipeResult.tables.length,
      uploads: uploadResult.deletedEntries.length,
      uploadDirectories: uploadResult.directories.map((item) => item.uploadDir),
      backup: backupResult
    });

    return {
      dryRun: false,
      tables: wipeResult.tables,
      uploads: uploadResult,
      rootUsername: ROOT_ADMIN_USERNAME,
      backup: backupResult,
      temporaryPasswordSource: normalizeText(process.env.ROOT_BOOTSTRAP_PASSWORD) ? 'ROOT_BOOTSTRAP_PASSWORD' : 'development-default'
    };
  }

  async function verifyCurrentPassword(user, password, verifyPassword) {
    const stored = user?.sifre || user?.password_hash || '';
    if (!stored) return false;
    const result = await verifyPassword(stored, password);
    return rowBool(result?.ok);
  }

  return {
    performFactoryReset,
    verifyCurrentPassword
  };
}
