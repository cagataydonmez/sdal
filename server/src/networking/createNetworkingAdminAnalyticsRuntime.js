export function createNetworkingAdminAnalyticsRuntime({
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
}) {
  const NETWORKING_DAILY_SUMMARY_REBUILD_INTERVAL_MS = 60 * 1000;
  let networkingDailySummaryRefreshPromise = null;

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

    const execRun = sqlRunAsync || ((...a) => Promise.resolve(sqlRun(...a)));
    await execRun('DELETE FROM member_networking_daily_summary');
    const now = new Date().toISOString();
    for (const row of summaryMap.values()) {
      await execRun(
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

    await execRun(
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
    const execGet = sqlGetAsync || ((...a) => Promise.resolve(sqlGet(...a)));
    const lastRebuiltAt = (await execGet(
      "SELECT value FROM networking_summary_meta WHERE key = 'member_networking_daily_summary:last_rebuilt_at'"
    ))?.value || '';
    const lastRebuiltMs = toDateMs(lastRebuiltAt);
    const hasRows = Number((await execGet('SELECT COUNT(*) AS cnt FROM member_networking_daily_summary'))?.cnt || 0) > 0;
    const isFresh = hasRows && lastRebuiltMs !== null && (Date.now() - lastRebuiltMs) < NETWORKING_DAILY_SUMMARY_REBUILD_INTERVAL_MS;
    if (isFresh) {
      return { lastRebuiltAt, rows: Number((await execGet('SELECT COUNT(*) AS cnt FROM member_networking_daily_summary'))?.cnt || 0), skipped: true };
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
        description: 'Baglanti istekleri gonderiliyor ama kabul orani beklenen seviyenin altinda kaldi.',
        metric: Number((connectionAcceptanceRate * 100).toFixed(2))
      });
    }

    if (mentorshipRequested >= 2 && mentorshipAcceptanceRate < 0.25) {
      alerts.push({
        code: 'mentorship_acceptance_low',
        severity: 'medium',
        title: 'Mentorship acceptance rate is low',
        description: 'Mentorluk talep hacmi var ancak kabul orani zayif gorunuyor.',
        metric: Number((mentorshipAcceptanceRate * 100).toFixed(2))
      });
    }

    if (teacherLinksCreated >= 1 && teacherLinkReadRate < 0.5) {
      alerts.push({
        code: 'teacher_link_reads_lagging',
        severity: teacherLinksRead === 0 ? 'high' : 'medium',
        title: 'Teacher link read rate is lagging',
        description: 'Ogretmen bagi uretiliyor fakat bildirimlerin okunma orani dusuk; trust feedback gorunurlugu zayif olabilir.',
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
        description: `${demandGap.cohort} cohortunda mentorluk talebi arzin onune gecti.`,
        metric: demandGap.gap,
        cohort: demandGap.cohort
      });
    }

    if ((hubViews + exploreViews) >= 10 && activationActions === 0) {
      alerts.push({
        code: 'networking_activation_low',
        severity: 'medium',
        title: 'Visibility is not turning into networking actions',
        description: 'Hub ve Explore goruntuleniyor fakat baglanti, mentorluk veya teacher-link aksiyonlari olusmuyor.',
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
      blockers.push(`Cooldown aktif. Yaklasik ${Math.ceil(cooldownRemainingMs / 60_000)} dakika bekleyin.`);
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
          reasons.push(`Aktivasyon orani baseline'in gerisinde (${round2(activationDelta * 100)}%).`);
          confidenceParts.push(Math.min(0.35, Math.abs(activationDelta)));
        } else if (activationDelta > 0.1) {
          reasons.push(`Aktivasyon orani baseline'in uzerinde (${round2(activationDelta * 100)}%).`);
          confidenceParts.push(Math.min(0.28, activationDelta));
        }

        if (connectionDelta > 0.12) {
          patch.secondDegreeWeight = round2((patch.secondDegreeWeight || p.secondDegreeWeight) * 1.04);
          patch.maxSecondDegreeBonus = round2((patch.maxSecondDegreeBonus || p.maxSecondDegreeBonus) * 1.03);
          reasons.push('Baglanti istegi donusumu guclu; graph yakinligi biraz daha one cikarilabilir.');
          confidenceParts.push(Math.min(0.2, connectionDelta));
        }

        if (mentorshipDelta > 0.12) {
          patch.directMentorshipBonus = round2((patch.directMentorshipBonus || p.directMentorshipBonus) * 1.05);
          patch.mentorshipOverlapWeight = round2((patch.mentorshipOverlapWeight || p.mentorshipOverlapWeight) * 1.04);
          reasons.push('Mentorluk talebi uretimi guclu; mentorluk sinyalleri korunup hafif artirilabilir.');
          confidenceParts.push(Math.min(0.2, mentorshipDelta));
        }

        if (teacherDelta > 0.12) {
          patch.directTeacherBonus = round2((patch.directTeacherBonus || p.directTeacherBonus) * 1.05);
          patch.teacherOverlapWeight = round2((patch.teacherOverlapWeight || p.teacherOverlapWeight) * 1.04);
          reasons.push('Teacher network aksiyonlari guclu; ogretmen yakinligi sinyali biraz daha artirilabilir.');
          confidenceParts.push(Math.min(0.2, teacherDelta));
        }
      }

      if (Number(perf.follow_conversion_rate || 0) > 0.2 && Number(perf.connection_request_rate || 0) < 0.08) {
        patch.secondDegreeWeight = round2((patch.secondDegreeWeight || p.secondDegreeWeight) * 1.04);
        patch.sharedGroupWeight = round2((patch.sharedGroupWeight || p.sharedGroupWeight) * 1.04);
        reasons.push('Follow donusumu var ama daha derin networking aksiyonlari dusuk; graph sinyalleri hafif guclendirilebilir.');
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
            reasons: [`${scored[0].variant} varyanti recommendation quality metriginide daha guclu performans gosteriyor.`],
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

  return {
    refreshMemberNetworkingDailySummaryIfStale,
    buildNetworkingAnalyticsAlerts,
    resolveNetworkSuggestionVariant,
    parseJsonValue,
    snapshotNetworkSuggestionConfigs,
    listNetworkSuggestionAbRecentChanges,
    listNetworkSuggestionAbRecentChangesWithEvaluation,
    buildNetworkSuggestionExperimentAnalytics,
    buildNetworkSuggestionAbRecommendations,
    getNetworkSuggestionExperimentDataset
  };
}
