import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_sdal/app/providers.dart';
import 'package:flutter_sdal/core/config/app_config.dart';
import 'package:flutter_sdal/core/network/api_result.dart';
import 'package:flutter_sdal/core/network/api_result_parser.dart';
import 'package:flutter_sdal/core/session/session_controller.dart';
import 'package:flutter_sdal/core/session/session_models.dart';
import 'package:flutter_sdal/core/state/async_action_state.dart';
import 'package:flutter_sdal/features/auth/application/auth_action_controller.dart';
import '../../test_support/fake_api_client.dart';

void main() {
  test('AuthActionController reports success for login', () async {
    final container = ProviderContainer(
      overrides: [
        sessionControllerProvider.overrideWith(_FakeSessionController.new),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(authActionControllerProvider.notifier);
    await notifier.login(username: 'member', password: 'secret');

    final state = container.read(authActionControllerProvider);
    expect(state.status, AsyncActionStatus.success);
    expect(state.scope, 'login');
  });

  test('AuthActionController reports register failure from API', () async {
    final container = ProviderContainer(
      overrides: [
        apiClientProvider.overrideWithValue(
          _FakeAuthApiClient(registerOk: false),
        ),
        sessionControllerProvider.overrideWith(_FakeSessionController.new),
      ],
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
    );

    final state = container.read(authActionControllerProvider);
    expect(state.status, AsyncActionStatus.error);
    expect(state.scope, 'register');
    expect(state.message, 'register fail');
  });
}

class _FakeSessionController extends SessionController {
  @override
  Future<SessionSnapshot> build() async => _fakeSnapshot();

  @override
  Future<String?> login({
    required String username,
    required String password,
  }) async {
    return null;
  }
}

class _FakeAuthApiClient extends FakeApiClient {
  _FakeAuthApiClient({this.registerOk = true});

  final bool registerOk;

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

SessionSnapshot _fakeSnapshot() {
  const config = AppConfig(
    apiBaseUrl: 'https://example.com/api',
    siteBaseUrl: 'https://example.com',
    appName: 'SDAL',
    oauthCallbackScheme: 'sdalnative',
  );
  const siteAccess = SiteAccessSnapshot(
    siteOpen: true,
    maintenanceMessage: '',
    modules: <String, bool>{},
    defaultLandingPage: '/feed',
  );
  return const SessionSnapshot(
    config: config,
    siteAccess: siteAccess,
    user: null,
  );
}
