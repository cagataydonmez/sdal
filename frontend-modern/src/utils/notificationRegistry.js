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
  mention_event: 'events',
  event_comment: 'events',
  event_invite: 'events',
  connection_request: 'networking',
  connection_accepted: 'networking',
  mentorship_request: 'networking',
  mentorship_accepted: 'networking',
  teacher_network_linked: 'networking',
  job_application: 'jobs'
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
  mention_event: 'important',
  event_comment: 'important',
  event_invite: 'important',
  connection_request: 'actionable',
  connection_accepted: 'important',
  mentorship_request: 'actionable',
  mentorship_accepted: 'important',
  teacher_network_linked: 'important',
  job_application: 'actionable'
});

const NOTIFICATION_CATEGORY_LABELS = Object.freeze({
  social: 'Sosyal',
  messaging: 'Mesajlar',
  groups: 'Gruplar',
  events: 'Etkinlikler',
  networking: 'Networking',
  jobs: 'İlanlar',
  system: 'Sistem'
});

function buildFallbackTarget(notification) {
  const type = String(notification?.type || '').trim().toLowerCase();
  const entityId = Number(notification?.entity_id || 0);
  const sourceUserId = Number(notification?.source_user_id || 0);
  const notificationId = Number(notification?.id || 0);

  if ((type === 'like' || type === 'comment' || type === 'mention_post') && entityId) {
    return { href: `/new?post=${entityId}&notification=${notificationId}` };
  }
  if ((type === 'mention_event' || type === 'event_comment') && entityId) {
    return { href: `/new/events?event=${entityId}&focus=comments&notification=${notificationId}` };
  }
  if (type === 'event_invite' && entityId) {
    return { href: `/new/events?event=${entityId}&focus=response&notification=${notificationId}` };
  }
  if (type === 'mention_group' && entityId) {
    return { href: `/new/groups/${entityId}?tab=posts&notification=${notificationId}` };
  }
  if (type === 'group_join_request' && entityId) {
    return { href: `/new/groups/${entityId}?tab=requests&notification=${notificationId}` };
  }
  if ((type === 'group_join_approved' || type === 'group_join_rejected') && entityId) {
    return { href: `/new/groups/${entityId}?tab=members&notification=${notificationId}` };
  }
  if (type === 'group_invite' && entityId) {
    return { href: `/new/groups/${entityId}?tab=invite&notification=${notificationId}` };
  }
  if ((type === 'mention_photo' || type === 'photo_comment') && entityId) {
    return { href: `/new/albums/photo/${entityId}?notification=${notificationId}` };
  }
  if (type === 'mention_message' && entityId) {
    return { href: `/new/messages/${entityId}?notification=${notificationId}` };
  }
  if (type === 'follow' && sourceUserId) {
    return { href: `/new/members/${sourceUserId}?notification=${notificationId}&context=follow` };
  }
  if (type === 'connection_request') {
    return { href: `/new/network/hub?section=incoming-connections${entityId ? `&request=${entityId}` : ''}&notification=${notificationId}` };
  }
  if (type === 'connection_accepted') {
    return {
      href: sourceUserId
        ? `/new/members/${sourceUserId}?notification=${notificationId}&context=connection_accepted`
        : `/new/network/hub?section=outgoing-connections&notification=${notificationId}`
    };
  }
  if (type === 'mentorship_request') {
    return { href: `/new/network/hub?section=incoming-mentorship${entityId ? `&request=${entityId}` : ''}&notification=${notificationId}` };
  }
  if (type === 'mentorship_accepted') {
    return {
      href: sourceUserId
        ? `/new/members/${sourceUserId}?notification=${notificationId}&context=mentorship_accepted`
        : `/new/network/hub?section=outgoing-mentorship&notification=${notificationId}`
    };
  }
  if (type === 'teacher_network_linked') {
    return { href: `/new/network/hub?section=teacher-notifications&notification=${notificationId}${entityId ? `&link=${entityId}` : ''}` };
  }
  if (type === 'job_application' && entityId) {
    return { href: `/new/jobs?job=${entityId}&tab=applications&notification=${notificationId}` };
  }
  return { href: notificationId ? `/new?notification=${notificationId}` : '/new' };
}

export function resolveNotificationTarget(notification) {
  if (notification?.target?.href) return notification.target;
  return buildFallbackTarget(notification);
}

export function getNotificationCategory(notification) {
  if (notification?.category) return String(notification.category);
  return NOTIFICATION_CATEGORY_MAP[String(notification?.type || '').trim().toLowerCase()] || 'system';
}

export function getNotificationPriority(notification) {
  if (notification?.priority) return String(notification.priority);
  return NOTIFICATION_PRIORITY_MAP[String(notification?.type || '').trim().toLowerCase()] || 'informational';
}

export function getNotificationCategoryLabel(category) {
  return NOTIFICATION_CATEGORY_LABELS[String(category || '').trim().toLowerCase()] || 'Diğer';
}

export function buildNotificationViewModel(notification) {
  const target = resolveNotificationTarget(notification);
  const category = getNotificationCategory(notification);
  const priority = getNotificationPriority(notification);
  return {
    ...notification,
    target,
    href: target?.href || '/new',
    category,
    priority,
    isActionable: Boolean(notification?.is_actionable || priority === 'actionable' || priority === 'critical'),
    actions: Array.isArray(notification?.actions) ? notification.actions : []
  };
}
