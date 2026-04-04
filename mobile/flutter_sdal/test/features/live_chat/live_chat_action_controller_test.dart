import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_sdal/core/network/api_result.dart';
import 'package:flutter_sdal/core/state/async_action_state.dart';
import 'package:flutter_sdal/features/live_chat/application/live_chat_action_controller.dart';
import 'package:flutter_sdal/features/live_chat/data/live_chat_repository.dart';
import '../../test_support/fake_api_client.dart';

void main() {
  test(
    'LiveChatActionController reports send success and returns item',
    () async {
      final container = ProviderContainer(
        overrides: [
          liveChatRepositoryProvider.overrideWithValue(
            _FakeLiveChatRepository(),
          ),
        ],
      );
      addTearDown(container.dispose);

      final item = await container
          .read(liveChatActionControllerProvider.notifier)
          .sendMessage('Selam');

      expect(item, isNotNull);
      expect(item!.id, 11);
      final state = container.read(liveChatActionControllerProvider);
      expect(state.status, AsyncActionStatus.success);
      expect(state.scope, 'live-chat:send');
    },
  );
}

class _FakeLiveChatRepository extends LiveChatRepository {
  _FakeLiveChatRepository() : super(FakeApiClient());

  @override
  Future<ApiResult<Map<String, dynamic>>> sendMessage(String message) async {
    return ApiResult<Map<String, dynamic>>(
      ok: true,
      statusCode: 200,
      message: 'ok',
      code: '',
      data: <String, dynamic>{
        'item': <String, dynamic>{
          'id': 11,
          'user_id': 4,
          'message': message,
          'created_at': '2026-04-04T10:00:00.000Z',
          'user': <String, dynamic>{
            'id': 4,
            'kadi': 'ada',
            'isim': 'Ada',
            'soyisim': 'Lovelace',
            'resim': '',
            'verified': 1,
          },
        },
      },
      rawData: <String, dynamic>{
        'item': <String, dynamic>{
          'id': 11,
          'user_id': 4,
          'message': message,
          'created_at': '2026-04-04T10:00:00.000Z',
          'user': <String, dynamic>{
            'id': 4,
            'kadi': 'ada',
            'isim': 'Ada',
            'soyisim': 'Lovelace',
            'resim': '',
            'verified': 1,
          },
        },
      },
    );
  }
}
