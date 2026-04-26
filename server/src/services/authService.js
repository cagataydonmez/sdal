import { HttpError } from '../shared/httpError.js';

export class AuthService {
  constructor({ userRepository, verifyPassword, hashPassword, rolePolicy }) {
    this.userRepository = userRepository;
    this.verifyPassword = verifyPassword;
    this.hashPassword = hashPassword;
    this.rolePolicy = rolePolicy;
  }

  async loginWithPassword({ username, password }) {
    if (!username) {
      throw new HttpError(400, 'Kullanıcı adını yazmazsan siteye giremezsin.');
    }
    if (!password) {
      throw new HttpError(400, 'Siteye girmek için şifreni de yazman gerekiyor.');
    }

    const user = await this.userRepository.findByUsername(username);
    if (!user) {
      throw new HttpError(400, 'Sdal.org sitesinde böyle bir kullanıcı henüz kayıtlı değil.');
    }
    const verification = await this.verifyPassword(user.legacy?.sifre || '', password);
    if (!verification?.ok) {
      throw new HttpError(400, 'Girdiğin şifre yanlış!');
    }
    if (user.banned) {
      throw new HttpError(400, `Merhaba ${user.firstName || ''} ${user.lastName || ''}, siteye girişiniz yasaklanmış!`);
    }
    if (!user.active) {
      throw new HttpError(403, 'Hesabınızı kullanmadan önce aktivasyonu tamamlamanız gerekiyor.', {
        code: 'ACTIVATION_REQUIRED',
        memberId: user.id,
        email: user.email || '',
        username: user.username || ''
      });
    }

    if (verification.needsRehash) {
      const nextHash = await this.hashPassword(password);
      await this.userRepository.updatePasswordHash(user.id, nextHash);
    }

    const role = this.rolePolicy.getUserRole(user.legacy || user);
    const isAdmin = this.rolePolicy.hasAdminRole(user.legacy || user);

    return {
      user,
      role,
      isAdmin,
      needsProfile: !user.profileCompleted
    };
  }

  async logout(userId) {
    if (!userId) return;
    await this.userRepository.setOnlineStatus(userId, false);
  }
}
