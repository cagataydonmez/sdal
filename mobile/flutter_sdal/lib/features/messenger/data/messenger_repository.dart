import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:web_socket_channel/io.dart';
import '../../../app/providers.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_result.dart';
import '../../../core/network/json_utils.dart';
import '../../../core/network/paged_response.dart';
import '../../../core/network/realtime_connection_state.dart';

part 'messenger_repository.freezed.dart';
part 'messenger_repository.g.dart';

@freezed
class MessengerContact with _$MessengerContact {
  const MessengerContact._();

  const factory MessengerContact({
    @JsonKey(fromJson: readRequiredInt) required int id,
    @JsonKey(fromJson: readRequiredText) required String name,
    @JsonKey(fromJson: readRequiredText) required String handle,
    @JsonKey(fromJson: readRequiredText) required String photo,
    @JsonKey(fromJson: readRequiredBool) required bool verified,
  }) = _MessengerContact;

  factory MessengerContact.fromJson(Map<String, dynamic> json) =>
      _$MessengerContactFromJson(
        normalizeJsonAliases(json, {
          'name': ['isim', 'kadi'],
          'handle': ['kadi'],
          'photo': ['resim'],
        }),
      );

  factory MessengerContact.fromMap(JsonMap map) =>
      MessengerContact.fromJson(map);
}

@freezed
class MessengerMessage with _$MessengerMessage {
  const MessengerMessage._();

  const factory MessengerMessage({
    @JsonKey(fromJson: readRequiredInt) required int id,
    @JsonKey(fromJson: readRequiredInt) required int threadId,
    @JsonKey(fromJson: readRequiredInt) required int senderId,
    @JsonKey(fromJson: readRequiredInt) required int receiverId,
    @JsonKey(fromJson: readRequiredText) required String body,
    @JsonKey(fromJson: readRequiredText) required String createdAt,
    @JsonKey(fromJson: readRequiredText) required String clientWrittenAt,
    @JsonKey(fromJson: readRequiredText) required String serverReceivedAt,
    @JsonKey(fromJson: readRequiredText) required String deliveredAt,
    @JsonKey(fromJson: readRequiredText) required String readAt,
    @JsonKey(fromJson: readRequiredBool) required bool isMine,
    @JsonKey(fromJson: readRequiredText) required String senderName,
  }) = _MessengerMessage;

  factory MessengerMessage.fromJson(Map<String, dynamic> json) =>
      _$MessengerMessageFromJson(
        normalizeJsonAliases(json, {
          'createdAt': ['created_at'],
          'senderName': ['isim', 'kadi'],
        }),
      );

  factory MessengerMessage.fromMap(JsonMap map) =>
      MessengerMessage.fromJson(map);
}

@freezed
class MessengerThreadSummary with _$MessengerThreadSummary {
  const factory MessengerThreadSummary({
    @JsonKey(fromJson: readRequiredInt) required int id,
    required MessengerContact peer,
    @JsonKey(fromJson: readRequiredInt) required int unreadCount,
    MessengerMessage? lastMessage,
  }) = _MessengerThreadSummary;

  factory MessengerThreadSummary.fromJson(Map<String, dynamic> json) =>
      _$MessengerThreadSummaryFromJson(json);

  factory MessengerThreadSummary.fromMap(JsonMap map) =>
      MessengerThreadSummary.fromJson(map);
}

@freezed
class MessengerRealtimeEvent with _$MessengerRealtimeEvent {
  const factory MessengerRealtimeEvent({
    @JsonKey(fromJson: readRequiredText) required String type,
    @JsonKey(fromJson: readRequiredInt) required int threadId,
    @JsonKey(fromJson: readOptionalInt) int? byUserId,
    MessengerMessage? item,
  }) = _MessengerRealtimeEvent;

  factory MessengerRealtimeEvent.fromJson(Map<String, dynamic> json) =>
      _$MessengerRealtimeEventFromJson(json);

  factory MessengerRealtimeEvent.fromMap(JsonMap map) =>
      MessengerRealtimeEvent.fromJson(map);
}

class MessengerRepository {
  const MessengerRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<List<MessengerThreadSummary>> fetchThreads({String query = ''}) async {
    final result = await _apiClient.get<JsonMap>(
      '/api/sdal-messenger/threads',
      query: {'limit': 40, if (query.trim().isNotEmpty) 'q': query.trim()},
      decoder: asJsonMap,
    );
    final items = asJsonMapList(asJsonMap(result.rawData)['items']);
    return items.map(MessengerThreadSummary.fromMap).toList(growable: false);
  }

  Future<PagedResponse<MessengerMessage>> fetchMessages(
    int threadId, {
    int? beforeId,
    int limit = 60,
  }) async {
    final safeLimit = limit.clamp(1, 120);
    final result = await _apiClient.get<JsonMap>(
      '/api/sdal-messenger/threads/$threadId/messages',
      query: {
        'limit': safeLimit,
        if ((beforeId ?? 0) > 0) 'before': beforeId,
        if ((beforeId ?? 0) > 0) 'beforeId': beforeId,
      },
      decoder: asJsonMap,
    );
    final page = PagedResponse<MessengerMessage>.fromDynamic({
      ...asJsonMap(result.rawData),
      'hasMore':
          asJsonMapList(asJsonMap(result.rawData)['items']).length == safeLimit,
      'limit': safeLimit,
    }, MessengerMessage.fromMap);
    return page;
  }

  Future<List<MessengerContact>> searchContacts(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const <MessengerContact>[];
    final result = await _apiClient.get<JsonMap>(
      '/api/sdal-messenger/contacts',
      query: {'q': trimmed, 'limit': 20},
      decoder: asJsonMap,
    );
    final items = asJsonMapList(asJsonMap(result.rawData)['items']);
    return items.map(MessengerContact.fromMap).toList(growable: false);
  }

  Future<int?> createThread(int userId) {
    return createThreadWithRecipients(<int>[userId]);
  }

  Future<int?> createThreadWithRecipients(List<int> recipientIds) async {
    final normalizedRecipientIds = recipientIds
        .where((value) => value > 0)
        .toSet()
        .toList(growable: false);
    if (normalizedRecipientIds.isEmpty) return null;
    final result = await _apiClient.post<JsonMap>(
      '/api/sdal-messenger/threads',
      body: {
        'recipientIds': normalizedRecipientIds,
        if (normalizedRecipientIds.length == 1)
          'userId': normalizedRecipientIds.first,
      },
      decoder: asJsonMap,
    );
    if (!result.ok) return null;
    return asInt(asJsonMap(result.rawData)['threadId']);
  }

  Future<ApiResult<JsonMap>> sendMessage({
    required int threadId,
    required String text,
  }) {
    return _apiClient.post<JsonMap>(
      '/api/sdal-messenger/threads/$threadId/messages',
      body: {
        'text': text,
        'clientWrittenAt': DateTime.now().toUtc().toIso8601String(),
      },
      decoder: asJsonMap,
    );
  }

  Future<ApiResult<dynamic>> markThreadRead(int threadId) {
    return _apiClient.post<dynamic>(
      '/api/sdal-messenger/threads/$threadId/read',
    );
  }
}

class MessengerRealtimeService {
  MessengerRealtimeService(this._apiClient);

  static const _rejectedUpgradeDelay = Duration(seconds: 30);

  final ApiClient _apiClient;
  final StreamController<MessengerRealtimeEvent> _eventsController =
      StreamController<MessengerRealtimeEvent>.broadcast();
  final StreamController<RealtimeConnectionState> _statesController =
      StreamController<RealtimeConnectionState>.broadcast();

  IOWebSocketChannel? _channel;
  Timer? _reconnectTimer;
  Timer? _reconnectIndicatorTimer;
  bool _connecting = false;
  bool _disposed = false;
  int _attempt = 0;
  RealtimeConnectionState _currentState =
      const RealtimeConnectionState.disconnected();

  Stream<MessengerRealtimeEvent> get events => _eventsController.stream;
  Stream<RealtimeConnectionState> get states => _statesController.stream;
  RealtimeConnectionState get currentState => _currentState;

  Future<void> start() async {
    if (_disposed || _connecting || _channel != null) return;
    _emitState(
      const RealtimeConnectionState(
        status: RealtimeConnectionStatus.connecting,
      ),
    );
    await _connect();
  }

  Future<void> stop() async {
    _reconnectTimer?.cancel();
    _reconnectIndicatorTimer?.cancel();
    _reconnectTimer = null;
    _reconnectIndicatorTimer = null;
    _attempt = 0;
    _connecting = false;
    await _channel?.sink.close();
    _channel = null;
    _emitState(
      const RealtimeConnectionState(
        status: RealtimeConnectionStatus.disconnected,
      ),
    );
  }

  Future<void> _connect() async {
    if (_disposed) return;
    _connecting = true;

    try {
      final uri = _apiClient.buildWebSocketUri('/ws/messenger');
      if (kDebugMode) {
        debugPrint(
          '[messenger-ws] connecting uri=$uri apiBase=${_apiClient.config.apiBaseUrl} siteBase=${_apiClient.config.siteBaseUrl}',
        );
      }
      final cookieHeader = await _apiClient.cookieHeaderForUri(uri);
      final channel = IOWebSocketChannel.connect(
        uri,
        headers: cookieHeader == null ? null : {'Cookie': cookieHeader},
        pingInterval: const Duration(seconds: 25),
        connectTimeout: const Duration(seconds: 10),
      );
      await channel.ready;
      _channel = channel;
      _connecting = false;
      _attempt = 0;
      _reconnectIndicatorTimer?.cancel();
      _emitState(
        const RealtimeConnectionState(
          status: RealtimeConnectionStatus.connected,
        ),
      );

      channel.stream.listen(
        _handleMessage,
        onDone: _scheduleReconnect,
        onError: (Object error, StackTrace stackTrace) =>
            _scheduleReconnect(error),
        cancelOnError: true,
      );
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[messenger-ws] connect failed: $error');
      }
      _connecting = false;
      _scheduleReconnect(error);
    }
  }

  void _handleMessage(dynamic payload) {
    final decoded = _decodePayload(payload);
    if (decoded.isEmpty) return;
    final type = coalesceText([decoded['type']], fallback: '');
    if (type.isEmpty || type == 'messenger:hello') return;
    _eventsController.add(MessengerRealtimeEvent.fromMap(decoded));
  }

  JsonMap _decodePayload(dynamic payload) {
    if (payload is Map<String, dynamic>) return payload;
    if (payload is String) {
      try {
        final decoded = jsonDecode(payload);
        return asJsonMap(decoded);
      } catch (_) {
        return const <String, dynamic>{};
      }
    }
    return const <String, dynamic>{};
  }

  void _scheduleReconnect([Object? error]) {
    _channel = null;
    _connecting = false;
    if (_disposed) return;

    _attempt += 1;
    final delay = _resolveReconnectDelay(error);
    final nextState = RealtimeConnectionState(
      status: _attempt >= 3
          ? RealtimeConnectionStatus.failed
          : RealtimeConnectionStatus.reconnecting,
      message: error?.toString(),
      attempt: _attempt,
    );

    _reconnectIndicatorTimer?.cancel();
    if (_currentState.status == RealtimeConnectionStatus.connected) {
      _reconnectIndicatorTimer = Timer(const Duration(seconds: 2), () {
        if (_disposed || _channel != null || _connecting) return;
        _emitState(nextState);
      });
    } else {
      _emitState(nextState);
    }

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, () {
      if (_disposed) return;
      _connect();
    });
  }

  Duration _resolveReconnectDelay(Object? error) {
    final message = error?.toString() ?? '';
    if (message.contains('HTTP status code: 400') &&
        message.contains('was not upgraded to websocket')) {
      return _rejectedUpgradeDelay;
    }
    return Duration(seconds: _attempt > 5 ? 5 : _attempt);
  }

  Future<void> dispose() async {
    _disposed = true;
    await stop();
    await _eventsController.close();
    await _statesController.close();
  }

  void _emitState(RealtimeConnectionState nextState) {
    if (_currentState.status == nextState.status &&
        _currentState.message == nextState.message &&
        _currentState.attempt == nextState.attempt) {
      return;
    }
    _currentState = nextState;
    _statesController.add(nextState);
  }
}

final messengerRepositoryProvider = Provider<MessengerRepository>(
  (ref) => MessengerRepository(ref.watch(apiClientProvider)),
);

final messengerRealtimeServiceProvider = Provider<MessengerRealtimeService>((
  ref,
) {
  final service = MessengerRealtimeService(ref.watch(apiClientProvider));
  ref.onDispose(() {
    service.dispose();
  });
  return service;
});

final messengerThreadsProvider = FutureProvider.autoDispose
    .family<List<MessengerThreadSummary>, String>(
      (ref, query) =>
          ref.watch(messengerRepositoryProvider).fetchThreads(query: query),
    );

final activeMessengerThreadIdProvider = StateProvider<int?>((ref) => null);

final messengerUnreadCountProvider = FutureProvider.autoDispose<int>((
  ref,
) async {
  final activeThreadId = ref.watch(activeMessengerThreadIdProvider);
  final threads = await ref.watch(messengerThreadsProvider('').future);
  return threads.fold<int>(
    0,
    (sum, thread) =>
        sum + (thread.id == activeThreadId ? 0 : thread.unreadCount),
  );
});

final messengerMessagesProvider = FutureProvider.autoDispose
    .family<PagedResponse<MessengerMessage>, int>(
      (ref, threadId) =>
          ref.watch(messengerRepositoryProvider).fetchMessages(threadId),
    );

final messengerContactsProvider = FutureProvider.autoDispose
    .family<List<MessengerContact>, String>(
      (ref, query) =>
          ref.watch(messengerRepositoryProvider).searchContacts(query),
    );
