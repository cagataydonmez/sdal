export function registerAdminExperimentRoutes(app, {
  requireAdmin,
  sqlGet,
  sqlAll,
  sqlRun,
  sqlGetAsync,
  sqlAllAsync,
  sqlRunAsync,
  handleEngagementAbOverview,
  handleEngagementAbUpdate,
  handleEngagementAbRebalance,
  handleAdminDashboardSummary,
  handleAdminDashboardActivity,
  parseNetworkWindowDays,
  toIsoThreshold,
  normalizeCohortValue,
  getNetworkSuggestionExperimentDataset,
  getNetworkSuggestionAbConfigs,
  buildNetworkSuggestionExperimentAnalytics,
  listNetworkSuggestionAbRecentChanges,
  listNetworkSuggestionAbRecentChangesWithEvaluation,
  buildNetworkSuggestionAbRecommendations,
  NETWORK_SUGGESTION_APPLY_CONFIRMATION_TOKEN,
  resolveNetworkSuggestionVariant,
  parseJsonValue,
  snapshotNetworkSuggestionConfigs,
  ensureNetworkSuggestionAbTables,
  networkSuggestionDefaultParams,
  networkSuggestionDefaultVariants,
  normalizeNetworkSuggestionParams,
  toDbBooleanParam,
  logAdminAction,
  recalculateMemberEngagementScores
}) {
  function clamp(value, min, max) {
    const numeric = Number(value);
    if (!Number.isFinite(numeric)) return min;
    return Math.max(min, Math.min(max, numeric));
  }

  app.get('/api/new/admin/engagement-ab', requireAdmin, handleEngagementAbOverview);
  app.put('/api/new/admin/engagement-ab/:variant', requireAdmin, handleEngagementAbUpdate);
  app.post('/api/new/admin/engagement-ab/rebalance', requireAdmin, handleEngagementAbRebalance);

  app.get('/api/new/admin/network-suggestion-ab', requireAdmin, async (req, res) => {
    try {
      const windowDays = parseNetworkWindowDays(req.query.window);
      const sinceIso = toIsoThreshold(windowDays);
      const cohort = normalizeCohortValue(req.query.cohort);
      const dataset = await getNetworkSuggestionExperimentDataset({ sinceIso, cohort });
      const configs = getNetworkSuggestionAbConfigs().map((cfg) => ({
        variant: cfg.variant,
        name: cfg.name,
        description: cfg.description,
        trafficPct: cfg.trafficPct,
        enabled: cfg.enabled,
        params: cfg.params,
        updatedAt: cfg.updatedAt
      }));
      const performanceBundle = buildNetworkSuggestionExperimentAnalytics({
        exposureRows: dataset.exposureRows,
        actionRows: dataset.actionRows,
        configs,
        assignmentCounts: dataset.assignmentCounts
      });
      const recentSuggestionChanges = await listNetworkSuggestionAbRecentChangesWithEvaluation(10);
      const recommendations = buildNetworkSuggestionAbRecommendations(configs, performanceBundle.variants, recentSuggestionChanges);
      const lastObservedAt = [...dataset.exposureRows, ...dataset.actionRows]
        .map((row) => row?.created_at)
        .filter(Boolean)
        .sort((a, b) => String(b).localeCompare(String(a)))[0] || null;

      res.json({
        window: `${windowDays}d`,
        since: sinceIso,
        cohort: String(cohort || 'all'),
        configs,
        performance: performanceBundle.variants,
        assignmentCounts: performanceBundle.assignment_counts,
        recommendations,
        leadingVariant: performanceBundle.leading_variant,
        recentChanges: recentSuggestionChanges,
        totals: {
          exposure_users: performanceBundle.total_exposure_users,
          exposure_events: performanceBundle.total_exposure_events
        },
        lastObservedAt
      });
    } catch (err) {
      console.error('admin.network-suggestion-ab failed:', err);
      res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.post('/api/new/admin/network-suggestion-ab/apply', requireAdmin, async (req, res) => {
    try {
      const windowDays = parseNetworkWindowDays(req.body?.window || req.query?.window);
      const sinceIso = toIsoThreshold(windowDays);
      const cohort = normalizeCohortValue(req.body?.cohort || req.query?.cohort);
      const recommendationIndex = Math.max(0, parseInt(req.body?.index ?? req.body?.recommendationIndex ?? '0', 10) || 0);
      const dataset = await getNetworkSuggestionExperimentDataset({ sinceIso, cohort });
      const configs = getNetworkSuggestionAbConfigs();
      const performanceBundle = buildNetworkSuggestionExperimentAnalytics({
        exposureRows: dataset.exposureRows,
        actionRows: dataset.actionRows,
        configs,
        assignmentCounts: dataset.assignmentCounts
      });
      const recommendations = buildNetworkSuggestionAbRecommendations(configs, performanceBundle.variants, listNetworkSuggestionAbRecentChanges(10));
      const recommendation = recommendations[recommendationIndex];
      if (!recommendation) {
        return res.status(404).json({
          ok: false,
          code: 'NETWORK_SUGGESTION_RECOMMENDATION_NOT_FOUND',
          message: 'Uygulanabilir recommendation bulunamadı.',
          data: null
        });
      }
      if (!recommendation.guardrails?.can_apply) {
        return res.status(409).json({
          ok: false,
          code: 'NETWORK_SUGGESTION_RECOMMENDATION_GUARDRAIL_BLOCKED',
          message: 'Recommendation guardrail nedeniyle uygulanamıyor.',
          data: {
            recommendation_index: recommendationIndex,
            recommendation,
            guardrails: recommendation.guardrails
          }
        });
      }
      if (String(req.body?.confirmation || '').trim().toLowerCase() !== NETWORK_SUGGESTION_APPLY_CONFIRMATION_TOKEN) {
        return res.status(409).json({
          ok: false,
          code: 'NETWORK_SUGGESTION_RECOMMENDATION_CONFIRM_REQUIRED',
          message: 'Recommendation uygulamak için ikinci onay gerekli.',
          data: {
            recommendation_index: recommendationIndex,
            confirmation_token: NETWORK_SUGGESTION_APPLY_CONFIRMATION_TOKEN,
            recommendation
          }
        });
      }

      const now = new Date().toISOString();
      const touchedVariants = new Set();
      const beforeSnapshot = [];
      if (recommendation.patch && typeof recommendation.patch === 'object') {
        const variant = resolveNetworkSuggestionVariant(recommendation.variant);
        const existing = await sqlGetAsync('SELECT variant, params_json FROM network_suggestion_ab_config WHERE variant = ?', [variant]);
        if (!existing) {
          return res.status(404).json({
            ok: false,
            code: 'NETWORK_SUGGESTION_VARIANT_NOT_FOUND',
            message: 'Recommendation varyantı bulunamadı.',
            data: null
          });
        }
        beforeSnapshot.push(...snapshotNetworkSuggestionConfigs(configs, [variant]));
        let currentParams = networkSuggestionDefaultVariants[variant]?.params || networkSuggestionDefaultParams;
        try {
          currentParams = existing.params_json ? JSON.parse(existing.params_json) : currentParams;
        } catch {
          // keep defaults
        }
        const mergedParams = normalizeNetworkSuggestionParams(
          { ...currentParams, ...recommendation.patch },
          networkSuggestionDefaultVariants[variant]?.params || networkSuggestionDefaultParams
        );
        await sqlRunAsync(
          `UPDATE network_suggestion_ab_config
           SET params_json = ?, updated_at = ?
           WHERE variant = ?`,
          [JSON.stringify(mergedParams), now, variant]
        );
        touchedVariants.add(variant);
      }

      if (recommendation.trafficPatch && typeof recommendation.trafficPatch === 'object') {
        const trafficVariants = Object.keys(recommendation.trafficPatch || {}).map((variantKey) => resolveNetworkSuggestionVariant(variantKey));
        const trafficSnapshot = snapshotNetworkSuggestionConfigs(configs, trafficVariants);
        for (const row of trafficSnapshot) {
          if (!beforeSnapshot.some((item) => item.variant === row.variant)) beforeSnapshot.push(row);
        }
        for (const [variantKey, nextTraffic] of Object.entries(recommendation.trafficPatch)) {
          const variant = resolveNetworkSuggestionVariant(variantKey);
          await sqlRunAsync(
            `UPDATE network_suggestion_ab_config
             SET traffic_pct = ?, updated_at = ?
             WHERE variant = ?`,
            [clamp(Math.round(Number(nextTraffic || 0)), 0, 100), now, variant]
          );
          touchedVariants.add(variant);
        }
      }

      const afterSnapshot = snapshotNetworkSuggestionConfigs(getNetworkSuggestionAbConfigs(), Array.from(touchedVariants));
      const historyResult = await sqlRunAsync(
        `INSERT INTO network_suggestion_ab_change_log
         (action_type, related_change_id, actor_user_id, recommendation_index, cohort, window_days, payload_json,
          before_snapshot_json, after_snapshot_json, created_at, rolled_back_at, rollback_change_id)
         VALUES (?, NULL, ?, ?, ?, ?, ?, ?, ?, ?, NULL, NULL)`,
        [
          'apply',
          Number(req.session?.userId || 0) || null,
          recommendationIndex,
          String(cohort || 'all'),
          windowDays,
          JSON.stringify(recommendation),
          JSON.stringify(beforeSnapshot),
          JSON.stringify(afterSnapshot),
          now
        ]
      );
      const historyId = Number(historyResult?.lastInsertRowid || 0) || null;

      logAdminAction(req, 'network_suggestion_ab_recommendation_apply', {
        historyId,
        recommendationIndex,
        variant: recommendation.variant,
        touchedVariants: Array.from(touchedVariants),
        hasPatch: Boolean(recommendation.patch && typeof recommendation.patch === 'object'),
        hasTrafficPatch: Boolean(recommendation.trafficPatch && typeof recommendation.trafficPatch === 'object')
      });

      return res.json({
        ok: true,
        code: 'NETWORK_SUGGESTION_RECOMMENDATION_APPLIED',
        message: 'Recommendation konfigürasyona uygulandı.',
        data: {
          history_id: historyId,
          recommendation_index: recommendationIndex,
          applied: recommendation,
          touched_variants: Array.from(touchedVariants),
          before_snapshot: beforeSnapshot,
          after_snapshot: afterSnapshot
        }
      });
    } catch (err) {
      console.error('admin.network-suggestion-ab.apply failed:', err);
      return res.status(500).json({
        ok: false,
        code: 'NETWORK_SUGGESTION_RECOMMENDATION_APPLY_FAILED',
        message: 'Recommendation uygulanamadı.',
        data: null
      });
    }
  });

  app.post('/api/new/admin/network-suggestion-ab/rollback/:id', requireAdmin, async (req, res) => {
    try {
      ensureNetworkSuggestionAbTables();
      const changeId = Number(req.params.id || 0);
      if (!changeId) {
        return res.status(400).json({
          ok: false,
          code: 'NETWORK_SUGGESTION_ROLLBACK_ID_REQUIRED',
          message: 'Rollback için geçerli kayıt ID gerekli.',
          data: null
        });
      }
      const row = await sqlGetAsync(
        `SELECT id, action_type, payload_json, before_snapshot_json, after_snapshot_json, rolled_back_at, rollback_change_id
         FROM network_suggestion_ab_change_log
         WHERE id = ?`,
        [changeId]
      );
      if (!row) {
        return res.status(404).json({
          ok: false,
          code: 'NETWORK_SUGGESTION_CHANGE_NOT_FOUND',
          message: 'Rollback kaydı bulunamadı.',
          data: null
        });
      }
      if (String(row.action_type || '') !== 'apply') {
        return res.status(409).json({
          ok: false,
          code: 'NETWORK_SUGGESTION_ROLLBACK_ONLY_APPLY',
          message: 'Sadece apply kayıtları rollback edilebilir.',
          data: null
        });
      }
      if (row.rolled_back_at || Number(row.rollback_change_id || 0) > 0) {
        return res.status(409).json({
          ok: false,
          code: 'NETWORK_SUGGESTION_ALREADY_ROLLED_BACK',
          message: 'Bu recommendation zaten rollback edilmiş.',
          data: null
        });
      }

      const beforeSnapshot = parseJsonValue(row.before_snapshot_json, []) || [];
      const afterSnapshot = parseJsonValue(row.after_snapshot_json, []) || [];
      if (!Array.isArray(beforeSnapshot) || !beforeSnapshot.length) {
        return res.status(409).json({
          ok: false,
          code: 'NETWORK_SUGGESTION_ROLLBACK_SNAPSHOT_MISSING',
          message: 'Rollback için gerekli snapshot bulunamadı.',
          data: null
        });
      }

      const now = new Date().toISOString();
      for (const snapshot of beforeSnapshot) {
        const variant = resolveNetworkSuggestionVariant(snapshot?.variant);
        const params = normalizeNetworkSuggestionParams(
          snapshot?.params && typeof snapshot.params === 'object' ? snapshot.params : {},
          networkSuggestionDefaultVariants[variant]?.params || networkSuggestionDefaultParams
        );
        await sqlRunAsync(
          `UPDATE network_suggestion_ab_config
           SET name = ?, description = ?, traffic_pct = ?, enabled = ?, params_json = ?, updated_at = ?
           WHERE variant = ?`,
          [
            String(snapshot?.name || networkSuggestionDefaultVariants[variant]?.name || variant),
            String(snapshot?.description || networkSuggestionDefaultVariants[variant]?.description || ''),
            clamp(Math.round(Number(snapshot?.trafficPct || 0)), 0, 100),
            toDbBooleanParam(Number(snapshot?.enabled || 0) === 1),
            JSON.stringify(params),
            now,
            variant
          ]
        );
      }

      const restoredSnapshot = snapshotNetworkSuggestionConfigs(getNetworkSuggestionAbConfigs(), beforeSnapshot.map((item) => item.variant));
      const rollbackResult = await sqlRunAsync(
        `INSERT INTO network_suggestion_ab_change_log
         (action_type, related_change_id, actor_user_id, recommendation_index, cohort, window_days, payload_json,
          before_snapshot_json, after_snapshot_json, created_at, rolled_back_at, rollback_change_id)
         VALUES (?, ?, ?, NULL, ?, NULL, ?, ?, ?, ?, NULL, NULL)`,
        [
          'rollback',
          changeId,
          Number(req.session?.userId || 0) || null,
          'all',
          JSON.stringify({ source_change_id: changeId }),
          JSON.stringify(afterSnapshot),
          JSON.stringify(restoredSnapshot),
          now
        ]
      );
      const rollbackHistoryId = Number(rollbackResult?.lastInsertRowid || 0) || null;
      await sqlRunAsync(
        `UPDATE network_suggestion_ab_change_log
         SET rolled_back_at = ?, rollback_change_id = ?
         WHERE id = ?`,
        [now, rollbackHistoryId, changeId]
      );

      logAdminAction(req, 'network_suggestion_ab_recommendation_rollback', {
        changeId,
        rollbackHistoryId,
        restoredVariants: beforeSnapshot.map((item) => resolveNetworkSuggestionVariant(item.variant))
      });

      return res.json({
        ok: true,
        code: 'NETWORK_SUGGESTION_RECOMMENDATION_ROLLED_BACK',
        message: 'Recommendation değişikliği geri alındı.',
        data: {
          change_id: changeId,
          rollback_history_id: rollbackHistoryId,
          restored_snapshot: restoredSnapshot
        }
      });
    } catch (err) {
      console.error('admin.network-suggestion-ab.rollback failed:', err);
      return res.status(500).json({
        ok: false,
        code: 'NETWORK_SUGGESTION_ROLLBACK_FAILED',
        message: 'Recommendation rollback edilemedi.',
        data: null
      });
    }
  });

  app.put('/api/new/admin/network-suggestion-ab/:variant', requireAdmin, async (req, res) => {
    try {
      const variant = String(req.params.variant || '').trim().toUpperCase();
      if (!variant) return res.status(400).send('Variant gerekli.');
      const existing = await sqlGetAsync('SELECT variant, params_json FROM network_suggestion_ab_config WHERE variant = ?', [variant]);
      if (!existing) return res.status(404).send('Variant bulunamadı.');
      let currentParams = networkSuggestionDefaultVariants[variant]?.params || networkSuggestionDefaultParams;
      try {
        currentParams = existing.params_json ? JSON.parse(existing.params_json) : currentParams;
      } catch {
        // ignore parse error and keep fallback
      }
      const payload = req.body || {};
      const mergedParams = normalizeNetworkSuggestionParams(
        payload.params && typeof payload.params === 'object'
          ? { ...currentParams, ...payload.params }
          : currentParams,
        networkSuggestionDefaultVariants[variant]?.params || networkSuggestionDefaultParams
      );
      const trafficPct = clamp(Math.round(Number(payload.trafficPct ?? payload.traffic_pct ?? 50) || 0), 0, 100);
      const enabled = String(payload.enabled ?? '1') === '1' ? 1 : 0;
      const enabledDbValue = toDbBooleanParam(enabled);
      const name = String(payload.name || '').trim() || (networkSuggestionDefaultVariants[variant]?.name || variant);
      const description = String(payload.description || '').trim() || (networkSuggestionDefaultVariants[variant]?.description || '');
      await sqlRunAsync(
        `UPDATE network_suggestion_ab_config
         SET name = ?, description = ?, traffic_pct = ?, enabled = ?, params_json = ?, updated_at = ?
         WHERE variant = ?`,
        [name, description, trafficPct, enabledDbValue, JSON.stringify(mergedParams), new Date().toISOString(), variant]
      );
      logAdminAction(req, 'network_suggestion_ab_config_update', { variant, trafficPct, enabled });
      res.json({ ok: true });
    } catch(err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.post('/api/new/admin/network-suggestion-ab/rebalance', requireAdmin, async (req, res) => {
    try {
      const keepAssignments = String(req.body?.keepAssignments || '0') === '1';
      if (!keepAssignments) {
        await sqlRunAsync('DELETE FROM network_suggestion_ab_assignments');
      }
      logAdminAction(req, 'network_suggestion_ab_rebalance', { keepAssignments });
      res.json({ ok: true, keepAssignments });
    } catch(err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.get('/api/new/admin/stats', requireAdmin, handleAdminDashboardSummary);
  app.get('/api/admin/dashboard/summary', requireAdmin, handleAdminDashboardSummary);

  app.get('/api/new/admin/engagement-scores', requireAdmin, async (req, res) => {
    try {
      const q = String(req.query.q || '').trim();
      const minScoreRaw = String(req.query.minScore ?? req.query.min_score ?? '').trim();
      const maxScoreRaw = String(req.query.maxScore ?? req.query.max_score ?? '').trim();
      const minScore = minScoreRaw === '' ? NaN : Number(minScoreRaw);
      const maxScore = maxScoreRaw === '' ? NaN : Number(maxScoreRaw);
      const status = String(req.query.status || 'all').trim();
      const sort = String(req.query.sort || 'score_desc').trim();
      const variant = String(req.query.variant || '').trim().toUpperCase();
      const page = Math.max(parseInt(req.query.page || '1', 10), 1);
      const limit = Math.min(Math.max(parseInt(req.query.limit || '40', 10), 1), 200);
      const activeExpr = "(COALESCE(CAST(u.aktiv AS INTEGER), 0) = 1 OR LOWER(CAST(u.aktiv AS TEXT)) IN ('true','evet','yes'))";
      const bannedExpr = "(COALESCE(CAST(u.yasak AS INTEGER), 0) = 1 OR LOWER(CAST(u.yasak AS TEXT)) IN ('true','evet','yes'))";

      const whereParts = [];
      const params = [];
      if (q) {
        whereParts.push('(LOWER(CAST(u.kadi AS TEXT)) LIKE LOWER(?) OR LOWER(CAST(u.isim AS TEXT)) LIKE LOWER(?) OR LOWER(CAST(u.soyisim AS TEXT)) LIKE LOWER(?))');
        params.push(`%${q}%`, `%${q}%`, `%${q}%`);
      }
      if (status === 'active') whereParts.push(`${activeExpr} AND NOT ${bannedExpr}`);
      if (status === 'pending') whereParts.push(`NOT ${activeExpr} AND NOT ${bannedExpr}`);
      if (status === 'banned') whereParts.push(`${bannedExpr}`);
      if (Number.isFinite(minScore)) {
        whereParts.push('COALESCE(es.score, 0) >= ?');
        params.push(minScore);
      }
      if (Number.isFinite(maxScore)) {
        whereParts.push('COALESCE(es.score, 0) <= ?');
        params.push(maxScore);
      }
      if (variant) {
        whereParts.push("COALESCE(NULLIF(es.ab_variant, ''), 'A') = ?");
        params.push(variant);
      }
      const where = whereParts.length ? `WHERE ${whereParts.join(' AND ')}` : '';
      const sortMap = {
        score_desc: 'COALESCE(es.score, 0) DESC, u.id DESC',
        score_asc: 'COALESCE(es.score, 0) ASC, u.id DESC',
        recent_update: 'COALESCE(es.updated_at, "") DESC, u.id DESC',
        name: 'u.kadi COLLATE NOCASE ASC'
      };
      const orderBy = sortMap[sort] || sortMap.score_desc;
      const total = (await sqlGetAsync(
        `SELECT COUNT(*) AS cnt
         FROM uyeler u
         LEFT JOIN member_engagement_scores es ON es.user_id = u.id
         ${where}`,
        params
      ))?.cnt || 0;
      const pages = Math.max(Math.ceil(total / limit), 1);
      const safePage = Math.min(page, pages);
      const offset = (safePage - 1) * limit;

      const items = await sqlAllAsync(
        `SELECT u.id, u.kadi, u.isim, u.soyisim, u.resim, u.aktiv, u.yasak, u.online, u.verified,
                COALESCE(NULLIF(es.ab_variant, ''), 'A') AS ab_variant,
                COALESCE(es.score, 0) AS score,
                COALESCE(es.raw_score, 0) AS raw_score,
                COALESCE(es.creator_score, 0) AS creator_score,
                COALESCE(es.engagement_received_score, 0) AS engagement_received_score,
                COALESCE(es.community_score, 0) AS community_score,
                COALESCE(es.network_score, 0) AS network_score,
                COALESCE(es.quality_score, 0) AS quality_score,
                COALESCE(es.penalty_score, 0) AS penalty_score,
                COALESCE(es.posts_30d, 0) AS posts_30d,
                COALESCE(es.likes_received_30d, 0) AS likes_received_30d,
                COALESCE(es.comments_received_30d, 0) AS comments_received_30d,
                COALESCE(es.followers_count, 0) AS followers_count,
                COALESCE(es.following_count, 0) AS following_count,
                es.last_activity_at,
                es.updated_at
         FROM uyeler u
         LEFT JOIN member_engagement_scores es ON es.user_id = u.id
         ${where}
         ORDER BY ${orderBy}
         LIMIT ? OFFSET ?`,
        [...params, limit, offset]
      );

      const summary = (await sqlGetAsync(
        `SELECT ROUND(AVG(COALESCE(es.score, 0)), 2) AS avgScore,
                MAX(COALESCE(es.score, 0)) AS maxScore,
                MIN(COALESCE(es.score, 0)) AS minScore
         FROM uyeler u
         LEFT JOIN member_engagement_scores es ON es.user_id = u.id`
      )) || { avgScore: 0, maxScore: 0, minScore: 0 };
      const lastCalculatedAt = (await sqlGetAsync('SELECT MAX(updated_at) AS ts FROM member_engagement_scores'))?.ts || null;
      res.json({
        items,
        page: safePage,
        pages,
        total,
        limit,
        sort,
        status,
        summary,
        lastCalculatedAt
      });
    } catch(err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.post('/api/new/admin/engagement-scores/recalculate', requireAdmin, async (_req, res) => {
    try {
      recalculateMemberEngagementScores('admin_manual');
      const lastCalculatedAt = (await sqlGetAsync('SELECT MAX(updated_at) AS ts FROM member_engagement_scores'))?.ts || null;
      res.json({ ok: true, lastCalculatedAt });
    } catch(err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.get('/api/new/admin/live', requireAdmin, handleAdminDashboardActivity);
  app.get('/api/admin/dashboard/activity', requireAdmin, handleAdminDashboardActivity);
}
