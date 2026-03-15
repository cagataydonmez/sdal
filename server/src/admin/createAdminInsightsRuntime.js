export function createAdminInsightsRuntime({
  sqlGet,
  sqlAll,
  sqlGetAsync,
  sqlAllAsync,
  sqlRun,
  sqlRunAsync,
  hasTable,
  hasColumn,
  joinUserOnPhotoOwnerExpr,
  readAdminStorageSnapshot,
  cleanupStaleOnlineUsersAsync,
  listOnlineMembersAsync,
  getEngagementAbConfigs,
  engagementDefaultParams,
  engagementDefaultVariants,
  normalizeEngagementParams,
  toDbBooleanParam,
  recalculateMemberEngagementScores,
  scheduleEngagementRecalculation,
  logAdminAction,
  getStatsCache,
  setStatsCache,
  getLiveCache,
  setLiveCache,
  adminStatsCacheTtlMs,
  adminLiveCacheTtlMs
}) {
  function clamp(value, min, max) {
    const numeric = Number(value);
    if (!Number.isFinite(numeric)) return min;
    return Math.max(min, Math.min(max, numeric));
  }

  function round2(value) {
    const n = Number(value);
    if (!Number.isFinite(n)) return 0;
    return Number(n.toFixed(2));
  }

  async function buildEngagementAbPerformanceRows() {
    const execAll = sqlAllAsync || ((...a) => Promise.resolve(sqlAll(...a)));
    const rows = await execAll(
      `SELECT COALESCE(NULLIF(ab_variant, ''), 'A') AS variant,
              COUNT(*) AS users,
              ROUND(AVG(COALESCE(score, 0)), 2) AS avg_score,
              ROUND(AVG(COALESCE(raw_score, 0)), 2) AS avg_raw_score,
              ROUND(AVG(COALESCE(posts_30d, 0)), 2) AS avg_posts_30d,
              ROUND(AVG(COALESCE(likes_received_30d, 0)), 2) AS avg_likes_received_30d,
              ROUND(AVG(COALESCE(comments_received_30d, 0)), 2) AS avg_comments_received_30d,
              ROUND(AVG(COALESCE(follows_gained_30d, 0)), 2) AS avg_follows_gained_30d,
              ROUND(AVG(COALESCE(story_views_received_30d, 0)), 2) AS avg_story_views_received_30d
       FROM member_engagement_scores
       GROUP BY COALESCE(NULLIF(ab_variant, ''), 'A')
       ORDER BY variant ASC`
    );
    return rows.map((row) => ({
      ...row,
      engagementRate: Number(((Number(row.avg_likes_received_30d || 0) + Number(row.avg_comments_received_30d || 0) * 2) / Math.max(Number(row.avg_posts_30d || 0), 1)).toFixed(2))
    }));
  }

  function buildEngagementAbRecommendations(configs, performance) {
    const perfMap = new Map((performance || []).map((item) => [String(item.variant || '').toUpperCase(), item]));
    const configMap = new Map((configs || []).map((item) => [String(item.variant || '').toUpperCase(), item]));
    const baseline = perfMap.get('A') || performance?.[0] || null;
    const recommendations = [];

    for (const cfg of (configs || [])) {
      const variant = String(cfg.variant || '').toUpperCase();
      const perf = perfMap.get(variant);
      if (!perf || Number(perf.users || 0) < 20) continue;
      const params = cfg.params || engagementDefaultParams;
      const patch = {};
      const reasons = [];
      const confidenceParts = [];

      if (baseline && baseline.variant !== variant && Number(baseline.users || 0) >= 20) {
        const baselineRate = Math.max(Number(baseline.engagementRate || 0), 0.01);
        const baselineScore = Math.max(Number(baseline.avg_score || 0), 0.01);
        const rateDelta = (Number(perf.engagementRate || 0) - baselineRate) / baselineRate;
        const scoreDelta = (Number(perf.avg_score || 0) - baselineScore) / baselineScore;

        if (rateDelta < -0.08) {
          patch.receivedCommentWeight = round2(params.receivedCommentWeight * 1.1);
          patch.scaleReceived = round2(params.scaleReceived * 1.06);
          reasons.push(`Etkilesim orani baseline'a gore dusuk (${round2(rateDelta * 100)}%).`);
          confidenceParts.push(Math.min(0.4, Math.abs(rateDelta)));
        } else if (rateDelta > 0.08 && scoreDelta > -0.03) {
          patch.receivedCommentWeight = round2(params.receivedCommentWeight * 1.04);
          patch.capReceived = round2(params.capReceived * 1.03);
          reasons.push(`Etkilesim orani baseline'a gore yuksek (${round2(rateDelta * 100)}%).`);
          confidenceParts.push(Math.min(0.35, Math.abs(rateDelta)));
        }

        if (scoreDelta < -0.08) {
          patch.recency7d = round2(params.recency7d * 1.03);
          patch.recency30d = round2(params.recency30d * 1.02);
          patch.penaltyLowQualityPost = round2(params.penaltyLowQualityPost * 0.95);
          reasons.push(`Ortalama skor baseline'a gore dusuk (${round2(scoreDelta * 100)}%).`);
          confidenceParts.push(Math.min(0.35, Math.abs(scoreDelta)));
        } else if (scoreDelta > 0.12 && rateDelta >= -0.05) {
          patch.penaltyAggressiveFollow = round2(params.penaltyAggressiveFollow * 1.05);
          reasons.push(`Ortalama skor baseline'a gore yuksek (${round2(scoreDelta * 100)}%).`);
          confidenceParts.push(Math.min(0.25, Math.abs(scoreDelta)));
        }
      }

      const postsAvg = Number(perf.avg_posts_30d || 0);
      const followsGainAvg = Number(perf.avg_follows_gained_30d || 0);
      if (postsAvg < 1.2) {
        patch.creatorRecentPostWeight = round2(params.creatorRecentPostWeight * 1.07);
        reasons.push('Icerik uretim ortalamasi dusuk; taze icerik sinyali artirildi.');
        confidenceParts.push(0.14);
      }
      if (followsGainAvg < 0.5) {
        patch.networkFollowGainWeight = round2(params.networkFollowGainWeight * 1.06);
        reasons.push('Takipci artisi dusuk; network buyume katsayisi artirildi.');
        confidenceParts.push(0.12);
      }

      const normalizedPatch = normalizeEngagementParams(
        { ...params, ...patch },
        engagementDefaultVariants[variant]?.params || engagementDefaultParams
      );
      const finalPatch = {};
      for (const key of Object.keys(params)) {
        if (Number(normalizedPatch[key]) !== Number(params[key])) {
          finalPatch[key] = normalizedPatch[key];
        }
      }
      if (!Object.keys(finalPatch).length) continue;

      const confidenceBase = confidenceParts.reduce((sum, value) => sum + value, 0);
      const sampleFactor = Math.min(1, Number(perf.users || 0) / 250);
      const confidence = round2(clamp(0.25 + confidenceBase + sampleFactor * 0.35, 0, 0.95));

      recommendations.push({
        variant,
        confidence,
        reasons: reasons.slice(0, 4),
        patch: finalPatch
      });
    }

    const activeConfigs = (configs || []).filter((cfg) => Number(cfg.enabled || 0) === 1);
    if (activeConfigs.length >= 2) {
      const scored = activeConfigs
        .map((cfg) => {
          const perf = perfMap.get(cfg.variant);
          if (!perf) return null;
          const quality = Number(perf.avg_score || 0) * 0.6 + Number(perf.engagementRate || 0) * 0.4;
          return { variant: cfg.variant, quality };
        })
        .filter(Boolean)
        .sort((a, b) => b.quality - a.quality);
      if (scored.length >= 2 && scored[0].quality > scored[1].quality * 1.05) {
        const winner = configMap.get(scored[0].variant);
        const loser = configMap.get(scored[scored.length - 1].variant);
        if (winner && loser) {
          recommendations.push({
            variant: winner.variant,
            confidence: 0.62,
            reasons: [`${winner.variant} varyanti kalite metriginide daha iyi performans gosteriyor.`],
            trafficPatch: {
              [winner.variant]: clamp(Number(winner.trafficPct || 0) + 5, 0, 100),
              [loser.variant]: clamp(Number(loser.trafficPct || 0) - 5, 0, 100)
            }
          });
        }
      }
    }

    return recommendations;
  }

  async function handleEngagementAbOverview(_req, res) {
    const configs = getEngagementAbConfigs().map((cfg) => ({
      variant: cfg.variant,
      name: cfg.name,
      description: cfg.description,
      trafficPct: cfg.trafficPct,
      enabled: cfg.enabled,
      params: cfg.params,
      updatedAt: cfg.updatedAt
    }));
    const execAll = sqlAllAsync || ((...a) => Promise.resolve(sqlAll(...a)));
    const execGet = sqlGetAsync || ((...a) => Promise.resolve(sqlGet(...a)));
    const performance = await buildEngagementAbPerformanceRows();
    const recommendations = buildEngagementAbRecommendations(configs, performance);
    const [assignmentCounts, lastCalculatedRow] = await Promise.all([
      execAll(
        `SELECT variant, COUNT(*) AS cnt
         FROM engagement_ab_assignments
         GROUP BY variant
         ORDER BY variant ASC`
      ),
      execGet('SELECT MAX(updated_at) AS ts FROM member_engagement_scores')
    ]);
    const lastCalculatedAt = lastCalculatedRow?.ts || null;
    res.json({ configs, performance, assignmentCounts, recommendations, lastCalculatedAt });
  }

  async function handleEngagementAbUpdate(req, res) {
    const execGet = sqlGetAsync || ((...a) => Promise.resolve(sqlGet(...a)));
    const execRun = sqlRunAsync || ((...a) => Promise.resolve(sqlRun(...a)));
    const variant = String(req.params.variant || '').trim().toUpperCase();
    if (!variant) return res.status(400).send('Variant gerekli.');
    const existing = await execGet('SELECT variant, params_json FROM engagement_ab_config WHERE variant = ?', [variant]);
    if (!existing) return res.status(404).send('Variant bulunamadi.');
    let currentParams = engagementDefaultVariants[variant]?.params || engagementDefaultParams;
    try {
      currentParams = existing.params_json ? JSON.parse(existing.params_json) : currentParams;
    } catch {
      // ignore parse error and keep fallback
    }
    const payload = req.body || {};
    const mergedParams = normalizeEngagementParams(
      payload.params && typeof payload.params === 'object'
        ? { ...currentParams, ...payload.params }
        : currentParams,
      engagementDefaultVariants[variant]?.params || engagementDefaultParams
    );
    const trafficPct = clamp(Math.round(Number(payload.trafficPct ?? payload.traffic_pct ?? 50) || 0), 0, 100);
    const enabled = String(payload.enabled ?? '1') === '1' ? 1 : 0;
    const enabledDbValue = toDbBooleanParam(enabled);
    const name = String(payload.name || '').trim() || (engagementDefaultVariants[variant]?.name || variant);
    const description = String(payload.description || '').trim() || (engagementDefaultVariants[variant]?.description || '');
    await execRun(
      `UPDATE engagement_ab_config
       SET name = ?, description = ?, traffic_pct = ?, enabled = ?, params_json = ?, updated_at = ?
       WHERE variant = ?`,
      [name, description, trafficPct, enabledDbValue, JSON.stringify(mergedParams), new Date().toISOString(), variant]
    );
    logAdminAction(req, 'engagement_ab_config_update', { variant, trafficPct, enabled });
    scheduleEngagementRecalculation('engagement_ab_updated');
    res.json({ ok: true });
  }

  async function handleEngagementAbRebalance(req, res) {
    const execRun = sqlRunAsync || ((...a) => Promise.resolve(sqlRun(...a)));
    const keepAssignments = String(req.body?.keepAssignments || '0') === '1';
    if (!keepAssignments) {
      await execRun('DELETE FROM engagement_ab_assignments');
    }
    recalculateMemberEngagementScores('admin_rebalance_ab');
    logAdminAction(req, 'engagement_ab_rebalance', { keepAssignments });
    res.json({ ok: true, keepAssignments });
  }

  async function handleAdminDashboardSummary(req, res) {
    try {
      const recentLimit = Math.min(Math.max(parseInt(req.query.recentLimit || '12', 10), 1), 80);
      const cacheKey = `recentLimit:${recentLimit}`;
      const now = Date.now();
      const cache = getStatsCache();
      if (cache.value && cache.key === cacheKey && cache.expiresAt > now) {
        return res.json(cache.value);
      }

      cleanupStaleOnlineUsersAsync().catch(() => {});

      const countBy = async (tableName, whereClause = '', params = []) => {
        if (!hasTable(tableName)) return 0;
        const row = await sqlGetAsync(
          `SELECT CAST(COUNT(*) AS INTEGER) AS cnt FROM ${tableName}${whereClause ? ` WHERE ${whereClause}` : ''}`,
          params
        );
        return Number(row?.cnt || 0);
      };

      const [
        countsRow,
        recentUsers,
        recentPosts,
        recentPhotos,
        networkFunnelRows,
        mentorshipRows,
        teacherLinkRows
      ] = await Promise.all([
        Promise.all([
          countBy('uyeler'),
          countBy('uyeler', 'aktiv = 1 AND yasak = 0'),
          countBy('uyeler', 'aktiv = 0 AND yasak = 0'),
          countBy('uyeler', 'yasak = 1'),
          countBy('posts'),
          countBy('album_foto'),
          countBy('stories'),
          countBy('groups'),
          countBy('gelenkutusu'),
          countBy('events'),
          countBy('announcements'),
          countBy('chat_messages')
        ]).then(([users, active_users, pending_users, banned_users, posts, photos, stories, groups, messages, events, announcements, chat]) => ({
          users,
          active_users,
          pending_users,
          banned_users,
          posts,
          photos,
          stories,
          groups,
          messages,
          events,
          announcements,
          chat
        })),
        hasTable('uyeler')
          ? sqlAllAsync(
            `SELECT id, kadi, isim, soyisim, resim, ilktarih
             FROM uyeler
             ORDER BY id DESC
             LIMIT ?`,
            [recentLimit]
          )
          : Promise.resolve([]),
        hasTable('posts')
          ? sqlAllAsync(
            `SELECT p.id, p.content, p.image, p.created_at, u.kadi
             FROM posts p
             LEFT JOIN uyeler u ON u.id = p.user_id
             ORDER BY p.id DESC
             LIMIT ?`,
            [recentLimit]
          )
          : Promise.resolve([]),
        hasTable('album_foto')
          ? sqlAllAsync(
            `SELECT f.id, f.dosyaadi, f.baslik, f.tarih, u.kadi
             FROM album_foto f
             LEFT JOIN uyeler u ON ${joinUserOnPhotoOwnerExpr}
             ORDER BY f.id DESC
             LIMIT ?`,
            [recentLimit]
          )
          : Promise.resolve([]),
        hasTable('connection_requests')
          ? sqlAllAsync(
            `SELECT status, CAST(COUNT(*) AS INTEGER) AS count
             FROM connection_requests
             GROUP BY status`
          )
          : Promise.resolve([]),
        hasTable('mentorship_requests')
          ? sqlAllAsync(
            `SELECT status, CAST(COUNT(*) AS INTEGER) AS count
             FROM mentorship_requests
             GROUP BY status`
          )
          : Promise.resolve([]),
        hasTable('teacher_alumni_links')
          ? sqlAllAsync(
            `SELECT relationship_type, CAST(COUNT(*) AS INTEGER) AS count
             FROM teacher_alumni_links
             GROUP BY relationship_type`
          )
          : Promise.resolve([])
      ]);

      const connectionStats = networkFunnelRows.reduce((acc, row) => {
        const key = String(row?.status || '').toLowerCase();
        if (!key) return acc;
        acc[key] = Number(row?.count || 0);
        return acc;
      }, {});
      const mentorshipStats = mentorshipRows.reduce((acc, row) => {
        const key = String(row?.status || '').toLowerCase();
        if (!key) return acc;
        acc[key] = Number(row?.count || 0);
        return acc;
      }, {});
      const teacherLinkByType = teacherLinkRows.reduce((acc, row) => {
        const key = String(row?.relationship_type || '').toLowerCase();
        if (!key) return acc;
        acc[key] = Number(row?.count || 0);
        return acc;
      }, {});

      const counts = {
        users: Number(countsRow?.users || 0),
        activeUsers: Number(countsRow?.active_users || 0),
        pendingUsers: Number(countsRow?.pending_users || 0),
        bannedUsers: Number(countsRow?.banned_users || 0),
        posts: Number(countsRow?.posts || 0),
        photos: Number(countsRow?.photos || 0),
        stories: Number(countsRow?.stories || 0),
        groups: Number(countsRow?.groups || 0),
        messages: Number(countsRow?.messages || 0),
        events: Number(countsRow?.events || 0),
        announcements: Number(countsRow?.announcements || 0),
        chat: Number(countsRow?.chat || 0)
      };
      const payload = {
        counts,
        networking: {
          connections: {
            requested: connectionStats.pending || 0,
            accepted: connectionStats.accepted || 0,
            ignored: connectionStats.ignored || 0,
            declined: connectionStats.declined || 0
          },
          mentorship: {
            requested: mentorshipStats.requested || 0,
            accepted: mentorshipStats.accepted || 0,
            declined: mentorshipStats.declined || 0
          },
          teacherLinks: {
            total: teacherLinkRows.reduce((sum, row) => sum + Number(row?.count || 0), 0),
            byRelationshipType: teacherLinkByType
          }
        },
        storage: readAdminStorageSnapshot(),
        recentUsers,
        recentPosts,
        recentPhotos
      };
      setStatsCache({
        key: cacheKey,
        value: payload,
        expiresAt: now + adminStatsCacheTtlMs
      });
      return res.json(payload);
    } catch (err) {
      console.error('admin.stats failed:', err);
      return res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  }

  async function handleAdminDashboardActivity(req, res) {
    try {
      const chatLimit = Math.min(Math.max(parseInt(req.query.chatLimit || '8', 10), 1), 50);
      const postLimit = Math.min(Math.max(parseInt(req.query.postLimit || '8', 10), 1), 50);
      const userLimit = Math.min(Math.max(parseInt(req.query.userLimit || '8', 10), 1), 50);
      const activityLimit = Math.min(Math.max(parseInt(req.query.activityLimit || '20', 10), 1), 120);
      const cacheKey = `chat:${chatLimit}:post:${postLimit}:user:${userLimit}:activity:${activityLimit}`;
      const now = Date.now();
      const cache = getLiveCache();
      if (cache.value && cache.key === cacheKey && cache.expiresAt > now) {
        return res.json(cache.value);
      }

      const safeRead = async (label, load, fallback) => {
        try {
          return await load();
        } catch (err) {
          console.error(`admin.live ${label} failed:`, err);
          return fallback;
        }
      };

      await safeRead('cleanup_stale_online', () => cleanupStaleOnlineUsersAsync(), null);
      const [
        onlineMembers,
        countsRow,
        chat,
        posts,
        newestUsers,
        newestPhotos
      ] = await Promise.all([
        safeRead('online_members', () => listOnlineMembersAsync({ limit: 20, excludeUserId: null }), []),
        safeRead(
          'counts',
          async () => {
            const countBy = async (tableName, whereClause = '', params = []) => {
              if (!hasTable(tableName)) return 0;
              const row = await sqlGetAsync(
                `SELECT CAST(COUNT(*) AS INTEGER) AS cnt FROM ${tableName}${whereClause ? ` WHERE ${whereClause}` : ''}`,
                params
              );
              return Number(row?.cnt || 0);
            };
            return {
              pending_verifications: await countBy('verification_requests', 'status = ?', ['pending']),
              pending_events: await countBy(
                'events',
                hasColumn('events', 'approved')
                  ? "LOWER(COALESCE(NULLIF(TRIM(CAST(approved AS TEXT)), ''), '1')) IN ('0','false','hayir','no')"
                  : ''
              ),
              pending_announcements: await countBy(
                'announcements',
                hasColumn('announcements', 'approved')
                  ? "LOWER(COALESCE(NULLIF(TRIM(CAST(approved AS TEXT)), ''), '1')) IN ('0','false','hayir','no')"
                  : ''
              ),
              pending_photos: await countBy(
                'album_foto',
                hasColumn('album_foto', 'aktif')
                  ? 'aktif = 0'
                  : ''
              )
            };
          },
          { pending_verifications: 0, pending_events: 0, pending_announcements: 0, pending_photos: 0 }
        ),
        safeRead(
          'chat_rows',
          () => sqlAllAsync(
            `SELECT c.id, c.created_at AS ts, u.kadi
             FROM chat_messages c
             LEFT JOIN uyeler u ON u.id = c.user_id
             ORDER BY c.id DESC
             LIMIT ?`,
            [chatLimit]
          ),
          []
        ),
        safeRead(
          'post_rows',
          () => sqlAllAsync(
            `SELECT p.id, p.content, p.image, p.created_at AS ts, u.kadi
             FROM posts p
             LEFT JOIN uyeler u ON u.id = p.user_id
             ORDER BY p.id DESC
             LIMIT ?`,
            [postLimit]
          ),
          []
        ),
        safeRead(
          'newest_users',
          () => sqlAllAsync('SELECT id, kadi, isim, soyisim, resim, ilktarih AS ts FROM uyeler ORDER BY id DESC LIMIT ?', [userLimit]),
          []
        ),
        safeRead(
          'newest_photos',
          () => sqlAllAsync(
            `SELECT f.id, f.dosyaadi, f.baslik, f.tarih, u.kadi
             FROM album_foto f
             LEFT JOIN uyeler u ON ${joinUserOnPhotoOwnerExpr}
             ORDER BY f.id DESC
             LIMIT ?`,
            [userLimit]
          ),
          []
        )
      ]);

      const counts = {
        onlineUsers: onlineMembers.length,
        pendingVerifications: Number(countsRow?.pending_verifications || 0),
        pendingEvents: Number(countsRow?.pending_events || 0),
        pendingAnnouncements: Number(countsRow?.pending_announcements || 0),
        pendingPhotos: Number(countsRow?.pending_photos || 0)
      };

      const rows = [];
      for (const item of chat) {
        rows.push({
          id: `chat-${item.id}`,
          type: 'chat',
          message: `@${item.kadi || 'uye'} canli sohbete mesaj gonderdi.`,
          at: item.ts || null
        });
      }
      for (const item of posts) {
        rows.push({
          id: `post-${item.id}`,
          type: 'post',
          message: `@${item.kadi || 'uye'} yeni gonderi paylasti.`,
          at: item.ts || null
        });
      }
      for (const item of newestUsers) {
        rows.push({
          id: `user-${item.id}`,
          type: 'user',
          message: `@${item.kadi || 'uye'} sisteme katildi.`,
          at: item.ts || null
        });
      }

      const newestPosts = posts.map((item) => ({
        id: item.id,
        kadi: item.kadi,
        created_at: item.ts,
        content: item.content || '',
        image: item.image || null
      }));

      rows.sort((a, b) => new Date(b.at || 0).getTime() - new Date(a.at || 0).getTime());
      const payload = {
        counts,
        activity: rows.slice(0, activityLimit),
        onlineMembers,
        newestUsers,
        newestPosts,
        newestPhotos,
        now: new Date().toISOString()
      };
      setLiveCache({
        key: cacheKey,
        value: payload,
        expiresAt: now + adminLiveCacheTtlMs
      });
      return res.json(payload);
    } catch (err) {
      console.error('admin.live failed:', err);
      return res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  }

  return {
    handleEngagementAbOverview,
    handleEngagementAbUpdate,
    handleEngagementAbRebalance,
    handleAdminDashboardSummary,
    handleAdminDashboardActivity
  };
}
