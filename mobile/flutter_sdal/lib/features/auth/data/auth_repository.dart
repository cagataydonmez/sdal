import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/providers.dart';
import '../../../core/network/json_utils.dart';
import '../../../core/session/session_models.dart';
import '../../../core/session/session_repository.dart';
import '../application/auth_action_controller.dart';

class OAuthFlowResult {
  const OAuthFlowResult({
    required this.providerAvailable,
    this.token = '',
    this.errorMessage = '',
  });

  final bool providerAvailable;
  final String token;
  final String errorMessage;
}

class AuthRepository {
  const AuthRepository({
    required this.sessionRepository,
    required this.apiClient,
  });

  final SessionRepository sessionRepository;
  final dynamic apiClient;

  Future<OAuthFlowResult> runOAuthFlow({
    required String provider,
    required OAuthAuthenticate authenticate,
  }) async {
    final providers = await sessionRepository.fetchOAuthProviders();
    OAuthProviderLink? target;
    for (final item in providers) {
      if (item.provider == provider) {
        target = item;
        break;
      }
    }
    if (target == null) {
      return const OAuthFlowResult(
        providerAvailable: false,
        errorMessage: 'OAuth sağlayıcısı şu anda kullanılamıyor.',
      );
    }
    final authUri = apiClient.buildApiUri(
      target.startUrl,
      query: const {'native': '1'},
    );
    final callbackUrl = await authenticate(
      url: authUri.toString(),
      callbackUrlScheme: sessionRepository.config.oauthCallbackScheme,
    );
    final callback = Uri.parse(callbackUrl);
    final oauthError = callback.queryParameters['oauth'];
    if (oauthError != null && oauthError.isNotEmpty) {
      return OAuthFlowResult(
        providerAvailable: true,
        errorMessage: 'OAuth akışı tamamlanamadı: $oauthError',
      );
    }
    final token = callback.queryParameters['token'] ?? '';
    if (token.isEmpty) {
      return const OAuthFlowResult(
        providerAvailable: true,
        errorMessage: 'OAuth dönüşünde oturum jetonu bulunamadı.',
      );
    }
    return OAuthFlowResult(providerAvailable: true, token: token);
  }

  Future<String> fetchLegalContent(String path) async {
    final result = await apiClient.get<String>(
      path,
      decoder: (raw) => raw?.toString() ?? '',
    );
    return coalesceText([result.rawData], fallback: '');
  }
}

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(
    sessionRepository: ref.watch(sessionRepositoryProvider),
    apiClient: ref.watch(apiClientProvider),
  ),
);
