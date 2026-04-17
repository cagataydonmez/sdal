import path from 'path';

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
}) {
  const isPostgres = dbDriver === 'postgres';
  const boolValue = (value) => (isPostgres ? !!value : (value ? 1 : 0));
  const categoryTable = isPostgres ? 'album_categories' : 'album_kat';
  const photoTable = isPostgres ? 'album_photos' : 'album_foto';
  const commentTable = isPostgres ? 'album_photo_comments' : 'album_fotoyorum';
  const likeTable = 'album_photo_likes';
  const permissionTable = 'album_category_permissions';
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
       COALESCE(${alias}.cover_file_name, '') AS cover_file_name`
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
       COALESCE(${alias}.cover_file_name, '') AS cover_file_name`;

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
       COALESCE(${alias}.tagged_user_ids_json, '[]') AS tagged_user_ids_json`
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
       COALESCE(${alias}.tagged_user_ids_json, '[]') AS tagged_user_ids_json`;

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

  async function ensureAlbumSchema() {
    if (isPostgres) return;

    const statements = [
      "ALTER TABLE album_kat ADD COLUMN visibility_scope TEXT DEFAULT 'public'",
      "ALTER TABLE album_kat ADD COLUMN cohort_year TEXT",
      "ALTER TABLE album_kat ADD COLUMN album_type TEXT DEFAULT 'general'",
      'ALTER TABLE album_kat ADD COLUMN owner_user_id INTEGER',
      'ALTER TABLE album_kat ADD COLUMN is_system_album INTEGER DEFAULT 0',
      'ALTER TABLE album_kat ADD COLUMN cover_file_name TEXT',
      'ALTER TABLE album_foto ADD COLUMN allow_comments INTEGER DEFAULT 1',
      'ALTER TABLE album_foto ADD COLUMN updated_at TEXT',
      "ALTER TABLE album_foto ADD COLUMN tagged_user_ids_json TEXT DEFAULT '[]'",
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

  async function summarizeCategory(category, viewer, currentUser) {
    const countRow = await sqlGetAsync(
      `SELECT COUNT(*) AS cnt
       FROM ${photoTable} p
       WHERE p.${isPostgres ? 'category_id' : 'katid'} = ?
         AND ${photoActiveSql}`,
      [category.id],
    );
    const previews = await sqlAllAsync(
      `SELECT COALESCE(p.${isPostgres ? 'file_name' : 'dosyaadi'}, '') AS file_name
       FROM ${photoTable} p
       WHERE p.${isPostgres ? 'category_id' : 'katid'} = ?
         AND ${photoActiveSql}
       ORDER BY p.${isPostgres ? 'created_at' : 'tarih'} DESC, p.id DESC
       LIMIT 5`,
      [category.id],
    );

    return {
      id: Number(category.id || 0),
      kategori: category.title || 'Albüm',
      aciklama: category.description || '',
      count: Number(countRow?.cnt || 0),
      previews: previews.map((item) => item.file_name).filter(Boolean),
      visibilityScope: String(category.visibility_scope || 'public'),
      cohortYear: String(category.cohort_year || ''),
      albumType: String(category.album_type || 'general'),
      ownerUserId: normalizeUserId(category.owner_user_id),
      isSystemAlbum: isTruthy(category.is_system_album),
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
    const placeholders = categoryIds.map(() => '?').join(', ');
    const rows = await sqlAllAsync(
      `SELECT ${photoSelect('p')},
              COALESCE(${isPostgres ? 'c.name' : 'c.kategori'}, '') AS category_title
       FROM ${photoTable} p
       JOIN ${categoryTable} c ON c.id = p.${isPostgres ? 'category_id' : 'katid'}
       WHERE p.${isPostgres ? 'category_id' : 'katid'} IN (${placeholders})
         AND ${photoActiveSql}
       ORDER BY ${orderBy}
       LIMIT ?`,
      [...categoryIds, limit],
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

  app.get('/api/albums', async (req, res) => {
    try {
      await schemaReady;
      if (!req.session.userId) return res.status(401).send('Login required');
      const viewer = await findViewer(req.session.userId);
      const currentUser = getCurrentUser(req);
      const categories = await listAccessibleCategories(viewer, currentUser);

      // Recompute counts with a reliable batch query (summarizeCategory's per-row
      // count can return 0 due to pg BIGINT id coercion; batch GROUP BY is reliable).
      const validIds = categories.map((item) => item.id).filter(Boolean);
      if (validIds.length > 0) {
        const placeholders = validIds.map(() => '?').join(', ');
        const countRows = await sqlAllAsync(
          `SELECT p.${isPostgres ? 'category_id' : 'katid'} AS cid, COUNT(*) AS cnt
           FROM ${photoTable} p
           WHERE p.${isPostgres ? 'category_id' : 'katid'} IN (${placeholders})
             AND ${photoActiveSql}
           GROUP BY p.${isPostgres ? 'category_id' : 'katid'}`,
          validIds,
        );
        const countsMap = {};
        for (const row of countRows) {
          countsMap[String(row.cid)] = Number(row.cnt || 0);
        }
        for (const cat of categories) {
          cat.count = countsMap[String(cat.id)] ?? 0;
        }
      }

      const categoryIds = validIds.filter((value) => Number(value) > 0);
      const latest = await listPhotoCards(categoryIds, req.session.userId, {
        orderBy: `p.${isPostgres ? 'created_at' : 'tarih'} DESC, p.id DESC`,
        limit: 10,
      });
      const popular = await listPhotoCards(categoryIds, req.session.userId, {
        orderBy: `COALESCE(p.${isPostgres ? 'view_count' : 'hit'}, 0) DESC, p.${isPostgres ? 'created_at' : 'tarih'} DESC, p.id DESC`,
        limit: 10,
      });
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

      const requestedCohort = String(req.body?.cohortYear || req.body?.cohort || viewer?.mezuniyetyili || '').trim();
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
    return albumUpload.single('file')(req, res, (error) => {
      if (error) return next(error);
      next();
    });
  }, async (req, res) => {
    try {
      await schemaReady;
      const viewer = await findViewer(req.session.userId);
      const currentUser = getCurrentUser(req);
      const categoryId = Number.parseInt(
        String(req.body?.kat || req.body?.categoryId || '').trim(),
        10,
      );
      const title = sanitizePlainUserText(String(req.body?.baslik || req.body?.title || '').trim(), 255);
      const description = formatUserText(req.body?.aciklama || req.body?.description || '');
      const allowComments = isTruthy(req.body?.yorumlaraIzin ?? req.body?.allowComments ?? true);
      const taggedUserIds = parseIdArray(req.body?.taggedUserIds);

      if (!title) return res.status(400).send('Yüklemek üzere olduğun fotoğraf için bir başlık girmen gerekiyor.');
      if (!categoryId) return res.status(400).send('Albüm seçmelisin.');
      if (!req.file?.filename) return res.status(400).send('Geçerli bir resim dosyası girmedin.');

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
        file: req.file,
        bucket: 'album_photo',
        preset: uploadImagePresets.albumPhoto,
      });
      if (!processed.ok) return res.status(processed.statusCode).send(processed.message);

      const storedFilename = path.basename(processed.path || req.file.path);
      const requireApproval = false;
      const activeValue = boolValue(!requireApproval);
      const now = new Date().toISOString();
      let result;

      if (isPostgres) {
        result = await sqlRunAsync(
          `INSERT INTO ${photoTable}
            (category_id, file_name, title, description, is_active, uploaded_by_user_id, created_at, updated_at, view_count, allow_comments, tagged_user_ids_json)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
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
            (katid, dosyaadi, baslik, aciklama, aktif, ekleyenid, tarih, updated_at, hit, allow_comments, tagged_user_ids_json)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
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
      await notifyTaggedUsers(taggedUserIds, [], req.session.userId, photoId);

      res.json({
        ok: true,
        id: photoId,
        file: storedFilename,
        categoryId,
        active: !requireApproval,
        requiresApproval: requireApproval,
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
      for (const row of rows) {
        const likeCountRow = await sqlGetAsync(`SELECT COUNT(*) AS cnt FROM ${likeTable} WHERE photo_id = ?`, [row.id]);
        const commentCountRow = await sqlGetAsync(
          `SELECT COUNT(*) AS cnt FROM ${commentTable} WHERE ${isPostgres ? 'photo_id' : 'fotoid'} = ?`,
          [row.id],
        );
        photos.push({
          id: Number(row.id || 0),
          dosyaadi: row.file_name || '',
          baslik: row.title || 'Fotoğraf',
          tarih: row.created_at || '',
          viewCount: Number(row.view_count || 0),
          likeCount: Number(likeCountRow?.cnt || 0),
          commentCount: Number(commentCountRow?.cnt || 0),
          allowComments: isTruthy(row.allow_comments),
        });
      }

      const summary = await summarizeCategory(context.category, viewer, currentUser);
      res.json({
        category: {
          ...summary,
          id: context.category.id,
        },
        photos,
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

      const canEditPhoto = sameUserId(context.photo.uploaded_by_user_id, req.session.userId) || hasCategoryManagementAccess(currentUser);
      if (isPostgres) {
        await sqlRunAsync(`UPDATE ${photoTable} SET view_count = COALESCE(view_count, 0) + 1 WHERE id = ?`, [context.photo.id]);
      } else {
        await sqlRunAsync(`UPDATE ${photoTable} SET hit = COALESCE(hit, 0) + 1 WHERE id = ?`, [context.photo.id]);
      }

      const likeCountRow = await sqlGetAsync(`SELECT COUNT(*) AS cnt FROM ${likeTable} WHERE photo_id = ?`, [context.photo.id]);
      const commentCountRow = await sqlGetAsync(
        `SELECT COUNT(*) AS cnt FROM ${commentTable} WHERE ${isPostgres ? 'photo_id' : 'fotoid'} = ?`,
        [context.photo.id],
      );
      const likedRow = await sqlGetAsync(
        `SELECT id FROM ${likeTable} WHERE photo_id = ? AND user_id = ? LIMIT 1`,
        [context.photo.id, req.session.userId],
      );
      const taggedUsers = await readTaggedUsers(parseStringArrayJson(context.photo.tagged_user_ids_json));

      res.json({
        row: {
          id: Number(context.photo.id || 0),
          katid: Number(context.photo.category_id || 0),
          dosyaadi: context.photo.file_name || '',
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
        },
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

      if (!title) return res.status(400).send('Fotoğraf başlığı zorunlu.');

      if (isPostgres) {
        await sqlRunAsync(
          `UPDATE ${photoTable}
           SET title = ?, description = ?, allow_comments = ?, tagged_user_ids_json = ?, updated_at = ?
           WHERE id = ?`,
          [
            title,
            description,
            boolValue(allowComments),
            JSON.stringify(taggedUserIds),
            new Date().toISOString(),
            context.photo.id,
          ],
        );
      } else {
        await sqlRunAsync(
          `UPDATE ${photoTable}
           SET baslik = ?, aciklama = ?, allow_comments = ?, tagged_user_ids_json = ?, updated_at = ?
           WHERE id = ?`,
          [
            title,
            description,
            boolValue(allowComments),
            JSON.stringify(taggedUserIds),
            new Date().toISOString(),
            context.photo.id,
          ],
        );
      }

      await notifyTaggedUsers(
        taggedUserIds,
        parseStringArrayJson(context.photo.tagged_user_ids_json),
        req.session.userId,
        context.photo.id,
      );

      res.json({ ok: true });
    } catch (error) {
      console.error(error);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  // Replace the actual photo file while keeping all metadata/comments/likes.
  app.put('/api/photos/:id/file', (req, res, next) => {
    if (!req.session.userId) return res.status(401).send('Login required');
    return albumUpload.single('file')(req, res, (error) => {
      if (error) return next(error);
      next();
    });
  }, async (req, res) => {
    try {
      await schemaReady;
      const viewer = await findViewer(req.session.userId);
      const currentUser = getCurrentUser(req);
      const context = await loadPhotoContext(Number(req.params.id || 0), viewer, currentUser);
      if (context.error) return res.status(context.error.status).send(context.error.message);

      const canEditPhoto =
        sameUserId(context.photo.uploaded_by_user_id, req.session.userId) ||
        hasCategoryManagementAccess(currentUser);
      if (!canEditPhoto) return res.status(403).send('Bu fotoğrafı düzenleme yetkin yok.');
      if (!req.file?.filename) return res.status(400).send('Geçerli bir resim dosyası girmedin.');

      const processed = await processDiskImageUpload({
        req,
        res,
        file: req.file,
        bucket: 'album_photo',
        preset: uploadImagePresets.albumPhoto,
      });
      if (!processed.ok) return res.status(processed.statusCode).send(processed.message);

      const storedFilename = path.basename(processed.path || req.file.path);
      const now = new Date().toISOString();

      if (isPostgres) {
        await sqlRunAsync(
          `UPDATE ${photoTable} SET file_name = ?, updated_at = ? WHERE id = ?`,
          [storedFilename, now, context.photo.id],
        );
        await sqlRunAsync(
          `UPDATE ${categoryTable} SET last_upload_at = ?, last_uploaded_by_user_id = ?, cover_file_name = COALESCE(?, cover_file_name) WHERE id = ?`,
          [now, req.session.userId, storedFilename, context.photo.category_id],
        );
      } else {
        await sqlRunAsync(
          `UPDATE ${photoTable} SET dosyaadi = ?, updated_at = ? WHERE id = ?`,
          [storedFilename, now, context.photo.id],
        );
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

      const canEditPhoto =
        sameUserId(context.photo.uploaded_by_user_id, req.session.userId) ||
        hasCategoryManagementAccess(currentUser);
      if (!canEditPhoto) {
        return res.status(403).send('Bu fotoğrafı silme yetkin yok.');
      }

      await sqlRunAsync(
        `DELETE FROM ${likeTable} WHERE photo_id = ?`,
        [context.photo.id],
      );
      await sqlRunAsync(
        `DELETE FROM ${commentTable} WHERE ${isPostgres ? 'photo_id' : 'fotoid'} = ?`,
        [context.photo.id],
      );
      await sqlRunAsync(`DELETE FROM ${photoTable} WHERE id = ?`, [context.photo.id]);

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
         WHERE c.${isPostgres ? 'photo_id' : 'fotoid'} = ?
         ORDER BY c.id DESC`,
        [context.photo.id],
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
          [context.photo.id, authorHandle, req.session.userId, comment, now, now],
        );
      } else {
        await sqlRunAsync(
          `INSERT INTO ${commentTable} (fotoid, uyeadi, author_user_id, yorum, tarih, updated_at)
           VALUES (?, ?, ?, ?, ?, ?)`,
          [context.photo.id, authorHandle, req.session.userId, comment, now, now],
        );
      }

      const ownerId = normalizeUserId(context.photo.uploaded_by_user_id);
      if (ownerId && !sameUserId(ownerId, req.session.userId)) {
        addNotification({
          userId: ownerId,
          type: 'photo_comment',
          sourceUserId: req.session.userId,
          entityId: context.photo.id,
          message: 'Fotoğrafına yorum yaptı.',
        });
      }

      notifyMentions({
        text: rawComment,
        sourceUserId: req.session.userId,
        entityId: context.photo.id,
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

      const commentId = Number(req.params.commentId || 0);
      const row = await sqlGetAsync(
        `SELECT id, ${isPostgres ? 'photo_id' : 'fotoid'} AS photo_id, author_user_id
         FROM ${commentTable}
         WHERE id = ?`,
        [commentId],
      );
      if (!row || Number(row.photo_id || 0) !== Number(context.photo.id || 0)) {
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

      const commentId = Number(req.params.commentId || 0);
      const row = await sqlGetAsync(
        `SELECT id, ${isPostgres ? 'photo_id' : 'fotoid'} AS photo_id, author_user_id
         FROM ${commentTable}
         WHERE id = ?`,
        [commentId],
      );
      if (!row || Number(row.photo_id || 0) !== Number(context.photo.id || 0)) {
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

      const canDeleteAll = sameUserId(context.photo.uploaded_by_user_id, req.session.userId) ||
        hasCategoryManagementAccess(currentUser);
      if (!canDeleteAll) return res.status(403).send('Bu fotoğrafın yorumlarını topluca silemezsin.');

      await sqlRunAsync(
        `DELETE FROM ${commentTable} WHERE ${isPostgres ? 'photo_id' : 'fotoid'} = ?`,
        [context.photo.id],
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

      const existing = await sqlGetAsync(
        `SELECT id FROM ${likeTable} WHERE photo_id = ? AND user_id = ? LIMIT 1`,
        [context.photo.id, req.session.userId],
      );
      let liked = false;
      if (existing) {
        await sqlRunAsync(`DELETE FROM ${likeTable} WHERE id = ?`, [existing.id]);
      } else {
        liked = true;
        await sqlRunAsync(
          `INSERT INTO ${likeTable} (photo_id, user_id, created_at) VALUES (?, ?, ?)`,
          [context.photo.id, req.session.userId, new Date().toISOString()],
        );
        const ownerId = normalizeUserId(context.photo.uploaded_by_user_id);
        if (ownerId && !sameUserId(ownerId, req.session.userId)) {
          addNotification({
            userId: ownerId,
            type: 'mention_photo',
            sourceUserId: req.session.userId,
            entityId: context.photo.id,
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

      const rows = await sqlAllAsync(
        `SELECT ${userSelect('u')}
         FROM ${likeTable} l
         JOIN ${userTable} u ON u.id = l.user_id
         WHERE l.photo_id = ?
         ORDER BY l.created_at DESC, l.id DESC`,
        [context.photo.id],
      );
      res.json({
        items: rows.map((row) => ({
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
