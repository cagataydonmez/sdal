const cache = new Map();

const DEFAULT_MAX_AGE_MS = 60_000;

export function getCached(key) {
  const entry = cache.get(key);
  if (!entry) return null;
  return { data: entry.data, stale: Date.now() - entry.time > (entry.maxAge || DEFAULT_MAX_AGE_MS) };
}

export function setCache(key, data, maxAgeMs = DEFAULT_MAX_AGE_MS) {
  cache.set(key, { data, time: Date.now(), maxAge: maxAgeMs });
}

export function invalidateCache(key) {
  if (key) cache.delete(key);
  else cache.clear();
}

export async function fetchWithSWR(key, fetcher, { maxAgeMs = DEFAULT_MAX_AGE_MS } = {}) {
  const cached = getCached(key);
  if (cached && !cached.stale) {
    return { data: cached.data, fromCache: true };
  }
  const data = await fetcher();
  setCache(key, data, maxAgeMs);
  return { data, fromCache: false };
}
