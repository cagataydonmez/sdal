import path from 'path';
import { randomUUID } from 'crypto';

export function registerAlbumRoutes(app, {
  dbDriver,
  sqlGetAsync,
  sqlAllAsync,
  sqlRunAsync,
  albumUpload,
  processDiskImageUpload,
  loadMediaSettings,
  uploadImagePresets,
  sanitizePlainUserText,
  formatUserText,
  notifyMentions,
  getCurrentUser,
  addNotification,
  normalizeUserId,
  sameUserId,
  logUserActivity = null,
}) {
  const isPostgres = dbDriver === 'postgres';
  const boolValue = (value) => (isPostgres ? !!value : (value ? 1 : 0));
  const categoryTable = isPostgres ? 'album_categories' : 'album_kat';
  const photoTable = isPostgres ? 'album_photos' : 'album_foto';
  const commentTable = isPostgres ? 'album_photo_comments' : 'album_fotoyorum';
  const likeTable = 'album_photo_likes';
  const permissionTable = 'album_category_permissions';
  const editTable = 'album_photo_media_edits';
  const userTable = isPostgres ? 'users' : 'uyeler';
  const photoActiveSql = isPostgres
    ? 'COALESCE(p.is_active, TRUE) IS TRUE'
    : "(COALESCE(CAST(p.aktif AS INTEGER), 0) = 1 OR LOWER(CAST(p.aktif AS TEXT)) IN ('true','evet','yes'))";

  const categorySelect = (alias = 'c') => isPostgres
    ? `${alias}.id,
       ${alias}.name AS title,
       COALESCE(${alias}.description, '') AS description,
       COALESCE(${alias}.created_at::text, '') AS created_at,
       COALESCE(${alias}.last_upload_at::text, '') AS last_upload_at,
       ${alias}.last_uploaded_by_user_id AS last_uploaded_by_user_id,
       COALESCE(${alias}.is_active, TRUE) AS is_active,
       COALESCE(${alias}.visibility_scope, 'public') AS visibility_scope,
       COALESCE(${alias}.cohort_year, '') AS cohort_year,
       COALESCE(${alias}.album_type, 'general') AS album_type,
       ${alias}.owner_user_id AS owner_user_id,
       COALESCE(${alias}.is_system_album, FALSE) AS is_system_album,
       COALESCE(${alias}.cover_file_name, '') AS cover_file_name,
       COALESCE(${alias}.cover_mode, 'latest') AS cover_mode`
    : `${alias}.id,
       ${alias}.kategori AS title,
       COALESCE(${alias}.aciklama, '') AS description,
       COALESCE(${alias}.ilktarih, '') AS created_at,
       COALESCE(${alias}.sonekleme, '') AS last_upload_at,
       ${alias}.sonekleyen AS last_uploaded_by_user_id,
       COALESCE(${alias}.aktif, 1) AS is_active,
       COALESCE(${alias}.visibility_scope, 'public') AS visibility_scope,
       COALESCE(${alias}.cohort_year, '') AS cohort_year,
       COALESCE(${alias}.album_type, 'general') AS album_type,
       ${alias}.owner_user_id AS owner_user_id,
       COALESCE(${alias}.is_system_album, 0) AS is_system_album,
       COALESCE(${alias}.cover_file_name, '') AS cover_file_name,
       COALESCE(${alias}.cover_mode, 'latest') AS cover_mode`;

  const photoSelect = (alias = 'p') => isPostgres
    ? `${alias}.id,
       ${alias}.category_id AS category_id,
       COALESCE(${alias}.file_name, '') AS file_name,
       COALESCE(${alias}.title, '') AS title,
       COALESCE(${alias}.description, '') AS description,
       COALESCE(${alias}.is_active, TRUE) AS is_active,
       ${alias}.uploaded_by_user_id AS uploaded_by_user_id,
       COALESCE(${alias}.created_at::text, '') AS created_at,
       COALESCE(${alias}.updated_at::text, '') AS updated_at,
       COALESCE(${alias}.view_count, 0) AS view_count,
       COALESCE(${alias}.allow_comments, TRUE) AS allow_comments,
       COALESCE(${alias}.tagged_user_ids_json, '[]') AS tagged_user_ids_json,
       COALESCE(${alias}.album_group_key, '') AS album_group_key,
       COALESCE(${alias}.album_group_index, 0) AS album_group_index`
    : `${alias}.id,
       ${alias}.katid AS category_id,
       COALESCE(${alias}.dosyaadi, '') AS file_name,
       COALESCE(${alias}.baslik, '') AS title,
       COALESCE(${alias}.aciklama, '') AS description,
       COALESCE(${alias}.aktif, 1) AS is_active,
       ${alias}.ekleyenid AS uploaded_by_user_id,
       COALESCE(${alias}.tarih, '') AS created_at,
       COALESCE(${alias}.updated_at, '') AS updated_at,
       COALESCE(${alias}.hit, 0) AS view_count,
       COALESCE(${alias}.allow_comments, 1) AS allow_comments,
       COALESCE(${alias}.tagged_user_ids_json, '[]') AS tagged_user_ids_json,
       COALESCE(${alias}.album_group_key, '') AS album_group_key,
       COALESCE(${alias}.album_group_index, 0) AS album_group_index`;

  const userSelect = (alias = 'u') => isPostgres
    ? `${alias}.id,
       COALESCE(${alias}.username, '') AS kadi,
       COALESCE(${alias}.first_name, '') AS isim,
       COALESCE(${alias}.last_name, '') AS soyisim,
       COALESCE(${alias}.avatar_path, '') AS resim,
       CASE WHEN COALESCE(${alias}.is_verified, FALSE) THEN 1 ELSE 0 END AS verified,
       COALESCE(${alias}.graduation_year, '') AS mezuniyetyili,
       COALESCE(${alias}.role, 'user') AS role,
       CASE WHEN COALESCE(${alias}.legacy_admin_flag, FALSE) THEN 1 ELSE 0 END AS admin,
       CASE WHEN COALESCE(${alias}.is_album_admin, FALSE) THEN 1 ELSE 0 END AS albumadmin`
    : `${alias}.id,
       COALESCE(${alias}.kadi, '') AS kadi,
       COALESCE(${alias}.isim, '') AS isim,
       COALESCE(${alias}.soyisim, '') AS soyisim,
       COALESCE(${alias}.resim, '') AS resim,
       COALESCE(${alias}.verified, 0) AS verified,
       COALESCE(${alias}.mezuniyetyili, '') AS mezuniyetyili,
       COALESCE(${alias}.role, 'user') AS role,
       COALESCE(${alias}.admin, 0) AS admin,
       COALESCE(${alias}.albumadmin, 0) AS albumadmin`;

  const schemaReady = ensureAlbumSchema();

  function isTruthy(value) {
    if (value === true) return true;
    if (Number(value) === 1) return true;
    const raw = String(value || '').trim().toLowerCase();
    return raw === '1' || raw === 'true' || raw === 'evet' || raw === 'yes';
  }

  function normalizeRole(user) {
    return String(user?.role || '').trim().toLowerCase();
  }

  function hasCategoryManagementAccess(user) {
    const role = normalizeRole(user);
    return (
      Number(user?.admin || 0) === 1 ||
      Number(user?.albumadmin || 0) === 1 ||
      role === 'admin' ||
      role === 'root' ||
      role === 'mod'
    );
  }

  function parseIdArray(rawValue) {
    if (Array.isArray(rawValue)) {
      return Array.from(
        new Set(
          rawValue
            .map((value) => Number.parseInt(String(value || '').trim(), 10))
            .filter((value) => Number.isInteger(value) && value > 0),
        ),
      );
    }

    if (typeof rawValue === 'string') {
      const trimmed = rawValue.trim();
      if (!trimmed) return [];
      if (trimmed.startsWith('[')) {
        try {
          return parseIdArray(JSON.parse(trimmed));
        } catch {
          return [];
        }
      }
      return parseIdArray(trimmed.split(','));
    }

    return [];
  }

  function parseStringArrayJson(rawValue) {
    try {
      const parsed = JSON.parse(String(rawValue || '[]'));
      return Array.isArray(parsed) ? parsed : [];
    } catch {
      return [];
    }
  }

  function parseJsonObjectField(rawValue) {
    if (!rawValue) return {};
    if (typeof rawValue === 'object' && !Array.isArray(rawValue)) {
      return rawValue;
    }
    try {
      const parsed = JSON.parse(String(rawValue || '{}'));
      return parsed && typeof parsed === 'object' && !Array.isArray(parsed)
        ? parsed
        : {};
    } catch {
      return {};
    }
  }

  function parseJsonArrayField(rawValue) {
    if (Array.isArray(rawValue)) return rawValue;
    try {
      const parsed = JSON.parse(String(rawValue || '[]'));
      return Array.isArray(parsed) ? parsed : [];
    } catch {
      return [];
    }
  }

  function normalizeIntegerId(value) {
    const text = String(value ?? '').trim();
    if (!text) return 0;
    const parsed = Number.parseFloat(text.replace(',', '.'));
    if (!Number.isFinite(parsed)) return 0;
    return Math.max(0, Math.trunc(parsed));
  }

  function resolveRequestedCategoryId(req) {
    return normalizeIntegerId(
      req.body?.kat ||
        req.body?.categoryId ||
        req.body?.albumId ||
        req.body?.category_id ||
        req.query?.kat ||
        req.query?.categoryId ||
        req.query?.albumId ||
        req.query?.category_id ||
        '',
    );
  }

  async function ensurePhotoCategory(photoId, categoryId) {
    if (!photoId || !categoryId) return;
    const categoryColumn = isPostgres ? 'category_id' : 'katid';
    const normalizedCategoryId = normalizeIntegerId(categoryId);
    const existing = await sqlGetAsync(
      `SELECT ${categoryColumn} AS category_id
       FROM ${photoTable}
       WHERE id = ?
       LIMIT 1`,
      [photoId],
    );
    if (normalizeIntegerId(existing?.category_id) === normalizedCategoryId) return;
    await sqlRunAsync(
      `UPDATE ${photoTable}
       SET ${categoryColumn} = ${isPostgres ? '?' : 'CAST(? AS INTEGER)'}
       WHERE id = ?`,
      [normalizedCategoryId, photoId],
    );
  }

  function getUploadFieldFiles(req, fieldName) {
    if (Array.isArray(req.files)) {
      return fieldName === 'file' || fieldName === 'files' ? req.files : [];
    }
    const files = req.files?.[fieldName];
    return Array.isArray(files) ? files : [];
  }

  function getUploadFieldFile(req, fieldName) {
    return getUploadFieldFiles(req, fieldName)[0] || req.file || null;
  }

  async function ensureAlbumSchema() {
    if (isPostgres) return;

    const statements = [
      "ALTER TABLE album_kat ADD COLUMN visibility_scope TEXT DEFAULT 'public'",
      "ALTER TABLE album_kat ADD COLUMN cohort_year TEXT",
      "ALTER TABLE album_kat ADD COLUMN album_type TEXT DEFAULT 'general'",
      'ALTER TABLE album_kat ADD COLUMN owner_user_id INTEGER',
      'ALTER TABLE album_kat ADD COLUMN is_system_album INTEGER DEFAULT 0',
      'ALTER TABLE album_kat ADD COLUMN cover_file_name TEXT',
      "ALTER TABLE album_kat ADD COLUMN cover_mode TEXT DEFAULT 'latest'",
      'ALTER TABLE album_foto ADD COLUMN allow_comments INTEGER DEFAULT 1',
      'ALTER TABLE album_foto ADD COLUMN updated_at TEXT',
      "ALTER TABLE album_foto ADD COLUMN tagged_user_ids_json TEXT DEFAULT '[]'",
      'ALTER TABLE album_foto ADD COLUMN album_group_key TEXT',
      'ALTER TABLE album_foto ADD COLUMN album_group_index INTEGER DEFAULT 0',
      'ALTER TABLE album_fotoyorum ADD COLUMN author_user_id INTEGER',
      'ALTER TABLE album_fotoyorum ADD COLUMN updated_at TEXT',
      `CREATE TABLE IF NOT EXISTS ${likeTable} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        photo_id INTEGER NOT NULL,
        user_id INTEGER NOT NULL,
        created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
        UNIQUE (photo_id, user_id)
      )`,
      `CREATE TABLE IF NOT EXISTS ${permissionTable} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        category_id INTEGER NOT NULL,
        user_id INTEGER,
        group_id INTEGER,
        created_by_user_id INTEGER,
        created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
      )`,
      `CREATE UNIQUE INDEX IF NOT EXISTS idx_album_category_permissions_category_user
       ON ${permissionTable} (category_id, user_id)`,
      `CREATE UNIQUE INDEX IF NOT EXISTS idx_album_category_permissions_category_group
       ON ${permissionTable} (category_id, group_id)`,
      `CREATE INDEX IF NOT EXISTS idx_album_photo_likes_photo_id
       ON ${likeTable} (photo_id, created_at DESC)`,
      `CREATE TABLE IF NOT EXISTS ${editTable} (
        photo_id ${isPostgres ? 'BIGINT PRIMARY KEY' : 'INTEGER PRIMARY KEY'},
        metadata_json TEXT NOT NULL DEFAULT '{}',
        source_file_name TEXT,
        updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
      )`,
      `ALTER TABLE ${editTable} ADD COLUMN source_file_name TEXT`,
    ];

    for (const statement of statements) {
      try {
        await sqlRunAsync(statement);
      } catch (error) {
        const message = String(error?.message || '').toLowerCase();
        if (
          message.includes('duplicate column') ||
          message.includes('already exists') ||
          message.includes('duplicate key')
        ) {
          continue;
        }
        throw error;
      }
    }
  }

  async function findViewer(userId) {
    if (!userId) return null;
    return sqlGetAsync(
      `SELECT ${userSelect('u')}
       FROM ${userTable} u
       WHERE u.id = ?`,
      [userId],
    );
  }

  async function ensureCohortAlbum(viewer) {
    const year = String(viewer?.mezuniyetyili || '').trim();
    if (!/^\d{4}$/.test(year)) return null;

    const existing = await sqlGetAsync(
      `SELECT ${categorySelect('c')}
       FROM ${categoryTable} c
       WHERE COALESCE(c.album_type, 'general') = 'cohort'
         AND COALESCE(c.cohort_year, '') = ?
         AND ${isPostgres ? 'COALESCE(c.is_active, TRUE) IS TRUE' : 'COALESCE(c.aktif, 1) = 1'}
       ORDER BY c.id
       LIMIT 1`,
      [year],
    );
    if (existing) return existing;

    const now = new Date().toISOString();
    const title = `${year} Mezunları`;
    if (isPostgres) {
      await sqlRunAsync(
        `INSERT INTO ${categoryTable}
          (name, description, created_at, last_upload_at, last_uploaded_by_user_id, is_active, visibility_scope, cohort_year, album_type, is_system_album)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
        [
          title,
          `${year} cohortuna özel sabit albüm.`,
          now,
          now,
          viewer?.id || null,
          true,
          'cohort',
          year,
          'cohort',
          true,
        ],
      );
    } else {
      await sqlRunAsync(
        `INSERT INTO ${categoryTable}
          (kategori, aciklama, ilktarih, sonekleme, sonekleyen, aktif, visibility_scope, cohort_year, album_type, is_system_album)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
        [
          title,
          `${year} cohortuna özel sabit albüm.`,
          now,
          now,
          viewer?.id || null,
          1,
          'cohort',
          year,
          'cohort',
          1,
        ],
      );
    }

    return sqlGetAsync(
      `SELECT ${categorySelect('c')}
       FROM ${categoryTable} c
       WHERE COALESCE(c.album_type, 'general') = 'cohort'
         AND COALESCE(c.cohort_year, '') = ?
       ORDER BY c.id DESC
       LIMIT 1`,
      [year],
    );
  }

  async function listExplicitPermissionRows(categoryId) {
    return sqlAllAsync(
      `SELECT user_id, group_id
       FROM ${permissionTable}
       WHERE category_id = ?`,
      [categoryId],
    );
  }

  async function hasExplicitAccess(categoryId, userId) {
    if (!categoryId || !userId) return false;
    const direct = await sqlGetAsync(
      `SELECT id
       FROM ${permissionTable}
       WHERE category_id = ?
         AND user_id = ?
       LIMIT 1`,
      [categoryId, userId],
    );
    if (direct) return true;

    const viaGroup = await sqlGetAsync(
      `SELECT p.id
       FROM ${permissionTable} p
       JOIN group_members gm ON gm.group_id = p.group_id
       WHERE p.category_id = ?
         AND gm.user_id = ?
       LIMIT 1`,
      [categoryId, userId],
    );
    return !!viaGroup;
  }

  async function canAccessCategory(category, viewer, currentUser) {
    if (!category || !viewer) return false;
    if (!isTruthy(category.is_active)) return false;
    if (hasCategoryManagementAccess(currentUser)) return true;
    if (sameUserId(category.owner_user_id, viewer.id)) return true;

    const scope = String(category.visibility_scope || 'public').trim().toLowerCase();
    if (scope === 'public') return true;
    if (scope === 'cohort') {
      const viewerYear = String(viewer.mezuniyetyili || '').trim();
      return !!viewerYear && viewerYear === String(category.cohort_year || '').trim();
    }
    if (scope === 'private' || scope === 'custom') {
      return hasExplicitAccess(category.id, viewer.id);
    }
    return true;
  }

  function canEditCategory(category, viewer, currentUser) {
    if (!category || !viewer) return false;
    if (hasCategoryManagementAccess(currentUser)) return true;
    return String(category.album_type || '').trim().toLowerCase() === 'profile' &&
      sameUserId(category.owner_user_id, viewer.id);
  }

  async function canUploadToCategory(category, viewer, currentUser) {
    if (!(await canAccessCategory(category, viewer, currentUser))) return false;
    const type = String(category.album_type || '').trim().toLowerCase();
    if (type !== 'profile') return true;
    return canEditCategory(category, viewer, currentUser);
  }

  async function getCategoryById(categoryId) {
    return sqlGetAsync(
      `SELECT ${categorySelect('c')}
       FROM ${categoryTable} c
       WHERE c.id = ?`,
      [categoryId],
    );
  }

  async function getPhotoById(photoId) {
    return sqlGetAsync(
      `SELECT ${photoSelect('p')}
       FROM ${photoTable} p
       WHERE p.id = ?`,
      [photoId],
    );
  }

  async function listPhotoGroup(photo) {
    const groupKey = String(photo?.album_group_key || '').trim();
    if (!photo || !groupKey) return photo ? [photo] : [];
    return sqlAllAsync(
      `SELECT ${photoSelect('p')}
       FROM ${photoTable} p
       WHERE p.${isPostgres ? 'category_id' : 'katid'} = ?
         AND COALESCE(p.album_group_key, '') = ?
         AND ${photoActiveSql}
       ORDER BY COALESCE(p.album_group_index, 0) ASC, p.id ASC`,
      [photo.category_id, groupKey],
    );
  }

  async function getPhotoGroupContext(photo) {
    const photos = await listPhotoGroup(photo);
    const ids = photos.map((item) => Number(item.id || 0)).filter(Boolean);
    const canonical = photos[0] || photo;
    return {
      photos,
      ids,
      canonical,
      canonicalId: Number(canonical?.id || photo?.id || 0),
      isGroup: ids.length > 1,
    };
  }

  function sqlInPlaceholders(values) {
    return values.map(() => '?').join(', ');
  }

  function runAlbumUpload(req, res, next, fields) {
    return albumUpload.fields(fields)(req, res, (error) => {
      if (!error) return next();
      const code = String(error?.code || '').trim();
      const message = String(error?.message || '').trim();
      if (code === 'LIMIT_FILE_SIZE' || message.toLowerCase().includes('too large')) {
        return res.status(413).json({
          ok: false,
          message: 'Fotoğraf dosyası çok büyük. Lütfen fotoğrafları biraz küçültüp tekrar dene.',
          code: 'UPLOAD_TOO_LARGE',
        });
      }
      return res.status(400).json({
        ok: false,
        message: message || 'Fotoğraf yükleme tamamlanamadı.',
        code: code || 'UPLOAD_FAILED',
      });
    });
  }

  async function readTaggedUsers(taggedUserIds) {
    const ids = parseIdArray(taggedUserIds);
    if (!ids.length) return [];
    const placeholders = ids.map(() => '?').join(', ');
    return sqlAllAsync(
      `SELECT ${userSelect('u')}
       FROM ${userTable} u
       WHERE u.id IN (${placeholders})`,
      ids,
    );
  }

  async function replaceCategoryPermissions(categoryId, {
    userIds = [],
    groupIds = [],
    createdByUserId = null,
  } = {}) {
    await sqlRunAsync(`DELETE FROM ${permissionTable} WHERE category_id = ?`, [categoryId]);
    for (const userId of parseIdArray(userIds)) {
      await sqlRunAsync(
        `INSERT INTO ${permissionTable} (category_id, user_id, created_by_user_id, created_at)
         VALUES (?, ?, ?, ?)`,
        [categoryId, userId, createdByUserId, new Date().toISOString()],
      );
    }
    for (const groupId of parseIdArray(groupIds)) {
      await sqlRunAsync(
        `INSERT INTO ${permissionTable} (category_id, group_id, created_by_user_id, created_at)
         VALUES (?, ?, ?, ?)`,
        [categoryId, groupId, createdByUserId, new Date().toISOString()],
      );
    }
  }

  async function listCategoryPermissionMembers(categoryId) {
    return sqlAllAsync(
      `SELECT ${userSelect('u')}
       FROM ${permissionTable} p
       JOIN ${userTable} u ON u.id = p.user_id
       WHERE p.category_id = ?
         AND p.user_id IS NOT NULL
       ORDER BY ${isPostgres ? 'u.first_name, u.last_name, u.username' : 'u.isim, u.soyisim, u.kadi'}`,
      [categoryId],
    );
  }

  async function listCategoryPermissionGroups(categoryId) {
    return sqlAllAsync(
      `SELECT g.id,
              COALESCE(g.name, '') AS name,
              COALESCE(g.description, '') AS description,
              COALESCE(g.cover_image, '') AS cover_image,
              COALESCE(g.visibility, 'public') AS visibility,
              COALESCE(g.is_cohort_group, 0) AS is_cohort_group,
              COALESCE(g.cohort_year, '') AS cohort_year,
              0 AS members
       FROM ${permissionTable} p
       JOIN groups g ON g.id = p.group_id
       WHERE p.category_id = ?
         AND p.group_id IS NOT NULL
       ORDER BY g.name`,
      [categoryId],
    );
  }

  function normalizeCoverMode(value) {
    const mode = String(value || '').trim().toLowerCase();
    return ['latest', 'fixed', 'shuffle'].includes(mode) ? mode : 'latest';
  }

  async function resolveCoverFileName(categoryId, coverPhotoId) {
    const normalizedPhotoId = normalizeIntegerId(coverPhotoId);
    if (!normalizedPhotoId) return '';
    const row = await sqlGetAsync(
      `SELECT COALESCE(p.${isPostgres ? 'file_name' : 'dosyaadi'}, '') AS file_name
       FROM ${photoTable} p
       WHERE p.id = ?
         AND p.${isPostgres ? 'category_id' : 'katid'} = ?
         AND ${photoActiveSql}
       LIMIT 1`,
      [normalizedPhotoId, categoryId],
    );
    return String(row?.file_name || '').trim();
  }

  async function summarizeCategory(category, viewer, currentUser) {
    const categoryIdParam = String(category.id);
    const countRow = await sqlGetAsync(
      `SELECT COUNT(*) AS cnt
       FROM ${photoTable} p
       WHERE p.${isPostgres ? 'category_id' : 'katid'} = ?
         AND ${photoActiveSql}`,
      [categoryIdParam],
    );
    const coverMode = normalizeCoverMode(category.cover_mode);
    const coverFileName = String(category.cover_file_name || '').trim();
    const coverRow = coverMode === 'fixed' && coverFileName
      ? await sqlGetAsync(
          `SELECT ${photoSelect('p')}
           FROM ${photoTable} p
           WHERE p.${isPostgres ? 'category_id' : 'katid'} = ?
             AND COALESCE(p.${isPostgres ? 'file_name' : 'dosyaadi'}, '') = ?
             AND ${photoActiveSql}
           LIMIT 1`,
          [categoryIdParam, coverFileName],
        )
      : null;
    const previewRows = await sqlAllAsync(
      `SELECT ${photoSelect('p')}
       FROM ${photoTable} p
       WHERE p.${isPostgres ? 'category_id' : 'katid'} = ?
         AND ${photoActiveSql}
         ${coverMode === 'fixed' && coverFileName ? `AND COALESCE(p.${isPostgres ? 'file_name' : 'dosyaadi'}, '') <> ?` : ''}
       ORDER BY ${coverMode === 'shuffle' ? (isPostgres ? 'RANDOM()' : 'RANDOM()') : `p.${isPostgres ? 'created_at' : 'tarih'} DESC, p.id DESC`}
       LIMIT ${coverMode === 'fixed' && coverFileName ? 4 : 5}`,
      coverMode === 'fixed' && coverFileName
        ? [categoryIdParam, coverFileName]
        : [categoryIdParam],
    );
    const previews = [
      ...(coverMode === 'fixed' && coverFileName ? [coverFileName] : []),
      ...previewRows.map((item) => item.file_name).filter(Boolean),
    ];
    const previewMediaRows = [
      ...(coverRow ? [coverRow] : []),
      ...previewRows,
    ].filter(Boolean);
    const previewMedia = [];
    for (const row of previewMediaRows) {
      previewMedia.push(await buildAlbumPhotoMediaPayload(row));
    }

    return {
      id: Number(category.id || 0),
      kategori: category.title || 'Albüm',
      aciklama: category.description || '',
      count: Number(countRow?.cnt || 0),
      previews,
      previewMedia,
      visibilityScope: String(category.visibility_scope || 'public'),
      cohortYear: String(category.cohort_year || ''),
      albumType: String(category.album_type || 'general'),
      ownerUserId: normalizeUserId(category.owner_user_id),
      isSystemAlbum: isTruthy(category.is_system_album),
      coverMode,
      coverFileName,
      canUpload: await canUploadToCategory(category, viewer, currentUser),
      canEdit: canEditCategory(category, viewer, currentUser),
    };
  }

  async function listAccessibleCategories(viewer, currentUser) {
    await ensureCohortAlbum(viewer);
    const rows = await sqlAllAsync(
      `SELECT ${categorySelect('c')}
       FROM ${categoryTable} c
       WHERE ${isPostgres ? 'COALESCE(c.is_active, TRUE) IS TRUE' : 'COALESCE(c.aktif, 1) = 1'}
       ORDER BY
         CASE COALESCE(c.album_type, 'general')
           WHEN 'cohort' THEN 0
           WHEN 'profile' THEN 2
           ELSE 1
         END,
         LOWER(COALESCE(${isPostgres ? 'c.name' : 'c.kategori'}, '')) ASC,
         c.id ASC`,
    );

    const items = [];
    for (const row of rows) {
      if (!(await canAccessCategory(row, viewer, currentUser))) continue;
      items.push(await summarizeCategory(row, viewer, currentUser));
    }
    return items;
  }

  async function listPhotoCards(categoryIds, viewerUserId, {
    orderBy,
    limit = 10,
  }) {
    if (!categoryIds.length) return [];
    const idStrings = categoryIds.map(String);
    const placeholders = idStrings.map(() => '?').join(', ');
    const rows = await sqlAllAsync(
      `SELECT ${photoSelect('p')},
              COALESCE(${isPostgres ? 'c.name' : 'c.kategori'}, '') AS category_title
       FROM ${photoTable} p
       JOIN ${categoryTable} c ON ${isPostgres ? 'c.id = p.category_id' : 'CAST(c.id AS TEXT) = CAST(p.katid AS TEXT)'}
       WHERE p.${isPostgres ? 'category_id' : 'katid'} IN (${placeholders})
         AND ${photoActiveSql}
       ORDER BY ${orderBy}
       LIMIT ?`,
      [...idStrings, limit],
    );

    const cards = [];
    for (const row of rows) {
      const likeCountRow = await sqlGetAsync(
        `SELECT COUNT(*) AS cnt FROM ${likeTable} WHERE photo_id = ?`,
        [row.id],
      );
      const commentCountRow = await sqlGetAsync(
        `SELECT COUNT(*) AS cnt FROM ${commentTable} WHERE ${isPostgres ? 'photo_id' : 'fotoid'} = ?`,
        [row.id],
      );
      const likedRow = viewerUserId
        ? await sqlGetAsync(
            `SELECT id FROM ${likeTable} WHERE photo_id = ? AND user_id = ? LIMIT 1`,
            [row.id, viewerUserId],
          )
        : null;
      cards.push({
        id: Number(row.id || 0),
        katid: Number(row.category_id || 0),
        dosyaadi: row.file_name || '',
        media: await buildAlbumPhotoMediaPayload(row),
        baslik: row.title || 'Fotoğraf',
        tarih: row.created_at || '',
        kategori: row.category_title || '',
        viewCount: Number(row.view_count || 0),
        likeCount: Number(likeCountRow?.cnt || 0),
        commentCount: Number(commentCountRow?.cnt || 0),
        liked: !!likedRow,
        allowComments: isTruthy(row.allow_comments),
      });
    }
    return cards;
  }

  async function loadCategoryContext(categoryId, viewer, currentUser) {
    const category = await getCategoryById(categoryId);
    if (!category) return { error: { status: 404, message: 'Albüm bulunamadı.' } };
    if (!(await canAccessCategory(category, viewer, currentUser))) {
      return { error: { status: 403, message: 'Bu albüme erişim yetkin yok.' } };
    }
    return { category };
  }

  async function loadPhotoContext(photoId, viewer, currentUser) {
    const photo = await getPhotoById(photoId);
    if (!photo) return { error: { status: 404, message: 'Fotoğraf bulunamadı.' } };
    const category = await getCategoryById(photo.category_id);
    if (!category) return { error: { status: 404, message: 'Albüm bulunamadı.' } };
    if (!(await canAccessCategory(category, viewer, currentUser))) {
      return { error: { status: 403, message: 'Bu fotoğrafa erişim yetkin yok.' } };
    }
    return { photo, category };
  }

  async function notifyTaggedUsers(taggedUserIds, previousTaggedUserIds, sourceUserId, photoId) {
    const previousSet = new Set(parseIdArray(previousTaggedUserIds).map((value) => String(value)));
    for (const userId of parseIdArray(taggedUserIds)) {
      if (previousSet.has(String(userId))) continue;
      if (sameUserId(userId, sourceUserId)) continue;
      addNotification({
        userId,
        type: 'mention_photo',
        sourceUserId,
        entityId: photoId,
        message: 'Bir fotoğrafta seni etiketledi.',
      });
    }
  }

  async function getPhotoEditState(photoId) {
    if (!photoId) {
      return { metadata: {}, sourceFileName: '' };
    }
    const row = await sqlGetAsync(
      `SELECT metadata_json, COALESCE(source_file_name, '') AS source_file_name
       FROM ${editTable}
       WHERE photo_id = ?
       LIMIT 1`,
      [photoId],
    );
    return {
      metadata: parseJsonObjectField(row?.metadata_json),
      sourceFileName: String(row?.source_file_name || '').trim(),
    };
  }

  function albumMediaUrl(fileName, { width } = {}) {
    const clean = String(fileName || '').trim();
    if (!clean) return '';
    const params = new URLSearchParams();
    if (width) params.set('width', String(width));
    params.set('file', clean);
    return `/api/media/kucukresim?${params.toString()}`;
  }

  function resolveEditAspectRatio(metadata) {
    const data = parseJsonObjectField(metadata);
    const explicit = Number(data.aspectRatio || 0);
    if (Number.isFinite(explicit) && explicit > 0) return explicit;
    const widthFactor = Number(data.freeformWidthFactor || 0);
    const heightFactor = Number(data.freeformHeightFactor || 0);
    if (
      Number.isFinite(widthFactor) &&
      Number.isFinite(heightFactor) &&
      widthFactor > 0 &&
      heightFactor > 0
    ) {
      return widthFactor / heightFactor;
    }
    return 4 / 3;
  }

  async function buildAlbumPhotoMediaPayload(photo, editStateArg = null) {
    const fileName = String(photo?.file_name || '').trim();
    const editState = editStateArg || await getPhotoEditState(photo?.id);
    const metadata = parseJsonObjectField(editState.metadata);
    const isCropOnly = String(metadata.editorMode || '').trim() === 'cropOnly';
    const sourceFileName = isCropOnly
      ? ''
      : String(editState.sourceFileName || '').trim();
    const aspectRatio = resolveEditAspectRatio(metadata);
    return {
      fileName,
      displayFileName: fileName,
      displayUrl: albumMediaUrl(fileName, { width: 1400 }),
      thumbnailUrl: albumMediaUrl(fileName, { width: 640 }),
      lightboxUrl: albumMediaUrl(fileName, { width: 2200 }),
      sourceFileName,
      editSourceFileName: sourceFileName,
      editMetadata: metadata,
      aspectRatio,
      isEdited: Object.keys(metadata).length > 0 || !!sourceFileName,
    };
  }

  async function savePhotoEditMetadata(photoId, metadata, { sourceFileName = '' } = {}) {
    if (!photoId) return;
    const payload = JSON.stringify(parseJsonObjectField(metadata));
    const now = new Date().toISOString();
    let effectiveSourceFileName = String(sourceFileName || '').trim();
    if (!effectiveSourceFileName) {
      const existing = await sqlGetAsync(
        `SELECT COALESCE(source_file_name, '') AS source_file_name
         FROM ${editTable}
         WHERE photo_id = ?
         LIMIT 1`,
        [photoId],
      );
      effectiveSourceFileName = String(existing?.source_file_name || '').trim();
    }
    await sqlRunAsync(
      `INSERT INTO ${editTable} (photo_id, metadata_json, source_file_name, updated_at)
       VALUES (?, ?, ?, ?)
       ON CONFLICT(photo_id) DO UPDATE SET
         metadata_json = excluded.metadata_json,
         source_file_name = excluded.source_file_name,
         updated_at = excluded.updated_at`,
      [photoId, payload, effectiveSourceFileName || null, now],
    );
  }

  app.get('/api/albums', async (req, res) => {
    try {
      await schemaReady;
      if (!req.session.userId) return res.status(401).send('Login required');
      const viewer = await findViewer(req.session.userId);
      const currentUser = getCurrentUser(req);
      const categories = await listAccessibleCategories(viewer, currentUser);

      const validIds = categories.map((item) => item.id).filter(Boolean);
      const validIdStrings = validIds.map(String);
      if (validIds.length > 0) {
        try {
          const placeholders = validIds.map(() => '?').join(', ');
          const countRows = await sqlAllAsync(
            `SELECT p.${isPostgres ? 'category_id' : 'katid'} AS cid, COUNT(*) AS cnt
             FROM ${photoTable} p
             WHERE p.${isPostgres ? 'category_id' : 'katid'} IN (${placeholders})
               AND ${photoActiveSql}
             GROUP BY p.${isPostgres ? 'category_id' : 'katid'}`,
            validIdStrings,
          );
          const countsMap = {};
          for (const row of countRows) {
            countsMap[String(row.cid)] = Number(row.cnt || 0);
          }
          for (const cat of categories) {
            cat.count = countsMap[String(cat.id)] ?? 0;
          }
        } catch (error) {
          console.error('album_dashboard_counts_failed', error);
        }
      }

      const categoryIds = validIds.filter((value) => Number(value) > 0);
      let latest = [];
      let popular = [];
      try {
        latest = await listPhotoCards(categoryIds, req.session.userId, {
          orderBy: `p.${isPostgres ? 'created_at' : 'tarih'} DESC, p.id DESC`,
          limit: 10,
        });
      } catch (error) {
        console.error('album_dashboard_latest_failed', error);
      }
      try {
        popular = await listPhotoCards(categoryIds, req.session.userId, {
          orderBy: `COALESCE(p.${isPostgres ? 'view_count' : 'hit'}, 0) DESC, p.${isPostgres ? 'created_at' : 'tarih'} DESC, p.id DESC`,
          limit: 10,
        });
      } catch (error) {
        console.error('album_dashboard_popular_failed', error);
      }
      const mine = categories.filter((item) => sameUserId(item.ownerUserId, req.session.userId));
      res.json({
        items: categories,
        categories,
        latest,
        popular,
        mine,
        permissions: {
          canCreateAlbum: true,
          canManageCategories: hasCategoryManagementAccess(currentUser),
        },
      });
    } catch (error) {
      console.error(error);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.get('/api/album/categories/active', async (req, res) => {
    try {
      await schemaReady;
      if (!req.session.userId) return res.status(401).send('Login required');
      const viewer = await findViewer(req.session.userId);
      const currentUser = getCurrentUser(req);
      const categories = await listAccessibleCategories(viewer, currentUser);
      const uploadable = categories.filter((item) => item.canUpload);
      res.json({ categories: uploadable });
    } catch (error) {
      console.error(error);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.post('/api/albums', async (req, res) => {
    try {
      await schemaReady;
      if (!req.session.userId) return res.status(401).send('Login required');
      const viewer = await findViewer(req.session.userId);
      const currentUser = getCurrentUser(req);
      const isProfileAlbum = isTruthy(req.body?.isProfileAlbum);
      if (!isProfileAlbum && !hasCategoryManagementAccess(currentUser)) {
        return res.status(403).send('Albüm oluşturma yetkin yok.');
      }

      const title = sanitizePlainUserText(String(req.body?.title || req.body?.kategori || '').trim(), 120);
      const description = formatUserText(req.body?.description || req.body?.aciklama || '');
      let visibilityScope = String(req.body?.visibilityScope || req.body?.visibility || 'public').trim().toLowerCase();
      if (!['public', 'cohort', 'private', 'custom'].includes(visibilityScope)) {
        visibilityScope = 'public';
      }

      const viewerCohort = String(viewer?.mezuniyetyili || '').trim();
      const requestedCohort = visibilityScope === 'cohort'
        ? viewerCohort
        : String(req.body?.cohortYear || req.body?.cohort || viewerCohort || '').trim();
      const userIds = parseIdArray(req.body?.allowedUserIds);
      const groupIds = parseIdArray(req.body?.allowedGroupIds);
      const albumType = isProfileAlbum
        ? 'profile'
        : visibilityScope === 'cohort'
        ? 'cohort'
        : 'general';
      const ownerUserId = isProfileAlbum ? req.session.userId : null;
      const cohortYear = visibilityScope === 'cohort' ? requestedCohort : '';
      const isSystemAlbum = !isProfileAlbum && isTruthy(req.body?.isSystemAlbum);
      const now = new Date().toISOString();

      if (!title) return res.status(400).send('Albüm başlığı zorunlu.');
      if (visibilityScope === 'cohort' && !/^\d{4}$/.test(cohortYear)) {
        return res.status(400).send('Geçerli bir cohort yılı seçmelisin.');
      }
      if ((visibilityScope === 'private' || visibilityScope === 'custom') && !userIds.length && !groupIds.length) {
        return res.status(400).send('Özel albüm için en az bir kişi veya grup seçmelisin.');
      }

      let result;
      if (isPostgres) {
        result = await sqlRunAsync(
          `INSERT INTO ${categoryTable}
            (name, description, created_at, last_upload_at, last_uploaded_by_user_id, is_active, visibility_scope, cohort_year, album_type, owner_user_id, is_system_album)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
          [
            title,
            description,
            now,
            now,
            req.session.userId,
            true,
            visibilityScope,
            cohortYear || null,
            albumType,
            ownerUserId,
            isSystemAlbum,
          ],
        );
      } else {
        result = await sqlRunAsync(
          `INSERT INTO ${categoryTable}
            (kategori, aciklama, ilktarih, sonekleme, sonekleyen, aktif, visibility_scope, cohort_year, album_type, owner_user_id, is_system_album)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
          [
            title,
            description,
            now,
            now,
            req.session.userId,
            1,
            visibilityScope,
            cohortYear || null,
            albumType,
            ownerUserId,
            boolValue(isSystemAlbum),
          ],
        );
      }

      const categoryId = Number(result?.lastInsertRowid || result?.insertId || 0);
      await replaceCategoryPermissions(categoryId, {
        userIds,
        groupIds,
        createdByUserId: req.session.userId,
      });

      const category = await getCategoryById(categoryId);
      res.json({ ok: true, category: await summarizeCategory(category, viewer, currentUser) });
    } catch (error) {
      console.error(error);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.put('/api/albums/:id', async (req, res) => {
    try {
      await schemaReady;
      if (!req.session.userId) return res.status(401).send('Login required');
      const viewer = await findViewer(req.session.userId);
      const currentUser = getCurrentUser(req);
      const category = await getCategoryById(Number(req.params.id || 0));
      if (!category) return res.status(404).send('Albüm bulunamadı.');
      if (!canEditCategory(category, viewer, currentUser)) {
        return res.status(403).send('Bu albümü düzenleme yetkin yok.');
      }

      const title = sanitizePlainUserText(String(req.body?.title || req.body?.kategori || '').trim(), 120);
      const description = formatUserText(req.body?.description || req.body?.aciklama || '');
      let visibilityScope = String(req.body?.visibilityScope || req.body?.visibility || category.visibility_scope || 'public').trim().toLowerCase();
      if (!['public', 'cohort', 'private', 'custom'].includes(visibilityScope)) {
        visibilityScope = 'public';
      }

      const viewerCohort = String(viewer?.mezuniyetyili || '').trim();
      const requestedCohort = visibilityScope === 'cohort'
        ? String(req.body?.cohortYear || req.body?.cohort || viewerCohort || '').trim()
        : '';
      const userIds = parseIdArray(req.body?.allowedUserIds);
      const groupIds = parseIdArray(req.body?.allowedGroupIds);
      const coverMode = normalizeCoverMode(req.body?.coverMode);
      const coverFileName = coverMode === 'fixed'
        ? await resolveCoverFileName(category.id, req.body?.coverPhotoId)
        : '';

      if (!title) return res.status(400).send('Albüm başlığı zorunlu.');
      if (visibilityScope === 'cohort' && !/^\d{4}$/.test(requestedCohort)) {
        return res.status(400).send('Geçerli bir cohort yılı seçmelisin.');
      }
      if ((visibilityScope === 'private' || visibilityScope === 'custom') && !userIds.length && !groupIds.length) {
        return res.status(400).send('Özel albüm için en az bir kişi veya grup seçmelisin.');
      }
      if (coverMode === 'fixed' && !coverFileName) {
        return res.status(400).send('Sabit kapak için bu albümden bir fotoğraf seçmelisin.');
      }

      if (isPostgres) {
        await sqlRunAsync(
          `UPDATE ${categoryTable}
           SET name = ?,
               description = ?,
               visibility_scope = ?,
               cohort_year = ?,
               cover_mode = ?,
               cover_file_name = ?
           WHERE id = ?`,
          [
            title,
            description,
            visibilityScope,
            visibilityScope === 'cohort' ? requestedCohort : null,
            coverMode,
            coverMode === 'fixed' ? coverFileName : null,
            category.id,
          ],
        );
      } else {
        await sqlRunAsync(
          `UPDATE ${categoryTable}
           SET kategori = ?,
               aciklama = ?,
               visibility_scope = ?,
               cohort_year = ?,
               cover_mode = ?,
               cover_file_name = ?
           WHERE id = ?`,
          [
            title,
            description,
            visibilityScope,
            visibilityScope === 'cohort' ? requestedCohort : null,
            coverMode,
            coverMode === 'fixed' ? coverFileName : null,
            category.id,
          ],
        );
      }

      await replaceCategoryPermissions(category.id, {
        userIds,
        groupIds,
        createdByUserId: req.session.userId,
      });

      const updated = await getCategoryById(category.id);
      res.json({ ok: true, category: await summarizeCategory(updated, viewer, currentUser) });
    } catch (error) {
      console.error(error);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.delete('/api/albums/:id', async (req, res) => {
    try {
      await schemaReady;
      if (!req.session.userId) return res.status(401).send('Login required');
      const viewer = await findViewer(req.session.userId);
      const currentUser = getCurrentUser(req);
      const category = await getCategoryById(Number(req.params.id || 0));
      if (!category) return res.status(404).send('Albüm bulunamadı.');
      if (!canEditCategory(category, viewer, currentUser)) {
        return res.status(403).send('Bu albümü silme yetkin yok.');
      }
      await sqlRunAsync(`DELETE FROM ${categoryTable} WHERE id = ?`, [category.id]);
      res.json({ ok: true });
    } catch (error) {
      console.error(error);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.post('/api/album/upload', (req, res, next) => {
    if (!req.session.userId) return res.status(401).send('Login required');
    return runAlbumUpload(req, res, next, [
      { name: 'file', maxCount: 1 },
      { name: 'sourceFile', maxCount: 1 },
    ]);
  }, async (req, res) => {
    try {
      await schemaReady;
      const viewer = await findViewer(req.session.userId);
      if (!viewer || Number(viewer.verified || 0) !== 1) {
        return res.status(403).json({ error: 'VERIFICATION_REQUIRED', message: 'Yazma işlemleri için önce profilinizi doğrulamanız gerekiyor.' });
      }
      const currentUser = getCurrentUser(req);
      const categoryId = normalizeIntegerId(resolveRequestedCategoryId(req));
      const uploadFile = getUploadFieldFile(req, 'file');
      const sourceUploadFile = getUploadFieldFile(req, 'sourceFile');
      const rawTitle = String(req.body?.baslik || req.body?.title || '').trim();
      const fallbackTitle = String(uploadFile?.originalname || 'Fotoğraf')
        .replace(/\.[^.]+$/, '')
        .trim();
      const title = sanitizePlainUserText(rawTitle || fallbackTitle || 'Fotoğraf', 255);
      const description = formatUserText(req.body?.aciklama || req.body?.description || '');
      const allowComments = isTruthy(req.body?.yorumlaraIzin ?? req.body?.allowComments ?? true);
      const taggedUserIds = parseIdArray(req.body?.taggedUserIds);
      const editMetadata = parseJsonObjectField(req.body?.editMetadata);
      const albumGroupKey = sanitizePlainUserText(
        String(req.body?.albumGroupKey || req.body?.groupKey || '').trim(),
        80,
      );
      const albumGroupIndex = Math.max(
        0,
        Number.parseInt(String(req.body?.albumGroupIndex || req.body?.groupIndex || '0'), 10) || 0,
      );

      if (!categoryId) return res.status(400).send('Albüm seçmelisin.');
      if (!uploadFile?.filename) return res.status(400).send('Geçerli bir resim dosyası girmedin.');

      const categoryContext = await loadCategoryContext(categoryId, viewer, currentUser);
      if (categoryContext.error) {
        return res.status(categoryContext.error.status).send(categoryContext.error.message);
      }
      if (!(await canUploadToCategory(categoryContext.category, viewer, currentUser))) {
        return res.status(403).send('Bu albüme fotoğraf ekleme yetkin yok.');
      }

      const processed = await processDiskImageUpload({
        req,
        res,
        file: uploadFile,
        bucket: 'album_photo',
        preset: uploadImagePresets.albumPhoto,
      });
      if (!processed.ok) return res.status(processed.statusCode).send(processed.message);

      const storedFilename = path.basename(processed.path || uploadFile.path);
      const requireApproval = false;
      const activeValue = boolValue(!requireApproval);
      const now = new Date().toISOString();
      let result;

      if (isPostgres) {
        result = await sqlRunAsync(
          `INSERT INTO ${photoTable}
            (category_id, file_name, title, description, is_active, uploaded_by_user_id, created_at, updated_at, view_count, allow_comments, tagged_user_ids_json, album_group_key, album_group_index)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
          [
            categoryId,
            storedFilename,
            title,
            description,
            activeValue,
            req.session.userId,
            now,
            now,
            0,
            boolValue(allowComments),
            JSON.stringify(taggedUserIds),
            albumGroupKey || null,
            albumGroupKey ? albumGroupIndex : 0,
          ],
        );
        await sqlRunAsync(
          `UPDATE ${categoryTable}
           SET last_upload_at = ?, last_uploaded_by_user_id = ?, cover_file_name = COALESCE(?, cover_file_name)
           WHERE id = ?`,
          [now, req.session.userId, storedFilename, categoryId],
        );
      } else {
        result = await sqlRunAsync(
          `INSERT INTO ${photoTable}
            (katid, dosyaadi, baslik, aciklama, aktif, ekleyenid, tarih, updated_at, hit, allow_comments, tagged_user_ids_json, album_group_key, album_group_index)
           VALUES (CAST(? AS INTEGER), ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
          [
            categoryId,
            storedFilename,
            title,
            description,
            activeValue,
            req.session.userId,
            now,
            now,
            0,
            boolValue(allowComments),
            JSON.stringify(taggedUserIds),
            albumGroupKey || null,
            albumGroupKey ? albumGroupIndex : 0,
          ],
        );
        await sqlRunAsync(
          `UPDATE ${categoryTable}
           SET sonekleme = ?, sonekleyen = ?, cover_file_name = COALESCE(?, cover_file_name)
           WHERE id = ?`,
          [now, req.session.userId, storedFilename, categoryId],
        );
      }

      const photoId = Number(result?.lastInsertRowid || result?.insertId || 0);
      await ensurePhotoCategory(photoId, categoryId);
      const sourceStoredFilename = path.basename(
        sourceUploadFile?.path || processed.path || uploadFile.path,
      );
      if (Object.keys(editMetadata).length > 0 || sourceStoredFilename) {
        await savePhotoEditMetadata(photoId, editMetadata, {
          sourceFileName: sourceStoredFilename,
        });
      }
      await notifyTaggedUsers(taggedUserIds, [], req.session.userId, photoId);

      res.json({
        ok: true,
        id: photoId,
        file: storedFilename,
        categoryId,
        groupKey: albumGroupKey,
        groupIndex: albumGroupKey ? albumGroupIndex : 0,
        active: !requireApproval,
        requiresApproval: requireApproval,
      });
    } catch (error) {
      console.error(error);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.post('/api/album/upload-batch', (req, res, next) => {
    if (!req.session.userId) return res.status(401).send('Login required');
    return runAlbumUpload(req, res, next, [
      { name: 'files', maxCount: 20 },
      { name: 'sourceFiles', maxCount: 20 },
    ]);
  }, async (req, res) => {
    try {
      await schemaReady;
      const viewer = await findViewer(req.session.userId);
      if (!viewer || Number(viewer.verified || 0) !== 1) {
        return res.status(403).json({ error: 'VERIFICATION_REQUIRED', message: 'Yazma işlemleri için önce profilinizi doğrulamanız gerekiyor.' });
      }
      const currentUser = getCurrentUser(req);
      const categoryId = normalizeIntegerId(resolveRequestedCategoryId(req));
      const description = formatUserText(req.body?.aciklama || req.body?.description || '');
      const allowComments = isTruthy(req.body?.yorumlaraIzin ?? req.body?.allowComments ?? true);
      const taggedUserIds = parseIdArray(req.body?.taggedUserIds);
      const titles = parseJsonArrayField(req.body?.titles).map((item) =>
        sanitizePlainUserText(String(item || '').trim(), 255),
      );
      const metadataList = parseJsonArrayField(req.body?.metadataList).map((item) =>
        parseJsonObjectField(item),
      );
      const files = getUploadFieldFiles(req, 'files');
      const sourceFiles = getUploadFieldFiles(req, 'sourceFiles');

      if (!categoryId) return res.status(400).send('Albüm seçmelisin.');
      if (!files.length) return res.status(400).send('En az bir görsel seçmelisin.');

      const categoryContext = await loadCategoryContext(categoryId, viewer, currentUser);
      if (categoryContext.error) {
        return res.status(categoryContext.error.status).send(categoryContext.error.message);
      }
      if (!(await canUploadToCategory(categoryContext.category, viewer, currentUser))) {
        return res.status(403).send('Bu albüme fotoğraf ekleme yetkin yok.');
      }

      const createdItems = [];
      let lastStoredFilename = '';
      const now = new Date().toISOString();
      const groupKey = files.length > 1 ? randomUUID() : null;
      const sharedTitle = titles.find((item) => String(item || '').trim()) || '';
      for (let index = 0; index < files.length; index += 1) {
        const file = files[index];
        const processed = await processDiskImageUpload({
          req,
          res,
          file,
          bucket: 'album_photo',
          preset: uploadImagePresets.albumPhoto,
        });
        if (!processed.ok) {
          return res.status(processed.statusCode).send(processed.message);
        }

        const storedFilename = path.basename(processed.path || file.path);
        lastStoredFilename = storedFilename;
        const fallbackTitle = String(file.originalname || 'Fotoğraf')
          .replace(/\.[^.]+$/, '')
          .trim();
        const title = sharedTitle || fallbackTitle || `Fotoğraf ${index + 1}`;
        let result;
        if (isPostgres) {
          result = await sqlRunAsync(
            `INSERT INTO ${photoTable}
              (category_id, file_name, title, description, is_active, uploaded_by_user_id, created_at, updated_at, view_count, allow_comments, tagged_user_ids_json, album_group_key, album_group_index)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
            [
              categoryId,
              storedFilename,
              title,
              description,
              true,
              req.session.userId,
              now,
              now,
              0,
              boolValue(allowComments),
              JSON.stringify(taggedUserIds),
              groupKey,
              groupKey ? index : 0,
            ],
          );
        } else {
          result = await sqlRunAsync(
            `INSERT INTO ${photoTable}
              (katid, dosyaadi, baslik, aciklama, aktif, ekleyenid, tarih, updated_at, hit, allow_comments, tagged_user_ids_json, album_group_key, album_group_index)
             VALUES (CAST(? AS INTEGER), ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
            [
              categoryId,
              storedFilename,
              title,
              description,
              1,
              req.session.userId,
              now,
              now,
              0,
              boolValue(allowComments),
              JSON.stringify(taggedUserIds),
              groupKey,
              groupKey ? index : 0,
            ],
          );
        }
        const photoId = Number(result?.lastInsertRowid || result?.insertId || 0);
        await ensurePhotoCategory(photoId, categoryId);
        const metadata = metadataList[index] || {};
        const sourceStoredFilename = path.basename(
          sourceFiles[index]?.path || processed.path || file.path,
        );
        if (Object.keys(metadata).length > 0 || sourceStoredFilename) {
          await savePhotoEditMetadata(photoId, metadata, {
            sourceFileName: sourceStoredFilename,
          });
        }
        await notifyTaggedUsers(taggedUserIds, [], req.session.userId, photoId);
        createdItems.push({
          id: photoId,
          file: storedFilename,
          title,
          groupKey: groupKey || '',
          groupIndex: groupKey ? index : 0,
        });
      }

      if (isPostgres) {
        await sqlRunAsync(
          `UPDATE ${categoryTable}
           SET last_upload_at = ?, last_uploaded_by_user_id = ?, cover_file_name = COALESCE(?, cover_file_name)
           WHERE id = ?`,
          [now, req.session.userId, lastStoredFilename || null, categoryId],
        );
      } else {
        await sqlRunAsync(
          `UPDATE ${categoryTable}
           SET sonekleme = ?, sonekleyen = ?, cover_file_name = COALESCE(?, cover_file_name)
           WHERE id = ?`,
          [now, req.session.userId, lastStoredFilename || null, categoryId],
        );
      }

      res.json({
        ok: true,
        count: createdItems.length,
        items: createdItems,
        groupKey: groupKey || '',
        categoryId,
      });
    } catch (error) {
      console.error(error);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.get('/api/albums/:id', async (req, res) => {
    try {
      await schemaReady;
      if (!req.session.userId) return res.status(401).send('Login required');
      const page = Math.max(Number.parseInt(String(req.query.page || '1'), 10) || 1, 1);
      const pageSize = Math.min(Math.max(Number.parseInt(String(req.query.pageSize || '24'), 10) || 24, 1), 60);
      const viewer = await findViewer(req.session.userId);
      const currentUser = getCurrentUser(req);
      const context = await loadCategoryContext(Number(req.params.id || 0), viewer, currentUser);
      if (context.error) return res.status(context.error.status).send(context.error.message);

      const totalRow = await sqlGetAsync(
        `SELECT COUNT(*) AS cnt
         FROM ${photoTable} p
         WHERE p.${isPostgres ? 'category_id' : 'katid'} = ?
           AND ${photoActiveSql}`,
        [req.params.id],
      );
      const total = Number(totalRow?.cnt || 0);
      const pages = Math.max(Math.ceil(total / pageSize), 1);
      const safePage = Math.min(page, pages);
      const offset = (safePage - 1) * pageSize;
      const rows = await sqlAllAsync(
        `SELECT ${photoSelect('p')}
         FROM ${photoTable} p
         WHERE p.${isPostgres ? 'category_id' : 'katid'} = ?
           AND ${photoActiveSql}
         ORDER BY p.${isPostgres ? 'created_at' : 'tarih'} DESC, p.id DESC
         LIMIT ? OFFSET ?`,
        [req.params.id, pageSize, offset],
      );

      const photos = [];
      const seenPhotoGroups = new Set();
      for (const row of rows) {
        const groupKey = String(row.album_group_key || '').trim();
        const dedupeKey = groupKey ? `group:${groupKey}` : `photo:${row.id}`;
        if (seenPhotoGroups.has(dedupeKey)) continue;
        seenPhotoGroups.add(dedupeKey);
        const group = await getPhotoGroupContext(row);
        const displayPhoto = group.canonical || row;
        const aggregateIds = group.ids.length ? group.ids : [row.id];
        const placeholders = sqlInPlaceholders(aggregateIds);
        const likeCountRow = await sqlGetAsync(
          `SELECT COUNT(DISTINCT user_id) AS cnt FROM ${likeTable} WHERE photo_id IN (${placeholders})`,
          aggregateIds,
        );
        const commentCountRow = await sqlGetAsync(
          `SELECT COUNT(*) AS cnt FROM ${commentTable} WHERE ${isPostgres ? 'photo_id' : 'fotoid'} IN (${placeholders})`,
          aggregateIds,
        );
        photos.push({
          id: Number(displayPhoto.id || 0),
          dosyaadi: displayPhoto.file_name || '',
          media: await buildAlbumPhotoMediaPayload(displayPhoto),
          baslik: displayPhoto.title || 'Fotoğraf',
          tarih: displayPhoto.created_at || '',
          viewCount: Number(displayPhoto.view_count || 0),
          likeCount: Number(likeCountRow?.cnt || 0),
          commentCount: Number(commentCountRow?.cnt || 0),
          allowComments: isTruthy(displayPhoto.allow_comments),
          groupKey,
          groupCount: group.ids.length,
          groupIndex: Number(displayPhoto.album_group_index || 0),
        });
      }

      const summary = await summarizeCategory(context.category, viewer, currentUser);
      res.json({
        category: {
          ...summary,
          id: context.category.id,
        },
        photos,
        allowedMembers: (await listCategoryPermissionMembers(context.category.id)).map((row) => ({
          id: Number(row.id || 0),
          kadi: row.kadi || '',
          isim: row.isim || '',
          soyisim: row.soyisim || '',
          resim: row.resim || '',
          verified: isTruthy(row.verified),
          mezuniyetyili: row.mezuniyetyili || '',
          role: row.role || 'user',
        })),
        allowedGroups: await listCategoryPermissionGroups(context.category.id),
        page: safePage,
        pages,
        total,
        pageSize,
      });
    } catch (error) {
      console.error(error);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.get('/api/photos/:id', async (req, res) => {
    try {
      await schemaReady;
      if (!req.session.userId) return res.status(401).send('Login required');
      const viewer = await findViewer(req.session.userId);
      const currentUser = getCurrentUser(req);
      const context = await loadPhotoContext(Number(req.params.id || 0), viewer, currentUser);
      if (context.error) return res.status(context.error.status).send(context.error.message);
      const group = await getPhotoGroupContext(context.photo);
      const aggregateIds = group.ids.length ? group.ids : [context.photo.id];
      const placeholders = sqlInPlaceholders(aggregateIds);

      const canEditPhoto = sameUserId(context.photo.uploaded_by_user_id, req.session.userId) || hasCategoryManagementAccess(currentUser);
      if (isPostgres) {
        await sqlRunAsync(`UPDATE ${photoTable} SET view_count = COALESCE(view_count, 0) + 1 WHERE id = ?`, [context.photo.id]);
      } else {
        await sqlRunAsync(`UPDATE ${photoTable} SET hit = COALESCE(hit, 0) + 1 WHERE id = ?`, [context.photo.id]);
      }
      logUserActivity?.(req, {
        userId: req.session.userId,
        eventType: 'photo_view',
        targetType: 'photo',
        targetId: context.photo.id,
        metadata: {
          title: context.photo.title || '',
          fileName: context.photo.file_name || '',
          categoryId: Number(context.photo.category_id || 0),
          ownerUserId: normalizeUserId(context.photo.uploaded_by_user_id)
        }
      });

      const likeCountRow = await sqlGetAsync(
        `SELECT COUNT(DISTINCT user_id) AS cnt FROM ${likeTable} WHERE photo_id IN (${placeholders})`,
        aggregateIds,
      );
      const commentCountRow = await sqlGetAsync(
        `SELECT COUNT(*) AS cnt FROM ${commentTable} WHERE ${isPostgres ? 'photo_id' : 'fotoid'} IN (${placeholders})`,
        aggregateIds,
      );
      const likedRow = await sqlGetAsync(
        `SELECT id FROM ${likeTable} WHERE photo_id IN (${placeholders}) AND user_id = ? LIMIT 1`,
        [...aggregateIds, req.session.userId],
      );
      const taggedUsers = await readTaggedUsers(parseStringArrayJson(context.photo.tagged_user_ids_json));
      const editState = await getPhotoEditState(context.photo.id);
      const rowMedia = await buildAlbumPhotoMediaPayload(context.photo, editState);
      const groupPhotos = [];
      for (const item of group.photos) {
        const itemEditState = Number(item.id || 0) === Number(context.photo.id || 0)
          ? editState
          : await getPhotoEditState(item.id);
        const itemMedia = await buildAlbumPhotoMediaPayload(item, itemEditState);
        groupPhotos.push({
          id: Number(item.id || 0),
          fileName: item.file_name || '',
          title: item.title || 'Fotoğraf',
          groupIndex: Number(item.album_group_index || 0),
          media: itemMedia,
          editMetadata: itemMedia.editMetadata,
          editSourceFileName: itemMedia.editSourceFileName,
        });
      }

      res.json({
        row: {
          id: Number(context.photo.id || 0),
          katid: Number(context.photo.category_id || 0),
          dosyaadi: context.photo.file_name || '',
          media: rowMedia,
          baslik: context.photo.title || 'Fotoğraf',
          aciklama: context.photo.description || '',
          tarih: context.photo.created_at || '',
          updatedAt: context.photo.updated_at || '',
          hit: Number(context.photo.view_count || 0) + 1,
          allowComments: isTruthy(context.photo.allow_comments),
          likeCount: Number(likeCountRow?.cnt || 0),
          commentCount: Number(commentCountRow?.cnt || 0),
          liked: !!likedRow,
          ekleyenid: normalizeUserId(context.photo.uploaded_by_user_id),
          groupKey: context.photo.album_group_key || '',
          groupIndex: Number(context.photo.album_group_index || 0),
          groupCount: group.ids.length,
        },
        groupPhotos,
        category: await summarizeCategory(context.category, viewer, currentUser),
        taggedUsers: taggedUsers.map((row) => ({
          id: Number(row.id || 0),
          kadi: row.kadi || '',
          isim: row.isim || '',
          soyisim: row.soyisim || '',
          resim: row.resim || '',
        })),
        permissions: {
          canEditPhoto,
          canToggleComments: canEditPhoto,
          canBulkDeleteComments: canEditPhoto,
        },
        editMetadata: editState.metadata,
        editSourceFileName: editState.sourceFileName,
      });
    } catch (error) {
      console.error(error);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.patch('/api/photos/:id', async (req, res) => {
    try {
      await schemaReady;
      if (!req.session.userId) return res.status(401).send('Login required');
      const viewer = await findViewer(req.session.userId);
      const currentUser = getCurrentUser(req);
      const context = await loadPhotoContext(Number(req.params.id || 0), viewer, currentUser);
      if (context.error) return res.status(context.error.status).send(context.error.message);
      const group = await getPhotoGroupContext(context.photo);
      const aggregateIds = group.ids.length ? group.ids : [context.photo.id];
      const placeholders = sqlInPlaceholders(aggregateIds);
      const canEditPhoto = sameUserId(context.photo.uploaded_by_user_id, req.session.userId) || hasCategoryManagementAccess(currentUser);
      if (!canEditPhoto) return res.status(403).send('Bu fotoğrafı düzenleme yetkin yok.');

      const title = sanitizePlainUserText(
        String(req.body?.baslik || req.body?.title || context.photo.title || '').trim(),
        255,
      );
      const description = formatUserText(req.body?.aciklama || req.body?.description || context.photo.description || '');
      const allowComments = isTruthy(req.body?.yorumlaraIzin ?? req.body?.allowComments ?? context.photo.allow_comments);
      const taggedUserIds = parseIdArray(
        typeof req.body?.taggedUserIds === 'undefined'
          ? parseStringArrayJson(context.photo.tagged_user_ids_json)
          : req.body?.taggedUserIds,
      );
      const editMetadata = parseJsonObjectField(req.body?.editMetadata);

      if (!title) return res.status(400).send('Fotoğraf başlığı zorunlu.');

      if (isPostgres) {
        await sqlRunAsync(
          `UPDATE ${photoTable}
           SET title = ?, description = ?, allow_comments = ?, tagged_user_ids_json = ?, updated_at = ?
           WHERE id IN (${placeholders})`,
          [
            title,
            description,
            boolValue(allowComments),
            JSON.stringify(taggedUserIds),
            new Date().toISOString(),
            ...aggregateIds,
          ],
        );
      } else {
        await sqlRunAsync(
          `UPDATE ${photoTable}
           SET baslik = ?, aciklama = ?, allow_comments = ?, tagged_user_ids_json = ?, updated_at = ?
           WHERE id IN (${placeholders})`,
          [
            title,
            description,
            boolValue(allowComments),
            JSON.stringify(taggedUserIds),
            new Date().toISOString(),
            ...aggregateIds,
          ],
        );
      }

      await notifyTaggedUsers(
        taggedUserIds,
        parseStringArrayJson(context.photo.tagged_user_ids_json),
        req.session.userId,
        context.photo.id,
      );
      if (Object.keys(editMetadata).length > 0) {
        await savePhotoEditMetadata(context.photo.id, editMetadata);
      }

      res.json({ ok: true });
    } catch (error) {
      console.error(error);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  // Replace the actual photo file while keeping all metadata/comments/likes.
  app.put('/api/photos/:id/file', (req, res, next) => {
    if (!req.session.userId) return res.status(401).send('Login required');
    return runAlbumUpload(req, res, next, [
      { name: 'file', maxCount: 1 },
      { name: 'sourceFile', maxCount: 1 },
    ]);
  }, async (req, res) => {
    try {
      await schemaReady;
      const viewer = await findViewer(req.session.userId);
      const currentUser = getCurrentUser(req);
      const context = await loadPhotoContext(Number(req.params.id || 0), viewer, currentUser);
      if (context.error) return res.status(context.error.status).send(context.error.message);
      const hasRequestedGroupIndex = typeof req.body?.albumGroupIndex !== 'undefined';
      const requestedGroupIndex = normalizeIntegerId(req.body?.albumGroupIndex);
      let targetPhoto = context.photo;
      if (hasRequestedGroupIndex) {
        const group = await getPhotoGroupContext(context.photo);
        const indexedTarget = group.photos.find((item) => (
          Number(item.album_group_index || 0) === requestedGroupIndex
        ));
        if (!indexedTarget) {
          return res.status(400).send('Düzenlenecek grup fotoğrafı bulunamadı.');
        }
        targetPhoto = indexedTarget;
      }

      const canEditPhoto =
        sameUserId(targetPhoto.uploaded_by_user_id, req.session.userId) ||
        hasCategoryManagementAccess(currentUser);
      if (!canEditPhoto) return res.status(403).send('Bu fotoğrafı düzenleme yetkin yok.');
      const uploadFile = getUploadFieldFile(req, 'file');
      const sourceUploadFile = getUploadFieldFile(req, 'sourceFile');
      if (!uploadFile?.filename) return res.status(400).send('Geçerli bir resim dosyası girmedin.');
      const editMetadata = parseJsonObjectField(req.body?.editMetadata);

      const processed = await processDiskImageUpload({
        req,
        res,
        file: uploadFile,
        bucket: 'album_photo',
        preset: uploadImagePresets.albumPhoto,
      });
      if (!processed.ok) return res.status(processed.statusCode).send(processed.message);

      const storedFilename = path.basename(processed.path || uploadFile.path);
      const now = new Date().toISOString();

      if (isPostgres) {
        await sqlRunAsync(
          `UPDATE ${photoTable} SET file_name = ?, updated_at = ? WHERE id = ?`,
          [storedFilename, now, targetPhoto.id],
        );
        await sqlRunAsync(
          `UPDATE ${categoryTable} SET last_upload_at = ?, last_uploaded_by_user_id = ?, cover_file_name = COALESCE(?, cover_file_name) WHERE id = ?`,
          [now, req.session.userId, storedFilename, targetPhoto.category_id],
        );
      } else {
        await sqlRunAsync(
          `UPDATE ${photoTable} SET dosyaadi = ?, updated_at = ? WHERE id = ?`,
          [storedFilename, now, targetPhoto.id],
        );
        await sqlRunAsync(
          `UPDATE ${categoryTable} SET sonekleme = ?, sonekleyen = ?, cover_file_name = COALESCE(?, cover_file_name) WHERE id = ?`,
          [now, req.session.userId, storedFilename, targetPhoto.category_id],
        );
      }

      const sourceStoredFilename = path.basename(
        sourceUploadFile?.path || processed.path || uploadFile.path,
      );
      if (Object.keys(editMetadata).length > 0 || sourceStoredFilename) {
        await savePhotoEditMetadata(targetPhoto.id, editMetadata, {
          sourceFileName: sourceStoredFilename,
        });
      }

      res.json({ ok: true, fileName: storedFilename });
    } catch (error) {
      console.error(error);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.delete('/api/photos/:id', async (req, res) => {
    try {
      await schemaReady;
      if (!req.session.userId) return res.status(401).send('Login required');
      const viewer = await findViewer(req.session.userId);
      const currentUser = getCurrentUser(req);
      const context = await loadPhotoContext(
        Number(req.params.id || 0),
        viewer,
        currentUser,
      );
      if (context.error) {
        return res.status(context.error.status).send(context.error.message);
      }
      const group = await getPhotoGroupContext(context.photo);
      const aggregateIds = group.ids.length ? group.ids : [context.photo.id];
      const placeholders = sqlInPlaceholders(aggregateIds);

      const canEditPhoto =
        sameUserId(context.photo.uploaded_by_user_id, req.session.userId) ||
        hasCategoryManagementAccess(currentUser);
      if (!canEditPhoto) {
        return res.status(403).send('Bu fotoğrafı silme yetkin yok.');
      }

      await sqlRunAsync(
        `DELETE FROM ${likeTable} WHERE photo_id IN (${placeholders})`,
        aggregateIds,
      );
      await sqlRunAsync(
        `DELETE FROM ${editTable} WHERE photo_id IN (${placeholders})`,
        aggregateIds,
      );
      await sqlRunAsync(
        `DELETE FROM ${commentTable} WHERE ${isPostgres ? 'photo_id' : 'fotoid'} IN (${placeholders})`,
        aggregateIds,
      );
      await sqlRunAsync(`DELETE FROM ${photoTable} WHERE id IN (${placeholders})`, aggregateIds);
      await sqlRunAsync(
        `UPDATE ${categoryTable}
         SET cover_mode = 'latest',
             cover_file_name = NULL
         WHERE id = ?
           AND COALESCE(cover_file_name, '') IN (${sqlInPlaceholders(group.photos.map((item) => item.file_name || ''))})`,
        [
          context.category.id,
          ...group.photos.map((item) => item.file_name || ''),
        ],
      );

      res.json({ ok: true });
    } catch (error) {
      console.error(error);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.get('/api/photos/:id/comments', async (req, res) => {
    try {
      await schemaReady;
      if (!req.session.userId) return res.status(401).send('Login required');
      const viewer = await findViewer(req.session.userId);
      const currentUser = getCurrentUser(req);
      const context = await loadPhotoContext(Number(req.params.id || 0), viewer, currentUser);
      if (context.error) return res.status(context.error.status).send(context.error.message);
      const group = await getPhotoGroupContext(context.photo);
      const aggregateIds = group.ids.length ? group.ids : [context.photo.id];
      const placeholders = sqlInPlaceholders(aggregateIds);

      const canManageComments = sameUserId(context.photo.uploaded_by_user_id, req.session.userId) || hasCategoryManagementAccess(currentUser);
      const commentsHidden = !isTruthy(context.photo.allow_comments);
      if (commentsHidden && !canManageComments) {
        return res.json({ comments: [], hidden: true });
      }

      const rows = await sqlAllAsync(
        `SELECT c.id,
                COALESCE(c.${isPostgres ? 'author_user_id' : 'author_user_id'}, 0) AS user_id,
                COALESCE(c.${isPostgres ? 'author_username' : 'uyeadi'}, '') AS uyeadi,
                COALESCE(c.${isPostgres ? 'comment_body' : 'yorum'}, '') AS yorum,
                COALESCE(c.${isPostgres ? 'created_at::text' : 'tarih'}, '') AS tarih,
                COALESCE(c.${isPostgres ? 'updated_at::text' : 'updated_at'}, '') AS updated_at,
                ${userSelect('u')}
         FROM ${commentTable} c
         LEFT JOIN ${userTable} u ON u.id = c.${isPostgres ? 'author_user_id' : 'author_user_id'}
         WHERE c.${isPostgres ? 'photo_id' : 'fotoid'} IN (${placeholders})
         ORDER BY c.id DESC`,
        aggregateIds,
      );

      const comments = rows.map((row) => {
        const effectiveUserId = normalizeUserId(row.user_id);
        const isCommentAuthor = effectiveUserId && sameUserId(effectiveUserId, req.session.userId);
        return {
          id: Number(row.id || 0),
          user_id: effectiveUserId || 0,
          kadi: row.kadi || row.uyeadi || '',
          isim: row.isim || '',
          soyisim: row.soyisim || '',
          resim: row.resim || '',
          verified: Number(row.verified || 0) === 1,
          yorum: row.yorum || '',
          tarih: row.tarih || '',
          updatedAt: row.updated_at || '',
          canEdit: !!isCommentAuthor,
          canDelete: !!(isCommentAuthor || canManageComments),
        };
      });

      res.json({ comments, hidden: commentsHidden });
    } catch (error) {
      console.error(error);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.post('/api/photos/:id/comments', async (req, res) => {
    try {
      await schemaReady;
      if (!req.session.userId) return res.status(401).send('Login required');
      const viewer = await findViewer(req.session.userId);
      const currentUser = getCurrentUser(req);
      const context = await loadPhotoContext(Number(req.params.id || 0), viewer, currentUser);
      if (context.error) return res.status(context.error.status).send(context.error.message);
      const group = await getPhotoGroupContext(context.photo);
      if (!isTruthy(context.photo.allow_comments)) {
        return res.status(400).send('Fotoğraf şu anda yoruma kapalı.');
      }

      const rawComment = String(req.body?.yorum || req.body?.comment || '');
      const comment = formatUserText(rawComment);
      if (!comment) return res.status(400).send('Yorum girmedin.');
      const authorHandle = String(viewer?.kadi || currentUser?.kadi || 'Misafir').trim() || 'Misafir';
      const now = new Date().toISOString();

      if (isPostgres) {
        await sqlRunAsync(
          `INSERT INTO ${commentTable} (photo_id, author_username, author_user_id, comment_body, created_at, updated_at)
           VALUES (?, ?, ?, ?, ?, ?)`,
          [group.canonicalId, authorHandle, req.session.userId, comment, now, now],
        );
      } else {
        await sqlRunAsync(
          `INSERT INTO ${commentTable} (fotoid, uyeadi, author_user_id, yorum, tarih, updated_at)
           VALUES (?, ?, ?, ?, ?, ?)`,
          [group.canonicalId, authorHandle, req.session.userId, comment, now, now],
        );
      }

      const ownerId = normalizeUserId(context.photo.uploaded_by_user_id);
      if (ownerId && !sameUserId(ownerId, req.session.userId)) {
        addNotification({
          userId: ownerId,
          type: 'photo_comment',
          sourceUserId: req.session.userId,
          entityId: group.canonicalId,
          message: 'Fotoğrafına yorum yaptı.',
        });
      }

      notifyMentions({
        text: rawComment,
        sourceUserId: req.session.userId,
        entityId: group.canonicalId,
        type: 'mention_photo',
        message: 'Fotoğraf yorumunda senden bahsetti.',
      });

      res.json({ ok: true });
    } catch (error) {
      console.error(error);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.patch('/api/photos/:id/comments/:commentId', async (req, res) => {
    try {
      await schemaReady;
      if (!req.session.userId) return res.status(401).send('Login required');
      const viewer = await findViewer(req.session.userId);
      const currentUser = getCurrentUser(req);
      const context = await loadPhotoContext(Number(req.params.id || 0), viewer, currentUser);
      if (context.error) return res.status(context.error.status).send(context.error.message);
      const group = await getPhotoGroupContext(context.photo);
      const aggregateIds = group.ids.length ? group.ids : [context.photo.id];

      const commentId = Number(req.params.commentId || 0);
      const row = await sqlGetAsync(
        `SELECT id, ${isPostgres ? 'photo_id' : 'fotoid'} AS photo_id, author_user_id
         FROM ${commentTable}
         WHERE id = ?`,
        [commentId],
      );
      if (!row || !aggregateIds.includes(Number(row.photo_id || 0))) {
        return res.status(404).send('Yorum bulunamadı.');
      }
      if (!sameUserId(row.author_user_id, req.session.userId) && !hasCategoryManagementAccess(currentUser)) {
        return res.status(403).send('Bu yorumu düzenleme yetkin yok.');
      }

      const rawComment = String(req.body?.yorum || req.body?.comment || '');
      const comment = formatUserText(rawComment);
      if (!comment) return res.status(400).send('Yorum boş olamaz.');
      const now = new Date().toISOString();

      if (isPostgres) {
        await sqlRunAsync(
          `UPDATE ${commentTable}
           SET comment_body = ?, updated_at = ?
           WHERE id = ?`,
          [comment, now, commentId],
        );
      } else {
        await sqlRunAsync(
          `UPDATE ${commentTable}
           SET yorum = ?, updated_at = ?
           WHERE id = ?`,
          [comment, now, commentId],
        );
      }

      res.json({ ok: true });
    } catch (error) {
      console.error(error);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.delete('/api/photos/:id/comments/:commentId', async (req, res) => {
    try {
      await schemaReady;
      if (!req.session.userId) return res.status(401).send('Login required');
      const viewer = await findViewer(req.session.userId);
      const currentUser = getCurrentUser(req);
      const context = await loadPhotoContext(Number(req.params.id || 0), viewer, currentUser);
      if (context.error) return res.status(context.error.status).send(context.error.message);
      const group = await getPhotoGroupContext(context.photo);
      const aggregateIds = group.ids.length ? group.ids : [context.photo.id];

      const commentId = Number(req.params.commentId || 0);
      const row = await sqlGetAsync(
        `SELECT id, ${isPostgres ? 'photo_id' : 'fotoid'} AS photo_id, author_user_id
         FROM ${commentTable}
         WHERE id = ?`,
        [commentId],
      );
      if (!row || !aggregateIds.includes(Number(row.photo_id || 0))) {
        return res.status(404).send('Yorum bulunamadı.');
      }

      const canDelete = sameUserId(row.author_user_id, req.session.userId) ||
        sameUserId(context.photo.uploaded_by_user_id, req.session.userId) ||
        hasCategoryManagementAccess(currentUser);
      if (!canDelete) return res.status(403).send('Bu yorumu silme yetkin yok.');

      await sqlRunAsync(`DELETE FROM ${commentTable} WHERE id = ?`, [commentId]);
      res.json({ ok: true });
    } catch (error) {
      console.error(error);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.delete('/api/photos/:id/comments', async (req, res) => {
    try {
      await schemaReady;
      if (!req.session.userId) return res.status(401).send('Login required');
      const viewer = await findViewer(req.session.userId);
      const currentUser = getCurrentUser(req);
      const context = await loadPhotoContext(Number(req.params.id || 0), viewer, currentUser);
      if (context.error) return res.status(context.error.status).send(context.error.message);
      const group = await getPhotoGroupContext(context.photo);
      const aggregateIds = group.ids.length ? group.ids : [context.photo.id];
      const placeholders = sqlInPlaceholders(aggregateIds);

      const canDeleteAll = sameUserId(context.photo.uploaded_by_user_id, req.session.userId) ||
        hasCategoryManagementAccess(currentUser);
      if (!canDeleteAll) return res.status(403).send('Bu fotoğrafın yorumlarını topluca silemezsin.');

      await sqlRunAsync(
        `DELETE FROM ${commentTable} WHERE ${isPostgres ? 'photo_id' : 'fotoid'} IN (${placeholders})`,
        aggregateIds,
      );
      res.json({ ok: true });
    } catch (error) {
      console.error(error);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.post('/api/photos/:id/like', async (req, res) => {
    try {
      await schemaReady;
      if (!req.session.userId) return res.status(401).send('Login required');
      const viewer = await findViewer(req.session.userId);
      const currentUser = getCurrentUser(req);
      const context = await loadPhotoContext(Number(req.params.id || 0), viewer, currentUser);
      if (context.error) return res.status(context.error.status).send(context.error.message);
      const group = await getPhotoGroupContext(context.photo);
      const aggregateIds = group.ids.length ? group.ids : [context.photo.id];
      const placeholders = sqlInPlaceholders(aggregateIds);

      const existing = await sqlGetAsync(
        `SELECT id FROM ${likeTable} WHERE photo_id IN (${placeholders}) AND user_id = ? LIMIT 1`,
        [...aggregateIds, req.session.userId],
      );
      let liked = false;
      if (existing) {
        await sqlRunAsync(
          `DELETE FROM ${likeTable} WHERE photo_id IN (${placeholders}) AND user_id = ?`,
          [...aggregateIds, req.session.userId],
        );
      } else {
        liked = true;
        await sqlRunAsync(
          `INSERT INTO ${likeTable} (photo_id, user_id, created_at) VALUES (?, ?, ?)`,
          [group.canonicalId, req.session.userId, new Date().toISOString()],
        );
        const ownerId = normalizeUserId(context.photo.uploaded_by_user_id);
        if (ownerId && !sameUserId(ownerId, req.session.userId)) {
          addNotification({
            userId: ownerId,
            type: 'mention_photo',
            sourceUserId: req.session.userId,
            entityId: group.canonicalId,
            message: 'Fotoğrafını beğendi.',
          });
        }
      }
      res.json({ ok: true, liked });
    } catch (error) {
      console.error(error);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.get('/api/photos/:id/likes', async (req, res) => {
    try {
      await schemaReady;
      if (!req.session.userId) return res.status(401).send('Login required');
      const viewer = await findViewer(req.session.userId);
      const currentUser = getCurrentUser(req);
      const context = await loadPhotoContext(Number(req.params.id || 0), viewer, currentUser);
      if (context.error) return res.status(context.error.status).send(context.error.message);
      const group = await getPhotoGroupContext(context.photo);
      const aggregateIds = group.ids.length ? group.ids : [context.photo.id];
      const placeholders = sqlInPlaceholders(aggregateIds);

      const rows = await sqlAllAsync(
        `SELECT ${userSelect('u')}, l.created_at AS liked_at
         FROM ${likeTable} l
         JOIN ${userTable} u ON u.id = l.user_id
         WHERE l.photo_id IN (${placeholders})
         ORDER BY l.created_at DESC, l.id DESC`,
        aggregateIds,
      );
      const seenLikeUsers = new Set();
      res.json({
        items: rows.filter((row) => {
          const id = Number(row.id || 0);
          if (!id || seenLikeUsers.has(id)) return false;
          seenLikeUsers.add(id);
          return true;
        }).map((row) => ({
          id: Number(row.id || 0),
          username: row.kadi || '',
          firstName: row.isim || '',
          lastName: row.soyisim || '',
          avatarUrl: row.resim || '',
          graduationYear: row.mezuniyetyili ? Number(row.mezuniyetyili) || null : null,
        })),
      });
    } catch (error) {
      console.error(error);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });
}
