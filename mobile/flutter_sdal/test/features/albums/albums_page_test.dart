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
import 'package:flutter_sdal/core/widgets/sdal_network_image.dart';
import 'package:flutter_sdal/features/albums/data/albums_repository.dart';
import 'package:flutter_sdal/features/albums/presentation/album_category_page.dart';
import 'package:flutter_sdal/features/albums/presentation/albums_page.dart';
import 'package:flutter_sdal/l10n/generated/app_localizations.dart';
import '../../test_support/fake_api_client.dart';

void main() {
  testWidgets(
    'AlbumsPage renders categories and appends latest photos on load more',
    (tester) async {
      final repository = _FakeAlbumsRepository();

      await tester.pumpWidget(
        _wrapWithApp(repository: repository, child: const AlbumsPage()),
      );

      await tester.pumpAndSettle();

      expect(find.text('Albümler'), findsOneWidget);
      expect(find.text('Bahar Balosu (2)'), findsOneWidget);
      expect(find.byType(SdalNetworkImage), findsNWidgets(2));
      expect(find.text('Daha fazla fotoğraf'), findsOneWidget);

      await tester.tap(find.text('Daha fazla fotoğraf'));
      await tester.pumpAndSettle();

      expect(repository.latestOffsets, [0, 2]);
      expect(find.byType(SdalNetworkImage), findsNWidgets(3));
      expect(find.text('Daha fazla fotoğraf'), findsNothing);
    },
  );

  testWidgets(
    'AlbumCategoryPage appends the next page and keeps description visible',
    (tester) async {
      final repository = _FakeAlbumsRepository();

      await tester.pumpWidget(
        _wrapWithApp(
          repository: repository,
          child: const AlbumCategoryPage(categoryId: 7),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Mezuniyet 2012 anıları'), findsOneWidget);
      expect(find.byType(SdalNetworkImage), findsNWidgets(2));
      expect(find.text('Daha fazla fotoğraf'), findsOneWidget);

      await tester.tap(find.text('Daha fazla fotoğraf'));
      await tester.pumpAndSettle();

      expect(repository.categoryPages, [1, 2]);
      expect(find.byType(SdalNetworkImage), findsNWidgets(3));
      expect(find.text('Daha fazla fotoğraf'), findsNothing);
    },
  );
}

Widget _wrapWithApp({
  required AlbumsRepository repository,
  required Widget child,
}) {
  return ProviderScope(
    overrides: [
      appConfigProvider.overrideWithValue(_config),
      albumsRepositoryProvider.overrideWithValue(repository),
      sessionControllerProvider.overrideWith(_StaticSessionController.new),
      shellMenuProvider.overrideWith((ref) async => _emptyMenu),
      shellSidebarProvider.overrideWith((ref) async => _emptySidebar),
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
        routes: [GoRoute(path: '/', builder: (context, state) => child)],
      ),
    ),
  );
}

class _FakeAlbumsRepository extends AlbumsRepository {
  _FakeAlbumsRepository() : super(FakeApiClient());

  final List<int> latestOffsets = <int>[];
  final List<int> categoryPages = <int>[];

  @override
  Future<List<AlbumCategoryItem>> fetchCategories() async {
    return const [
      AlbumCategoryItem(
        id: 7,
        title: 'Bahar Balosu',
        description: 'Kampüs fotoğrafları',
        count: 2,
        previews: <String>[],
      ),
    ];
  }

  @override
  Future<AlbumsPageData> fetchLatest({int limit = 24, int offset = 0}) async {
    latestOffsets.add(offset);
    if (offset == 0) {
      return AlbumsPageData(
        items: const [
          AlbumLatestPhoto(
            id: 1,
            categoryId: 7,
            fileName: 'a.jpg',
            date: '2026-04-01',
            categoryTitle: 'Bahar Balosu',
          ),
          AlbumLatestPhoto(
            id: 2,
            categoryId: 7,
            fileName: 'b.jpg',
            date: '2026-04-02',
            categoryTitle: 'Bahar Balosu',
          ),
        ],
        hasMore: true,
      );
    }
    return AlbumsPageData(
      items: const [
        AlbumLatestPhoto(
          id: 3,
          categoryId: 7,
          fileName: 'c.jpg',
          date: '2026-04-03',
          categoryTitle: 'Bahar Balosu',
        ),
      ],
      hasMore: false,
    );
  }

  @override
  Future<AlbumCategoryDetail> fetchCategoryDetail(
    int categoryId, {
    int page = 1,
    int pageSize = 24,
  }) async {
    categoryPages.add(page);
    if (page == 1) {
      return AlbumCategoryDetail(
        id: categoryId,
        title: 'Bahar Balosu',
        description: 'Mezuniyet 2012 anıları',
        photos: const [
          AlbumPhotoSummary(
            id: 11,
            fileName: 'cat-a.jpg',
            title: 'A',
            date: '2026-04-01',
          ),
          AlbumPhotoSummary(
            id: 12,
            fileName: 'cat-b.jpg',
            title: 'B',
            date: '2026-04-02',
          ),
        ],
        page: 1,
        pages: 2,
      );
    }
    return AlbumCategoryDetail(
      id: categoryId,
      title: 'Bahar Balosu',
      description: 'Mezuniyet 2012 anıları',
      photos: const [
        AlbumPhotoSummary(
          id: 13,
          fileName: 'cat-c.jpg',
          title: 'C',
          date: '2026-04-03',
        ),
      ],
      page: 2,
      pages: 2,
    );
  }
}

const _config = AppConfig(
  apiBaseUrl: 'https://example.com/api',
  siteBaseUrl: 'https://example.com',
  appName: 'SDAL',
  oauthCallbackScheme: 'sdalnative',
);

const _emptyMenu = ShellMenuSnapshot(items: <ShellMenuItem>[], badges: {});
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
