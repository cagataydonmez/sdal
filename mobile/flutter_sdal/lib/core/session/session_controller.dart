import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../watch/watch_bridge_service.dart';
import '../../app/providers.dart';
import 'session_models.dart';
import 'session_repository.dart';

class SessionController extends AsyncNotifier<SessionSnapshot> {
  SessionRepository get _repository => ref.read(sessionRepositoryProvider);
  bool _refreshInFlight = false;

  @override
  Future<SessionSnapshot> build() async {
    final snapshot = await _repository.bootstrap();
    if (snapshot.isAuthenticated) _syncWatch(snapshot);
    return snapshot;
  }

  /// Pushes the current session cookie to the Watch companion app.
  void _syncWatch(SessionSnapshot snapshot) {
    final apiClient = ref.read(apiClientProvider);
    final siteUri = snapshot.config.siteBaseUri;
    apiClient.cookieHeaderForUri(siteUri).then((cookie) {
      if (cookie != null && cookie.isNotEmpty) {
        WatchBridgeService.pushSession(
          cookie: cookie,
          baseUrl: snapshot.config.siteBaseUrl,
          userId: snapshot.user?.id ?? 0,
          userPhoto: snapshot.user?.photo ?? '',
          activeTheme: snapshot.siteAccess.activeTheme.id,
        );
      }
    });
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
    if (state.value?.isAuthenticated == true) _syncWatch(state.value!);
    return state.hasError ? state.error.toString() : null;
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_repository.bootstrap);
    final snapshot = state.value;
    if (snapshot?.isAuthenticated == true) _syncWatch(snapshot!);
  }

  Future<bool> refreshSilently() async {
    if (_refreshInFlight) return true;
    _refreshInFlight = true;
    try {
      final next = await AsyncValue.guard(_repository.bootstrap);
      if (next.hasValue) {
        state = next;
        final snapshot = next.value;
        if (snapshot?.isAuthenticated == true) _syncWatch(snapshot!);
        return true;
      }
      return false;
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
    WatchBridgeService.clearSession();
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
    WatchBridgeService.clearSession();
    state = await AsyncValue.guard(_repository.bootstrap);
    return state.hasError ? state.error.toString() : null;
  }

  Future<List<OAuthProviderLink>> fetchOAuthProviders() {
    return _repository.fetchOAuthProviders();
  }

  Future<String?> exchangeMobileOAuthToken(
    String token, {
    Map<String, dynamic> device = const {},
  }) async {
    final result = await _repository.exchangeMobileOAuthToken(
      token,
      device: device,
    );
    if (!result.ok) {
      return result.message.isNotEmpty
          ? result.message
          : 'OAuth oturumu açılamadı.';
    }
    // Same as login(): skip AsyncLoading to avoid the MaterialApp swap that
    // causes a Duplicate GlobalKey crash.
    state = await AsyncValue.guard(_repository.bootstrap);
    if (state.value?.isAuthenticated == true) _syncWatch(state.value!);
    return state.hasError ? state.error.toString() : null;
  }
}

final sessionControllerProvider =
    AsyncNotifierProvider<SessionController, SessionSnapshot>(
      SessionController.new,
    );
