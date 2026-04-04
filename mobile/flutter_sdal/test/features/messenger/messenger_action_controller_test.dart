import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_sdal/core/network/api_result.dart';
import 'package:flutter_sdal/core/network/json_utils.dart';
import 'package:flutter_sdal/core/state/async_action_state.dart';
import 'package:flutter_sdal/features/messenger/application/messenger_action_controller.dart';
import 'package:flutter_sdal/features/messenger/data/messenger_repository.dart';
import '../../test_support/fake_api_client.dart';

void main() {
  test(
    'MessengerActionController returns thread id on create success',
    () async {
      final container = ProviderContainer(
        overrides: [
          messengerRepositoryProvider.overrideWithValue(
            _FakeMessengerRepository(threadId: 42),
          ),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(
        messengerActionControllerProvider.notifier,
      );
      final threadId = await notifier.createThread(9);

      expect(threadId, 42);
      final state = container.read(messengerActionControllerProvider);
      expect(state.status, AsyncActionStatus.success);
      expect(state.scope, 'messenger:createThread');
    },
  );

  test('MessengerActionController reports send failure', () async {
    final container = ProviderContainer(
      overrides: [
        messengerRepositoryProvider.overrideWithValue(
          _FakeMessengerRepository(sendOk: false),
        ),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(messengerActionControllerProvider.notifier);
    final ok = await notifier.sendMessage(threadId: 13, text: 'test');

    expect(ok, isFalse);
    final state = container.read(messengerActionControllerProvider);
    expect(state.status, AsyncActionStatus.error);
    expect(state.scope, 'messenger:send:13');
    expect(state.message, 'send fail');
  });
}

class _FakeMessengerRepository extends MessengerRepository {
  _FakeMessengerRepository({this.threadId, this.sendOk = true})
    : super(FakeApiClient());

  final int? threadId;
  final bool sendOk;

  @override
  Future<int?> createThread(int userId) async => threadId;

  @override
  Future<ApiResult<JsonMap>> sendMessage({
    required int threadId,
    required String text,
  }) async {
    return ApiResult<JsonMap>(
      ok: sendOk,
      statusCode: sendOk ? 200 : 400,
      message: sendOk ? '' : 'send fail',
      code: '',
      data: const <String, dynamic>{},
      rawData: const <String, dynamic>{},
    );
  }
}
