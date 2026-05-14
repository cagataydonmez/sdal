import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_sdal/core/config/app_config.dart';
import 'package:flutter_sdal/core/network/api_result.dart';
import 'package:flutter_sdal/core/session/session_models.dart';

void main() {
  test('ApiResult.requireData throws readable fallback', () {
    const result = ApiResult<String>(
      ok: false,
      statusCode: 500,
      message: '',
      code: 'ERR',
      data: null,
      rawData: null,
    );

    expect(() => result.requireData('Eksik veri'), throwsA(isA<StateError>()));
  });

  test('SessionSnapshot maps web landing page to mobile route', () {
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
        defaultLandingPage: '/new/explore',
      ),
      user: const SessionUser(
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
        graduationYear: '2011',
      ),
    );

    expect(snapshot.defaultHomePath, '/explore');
  });
}
