/**
 * Image Processor – Sharp-based variant pipeline
 *
 * Accepts a raw image buffer and produces optimized WebP variants
 * (thumb, feed, full) with metadata stripped and auto-rotation applied.
 *
 * All widths/quality are configurable via the settings parameter
 * (sourced from the media_settings DB table at runtime).
 */

import sharp from 'sharp';

// Allowed decoded formats (checked after sharp decodes the buffer)
const ALLOWED_FORMATS = new Set(['jpeg', 'png', 'webp', 'heif', 'heic', 'tiff']);

// Allowed MIME types (checked before processing)
const ALLOWED_MIME_TYPES = new Set([
  'image/jpeg',
  'image/png',
  'image/webp',
  'image/heic',
  'image/heif',
  'image/tiff'
]);

/**
 * Validate that the buffer is a decodable image of an allowed type.
 * Throws on invalid/corrupt images.
 */
export async function validateImageBuffer(buffer) {
  if (!buffer || buffer.length === 0) {
    throw new Error('Empty image buffer');
  }

  const image = sharp(buffer, { failOn: 'error' });
  const metadata = await image.metadata();

  if (!metadata.format || !ALLOWED_FORMATS.has(metadata.format)) {
    throw new Error(`Unsupported image format: ${metadata.format || 'unknown'}`);
  }

  return metadata;
}

/**
 * Check if a MIME type is in our allowlist.
 */
export function isAllowedMimeType(mimeType) {
  return ALLOWED_MIME_TYPES.has(String(mimeType || '').toLowerCase());
}

/**
 * Generate all three variants from a raw image buffer.
 *
 * @param {Buffer} buffer - raw uploaded image data
 * @param {object} settings - processing settings
 * @param {number} [settings.thumbWidth=200]
 * @param {number} [settings.feedWidth=800]
 * @param {number} [settings.fullWidth=1600]
 * @param {number} [settings.webpQuality=80]
 * @returns {Promise<{ thumb: Buffer, feed: Buffer, full: Buffer, metadata: { width: number, height: number, format: string } }>}
 */
export async function generateVariants(buffer, settings = {}) {
  const thumbWidth = Number(settings.thumbWidth) || 200;
  const feedWidth = Number(settings.feedWidth) || 800;
  const fullWidth = Number(settings.fullWidth) || 1600;
  const quality = Number(settings.webpQuality) || 80;

  // Validate first
  const metadata = await validateImageBuffer(buffer);

  // Create a base pipeline: auto-rotate + strip metadata
  const basePipeline = () =>
    sharp(buffer, { failOn: 'error' })
      .rotate()                    // auto-rotate based on EXIF
      .withMetadata({ orientation: undefined }); // strip EXIF but keep rotation fix

  // Generate variants in parallel (limited concurrency for low-resource servers)
  const [thumb, feed, full] = await Promise.all([
    basePipeline()
      .resize(thumbWidth, null, { fit: 'inside', withoutEnlargement: true })
      .webp({ quality, effort: 4 })
      .toBuffer(),

    basePipeline()
      .resize(feedWidth, null, { fit: 'inside', withoutEnlargement: true })
      .webp({ quality, effort: 4 })
      .toBuffer(),

    basePipeline()
      .resize(fullWidth, null, { fit: 'inside', withoutEnlargement: true })
      .webp({ quality, effort: 4 })
      .toBuffer(),
  ]);

  return {
    thumb,
    feed,
    full,
    metadata: {
      width: metadata.width || 0,
      height: metadata.height || 0,
      format: metadata.format || 'unknown'
    }
  };
}
