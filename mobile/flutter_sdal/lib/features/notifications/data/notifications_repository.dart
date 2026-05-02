import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import '../../../app/providers.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/paged_response.dart';
import '../../../core/network/api_result.dart';
import '../../../core/network/json_utils.dart';

part 'notifications_repository.freezed.dart';
part 'notifications_repository.g.dart';

@freezed
abstract class NotificationTarget with _$NotificationTarget {
  const factory NotificationTarget({
    @JsonKey(fromJson: readRequiredText) required String route,
    @JsonKey(fromJson: readRequiredText) required String href,
    @JsonKey(fromJson: readRequiredText) required String label,
  }) = _NotificationTarget;

  factory NotificationTarget.fromJson(Map<String, dynamic> json) =>
      _$NotificationTargetFromJson(json);

  factory NotificationTarget.fromMap(JsonMap map) =>
      NotificationTarget.fromJson(map);
}

@freezed
abstract class NotificationActionItem with _$NotificationActionItem {
  const factory NotificationActionItem({
    @JsonKey(fromJson: readRequiredText) required String kind,
    @JsonKey(fromJson: _readActionLabel) required String label,
    @JsonKey(fromJson: readRequiredText) required String endpoint,
    @JsonKey(fromJson: _readActionMethod) required String method,
  }) = _NotificationActionItem;

  factory NotificationActionItem.fromJson(Map<String, dynamic> json) =>
      _$NotificationActionItemFromJson(
        normalizeJsonAliases(json, {'label': const [], 'method': const []}),
      );

  factory NotificationActionItem.fromMap(JsonMap map) =>
      NotificationActionItem.fromJson(
        normalizeJsonAliases(map, {'label': const [], 'method': const []}),
      );
}

@freezed
abstract class AppNotification with _$AppNotification {
  const AppNotification._();

  const factory AppNotification({
    @JsonKey(fromJson: readRequiredInt) required int id,
    @JsonKey(fromJson: readRequiredText) required String type,
    @JsonKey(fromJson: readRequiredText) required String message,
    @JsonKey(fromJson: readRequiredText) required String createdAt,
    @JsonKey(fromJson: readRequiredText) required String readAt,
    @JsonKey(fromJson: readRequiredText) required String category,
    @JsonKey(fromJson: readRequiredText) required String priority,
    NotificationTarget? target,
    @Default(<NotificationActionItem>[]) List<NotificationActionItem> actions,
    @JsonKey(fromJson: readRequiredText) required String sourceName,
    @JsonKey(fromJson: readRequiredText) required String sourcePhoto,
    @JsonKey(fromJson: readRequiredText) required String sourceInitials,
    @JsonKey(fromJson: readRequiredText) required String imageUrl,
    @JsonKey(fromJson: readRequiredText) required String imageShape,
  }) = _AppNotification;

  bool get isUnread => readAt.isEmpty;

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      _$AppNotificationFromJson(
        normalizeJsonAliases(json, {
          'createdAt': ['created_at'],
          'readAt': ['read_at'],
          'sourceName': ['isim', 'kadi'],
          'sourcePhoto': ['source_photo', 'resim'],
          'sourceInitials': ['source_initials'],
          'imageUrl': ['image_url'],
          'imageShape': ['image_shape'],
        }),
      );

  factory AppNotification.fromMap(JsonMap map) => AppNotification.fromJson(map);
}

@freezed
abstract class NotificationPreferences with _$NotificationPreferences {
  const factory NotificationPreferences({
    @NotificationCategoryConverter() required Map<String, bool> categories,
    @JsonKey(fromJson: readRequiredBool) required bool quietModeEnabled,
    @JsonKey(fromJson: readRequiredText) required String quietModeStart,
    @JsonKey(fromJson: readRequiredText) required String quietModeEnd,
  }) = _NotificationPreferences;

  factory NotificationPreferences.fromJson(Map<String, dynamic> json) =>
      _$NotificationPreferencesFromJson(json);

  factory NotificationPreferences.fromMap(JsonMap map) {
    final preferences = asJsonMap(map['preferences']).isEmpty
        ? map
        : asJsonMap(map['preferences']);
    final quietMode = asJsonMap(preferences['quiet_mode']);
    return NotificationPreferences.fromJson({
      'categories': preferences['categories'],
      'quietModeEnabled': quietMode['enabled'],
      'quietModeStart': quietMode['start'],
      'quietModeEnd': quietMode['end'],
    });
  }
}

class NotificationCategoryConverter
    implements JsonConverter<Map<String, bool>, Map<String, dynamic>?> {
  const NotificationCategoryConverter();

  @override
  Map<String, bool> fromJson(Map<String, dynamic>? json) {
    if (json == null) return const <String, bool>{};
    return asJsonMap(
      json,
    ).map((key, value) => MapEntry(key, asBool(value) ?? true));
  }

  @override
  Map<String, dynamic> toJson(Map<String, bool> object) =>
      Map<String, dynamic>.from(object);
}

class NotificationTelemetryEvent {
  const NotificationTelemetryEvent({
    required this.eventName,
    this.notificationId,
    this.notificationType = '',
    this.surface = '',
    this.actionKind = '',
  });

  final int? notificationId;
  final String eventName;
  final String notificationType;
  final String surface;
  final String actionKind;

  JsonMap toJson() => <String, dynamic>{
    if (notificationId != null) 'notification_id': notificationId,
    'event_name': eventName,
    if (notificationType.trim().isNotEmpty)
      'notification_type': notificationType,
    if (surface.trim().isNotEmpty) 'surface': surface,
    if (actionKind.trim().isNotEmpty) 'action_kind': actionKind,
  };
}

String _readActionLabel(dynamic value) => asString(value) ?? 'İşlem';

String _readActionMethod(dynamic value) => asString(value) ?? 'POST';

class NotificationsRepository {
  const NotificationsRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<PagedResponse<AppNotification>> fetchNotifications({
    String? cursor,
    int limit = 20,
    String sort = 'priority',
  }) async {
    final result = await _apiClient.get<dynamic>(
      '/api/new/notifications',
      query: {'limit': limit, 'cursor': cursor, 'sort': sort},
    );
    return PagedResponse<AppNotification>.fromDynamic(
      asJsonMap(result.rawData)['data'] ?? result.rawData,
      AppNotification.fromMap,
    );
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

  Future<ApiResult<dynamic>> markAllRead() async {
    final canonical = await _apiClient.post<dynamic>(
      '/api/new/notifications/read',
    );
    if (canonical.ok || !_shouldFallback(canonical.statusCode)) {
      return canonical;
    }
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

  Future<AppNotification> fetchNotificationDetail(int notificationId) async {
    final result = await openNotification(notificationId);
    if (!result.ok) {
      throw StateError(
        result.message.isNotEmpty ? result.message : 'Bildirim açılamadı.',
      );
    }
    final item = asJsonMap(asJsonMap(result.rawData)['item']);
    if (item.isEmpty) throw StateError('Bildirim bulunamadı.');
    return AppNotification.fromMap(item);
  }

  Future<ApiResult<JsonMap>> trackTelemetry(
    List<NotificationTelemetryEvent> events,
  ) {
    if (events.isEmpty) {
      return Future.value(
        const ApiResult<JsonMap>(
          ok: true,
          statusCode: 200,
          message: '',
          code: '',
          data: <String, dynamic>{},
          rawData: <String, dynamic>{},
        ),
      );
    }
    return _apiClient.post<JsonMap>(
      '/api/new/notifications/telemetry',
      body: {'events': events.map((event) => event.toJson()).toList()},
      decoder: asJsonMap,
    );
  }

  Future<ApiResult<dynamic>> runAction(NotificationActionItem action) {
    if (action.endpoint.trim().isEmpty) {
      return Future.value(
        const ApiResult<dynamic>(
          ok: false,
          statusCode: 0,
          message: 'İşlem adresi eksik.',
          code: '',
          data: null,
          rawData: null,
        ),
      );
    }
    final method = action.method.toUpperCase();
    if (method == 'PUT') {
      return _apiClient.put<dynamic>(action.endpoint);
    }
    if (method == 'DELETE') {
      return _apiClient.delete<dynamic>(action.endpoint);
    }
    return _apiClient.post<dynamic>(action.endpoint);
  }

  Future<ApiResult<dynamic>> deleteNotification(int notificationId) {
    return _apiClient.delete<dynamic>('/api/new/notifications/$notificationId');
  }

  Future<ApiResult<dynamic>> deleteAllNotifications() {
    return _apiClient.delete<dynamic>('/api/new/notifications');
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

  bool _shouldFallback(int statusCode) =>
      statusCode == 404 || statusCode == 405 || statusCode == 501;
}

final notificationsRepositoryProvider = Provider<NotificationsRepository>(
  (ref) => NotificationsRepository(ref.watch(apiClientProvider)),
);

final notificationsProvider =
    FutureProvider.autoDispose<PagedResponse<AppNotification>>(
      (ref) => ref.watch(notificationsRepositoryProvider).fetchNotifications(),
    );

final notificationPreferencesProvider =
    FutureProvider.autoDispose<NotificationPreferences>(
      (ref) => ref.watch(notificationsRepositoryProvider).fetchPreferences(),
    );

final notificationUnreadCountProvider = FutureProvider.autoDispose<int>(
  (ref) => ref.watch(notificationsRepositoryProvider).fetchUnreadCount(),
);

final notificationDetailProvider = FutureProvider.autoDispose
    .family<AppNotification, int>(
      (ref, id) => ref
          .watch(notificationsRepositoryProvider)
          .fetchNotificationDetail(id),
    );
