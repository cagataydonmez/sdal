import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/state/async_action_state.dart';
import '../data/feed_repository.dart';

class FeedActionController extends AutoDisposeNotifier<AsyncActionState> {
  FeedRepository get _repository => ref.read(feedRepositoryProvider);

  @override
  AsyncActionState build() => const AsyncActionState.idle();

  Future<bool> createPost({
    required String content,
    File? imageFile,
    String feedType = 'main',
  }) async {
    state = const AsyncActionState.loading(scope: 'createPost');
    final result = imageFile == null
        ? await _repository.createPost(content: content, feedType: feedType)
        : await _repository.createPostWithImage(
            content: content,
            feedType: feedType,
            imageFile: imageFile,
          );
    if (result.ok) {
      ref.invalidate(feedItemsProvider);
      state = AsyncActionState.success(
        scope: 'createPost',
        message: result.message.isNotEmpty
            ? result.message
            : 'Gönderi paylaşıldı.',
      );
      return true;
    }
    state = AsyncActionState.error(
      scope: 'createPost',
      message: result.message.isNotEmpty
          ? result.message
          : 'Gönderi paylaşılamadı.',
    );
    return false;
  }

  Future<bool> toggleLike(int postId) async {
    state = AsyncActionState.loading(scope: 'like:$postId');
    final result = await _repository.toggleLike(postId);
    if (result.ok) {
      ref.invalidate(feedItemsProvider);
      ref.invalidate(postDetailProvider(postId));
      state = const AsyncActionState.success(scope: 'like');
      return true;
    }
    state = AsyncActionState.error(
      scope: 'like:$postId',
      message: result.message,
    );
    return false;
  }

  Future<bool> createComment({
    required int postId,
    required String comment,
  }) async {
    state = AsyncActionState.loading(scope: 'comment:$postId');
    final result = await _repository.createComment(
      postId: postId,
      comment: comment,
    );
    if (result.ok) {
      ref.invalidate(postCommentsProvider(postId));
      ref.invalidate(postDetailProvider(postId));
      ref.invalidate(feedItemsProvider);
      state = const AsyncActionState.success(scope: 'comment');
      return true;
    }
    state = AsyncActionState.error(
      scope: 'comment:$postId',
      message: result.message,
    );
    return false;
  }

  void reset() {
    state = const AsyncActionState.idle();
  }
}

final feedActionControllerProvider =
    AutoDisposeNotifierProvider<FeedActionController, AsyncActionState>(
      FeedActionController.new,
    );
