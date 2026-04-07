import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/providers.dart';
import '../../../core/network/api_result.dart';
import '../../../core/network/json_utils.dart';
import '../../../core/network/paged_response.dart';

class MemberSummary {
  const MemberSummary({
    required this.id,
    required this.name,
    required this.handle,
    required this.city,
    required this.profession,
    required this.photo,
    required this.verified,
    required this.graduationYear,
    required this.joinedAt,
  });

  final int id;
  final String name;
  final String handle;
  final String city;
  final String profession;
  final String photo;
  final bool verified;
  final String graduationYear;
  final DateTime? joinedAt;

  factory MemberSummary.fromMap(JsonMap map) {
    return MemberSummary(
      id: asInt(map['id']) ?? 0,
      name: coalesceText([
        [map['isim'], map['soyisim']].whereType<Object>().join(' ').trim(),
        map['name'],
        map['isim'],
      ], fallback: 'SDAL Üyesi'),
      handle: coalesceText([map['kadi']], fallback: ''),
      city: coalesceText([map['sehir'], map['city']], fallback: ''),
      profession: coalesceText([
        map['meslek'],
        map['profession'],
      ], fallback: ''),
      photo: coalesceText([map['resim'], map['photo']], fallback: ''),
      verified: asBool(map['verified']) ?? false,
      graduationYear: coalesceText([map['mezuniyetyili']], fallback: ''),
      joinedAt: asDateTime(map['ilktarih'] ?? map['joinedAt']),
    );
  }
}

class MemberDetail {
  const MemberDetail({
    required this.summary,
    required this.email,
    required this.signature,
    required this.company,
    required this.title,
    required this.expertise,
    required this.linkedinUrl,
    required this.graduationYear,
  });

  final MemberSummary summary;
  final String email;
  final String signature;
  final String company;
  final String title;
  final String expertise;
  final String linkedinUrl;
  final String graduationYear;

  factory MemberDetail.fromMap(JsonMap map) {
    return MemberDetail(
      summary: MemberSummary.fromMap(map),
      email: coalesceText([map['email']], fallback: ''),
      signature: coalesceText([map['imza'], map['signature']], fallback: ''),
      company: coalesceText([map['sirket'], map['company']], fallback: ''),
      title: coalesceText([map['unvan'], map['title']], fallback: ''),
      expertise: coalesceText([
        map['uzmanlik'],
        map['expertise'],
      ], fallback: ''),
      linkedinUrl: coalesceText([map['linkedin_url']], fallback: ''),
      graduationYear: coalesceText([map['mezuniyetyili']], fallback: ''),
    );
  }
}

class ExploreRepository {
  const ExploreRepository(this._apiClient);

  final dynamic _apiClient;

  Future<List<MemberSummary>> fetchMembers({
    String term = '',
    String? q,
    String year = '',
    String city = '',
    int page = 1,
  }) async {
    final queryText = (q ?? term).trim();
    final trimmedYear = year.trim();
    final trimmedCity = city.trim();
    final result = await _apiClient.get<JsonMap>(
      '/api/members',
      query: {
        'page': page < 1 ? 1 : page,
        'pageSize': 20,
        'excludeSelf': 1,
        if (queryText.isNotEmpty) 'q': queryText,
        if (queryText.isNotEmpty) 'term': queryText,
        if (trimmedYear.isNotEmpty) 'year': trimmedYear,
        if (trimmedYear.isNotEmpty) 'gradYear': trimmedYear,
        if (trimmedCity.isNotEmpty) 'city': trimmedCity,
        if (trimmedCity.isNotEmpty) 'location': trimmedCity,
      },
      decoder: (raw) => asJsonMap(raw),
    );
    return PagedResponse<MemberSummary>.fromDynamic(
      result.rawData,
      MemberSummary.fromMap,
    ).items;
  }

  Future<List<MemberSummary>> fetchLatestMembers({int limit = 10}) async {
    final result = await _apiClient.get<JsonMap>(
      '/api/members/latest',
      query: {'limit': limit.clamp(1, 20)},
      decoder: (raw) => asJsonMap(raw),
    );
    final payload = asJsonMap(result.rawData);
    return asJsonMapList(
      payload['items'] ?? payload['rows'],
    ).map(MemberSummary.fromMap).toList(growable: false);
  }

  Future<List<MemberSummary>> fetchSuggestions() async {
    final result = await _apiClient.get<dynamic>(
      '/api/new/explore/suggestions',
      query: const {'limit': 10, 'offset': 0},
    );
    final payload = asJsonMap(result.rawData);
    final rawItems = payload['items'] ?? payload['rows'] ?? result.rawData;
    return asJsonMapList(
      rawItems,
    ).map(MemberSummary.fromMap).toList(growable: false);
  }

  Future<MemberDetail?> fetchMemberDetail(int memberId) async {
    final result = await _apiClient.get<JsonMap>(
      '/api/members/$memberId',
      decoder: (raw) => asJsonMap(raw),
    );
    final payload = asJsonMap(result.rawData);
    final row = asJsonMap(payload['row']);
    if (row.isEmpty) return null;
    return MemberDetail.fromMap(row);
  }

  Future<ApiResult<dynamic>> follow(int memberId) {
    return _apiClient.post<dynamic>('/api/new/follow/$memberId');
  }
}

final exploreRepositoryProvider = Provider<ExploreRepository>(
  (ref) => ExploreRepository(ref.watch(apiClientProvider)),
);

final directoryMembersProvider =
    FutureProvider.autoDispose<List<MemberSummary>>(
      (ref) => ref.watch(exploreRepositoryProvider).fetchMembers(),
    );

final suggestionMembersProvider =
    FutureProvider.autoDispose<List<MemberSummary>>(
      (ref) => ref.watch(exploreRepositoryProvider).fetchSuggestions(),
    );

final latestMembersProvider = FutureProvider.autoDispose<List<MemberSummary>>(
  (ref) => ref.watch(exploreRepositoryProvider).fetchLatestMembers(),
);

final memberDetailProvider = FutureProvider.autoDispose
    .family<MemberDetail?, int>(
      (ref, memberId) =>
          ref.watch(exploreRepositoryProvider).fetchMemberDetail(memberId),
    );
