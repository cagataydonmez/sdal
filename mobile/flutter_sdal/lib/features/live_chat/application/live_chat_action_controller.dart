import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/json_utils.dart';
import '../../../core/state/async_action_state.dart';
import '../data/live_chat_repository.dart';

class LiveChatActionController extends Notifier<AsyncActionState> {
  LiveChatRepository get _repository => ref.read(liveChatRepositoryProvider);

  @override
  AsyncActionState build() => const AsyncActionState.idle();

  Future<LiveChatMessage?> sendMessage(String message) async {
    state = const AsyncActionState.loading(scope: 'live-chat:send');
    final result = await _repository.sendMessage(message);
    if (result.ok) {
      state = const AsyncActionState.success(scope: 'live-chat:send');
      final item = asJsonMap(result.rawData)['item'];
      return asJsonMap(item).isEmpty
          ? null
          : LiveChatMessage.fromMap(asJsonMap(item));
    }
    state = AsyncActionState.error(
      scope: 'live-chat:send',
      message: result.message.isNotEmpty
          ? result.message
          : 'Mesaj gonderilemedi.',
    );
    return null;
  }

  Future<LiveChatMessage?> editMessage({
    required int messageId,
    required String message,
  }) async {
    state = AsyncActionState.loading(scope: 'live-chat:edit:$messageId');
    final result = await _repository.editMessage(
      messageId: messageId,
      message: message,
    );
    if (result.ok) {
      state = const AsyncActionState.success(scope: 'live-chat:edit');
      final item = asJsonMap(result.rawData)['item'];
      return asJsonMap(item).isEmpty
          ? null
          : LiveChatMessage.fromMap(asJsonMap(item));
    }
    state = AsyncActionState.error(
      scope: 'live-chat:edit:$messageId',
      message: result.message.isNotEmpty
          ? result.message
          : 'Mesaj guncellenemedi.',
    );
    return null;
  }

  Future<bool> deleteMessage(int messageId) async {
    state = AsyncActionState.loading(scope: 'live-chat:delete:$messageId');
    final result = await _repository.deleteMessage(messageId);
    if (result.ok) {
      state = const AsyncActionState.success(scope: 'live-chat:delete');
      return true;
    }
    state = AsyncActionState.error(
      scope: 'live-chat:delete:$messageId',
      message: result.message.isNotEmpty ? result.message : 'Mesaj silinemedi.',
    );
    return false;
  }
}

final liveChatActionControllerProvider =
    NotifierProvider.autoDispose<LiveChatActionController, AsyncActionState>(
      LiveChatActionController.new,
    );
