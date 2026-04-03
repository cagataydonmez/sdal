const DEFAULT_MOBILE_OAUTH_CALLBACK_URL = 'sdalnative://oauth-callback';

function normalizeCallbackUrl(input) {
  const raw = String(input || '').trim();
  if (!raw) return '';
  try {
    const url = new URL(raw);
    const protocol = String(url.protocol || '').toLowerCase();
    if (!protocol || protocol === 'javascript:' || protocol === 'data:') return '';
    url.search = '';
    url.hash = '';
    return url.toString();
  } catch {
    return '';
  }
}

export function resolveMobileOAuthCallbackBaseUrl() {
  const configured = normalizeCallbackUrl(
    process.env.SDAL_MOBILE_OAUTH_CALLBACK_URL
      || process.env.MOBILE_OAUTH_CALLBACK_URL
      || DEFAULT_MOBILE_OAUTH_CALLBACK_URL
  );
  return configured || DEFAULT_MOBILE_OAUTH_CALLBACK_URL;
}

export function buildMobileOAuthCallbackUrl(params = {}) {
  const target = new URL(resolveMobileOAuthCallbackBaseUrl());
  for (const [key, value] of Object.entries(params || {})) {
    if (value === null || value === undefined || value === '') continue;
    target.searchParams.set(key, String(value));
  }
  return target.toString();
}
