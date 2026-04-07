import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../network/api_client.dart';
import '../network/json_utils.dart';

class ShellMenuSnapshot {
  const ShellMenuSnapshot({required this.items, required this.badges});

  final List<ShellMenuItem> items;
  final Map<String, int> badges;

  List<ShellMenuItem> get appItems =>
      items.where((item) => item.appRoute != null).toList(growable: false);

  int? badgeForRoute(String route) {
    final routeBadge = badges[route];
    if (routeBadge != null) return routeBadge;
    final routeKeys = _routeBadgeKeys(route);
    for (final key in routeKeys) {
      final badge = badges[key];
      if (badge != null) return badge;
    }
    for (final item in appItems) {
      if (item.appRoute == route && item.badgeCount != null) {
        return item.badgeCount;
      }
    }
    return null;
  }
}

class ShellMenuItem {
  const ShellMenuItem({
    required this.label,
    required this.url,
    required this.legacyUrl,
    this.badgeCount,
  });

  final String label;
  final String url;
  final String legacyUrl;
  final int? badgeCount;

  String? get appRoute => normalizeShellMenuRoute(url);
}

class ShellSidebarSnapshot {
  const ShellSidebarSnapshot({
    required this.onlineUsers,
    required this.newMembers,
    required this.newMessagesCount,
  });

  final List<ShellSidebarMember> onlineUsers;
  final List<ShellSidebarMember> newMembers;
  final int newMessagesCount;
}

class ShellSidebarMember {
  const ShellSidebarMember({
    required this.id,
    required this.username,
    required this.firstName,
    required this.lastName,
    required this.photo,
    required this.graduationYear,
  });

  final int id;
  final String username;
  final String firstName;
  final String lastName;
  final String photo;
  final String graduationYear;

  String get displayName {
    final fullName = '${firstName.trim()} ${lastName.trim()}'.trim();
    if (fullName.isNotEmpty) return fullName;
    if (username.isNotEmpty) return '@$username';
    return 'SDAL Üyesi';
  }
}

class QuickAccessUser {
  const QuickAccessUser({
    required this.id,
    required this.kadi,
    required this.photo,
    required this.graduationYear,
    required this.isOnline,
  });

  final int id;
  final String kadi;
  final String photo;
  final String graduationYear;
  final bool isOnline;

  String get displayName => kadi.isNotEmpty ? '@$kadi' : 'SDAL Üyesi';
}

class ShellMetadataRepository {
  const ShellMetadataRepository({required this.apiClient});

  final ApiClient apiClient;

  Future<ShellMenuSnapshot> fetchMenu() async {
    final result = await apiClient.get<JsonMap>(
      '/api/menu',
      decoder: (raw) => asJsonMap(raw),
    );
    final payload = asJsonMap(result.rawData);
    final items = asJsonMapList(payload['items'])
        .map((row) {
          final normalized = normalizeJsonAliases(row, {
            'label': ['title', 'name'],
            'url': const [],
            'legacyUrl': ['legacy_url', 'legacy'],
            'badgeCount': ['badge', 'count', 'unread', 'unreadCount'],
          });
          return ShellMenuItem(
            label: coalesceText([normalized['label']], fallback: ''),
            url: coalesceText([normalized['url']], fallback: ''),
            legacyUrl: coalesceText([
              normalized['legacyUrl'],
              normalized['url'],
            ], fallback: ''),
            badgeCount: asInt(normalized['badgeCount']),
          );
        })
        .where((item) => item.label.isNotEmpty && item.url.isNotEmpty)
        .toList(growable: false);

    final rawBadges = asJsonMap(payload['badges']);
    final badges = <String, int>{};
    rawBadges.forEach((key, value) {
      final count = asInt(value);
      if (count != null && count > 0) {
        badges[key] = count;
      }
    });

    final topLevelFallbacks = <String, dynamic>{
      'messages': payload['newMessagesCount'],
      'inbox': payload['newMessagesCount'],
      'notifications': payload['newNotificationsCount'],
    };
    topLevelFallbacks.forEach((key, value) {
      final count = asInt(value);
      if (count != null && count > 0) {
        badges[key] = math.max(count, badges[key] ?? 0);
      }
    });

    return ShellMenuSnapshot(items: items, badges: badges);
  }

  Future<ShellSidebarSnapshot> fetchSidebar() async {
    final result = await apiClient.get<JsonMap>(
      '/api/sidebar',
      decoder: (raw) => asJsonMap(raw),
    );
    final payload = asJsonMap(result.rawData);
    return ShellSidebarSnapshot(
      onlineUsers: asJsonMapList(
        payload['onlineUsers'],
      ).map(_shellSidebarMemberFromMap).toList(growable: false),
      newMembers: asJsonMapList(
        payload['newMembers'],
      ).map(_shellSidebarMemberFromMap).toList(growable: false),
      newMessagesCount: asInt(payload['newMessagesCount']) ?? 0,
    );
  }

  Future<List<QuickAccessUser>> fetchQuickAccess() async {
    final result = await apiClient.get<JsonMap>(
      '/api/quick-access',
      decoder: (raw) => asJsonMap(raw),
    );
    final payload = asJsonMap(result.rawData);
    return asJsonMapList(
          payload['users'] ?? payload['items'] ?? payload['rows'],
        )
        .map(_quickAccessUserFromMap)
        .where((user) => user.id > 0)
        .toList(growable: false);
  }

  Future<dynamic> addQuickAccessUser(int memberId) {
    return apiClient.post<dynamic>(
      '/api/quick-access/add',
      body: {'id': memberId},
    );
  }

  Future<dynamic> removeQuickAccessUser(int memberId) {
    return apiClient.post<dynamic>(
      '/api/quick-access/remove',
      body: {'id': memberId},
    );
  }
}

ShellSidebarMember _shellSidebarMemberFromMap(JsonMap row) {
  final normalized = normalizeJsonAliases(row, {
    'username': ['kadi'],
    'firstName': ['isim'],
    'lastName': ['soyisim'],
    'photo': ['resim'],
    'graduationYear': ['mezuniyetyili'],
  });
  return ShellSidebarMember(
    id: asInt(normalized['id']) ?? 0,
    username: coalesceText([normalized['username']], fallback: ''),
    firstName: coalesceText([normalized['firstName']], fallback: ''),
    lastName: coalesceText([normalized['lastName']], fallback: ''),
    photo: coalesceText([normalized['photo']], fallback: ''),
    graduationYear: coalesceText([normalized['graduationYear']], fallback: ''),
  );
}

QuickAccessUser _quickAccessUserFromMap(JsonMap row) {
  final normalized = normalizeJsonAliases(row, {
    'kadi': ['username'],
    'photo': ['resim'],
    'graduationYear': ['mezuniyetyili'],
    'isOnline': ['online'],
  });
  return QuickAccessUser(
    id: asInt(normalized['id']) ?? 0,
    kadi: coalesceText([normalized['kadi']], fallback: ''),
    photo: coalesceText([normalized['photo']], fallback: ''),
    graduationYear: coalesceText([normalized['graduationYear']], fallback: ''),
    isOnline: asBool(normalized['isOnline']) ?? false,
  );
}

String? normalizeShellMenuRoute(String raw) {
  final value = raw.trim().toLowerCase();
  if (value.isEmpty) return null;
  if (value.startsWith('/new/feed') || value == '/feed') return '/feed';
  if (value.startsWith('/new/explore') || value == '/explore') {
    return '/explore';
  }
  if (value.startsWith('/new/notifications') || value == '/notifications') {
    return '/notifications';
  }
  if (value.startsWith('/new/profile') || value == '/profile') {
    return '/profile';
  }
  if (value.startsWith('/new/messages') ||
      value.startsWith('/new/messenger') ||
      value == '/inbox') {
    return '/inbox';
  }
  if (value.startsWith('/new/requests') || value == '/requests') {
    return '/requests';
  }
  if (value.startsWith('/new/following') || value == '/following') {
    return '/following';
  }
  if (value.startsWith('/new/networking') || value == '/network/hub') {
    return '/network/hub';
  }
  if (value.startsWith('/new/teacher') || value == '/network/teachers') {
    return '/network/teachers';
  }
  if (value == '/groups' || value.startsWith('/new/groups')) return '/groups';
  if (value == '/events' || value.startsWith('/new/events')) return '/events';
  if (value == '/announcements' || value.startsWith('/new/announcements')) {
    return '/announcements';
  }
  if (value == '/panolar' ||
      value.startsWith('/panolar?') ||
      value.contains('pano.asp') ||
      value.contains('panolar.asp') ||
      value.contains('mesajpanosu.asp')) {
    return '/panolar';
  }
  if (value == '/jobs' || value.startsWith('/new/jobs')) return '/jobs';
  if (value == '/opportunities' || value.startsWith('/new/opportunities')) {
    return '/opportunities';
  }
  if (value == '/albums' || value.startsWith('/new/albums')) return '/albums';
  if (value == '/feed/live-chat' || value.startsWith('/new/live-chat')) {
    return '/feed/live-chat';
  }
  return null;
}

IconData iconForShellRoute(String route) => switch (route) {
  '/feed' => Icons.dynamic_feed_outlined,
  '/explore' => Icons.explore_outlined,
  '/inbox' => Icons.chat_bubble_outline,
  '/notifications' => Icons.notifications_outlined,
  '/profile' => Icons.person_outline,
  '/groups' => Icons.groups_outlined,
  '/events' => Icons.event_outlined,
  '/announcements' => Icons.campaign_outlined,
  '/panolar' => Icons.view_agenda_outlined,
  '/requests' => Icons.assignment_outlined,
  '/network/hub' => Icons.hub_outlined,
  '/network/teachers' => Icons.school_outlined,
  '/jobs' => Icons.work_outline,
  '/opportunities' => Icons.auto_awesome_outlined,
  '/albums' => Icons.photo_library_outlined,
  '/following' => Icons.favorite_border,
  '/feed/live-chat' => Icons.forum_outlined,
  _ => Icons.link_rounded,
};

List<String> _routeBadgeKeys(String route) => switch (route) {
  '/inbox' => const ['messages', 'inbox', 'messenger', 'newMessagesCount'],
  '/notifications' => const [
    'notifications',
    'notification',
    'newNotificationsCount',
  ],
  _ => <String>[route],
};

final shellMetadataRepositoryProvider = Provider<ShellMetadataRepository>(
  (ref) => ShellMetadataRepository(apiClient: ref.watch(apiClientProvider)),
);

final shellMenuProvider = FutureProvider<ShellMenuSnapshot>(
  (ref) => ref.watch(shellMetadataRepositoryProvider).fetchMenu(),
);

final shellSidebarProvider = FutureProvider<ShellSidebarSnapshot>(
  (ref) => ref.watch(shellMetadataRepositoryProvider).fetchSidebar(),
);

final quickAccessUsersProvider = FutureProvider<List<QuickAccessUser>>(
  (ref) => ref.watch(shellMetadataRepositoryProvider).fetchQuickAccess(),
);
