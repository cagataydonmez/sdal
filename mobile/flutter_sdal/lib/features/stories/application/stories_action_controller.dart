import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/state/async_action_state.dart';
import '../data/stories_repository.dart';

class StoriesActionController extends AutoDisposeNotifier<AsyncActionState> {
  StoriesRepository get _repository => ref.read(storiesRepositoryProvider);

  @override
  AsyncActionState build() => const AsyncActionState.idle();

  Future<StoryMutationResult?> uploadStory({
    required File imageFile,
    required String caption,
    String feedType = 'main',
  }) async {
    state = const AsyncActionState.loading(scope: 'stories:upload');
    final result = await _repository.uploadStory(
      imageFile: imageFile,
      caption: caption,
      feedType: feedType,
    );
    if (result.ok) {
      state = const AsyncActionState.success(scope: 'stories:upload');
      return result.data;
    }
    state = AsyncActionState.error(
      scope: 'stories:upload',
      message: result.message.isNotEmpty
          ? result.message
          : 'Hikaye yüklenemedi.',
    );
    return null;
  }

  Future<StoryMutationResult?> editStory({
    required int storyId,
    required String caption,
  }) async {
    state = AsyncActionState.loading(scope: 'stories:edit:$storyId');
    final result = await _repository.editStory(
      storyId: storyId,
      caption: caption,
    );
    if (result.ok) {
      state = const AsyncActionState.success(scope: 'stories:edit');
      return result.data;
    }
    state = AsyncActionState.error(
      scope: 'stories:edit:$storyId',
      message: result.message.isNotEmpty
          ? result.message
          : 'Hikaye güncellenemedi.',
    );
    return null;
  }

  Future<bool> deleteStory(int storyId) async {
    state = AsyncActionState.loading(scope: 'stories:delete:$storyId');
    final result = await _repository.deleteStory(storyId);
    if (result.ok) {
      state = const AsyncActionState.success(scope: 'stories:delete');
      return true;
    }
    state = AsyncActionState.error(
      scope: 'stories:delete:$storyId',
      message: result.message.isNotEmpty
          ? result.message
          : 'Hikaye silinemedi.',
    );
    return false;
  }

  Future<StoryMutationResult?> repostStory(int storyId) async {
    state = AsyncActionState.loading(scope: 'stories:repost:$storyId');
    final result = await _repository.repostStory(storyId);
    if (result.ok) {
      state = const AsyncActionState.success(scope: 'stories:repost');
      return result.data;
    }
    state = AsyncActionState.error(
      scope: 'stories:repost:$storyId',
      message: result.message.isNotEmpty
          ? result.message
          : 'Hikaye yeniden paylasilamadi.',
    );
    return null;
  }
}

final storiesActionControllerProvider =
    AutoDisposeNotifierProvider<StoriesActionController, AsyncActionState>(
      StoriesActionController.new,
    );
