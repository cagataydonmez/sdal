import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/io.dart';
import '../../../app/providers.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_result.dart';
import '../../../core/network/json_utils.dart';
import '../../../core/network/realtime_connection_state.dart';

class LiveChatUser {
  const LiveChatUser({
    required this.id,
    required this.handle,
    required this.displayName,
    required this.photo,
    required this.verified,
  });

  final int id;
  final String handle;
  final String displayName;
  final String photo;
  final bool verified;

  factory LiveChatUser.fromMap(JsonMap map) {
    final firstName = coalesceText([map['isim']], fallback: '');
    final lastName = coalesceText([map['soyisim']], fallback: '');
    final fullName = '$firstName $lastName'.trim();
    final handle = coalesceText([map['kadi']], fallback: '');
    return LiveChatUser(
      id: asInt(map['id']) ?? 0,
      handle: handle,
      displayName: fullName.isNotEmpty
          ? fullName
          : handle.isNotEmpty
          ? '@$handle'
          : 'SDAL Üyesi',
      photo: coalesceText([map['resim']], fallback: ''),
      verified: asBool(map['verified']) ?? false,
    );
  }
}

class LiveChatMessage {
  const LiveChatMessage({
    required this.id,
    required this.userId,
    required this.message,
    required this.createdAt,
    required this.user,
  });

  final int id;
  final int userId;
  final String message;
  final String createdAt;
  final LiveChatUser? user;

  factory LiveChatMessage.fromMap(JsonMap map) {
    final userMap = asJsonMap(map['user']);
    return LiveChatMessage(
      id: asInt(map['id']) ?? 0,
      userId: asInt(map['user_id']) ?? asInt(map['userId']) ?? 0,
      message: coalesceText([map['message']], fallback: ''),
      createdAt: coalesceText([
        map['created_at'],
        map['createdAt'],
      ], fallback: ''),
      user: userMap.isEmpty
          ? LiveChatUser.fromMap(map)
          : LiveChatUser.fromMap(userMap),
    );
  }
}

class LiveChatEvent {
  const LiveChatEvent({required this.type, this.item, this.messageId});

  final String type;
  final LiveChatMessage? item;
  final int? messageId;

  factory LiveChatEvent.fromMap(JsonMap map) {
    final type = coalesceText([map['type']], fallback: '');
    return LiveChatEvent(
      type: type,
      item: type == 'chat:deleted' ? null : LiveChatMessage.fromMap(map),
      messageId: asInt(map['id']),
    );
  }
}

class LiveChatRepository {
  const LiveChatRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<List<LiveChatMessage>> fetchMessages({
    int? sinceId,
    int? beforeId,
    int limit = 50,
  }) async {
    final result = await _apiClient.get<JsonMap>(
      '/api/new/chat/messages',
      query: {
        'limit': limit,
        if (sinceId != null && sinceId > 0) 'sinceId': sinceId,
        if (beforeId != null && beforeId > 0) 'beforeId': beforeId,
      },
      decoder: asJsonMap,
    );
    return asJsonMapList(
      asJsonMap(result.rawData)['items'],
    ).map(LiveChatMessage.fromMap).toList(growable: false);
  }

  Future<ApiResult<JsonMap>> sendMessage(String message) {
    return _apiClient.post<JsonMap>(
      '/api/new/chat/send',
      body: {'message': message},
      decoder: asJsonMap,
    );
  }

  Future<ApiResult<JsonMap>> editMessage({
    required int messageId,
    required String message,
  }) {
    return _apiClient.post<JsonMap>(
      '/api/new/chat/messages/$messageId/edit',
      body: {'message': message},
      decoder: asJsonMap,
    );
  }

  Future<ApiResult<dynamic>> deleteMessage(int messageId) {
    return _apiClient.post<dynamic>('/api/new/chat/messages/$messageId/delete');
  }
}

class LiveChatRealtimeService {
  LiveChatRealtimeService(this._apiClient);

  final ApiClient _apiClient;
  final StreamController<LiveChatEvent> _eventsController =
      StreamController<LiveChatEvent>.broadcast();
  final StreamController<RealtimeConnectionState> _statesController =
      StreamController<RealtimeConnectionState>.broadcast();

  IOWebSocketChannel? _channel;
  Timer? _reconnectTimer;
  bool _connecting = false;
  bool _disposed = false;
  int _attempt = 0;

  Stream<LiveChatEvent> get events => _eventsController.stream;
  Stream<RealtimeConnectionState> get states => _statesController.stream;

  Future<void> start() async {
    if (_disposed || _connecting || _channel != null) return;
    await _connect();
  }

  Future<void> sendDraft(String message) async {
    final channel = _channel;
    if (channel == null || message.trim().isEmpty) return;
    channel.sink.add(jsonEncode({'message': message.trim()}));
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
      final uri = _apiClient.buildWebSocketUri('/ws/chat');
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
        onDone: _handleDisconnect,
        onError: (_) => _handleDisconnect(),
        cancelOnError: true,
      );
    } catch (_) {
      _connecting = false;
      _handleDisconnect();
    }
  }

  void _handleMessage(dynamic raw) {
    try {
      final event = LiveChatEvent.fromMap(asJsonMap(jsonDecode(raw as String)));
      if (event.type.isNotEmpty) {
        _eventsController.add(event);
      }
    } catch (_) {
      // Ignore malformed payloads.
    }
  }

  void _handleDisconnect() {
    _channel = null;
    if (_disposed) return;
    _attempt += 1;
    _statesController.add(
      RealtimeConnectionState(
        status: RealtimeConnectionStatus.disconnected,
        attempt: _attempt,
      ),
    );
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 3), _connect);
  }

  void dispose() {
    _disposed = true;
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _eventsController.close();
    _statesController.close();
  }
}

final liveChatRepositoryProvider = Provider<LiveChatRepository>(
  (ref) => LiveChatRepository(ref.watch(apiClientProvider)),
);

final liveChatRealtimeServiceProvider = Provider<LiveChatRealtimeService>((
  ref,
) {
  final service = LiveChatRealtimeService(ref.watch(apiClientProvider));
  ref.onDispose(service.dispose);
  return service;
});
