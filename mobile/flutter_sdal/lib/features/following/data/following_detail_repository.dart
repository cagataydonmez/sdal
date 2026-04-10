import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/providers.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/json_utils.dart';

class FollowingDetailSection {
  const FollowingDetailSection({
    required this.key,
    required this.label,
    required this.icon,
  });

  final String key;
  final String label;
  final IconData icon;

  static const groups = FollowingDetailSection(
    key: 'groups',
    label: 'Gruplar',
    icon: Icons.groups_rounded,
  );
  static const events = FollowingDetailSection(
    key: 'events',
    label: 'Etkinlikler',
    icon: Icons.event_rounded,
  );
  static const announcements = FollowingDetailSection(
    key: 'announcements',
    label: 'Duyurular',
    icon: Icons.campaign_rounded,
  );
  static const jobs = FollowingDetailSection(
    key: 'jobs',
    label: 'İş ilanları',
    icon: Icons.work_rounded,
  );
  static const teachers = FollowingDetailSection(
    key: 'teachers',
    label: 'Öğretmenler',
    icon: Icons.school_rounded,
  );
  static const following = FollowingDetailSection(
    key: 'following',
    label: 'Takip ettikleri',
    icon: Icons.person_search_rounded,
  );
  static const photos = FollowingDetailSection(
    key: 'photos',
    label: 'Fotoğraflar',
    icon: Icons.photo_library_rounded,
  );

  static const all = <FollowingDetailSection>[
    groups,
    events,
    announcements,
    jobs,
    teachers,
    following,
    photos,
  ];

  static FollowingDetailSection? fromKey(String key) {
    for (final section in all) {
      if (section.key == key) return section;
    }
    return null;
  }
}

class FollowingDetailMember {
  const FollowingDetailMember({
    required this.id,
    required this.name,
    required this.handle,
    required this.photo,
    required this.verified,
  });

  final int id;
  final String name;
  final String handle;
  final String photo;
  final bool verified;

  factory FollowingDetailMember.fromMap(JsonMap map) {
    return FollowingDetailMember(
      id: asInt(map['id']) ?? 0,
      name: coalesceText([map['name']], fallback: 'SDAL Üyesi'),
      handle: coalesceText([map['handle']], fallback: ''),
      photo: coalesceText([map['photo']], fallback: ''),
      verified: asBool(map['verified']) ?? false,
    );
  }
}

class FollowingDetailItem {
  const FollowingDetailItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.meta,
    required this.route,
    required this.image,
    required this.externalUrl,
  });

  final int id;
  final String title;
  final String subtitle;
  final String meta;
  final String route;
  final String image;
  final String externalUrl;

  bool get hasRoute => route.isNotEmpty;
  bool get hasImage => image.isNotEmpty;

  factory FollowingDetailItem.fromMap(JsonMap map) {
    return FollowingDetailItem(
      id: asInt(map['id']) ?? 0,
      title: coalesceText([map['title']], fallback: 'Kayıt'),
      subtitle: coalesceText([map['subtitle']], fallback: ''),
      meta: coalesceText([map['meta']], fallback: ''),
      route: coalesceText([map['route']], fallback: ''),
      image: coalesceText([map['image']], fallback: ''),
      externalUrl: coalesceText([map['externalUrl']], fallback: ''),
    );
  }
}

class FollowingDetailResponse {
  const FollowingDetailResponse({
    required this.member,
    required this.sectionKey,
    required this.title,
    required this.items,
  });

  final FollowingDetailMember member;
  final String sectionKey;
  final String title;
  final List<FollowingDetailItem> items;

  factory FollowingDetailResponse.fromMap(JsonMap map) {
    return FollowingDetailResponse(
      member: FollowingDetailMember.fromMap(asJsonMap(map['member'])),
      sectionKey: coalesceText([map['section']], fallback: ''),
      title: coalesceText([map['title']], fallback: 'Detaylar'),
      items: asJsonMapList(
        map['items'],
      ).map(FollowingDetailItem.fromMap).toList(growable: false),
    );
  }
}

class FollowingDetailRepository {
  const FollowingDetailRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<FollowingDetailResponse> fetchSection({
    required int memberId,
    required String sectionKey,
  }) async {
    final result = await _apiClient.get<JsonMap>(
      '/api/new/follows/$memberId/details/$sectionKey',
      decoder: asJsonMap,
    );
    return FollowingDetailResponse.fromMap(asJsonMap(result.rawData));
  }
}

final followingDetailRepositoryProvider = Provider<FollowingDetailRepository>(
  (ref) => FollowingDetailRepository(ref.watch(apiClientProvider)),
);

final followingDetailSectionProvider = FutureProvider.autoDispose
    .family<FollowingDetailResponse, ({int memberId, String sectionKey})>(
      (ref, args) => ref
          .watch(followingDetailRepositoryProvider)
          .fetchSection(memberId: args.memberId, sectionKey: args.sectionKey),
    );
