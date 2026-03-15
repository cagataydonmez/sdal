import { createNetworkingAdminAnalyticsRuntime } from './createNetworkingAdminAnalyticsRuntime.js';
import { createTeacherLinkModerationRuntime } from './createTeacherLinkModerationRuntime.js';
import { createNetworkDiscoveryPayloadRuntime } from './createNetworkDiscoveryPayloadRuntime.js';
import { createOpportunityInboxRuntime } from '../opportunities/createOpportunityInboxRuntime.js';

export function createNetworkingRuntime({
  sqlGet,
  sqlAll,
  sqlRun,
  sqlGetAsync,
  sqlAllAsync,
  sqlRunAsync,
  hasColumn,
  hasTable,
  normalizeCohortValue,
  roleAtLeast,
  TEACHER_NETWORK_MIN_CLASS_YEAR,
  TEACHER_NETWORK_MAX_CLASS_YEAR,
  TEACHER_COHORT_VALUE,
  getNetworkSuggestionAbConfigs,
  getAssignedNetworkSuggestionVariant,
  getSafeAssignedNetworkSuggestionVariant,
  readExploreSuggestionsCache,
  writeExploreSuggestionsCache,
  networkSuggestionDefaultParams,
  networkSuggestionDefaultVariants,
  normalizeNetworkSuggestionParams,
  buildScoredNetworkSuggestion,
  createPeerMap,
  getPeerOverlapCount,
  mapNetworkSuggestionForApi,
  sortNetworkSuggestions
}) {
  const NETWORKING_TELEMETRY_CLIENT_EVENT_NAMES = new Set([
    'network_hub_viewed',
    'network_hub_suggestions_loaded',
    'network_explore_viewed',
    'network_explore_suggestions_loaded',
    'teacher_network_viewed'
  ]);
  const NETWORKING_TELEMETRY_ACTION_EVENT_NAMES = new Set([
    'connection_requested',
    'connection_accepted',
    'connection_ignored',
    'connection_cancelled',
    'mentorship_requested',
    'mentorship_accepted',
    'mentorship_declined',
    'teacher_link_created',
    'teacher_links_read',
    'follow_created',
    'follow_removed'
  ]);
  const NETWORK_SUGGESTION_APPLY_MIN_EXPOSURE_USERS = 2;
  const NETWORK_SUGGESTION_APPLY_COOLDOWN_MS = 10 * 60 * 1000;
  const NETWORK_SUGGESTION_APPLY_CONFIRMATION_TOKEN = 'apply';

  function clamp(value, min, max) {
    const numeric = Number(value);
    if (!Number.isFinite(numeric)) return min;
    return Math.max(min, Math.min(max, numeric));
  }

  function round2(value) {
    const numeric = Number(value);
    if (!Number.isFinite(numeric)) return 0;
    return Number(numeric.toFixed(2));
  }

  function toDateMs(value) {
    const raw = String(value || '').trim();
    if (!raw) return null;
    const numeric = Date.parse(raw);
    return Number.isFinite(numeric) ? numeric : null;
  }

  function normalizeMentorshipStatus(value) {
    const raw = String(value || '').trim().toLowerCase();
    if (raw === 'requested' || raw === 'accepted' || raw === 'declined' || raw === 'cancelled') return raw;
    return '';
  }

  function normalizeConnectionStatus(value) {
    const raw = String(value || '').trim().toLowerCase();
    if (raw === 'pending' || raw === 'accepted' || raw === 'ignored') return raw;
    return '';
  }

  function normalizeTeacherAlumniRelationshipType(value) {
    const raw = String(value || '').trim().toLowerCase();
    if (raw === 'taught_in_class' || raw === 'mentor' || raw === 'advisor') return raw;
    return '';
  }

  function normalizeTeacherLinkCreatedVia(value) {
    const raw = String(value || '').trim().toLowerCase();
    if (raw === 'manual_alumni_link' || raw === 'admin_review_update' || raw === 'import') return raw;
    return 'manual_alumni_link';
  }

  function normalizeTeacherLinkSourceSurface(value) {
    const raw = String(value || '').trim().toLowerCase();
    if (raw === 'teachers_network_page' || raw === 'member_detail_page' || raw === 'network_hub' || raw === 'admin_panel') return raw;
    return 'teachers_network_page';
  }

  function normalizeTeacherLinkReviewStatus(value) {
    const raw = String(value || '').trim().toLowerCase();
    if (raw === 'pending' || raw === 'confirmed' || raw === 'flagged' || raw === 'rejected' || raw === 'merged') return raw;
    return '';
  }

  function normalizeNetworkingTelemetryEventName(value, { allowClientEvents = true, allowActionEvents = true } = {}) {
    const raw = String(value || '').trim().toLowerCase();
    if (!raw) return '';
    if (allowClientEvents && NETWORKING_TELEMETRY_CLIENT_EVENT_NAMES.has(raw)) return raw;
    if (allowActionEvents && NETWORKING_TELEMETRY_ACTION_EVENT_NAMES.has(raw)) return raw;
    return '';
  }

  function normalizeNetworkingTelemetrySourceSurface(value) {
    const raw = String(value || '').trim().toLowerCase();
    if (raw === 'network_hub' || raw === 'explore_page' || raw === 'teachers_network_page' || raw === 'member_detail_page' || raw === 'admin_panel' || raw === 'server_action') return raw;
    return 'server_action';
  }

  function normalizeNetworkingTelemetryEntityType(value) {
    const raw = String(value || '').trim().toLowerCase();
    if (raw === 'user' || raw === 'connection_request' || raw === 'mentorship_request' || raw === 'teacher_link' || raw === 'suggestion_batch' || raw === 'notification') return raw;
    return '';
  }

  function normalizeTeacherLinkReviewNote(value) {
    return String(value || '').trim().slice(0, 500);
  }

  function normalizeBooleanFlag(value) {
    const raw = String(value ?? '').trim().toLowerCase();
    return raw === '1' || raw === 'true' || raw === 'yes' || raw === 'on';
  }

  function parseTeacherNetworkClassYear(value) {
    const raw = String(value ?? '').trim();
    if (!raw) return { provided: false, value: null, valid: true };
    if (!/^\d{4}$/.test(raw)) return { provided: true, value: null, valid: false };
    const year = Number.parseInt(raw, 10);
    const valid = Number.isFinite(year) && year >= TEACHER_NETWORK_MIN_CLASS_YEAR && year <= TEACHER_NETWORK_MAX_CLASS_YEAR;
    return { provided: true, value: valid ? year : null, valid };
  }

  function calculateCooldownRemainingSeconds(timestampValue, cooldownSeconds) {
    const cooldown = Number(cooldownSeconds || 0);
    if (!Number.isFinite(cooldown) || cooldown <= 0) return 0;
    const fromMs = toDateMs(timestampValue);
    if (fromMs === null) return 0;
    const remainingMs = fromMs + cooldown * 1000 - Date.now();
    return remainingMs > 0 ? Math.ceil(remainingMs / 1000) : 0;
  }

  function apiSuccessEnvelope(code, message, data = null, legacy = null) {
    const payload = { ok: true, code, message, data };
    if (legacy && typeof legacy === 'object') Object.assign(payload, legacy);
    return payload;
  }

  function apiErrorEnvelope(code, message, data = null, legacy = null) {
    const payload = { ok: false, code, message, data };
    if (legacy && typeof legacy === 'object') Object.assign(payload, legacy);
    return payload;
  }

  function sendApiError(res, statusCode, code, message, data = null, legacy = null) {
    return res.status(statusCode).json(apiErrorEnvelope(code, message, data, legacy));
  }

  function ensureConnectionRequestsTable() {
    sqlRun(`
      CREATE TABLE IF NOT EXISTS connection_requests (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sender_id INTEGER NOT NULL,
        receiver_id INTEGER NOT NULL,
        status TEXT DEFAULT 'pending',
        created_at TEXT,
        updated_at TEXT,
        responded_at TEXT,
        UNIQUE(sender_id, receiver_id)
      )
    `);
    if (!hasColumn('connection_requests', 'responded_at')) {
      try {
        sqlRun('ALTER TABLE connection_requests ADD COLUMN responded_at TEXT');
      } catch {}
    }
    sqlRun('CREATE INDEX IF NOT EXISTS idx_connection_requests_sender ON connection_requests (sender_id, updated_at DESC)');
    sqlRun('CREATE INDEX IF NOT EXISTS idx_connection_requests_receiver ON connection_requests (receiver_id, updated_at DESC)');
  }

  function ensureMentorshipRequestsTable() {
    sqlRun(`
      CREATE TABLE IF NOT EXISTS mentorship_requests (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        requester_id INTEGER NOT NULL,
        mentor_id INTEGER NOT NULL,
        status TEXT DEFAULT 'requested',
        focus_area TEXT,
        message TEXT,
        created_at TEXT,
        updated_at TEXT,
        responded_at TEXT,
        UNIQUE(requester_id, mentor_id)
      )
    `);
    if (!hasColumn('mentorship_requests', 'responded_at')) {
      try {
        sqlRun('ALTER TABLE mentorship_requests ADD COLUMN responded_at TEXT');
      } catch {}
    }
    sqlRun('CREATE INDEX IF NOT EXISTS idx_mentorship_requests_requester ON mentorship_requests (requester_id, updated_at DESC)');
    sqlRun('CREATE INDEX IF NOT EXISTS idx_mentorship_requests_mentor ON mentorship_requests (mentor_id, updated_at DESC)');
  }

  function ensureTeacherAlumniLinksTable() {
    sqlRun(`
      CREATE TABLE IF NOT EXISTS teacher_alumni_links (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        teacher_user_id INTEGER NOT NULL,
        alumni_user_id INTEGER NOT NULL,
        relationship_type TEXT NOT NULL,
        class_year INTEGER,
        notes TEXT,
        confidence_score REAL NOT NULL DEFAULT 1.0,
        created_via TEXT NOT NULL DEFAULT 'manual_alumni_link',
        source_surface TEXT NOT NULL DEFAULT 'teachers_network_page',
        last_reviewed_by INTEGER,
        review_status TEXT NOT NULL DEFAULT 'pending',
        review_note TEXT,
        reviewed_at TEXT,
        merged_into_link_id INTEGER,
        created_by INTEGER,
        created_at TEXT NOT NULL,
        UNIQUE(teacher_user_id, alumni_user_id, relationship_type, class_year)
      )
    `);
    if (!hasColumn('teacher_alumni_links', 'created_via')) {
      try {
        sqlRun("ALTER TABLE teacher_alumni_links ADD COLUMN created_via TEXT NOT NULL DEFAULT 'manual_alumni_link'");
      } catch {}
    }
    if (!hasColumn('teacher_alumni_links', 'source_surface')) {
      try {
        sqlRun("ALTER TABLE teacher_alumni_links ADD COLUMN source_surface TEXT NOT NULL DEFAULT 'teachers_network_page'");
      } catch {}
    }
    if (!hasColumn('teacher_alumni_links', 'last_reviewed_by')) {
      try {
        sqlRun('ALTER TABLE teacher_alumni_links ADD COLUMN last_reviewed_by INTEGER');
      } catch {}
    }
    if (!hasColumn('teacher_alumni_links', 'review_status')) {
      try {
        sqlRun("ALTER TABLE teacher_alumni_links ADD COLUMN review_status TEXT NOT NULL DEFAULT 'pending'");
      } catch {}
    }
    if (!hasColumn('teacher_alumni_links', 'review_note')) {
      try {
        sqlRun('ALTER TABLE teacher_alumni_links ADD COLUMN review_note TEXT');
      } catch {}
    }
    if (!hasColumn('teacher_alumni_links', 'reviewed_at')) {
      try {
        sqlRun('ALTER TABLE teacher_alumni_links ADD COLUMN reviewed_at TEXT');
      } catch {}
    }
    if (!hasColumn('teacher_alumni_links', 'merged_into_link_id')) {
      try {
        sqlRun('ALTER TABLE teacher_alumni_links ADD COLUMN merged_into_link_id INTEGER');
      } catch {}
    }
    sqlRun('CREATE INDEX IF NOT EXISTS idx_teacher_alumni_links_alumni ON teacher_alumni_links (alumni_user_id, created_at DESC)');
    sqlRun('CREATE INDEX IF NOT EXISTS idx_teacher_alumni_links_teacher ON teacher_alumni_links (teacher_user_id, created_at DESC)');
    sqlRun('CREATE INDEX IF NOT EXISTS idx_teacher_alumni_links_review_status ON teacher_alumni_links (review_status, created_at DESC)');
  }

  function ensureTeacherAlumniLinkModerationEventsTable() {
    sqlRun(`
      CREATE TABLE IF NOT EXISTS teacher_alumni_link_moderation_events (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        link_id INTEGER NOT NULL,
        actor_user_id INTEGER,
        event_type TEXT NOT NULL,
        from_status TEXT,
        to_status TEXT,
        note TEXT,
        merge_target_id INTEGER,
        created_at TEXT NOT NULL
      )
    `);
    sqlRun('CREATE INDEX IF NOT EXISTS idx_teacher_link_moderation_events_link ON teacher_alumni_link_moderation_events (link_id, created_at DESC)');
  }

  function ensureNetworkingTelemetryEventsTable() {
    sqlRun(`
      CREATE TABLE IF NOT EXISTS networking_telemetry_events (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER,
        event_name TEXT NOT NULL,
        source_surface TEXT NOT NULL DEFAULT 'server_action',
        target_user_id INTEGER,
        entity_type TEXT,
        entity_id INTEGER,
        metadata_json TEXT,
        created_at TEXT NOT NULL
      )
    `);
    sqlRun('CREATE INDEX IF NOT EXISTS idx_networking_telemetry_event_name ON networking_telemetry_events (event_name, created_at DESC)');
    sqlRun('CREATE INDEX IF NOT EXISTS idx_networking_telemetry_user_id ON networking_telemetry_events (user_id, created_at DESC)');
  }

  function ensureMemberNetworkingDailySummaryTable() {
    sqlRun(`
      CREATE TABLE IF NOT EXISTS member_networking_daily_summary (
        user_id INTEGER NOT NULL,
        date TEXT NOT NULL,
        cohort TEXT,
        connections_requested INTEGER NOT NULL DEFAULT 0,
        connections_accepted INTEGER NOT NULL DEFAULT 0,
        connections_pending INTEGER NOT NULL DEFAULT 0,
        connections_ignored INTEGER NOT NULL DEFAULT 0,
        connections_declined INTEGER NOT NULL DEFAULT 0,
        connections_cancelled INTEGER NOT NULL DEFAULT 0,
        mentorship_requested INTEGER NOT NULL DEFAULT 0,
        mentorship_accepted INTEGER NOT NULL DEFAULT 0,
        mentorship_declined INTEGER NOT NULL DEFAULT 0,
        teacher_links_created INTEGER NOT NULL DEFAULT 0,
        teacher_links_read INTEGER NOT NULL DEFAULT 0,
        follow_created INTEGER NOT NULL DEFAULT 0,
        follow_removed INTEGER NOT NULL DEFAULT 0,
        hub_views INTEGER NOT NULL DEFAULT 0,
        hub_suggestion_loads INTEGER NOT NULL DEFAULT 0,
        explore_views INTEGER NOT NULL DEFAULT 0,
        explore_suggestion_loads INTEGER NOT NULL DEFAULT 0,
        teacher_network_views INTEGER NOT NULL DEFAULT 0,
        updated_at TEXT NOT NULL,
        PRIMARY KEY (user_id, date)
      )
    `);
    sqlRun('CREATE INDEX IF NOT EXISTS idx_member_networking_daily_summary_date ON member_networking_daily_summary (date DESC)');
    sqlRun('CREATE INDEX IF NOT EXISTS idx_member_networking_daily_summary_cohort ON member_networking_daily_summary (cohort, date DESC)');
  }

  function ensureNetworkingSummaryMetaTable() {
    sqlRun(`
      CREATE TABLE IF NOT EXISTS networking_summary_meta (
        key TEXT PRIMARY KEY,
        value TEXT,
        updated_at TEXT NOT NULL
      )
    `);
  }

  function ensureNetworkSuggestionAbTables() {
    try {
      sqlRun(`
        CREATE TABLE IF NOT EXISTS network_suggestion_ab_config (
          variant TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          description TEXT,
          traffic_pct INTEGER NOT NULL DEFAULT 0,
          enabled INTEGER NOT NULL DEFAULT 1,
          params_json TEXT,
          updated_at TEXT NOT NULL
        )
      `);
      sqlRun(`
        CREATE TABLE IF NOT EXISTS network_suggestion_ab_assignments (
          user_id INTEGER PRIMARY KEY,
          variant TEXT NOT NULL,
          assigned_at TEXT NOT NULL,
          updated_at TEXT NOT NULL
        )
      `);
      sqlRun('CREATE INDEX IF NOT EXISTS idx_network_suggestion_ab_assignments_variant ON network_suggestion_ab_assignments (variant, updated_at DESC)');
      sqlRun(`
        CREATE TABLE IF NOT EXISTS network_suggestion_ab_change_log (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          action_type TEXT NOT NULL DEFAULT 'apply',
          related_change_id INTEGER,
          actor_user_id INTEGER,
          recommendation_index INTEGER,
          cohort TEXT,
          window_days INTEGER,
          payload_json TEXT,
          before_snapshot_json TEXT,
          after_snapshot_json TEXT,
          created_at TEXT NOT NULL,
          rolled_back_at TEXT,
          rollback_change_id INTEGER
        )
      `);
      sqlRun('CREATE INDEX IF NOT EXISTS idx_network_suggestion_ab_change_log_created_at ON network_suggestion_ab_change_log (created_at DESC)');
      return true;
    } catch (err) {
      console.error('network_suggestion_ab bootstrap failed:', err);
      return hasTable('network_suggestion_ab_config') && hasTable('network_suggestion_ab_assignments');
    }
  }

  function toSummaryDateKey(value) {
    const raw = String(value || '').trim();
    if (!raw) return '';
    return raw.slice(0, 10);
  }

  function incrementNetworkingDailySummaryMetric(bucket, key, delta = 1) {
    const metricKey = String(key || '').trim();
    if (!metricKey) return;
    bucket[metricKey] = Math.max(0, Number(bucket[metricKey] || 0) + Number(delta || 0));
  }

  function recordNetworkingTelemetryEvent({
    userId = null,
    eventName = '',
    sourceSurface = 'server_action',
    targetUserId = null,
    entityType = '',
    entityId = null,
    metadata = null,
    createdAt = null
  } = {}) {
    const normalizedEventName = normalizeNetworkingTelemetryEventName(eventName);
    if (!normalizedEventName) return;
    ensureNetworkingTelemetryEventsTable();
    const nowIso = createdAt || new Date().toISOString();
    let metadataJson = null;
    if (metadata && typeof metadata === 'object') {
      try {
        metadataJson = JSON.stringify(metadata).slice(0, 4000);
      } catch {
        metadataJson = null;
      }
    }
    sqlRun(
      `INSERT INTO networking_telemetry_events
         (user_id, event_name, source_surface, target_user_id, entity_type, entity_id, metadata_json, created_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        Number(userId || 0) || null,
        normalizedEventName,
        normalizeNetworkingTelemetrySourceSurface(sourceSurface),
        Number(targetUserId || 0) || null,
        normalizeNetworkingTelemetryEntityType(entityType) || null,
        Number(entityId || 0) || null,
        metadataJson,
        nowIso
      ]
    );

    const safeUserId = Number(userId || 0);
    if (!safeUserId) return;

    ensureMemberNetworkingDailySummaryTable();
    const dateKey = toSummaryDateKey(nowIso);
    const bucket = sqlGet(
      'SELECT * FROM member_networking_daily_summary WHERE user_id = ? AND date = ?',
      [safeUserId, dateKey]
    );
    const metrics = bucket ? { ...bucket } : {
      user_id: safeUserId,
      date: dateKey,
      cohort: normalizeCohortValue(sqlGet('SELECT mezuniyetyili FROM uyeler WHERE id = ?', [safeUserId])?.mezuniyetyili) || 'unknown',
      connections_requested: 0,
      connections_accepted: 0,
      connections_pending: 0,
      connections_ignored: 0,
      connections_declined: 0,
      connections_cancelled: 0,
      mentorship_requested: 0,
      mentorship_accepted: 0,
      mentorship_declined: 0,
      teacher_links_created: 0,
      teacher_links_read: 0,
      follow_created: 0,
      follow_removed: 0,
      hub_views: 0,
      hub_suggestion_loads: 0,
      explore_views: 0,
      explore_suggestion_loads: 0,
      teacher_network_views: 0
    };

    if (normalizedEventName === 'teacher_links_read') incrementNetworkingDailySummaryMetric(metrics, 'teacher_links_read', 1);
    if (normalizedEventName === 'follow_created') incrementNetworkingDailySummaryMetric(metrics, 'follow_created', 1);
    if (normalizedEventName === 'follow_removed') incrementNetworkingDailySummaryMetric(metrics, 'follow_removed', 1);
    if (normalizedEventName === 'network_hub_viewed') incrementNetworkingDailySummaryMetric(metrics, 'hub_views', 1);
    if (normalizedEventName === 'network_hub_suggestions_loaded') incrementNetworkingDailySummaryMetric(metrics, 'hub_suggestion_loads', 1);
    if (normalizedEventName === 'network_explore_viewed') incrementNetworkingDailySummaryMetric(metrics, 'explore_views', 1);
    if (normalizedEventName === 'network_explore_suggestions_loaded') incrementNetworkingDailySummaryMetric(metrics, 'explore_suggestion_loads', 1);
    if (normalizedEventName === 'teacher_network_viewed') incrementNetworkingDailySummaryMetric(metrics, 'teacher_network_views', 1);

    sqlRun(
      `INSERT INTO member_networking_daily_summary (
         user_id, date, cohort, connections_requested, connections_accepted, connections_pending,
         connections_ignored, connections_declined, connections_cancelled, mentorship_requested,
         mentorship_accepted, mentorship_declined, teacher_links_created, teacher_links_read,
         follow_created, follow_removed, hub_views, hub_suggestion_loads, explore_views,
         explore_suggestion_loads, teacher_network_views, updated_at
       ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
       ON CONFLICT(user_id, date) DO UPDATE SET
         cohort = excluded.cohort,
         connections_requested = excluded.connections_requested,
         connections_accepted = excluded.connections_accepted,
         connections_pending = excluded.connections_pending,
         connections_ignored = excluded.connections_ignored,
         connections_declined = excluded.connections_declined,
         connections_cancelled = excluded.connections_cancelled,
         mentorship_requested = excluded.mentorship_requested,
         mentorship_accepted = excluded.mentorship_accepted,
         mentorship_declined = excluded.mentorship_declined,
         teacher_links_created = excluded.teacher_links_created,
         teacher_links_read = excluded.teacher_links_read,
         follow_created = excluded.follow_created,
         follow_removed = excluded.follow_removed,
         hub_views = excluded.hub_views,
         hub_suggestion_loads = excluded.hub_suggestion_loads,
         explore_views = excluded.explore_views,
         explore_suggestion_loads = excluded.explore_suggestion_loads,
         teacher_network_views = excluded.teacher_network_views,
         updated_at = excluded.updated_at`,
      [
        metrics.user_id,
        metrics.date,
        metrics.cohort,
        metrics.connections_requested,
        metrics.connections_accepted,
        metrics.connections_pending,
        metrics.connections_ignored,
        metrics.connections_declined,
        metrics.connections_cancelled,
        metrics.mentorship_requested,
        metrics.mentorship_accepted,
        metrics.mentorship_declined,
        metrics.teacher_links_created,
        metrics.teacher_links_read,
        metrics.follow_created,
        metrics.follow_removed,
        metrics.hub_views,
        metrics.hub_suggestion_loads,
        metrics.explore_views,
        metrics.explore_suggestion_loads,
        metrics.teacher_network_views,
        nowIso
      ]
    );
  }

  const adminAnalyticsRuntime = createNetworkingAdminAnalyticsRuntime({
    sqlGet,
    sqlGetAsync,
    sqlAll,
    sqlRun,
    sqlRunAsync,
    sqlAllAsync,
    hasTable,
    normalizeCohortValue,
    ensureConnectionRequestsTable,
    ensureMentorshipRequestsTable,
    ensureTeacherAlumniLinksTable,
    ensureNetworkingTelemetryEventsTable,
    ensureMemberNetworkingDailySummaryTable,
    ensureNetworkingSummaryMetaTable,
    ensureNetworkSuggestionAbTables,
    getNetworkSuggestionAbConfigs,
    networkSuggestionDefaultParams,
    networkSuggestionDefaultVariants,
    normalizeNetworkSuggestionParams,
    normalizeNetworkingTelemetryEventName,
    toDateMs,
    toSummaryDateKey,
    clamp,
    round2,
    NETWORK_SUGGESTION_APPLY_MIN_EXPOSURE_USERS,
    NETWORK_SUGGESTION_APPLY_COOLDOWN_MS,
    NETWORK_SUGGESTION_APPLY_CONFIRMATION_TOKEN
  });
  const teacherLinkModerationRuntime = createTeacherLinkModerationRuntime({
    sqlGet,
    sqlAll,
    sqlRun,
    normalizeCohortValue,
    roleAtLeast,
    TEACHER_NETWORK_MIN_CLASS_YEAR,
    TEACHER_NETWORK_MAX_CLASS_YEAR,
    TEACHER_COHORT_VALUE,
    normalizeTeacherAlumniRelationshipType,
    normalizeTeacherLinkCreatedVia,
    normalizeTeacherLinkSourceSurface,
    normalizeTeacherLinkReviewStatus,
    normalizeTeacherLinkReviewNote,
    ensureTeacherAlumniLinksTable,
    ensureTeacherAlumniLinkModerationEventsTable
  });
  const discoveryPayloadRuntime = createNetworkDiscoveryPayloadRuntime({
    sqlGetAsync,
    sqlAllAsync,
    hasTable,
    hasColumn,
    ensureConnectionRequestsTable,
    ensureMentorshipRequestsTable,
    ensureTeacherAlumniLinksTable,
    getAssignedNetworkSuggestionVariant,
    getSafeAssignedNetworkSuggestionVariant,
    readExploreSuggestionsCache,
    writeExploreSuggestionsCache,
    buildScoredNetworkSuggestion,
    createPeerMap,
    getPeerOverlapCount,
    mapNetworkSuggestionForApi,
    sortNetworkSuggestions
  });
  const opportunityInboxRuntime = createOpportunityInboxRuntime({
    sqlGetAsync,
    sqlAllAsync,
    hasTable,
    hasColumn,
    buildNetworkInboxPayload: discoveryPayloadRuntime.buildNetworkInboxPayload,
    buildExploreSuggestionsPayload: discoveryPayloadRuntime.buildExploreSuggestionsPayload
  });

  return {
    NETWORK_SUGGESTION_APPLY_CONFIRMATION_TOKEN,
    normalizeMentorshipStatus,
    normalizeConnectionStatus,
    normalizeTeacherAlumniRelationshipType,
    normalizeTeacherLinkCreatedVia,
    normalizeTeacherLinkSourceSurface,
    normalizeTeacherLinkReviewStatus,
    normalizeNetworkingTelemetryEventName,
    normalizeTeacherLinkReviewNote,
    normalizeBooleanFlag,
    parseTeacherNetworkClassYear,
    calculateCooldownRemainingSeconds,
    apiSuccessEnvelope,
    sendApiError,
    ensureConnectionRequestsTable,
    ensureMentorshipRequestsTable,
    ensureTeacherAlumniLinksTable,
    ensureTeacherAlumniLinkModerationEventsTable,
    ensureNetworkingTelemetryEventsTable,
    ensureMemberNetworkingDailySummaryTable,
    ensureNetworkingSummaryMetaTable,
    ensureNetworkSuggestionAbTables,
    toSummaryDateKey,
    recordNetworkingTelemetryEvent,
    ...adminAnalyticsRuntime,
    ...teacherLinkModerationRuntime,
    ...discoveryPayloadRuntime,
    ...opportunityInboxRuntime
  };
}
