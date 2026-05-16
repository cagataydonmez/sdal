export const ADMIN_PERMISSIONS = Object.freeze({
  ADMIN_ACCESS: 'admin.access',
  USERS_VIEW: 'users.view',
  USERS_MANAGE_ROLE: 'users.manage_role',
  USERS_MANAGE_STATUS: 'users.manage_status',
  MODERATION_VIEW: 'moderation.view',
  MODERATION_MANAGE: 'moderation.manage',
  REQUESTS_VIEW: 'requests.view',
  REQUESTS_MANAGE: 'requests.manage',
  ANNOUNCEMENTS_MANAGE: 'announcements.manage',
  GROUPS_MANAGE: 'groups.manage',
  NOTIFICATIONS_MANAGE: 'notifications.manage',
  AUDIT_VIEW: 'audit.view',
  SETTINGS_MANAGE: 'settings.manage',
  TECHNICAL_MANAGE: 'technical.manage'
});

const ROLE_PERMISSIONS = Object.freeze({
  root: Object.freeze(Object.values(ADMIN_PERMISSIONS)),
  admin: Object.freeze([
    ADMIN_PERMISSIONS.ADMIN_ACCESS,
    ADMIN_PERMISSIONS.USERS_VIEW,
    ADMIN_PERMISSIONS.USERS_MANAGE_ROLE,
    ADMIN_PERMISSIONS.USERS_MANAGE_STATUS,
    ADMIN_PERMISSIONS.MODERATION_VIEW,
    ADMIN_PERMISSIONS.MODERATION_MANAGE,
    ADMIN_PERMISSIONS.REQUESTS_VIEW,
    ADMIN_PERMISSIONS.REQUESTS_MANAGE,
    ADMIN_PERMISSIONS.ANNOUNCEMENTS_MANAGE,
    ADMIN_PERMISSIONS.GROUPS_MANAGE,
    ADMIN_PERMISSIONS.NOTIFICATIONS_MANAGE,
    ADMIN_PERMISSIONS.AUDIT_VIEW,
    ADMIN_PERMISSIONS.SETTINGS_MANAGE
  ]),
  mod: Object.freeze([
    ADMIN_PERMISSIONS.ADMIN_ACCESS,
    ADMIN_PERMISSIONS.MODERATION_VIEW
  ]),
  user: Object.freeze([])
});

const MODERATION_RESOURCE_PERMISSION_MAP = Object.freeze({
  users: [ADMIN_PERMISSIONS.USERS_VIEW],
  posts: [ADMIN_PERMISSIONS.MODERATION_VIEW],
  stories: [ADMIN_PERMISSIONS.MODERATION_VIEW],
  chat: [ADMIN_PERMISSIONS.MODERATION_VIEW],
  messages: [ADMIN_PERMISSIONS.MODERATION_VIEW],
  groups: [ADMIN_PERMISSIONS.MODERATION_VIEW],
  events: [ADMIN_PERMISSIONS.MODERATION_VIEW],
  announcements: [ADMIN_PERMISSIONS.MODERATION_VIEW, ADMIN_PERMISSIONS.ANNOUNCEMENTS_MANAGE],
  requests: [ADMIN_PERMISSIONS.REQUESTS_VIEW],
  filters: [ADMIN_PERMISSIONS.MODERATION_VIEW]
});

function normalizePermissionList(values) {
  return Array.from(new Set((values || []).filter(Boolean))).sort((a, b) => a.localeCompare(b));
}

export function buildEffectiveAdminPermissions({ user, role, moderationPermissionKeys = [] } = {}) {
  const normalizedRole = String(role || user?.role || 'user').trim().toLowerCase();
  const permissions = new Set(ROLE_PERMISSIONS[normalizedRole] || ROLE_PERMISSIONS.user);

  for (const key of moderationPermissionKeys || []) {
    const [resource, action] = String(key || '').split('.');
    for (const mapped of MODERATION_RESOURCE_PERMISSION_MAP[resource] || []) permissions.add(mapped);
    if (['moderate', 'delete', 'update', 'toggle'].includes(action)) {
      permissions.add(ADMIN_PERMISSIONS.MODERATION_MANAGE);
      if (resource === 'requests') permissions.add(ADMIN_PERMISSIONS.REQUESTS_MANAGE);
      if (resource === 'users') permissions.add(ADMIN_PERMISSIONS.USERS_MANAGE_STATUS);
      if (resource === 'groups') permissions.add(ADMIN_PERMISSIONS.GROUPS_MANAGE);
    }
  }

  return normalizePermissionList(Array.from(permissions));
}

export function hasAdminPermission(permissions, permission) {
  return Array.isArray(permissions) && permissions.includes(permission);
}

export function buildAdminModules(permissions = []) {
  const can = (permission) => hasAdminPermission(permissions, permission);
  return [
    {
      key: 'home',
      label: 'Komuta Merkezi',
      path: '/admin',
      enabled: can(ADMIN_PERMISSIONS.ADMIN_ACCESS)
    },
    {
      key: 'users',
      label: 'Üyeler',
      path: '/admin/management',
      enabled: can(ADMIN_PERMISSIONS.USERS_VIEW)
    },
    {
      key: 'moderation',
      label: 'Moderasyon',
      path: '/admin/content',
      enabled: can(ADMIN_PERMISSIONS.MODERATION_VIEW) || can(ADMIN_PERMISSIONS.REQUESTS_VIEW)
    },
    {
      key: 'notifications',
      label: 'Bildirimler',
      path: '/admin/notifications',
      enabled: can(ADMIN_PERMISSIONS.NOTIFICATIONS_MANAGE)
    },
    {
      key: 'audit',
      label: 'Denetim',
      path: '/admin/audit',
      enabled: can(ADMIN_PERMISSIONS.AUDIT_VIEW)
    },
    {
      key: 'settings',
      label: 'Ayarlar',
      path: '/admin/modules',
      enabled: can(ADMIN_PERMISSIONS.SETTINGS_MANAGE)
    }
  ].filter((module) => module.enabled);
}

export function assignableRolesForRole(role) {
  const normalizedRole = String(role || 'user').trim().toLowerCase();
  if (normalizedRole === 'root') return ['root', 'admin', 'mod', 'user'];
  if (normalizedRole === 'admin') return ['mod', 'user'];
  return [];
}
