import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/auth_pages.dart';
import '../../features/explore/presentation/explore_page.dart';
import '../../features/explore/presentation/member_detail_page.dart';
import '../../features/feed/presentation/feed_page.dart';
import '../../features/feed/presentation/post_detail_page.dart';
import '../../features/messenger/presentation/inbox_page.dart';
import '../../features/messenger/presentation/thread_detail_page.dart';
import '../../features/networking/presentation/networking_pages.dart';
import '../../features/notifications/presentation/notifications_page.dart';
import '../../features/profile/presentation/profile_page.dart';
import '../../features/profile/presentation/profile_photo_page.dart';
import '../../features/profile/presentation/profile_verification_page.dart';
import '../../l10n/generated/app_localizations.dart';
import '../session/session_controller.dart';
import '../session/session_models.dart';
import '../widgets/app_tab_shell.dart';
import '../widgets/status_views.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final appRouterProvider = Provider<GoRouter>((ref) {
  final snapshot = ref.watch(sessionControllerProvider).value!;

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: snapshot.isAuthenticated
        ? snapshot.defaultHomePath
        : '/login',
    redirect: (context, state) => redirectForSessionState(snapshot, state.uri),
    routes: [
      GoRoute(
        path: '/',
        redirect: (context, state) =>
            snapshot.isAuthenticated ? snapshot.defaultHomePath : '/login',
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
        builder: (context, state) => StatusScaffold(
          title: AppLocalizations.of(context)!.siteClosedTitle,
          message: snapshot.siteAccess.maintenanceMessage.isNotEmpty
              ? snapshot.siteAccess.maintenanceMessage
              : AppLocalizations.of(context)!.siteClosedFallbackMessage,
        ),
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
