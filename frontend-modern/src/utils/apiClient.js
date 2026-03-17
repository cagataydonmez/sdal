/**
 * Shared API client for non-admin pages.
 * Mirrors the pattern in admin/api/adminClient.js.
 */

export async function apiFetch(url, options = {}) {
  const res = await fetch(url, {
    credentials: 'include',
    headers: {
      'Content-Type': 'application/json',
      ...(options.headers || {}),
    },
    ...options,
  });

  if (!res.ok) {
    const message = await res.text();
    throw new Error(message || `Request failed: ${res.status}`);
  }

  if (res.status === 204) return null;
  return res.json();
}

export function withQuery(basePath, params = {}) {
  const qs = new URLSearchParams();
  for (const [key, value] of Object.entries(params)) {
    if (value === null || value === undefined || value === '') continue;
    qs.set(key, String(value));
  }
  const str = qs.toString();
  return str ? `${basePath}?${str}` : basePath;
}

export const api = {
  get: (url, options) => apiFetch(url, { ...options, method: 'GET' }),
  post: (url, body, options) => apiFetch(url, { ...options, method: 'POST', body: JSON.stringify(body ?? {}) }),
  put: (url, body, options) => apiFetch(url, { ...options, method: 'PUT', body: JSON.stringify(body ?? {}) }),
  del: (url, options) => apiFetch(url, { ...options, method: 'DELETE' }),
};
