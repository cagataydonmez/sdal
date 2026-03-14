import crypto from 'crypto';
import { promisify } from 'util';

const scryptAsync = promisify(crypto.scrypt);
const PASSWORD_HASH_PREFIX = 'scrypt$';
const E2E_PASSWORD_HASH_PREFIX = 'e2e-sha256$';
const e2eHarnessEnabledForAuth = String(process.env.E2E_HARNESS_ENABLED || '').trim().toLowerCase() === 'true';
const ROLE_PRIORITY = Object.freeze({ user: 0, mod: 1, admin: 2, root: 3 });
const MIN_GRADUATION_YEAR = 1999;
const MAX_GRADUATION_YEAR = 2100;
const TEACHER_COHORT_VALUE = 'teacher';
const WRITE_ALLOWED_WITHOUT_VERIFICATION = Object.freeze([
  '/api/profile',
  '/api/profile/password',
  '/api/profile/photo',
  '/api/new/verified/request',
  '/api/new/verified/proof',
  '/api/new/requests',
  '/api/new/requests/upload'
]);
const ROOT_ALLOWED_PATHS = Object.freeze([
  '/admin/users/',
  '/admin/moderators/',
  '/api/admin/login',
  '/api/admin/logout',
  '/api/auth/logout'
]);

function timingSafeTextEqual(a, b) {
  const left = Buffer.from(String(a || ''), 'utf8');
  const right = Buffer.from(String(b || ''), 'utf8');
  if (!left.length || left.length !== right.length) return false;
  try {
    return crypto.timingSafeEqual(left, right);
  } catch {
    return false;
  }
}

function hashE2EPassword(password) {
  const digest = crypto.createHash('sha256').update(String(password || ''), 'utf8').digest('hex');
  return `${E2E_PASSWORD_HASH_PREFIX}${digest}`;
}

export function createAuthRuntime({
  dbDriver,
  sqlGet,
  sqlAll,
  sqlRun,
  sqlRunAsync,
  moderationActionDefinitions,
  moderationResourceDefinitions,
  moderationPermissionKeySet
}) {
  function toDbBooleanParam(value) {
    const bool = value === true || Number(value) === 1 || ['1', 'true', 'evet', 'yes'].includes(String(value || '').trim().toLowerCase());
    return dbDriver === 'postgres' ? bool : (bool ? 1 : 0);
  }

  function normalizeRole(value) {
    const role = String(value || '').trim().toLowerCase();
    return ROLE_PRIORITY[role] !== undefined ? role : 'user';
  }

  function roleAtLeast(role, minRole) {
    return (ROLE_PRIORITY[normalizeRole(role)] || 0) >= (ROLE_PRIORITY[normalizeRole(minRole)] || 0);
  }

  function getUserRole(user) {
    const explicit = normalizeRole(user?.role);
    if (explicit !== 'user') return explicit;
    if (Number(user?.admin || 0) === 1) return 'admin';
    return 'user';
  }

  function hasAdminRole(user) {
    return roleAtLeast(getUserRole(user), 'admin');
  }

  function isVerifiedMember(user) {
    if (!user) return false;
    if (Number(user.verified || 0) === 1) return true;
    const status = String(user.verification_status || '').trim().toLowerCase();
    return status === 'approved' || status === 'verified';
  }

  function buildModeratorPermissionMap(userId) {
    const map = new Map();
    if (!userId) return map;
    const rows = sqlAll('SELECT permission_key, enabled FROM moderator_permissions WHERE user_id = ?', [userId]) || [];
    for (const row of rows) {
      const key = String(row.permission_key || '').trim();
      if (!key) continue;
      map.set(key, Number(row.enabled || 0) === 1);
    }
    return map;
  }

  function getModeratorPermissionSummary(userId) {
    const map = buildModeratorPermissionMap(userId);
    const assignedKeys = [];
    for (const [key, enabled] of map.entries()) {
      if (enabled && moderationPermissionKeySet.has(key)) assignedKeys.push(key);
    }
    return {
      assignedKeys: assignedKeys.sort((a, b) => a.localeCompare(b)),
      permissionMap: Object.fromEntries(Array.from(map.entries())),
      resources: moderationResourceDefinitions.map((resource) => ({
        ...resource,
        permissions: moderationActionDefinitions.map((action) => {
          const key = `${resource.key}.${action.key}`;
          return {
            key,
            enabled: map.get(key) === true,
            actionKey: action.key,
            actionLabel: action.label,
            description: action.description
          };
        })
      }))
    };
  }

  function replaceModeratorPermissions(userId, permissionKeys = [], actorId = null) {
    if (!userId) return;
    const normalized = new Set(
      (Array.isArray(permissionKeys) ? permissionKeys : [])
        .map((item) => String(item || '').trim())
        .filter((key) => moderationPermissionKeySet.has(key))
    );
    const now = new Date().toISOString();
    sqlRun('DELETE FROM moderator_permissions WHERE user_id = ?', [userId]);
    for (const permissionKey of moderationPermissionKeySet) {
      sqlRun(
        `INSERT INTO moderator_permissions (user_id, permission_key, enabled, created_by, updated_by, created_at, updated_at)
         VALUES (?, ?, ?, ?, ?, ?, ?)`,
        [userId, permissionKey, toDbBooleanParam(normalized.has(permissionKey)), actorId || userId, actorId || userId, now, now]
      );
    }
  }

  async function replaceModeratorPermissionsAsync(userId, permissionKeys = [], actorId = null) {
    if (!userId) return;
    const normalized = new Set(
      (Array.isArray(permissionKeys) ? permissionKeys : [])
        .map((item) => String(item || '').trim())
        .filter((key) => moderationPermissionKeySet.has(key))
    );
    const now = new Date().toISOString();
    await sqlRunAsync('DELETE FROM moderator_permissions WHERE user_id = ?', [userId]);
    for (const permissionKey of moderationPermissionKeySet) {
      await sqlRunAsync(
        `INSERT INTO moderator_permissions (user_id, permission_key, enabled, created_by, updated_by, created_at, updated_at)
         VALUES (?, ?, ?, ?, ?, ?, ?)`,
        [userId, permissionKey, toDbBooleanParam(normalized.has(permissionKey)), actorId || userId, actorId || userId, now, now]
      );
    }
  }

  function userHasModerationPermission(user, permissionKey) {
    if (!permissionKey || !moderationPermissionKeySet.has(permissionKey)) return false;
    const role = getUserRole(user);
    if (role === 'root' || role === 'admin') return true;
    if (role !== 'mod' || !user?.id) return false;
    const row = sqlGet('SELECT enabled FROM moderator_permissions WHERE user_id = ? AND permission_key = ? LIMIT 1', [user.id, permissionKey]);
    return Number(row?.enabled || 0) === 1;
  }

  function hasAdminSession(req, user = null) {
    const targetUser = user || getCurrentUser(req);
    return hasAdminRole(targetUser);
  }

  function ensureVerifiedSocialHubMember(req, res) {
    const user = getCurrentUser(req);
    if (hasAdminSession(req, user)) return true;
    if (isVerifiedMember(user)) return true;
    res.status(403).json({
      code: 'VERIFICATION_REQUIRED',
      message: 'Bu özelliği kullanmak için profil doğrulaması gerekli.'
    });
    return false;
  }

  async function hashPassword(password) {
    const salt = crypto.randomBytes(16).toString('hex');
    const derived = await scryptAsync(String(password), salt, 64);
    return `${PASSWORD_HASH_PREFIX}${salt}$${Buffer.from(derived).toString('hex')}`;
  }

  async function verifyPassword(stored, candidate) {
    const storedText = String(stored || '');
    const rawCandidate = String(candidate || '');
    if (storedText.startsWith(E2E_PASSWORD_HASH_PREFIX)) {
      if (!e2eHarnessEnabledForAuth) return { ok: false, needsRehash: false };
      const expected = storedText.slice(E2E_PASSWORD_HASH_PREFIX.length);
      const actual = crypto.createHash('sha256').update(rawCandidate, 'utf8').digest('hex');
      return { ok: timingSafeTextEqual(expected, actual), needsRehash: false };
    }
    if (!storedText.startsWith(PASSWORD_HASH_PREFIX)) {
      return { ok: storedText === rawCandidate, needsRehash: storedText === rawCandidate };
    }
    const parts = storedText.split('$');
    if (parts.length !== 3) return { ok: false, needsRehash: false };
    const [, salt, expectedHex] = parts;
    const derived = await scryptAsync(rawCandidate, salt, 64);
    const expected = Buffer.from(expectedHex, 'hex');
    const actual = Buffer.from(derived);
    if (expected.length !== actual.length) return { ok: false, needsRehash: false };
    return { ok: crypto.timingSafeEqual(expected, actual), needsRehash: false };
  }

  function isRootUser(user) {
    return getUserRole(user) === 'root';
  }

  function selectCompatUserById(userId) {
    if (!userId) return null;
    if (dbDriver !== 'postgres') {
      return sqlGet('SELECT * FROM uyeler WHERE id = ?', [userId]);
    }
    return sqlGet(
      `SELECT
         id,
         username AS kadi,
         password_hash AS sifre,
         email,
         first_name AS isim,
         last_name AS soyisim,
         COALESCE(avatar_path, 'yok') AS resim,
         CASE WHEN COALESCE(is_active, true) THEN 1 ELSE 0 END AS aktiv,
         CASE WHEN COALESCE(is_banned, false) THEN 1 ELSE 0 END AS yasak,
         CASE WHEN COALESCE(is_profile_initialized, true) THEN 1 ELSE 0 END AS ilkbd,
         CASE WHEN COALESCE(legacy_admin_flag, false) THEN 1 ELSE 0 END AS admin,
         CASE WHEN COALESCE(is_verified, false) THEN 1 ELSE 0 END AS verified,
         role,
         oauth_provider,
         oauth_subject,
         CASE WHEN COALESCE(oauth_email_verified, false) THEN 1 ELSE 0 END AS oauth_email_verified,
         graduation_year AS mezuniyetyili,
         privacy_consent_at AS kvkk_consent_at,
         directory_consent_at,
         CASE WHEN COALESCE(is_online, false) THEN 1 ELSE 0 END AS online,
         profile_view_count AS hit,
         last_activity_date AS sonislemtarih,
         last_activity_time AS sonislemsaat,
         last_seen_at AS sontarih,
         previous_last_seen_at AS oncekisontarih,
         last_ip AS sonip,
         CASE WHEN COALESCE(is_album_admin, false) THEN 1 ELSE 0 END AS albumadmin,
         quick_access_ids_json AS hizliliste
       FROM users
       WHERE id = ?`,
      [userId]
    );
  }

  function getCurrentUser(req) {
    if (!req.session.userId) return null;
    const cacheKey = String(req.session.userId);
    if (req._currentUserCache && req._currentUserCache.key === cacheKey) {
      return req._currentUserCache.value;
    }
    const user = selectCompatUserById(req.session.userId);
    req._currentUserCache = { key: cacheKey, value: user };
    return user;
  }

  function normalizeCohortValue(value) {
    const raw = String(value || '').trim().toLowerCase();
    if (raw === 'teacher' || raw === 'ogretmen') return TEACHER_COHORT_VALUE;
    return String(value || '').trim();
  }

  function parseGraduationYear(value) {
    const year = parseInt(String(value || '').trim(), 10);
    return Number.isFinite(year) ? year : NaN;
  }

  function hasValidGraduationYear(value) {
    if (normalizeCohortValue(value) === TEACHER_COHORT_VALUE) return true;
    const year = parseGraduationYear(value);
    return Number.isFinite(year) && year >= MIN_GRADUATION_YEAR && year <= MAX_GRADUATION_YEAR;
  }

  function hasKvkkConsent(user) {
    return Boolean(user?.kvkk_consent_at);
  }

  function hasDirectoryConsent(user) {
    return Boolean(user?.directory_consent_at);
  }

  function isOAuthProfileIncomplete(user) {
    const oauthProvider = String(user?.oauth_provider || '').trim();
    if (!oauthProvider) return false;
    return !hasValidGraduationYear(user?.mezuniyetyili) || !hasKvkkConsent(user) || !hasDirectoryConsent(user);
  }

  async function requireAuth(req, res, next) {
    if (!req.session.userId) return res.status(401).send('Login required');
    const user = getCurrentUser(req);
    if (!user) return res.status(401).send('Login required');
    req.authUser = user;
    const writeMethod = new Set(['POST', 'PUT', 'PATCH', 'DELETE']).has(String(req.method || '').toUpperCase());
    if (writeMethod) {
      const isVerified = isVerifiedMember(req.authUser);
      const canWriteWithoutVerification = WRITE_ALLOWED_WITHOUT_VERIFICATION.some((item) => req.path === item || req.path.startsWith(`${item}/`));
      if (!isVerified && !canWriteWithoutVerification) {
        return res.status(403).json({
          error: 'VERIFICATION_REQUIRED',
          message: 'Yazma işlemleri için önce profilinizi doğrulamanız gerekiyor.',
          verificationUrl: '/new/profile/verification'
        });
      }
    }
    if (req.path.startsWith('/api/new/') && isOAuthProfileIncomplete(req.authUser)) {
      return res.status(403).json({ error: 'PROFILE_INCOMPLETE', message: 'Mezuniyet yılını (en az 1999) girmeden bu özelliği kullanamazsın.' });
    }
    if (isRootUser(user) && writeMethod) {
      const allowed = ROOT_ALLOWED_PATHS.some((prefix) => req.path.startsWith(prefix));
      if (!allowed) return res.status(403).send('ROOT hesabı normal kullanıcı işlemleri yapamaz.');
    }
    return next();
  }

  function requireRole(role) {
    return (req, res, next) => {
      const user = req.authUser || getCurrentUser(req);
      if (!user) return res.status(401).send('Login required');
      if (!roleAtLeast(getUserRole(user), role)) return res.status(403).send('Yetki yok.');
      req.authUser = user;
      return next();
    };
  }

  function requireScopedModeration(graduationYearSelector = (req) => req.body?.graduationYear ?? req.params?.graduationYear ?? req.query?.graduationYear) {
    return (req, res, next) => {
      const user = req.authUser || getCurrentUser(req);
      if (!user) return res.status(401).send('Login required');
      const role = getUserRole(user);
      if (role === 'root' || role === 'admin') return next();
      if (role !== 'mod') return res.status(403).send('Moderasyon yetkisi gerekli.');
      const graduationYear = parseGraduationYear(typeof graduationYearSelector === 'function' ? graduationYearSelector(req) : graduationYearSelector);
      if (!Number.isFinite(graduationYear)) return res.status(400).send('Geçerli mezuniyet yılı gerekli.');
      const scope = sqlGet('SELECT id FROM moderator_scopes WHERE user_id = ? AND scope_type = ? AND scope_value = ?', [user.id, 'graduation_year', String(graduationYear)]);
      if (!scope) return res.status(403).send('Bu mezuniyet yılı için moderasyon yetkin yok.');
      req.authUser = user;
      return next();
    };
  }

  function requireModerationPermission(permissionKey) {
    return (req, res, next) => {
      const user = req.authUser || getCurrentUser(req);
      if (!user) return res.status(401).send('Login required');
      if (!userHasModerationPermission(user, permissionKey)) return res.status(403).send('Bu işlem için moderasyon yetkin yok.');
      req.authUser = user;
      return next();
    };
  }

  function getModeratorScopedGraduationYears(userId) {
    if (!userId) return [];
    const rows = sqlAll(
      `SELECT DISTINCT scope_value
       FROM moderator_scopes
       WHERE user_id = ? AND scope_type = 'graduation_year'
       ORDER BY scope_value ASC`,
      [userId]
    ) || [];
    return rows
      .map((row) => String(row.scope_value || '').trim())
      .filter((value) => /^\d{4}$/.test(value));
  }

  function getModerationScopeContext(user) {
    const role = getUserRole(user);
    if (role === 'root' || role === 'admin') {
      return { role, isScopedModerator: false, years: [] };
    }
    if (role !== 'mod') {
      return { role, isScopedModerator: false, years: [] };
    }
    const years = getModeratorScopedGraduationYears(user?.id);
    return { role, isScopedModerator: true, years };
  }

  function applyModerationScopeFilter(context, params, graduationYearColumnSql) {
    if (!context?.isScopedModerator) return '';
    const years = Array.isArray(context.years) ? context.years : [];
    if (!years.length) return ' AND 1 = 0';
    const placeholders = years.map(() => '?').join(', ');
    params.push(...years);
    return ` AND CAST(COALESCE(${graduationYearColumnSql}, '') AS TEXT) IN (${placeholders})`;
  }

  function ensureCanModerateTargetUser(req, res, targetUserId, { notFoundMessage = 'Kullanıcı bulunamadı.' } = {}) {
    const actor = req.authUser || getCurrentUser(req);
    if (!actor) {
      res.status(401).send('Login required');
      return null;
    }
    const context = getModerationScopeContext(actor);
    const target = sqlGet('SELECT id, mezuniyetyili, role FROM uyeler WHERE id = ?', [targetUserId]);
    if (!target) {
      res.status(404).send(notFoundMessage);
      return null;
    }
    if (normalizeRole(target.role) === 'root') {
      res.status(403).send('Root kullanıcıya bu işlem uygulanamaz.');
      return null;
    }
    if (!context.isScopedModerator) return target;
    const targetYear = String(target.mezuniyetyili || '').trim();
    if (!targetYear || !context.years.includes(targetYear)) {
      res.status(403).send('Bu kullanıcı mezuniyet yılı kapsamınız dışında.');
      return null;
    }
    return target;
  }

  return {
    hashE2EPassword,
    normalizeRole,
    roleAtLeast,
    getUserRole,
    hasAdminRole,
    isVerifiedMember,
    ensureVerifiedSocialHubMember,
    buildModeratorPermissionMap,
    getModeratorPermissionSummary,
    replaceModeratorPermissions,
    replaceModeratorPermissionsAsync,
    userHasModerationPermission,
    requireModerationPermission,
    hasAdminSession,
    hashPassword,
    verifyPassword,
    isRootUser,
    selectCompatUserById,
    getCurrentUser,
    MIN_GRADUATION_YEAR,
    MAX_GRADUATION_YEAR,
    TEACHER_COHORT_VALUE,
    normalizeCohortValue,
    parseGraduationYear,
    hasValidGraduationYear,
    hasKvkkConsent,
    hasDirectoryConsent,
    isOAuthProfileIncomplete,
    requireAuth,
    requireRole,
    requireScopedModeration,
    getModeratorScopedGraduationYears,
    getModerationScopeContext,
    applyModerationScopeFilter,
    ensureCanModerateTargetUser
  };
}
