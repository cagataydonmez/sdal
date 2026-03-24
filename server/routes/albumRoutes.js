import path from 'path';

export function registerAlbumRoutes(app, {
  sqlGet,
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
  toDbFlagForColumn
}) {
  const albumActiveExpr = "(COALESCE(CAST(aktif AS INTEGER), 0) = 1 OR LOWER(CAST(aktif AS TEXT)) IN ('true','evet','yes'))";
  const albumActiveValue = toDbFlagForColumn('album_foto', 'aktif', true);
  const isTruthyAlbumFlag = (value) => {
    if (value === true) return true;
    if (Number(value) === 1) return true;
    const raw = String(value || '').trim().toLowerCase();
    return raw === '1' || raw === 'true' || raw === 'evet' || raw === 'yes';
  };

  app.get('/api/albums', async (req, res) => {
    try {
      if (!req.session.userId) return res.status(401).send('Login required');
      const categories = await sqlAllAsync(`SELECT id, kategori, aciklama FROM album_kat WHERE ${albumActiveExpr} ORDER BY id`);
      const items = await Promise.all(categories.map(async (cat) => {
        const countRow = await sqlGetAsync(`SELECT COUNT(*) AS cnt FROM album_foto WHERE ${albumActiveExpr} AND katid = ?`, [cat.id]);
        const previews = await sqlAllAsync(`SELECT dosyaadi FROM album_foto WHERE ${albumActiveExpr} AND katid = ? ORDER BY id DESC LIMIT 5`, [cat.id]);
        return { ...cat, count: countRow?.cnt || 0, previews: previews.map((p) => p.dosyaadi) };
      }));
      res.json({ items });
    } catch (err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.get('/api/album/categories/active', async (req, res) => {
    try {
      if (!req.session.userId) return res.status(401).send('Login required');
      const categories = await sqlAllAsync(`SELECT id, kategori FROM album_kat WHERE ${albumActiveExpr} ORDER BY kategori`);
      res.json({ categories });
    } catch (err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.post('/api/album/upload', (req, res, next) => {
    if (!req.session.userId) return res.status(401).send('Login required');
    return albumUpload.single('file')(req, res, (err) => {
      if (err) return next(err);
      next();
    });
  }, async (req, res) => {
    try {
      const kat = String(req.body?.kat || '').trim();
      const baslik = sanitizePlainUserText(String(req.body?.baslik || '').trim(), 255);
      const aciklama = formatUserText(req.body?.aciklama || '');

      if (!baslik) return res.status(400).send('Yüklemek üzere olduğun fotoğraf için bir başlık girmen gerekiyor.');
      if (!kat) return res.status(400).send('Kategori seçmelisin.');
      const category = await sqlGetAsync(`SELECT * FROM album_kat WHERE id = ? AND ${albumActiveExpr}`, [kat]);
      if (!category) return res.status(400).send('Seçtiğin kategori bulunamadı.');
      if (!req.file?.filename) return res.status(400).send('Geçerli bir resim dosyası girmedin.');

      const processed = await processDiskImageUpload({
        req,
        res,
        file: req.file,
        bucket: 'album_photo',
        preset: uploadImagePresets.albumPhoto
      });
      if (!processed.ok) return res.status(processed.statusCode).send(processed.message);

      const storedFilename = path.basename(processed.path || req.file.path);
      const mediaSettings = loadMediaSettings(sqlGet);
      const requireApproval = mediaSettings.albumUploadsRequireApproval === true;
      const initialActiveValue = requireApproval ? toDbFlagForColumn('album_foto', 'aktif', false) : albumActiveValue;

      await sqlRunAsync('UPDATE album_kat SET sonekleme = ?, sonekleyen = ? WHERE id = ?', [new Date().toISOString(), req.session.userId, category.id]);
      await sqlRunAsync(
        `INSERT INTO album_foto (dosyaadi, katid, baslik, aciklama, aktif, ekleyenid, tarih, hit)
         VALUES (?, ?, ?, ?, ?, ?, ?, 0)`,
        [storedFilename, String(category.id), baslik, aciklama, initialActiveValue, req.session.userId, new Date().toISOString()]
      );

      res.json({
        ok: true,
        file: storedFilename,
        categoryId: category.id,
        active: !requireApproval,
        requiresApproval: requireApproval
      });
    } catch (err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.get('/api/albums/:id', async (req, res) => {
    try {
      if (!req.session.userId) return res.status(401).send('Login required');
      const page = Math.max(parseInt(req.query.page || '1', 10), 1);
      const pageSize = Math.min(Math.max(parseInt(req.query.pageSize || '20', 10), 1), 50);
      const category = await sqlGetAsync(`SELECT id, kategori, aciklama FROM album_kat WHERE id = ? AND ${albumActiveExpr}`, [req.params.id]);
      if (!category) return res.status(404).send('Kategori bulunamadı');
      const totalRow = await sqlGetAsync(`SELECT COUNT(*) AS cnt FROM album_foto WHERE ${albumActiveExpr} AND katid = ?`, [req.params.id]);
      const total = totalRow?.cnt || 0;
      const pages = Math.max(Math.ceil(total / pageSize), 1);
      const safePage = Math.min(page, pages);
      const offset = (safePage - 1) * pageSize;
      const photos = await sqlAllAsync(`SELECT id, dosyaadi, baslik, tarih FROM album_foto WHERE ${albumActiveExpr} AND katid = ? ORDER BY tarih LIMIT ? OFFSET ?`, [req.params.id, pageSize, offset]);
      res.json({ category, photos, page: safePage, pages, total, pageSize });
    } catch (err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.get('/api/photos/:id', async (req, res) => {
    try {
      if (!req.session.userId) return res.status(401).send('Login required');
      const row = await sqlGetAsync(`SELECT id, katid, dosyaadi, baslik, aciklama, tarih FROM album_foto WHERE id = ? AND ${albumActiveExpr}`, [req.params.id]);
      if (!row) return res.status(404).send('Fotoğraf bulunamadı');
      const category = await sqlGetAsync('SELECT id, kategori FROM album_kat WHERE id = ?', [row.katid]);
      const comments = await sqlAllAsync(
        `SELECT c.id, c.uyeadi, c.yorum, c.tarih,
                u.id AS user_id, u.kadi, u.verified, u.resim, u.isim, u.soyisim
         FROM album_fotoyorum c
         LEFT JOIN uyeler u ON LOWER(u.kadi) = LOWER(c.uyeadi)
         WHERE c.fotoid = ?
         ORDER BY c.id DESC`,
        [row.id]
      );
      res.json({ row, category, comments });
    } catch (err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.get('/api/photos/:id/comments', async (req, res) => {
    try {
      if (!req.session.userId) return res.status(401).send('Login required');
      const comments = await sqlAllAsync(
        `SELECT c.id, c.uyeadi, c.yorum, c.tarih,
                u.id AS user_id, u.kadi, u.verified, u.resim, u.isim, u.soyisim
         FROM album_fotoyorum c
         LEFT JOIN uyeler u ON LOWER(u.kadi) = LOWER(c.uyeadi)
         WHERE c.fotoid = ?
         ORDER BY c.id DESC`,
        [req.params.id]
      );
      res.json({ comments });
    } catch (err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.post('/api/photos/:id/comments', async (req, res) => {
    try {
      if (!req.session.userId) return res.status(401).send('Login required');
      const photo = await sqlGetAsync('SELECT id, ekleyenid, aktif FROM album_foto WHERE id = ?', [req.params.id]);
      if (!photo) return res.status(404).send('Fotoğraf bulunamadı');
      if (!isTruthyAlbumFlag(photo.aktif)) return res.status(400).send('Fotoğraf yoruma açık değil');
      const yorumRaw = String(req.body?.yorum || '');
      const yorum = formatUserText(yorumRaw);
      if (!yorum) return res.status(400).send('Yorum girmedin');
      const user = getCurrentUser(req);
      await sqlRunAsync('INSERT INTO album_fotoyorum (fotoid, uyeadi, yorum, tarih) VALUES (?, ?, ?, ?)', [
        photo.id,
        user?.kadi || 'Misafir',
        yorum,
        new Date().toISOString()
      ]);
      const ownerId = normalizeUserId(photo.ekleyenid);
      if (ownerId && !sameUserId(ownerId, req.session.userId)) {
        addNotification({
          userId: ownerId,
          type: 'photo_comment',
          sourceUserId: req.session.userId,
          entityId: photo.id,
          message: 'Fotoğrafına yorum yaptı.'
        });
      }
      notifyMentions({
        text: yorumRaw,
        sourceUserId: req.session.userId,
        entityId: photo.id,
        type: 'mention_photo',
        message: 'Fotoğraf yorumunda senden bahsetti.'
      });
      res.json({ ok: true });
    } catch (err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });
}
