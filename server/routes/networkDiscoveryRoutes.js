import { getCacheJson, setCacheJson } from '../src/infra/performanceCache.js';
import { createRateLimitMiddleware } from '../src/http/middleware/rateLimit.js';

const heavyEndpointRateLimit = createRateLimitMiddleware({
  bucket: 'heavy_network',
  limit: 15,
  windowSeconds: 60,
  keyGenerator: (req) => String(req.session?.userId || req.ip || 'unknown')
});

export function registerNetworkDiscoveryRoutes(app, {
  requireAuth,
  requireAdmin,
  sqlRunAsync,
  sqlGetAsync,
  sqlAllAsync,
  apiSuccessEnvelope,
  sendApiError,
  normalizeNetworkingTelemetryEventName,
  recordNetworkingTelemetryEvent,
  ensureConnectionRequestsTable,
  ensureMentorshipRequestsTable,
  ensureTeacherAlumniLinksTable,
  ensureNetworkingTelemetryEventsTable,
  ensureMemberNetworkingDailySummaryTable,
  ensureNetworkSuggestionAbTables,
  parseNetworkWindowDays,
  toIsoThreshold,
  toSummaryDateKey,
  normalizeCohortValue,
  refreshMemberNetworkingDailySummaryIfStale,
  getNetworkSuggestionExperimentDataset,
  buildNetworkingAnalyticsAlerts,
  getNetworkSuggestionAbConfigs,
  listNetworkSuggestionAbRecentChangesWithEvaluation,
  buildNetworkSuggestionExperimentAnalytics,
  buildNetworkSuggestionAbRecommendations,
  buildOpportunityInboxPayload,
  buildNetworkHubPayload,
  buildNetworkMetricsPayload,
  buildExploreSuggestionsPayload
}) {
  app.get('/api/new/opportunities', requireAuth, heavyEndpointRateLimit, async (req, res) => {
    try {
      const userId = Number(req.session?.userId || 0);
      const limit = Math.min(Math.max(parseInt(req.query.limit || '20', 10), 1), 40);
      const cursor = String(req.query.cursor || '').trim();
      const tab = String(req.query.tab || 'all').trim().toLowerCase();

      const cacheKey = `opp-inbox:${userId}:${tab}:${cursor}:${limit}`;
      const cached = await getCacheJson(cacheKey);
      if (cached) {
        return res.json(apiSuccessEnvelope(
          'OPPORTUNITY_INBOX_OK',
          'Fırsat merkezi hazır.',
          { opportunities: cached },
          { opportunities: cached }
        ));
      }

      const opportunities = await buildOpportunityInboxPayload(userId, { limit, cursor, tab });
      await setCacheJson(cacheKey, opportunities, 15);
      return res.json(apiSuccessEnvelope(
        'OPPORTUNITY_INBOX_OK',
        'Fırsat merkezi hazır.',
        { opportunities },
        { opportunities }
      ));
    } catch (err) {
      console.error('opportunity.inbox failed:', err);
      return sendApiError(res, 500, 'OPPORTUNITY_INBOX_FAILED', 'Fırsat merkezi verileri hazırlanamadı.');
    }
  });

  app.get('/api/new/network/hub', requireAuth, heavyEndpointRateLimit, async (req, res) => {
    try {
      const userId = Number(req.session?.userId || 0);
      const limit = Math.min(Math.max(parseInt(req.query.limit || '12', 10), 1), 50);
      const teacherLinkLimit = Math.min(Math.max(parseInt(req.query.teacher_limit || String(limit), 10), 1), 50);
      const suggestionLimit = Math.min(Math.max(parseInt(req.query.suggestion_limit || '8', 10), 1), 20);
      const windowDays = parseNetworkWindowDays(req.query.window);

      const hubCacheKey = `net-hub:${userId}:${windowDays}:${limit}:${teacherLinkLimit}:${suggestionLimit}`;
      const cachedHub = await getCacheJson(hubCacheKey);
      if (cachedHub) {
        return res.json({
          ok: true,
          code: 'NETWORK_HUB_BOOTSTRAP_OK',
          message: 'Networking hub bootstrap hazir.',
          data: { hub: cachedHub }
        });
      }

      const hub = await buildNetworkHubPayload(userId, { windowDays, limit, teacherLinkLimit, suggestionLimit });
      await setCacheJson(hubCacheKey, hub, 20);
      return res.json({
        ok: true,
        code: 'NETWORK_HUB_BOOTSTRAP_OK',
        message: 'Networking hub bootstrap hazir.',
        data: { hub }
      });
    } catch (err) {
      console.error('network.hub failed:', err);
      return res.status(500).json({
        ok: false,
        code: 'NETWORK_HUB_BOOTSTRAP_FAILED',
        message: 'Networking hub verileri hazirlanamadi.',
        data: null
      });
    }
  });

  app.get('/api/new/network/metrics', requireAuth, heavyEndpointRateLimit, async (req, res) => {
    try {
      const userId = Number(req.session?.userId || 0);
      const windowDays = parseNetworkWindowDays(req.query.window);

      const metricsCacheKey = `net-metrics:${userId}:${windowDays}`;
      const cachedMetrics = await getCacheJson(metricsCacheKey);
      if (cachedMetrics) {
        return res.json(apiSuccessEnvelope('NETWORK_METRICS_OK', 'Networking metrikleri hazır.', cachedMetrics, cachedMetrics));
      }

      const payload = await buildNetworkMetricsPayload(userId, windowDays);
      await setCacheJson(metricsCacheKey, payload, 30);
      return res.json(apiSuccessEnvelope('NETWORK_METRICS_OK', 'Networking metrikleri hazır.', payload, payload));
    } catch (err) {
      console.error('network.metrics failed:', err);
      return sendApiError(res, 500, 'NETWORK_METRICS_FAILED', 'Beklenmeyen bir hata oluştu.');
    }
  });

  app.post('/api/new/network/inbox/teacher-links/read', requireAuth, async (req, res) => {
    try {
      const result = await sqlRunAsync(
        `UPDATE notifications
         SET read_at = COALESCE(read_at, ?)
         WHERE user_id = ?
           AND type = 'teacher_network_linked'`,
        [new Date().toISOString(), req.session.userId]
      );
      const updated = Number(result?.changes || 0);
      if (updated > 0) {
        recordNetworkingTelemetryEvent({
          userId: req.session.userId,
          eventName: 'teacher_links_read',
          sourceSurface: req.body?.source_surface,
          entityType: 'notification',
          metadata: { updated }
        });
      }
      return res.json(apiSuccessEnvelope(
        'NETWORK_TEACHER_LINKS_MARKED_READ',
        'Öğretmen ağı bildirimleri okundu olarak işaretlendi.',
        { updated },
        { updated }
      ));
    } catch (err) {
      console.error('network.inbox.teacher-links.read failed:', err);
      return sendApiError(res, 500, 'NETWORK_TEACHER_LINKS_MARK_READ_FAILED', 'Beklenmeyen bir hata oluştu.');
    }
  });

  app.post('/api/new/network/telemetry', requireAuth, async (req, res) => {
    try {
      const userId = Number(req.session?.userId || 0);
      const eventName = normalizeNetworkingTelemetryEventName(req.body?.event_name, { allowClientEvents: true, allowActionEvents: false });
      if (!eventName) {
        return sendApiError(res, 400, 'INVALID_NETWORKING_TELEMETRY_EVENT', 'Geçersiz networking telemetry olayı.');
      }
      recordNetworkingTelemetryEvent({
        userId,
        eventName,
        sourceSurface: req.body?.source_surface,
        targetUserId: req.body?.target_user_id,
        entityType: req.body?.entity_type,
        entityId: req.body?.entity_id,
        metadata: req.body?.metadata && typeof req.body.metadata === 'object' ? req.body.metadata : null
      });
      return res.json(apiSuccessEnvelope(
        'NETWORKING_TELEMETRY_RECORDED',
        'Networking telemetry kaydedildi.',
        { recorded: true, event_name: eventName },
        { recorded: true, event_name: eventName }
      ));
    } catch (err) {
      console.error('network.telemetry.record failed:', err);
      return sendApiError(res, 500, 'NETWORKING_TELEMETRY_RECORD_FAILED', 'Beklenmeyen bir hata oluştu.');
    }
  });

  app.get('/api/new/admin/network/analytics', requireAdmin, async (req, res) => {
    try {
      ensureConnectionRequestsTable();
      ensureMentorshipRequestsTable();
      ensureTeacherAlumniLinksTable();
      ensureNetworkingTelemetryEventsTable();
      ensureMemberNetworkingDailySummaryTable();
      ensureNetworkSuggestionAbTables();

      const windowDays = parseNetworkWindowDays(req.query.window);
      const sinceIso = toIsoThreshold(windowDays);
      const sinceDate = toSummaryDateKey(sinceIso);
      const cohort = normalizeCohortValue(req.query.cohort);
      const includeCohort = cohort && cohort !== 'all';
      const summaryRefresh = await refreshMemberNetworkingDailySummaryIfStale();

      const summaryWhere = ['s.date >= ?'];
      const summaryParams = [sinceDate];
      if (includeCohort) {
        summaryWhere.push('LOWER(COALESCE(s.cohort, ?)) = LOWER(?)');
        summaryParams.push('unknown', cohort);
      }
      const summaryWhereSql = `WHERE ${summaryWhere.join(' AND ')}`;

      const [summaryTotals, topCohorts, mentorSupplyRows, mentorDemandRows, experimentDataset] = await Promise.all([
        sqlGetAsync(
          `SELECT
              CAST(COALESCE(SUM(s.connections_requested), 0) AS INTEGER) AS connections_requested,
              CAST(COALESCE(SUM(s.connections_accepted), 0) AS INTEGER) AS connections_accepted,
              CAST(COALESCE(SUM(s.connections_pending), 0) AS INTEGER) AS connections_pending,
              CAST(COALESCE(SUM(s.connections_ignored), 0) AS INTEGER) AS connections_ignored,
              CAST(COALESCE(SUM(s.connections_declined), 0) AS INTEGER) AS connections_declined,
              CAST(COALESCE(SUM(s.connections_cancelled), 0) AS INTEGER) AS connections_cancelled,
              CAST(COALESCE(SUM(s.mentorship_requested), 0) AS INTEGER) AS mentorship_requested,
              CAST(COALESCE(SUM(s.mentorship_accepted), 0) AS INTEGER) AS mentorship_accepted,
              CAST(COALESCE(SUM(s.mentorship_declined), 0) AS INTEGER) AS mentorship_declined,
              CAST(COALESCE(SUM(s.teacher_links_created), 0) AS INTEGER) AS teacher_links_created,
              CAST(COALESCE(SUM(s.teacher_links_read), 0) AS INTEGER) AS teacher_links_read,
              CAST(COALESCE(SUM(s.follow_created), 0) AS INTEGER) AS follow_created,
              CAST(COALESCE(SUM(s.follow_removed), 0) AS INTEGER) AS follow_removed,
              CAST(COALESCE(SUM(s.hub_views), 0) AS INTEGER) AS hub_views,
              CAST(COALESCE(SUM(s.hub_suggestion_loads), 0) AS INTEGER) AS hub_suggestion_loads,
              CAST(COALESCE(SUM(s.explore_views), 0) AS INTEGER) AS explore_views,
              CAST(COALESCE(SUM(s.explore_suggestion_loads), 0) AS INTEGER) AS explore_suggestion_loads,
              CAST(COALESCE(SUM(s.teacher_network_views), 0) AS INTEGER) AS teacher_network_views
           FROM member_networking_daily_summary s
           ${summaryWhereSql}`,
          summaryParams
        ),
        sqlAllAsync(
          `SELECT LOWER(COALESCE(s.cohort, 'unknown')) AS cohort,
                  CAST(COALESCE(SUM(s.connections_requested + s.mentorship_requested), 0) AS INTEGER) AS actions
           FROM member_networking_daily_summary s
           ${summaryWhereSql}
           GROUP BY LOWER(COALESCE(s.cohort, 'unknown'))
           ORDER BY actions DESC, cohort ASC
           LIMIT 5`,
          summaryParams
        ),
        sqlAllAsync(
          `SELECT LOWER(COALESCE(NULLIF(CAST(mezuniyetyili AS TEXT), ''), 'unknown')) AS cohort,
                  CAST(COUNT(*) AS INTEGER) AS count
           FROM uyeler
           WHERE mentor_opt_in = 1
           GROUP BY cohort
           ORDER BY count DESC, cohort ASC
           LIMIT 10`
        ),
        sqlAllAsync(
          `SELECT LOWER(COALESCE(s.cohort, 'unknown')) AS cohort,
                  CAST(COALESCE(SUM(s.mentorship_requested), 0) AS INTEGER) AS count
           FROM member_networking_daily_summary s
           ${summaryWhereSql}
           GROUP BY LOWER(COALESCE(s.cohort, 'unknown'))
           HAVING CAST(COALESCE(SUM(s.mentorship_requested), 0) AS INTEGER) > 0
           ORDER BY count DESC, cohort ASC
           LIMIT 10`,
          summaryParams
        ),
        getNetworkSuggestionExperimentDataset({ sinceIso, cohort })
      ]);

      const requested = Number(summaryTotals?.connections_requested || 0);
      const accepted = Number(summaryTotals?.connections_accepted || 0);
      const analyticsAlerts = buildNetworkingAnalyticsAlerts(summaryTotals, mentorDemandRows, mentorSupplyRows);
      const experimentConfigs = getNetworkSuggestionAbConfigs();
      const recentSuggestionChanges = await listNetworkSuggestionAbRecentChangesWithEvaluation(6);
      const suggestionExperiment = buildNetworkSuggestionExperimentAnalytics({
        exposureRows: experimentDataset.exposureRows,
        actionRows: experimentDataset.actionRows,
        configs: experimentConfigs,
        assignmentCounts: experimentDataset.assignmentCounts
      });
      suggestionExperiment.recent_changes = recentSuggestionChanges;
      suggestionExperiment.recommendations = buildNetworkSuggestionAbRecommendations(
        experimentConfigs,
        suggestionExperiment.variants,
        suggestionExperiment.recent_changes || []
      );

      return res.json({
        window: `${windowDays}d`,
        since: sinceIso,
        summary: {
          source: 'member_networking_daily_summary',
          granularity: 'day',
          last_rebuilt_at: summaryRefresh?.lastRebuiltAt || null,
          rebuilt_rows: Number(summaryRefresh?.rows || 0),
          skipped_refresh: Boolean(summaryRefresh?.skipped)
        },
        cohort: includeCohort ? cohort : 'all',
        networking: {
          connections: {
            requested,
            accepted,
            acceptance_rate: requested > 0 ? Number((accepted / requested).toFixed(4)) : 0,
            pending: Number(summaryTotals?.connections_pending || 0),
            ignored: Number(summaryTotals?.connections_ignored || 0),
            declined: Number(summaryTotals?.connections_declined || 0),
            cancelled: Number(summaryTotals?.connections_cancelled || 0)
          },
          mentorship: {
            requested: Number(summaryTotals?.mentorship_requested || 0),
            accepted: Number(summaryTotals?.mentorship_accepted || 0),
            declined: Number(summaryTotals?.mentorship_declined || 0)
          },
          teacher_links: {
            created: Number(summaryTotals?.teacher_links_created || 0)
          },
          telemetry: {
            frontend: {
              hub_views: Number(summaryTotals?.hub_views || 0),
              hub_suggestion_loads: Number(summaryTotals?.hub_suggestion_loads || 0),
              explore_views: Number(summaryTotals?.explore_views || 0),
              explore_suggestion_loads: Number(summaryTotals?.explore_suggestion_loads || 0),
              teacher_network_views: Number(summaryTotals?.teacher_network_views || 0)
            },
            actions: {
              connection_requested: Number(summaryTotals?.connections_requested || 0),
              connection_accepted: Number(summaryTotals?.connections_accepted || 0),
              connection_ignored: Number(summaryTotals?.connections_ignored || 0),
              connection_cancelled: Number(summaryTotals?.connections_cancelled || 0),
              mentorship_requested: Number(summaryTotals?.mentorship_requested || 0),
              mentorship_accepted: Number(summaryTotals?.mentorship_accepted || 0),
              mentorship_declined: Number(summaryTotals?.mentorship_declined || 0),
              teacher_link_created: Number(summaryTotals?.teacher_links_created || 0),
              teacher_links_read: Number(summaryTotals?.teacher_links_read || 0),
              follow_created: Number(summaryTotals?.follow_created || 0),
              follow_removed: Number(summaryTotals?.follow_removed || 0)
            },
            top_events: [
              { event_name: 'connection_requested', count: Number(summaryTotals?.connections_requested || 0) },
              { event_name: 'connection_accepted', count: Number(summaryTotals?.connections_accepted || 0) },
              { event_name: 'connection_ignored', count: Number(summaryTotals?.connections_ignored || 0) },
              { event_name: 'connection_cancelled', count: Number(summaryTotals?.connections_cancelled || 0) },
              { event_name: 'mentorship_requested', count: Number(summaryTotals?.mentorship_requested || 0) },
              { event_name: 'mentorship_accepted', count: Number(summaryTotals?.mentorship_accepted || 0) },
              { event_name: 'mentorship_declined', count: Number(summaryTotals?.mentorship_declined || 0) },
              { event_name: 'teacher_link_created', count: Number(summaryTotals?.teacher_links_created || 0) },
              { event_name: 'teacher_links_read', count: Number(summaryTotals?.teacher_links_read || 0) },
              { event_name: 'follow_created', count: Number(summaryTotals?.follow_created || 0) },
              { event_name: 'follow_removed', count: Number(summaryTotals?.follow_removed || 0) },
              { event_name: 'network_hub_viewed', count: Number(summaryTotals?.hub_views || 0) },
              { event_name: 'network_hub_suggestions_loaded', count: Number(summaryTotals?.hub_suggestion_loads || 0) },
              { event_name: 'network_explore_viewed', count: Number(summaryTotals?.explore_views || 0) },
              { event_name: 'network_explore_suggestions_loaded', count: Number(summaryTotals?.explore_suggestion_loads || 0) },
              { event_name: 'teacher_network_viewed', count: Number(summaryTotals?.teacher_network_views || 0) }
            ].filter((item) => item.count > 0)
              .sort((a, b) => Number(b.count || 0) - Number(a.count || 0) || String(a.event_name).localeCompare(String(b.event_name)))
          },
          alerts: analyticsAlerts,
          experiments: {
            network_suggestions: suggestionExperiment
          },
          top_active_graduation_years: topCohorts,
          mentor_supply_vs_demand: {
            supply: mentorSupplyRows,
            demand: mentorDemandRows
          }
        }
      });
    } catch (err) {
      console.error('admin.network.analytics failed:', err);
      return res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.get('/api/new/explore/suggestions', requireAuth, heavyEndpointRateLimit, async (req, res) => {
    try {
      const payload = await buildExploreSuggestionsPayload(req.session.userId, {
        limit: req.query.limit || '12',
        offset: req.query.offset || '0'
      });
      return res.json(apiSuccessEnvelope('EXPLORE_SUGGESTIONS_OK', 'Önerilen mezun kartları hazır.', payload, payload));
    } catch (err) {
      console.error('explore.suggestions failed:', err);
      return sendApiError(res, 500, 'EXPLORE_SUGGESTIONS_FAILED', 'Beklenmeyen bir hata oluştu.');
    }
  });
}
