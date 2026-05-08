import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/state/async_action_state.dart';
import '../data/messenger_repository.dart';

class MessengerActionController extends Notifier<AsyncActionState> {
  MessengerRepository get _repository => ref.read(messengerRepositoryProvider);

  @override
  AsyncActionState build() => const AsyncActionState.idle();

  Future<int?> createThread(int userId) async {
    state = const AsyncActionState.loading(scope: 'messenger:createThread');
    final threadId = await _repository.createThread(userId);
    if (threadId == null) {
      state = const AsyncActionState.error(
        scope: 'messenger:createThread',
        message: 'Yeni sohbet başlatılamadı.',
      );
      return null;
    }
    ref.invalidate(messengerThreadsProvider(''));
    state = const AsyncActionState.success(scope: 'messenger:createThread');
    return threadId;
  }

  Future<bool> sendMessage({
    required int threadId,
    required String text,
  }) async {
    state = AsyncActionState.loading(scope: 'messenger:send:$threadId');
    final result = await _repository.sendMessage(
      threadId: threadId,
      text: text,
    );
    if (result.ok) {
      ref.invalidate(messengerMessagesProvider(threadId));
      ref.invalidate(messengerThreadsProvider(''));
      state = const AsyncActionState.success(scope: 'messenger:send');
      return true;
    }
    state = AsyncActionState.error(
      scope: 'messenger:send:$threadId',
      message: result.message.isNotEmpty
          ? result.message
          : 'Mesaj gönderilemedi.',
    );
    return false;
  }

  Future<bool> sendPhotoMessage({
    required int threadId,
    required File photo,
  }) async {
    state = AsyncActionState.loading(scope: 'messenger:send:$threadId');
    final result = await _repository.sendPhotoMessage(
      threadId: threadId,
      photo: photo,
    );
    if (result.ok) {
      ref.invalidate(messengerMessagesProvider(threadId));
      ref.invalidate(messengerThreadsProvider(''));
      state = const AsyncActionState.success(scope: 'messenger:send');
      return true;
    }
    state = AsyncActionState.error(
      scope: 'messenger:send:$threadId',
      message: result.message.isNotEmpty
          ? result.message
          : 'Fotoğraf gönderilemedi.',
    );
    return false;
  }

  void reset() {
    state = const AsyncActionState.idle();
  }
}

final messengerActionControllerProvider =
    NotifierProvider.autoDispose<MessengerActionController, AsyncActionState>(
      MessengerActionController.new,
    );
