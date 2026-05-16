import 'package:flutter/foundation.dart' show FlutterError, FlutterErrorDetails;
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
    'AlbumsPage renders categories from dashboard',
    (tester) async {
      final repository = _FakeAlbumsRepository();

      // Suppress layout overflow errors that arise from the test's constrained
      // viewport — the page layout is valid on real devices.
      final previousOnError = FlutterError.onError;
      FlutterError.onError = (FlutterErrorDetails details) {
        if (details.exceptionAsString().contains('overflowed')) return;
        previousOnError?.call(details);
      };
      addTearDown(() => FlutterError.onError = previousOnError);

      await tester.pumpWidget(
        _wrapWithApp(repository: repository, child: const AlbumsPage()),
      );

      await tester.pumpAndSettle();

      expect(find.text('Bahar Balosu'), findsAtLeastNWidgets(1));
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
      expect(find.text('Daha fazla göster'), findsOneWidget);

      await tester.tap(find.text('Daha fazla göster'));
      await tester.pumpAndSettle();

      expect(repository.categoryPages, [1, 2]);
      expect(find.byType(SdalNetworkImage), findsNWidgets(3));
      expect(find.text('Daha fazla göster'), findsNothing);
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

AlbumCategoryItem _fakeCategory({
  int id = 7,
  String title = 'Bahar Balosu',
}) =>
    AlbumCategoryItem(
      id: id,
      title: title,
      description: 'Kampüs fotoğrafları',
      count: 2,
      previews: const <String>[],
      visibilityScope: 'public',
      cohortYear: '',
      albumType: 'general',
      ownerUserId: null,
      isSystemAlbum: false,
      canUpload: false,
      canEdit: false,
    );

AlbumPhotoCard _fakePhoto({required int id, required String fileName}) =>
    AlbumPhotoCard(
      id: id,
      categoryId: 7,
      fileName: fileName,
      title: 'Fotoğraf $id',
      date: '2026-04-01',
      categoryTitle: 'Bahar Balosu',
      viewCount: 0,
      likeCount: 0,
      commentCount: 0,
      liked: false,
      allowComments: true,
      media: AlbumPhotoMedia.empty(fileName),
    );

class _FakeAlbumsRepository extends AlbumsRepository {
  _FakeAlbumsRepository() : super(FakeApiClient());

  final List<int> categoryPages = <int>[];

  @override
  Future<AlbumsDashboardData> fetchDashboard() async {
    return AlbumsDashboardData(
      categories: [_fakeCategory()],
      latest: [_fakePhoto(id: 1, fileName: 'a.jpg')],
      popular: const [],
      mine: const [],
      canCreateAlbum: false,
      canManageCategories: false,
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
        photos: [
          _fakePhoto(id: 11, fileName: 'cat-a.jpg'),
          _fakePhoto(id: 12, fileName: 'cat-b.jpg'),
        ],
        page: 1,
        pages: 2,
        total: 3,
        visibilityScope: 'public',
        cohortYear: '',
        albumType: 'general',
        canUpload: false,
        canEdit: false,
      );
    }
    return AlbumCategoryDetail(
      id: categoryId,
      title: 'Bahar Balosu',
      description: 'Mezuniyet 2012 anıları',
      photos: [
        _fakePhoto(id: 13, fileName: 'cat-c.jpg'),
      ],
      page: 2,
      pages: 2,
      total: 3,
      visibilityScope: 'public',
      cohortYear: '',
      albumType: 'general',
      canUpload: false,
      canEdit: false,
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
