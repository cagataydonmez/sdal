import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/state/async_action_state.dart';
import '../../../core/network/json_utils.dart';
import '../data/albums_repository.dart';

class AlbumUploadResult {
  const AlbumUploadResult({
    required this.ok,
    this.photoId = 0,
    this.message = '',
  });

  final bool ok;
  final int photoId;
  final String message;
}

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

  Future<AlbumUploadResult> uploadPhoto({
    required int categoryId,
    required String title,
    required String description,
    required File file,
    File? sourceFile,
    required bool allowComments,
    List<int> taggedUserIds = const <int>[],
    Map<String, dynamic> editMetadata = const <String, dynamic>{},
    String albumGroupKey = '',
    int albumGroupIndex = 0,
  }) async {
    state = const AsyncActionState.loading(scope: 'albums:upload');
    final result = await _repository.uploadPhoto(
      categoryId: categoryId,
      title: title,
      description: description,
      file: file,
      sourceFile: sourceFile,
      allowComments: allowComments,
      taggedUserIds: taggedUserIds,
      editMetadata: editMetadata,
      albumGroupKey: albumGroupKey,
      albumGroupIndex: albumGroupIndex,
    );
    if (result.ok) {
      final payload = asJsonMap(result.rawData);
      final photoId = asInt(payload['id'] ?? payload['photoId']) ?? 0;
      final message = result.message.isNotEmpty
          ? result.message
          : 'Fotoğraf yüklendi.';
      state = AsyncActionState.success(
        scope: 'albums:upload',
        message: message,
      );
      return AlbumUploadResult(ok: true, photoId: photoId, message: message);
    }
    final message = result.message.isNotEmpty
        ? result.message
        : 'Fotoğraf yüklenemedi.';
    state = AsyncActionState.error(scope: 'albums:upload', message: message);
    return AlbumUploadResult(ok: false, message: message);
  }

  Future<AlbumUploadResult> uploadPhotosBatch({
    required int categoryId,
    required String description,
    required bool allowComments,
    required List<File> files,
    List<File> sourceFiles = const <File>[],
    required List<String> titles,
    List<int> taggedUserIds = const <int>[],
    List<Map<String, dynamic>> metadataList = const <Map<String, dynamic>>[],
  }) async {
    state = const AsyncActionState.loading(scope: 'albums:upload');
    final result = await _repository.uploadPhotosBatch(
      categoryId: categoryId,
      description: description,
      allowComments: allowComments,
      files: files,
      sourceFiles: sourceFiles,
      titles: titles,
      taggedUserIds: taggedUserIds,
      metadataList: metadataList,
    );
    if (result.ok) {
      final payload = asJsonMap(result.rawData);
      final items = asJsonMapList(payload['items']);
      final photoId = items.isEmpty
          ? asInt(payload['id'] ?? payload['photoId']) ?? 0
          : asInt(items.first['id'] ?? items.first['photoId']) ?? 0;
      final message = result.message.isNotEmpty
          ? result.message
          : 'Fotoğraflar yüklendi.';
      state = AsyncActionState.success(
        scope: 'albums:upload',
        message: message,
      );
      return AlbumUploadResult(ok: true, photoId: photoId, message: message);
    }
    final message = result.message.isNotEmpty
        ? result.message
        : 'Fotoğraflar yüklenemedi.';
    state = AsyncActionState.error(scope: 'albums:upload', message: message);
    return AlbumUploadResult(ok: false, message: message);
  }

  Future<bool> toggleLike(int photoId) async {
    state = AsyncActionState.loading(scope: 'albums:like:$photoId');
    final result = await _repository.toggleLike(photoId);
    if (result.ok) {
      state = const AsyncActionState.success(scope: 'albums:like');
      return true;
    }
    state = AsyncActionState.error(
      scope: 'albums:like:$photoId',
      message: result.message.isNotEmpty
          ? result.message
          : 'Beğeni kaydedilemedi.',
    );
    return false;
  }

  Future<bool> editComment({
    required int photoId,
    required int commentId,
    required String comment,
  }) async {
    state = AsyncActionState.loading(scope: 'albums:comment-edit:$commentId');
    final result = await _repository.editComment(
      photoId: photoId,
      commentId: commentId,
      comment: comment,
    );
    if (result.ok) {
      state = const AsyncActionState.success(scope: 'albums:comment-edit');
      return true;
    }
    state = AsyncActionState.error(
      scope: 'albums:comment-edit:$commentId',
      message: result.message.isNotEmpty
          ? result.message
          : 'Yorum güncellenemedi.',
    );
    return false;
  }

  Future<bool> deleteComment({
    required int photoId,
    required int commentId,
  }) async {
    state = AsyncActionState.loading(scope: 'albums:comment-delete:$commentId');
    final result = await _repository.deleteComment(
      photoId: photoId,
      commentId: commentId,
    );
    if (result.ok) {
      state = const AsyncActionState.success(scope: 'albums:comment-delete');
      return true;
    }
    state = AsyncActionState.error(
      scope: 'albums:comment-delete:$commentId',
      message: result.message.isNotEmpty ? result.message : 'Yorum silinemedi.',
    );
    return false;
  }

  Future<bool> deleteAllComments(int photoId) async {
    state = AsyncActionState.loading(scope: 'albums:comments-clear:$photoId');
    final result = await _repository.deleteAllComments(photoId);
    if (result.ok) {
      state = const AsyncActionState.success(scope: 'albums:comments-clear');
      return true;
    }
    state = AsyncActionState.error(
      scope: 'albums:comments-clear:$photoId',
      message: result.message.isNotEmpty
          ? result.message
          : 'Yorumlar silinemedi.',
    );
    return false;
  }

  Future<bool> updatePhoto({
    required int photoId,
    required String title,
    required String description,
    required bool allowComments,
    List<int> taggedUserIds = const <int>[],
    Map<String, dynamic> editMetadata = const <String, dynamic>{},
  }) async {
    state = AsyncActionState.loading(scope: 'albums:photo-edit:$photoId');
    final result = await _repository.updatePhoto(
      photoId: photoId,
      title: title,
      description: description,
      allowComments: allowComments,
      taggedUserIds: taggedUserIds,
      editMetadata: editMetadata,
    );
    if (result.ok) {
      state = const AsyncActionState.success(scope: 'albums:photo-edit');
      return true;
    }
    state = AsyncActionState.error(
      scope: 'albums:photo-edit:$photoId',
      message: result.message.isNotEmpty
          ? result.message
          : 'Fotoğraf güncellenemedi.',
    );
    return false;
  }

  Future<bool> replacePhotoFile({
    required int photoId,
    required File file,
    File? sourceFile,
    Map<String, dynamic> editMetadata = const <String, dynamic>{},
  }) async {
    state = AsyncActionState.loading(scope: 'albums:photo-replace:$photoId');
    final result = await _repository.replacePhotoFile(
      photoId: photoId,
      file: file,
      sourceFile: sourceFile,
      editMetadata: editMetadata,
    );
    if (result.ok) {
      state = const AsyncActionState.success(scope: 'albums:photo-replace');
      return true;
    }
    state = AsyncActionState.error(
      scope: 'albums:photo-replace:$photoId',
      message: result.message.isNotEmpty
          ? result.message
          : 'Fotoğraf değiştirilemedi.',
    );
    return false;
  }

  Future<bool> deletePhoto(int photoId) async {
    state = AsyncActionState.loading(scope: 'albums:photo-delete:$photoId');
    final result = await _repository.deletePhoto(photoId);
    if (result.ok) {
      state = const AsyncActionState.success(scope: 'albums:photo-delete');
      return true;
    }
    state = AsyncActionState.error(
      scope: 'albums:photo-delete:$photoId',
      message: result.message.isNotEmpty
          ? result.message
          : 'Fotoğraf silinemedi.',
    );
    return false;
  }

  Future<bool> createAlbum({
    required String title,
    required String description,
    required String visibilityScope,
    bool isProfileAlbum = false,
    String cohortYear = '',
    List<int> allowedUserIds = const <int>[],
    List<int> allowedGroupIds = const <int>[],
  }) async {
    state = const AsyncActionState.loading(scope: 'albums:create');
    final result = await _repository.createAlbum(
      title: title,
      description: description,
      visibilityScope: visibilityScope,
      isProfileAlbum: isProfileAlbum,
      cohortYear: cohortYear,
      allowedUserIds: allowedUserIds,
      allowedGroupIds: allowedGroupIds,
    );
    if (result.ok) {
      state = AsyncActionState.success(
        scope: 'albums:create',
        message: result.message.isNotEmpty
            ? result.message
            : 'Albüm oluşturuldu.',
      );
      return true;
    }
    state = AsyncActionState.error(
      scope: 'albums:create',
      message: result.message.isNotEmpty
          ? result.message
          : 'Albüm oluşturulamadı.',
    );
    return false;
  }

  Future<bool> updateAlbum({
    required int categoryId,
    required String title,
    required String description,
    required String visibilityScope,
    String cohortYear = '',
    String coverMode = 'latest',
    int? coverPhotoId,
    List<int> allowedUserIds = const <int>[],
    List<int> allowedGroupIds = const <int>[],
  }) async {
    state = AsyncActionState.loading(scope: 'albums:update:$categoryId');
    final result = await _repository.updateAlbum(
      categoryId: categoryId,
      title: title,
      description: description,
      visibilityScope: visibilityScope,
      cohortYear: cohortYear,
      coverMode: coverMode,
      coverPhotoId: coverPhotoId,
      allowedUserIds: allowedUserIds,
      allowedGroupIds: allowedGroupIds,
    );
    if (result.ok) {
      state = AsyncActionState.success(
        scope: 'albums:update',
        message: result.message.isNotEmpty
            ? result.message
            : 'Albüm güncellendi.',
      );
      return true;
    }
    state = AsyncActionState.error(
      scope: 'albums:update:$categoryId',
      message: result.message.isNotEmpty
          ? result.message
          : 'Albüm güncellenemedi.',
    );
    return false;
  }

  Future<bool> deleteAlbum(int categoryId) async {
    state = AsyncActionState.loading(scope: 'albums:delete:$categoryId');
    final result = await _repository.deleteAlbum(categoryId);
    if (result.ok) {
      state = const AsyncActionState.success(scope: 'albums:delete');
      return true;
    }
    state = AsyncActionState.error(
      scope: 'albums:delete:$categoryId',
      message: result.message.isNotEmpty ? result.message : 'Albüm silinemedi.',
    );
    return false;
  }
}

final albumsActionControllerProvider =
    NotifierProvider.autoDispose<AlbumsActionController, AsyncActionState>(
      AlbumsActionController.new,
    );
