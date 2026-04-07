import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import '../../../app/providers.dart';
import '../../../core/network/json_utils.dart';
import '../../../core/state/async_action_state.dart';
import '../../../core/session/session_controller.dart';

class AuthActionController extends AutoDisposeNotifier<AsyncActionState> {
  @override
  AsyncActionState build() => const AsyncActionState.idle();

  Future<void> login({
    required String username,
    required String password,
  }) async {
    state = const AsyncActionState.loading(scope: 'login');
    final message = await ref
        .read(sessionControllerProvider.notifier)
        .login(username: username, password: password);
    state = message == null
        ? const AsyncActionState.success(scope: 'login')
        : AsyncActionState.error(message: message, scope: 'login');
  }

  Future<void> startOAuth(String provider) async {
    state = const AsyncActionState.loading(scope: 'oauth');

    try {
      final providers = await ref
          .read(sessionControllerProvider.notifier)
          .fetchOAuthProviders();
      final target = providers.firstWhere((item) => item.provider == provider);
      final config = ref.read(appConfigProvider);
      final apiClient = ref.read(apiClientProvider);
      final authUri = apiClient.buildApiUri(
        target.startUrl,
        query: const {'native': '1'},
      );
      final callbackUrl = await FlutterWebAuth2.authenticate(
        url: authUri.toString(),
        callbackUrlScheme: config.oauthCallbackScheme,
      );
      final callback = Uri.parse(callbackUrl);
      final token = callback.queryParameters['token'];
      final oauthError = callback.queryParameters['oauth'];
      if (oauthError != null && oauthError.isNotEmpty) {
        state = AsyncActionState.error(
          message: 'OAuth akışı tamamlanamadı: $oauthError',
          scope: 'oauth',
        );
        return;
      }
      if (token == null || token.isEmpty) {
        state = const AsyncActionState.error(
          message: 'OAuth dönüşünde oturum jetonu bulunamadı.',
          scope: 'oauth',
        );
        return;
      }
      final message = await ref
          .read(sessionControllerProvider.notifier)
          .exchangeMobileOAuthToken(token);
      state = message == null
          ? const AsyncActionState.success(scope: 'oauth')
          : AsyncActionState.error(message: message, scope: 'oauth');
    } catch (error) {
      state = AsyncActionState.error(message: error.toString(), scope: 'oauth');
    }
  }

  Future<void> register({
    required String username,
    required String password,
    required String repeatPassword,
    required String email,
    required String firstName,
    required String lastName,
    required String graduationYear,
    required String captcha,
    required bool kvkkConsent,
    required bool directoryConsent,
  }) async {
    state = const AsyncActionState.loading(scope: 'register');
    final result = await ref
        .read(apiClientProvider)
        .post<JsonMap>(
          '/api/register',
          body: {
            'kadi': username,
            'sifre': password,
            'sifre2': repeatPassword,
            'email': email,
            'isim': firstName,
            'soyisim': lastName,
            'mezuniyetyili': graduationYear,
            'gkodu': captcha,
            'kvkk_consent': kvkkConsent,
            'directory_consent': directoryConsent,
          },
          decoder: asJsonMap,
        );
    state = result.ok
        ? const AsyncActionState.success(
            message:
                'Kayıt isteği gönderildi. Aktivasyon e-postasını kontrol edin.',
            scope: 'register',
          )
        : AsyncActionState.error(message: result.message, scope: 'register');
  }

  Future<void> activate({
    required String memberId,
    required String code,
  }) async {
    state = const AsyncActionState.loading(scope: 'activate');
    final result = await ref
        .read(apiClientProvider)
        .get<JsonMap>(
          '/api/activate',
          query: {'id': memberId, 'akt': code},
          decoder: asJsonMap,
        );
    state = result.ok
        ? AsyncActionState.success(
            message: result.message.isNotEmpty
                ? result.message
                : 'Aktivasyon tamamlandı.',
            scope: 'activate',
          )
        : AsyncActionState.error(
            message: result.message.isNotEmpty
                ? result.message
                : 'Aktivasyon başarısız.',
            scope: 'activate',
          );
  }

  Future<void> resendActivation({
    required String memberId,
    required String email,
  }) async {
    state = const AsyncActionState.loading(scope: 'resendActivation');
    final result = await ref
        .read(apiClientProvider)
        .post<JsonMap>(
          '/api/activation/resend',
          body: {'id': memberId, 'email': email},
          decoder: asJsonMap,
        );
    state = result.ok
        ? AsyncActionState.success(
            message: result.message.isNotEmpty
                ? result.message
                : 'Aktivasyon e-postası yeniden gönderildi.',
            scope: 'resendActivation',
          )
        : AsyncActionState.error(
            message: result.message.isNotEmpty
                ? result.message
                : 'İşlem başarısız.',
            scope: 'resendActivation',
          );
  }

  Future<void> requestPasswordReset({
    required String username,
    required String email,
  }) async {
    state = const AsyncActionState.loading(scope: 'passwordReset');
    final result = await ref
        .read(apiClientProvider)
        .post<JsonMap>(
          '/api/password-reset',
          body: {'kadi': username, 'email': email},
          decoder: asJsonMap,
        );
    state = result.ok
        ? AsyncActionState.success(
            message: result.message.isNotEmpty
                ? result.message
                : 'Şifre sıfırlama e-postası gönderildi.',
            scope: 'passwordReset',
          )
        : AsyncActionState.error(
            message: result.message.isNotEmpty
                ? result.message
                : 'İşlem başarısız.',
            scope: 'passwordReset',
          );
  }

  void reset() {
    state = const AsyncActionState.idle();
  }
}

final authActionControllerProvider =
    AutoDisposeNotifierProvider<AuthActionController, AsyncActionState>(
      AuthActionController.new,
    );
