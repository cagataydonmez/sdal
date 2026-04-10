import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'session_models.dart';
import 'session_repository.dart';

class SessionController extends AsyncNotifier<SessionSnapshot> {
  SessionRepository get _repository => ref.read(sessionRepositoryProvider);

  @override
  Future<SessionSnapshot> build() {
    return _repository.bootstrap();
  }

  Future<String?> login({
    required String username,
    required String password,
  }) async {
    final result = await _repository.login(
      username: username,
      password: password,
    );
    if (!result.ok) {
      return result.message.isNotEmpty
          ? result.message
          : 'Giriş başarısız oldu.';
    }
    state = const AsyncLoading();
    state = await AsyncValue.guard(_repository.bootstrap);
    return state.hasError ? state.error.toString() : null;
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_repository.bootstrap);
  }

  void expire() {
    final snapshot = state.valueOrNull;
    if (snapshot == null) {
      ref.invalidateSelf();
      return;
    }
    if (!snapshot.isAuthenticated) return;
    state = AsyncData(
      SessionSnapshot(
        config: snapshot.config,
        siteAccess: snapshot.siteAccess,
        user: null,
        menuVisibility: snapshot.menuVisibility,
        moduleMenuOrder: snapshot.moduleMenuOrder,
      ),
    );
  }

  Future<String?> logout() async {
    final result = await _repository.logout();
    if (!result.ok && result.statusCode != 204) {
      return result.message.isNotEmpty ? result.message : 'Çıkış yapılamadı.';
    }
    state = await AsyncValue.guard(_repository.bootstrap);
    return state.hasError ? state.error.toString() : null;
  }

  Future<List<OAuthProviderLink>> fetchOAuthProviders() {
    return _repository.fetchOAuthProviders();
  }

  Future<String?> exchangeMobileOAuthToken(String token) async {
    final result = await _repository.exchangeMobileOAuthToken(token);
    if (!result.ok) {
      return result.message.isNotEmpty
          ? result.message
          : 'OAuth oturumu açılamadı.';
    }
    state = const AsyncLoading();
    state = await AsyncValue.guard(_repository.bootstrap);
    return state.hasError ? state.error.toString() : null;
  }
}

final sessionControllerProvider =
    AsyncNotifierProvider<SessionController, SessionSnapshot>(
      SessionController.new,
    );
