import { readApiPayload } from './api.js';
import { getCached, setCache } from './swrCache.js';

export const NOTIFICATION_PREFERENCE_DEFAULTS = Object.freeze({
  categories: {
    social: true,
    messaging: true,
    groups: true,
    events: true,
    networking: true,
    jobs: true,
    system: true
  },
  quiet_mode: {
    enabled: false,
    start: '',
    end: ''
  },
  high_priority_override: true,
  updated_at: null
});

const NOTIFICATION_PREFERENCES_CACHE_KEY = 'notification-preferences';
const NOTIFICATION_PREFERENCES_CACHE_MAX_AGE_MS = 120_000;

function normalizePreferences(input) {
  const source = input && typeof input === 'object' ? input : {};
  const categories = {};
  for (const [key, defaultValue] of Object.entries(NOTIFICATION_PREFERENCE_DEFAULTS.categories)) {
    categories[key] = Object.prototype.hasOwnProperty.call(source.categories || {}, key)
      ? Boolean(source.categories[key])
      : defaultValue;
  }
  return {
    categories,
    quiet_mode: {
      enabled: Boolean(source?.quiet_mode?.enabled),
      start: String(source?.quiet_mode?.start || '').trim(),
      end: String(source?.quiet_mode?.end || '').trim()
    },
    high_priority_override: source?.high_priority_override !== false,
    updated_at: source?.updated_at || null
  };
}

export async function fetchNotificationPreferences() {
  const cached = getCached(NOTIFICATION_PREFERENCES_CACHE_KEY);
  if (cached && !cached.stale) {
    return cached.data;
  }
  const res = await fetch('/api/new/notifications/preferences', {
    credentials: 'include',
    cache: 'no-store'
  });
  const { data, message, code } = await readApiPayload(res, 'Bildirim tercihleri yüklenemedi.');
  const result = {
    ok: res.ok,
    message,
    code,
    preferences: normalizePreferences(data?.preferences),
    experiments: {
      assignments: data?.experiments?.assignments || {},
      configs: Array.isArray(data?.experiments?.configs) ? data.experiments.configs : []
    }
  };
  if (result.ok) {
    setCache(NOTIFICATION_PREFERENCES_CACHE_KEY, result, NOTIFICATION_PREFERENCES_CACHE_MAX_AGE_MS);
  }
  return result;
}

export async function updateNotificationPreferences(body = {}) {
  const res = await fetch('/api/new/notifications/preferences', {
    method: 'PUT',
    credentials: 'include',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body)
  });
  const { data, message, code } = await readApiPayload(res, 'Bildirim tercihleri güncellenemedi.');
  const cached = getCached(NOTIFICATION_PREFERENCES_CACHE_KEY);
  const result = {
    ok: res.ok,
    message,
    code,
    preferences: normalizePreferences(data?.preferences)
  };
  if (result.ok) {
    setCache(NOTIFICATION_PREFERENCES_CACHE_KEY, {
      ...result,
      experiments: cached?.data?.experiments || { assignments: {}, configs: [] }
    }, NOTIFICATION_PREFERENCES_CACHE_MAX_AGE_MS);
  }
  return result;
}

export function isQuietModeActive(preferences) {
  const quietMode = preferences?.quiet_mode || {};
  if (!quietMode.enabled) return false;
  const start = String(quietMode.start || '').trim();
  const end = String(quietMode.end || '').trim();
  if (!start || !end) return true;
  return true;
}
