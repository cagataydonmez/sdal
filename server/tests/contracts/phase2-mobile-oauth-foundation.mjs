import assert from 'node:assert/strict';

process.env.REDIS_URL = '';
process.env.SDAL_MOBILE_OAUTH_CALLBACK_URL = 'sdalflutter://oauth-callback';

const { buildMobileOAuthCallbackUrl, resolveMobileOAuthCallbackBaseUrl } = await import('../../src/auth/mobileOAuthCallback.js');
const { issueMobileOAuthToken, consumeMobileOAuthToken } = await import('../../src/infra/mobileOAuthTokenStore.js');

const callbackBase = resolveMobileOAuthCallbackBaseUrl();
assert.equal(callbackBase, 'sdalflutter://oauth-callback', 'mobile oauth callback base should respect env override');

const successUrl = buildMobileOAuthCallbackUrl({ token: 'abc123' });
assert.equal(successUrl, 'sdalflutter://oauth-callback?token=abc123', 'token callback url should be encoded on configured base');

const failureUrl = buildMobileOAuthCallbackUrl({ oauth: 'failed' });
assert.equal(failureUrl, 'sdalflutter://oauth-callback?oauth=failed', 'error callback url should be encoded on configured base');

const token = await issueMobileOAuthToken(42, { ttlSeconds: 30 });
assert.ok(typeof token === 'string' && token.length > 20, 'issued mobile oauth token should be opaque');

const firstConsume = await consumeMobileOAuthToken(token);
assert.equal(firstConsume, 42, 'consume should return the stored user id');

const secondConsume = await consumeMobileOAuthToken(token);
assert.equal(secondConsume, null, 'consume should be one-time');

console.log('phase2 mobile oauth foundation tests passed');
process.exit(0);
