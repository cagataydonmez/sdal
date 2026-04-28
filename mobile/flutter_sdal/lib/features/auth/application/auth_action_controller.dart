import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import '../../../app/providers.dart';
import '../../../core/network/json_utils.dart';
import '../../../core/security/device_identity_service.dart';
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
    this.deviceChallengeRequired = false,
    this.memberId = '',
    this.username = '',
    this.email = '',
    this.message = '',
  });

  final bool success;
  final bool activationRequired;
  final bool captchaRequired;
  final bool deviceChallengeRequired;
  final String memberId;
  final String username;
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
    final device = await ref.read(deviceIdentityServiceProvider).metadata();
    final result = await ref
        .read(apiClientProvider)
        .post<JsonMap>(
          '/api/auth/login',
          body: {
            'kadi': username,
            'sifre': password,
            if (captcha.trim().isNotEmpty) 'gkodu': captcha.trim(),
            ...device.toJson(),
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
    final device = await ref.read(deviceIdentityServiceProvider).metadata();
    final result = await ref
        .read(apiClientProvider)
        .post<JsonMap>(
          '/api/auth/login',
          body: {
            'kadi': username,
            'sifre': password,
            if (captcha.trim().isNotEmpty) 'gkodu': captcha.trim(),
            ...device.toJson(),
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
      deviceChallengeRequired: code == 'DEVICE_CHALLENGE_REQUIRED',
      memberId: asString(payload['memberId']) ?? '',
      username:
          asString(payload['username']) ??
          asString(payload['kadi']) ??
          username,
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
      if (_isOAuthCancellation(error)) {
        state = const AsyncActionState.idle();
        return;
      }
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
    final device = await ref.read(deviceIdentityServiceProvider).metadata();
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
            ...device.toJson(),
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
    String memberId = '',
    String username = '',
    String password = '',
    String email = '',
    required String code,
  }) async {
    state = const AsyncActionState.loading(scope: 'activate');
    final result = memberId.trim().isNotEmpty
        ? await ref
              .read(apiClientProvider)
              .get<JsonMap>(
                '/api/activate',
                query: {'id': memberId.trim(), 'akt': code},
                decoder: asJsonMap,
              )
        : await ref
              .read(apiClientProvider)
              .post<JsonMap>(
                '/api/activate',
                body: {
                  'kadi': username.trim(),
                  if (password.isNotEmpty) 'sifre': password,
                  if (email.trim().isNotEmpty) 'email': email.trim(),
                  'akt': code,
                },
                decoder: asJsonMap,
              );
    if (!ref.mounted) return;
    if (result.ok) {
      state = AsyncActionState.success(
        message: result.message.isNotEmpty
            ? result.message
            : 'Aktivasyon tamamlandı.',
        scope: 'activate',
      );
      return;
    }
    state = AsyncActionState.error(
      message: result.message.isNotEmpty
          ? result.message
          : 'Aktivasyon başarısız.',
      scope: 'activate',
    );
  }

  Future<bool> startPhoneVerification({required String phoneNumber}) async {
    state = const AsyncActionState.loading(scope: 'phoneStart');
    final device = await ref.read(deviceIdentityServiceProvider).metadata();
    final result = await ref
        .read(apiClientProvider)
        .post<JsonMap>(
          '/api/auth/phone/start',
          body: {'phone_number': phoneNumber, 'device_id': device.deviceId},
          decoder: asJsonMap,
        );
    if (!ref.mounted) return false;
    state = result.ok
        ? const AsyncActionState.success(scope: 'phoneStart')
        : AsyncActionState.error(
            message: result.message.isNotEmpty
                ? result.message
                : 'Too many attempts. Please try again later.',
            scope: 'phoneStart',
          );
    return result.ok;
  }

  Future<bool> completePhoneVerification({
    required String phoneNumber,
    required String firebaseIdToken,
  }) async {
    state = const AsyncActionState.loading(scope: 'phoneComplete');
    final device = await ref.read(deviceIdentityServiceProvider).metadata();
    final result = await ref
        .read(apiClientProvider)
        .post<JsonMap>(
          '/api/auth/phone/complete',
          body: {
            'phone_number': phoneNumber,
            'firebase_id_token': firebaseIdToken,
            ...device.toJson(),
          },
          decoder: asJsonMap,
        );
    if (!ref.mounted) return false;
    if (result.ok) {
      await ref.read(sessionControllerProvider.notifier).refreshSilently();
      if (!ref.mounted) return true;
      state = const AsyncActionState.success(scope: 'phoneComplete');
      return true;
    }
    state = AsyncActionState.error(
      message: result.message.isNotEmpty
          ? result.message
          : 'Invalid code or expired session.',
      scope: 'phoneComplete',
    );
    return false;
  }

  Future<bool> completeDeviceEmailChallenge({required String code}) async {
    state = const AsyncActionState.loading(scope: 'deviceChallenge');
    final device = await ref.read(deviceIdentityServiceProvider).metadata();
    final result = await ref
        .read(apiClientProvider)
        .post<JsonMap>(
          '/api/auth/device/challenge/complete',
          body: {...device.toJson(), 'code': code.trim()},
          decoder: asJsonMap,
        );
    if (!ref.mounted) return false;
    if (result.ok) {
      await ref.read(sessionControllerProvider.notifier).refreshSilently();
      if (!ref.mounted) return true;
      state = const AsyncActionState.success(scope: 'deviceChallenge');
      return true;
    }
    state = AsyncActionState.error(
      message: result.message.isNotEmpty
          ? result.message
          : 'Invalid code or expired session.',
      scope: 'deviceChallenge',
    );
    return false;
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

bool _isOAuthCancellation(Object error) {
  final text = error.toString().toLowerCase();
  return text.contains('canceled') ||
      text.contains('cancelled') ||
      text.contains('user_cancelled') ||
      text.contains('user cancelled');
}

final authActionControllerProvider =
    NotifierProvider.autoDispose<AuthActionController, AsyncActionState>(
      AuthActionController.new,
    );
