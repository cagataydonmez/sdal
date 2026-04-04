import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_sdal/core/config/app_config.dart';
import 'package:flutter_sdal/core/routing/app_router.dart';
import 'package:flutter_sdal/core/session/session_models.dart';

void main() {
  group('redirectForSessionState', () {
    test('routes guests to login for protected paths', () {
      final snapshot = _snapshot();

      expect(redirectForSessionState(snapshot, Uri.parse('/feed')), '/login');
      expect(redirectForSessionState(snapshot, Uri.parse('/register')), isNull);
    });

    test('routes banned members to account-banned', () {
      final snapshot = _snapshot(
        user: const SessionUser(
          id: 7,
          kadi: 'yasakli',
          isim: 'Yasak',
          soyisim: 'Uye',
          photo: '',
          role: 'user',
          isAdmin: false,
          isVerified: true,
          isBanned: true,
          state: 'active',
        ),
      );

      expect(
        redirectForSessionState(snapshot, Uri.parse('/feed')),
        '/account-banned',
      );
    });

    test('routes closed modules to module-closed page', () {
      final snapshot = _snapshot(
        siteAccess: const SiteAccessSnapshot(
          siteOpen: true,
          maintenanceMessage: '',
          modules: <String, bool>{'notifications': false},
          defaultLandingPage: '/new',
        ),
        user: _verifiedUser,
      );

      expect(
        redirectForSessionState(snapshot, Uri.parse('/notifications')),
        '/module-closed?module=notifications',
      );
    });

    test('routes unverified users away from gated networking routes', () {
      final snapshot = _snapshot(
        user: const SessionUser(
          id: 9,
          kadi: 'dogrulama',
          isim: 'Eksik',
          soyisim: 'Uye',
          photo: '',
          role: 'user',
          isAdmin: false,
          isVerified: false,
          isBanned: false,
          state: 'active',
        ),
      );

      expect(
        redirectForSessionState(snapshot, Uri.parse('/network/hub')),
        '/verification-required?feature=networking',
      );
      expect(redirectForSessionState(snapshot, Uri.parse('/inbox')), isNull);
    });
  });

  group('route helpers', () {
    test('moduleKeyForLocation maps mobile routes to backend modules', () {
      expect(moduleKeyForLocation('/feed'), 'feed');
      expect(moduleKeyForLocation('/members/42'), 'explore');
      expect(moduleKeyForLocation('/messages/2'), 'messenger');
      expect(moduleKeyForLocation('/following'), 'following');
      expect(moduleKeyForLocation('/requests'), 'requests');
      expect(moduleKeyForLocation('/groups/12'), 'groups');
      expect(moduleKeyForLocation('/albums/photo/9'), 'albums');
      expect(moduleKeyForLocation('/network/teachers'), 'teachers_network');
    });

    test('requiresVerificationGate only gates networking surfaces', () {
      expect(requiresVerificationGate('/network/hub'), isTrue);
      expect(requiresVerificationGate('/network/inbox'), isTrue);
      expect(requiresVerificationGate('/messages/4'), isFalse);
      expect(requiresVerificationGate('/inbox'), isFalse);
    });
  });
}

SessionSnapshot _snapshot({SiteAccessSnapshot? siteAccess, SessionUser? user}) {
  return SessionSnapshot(
    config: const AppConfig(
      apiBaseUrl: 'https://example.com/api',
      siteBaseUrl: 'https://example.com',
      appName: 'SDAL',
      oauthCallbackScheme: 'sdalnative',
    ),
    siteAccess:
        siteAccess ??
        const SiteAccessSnapshot(
          siteOpen: true,
          maintenanceMessage: '',
          modules: <String, bool>{},
          defaultLandingPage: '/new/feed',
        ),
    user: user,
  );
}

const SessionUser _verifiedUser = SessionUser(
  id: 1,
  kadi: 'uye',
  isim: 'Ada',
  soyisim: 'Lovelace',
  photo: '',
  role: 'user',
  isAdmin: false,
  isVerified: true,
  isBanned: false,
  state: 'active',
);
