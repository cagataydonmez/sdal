import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_sdal/core/config/app_config.dart';
import 'package:flutter_sdal/core/session/session_models.dart';

void main() {
  test('SessionUser decodes legacy alias fields', () {
    final user = SessionUser.fromMap({
      'id': '12',
      'kadi': 'ada',
      'isim': 'Ada',
      'soyisim': 'Lovelace',
      'resim': '/uploads/avatar.png',
      'admin': 1,
      'verified': 'true',
      'yasak': 0,
      'state': 'active',
      'mezuniyetyili': '2011',
      'oauth_provider': 'google',
    });

    expect(user.id, 12);
    expect(user.photo, '/uploads/avatar.png');
    expect(user.isAdmin, isTrue);
    expect(user.isVerified, isTrue);
    expect(user.isBanned, isFalse);
    expect(user.graduationYear, '2011');
    expect(user.oauthProvider, 'google');
  });

  test('SiteAccessSnapshot decodes module map and fallback message alias', () {
    final snapshot = SiteAccessSnapshot.fromMap({
      'siteOpen': false,
      'message': 'bakim',
      'modules': {'feed': 1, 'notifications': 0},
      'defaultLandingPage': '/new/explore',
    });

    expect(snapshot.siteOpen, isFalse);
    expect(snapshot.maintenanceMessage, 'bakim');
    expect(snapshot.isModuleOpen('feed'), isTrue);
    expect(snapshot.isModuleOpen('notifications'), isFalse);
  });

  test('SessionSnapshot prefers moderation workspace for moderator users', () {
    const user = SessionUser(
      id: 44,
      kadi: 'cohortmod',
      isim: 'Cohort',
      soyisim: 'Moderator',
      photo: '',
      role: 'mod',
      isAdmin: false,
      isVerified: true,
      isBanned: false,
      state: 'active',
    );

    final snapshot = SessionSnapshot(
      config: const AppConfig(
        apiBaseUrl: 'https://example.com/api',
        siteBaseUrl: 'https://example.com',
        appName: 'SDAL',
        oauthCallbackScheme: 'sdalnative',
      ),
      siteAccess: const SiteAccessSnapshot(
        siteOpen: true,
        maintenanceMessage: '',
        modules: <String, bool>{},
        defaultLandingPage: '/new/feed',
      ),
      user: user,
    );

    expect(snapshot.isModerator, isTrue);
    expect(snapshot.managementEntryPath, '/moderation');
  });
}
