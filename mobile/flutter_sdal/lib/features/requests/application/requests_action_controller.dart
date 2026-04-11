import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/json_utils.dart';
import '../../../core/state/async_action_state.dart';
import '../data/requests_repository.dart';

class RequestsActionController extends Notifier<AsyncActionState> {
  RequestsRepository get _repository => ref.read(requestsRepositoryProvider);

  @override
  AsyncActionState build() => const AsyncActionState.idle();

  Future<RequestAttachment?> uploadAttachment(File file) async {
    state = const AsyncActionState.loading(scope: 'requests:upload');
    final result = await _repository.uploadAttachment(file);
    final attachment = result.data;
    if (result.ok && attachment != null) {
      state = AsyncActionState.success(
        scope: 'requests:upload',
        message: result.message.isNotEmpty
            ? result.message
            : 'Ek dosya yüklendi.',
      );
      return attachment;
    }
    state = AsyncActionState.error(
      scope: 'requests:upload',
      message: result.message.isNotEmpty
          ? result.message
          : 'Ek dosya yüklenemedi.',
    );
    return null;
  }

  Future<bool> createRequest({
    required String categoryKey,
    required JsonMap payload,
  }) async {
    state = const AsyncActionState.loading(scope: 'requests:create');
    final result = await _repository.createRequest(
      categoryKey: categoryKey,
      payload: payload,
    );
    if (result.ok) {
      ref.invalidate(myRequestsProvider);
      state = AsyncActionState.success(
        scope: 'requests:create',
        message: result.message.isNotEmpty
            ? result.message
            : 'Talep gönderildi.',
      );
      return true;
    }
    state = AsyncActionState.error(
      scope: 'requests:create',
      message: result.message.isNotEmpty
          ? result.message
          : 'Talep gönderilemedi.',
    );
    return false;
  }

  void reset() {
    state = const AsyncActionState.idle();
  }
}

final requestsActionControllerProvider =
    NotifierProvider.autoDispose<RequestsActionController, AsyncActionState>(
      RequestsActionController.new,
    );
