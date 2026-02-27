/**
 * Storage Provider Abstraction
 *
 * Common interface for local filesystem and S3-compatible object storage.
 * The active provider is selected based on DB media_settings.
 *
 * Interface (each provider implements):
 *   saveVariant(key, buffer, contentType, cacheControl) → { url, path }
 *   deletePrefix(prefix) → void
 *   getPublicUrl(pathOrKey) → string
 */

import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// ---------------------------------------------------------------------------
// Local Storage Provider
// ---------------------------------------------------------------------------

export class LocalStorageProvider {
  /**
   * @param {string} basePath - absolute path to the uploads root (e.g. /var/www/sdal/uploads)
   * @param {string} urlPrefix - URL prefix for serving (e.g. /uploads)
   */
  constructor(basePath, urlPrefix = '/uploads') {
    this.basePath = path.resolve(basePath);
    this.urlPrefix = urlPrefix;
  }

  /**
   * Resolve and validate a safe absolute path under basePath.
   * Prevents path traversal attacks.
   */
  _safePath(key) {
    // Normalize and strip leading slashes from key
    const normalized = String(key || '')
      .replace(/\\/g, '/')
      .replace(/^\/+/, '')
      .split('/')
      .filter((seg) => seg && seg !== '..' && seg !== '.')
      .join('/');

    if (!normalized) throw new Error('Invalid storage key');

    const full = path.join(this.basePath, normalized);

    // Double-check the resolved path is under basePath
    if (!full.startsWith(this.basePath + path.sep) && full !== this.basePath) {
      throw new Error('Path traversal detected');
    }

    return full;
  }

  async saveVariant(key, buffer, contentType = 'image/webp', cacheControl = 'public, max-age=31536000, immutable') {
    const fullPath = this._safePath(key);
    const dir = path.dirname(fullPath);

    if (!fs.existsSync(dir)) {
      fs.mkdirSync(dir, { recursive: true });
    }

    fs.writeFileSync(fullPath, buffer);

    const relativePath = path.relative(this.basePath, fullPath).split(path.sep).join('/');
    const url = `${this.urlPrefix}/${relativePath}`;

    return { url, path: relativePath };
  }

  async deletePrefix(prefix) {
    const fullPath = this._safePath(prefix);
    if (fs.existsSync(fullPath)) {
      fs.rmSync(fullPath, { recursive: true, force: true });
    }
  }

  async deleteKeys(keys) {
    for (const key of keys) {
      try {
        const fullPath = this._safePath(key);
        if (fs.existsSync(fullPath)) {
          fs.unlinkSync(fullPath);
        }
      } catch {
        // best effort
      }
    }
  }

  getPublicUrl(pathOrKey) {
    const normalized = String(pathOrKey || '')
      .replace(/\\/g, '/')
      .replace(/^\/+/, '');
    return `${this.urlPrefix}/${normalized}`;
  }
}

// ---------------------------------------------------------------------------
// Spaces (S3-compatible) Storage Provider
// ---------------------------------------------------------------------------

export class SpacesStorageProvider {
  /**
   * @param {object} config
   * @param {string} config.endpoint - e.g. https://fra1.digitaloceanspaces.com
   * @param {string} config.region - e.g. fra1
   * @param {string} config.bucket
   * @param {string} config.accessKeyId
   * @param {string} config.secretAccessKey
   * @param {string} [config.cdnBase] - optional CDN URL base
   */
  constructor(config) {
    this.config = config;
    this.bucket = config.bucket;
    this.cdnBase = config.cdnBase || '';
    this._client = null;
  }

  async _getClient() {
    if (this._client) return this._client;

    // Lazy-load AWS SDK to avoid loading it when not needed
    const { S3Client } = await import('@aws-sdk/client-s3');

    this._client = new S3Client({
      endpoint: this.config.endpoint,
      region: this.config.region || 'us-east-1',
      credentials: {
        accessKeyId: this.config.accessKeyId,
        secretAccessKey: this.config.secretAccessKey,
      },
      forcePathStyle: false,
    });

    return this._client;
  }

  async saveVariant(key, buffer, contentType = 'image/webp', cacheControl = 'public, max-age=31536000, immutable') {
    const client = await this._getClient();
    const { PutObjectCommand } = await import('@aws-sdk/client-s3');

    const normalizedKey = String(key || '').replace(/^\/+/, '');

    await client.send(new PutObjectCommand({
      Bucket: this.bucket,
      Key: normalizedKey,
      Body: buffer,
      ContentType: contentType,
      CacheControl: cacheControl,
      ACL: 'public-read',
    }));

    const url = this.getPublicUrl(normalizedKey);
    return { url, path: normalizedKey };
  }

  async deletePrefix(prefix) {
    const client = await this._getClient();
    const { ListObjectsV2Command, DeleteObjectsCommand } = await import('@aws-sdk/client-s3');

    const normalizedPrefix = String(prefix || '').replace(/^\/+/, '');

    const listResult = await client.send(new ListObjectsV2Command({
      Bucket: this.bucket,
      Prefix: normalizedPrefix,
    }));

    const objects = (listResult.Contents || []).map((obj) => ({ Key: obj.Key }));
    if (objects.length === 0) return;

    await client.send(new DeleteObjectsCommand({
      Bucket: this.bucket,
      Delete: { Objects: objects },
    }));
  }

  async deleteKeys(keys) {
    if (!keys || keys.length === 0) return;
    const client = await this._getClient();
    const { DeleteObjectsCommand } = await import('@aws-sdk/client-s3');

    const objects = keys.map((k) => ({ Key: String(k).replace(/^\/+/, '') }));

    await client.send(new DeleteObjectsCommand({
      Bucket: this.bucket,
      Delete: { Objects: objects },
    }));
  }

  getPublicUrl(pathOrKey) {
    const normalized = String(pathOrKey || '').replace(/^\/+/, '');
    if (this.cdnBase) {
      return `${this.cdnBase.replace(/\/+$/, '')}/${normalized}`;
    }
    // Fallback to direct Spaces URL
    return `${this.config.endpoint.replace(/\/+$/, '')}/${this.bucket}/${normalized}`;
  }

  /**
   * Test connectivity by attempting a small write + delete.
   * Returns { ok: true } or { ok: false, error: string }.
   */
  async testConnection() {
    try {
      const testKey = `_sdal_connection_test_${Date.now()}.txt`;
      const testBuffer = Buffer.from('SDAL connectivity test', 'utf-8');

      await this.saveVariant(testKey, testBuffer, 'text/plain', 'no-cache');
      await this.deleteKeys([testKey]);

      return { ok: true };
    } catch (err) {
      return { ok: false, error: err?.message || 'Unknown error' };
    }
  }
}

// ---------------------------------------------------------------------------
// Factory
// ---------------------------------------------------------------------------

/**
 * Get the active storage provider based on media settings.
 *
 * @param {object} settings - row from media_settings table
 * @param {string} uploadsDir - resolved local uploads directory
 * @returns {LocalStorageProvider|SpacesStorageProvider}
 */
export function getStorageProvider(settings, uploadsDir) {
  if (settings?.storage_provider === 'spaces') {
    const endpoint = process.env.SPACES_ENDPOINT || '';
    const accessKeyId = process.env.SPACES_KEY || '';
    const secretAccessKey = process.env.SPACES_SECRET || '';
    const bucket = process.env.SPACES_BUCKET || '';
    const region = process.env.SPACES_REGION || '';
    const cdnBase = process.env.SPACES_CDN_BASE || '';

    if (!endpoint || !accessKeyId || !secretAccessKey || !bucket) {
      throw new Error('Spaces credentials not configured. Set SPACES_KEY, SPACES_SECRET, SPACES_BUCKET, and SPACES_ENDPOINT environment variables.');
    }

    return new SpacesStorageProvider({
      endpoint,
      region,
      bucket,
      accessKeyId,
      secretAccessKey,
      cdnBase,
    });
  }

  // Default: local storage
  return new LocalStorageProvider(uploadsDir);
}
