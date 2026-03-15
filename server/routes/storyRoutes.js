import fs from 'fs';
import path from 'path';
import sharp from 'sharp';

const STORY_TTL_MS = 24 * 60 * 60 * 1000;

function parseIsoMs(value) {
  const ms = Date.parse(String(value || ''));
  return Number.isFinite(ms) ? ms : null;
}

function storyTiming(row, nowMs = Date.now()) {
  const createdMs = parseIsoMs(row.created_at) ?? nowMs;
  const expiresMs = parseIsoMs(row.expires_at) ?? (createdMs + STORY_TTL_MS);
  return {
    createdAt: row.created_at || new Date(createdMs).toISOString(),
    expiresAt: new Date(expiresMs).toISOString(),
    isExpired: expiresMs <= nowMs
  };
}

function parseStoryId(value) {
  const storyId = Number(value);
  if (!Number.isInteger(storyId) || storyId <= 0) return null;
  return storyId;
}

export function registerStoryRoutes(app, {
  requireAuth,
  sqlGet,
  sqlGetAsync,
  sqlAllAsync,
  sqlRun,
  sqlRunAsync,
  buildVersionedCacheKey,
  cacheNamespaces,
  getCacheJson,
  setCacheJson,
  storyRailCacheTtlSeconds,
  getImageVariantsBatch,
  uploadsDir,
  uploadRateLimit,
  storyUpload,
  validateUploadedImageFile,
  allowedImageSafetyMimes,
  getMediaUploadLimitBytes,
  cleanupUploadedFile,
  enforceUploadQuota,
  formatUserText,
  storyDir,
  processUpload,
  deleteImageRecord,
  writeAppLog,
  scheduleEngagementRecalculation,
  invalidateCacheNamespace
}) {
  app.get('/api/new/stories', requireAuth, async (req, res) => {
    try {
      const nowMs = Date.now();
      const nowIso = new Date(nowMs).toISOString();
      const limit = Math.min(Math.max(parseInt(req.query.limit || '60', 10), 1), 120);
      const cursor = Math.max(parseInt(req.query.cursor || '0', 10), 0);
      const cacheKey = await buildVersionedCacheKey(cacheNamespaces.stories, [
        `user:${Number(req.session.userId || 0)}`,
        `limit:${limit}`,
        `cursor:${cursor || 0}`
      ]);
      const cached = await getCacheJson(cacheKey);
      if (cached && Array.isArray(cached.items)) {
        res.setHeader('X-Has-More', cached.hasMore ? '1' : '0');
        return res.json({ items: cached.items });
      }

      const whereParts = ['(s.expires_at IS NULL OR s.expires_at > ?)'];
      const params = [nowIso];
      if (cursor > 0) {
        whereParts.push('s.id < ?');
        params.push(cursor);
      }
      const rows = await sqlAllAsync(
        `SELECT s.id, s.user_id, s.image, s.image_record_id, s.caption, s.created_at, s.expires_at,
                u.kadi, u.isim, u.soyisim, u.resim, u.verified
         FROM stories s
         LEFT JOIN uyeler u ON u.id = s.user_id
         WHERE ${whereParts.join(' AND ')}
         ORDER BY s.id DESC
         LIMIT ?`,
        [...params, limit + 1]
      );
      const viewed = await sqlAllAsync('SELECT story_id FROM story_views WHERE user_id = ?', [req.session.userId]);
      const viewedSet = new Set(viewed.map((v) => Number(v.story_id)));
      const variantsMap = await getImageVariantsBatch(
        rows.slice(0, limit).map((row) => row.image_record_id).filter(Boolean),
        sqlAllAsync,
        uploadsDir
      );
      const items = rows
        .slice(0, limit)
        .map((r) => {
          const timing = storyTiming(r, nowMs);
          const item = {
            id: r.id,
            image: r.image,
            caption: r.caption,
            createdAt: timing.createdAt,
            expiresAt: timing.expiresAt,
            isExpired: timing.isExpired,
            author: {
              id: r.user_id,
              kadi: r.kadi,
              isim: r.isim,
              soyisim: r.soyisim,
              resim: r.resim,
              verified: r.verified
            },
            viewed: viewedSet.has(Number(r.id))
          };
          if (r.image_record_id) {
            const variants = variantsMap.get(String(r.image_record_id));
            if (variants) item.variants = { thumbUrl: variants.thumbUrl, feedUrl: variants.feedUrl, fullUrl: variants.fullUrl };
          }
          return item;
        })
        .filter((story) => !story.isExpired);
      const hasMore = rows.length > limit;
      res.setHeader('X-Has-More', hasMore ? '1' : '0');
      await setCacheJson(cacheKey, { items, hasMore }, storyRailCacheTtlSeconds);
      return res.json({ items });
    } catch (err) {
      console.error('GET /api/new/stories failed:', err);
      return res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.get('/api/new/stories/mine', requireAuth, async (req, res) => {
    try {
      const rows = await sqlAllAsync(
        `SELECT s.id, s.image, s.image_record_id, s.caption, s.created_at, s.expires_at,
                COUNT(v.id) AS view_count
         FROM stories s
         LEFT JOIN story_views v ON v.story_id = s.id
         WHERE s.user_id = ?
         GROUP BY s.id
         ORDER BY s.created_at DESC`,
        [req.session.userId]
      );
      const nowMs = Date.now();
      const variantsMap = await getImageVariantsBatch(
        rows.map((row) => row.image_record_id).filter(Boolean),
        sqlAllAsync,
        uploadsDir
      );
      return res.json({
        items: rows.map((row) => {
          const timing = storyTiming(row, nowMs);
          const item = {
            id: row.id,
            image: row.image,
            caption: row.caption,
            createdAt: timing.createdAt,
            expiresAt: timing.expiresAt,
            isExpired: timing.isExpired,
            viewCount: Number(row.view_count || 0)
          };
          if (row.image_record_id) {
            const variants = variantsMap.get(String(row.image_record_id));
            if (variants) item.variants = { thumbUrl: variants.thumbUrl, feedUrl: variants.feedUrl, fullUrl: variants.fullUrl };
          }
          return item;
        })
      });
    } catch (err) {
      console.error('GET /api/new/stories/mine failed:', err);
      return res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.get('/api/new/stories/user/:id', requireAuth, async (req, res) => {
    try {
      const userId = Number(req.params.id || 0);
      if (!Number.isInteger(userId) || userId <= 0) return res.status(400).send('Geçersiz üye kimliği.');
      const includeExpired = String(req.query.includeExpired || '0') === '1';
      const nowMs = Date.now();
      const nowIso = new Date(nowMs).toISOString();

      const rows = await sqlAllAsync(
        `SELECT s.id, s.user_id, s.image, s.image_record_id, s.caption, s.created_at, s.expires_at,
                u.kadi, u.isim, u.soyisim, u.resim, u.verified
         FROM stories s
         LEFT JOIN uyeler u ON u.id = s.user_id
         WHERE s.user_id = ?
           AND (? = 1 OR s.expires_at IS NULL OR s.expires_at > ?)
         ORDER BY s.created_at DESC`,
        [userId, includeExpired ? 1 : 0, nowIso]
      );

      const viewed = await sqlAllAsync('SELECT story_id FROM story_views WHERE user_id = ?', [req.session.userId]);
      const viewedSet = new Set(viewed.map((v) => Number(v.story_id)));
      const variantsMap = await getImageVariantsBatch(
        rows.map((row) => row.image_record_id).filter(Boolean),
        sqlAllAsync,
        uploadsDir
      );
      const items = rows.map((r) => {
        const timing = storyTiming(r, nowMs);
        const item = {
          id: r.id,
          image: r.image,
          caption: r.caption,
          createdAt: timing.createdAt,
          expiresAt: timing.expiresAt,
          isExpired: timing.isExpired,
          author: {
            id: r.user_id,
            kadi: r.kadi,
            isim: r.isim,
            soyisim: r.soyisim,
            resim: r.resim,
            verified: r.verified
          },
          viewed: viewedSet.has(Number(r.id))
        };
        if (r.image_record_id) {
          const variants = variantsMap.get(String(r.image_record_id));
          if (variants) item.variants = { thumbUrl: variants.thumbUrl, feedUrl: variants.feedUrl, fullUrl: variants.fullUrl };
        }
        return item;
      });

      return res.json({ items });
    } catch (err) {
      console.error('GET /api/new/stories/user/:id failed:', err);
      return res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.post('/api/new/stories/upload', requireAuth, uploadRateLimit, storyUpload.single('image'), async (req, res) => {
    if (!req.file) return res.status(400).send('Görsel seçilmedi.');
    try {
      const validation = validateUploadedImageFile(req.file.path, {
        allowedMimes: allowedImageSafetyMimes,
        maxBytes: getMediaUploadLimitBytes()
      });
      if (!validation.ok) {
        cleanupUploadedFile(req.file.path);
        return res.status(400).send(validation.reason);
      }
      const quotaOk = await enforceUploadQuota(req, res, {
        fileSize: validation.size || req.file.size || 0,
        bucket: 'story_image'
      });
      if (!quotaOk) {
        cleanupUploadedFile(req.file.path);
        return res.status(429).send('Günlük yükleme kotan doldu. Lütfen daha sonra tekrar dene.');
      }

      const caption = formatUserText(req.body?.caption || '');
      const outputName = `story_${req.session.userId}_${Date.now()}.webp`;
      const outputPath = path.join(storyDir, outputName);

      await sharp(req.file.path)
        .rotate()
        .resize(1080, 1920, { fit: 'contain', background: '#0b0f16', withoutEnlargement: true })
        .webp({ quality: 82, effort: 4 })
        .toFile(outputPath);

      try {
        if (req.file.path !== outputPath && fs.existsSync(req.file.path)) fs.unlinkSync(req.file.path);
      } catch {}

      const image = `/uploads/stories/${outputName}`;
      const now = new Date();
      const expires = new Date(now.getTime() + STORY_TTL_MS);

      let imageRecordId = null;
      let variants = null;
      try {
        const storyBuffer = fs.readFileSync(outputPath);
        const uploadResult = await processUpload({
          buffer: storyBuffer,
          mimeType: 'image/webp',
          userId: req.session.userId,
          entityType: 'story',
          entityId: '0',
          sqlGet: sqlGetAsync,
          sqlRun: sqlRunAsync,
          uploadsDir,
          writeAppLog
        });
        imageRecordId = uploadResult.imageId;
        variants = uploadResult.variants;
      } catch (err) {
        writeAppLog('error', 'story_variant_generation_failed', { message: err?.message });
      }

      const result = await sqlRunAsync('INSERT INTO stories (user_id, image, image_record_id, caption, created_at, expires_at) VALUES (?, ?, ?, ?, ?, ?)', [
        req.session.userId,
        image,
        imageRecordId,
        caption,
        now.toISOString(),
        expires.toISOString()
      ]);

      const storyId = result?.lastInsertRowid;
      if (imageRecordId && storyId) {
        try {
          await sqlRunAsync('UPDATE image_records SET entity_id = ? WHERE id = ?', [storyId, imageRecordId]);
        } catch {}
      }

      scheduleEngagementRecalculation('story_created');
      invalidateCacheNamespace(cacheNamespaces.stories);
      res.json({ ok: true, id: storyId, image, variants });
    } catch (err) {
      writeAppLog('error', 'story_upload_failed', {
        userId: req.session?.userId || null,
        message: err?.message || 'unknown_error'
      });
      return res.status(500).send('Hikaye yükleme sırasında hata oluştu.');
    }
  });

  async function updateStoryCaption(req, res) {
    try {
      const storyId = parseStoryId(req.params.id);
      if (!storyId) return res.status(400).send('Geçersiz hikaye kimliği.');
      const story = await sqlGetAsync('SELECT id FROM stories WHERE id = ? AND user_id = ?', [storyId, req.session.userId]);
      if (!story) return res.status(404).send('Hikaye bulunamadı.');
      const caption = formatUserText(req.body?.caption || '');
      await sqlRunAsync('UPDATE stories SET caption = ? WHERE id = ?', [caption, storyId]);
      invalidateCacheNamespace(cacheNamespaces.stories);
      res.json({ ok: true });
    } catch (err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  }

  async function deleteStory(req, res) {
    try {
      const storyId = parseStoryId(req.params.id);
      if (!storyId) return res.status(400).send('Geçersiz hikaye kimliği.');
      const story = await sqlGetAsync('SELECT id, image_record_id FROM stories WHERE id = ? AND user_id = ?', [storyId, req.session.userId]);
      if (!story) return res.status(404).send('Hikaye bulunamadı.');
      if (story.image_record_id) {
        deleteImageRecord(story.image_record_id, sqlGetAsync, sqlRunAsync, uploadsDir, writeAppLog).catch(() => {});
      }
      await sqlRunAsync('DELETE FROM story_views WHERE story_id = ?', [storyId]);
      await sqlRunAsync('DELETE FROM stories WHERE id = ?', [storyId]);
      invalidateCacheNamespace(cacheNamespaces.stories);
      res.json({ ok: true });
    } catch (err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  }

  app.patch('/api/new/stories/:id', requireAuth, updateStoryCaption);
  app.delete('/api/new/stories/:id', requireAuth, deleteStory);
  app.post('/api/new/stories/:id/edit', requireAuth, updateStoryCaption);
  app.post('/api/new/stories/:id/delete', requireAuth, deleteStory);
  app.post('/api/new/stories/:id', requireAuth, updateStoryCaption);
  app.post('/api/new/stories/:id/remove', requireAuth, deleteStory);

  app.post('/api/new/stories/:id/repost', requireAuth, async (req, res) => {
    try {
      const storyId = parseStoryId(req.params.id);
      if (!storyId) return res.status(400).send('Geçersiz hikaye kimliği.');
      const story = await sqlGetAsync('SELECT id, user_id, image, caption, created_at, expires_at FROM stories WHERE id = ?', [storyId]);
      if (!story || Number(story.user_id) !== Number(req.session.userId)) {
        return res.status(404).send('Hikaye bulunamadı.');
      }
      const timing = storyTiming(story);
      if (!timing.isExpired) {
        return res.status(400).send('Sadece süresi dolan hikayeler yeniden paylaşılabilir.');
      }
      const now = new Date();
      const expires = new Date(now.getTime() + STORY_TTL_MS);
      const result = await sqlRunAsync(
        'INSERT INTO stories (user_id, image, caption, created_at, expires_at) VALUES (?, ?, ?, ?, ?)',
        [req.session.userId, story.image, story.caption || '', now.toISOString(), expires.toISOString()]
      );
      scheduleEngagementRecalculation('story_created');
      invalidateCacheNamespace(cacheNamespaces.stories);
      res.json({ ok: true, id: result?.lastInsertRowid, image: story.image });
    } catch (err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.post('/api/new/stories/:id/view', requireAuth, async (req, res) => {
    try {
      const storyId = parseStoryId(req.params.id);
      if (!storyId) return res.status(400).send('Geçersiz hikaye kimliği.');
      const story = await sqlGetAsync('SELECT id, created_at, expires_at FROM stories WHERE id = ?', [storyId]);
      if (!story) return res.status(404).send('Hikaye bulunamadı.');
      const timing = storyTiming(story);
      if (timing.isExpired) return res.status(400).send('Hikaye süresi dolmuş.');
      const existing = await sqlGetAsync('SELECT id FROM story_views WHERE story_id = ? AND user_id = ?', [storyId, req.session.userId]);
      if (!existing) {
        await sqlRunAsync('INSERT INTO story_views (story_id, user_id, created_at) VALUES (?, ?, ?)', [
          storyId,
          req.session.userId,
          new Date().toISOString()
        ]);
        scheduleEngagementRecalculation('story_viewed');
        invalidateCacheNamespace(cacheNamespaces.stories);
      }
      res.json({ ok: true });
    } catch (err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });
}
