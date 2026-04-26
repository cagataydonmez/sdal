import crypto from 'crypto';

const TEST_MULTI_ACCOUNT_EMAIL = 'cagatay.donmez@gmail.com';

function isTestMultiAccountEmail(email) {
  return String(email || '').trim().toLowerCase() === TEST_MULTI_ACCOUNT_EMAIL;
}

function escapeHtml(value) {
  return String(value ?? '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#039;');
}

export function registerOAuthRoutes(app, {
  sqlGet,
  sqlAll,
  sqlGetAsync,
  sqlRun,
  sqlRunAsync,
  getEnabledOAuthProviders,
  getOAuthProviderConfig,
  randomState,
  sanitizeOAuthReturnTo,
  base64Url,
  withOAuthError,
  oauthFetchToken,
  oauthFetchProfile,
  findOrCreateOAuthUser,
  buildMobileOAuthCallbackUrl,
  issueMobileOAuthToken,
  consumeMobileOAuthToken,
  applyUserSession,
  oauthLoginToSuccessPath
}) {
  function fetchTestAccountChoices(email) {
    if (!isTestMultiAccountEmail(email)) return [];
    return sqlAll(
      `SELECT id, kadi, isim, soyisim, mezuniyetyili, role
       FROM uyeler
       WHERE lower(email) = lower(?)
         AND COALESCE(CAST(yasak AS INTEGER), 0) = 0
       ORDER BY CASE WHEN lower(kadi) = 'cagatay' THEN 0 ELSE 1 END, id DESC`,
      [TEST_MULTI_ACCOUNT_EMAIL]
    );
  }

  function rememberOAuthChoice(req, { provider, profile, choices }) {
    req.session.oauthChoice = {
      provider,
      providerUserId: String(profile.providerUserId || '').trim(),
      email: String(profile.email || '').trim(),
      emailVerified: profile.emailVerified ? 1 : 0,
      raw: profile.raw || {},
      choices: choices.map((item) => Number(item.id || 0)).filter(Boolean)
    };
  }

  function bindOAuthAccountToUser({ userId, provider, profile }) {
    const nowIso = new Date().toISOString();
    const providerUserId = String(profile.providerUserId || '').trim();
    const email = String(profile.email || '').trim();
    const existingAccount = sqlGet('SELECT id FROM oauth_accounts WHERE provider = ? AND provider_user_id = ?', [provider, providerUserId]);
    if (existingAccount) {
      sqlRun(
        'UPDATE oauth_accounts SET user_id = ?, email = ?, profile_json = ?, updated_at = ? WHERE id = ?',
        [userId, email, JSON.stringify(profile.raw || {}), nowIso, existingAccount.id]
      );
    } else {
      sqlRun(
        `INSERT INTO oauth_accounts (user_id, provider, provider_user_id, email, profile_json, created_at, updated_at)
         VALUES (?, ?, ?, ?, ?, ?, ?)`,
        [userId, provider, providerUserId, email, JSON.stringify(profile.raw || {}), nowIso, nowIso]
      );
    }
    sqlRun(
      'UPDATE uyeler SET oauth_provider = ?, oauth_subject = ?, oauth_email_verified = ? WHERE id = ?',
      [provider, providerUserId, profile.emailVerified ? 1 : 0, userId]
    );
  }

  async function completeOAuthLogin(req, res, user, { isNative, loginRedirectPath, nativeRedirect }) {
    if (!user || user.yasak === 1) {
      return res.redirect(isNative ? nativeRedirect({ oauth: 'blocked' }) : withOAuthError(loginRedirectPath, 'blocked'));
    }
    if (user.aktiv === 0) {
      await sqlRunAsync('UPDATE uyeler SET aktiv = 1 WHERE id = ?', [user.id]);
      user.aktiv = 1;
    }
    if (isNative) {
      const token = await issueMobileOAuthToken(user.id);
      return res.redirect(nativeRedirect({ token }));
    }
    applyUserSession(req, user);
    res.cookie('uyegiris', 'evet');
    res.cookie('uyeid', String(user.id));
    res.cookie('kadi', user.kadi);
    return res.redirect(oauthLoginToSuccessPath(loginRedirectPath));
  }

  function renderOAuthChoicePage(res, choices) {
    const items = choices.map((item) => {
      const name = `${item.isim || ''} ${item.soyisim || ''}`.trim() || item.kadi || `#${item.id}`;
      const meta = [item.kadi ? `@${item.kadi}` : '', item.mezuniyetyili || '', item.role || 'user'].filter(Boolean).join(' · ');
      return `<form method="post" action="/api/auth/oauth/select" style="margin:0 0 10px;">
        <input type="hidden" name="userId" value="${escapeHtml(item.id)}" />
        <button type="submit" style="width:100%;text-align:left;padding:14px 16px;border:1px solid #d7dee8;border-radius:10px;background:#fff;cursor:pointer;">
          <strong style="display:block;font-size:16px;">${escapeHtml(name)}</strong>
          <span style="color:#667085;">${escapeHtml(meta)}</span>
        </button>
      </form>`;
    }).join('');
    res.type('html').send(`<!doctype html>
      <html lang="tr"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
      <title>SDAL OAuth Hesap Seçimi</title></head>
      <body style="font-family:system-ui,-apple-system,Segoe UI,sans-serif;background:#f5f7fb;margin:0;padding:24px;color:#111827;">
        <main style="max-width:520px;margin:0 auto;background:#fff;border:1px solid #e5e7eb;border-radius:16px;padding:22px;">
          <h1 style="margin:0 0 8px;font-size:22px;">Hangi kullanıcıyla giriş yapmak istiyorsunuz?</h1>
          <p style="margin:0 0 18px;color:#667085;">Bu test e-posta adresine bağlı hesaplardan birini seçin.</p>
          ${items}
        </main>
      </body></html>`);
  }

  app.get('/api/auth/oauth/providers', (req, res) => {
    res.json({ providers: getEnabledOAuthProviders(req, { includeDisabled: true }) });
  });

  app.post('/api/auth/oauth/select', async (req, res) => {
    const choice = req.session.oauthChoice || null;
    const isNative = Number(req.session.oauthNative || 0) === 1;
    const loginRedirectPath = sanitizeOAuthReturnTo(req.session.oauthReturnTo, '/new/login');
    const nativeRedirect = (params) => buildMobileOAuthCallbackUrl(params);
    try {
      const userId = Number(req.body?.userId || 0);
      if (!choice || !choice.choices?.includes(userId)) {
        return res.redirect(isNative ? nativeRedirect({ oauth: 'invalid_choice' }) : withOAuthError(loginRedirectPath, 'invalid_choice'));
      }
      const user = await sqlGetAsync('SELECT * FROM uyeler WHERE id = ?', [userId]);
      if (!user) return res.redirect(isNative ? nativeRedirect({ oauth: 'invalid_choice' }) : withOAuthError(loginRedirectPath, 'invalid_choice'));
      bindOAuthAccountToUser({
        userId,
        provider: choice.provider,
        profile: {
          providerUserId: choice.providerUserId,
          email: choice.email,
          emailVerified: Number(choice.emailVerified || 0) === 1,
          raw: choice.raw || {}
        }
      });
      return completeOAuthLogin(req, res, user, { isNative, loginRedirectPath, nativeRedirect });
    } catch (err) {
      console.error('OAuth select error:', err);
      return res.redirect(isNative ? nativeRedirect({ oauth: 'failed' }) : withOAuthError(loginRedirectPath, 'failed'));
    } finally {
      req.session.oauthChoice = null;
      req.session.oauthState = null;
      req.session.oauthProvider = null;
      req.session.oauthPkceVerifier = null;
      req.session.oauthNative = null;
      req.session.oauthReturnTo = null;
    }
  });

  app.get('/api/auth/oauth/:provider/start', (req, res) => {
    const config = getOAuthProviderConfig(req.params.provider, req);
    if (!config || !config.enabled) return res.status(404).send('OAuth provider aktif değil.');

    const state = randomState();
    req.session.oauthState = state;
    req.session.oauthProvider = config.provider;
    req.session.oauthNative = String(req.query.native || '') === '1' ? 1 : 0;
    req.session.oauthReturnTo = sanitizeOAuthReturnTo(req.query.returnTo, '/new/login');

    if (config.provider === 'x') {
      const verifier = base64Url(crypto.randomBytes(32));
      const challenge = base64Url(crypto.createHash('sha256').update(verifier).digest());
      req.session.oauthPkceVerifier = verifier;
      const params = new URLSearchParams({
        response_type: 'code',
        client_id: config.clientId,
        redirect_uri: config.redirectUri,
        scope: config.scope,
        state,
        code_challenge: challenge,
        code_challenge_method: 'S256'
      });
      return res.redirect(`${config.authUrl}?${params.toString()}`);
    }

    const params = new URLSearchParams({
      response_type: 'code',
      client_id: config.clientId,
      redirect_uri: config.redirectUri,
      scope: config.scope,
      state
    });
    res.redirect(`${config.authUrl}?${params.toString()}`);
  });

  app.get('/api/auth/oauth/:provider/callback', async (req, res) => {
    const config = getOAuthProviderConfig(req.params.provider, req);
    const isNative = Number(req.session.oauthNative || 0) === 1;
    const loginRedirectPath = sanitizeOAuthReturnTo(req.session.oauthReturnTo, '/new/login');
    const nativeRedirect = (params) => buildMobileOAuthCallbackUrl(params);
    if (!config || !config.enabled) {
      return res.redirect(isNative ? nativeRedirect({ oauth: 'disabled' }) : withOAuthError(loginRedirectPath, 'disabled'));
    }
    const state = String(req.query.state || '');
    const code = String(req.query.code || '');
    if (!code || !state) return res.redirect(isNative ? nativeRedirect({ oauth: 'invalid' }) : withOAuthError(loginRedirectPath, 'invalid'));
    if (state !== String(req.session.oauthState || '') || config.provider !== String(req.session.oauthProvider || '')) {
      return res.redirect(isNative ? nativeRedirect({ oauth: 'state' }) : withOAuthError(loginRedirectPath, 'state'));
    }

    try {
      const accessToken = await oauthFetchToken(config, code, String(req.session.oauthPkceVerifier || ''));
      const profile = await oauthFetchProfile(config, accessToken);
      const choices = fetchTestAccountChoices(profile.email);
      if (config.provider === 'google' && choices.length > 1) {
        rememberOAuthChoice(req, { provider: config.provider, profile, choices });
        return renderOAuthChoicePage(res, choices);
      }
      const user = findOrCreateOAuthUser({ provider: config.provider, profile });
      return completeOAuthLogin(req, res, user, { isNative, loginRedirectPath, nativeRedirect });
    } catch (err) {
      console.error('OAuth callback error:', config.provider, err);
      res.redirect(isNative ? nativeRedirect({ oauth: 'failed' }) : withOAuthError(loginRedirectPath, 'failed'));
    } finally {
      if (!req.session.oauthChoice) {
        req.session.oauthState = null;
        req.session.oauthProvider = null;
        req.session.oauthPkceVerifier = null;
        req.session.oauthNative = null;
        req.session.oauthReturnTo = null;
      }
    }
  });

  app.post('/api/auth/oauth/mobile/exchange', async (req, res) => {
    try {
      const token = String(req.body?.token || '').trim();
      const userId = await consumeMobileOAuthToken(token);
      if (!userId) return res.status(400).send('OAuth token gecersiz veya suresi dolmus.');
      const user = await sqlGetAsync('SELECT * FROM uyeler WHERE id = ?', [userId]);
      if (!user || user.yasak === 1) return res.status(400).send('Kullanici gecersiz.');
      applyUserSession(req, user);
      res.cookie('uyegiris', 'evet');
      res.cookie('uyeid', String(user.id));
      res.cookie('kadi', user.kadi);
      res.json({ ok: true, user: { id: user.id, kadi: user.kadi, isim: user.isim, soyisim: user.soyisim } });
    } catch (err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });
}
