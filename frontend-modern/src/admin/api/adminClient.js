export async function apiJson(url, options = {}) {
  const res = await fetch(url, {
    credentials: 'include',
    headers: {
      'Content-Type': 'application/json',
      ...(options.headers || {})
    },
    ...options
  });

  if (!res.ok) {
    const message = await res.text();
    throw new Error(message || `Request failed: ${res.status}`);
  }

  if (res.status === 204) return null;
  return res.json();
}

export function withQuery(basePath, query = {}) {
  const params = new URLSearchParams();
  for (const [key, value] of Object.entries(query || {})) {
    if (value === null || value === undefined || value === '') continue;
    params.set(key, String(value));
  }
  const qs = params.toString();
  return qs ? `${basePath}?${qs}` : basePath;
}

export const adminClient = {
  get: (url, options = {}) => apiJson(url, { ...options, method: 'GET' }),
  post: (url, body, options = {}) => apiJson(url, { ...options, method: 'POST', body: JSON.stringify(body || {}) }),
  put: (url, body, options = {}) => apiJson(url, { ...options, method: 'PUT', body: JSON.stringify(body || {}) }),
  del: (url, options = {}) => apiJson(url, { ...options, method: 'DELETE' })
};
