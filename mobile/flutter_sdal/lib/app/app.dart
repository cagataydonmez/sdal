import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/l10n/context_l10n.dart';
import '../l10n/generated/app_localizations.dart';
import '../core/routing/app_router.dart';
import '../core/session/session_controller.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/theme_mode_controller.dart';
import '../core/theme/theme_mode_store.dart';
import '../core/widgets/status_views.dart';

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
          routerConfig: router,
        );
      },
    );
  }
}
