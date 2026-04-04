import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/providers.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_result.dart';
import '../../../core/network/json_utils.dart';

class FollowingMember {
  const FollowingMember({
    required this.memberId,
    required this.name,
    required this.handle,
    required this.photo,
    required this.followedAt,
    required this.engagementScore,
    required this.verified,
  });

  final int memberId;
  final String name;
  final String handle;
  final String photo;
  final String followedAt;
  final double engagementScore;
  final bool verified;

  factory FollowingMember.fromMap(JsonMap map) {
    return FollowingMember(
      memberId: asInt(map['following_id']) ?? asInt(map['id']) ?? 0,
      name: coalesceText([
        '${asString(map['isim']) ?? ''} ${asString(map['soyisim']) ?? ''}'
            .trim(),
        map['isim'],
        map['kadi'],
      ], fallback: 'SDAL Üyesi'),
      handle: coalesceText([map['kadi']], fallback: ''),
      photo: coalesceText([map['resim'], map['photo']], fallback: ''),
      followedAt: coalesceText([
        map['followed_at'],
        map['created_at'],
      ], fallback: ''),
      engagementScore: (map['engagement_score'] is num)
          ? (map['engagement_score'] as num).toDouble()
          : double.tryParse('${map['engagement_score'] ?? ''}') ?? 0,
      verified: asBool(map['verified']) ?? false,
    );
  }
}

class FollowingPageData {
  const FollowingPageData({required this.items, required this.hasMore});

  final List<FollowingMember> items;
  final bool hasMore;
}

class FollowingRepository {
  const FollowingRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<FollowingPageData> fetchFollowing({
    int limit = 24,
    int offset = 0,
    String sort = 'engagement',
  }) async {
    final result = await _apiClient.get<JsonMap>(
      '/api/new/follows',
      query: {'limit': limit, 'offset': offset, 'sort': sort},
      decoder: asJsonMap,
    );
    final payload = asJsonMap(result.rawData);
    return FollowingPageData(
      items: asJsonMapList(
        payload['items'],
      ).map(FollowingMember.fromMap).toList(growable: false),
      hasMore: asBool(payload['hasMore']) ?? false,
    );
  }

  Future<ApiResult<JsonMap>> toggleFollow(int memberId) {
    return _apiClient.post<JsonMap>(
      '/api/new/follow/$memberId',
      decoder: asJsonMap,
    );
  }
}

final followingRepositoryProvider = Provider<FollowingRepository>(
  (ref) => FollowingRepository(ref.watch(apiClientProvider)),
);
