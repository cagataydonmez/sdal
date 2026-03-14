export function registerNotificationRoutes(app, {
  requireAuth,
  requireAdmin,
  sqlGetAsync,
  sqlAllAsync,
  sqlRun,
  sqlRunAsync,
  ensureNotificationIndexes,
  normalizeNotificationSortMode,
  parseNotificationCursor,
  buildNotificationSortBucketSql,
  buildNotificationOrderSql,
  enrichNotificationRows,
  buildNotificationCursor,
  apiSuccessEnvelope,
  sendApiError,
  normalizeNotificationTelemetryEventName,
  recordNotificationTelemetryEvent,
  readNotificationPreferenceRow,
  mapNotificationPreferenceResponse,
  getNotificationExperimentAssignments,
  readNotificationExperimentConfigs,
  ensureNotificationPreferencesTable,
  notificationPreferenceCategoryKeys,
  getNotificationCategory,
  getNotificationPriority,
  getNotificationDedupeRule,
  notificationGovernanceChecklist,
  ensureNotificationExperimentConfigsTable,
  ensureNotificationDeliveryAuditTable,
  ensureNotificationTelemetryEventsTable,
  parseNetworkWindowDays,
  toIsoThreshold,
  notificationTypeInventory
}) {
  app.get('/api/new/notifications', requireAuth, async (req, res) => {
    try {
      ensureNotificationIndexes();
      const limit = Math.min(Math.max(parseInt(req.query.limit || '20', 10), 1), 100);
      const sort = normalizeNotificationSortMode(req.query.sort || 'priority');
      const cursor = parseNotificationCursor(req.query.cursor || '', sort);

      const whereParts = ['n.user_id = ?'];
      const params = [req.session.userId];
      if (cursor?.id > 0 && sort === 'priority' && Number.isFinite(cursor.bucket)) {
        const bucketSql = buildNotificationSortBucketSql('n');
        whereParts.push(`(${bucketSql} > ? OR (${bucketSql} = ? AND n.id < ?))`);
        params.push(cursor.bucket, cursor.bucket, cursor.id);
      } else if (cursor?.id > 0) {
        whereParts.push('n.id < ?');
        params.push(cursor.id);
      }

      const rows = await sqlAllAsync(
        `SELECT n.id, n.type, n.entity_id, n.source_user_id, n.message, n.read_at, n.created_at,
                u.kadi, u.isim, u.soyisim, u.resim, u.verified
         FROM notifications n
         LEFT JOIN uyeler u ON u.id = n.source_user_id
         WHERE ${whereParts.join(' AND ')}
         ${buildNotificationOrderSql(sort)}
         LIMIT ?`,
        [...params, limit + 1]
      );
      const slice = rows.slice(0, limit);
      const items = await enrichNotificationRows(slice, req.session.userId);
      const nextCursor = rows.length > limit ? buildNotificationCursor(slice[slice.length - 1], sort) : null;
      res.json(apiSuccessEnvelope(
        'NOTIFICATIONS_LIST_OK',
        'Bildirimler listelendi.',
        { items, hasMore: rows.length > limit, next_cursor: nextCursor },
        { items, hasMore: rows.length > limit, next_cursor: nextCursor }
      ));
    } catch (err) {
      console.error('notifications.list failed:', err);
      res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.get('/api/new/notifications/unread', requireAuth, async (req, res) => {
    try {
      ensureNotificationIndexes();
      const row = await sqlGetAsync('SELECT COUNT(*) AS cnt FROM notifications WHERE user_id = ? AND read_at IS NULL', [req.session.userId]);
      res.json({ count: Number(row?.cnt || 0) });
    } catch (err) {
      console.error('notifications.unread failed:', err);
      res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.post('/api/new/notifications/read', requireAuth, async (req, res) => {
    try {
      await sqlRunAsync('UPDATE notifications SET read_at = ? WHERE user_id = ? AND read_at IS NULL', [
        new Date().toISOString(),
        req.session.userId
      ]);
      res.json({ ok: true });
    } catch (err) {
      console.error('notifications.read failed:', err);
      res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.post('/api/new/notifications/bulk-read', requireAuth, async (req, res) => {
    try {
      const ids = Array.isArray(req.body?.ids)
        ? Array.from(new Set(req.body.ids.map((value) => Number(value)).filter((value) => Number.isFinite(value) && value > 0)))
        : [];
      const now = new Date().toISOString();
      let result = null;
      if (ids.length > 0) {
        result = await sqlRunAsync(
          `UPDATE notifications
           SET read_at = COALESCE(read_at, ?)
           WHERE user_id = ?
             AND id IN (${ids.map(() => '?').join(',')})`,
          [now, req.session.userId, ...ids]
        );
      } else {
        result = await sqlRunAsync(
          'UPDATE notifications SET read_at = COALESCE(read_at, ?) WHERE user_id = ? AND read_at IS NULL',
          [now, req.session.userId]
        );
      }
      return res.json(apiSuccessEnvelope(
        'NOTIFICATIONS_BULK_READ_OK',
        'Bildirimler okundu olarak işaretlendi.',
        { updated: Number(result?.changes || 0) },
        { updated: Number(result?.changes || 0) }
      ));
    } catch (err) {
      console.error('notifications.bulkRead failed:', err);
      return sendApiError(res, 500, 'NOTIFICATIONS_BULK_READ_FAILED', 'Beklenmeyen bir hata oluştu.');
    }
  });

  app.post('/api/new/notifications/:id/read', requireAuth, async (req, res) => {
    try {
      const notificationId = Number(req.params.id || 0);
      if (!notificationId) return sendApiError(res, 400, 'INVALID_NOTIFICATION_ID', 'Geçersiz bildirim kimliği.');
      const row = await sqlGetAsync(
        `SELECT n.id, n.user_id, n.type, n.entity_id, n.source_user_id, n.message, n.read_at, n.created_at,
                u.kadi, u.isim, u.soyisim, u.resim, u.verified
         FROM notifications n
         LEFT JOIN uyeler u ON u.id = n.source_user_id
         WHERE n.id = ? AND n.user_id = ?`,
        [notificationId, req.session.userId]
      );
      if (!row) return sendApiError(res, 404, 'NOTIFICATION_NOT_FOUND', 'Bildirim bulunamadı.');
      const now = new Date().toISOString();
      if (!row.read_at) {
        await sqlRunAsync('UPDATE notifications SET read_at = ? WHERE id = ? AND user_id = ?', [now, notificationId, req.session.userId]);
      }
      const [item] = await enrichNotificationRows([{ ...row, read_at: row.read_at || now }], req.session.userId);
      return res.json(apiSuccessEnvelope(
        'NOTIFICATION_MARKED_READ',
        'Bildirim okundu olarak işaretlendi.',
        { item },
        { item }
      ));
    } catch (err) {
      console.error('notifications.readOne failed:', err);
      return sendApiError(res, 500, 'NOTIFICATION_MARK_READ_FAILED', 'Beklenmeyen bir hata oluştu.');
    }
  });

  app.post('/api/new/notifications/:id/open', requireAuth, async (req, res) => {
    try {
      const notificationId = Number(req.params.id || 0);
      if (!notificationId) return sendApiError(res, 400, 'INVALID_NOTIFICATION_ID', 'Geçersiz bildirim kimliği.');
      const row = await sqlGetAsync(
        `SELECT n.id, n.user_id, n.type, n.entity_id, n.source_user_id, n.message, n.read_at, n.created_at,
                u.kadi, u.isim, u.soyisim, u.resim, u.verified
         FROM notifications n
         LEFT JOIN uyeler u ON u.id = n.source_user_id
         WHERE n.id = ? AND n.user_id = ?`,
        [notificationId, req.session.userId]
      );
      if (!row) return sendApiError(res, 404, 'NOTIFICATION_NOT_FOUND', 'Bildirim bulunamadı.');
      const now = new Date().toISOString();
      if (!row.read_at) {
        await sqlRunAsync('UPDATE notifications SET read_at = ? WHERE id = ? AND user_id = ?', [now, notificationId, req.session.userId]);
      }
      const [item] = await enrichNotificationRows([{ ...row, read_at: row.read_at || now }], req.session.userId);
      return res.json(apiSuccessEnvelope(
        'NOTIFICATION_OPENED',
        'Bildirim açıldı.',
        { item, target: item?.target || null },
        { item, target: item?.target || null }
      ));
    } catch (err) {
      console.error('notifications.open failed:', err);
      return sendApiError(res, 500, 'NOTIFICATION_OPEN_FAILED', 'Beklenmeyen bir hata oluştu.');
    }
  });

  app.post('/api/new/notifications/telemetry', requireAuth, async (req, res) => {
    try {
      const rawEvents = Array.isArray(req.body?.events) ? req.body.events : [req.body];
      const accepted = [];
      for (const rawEvent of rawEvents) {
        const notificationId = Number(rawEvent?.notification_id || 0);
        const eventName = normalizeNotificationTelemetryEventName(rawEvent?.event_name);
        if (!eventName) continue;
        let notificationType = String(rawEvent?.notification_type || '').trim().toLowerCase();
        if (notificationId > 0) {
          const notificationRow = await sqlGetAsync(
            'SELECT id, type FROM notifications WHERE id = ? AND user_id = ?',
            [notificationId, req.session.userId]
          );
          if (!notificationRow) continue;
          if (!notificationType) notificationType = String(notificationRow.type || '').trim().toLowerCase();
        }
        const didRecord = recordNotificationTelemetryEvent({
          userId: req.session.userId,
          notificationId: notificationId || null,
          eventName,
          notificationType,
          surface: rawEvent?.surface,
          actionKind: rawEvent?.action_kind
        });
        if (didRecord) {
          accepted.push({
            notification_id: notificationId || null,
            event_name: eventName
          });
        }
      }
      return res.json(apiSuccessEnvelope(
        'NOTIFICATION_TELEMETRY_RECORDED',
        'Notification telemetry kaydedildi.',
        { accepted_count: accepted.length, items: accepted },
        { accepted_count: accepted.length, items: accepted }
      ));
    } catch (err) {
      console.error('notifications.telemetry failed:', err);
      return sendApiError(res, 500, 'NOTIFICATION_TELEMETRY_FAILED', 'Beklenmeyen bir hata oluştu.');
    }
  });

  app.get('/api/new/notifications/preferences', requireAuth, (req, res) => {
    try {
      const row = readNotificationPreferenceRow(req.session.userId);
      const preferences = mapNotificationPreferenceResponse(row);
      return res.json(apiSuccessEnvelope(
        'NOTIFICATION_PREFERENCES_OK',
        'Bildirim tercihleri hazır.',
        {
          preferences,
          experiments: {
            assignments: getNotificationExperimentAssignments(req.session.userId),
            configs: readNotificationExperimentConfigs()
          }
        },
        {
          preferences,
          experiments: {
            assignments: getNotificationExperimentAssignments(req.session.userId),
            configs: readNotificationExperimentConfigs()
          }
        }
      ));
    } catch (err) {
      console.error('notifications.preferences.get failed:', err);
      return sendApiError(res, 500, 'NOTIFICATION_PREFERENCES_GET_FAILED', 'Beklenmeyen bir hata oluştu.');
    }
  });

  app.put('/api/new/notifications/preferences', requireAuth, (req, res) => {
    try {
      ensureNotificationPreferencesTable();
      const userId = Number(req.session?.userId || 0);
      const current = readNotificationPreferenceRow(userId);
      const patch = req.body?.categories && typeof req.body.categories === 'object' ? req.body.categories : {};
      const quietMode = req.body?.quiet_mode && typeof req.body.quiet_mode === 'object' ? req.body.quiet_mode : {};
      const nextRow = {
        ...current,
        updated_at: new Date().toISOString()
      };
      for (const key of notificationPreferenceCategoryKeys) {
        if (Object.prototype.hasOwnProperty.call(patch, key)) {
          nextRow[`${key}_enabled`] = patch[key] ? 1 : 0;
        }
      }
      if (Object.prototype.hasOwnProperty.call(quietMode, 'enabled')) {
        nextRow.quiet_mode_enabled = quietMode.enabled ? 1 : 0;
      }
      if (Object.prototype.hasOwnProperty.call(quietMode, 'start')) {
        nextRow.quiet_mode_start = quietMode.start ? String(quietMode.start).trim() : null;
      }
      if (Object.prototype.hasOwnProperty.call(quietMode, 'end')) {
        nextRow.quiet_mode_end = quietMode.end ? String(quietMode.end).trim() : null;
      }
      sqlRun(
        `INSERT INTO notification_user_preferences
           (user_id, social_enabled, messaging_enabled, groups_enabled, events_enabled, networking_enabled, jobs_enabled, system_enabled, quiet_mode_enabled, quiet_mode_start, quiet_mode_end, updated_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
         ON CONFLICT(user_id) DO UPDATE SET
           social_enabled = excluded.social_enabled,
           messaging_enabled = excluded.messaging_enabled,
           groups_enabled = excluded.groups_enabled,
           events_enabled = excluded.events_enabled,
           networking_enabled = excluded.networking_enabled,
           jobs_enabled = excluded.jobs_enabled,
           system_enabled = excluded.system_enabled,
           quiet_mode_enabled = excluded.quiet_mode_enabled,
           quiet_mode_start = excluded.quiet_mode_start,
           quiet_mode_end = excluded.quiet_mode_end,
           updated_at = excluded.updated_at`,
        [
          userId,
          Number(nextRow.social_enabled || 0),
          Number(nextRow.messaging_enabled || 0),
          Number(nextRow.groups_enabled || 0),
          Number(nextRow.events_enabled || 0),
          Number(nextRow.networking_enabled || 0),
          Number(nextRow.jobs_enabled || 0),
          Number(nextRow.system_enabled || 0),
          Number(nextRow.quiet_mode_enabled || 0),
          nextRow.quiet_mode_start || null,
          nextRow.quiet_mode_end || null,
          nextRow.updated_at
        ]
      );
      const preferences = mapNotificationPreferenceResponse(nextRow);
      return res.json(apiSuccessEnvelope(
        'NOTIFICATION_PREFERENCES_UPDATED',
        'Bildirim tercihleri güncellendi.',
        { preferences },
        { preferences }
      ));
    } catch (err) {
      console.error('notifications.preferences.update failed:', err);
      return sendApiError(res, 500, 'NOTIFICATION_PREFERENCES_UPDATE_FAILED', 'Beklenmeyen bir hata oluştu.');
    }
  });

  app.get('/api/new/admin/notifications/governance', requireAdmin, (_req, res) => {
    try {
      const inventory = notificationTypeInventory.sort().map((type) => ({
        type,
        category: getNotificationCategory(type),
        priority: getNotificationPriority(type),
        has_dedupe_rule: Boolean(getNotificationDedupeRule(type))
      }));
      return res.json(apiSuccessEnvelope(
        'ADMIN_NOTIFICATIONS_GOVERNANCE_OK',
        'Notification governance policy hazır.',
        { checklist: notificationGovernanceChecklist, inventory },
        { checklist: notificationGovernanceChecklist, inventory }
      ));
    } catch (err) {
      console.error('admin.notifications.governance failed:', err);
      return sendApiError(res, 500, 'ADMIN_NOTIFICATIONS_GOVERNANCE_FAILED', 'Beklenmeyen bir hata oluştu.');
    }
  });

  app.get('/api/new/admin/notifications/experiments', requireAdmin, (_req, res) => {
    try {
      const configs = readNotificationExperimentConfigs();
      return res.json(apiSuccessEnvelope(
        'ADMIN_NOTIFICATIONS_EXPERIMENTS_OK',
        'Notification experiment ayarları hazır.',
        { items: configs },
        { items: configs }
      ));
    } catch (err) {
      console.error('admin.notifications.experiments.list failed:', err);
      return sendApiError(res, 500, 'ADMIN_NOTIFICATIONS_EXPERIMENTS_FAILED', 'Beklenmeyen bir hata oluştu.');
    }
  });

  app.put('/api/new/admin/notifications/experiments/:key', requireAdmin, (req, res) => {
    try {
      ensureNotificationExperimentConfigsTable();
      const experimentKey = String(req.params.key || '').trim();
      const existing = readNotificationExperimentConfigs().find((item) => item.key === experimentKey);
      if (!existing) {
        return sendApiError(res, 404, 'ADMIN_NOTIFICATIONS_EXPERIMENT_NOT_FOUND', 'Experiment bulunamadı.');
      }
      const status = String(req.body?.status || existing.status).trim().toLowerCase() === 'paused' ? 'paused' : 'active';
      const rawVariants = Array.isArray(req.body?.variants)
        ? req.body.variants
        : String(req.body?.variants || '').split(',');
      const variants = rawVariants.map((item) => String(item || '').trim()).filter(Boolean);
      const safeVariants = variants.length ? variants : existing.variants;
      sqlRun(
        `UPDATE notification_experiment_configs
         SET status = ?, variants_json = ?, updated_at = ?
         WHERE experiment_key = ?`,
        [status, JSON.stringify(safeVariants), new Date().toISOString(), experimentKey]
      );
      const item = readNotificationExperimentConfigs().find((row) => row.key === experimentKey) || existing;
      return res.json(apiSuccessEnvelope(
        'ADMIN_NOTIFICATIONS_EXPERIMENT_UPDATED',
        'Notification experiment ayarı güncellendi.',
        { item },
        { item }
      ));
    } catch (err) {
      console.error('admin.notifications.experiments.update failed:', err);
      return sendApiError(res, 500, 'ADMIN_NOTIFICATIONS_EXPERIMENT_UPDATE_FAILED', 'Beklenmeyen bir hata oluştu.');
    }
  });

  app.get('/api/new/admin/notifications/ops', requireAdmin, async (req, res) => {
    try {
      ensureNotificationDeliveryAuditTable();
      ensureNotificationTelemetryEventsTable();
      ensureNotificationPreferencesTable();
      const windowDays = parseNetworkWindowDays(req.query.window);
      const sinceIso = toIsoThreshold(windowDays);
      const day1Iso = new Date(Date.now() - (24 * 60 * 60 * 1000)).toISOString();
      const day7Iso = new Date(Date.now() - (7 * 24 * 60 * 60 * 1000)).toISOString();

      const [deliveryRows, telemetryRows, unreadRows, noisyRows, quietModeRow] = await Promise.all([
        sqlAllAsync(
          `SELECT notification_type, delivery_status, COUNT(*) AS cnt
           FROM notification_delivery_audit
           WHERE created_at >= ?
           GROUP BY notification_type, delivery_status
           ORDER BY cnt DESC, notification_type ASC`,
          [sinceIso]
        ),
        sqlAllAsync(
          `SELECT COALESCE(surface, 'unknown') AS surface, event_name, COUNT(*) AS cnt
           FROM notification_telemetry_events
           WHERE created_at >= ?
           GROUP BY COALESCE(surface, 'unknown'), event_name
           ORDER BY surface ASC, event_name ASC`,
          [sinceIso]
        ),
        sqlAllAsync(
          `SELECT type,
                  COUNT(*) AS unread_count,
                  SUM(CASE WHEN created_at < ? THEN 1 ELSE 0 END) AS older_than_1d,
                  SUM(CASE WHEN created_at < ? THEN 1 ELSE 0 END) AS older_than_7d
           FROM notifications
           WHERE read_at IS NULL
           GROUP BY type
           ORDER BY unread_count DESC, type ASC
           LIMIT 20`,
          [day1Iso, day7Iso]
        ),
        sqlAllAsync(
          `SELECT type, COUNT(*) AS cnt
           FROM notifications
           WHERE created_at >= ?
           GROUP BY type
           ORDER BY cnt DESC, type ASC
           LIMIT 10`,
          [sinceIso]
        ),
        sqlGetAsync('SELECT COUNT(*) AS cnt FROM notification_user_preferences WHERE quiet_mode_enabled = 1')
      ]);

      const deliverySummary = { inserted: 0, skipped: 0, failed: 0 };
      const typeMap = new Map();
      for (const row of deliveryRows || []) {
        const type = String(row?.notification_type || 'unknown').trim();
        const status = String(row?.delivery_status || 'unknown').trim();
        const count = Number(row?.cnt || 0);
        if (deliverySummary[status] != null) deliverySummary[status] += count;
        const current = typeMap.get(type) || { type, inserted: 0, skipped: 0, failed: 0 };
        if (current[status] != null) current[status] += count;
        typeMap.set(type, current);
      }

      const surfaceMap = new Map();
      for (const row of telemetryRows || []) {
        const surface = String(row?.surface || 'unknown').trim() || 'unknown';
        const eventName = String(row?.event_name || 'unknown').trim();
        const count = Number(row?.cnt || 0);
        const current = surfaceMap.get(surface) || {
          surface,
          impression: 0,
          open: 0,
          action: 0,
          landed: 0,
          bounce: 0,
          no_action: 0
        };
        if (current[eventName] != null) current[eventName] += count;
        surfaceMap.set(surface, current);
      }

      const surfaceConversion = Array.from(surfaceMap.values()).map((item) => ({
        ...item,
        open_rate: item.impression > 0 ? Number((item.open / item.impression).toFixed(4)) : 0,
        action_rate: item.impression > 0 ? Number((item.action / item.impression).toFixed(4)) : 0,
        bounce_rate: item.landed > 0 ? Number((item.bounce / item.landed).toFixed(4)) : 0,
        no_action_rate: item.landed > 0 ? Number((item.no_action / item.landed).toFixed(4)) : 0
      })).sort((a, b) => String(a.surface).localeCompare(String(b.surface)));

      const unreadAging = (unreadRows || []).map((row) => ({
        type: String(row?.type || '').trim(),
        category: getNotificationCategory(row?.type),
        unread_count: Number(row?.unread_count || 0),
        older_than_1d: Number(row?.older_than_1d || 0),
        older_than_7d: Number(row?.older_than_7d || 0)
      }));

      const alerts = [];
      for (const surface of surfaceConversion) {
        if (Number(surface.bounce_rate || 0) >= 0.25) {
          alerts.push({ code: 'bounce_rate_high', severity: 'high', surface: surface.surface, message: `${surface.surface} yüzeyinde bounce rate yükseldi.` });
        }
        if (Number(surface.no_action_rate || 0) >= 0.4) {
          alerts.push({ code: 'no_action_rate_high', severity: 'medium', surface: surface.surface, message: `${surface.surface} yüzeyinde no-action oranı yüksek.` });
        }
      }
      if (Number(deliverySummary.failed || 0) > 0) {
        alerts.push({ code: 'critical_insert_failures', severity: 'high', message: 'Notification delivery audit içinde failed insert kayıtları var.' });
      }

      return res.json(apiSuccessEnvelope(
        'ADMIN_NOTIFICATIONS_OPS_OK',
        'Notification operations verileri hazır.',
        {
          window: `${windowDays}d`,
          since: sinceIso,
          delivery_summary: deliverySummary,
          delivery_by_type: Array.from(typeMap.values()).sort((a, b) => (Number(b.failed || 0) - Number(a.failed || 0)) || String(a.type).localeCompare(String(b.type))),
          noisy_types: (noisyRows || []).map((row) => ({
            type: String(row?.type || '').trim(),
            category: getNotificationCategory(row?.type),
            count: Number(row?.cnt || 0)
          })),
          unread_aging: unreadAging,
          surface_conversion: surfaceConversion,
          quiet_mode_enabled_users: Number(quietModeRow?.cnt || 0),
          alerts
        },
        {
          window: `${windowDays}d`,
          since: sinceIso,
          delivery_summary: deliverySummary,
          delivery_by_type: Array.from(typeMap.values()).sort((a, b) => (Number(b.failed || 0) - Number(a.failed || 0)) || String(a.type).localeCompare(String(b.type))),
          noisy_types: (noisyRows || []).map((row) => ({
            type: String(row?.type || '').trim(),
            category: getNotificationCategory(row?.type),
            count: Number(row?.cnt || 0)
          })),
          unread_aging: unreadAging,
          surface_conversion: surfaceConversion,
          quiet_mode_enabled_users: Number(quietModeRow?.cnt || 0),
          alerts
        }
      ));
    } catch (err) {
      console.error('admin.notifications.ops failed:', err);
      return sendApiError(res, 500, 'ADMIN_NOTIFICATIONS_OPS_FAILED', 'Beklenmeyen bir hata oluştu.');
    }
  });
}
