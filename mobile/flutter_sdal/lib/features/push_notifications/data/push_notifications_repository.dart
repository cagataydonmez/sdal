import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_result.dart';
import '../../../core/network/json_utils.dart';
import 'push_notifications_store.dart';

class PushNotificationsRepository {
  const PushNotificationsRepository({
    required this.apiClient,
    required this.store,
  });

  final ApiClient apiClient;
  final PushNotificationsStore store;

  Future<ApiResult<JsonMap>> registerDevice({
    required String installationId,
    required String platform,
    required String pushToken,
    String locale = '',
    String appVersion = '',
  }) {
    return apiClient.post<JsonMap>(
      '/api/new/mobile/push/register',
      body: {
        'installation_id': installationId,
        'platform': platform,
        'push_token': pushToken,
        if (locale.trim().isNotEmpty) 'locale': locale.trim(),
        if (appVersion.trim().isNotEmpty) 'app_version': appVersion.trim(),
      },
      decoder: asJsonMap,
    );
  }

  Future<ApiResult<JsonMap>> unregisterDevice({
    required String installationId,
    String pushToken = '',
  }) {
    return apiClient.post<JsonMap>(
      '/api/new/mobile/push/unregister',
      body: {
        'installation_id': installationId,
        if (pushToken.trim().isNotEmpty) 'push_token': pushToken.trim(),
      },
      decoder: asJsonMap,
    );
  }
}

final pushNotificationsStoreProvider = FutureProvider<PushNotificationsStore>(
  (_) => PushNotificationsStore.create(),
);

final pushNotificationsRepositoryProvider =
    FutureProvider<PushNotificationsRepository>((ref) async {
      final store = await ref.watch(pushNotificationsStoreProvider.future);
      return PushNotificationsRepository(
        apiClient: ref.watch(apiClientProvider),
        store: store,
      );
    });
