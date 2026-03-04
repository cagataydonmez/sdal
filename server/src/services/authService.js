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

    const user = this.userRepository.findByUsername(username);
    if (!user) {
      throw new HttpError(400, 'Sdal.org sitesinde böyle bir kullanıcı henüz kayıtlı değil.');
    }
    if (user.banned) {
      throw new HttpError(400, `Merhaba ${user.firstName || ''} ${user.lastName || ''}, siteye girişiniz yasaklanmış!`);
    }
    if (!user.active) {
      throw new HttpError(400, `Onay işleminizi henüz tamamlamamışsınız. Aktivasyon maili için /aktivasyon-gonder?id=${user.id}`);
    }

    const verification = await this.verifyPassword(user.legacy?.sifre || '', password);
    if (!verification?.ok) {
      throw new HttpError(400, 'Girdiğin şifre yanlış!');
    }

    if (verification.needsRehash) {
      const nextHash = await this.hashPassword(password);
      this.userRepository.updatePasswordHash(user.id, nextHash);
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

  logout(userId) {
    if (!userId) return;
    this.userRepository.setOnlineStatus(userId, false);
  }
}
