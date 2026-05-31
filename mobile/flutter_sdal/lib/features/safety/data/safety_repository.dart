import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/providers.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_result.dart';
import '../../../core/network/json_utils.dart';

/// Backend client for App Store 1.2 user-safety features:
/// EULA acceptance, reporting (flagging) content and blocking abusive users.
class SafetyRepository {
  const SafetyRepository(this._apiClient);

  final ApiClient _apiClient;

  /// Whether the current user has accepted the zero-tolerance EULA.
  /// Fails open (returns true) on transient errors so users are never locked
  /// out of the app by a network hiccup — the gate still works on success.
  Future<bool> isEulaAccepted() async {
    final result = await _apiClient.get<JsonMap>(
      '/api/legal/eula/status',
      decoder: (raw) => asJsonMap(raw),
    );
    if (!result.ok) return true;
    return asBool(asJsonMap(result.rawData)['accepted']) ?? false;
  }

  Future<ApiResult<void>> acceptEula() {
    return _apiClient.post<void>('/api/legal/eula/accept');
  }

  Future<ApiResult<void>> reportPost(int postId, String reason) {
    return _apiClient.post<void>(
      '/api/new/posts/$postId/report',
      body: {'reason': reason},
    );
  }

  Future<ApiResult<void>> reportComment(int postId, int commentId, String reason) {
    return _apiClient.post<void>(
      '/api/new/posts/$postId/comments/$commentId/report',
      body: {'reason': reason},
    );
  }

  Future<ApiResult<void>> blockUser(int userId) {
    return _apiClient.post<void>('/api/new/users/$userId/block');
  }

  Future<ApiResult<void>> unblockUser(int userId) {
    return _apiClient.delete<void>('/api/new/users/$userId/block');
  }

  Future<List<JsonMap>> listBlockedUsers() async {
    final result = await _apiClient.get<JsonMap>(
      '/api/new/blocks',
      decoder: (raw) => asJsonMap(raw),
    );
    if (!result.ok) return const <JsonMap>[];
    return asJsonMapList(asJsonMap(result.rawData)['items']);
  }
}

final safetyRepositoryProvider = Provider<SafetyRepository>(
  (ref) => SafetyRepository(ref.watch(apiClientProvider)),
);
