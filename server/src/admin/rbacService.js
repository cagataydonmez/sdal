export const ROOT_ADMIN_USERNAME = 'cagatay';

export const DEFAULT_PERMISSION_GROUPS = Object.freeze([
  { name: 'admin', description: 'Full admin-panel access except root-only destructive operations.', isSystem: true },
  { name: 'mod', description: 'Moderation-focused access for member and content review workflows.', isSystem: true },
  { name: 'user', description: 'Default site member group with no admin-panel permissions.', isSystem: true }
]);

export const DEFAULT_PERMISSIONS = Object.freeze([
  { key: 'admin_panel', label: 'Admin panel', description: 'Open admin and moderation workspaces.' },
  { key: 'users', label: 'Users', description: 'Member profiles, account status, roles and graduation data.' },
  { key: 'posts', label: 'Posts', description: 'Feed posts and comments.' },
  { key: 'stories', label: 'Stories', description: 'Story content.' },
  { key: 'groups', label: 'Groups', description: 'Community groups and memberships.' },
  { key: 'reports', label: 'Reports and requests', description: 'Member requests, verification queues and appeals.' },
  { key: 'messages', label: 'Messages', description: 'Chat, messenger and private-message moderation.' },
  { key: 'events', label: 'Events', description: 'Events and event approval workflows.' },
  { key: 'announcements', label: 'Announcements', description: 'Announcements and publishing workflows.' },
  { key: 'albums', label: 'Albums', description: 'Album categories, photos and related moderation.' },
  { key: 'communication', label: 'Communication', description: 'Broadcast notifications and admin communication operations.' },
  { key: 'settings', label: 'Settings', description: 'Site controls, modules, languages and operational settings.' },
  { key: 'database', label: 'Database', description: 'Database backup, restore and inspection tools.' },
  { key: 'logs', label: 'Logs', description: 'Application and legacy log views.' },
  { key: 'security', label: 'Security', description: 'Security status and validation monitoring.' },
  { key: 'experiments', label: 'Experiments', description: 'A/B tests, engagement scoring and dashboards.' },
  { key: 'factory_reset', label: 'Factory reset', description: 'Root-only destructive full app reset.' }
]);

const ADMIN_WRITE_KEYS = new Set(DEFAULT_PERMISSIONS.map((item) => item.key).filter((key) => key !== 'factory_reset'));
const MOD_WRITE_KEYS = new Set(['posts', 'stories', 'groups', 'reports', 'messages', 'events', 'announcements', 'albums']);
const MOD_READ_KEYS = new Set(['admin_panel', 'users', 'posts', 'stories', 'groups', 'reports', 'messages', 'events', 'announcements', 'albums', 'logs']);

function normalizeText(value) {
  return String(value || '').trim();
}

function normalizeKey(value) {
  return normalizeText(value).toLowerCase().replace(/[^a-z0-9_.-]+/g, '_').replace(/^_+|_+$/g, '');
}

function toDbBooleanParam(dbDriver, value) {
  const bool = value === true || Number(value) === 1 || ['1', 'true', 'yes', 'evet'].includes(String(value || '').trim().toLowerCase());
  return dbDriver === 'postgres' ? bool : (bool ? 1 : 0);
}

function rowBool(value) {
  return value === true || Number(value || 0) === 1 || ['1', 'true', 'yes', 'evet'].includes(String(value || '').trim().toLowerCase());
}

function userTableName(dbDriver) {
  return dbDriver === 'postgres' ? 'users' : 'uyeler';
}

function userNameColumn(dbDriver) {
  return dbDriver === 'postgres' ? 'username' : 'kadi';
}

function userRoleColumn() {
  return 'role';
}

function userAdminColumn(dbDriver) {
  return dbDriver === 'postgres' ? 'legacy_admin_flag' : 'admin';
}

function userActiveColumn(dbDriver) {
  return dbDriver === 'postgres' ? 'is_active' : 'aktiv';
}

function userVerifiedColumn(dbDriver) {
  return dbDriver === 'postgres' ? 'is_verified' : 'verified';
}

function userUpdatedColumn(dbDriver) {
  return dbDriver === 'postgres' ? 'updated_at' : null;
}

function permissionPatchForGroup(groupName) {
  const name = normalizeKey(groupName);
  if (name === 'admin') {
    return DEFAULT_PERMISSIONS.map((permission) => ({
      key: permission.key,
      canRead: permission.key !== 'factory_reset',
      canWrite: ADMIN_WRITE_KEYS.has(permission.key)
    }));
  }
  if (name === 'mod') {
    return DEFAULT_PERMISSIONS.map((permission) => ({
      key: permission.key,
      canRead: MOD_READ_KEYS.has(permission.key),
      canWrite: MOD_WRITE_KEYS.has(permission.key)
    }));
  }
  return DEFAULT_PERMISSIONS.map((permission) => ({
    key: permission.key,
    canRead: false,
    canWrite: false
  }));
}

export function isRootAdmin(user) {
  const username = normalizeText(user?.username || user?.kadi).toLowerCase();
  const role = normalizeText(user?.role).toLowerCase();
  return username === ROOT_ADMIN_USERNAME && role === 'root';
}

export function createRbacService({ dbDriver, sqlGetAsync, sqlAllAsync, sqlRunAsync }) {
  async function ensureSchema() {
    if (dbDriver === 'postgres') {
      await sqlRunAsync(`
        CREATE TABLE IF NOT EXISTS permission_groups (
          id BIGINT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
          name TEXT NOT NULL UNIQUE,
          description TEXT,
          is_system BOOLEAN NOT NULL DEFAULT FALSE,
          created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
          updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
        )
      `);
      await sqlRunAsync(`
        CREATE TABLE IF NOT EXISTS permissions (
          id BIGINT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
          permission_key TEXT NOT NULL UNIQUE,
          label TEXT NOT NULL,
          description TEXT,
          created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
          updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
        )
      `);
      await sqlRunAsync(`
        CREATE TABLE IF NOT EXISTS group_permissions (
          group_id BIGINT NOT NULL REFERENCES permission_groups(id) ON DELETE CASCADE,
          permission_id BIGINT NOT NULL REFERENCES permissions(id) ON DELETE CASCADE,
          can_read BOOLEAN NOT NULL DEFAULT FALSE,
          can_write BOOLEAN NOT NULL DEFAULT FALSE,
          created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
          updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
          PRIMARY KEY (group_id, permission_id)
        )
      `);
      await sqlRunAsync(`
        CREATE TABLE IF NOT EXISTS user_permission_groups (
          user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
          group_id BIGINT NOT NULL REFERENCES permission_groups(id) ON DELETE RESTRICT,
          assigned_by BIGINT REFERENCES users(id) ON DELETE SET NULL,
          created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
          updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
          PRIMARY KEY (user_id)
        )
      `);
      return;
    }

    await sqlRunAsync(`
      CREATE TABLE IF NOT EXISTS permission_groups (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        description TEXT,
        is_system INTEGER NOT NULL DEFAULT 0,
        created_at TEXT,
        updated_at TEXT
      )
    `);
    await sqlRunAsync(`
      CREATE TABLE IF NOT EXISTS permissions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        permission_key TEXT NOT NULL UNIQUE,
        label TEXT NOT NULL,
        description TEXT,
        created_at TEXT,
        updated_at TEXT
      )
    `);
    await sqlRunAsync(`
      CREATE TABLE IF NOT EXISTS group_permissions (
        group_id INTEGER NOT NULL,
        permission_id INTEGER NOT NULL,
        can_read INTEGER NOT NULL DEFAULT 0,
        can_write INTEGER NOT NULL DEFAULT 0,
        created_at TEXT,
        updated_at TEXT,
        PRIMARY KEY (group_id, permission_id)
      )
    `);
    await sqlRunAsync(`
      CREATE TABLE IF NOT EXISTS user_permission_groups (
        user_id INTEGER NOT NULL PRIMARY KEY,
        group_id INTEGER NOT NULL,
        assigned_by INTEGER,
        created_at TEXT,
        updated_at TEXT
      )
    `);
  }

  async function upsertPermission(permission) {
    const now = new Date().toISOString();
    if (dbDriver === 'postgres') {
      await sqlRunAsync(
        `INSERT INTO permissions (permission_key, label, description, created_at, updated_at)
         VALUES (?, ?, ?, ?, ?)
         ON CONFLICT (permission_key) DO UPDATE SET
           label = excluded.label,
           description = excluded.description,
           updated_at = excluded.updated_at`,
        [permission.key, permission.label, permission.description, now, now]
      );
      return;
    }
    await sqlRunAsync(
      `INSERT INTO permissions (permission_key, label, description, created_at, updated_at)
       VALUES (?, ?, ?, ?, ?)
       ON CONFLICT(permission_key) DO UPDATE SET
         label = excluded.label,
         description = excluded.description,
         updated_at = excluded.updated_at`,
      [permission.key, permission.label, permission.description, now, now]
    );
  }

  async function upsertGroup(group) {
    const now = new Date().toISOString();
    const name = normalizeKey(group.name);
    const isSystem = toDbBooleanParam(dbDriver, group.isSystem);
    if (dbDriver === 'postgres') {
      await sqlRunAsync(
        `INSERT INTO permission_groups (name, description, is_system, created_at, updated_at)
         VALUES (?, ?, ?, ?, ?)
         ON CONFLICT (name) DO UPDATE SET
           description = excluded.description,
           is_system = excluded.is_system,
           updated_at = excluded.updated_at`,
        [name, group.description || '', isSystem, now, now]
      );
      return sqlGetAsync('SELECT * FROM permission_groups WHERE name = ?', [name]);
    }
    await sqlRunAsync(
      `INSERT INTO permission_groups (name, description, is_system, created_at, updated_at)
       VALUES (?, ?, ?, ?, ?)
       ON CONFLICT(name) DO UPDATE SET
         description = excluded.description,
         is_system = excluded.is_system,
         updated_at = excluded.updated_at`,
      [name, group.description || '', isSystem, now, now]
    );
    return sqlGetAsync('SELECT * FROM permission_groups WHERE name = ?', [name]);
  }

  async function replaceGroupPermissions(groupId, permissionPatch) {
    const normalized = new Map();
    for (const item of Array.isArray(permissionPatch) ? permissionPatch : []) {
      const key = normalizeKey(item.key || item.permissionKey || item.permission_key);
      if (!key) continue;
      normalized.set(key, {
        canRead: Boolean(item.canRead ?? item.read ?? item.can_read),
        canWrite: Boolean(item.canWrite ?? item.write ?? item.can_write)
      });
    }
    const now = new Date().toISOString();
    await sqlRunAsync('DELETE FROM group_permissions WHERE group_id = ?', [groupId]);
    const permissions = await listPermissions();
    for (const permission of permissions) {
      const patch = normalized.get(permission.key) || { canRead: false, canWrite: false };
      await sqlRunAsync(
        `INSERT INTO group_permissions (group_id, permission_id, can_read, can_write, created_at, updated_at)
         VALUES (?, ?, ?, ?, ?, ?)`,
        [
          groupId,
          permission.id,
          toDbBooleanParam(dbDriver, patch.canRead || patch.canWrite),
          toDbBooleanParam(dbDriver, patch.canWrite),
          now,
          now
        ]
      );
    }
  }

  async function seedDefaults() {
    await ensureSchema();
    for (const permission of DEFAULT_PERMISSIONS) await upsertPermission(permission);
    for (const group of DEFAULT_PERMISSION_GROUPS) {
      const row = await upsertGroup(group);
      await replaceGroupPermissions(row.id, permissionPatchForGroup(group.name));
    }
  }

  async function listPermissions() {
    const rows = await sqlAllAsync(
      `SELECT id, permission_key, label, description
       FROM permissions
       ORDER BY permission_key ASC`
    );
    return (rows || []).map((row) => ({
      id: Number(row.id),
      key: String(row.permission_key || ''),
      label: String(row.label || row.permission_key || ''),
      description: String(row.description || '')
    }));
  }

  async function listGroups() {
    const groups = await sqlAllAsync(
      `SELECT id, name, description, is_system
       FROM permission_groups
       ORDER BY CASE name WHEN 'admin' THEN 0 WHEN 'mod' THEN 1 WHEN 'user' THEN 2 ELSE 3 END, name ASC`
    );
    const rows = await sqlAllAsync(
      `SELECT pg.id AS group_id, p.permission_key, gp.can_read, gp.can_write
       FROM permission_groups pg
       LEFT JOIN group_permissions gp ON gp.group_id = pg.id
       LEFT JOIN permissions p ON p.id = gp.permission_id
       ORDER BY pg.name ASC, p.permission_key ASC`
    );
    const byGroup = new Map();
    for (const row of rows || []) {
      if (!row.permission_key) continue;
      const arr = byGroup.get(Number(row.group_id)) || [];
      arr.push({
        key: String(row.permission_key),
        canRead: rowBool(row.can_read),
        canWrite: rowBool(row.can_write)
      });
      byGroup.set(Number(row.group_id), arr);
    }
    return (groups || []).map((group) => ({
      id: Number(group.id),
      name: String(group.name || ''),
      description: String(group.description || ''),
      isSystem: rowBool(group.is_system),
      permissions: byGroup.get(Number(group.id)) || []
    }));
  }

  async function createGroup({ name, description = '', permissions = [] }) {
    const groupName = normalizeKey(name);
    if (!groupName) {
      const err = new Error('Permission group name is required.');
      err.statusCode = 400;
      throw err;
    }
    const group = await upsertGroup({ name: groupName, description, isSystem: false });
    await replaceGroupPermissions(group.id, permissions);
    return group;
  }

  async function updateGroup(id, { name, description = '', permissions = [] }) {
    const group = await sqlGetAsync('SELECT * FROM permission_groups WHERE id = ?', [id]);
    if (!group) {
      const err = new Error('Permission group not found.');
      err.statusCode = 404;
      throw err;
    }
    const currentName = normalizeKey(group.name);
    const nextName = normalizeKey(name || group.name);
    if (['admin', 'mod', 'user'].includes(currentName) && nextName !== currentName) {
      const err = new Error('Default permission groups cannot be renamed.');
      err.statusCode = 400;
      throw err;
    }
    await sqlRunAsync(
      'UPDATE permission_groups SET name = ?, description = ?, updated_at = ? WHERE id = ?',
      [nextName, String(description || ''), new Date().toISOString(), id]
    );
    await replaceGroupPermissions(id, permissions);
  }

  async function deleteGroup(id) {
    const group = await sqlGetAsync('SELECT * FROM permission_groups WHERE id = ?', [id]);
    if (!group) return;
    if (['admin', 'mod', 'user'].includes(normalizeKey(group.name)) || rowBool(group.is_system)) {
      const err = new Error('Default permission groups cannot be deleted.');
      err.statusCode = 400;
      throw err;
    }
    const assigned = await sqlGetAsync('SELECT user_id FROM user_permission_groups WHERE group_id = ? LIMIT 1', [id]);
    if (assigned) {
      const err = new Error('Permission group is assigned to users.');
      err.statusCode = 409;
      throw err;
    }
    await sqlRunAsync('DELETE FROM permission_groups WHERE id = ?', [id]);
  }

  async function defaultGroupId() {
    const row = await sqlGetAsync("SELECT id FROM permission_groups WHERE name = 'user' LIMIT 1");
    return row?.id || null;
  }

  async function assignDefaultUserGroup(userId, assignedBy = null) {
    const groupId = await defaultGroupId();
    if (!groupId || !userId) return;
    await assignUserGroup({ userId, groupId, assignedBy, forceUserRole: false });
  }

  async function assignUserGroup({ userId, groupId, assignedBy = null, forceUserRole = true }) {
    const group = await sqlGetAsync('SELECT id, name FROM permission_groups WHERE id = ?', [groupId]);
    if (!group) {
      const err = new Error('Permission group not found.');
      err.statusCode = 404;
      throw err;
    }
    const table = userTableName(dbDriver);
    const nameColumn = userNameColumn(dbDriver);
    const user = await sqlGetAsync(`SELECT id, ${nameColumn} AS username, role FROM ${table} WHERE id = ?`, [userId]);
    if (!user) {
      const err = new Error('User not found.');
      err.statusCode = 404;
      throw err;
    }
    if (normalizeText(user.username).toLowerCase() === ROOT_ADMIN_USERNAME) {
      const err = new Error('Root admin cannot be assigned to a lower permission group.');
      err.statusCode = 400;
      throw err;
    }
    const now = new Date().toISOString();
    if (dbDriver === 'postgres') {
      await sqlRunAsync(
        `INSERT INTO user_permission_groups (user_id, group_id, assigned_by, created_at, updated_at)
         VALUES (?, ?, ?, ?, ?)
         ON CONFLICT (user_id) DO UPDATE SET
           group_id = excluded.group_id,
           assigned_by = excluded.assigned_by,
           updated_at = excluded.updated_at`,
        [userId, groupId, assignedBy, now, now]
      );
    } else {
      await sqlRunAsync(
        `INSERT INTO user_permission_groups (user_id, group_id, assigned_by, created_at, updated_at)
         VALUES (?, ?, ?, ?, ?)
         ON CONFLICT(user_id) DO UPDATE SET
           group_id = excluded.group_id,
           assigned_by = excluded.assigned_by,
           updated_at = excluded.updated_at`,
        [userId, groupId, assignedBy, now, now]
      );
    }
    if (forceUserRole) {
      const groupName = normalizeKey(group.name);
      const nextRole = ['admin', 'mod'].includes(groupName) ? groupName : 'user';
      const adminValue = toDbBooleanParam(dbDriver, nextRole === 'admin');
      const updatedColumn = userUpdatedColumn(dbDriver);
      const updatedSql = updatedColumn ? `, ${updatedColumn} = ?` : '';
      const params = updatedColumn ? [nextRole, adminValue, now, userId] : [nextRole, adminValue, userId];
      await sqlRunAsync(
        `UPDATE ${table} SET ${userRoleColumn()} = ?, ${userAdminColumn(dbDriver)} = ?${updatedSql} WHERE id = ?`,
        params
      );
    }
  }

  async function listUsersWithGroups({ q = '', page = 1, limit = 50 } = {}) {
    const safePage = Math.max(Number.parseInt(String(page || '1'), 10) || 1, 1);
    const safeLimit = Math.min(Math.max(Number.parseInt(String(limit || '50'), 10) || 50, 1), 100);
    const offset = (safePage - 1) * safeLimit;
    const table = userTableName(dbDriver);
    const username = userNameColumn(dbDriver);
    const active = userActiveColumn(dbDriver);
    const verified = userVerifiedColumn(dbDriver);
    const first = dbDriver === 'postgres' ? 'first_name' : 'isim';
    const last = dbDriver === 'postgres' ? 'last_name' : 'soyisim';
    const email = 'email';
    const where = [];
    const params = [];
    const search = normalizeText(q);
    if (search) {
      where.push(`(LOWER(${username}) LIKE LOWER(?) OR LOWER(COALESCE(${email}, '')) LIKE LOWER(?) OR LOWER(COALESCE(${first}, '')) LIKE LOWER(?) OR LOWER(COALESCE(${last}, '')) LIKE LOWER(?))`);
      const like = `%${search}%`;
      params.push(like, like, like, like);
    }
    const whereSql = where.length ? `WHERE ${where.join(' AND ')}` : '';
    const rows = await sqlAllAsync(
      `SELECT u.id, u.${username} AS username, u.${first} AS first_name, u.${last} AS last_name,
              u.email, u.role, u.${active} AS is_active, u.${verified} AS is_verified,
              pg.id AS group_id, pg.name AS group_name
       FROM ${table} u
       LEFT JOIN user_permission_groups upg ON upg.user_id = u.id
       LEFT JOIN permission_groups pg ON pg.id = upg.group_id
       ${whereSql}
       ORDER BY LOWER(u.${username}) ASC
       LIMIT ? OFFSET ?`,
      [...params, safeLimit, offset]
    );
    const total = await sqlGetAsync(`SELECT COUNT(*) AS count FROM ${table} u ${whereSql}`, params);
    return {
      meta: { page: safePage, limit: safeLimit, total: Number(total?.count || total?.COUNT || 0) },
      users: (rows || []).map((row) => ({
        id: Number(row.id),
        username: String(row.username || ''),
        kadi: String(row.username || ''),
        firstName: String(row.first_name || ''),
        lastName: String(row.last_name || ''),
        email: String(row.email || ''),
        role: String(row.role || 'user'),
        isRoot: String(row.username || '').toLowerCase() === ROOT_ADMIN_USERNAME && String(row.role || '').toLowerCase() === 'root',
        isActive: rowBool(row.is_active),
        isVerified: rowBool(row.is_verified),
        group: row.group_id ? { id: Number(row.group_id), name: String(row.group_name || '') } : null
      }))
    };
  }

  async function hasPermission(user, permissionKey, action = 'read') {
    if (!user) return false;
    if (isRootAdmin(user)) return true;
    const key = normalizeKey(permissionKey);
    if (!key) return false;
    const userId = Number(user.id || 0);
    if (!userId) return false;
    const column = String(action || '').toLowerCase() === 'write' ? 'can_write' : 'can_read';
    const row = await sqlGetAsync(
      `SELECT gp.${column} AS allowed
       FROM user_permission_groups upg
       JOIN group_permissions gp ON gp.group_id = upg.group_id
       JOIN permissions p ON p.id = gp.permission_id
       WHERE upg.user_id = ? AND p.permission_key = ?
       LIMIT 1`,
      [userId, key]
    );
    return rowBool(row?.allowed);
  }

  function requireRootAdmin(req, res, next) {
    const user = req.authUser || req.adminUser;
    if (!isRootAdmin(user)) return res.status(403).json({ error: 'ROOT_ADMIN_REQUIRED', message: 'Root admin access required.' });
    return next();
  }

  function requirePermission(permissionKey, action = 'read') {
    return async (req, res, next) => {
      const user = req.authUser || req.adminUser;
      if (!user) return res.status(401).send('Login required');
      if (!(await hasPermission(user, permissionKey, action))) {
        return res.status(403).json({ error: 'PERMISSION_REQUIRED', permissionKey, action });
      }
      return next();
    };
  }

  return {
    ensureSchema,
    seedDefaults,
    listPermissions,
    listGroups,
    createGroup,
    updateGroup,
    deleteGroup,
    assignDefaultUserGroup,
    assignUserGroup,
    listUsersWithGroups,
    hasPermission,
    requirePermission,
    requireRootAdmin,
    replaceGroupPermissions
  };
}
