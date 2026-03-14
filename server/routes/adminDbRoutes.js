import fs from 'fs';
import path from 'path';

export function registerAdminDbRoutes(app, {
  dbDriver,
  dbPath,
  requireAdmin,
  dbBackupUpload,
  validateUploadedFileSafety,
  cleanupUploadedFile,
  logAdminAction,
  writeAppLog,
  runtime
}) {
  app.get('/api/new/admin/db/backups', requireAdmin, (_req, res) => {
    res.json({
      items: runtime.listDbBackups(),
      dbPath,
      dbDriver
    });
  });

  app.get('/api/new/admin/db/driver/status', requireAdmin, async (req, res) => {
    try {
      const readiness = await runtime.buildDbDriverSwitchReadiness();
      const expectedConfirmText = runtime.buildDbDriverSwitchConfirmText(readiness.currentDriver, readiness.targetDriver);
      const challenge = runtime.issueDbDriverSwitchChallenge(req, readiness.targetDriver);
      const requiresSqliteDriftAck = readiness.currentDriver === 'postgres' && readiness.targetDriver === 'sqlite';
      const warnings = [];
      if (requiresSqliteDriftAck) {
        warnings.push('PostgreSQL -> SQLite geçişinde otomatik veri kopyalama yapılmaz; mevcut SQLite dosyası kullanılacaktır.');
      }
      warnings.push('Geçiş sırasında API işlemi yeniden başlatılır. Worker servisi için ayrıca restart önerilir.');

      res.json({
        currentDriver: readiness.currentDriver,
        targetDriver: readiness.targetDriver,
        expectedConfirmText,
        challengeToken: challenge.token,
        challengeExpiresAt: new Date(challenge.expiresAt).toISOString(),
        inProgress: runtime.dbDriverSwitchState.inProgress,
        switchEnabled: !runtime.dbDriverSwitchState.inProgress && readiness.blockers.length === 0,
        blockers: readiness.blockers,
        warnings,
        requiresSqliteDriftAck,
        envFile: readiness.envFile,
        sqlite: readiness.sqlite,
        postgres: readiness.postgres,
        restart: {
          mode: runtime.dbDriverSwitchRestartCommand ? 'custom_command' : 'api_process_exit',
          commandConfigured: Boolean(runtime.dbDriverSwitchRestartCommand),
          delayMs: runtime.dbDriverSwitchRestartDelayMs
        },
        lastSwitch: runtime.dbDriverSwitchState.lastSwitch,
        lastAttemptAt: runtime.dbDriverSwitchState.lastAttemptAt,
        lastSuccessAt: runtime.dbDriverSwitchState.lastSuccessAt,
        lastError: runtime.dbDriverSwitchState.lastError
      });
    } catch (err) {
      writeAppLog('error', 'db_driver_switch_status_failed', { message: err?.message || 'unknown_error' });
      res.status(500).send(err?.message || 'DB driver durumu okunamadı.');
    }
  });

  app.post('/api/new/admin/db/driver/switch', requireAdmin, async (req, res) => {
    if (runtime.dbDriverSwitchState.inProgress) {
      return res.status(409).send('DB driver geçişi zaten devam ediyor.');
    }

    const startedAt = new Date().toISOString();
    runtime.dbDriverSwitchState.inProgress = true;
    runtime.dbDriverSwitchState.lastAttemptAt = startedAt;
    runtime.dbDriverSwitchState.lastError = null;

    let envBackupName = '';
    let envUpdated = false;
    try {
      const readiness = await runtime.buildDbDriverSwitchReadiness();
      const targetDriver = readiness.targetDriver;
      const expectedConfirmText = runtime.buildDbDriverSwitchConfirmText(readiness.currentDriver, targetDriver);
      const requestedTarget = String(req.body?.targetDriver || '').trim().toLowerCase();
      const confirmText = String(req.body?.confirmText || '').trim();
      const challengeToken = String(req.body?.challengeToken || '').trim();
      const acknowledgeSqliteDrift = req.body?.acknowledgeSqliteDrift === true;

      if (requestedTarget && requestedTarget !== targetDriver) {
        return res.status(400).send(`Bu oturumda geçerli hedef driver ${targetDriver}.`);
      }
      if (confirmText !== expectedConfirmText) {
        return res.status(400).send(`Onay metni eşleşmedi. Beklenen: ${expectedConfirmText}`);
      }
      if (!runtime.consumeDbDriverSwitchChallenge(req, targetDriver, challengeToken)) {
        return res.status(400).send('Geçiş onayı geçersiz veya süresi dolmuş. Yenileyip tekrar deneyin.');
      }
      if (readiness.currentDriver === 'postgres' && targetDriver === 'sqlite' && !acknowledgeSqliteDrift) {
        return res.status(400).send('PostgreSQL -> SQLite geçişi için veri farklılığı onay kutusu zorunludur.');
      }
      if (readiness.blockers.length > 0) {
        return res.status(400).json({
          ok: false,
          blockers: readiness.blockers
        });
      }

      const stamp = runtime.backupTimestamp();
      envBackupName = `sdal-env-pre-driver-switch-${stamp}-${readiness.currentDriver}-to-${targetDriver}.env`;
      const envBackupPath = path.join(runtime.dbBackupDir, envBackupName);
      fs.copyFileSync(runtime.dbDriverSwitchEnvFile, envBackupPath);

      const backup = await runtime.createDbBackup(`pre-switch-${readiness.currentDriver}-to-${targetDriver}`);

      const envUpdates = { SDAL_DB_DRIVER: targetDriver };
      if (targetDriver === 'sqlite') {
        envUpdates.SDAL_DB_PATH = dbPath;
      }
      runtime.writeEnvUpdates(runtime.dbDriverSwitchEnvFile, envUpdates);
      envUpdated = true;

      const result = {
        switchedFrom: readiness.currentDriver,
        switchedTo: targetDriver,
        envFile: runtime.dbDriverSwitchEnvFile,
        envBackup: envBackupName,
        preSwitchBackup: backup?.name || null,
        requestedBy: req.session?.userId || null,
        at: new Date().toISOString()
      };
      runtime.dbDriverSwitchState.lastSwitch = result;
      runtime.dbDriverSwitchState.lastSuccessAt = result.at;
      logAdminAction(req, 'db_driver_switch', result);

      res.json({
        ok: true,
        message: `DB driver ${targetDriver} olarak güncellendi. Servis yeniden başlatılıyor.`,
        result,
        restart: {
          mode: runtime.dbDriverSwitchRestartCommand ? 'custom_command' : 'api_process_exit',
          commandConfigured: Boolean(runtime.dbDriverSwitchRestartCommand),
          delayMs: runtime.dbDriverSwitchRestartDelayMs
        },
        note: 'Worker servisi farklı process olduğu için ayrıca restart edilmesi önerilir.'
      });

      runtime.scheduleDbDriverSwitchRestart({
        switchedFrom: readiness.currentDriver,
        switchedTo: targetDriver,
        userId: req.session?.userId || null
      });
    } catch (err) {
      if (envUpdated && envBackupName) {
        try {
          fs.copyFileSync(path.join(runtime.dbBackupDir, envBackupName), runtime.dbDriverSwitchEnvFile);
        } catch {
          // best effort rollback
        }
      }
      runtime.dbDriverSwitchState.lastError = err?.message || 'unknown_error';
      writeAppLog('error', 'db_driver_switch_failed', {
        message: err?.message || 'unknown_error',
        stack: err?.stack || ''
      });
      res.status(500).send(err?.message || 'DB driver geçişi başarısız.');
    } finally {
      runtime.dbDriverSwitchState.inProgress = false;
    }
  });

  app.post('/api/new/admin/db/backups', requireAdmin, async (req, res) => {
    try {
      const label = String(req.body?.label || 'manual');
      const backup = await runtime.createDbBackup(label);
      logAdminAction(req, 'db_backup_create', { file: backup.name, size: backup.size });
      res.json({ ok: true, backup });
    } catch (err) {
      writeAppLog('error', 'db_backup_create_failed', { message: err?.message || 'unknown' });
      res.status(500).send(err?.message || 'Yedek oluşturulamadı.');
    }
  });

  app.get('/api/new/admin/db/backups/:name/download', requireAdmin, (req, res) => {
    const fullPath = runtime.resolveBackupPath(req.params.name || '');
    if (!fullPath || !fs.existsSync(fullPath)) return res.status(404).send('Yedek dosyası bulunamadı.');
    logAdminAction(req, 'db_backup_download', { file: path.basename(fullPath) });
    res.download(fullPath, path.basename(fullPath));
  });

  app.post('/api/new/admin/db/restore', requireAdmin, dbBackupUpload.single('backup'), (req, res) => {
    try {
      if (!req.file?.path) return res.status(400).send('Yedek dosyası gerekli.');
      const backupValidation = validateUploadedFileSafety(req.file.path, { allowedMimes: [] });
      if (!backupValidation.ok) {
        cleanupUploadedFile(req.file.path);
        return res.status(400).send(backupValidation.reason);
      }
      const restored = runtime.restoreDbFromUploadedFile(req.file.path);
      logAdminAction(req, 'db_restore', {
        sourceName: String(req.file.originalname || ''),
        uploadedFile: restored.uploadedName,
        preRestoreBackup: restored.preRestoreName
      });
      res.json({ ok: true, restored });
    } catch (err) {
      writeAppLog('error', 'db_restore_failed', { message: err?.message || 'unknown' });
      res.status(500).send(err?.message || 'Geri yükleme başarısız.');
    } finally {
      try {
        if (req.file?.path && fs.existsSync(req.file.path)) fs.unlinkSync(req.file.path);
      } catch {
        // no-op
      }
    }
  });
}
