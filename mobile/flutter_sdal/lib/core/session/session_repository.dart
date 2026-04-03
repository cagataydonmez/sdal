import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/providers.dart';
import '../config/app_config.dart';
import '../network/api_client.dart';
import '../network/api_result.dart';
import '../network/json_utils.dart';
import 'session_models.dart';

class SessionRepository {
  const SessionRepository({required this.apiClient, required this.config});

  final ApiClient apiClient;
  final AppConfig config;

  Future<SessionSnapshot> bootstrap() async {
    final siteAccessResult = await apiClient.get<JsonMap>(
      '/api/site-access',
      decoder: (raw) => asJsonMap(raw),
    );
    final sessionResult = await apiClient.get<JsonMap>(
      '/api/session',
      decoder: (raw) => asJsonMap(raw),
    );

    final siteAccess = SiteAccessSnapshot.fromMap(
      siteAccessResult.rawData is JsonMap
          ? siteAccessResult.rawData as JsonMap
          : asJsonMap(siteAccessResult.rawData),
    );
    final sessionPayload = asJsonMap(sessionResult.rawData);
    final userMap = asJsonMap(sessionPayload['user']);
    final user = userMap.isEmpty ? null : SessionUser.fromMap(userMap);

    return SessionSnapshot(config: config, siteAccess: siteAccess, user: user);
  }

  Future<ApiResult<JsonMap>> login({
    required String username,
    required String password,
  }) {
    return apiClient.post<JsonMap>(
      '/api/auth/login',
      body: {'kadi': username, 'sifre': password},
      decoder: (raw) => asJsonMap(raw),
    );
  }

  Future<ApiResult<void>> logout() {
    return apiClient.post<void>('/api/auth/logout');
  }

  Future<List<OAuthProviderLink>> fetchOAuthProviders() async {
    final result = await apiClient.get<JsonMap>(
      '/api/auth/oauth/providers',
      decoder: (raw) => asJsonMap(raw),
    );
    final payload = asJsonMap(result.rawData);
    final providers = asJsonMapList(payload['providers']);
    return providers
        .map(OAuthProviderLink.fromMap)
        .where((item) => item.enabled)
        .toList(growable: false);
  }

  Future<ApiResult<JsonMap>> exchangeMobileOAuthToken(String token) {
    return apiClient.post<JsonMap>(
      '/api/auth/oauth/mobile/exchange',
      body: {'token': token},
      decoder: (raw) => asJsonMap(raw),
    );
  }
}

final sessionRepositoryProvider = Provider<SessionRepository>(
  (ref) => SessionRepository(
    apiClient: ref.watch(apiClientProvider),
    config: ref.watch(appConfigProvider),
  ),
);
