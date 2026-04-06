import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/providers.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_result.dart';
import '../../../core/network/json_utils.dart';

class StoryAuthor {
  const StoryAuthor({
    required this.id,
    required this.handle,
    required this.displayName,
    required this.photo,
    required this.verified,
  });

  final int id;
  final String handle;
  final String displayName;
  final String photo;
  final bool verified;

  factory StoryAuthor.fromMap(JsonMap map) {
    final firstName = coalesceText([map['isim']], fallback: '');
    final lastName = coalesceText([map['soyisim']], fallback: '');
    final fullName = '$firstName $lastName'.trim();
    final handle = coalesceText([map['kadi']], fallback: '');
    return StoryAuthor(
      id: asInt(map['id']) ?? 0,
      handle: handle,
      displayName: fullName.isNotEmpty
          ? fullName
          : handle.isNotEmpty
          ? '@$handle'
          : 'SDAL Üyesi',
      photo: coalesceText([map['resim']], fallback: ''),
      verified: asBool(map['verified']) ?? false,
    );
  }
}

class StoryMediaVariants {
  const StoryMediaVariants({
    required this.thumbUrl,
    required this.feedUrl,
    required this.fullUrl,
  });

  final String thumbUrl;
  final String feedUrl;
  final String fullUrl;

  factory StoryMediaVariants.fromMap(JsonMap map) {
    return StoryMediaVariants(
      thumbUrl: coalesceText([map['thumbUrl']], fallback: ''),
      feedUrl: coalesceText([map['feedUrl']], fallback: ''),
      fullUrl: coalesceText([map['fullUrl']], fallback: ''),
    );
  }
}

class StoryItem {
  const StoryItem({
    required this.id,
    required this.image,
    required this.caption,
    required this.createdAt,
    required this.expiresAt,
    required this.isExpired,
    required this.viewed,
    required this.groupId,
    required this.viewCount,
    required this.author,
    required this.variants,
  });

  final int id;
  final String image;
  final String caption;
  final String createdAt;
  final String expiresAt;
  final bool isExpired;
  final bool viewed;
  final int? groupId;
  final int viewCount;
  final StoryAuthor? author;
  final StoryMediaVariants? variants;

  String get mediaUrl {
    final variantUrl = variants?.fullUrl ?? variants?.feedUrl ?? '';
    return variantUrl.isNotEmpty ? variantUrl : image;
  }

  bool get isExpiredResolved {
    final now = DateTime.now();
    final expiresAtDate = DateTime.tryParse(expiresAt);
    if (expiresAtDate != null) {
      return !expiresAtDate.isAfter(now);
    }
    final createdAtDate = DateTime.tryParse(createdAt);
    if (createdAtDate != null) {
      return !createdAtDate.add(const Duration(hours: 24)).isAfter(now);
    }
    return isExpired;
  }

  factory StoryItem.fromMap(JsonMap map) {
    final authorMap = asJsonMap(map['author']);
    final variantsMap = asJsonMap(map['variants']);
    return StoryItem(
      id: asInt(map['id']) ?? 0,
      image: coalesceText([map['image']], fallback: ''),
      caption: coalesceText([map['caption']], fallback: ''),
      createdAt: coalesceText([
        map['createdAt'],
        map['created_at'],
      ], fallback: ''),
      expiresAt: coalesceText([
        map['expiresAt'],
        map['expires_at'],
      ], fallback: ''),
      isExpired: asBool(map['isExpired']) ?? false,
      viewed: asBool(map['viewed']) ?? false,
      groupId: asInt(map['groupId']),
      viewCount: asInt(map['viewCount']) ?? 0,
      author: authorMap.isEmpty ? null : StoryAuthor.fromMap(authorMap),
      variants: variantsMap.isEmpty
          ? null
          : StoryMediaVariants.fromMap(variantsMap),
    );
  }
}

class StoriesRepository {
  const StoriesRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<List<StoryItem>> fetchFeedStories({String feedType = 'main'}) async {
    final result = await _apiClient.get<JsonMap>(
      '/api/new/stories',
      query: {'feedType': feedType},
      decoder: asJsonMap,
    );
    return asJsonMapList(
      asJsonMap(result.rawData)['items'],
    ).map(StoryItem.fromMap).toList(growable: false);
  }

  Future<List<StoryItem>> fetchMyStories({String feedType = 'main'}) async {
    final result = await _apiClient.get<JsonMap>(
      '/api/new/stories/mine',
      query: {'feedType': feedType},
      decoder: asJsonMap,
    );
    return asJsonMapList(
      asJsonMap(result.rawData)['items'],
    ).map(StoryItem.fromMap).toList(growable: false);
  }

  Future<List<StoryItem>> fetchMemberStories(int userId) async {
    final result = await _apiClient.get<JsonMap>(
      '/api/new/stories/user/$userId',
      decoder: asJsonMap,
    );
    return asJsonMapList(
      asJsonMap(result.rawData)['items'],
    ).map(StoryItem.fromMap).toList(growable: false);
  }

  Future<ApiResult<dynamic>> uploadStory({
    required File imageFile,
    required String caption,
    String feedType = 'main',
  }) {
    return _apiClient.multipart<dynamic>(
      '/api/new/stories/upload',
      files: {'image': imageFile},
      fields: {'caption': caption, 'feedType': feedType},
    );
  }

  Future<ApiResult<dynamic>> editStory({
    required int storyId,
    required String caption,
  }) {
    return _apiClient.post<dynamic>(
      '/api/new/stories/$storyId/edit',
      body: {'caption': caption},
    );
  }

  Future<ApiResult<dynamic>> deleteStory(int storyId) {
    return _apiClient.post<dynamic>('/api/new/stories/$storyId/delete');
  }

  Future<ApiResult<dynamic>> repostStory(int storyId) {
    return _apiClient.post<dynamic>('/api/new/stories/$storyId/repost');
  }

  Future<ApiResult<dynamic>> markViewed(int storyId) {
    return _apiClient.post<dynamic>('/api/new/stories/$storyId/view');
  }
}

final storiesRepositoryProvider = Provider<StoriesRepository>(
  (ref) => StoriesRepository(ref.watch(apiClientProvider)),
);

final feedStoriesProvider = FutureProvider.autoDispose
    .family<List<StoryItem>, String>((ref, feedType) {
      return ref
          .watch(storiesRepositoryProvider)
          .fetchFeedStories(feedType: feedType);
    });

final myStoriesProvider = FutureProvider.autoDispose
    .family<List<StoryItem>, String>((ref, feedType) {
      return ref
          .watch(storiesRepositoryProvider)
          .fetchMyStories(feedType: feedType);
    });

final myActiveStoriesProvider = FutureProvider.autoDispose
    .family<List<StoryItem>, String>((ref, feedType) async {
      final items = await ref.watch(myStoriesProvider(feedType).future);
      return items
          .where((item) => !item.isExpiredResolved)
          .toList(growable: false);
    });

final myExpiredStoriesProvider = FutureProvider.autoDispose
    .family<List<StoryItem>, String>((ref, feedType) async {
      final items = await ref.watch(myStoriesProvider(feedType).future);
      return items
          .where((item) => item.isExpiredResolved)
          .toList(growable: false);
    });

final memberStoriesProvider = FutureProvider.autoDispose
    .family<List<StoryItem>, int>((ref, memberId) {
      return ref.watch(storiesRepositoryProvider).fetchMemberStories(memberId);
    });
