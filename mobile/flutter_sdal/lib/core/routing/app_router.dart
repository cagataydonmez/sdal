import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/auth_pages.dart';
import '../../features/albums/presentation/album_category_page.dart';
import '../../features/albums/presentation/album_edit_page.dart';
import '../../features/albums/presentation/album_photo_page.dart';
import '../../features/albums/presentation/album_upload_page.dart';
import '../../features/albums/presentation/albums_page.dart';
import '../../features/community/presentation/announcements_page.dart';
import '../../features/community/presentation/announcements_create_page.dart';
import '../../features/community/presentation/entity_detail_page.dart';
import '../../features/community/presentation/events_page.dart';
import '../../features/community/presentation/events_create_page.dart';
import '../../features/admin/presentation/admin_pages.dart';
import '../../features/admin/presentation/admin_app_module_pages.dart';
import '../../features/admin/presentation/admin_root_pages.dart';
import '../../features/admin/presentation/admin_workspace_pages.dart';
import '../../features/bulletin/presentation/bulletin_page.dart';
import '../../features/explore/presentation/explore_page.dart';
import '../../features/explore/presentation/member_detail_page.dart';
import '../../features/feed/presentation/feed_page.dart';
import '../../features/feed/data/feed_repository.dart';
import '../../features/feed/presentation/post_detail_page.dart';
import '../../features/following/presentation/following_page.dart';
import '../../features/following/presentation/following_detail_page.dart';
import '../../features/groups/presentation/group_detail_page.dart';
import '../../features/groups/presentation/groups_page.dart';
import '../../features/messenger/presentation/inbox_page.dart';
import '../../features/messenger/presentation/thread_detail_page.dart';
import '../../features/networking/presentation/networking_pages.dart';
import '../../features/networking/presentation/teacher_network_map_page.dart';
import '../../features/notifications/presentation/notifications_page.dart';
import '../../features/legal/presentation/legal_content_page.dart';
import '../../features/profile/presentation/profile_page.dart';
import '../../features/profile/presentation/profile_edit_page.dart';
import '../../features/profile/presentation/email_change_verify_page.dart';
import '../../features/profile/presentation/profile_photo_page.dart';
import '../../features/profile/presentation/profile_settings_page.dart';
import '../../features/profile/presentation/profile_verification_page.dart';
import '../../features/opportunities/presentation/jobs_page.dart';
import '../../features/opportunities/presentation/jobs_create_page.dart';
import '../../features/opportunities/presentation/job_detail_page.dart';
import '../../features/opportunities/presentation/job_apply_page.dart';
import '../../features/opportunities/presentation/job_applications_page.dart';
import '../../features/opportunities/presentation/job_application_detail_page.dart';
import '../../features/requests/presentation/requests_page.dart';
import '../../features/requests/presentation/module_access_request_page.dart';
import '../../features/stories/presentation/expired_stories_page.dart';
import '../../l10n/generated/app_localizations.dart';
import 'route_refresh_coordinator.dart';
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
      GoRoute(
        path: '/login',
        pageBuilder: (context, state) => _fadePage(const LoginPage()),
      ),
      GoRoute(
        path: '/register',
        pageBuilder: (context, state) => _slidePage(const RegisterPage()),
      ),
      GoRoute(
        path: '/activate',
        pageBuilder: (context, state) => _slidePage(
          ActivationPage(
            memberId: state.uri.queryParameters['id'] ?? '',
            code: state.uri.queryParameters['akt'] ?? '',
            username: state.uri.queryParameters['kadi'] ?? '',
            email: state.uri.queryParameters['email'] ?? '',
          ),
        ),
      ),
      GoRoute(
        path: '/activation/resend',
        pageBuilder: (context, state) =>
            _slidePage(const ActivationResendPage()),
      ),
      GoRoute(
        path: '/password-reset',
        pageBuilder: (context, state) => _slidePage(const PasswordResetPage()),
      ),
      GoRoute(
        path: '/phone-verification',
        pageBuilder: (context, state) =>
            _slidePage(const PhoneVerificationPage()),
      ),
      GoRoute(
        path: '/device-challenge',
        pageBuilder: (context, state) =>
            _slidePage(const DeviceEmailChallengePage()),
      ),
      GoRoute(
        path: '/legal',
        pageBuilder: (context, state) {
          final extra = state.extra is Map ? state.extra as Map : const {};
          return _slidePage(
            LegalContentPage(
              title: (extra['title'] ?? 'Yasal içerik').toString(),
              path: (extra['path'] ?? '/kvkk').toString(),
              requireAcceptance: extra['requireAcceptance'] == true,
            ),
          );
        },
      ),
      GoRoute(
        path: '/profile/email-change/verify',
        pageBuilder: (context, state) => _slidePage(
          EmailChangeVerifyPage(
            token: state.uri.queryParameters['token'] ?? '',
          ),
        ),
      ),
      GoRoute(
        path: '/oauth/callback',
        pageBuilder: (context, state) => _fadePage(const OAuthCallbackPage()),
      ),
      GoRoute(
        path: '/site-closed',
        pageBuilder: (context, state) {
          final s = ref.read(sessionControllerProvider).value;
          final maintenanceMessage = s?.siteAccess.maintenanceMessage ?? '';
          return _fadePage(
            StatusScaffold(
              title: AppLocalizations.of(context)!.siteClosedTitle,
              message: maintenanceMessage.isNotEmpty
                  ? maintenanceMessage
                  : AppLocalizations.of(context)!.siteClosedFallbackMessage,
            ),
          );
        },
      ),
      GoRoute(
        path: '/module-closed',
        pageBuilder: (context, state) => _fadePage(
          ModuleAccessRequestPage(
            moduleKey: state.uri.queryParameters['module'] ?? '',
          ),
        ),
      ),
      GoRoute(
        path: '/account-banned',
        pageBuilder: (context, state) => _fadePage(
          StatusScaffold(
            title: AppLocalizations.of(context)!.accountBannedTitle,
            message: AppLocalizations.of(context)!.accountBannedMessage,
          ),
        ),
      ),
      GoRoute(
        path: '/verification-required',
        pageBuilder: (context, state) {
          final feature = state.uri.queryParameters['feature'] ?? 'networking';
          final l10n = AppLocalizations.of(context)!;
          return _fadePage(
            StatusScaffold(
              title: l10n.verificationRequiredTitle,
              message: l10n.verificationRequiredMessage(feature),
            ),
          );
        },
      ),
      StatefulShellRoute(
        builder: (context, state, navigationShell) =>
            AppTabShell(navigationShell: navigationShell),
        navigatorContainerBuilder: buildAppTabNavigationContainer,
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/feed',
                pageBuilder: (context, state) => _tabPage(const FeedPage()),
              ),
              GoRoute(
                path: '/posts/:postId',
                pageBuilder: (context, state) => _liftPage(
                  PostDetailPage(
                    postId:
                        int.tryParse(state.pathParameters['postId'] ?? '') ?? 0,
                  ),
                ),
              ),
              GoRoute(
                path: '/groups',
                pageBuilder: (context, state) => _slidePage(const GroupsPage()),
              ),
              GoRoute(
                path: '/groups/:groupId',
                pageBuilder: (context, state) => _liftPage(
                  GroupDetailPage(
                    groupId:
                        int.tryParse(state.pathParameters['groupId'] ?? '') ??
                        0,
                  ),
                ),
                routes: [
                  GoRoute(
                    path: 'events/:eventId',
                    pageBuilder: (context, state) => _slidePage(
                      GroupEventDetailPage(
                        groupId:
                            int.tryParse(
                              state.pathParameters['groupId'] ?? '',
                            ) ??
                            0,
                        eventId:
                            int.tryParse(
                              state.pathParameters['eventId'] ?? '',
                            ) ??
                            0,
                      ),
                    ),
                  ),
                  GoRoute(
                    path: 'announcements/:announcementId',
                    pageBuilder: (context, state) => _slidePage(
                      GroupAnnouncementDetailPage(
                        groupId:
                            int.tryParse(
                              state.pathParameters['groupId'] ?? '',
                            ) ??
                            0,
                        announcementId:
                            int.tryParse(
                              state.pathParameters['announcementId'] ?? '',
                            ) ??
                            0,
                      ),
                    ),
                  ),
                ],
              ),
              GoRoute(
                path: '/events',
                pageBuilder: (context, state) => _slidePage(const EventsPage()),
                routes: [
                  GoRoute(
                    path: 'create',
                    pageBuilder: (context, state) =>
                        _slidePage(const EventsCreatePage()),
                  ),
                  GoRoute(
                    path: ':eventId',
                    pageBuilder: (context, state) => _slidePage(
                      EventDetailPage(
                        eventId:
                            int.tryParse(
                              state.pathParameters['eventId'] ?? '',
                            ) ??
                            0,
                      ),
                    ),
                  ),
                ],
              ),
              GoRoute(
                path: '/announcements',
                pageBuilder: (context, state) =>
                    _slidePage(const AnnouncementsPage()),
                routes: [
                  GoRoute(
                    path: 'create',
                    pageBuilder: (context, state) =>
                        _slidePage(const AnnouncementsCreatePage()),
                  ),
                  GoRoute(
                    path: ':announcementId',
                    pageBuilder: (context, state) => _slidePage(
                      AnnouncementDetailPage(
                        announcementId:
                            int.tryParse(
                              state.pathParameters['announcementId'] ?? '',
                            ) ??
                            0,
                      ),
                    ),
                  ),
                ],
              ),
              GoRoute(
                path: '/following',
                pageBuilder: (context, state) =>
                    _slidePage(const FollowingPage()),
              ),
              GoRoute(
                path: '/following/member/:memberId/:section',
                pageBuilder: (context, state) => _slidePage(
                  FollowingDetailPage(
                    memberId:
                        int.tryParse(state.pathParameters['memberId'] ?? '') ??
                        0,
                    sectionKey: state.pathParameters['section'] ?? '',
                  ),
                ),
              ),
              GoRoute(
                path: '/albums',
                pageBuilder: (context, state) => _slidePage(const AlbumsPage()),
              ),
              GoRoute(
                path: '/albums/upload',
                pageBuilder: (context, state) => _slidePage(
                  AlbumUploadPage(
                    initialCategoryId:
                        int.tryParse(
                          state.uri.queryParameters['albumId'] ?? '',
                        ) ??
                        0,
                  ),
                ),
              ),
              GoRoute(
                path: '/albums/photo/:photoId',
                pageBuilder: (context, state) => _liftPage(
                  AlbumPhotoPage(
                    photoId:
                        int.tryParse(state.pathParameters['photoId'] ?? '') ??
                        0,
                  ),
                ),
              ),
              GoRoute(
                path: '/albums/new',
                pageBuilder: (context, state) => _slidePage(
                  AlbumEditPage(
                    profileMode:
                        (state.uri.queryParameters['profile'] ?? '0') == '1',
                  ),
                ),
              ),
              GoRoute(
                path: '/albums/:categoryId/edit',
                pageBuilder: (context, state) => _slidePage(
                  AlbumEditPage(
                    categoryId:
                        int.tryParse(
                          state.pathParameters['categoryId'] ?? '',
                        ) ??
                        0,
                  ),
                ),
              ),
              GoRoute(
                path: '/albums/:categoryId',
                pageBuilder: (context, state) => _liftPage(
                  AlbumCategoryPage(
                    categoryId:
                        int.tryParse(
                          state.pathParameters['categoryId'] ?? '',
                        ) ??
                        0,
                  ),
                ),
              ),
              GoRoute(
                path: '/panolar',
                pageBuilder: (context, state) => _slidePage(
                  BulletinPage(
                    initialCategoryId:
                        int.tryParse(
                          state.uri.queryParameters['mkatid'] ?? '',
                        ) ??
                        0,
                  ),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/explore',
                pageBuilder: (context, state) => _tabPage(const ExplorePage()),
              ),
              GoRoute(
                path: '/members/:memberId',
                pageBuilder: (context, state) => _liftPage(
                  MemberDetailPage(
                    memberId:
                        int.tryParse(state.pathParameters['memberId'] ?? '') ??
                        0,
                  ),
                ),
              ),
              GoRoute(
                path: '/network/hub',
                pageBuilder: (context, state) =>
                    _slidePage(const NetworkingHubPage()),
              ),
              GoRoute(
                path: '/network/inbox',
                pageBuilder: (context, state) =>
                    _slidePage(const NetworkingInboxPage()),
              ),
              GoRoute(
                path: '/network/teachers',
                pageBuilder: (context, state) =>
                    _slidePage(const TeacherLinksPage()),
              ),
              GoRoute(
                path: '/network/teachers/:teacherId/map',
                pageBuilder: (context, state) => _liftPage(
                  TeacherNetworkMapPage(
                    teacherId:
                        int.tryParse(state.pathParameters['teacherId'] ?? '') ??
                        0,
                  ),
                ),
              ),
              GoRoute(
                path: '/jobs',
                pageBuilder: (context, state) => _slidePage(const JobsPage()),
                routes: [
                  GoRoute(
                    path: 'create',
                    pageBuilder: (context, state) =>
                        _slidePage(const JobsCreatePage()),
                  ),
                  GoRoute(
                    path: ':jobId',
                    pageBuilder: (context, state) => _slidePage(
                      JobDetailPage(
                        jobId:
                            int.tryParse(state.pathParameters['jobId'] ?? '') ??
                            0,
                      ),
                    ),
                    routes: [
                      GoRoute(
                        path: 'apply',
                        pageBuilder: (context, state) {
                          final extra = state.extra is Map
                              ? state.extra as Map
                              : const {};
                          return _slidePage(
                            JobApplyPage(
                              jobId:
                                  int.tryParse(
                                    state.pathParameters['jobId'] ?? '',
                                  ) ??
                                  0,
                              jobTitle: (extra['jobTitle'] ?? '').toString(),
                            ),
                          );
                        },
                      ),
                      GoRoute(
                        path: 'applications',
                        pageBuilder: (context, state) {
                          final extra = state.extra is Map
                              ? state.extra as Map
                              : const {};
                          return _slidePage(
                            JobApplicationsPage(
                              jobId:
                                  int.tryParse(
                                    state.pathParameters['jobId'] ?? '',
                                  ) ??
                                  0,
                              jobTitle: (extra['jobTitle'] ?? '').toString(),
                            ),
                          );
                        },
                        routes: [
                          GoRoute(
                            path: ':appId',
                            pageBuilder: (context, state) {
                              final extra = state.extra is Map
                                  ? state.extra as Map
                                  : const {};
                              return _liftPage(
                                JobApplicationDetailPage(
                                  jobId:
                                      int.tryParse(
                                        state.pathParameters['jobId'] ?? '',
                                      ) ??
                                      0,
                                  applicationId:
                                      int.tryParse(
                                        state.pathParameters['appId'] ?? '',
                                      ) ??
                                      0,
                                  jobTitle: (extra['jobTitle'] ?? '')
                                      .toString(),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/messenger',
                pageBuilder: (context, state) => _tabPage(const InboxPage()),
              ),
              GoRoute(
                path: '/inbox',
                redirect: (context, state) => '/messenger',
              ),
              GoRoute(
                path: '/messages/:threadId',
                pageBuilder: (context, state) => _liftPage(
                  ThreadDetailPage(
                    threadId:
                        int.tryParse(state.pathParameters['threadId'] ?? '') ??
                        0,
                  ),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/notifications',
                pageBuilder: (context, state) =>
                    _tabPage(const NotificationsPage()),
              ),
              GoRoute(
                path: '/notifications/:notificationId',
                pageBuilder: (context, state) => _liftPage(
                  NotificationDetailPage(
                    notificationId:
                        int.tryParse(
                          state.pathParameters['notificationId'] ?? '',
                        ) ??
                        0,
                  ),
                ),
              ),
              GoRoute(
                path: '/requests',
                pageBuilder: (context, state) => _slidePage(
                  RequestsPage(
                    initialCategoryKey:
                        state.uri.queryParameters['category'] ?? '',
                    highlightedRequestId:
                        int.tryParse(
                          state.uri.queryParameters['request'] ?? '',
                        ) ??
                        0,
                    notificationId:
                        int.tryParse(
                          state.uri.queryParameters['notification'] ?? '',
                        ) ??
                        0,
                    notificationStatus:
                        state.uri.queryParameters['status'] ?? '',
                  ),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                pageBuilder: (context, state) => _tabPage(const ProfilePage()),
              ),
              GoRoute(
                path: '/profile/edit',
                pageBuilder: (context, state) =>
                    _slidePage(const ProfileEditPage()),
              ),
              GoRoute(
                path: '/profile/onboarding',
                pageBuilder: (context, state) =>
                    _slidePage(const GraduationYearOnboardingPage()),
              ),
              GoRoute(
                path: '/profile/photo',
                pageBuilder: (context, state) =>
                    _slidePage(const ProfilePhotoPage()),
              ),
              GoRoute(
                path: '/profile/verification',
                pageBuilder: (context, state) =>
                    _slidePage(const ProfileVerificationPage()),
              ),
              GoRoute(
                path: '/profile/settings',
                pageBuilder: (context, state) =>
                    _slidePage(const ProfileSettingsPage()),
              ),
              GoRoute(
                path: '/profile/stories/expired',
                pageBuilder: (context, state) => _slidePage(
                  ExpiredStoriesPage(
                    initialFeedType:
                        state.uri.queryParameters['feedType'] == 'community'
                        ? FeedType.community
                        : FeedType.main,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/admin',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) =>
            _adminPanelPage(const AdminWorkspacePage(), root: true),
      ),
      GoRoute(
        path: '/moderation',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) =>
            _adminPanelPage(const ModeratorWorkspacePage(), root: true),
      ),
      GoRoute(
        path: '/admin/modules',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) =>
            _adminPanelPage(const AdminModuleManagementPage()),
      ),
      GoRoute(
        path: '/admin/app/:moduleKey',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => _adminPanelPage(
          AdminAppModulePage(
            moduleKey: state.pathParameters['moduleKey'] ?? '',
          ),
        ),
      ),
      GoRoute(
        path: '/admin/teacher-network',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) =>
            _adminPanelPage(const AdminTeacherNetworkManagementPage()),
      ),
      GoRoute(
        path: '/admin/teacher-accounts',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) =>
            _adminPanelPage(const AdminTeacherAccountsPage()),
      ),
      GoRoute(
        path: '/admin/audit',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) =>
            _adminPanelPage(const AdminAuditLogPage()),
      ),
      GoRoute(
        path: '/admin/root',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) =>
            _adminPanelPage(const RootAdminToolsPage()),
      ),
      GoRoute(
        path: '/admin/root/member-activity',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) =>
            _adminPanelPage(const RootMemberActivityPage()),
      ),
      GoRoute(
        path: '/admin/factory-reset',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) =>
            _adminPanelPage(const FactoryResetPage()),
      ),
      GoRoute(
        path: '/admin/test-data',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) =>
            _adminPanelPage(const TestDataSeedPage()),
      ),
      GoRoute(
        path: '/admin/permission-groups',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) =>
            _adminPanelPage(const PermissionGroupsPage()),
      ),
      GoRoute(
        path: '/admin/user-permissions',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) =>
            _adminPanelPage(const UserPermissionsPage()),
      ),
      GoRoute(
        path: '/admin/:section',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => _adminPanelPage(
          AdminSectionPage(sectionKey: state.pathParameters['section'] ?? ''),
        ),
      ),
      GoRoute(path: '/feed/live-chat', redirect: (context, state) => '/feed'),
      GoRoute(
        path: '/opportunities',
        redirect: (context, state) {
          final query = state.uri.hasQuery ? '?${state.uri.query}' : '';
          return '/explore$query';
        },
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
    '/legal',
    '/password-reset',
    '/device-challenge',
    '/profile/email-change/verify',
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

  if (snapshot.requiresPhoneVerification) {
    return location == '/phone-verification' ? null : '/phone-verification';
  }

  if (location == '/phone-verification') {
    return snapshot.defaultHomePath;
  }

  if (snapshot.requiresInitialGraduationClaim) {
    return location == '/profile/onboarding' || location == '/legal'
        ? null
        : '/profile/onboarding';
  }

  if (location == '/profile/onboarding') {
    return snapshot.defaultHomePath;
  }

  if ((publicRoutes.contains(location) && location != '/legal') ||
      location == '/site-closed' ||
      location == '/account-banned') {
    return snapshot.defaultHomePath;
  }

  if (location == '/admin' &&
      snapshot.isModerator &&
      !snapshot.hasAdminAccess) {
    return '/moderation';
  }

  if (location == '/admin/modules' && !snapshot.hasAdminAccess) {
    return snapshot.managementEntryPath;
  }

  if ((location == '/admin' || location.startsWith('/admin/')) &&
      !snapshot.hasAdminAccess &&
      !snapshot.isModerator) {
    return snapshot.managementEntryPath;
  }

  if (location == '/moderation' &&
      !snapshot.hasAdminAccess &&
      !snapshot.isModerator) {
    return snapshot.managementEntryPath;
  }

  final moduleKey = moduleKeyForLocation(location);
  if (moduleKey != null && !snapshot.isModuleOpen(moduleKey)) {
    return location == '/module-closed'
        ? null
        : '/module-closed?module=$moduleKey';
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
  if (location == '/messenger' || location.startsWith('/messages/')) {
    return 'messenger';
  }
  if (location == '/notifications' || location.startsWith('/notifications/')) {
    return 'notifications';
  }
  if (location == '/profile') return 'profile';
  if (location == '/profile/edit' ||
      location == '/profile/onboarding' ||
      location == '/profile/photo' ||
      location == '/profile/verification') {
    return 'profile';
  }
  if (location == '/following') return 'following';
  if (location == '/requests') return 'requests';
  if (location == '/announcements') return 'announcements';
  if (location == '/events') return 'events';
  if (location == '/jobs') return 'jobs';
  if (location == '/opportunities') return 'explore';
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
  if (location == '/messenger' || location.startsWith('/messages/')) {
    return false;
  }
  return location.startsWith('/network/');
}

// ── Transition helpers ────────────────────────────────────────────────────────

const _kCurve = Curves.easeOutCubic;
const _kDuration = Duration(milliseconds: 280);
const _kTabDuration = Duration(milliseconds: 220);

Page<void> _tabPage(Widget child) => CustomTransitionPage<void>(
  child: RouteSilentRefresh(child: child),
  transitionDuration: _kTabDuration,
  reverseTransitionDuration: _kTabDuration,
  transitionsBuilder: (context, animation, secondaryAnimation, child) {
    final curved = CurvedAnimation(parent: animation, curve: _kCurve);
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.015),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  },
);

/// Slide from right + fade. Use for list / feature pages pushed from the tab shell.
Page<void> _slidePage(Widget child) => _isCupertinoNavigationPlatform
    ? CupertinoPage<void>(child: RouteSilentRefresh(child: child))
    : CustomTransitionPage<void>(
        child: RouteSilentRefresh(child: child),
        transitionDuration: _kDuration,
        reverseTransitionDuration: _kDuration,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return _buildPushPopTransition(
            animation: animation,
            child: child,
            enterOffset: const Offset(0.06, 0),
          );
        },
      );

/// Lift from below + fade. Use for detail pages opened from a list item.
Page<void> _liftPage(Widget child) => _isCupertinoNavigationPlatform
    ? CupertinoPage<void>(child: RouteSilentRefresh(child: child))
    : CustomTransitionPage<void>(
        child: RouteSilentRefresh(child: child),
        transitionDuration: _kDuration,
        reverseTransitionDuration: _kDuration,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return _buildPushPopTransition(
            animation: animation,
            child: child,
            enterOffset: const Offset(0, 0.05),
          );
        },
      );

Page<void> _adminPanelPage(Widget child, {bool root = false}) =>
    CustomTransitionPage<void>(
      opaque: false,
      barrierColor: const Color(0x8A000000),
      child: _AdminPanelRouteFrame(child: RouteSilentRefresh(child: child)),
      transitionDuration: _kDuration,
      reverseTransitionDuration: _kDuration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: _kCurve,
          reverseCurve: _kCurve,
        );
        final isPopping = animation.status == AnimationStatus.reverse;
        final offset = root
            ? Tween<Offset>(
                begin: isPopping ? Offset.zero : const Offset(0, 1),
                end: isPopping ? const Offset(0, 1) : Offset.zero,
              ).animate(curved)
            : Tween<Offset>(
                begin: isPopping ? Offset.zero : const Offset(0.08, 0),
                end: isPopping ? const Offset(1, 0) : Offset.zero,
              ).animate(curved);
        return SlideTransition(position: offset, child: child);
      },
    );

/// Cross-fade. Use for full-screen takeovers (auth, status screens).
Page<void> _fadePage(Widget child) => CustomTransitionPage<void>(
  child: RouteSilentRefresh(child: child),
  transitionDuration: _kDuration,
  transitionsBuilder: (context, animation, secondaryAnimation, child) =>
      FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: _kCurve),
        child: child,
      ),
);

Widget _buildPushPopTransition({
  required Animation<double> animation,
  required Widget child,
  required Offset enterOffset,
}) {
  final curved = CurvedAnimation(
    parent: animation,
    curve: _kCurve,
    reverseCurve: _kCurve,
  );
  final isPopping = animation.status == AnimationStatus.reverse;
  final position = Tween<Offset>(
    begin: isPopping ? Offset.zero : enterOffset,
    end: isPopping ? const Offset(1, 0) : Offset.zero,
  ).animate(curved);

  final transitioningChild = SlideTransition(position: position, child: child);
  if (isPopping) {
    return transitioningChild;
  }

  return FadeTransition(opacity: curved, child: transitioningChild);
}

class _AdminPanelRouteFrame extends StatelessWidget {
  const _AdminPanelRouteFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: FractionallySizedBox(
        heightFactor: 0.96,
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: child,
        ),
      ),
    );
  }
}

bool get _isCupertinoNavigationPlatform =>
    defaultTargetPlatform == TargetPlatform.iOS;
