export function createNetworkingRuntime({
  sqlGet,
  sqlAll,
  sqlRun,
  sqlGetAsync,
  sqlAllAsync,
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

  const NETWORKING_DAILY_SUMMARY_REBUILD_INTERVAL_MS = 60 * 1000;
  const NETWORK_SUGGESTION_APPLY_MIN_EXPOSURE_USERS = 2;
  const NETWORK_SUGGESTION_APPLY_COOLDOWN_MS = 10 * 60 * 1000;
  const NETWORK_SUGGESTION_APPLY_CONFIRMATION_TOKEN = 'apply';
  let networkingDailySummaryRefreshPromise = null;

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

  async function rebuildMemberNetworkingDailySummary() {
    ensureConnectionRequestsTable();
    ensureMentorshipRequestsTable();
    ensureTeacherAlumniLinksTable();
    ensureNetworkingTelemetryEventsTable();
    ensureMemberNetworkingDailySummaryTable();
    ensureNetworkingSummaryMetaTable();

    const [userRows, connectionRows, mentorshipRows, teacherLinkRows, telemetryRows] = await Promise.all([
      sqlAllAsync(`SELECT id, LOWER(COALESCE(NULLIF(CAST(mezuniyetyili AS TEXT), ''), 'unknown')) AS cohort FROM uyeler`),
      sqlAllAsync(`SELECT sender_id AS user_id, status, created_at FROM connection_requests WHERE COALESCE(TRIM(created_at), '') <> ''`),
      sqlAllAsync(`SELECT requester_id AS user_id, status, created_at FROM mentorship_requests WHERE COALESCE(TRIM(created_at), '') <> ''`),
      sqlAllAsync(`SELECT COALESCE(created_by, alumni_user_id) AS user_id, created_at FROM teacher_alumni_links WHERE COALESCE(TRIM(created_at), '') <> ''`),
      sqlAllAsync(`SELECT user_id, event_name, created_at FROM networking_telemetry_events WHERE COALESCE(TRIM(created_at), '') <> ''`)
    ]);

    const cohortMap = new Map();
    for (const row of userRows || []) {
      cohortMap.set(Number(row?.id || 0), String(row?.cohort || 'unknown').trim().toLowerCase() || 'unknown');
    }

    const summaryMap = new Map();
    function getBucket(userId, dateKey) {
      const safeUserId = Number(userId || 0);
      if (!safeUserId || !dateKey) return null;
      const mapKey = `${safeUserId}:${dateKey}`;
      if (!summaryMap.has(mapKey)) {
        summaryMap.set(mapKey, {
          user_id: safeUserId,
          date: dateKey,
          cohort: cohortMap.get(safeUserId) || 'unknown',
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
        });
      }
      return summaryMap.get(mapKey);
    }

    for (const row of connectionRows || []) {
      const bucket = getBucket(row?.user_id, toSummaryDateKey(row?.created_at));
      if (!bucket) continue;
      incrementNetworkingDailySummaryMetric(bucket, 'connections_requested', 1);
      const status = String(row?.status || '').trim().toLowerCase();
      if (status === 'accepted') incrementNetworkingDailySummaryMetric(bucket, 'connections_accepted', 1);
      else if (status === 'pending') incrementNetworkingDailySummaryMetric(bucket, 'connections_pending', 1);
      else if (status === 'ignored') incrementNetworkingDailySummaryMetric(bucket, 'connections_ignored', 1);
      else if (status === 'declined') incrementNetworkingDailySummaryMetric(bucket, 'connections_declined', 1);
      else if (status === 'cancelled') incrementNetworkingDailySummaryMetric(bucket, 'connections_cancelled', 1);
    }

    for (const row of mentorshipRows || []) {
      const bucket = getBucket(row?.user_id, toSummaryDateKey(row?.created_at));
      if (!bucket) continue;
      incrementNetworkingDailySummaryMetric(bucket, 'mentorship_requested', 1);
      const status = String(row?.status || '').trim().toLowerCase();
      if (status === 'accepted') incrementNetworkingDailySummaryMetric(bucket, 'mentorship_accepted', 1);
      else if (status === 'declined') incrementNetworkingDailySummaryMetric(bucket, 'mentorship_declined', 1);
    }

    for (const row of teacherLinkRows || []) {
      const bucket = getBucket(row?.user_id, toSummaryDateKey(row?.created_at));
      if (!bucket) continue;
      incrementNetworkingDailySummaryMetric(bucket, 'teacher_links_created', 1);
    }

    for (const row of telemetryRows || []) {
      const bucket = getBucket(row?.user_id, toSummaryDateKey(row?.created_at));
      if (!bucket) continue;
      const eventName = String(row?.event_name || '').trim().toLowerCase();
      if (eventName === 'teacher_links_read') incrementNetworkingDailySummaryMetric(bucket, 'teacher_links_read', 1);
      else if (eventName === 'follow_created') incrementNetworkingDailySummaryMetric(bucket, 'follow_created', 1);
      else if (eventName === 'follow_removed') incrementNetworkingDailySummaryMetric(bucket, 'follow_removed', 1);
      else if (eventName === 'network_hub_viewed') incrementNetworkingDailySummaryMetric(bucket, 'hub_views', 1);
      else if (eventName === 'network_hub_suggestions_loaded') incrementNetworkingDailySummaryMetric(bucket, 'hub_suggestion_loads', 1);
      else if (eventName === 'network_explore_viewed') incrementNetworkingDailySummaryMetric(bucket, 'explore_views', 1);
      else if (eventName === 'network_explore_suggestions_loaded') incrementNetworkingDailySummaryMetric(bucket, 'explore_suggestion_loads', 1);
      else if (eventName === 'teacher_network_viewed') incrementNetworkingDailySummaryMetric(bucket, 'teacher_network_views', 1);
    }

    sqlRun('DELETE FROM member_networking_daily_summary');
    const now = new Date().toISOString();
    for (const row of summaryMap.values()) {
      sqlRun(
        `INSERT INTO member_networking_daily_summary (
           user_id, date, cohort, connections_requested, connections_accepted, connections_pending,
           connections_ignored, connections_declined, connections_cancelled, mentorship_requested,
           mentorship_accepted, mentorship_declined, teacher_links_created, teacher_links_read,
           follow_created, follow_removed, hub_views, hub_suggestion_loads, explore_views,
           explore_suggestion_loads, teacher_network_views, updated_at
         ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
        [
          row.user_id,
          row.date,
          row.cohort,
          row.connections_requested,
          row.connections_accepted,
          row.connections_pending,
          row.connections_ignored,
          row.connections_declined,
          row.connections_cancelled,
          row.mentorship_requested,
          row.mentorship_accepted,
          row.mentorship_declined,
          row.teacher_links_created,
          row.teacher_links_read,
          row.follow_created,
          row.follow_removed,
          row.hub_views,
          row.hub_suggestion_loads,
          row.explore_views,
          row.explore_suggestion_loads,
          row.teacher_network_views,
          now
        ]
      );
    }

    sqlRun(
      `INSERT INTO networking_summary_meta (key, value, updated_at)
       VALUES ('member_networking_daily_summary:last_rebuilt_at', ?, ?)
       ON CONFLICT(key) DO UPDATE SET value = excluded.value, updated_at = excluded.updated_at`,
      [now, now]
    );

    return { lastRebuiltAt: now, rows: summaryMap.size };
  }

  async function refreshMemberNetworkingDailySummaryIfStale() {
    ensureNetworkingSummaryMetaTable();
    ensureMemberNetworkingDailySummaryTable();
    const lastRebuiltAt = sqlGet(
      "SELECT value FROM networking_summary_meta WHERE key = 'member_networking_daily_summary:last_rebuilt_at'"
    )?.value || '';
    const lastRebuiltMs = toDateMs(lastRebuiltAt);
    const hasRows = Number(sqlGet('SELECT COUNT(*) AS cnt FROM member_networking_daily_summary')?.cnt || 0) > 0;
    const isFresh = hasRows && lastRebuiltMs !== null && (Date.now() - lastRebuiltMs) < NETWORKING_DAILY_SUMMARY_REBUILD_INTERVAL_MS;
    if (isFresh) {
      return { lastRebuiltAt, rows: Number(sqlGet('SELECT COUNT(*) AS cnt FROM member_networking_daily_summary')?.cnt || 0), skipped: true };
    }
    if (!networkingDailySummaryRefreshPromise) {
      networkingDailySummaryRefreshPromise = rebuildMemberNetworkingDailySummary()
        .finally(() => {
          networkingDailySummaryRefreshPromise = null;
        });
    }
    return networkingDailySummaryRefreshPromise;
  }

  function buildNetworkingAnalyticsAlerts(summaryTotals, mentorDemandRows = [], mentorSupplyRows = []) {
    const alerts = [];
    const connectionsRequested = Number(summaryTotals?.connections_requested || 0);
    const connectionsAccepted = Number(summaryTotals?.connections_accepted || 0);
    const mentorshipRequested = Number(summaryTotals?.mentorship_requested || 0);
    const mentorshipAccepted = Number(summaryTotals?.mentorship_accepted || 0);
    const teacherLinksCreated = Number(summaryTotals?.teacher_links_created || 0);
    const teacherLinksRead = Number(summaryTotals?.teacher_links_read || 0);
    const hubViews = Number(summaryTotals?.hub_views || 0);
    const exploreViews = Number(summaryTotals?.explore_views || 0);
    const activationActions = connectionsRequested + mentorshipRequested + teacherLinksCreated;
    const connectionAcceptanceRate = connectionsRequested > 0 ? connectionsAccepted / connectionsRequested : 0;
    const mentorshipAcceptanceRate = mentorshipRequested > 0 ? mentorshipAccepted / mentorshipRequested : 0;
    const teacherLinkReadRate = teacherLinksCreated > 0 ? teacherLinksRead / teacherLinksCreated : 1;

    if (connectionsRequested >= 3 && connectionAcceptanceRate < 0.35) {
      alerts.push({
        code: 'connection_acceptance_low',
        severity: 'high',
        title: 'Connection acceptance rate is low',
        description: 'Bağlantı istekleri gönderiliyor ama kabul oranı beklenen seviyenin altında kaldı.',
        metric: Number((connectionAcceptanceRate * 100).toFixed(2))
      });
    }

    if (mentorshipRequested >= 2 && mentorshipAcceptanceRate < 0.25) {
      alerts.push({
        code: 'mentorship_acceptance_low',
        severity: 'medium',
        title: 'Mentorship acceptance rate is low',
        description: 'Mentorluk talep hacmi var ancak kabul oranı zayıf görünüyor.',
        metric: Number((mentorshipAcceptanceRate * 100).toFixed(2))
      });
    }

    if (teacherLinksCreated >= 1 && teacherLinkReadRate < 0.5) {
      alerts.push({
        code: 'teacher_link_reads_lagging',
        severity: teacherLinksRead === 0 ? 'high' : 'medium',
        title: 'Teacher link read rate is lagging',
        description: 'Öğretmen bağı üretiliyor fakat bildirimlerin okunma oranı düşük; trust feedback görünürlüğü zayıf olabilir.',
        metric: Number((teacherLinkReadRate * 100).toFixed(2))
      });
    }

    const mentorSupplyMap = new Map(
      (mentorSupplyRows || []).map((row) => [String(row?.cohort || '').trim().toLowerCase(), Number(row?.count || 0)])
    );
    const demandGap = (mentorDemandRows || [])
      .map((row) => {
        const cohort = String(row?.cohort || '').trim().toLowerCase();
        const demand = Number(row?.count || 0);
        const supply = Number(mentorSupplyMap.get(cohort) || 0);
        return { cohort, demand, supply, gap: demand - supply };
      })
      .sort((a, b) => b.gap - a.gap)[0];
    if (demandGap && demandGap.gap >= 2) {
      alerts.push({
        code: 'mentor_supply_gap',
        severity: 'medium',
        title: 'Mentor supply is behind demand',
        description: `${demandGap.cohort} cohortunda mentorluk talebi arzın önüne geçti.`,
        metric: demandGap.gap,
        cohort: demandGap.cohort
      });
    }

    if ((hubViews + exploreViews) >= 10 && activationActions === 0) {
      alerts.push({
        code: 'networking_activation_low',
        severity: 'medium',
        title: 'Visibility is not turning into networking actions',
        description: 'Hub ve Explore görüntüleniyor fakat bağlantı, mentorluk veya teacher-link aksiyonları oluşmuyor.',
        metric: hubViews + exploreViews
      });
    }

    return alerts;
  }

  function parseTelemetryMetadataJson(value) {
    if (!value) return {};
    try {
      const parsed = JSON.parse(String(value || '{}'));
      return parsed && typeof parsed === 'object' ? parsed : {};
    } catch {
      return {};
    }
  }

  function resolveNetworkSuggestionVariant(value, fallback = 'A') {
    const raw = String(value || fallback || 'A').trim().toUpperCase();
    return raw || 'A';
  }

  function rateFromCounts(numerator, denominator) {
    const top = Number(numerator || 0);
    const bottom = Number(denominator || 0);
    if (bottom <= 0) return 0;
    return Number((top / bottom).toFixed(4));
  }

  function parseJsonValue(value, fallback = null) {
    if (!value) return fallback;
    try {
      return JSON.parse(String(value));
    } catch {
      return fallback;
    }
  }

  function snapshotNetworkSuggestionConfigs(configs = [], variants = []) {
    const variantSet = new Set((variants || []).map((variant) => resolveNetworkSuggestionVariant(variant)));
    return (configs || [])
      .filter((cfg) => variantSet.has(resolveNetworkSuggestionVariant(cfg.variant)))
      .map((cfg) => ({
        variant: resolveNetworkSuggestionVariant(cfg.variant),
        name: String(cfg.name || ''),
        description: String(cfg.description || ''),
        trafficPct: Number(cfg.trafficPct || 0),
        enabled: Number(cfg.enabled || 0) === 1 ? 1 : 0,
        params: { ...(cfg.params || {}) },
        updatedAt: cfg.updatedAt || null
      }))
      .sort((a, b) => String(a.variant).localeCompare(String(b.variant)));
  }

  function listNetworkSuggestionAbRecentChanges(limit = 8) {
    ensureNetworkSuggestionAbTables();
    const rows = sqlAll(
      `SELECT id, action_type, related_change_id, actor_user_id, recommendation_index, cohort, window_days,
              payload_json, before_snapshot_json, after_snapshot_json, created_at, rolled_back_at, rollback_change_id
       FROM network_suggestion_ab_change_log
       ORDER BY id DESC
       LIMIT ?`,
      [Math.min(Math.max(Number(limit || 8), 1), 20)]
    );
    return rows.map((row) => ({
      id: Number(row.id || 0),
      action_type: String(row.action_type || 'apply'),
      related_change_id: Number(row.related_change_id || 0) || null,
      actor_user_id: Number(row.actor_user_id || 0) || null,
      recommendation_index: Number(row.recommendation_index || 0),
      cohort: String(row.cohort || 'all'),
      window_days: Number(row.window_days || 30),
      payload: parseJsonValue(row.payload_json, {}) || {},
      before_snapshot: parseJsonValue(row.before_snapshot_json, []) || [],
      after_snapshot: parseJsonValue(row.after_snapshot_json, []) || [],
      created_at: row.created_at || null,
      rolled_back_at: row.rolled_back_at || null,
      rollback_change_id: Number(row.rollback_change_id || 0) || null
    }));
  }

  function pickPrimaryRecommendationVariant(change) {
    return resolveNetworkSuggestionVariant(
      change?.payload?.variant
        || change?.after_snapshot?.[0]?.variant
        || change?.before_snapshot?.[0]?.variant
        || 'A'
    );
  }

  function toWindowShiftIso(value, daysDelta) {
    const baseMs = toDateMs(value);
    if (baseMs === null) return '';
    return new Date(baseMs + Number(daysDelta || 0) * 24 * 60 * 60 * 1000).toISOString();
  }

  function buildVariantDelta(beforeRow = {}, afterRow = {}) {
    const beforeActivation = Number(beforeRow?.activation_rate || 0);
    const afterActivation = Number(afterRow?.activation_rate || 0);
    const beforeConnection = Number(beforeRow?.connection_request_rate || 0);
    const afterConnection = Number(afterRow?.connection_request_rate || 0);
    const beforeMentorship = Number(beforeRow?.mentorship_request_rate || 0);
    const afterMentorship = Number(afterRow?.mentorship_request_rate || 0);
    const beforeTeacher = Number(beforeRow?.teacher_link_create_rate || 0);
    const afterTeacher = Number(afterRow?.teacher_link_create_rate || 0);

    const weightedBefore = beforeActivation * 0.55 + beforeConnection * 0.2 + beforeMentorship * 0.15 + beforeTeacher * 0.1;
    const weightedAfter = afterActivation * 0.55 + afterConnection * 0.2 + afterMentorship * 0.15 + afterTeacher * 0.1;
    const weightedDelta = Number((weightedAfter - weightedBefore).toFixed(4));

    let status = 'neutral';
    if (Number(afterRow?.exposure_users || 0) < 1 || Number(beforeRow?.exposure_users || 0) < 1) {
      status = 'insufficient_data';
    } else if (weightedDelta >= 0.03) {
      status = 'positive';
    } else if (weightedDelta <= -0.03) {
      status = 'negative';
    }

    return {
      status,
      weighted_delta: weightedDelta,
      exposure_users_delta: Number(afterRow?.exposure_users || 0) - Number(beforeRow?.exposure_users || 0),
      activation_rate_delta: Number((afterActivation - beforeActivation).toFixed(4)),
      connection_request_rate_delta: Number((afterConnection - beforeConnection).toFixed(4)),
      mentorship_request_rate_delta: Number((afterMentorship - beforeMentorship).toFixed(4)),
      teacher_link_create_rate_delta: Number((afterTeacher - beforeTeacher).toFixed(4))
    };
  }

  async function getNetworkSuggestionExperimentDataset({ sinceIso, untilIso = '', cohort = 'all' } = {}) {
    ensureNetworkingTelemetryEventsTable();
    ensureNetworkSuggestionAbTables();
    const includeCohort = String(cohort || 'all').trim().toLowerCase() !== 'all';
    const normalizedCohort = normalizeCohortValue(cohort);
    const includeUpperBound = Boolean(untilIso);
    const telemetryCohortSql = includeCohort
      ? "AND LOWER(COALESCE(NULLIF(CAST(u.mezuniyetyili AS TEXT), ''), 'unknown')) = LOWER(?)"
      : '';
    const telemetryUpperSql = includeUpperBound ? 'AND e.created_at < ?' : '';
    const telemetryParams = includeCohort
      ? (includeUpperBound ? [sinceIso, untilIso, normalizedCohort] : [sinceIso, normalizedCohort])
      : (includeUpperBound ? [sinceIso, untilIso] : [sinceIso]);
    const assignmentParams = includeCohort ? [normalizedCohort] : [];
    const assignmentWhere = includeCohort
      ? "WHERE LOWER(COALESCE(NULLIF(CAST(u.mezuniyetyili AS TEXT), ''), 'unknown')) = LOWER(?)"
      : '';

    const [exposureRows, actionRows, assignmentCounts] = await Promise.all([
      sqlAllAsync(
        `SELECT e.user_id, e.event_name, e.metadata_json, e.created_at, a.variant AS assigned_variant
         FROM networking_telemetry_events e
         LEFT JOIN network_suggestion_ab_assignments a ON a.user_id = e.user_id
         LEFT JOIN uyeler u ON u.id = e.user_id
         WHERE e.created_at >= ?
           ${telemetryUpperSql}
           AND e.event_name IN ('network_hub_suggestions_loaded', 'network_explore_suggestions_loaded')
           ${telemetryCohortSql}
         ORDER BY e.user_id ASC, e.created_at ASC`,
        telemetryParams
      ),
      sqlAllAsync(
        `SELECT e.user_id, e.event_name, e.metadata_json, e.created_at, a.variant AS assigned_variant
         FROM networking_telemetry_events e
         LEFT JOIN network_suggestion_ab_assignments a ON a.user_id = e.user_id
         LEFT JOIN uyeler u ON u.id = e.user_id
         WHERE e.created_at >= ?
           ${telemetryUpperSql}
           AND e.event_name IN ('follow_created', 'connection_requested', 'mentorship_requested', 'teacher_link_created')
           ${telemetryCohortSql}
         ORDER BY e.user_id ASC, e.created_at ASC`,
        telemetryParams
      ),
      sqlAllAsync(
        `SELECT a.variant, COUNT(*) AS cnt
         FROM network_suggestion_ab_assignments a
         LEFT JOIN uyeler u ON u.id = a.user_id
         ${assignmentWhere}
         GROUP BY a.variant
         ORDER BY a.variant ASC`,
        assignmentParams
      )
    ]);

    return { exposureRows, actionRows, assignmentCounts };
  }

  async function evaluateNetworkSuggestionChange(change) {
    if (!change || String(change.action_type || '') !== 'apply') return null;
    const variant = pickPrimaryRecommendationVariant(change);
    const windowDays = Math.max(1, Number(change.window_days || 30));
    const beforeSinceIso = toWindowShiftIso(change.created_at, -windowDays);
    const afterUntilIso = change.rolled_back_at || toWindowShiftIso(change.created_at, windowDays) || new Date().toISOString();
    const effectiveAfterUntilIso = toDateMs(afterUntilIso) !== null && toDateMs(afterUntilIso) < Date.now()
      ? afterUntilIso
      : new Date().toISOString();

    const [beforeDataset, afterDataset] = await Promise.all([
      getNetworkSuggestionExperimentDataset({
        sinceIso: beforeSinceIso,
        untilIso: change.created_at,
        cohort: change.cohort || 'all'
      }),
      getNetworkSuggestionExperimentDataset({
        sinceIso: change.created_at,
        untilIso: effectiveAfterUntilIso,
        cohort: change.cohort || 'all'
      })
    ]);

    const configs = getNetworkSuggestionAbConfigs();
    const beforePerformance = buildNetworkSuggestionExperimentAnalytics({
      exposureRows: beforeDataset.exposureRows,
      actionRows: beforeDataset.actionRows,
      configs,
      assignmentCounts: beforeDataset.assignmentCounts
    });
    const afterPerformance = buildNetworkSuggestionExperimentAnalytics({
      exposureRows: afterDataset.exposureRows,
      actionRows: afterDataset.actionRows,
      configs,
      assignmentCounts: afterDataset.assignmentCounts
    });
    const beforeRow = beforePerformance.variants.find((row) => resolveNetworkSuggestionVariant(row.variant) === variant) || { variant };
    const afterRow = afterPerformance.variants.find((row) => resolveNetworkSuggestionVariant(row.variant) === variant) || { variant };
    const delta = buildVariantDelta(beforeRow, afterRow);

    return {
      variant,
      window_days: windowDays,
      before: beforeRow,
      after: afterRow,
      delta,
      status: delta.status
    };
  }

  async function listNetworkSuggestionAbRecentChangesWithEvaluation(limit = 8) {
    const changes = listNetworkSuggestionAbRecentChanges(limit);
    const enriched = await Promise.all(changes.map(async (change) => ({
      ...change,
      evaluation: await evaluateNetworkSuggestionChange(change)
    })));
    return enriched;
  }

  function buildNetworkSuggestionExperimentAnalytics({
    exposureRows = [],
    actionRows = [],
    configs = [],
    assignmentCounts = []
  } = {}) {
    const variantMetaMap = new Map((configs || []).map((cfg) => [String(cfg.variant || '').trim().toUpperCase(), cfg]));
    const variants = new Map();

    function ensureVariantBucket(variantKey) {
      const variant = resolveNetworkSuggestionVariant(variantKey);
      if (!variants.has(variant)) {
        const meta = variantMetaMap.get(variant) || {};
        variants.set(variant, {
          variant,
          name: String(meta.name || variant),
          description: String(meta.description || ''),
          traffic_pct: Number(meta.trafficPct || 0),
          enabled: Number(meta.enabled || 0) === 1 ? 1 : 0,
          assignment_count: 0,
          exposure_user_ids: new Set(),
          exposed_user_ids: new Set(),
          activated_user_ids: new Set(),
          follow_user_ids: new Set(),
          connection_user_ids: new Set(),
          mentorship_user_ids: new Set(),
          teacher_link_user_ids: new Set(),
          exposure_events: 0,
          suggestion_impressions: 0,
          action_events: 0,
          actions: {
            follow_created: 0,
            connection_requested: 0,
            mentorship_requested: 0,
            teacher_link_created: 0
          }
        });
      }
      return variants.get(variant);
    }

    for (const cfg of configs || []) ensureVariantBucket(cfg?.variant);
    for (const row of assignmentCounts || []) ensureVariantBucket(row?.variant).assignment_count = Number(row?.cnt || 0);

    const exposureTimelineByUser = new Map();
    for (const row of exposureRows || []) {
      const userId = Number(row?.user_id || 0);
      if (!userId) continue;
      const metadata = parseTelemetryMetadataJson(row?.metadata_json);
      const variant = resolveNetworkSuggestionVariant(
        metadata.experiment_variant || metadata.network_suggestion_variant || row?.assigned_variant || 'A'
      );
      const bucket = ensureVariantBucket(variant);
      const suggestionCount = Math.max(0, Number(metadata.suggestion_count || 0));
      const ts = toDateMs(row?.created_at);
      bucket.exposure_events += 1;
      bucket.suggestion_impressions += suggestionCount;
      bucket.exposure_user_ids.add(userId);
      if (!exposureTimelineByUser.has(userId)) exposureTimelineByUser.set(userId, []);
      exposureTimelineByUser.get(userId).push({
        variant,
        ts: ts === null ? Number.MIN_SAFE_INTEGER : ts
      });
    }
    for (const timeline of exposureTimelineByUser.values()) timeline.sort((a, b) => Number(a.ts || 0) - Number(b.ts || 0));

    for (const row of actionRows || []) {
      const userId = Number(row?.user_id || 0);
      if (!userId) continue;
      const timeline = exposureTimelineByUser.get(userId);
      if (!timeline?.length) continue;
      const actionTs = toDateMs(row?.created_at);
      const comparableTs = actionTs === null ? Number.MAX_SAFE_INTEGER : actionTs;
      let attributedExposure = null;
      for (const exposure of timeline) {
        if (Number(exposure.ts || 0) <= comparableTs) attributedExposure = exposure;
        else break;
      }
      if (!attributedExposure) continue;
      const bucket = ensureVariantBucket(attributedExposure.variant);
      const eventName = normalizeNetworkingTelemetryEventName(row?.event_name);
      if (!['follow_created', 'connection_requested', 'mentorship_requested', 'teacher_link_created'].includes(eventName)) continue;
      bucket.action_events += 1;
      bucket.activated_user_ids.add(userId);
      bucket.exposed_user_ids.add(userId);
      bucket.actions[eventName] = Number(bucket.actions[eventName] || 0) + 1;
      if (eventName === 'follow_created') bucket.follow_user_ids.add(userId);
      else if (eventName === 'connection_requested') bucket.connection_user_ids.add(userId);
      else if (eventName === 'mentorship_requested') bucket.mentorship_user_ids.add(userId);
      else if (eventName === 'teacher_link_created') bucket.teacher_link_user_ids.add(userId);
    }

    for (const bucket of variants.values()) {
      for (const userId of bucket.exposure_user_ids) bucket.exposed_user_ids.add(userId);
    }

    const variantRows = Array.from(variants.values()).map((bucket) => {
      const exposureUsers = bucket.exposed_user_ids.size;
      const activatedUsers = bucket.activated_user_ids.size;
      return {
        variant: bucket.variant,
        name: bucket.name,
        description: bucket.description,
        traffic_pct: bucket.traffic_pct,
        enabled: bucket.enabled,
        assignment_count: bucket.assignment_count,
        exposure_users: exposureUsers,
        exposure_events: bucket.exposure_events,
        suggestion_impressions: bucket.suggestion_impressions,
        activated_users: activatedUsers,
        activation_rate: rateFromCounts(activatedUsers, exposureUsers),
        action_events: bucket.action_events,
        follow_created: Number(bucket.actions.follow_created || 0),
        follow_conversion_rate: rateFromCounts(bucket.follow_user_ids.size, exposureUsers),
        connection_requested: Number(bucket.actions.connection_requested || 0),
        connection_request_rate: rateFromCounts(bucket.connection_user_ids.size, exposureUsers),
        mentorship_requested: Number(bucket.actions.mentorship_requested || 0),
        mentorship_request_rate: rateFromCounts(bucket.mentorship_user_ids.size, exposureUsers),
        teacher_link_created: Number(bucket.actions.teacher_link_created || 0),
        teacher_link_create_rate: rateFromCounts(bucket.teacher_link_user_ids.size, exposureUsers)
      };
    }).sort((a, b) => {
      if (Number(b.activation_rate || 0) !== Number(a.activation_rate || 0)) return Number(b.activation_rate || 0) - Number(a.activation_rate || 0);
      if (Number(b.activated_users || 0) !== Number(a.activated_users || 0)) return Number(b.activated_users || 0) - Number(a.activated_users || 0);
      return String(a.variant || '').localeCompare(String(b.variant || ''));
    });

    const leadingVariant = variantRows.find((row) => Number(row.exposure_users || 0) > 0) || null;
    const totalExposureUsers = variantRows.reduce((sum, row) => sum + Number(row.exposure_users || 0), 0);
    const totalExposureEvents = variantRows.reduce((sum, row) => sum + Number(row.exposure_events || 0), 0);

    return {
      assignment_counts: (assignmentCounts || []).map((row) => ({
        variant: resolveNetworkSuggestionVariant(row?.variant),
        count: Number(row?.cnt || 0)
      })),
      total_exposure_users: totalExposureUsers,
      total_exposure_events: totalExposureEvents,
      leading_variant: leadingVariant
        ? {
            variant: leadingVariant.variant,
            activation_rate: leadingVariant.activation_rate,
            activated_users: leadingVariant.activated_users
          }
        : null,
      variants: variantRows
    };
  }

  function buildNetworkSuggestionRecommendationGuardrails(recommendation, performanceByVariant, recentChanges = []) {
    const blockers = [];
    let minimumExposureUsers = 0;
    const touchedVariants = new Set();

    if (recommendation?.patch) touchedVariants.add(resolveNetworkSuggestionVariant(recommendation.variant));
    if (recommendation?.trafficPatch && typeof recommendation.trafficPatch === 'object') {
      for (const variantKey of Object.keys(recommendation.trafficPatch)) touchedVariants.add(resolveNetworkSuggestionVariant(variantKey));
    }

    for (const variant of touchedVariants) {
      const perf = performanceByVariant.get(variant);
      const exposureUsers = Number(perf?.exposure_users || 0);
      minimumExposureUsers = minimumExposureUsers === 0 ? exposureUsers : Math.min(minimumExposureUsers, exposureUsers);
    }

    if (minimumExposureUsers < NETWORK_SUGGESTION_APPLY_MIN_EXPOSURE_USERS) {
      blockers.push(`Minimum ${NETWORK_SUGGESTION_APPLY_MIN_EXPOSURE_USERS} exposure user gereklidir.`);
    }

    const lastApply = (recentChanges || []).find((row) => row?.action_type === 'apply' && !row?.rolled_back_at);
    const lastApplyMs = toDateMs(lastApply?.created_at);
    const cooldownRemainingMs = lastApplyMs !== null
      ? Math.max(0, NETWORK_SUGGESTION_APPLY_COOLDOWN_MS - (Date.now() - lastApplyMs))
      : 0;
    if (cooldownRemainingMs > 0) {
      blockers.push(`Cooldown aktif. Yaklaşık ${Math.ceil(cooldownRemainingMs / 60_000)} dakika bekleyin.`);
    }

    return {
      confirmation_required: true,
      confirmation_token: NETWORK_SUGGESTION_APPLY_CONFIRMATION_TOKEN,
      minimum_exposure_users: NETWORK_SUGGESTION_APPLY_MIN_EXPOSURE_USERS,
      observed_minimum_exposure_users: minimumExposureUsers,
      cooldown_active: cooldownRemainingMs > 0,
      cooldown_remaining_seconds: Math.ceil(cooldownRemainingMs / 1000),
      can_apply: blockers.length === 0,
      blockers
    };
  }

  function buildNetworkSuggestionAbRecommendations(configs = [], performance = [], recentChanges = []) {
    const perfMap = new Map((performance || []).map((row) => [resolveNetworkSuggestionVariant(row?.variant), row]));
    const configMap = new Map((configs || []).map((cfg) => [resolveNetworkSuggestionVariant(cfg?.variant), cfg]));
    const baseline = perfMap.get('A') || performance?.[0] || null;
    const recommendations = [];

    for (const cfg of (configs || [])) {
      const variant = resolveNetworkSuggestionVariant(cfg?.variant);
      const perf = perfMap.get(variant);
      if (!perf || Number(perf.exposure_users || 0) < 1) continue;

      const p = cfg.params || networkSuggestionDefaultParams;
      const patch = {};
      const reasons = [];
      const confidenceParts = [];

      if (baseline && baseline.variant !== variant && Number(baseline.exposure_users || 0) >= 1) {
        const baselineActivation = Math.max(Number(baseline.activation_rate || 0), 0.01);
        const baselineConnection = Math.max(Number(baseline.connection_request_rate || 0), 0.01);
        const baselineMentorship = Math.max(Number(baseline.mentorship_request_rate || 0), 0.01);
        const baselineTeacher = Math.max(Number(baseline.teacher_link_create_rate || 0), 0.01);

        const activationDelta = (Number(perf.activation_rate || 0) - baselineActivation) / baselineActivation;
        const connectionDelta = (Number(perf.connection_request_rate || 0) - baselineConnection) / baselineConnection;
        const mentorshipDelta = (Number(perf.mentorship_request_rate || 0) - baselineMentorship) / baselineMentorship;
        const teacherDelta = (Number(perf.teacher_link_create_rate || 0) - baselineTeacher) / baselineTeacher;

        if (activationDelta < -0.12) {
          patch.secondDegreeWeight = round2(p.secondDegreeWeight * 1.06);
          patch.sharedGroupWeight = round2(p.sharedGroupWeight * 1.08);
          if (Number(p.engagementWeight || 0) > 0.12) patch.engagementWeight = round2(p.engagementWeight * 0.9);
          reasons.push(`Aktivasyon oranı baseline'ın gerisinde (${round2(activationDelta * 100)}%).`);
          confidenceParts.push(Math.min(0.35, Math.abs(activationDelta)));
        } else if (activationDelta > 0.1) {
          reasons.push(`Aktivasyon oranı baseline'ın üzerinde (${round2(activationDelta * 100)}%).`);
          confidenceParts.push(Math.min(0.28, activationDelta));
        }

        if (connectionDelta > 0.12) {
          patch.secondDegreeWeight = round2((patch.secondDegreeWeight || p.secondDegreeWeight) * 1.04);
          patch.maxSecondDegreeBonus = round2((patch.maxSecondDegreeBonus || p.maxSecondDegreeBonus) * 1.03);
          reasons.push('Bağlantı isteği dönüşümü güçlü; graph yakınlığı biraz daha öne çıkarılabilir.');
          confidenceParts.push(Math.min(0.2, connectionDelta));
        }

        if (mentorshipDelta > 0.12) {
          patch.directMentorshipBonus = round2((patch.directMentorshipBonus || p.directMentorshipBonus) * 1.05);
          patch.mentorshipOverlapWeight = round2((patch.mentorshipOverlapWeight || p.mentorshipOverlapWeight) * 1.04);
          reasons.push('Mentorluk talebi üretimi güçlü; mentorluk sinyalleri korunup hafif artırılabilir.');
          confidenceParts.push(Math.min(0.2, mentorshipDelta));
        }

        if (teacherDelta > 0.12) {
          patch.directTeacherBonus = round2((patch.directTeacherBonus || p.directTeacherBonus) * 1.05);
          patch.teacherOverlapWeight = round2((patch.teacherOverlapWeight || p.teacherOverlapWeight) * 1.04);
          reasons.push('Teacher network aksiyonları güçlü; öğretmen yakınlığı sinyali biraz daha artırılabilir.');
          confidenceParts.push(Math.min(0.2, teacherDelta));
        }
      }

      if (Number(perf.follow_conversion_rate || 0) > 0.2 && Number(perf.connection_request_rate || 0) < 0.08) {
        patch.secondDegreeWeight = round2((patch.secondDegreeWeight || p.secondDegreeWeight) * 1.04);
        patch.sharedGroupWeight = round2((patch.sharedGroupWeight || p.sharedGroupWeight) * 1.04);
        reasons.push('Follow dönüşümü var ama daha derin networking aksiyonları düşük; graph sinyalleri hafif güçlendirilebilir.');
        confidenceParts.push(0.12);
      }

      const normalizedPatch = normalizeNetworkSuggestionParams(
        { ...p, ...patch },
        networkSuggestionDefaultVariants[variant]?.params || networkSuggestionDefaultParams
      );
      const finalPatch = {};
      for (const key of Object.keys(p)) {
        if (Number(normalizedPatch[key]) !== Number(p[key])) finalPatch[key] = normalizedPatch[key];
      }
      if (!Object.keys(finalPatch).length) continue;

      const sampleFactor = Math.min(1, Number(perf.exposure_users || 0) / 40);
      const confidence = round2(clamp(0.18 + confidenceParts.reduce((sum, value) => sum + value, 0) + sampleFactor * 0.32, 0, 0.9));
      const recommendation = {
        variant,
        confidence,
        reasons: reasons.slice(0, 4),
        patch: finalPatch
      };
      recommendation.guardrails = buildNetworkSuggestionRecommendationGuardrails(recommendation, perfMap, recentChanges);
      recommendations.push(recommendation);
    }

    const activeConfigs = (configs || []).filter((cfg) => Number(cfg.enabled || 0) === 1);
    if (activeConfigs.length >= 2) {
      const scored = activeConfigs
        .map((cfg) => {
          const perf = perfMap.get(resolveNetworkSuggestionVariant(cfg.variant));
          if (!perf || Number(perf.exposure_users || 0) < 1) return null;
          const quality = Number(perf.activation_rate || 0) * 0.55
            + Number(perf.connection_request_rate || 0) * 0.2
            + Number(perf.mentorship_request_rate || 0) * 0.15
            + Number(perf.teacher_link_create_rate || 0) * 0.1;
          return { variant: resolveNetworkSuggestionVariant(cfg.variant), quality, exposureUsers: Number(perf.exposure_users || 0) };
        })
        .filter(Boolean)
        .sort((a, b) => Number(b.quality || 0) - Number(a.quality || 0));

      if (scored.length >= 2 && Number(scored[0].quality || 0) > Number(scored[1].quality || 0) * 1.08) {
        const winner = configMap.get(scored[0].variant);
        const loser = configMap.get(scored[scored.length - 1].variant);
        if (winner && loser) {
          const recommendation = {
            variant: scored[0].variant,
            confidence: round2(clamp(0.24 + Math.min(0.35, Number(scored[0].quality || 0) - Number(scored[1].quality || 0)), 0, 0.82)),
            reasons: [`${scored[0].variant} varyantı recommendation quality metriğinde daha güçlü performans gösteriyor.`],
            trafficPatch: {
              [scored[0].variant]: clamp(Number(winner.trafficPct || 0) + 5, 0, 100),
              [scored[scored.length - 1].variant]: clamp(Number(loser.trafficPct || 0) - 5, 0, 100)
            }
          };
          recommendation.guardrails = buildNetworkSuggestionRecommendationGuardrails(recommendation, perfMap, recentChanges);
          recommendations.push(recommendation);
        }
      }
    }

    return recommendations;
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
        createdAt || new Date().toISOString()
      ]
    );
  }

  function clampTeacherLinkConfidenceScore(value) {
    const numeric = Number(value || 0);
    if (!Number.isFinite(numeric)) return 0.05;
    return Math.max(0.05, Math.min(0.99, numeric));
  }

  function roundTeacherLinkConfidenceScore(value) {
    return Number(clampTeacherLinkConfidenceScore(value).toFixed(2));
  }

  function computeTeacherLinkConfidenceScore(row, duplicateProximityCount = 0) {
    let score = 0.52;
    const createdVia = normalizeTeacherLinkCreatedVia(row?.created_via);
    const sourceSurface = normalizeTeacherLinkSourceSurface(row?.source_surface);
    const reviewStatus = normalizeTeacherLinkReviewStatus(row?.review_status) || 'pending';
    const teacherRole = String(row?.teacher_role || '').trim().toLowerCase();
    const teacherCohort = normalizeCohortValue(row?.teacher_cohort);

    if (createdVia === 'manual_alumni_link') score += 0.08;
    if (createdVia === 'import') score += 0.03;
    if (sourceSurface === 'member_detail_page') score += 0.08;
    else if (sourceSurface === 'teachers_network_page') score += 0.04;
    else if (sourceSurface === 'network_hub') score += 0.03;
    if (Number(row?.teacher_verified || 0) === 1 || teacherRole === 'teacher' || teacherCohort === TEACHER_COHORT_VALUE || roleAtLeast(teacherRole, 'admin')) score += 0.16;
    if (Number(row?.alumni_verified || 0) === 1) score += 0.06;
    if (row?.class_year !== null && row?.class_year !== undefined && String(row.class_year).trim() !== '') score += 0.05;
    if (String(row?.notes || '').trim().length >= 12) score += 0.04;
    if (String(row?.relationship_type || '').trim().toLowerCase() === 'mentor') score += 0.05;
    if (reviewStatus === 'confirmed') score += 0.18;
    if (reviewStatus === 'flagged') score -= 0.28;

    const duplicatePenalty = Math.min(0.25, Math.max(0, Number(duplicateProximityCount || 0)) * 0.09);
    score -= duplicatePenalty;
    return roundTeacherLinkConfidenceScore(score);
  }

  function isTeacherLinkActiveStatus(value) {
    const status = normalizeTeacherLinkReviewStatus(value) || 'pending';
    return status !== 'rejected' && status !== 'merged';
  }

  function canTransitionTeacherLinkReviewStatus(currentStatus, nextStatus) {
    const current = normalizeTeacherLinkReviewStatus(currentStatus) || 'pending';
    const next = normalizeTeacherLinkReviewStatus(nextStatus);
    if (!next) return false;
    const allowedTransitions = {
      pending: ['confirmed', 'flagged', 'rejected', 'merged'],
      confirmed: ['pending', 'flagged', 'rejected', 'merged'],
      flagged: ['pending', 'confirmed', 'rejected', 'merged'],
      rejected: ['pending', 'confirmed', 'flagged'],
      merged: ['pending', 'confirmed', 'flagged']
    };
    return allowedTransitions[current]?.includes(next) || false;
  }

  function selectTeacherLinkMergeTarget(linkId, teacherUserId, alumniUserId, requestedTargetId = 0) {
    const safeLinkId = Number(linkId || 0);
    const safeTeacherUserId = Number(teacherUserId || 0);
    const safeAlumniUserId = Number(alumniUserId || 0);
    const safeRequestedTargetId = Number(requestedTargetId || 0);
    if (!safeLinkId || !safeTeacherUserId || !safeAlumniUserId) return null;

    if (safeRequestedTargetId > 0 && safeRequestedTargetId !== safeLinkId) {
      return sqlGet(
        `SELECT id, review_status
         FROM teacher_alumni_links
         WHERE id = ?
           AND teacher_user_id = ?
           AND alumni_user_id = ?
           AND COALESCE(review_status, 'pending') NOT IN ('rejected', 'merged')
         LIMIT 1`,
        [safeRequestedTargetId, safeTeacherUserId, safeAlumniUserId]
      ) || null;
    }

    return sqlGet(
      `SELECT id, review_status
       FROM teacher_alumni_links
       WHERE teacher_user_id = ?
         AND alumni_user_id = ?
         AND id <> ?
         AND COALESCE(review_status, 'pending') NOT IN ('rejected', 'merged')
       ORDER BY CASE WHEN COALESCE(review_status, 'pending') = 'confirmed' THEN 0 ELSE 1 END ASC,
                COALESCE(confidence_score, 0) DESC,
                COALESCE(CASE WHEN CAST(created_at AS TEXT) = '' THEN NULL ELSE created_at END, '1970-01-01T00:00:00.000Z') DESC,
                id DESC
       LIMIT 1`,
      [safeTeacherUserId, safeAlumniUserId, safeLinkId]
    ) || null;
  }

  function logTeacherLinkModerationEvent({ linkId, actorUserId = null, eventType, fromStatus = '', toStatus = '', note = '', mergeTargetId = null }) {
    const safeLinkId = Number(linkId || 0);
    const safeMergeTargetId = Number(mergeTargetId || 0) || null;
    const safeEventType = String(eventType || '').trim().slice(0, 64);
    if (!safeLinkId || !safeEventType) return;
    ensureTeacherAlumniLinkModerationEventsTable();
    sqlRun(
      `INSERT INTO teacher_alumni_link_moderation_events
         (link_id, actor_user_id, event_type, from_status, to_status, note, merge_target_id, created_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        safeLinkId,
        Number(actorUserId || 0) || null,
        safeEventType,
        normalizeTeacherLinkReviewStatus(fromStatus) || null,
        normalizeTeacherLinkReviewStatus(toStatus) || null,
        normalizeTeacherLinkReviewNote(note) || null,
        safeMergeTargetId,
        new Date().toISOString()
      ]
    );
  }

  function buildTeacherLinkModerationAssessment(row) {
    const reviewStatus = normalizeTeacherLinkReviewStatus(row?.review_status) || 'pending';
    const confidenceScore = Number(row?.confidence_score || 0);
    const noteLength = String(row?.notes || '').trim().length;
    const classYearPresent = row?.class_year !== null && row?.class_year !== undefined && String(row.class_year).trim() !== '';
    const duplicateActiveCount = Math.max(0, Number(row?.active_pair_link_count || 0) - 1);
    const teacherVerified = Number(row?.teacher_verified || 0) === 1;
    const alumniVerified = Number(row?.alumni_verified || 0) === 1;
    const createdVia = normalizeTeacherLinkCreatedVia(row?.created_via);
    const sourceSurface = normalizeTeacherLinkSourceSurface(row?.source_surface);

    const riskSignals = [];
    const positiveSignals = [];
    let riskScore = 0;

    if (confidenceScore < 0.45) {
      riskSignals.push({ code: 'low_confidence', label: 'Confidence score is low', severity: 'high' });
      riskScore += 3;
    } else if (confidenceScore < 0.65) {
      riskSignals.push({ code: 'medium_confidence', label: 'Confidence score needs review', severity: 'medium' });
      riskScore += 1;
    } else {
      positiveSignals.push({ code: 'healthy_confidence', label: 'Confidence score is strong' });
    }

    if (!classYearPresent) {
      riskSignals.push({ code: 'missing_class_year', label: 'Class year is missing', severity: 'medium' });
      riskScore += 1;
    } else {
      positiveSignals.push({ code: 'class_year_present', label: 'Class year is provided' });
    }

    if (noteLength === 0) {
      riskSignals.push({ code: 'missing_notes', label: 'No supporting note was added', severity: 'high' });
      riskScore += 2;
    } else if (noteLength < 12) {
      riskSignals.push({ code: 'short_notes', label: 'Supporting note is very short', severity: 'medium' });
      riskScore += 1;
    } else {
      positiveSignals.push({ code: 'detailed_notes', label: 'Supporting note adds context' });
    }

    if (duplicateActiveCount > 0) {
      riskSignals.push({ code: 'duplicate_active_pair', label: 'Another active link exists for the same teacher-alumni pair', severity: 'high' });
      riskScore += 3;
    } else {
      positiveSignals.push({ code: 'single_active_pair_record', label: 'No competing active duplicate exists' });
    }

    if (teacherVerified) positiveSignals.push({ code: 'teacher_verified', label: 'Teacher account is verified' });
    else {
      riskSignals.push({ code: 'teacher_unverified', label: 'Teacher account is not verified', severity: 'medium' });
      riskScore += 1;
    }

    if (alumniVerified) positiveSignals.push({ code: 'alumni_verified', label: 'Alumni account is verified' });
    else {
      riskSignals.push({ code: 'alumni_unverified', label: 'Alumni account is not verified', severity: 'medium' });
      riskScore += 1;
    }

    if (createdVia === 'import') {
      riskSignals.push({ code: 'imported_record', label: 'Record came from import flow', severity: 'medium' });
      riskScore += 1;
    } else {
      positiveSignals.push({ code: 'manual_submission', label: 'Record was submitted manually' });
    }

    if (sourceSurface === 'member_detail_page') {
      positiveSignals.push({ code: 'contextual_source_surface', label: 'Created from a contextual member detail flow' });
    }

    if (reviewStatus === 'flagged') {
      riskSignals.push({ code: 'previously_flagged', label: 'Record is already flagged', severity: 'high' });
      riskScore += 2;
    }

    const riskLevel = riskScore >= 6 ? 'high' : riskScore >= 3 ? 'medium' : 'low';
    let recommendedAction = 'keep_pending';
    let recommendationLabel = 'Keep pending';
    let decisionHint = 'Needs another moderation pass.';

    if (reviewStatus === 'merged') {
      recommendedAction = 'keep_merged';
      recommendationLabel = 'Keep merged';
      decisionHint = 'This record is already merged into another active link.';
    } else if (reviewStatus === 'rejected') {
      recommendedAction = 'keep_rejected';
      recommendationLabel = 'Keep rejected';
      decisionHint = 'This record is already removed from the active graph.';
    } else if (duplicateActiveCount > 0) {
      recommendedAction = 'merge';
      recommendationLabel = 'Merge';
      decisionHint = 'A duplicate active pair exists. Prefer merging instead of keeping two active claims.';
    } else if (confidenceScore >= 0.75 && teacherVerified && alumniVerified && (classYearPresent || noteLength >= 12)) {
      recommendedAction = 'confirm';
      recommendationLabel = 'Confirm';
      decisionHint = 'Core trust signals are present and the record looks safe to confirm.';
    } else if (riskLevel === 'high' && (!classYearPresent || noteLength === 0)) {
      recommendedAction = 'reject';
      recommendationLabel = 'Reject';
      decisionHint = 'Critical trust signals are missing. Reject unless stronger evidence is provided.';
    } else if (riskLevel === 'high' || confidenceScore < 0.55 || reviewStatus === 'flagged') {
      recommendedAction = 'flag';
      recommendationLabel = 'Flag';
      decisionHint = 'Signals are weak or conflicting. Escalate for closer review.';
    }

    return {
      risk_level: riskLevel,
      risk_score: riskScore,
      duplicate_active_count: duplicateActiveCount,
      recommended_action: recommendedAction,
      recommended_action_label: recommendationLabel,
      decision_hint: decisionHint,
      risk_signals: riskSignals,
      positive_signals: positiveSignals
    };
  }

  function refreshTeacherLinkConfidenceScore(linkId) {
    const safeLinkId = Number(linkId || 0);
    if (!safeLinkId) return 0;
    const row = sqlGet(
      `SELECT l.id, l.teacher_user_id, l.alumni_user_id, l.relationship_type, l.class_year, l.notes,
              COALESCE(l.created_via, 'manual_alumni_link') AS created_via,
              COALESCE(l.source_surface, 'teachers_network_page') AS source_surface,
              COALESCE(l.review_status, 'pending') AS review_status,
              teacher.verified AS teacher_verified,
              teacher.role AS teacher_role,
              teacher.mezuniyetyili AS teacher_cohort,
              alumni.verified AS alumni_verified
       FROM teacher_alumni_links l
       LEFT JOIN uyeler teacher ON teacher.id = l.teacher_user_id
       LEFT JOIN uyeler alumni ON alumni.id = l.alumni_user_id
       WHERE l.id = ?`,
      [safeLinkId]
    );
    if (!row) return 0;

    const duplicateProximityCount = Number(sqlGet(
      `SELECT COUNT(*) AS cnt
       FROM teacher_alumni_links
       WHERE teacher_user_id = ?
         AND alumni_user_id = ?
         AND id <> ?
         AND COALESCE(review_status, 'pending') NOT IN ('rejected', 'merged')`,
      [row.teacher_user_id, row.alumni_user_id, safeLinkId]
    )?.cnt || 0);

    const nextScore = computeTeacherLinkConfidenceScore(row, duplicateProximityCount);
    sqlRun('UPDATE teacher_alumni_links SET confidence_score = ? WHERE id = ?', [nextScore, safeLinkId]);
    return nextScore;
  }

  function listTeacherLinkPairDuplicates(alumniUserId, teacherUserId) {
    const safeAlumniUserId = Number(alumniUserId || 0);
    const safeTeacherUserId = Number(teacherUserId || 0);
    if (!safeAlumniUserId || !safeTeacherUserId) return [];
    return sqlAll(
      `SELECT id, relationship_type, class_year, notes, created_at,
              COALESCE(review_status, 'pending') AS review_status,
              confidence_score
       FROM teacher_alumni_links
       WHERE alumni_user_id = ?
         AND teacher_user_id = ?
         AND COALESCE(review_status, 'pending') NOT IN ('rejected', 'merged')
       ORDER BY COALESCE(CASE WHEN CAST(created_at AS TEXT) = '' THEN NULL ELSE created_at END, '1970-01-01T00:00:00.000Z') DESC, id DESC`,
      [safeAlumniUserId, safeTeacherUserId]
    ) || [];
  }

  function parseNetworkWindowDays(raw) {
    const value = String(raw || '30d').trim().toLowerCase();
    if (value === '7d') return 7;
    if (value === '90d') return 90;
    return 30;
  }

  function toIsoThreshold(days) {
    return new Date(Date.now() - days * 24 * 60 * 60 * 1000).toISOString();
  }

  function createEmptyNetworkInboxPayload() {
    return {
      connections: {
        incoming: [],
        outgoing: [],
        counts: {
          incoming_pending: 0,
          outgoing_pending: 0
        }
      },
      mentorship: {
        incoming: [],
        outgoing: [],
        counts: {
          incoming_requested: 0,
          outgoing_requested: 0
        }
      },
      teacherLinks: {
        events: [],
        count: 0,
        unread_count: 0
      }
    };
  }

  function createEmptyNetworkMetricsPayload(windowDays = 30) {
    return {
      window: `${windowDays}d`,
      since: toIsoThreshold(windowDays),
      metrics: {
        connections: {
          requested: 0,
          accepted: 0,
          pending_incoming: 0,
          pending_outgoing: 0
        },
        mentorship: {
          requested: 0,
          accepted: 0
        },
        teacherLinks: {
          created: 0
        },
        time_to_first_network_success_days: null
      }
    };
  }

  function createEmptyExploreSuggestionsPayload(variant = 'A') {
    return {
      items: [],
      hasMore: false,
      total: 0,
      experiment_variant: variant
    };
  }

  function selectOptionalColumnSql(table, alias, column, fallbackSql = 'NULL') {
    return hasColumn(table, column) ? `${alias}.${column}` : fallbackSql;
  }

  async function safeNetworkSection(label, fallbackValue, callback) {
    try {
      return await callback();
    } catch (err) {
      console.error(`network.section.${label} failed:`, err);
      return typeof fallbackValue === 'function' ? fallbackValue() : fallbackValue;
    }
  }

  async function buildNetworkInboxPayload(userId, { limit = 12, teacherLinkLimit = limit } = {}) {
    ensureConnectionRequestsTable();
    ensureMentorshipRequestsTable();
    ensureTeacherAlumniLinksTable();
    if (!hasTable('uyeler')) return createEmptyNetworkInboxPayload();
    const hasNotifications = hasTable('notifications');
    const userVerifiedSql = `${selectOptionalColumnSql('uyeler', 'u', 'verified', '0')} AS verified`;
    const canLoadTeacherLinkEvents = hasNotifications && hasColumn('notifications', 'user_id') && hasColumn('notifications', 'type');
    const teacherNotificationSourceUserIdSql = selectOptionalColumnSql('notifications', 'n', 'source_user_id', 'NULL');
    const teacherNotificationEntityIdSql = `${selectOptionalColumnSql('notifications', 'n', 'entity_id', 'NULL')} AS entity_id`;
    const teacherNotificationMessageSql = `${selectOptionalColumnSql('notifications', 'n', 'message', "''")} AS message`;
    const teacherNotificationReadAtSql = `${selectOptionalColumnSql('notifications', 'n', 'read_at', 'NULL')} AS read_at`;
    const teacherNotificationCreatedAtSql = selectOptionalColumnSql('notifications', 'n', 'created_at', 'NULL');

    const [incomingConnections, outgoingConnections, incomingMentorship, outgoingMentorship, teacherLinkEvents] = await Promise.all([
      sqlAllAsync(
        `SELECT cr.id, cr.sender_id, cr.receiver_id, cr.status, cr.created_at, cr.updated_at, cr.responded_at,
                u.kadi, u.isim, u.soyisim, u.resim, ${userVerifiedSql}
         FROM connection_requests cr
         LEFT JOIN uyeler u ON u.id = cr.sender_id
         WHERE cr.receiver_id = ? AND LOWER(TRIM(COALESCE(cr.status, ''))) = 'pending'
         ORDER BY COALESCE(CASE WHEN CAST(cr.updated_at AS TEXT) = '' THEN NULL ELSE cr.updated_at END, cr.created_at) DESC, cr.id DESC
         LIMIT ?`,
        [userId, limit]
      ),
      sqlAllAsync(
        `SELECT cr.id, cr.sender_id, cr.receiver_id, cr.status, cr.created_at, cr.updated_at, cr.responded_at,
                u.kadi, u.isim, u.soyisim, u.resim, ${userVerifiedSql}
         FROM connection_requests cr
         LEFT JOIN uyeler u ON u.id = cr.receiver_id
         WHERE cr.sender_id = ? AND LOWER(TRIM(COALESCE(cr.status, ''))) = 'pending'
         ORDER BY COALESCE(CASE WHEN CAST(cr.updated_at AS TEXT) = '' THEN NULL ELSE cr.updated_at END, cr.created_at) DESC, cr.id DESC
         LIMIT ?`,
        [userId, limit]
      ),
      sqlAllAsync(
        `SELECT mr.id, mr.requester_id, mr.mentor_id, mr.status, mr.focus_area, mr.message, mr.created_at, mr.updated_at, mr.responded_at,
                u.kadi, u.isim, u.soyisim, u.resim, ${userVerifiedSql}
         FROM mentorship_requests mr
         LEFT JOIN uyeler u ON u.id = mr.requester_id
         WHERE mr.mentor_id = ? AND LOWER(TRIM(COALESCE(mr.status, ''))) = 'requested'
         ORDER BY COALESCE(CASE WHEN CAST(mr.updated_at AS TEXT) = '' THEN NULL ELSE mr.updated_at END, mr.created_at) DESC, mr.id DESC
         LIMIT ?`,
        [userId, limit]
      ),
      sqlAllAsync(
        `SELECT mr.id, mr.requester_id, mr.mentor_id, mr.status, mr.focus_area, mr.message, mr.created_at, mr.updated_at, mr.responded_at,
                u.kadi, u.isim, u.soyisim, u.resim, ${userVerifiedSql}
         FROM mentorship_requests mr
         LEFT JOIN uyeler u ON u.id = mr.mentor_id
         WHERE mr.requester_id = ? AND LOWER(TRIM(COALESCE(mr.status, ''))) = 'requested'
         ORDER BY COALESCE(CASE WHEN CAST(mr.updated_at AS TEXT) = '' THEN NULL ELSE mr.updated_at END, mr.created_at) DESC, mr.id DESC
         LIMIT ?`,
        [userId, limit]
      ),
      canLoadTeacherLinkEvents
        ? sqlAllAsync(
          `SELECT n.id, n.type, ${teacherNotificationSourceUserIdSql} AS source_user_id, ${teacherNotificationEntityIdSql}, ${teacherNotificationMessageSql}, ${teacherNotificationReadAtSql}, ${teacherNotificationCreatedAtSql} AS created_at,
                  u.kadi, u.isim, u.soyisim, u.resim, ${userVerifiedSql}
           FROM notifications n
           LEFT JOIN uyeler u ON u.id = ${teacherNotificationSourceUserIdSql}
           WHERE n.user_id = ? AND n.type = 'teacher_network_linked'
           ORDER BY COALESCE(CASE WHEN CAST(${teacherNotificationCreatedAtSql} AS TEXT) = '' THEN NULL ELSE ${teacherNotificationCreatedAtSql} END, '1970-01-01T00:00:00.000Z') DESC, n.id DESC
           LIMIT ?`,
          [userId, teacherLinkLimit]
        )
        : Promise.resolve([])
    ]);

    return {
      connections: {
        incoming: incomingConnections,
        outgoing: outgoingConnections,
        counts: {
          incoming_pending: incomingConnections.length,
          outgoing_pending: outgoingConnections.length
        }
      },
      mentorship: {
        incoming: incomingMentorship,
        outgoing: outgoingMentorship,
        counts: {
          incoming_requested: incomingMentorship.length,
          outgoing_requested: outgoingMentorship.length
        }
      },
      teacherLinks: {
        events: teacherLinkEvents,
        count: teacherLinkEvents.length,
        unread_count: teacherLinkEvents.reduce((sum, item) => (item.read_at ? sum : sum + 1), 0)
      }
    };
  }

  async function buildNetworkMetricsPayload(userId, windowDays) {
    ensureConnectionRequestsTable();
    ensureMentorshipRequestsTable();
    ensureTeacherAlumniLinksTable();
    if (!hasTable('uyeler')) return createEmptyNetworkMetricsPayload(windowDays);

    const sinceIso = toIsoThreshold(windowDays);
    const [
      userRow,
      pendingIncoming,
      pendingOutgoing,
      requestedConnections,
      acceptedConnections,
      mentorshipRequested,
      mentorshipAccepted,
      teacherLinksCreated,
      firstAcceptedConnection,
      firstAcceptedMentorship
    ] = await Promise.all([
      sqlGetAsync('SELECT ilktarih FROM uyeler WHERE id = ?', [userId]),
      sqlGetAsync("SELECT CAST(COUNT(*) AS INTEGER) AS count FROM connection_requests WHERE receiver_id = ? AND LOWER(TRIM(COALESCE(status, ''))) = 'pending'", [userId]),
      sqlGetAsync("SELECT CAST(COUNT(*) AS INTEGER) AS count FROM connection_requests WHERE sender_id = ? AND LOWER(TRIM(COALESCE(status, ''))) = 'pending'", [userId]),
      sqlGetAsync(
        `SELECT CAST(COUNT(*) AS INTEGER) AS count
         FROM connection_requests
         WHERE sender_id = ?
           AND (
             created_at >= ?
             OR LOWER(TRIM(COALESCE(status, ''))) = 'pending'
           )`,
        [userId, sinceIso]
      ),
      sqlGetAsync(
        `SELECT CAST(COUNT(*) AS INTEGER) AS count
         FROM connection_requests
         WHERE LOWER(TRIM(COALESCE(status, ''))) = 'accepted'
           AND (sender_id = ? OR receiver_id = ?)
           AND COALESCE(CASE WHEN CAST(responded_at AS TEXT) = '' THEN NULL ELSE responded_at END, CASE WHEN CAST(updated_at AS TEXT) = '' THEN NULL ELSE updated_at END, created_at) >= ?`,
        [userId, userId, sinceIso]
      ),
      sqlGetAsync('SELECT CAST(COUNT(*) AS INTEGER) AS count FROM mentorship_requests WHERE requester_id = ? AND created_at >= ?', [userId, sinceIso]),
      sqlGetAsync(
        `SELECT CAST(COUNT(*) AS INTEGER) AS count
         FROM mentorship_requests
         WHERE LOWER(TRIM(COALESCE(status, ''))) = 'accepted'
           AND (requester_id = ? OR mentor_id = ?)
           AND COALESCE(CASE WHEN CAST(responded_at AS TEXT) = '' THEN NULL ELSE responded_at END, CASE WHEN CAST(updated_at AS TEXT) = '' THEN NULL ELSE updated_at END, created_at) >= ?`,
        [userId, userId, sinceIso]
      ),
      sqlGetAsync('SELECT CAST(COUNT(*) AS INTEGER) AS count FROM teacher_alumni_links WHERE created_by = ? AND created_at >= ?', [userId, sinceIso]),
      sqlGetAsync(
        `SELECT COALESCE(CASE WHEN CAST(responded_at AS TEXT) = '' THEN NULL ELSE responded_at END, CASE WHEN CAST(updated_at AS TEXT) = '' THEN NULL ELSE updated_at END, created_at) AS at
         FROM connection_requests
         WHERE LOWER(TRIM(COALESCE(status, ''))) = 'accepted' AND (sender_id = ? OR receiver_id = ?)
         ORDER BY at ASC, id ASC
         LIMIT 1`,
        [userId, userId]
      ),
      sqlGetAsync(
        `SELECT COALESCE(CASE WHEN CAST(responded_at AS TEXT) = '' THEN NULL ELSE responded_at END, CASE WHEN CAST(updated_at AS TEXT) = '' THEN NULL ELSE updated_at END, created_at) AS at
         FROM mentorship_requests
         WHERE LOWER(TRIM(COALESCE(status, ''))) = 'accepted' AND (requester_id = ? OR mentor_id = ?)
         ORDER BY at ASC, id ASC
         LIMIT 1`,
        [userId, userId]
      )
    ]);

    const successCandidates = [firstAcceptedConnection?.at, firstAcceptedMentorship?.at]
      .map((value) => new Date(String(value || '')).getTime())
      .filter((value) => Number.isFinite(value) && value > 0);
    const firstSuccessAt = successCandidates.length ? new Date(Math.min(...successCandidates)).toISOString() : null;
    const registrationAtMs = new Date(String(userRow?.ilktarih || '')).getTime();
    const timeToFirstNetworkSuccessDays = firstSuccessAt && Number.isFinite(registrationAtMs) && registrationAtMs > 0
      ? Math.max(0, Math.round((new Date(firstSuccessAt).getTime() - registrationAtMs) / (24 * 60 * 60 * 1000)))
      : null;

    return {
      window: `${windowDays}d`,
      since: sinceIso,
      metrics: {
        connections: {
          requested: Number(requestedConnections?.count || 0),
          accepted: Number(acceptedConnections?.count || 0),
          pending_incoming: Number(pendingIncoming?.count || 0),
          pending_outgoing: Number(pendingOutgoing?.count || 0)
        },
        mentorship: {
          requested: Number(mentorshipRequested?.count || 0),
          accepted: Number(mentorshipAccepted?.count || 0)
        },
        teacherLinks: {
          created: Number(teacherLinksCreated?.count || 0)
        },
        time_to_first_network_success_days: timeToFirstNetworkSuccessDays
      }
    };
  }

  async function buildPendingConnectionMaps(userId, { limit = 100 } = {}) {
    ensureConnectionRequestsTable();
    if (!hasTable('connection_requests')) {
      return { incoming: {}, outgoing: {} };
    }
    const [incomingRows, outgoingRows] = await Promise.all([
      sqlAllAsync(
        `SELECT id, sender_id
         FROM connection_requests
         WHERE receiver_id = ? AND LOWER(TRIM(COALESCE(status, ''))) = 'pending'
         ORDER BY COALESCE(CASE WHEN CAST(updated_at AS TEXT) = '' THEN NULL ELSE updated_at END, created_at) DESC, id DESC
         LIMIT ?`,
        [userId, limit]
      ),
      sqlAllAsync(
        `SELECT id, receiver_id
         FROM connection_requests
         WHERE sender_id = ? AND LOWER(TRIM(COALESCE(status, ''))) = 'pending'
         ORDER BY COALESCE(CASE WHEN CAST(updated_at AS TEXT) = '' THEN NULL ELSE updated_at END, created_at) DESC, id DESC
         LIMIT ?`,
        [userId, limit]
      )
    ]);

    const incoming = {};
    for (const row of incomingRows) {
      const senderId = Number(row?.sender_id || 0);
      if (!senderId) continue;
      incoming[senderId] = Number(row?.id || 0);
    }

    const outgoing = {};
    for (const row of outgoingRows) {
      const receiverId = Number(row?.receiver_id || 0);
      if (!receiverId) continue;
      outgoing[receiverId] = Number(row?.id || 0);
    }

    return { incoming, outgoing };
  }

  async function buildExploreSuggestionsPayload(userId, { limit = 12, offset = 0 } = {}) {
    const safeUserId = Number(userId || 0);
    const safeLimit = Math.min(Math.max(parseInt(limit || '12', 10), 1), 40);
    const safeOffset = Math.max(parseInt(offset || '0', 10), 0);
    const experiment = getAssignedNetworkSuggestionVariant(safeUserId);
    const configVersion = String(experiment?.config?.updatedAt || 'default');
    const cacheKey = `${safeUserId}:${safeLimit}:${safeOffset}:${experiment.variant}:${configVersion}`;
    const cached = readExploreSuggestionsCache(cacheKey);
    if (cached) return cached;

    if (!hasTable('uyeler')) return createEmptyExploreSuggestionsPayload(experiment.variant);
    const hasFollows = hasTable('follows');
    const hasMentorOptIn = hasColumn('uyeler', 'mentor_opt_in');
    const hasOnline = hasColumn('uyeler', 'online');
    const me = await sqlGetAsync(
      `SELECT id, mezuniyetyili, sehir, universite, meslek
       FROM uyeler
       WHERE id = ?`,
      [safeUserId]
    );
    if (!me) return { items: [], hasMore: false, total: 0, experiment_variant: experiment.variant };
    const hasEngagementScores = hasTable('member_engagement_scores');
    const candidateVerifiedSql = `${selectOptionalColumnSql('uyeler', 'u', 'verified', '0')} AS verified`;
    const candidateRoleSql = `${selectOptionalColumnSql('uyeler', 'u', 'role', "'user'")} AS role`;

    const [iFollowFollowers, followsMe, candidates] = await Promise.all([
      hasFollows
        ? sqlAllAsync(
          `SELECT f2.following_id AS user_id, COUNT(*) AS cnt
           FROM follows f1
           JOIN follows f2 ON f2.follower_id = f1.following_id
           WHERE f1.follower_id = ?
           GROUP BY f2.following_id`,
          [safeUserId]
        )
        : Promise.resolve([]),
      hasFollows ? sqlAllAsync('SELECT follower_id FROM follows WHERE following_id = ?', [safeUserId]) : Promise.resolve([]),
      sqlAllAsync(
        `SELECT u.id, u.kadi, u.isim, u.soyisim, u.resim, ${candidateVerifiedSql}, u.mezuniyetyili, u.sehir, u.universite, u.meslek, ${hasOnline ? 'u.online' : '0'} AS online,
                ${candidateRoleSql}, ${hasMentorOptIn ? 'u.mentor_opt_in' : '0'} AS mentor_opt_in,
                ${hasEngagementScores ? 'COALESCE(es.score, 0)' : '0'} AS engagement_score
         FROM uyeler u
         ${hasEngagementScores ? 'LEFT JOIN member_engagement_scores es ON es.user_id = u.id' : ''}
         WHERE COALESCE(CAST(u.aktiv AS INTEGER), 1) = 1
           AND COALESCE(CAST(u.yasak AS INTEGER), 0) = 0
           AND u.id != ?
           ${hasFollows ? `AND NOT EXISTS (
             SELECT 1
             FROM follows f
             WHERE f.follower_id = ?
               AND f.following_id = u.id
           )` : ''}`,
        hasFollows ? [safeUserId, safeUserId] : [safeUserId]
      )
    ]);

    const secondDegreeMap = new Map(iFollowFollowers.map((r) => [Number(r.user_id), Number(r.cnt || 0)]));
    const followsMeSet = new Set(followsMe.map((r) => Number(r.follower_id)));
    const candidateIds = candidates.map((row) => Number(row.id)).filter((id) => id > 0);
    const hasGroupMembers = hasTable('group_members');
    const hasMentorshipRequests = hasTable('mentorship_requests');
    const hasTeacherLinks = hasTable('teacher_alumni_links');

    const [sharedGroupsRows, mentorshipRows, teacherLinkRows] = await Promise.all([
      hasGroupMembers && candidateIds.length
        ? sqlAllAsync(
          `SELECT gm.user_id AS candidate_id, COUNT(*) AS shared_count
           FROM group_members gm
           JOIN group_members mine ON mine.group_id = gm.group_id
           WHERE mine.user_id = ?
             AND gm.user_id IN (${candidateIds.map(() => '?').join(',')})
           GROUP BY gm.user_id`,
          [safeUserId, ...candidateIds]
        )
        : Promise.resolve([]),
      hasMentorshipRequests
        ? sqlAllAsync(
          `SELECT requester_id, mentor_id
           FROM mentorship_requests
           WHERE status = 'accepted'
             AND (
               requester_id = ?
               OR mentor_id = ?
               OR requester_id IN (${[safeUserId, ...candidateIds].map(() => '?').join(',')})
               OR mentor_id IN (${[safeUserId, ...candidateIds].map(() => '?').join(',')})
             )`,
          [safeUserId, safeUserId, safeUserId, ...candidateIds, safeUserId, ...candidateIds]
        )
        : Promise.resolve([]),
      hasTeacherLinks
        ? sqlAllAsync(
          `SELECT teacher_user_id, alumni_user_id
           FROM teacher_alumni_links
           WHERE teacher_user_id = ?
              OR alumni_user_id = ?
              OR teacher_user_id IN (${[safeUserId, ...candidateIds].map(() => '?').join(',')})
              OR alumni_user_id IN (${[safeUserId, ...candidateIds].map(() => '?').join(',')})`,
          [safeUserId, safeUserId, safeUserId, ...candidateIds, safeUserId, ...candidateIds]
        )
        : Promise.resolve([])
    ]);

    const sharedGroupsMap = new Map(sharedGroupsRows.map((row) => [Number(row.candidate_id), Number(row.shared_count || 0)]));
    const mentorshipPeersMap = createPeerMap(mentorshipRows, 'requester_id', 'mentor_id');
    const teacherPeersMap = createPeerMap(teacherLinkRows, 'teacher_user_id', 'alumni_user_id');

    const scored = [];
    for (const c of candidates) {
      const cid = Number(c.id);
      if (!cid) continue;
      const secondDegree = secondDegreeMap.get(cid) || 0;
      const sharedGroups = sharedGroupsMap.get(cid) || 0;
      const mentorshipOverlap = getPeerOverlapCount(mentorshipPeersMap, safeUserId, cid);
      const hasDirectMentorshipLink = mentorshipPeersMap.get(safeUserId)?.has(cid);
      const teacherOverlap = getPeerOverlapCount(teacherPeersMap, safeUserId, cid);
      const hasDirectTeacherLink = teacherPeersMap.get(safeUserId)?.has(cid);
      scored.push(buildScoredNetworkSuggestion(c, {
        viewer: me,
        secondDegree,
        followsViewer: followsMeSet.has(cid),
        sharedGroups,
        mentorshipOverlap,
        hasDirectMentorshipLink,
        teacherOverlap,
        hasDirectTeacherLink,
        params: experiment.config.params
      }));
    }

    const sortedScored = sortNetworkSuggestions(scored);
    const items = sortedScored.slice(safeOffset, safeOffset + safeLimit).map(mapNetworkSuggestionForApi);
    const payload = {
      items,
      hasMore: safeOffset + items.length < sortedScored.length,
      total: sortedScored.length,
      experiment_variant: experiment.variant
    };
    writeExploreSuggestionsCache(cacheKey, payload);
    return payload;
  }

  async function buildNetworkHubPayload(userId, { windowDays = 30, limit = 12, teacherLinkLimit = limit, suggestionLimit = 8 } = {}) {
    const [inbox, metricsBundle, discovery, connectionMaps] = await Promise.all([
      safeNetworkSection('inbox', createEmptyNetworkInboxPayload, () => buildNetworkInboxPayload(userId, { limit, teacherLinkLimit })),
      safeNetworkSection('metrics', () => createEmptyNetworkMetricsPayload(windowDays), () => buildNetworkMetricsPayload(userId, windowDays)),
      safeNetworkSection('discovery', () => createEmptyExploreSuggestionsPayload(getSafeAssignedNetworkSuggestionVariant(userId)), () => buildExploreSuggestionsPayload(userId, { limit: suggestionLimit, offset: 0 })),
      safeNetworkSection('connection_maps', { incoming: {}, outgoing: {} }, () => buildPendingConnectionMaps(userId, { limit: 100 }))
    ]);

    return {
      window: metricsBundle.window,
      since: metricsBundle.since,
      inbox,
      metrics: metricsBundle.metrics,
      discovery: {
        suggestions: discovery.items || [],
        hasMore: Boolean(discovery.hasMore),
        total: Number(discovery.total || 0),
        experiment_variant: String(discovery.experiment_variant || 'A'),
        connection_maps: connectionMaps
      },
      counts: {
        actionable:
          Number(inbox.connections?.counts?.incoming_pending || 0)
          + Number(inbox.mentorship?.counts?.incoming_requested || 0)
          + Number(inbox.teacherLinks?.unread_count || 0)
      }
    };
  }

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
    refreshMemberNetworkingDailySummaryIfStale,
    buildNetworkingAnalyticsAlerts,
    resolveNetworkSuggestionVariant,
    parseJsonValue,
    snapshotNetworkSuggestionConfigs,
    listNetworkSuggestionAbRecentChanges,
    listNetworkSuggestionAbRecentChangesWithEvaluation,
    buildNetworkSuggestionExperimentAnalytics,
    buildNetworkSuggestionAbRecommendations,
    getNetworkSuggestionExperimentDataset,
    recordNetworkingTelemetryEvent,
    isTeacherLinkActiveStatus,
    canTransitionTeacherLinkReviewStatus,
    selectTeacherLinkMergeTarget,
    logTeacherLinkModerationEvent,
    buildTeacherLinkModerationAssessment,
    refreshTeacherLinkConfidenceScore,
    listTeacherLinkPairDuplicates,
    parseNetworkWindowDays,
    toIsoThreshold,
    buildNetworkInboxPayload,
    buildNetworkMetricsPayload,
    buildExploreSuggestionsPayload,
    buildNetworkHubPayload
  };
}
