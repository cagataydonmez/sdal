export function createNetworkDiscoveryPayloadRuntime({
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
}) {
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

    const relevantIds = [safeUserId, ...candidateIds];
    const relevantPlaceholders = relevantIds.map(() => '?').join(',');

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
      hasMentorshipRequests && relevantIds.length
        ? sqlAllAsync(
          `SELECT requester_id, mentor_id
           FROM mentorship_requests
           WHERE status = 'accepted'
             AND (requester_id IN (${relevantPlaceholders})
               OR mentor_id IN (${relevantPlaceholders}))`,
          [...relevantIds, ...relevantIds]
        )
        : Promise.resolve([]),
      hasTeacherLinks && relevantIds.length
        ? sqlAllAsync(
          `SELECT teacher_user_id, alumni_user_id
           FROM teacher_alumni_links
           WHERE teacher_user_id IN (${relevantPlaceholders})
              OR alumni_user_id IN (${relevantPlaceholders})`,
          [...relevantIds, ...relevantIds]
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
    parseNetworkWindowDays,
    toIsoThreshold,
    buildNetworkInboxPayload,
    buildNetworkMetricsPayload,
    buildExploreSuggestionsPayload,
    buildNetworkHubPayload
  };
}
