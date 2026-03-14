export function createNotificationGovernanceRuntime({
  sqlRun,
  sqlGet,
  sqlAll,
  hasTable,
  sanitizePlainUserText,
  getNotificationCategory,
  getNotificationPriority
}) {
  const notificationPreferenceCategoryKeys = Object.freeze([
    'social',
    'messaging',
    'groups',
    'events',
    'networking',
    'jobs',
    'system'
  ]);

  const notificationExperimentDefaults = Object.freeze({
    sort_order: {
      key: 'sort_order',
      label: 'Sort order',
      description: 'Priority-first vs recent-first ordering on inbox surfaces.',
      status: 'active',
      variants: ['priority', 'recent']
    },
    cta_wording: {
      key: 'cta_wording',
      label: 'CTA wording',
      description: 'Action-first vs neutral call-to-action copy on notification cards.',
      status: 'active',
      variants: ['action', 'neutral']
    },
    inbox_layout: {
      key: 'inbox_layout',
      label: 'Inbox layout',
      description: 'Grouped sections vs flat feed layout for notifications page.',
      status: 'active',
      variants: ['grouped', 'flat']
    }
  });

  const notificationGovernanceChecklist = Object.freeze([
    { key: 'target_required', label: 'Canonical target zorunlu', description: 'Yeni notification type doğrudan çözülebilir bir target üretmeli.' },
    { key: 'analytics_required', label: 'Analytics zorunlu', description: 'Impression, open ve gerekiyorsa action eventleri izlenmeli.' },
    { key: 'dedupe_required', label: 'Dedupe kuralı', description: 'Burst veya tekrar eden eventler için suppress/collapse kuralı tanımlanmalı.' },
    { key: 'priority_defined', label: 'Priority tanımı', description: 'Type için informational, important veya actionable seviyesi açık olmalı.' },
    { key: 'category_defined', label: 'Category tanımı', description: 'Type inbox bilgi mimarisindeki bir category altında yer almalı.' }
  ]);

  const notificationDedupeRules = Object.freeze({
    like: { windowSeconds: 900, compareMessage: false },
    follow: { windowSeconds: 1800, compareMessage: false },
    comment: { windowSeconds: 300, compareMessage: false },
    event_reminder: { windowSeconds: 6 * 60 * 60, compareMessage: false },
    event_starts_soon: { windowSeconds: 6 * 60 * 60, compareMessage: false },
    event_invite: { windowSeconds: 2 * 60 * 60, compareMessage: false },
    group_invite: { windowSeconds: 2 * 60 * 60, compareMessage: false },
    group_invite_accepted: { windowSeconds: 30 * 60, compareMessage: false },
    group_invite_rejected: { windowSeconds: 30 * 60, compareMessage: false }
  });

  const notificationDeliveryAuditTypes = new Set([
    'group_join_request',
    'group_join_approved',
    'group_join_rejected',
    'group_invite',
    'group_invite_accepted',
    'group_invite_rejected',
    'group_role_changed',
    'event_invite',
    'event_response',
    'event_reminder',
    'event_starts_soon',
    'connection_request',
    'connection_accepted',
    'mentorship_request',
    'mentorship_accepted',
    'teacher_network_linked',
    'teacher_link_review_confirmed',
    'teacher_link_review_flagged',
    'teacher_link_review_rejected',
    'teacher_link_review_merged',
    'job_application',
    'job_application_reviewed',
    'job_application_accepted',
    'job_application_rejected',
    'verification_approved',
    'verification_rejected',
    'member_request_approved',
    'member_request_rejected',
    'announcement_approved',
    'announcement_rejected'
  ]);

  const notificationTelemetryEventNames = new Set(['impression', 'open', 'action', 'landed', 'bounce', 'no_action']);

  function ensureNotificationPreferencesTable() {
    sqlRun(`
      CREATE TABLE IF NOT EXISTS notification_user_preferences (
        user_id INTEGER PRIMARY KEY,
        social_enabled INTEGER NOT NULL DEFAULT 1,
        messaging_enabled INTEGER NOT NULL DEFAULT 1,
        groups_enabled INTEGER NOT NULL DEFAULT 1,
        events_enabled INTEGER NOT NULL DEFAULT 1,
        networking_enabled INTEGER NOT NULL DEFAULT 1,
        jobs_enabled INTEGER NOT NULL DEFAULT 1,
        system_enabled INTEGER NOT NULL DEFAULT 1,
        quiet_mode_enabled INTEGER NOT NULL DEFAULT 0,
        quiet_mode_start TEXT,
        quiet_mode_end TEXT,
        updated_at TEXT NOT NULL
      )
    `);
    sqlRun('CREATE INDEX IF NOT EXISTS idx_notification_preferences_updated ON notification_user_preferences (updated_at DESC)');
  }

  function ensureNotificationExperimentConfigsTable() {
    sqlRun(`
      CREATE TABLE IF NOT EXISTS notification_experiment_configs (
        experiment_key TEXT PRIMARY KEY,
        label TEXT,
        description TEXT,
        status TEXT NOT NULL DEFAULT 'active',
        variants_json TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    `);
    sqlRun('CREATE INDEX IF NOT EXISTS idx_notification_experiments_updated ON notification_experiment_configs (updated_at DESC)');
    const now = new Date().toISOString();
    for (const experiment of Object.values(notificationExperimentDefaults)) {
      sqlRun(
        `INSERT OR IGNORE INTO notification_experiment_configs
           (experiment_key, label, description, status, variants_json, updated_at)
         VALUES (?, ?, ?, ?, ?, ?)`,
        [
          experiment.key,
          experiment.label,
          experiment.description,
          experiment.status,
          JSON.stringify(experiment.variants),
          now
        ]
      );
    }
  }

  function readNotificationExperimentConfigs() {
    ensureNotificationExperimentConfigsTable();
    return (sqlAll(
      `SELECT experiment_key, label, description, status, variants_json, updated_at
       FROM notification_experiment_configs
       ORDER BY experiment_key ASC`
    ) || []).map((row) => {
      let variants = [];
      try {
        const parsed = JSON.parse(String(row.variants_json || '[]'));
        variants = Array.isArray(parsed) ? parsed : [];
      } catch {
        variants = [];
      }
      if (!variants.length) {
        variants = [...(notificationExperimentDefaults[row.experiment_key]?.variants || ['control'])];
      }
      return {
        key: String(row.experiment_key || '').trim(),
        label: String(row.label || '').trim(),
        description: String(row.description || '').trim(),
        status: String(row.status || 'active').trim().toLowerCase() === 'paused' ? 'paused' : 'active',
        variants: variants.map((item) => String(item || '').trim()).filter(Boolean),
        updated_at: row.updated_at || null
      };
    });
  }

  function getNotificationExperimentAssignments(userId) {
    const safeUserId = Number(userId || 0);
    const configs = readNotificationExperimentConfigs();
    const assignments = {};
    for (const config of configs) {
      const fallback = String(config.variants?.[0] || 'control');
      if (config.status !== 'active' || !safeUserId || !Array.isArray(config.variants) || config.variants.length < 2) {
        assignments[config.key] = fallback;
        continue;
      }
      const bucket = Math.abs((safeUserId * 31) + String(config.key || '').length) % config.variants.length;
      assignments[config.key] = String(config.variants[bucket] || fallback);
    }
    return assignments;
  }

  function defaultNotificationPreferenceRow(userId = null) {
    return {
      user_id: Number(userId || 0) || null,
      social_enabled: 1,
      messaging_enabled: 1,
      groups_enabled: 1,
      events_enabled: 1,
      networking_enabled: 1,
      jobs_enabled: 1,
      system_enabled: 1,
      quiet_mode_enabled: 0,
      quiet_mode_start: null,
      quiet_mode_end: null,
      updated_at: null
    };
  }

  function readNotificationPreferenceRow(userId) {
    const safeUserId = Number(userId || 0);
    ensureNotificationPreferencesTable();
    if (!safeUserId) return defaultNotificationPreferenceRow();
    const row = sqlGet('SELECT * FROM notification_user_preferences WHERE user_id = ?', [safeUserId]) || {};
    return {
      ...defaultNotificationPreferenceRow(safeUserId),
      ...row
    };
  }

  function mapNotificationPreferenceResponse(row) {
    const safeRow = row || defaultNotificationPreferenceRow();
    const categories = {};
    for (const key of notificationPreferenceCategoryKeys) {
      categories[key] = Number(safeRow?.[`${key}_enabled`] ?? 1) === 1;
    }
    return {
      categories,
      quiet_mode: {
        enabled: Number(safeRow?.quiet_mode_enabled || 0) === 1,
        start: safeRow?.quiet_mode_start || null,
        end: safeRow?.quiet_mode_end || null
      },
      high_priority_override: true,
      updated_at: safeRow?.updated_at || null
    };
  }

  function isNotificationHighPriority(type) {
    const priority = getNotificationPriority(type);
    return priority === 'actionable' || priority === 'critical' || priority === 'important';
  }

  function shouldSuppressNotificationByPreference(userId, type) {
    const safeUserId = Number(userId || 0);
    if (!safeUserId) return false;
    const category = getNotificationCategory(type);
    if (!notificationPreferenceCategoryKeys.includes(category)) return false;
    if (isNotificationHighPriority(type)) return false;
    const prefs = readNotificationPreferenceRow(safeUserId);
    return Number(prefs?.[`${category}_enabled`] ?? 1) !== 1;
  }

  function getNotificationDedupeRule(type) {
    return notificationDedupeRules[String(type || '').trim().toLowerCase()] || null;
  }

  function findRecentDuplicateNotification({ userId, type, sourceUserId = null, entityId = null, message = '' } = {}) {
    const rule = getNotificationDedupeRule(type);
    const safeUserId = Number(userId || 0);
    if (!rule || !safeUserId || !hasTable('notifications')) return null;
    const sinceIso = new Date(Date.now() - (Number(rule.windowSeconds || 0) * 1000)).toISOString();
    const compareMessage = rule.compareMessage === true;
    const query = `SELECT id, created_at
       FROM notifications
       WHERE user_id = ?
         AND LOWER(TRIM(COALESCE(type, ''))) = LOWER(?)
         AND COALESCE(source_user_id, 0) = COALESCE(?, 0)
         AND COALESCE(entity_id, 0) = COALESCE(?, 0)
         AND ${compareMessage ? "COALESCE(message, '') = COALESCE(?, '')" : '1 = 1'}
         AND COALESCE(CASE WHEN CAST(created_at AS TEXT) = '' THEN NULL ELSE created_at END, '1970-01-01T00:00:00.000Z') >= ?
       ORDER BY id DESC
       LIMIT 1`;
    const params = compareMessage
      ? [safeUserId, type, Number(sourceUserId || 0) || null, Number(entityId || 0) || null, String(message || ''), sinceIso]
      : [safeUserId, type, Number(sourceUserId || 0) || null, Number(entityId || 0) || null, sinceIso];
    return sqlGet(query, params) || null;
  }

  function shouldAuditNotificationDelivery(type) {
    return notificationDeliveryAuditTypes.has(String(type || '').trim().toLowerCase());
  }

  function ensureNotificationDeliveryAuditTable() {
    sqlRun(`
      CREATE TABLE IF NOT EXISTS notification_delivery_audit (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        notification_id INTEGER,
        user_id INTEGER,
        source_user_id INTEGER,
        entity_id INTEGER,
        notification_type TEXT,
        delivery_status TEXT NOT NULL,
        skip_reason TEXT,
        error_message TEXT,
        created_at TEXT NOT NULL
      )
    `);
    sqlRun('CREATE INDEX IF NOT EXISTS idx_notification_delivery_audit_created ON notification_delivery_audit (created_at DESC)');
    sqlRun('CREATE INDEX IF NOT EXISTS idx_notification_delivery_audit_type ON notification_delivery_audit (notification_type, created_at DESC)');
  }

  function logNotificationDeliveryAudit({
    notificationId = null,
    userId = null,
    sourceUserId = null,
    entityId = null,
    notificationType = '',
    deliveryStatus = '',
    skipReason = '',
    errorMessage = '',
    createdAt = null
  } = {}) {
    ensureNotificationDeliveryAuditTable();
    sqlRun(
      `INSERT INTO notification_delivery_audit
         (notification_id, user_id, source_user_id, entity_id, notification_type, delivery_status, skip_reason, error_message, created_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        Number(notificationId || 0) || null,
        Number(userId || 0) || null,
        Number(sourceUserId || 0) || null,
        Number(entityId || 0) || null,
        sanitizePlainUserText(String(notificationType || '').trim().toLowerCase(), 120) || null,
        sanitizePlainUserText(String(deliveryStatus || '').trim().toLowerCase(), 40) || 'unknown',
        sanitizePlainUserText(String(skipReason || '').trim().toLowerCase(), 120) || null,
        sanitizePlainUserText(String(errorMessage || '').trim(), 500) || null,
        createdAt || new Date().toISOString()
      ]
    );
  }

  function addNotification({ userId, type, sourceUserId, entityId, message }) {
    const normalizedType = sanitizePlainUserText(String(type || '').trim().toLowerCase(), 120);
    const safeUserId = Number(userId || 0) || null;
    const safeSourceUserId = Number(sourceUserId || 0) || null;
    const safeEntityId = Number(entityId || 0) || null;
    const now = new Date().toISOString();
    if (!safeUserId) {
      logNotificationDeliveryAudit({
        notificationType: normalizedType,
        userId: null,
        sourceUserId: safeSourceUserId,
        entityId: safeEntityId,
        deliveryStatus: 'skipped',
        skipReason: 'missing_user_id',
        createdAt: now
      });
      return null;
    }
    if (shouldSuppressNotificationByPreference(safeUserId, normalizedType)) {
      logNotificationDeliveryAudit({
        notificationType: normalizedType,
        userId: safeUserId,
        sourceUserId: safeSourceUserId,
        entityId: safeEntityId,
        deliveryStatus: 'skipped',
        skipReason: 'category_disabled',
        createdAt: now
      });
      return null;
    }
    const duplicateNotification = findRecentDuplicateNotification({
      userId: safeUserId,
      type: normalizedType,
      sourceUserId: safeSourceUserId,
      entityId: safeEntityId,
      message
    });
    if (duplicateNotification) {
      logNotificationDeliveryAudit({
        notificationId: Number(duplicateNotification.id || 0) || null,
        notificationType: normalizedType,
        userId: safeUserId,
        sourceUserId: safeSourceUserId,
        entityId: safeEntityId,
        deliveryStatus: 'skipped',
        skipReason: 'deduped_recent_duplicate',
        createdAt: now
      });
      return Number(duplicateNotification.id || 0) || null;
    }
    try {
      const result = sqlRun(
        'INSERT INTO notifications (user_id, type, source_user_id, entity_id, message, created_at) VALUES (?, ?, ?, ?, ?, ?)',
        [safeUserId, normalizedType, safeSourceUserId, safeEntityId, message || '', now]
      );
      const notificationId = Number(result?.lastInsertRowid || 0) || null;
      if (shouldAuditNotificationDelivery(normalizedType)) {
        logNotificationDeliveryAudit({
          notificationId,
          notificationType: normalizedType,
          userId: safeUserId,
          sourceUserId: safeSourceUserId,
          entityId: safeEntityId,
          deliveryStatus: 'inserted',
          createdAt: now
        });
      }
      return notificationId;
    } catch (err) {
      logNotificationDeliveryAudit({
        notificationType: normalizedType,
        userId: safeUserId,
        sourceUserId: safeSourceUserId,
        entityId: safeEntityId,
        deliveryStatus: 'failed',
        errorMessage: err?.message || 'notification_insert_failed',
        createdAt: now
      });
      throw err;
    }
  }

  function normalizeNotificationTelemetryEventName(value) {
    const normalized = String(value || '').trim().toLowerCase();
    return notificationTelemetryEventNames.has(normalized) ? normalized : '';
  }

  function normalizeNotificationTelemetrySurface(value) {
    return sanitizePlainUserText(String(value || '').trim().toLowerCase(), 80) || 'unknown';
  }

  function normalizeNotificationTelemetryActionKind(value) {
    return sanitizePlainUserText(String(value || '').trim().toLowerCase(), 120) || '';
  }

  function ensureNotificationTelemetryEventsTable() {
    sqlRun(`
      CREATE TABLE IF NOT EXISTS notification_telemetry_events (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER,
        notification_id INTEGER,
        event_name TEXT NOT NULL,
        notification_type TEXT,
        surface TEXT,
        action_kind TEXT,
        created_at TEXT NOT NULL
      )
    `);
    sqlRun('CREATE INDEX IF NOT EXISTS idx_notification_telemetry_user_created ON notification_telemetry_events (user_id, created_at DESC)');
    sqlRun('CREATE INDEX IF NOT EXISTS idx_notification_telemetry_notification ON notification_telemetry_events (notification_id, created_at DESC)');
  }

  function recordNotificationTelemetryEvent({
    userId = null,
    notificationId = null,
    eventName = '',
    notificationType = '',
    surface = '',
    actionKind = '',
    createdAt = null
  } = {}) {
    const normalizedEventName = normalizeNotificationTelemetryEventName(eventName);
    if (!normalizedEventName) return false;
    ensureNotificationTelemetryEventsTable();
    sqlRun(
      `INSERT INTO notification_telemetry_events
         (user_id, notification_id, event_name, notification_type, surface, action_kind, created_at)
       VALUES (?, ?, ?, ?, ?, ?, ?)`,
      [
        Number(userId || 0) || null,
        Number(notificationId || 0) || null,
        normalizedEventName,
        sanitizePlainUserText(String(notificationType || '').trim().toLowerCase(), 120) || null,
        normalizeNotificationTelemetrySurface(surface),
        normalizeNotificationTelemetryActionKind(actionKind) || null,
        createdAt || new Date().toISOString()
      ]
    );
    return true;
  }

  return {
    notificationPreferenceCategoryKeys,
    notificationGovernanceChecklist,
    ensureNotificationPreferencesTable,
    ensureNotificationExperimentConfigsTable,
    readNotificationExperimentConfigs,
    getNotificationExperimentAssignments,
    readNotificationPreferenceRow,
    mapNotificationPreferenceResponse,
    getNotificationDedupeRule,
    ensureNotificationDeliveryAuditTable,
    ensureNotificationTelemetryEventsTable,
    normalizeNotificationTelemetryEventName,
    recordNotificationTelemetryEvent,
    addNotification
  };
}
