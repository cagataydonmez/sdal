import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/routing/app_router.dart';
import '../core/session/session_controller.dart';
import '../core/theme/app_theme.dart';
import '../core/widgets/status_views.dart';

class SdalFlutterApp extends ConsumerWidget {
  const SdalFlutterApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionState = ref.watch(sessionControllerProvider);
    final theme = buildSdalTheme();

    return sessionState.when(
      loading: () => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: theme,
        home: const AppSplashScreen(),
      ),
      error: (error, _) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: theme,
        home: StatusScaffold(
          title: 'Başlatılamadı',
          message: error.toString(),
          actionLabel: 'Tekrar dene',
          onAction: () => ref.invalidate(sessionControllerProvider),
        ),
      ),
      data: (_) {
        final router = ref.watch(appRouterProvider);
        return MaterialApp.router(
          debugShowCheckedModeBanner: false,
          title: 'SDAL',
          theme: theme,
          supportedLocales: const [Locale('tr'), Locale('en')],
          localizationsDelegates: const [
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
