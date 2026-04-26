import { z } from 'zod';
import { isHttpError } from '../../shared/httpError.js';
import { toLegacyAuthLoginResponse } from '../dto/legacyApiMappers.js';

const LoginSchema = z.object({
  kadi: z.string().min(1, 'Kullanıcı adı zorunludur.').max(15),
  sifre: z.string().min(1, 'Şifre zorunludur.').max(20),
  gkodu: z.string().optional().default(''),
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
      const failedAttempts = Number(req.session.loginFailedAttempts || 0);
      if (failedAttempts >= 3) {
        const captcha = String(parsed.data.gkodu || '').trim();
        if (!captcha) {
          return res.status(429).json({
            ok: false,
            code: 'CAPTCHA_REQUIRED',
            message: 'Çok sayıda hatalı deneme oldu. Devam etmek için güvenlik kodunu girin.'
          });
        }
        if (String(req.session.captcha || '').toUpperCase() !== captcha.toUpperCase()) {
          return res.status(400).json({
            ok: false,
            code: 'CAPTCHA_INVALID',
            message: 'Güvenlik kodu yanlış girildi.'
          });
        }
      }
      const result = await authService.loginWithPassword({ username, password });
      req.session.loginFailedAttempts = 0;

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
        const details = err.details && typeof err.details === 'object' ? err.details : {};
        if (details.code) {
          return res.status(err.statusCode).json({
            ok: false,
            code: details.code,
            message: err.message,
            ...details
          });
        }
        req.session.loginFailedAttempts = Number(req.session.loginFailedAttempts || 0) + 1;
        const captchaRequired = req.session.loginFailedAttempts >= 3;
        return res.status(err.statusCode).json({
          ok: false,
          code: captchaRequired ? 'CAPTCHA_REQUIRED' : 'LOGIN_FAILED',
          message: captchaRequired
            ? `${err.message} Üç hatalı denemeden sonra güvenlik kodu gerekiyor.`
            : err.message
        });
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
