/**
 * Upload Pipeline – Orchestration module
 *
 * Single entry point for all image uploads. Ties together:
 *  1. Validation (type, size, decode)
 *  2. Variant generation (imageProcessor)
 *  3. Storage (storageProvider)
 *  4. DB record creation
 *
 * Used by POST /api/upload-image and wired into existing post/story routes.
 */

import crypto from 'crypto';
import { validateImageBuffer, isAllowedMimeType, generateVariants } from './imageProcessor.js';
import { getStorageProvider } from './storageProvider.js';

/**
 * Load media settings from the DB.
 * Returns a settings object with defaults for any missing values.
 *
 * @param {Function} sqlGet - DB query function
 * @returns {object}
 */
export function loadMediaSettings(sqlGet) {
  const row = sqlGet('SELECT * FROM media_settings WHERE id = 1');
  return {
    storage_provider: row?.storage_provider || 'local',
    local_base_path: row?.local_base_path || '/var/www/sdal/uploads',
    thumbWidth: Number(row?.thumb_width) || 200,
    feedWidth: Number(row?.feed_width) || 800,
    fullWidth: Number(row?.full_width) || 1600,
    webpQuality: Number(row?.webp_quality) || 80,
    maxUploadBytes: Number(row?.max_upload_bytes) || 10485760,
    avifEnabled: Number(row?.avif_enabled) || 0,
    albumUploadsRequireApproval: Number(row?.album_uploads_require_approval || 0) === 1 || row?.album_uploads_require_approval === true
  };
}

/**
 * Process and store an uploaded image, creating all variants.
 *
 * @param {object} params
 * @param {Buffer} params.buffer - raw image file data
 * @param {string} params.mimeType - original MIME type from multer
 * @param {number} params.userId - uploading user ID
 * @param {string} params.entityType - 'post' | 'story' | 'album' | 'event' | 'announcement' | etc.
 * @param {number|string} params.entityId - ID of the associated entity
 * @param {Function} params.sqlGet - DB query function
 * @param {Function} params.sqlRun - DB exec function
 * @param {string} params.uploadsDir - resolved uploads directory path
 * @param {Function} [params.writeAppLog] - optional logging function
 * @returns {Promise<{ imageId: string, variants: { thumbUrl: string, feedUrl: string, fullUrl: string }, provider: string, metadata: object }>}
 */
export async function processUpload({
  buffer,
  mimeType,
  userId,
  entityType,
  entityId,
  sqlGet,
  sqlRun,
  uploadsDir,
  writeAppLog,
}) {
  const log = writeAppLog || (() => {});

  // 1. Validate MIME type
  if (!isAllowedMimeType(mimeType)) {
    throw new Error('Desteklenmeyen dosya türü. Sadece JPEG, PNG, WebP, GIF, BMP, TIFF veya HEIC/HEIF yükleyebilirsiniz.');
  }

  // 2. Load settings
  const settings = loadMediaSettings(sqlGet);

  // 3. Check file size
  if (buffer.length > settings.maxUploadBytes) {
    const maxMB = (settings.maxUploadBytes / (1024 * 1024)).toFixed(1);
    throw new Error(`Dosya boyutu çok büyük. Maksimum: ${maxMB} MB.`);
  }

  // 4. Generate variants (validates image integrity internally)
  const result = await generateVariants(buffer, settings);

  // 5. Generate unique image ID
  const imageId = crypto.randomUUID();

  // 6. Build storage keys
  const safeUserId = String(userId || 'unknown').replace(/[^a-zA-Z0-9_-]/g, '_');
  const safeEntityType = String(entityType || 'misc').replace(/[^a-zA-Z0-9_-]/g, '_');
  const safeEntityId = String(entityId || '0').replace(/[^a-zA-Z0-9_-]/g, '_');

  const baseKey = `images/${safeUserId}/${safeEntityType}_${safeEntityId}/${imageId}`;

  const variantKeys = {
    thumb: `${baseKey}/thumb.webp`,
    feed: `${baseKey}/feed.webp`,
    full: `${baseKey}/full.webp`,
  };

  // 7. Get storage provider and save variants
  const provider = getStorageProvider(settings, uploadsDir);
  const providerName = settings.storage_provider || 'local';

  const [thumbResult, feedResult, fullResult] = await Promise.all([
    provider.saveVariant(variantKeys.thumb, result.thumb, 'image/webp'),
    provider.saveVariant(variantKeys.feed, result.feed, 'image/webp'),
    provider.saveVariant(variantKeys.full, result.full, 'image/webp'),
  ]);

  // 8. Insert DB record
  const now = new Date().toISOString();
  try {
    sqlRun(
      `INSERT INTO image_records (id, user_id, entity_type, entity_id, provider, thumb_path, feed_path, full_path, width, height, created_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        imageId,
        userId,
        entityType,
        entityId,
        providerName,
        thumbResult.path,
        feedResult.path,
        fullResult.path,
        result.metadata.width,
        result.metadata.height,
        now,
      ]
    );
  } catch (err) {
    // If DB insert fails, try to clean up stored files
    log('error', 'image_record_insert_failed', { imageId, error: err?.message });
    try {
      await provider.deletePrefix(baseKey);
    } catch {
      // best effort cleanup
    }
    throw err;
  }

  log('info', 'image_uploaded', {
    imageId,
    userId,
    entityType,
    entityId,
    provider: providerName,
    thumbSize: result.thumb.length,
    feedSize: result.feed.length,
    fullSize: result.full.length,
  });

  return {
    imageId,
    variants: {
      thumbUrl: thumbResult.url,
      feedUrl: feedResult.url,
      fullUrl: fullResult.url,
    },
    provider: providerName,
    metadata: result.metadata,
  };
}

/**
 * Delete an image record and its stored variants.
 *
 * @param {string} imageId
 * @param {Function} sqlGet
 * @param {Function} sqlRun
 * @param {string} uploadsDir
 * @param {Function} [writeAppLog]
 */
export async function deleteImageRecord(imageId, sqlGet, sqlRun, uploadsDir, writeAppLog) {
  const log = writeAppLog || (() => {});

  const record = await Promise.resolve(sqlGet('SELECT * FROM image_records WHERE id = ?', [imageId]));
  if (!record) return;

  // Build provider based on the record's provider (not current settings)
  let provider;
  if (record.provider === 'spaces') {
    try {
      provider = getStorageProvider({ storage_provider: 'spaces' }, uploadsDir);
    } catch {
      log('error', 'image_delete_spaces_unavailable', { imageId });
      // Can't delete from Spaces if credentials are gone; just remove DB record
      await Promise.resolve(sqlRun('DELETE FROM image_records WHERE id = ?', [imageId]));
      return;
    }
  } else {
    provider = getStorageProvider({ storage_provider: 'local' }, uploadsDir);
  }

  // Delete stored files
  try {
    const keys = [record.thumb_path, record.feed_path, record.full_path].filter(Boolean);
    if (keys.length > 0) {
      await provider.deleteKeys(keys);
    }

    // Also try to delete the parent directory (for local, to clean up empty dirs)
    if (record.provider === 'local' && record.thumb_path) {
      const parentKey = record.thumb_path.split('/').slice(0, -1).join('/');
      if (parentKey) {
        await provider.deletePrefix(parentKey);
      }
    }
  } catch (err) {
    log('error', 'image_files_delete_failed', { imageId, error: err?.message });
  }

  // Remove DB record
  await Promise.resolve(sqlRun('DELETE FROM image_records WHERE id = ?', [imageId]));

  log('info', 'image_deleted', { imageId, provider: record.provider });
}

/**
 * Get variant URLs for an image record.
 * Returns null if the record doesn't exist.
 *
 * @param {string} imageId
 * @param {Function} sqlGet
 * @param {string} uploadsDir
 * @returns {object|null}
 */
export function getImageVariants(imageId, sqlGet, uploadsDir) {
  if (!imageId) return null;

  const record = sqlGet('SELECT * FROM image_records WHERE id = ?', [imageId]);
  if (!record) return null;

  let provider;
  try {
    provider = getStorageProvider(
      { storage_provider: record.provider || 'local' },
      uploadsDir
    );
  } catch {
    // If Spaces credentials are missing, fall back to constructing local URLs
    provider = getStorageProvider({ storage_provider: 'local' }, uploadsDir);
  }

  return {
    imageId: record.id,
    thumbUrl: provider.getPublicUrl(record.thumb_path),
    feedUrl: provider.getPublicUrl(record.feed_path),
    fullUrl: provider.getPublicUrl(record.full_path),
    width: record.width,
    height: record.height,
    provider: record.provider,
  };
}

/**
 * Fetch variant URLs for many image records in a single query.
 *
 * @param {Array<string|number>} imageIds
 * @param {Function} sqlAll - can be sync or async, must return row array
 * @param {string} uploadsDir
 * @returns {Promise<Map<string, object>>}
 */
export async function getImageVariantsBatch(imageIds, sqlAll, uploadsDir) {
  const out = new Map();
  if (typeof sqlAll !== 'function') return out;
  if (!Array.isArray(imageIds) || imageIds.length === 0) return out;

  const ids = [...new Set(
    imageIds
      .map((id) => String(id || '').trim())
      .filter(Boolean)
  )];
  if (ids.length === 0) return out;

  const placeholders = ids.map(() => '?').join(', ');
  const rows = await Promise.resolve(sqlAll(
    `SELECT * FROM image_records WHERE id IN (${placeholders})`,
    ids
  ));

  for (const record of Array.isArray(rows) ? rows : []) {
    let provider;
    try {
      provider = getStorageProvider(
        { storage_provider: record.provider || 'local' },
        uploadsDir
      );
    } catch {
      provider = getStorageProvider({ storage_provider: 'local' }, uploadsDir);
    }
    out.set(String(record.id), {
      imageId: record.id,
      thumbUrl: provider.getPublicUrl(record.thumb_path),
      feedUrl: provider.getPublicUrl(record.feed_path),
      fullUrl: provider.getPublicUrl(record.full_path),
      width: record.width,
      height: record.height,
      provider: record.provider
    });
  }

  return out;
}
