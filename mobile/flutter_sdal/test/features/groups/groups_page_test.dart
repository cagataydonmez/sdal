import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_sdal/app/providers.dart';
import 'package:flutter_sdal/core/config/app_config.dart';
import 'package:flutter_sdal/features/groups/presentation/groups_page.dart';
import 'package:flutter_sdal/features/groups/data/groups_repository.dart';
import 'package:flutter_sdal/l10n/generated/app_localizations.dart';

void main() {
  testWidgets('GroupsPage renders localized chrome and group item', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(
            const AppConfig(
              apiBaseUrl: 'https://example.com/api',
              siteBaseUrl: 'https://example.com',
              appName: 'SDAL',
              oauthCallbackScheme: 'sdalnative',
            ),
          ),
          groupsListProvider.overrideWith(
            (ref) async => const [
              GroupListItem(
                id: 1,
                name: 'Tasarim Ekibi',
                description: 'Yeni mezunlar ve mentorler',
                coverImage: '',
                membersCount: 12,
                visibility: 'public',
                joined: false,
                pending: false,
                invited: false,
                myRole: '',
                membershipStatus: 'none',
                showContactHint: false,
              ),
            ],
          ),
        ],
        child: MaterialApp(
          locale: const Locale('tr'),
          supportedLocales: const [Locale('tr'), Locale('en')],
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const GroupsPage(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Gruplar'), findsOneWidget);
    expect(find.text('Yeni grup'), findsOneWidget);
    expect(find.text('Tasarim Ekibi'), findsOneWidget);
    expect(find.text('12 üye'), findsOneWidget);
    expect(find.text('Katıl'), findsOneWidget);
  });
}
