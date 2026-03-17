import { z } from 'zod';
import { isHttpError } from '../../shared/httpError.js';
import { toLegacyAuthLoginResponse } from '../dto/legacyApiMappers.js';

const LoginSchema = z.object({
  kadi: z.string().min(1, 'Kullanıcı adı zorunludur.').max(15),
  sifre: z.string().min(1, 'Şifre zorunludur.').max(20),
});

export function createAuthController({ authService, applyUserSession }) {
  async function login(req, res) {
    const parsed = LoginSchema.safeParse(req.body);
    if (!parsed.success) {
      return res.status(400).send((parsed.error.issues ?? parsed.error.errors).map(e => e.message).join(', '));
    }
    try {
      const username = parsed.data.kadi;
      const password = parsed.data.sifre;
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
