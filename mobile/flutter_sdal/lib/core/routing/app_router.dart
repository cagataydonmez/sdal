import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/auth_pages.dart';
import '../../features/albums/presentation/album_category_page.dart';
import '../../features/albums/presentation/album_photo_page.dart';
import '../../features/albums/presentation/album_upload_page.dart';
import '../../features/albums/presentation/albums_page.dart';
import '../../features/community/presentation/announcements_page.dart';
import '../../features/community/presentation/events_page.dart';
import '../../features/admin/presentation/admin_pages.dart';
import '../../features/explore/presentation/explore_page.dart';
import '../../features/explore/presentation/member_detail_page.dart';
import '../../features/feed/presentation/feed_page.dart';
import '../../features/feed/data/feed_repository.dart';
import '../../features/feed/presentation/post_detail_page.dart';
import '../../features/following/presentation/following_page.dart';
import '../../features/groups/presentation/group_detail_page.dart';
import '../../features/groups/presentation/groups_page.dart';
import '../../features/live_chat/presentation/live_chat_page.dart';
import '../../features/messenger/presentation/inbox_page.dart';
import '../../features/messenger/presentation/thread_detail_page.dart';
import '../../features/networking/presentation/networking_pages.dart';
import '../../features/notifications/presentation/notifications_page.dart';
import '../../features/profile/presentation/profile_page.dart';
import '../../features/profile/presentation/profile_photo_page.dart';
import '../../features/profile/presentation/profile_verification_page.dart';
import '../../features/opportunities/presentation/jobs_page.dart';
import '../../features/opportunities/presentation/opportunities_page.dart';
import '../../features/requests/presentation/requests_page.dart';
import '../../features/stories/presentation/expired_stories_page.dart';
import '../../l10n/generated/app_localizations.dart';
import '../session/session_controller.dart';
import '../session/session_models.dart';
import '../widgets/app_tab_shell.dart';
import '../widgets/status_views.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

// Bridges Riverpod session state into a ChangeNotifier so GoRouter can
// refresh its redirect logic without recreating the router instance.
class _SessionListenable extends ChangeNotifier {
  _SessionListenable(Ref ref) {
    ref.listen(sessionControllerProvider, (_, _) => notifyListeners());
  }
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final listenable = _SessionListenable(ref);
  ref.onDispose(listenable.dispose);

  // Read once for the initial location — the provider is only created after
  // the session has resolved (SdalFlutterApp only watches this in the data
  // branch), so .value! is safe here.
  final initialSnapshot = ref.read(sessionControllerProvider).value!;

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: initialSnapshot.isAuthenticated
        ? initialSnapshot.defaultHomePath
        : '/login',
    refreshListenable: listenable,
    redirect: (context, state) {
      final snapshot = ref.read(sessionControllerProvider).value;
      if (snapshot == null) return null;
      return redirectForSessionState(snapshot, state.uri);
    },
    routes: [
      GoRoute(
        path: '/',
        redirect: (context, state) {
          final s = ref.read(sessionControllerProvider).value;
          return (s != null && s.isAuthenticated)
              ? s.defaultHomePath
              : '/login';
        },
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterPage(),
      ),
      GoRoute(
        path: '/activate',
        builder: (context, state) => ActivationPage(
          memberId: state.uri.queryParameters['id'] ?? '',
          code: state.uri.queryParameters['akt'] ?? '',
        ),
      ),
      GoRoute(
        path: '/activation/resend',
        builder: (context, state) => const ActivationResendPage(),
      ),
      GoRoute(
        path: '/password-reset',
        builder: (context, state) => const PasswordResetPage(),
      ),
      GoRoute(
        path: '/oauth/callback',
        builder: (context, state) => const OAuthCallbackPage(),
      ),
      GoRoute(
        path: '/site-closed',
        builder: (context, state) {
          final s = ref.read(sessionControllerProvider).value;
          final maintenanceMessage = s?.siteAccess.maintenanceMessage ?? '';
          return StatusScaffold(
            title: AppLocalizations.of(context)!.siteClosedTitle,
            message: maintenanceMessage.isNotEmpty
                ? maintenanceMessage
                : AppLocalizations.of(context)!.siteClosedFallbackMessage,
          );
        },
      ),
      GoRoute(
        path: '/module-closed',
        builder: (context, state) {
          final moduleKey = state.uri.queryParameters['module'] ?? '';
          final l10n = AppLocalizations.of(context)!;
          return StatusScaffold(
            title: l10n.moduleClosedTitle,
            message: moduleKey.isEmpty
                ? l10n.moduleClosedDefaultMessage
                : l10n.moduleClosedWithName(moduleKey),
          );
        },
      ),
      GoRoute(
        path: '/account-banned',
        builder: (context, state) => StatusScaffold(
          title: AppLocalizations.of(context)!.accountBannedTitle,
          message: AppLocalizations.of(context)!.accountBannedMessage,
        ),
      ),
      GoRoute(
        path: '/verification-required',
        builder: (context, state) {
          final feature = state.uri.queryParameters['feature'] ?? 'networking';
          final l10n = AppLocalizations.of(context)!;
          return StatusScaffold(
            title: l10n.verificationRequiredTitle,
            message: l10n.verificationRequiredMessage(feature),
          );
        },
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppTabShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/feed',
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: FeedPage()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/explore',
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: ExplorePage()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/inbox',
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: InboxPage()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/notifications',
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: NotificationsPage()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: ProfilePage()),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/posts/:postId',
        builder: (context, state) => PostDetailPage(
          postId: int.tryParse(state.pathParameters['postId'] ?? '') ?? 0,
        ),
      ),
      GoRoute(
        path: '/members/:memberId',
        builder: (context, state) => MemberDetailPage(
          memberId: int.tryParse(state.pathParameters['memberId'] ?? '') ?? 0,
        ),
      ),
      GoRoute(
        path: '/messages/:threadId',
        builder: (context, state) => ThreadDetailPage(
          threadId: int.tryParse(state.pathParameters['threadId'] ?? '') ?? 0,
        ),
      ),
      GoRoute(
        path: '/network/hub',
        builder: (context, state) => const NetworkingHubPage(),
      ),
      GoRoute(
        path: '/network/inbox',
        builder: (context, state) => const NetworkingInboxPage(),
      ),
      GoRoute(
        path: '/network/teachers',
        builder: (context, state) => const TeacherLinksPage(),
      ),
      GoRoute(
        path: '/profile/photo',
        builder: (context, state) => const ProfilePhotoPage(),
      ),
      GoRoute(
        path: '/profile/verification',
        builder: (context, state) => const ProfileVerificationPage(),
      ),
      GoRoute(
        path: '/profile/stories/expired',
        builder: (context, state) => ExpiredStoriesPage(
          initialFeedType: state.uri.queryParameters['feedType'] == 'community'
              ? FeedType.community
              : FeedType.main,
        ),
      ),
      GoRoute(
        path: '/feed/live-chat',
        builder: (context, state) => const LiveChatPage(),
      ),
      GoRoute(
        path: '/following',
        builder: (context, state) => const FollowingPage(),
      ),
      GoRoute(path: '/groups', builder: (context, state) => const GroupsPage()),
      GoRoute(
        path: '/groups/:groupId',
        builder: (context, state) => GroupDetailPage(
          groupId: int.tryParse(state.pathParameters['groupId'] ?? '') ?? 0,
        ),
      ),
      GoRoute(path: '/events', builder: (context, state) => const EventsPage()),
      GoRoute(
        path: '/announcements',
        builder: (context, state) => const AnnouncementsPage(),
      ),
      GoRoute(
        path: '/admin',
        builder: (context, state) => const AdminHubPage(),
      ),
      GoRoute(
        path: '/admin/:section',
        builder: (context, state) =>
            AdminSectionPage(sectionKey: state.pathParameters['section'] ?? ''),
      ),
      GoRoute(path: '/jobs', builder: (context, state) => const JobsPage()),
      GoRoute(
        path: '/opportunities',
        builder: (context, state) => const OpportunitiesPage(),
      ),
      GoRoute(path: '/albums', builder: (context, state) => const AlbumsPage()),
      GoRoute(
        path: '/albums/:categoryId',
        builder: (context, state) => AlbumCategoryPage(
          categoryId:
              int.tryParse(state.pathParameters['categoryId'] ?? '') ?? 0,
        ),
      ),
      GoRoute(
        path: '/albums/photo/:photoId',
        builder: (context, state) => AlbumPhotoPage(
          photoId: int.tryParse(state.pathParameters['photoId'] ?? '') ?? 0,
        ),
      ),
      GoRoute(
        path: '/albums/upload',
        builder: (context, state) => const AlbumUploadPage(),
      ),
      GoRoute(
        path: '/requests',
        builder: (context, state) => RequestsPage(
          initialCategoryKey: state.uri.queryParameters['category'] ?? '',
          highlightedRequestId:
              int.tryParse(state.uri.queryParameters['request'] ?? '') ?? 0,
          notificationId:
              int.tryParse(state.uri.queryParameters['notification'] ?? '') ??
              0,
          notificationStatus: state.uri.queryParameters['status'] ?? '',
        ),
      ),
    ],
  );
});

String? redirectForSessionState(SessionSnapshot snapshot, Uri uri) {
  final location = uri.path;
  final publicRoutes = <String>{
    '/login',
    '/register',
    '/activate',
    '/activation/resend',
    '/password-reset',
    '/oauth/callback',
  };

  if (!snapshot.siteAccess.siteOpen) {
    return location == '/site-closed' ? null : '/site-closed';
  }

  if (snapshot.isBanned) {
    return location == '/account-banned' ? null : '/account-banned';
  }

  if (!snapshot.isAuthenticated) {
    return publicRoutes.contains(location) ? null : '/login';
  }

  if (publicRoutes.contains(location) ||
      location == '/site-closed' ||
      location == '/account-banned') {
    return snapshot.defaultHomePath;
  }

  if ((location == '/admin' || location.startsWith('/admin/')) &&
      !(snapshot.user?.isAdmin ?? false)) {
    return snapshot.defaultHomePath;
  }

  final moduleKey = moduleKeyForLocation(location);
  if (moduleKey != null && !snapshot.isModuleOpen(moduleKey)) {
    return location == '/module-closed'
        ? null
        : '/module-closed?module=$moduleKey';
  }

  if (snapshot.requiresProfileCompletion &&
      !location.startsWith('/profile') &&
      location != '/module-closed') {
    return '/profile';
  }

  if (requiresVerificationGate(location) && snapshot.requiresVerification) {
    return location == '/verification-required'
        ? null
        : '/verification-required?feature=networking';
  }

  return null;
}

String? moduleKeyForLocation(String location) {
  if (location == '/feed' || location.startsWith('/posts/')) return 'feed';
  if (location == '/explore' || location.startsWith('/members/')) {
    return 'explore';
  }
  if (location == '/inbox' || location.startsWith('/messages/')) {
    return 'messenger';
  }
  if (location == '/notifications') return 'notifications';
  if (location == '/profile') return 'profile';
  if (location == '/profile/photo' || location == '/profile/verification') {
    return 'profile';
  }
  if (location == '/feed/live-chat') return 'feed';
  if (location == '/following') return 'following';
  if (location == '/requests') return 'requests';
  if (location == '/announcements') return 'announcements';
  if (location == '/events') return 'events';
  if (location == '/jobs') return 'jobs';
  if (location == '/opportunities') return 'opportunities';
  if (location == '/groups' || location.startsWith('/groups/')) return 'groups';
  if (location == '/albums' || location.startsWith('/albums/')) return 'albums';
  if (location.startsWith('/network/hub') ||
      location.startsWith('/network/inbox')) {
    return 'networking';
  }
  if (location.startsWith('/network/teachers')) return 'teachers_network';
  return null;
}

bool requiresVerificationGate(String location) {
  if (location == '/inbox' || location.startsWith('/messages/')) return false;
  return location.startsWith('/network/');
}
