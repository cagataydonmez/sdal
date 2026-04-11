import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/state/async_action_state.dart';
import '../data/albums_repository.dart';

class AlbumsActionController extends Notifier<AsyncActionState> {
  AlbumsRepository get _repository => ref.read(albumsRepositoryProvider);

  @override
  AsyncActionState build() => const AsyncActionState.idle();

  Future<bool> addComment({
    required int photoId,
    required String comment,
  }) async {
    state = AsyncActionState.loading(scope: 'albums:comment:$photoId');
    final result = await _repository.addComment(
      photoId: photoId,
      comment: comment,
    );
    if (result.ok) {
      state = const AsyncActionState.success(scope: 'albums:comment');
      return true;
    }
    state = AsyncActionState.error(
      scope: 'albums:comment:$photoId',
      message: result.message.isNotEmpty
          ? result.message
          : 'Yorum gönderilemedi.',
    );
    return false;
  }

  Future<bool> uploadPhoto({
    required int categoryId,
    required String title,
    required String description,
    required File file,
  }) async {
    state = const AsyncActionState.loading(scope: 'albums:upload');
    final result = await _repository.uploadPhoto(
      categoryId: categoryId,
      title: title,
      description: description,
      file: file,
    );
    if (result.ok) {
      state = AsyncActionState.success(
        scope: 'albums:upload',
        message: result.message.isNotEmpty
            ? result.message
            : 'Fotoğraf yüklendi.',
      );
      return true;
    }
    state = AsyncActionState.error(
      scope: 'albums:upload',
      message: result.message.isNotEmpty
          ? result.message
          : 'Fotoğraf yüklenemedi.',
    );
    return false;
  }
}

final albumsActionControllerProvider =
    NotifierProvider.autoDispose<AlbumsActionController, AsyncActionState>(
      AlbumsActionController.new,
    );
