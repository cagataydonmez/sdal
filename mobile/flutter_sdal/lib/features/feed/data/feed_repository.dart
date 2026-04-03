import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/providers.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_result.dart';
import '../../../core/network/json_utils.dart';
import '../../../core/network/paged_response.dart';

class FeedItem {
  const FeedItem({
    required this.id,
    required this.content,
    required this.createdAt,
    required this.authorName,
    required this.authorHandle,
    required this.authorPhoto,
    required this.imageUrl,
    required this.likeCount,
    required this.commentCount,
    required this.liked,
  });

  final int id;
  final String content;
  final String createdAt;
  final String authorName;
  final String authorHandle;
  final String authorPhoto;
  final String imageUrl;
  final int likeCount;
  final int commentCount;
  final bool liked;

  factory FeedItem.fromMap(JsonMap map) {
    final author = asJsonMap(map['author']);
    return FeedItem(
      id: asInt(map['id']) ?? 0,
      content: coalesceText([map['content']], fallback: ''),
      createdAt: coalesceText([
        map['createdAt'],
        map['created_at'],
      ], fallback: ''),
      authorName: coalesceText([
        author['isim'],
        author['name'],
        author['kadi'],
      ], fallback: 'SDAL Üyesi'),
      authorHandle: coalesceText([author['kadi']], fallback: ''),
      authorPhoto: coalesceText([
        author['resim'],
        author['photo'],
      ], fallback: ''),
      imageUrl: coalesceText([
        map['image'],
        asJsonMap(map['variants'])['feedUrl'],
      ], fallback: ''),
      likeCount: asInt(map['likeCount']) ?? 0,
      commentCount: asInt(map['commentCount']) ?? 0,
      liked: asBool(map['liked']) ?? false,
    );
  }
}

class FeedComment {
  const FeedComment({
    required this.id,
    required this.text,
    required this.authorName,
    required this.createdAt,
  });

  final int id;
  final String text;
  final String authorName;
  final String createdAt;

  factory FeedComment.fromMap(JsonMap map) {
    return FeedComment(
      id: asInt(map['id']) ?? 0,
      text: coalesceText([map['comment'], map['body']], fallback: ''),
      authorName: coalesceText([
        map['isim'],
        map['kadi'],
      ], fallback: 'SDAL Üyesi'),
      createdAt: coalesceText([
        map['created_at'],
        map['createdAt'],
      ], fallback: ''),
    );
  }
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
