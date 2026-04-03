import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/io.dart';
import '../../../app/providers.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_result.dart';
import '../../../core/network/json_utils.dart';
import '../../../core/network/realtime_connection_state.dart';

class MessengerContact {
  const MessengerContact({
    required this.id,
    required this.name,
    required this.handle,
    required this.photo,
    required this.verified,
  });

  final int id;
  final String name;
  final String handle;
  final String photo;
  final bool verified;

  factory MessengerContact.fromMap(JsonMap map) {
    return MessengerContact(
      id: asInt(map['id']) ?? 0,
      name: coalesceText([map['isim'], map['kadi']], fallback: 'SDAL Üyesi'),
      handle: coalesceText([map['kadi']], fallback: ''),
      photo: coalesceText([map['resim']], fallback: ''),
      verified: asBool(map['verified']) ?? false,
    );
  }
}

class MessengerThreadSummary {
  const MessengerThreadSummary({
    required this.id,
    required this.peer,
    required this.unreadCount,
    this.lastMessage,
  });

  final int id;
  final MessengerContact peer;
  final int unreadCount;
  final MessengerMessage? lastMessage;

  factory MessengerThreadSummary.fromMap(JsonMap map) {
    return MessengerThreadSummary(
      id: asInt(map['id']) ?? 0,
      peer: MessengerContact.fromMap(asJsonMap(map['peer'])),
      unreadCount: asInt(map['unreadCount']) ?? 0,
      lastMessage: asJsonMap(map['lastMessage']).isEmpty
          ? null
          : MessengerMessage.fromMap(asJsonMap(map['lastMessage'])),
    );
  }
}

class MessengerMessage {
  const MessengerMessage({
    required this.id,
    required this.threadId,
    required this.senderId,
    required this.receiverId,
    required this.body,
    required this.createdAt,
    required this.clientWrittenAt,
    required this.serverReceivedAt,
    required this.deliveredAt,
    required this.readAt,
    required this.isMine,
    required this.senderName,
  });

  final int id;
  final int threadId;
  final int senderId;
  final int receiverId;
  final String body;
  final String createdAt;
  final String clientWrittenAt;
  final String serverReceivedAt;
  final String deliveredAt;
  final String readAt;
  final bool isMine;
  final String senderName;

  factory MessengerMessage.fromMap(JsonMap map) {
    return MessengerMessage(
      id: asInt(map['id']) ?? 0,
      threadId: asInt(map['threadId']) ?? 0,
      senderId: asInt(map['senderId']) ?? 0,
      receiverId: asInt(map['receiverId']) ?? 0,
      body: coalesceText([map['body']], fallback: ''),
      createdAt: coalesceText([
        map['createdAt'],
        map['created_at'],
      ], fallback: ''),
      clientWrittenAt: coalesceText([map['clientWrittenAt']], fallback: ''),
      serverReceivedAt: coalesceText([map['serverReceivedAt']], fallback: ''),
      deliveredAt: coalesceText([map['deliveredAt']], fallback: ''),
      readAt: coalesceText([map['readAt']], fallback: ''),
      isMine: asBool(map['isMine']) ?? false,
      senderName: coalesceText([
        map['isim'],
        map['kadi'],
      ], fallback: 'SDAL Üyesi'),
    );
  }
}

class MessengerRealtimeEvent {
  const MessengerRealtimeEvent({
    required this.type,
    required this.threadId,
    this.byUserId,
    this.item,
  });

  final String type;
  final int threadId;
  final int? byUserId;
  final MessengerMessage? item;

  factory MessengerRealtimeEvent.fromMap(JsonMap map) {
    return MessengerRealtimeEvent(
      type: coalesceText([map['type']], fallback: ''),
      threadId: asInt(map['threadId']) ?? 0,
      byUserId: asInt(map['byUserId']),
      item: asJsonMap(map['item']).isEmpty
          ? null
          : MessengerMessage.fromMap(asJsonMap(map['item'])),
    );
  }
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

  Future<List<MessengerMessage>> fetchMessages(int threadId) async {
    final result = await _apiClient.get<JsonMap>(
      '/api/sdal-messenger/threads/$threadId/messages',
      decoder: asJsonMap,
    );
    final items = asJsonMapList(asJsonMap(result.rawData)['items']);
    return items.map(MessengerMessage.fromMap).toList(growable: false);
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

  Future<int?> createThread(int userId) async {
    final result = await _apiClient.post<JsonMap>(
      '/api/sdal-messenger/threads',
      body: {'userId': userId},
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

  final ApiClient _apiClient;
  final StreamController<MessengerRealtimeEvent> _eventsController =
      StreamController<MessengerRealtimeEvent>.broadcast();
  final StreamController<RealtimeConnectionState> _statesController =
      StreamController<RealtimeConnectionState>.broadcast();

  IOWebSocketChannel? _channel;
  Timer? _reconnectTimer;
  bool _connecting = false;
  bool _disposed = false;
  int _attempt = 0;

  Stream<MessengerRealtimeEvent> get events => _eventsController.stream;
  Stream<RealtimeConnectionState> get states => _statesController.stream;

  Future<void> start() async {
    if (_disposed || _connecting || _channel != null) return;
    await _connect();
  }

  Future<void> _connect() async {
    if (_disposed) return;
    _connecting = true;
    _statesController.add(
      RealtimeConnectionState(
        status: _attempt == 0
            ? RealtimeConnectionStatus.connecting
            : RealtimeConnectionStatus.reconnecting,
        attempt: _attempt,
      ),
    );

    try {
      final uri = _apiClient.buildWebSocketUri('/ws/messenger');
      final cookieHeader = await _apiClient.cookieHeaderForUri(uri);
      final channel = IOWebSocketChannel.connect(
        uri,
        headers: cookieHeader == null ? null : {'Cookie': cookieHeader},
        pingInterval: const Duration(seconds: 25),
        connectTimeout: const Duration(seconds: 10),
      );
      _channel = channel;
      _connecting = false;
      _attempt = 0;
      _statesController.add(
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
    final delay = Duration(seconds: _attempt > 5 ? 5 : _attempt);
    _statesController.add(
      RealtimeConnectionState(
        status: RealtimeConnectionStatus.reconnecting,
        message: error?.toString(),
        attempt: _attempt,
      ),
    );

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, () {
      if (_disposed) return;
      _connect();
    });
  }

  Future<void> dispose() async {
    _disposed = true;
    _reconnectTimer?.cancel();
    await _channel?.sink.close();
    _channel = null;
    await _eventsController.close();
    await _statesController.close();
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

final messengerMessagesProvider = FutureProvider.autoDispose
    .family<List<MessengerMessage>, int>(
      (ref, threadId) =>
          ref.watch(messengerRepositoryProvider).fetchMessages(threadId),
    );

final messengerContactsProvider = FutureProvider.autoDispose
    .family<List<MessengerContact>, String>(
      (ref, query) =>
          ref.watch(messengerRepositoryProvider).searchContacts(query),
    );
