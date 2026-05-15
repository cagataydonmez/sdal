import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../app/providers.dart';
import '../core/network/api_client.dart';
import '../core/l10n/context_l10n.dart';
import '../core/network/realtime_connection_state.dart';
import '../l10n/generated/app_localizations.dart';
import '../core/routing/app_router.dart';
import '../core/session/session_controller.dart';
import '../core/session/session_models.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/theme_mode_controller.dart';
import '../core/theme/theme_mode_store.dart';
import '../core/widgets/status_views.dart';
import '../features/messenger/data/messenger_repository.dart';
import '../features/notifications/data/notifications_repository.dart';
import '../features/admin/presentation/admin_api_monitor_widgets.dart';
import '../features/albums/data/albums_repository.dart';
import '../features/explore/data/explore_repository.dart';
import '../features/feed/data/feed_repository.dart';
import '../features/groups/data/groups_repository.dart';
import '../features/push_notifications/presentation/push_notifications_bootstrap.dart';

class SdalFlutterApp extends ConsumerStatefulWidget {
  const SdalFlutterApp({super.key});

  @override
  ConsumerState<SdalFlutterApp> createState() => _SdalFlutterAppState();
}

class _SdalFlutterAppState extends ConsumerState<SdalFlutterApp> {
  @override
  void initState() {
    super.initState();
    // Persist admin-driven theme changes so the correct palette shows on
    // cold-start before the first network response. User-explicit picks are
    // persisted directly in ProfileSettingsPage via SdalUserThemeStore.
    ref.listenManual(sdalAdminThemeProvider, (previous, next) {
      if (previous == next) return;
      ref.read(sdalActiveThemeStoreProvider).save(next);
    });
  }

  @override
  Widget build(BuildContext context) {
    final sessionState = ref.watch(sessionControllerProvider);
    final themeMode = ref.watch(themeModeControllerProvider).themeMode;
    final appTheme = ref.watch(sdalActiveThemeProvider);
    final light = buildSdalLightTheme(appTheme);
    final dark = buildSdalDarkTheme(appTheme);

    const localizationsDelegates = [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ];
    const supportedLocales = [Locale('tr'), Locale('en')];
    const locale = Locale('tr');

    return sessionState.when(
      loading: () => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: light,
        darkTheme: dark,
        themeMode: themeMode,
        locale: locale,
        supportedLocales: supportedLocales,
        localizationsDelegates: localizationsDelegates,
        home: const AppSplashScreen(),
      ),
      error: (error, _) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: light,
        darkTheme: dark,
        themeMode: themeMode,
        locale: locale,
        supportedLocales: supportedLocales,
        localizationsDelegates: localizationsDelegates,
        home: Builder(
          builder: (context) => StatusScaffold(
            title: context.l10n.appInitFailedTitle,
            message: error.toString(),
            actionLabel: context.l10n.retry,
            onAction: () => ref.invalidate(sessionControllerProvider),
          ),
        ),
      ),
      data: (_) {
        final router = ref.watch(appRouterProvider);
        return MaterialApp.router(
          debugShowCheckedModeBanner: false,
          onGenerateTitle: (context) => AppLocalizations.of(context)!.appName,
          theme: light,
          darkTheme: dark,
          themeMode: themeMode,
          locale: locale,
          supportedLocales: supportedLocales,
          localizationsDelegates: localizationsDelegates,
          builder: (context, child) => GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
            child: _SessionExpiryBridge(
              child: LiveSyncBootstrap(
                child: AdminApiMonitorOverlayHost(
                  child: PushNotificationsBootstrap(
                    child: child ?? const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
          ),
          routerConfig: router,
        );
      },
    );
  }
}

class _SessionExpiryBridge extends ConsumerStatefulWidget {
  const _SessionExpiryBridge({required this.child});

  final Widget child;

  @override
  ConsumerState<_SessionExpiryBridge> createState() =>
      _SessionExpiryBridgeState();
}

class _SessionExpiryBridgeState extends ConsumerState<_SessionExpiryBridge> {
  late final ApiClient _apiClient;
  VoidCallback? _handler;

  @override
  void initState() {
    super.initState();
    _apiClient = ref.read(apiClientProvider);
    _handler = () {
      ref.read(sessionControllerProvider.notifier).expire();
    };
    _apiClient.onUnauthorized = _handler;
  }

  @override
  void dispose() {
    if (identical(_apiClient.onUnauthorized, _handler)) {
      _apiClient.onUnauthorized = null;
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class LiveSyncBootstrap extends ConsumerStatefulWidget {
  const LiveSyncBootstrap({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<LiveSyncBootstrap> createState() => _LiveSyncBootstrapState();
}

class _LiveSyncBootstrapState extends ConsumerState<LiveSyncBootstrap>
    with WidgetsBindingObserver {
  static const _connectedHeartbeatInterval = Duration(seconds: 30);
  static const _failedHeartbeatInterval = Duration(seconds: 30);
  static const _fallbackHeartbeatInterval = Duration(seconds: 5);

  ProviderSubscription<AsyncValue<SessionSnapshot>>? _sessionSubscription;
  StreamSubscription<RealtimeConnectionState>? _messengerStatesSubscription;
  StreamSubscription<MessengerRealtimeEvent>? _messengerEventsSubscription;
  Timer? _heartbeatTimer;
  Duration? _heartbeatInterval;
  DateTime? _lastSessionRefreshAt;
  bool _isForeground = true;
  bool _isAuthenticated = false;
  bool _serverReachable = true;
  RealtimeConnectionStatus _messengerStatus =
      RealtimeConnectionStatus.disconnected;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final messengerRealtime = ref.read(messengerRealtimeServiceProvider);
    _messengerEventsSubscription = ref
        .read(messengerRealtimeServiceProvider)
        .events
        .listen(_handleMessengerEvent);
    _messengerStatus = messengerRealtime.currentState.status;
    _messengerStatesSubscription = messengerRealtime.states.listen((state) {
      _messengerStatus = state.status;
      if (state.status == RealtimeConnectionStatus.connected) {
        _setServerReachable(true);
      } else if (state.status == RealtimeConnectionStatus.failed) {
        unawaited(_refreshSessionSnapshot(force: true));
      }
      _syncLiveServices();
    });
    final snapshot = ref.read(sessionControllerProvider).value;
    _isAuthenticated = snapshot?.isAuthenticated ?? false;
    _syncLiveServices();
    _sessionSubscription = ref.listenManual(sessionControllerProvider, (
      previous,
      next,
    ) {
      _handleSessionSnapshotChanged(previous, next);
      _isAuthenticated = next.value?.isAuthenticated ?? false;
      _syncLiveServices();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final wasForeground = _isForeground;
    _isForeground = switch (state) {
      AppLifecycleState.resumed => true,
      AppLifecycleState.inactive => true,
      AppLifecycleState.hidden => false,
      AppLifecycleState.paused => false,
      AppLifecycleState.detached => false,
    };
    if (!wasForeground && _isForeground) {
      unawaited(_refreshSessionSnapshot(force: true));
    }
    _syncLiveServices();
  }

  void _handleMessengerEvent(MessengerRealtimeEvent event) {
    ref.invalidate(messengerThreadsProvider(''));
    ref.invalidate(messengerUnreadCountProvider);
    ref.invalidate(notificationUnreadCountProvider);
    ref.invalidate(notificationsProvider);
  }

  void _handleSessionSnapshotChanged(
    AsyncValue<SessionSnapshot>? previous,
    AsyncValue<SessionSnapshot> next,
  ) {
    final previousYear = previous?.value?.user?.graduationYear ?? '';
    final nextYear = next.value?.user?.graduationYear ?? '';
    if (previousYear == nextYear) return;
    ref.invalidate(albumsDashboardProvider);
    ref.invalidate(myAlbumsProvider);
    ref.invalidate(feedPageProvider);
    ref.invalidate(feedItemsProvider);
    ref.invalidate(onlineMembersProvider);
    ref.invalidate(directoryMembersProvider);
    ref.invalidate(suggestionMembersProvider);
    ref.invalidate(latestMembersProvider);
    ref.invalidate(groupsListProvider);
  }

  void _runHeartbeatTick() {
    unawaited(
      _refreshSessionSnapshot(
        minInterval: _serverReachable
            ? const Duration(minutes: 2)
            : Duration.zero,
        force: !_serverReachable,
      ),
    );
    ref.invalidate(messengerThreadsProvider(''));
    ref.invalidate(messengerUnreadCountProvider);
    ref.invalidate(notificationUnreadCountProvider);
    ref.invalidate(notificationsProvider);
  }

  Future<bool> _refreshSessionSnapshot({
    Duration minInterval = const Duration(seconds: 20),
    bool force = false,
  }) {
    if (!_isAuthenticated) return Future.value(true);
    final now = DateTime.now();
    final last = _lastSessionRefreshAt;
    if (!force && last != null && now.difference(last) < minInterval) {
      return Future.value(_serverReachable);
    }
    _lastSessionRefreshAt = now;
    return ref.read(sessionControllerProvider.notifier).refreshSilently().then((
      ok,
    ) {
      _setServerReachable(ok);
      return ok;
    });
  }

  void _setServerReachable(bool value) {
    if (_serverReachable == value || !mounted) return;
    setState(() => _serverReachable = value);
    _ensureHeartbeatTimer();
  }

  void _syncLiveServices() {
    final messengerRealtime = ref.read(messengerRealtimeServiceProvider);
    final shouldStayLive = _isAuthenticated && _isForeground;
    if (shouldStayLive) {
      unawaited(messengerRealtime.start());
      _ensureHeartbeatTimer();
      return;
    }

    _heartbeatTimer?.cancel();
    _heartbeatInterval = null;
    _heartbeatTimer = null;
    unawaited(messengerRealtime.stop());
  }

  void _ensureHeartbeatTimer() {
    final interval = !_serverReachable
        ? _fallbackHeartbeatInterval
        : switch (_messengerStatus) {
            RealtimeConnectionStatus.connected => _connectedHeartbeatInterval,
            RealtimeConnectionStatus.failed => _failedHeartbeatInterval,
            _ => _fallbackHeartbeatInterval,
          };
    if (_heartbeatTimer != null &&
        _heartbeatTimer!.isActive &&
        _heartbeatInterval == interval) {
      return;
    }
    _heartbeatTimer?.cancel();
    _heartbeatInterval = interval;
    _heartbeatTimer = Timer.periodic(interval, (_) {
      _runHeartbeatTick();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _heartbeatTimer?.cancel();
    _heartbeatInterval = null;
    _messengerStatesSubscription?.cancel();
    _messengerEventsSubscription?.cancel();
    _sessionSubscription?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final showOfflineBanner =
        _isAuthenticated && _isForeground && !_serverReachable;
    return Column(
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: showOfflineBanner
              ? const _OfflineConnectionBanner()
              : const SizedBox.shrink(),
        ),
        Expanded(child: widget.child),
      ],
    );
  }
}

class _OfflineConnectionBanner extends StatelessWidget {
  const _OfflineConnectionBanner();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).languageCode.toLowerCase();
    final text = locale == 'tr'
        ? 'İnternet bağlantın yok. Sunucuya erişilemiyor.'
        : 'No internet connection. The server cannot be reached.';
    return Material(
      color: theme.colorScheme.errorContainer,
      child: SafeArea(
        bottom: false,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Icon(
                Icons.wifi_off_rounded,
                size: 18,
                color: theme.colorScheme.onErrorContainer,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  text,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onErrorContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
