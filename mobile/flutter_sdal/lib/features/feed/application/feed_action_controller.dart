import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/state/async_action_state.dart';
import '../data/feed_repository.dart';

class FeedActionController extends Notifier<AsyncActionState> {
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
      ref.invalidate(feedPageProvider);
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
    final result = await _repository.toggleReaction(postId);
    if (result.ok) {
      ref.invalidate(feedItemsProvider);
      ref.invalidate(feedPageProvider);
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

  Future<bool> deletePost(int postId) async {
    state = AsyncActionState.loading(scope: 'delete:$postId');
    final result = await _repository.deletePost(postId);
    if (result.ok) {
      ref.invalidate(feedItemsProvider);
      ref.invalidate(feedPageProvider);
      ref.invalidate(postDetailProvider(postId));
      state = const AsyncActionState.success(scope: 'delete');
      return true;
    }
    state = AsyncActionState.error(
      scope: 'delete:$postId',
      message: result.message.isNotEmpty
          ? result.message
          : 'Gönderi silinemedi.',
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
      ref.invalidate(feedPageProvider);
      state = const AsyncActionState.success(scope: 'comment');
      return true;
    }
    state = AsyncActionState.error(
      scope: 'comment:$postId',
      message: result.message,
    );
    return false;
  }

  Future<bool> deleteComment({
    required int postId,
    required int commentId,
  }) async {
    state = AsyncActionState.loading(scope: 'comment-delete:$commentId');
    final result = await _repository.deleteComment(
      postId: postId,
      commentId: commentId,
    );
    if (result.ok) {
      ref.invalidate(postCommentsProvider(postId));
      ref.invalidate(postDetailProvider(postId));
      ref.invalidate(feedItemsProvider);
      ref.invalidate(feedPageProvider);
      state = const AsyncActionState.success(scope: 'comment-delete');
      return true;
    }
    state = AsyncActionState.error(
      scope: 'comment-delete:$commentId',
      message: result.message.isNotEmpty ? result.message : 'Yorum silinemedi.',
    );
    return false;
  }

  Future<bool> editPost({
    required int postId,
    required String content,
  }) async {
    state = AsyncActionState.loading(scope: 'edit-post:$postId');
    final result = await _repository.editPost(postId: postId, content: content);
    if (result.ok) {
      state = const AsyncActionState.success(scope: 'edit-post');
      return true;
    }
    state = AsyncActionState.error(
      scope: 'edit-post:$postId',
      message: result.message.isNotEmpty ? result.message : 'Gönderi düzenlenemedi.',
    );
    return false;
  }

  Future<bool> editComment({
    required int postId,
    required int commentId,
    required String comment,
  }) async {
    state = AsyncActionState.loading(scope: 'edit-comment:$commentId');
    final result = await _repository.editComment(
      postId: postId,
      commentId: commentId,
      comment: comment,
    );
    if (result.ok) {
      state = const AsyncActionState.success(scope: 'edit-comment');
      return true;
    }
    state = AsyncActionState.error(
      scope: 'edit-comment:$commentId',
      message: result.message.isNotEmpty ? result.message : 'Yorum düzenlenemedi.',
    );
    return false;
  }

  void reset() {
    state = const AsyncActionState.idle();
  }
}

final feedActionControllerProvider =
    NotifierProvider.autoDispose<FeedActionController, AsyncActionState>(
      FeedActionController.new,
    );
