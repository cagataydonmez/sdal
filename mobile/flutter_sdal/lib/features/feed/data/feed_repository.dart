import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import '../../../app/providers.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_result.dart';
import '../../../core/network/json_utils.dart';
import '../../../core/network/paged_response.dart';

part 'feed_repository.freezed.dart';
part 'feed_repository.g.dart';

@freezed
class FeedAuthor with _$FeedAuthor {
  const factory FeedAuthor({
    @JsonKey(fromJson: readRequiredText) required String isim,
    @JsonKey(fromJson: readRequiredText) required String kadi,
    @JsonKey(fromJson: readRequiredText) required String resim,
  }) = _FeedAuthor;

  factory FeedAuthor.fromJson(Map<String, dynamic> json) =>
      _$FeedAuthorFromJson(
        normalizeJsonAliases(json, {
          'isim': ['name', 'kadi'],
          'resim': ['photo'],
        }),
      );
}

@freezed
class FeedVariants with _$FeedVariants {
  const factory FeedVariants({
    @JsonKey(fromJson: readRequiredText) required String feedUrl,
  }) = _FeedVariants;

  factory FeedVariants.fromJson(Map<String, dynamic> json) =>
      _$FeedVariantsFromJson(json);
}

@freezed
class FeedItem with _$FeedItem {
  const FeedItem._();

  const factory FeedItem({
    @JsonKey(fromJson: readRequiredInt) required int id,
    @JsonKey(fromJson: readRequiredText) required String content,
    @JsonKey(fromJson: readRequiredText) required String createdAt,
    required FeedAuthor author,
    @JsonKey(fromJson: readRequiredText) required String image,
    FeedVariants? variants,
    @JsonKey(fromJson: readRequiredInt) required int likeCount,
    @JsonKey(fromJson: readRequiredInt) required int commentCount,
    @JsonKey(fromJson: readRequiredBool) required bool liked,
  }) = _FeedItem;

  String get authorName => author.isim.isNotEmpty ? author.isim : 'SDAL Üyesi';
  String get authorHandle => author.kadi;
  String get authorPhoto => author.resim;
  String get imageUrl => image.isNotEmpty ? image : (variants?.feedUrl ?? '');

  factory FeedItem.fromJson(Map<String, dynamic> json) => _$FeedItemFromJson(
    normalizeJsonAliases(json, {
      'createdAt': ['created_at'],
      'image': const [],
      'likeCount': const [],
      'commentCount': const [],
    }),
  );

  factory FeedItem.fromMap(JsonMap map) => FeedItem.fromJson(map);
}

@freezed
class FeedComment with _$FeedComment {
  const FeedComment._();

  const factory FeedComment({
    @JsonKey(fromJson: readRequiredInt) required int id,
    @JsonKey(fromJson: readRequiredText) required String comment,
    @JsonKey(fromJson: readRequiredText) required String isim,
    @JsonKey(fromJson: readRequiredText) required String createdAt,
  }) = _FeedComment;

  String get text => comment;
  String get authorName => isim.isNotEmpty ? isim : 'SDAL Üyesi';

  factory FeedComment.fromJson(Map<String, dynamic> json) =>
      _$FeedCommentFromJson(
        normalizeJsonAliases(json, {
          'comment': ['body'],
          'isim': ['kadi'],
          'createdAt': ['created_at'],
        }),
      );

  factory FeedComment.fromMap(JsonMap map) => FeedComment.fromJson(map);
}

class FeedRepository {
  const FeedRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<List<FeedItem>> fetchFeed() async {
    final result = await _apiClient.get<dynamic>(
      '/api/new/feed',
      query: const {'limit': 20, 'offset': 0},
    );
    final page = PagedResponse<FeedItem>.fromDynamic(
      result.rawData,
      FeedItem.fromMap,
    );
    return page.items;
  }

  Future<FeedItem?> fetchPost(int postId) async {
    final result = await _apiClient.get<JsonMap>(
      '/api/new/posts/$postId',
      decoder: (raw) => asJsonMap(raw),
    );
    final payload = asJsonMap(result.rawData);
    final item = asJsonMap(payload['item']);
    if (item.isEmpty && payload.isEmpty) return null;
    return FeedItem.fromMap(item.isEmpty ? payload : item);
  }

  Future<List<FeedComment>> fetchComments(int postId) async {
    final result = await _apiClient.get<JsonMap>(
      '/api/new/posts/$postId/comments',
      decoder: (raw) => asJsonMap(raw),
    );
    final payload = asJsonMap(result.rawData);
    final rawItems = payload['items'] ?? payload['rows'] ?? payload;
    return asJsonMapList(
      rawItems,
    ).map(FeedComment.fromMap).toList(growable: false);
  }

  Future<ApiResult<dynamic>> createPost({
    required String content,
    String feedType = 'main',
  }) {
    return _apiClient.post<dynamic>(
      '/api/new/posts',
      body: {'content': content, 'feedType': feedType},
    );
  }

  Future<ApiResult<dynamic>> createPostWithImage({
    required String content,
    required String feedType,
    required File imageFile,
  }) {
    return _apiClient.multipart<dynamic>(
      '/api/new/posts/upload',
      fields: {'content': content, 'feedType': feedType},
      files: {'image': imageFile},
    );
  }

  Future<ApiResult<dynamic>> toggleLike(int postId) {
    return _apiClient.post<dynamic>('/api/new/posts/$postId/like');
  }

  Future<ApiResult<dynamic>> createComment({
    required int postId,
    required String comment,
  }) {
    return _apiClient.post<dynamic>(
      '/api/new/posts/$postId/comments',
      body: {'comment': comment},
    );
  }
}

final feedRepositoryProvider = Provider<FeedRepository>(
  (ref) => FeedRepository(ref.watch(apiClientProvider)),
);

final feedItemsProvider = FutureProvider.autoDispose<List<FeedItem>>(
  (ref) => ref.watch(feedRepositoryProvider).fetchFeed(),
);

final postDetailProvider = FutureProvider.autoDispose.family<FeedItem?, int>(
  (ref, postId) => ref.watch(feedRepositoryProvider).fetchPost(postId),
);

final postCommentsProvider = FutureProvider.autoDispose
    .family<List<FeedComment>, int>(
      (ref, postId) => ref.watch(feedRepositoryProvider).fetchComments(postId),
    );
