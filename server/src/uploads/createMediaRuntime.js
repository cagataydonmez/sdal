import fs from 'fs';
import path from 'path';
import sharp from 'sharp';

export function createMediaRuntime({
  sqlGet,
  loadMediaSettings,
  envInt,
  allowedImageSafetyMimes,
  validateUploadedFileSafety,
  cleanupUploadedFile,
  applyImageFilter,
  getCurrentUser,
  getUserRole,
  roleAtLeast,
  consumeUploadQuota,
  uploadsDir,
  writeAppLog
}) {
  function getMediaUploadLimitBytes() {
    try {
      const settings = loadMediaSettings(sqlGet);
      const maxUploadBytes = Number(settings?.maxUploadBytes || 0);
      if (Number.isFinite(maxUploadBytes) && maxUploadBytes > 0) return maxUploadBytes;
    } catch {
      // fallback to env default
    }
    return envInt('MEDIA_MAX_UPLOAD_BYTES', 10 * 1024 * 1024);
  }

  function validateUploadedImageFile(filePath, { allowedMimes = allowedImageSafetyMimes, maxBytes = null } = {}) {
    const validation = validateUploadedFileSafety(filePath, { allowedMimes });
    if (!validation.ok) return validation;
    let size = 0;
    try {
      size = fs.statSync(filePath).size || 0;
    } catch {
      return { ok: false, reason: 'Dosya boyutu doğrulanamadı.' };
    }
    const limit = Number.isFinite(Number(maxBytes)) && Number(maxBytes) > 0 ? Number(maxBytes) : getMediaUploadLimitBytes();
    if (size > limit) {
      const maxMb = (limit / (1024 * 1024)).toFixed(1);
      return { ok: false, reason: `Dosya boyutu çok büyük. Maksimum: ${maxMb} MB.` };
    }
    return { ok: true, mime: validation.mime, size };
  }

  async function enforceUploadQuota(req, res, { fileSize = 0, bucket = 'uploads' } = {}) {
    const currentUser = getCurrentUser(req);
    const role = getUserRole(currentUser);
    const roleMultiplier = roleAtLeast(role, 'admin')
      ? Math.max(envInt('UPLOAD_QUOTA_ADMIN_MULTIPLIER', 3), 1)
      : 1;

    const maxFiles = envInt('UPLOAD_QUOTA_MAX_FILES', 140) * roleMultiplier;
    const maxBytes = envInt('UPLOAD_QUOTA_MAX_BYTES', 350 * 1024 * 1024) * roleMultiplier;
    const windowSeconds = envInt('UPLOAD_QUOTA_WINDOW_SECONDS', 24 * 60 * 60);
    const scope = req.session?.userId
      ? `user:${Number(req.session.userId)}`
      : `ip:${String(req.ip || 'unknown')}`;

    const verdict = await consumeUploadQuota({
      bucket,
      scope,
      bytes: Math.max(Number(fileSize || 0), 0),
      maxFiles,
      maxBytes,
      windowSeconds
    });

    if (verdict.limitFiles) res.setHeader('X-Upload-Quota-Limit-Files', String(verdict.limitFiles));
    if (verdict.limitBytes) res.setHeader('X-Upload-Quota-Limit-Bytes', String(verdict.limitBytes));
    if (verdict.remainingFiles !== null) res.setHeader('X-Upload-Quota-Remaining-Files', String(verdict.remainingFiles));
    if (verdict.remainingBytes !== null) res.setHeader('X-Upload-Quota-Remaining-Bytes', String(verdict.remainingBytes));
    if (verdict.retryAfterSeconds) res.setHeader('X-Upload-Quota-Reset', String(verdict.retryAfterSeconds));

    if (verdict.allowed) return true;
    if (verdict.retryAfterSeconds) res.setHeader('Retry-After', String(verdict.retryAfterSeconds));
    return false;
  }

  async function optimizeUploadedImage(filePath, {
    width = 1600,
    height = 1600,
    fit = 'inside',
    quality = 84,
    background = '#121212'
  } = {}) {
    if (!filePath || !fs.existsSync(filePath)) return filePath;
    const parsed = path.parse(filePath);
    const finalOutputPath = path.join(parsed.dir, `${parsed.name}.webp`);
    const tempOutputPath = finalOutputPath === filePath
      ? path.join(parsed.dir, `${parsed.name}.optimized.webp`)
      : finalOutputPath;
    await sharp(filePath)
      .rotate()
      .resize(width || null, height || null, {
        fit,
        withoutEnlargement: true,
        background
      })
      .webp({ quality, effort: 4 })
      .toFile(tempOutputPath);
    if (tempOutputPath !== finalOutputPath) {
      try {
        if (fs.existsSync(finalOutputPath)) fs.unlinkSync(finalOutputPath);
      } catch {
        // ignore cleanup errors
      }
      try {
        fs.renameSync(tempOutputPath, finalOutputPath);
      } catch {
        // ignore cleanup errors
      }
    }
    if (filePath !== finalOutputPath && fs.existsSync(filePath)) {
      try {
        fs.unlinkSync(filePath);
      } catch {
        // ignore cleanup errors
      }
    }
    return finalOutputPath;
  }

  function toUploadUrl(filePath) {
    if (!filePath) return null;
    const rel = path.relative(uploadsDir, filePath).split(path.sep).join('/');
    return `/uploads/${rel}`;
  }

  async function processDiskImageUpload({
    req,
    res,
    file,
    bucket,
    preset,
    filter,
    allowedMimes = allowedImageSafetyMimes
  }) {
    if (!file?.path) {
      return { ok: false, statusCode: 400, message: 'Görsel seçilmedi.' };
    }

    const validation = validateUploadedImageFile(file.path, {
      allowedMimes,
      maxBytes: getMediaUploadLimitBytes()
    });
    if (!validation.ok) {
      cleanupUploadedFile(file.path);
      return { ok: false, statusCode: 400, message: validation.reason || 'Dosya güvenlik kontrolünden geçemedi.' };
    }

    const quotaOk = await enforceUploadQuota(req, res, {
      fileSize: validation.size || file.size || 0,
      bucket
    });
    if (!quotaOk) {
      cleanupUploadedFile(file.path);
      return {
        ok: false,
        statusCode: 429,
        message: 'Günlük yükleme kotan doldu. Lütfen daha sonra tekrar dene.'
      };
    }

    let finalPath = file.path;
    if (filter) {
      try {
        await applyImageFilter(finalPath, filter);
      } catch {
        // keep original if filter fails
      }
    }
    if (preset) {
      try {
        finalPath = await optimizeUploadedImage(finalPath, preset);
      } catch (err) {
        writeAppLog('warn', 'image_optimize_failed', {
          path: finalPath,
          message: err?.message || 'unknown_error'
        });
      }
    }

    const outputExt = path.extname(finalPath || '').toLowerCase();
    const outputMime = outputExt === '.webp' ? 'image/webp' : validation.mime;

    return {
      ok: true,
      path: finalPath,
      url: toUploadUrl(finalPath),
      mime: outputMime || validation.mime,
      originalMime: validation.mime,
      size: validation.size || file.size || 0
    };
  }

  return {
    getMediaUploadLimitBytes,
    validateUploadedImageFile,
    enforceUploadQuota,
    processDiskImageUpload
  };
}
