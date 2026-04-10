import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../app/providers.dart';
import '../core/l10n/context_l10n.dart';
import '../l10n/generated/app_localizations.dart';
import '../core/routing/app_router.dart';
import '../core/session/session_controller.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/theme_mode_controller.dart';
import '../core/theme/theme_mode_store.dart';
import '../core/widgets/status_views.dart';
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
            child: PushNotificationsBootstrap(
              child: child ?? const SizedBox.shrink(),
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
  VoidCallback? _handler;

  @override
  void initState() {
    super.initState();
    final apiClient = ref.read(apiClientProvider);
    _handler = () {
      ref.read(sessionControllerProvider.notifier).expire();
    };
    apiClient.onUnauthorized = _handler;
  }

  @override
  void dispose() {
    final apiClient = ref.read(apiClientProvider);
    if (identical(apiClient.onUnauthorized, _handler)) {
      apiClient.onUnauthorized = null;
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
