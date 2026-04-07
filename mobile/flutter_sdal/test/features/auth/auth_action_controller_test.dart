import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_sdal/app/providers.dart';
import 'package:flutter_sdal/core/config/app_config.dart';
import 'package:flutter_sdal/core/network/api_client.dart';
import 'package:flutter_sdal/core/network/api_result.dart';
import 'package:flutter_sdal/core/network/api_result_parser.dart';
import 'package:flutter_sdal/core/session/session_controller.dart';
import 'package:flutter_sdal/core/session/session_models.dart';
import 'package:flutter_sdal/core/state/async_action_state.dart';
import 'package:flutter_sdal/features/auth/application/auth_action_controller.dart';
import '../../test_support/fake_api_client.dart';

void main() {
  test('AuthActionController reports success for login', () async {
    final container = ProviderContainer(overrides: _baseOverrides());
    addTearDown(container.dispose);

    final notifier = container.read(authActionControllerProvider.notifier);
    await notifier.login(username: 'member', password: 'secret');

    final state = container.read(authActionControllerProvider);
    expect(state.status, AsyncActionStatus.success);
    expect(state.scope, 'login');
  });

  test('AuthActionController reports register failure from API', () async {
    final container = ProviderContainer(
      overrides: _baseOverrides(
        apiClient: _FakeAuthApiClient(registerOk: false),
      ),
    );
    addTearDown(container.dispose);

    final notifier = container.read(authActionControllerProvider.notifier);
    await notifier.register(
      username: 'member',
      password: 'secret',
      repeatPassword: 'secret',
      email: 'member@example.com',
      firstName: 'Ada',
      lastName: 'Lovelace',
      graduationYear: '2011',
      captcha: 'ABCD',
      kvkkConsent: true,
      directoryConsent: true,
    );

    final state = container.read(authActionControllerProvider);
    expect(state.status, AsyncActionStatus.error);
    expect(state.scope, 'register');
    expect(state.message, 'register fail');
  });

  test(
    'AuthActionController reports provider-disabled for missing OAuth link',
    () async {
      final container = ProviderContainer(
        overrides: _baseOverrides(
          sessionControllerFactory: () =>
              _FakeSessionController(oAuthProviders: const []),
        ),
      );
      addTearDown(container.dispose);

      await container
          .read(authActionControllerProvider.notifier)
          .startOAuth('google');

      final state = container.read(authActionControllerProvider);
      expect(state.status, AsyncActionStatus.error);
      expect(state.scope, 'oauth');
      expect(state.message, 'OAuth sağlayıcısı şu anda kullanılamıyor.');
    },
  );

  test('AuthActionController reports callback OAuth error', () async {
    final container = ProviderContainer(
      overrides: _baseOverrides(
        oauthAuthenticate:
            ({required String url, required String callbackUrlScheme}) async =>
                '$callbackUrlScheme://oauth?oauth=access_denied',
      ),
    );
    addTearDown(container.dispose);

    await container
        .read(authActionControllerProvider.notifier)
        .startOAuth('google');

    final state = container.read(authActionControllerProvider);
    expect(state.status, AsyncActionStatus.error);
    expect(state.scope, 'oauth');
    expect(state.message, 'OAuth akışı tamamlanamadı: access_denied');
  });

  test('AuthActionController reports missing OAuth token', () async {
    final container = ProviderContainer(
      overrides: _baseOverrides(
        oauthAuthenticate:
            ({required String url, required String callbackUrlScheme}) async =>
                '$callbackUrlScheme://oauth?state=ok',
      ),
    );
    addTearDown(container.dispose);

    await container
        .read(authActionControllerProvider.notifier)
        .startOAuth('google');

    final state = container.read(authActionControllerProvider);
    expect(state.status, AsyncActionStatus.error);
    expect(state.scope, 'oauth');
    expect(state.message, 'OAuth dönüşünde oturum jetonu bulunamadı.');
  });

  test('AuthActionController reports OAuth exchange failure', () async {
    final container = ProviderContainer(
      overrides: _baseOverrides(
        sessionControllerFactory: () =>
            _FakeSessionController(exchangeMessage: 'exchange fail'),
        oauthAuthenticate:
            ({required String url, required String callbackUrlScheme}) async =>
                '$callbackUrlScheme://oauth?token=mobile-token',
      ),
    );
    addTearDown(container.dispose);

    await container
        .read(authActionControllerProvider.notifier)
        .startOAuth('google');

    final state = container.read(authActionControllerProvider);
    expect(state.status, AsyncActionStatus.error);
    expect(state.scope, 'oauth');
    expect(state.message, 'exchange fail');
  });
}

List<Override> _baseOverrides({
  ApiClient? apiClient,
  OAuthAuthenticate? oauthAuthenticate,
  _FakeSessionController Function()? sessionControllerFactory,
}) {
  return [
    appConfigProvider.overrideWithValue(_config),
    apiClientProvider.overrideWithValue(apiClient ?? _FakeAuthApiClient()),
    sessionControllerProvider.overrideWith(
      sessionControllerFactory ?? _FakeSessionController.new,
    ),
    if (oauthAuthenticate != null)
      oauthAuthenticateProvider.overrideWithValue(oauthAuthenticate),
  ];
}

class _FakeSessionController extends SessionController {
  _FakeSessionController({
    this.exchangeMessage,
    this.oAuthProviders = const [
      OAuthProviderLink(
        provider: 'google',
        title: 'Google',
        startUrl: '/api/auth/oauth/google/start',
        enabled: true,
      ),
    ],
  });

  final String? exchangeMessage;
  final List<OAuthProviderLink> oAuthProviders;

  @override
  Future<SessionSnapshot> build() async => _fakeSnapshot();

  @override
  Future<String?> login({
    required String username,
    required String password,
  }) async {
    return null;
  }

  @override
  Future<List<OAuthProviderLink>> fetchOAuthProviders() async => oAuthProviders;

  @override
  Future<String?> exchangeMobileOAuthToken(String token) async {
    return exchangeMessage;
  }
}

class _FakeAuthApiClient extends FakeApiClient {
  _FakeAuthApiClient({this.registerOk = true});

  final bool registerOk;

  @override
  Uri buildApiUri(String path, {Map<String, dynamic>? query}) {
    final uri = Uri.parse('https://example.com$path');
    final normalized = query?.map(
      (key, value) => MapEntry(key, value?.toString() ?? ''),
    );
    return normalized == null ? uri : uri.replace(queryParameters: normalized);
  }

  @override
  Future<ApiResult<T>> post<T>(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    ApiDecoder<T>? decoder,
  }) async {
    if (path == '/api/register') {
      return ApiResult<T>(
        ok: registerOk,
        statusCode: registerOk ? 200 : 400,
        message: registerOk ? 'ok' : 'register fail',
        code: '',
        data: null,
        rawData: <String, dynamic>{},
      );
    }
    return ApiResult<T>(
      ok: false,
      statusCode: 404,
      message: 'unexpected path',
      code: '',
      data: null,
      rawData: null,
    );
  }
}

const _config = AppConfig(
  apiBaseUrl: 'https://example.com/api',
  siteBaseUrl: 'https://example.com',
  appName: 'SDAL',
  oauthCallbackScheme: 'sdalnative',
);

SessionSnapshot _fakeSnapshot() {
  const siteAccess = SiteAccessSnapshot(
    siteOpen: true,
    maintenanceMessage: '',
    modules: <String, bool>{},
    defaultLandingPage: '/feed',
  );
  return const SessionSnapshot(
    config: _config,
    siteAccess: siteAccess,
    user: null,
  );
}
