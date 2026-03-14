import crypto from 'crypto';

export function registerOAuthRoutes(app, {
  sqlGet,
  sqlRun,
  getEnabledOAuthProviders,
  getOAuthProviderConfig,
  randomState,
  sanitizeOAuthReturnTo,
  base64Url,
  withOAuthError,
  oauthFetchToken,
  oauthFetchProfile,
  findOrCreateOAuthUser,
  issueMobileOAuthToken,
  consumeMobileOAuthToken,
  applyUserSession,
  oauthLoginToSuccessPath
}) {
  app.get('/api/auth/oauth/providers', (req, res) => {
    res.json({ providers: getEnabledOAuthProviders(req, { includeDisabled: true }) });
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
    if (!config || !config.enabled) {
      return res.redirect(isNative ? 'sdalnative://oauth-callback?oauth=disabled' : withOAuthError(loginRedirectPath, 'disabled'));
    }
    const state = String(req.query.state || '');
    const code = String(req.query.code || '');
    if (!code || !state) return res.redirect(isNative ? 'sdalnative://oauth-callback?oauth=invalid' : withOAuthError(loginRedirectPath, 'invalid'));
    if (state !== String(req.session.oauthState || '') || config.provider !== String(req.session.oauthProvider || '')) {
      return res.redirect(isNative ? 'sdalnative://oauth-callback?oauth=state' : withOAuthError(loginRedirectPath, 'state'));
    }

    try {
      const accessToken = await oauthFetchToken(config, code, String(req.session.oauthPkceVerifier || ''));
      const profile = await oauthFetchProfile(config, accessToken);
      const user = findOrCreateOAuthUser({ provider: config.provider, profile });
      if (!user || user.yasak === 1) {
        return res.redirect(isNative ? 'sdalnative://oauth-callback?oauth=blocked' : withOAuthError(loginRedirectPath, 'blocked'));
      }
      if (user.aktiv === 0) {
        sqlRun('UPDATE uyeler SET aktiv = 1 WHERE id = ?', [user.id]);
        user.aktiv = 1;
      }
      if (isNative) {
        const token = issueMobileOAuthToken(user.id);
        res.redirect(`sdalnative://oauth-callback?token=${encodeURIComponent(token)}`);
      } else {
        applyUserSession(req, user);
        res.cookie('uyegiris', 'evet');
        res.cookie('uyeid', String(user.id));
        res.cookie('kadi', user.kadi);
        res.redirect(oauthLoginToSuccessPath(loginRedirectPath));
      }
    } catch (err) {
      console.error('OAuth callback error:', config.provider, err);
      res.redirect(isNative ? 'sdalnative://oauth-callback?oauth=failed' : withOAuthError(loginRedirectPath, 'failed'));
    } finally {
      req.session.oauthState = null;
      req.session.oauthProvider = null;
      req.session.oauthPkceVerifier = null;
      req.session.oauthNative = null;
      req.session.oauthReturnTo = null;
    }
  });

  app.post('/api/auth/oauth/mobile/exchange', (req, res) => {
    const token = String(req.body?.token || '').trim();
    const userId = consumeMobileOAuthToken(token);
    if (!userId) return res.status(400).send('OAuth token gecersiz veya suresi dolmus.');
    const user = sqlGet('SELECT * FROM uyeler WHERE id = ?', [userId]);
    if (!user || user.yasak === 1) return res.status(400).send('Kullanici gecersiz.');
    applyUserSession(req, user);
    res.cookie('uyegiris', 'evet');
    res.cookie('uyeid', String(user.id));
    res.cookie('kadi', user.kadi);
    res.json({ ok: true, user: { id: user.id, kadi: user.kadi, isim: user.isim, soyisim: user.soyisim } });
  });
}
