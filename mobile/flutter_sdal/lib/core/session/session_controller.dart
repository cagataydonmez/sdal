import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'session_models.dart';
import 'session_repository.dart';

class SessionController extends AsyncNotifier<SessionSnapshot> {
  SessionRepository get _repository => ref.read(sessionRepositoryProvider);
  bool _refreshInFlight = false;

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
    // Skip AsyncLoading here — setting it would swap MaterialApp.router to the
    // splash MaterialApp and back, causing a Duplicate GlobalKey crash because
    // _rootNavigatorKey is torn from the tree while GoRouter still holds it.
    // The login page stays visible while bootstrap runs; GoRouter's redirect
    // handles the /login → home navigation once the state is authenticated.
    state = await AsyncValue.guard(_repository.bootstrap);
    return state.hasError ? state.error.toString() : null;
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_repository.bootstrap);
  }

  Future<void> refreshSilently() async {
    if (_refreshInFlight) return;
    _refreshInFlight = true;
    try {
      final next = await AsyncValue.guard(_repository.bootstrap);
      if (next.hasValue) {
        state = next;
      }
    } finally {
      _refreshInFlight = false;
    }
  }

  void expire() {
    final snapshot = state.value;
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
    // Same as login(): skip AsyncLoading to avoid the MaterialApp swap that
    // causes a Duplicate GlobalKey crash.
    state = await AsyncValue.guard(_repository.bootstrap);
    return state.hasError ? state.error.toString() : null;
  }
}

final sessionControllerProvider =
    AsyncNotifierProvider<SessionController, SessionSnapshot>(
      SessionController.new,
    );
