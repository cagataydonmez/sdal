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

enum FeedType { main, community }

extension FeedTypeApi on FeedType {
  String get apiValue => switch (this) {
    FeedType.main => 'main',
    FeedType.community => 'community',
  };
}

enum FeedFilter { latest, popular, following }

extension FeedFilterApi on FeedFilter {
  String get apiValue => switch (this) {
    FeedFilter.latest => 'latest',
    FeedFilter.popular => 'popular',
    FeedFilter.following => 'following',
  };
}

class FeedQuery {
  const FeedQuery({
    this.feedType = FeedType.main,
    this.filter = FeedFilter.latest,
  });

  final FeedType feedType;
  final FeedFilter filter;

  FeedQuery copyWith({FeedType? feedType, FeedFilter? filter}) {
    return FeedQuery(
      feedType: feedType ?? this.feedType,
      filter: filter ?? this.filter,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is FeedQuery &&
        other.feedType == feedType &&
        other.filter == filter;
  }

  @override
  int get hashCode => Object.hash(feedType, filter);
}

@freezed
class FeedAuthor with _$FeedAuthor {
  const factory FeedAuthor({
    @JsonKey(fromJson: readOptionalInt) int? id,
    @JsonKey(fromJson: readRequiredText) required String isim,
    @JsonKey(fromJson: readRequiredText) required String kadi,
    @JsonKey(fromJson: readRequiredText) required String resim,
  }) = _FeedAuthor;

  factory FeedAuthor.fromJson(Map<String, dynamic> json) =>
      _$FeedAuthorFromJson(
        normalizeJsonAliases(json, {
          'id': [
            'userId',
            'user_id',
            'authorId',
            'author_id',
            'memberId',
            'member_id',
          ],
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

  int? get authorId => author.id;
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
    @JsonKey(fromJson: readOptionalInt) int? userId,
    @JsonKey(fromJson: readOptionalText) String? kadi,
    @JsonKey(fromJson: readOptionalText) String? soyisim,
    @JsonKey(fromJson: readOptionalText) String? resim,
    @JsonKey(fromJson: readOptionalBool) bool? verified,
  }) = _FeedComment;

  String get text => comment;
  String get authorName {
    final fullName = '${isim.trim()} ${(soyisim ?? '').trim()}'.trim();
    if (fullName.isNotEmpty) return fullName;
    if (isim.isNotEmpty) return isim;
    if ((kadi ?? '').trim().isNotEmpty) return '@${kadi!.trim()}';
    return 'SDAL Üyesi';
  }

  String get authorHandle => (kadi ?? '').trim();
  String get authorPhoto => (resim ?? '').trim();

  factory FeedComment.fromJson(Map<String, dynamic> json) =>
      _$FeedCommentFromJson(
        normalizeJsonAliases(json, {
          'comment': ['body'],
          'isim': ['kadi'],
          'createdAt': ['created_at'],
          'userId': ['user_id'],
          'kadi': const [],
          'soyisim': const [],
          'resim': ['photo'],
          'verified': const [],
        }),
      );

  factory FeedComment.fromMap(JsonMap map) => FeedComment.fromJson(map);
}

class FeedRepository {
  const FeedRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<List<FeedItem>> fetchFeed({
    FeedType feedType = FeedType.main,
    FeedFilter filter = FeedFilter.latest,
  }) async {
    final result = await _apiClient.get<dynamic>(
      '/api/new/feed',
      query: {
        'limit': 20,
        'offset': 0,
        'feedType': feedType.apiValue,
        'filter': filter.apiValue,
      },
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

final feedQueryProvider = StateProvider.autoDispose<FeedQuery>(
  (ref) => const FeedQuery(),
);

final feedItemsProvider = FutureProvider.autoDispose<List<FeedItem>>((ref) {
  final query = ref.watch(feedQueryProvider);
  return ref
      .watch(feedRepositoryProvider)
      .fetchFeed(feedType: query.feedType, filter: query.filter);
});

final postDetailProvider = FutureProvider.autoDispose.family<FeedItem?, int>(
  (ref, postId) => ref.watch(feedRepositoryProvider).fetchPost(postId),
);

final postCommentsProvider = FutureProvider.autoDispose
    .family<List<FeedComment>, int>(
      (ref, postId) => ref.watch(feedRepositoryProvider).fetchComments(postId),
    );
