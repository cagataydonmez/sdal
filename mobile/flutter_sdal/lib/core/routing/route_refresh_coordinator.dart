import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:go_router/go_router.dart';

import '../../features/admin/data/admin_repository.dart';
import '../../features/albums/data/albums_repository.dart';
import '../../features/explore/data/explore_repository.dart';
import '../../features/feed/data/feed_repository.dart';
import '../../features/groups/data/groups_repository.dart';
import '../../features/messenger/data/messenger_repository.dart';
import '../../features/networking/data/networking_repository.dart';
import '../../features/notifications/data/notifications_repository.dart';
import '../../features/profile/data/profile_repository.dart';
import '../../features/requests/data/requests_repository.dart';
import '../../features/stories/data/stories_repository.dart';
import '../session/session_controller.dart';
import '../shell/shell_metadata_repository.dart';

class RouteRefreshSignal {
  const RouteRefreshSignal({required this.uri, required this.sequence});

  final Uri uri;
  final int sequence;

  String get path => uri.path;

  bool matches(String routePath) => path == routePath;
  bool startsWith(String routePrefix) => path.startsWith(routePrefix);
}

final routeRefreshSignalProvider = StateProvider<RouteRefreshSignal?>(
  (ref) => null,
);

final Set<String> _seenRouteRefreshKeys = <String>{};
final Map<String, DateTime> _lastRouteRefreshAt = <String, DateTime>{};
int _routeRefreshSequence = 0;

const _routeRefreshMinInterval = Duration(seconds: 2);

class RouteSilentRefresh extends ConsumerStatefulWidget {
  const RouteSilentRefresh({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<RouteSilentRefresh> createState() => _RouteSilentRefreshState();
}

class _RouteSilentRefreshState extends ConsumerState<RouteSilentRefresh> {
  String? _lastRouteKey;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scheduleForCurrentRoute();
  }

  void _scheduleForCurrentRoute() {
    final uri = _currentUri(context);
    if (uri == null) return;
    final key = _routeRefreshKey(uri);
    if (_lastRouteKey == key) return;
    _lastRouteKey = key;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      scheduleRouteSilentRefresh(ref, uri);
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

void scheduleRouteSilentRefresh(WidgetRef ref, Uri uri, {bool force = false}) {
  final path = uri.path;
  if (_isPublicOrStatusRoute(path)) return;

  final key = _routeRefreshKey(uri);
  final wasSeen = _seenRouteRefreshKeys.contains(key);
  _seenRouteRefreshKeys.add(key);
  if (!force && !wasSeen) return;

  final now = DateTime.now();
  final lastRun = _lastRouteRefreshAt[key];
  if (lastRun != null && now.difference(lastRun) < _routeRefreshMinInterval) {
    return;
  }
  _lastRouteRefreshAt[key] = now;

  ref.read(routeRefreshSignalProvider.notifier).state = RouteRefreshSignal(
    uri: uri,
    sequence: ++_routeRefreshSequence,
  );

  unawaited(ref.read(sessionControllerProvider.notifier).refreshSilently());
  ref.invalidate(shellMenuProvider);
  _invalidateRouteProviders(ref, uri);
}

Uri? _currentUri(BuildContext context) {
  try {
    return GoRouterState.of(context).uri;
  } catch (_) {
    return null;
  }
}

String _routeRefreshKey(Uri uri) {
  final query = uri.hasQuery ? '?${uri.query}' : '';
  return '${uri.path}$query';
}

bool _isPublicOrStatusRoute(String path) {
  return path == '/login' ||
      path == '/register' ||
      path == '/activate' ||
      path == '/activation/resend' ||
      path == '/legal' ||
      path == '/password-reset' ||
      path == '/device-challenge' ||
      path == '/oauth/callback' ||
      path == '/site-closed' ||
      path == '/module-closed' ||
      path == '/account-banned' ||
      path == '/verification-required';
}

void _invalidateRouteProviders(WidgetRef ref, Uri uri) {
  final path = uri.path;

  if (path == '/feed') {
    _invalidateFeed(ref);
    return;
  }

  final postId = _idAfter(path, '/posts/');
  if (postId != null) {
    ref.invalidate(postDetailProvider(postId));
    ref.invalidate(postCommentsProvider(postId));
    _invalidateFeed(ref);
    return;
  }

  if (path == '/explore') {
    ref.invalidate(latestMembersProvider);
    ref.invalidate(suggestionMembersProvider);
    ref.invalidate(directoryMembersProvider);
    return;
  }

  final memberId = _idAfter(path, '/members/');
  if (memberId != null) {
    ref.invalidate(memberDetailProvider(memberId));
    ref.invalidate(memberProfileAlbumsProvider(memberId));
    ref.invalidate(memberStoriesProvider(memberId));
    return;
  }

  if (path == '/messenger' || path == '/inbox') {
    ref.invalidate(messengerThreadsProvider(''));
    ref.invalidate(messengerUnreadCountProvider);
    return;
  }

  final threadId = _idAfter(path, '/messages/');
  if (threadId != null) {
    ref.invalidate(messengerMessagesProvider(threadId));
    ref.invalidate(messengerThreadsProvider(''));
    ref.invalidate(messengerUnreadCountProvider);
    return;
  }

  if (path == '/notifications') {
    ref.invalidate(notificationsProvider);
    ref.invalidate(notificationPreferencesProvider);
    ref.invalidate(notificationUnreadCountProvider);
    return;
  }

  final notificationId = _idAfter(path, '/notifications/');
  if (notificationId != null) {
    ref.invalidate(notificationDetailProvider(notificationId));
    ref.invalidate(notificationsProvider);
    ref.invalidate(notificationUnreadCountProvider);
    return;
  }

  if (path == '/requests') {
    ref.invalidate(requestCategoriesProvider);
    ref.invalidate(myRequestsProvider);
    return;
  }

  if (path == '/profile') {
    ref.invalidate(profileProvider);
    ref.invalidate(myAlbumsProvider);
    ref.invalidate(myStoriesProvider(FeedType.main.apiValue));
    ref.invalidate(myStoriesProvider(FeedType.community.apiValue));
    return;
  }

  if (path == '/albums') {
    _invalidateAlbums(ref);
    return;
  }

  if (path.startsWith('/albums/')) {
    _invalidateAlbums(ref);
    final photoId = _idAfter(path, '/albums/photo/');
    if (photoId != null) ref.invalidate(albumPhotoLikesProvider(photoId));
    return;
  }

  if (path == '/groups') {
    ref.invalidate(groupsListProvider);
    return;
  }

  final groupId = _idAfter(path, '/groups/');
  if (groupId != null) {
    ref.invalidate(groupDetailProvider(groupId));
    ref.invalidate(groupPostsProvider(groupId));
    ref.invalidate(groupContentApprovalSettingsProvider(groupId));
    ref.invalidate(groupContentApprovalsProvider(groupId));
    return;
  }

  if (path == '/network/hub') {
    ref.invalidate(networkHubProvider);
    ref.invalidate(networkMetricsProvider);
    ref.invalidate(connectionRequestsProvider);
    ref.invalidate(mentorshipRequestsProvider);
    return;
  }

  if (path == '/network/inbox') {
    ref.invalidate(networkInboxProvider);
    ref.invalidate(connectionRequestsProvider);
    ref.invalidate(mentorshipRequestsProvider);
    return;
  }

  if (path == '/network/teachers') {
    ref.invalidate(teacherLinksProvider);
    return;
  }

  final teacherId = _teacherMapId(path);
  if (teacherId != null) {
    ref.invalidate(teacherNetworkMapProvider(teacherId));
    return;
  }

  if (path == '/admin' || path == '/moderation') {
    _invalidateAdminOverview(ref);
    return;
  }

  if (path.startsWith('/admin/')) {
    _invalidateAdminRoute(ref, path);
  }
}

void _invalidateFeed(WidgetRef ref) {
  ref.invalidate(feedItemsProvider);
  ref.invalidate(feedPageProvider);
  ref.invalidate(onlineMembersProvider);
  ref.invalidate(feedStoriesProvider(FeedType.main.apiValue));
  ref.invalidate(feedStoriesProvider(FeedType.community.apiValue));
}

void _invalidateAlbums(WidgetRef ref) {
  ref.invalidate(albumsDashboardProvider);
  ref.invalidate(myAlbumsProvider);
}

void _invalidateAdminOverview(WidgetRef ref) {
  ref.invalidate(adminEffectiveAccessProvider);
  ref.invalidate(adminMobileSummaryProvider);
  ref.invalidate(adminAccessProvider);
  ref.invalidate(adminSummaryProvider);
  ref.invalidate(adminLiveProvider);
  ref.invalidate(adminSecurityProvider);
  ref.invalidate(adminRequestNotificationsProvider);
}

void _invalidateAdminRoute(WidgetRef ref, String path) {
  _invalidateAdminOverview(ref);

  if (path == '/admin/modules') {
    ref.invalidate(adminSiteControlsProvider);
    ref.invalidate(adminPagesProvider);
    return;
  }
  if (path == '/admin/teacher-network') {
    ref.invalidate(adminTeacherNetworkLinkPreviewProvider);
    ref.invalidate(adminTeacherNetworkLinksProvider);
    return;
  }
  if (path == '/admin/teacher-accounts') {
    ref.invalidate(adminTeacherAccountsProvider);
    return;
  }
  if (path == '/admin/audit') {
    ref.invalidate(adminAuditLogProvider);
    return;
  }
  if (path == '/admin/root') {
    ref.invalidate(adminSecurityProvider);
    ref.invalidate(adminAuthSecurityProvider);
    return;
  }
  if (path == '/admin/root/member-activity') {
    ref.invalidate(adminRootActivityUsersProvider);
    ref.invalidate(adminRootMemberActivityProvider);
    return;
  }
  if (path == '/admin/permission-groups') {
    ref.invalidate(adminPermissionsProvider);
    ref.invalidate(adminPermissionGroupsProvider);
    return;
  }
  if (path == '/admin/user-permissions') {
    ref.invalidate(adminPermissionsProvider);
    ref.invalidate(adminPermissionGroupsProvider);
    ref.invalidate(adminPermissionUsersProvider);
    return;
  }

  final sectionKey = path.substring('/admin/'.length);
  _invalidateAdminSection(ref, sectionKey);
}

void _invalidateAdminSection(WidgetRef ref, String sectionKey) {
  switch (sectionKey) {
    case 'content':
      ref.invalidate(adminPostPreviewProvider);
      ref.invalidate(adminCommentPreviewProvider);
      ref.invalidate(adminStoryPreviewProvider);
      ref.invalidate(adminContentApprovalSettingsProvider);
      ref.invalidate(adminContentApprovalsProvider);
      break;
    case 'requests':
      ref.invalidate(adminMemberRequestPreviewProvider);
      ref.invalidate(adminVerificationRequestPreviewProvider);
      ref.invalidate(adminApprovedVerificationRequestPreviewProvider);
      ref.invalidate(adminTeacherNetworkLinkPreviewProvider);
      ref.invalidate(adminVerificationSettingsProvider);
      ref.invalidate(adminRequestNotificationsProvider);
      break;
    case 'management':
      ref.invalidate(adminUserPreviewProvider);
      break;
    case 'api-monitor':
      ref.invalidate(adminUserPreviewProvider);
      ref.invalidate(adminUserApiActivityProvider);
      break;
    case 'notifications':
      ref.invalidate(adminNotificationOpsProvider);
      ref.invalidate(adminPushSettingsProvider);
      ref.invalidate(adminBroadcastHistoryProvider);
      break;
    case 'auth-security':
      ref.invalidate(adminAuthSecurityProvider);
      ref.invalidate(adminAuthSettingsProvider);
      break;
    case 'operations':
      ref.invalidate(adminSiteControlsProvider);
      ref.invalidate(adminPagesProvider);
      ref.invalidate(adminEmailCategoriesProvider);
      ref.invalidate(adminEmailTemplatesProvider);
      ref.invalidate(adminAppLogFilesProvider);
      break;
    case 'database':
      ref.invalidate(adminDbBackupsProvider);
      ref.invalidate(adminDbDriverStatusProvider);
      break;
    case 'languages':
      ref.invalidate(adminLanguagesProvider);
      ref.invalidate(adminLanguageConfigProvider);
      ref.invalidate(adminLanguageKeysProvider);
      ref.invalidate(adminLanguageStringsProvider);
      break;
  }
}

int? _idAfter(String path, String prefix) {
  if (!path.startsWith(prefix)) return null;
  final raw = path.substring(prefix.length).split('/').first;
  return int.tryParse(raw);
}

int? _teacherMapId(String path) {
  const prefix = '/network/teachers/';
  const suffix = '/map';
  if (!path.startsWith(prefix) || !path.endsWith(suffix)) return null;
  final raw = path.substring(prefix.length, path.length - suffix.length);
  return int.tryParse(raw);
}
