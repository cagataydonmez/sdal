import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
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

class FeedOnlineMember {
  const FeedOnlineMember({
    required this.id,
    required this.name,
    required this.handle,
    required this.photo,
  });

  final int id;
  final String name;
  final String handle;
  final String photo;

  factory FeedOnlineMember.fromMap(JsonMap map) {
    final firstName = coalesceText([map['isim']], fallback: '');
    final lastName = coalesceText([map['soyisim']], fallback: '');
    final fullName = '$firstName $lastName'.trim();
    return FeedOnlineMember(
      id: asInt(map['id']) ?? 0,
      name: fullName.isNotEmpty
          ? fullName
          : coalesceText([map['name'], map['kadi']], fallback: 'SDAL Üyesi'),
      handle: coalesceText([map['kadi']], fallback: ''),
      photo: coalesceText([map['resim'], map['photo']], fallback: ''),
    );
  }
}

class FeedPageData {
  const FeedPageData({
    required this.items,
    required this.hasMore,
    required this.limit,
    this.offset,
    this.cursor,
    this.nextCursor,
  });

  final List<FeedItem> items;
  final bool hasMore;
  final int limit;
  final int? offset;
  final int? cursor;
  final int? nextCursor;
}

class FeedRepository {
  const FeedRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<FeedPageData> fetchFeedPage({
    FeedType feedType = FeedType.main,
    FeedFilter filter = FeedFilter.latest,
    int limit = 20,
    int offset = 0,
    int? cursor,
  }) async {
    final safeLimit = limit.clamp(1, 50);
    final safeOffset = offset < 0 ? 0 : offset;
    final safeCursor = (cursor ?? 0) > 0 ? cursor : null;
    final result = await _apiClient.get<dynamic>(
      '/api/new/feed',
      query: {
        'limit': safeLimit,
        if (safeCursor == null) 'offset': safeOffset,
        ...?safeCursor == null ? null : {'cursor': safeCursor},
        'feedType': feedType.apiValue,
        'filter': filter.apiValue,
      },
    );
    final page = PagedResponse<FeedItem>.fromDynamic(
      result.rawData,
      FeedItem.fromMap,
    );
    final nextCursor =
        asInt(page.nextCursor) ??
        (page.hasMore && page.items.isNotEmpty ? page.items.last.id : null);
    return FeedPageData(
      items: page.items,
      hasMore: page.hasMore,
      limit: page.limit ?? safeLimit,
      offset: safeCursor == null ? (page.offset ?? safeOffset) : null,
      cursor: asInt(asJsonMap(result.rawData)['cursor']) ?? safeCursor,
      nextCursor: nextCursor,
    );
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

  Future<ApiResult<dynamic>> toggleReaction(int postId) async {
    final canonical = await _apiClient.post<dynamic>(
      '/api/new/posts/$postId/react',
    );
    if (canonical.ok || !_shouldFallback(canonical.statusCode)) {
      return canonical;
    }
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

  Future<ApiResult<dynamic>> deleteComment({
    required int postId,
    required int commentId,
  }) {
    return _apiClient.delete<dynamic>(
      '/api/new/posts/$postId/comments/$commentId',
    );
  }

  Future<ApiResult<dynamic>> deletePost(int postId) async {
    final canonical = await _apiClient.delete<dynamic>(
      '/api/new/posts/$postId',
    );
    if (canonical.ok || !_shouldFallback(canonical.statusCode)) {
      return canonical;
    }
    return _apiClient.post<dynamic>('/api/new/posts/$postId/delete');
  }

  Future<List<FeedOnlineMember>> fetchOnlineMembers({int limit = 12}) async {
    final result = await _apiClient.get<JsonMap>(
      '/api/new/online-members',
      query: {'limit': limit.clamp(1, 20), 'excludeSelf': 1},
      decoder: (raw) => asJsonMap(raw),
    );
    final payload = asJsonMap(result.rawData);
    return asJsonMapList(
      payload['items'] ?? payload['rows'],
    ).map(FeedOnlineMember.fromMap).toList(growable: false);
  }

  bool _shouldFallback(int statusCode) =>
      statusCode == 404 || statusCode == 405 || statusCode == 501;
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
      .fetchFeedPage(feedType: query.feedType, filter: query.filter)
      .then((page) => page.items);
});

final feedPageProvider = FutureProvider.autoDispose<FeedPageData>((ref) {
  final query = ref.watch(feedQueryProvider);
  return ref
      .watch(feedRepositoryProvider)
      .fetchFeedPage(feedType: query.feedType, filter: query.filter);
});

final postDetailProvider = FutureProvider.autoDispose.family<FeedItem?, int>(
  (ref, postId) => ref.watch(feedRepositoryProvider).fetchPost(postId),
);

final postCommentsProvider = FutureProvider.autoDispose
    .family<List<FeedComment>, int>(
      (ref, postId) => ref.watch(feedRepositoryProvider).fetchComments(postId),
    );

final onlineMembersProvider =
    FutureProvider.autoDispose<List<FeedOnlineMember>>(
      (ref) => ref.watch(feedRepositoryProvider).fetchOnlineMembers(),
    );
