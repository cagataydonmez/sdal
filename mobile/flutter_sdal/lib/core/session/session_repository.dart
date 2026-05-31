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

    final siteAccessPayload = _requireSiteAccessPayload(siteAccessResult);
    final sessionPayload = _resolveSessionPayload(sessionResult);
    final siteAccess = SiteAccessSnapshot.fromMap(siteAccessPayload);
    final userMap = asJsonMap(sessionPayload['user']);
    final user = userMap.isEmpty ? null : SessionUser.fromMap(userMap);

    // App Store 1.2: determine whether the authenticated user has accepted the
    // zero-tolerance EULA so the router can gate them until they do.
    var eulaAccepted = true;
    if (user != null) {
      final eulaResult = await apiClient.get<JsonMap>(
        '/api/legal/eula/status',
        decoder: (raw) => asJsonMap(raw),
      );
      if (eulaResult.ok) {
        eulaAccepted = asBool(asJsonMap(eulaResult.rawData)['accepted']) ?? false;
      }
    }
    final menuVisibility = asJsonMap(
      siteAccessPayload['menuVisibility'],
    ).map((key, value) => MapEntry(key, asBool(value) ?? true));
    final moduleMenuOrder =
        (siteAccessPayload['moduleMenuOrder'] as List?)
            ?.map(asString)
            .whereType<String>()
            .toList(growable: false) ??
        const <String>[];

    return SessionSnapshot(
      config: config,
      siteAccess: siteAccess,
      user: user,
      menuVisibility: menuVisibility,
      moduleMenuOrder: moduleMenuOrder,
      eulaAccepted: eulaAccepted,
    );
  }

  JsonMap _requireSiteAccessPayload(ApiResult<JsonMap> result) {
    if (result.ok) return asJsonMap(result.rawData);
    throw StateError(_bootstrapMessageFor(result));
  }

  JsonMap _resolveSessionPayload(ApiResult<JsonMap> result) {
    if (result.ok) return asJsonMap(result.rawData);
    if (result.statusCode == 0) {
      throw StateError(_bootstrapMessageFor(result));
    }
    return const <String, dynamic>{'user': null};
  }

  String _bootstrapMessageFor(ApiResult<dynamic> result) {
    if (result.statusCode == 0) {
      return 'Sunucuya ulasilamadi. Internet baglantinizi ve DNS ayarlarinizi kontrol edip tekrar deneyin.';
    }
    final message = result.message.trim();
    if (message.isNotEmpty) return message;
    return 'Uygulama baslatilamadi. Lutfen tekrar deneyin.';
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

  Future<ApiResult<JsonMap>> exchangeMobileOAuthToken(
    String token, {
    JsonMap device = const {},
  }) {
    return apiClient.post<JsonMap>(
      '/api/auth/oauth/mobile/exchange',
      body: {'token': token, ...device},
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
