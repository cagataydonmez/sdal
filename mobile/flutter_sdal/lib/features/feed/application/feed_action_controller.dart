import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_result.dart';
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

  Future<bool> toggleLike(FeedItem item) async {
    state = AsyncActionState.loading(scope: 'like:${item.id}');
    final result = await _repository.toggleReaction(item);
    if (result.ok) {
      ref.invalidate(feedItemsProvider);
      ref.invalidate(feedPageProvider);
      ref.invalidate(postDetailProvider(item.id));
      ref.invalidate(postLikesProvider(item.id));
      state = const AsyncActionState.success(scope: 'like');
      return true;
    }
    state = AsyncActionState.error(
      scope: 'like:${item.id}',
      message: result.message,
    );
    return false;
  }

  Future<bool> toggleLikeForPost(int postId) async {
    state = AsyncActionState.loading(scope: 'like:$postId');
    final result = await _repository.togglePostLike(postId);
    if (result.ok) {
      ref.invalidate(feedItemsProvider);
      ref.invalidate(feedPageProvider);
      ref.invalidate(postDetailProvider(postId));
      ref.invalidate(postLikesProvider(postId));
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
      // Feed list is updated directly in the UI; only invalidate detail page.
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
    File? imageFile,
    bool removeImage = false,
  }) async {
    state = AsyncActionState.loading(scope: 'edit-post:$postId');
    late ApiResult<dynamic> result;
    try {
      if (imageFile != null) {
        result = await _repository.editPostWithImage(
          postId: postId,
          content: content,
          imageFile: imageFile,
        );
      } else if (removeImage) {
        result = await _repository.deletePostImage(
          postId: postId,
          content: content,
        );
      } else {
        result = await _repository.editPost(postId: postId, content: content);
      }
    } catch (e) {
      result = ApiResult<dynamic>(
        ok: false,
        statusCode: 500,
        message: 'Beklenmedik bir hata oluştu: $e',
        code: 'error',
        data: null,
        rawData: null,
      );
    }

    if (result.ok) {
      // Feed list is updated directly in the UI; only invalidate detail page.
      ref.invalidate(postDetailProvider(postId));
      state = const AsyncActionState.success(scope: 'edit-post');
      return true;
    }
    state = AsyncActionState.error(
      scope: 'edit-post:$postId',
      message: result.message ?? 'Gönderi düzenlenemedi.',
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
      ref.invalidate(postCommentsProvider(postId));
      ref.invalidate(postDetailProvider(postId));
      ref.invalidate(feedItemsProvider);
      ref.invalidate(feedPageProvider);
      state = const AsyncActionState.success(scope: 'edit-comment');
      return true;
    }
    state = AsyncActionState.error(
      scope: 'edit-comment:$commentId',
      message: result.message.isNotEmpty ? result.message : 'Yorum düzenlenemedi.',
    );
    return false;
  }

  Future<bool> editEvent({
    required int eventId,
    required String title,
    required String description,
    required String location,
    required String startsAt,
    required String endsAt,
    File? imageFile,
  }) async {
    state = AsyncActionState.loading(scope: 'edit-event:$eventId');
    final result = await _repository.editEvent(
      eventId: eventId,
      title: title,
      description: description,
      location: location,
      startsAt: startsAt,
      endsAt: endsAt,
      imageFile: imageFile,
    );
    if (result.ok) {
      ref.invalidate(feedPageProvider);
      state = const AsyncActionState.success(scope: 'edit-event');
      return true;
    }
    state = AsyncActionState.error(
      scope: 'edit-event:$eventId',
      message: result.message ?? 'Etkinlik düzenlenemedi.',
    );
    return false;
  }

  Future<bool> deleteEvent(int eventId) async {
    state = AsyncActionState.loading(scope: 'delete-event:$eventId');
    final result = await _repository.deleteEvent(eventId);
    if (result.ok) {
      ref.invalidate(feedPageProvider);
      state = const AsyncActionState.success(scope: 'delete-event');
      return true;
    }
    state = AsyncActionState.error(
      scope: 'delete-event:$eventId',
      message: result.message ?? 'Etkinlik silinemedi.',
    );
    return false;
  }

  Future<bool> editAnnouncement({
    required int announcementId,
    required String title,
    required String body,
    File? imageFile,
    bool? approved,
  }) async {
    state = AsyncActionState.loading(scope: 'edit-announcement:$announcementId');
    final result = await _repository.editAnnouncement(
      announcementId: announcementId,
      title: title,
      body: body,
      imageFile: imageFile,
      approved: approved,
    );
    if (result.ok) {
      ref.invalidate(feedPageProvider);
      state = const AsyncActionState.success(scope: 'edit-announcement');
      return true;
    }
    state = AsyncActionState.error(
      scope: 'edit-announcement:$announcementId',
      message: result.message ?? 'Duyuru düzenlenemedi.',
    );
    return false;
  }

  Future<bool> deleteAnnouncement(int announcementId) async {
    state = AsyncActionState.loading(scope: 'delete-announcement:$announcementId');
    final result = await _repository.deleteAnnouncement(announcementId);
    if (result.ok) {
      ref.invalidate(feedPageProvider);
      state = const AsyncActionState.success(scope: 'delete-announcement');
      return true;
    }
    state = AsyncActionState.error(
      scope: 'delete-announcement:$announcementId',
      message: result.message ?? 'Duyuru silinemedi.',
    );
    return false;
  }

  Future<bool> editJob({
    required int jobId,
    required String title,
    required String company,
    required String description,
    required String location,
    required String jobType,
    required String workMode,
    required String link,
    File? imageFile,
    bool? showInFeed,
  }) async {
    state = AsyncActionState.loading(scope: 'edit-job:$jobId');
    final result = await _repository.editJob(
      jobId: jobId,
      title: title,
      company: company,
      description: description,
      location: location,
      jobType: jobType,
      workMode: workMode,
      link: link,
      imageFile: imageFile,
      showInFeed: showInFeed,
    );
    if (result.ok) {
      ref.invalidate(feedPageProvider);
      state = const AsyncActionState.success(scope: 'edit-job');
      return true;
    }
    state = AsyncActionState.error(
      scope: 'edit-job:$jobId',
      message: result.message ?? 'İş ilanı düzenlenemedi.',
    );
    return false;
  }

  Future<bool> deleteJob(int jobId) async {
    state = AsyncActionState.loading(scope: 'delete-job:$jobId');
    final result = await _repository.deleteJob(jobId);
    if (result.ok) {
      ref.invalidate(feedPageProvider);
      state = const AsyncActionState.success(scope: 'delete-job');
      return true;
    }
    state = AsyncActionState.error(
      scope: 'delete-job:$jobId',
      message: result.message ?? 'İş ilanı silinemedi.',
    );
    return false;
  }

  void reset() {
    state = const AsyncActionState.idle();
  }
}

final feedActionControllerProvider =
    NotifierProvider<FeedActionController, AsyncActionState>(
      FeedActionController.new,
    );
