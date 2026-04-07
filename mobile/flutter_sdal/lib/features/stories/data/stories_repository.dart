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

  StoryItem copyWith({
    String? image,
    String? caption,
    String? createdAt,
    String? expiresAt,
    bool? isExpired,
    bool? viewed,
    int? groupId,
    int? viewCount,
    StoryAuthor? author,
    StoryMediaVariants? variants,
  }) {
    return StoryItem(
      id: id,
      image: image ?? this.image,
      caption: caption ?? this.caption,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      isExpired: isExpired ?? this.isExpired,
      viewed: viewed ?? this.viewed,
      groupId: groupId ?? this.groupId,
      viewCount: viewCount ?? this.viewCount,
      author: author ?? this.author,
      variants: variants ?? this.variants,
    );
  }

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

class StoryMutationResult {
  const StoryMutationResult({
    required this.id,
    required this.image,
    this.variants,
  });

  final int? id;
  final String image;
  final StoryMediaVariants? variants;

  factory StoryMutationResult.fromMap(JsonMap map) {
    final variantsMap = asJsonMap(map['variants']);
    return StoryMutationResult(
      id: asInt(map['id']),
      image: coalesceText([map['image']], fallback: ''),
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

  Future<ApiResult<StoryMutationResult>> uploadStory({
    required File imageFile,
    required String caption,
    String feedType = 'main',
  }) {
    return _apiClient.multipart<StoryMutationResult>(
      '/api/new/stories/upload',
      files: {'image': imageFile},
      fields: {'caption': caption, 'feedType': feedType},
      decoder: (raw) => StoryMutationResult.fromMap(asJsonMap(raw)),
    );
  }

  Future<ApiResult<StoryMutationResult>> editStory({
    required int storyId,
    required String caption,
  }) async {
    final canonical = await _apiClient.patch<StoryMutationResult>(
      '/api/new/stories/$storyId',
      body: {'caption': caption},
      decoder: (raw) => StoryMutationResult.fromMap(asJsonMap(raw)),
    );
    if (canonical.ok || !_shouldFallback(canonical.statusCode)) {
      return canonical;
    }
    return _apiClient.post<StoryMutationResult>(
      '/api/new/stories/$storyId/edit',
      body: {'caption': caption},
      decoder: (raw) => StoryMutationResult.fromMap(asJsonMap(raw)),
    );
  }

  Future<ApiResult<StoryMutationResult>> deleteStory(int storyId) async {
    final canonical = await _apiClient.delete<StoryMutationResult>(
      '/api/new/stories/$storyId',
      decoder: (raw) => StoryMutationResult.fromMap(asJsonMap(raw)),
    );
    if (canonical.ok || !_shouldFallback(canonical.statusCode)) {
      return canonical;
    }
    return _apiClient.post<StoryMutationResult>(
      '/api/new/stories/$storyId/delete',
      decoder: (raw) => StoryMutationResult.fromMap(asJsonMap(raw)),
    );
  }

  Future<ApiResult<StoryMutationResult>> repostStory(int storyId) {
    return _apiClient.post<StoryMutationResult>(
      '/api/new/stories/$storyId/repost',
      decoder: (raw) => StoryMutationResult.fromMap(asJsonMap(raw)),
    );
  }

  Future<ApiResult<dynamic>> markViewed(int storyId) {
    return _apiClient.post<dynamic>('/api/new/stories/$storyId/view');
  }

  bool _shouldFallback(int statusCode) =>
      statusCode == 404 || statusCode == 405 || statusCode == 501;
}

final storiesRepositoryProvider = Provider<StoriesRepository>(
  (ref) => StoriesRepository(ref.watch(apiClientProvider)),
);

typedef StoryOverlayState = Map<int, StoryItem?>;

class StoryOverlayController extends StateNotifier<StoryOverlayState> {
  StoryOverlayController() : super(const {});

  void upsert(StoryItem item) {
    state = {...state, item.id: item};
  }

  void remove(int storyId) {
    state = {...state, storyId: null};
  }

  void clear() {
    state = const {};
  }
}

final feedStoryOverlayProvider = StateNotifierProvider.autoDispose
    .family<StoryOverlayController, StoryOverlayState, String>(
      (ref, feedType) => StoryOverlayController(),
    );

final myStoryOverlayProvider = StateNotifierProvider.autoDispose
    .family<StoryOverlayController, StoryOverlayState, String>(
      (ref, feedType) => StoryOverlayController(),
    );

List<StoryItem> _mergeStoryItems(
  List<StoryItem> base,
  StoryOverlayState overlay,
) {
  final merged = <int, StoryItem>{for (final item in base) item.id: item};
  final newItems = <StoryItem>[];

  for (final entry in overlay.entries) {
    final item = entry.value;
    if (item == null) {
      merged.remove(entry.key);
      continue;
    }
    final existed = merged.containsKey(entry.key);
    merged[entry.key] = item;
    if (!existed) {
      newItems.add(item);
    }
  }

  final items = [
    ...newItems,
    for (final item in base)
      if (merged.containsKey(item.id)) merged[item.id]!,
  ];
  items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return items;
}

final feedStoriesProvider = FutureProvider.autoDispose
    .family<List<StoryItem>, String>((ref, feedType) {
      return ref
          .watch(storiesRepositoryProvider)
          .fetchFeedStories(feedType: feedType);
    });

final optimisticFeedStoriesProvider = Provider.autoDispose
    .family<AsyncValue<List<StoryItem>>, String>((ref, feedType) {
      final items = ref.watch(feedStoriesProvider(feedType));
      final overlay = ref.watch(feedStoryOverlayProvider(feedType));
      return items.whenData((value) => _mergeStoryItems(value, overlay));
    });

final myStoriesProvider = FutureProvider.autoDispose
    .family<List<StoryItem>, String>((ref, feedType) {
      return ref
          .watch(storiesRepositoryProvider)
          .fetchMyStories(feedType: feedType);
    });

final optimisticMyStoriesProvider = Provider.autoDispose
    .family<AsyncValue<List<StoryItem>>, String>((ref, feedType) {
      final items = ref.watch(myStoriesProvider(feedType));
      final overlay = ref.watch(myStoryOverlayProvider(feedType));
      return items.whenData((value) => _mergeStoryItems(value, overlay));
    });

final myActiveStoriesProvider = Provider.autoDispose
    .family<AsyncValue<List<StoryItem>>, String>((ref, feedType) {
      final items = ref.watch(optimisticMyStoriesProvider(feedType));
      return items.whenData(
        (value) => value
            .where((item) => !item.isExpiredResolved)
            .toList(growable: false),
      );
    });

final myExpiredStoriesProvider = Provider.autoDispose
    .family<AsyncValue<List<StoryItem>>, String>((ref, feedType) {
      final items = ref.watch(optimisticMyStoriesProvider(feedType));
      return items.whenData(
        (value) => value
            .where((item) => item.isExpiredResolved)
            .toList(growable: false),
      );
    });

final memberStoriesProvider = FutureProvider.autoDispose
    .family<List<StoryItem>, int>((ref, memberId) {
      return ref.watch(storiesRepositoryProvider).fetchMemberStories(memberId);
    });
