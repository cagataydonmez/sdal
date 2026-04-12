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
import '../features/push_notifications/presentation/push_notifications_bootstrap.dart';

class SdalFlutterApp extends ConsumerWidget {
  const SdalFlutterApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionState = ref.watch(sessionControllerProvider);
    final themeMode = ref.watch(themeModeControllerProvider).themeMode;

    return sessionState.when(
      loading: () => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: sdalLightTheme,
        darkTheme: sdalDarkTheme,
        themeMode: themeMode,
        locale: const Locale('tr'),
        supportedLocales: const [Locale('tr'), Locale('en')],
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const AppSplashScreen(),
      ),
      error: (error, _) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: sdalLightTheme,
        darkTheme: sdalDarkTheme,
        themeMode: themeMode,
        locale: const Locale('tr'),
        supportedLocales: const [Locale('tr'), Locale('en')],
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
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
          theme: sdalLightTheme,
          darkTheme: sdalDarkTheme,
          themeMode: themeMode,
          locale: const Locale('tr'),
          supportedLocales: const [Locale('tr'), Locale('en')],
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          builder: (context, child) => _SessionExpiryBridge(
            child: LiveSyncBootstrap(
              child: PushNotificationsBootstrap(
                child: child ?? const SizedBox.shrink(),
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
  static const _fallbackHeartbeatInterval = Duration(seconds: 5);

  ProviderSubscription<AsyncValue<SessionSnapshot>>? _sessionSubscription;
  StreamSubscription<RealtimeConnectionState>? _messengerStatesSubscription;
  StreamSubscription<MessengerRealtimeEvent>? _messengerEventsSubscription;
  Timer? _heartbeatTimer;
  Duration? _heartbeatInterval;
  bool _isForeground = true;
  bool _isAuthenticated = false;
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
      _syncLiveServices();
    });
    final snapshot = ref.read(sessionControllerProvider).value;
    _isAuthenticated = snapshot?.isAuthenticated ?? false;
    _syncLiveServices();
    _sessionSubscription = ref.listenManual(sessionControllerProvider, (
      _,
      next,
    ) {
      _isAuthenticated = next.value?.isAuthenticated ?? false;
      _syncLiveServices();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _isForeground = switch (state) {
      AppLifecycleState.resumed => true,
      AppLifecycleState.inactive => true,
      AppLifecycleState.hidden => false,
      AppLifecycleState.paused => false,
      AppLifecycleState.detached => false,
    };
    _syncLiveServices();
  }

  void _handleMessengerEvent(MessengerRealtimeEvent event) {
    ref.invalidate(messengerThreadsProvider(''));
    ref.invalidate(messengerUnreadCountProvider);
    ref.invalidate(notificationUnreadCountProvider);
    ref.invalidate(notificationsProvider);
  }

  void _runHeartbeatTick() {
    ref.invalidate(messengerThreadsProvider(''));
    ref.invalidate(messengerUnreadCountProvider);
    ref.invalidate(notificationUnreadCountProvider);
    ref.invalidate(notificationsProvider);
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
    final interval = _messengerStatus == RealtimeConnectionStatus.connected
        ? _connectedHeartbeatInterval
        : _fallbackHeartbeatInterval;
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
  Widget build(BuildContext context) => widget.child;
}
