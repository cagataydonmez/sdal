import { isHttpError } from '../../shared/httpError.js';
import { toLegacyAuthLoginResponse } from '../dto/legacyApiMappers.js';

export function createAuthController({ authService, applyUserSession }) {
  async function login(req, res) {
    try {
      const username = req.body?.kadi;
      const password = req.body?.sifre;
      const result = await authService.loginWithPassword({ username, password });

      applyUserSession(req, result.user.legacy || {
        id: result.user.id,
        kadi: result.user.username,
        isim: result.user.firstName,
        soyisim: result.user.lastName,
        admin: result.isAdmin ? 1 : 0,
        role: result.role
      });
      res.cookie('uyegiris', 'evet');
      res.cookie('uyeid', String(result.user.id));
      res.cookie('kadi', result.user.username);

      res.json(toLegacyAuthLoginResponse(result));
    } catch (err) {
      if (isHttpError(err)) {
        return res.status(err.statusCode).send(err.message);
      }
      console.error('auth.login failed:', err);
      return res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  }

  async function logout(req, res) {
    await authService.logout(req.session.userId);
    req.session.destroy(() => {
      res.clearCookie('uyegiris');
      res.clearCookie('uyeid');
      res.clearCookie('kadi');
      res.clearCookie('admingiris');
      res.status(204).send();
    });
  }

  return {
    login,
    logout
  };
}
