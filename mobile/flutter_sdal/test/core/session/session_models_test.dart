import 'package:flutter_test/flutter_test.dart';
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
}
