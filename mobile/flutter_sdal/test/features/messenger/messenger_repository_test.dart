import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_sdal/core/network/api_result.dart';
import 'package:flutter_sdal/core/network/api_result_parser.dart';
import 'package:flutter_sdal/features/messenger/data/messenger_repository.dart';

import '../../test_support/fake_api_client.dart';

void main() {
  group('MessengerRepository contracts', () {
    test('createThread sends recipientIds plus legacy userId alias', () async {
      final apiClient = _RecordingMessengerApiClient(
        postRawData: const {'threadId': 42},
      );
      final repository = MessengerRepository(apiClient);

      final threadId = await repository.createThread(9);

      expect(threadId, 42);
      expect(apiClient.lastMethod, 'POST');
      expect(apiClient.lastPath, '/api/sdal-messenger/threads');
      expect(apiClient.lastBody, {
        'recipientIds': [9],
        'userId': 9,
      });
    });

    test(
      'fetchMessages sends before and beforeId aliases for pagination',
      () async {
        final apiClient = _RecordingMessengerApiClient(
          getRawData: {
            'items': [
              {
                'id': 101,
                'threadId': 7,
                'senderId': 9,
                'receiverId': 3,
                'body': 'hello',
                'createdAt': '2026-01-01T12:00:00.000Z',
                'clientWrittenAt': '2026-01-01T12:00:00.000Z',
                'serverReceivedAt': '2026-01-01T12:00:01.000Z',
                'deliveredAt': '2026-01-01T12:00:02.000Z',
                'readAt': '2026-01-01T12:00:03.000Z',
                'isMine': true,
                'senderName': 'Test User',
              },
            ],
          },
        );
        final repository = MessengerRepository(apiClient);

        final page = await repository.fetchMessages(
          7,
          beforeId: 101,
          limit: 30,
        );

        expect(apiClient.lastMethod, 'GET');
        expect(apiClient.lastPath, '/api/sdal-messenger/threads/7/messages');
        expect(apiClient.lastQuery, {
          'limit': 30,
          'before': 101,
          'beforeId': 101,
        });
        expect(page.items, hasLength(1));
        expect(page.hasMore, isFalse);
      },
    );
  });
}

class _RecordingMessengerApiClient extends FakeApiClient {
  _RecordingMessengerApiClient({
    this.getRawData = const <String, Object?>{'items': <Object?>[]},
    this.postRawData = const <String, Object?>{'threadId': 0},
  });

  final dynamic getRawData;
  final dynamic postRawData;

  String? lastMethod;
  String? lastPath;
  Map<String, dynamic>? lastQuery;
  Object? lastBody;

  @override
  Future<ApiResult<T>> get<T>(
    String path, {
    Map<String, dynamic>? query,
    ApiDecoder<T>? decoder,
  }) async {
    lastMethod = 'GET';
    lastPath = path;
    lastQuery = query == null ? null : Map<String, dynamic>.from(query);
    return ApiResult<T>(
      ok: true,
      statusCode: 200,
      message: '',
      code: '',
      data: decoder == null ? null : decoder(getRawData),
      rawData: getRawData,
    );
  }

  @override
  Future<ApiResult<T>> post<T>(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    ApiDecoder<T>? decoder,
  }) async {
    lastMethod = 'POST';
    lastPath = path;
    lastQuery = query == null ? null : Map<String, dynamic>.from(query);
    lastBody = body;
    return ApiResult<T>(
      ok: true,
      statusCode: 200,
      message: '',
      code: '',
      data: decoder == null ? null : decoder(postRawData),
      rawData: postRawData,
    );
  }
}
