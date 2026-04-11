import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_sdal/app/providers.dart';
import 'package:flutter_sdal/core/config/app_config.dart';
import 'package:flutter_sdal/core/session/session_controller.dart';
import 'package:flutter_sdal/core/session/session_models.dart';
import 'package:flutter_sdal/core/shell/shell_metadata_repository.dart';
import 'package:flutter_sdal/core/widgets/feature_scaffold.dart';
import 'package:flutter_sdal/l10n/generated/app_localizations.dart';

void main() {
  testWidgets('quick menu dismisses when dragging down from menu content', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(_config),
          sessionControllerProvider.overrideWith(_StaticSessionController.new),
          shellMenuProvider.overrideWith((ref) async => _menu),
          shellSidebarProvider.overrideWith((ref) async => _emptySidebar),
          quickAccessUsersProvider.overrideWith(
            (ref) async => const <QuickAccessUser>[],
          ),
        ],
        child: MaterialApp.router(
          locale: const Locale('tr'),
          supportedLocales: const [Locale('tr'), Locale('en')],
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          routerConfig: GoRouter(
            initialLocation: '/groups',
            routes: [
              GoRoute(
                path: '/groups',
                builder: (context, state) => const FeatureScaffold(
                  title: 'Gruplar',
                  child: SizedBox.expand(),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.grid_view_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Gruplar'), findsNWidgets(2));

    await tester.drag(find.text('Gruplar').last, const Offset(0, 420));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Gruplar'), findsNothing);
  });
}

const _config = AppConfig(
  apiBaseUrl: 'https://example.com/api',
  siteBaseUrl: 'https://example.com',
  appName: 'SDAL',
  oauthCallbackScheme: 'sdalnative',
);

const _menu = ShellMenuSnapshot(
  items: <ShellMenuItem>[
    ShellMenuItem(label: 'Gruplar', url: '/groups', legacyUrl: '/groups'),
  ],
  badges: {},
);

const _emptySidebar = ShellSidebarSnapshot(
  onlineUsers: <ShellSidebarMember>[],
  newMembers: <ShellSidebarMember>[],
  newMessagesCount: 0,
);

class _StaticSessionController extends SessionController {
  @override
  Future<SessionSnapshot> build() async {
    const siteAccess = SiteAccessSnapshot(
      siteOpen: true,
      maintenanceMessage: '',
      modules: <String, bool>{},
      defaultLandingPage: '/feed',
    );
    return const SessionSnapshot(
      config: _config,
      siteAccess: siteAccess,
      user: null,
    );
  }
}
