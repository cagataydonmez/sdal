import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/providers.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_result.dart';
import '../../../core/network/json_utils.dart';

class NotificationTarget {
  const NotificationTarget({
    required this.route,
    required this.href,
    required this.label,
  });

  final String route;
  final String href;
  final String label;

  factory NotificationTarget.fromMap(JsonMap map) {
    return NotificationTarget(
      route: coalesceText([map['route']], fallback: ''),
      href: coalesceText([map['href']], fallback: ''),
      label: coalesceText([map['label']], fallback: ''),
    );
  }
}

class NotificationActionItem {
  const NotificationActionItem({
    required this.kind,
    required this.label,
    required this.endpoint,
    required this.method,
  });

  final String kind;
  final String label;
  final String endpoint;
  final String method;

  factory NotificationActionItem.fromMap(JsonMap map) {
    return NotificationActionItem(
      kind: coalesceText([map['kind']], fallback: ''),
      label: coalesceText([map['label']], fallback: 'İşlem'),
      endpoint: coalesceText([map['endpoint']], fallback: ''),
      method: coalesceText([map['method']], fallback: 'POST'),
    );
  }
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.message,
    required this.createdAt,
    required this.readAt,
    required this.category,
    required this.priority,
    required this.target,
    required this.actions,
    required this.sourceName,
  });

  final int id;
  final String type;
  final String message;
  final String createdAt;
  final String readAt;
  final String category;
  final String priority;
  final NotificationTarget? target;
  final List<NotificationActionItem> actions;
  final String sourceName;

  bool get isUnread => readAt.isEmpty;

  factory AppNotification.fromMap(JsonMap map) {
    return AppNotification(
      id: asInt(map['id']) ?? 0,
      type: coalesceText([map['type']], fallback: ''),
      message: coalesceText([map['message']], fallback: 'Bildirim'),
      createdAt: coalesceText([map['created_at']], fallback: ''),
      readAt: coalesceText([map['read_at']], fallback: ''),
      category: coalesceText([map['category']], fallback: ''),
      priority: coalesceText([map['priority']], fallback: ''),
      target: asJsonMap(map['target']).isEmpty
          ? null
          : NotificationTarget.fromMap(asJsonMap(map['target'])),
      actions: asJsonMapList(
        map['actions'],
      ).map(NotificationActionItem.fromMap).toList(growable: false),
      sourceName: coalesceText([map['isim'], map['kadi']], fallback: ''),
    );
  }
}

class NotificationPreferences {
  const NotificationPreferences({
    required this.categories,
    required this.quietModeEnabled,
    required this.quietModeStart,
    required this.quietModeEnd,
  });

  final Map<String, bool> categories;
  final bool quietModeEnabled;
  final String quietModeStart;
  final String quietModeEnd;

  factory NotificationPreferences.fromMap(JsonMap map) {
    final preferences = asJsonMap(map['preferences']);
    final categories = asJsonMap(
      preferences['categories'],
    ).map((key, value) => MapEntry(key, asBool(value) ?? true));
    final quietMode = asJsonMap(preferences['quiet_mode']);
    return NotificationPreferences(
      categories: categories,
      quietModeEnabled: asBool(quietMode['enabled']) ?? false,
      quietModeStart: coalesceText([quietMode['start']], fallback: ''),
      quietModeEnd: coalesceText([quietMode['end']], fallback: ''),
    );
  }
}

class NotificationsRepository {
  const NotificationsRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<List<AppNotification>> fetchNotifications() async {
    final result = await _apiClient.get<JsonMap>(
      '/api/new/notifications',
      decoder: asJsonMap,
    );
    final items = asJsonMapList(
      asJsonMap(asJsonMap(result.rawData)['data'])['items'],
    );
    return items.map(AppNotification.fromMap).toList(growable: false);
  }

  Future<int> fetchUnreadCount() async {
    final result = await _apiClient.get<JsonMap>(
      '/api/new/notifications/unread',
      decoder: asJsonMap,
    );
    return asInt(asJsonMap(result.rawData)['count']) ?? 0;
  }

  Future<NotificationPreferences> fetchPreferences() async {
    final result = await _apiClient.get<JsonMap>(
      '/api/new/notifications/preferences',
      decoder: asJsonMap,
    );
    return NotificationPreferences.fromMap(asJsonMap(result.rawData));
  }

  Future<ApiResult<dynamic>> markAllRead() {
    return _apiClient.post<dynamic>('/api/new/notifications/bulk-read');
  }

  Future<ApiResult<dynamic>> markRead(int notificationId) {
    return _apiClient.post<dynamic>(
      '/api/new/notifications/$notificationId/read',
    );
  }

  Future<ApiResult<JsonMap>> openNotification(int notificationId) {
    return _apiClient.post<JsonMap>(
      '/api/new/notifications/$notificationId/open',
      decoder: asJsonMap,
    );
  }

  Future<ApiResult<dynamic>> runAction(NotificationActionItem action) {
    final method = action.method.toUpperCase();
    if (method == 'PUT') {
      return _apiClient.put<dynamic>(action.endpoint);
    }
    if (method == 'DELETE') {
      return _apiClient.delete<dynamic>(action.endpoint);
    }
    return _apiClient.post<dynamic>(action.endpoint);
  }

  Future<ApiResult<dynamic>> savePreferences(
    NotificationPreferences preferences,
  ) {
    return _apiClient.put<dynamic>(
      '/api/new/notifications/preferences',
      body: {
        'categories': preferences.categories,
        'quiet_mode': {
          'enabled': preferences.quietModeEnabled,
          'start': preferences.quietModeStart,
          'end': preferences.quietModeEnd,
        },
      },
    );
  }
}

final notificationsRepositoryProvider = Provider<NotificationsRepository>(
  (ref) => NotificationsRepository(ref.watch(apiClientProvider)),
);

final notificationsProvider = FutureProvider.autoDispose<List<AppNotification>>(
  (ref) => ref.watch(notificationsRepositoryProvider).fetchNotifications(),
);

final notificationPreferencesProvider =
    FutureProvider.autoDispose<NotificationPreferences>(
      (ref) => ref.watch(notificationsRepositoryProvider).fetchPreferences(),
    );

final notificationUnreadCountProvider = FutureProvider.autoDispose<int>(
  (ref) => ref.watch(notificationsRepositoryProvider).fetchUnreadCount(),
);
