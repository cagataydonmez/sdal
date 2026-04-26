import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import '../../../app/providers.dart';
import '../../../core/network/json_utils.dart';
import '../../../core/state/async_action_state.dart';
import '../../../core/session/session_controller.dart';
import '../data/auth_repository.dart';

typedef OAuthAuthenticate =
    Future<String> Function({
      required String url,
      required String callbackUrlScheme,
    });

class LoginActionResult {
  const LoginActionResult({
    required this.success,
    this.activationRequired = false,
    this.captchaRequired = false,
    this.memberId = '',
    this.email = '',
    this.message = '',
  });

  final bool success;
  final bool activationRequired;
  final bool captchaRequired;
  final String memberId;
  final String email;
  final String message;
}

final oauthAuthenticateProvider = Provider<OAuthAuthenticate>(
  (ref) =>
      ({required String url, required String callbackUrlScheme}) =>
          FlutterWebAuth2.authenticate(
            url: url,
            callbackUrlScheme: callbackUrlScheme,
          ),
);

class AuthActionController extends Notifier<AsyncActionState> {
  @override
  AsyncActionState build() => const AsyncActionState.idle();

  Future<void> login({
    required String username,
    required String password,
    String captcha = '',
  }) async {
    state = const AsyncActionState.loading(scope: 'login');
    final result = await ref
        .read(apiClientProvider)
        .post<JsonMap>(
          '/api/auth/login',
          body: {
            'kadi': username,
            'sifre': password,
            if (captcha.trim().isNotEmpty) 'gkodu': captcha.trim(),
          },
          decoder: asJsonMap,
        );
    if (!ref.mounted) return;
    if (result.ok) {
      await ref.read(sessionControllerProvider.notifier).refreshSilently();
      if (!ref.mounted) return;
      state = const AsyncActionState.success(scope: 'login');
      return;
    }
    final message = result.message.isNotEmpty
        ? result.message
        : 'Giriş başarısız oldu.';
    state = AsyncActionState.error(message: message, scope: 'login');
  }

  Future<LoginActionResult> loginWithResult({
    required String username,
    required String password,
    String captcha = '',
  }) async {
    state = const AsyncActionState.loading(scope: 'login');
    final result = await ref
        .read(apiClientProvider)
        .post<JsonMap>(
          '/api/auth/login',
          body: {
            'kadi': username,
            'sifre': password,
            if (captcha.trim().isNotEmpty) 'gkodu': captcha.trim(),
          },
          decoder: asJsonMap,
        );
    if (!ref.mounted) {
      return const LoginActionResult(success: false);
    }
    if (result.ok) {
      await ref.read(sessionControllerProvider.notifier).refreshSilently();
      if (!ref.mounted) {
        return const LoginActionResult(success: true);
      }
      state = const AsyncActionState.success(scope: 'login');
      return const LoginActionResult(success: true);
    }
    final payload = asJsonMap(result.rawData);
    final code = result.code.isNotEmpty
        ? result.code
        : (asString(payload['code']) ?? '');
    final message = result.message.isNotEmpty
        ? result.message
        : 'Giriş başarısız oldu.';
    state = AsyncActionState.error(message: message, scope: 'login');
    return LoginActionResult(
      success: false,
      activationRequired: code == 'ACTIVATION_REQUIRED',
      captchaRequired: code == 'CAPTCHA_REQUIRED' || code == 'CAPTCHA_INVALID',
      memberId: asString(payload['memberId']) ?? '',
      email: asString(payload['email']) ?? '',
      message: message,
    );
  }

  Future<void> startOAuth(String provider) async {
    state = const AsyncActionState.loading(scope: 'oauth');

    try {
      final result = await ref
          .read(authRepositoryProvider)
          .runOAuthFlow(
            provider: provider,
            authenticate: ref.read(oauthAuthenticateProvider),
          );
      if (!ref.mounted) return;
      if (!result.providerAvailable || result.errorMessage.isNotEmpty) {
        state = AsyncActionState.error(
          message: result.errorMessage,
          scope: 'oauth',
        );
        return;
      }
      final message = await ref
          .read(sessionControllerProvider.notifier)
          .exchangeMobileOAuthToken(result.token);
      if (!ref.mounted) return;
      state = message == null
          ? const AsyncActionState.success(scope: 'oauth')
          : AsyncActionState.error(message: message, scope: 'oauth');
    } catch (error) {
      if (!ref.mounted) return;
      state = AsyncActionState.error(message: error.toString(), scope: 'oauth');
    }
  }

  Future<String> fetchLegalContent(String path) {
    return ref.read(authRepositoryProvider).fetchLegalContent(path);
  }

  Future<JsonMap?> register({
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
    if (!ref.mounted) return null;
    if (result.ok) {
      state = const AsyncActionState.success(
        message:
            'Kayıt isteği gönderildi. Aktivasyon e-postasını kontrol edin.',
        scope: 'register',
      );
      return asJsonMap(result.rawData);
    }
    state = AsyncActionState.error(message: result.message, scope: 'register');
    return asJsonMap(result.rawData);
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
    if (!ref.mounted) return;
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
    if (!ref.mounted) return;
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
    if (!ref.mounted) return;
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
    NotifierProvider.autoDispose<AuthActionController, AsyncActionState>(
      AuthActionController.new,
    );
