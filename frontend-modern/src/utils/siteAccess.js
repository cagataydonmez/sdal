import { getCached, setCache } from './swrCache.js';

const SITE_ACCESS_CACHE_MAX_AGE_MS = 120_000;
const inflightRequests = new Map();

function normalizePath(path) {
  const value = String(path || '').trim();
  return value || '/new';
}

function getSiteAccessCacheKey(path) {
  return `site-access:${normalizePath(path)}`;
}

export function getCachedSiteAccess(path) {
  return getCached(getSiteAccessCacheKey(path));
}

export function primeSiteAccess(path, payload, maxAgeMs = SITE_ACCESS_CACHE_MAX_AGE_MS) {
  if (!payload || typeof payload !== 'object') return;
  setCache(getSiteAccessCacheKey(path), payload, maxAgeMs);
}

export async function fetchSiteAccess(path, { force = false } = {}) {
  const normalizedPath = normalizePath(path);
  const cacheKey = getSiteAccessCacheKey(normalizedPath);
  if (!force) {
    const cached = getCached(cacheKey);
    if (cached && !cached.stale) return cached.data;
  }
  const existingRequest = inflightRequests.get(cacheKey);
  if (existingRequest) return existingRequest;
  const request = fetch(`/api/site-access?path=${encodeURIComponent(normalizedPath)}`, {
    credentials: 'include'
  })
    .then((response) => (response.ok ? response.json() : null))
    .then((payload) => {
      if (payload && typeof payload === 'object') {
        primeSiteAccess(normalizedPath, payload);
      }
      return payload;
    })
    .finally(() => {
      inflightRequests.delete(cacheKey);
    });
  inflightRequests.set(cacheKey, request);
  return request;
}
