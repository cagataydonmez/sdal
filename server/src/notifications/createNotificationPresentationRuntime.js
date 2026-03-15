export function createNotificationPresentationRuntime({
  sqlRun,
  sqlGet,
  sqlGetAsync,
  sqlAllAsync,
  hasTable,
  ensureJobApplicationsTable
}) {
  const NOTIFICATION_CATEGORY_MAP = Object.freeze({
    like: 'social',
    comment: 'social',
    mention_post: 'social',
    mention_photo: 'social',
    photo_comment: 'social',
    follow: 'social',
    mention_message: 'messaging',
    mention_group: 'groups',
    group_join_request: 'groups',
    group_join_approved: 'groups',
    group_join_rejected: 'groups',
    group_invite: 'groups',
    group_invite_accepted: 'groups',
    group_invite_rejected: 'groups',
    group_role_changed: 'groups',
    mention_event: 'events',
    event_comment: 'events',
    event_invite: 'events',
    event_response: 'events',
    event_reminder: 'events',
    event_starts_soon: 'events',
    connection_request: 'networking',
    connection_accepted: 'networking',
    mentorship_request: 'networking',
    mentorship_accepted: 'networking',
    teacher_network_linked: 'networking',
    teacher_link_review_confirmed: 'networking',
    teacher_link_review_flagged: 'networking',
    teacher_link_review_rejected: 'networking',
    teacher_link_review_merged: 'networking',
    job_application: 'jobs',
    job_application_reviewed: 'jobs',
    job_application_accepted: 'jobs',
    job_application_rejected: 'jobs',
    verification_approved: 'system',
    verification_rejected: 'system',
    member_request_approved: 'system',
    member_request_rejected: 'system',
    announcement_approved: 'system',
    announcement_rejected: 'system'
  });

  const NOTIFICATION_PRIORITY_MAP = Object.freeze({
    like: 'informational',
    comment: 'important',
    mention_post: 'important',
    mention_photo: 'important',
    photo_comment: 'important',
    follow: 'informational',
    mention_message: 'important',
    mention_group: 'important',
    group_join_request: 'actionable',
    group_join_approved: 'important',
    group_join_rejected: 'important',
    group_invite: 'actionable',
    group_invite_accepted: 'important',
    group_invite_rejected: 'important',
    group_role_changed: 'important',
    mention_event: 'important',
    event_comment: 'important',
    event_invite: 'important',
    event_response: 'important',
    event_reminder: 'important',
    event_starts_soon: 'important',
    connection_request: 'actionable',
    connection_accepted: 'important',
    mentorship_request: 'actionable',
    mentorship_accepted: 'important',
    teacher_network_linked: 'important',
    teacher_link_review_confirmed: 'important',
    teacher_link_review_flagged: 'important',
    teacher_link_review_rejected: 'important',
    teacher_link_review_merged: 'important',
    job_application: 'actionable',
    job_application_reviewed: 'important',
    job_application_accepted: 'important',
    job_application_rejected: 'important',
    verification_approved: 'important',
    verification_rejected: 'important',
    member_request_approved: 'important',
    member_request_rejected: 'important',
    announcement_approved: 'important',
    announcement_rejected: 'important'
  });

  const NOTIFICATION_ACTIONABLE_TYPES = Object.freeze(
    Object.entries(NOTIFICATION_PRIORITY_MAP)
      .filter(([, priority]) => priority === 'actionable' || priority === 'critical')
      .map(([type]) => type)
  );

  function getNotificationCategory(type) {
    return NOTIFICATION_CATEGORY_MAP[String(type || '').trim().toLowerCase()] || 'system';
  }

  function getNotificationPriority(type) {
    return NOTIFICATION_PRIORITY_MAP[String(type || '').trim().toLowerCase()] || 'informational';
  }

  function isNotificationActionable(type) {
    const priority = getNotificationPriority(type);
    return priority === 'critical' || priority === 'actionable';
  }

  function ensureNotificationIndexes() {
    if (!hasTable('notifications')) return;
    try {
      sqlRun('CREATE INDEX IF NOT EXISTS idx_notifications_user_id_desc ON notifications (user_id, id DESC)');
    } catch {}
    try {
      sqlRun('CREATE INDEX IF NOT EXISTS idx_notifications_user_read_id ON notifications (user_id, read_at, id DESC)');
    } catch {}
  }

  function buildNotificationSortBucketSql(alias = 'n') {
    const actionableTypeSql = NOTIFICATION_ACTIONABLE_TYPES.map((type) => `'${type}'`).join(', ');
    return `CASE
      WHEN ${alias}.read_at IS NULL AND LOWER(TRIM(COALESCE(${alias}.type, ''))) IN (${actionableTypeSql}) THEN 0
      WHEN ${alias}.read_at IS NULL THEN 1
      WHEN LOWER(TRIM(COALESCE(${alias}.type, ''))) IN (${actionableTypeSql}) THEN 2
      ELSE 3
    END`;
  }

  function normalizeNotificationSortMode(sortMode = 'priority') {
    const mode = String(sortMode || 'priority').trim().toLowerCase();
    return mode === 'priority' ? 'priority' : 'recent';
  }

  function buildNotificationOrderSql(sortMode = 'priority', alias = 'n') {
    const mode = normalizeNotificationSortMode(sortMode);
    if (mode !== 'priority' || NOTIFICATION_ACTIONABLE_TYPES.length === 0) {
      return `ORDER BY ${alias}.id DESC`;
    }
    return `ORDER BY
      ${buildNotificationSortBucketSql(alias)} ASC,
      ${alias}.id DESC`;
  }

  function computeNotificationSortBucket(row) {
    const type = String(row?.type || '').trim().toLowerCase();
    const actionable = isNotificationActionable(type);
    if (!row?.read_at && actionable) return 0;
    if (!row?.read_at) return 1;
    if (actionable) return 2;
    return 3;
  }

  function parseNotificationCursor(rawCursor, sortMode = 'priority') {
    const raw = String(rawCursor || '').trim();
    if (!raw) return null;
    const mode = normalizeNotificationSortMode(sortMode);
    if (mode === 'priority' && raw.includes(':')) {
      const [bucketPart, idPart] = raw.split(':');
      const bucket = parseInt(bucketPart || '', 10);
      const id = parseInt(idPart || '', 10);
      if (Number.isFinite(bucket) && Number.isFinite(id) && id > 0) {
        return { bucket, id };
      }
    }
    const id = parseInt(raw, 10);
    if (!Number.isFinite(id) || id <= 0) return null;
    return { bucket: null, id };
  }

  function buildNotificationCursor(row, sortMode = 'priority') {
    const id = Number(row?.id || 0);
    if (!id) return null;
    const mode = normalizeNotificationSortMode(sortMode);
    if (mode !== 'priority') return String(id);
    return `${computeNotificationSortBucket(row)}:${id}`;
  }

  async function buildNotificationTarget(row) {
    const notificationId = Number(row?.id || 0);
    const entityId = Number(row?.entity_id || 0);
    const sourceUserId = Number(row?.source_user_id || 0);
    const type = String(row?.type || '').trim().toLowerCase();
    const pushNotificationParam = (value) => `${value}${value.includes('?') ? '&' : '?'}notification=${notificationId}`;

    if ((type === 'like' || type === 'comment' || type === 'mention_post') && entityId) {
      return {
        href: `/new?post=${entityId}&notification=${notificationId}`,
        route: '/new',
        entity_type: 'post',
        entity_id: entityId,
        context: { post: entityId, notification: notificationId }
      };
    }
    if (type === 'mention_photo' || type === 'photo_comment') {
      const href = entityId ? `/new/albums/photo/${entityId}?notification=${notificationId}` : `/new/notifications?notification=${notificationId}`;
      return {
        href,
        route: entityId ? `/new/albums/photo/${entityId}` : '/new/notifications',
        entity_type: 'photo',
        entity_id: entityId || null,
        context: { photo: entityId || null, notification: notificationId }
      };
    }
    if (type === 'mention_message') {
      const href = entityId ? `/new/messages/${entityId}?notification=${notificationId}` : `/new/messages?notification=${notificationId}`;
      return {
        href,
        route: entityId ? `/new/messages/${entityId}` : '/new/messages',
        entity_type: 'message',
        entity_id: entityId || null,
        context: { message: entityId || null, notification: notificationId }
      };
    }
    if (type === 'mention_group' && entityId) {
      return {
        href: `/new/groups/${entityId}?tab=posts&notification=${notificationId}`,
        route: `/new/groups/${entityId}`,
        entity_type: 'group',
        entity_id: entityId,
        context: { tab: 'posts', notification: notificationId }
      };
    }
    if (type === 'group_join_request' && entityId) {
      return {
        href: `/new/groups/${entityId}?tab=requests&notification=${notificationId}`,
        route: `/new/groups/${entityId}`,
        entity_type: 'group',
        entity_id: entityId,
        context: { tab: 'requests', notification: notificationId }
      };
    }
    if ((type === 'group_join_approved' || type === 'group_join_rejected') && entityId) {
      return {
        href: `/new/groups/${entityId}?tab=members&notification=${notificationId}`,
        route: `/new/groups/${entityId}`,
        entity_type: 'group',
        entity_id: entityId,
        context: { tab: 'members', notification: notificationId }
      };
    }
    if (type === 'group_invite' && entityId) {
      return {
        href: `/new/groups/${entityId}?tab=invite&notification=${notificationId}`,
        route: `/new/groups/${entityId}`,
        entity_type: 'group',
        entity_id: entityId,
        context: { tab: 'invite', notification: notificationId }
      };
    }
    if ((type === 'group_invite_accepted' || type === 'group_invite_rejected' || type === 'group_role_changed') && entityId) {
      return {
        href: `/new/groups/${entityId}?tab=members&notification=${notificationId}`,
        route: `/new/groups/${entityId}`,
        entity_type: 'group',
        entity_id: entityId,
        context: { tab: 'members', notification: notificationId }
      };
    }
    if ((type === 'mention_event' || type === 'event_comment') && entityId) {
      return {
        href: `/new/events?event=${entityId}&focus=comments&notification=${notificationId}`,
        route: '/new/events',
        entity_type: 'event',
        entity_id: entityId,
        context: { event: entityId, focus: 'comments', notification: notificationId }
      };
    }
    if (type === 'event_invite' && entityId) {
      return {
        href: `/new/events?event=${entityId}&focus=response&notification=${notificationId}`,
        route: '/new/events',
        entity_type: 'event',
        entity_id: entityId,
        context: { event: entityId, focus: 'response', notification: notificationId }
      };
    }
    if (type === 'event_response' && entityId) {
      return {
        href: `/new/events?event=${entityId}&focus=response&notification=${notificationId}`,
        route: '/new/events',
        entity_type: 'event',
        entity_id: entityId,
        context: { event: entityId, focus: 'response', notification: notificationId }
      };
    }
    if ((type === 'event_reminder' || type === 'event_starts_soon') && entityId) {
      return {
        href: `/new/events?event=${entityId}&focus=details&notification=${notificationId}`,
        route: '/new/events',
        entity_type: 'event',
        entity_id: entityId,
        context: { event: entityId, focus: 'details', notification: notificationId }
      };
    }
    if (type === 'follow' && sourceUserId) {
      return {
        href: `/new/members/${sourceUserId}?notification=${notificationId}&context=follow`,
        route: `/new/members/${sourceUserId}`,
        entity_type: 'user',
        entity_id: sourceUserId,
        context: { member: sourceUserId, notification: notificationId, context: 'follow' }
      };
    }
    if (type === 'connection_request') {
      return {
        href: `/new/network/hub?section=incoming-connections${entityId ? `&request=${entityId}` : ''}&notification=${notificationId}`,
        route: '/new/network/hub',
        entity_type: 'connection_request',
        entity_id: entityId || null,
        context: { section: 'incoming-connections', request: entityId || null, notification: notificationId }
      };
    }
    if (type === 'connection_accepted') {
      const href = sourceUserId
        ? `/new/members/${sourceUserId}?notification=${notificationId}&context=connection_accepted`
        : `/new/network/hub?section=outgoing-connections&notification=${notificationId}`;
      return {
        href,
        route: sourceUserId ? `/new/members/${sourceUserId}` : '/new/network/hub',
        entity_type: sourceUserId ? 'user' : 'connection_request',
        entity_id: sourceUserId || entityId || null,
        context: sourceUserId
          ? { member: sourceUserId, notification: notificationId, context: 'connection_accepted' }
          : { section: 'outgoing-connections', notification: notificationId }
      };
    }
    if (type === 'mentorship_request') {
      return {
        href: `/new/network/hub?section=incoming-mentorship${entityId ? `&request=${entityId}` : ''}&notification=${notificationId}`,
        route: '/new/network/hub',
        entity_type: 'mentorship_request',
        entity_id: entityId || null,
        context: { section: 'incoming-mentorship', request: entityId || null, notification: notificationId }
      };
    }
    if (type === 'mentorship_accepted') {
      const href = sourceUserId
        ? `/new/members/${sourceUserId}?notification=${notificationId}&context=mentorship_accepted`
        : `/new/network/hub?section=outgoing-mentorship&notification=${notificationId}`;
      return {
        href,
        route: sourceUserId ? `/new/members/${sourceUserId}` : '/new/network/hub',
        entity_type: sourceUserId ? 'user' : 'mentorship_request',
        entity_id: sourceUserId || entityId || null,
        context: sourceUserId
          ? { member: sourceUserId, notification: notificationId, context: 'mentorship_accepted' }
          : { section: 'outgoing-mentorship', notification: notificationId }
      };
    }
    if (type === 'teacher_network_linked') {
      return {
        href: `/new/network/hub?section=teacher-notifications&notification=${notificationId}${entityId ? `&link=${entityId}` : ''}`,
        route: '/new/network/hub',
        entity_type: 'teacher_link',
        entity_id: entityId || null,
        context: { section: 'teacher-notifications', notification: notificationId, link: entityId || null }
      };
    }
    if (
      type === 'teacher_link_review_confirmed'
      || type === 'teacher_link_review_flagged'
      || type === 'teacher_link_review_rejected'
      || type === 'teacher_link_review_merged'
    ) {
      const reviewStatus = type.replace('teacher_link_review_', '');
      return {
        href: `/new/network/teachers?notification=${notificationId}${entityId ? `&link=${entityId}` : ''}&review=${reviewStatus}`,
        route: '/new/network/teachers',
        entity_type: 'teacher_link',
        entity_id: entityId || null,
        context: { notification: notificationId, link: entityId || null, review: reviewStatus }
      };
    }
    if (type === 'job_application' && entityId) {
      return {
        href: `/new/jobs?job=${entityId}&tab=applications&notification=${notificationId}`,
        route: '/new/jobs',
        entity_type: 'job',
        entity_id: entityId,
        context: { job: entityId, tab: 'applications', notification: notificationId }
      };
    }
    if ((type === 'job_application_reviewed' || type === 'job_application_accepted' || type === 'job_application_rejected') && entityId) {
      ensureJobApplicationsTable();
      const execGet = sqlGetAsync || ((...a) => Promise.resolve(sqlGet(...a)));
      const applicationRow = await execGet('SELECT id, job_id FROM job_applications WHERE id = ?', [entityId]);
      const jobId = Number(applicationRow?.job_id || 0);
      const href = jobId
        ? `/new/jobs?job=${jobId}&focus=my-application&application=${entityId}&notification=${notificationId}`
        : `/new/jobs?notification=${notificationId}`;
      return {
        href,
        route: '/new/jobs',
        entity_type: 'job_application',
        entity_id: entityId,
        context: { job: jobId || null, application: entityId, focus: 'my-application', notification: notificationId }
      };
    }
    if (type === 'verification_approved' || type === 'verification_rejected') {
      const status = type.replace('verification_', '');
      return {
        href: `/new/profile/verification?notification=${notificationId}&status=${status}`,
        route: '/new/profile/verification',
        entity_type: 'verification_request',
        entity_id: entityId || null,
        context: { notification: notificationId, status }
      };
    }
    if ((type === 'member_request_approved' || type === 'member_request_rejected') && entityId) {
      const status = type.replace('member_request_', '');
      return {
        href: `/new/requests?request=${entityId}&notification=${notificationId}&status=${status}`,
        route: '/new/requests',
        entity_type: 'member_request',
        entity_id: entityId,
        context: { request: entityId, notification: notificationId, status }
      };
    }
    if ((type === 'announcement_approved' || type === 'announcement_rejected') && entityId) {
      const status = type.replace('announcement_', '');
      return {
        href: `/new/announcements?announcement=${entityId}&notification=${notificationId}&status=${status}`,
        route: '/new/announcements',
        entity_type: 'announcement',
        entity_id: entityId,
        context: { announcement: entityId, notification: notificationId, status }
      };
    }
    return {
      href: pushNotificationParam('/new'),
      route: '/new',
      entity_type: '',
      entity_id: entityId || null,
      context: { notification: notificationId }
    };
  }

  async function buildNotificationActions(row, prebuiltTarget) {
    const target = prebuiltTarget || await buildNotificationTarget(row);
    const type = String(row?.type || '').trim().toLowerCase();
    const actions = [{ kind: 'open', label: 'Aç', href: target.href }];

    if (type === 'group_invite' && String(row?.invite_status || 'pending') === 'pending' && Number(row?.entity_id || 0) > 0) {
      actions.push(
        { kind: 'accept_group_invite', label: 'Kabul Et', method: 'POST', endpoint: `/api/new/groups/${Number(row.entity_id)}/invitations/respond`, body: { action: 'accept' } },
        { kind: 'reject_group_invite', label: 'Reddet', method: 'POST', endpoint: `/api/new/groups/${Number(row.entity_id)}/invitations/respond`, body: { action: 'reject' } }
      );
    }
    if (type === 'connection_request' && String(row?.request_status || 'pending') === 'pending' && Number(row?.entity_id || 0) > 0) {
      actions.push(
        { kind: 'accept_connection_request', label: 'Kabul Et', method: 'POST', endpoint: `/api/new/connections/accept/${Number(row.entity_id)}`, body: { source_surface: 'notifications_page' } },
        { kind: 'ignore_connection_request', label: 'Yoksay', method: 'POST', endpoint: `/api/new/connections/ignore/${Number(row.entity_id)}`, body: { source_surface: 'notifications_page' } }
      );
    }
    if (type === 'mentorship_request' && String(row?.request_status || 'requested') === 'requested' && Number(row?.entity_id || 0) > 0) {
      actions.push(
        { kind: 'accept_mentorship_request', label: 'Kabul Et', method: 'POST', endpoint: `/api/new/mentorship/accept/${Number(row.entity_id)}`, body: { source_surface: 'notifications_page' } },
        { kind: 'decline_mentorship_request', label: 'Reddet', method: 'POST', endpoint: `/api/new/mentorship/decline/${Number(row.entity_id)}`, body: { source_surface: 'notifications_page' } }
      );
    }
    if (type === 'teacher_network_linked' && !row?.read_at) {
      actions.push({
        kind: 'mark_teacher_notifications_read',
        label: 'Okundu yap',
        method: 'POST',
        endpoint: '/api/new/network/inbox/teacher-links/read',
        body: { source_surface: 'notifications_page' }
      });
    }
    return actions;
  }

  async function enrichNotificationRows(rows, userId) {
    const safeRows = Array.isArray(rows) ? rows : [];
    const inviteEntityIds = Array.from(new Set(
      safeRows
        .filter((row) => String(row?.type || '') === 'group_invite' && Number(row?.entity_id || 0) > 0)
        .map((row) => Number(row.entity_id))
    ));
    const inviteStatusMap = new Map();
    const connectionRequestIds = Array.from(new Set(
      safeRows
        .filter((row) => String(row?.type || '') === 'connection_request' && Number(row?.entity_id || 0) > 0)
        .map((row) => Number(row.entity_id))
    ));
    const mentorshipRequestIds = Array.from(new Set(
      safeRows
        .filter((row) => String(row?.type || '') === 'mentorship_request' && Number(row?.entity_id || 0) > 0)
        .map((row) => Number(row.entity_id))
    ));
    const connectionStatusMap = new Map();
    const mentorshipStatusMap = new Map();

    if (inviteEntityIds.length > 0) {
      const inviteRows = await sqlAllAsync(
        `SELECT group_id, status, id
         FROM group_invites
         WHERE invited_user_id = ?
           AND group_id IN (${inviteEntityIds.map(() => '?').join(',')})
         ORDER BY id DESC`,
        [userId, ...inviteEntityIds]
      );
      for (const inviteRow of inviteRows) {
        const groupId = Number(inviteRow.group_id || 0);
        if (!groupId || inviteStatusMap.has(groupId)) continue;
        inviteStatusMap.set(groupId, String(inviteRow.status || 'pending'));
      }
    }

    if (connectionRequestIds.length > 0) {
      const connectionRows = await sqlAllAsync(
        `SELECT id, status
         FROM connection_requests
         WHERE id IN (${connectionRequestIds.map(() => '?').join(',')})`,
        connectionRequestIds
      );
      for (const connectionRow of connectionRows) {
        connectionStatusMap.set(Number(connectionRow.id || 0), String(connectionRow.status || 'pending'));
      }
    }

    if (mentorshipRequestIds.length > 0) {
      const mentorshipRows = await sqlAllAsync(
        `SELECT id, status
         FROM mentorship_requests
         WHERE id IN (${mentorshipRequestIds.map(() => '?').join(',')})`,
        mentorshipRequestIds
      );
      for (const mentorshipRow of mentorshipRows) {
        mentorshipStatusMap.set(Number(mentorshipRow.id || 0), String(mentorshipRow.status || 'requested'));
      }
    }

    return Promise.all(safeRows.map(async (row) => {
      const inviteStatus = String(row?.type || '') === 'group_invite' && row?.entity_id
        ? (inviteStatusMap.get(Number(row.entity_id || 0)) || 'pending')
        : undefined;
      const requestStatus = String(row?.type || '') === 'connection_request'
        ? (connectionStatusMap.get(Number(row?.entity_id || 0)) || '')
        : String(row?.type || '') === 'mentorship_request'
          ? (mentorshipStatusMap.get(Number(row?.entity_id || 0)) || '')
          : '';
      const baseRow = {
        ...row,
        ...(inviteStatus ? { invite_status: inviteStatus } : {}),
        ...(requestStatus ? { request_status: requestStatus } : {})
      };
      const target = await buildNotificationTarget(baseRow);
      const actions = await buildNotificationActions(baseRow, target);
      return {
        ...baseRow,
        category: getNotificationCategory(baseRow?.type),
        priority: getNotificationPriority(baseRow?.type),
        is_actionable: isNotificationActionable(baseRow?.type),
        target,
        actions
      };
    }));
  }

  return {
    notificationTypeInventory: Object.keys(NOTIFICATION_CATEGORY_MAP),
    getNotificationCategory,
    getNotificationPriority,
    ensureNotificationIndexes,
    buildNotificationSortBucketSql,
    normalizeNotificationSortMode,
    buildNotificationOrderSql,
    parseNotificationCursor,
    buildNotificationCursor,
    buildNotificationTarget,
    buildNotificationActions,
    enrichNotificationRows
  };
}
