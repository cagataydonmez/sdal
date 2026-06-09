import crypto from 'crypto';

const ALLOWED_GAMES = new Set(['crowngrid', 'wordstorm', 'arealoom', 'dualdots']);
const ALLOWED_CALLBACK_SCHEMES = new Set([
  'crowngrid',
  'wordgame',
  'wordstorm',
  'arealoom',
  'dualdots',
]);

function base64urlJson(value) {
  return Buffer.from(JSON.stringify(value)).toString('base64url');
}

function signPayload(payload, secret) {
  const body = base64urlJson(payload);
  const sig = crypto.createHmac('sha256', secret).update(body).digest('base64url');
  return `${body}.${sig}`;
}

function safeRedirectUri(value) {
  try {
    const uri = new URL(String(value || ''));
    if (!ALLOWED_CALLBACK_SCHEMES.has(uri.protocol.replace(':', ''))) return null;
    return uri;
  } catch {
    return null;
  }
}

function displayNameFor(user) {
  const full = [user?.isim, user?.soyisim].filter(Boolean).join(' ').trim();
  return full || String(user?.kadi || '').trim();
}

function appendQuery(uri, params) {
  for (const [key, value] of Object.entries(params)) {
    if (value != null && value !== '') uri.searchParams.set(key, String(value));
  }
  return uri.toString();
}

export function registerGameHubBridgeRoutes(app, { sqlGetAsync }) {
  app.get('/api/gamehub/authorize', async (req, res) => {
    const game = String(req.query.game || '').trim().toLowerCase();
    if (!ALLOWED_GAMES.has(game)) return res.status(400).send('Geçersiz oyun.');

    const redirectUri = safeRedirectUri(req.query.redirect_uri);
    if (!redirectUri) return res.status(400).send('Geçersiz dönüş adresi.');

    if (!req.session?.userId) {
      const returnTo = encodeURIComponent(req.originalUrl || '/api/gamehub/authorize');
      return res.redirect(302, `/new/login?returnTo=${returnTo}`);
    }

    const secret = String(process.env.SDAL_GAMEHUB_SHARED_SECRET || '').trim();
    if (secret.length < 32) {
      return res.status(503).send('GameHub bağlantısı yapılandırılmamış.');
    }

    const user = await sqlGetAsync(
      'SELECT id, kadi, isim, soyisim, email FROM uyeler WHERE id = ?',
      [req.session.userId]
    );
    if (!user) return res.status(401).send('Oturum bulunamadı.');

    const now = Math.floor(Date.now() / 1000);
    const token = signPayload({
      iss: 'sdal-social',
      aud: 'gamehub',
      game,
      sub: String(user.id),
      username: String(user.kadi || ''),
      firstName: String(user.isim || ''),
      lastName: String(user.soyisim || ''),
      displayName: displayNameFor(user),
      iat: now,
      exp: now + 120,
      nonce: crypto.randomBytes(12).toString('base64url'),
    }, secret);

    if (String(req.get('accept') || '').includes('application/json')) {
      return res.json({ token, expiresIn: 120, game, displayName: displayNameFor(user) });
    }

    return res.redirect(302, appendQuery(redirectUri, { token, game }));
  });
}
