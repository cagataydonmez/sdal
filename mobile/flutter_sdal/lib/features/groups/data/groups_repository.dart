import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/providers.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_result.dart';
import '../../../core/network/json_utils.dart';

class GroupPerson {
  const GroupPerson({
    required this.id,
    required this.handle,
    required this.displayName,
    required this.photo,
    required this.verified,
    required this.role,
    required this.createdAt,
  });

  final int id;
  final String handle;
  final String displayName;
  final String photo;
  final bool verified;
  final String role;
  final String createdAt;

  factory GroupPerson.fromMap(JsonMap map) {
    final firstName = coalesceText([map['isim']], fallback: '');
    final lastName = coalesceText([map['soyisim']], fallback: '');
    final fullName = '$firstName $lastName'.trim();
    final handle = coalesceText([map['kadi']], fallback: '');
    return GroupPerson(
      id:
          asInt(map['id']) ??
          asInt(map['user_id']) ??
          asInt(map['invited_user_id']) ??
          0,
      handle: handle,
      displayName: fullName.isNotEmpty
          ? fullName
          : handle.isNotEmpty
          ? '@$handle'
          : 'SDAL Uyesi',
      photo: coalesceText([map['resim']], fallback: ''),
      verified: asBool(map['verified']) ?? false,
      role: coalesceText([map['role']], fallback: ''),
      createdAt: coalesceText([map['created_at']], fallback: ''),
    );
  }
}

class GroupListItem {
  const GroupListItem({
    required this.id,
    required this.name,
    required this.description,
    required this.coverImage,
    required this.membersCount,
    required this.visibility,
    required this.joined,
    required this.pending,
    required this.invited,
    required this.myRole,
    required this.membershipStatus,
    required this.showContactHint,
    required this.isCohortGroup,
    required this.cohortYear,
  });

  final int id;
  final String name;
  final String description;
  final String coverImage;
  final int membersCount;
  final String visibility;
  final bool joined;
  final bool pending;
  final bool invited;
  final String myRole;
  final String membershipStatus;
  final bool showContactHint;
  final bool isCohortGroup;
  final String cohortYear;

  factory GroupListItem.fromMap(JsonMap map) {
    return GroupListItem(
      id: asInt(map['id']) ?? 0,
      name: coalesceText([map['name']], fallback: 'Grup'),
      description: coalesceText([map['description']], fallback: ''),
      coverImage: coalesceText([map['cover_image']], fallback: ''),
      membersCount: asInt(map['members']) ?? 0,
      visibility: coalesceText([map['visibility']], fallback: 'public'),
      joined: asBool(map['joined']) ?? false,
      pending: asBool(map['pending']) ?? false,
      invited: asBool(map['invited']) ?? false,
      myRole: coalesceText([map['myRole']], fallback: ''),
      membershipStatus: coalesceText([
        map['membershipStatus'],
      ], fallback: 'none'),
      showContactHint: asBool(map['show_contact_hint']) ?? false,
      isCohortGroup: (asInt(map['is_cohort_group']) ?? 0) == 1,
      cohortYear: coalesceText([map['cohort_year']], fallback: ''),
    );
  }
}

class GroupPost {
  const GroupPost({
    required this.id,
    required this.content,
    required this.image,
    required this.createdAt,
    required this.author,
    required this.likeCount,
    required this.commentCount,
    required this.liked,
    required this.postType,
    this.entityId,
  });

  final int id;
  final String content;
  final String image;
  final String createdAt;
  final GroupPerson author;
  final int likeCount;
  final int commentCount;
  final bool liked;
  final String postType;
  final int? entityId;

  bool get isEntityPost => postType == 'group_event' || postType == 'group_announcement' || postType == 'event' || postType == 'announcement';

  factory GroupPost.fromMap(JsonMap map) {
    return GroupPost(
      id: asInt(map['id']) ?? 0,
      content: coalesceText([map['content']], fallback: ''),
      image: coalesceText([map['image']], fallback: ''),
      createdAt: coalesceText([map['created_at']], fallback: ''),
      author: GroupPerson.fromMap(map),
      likeCount: asInt(map['likeCount']) ?? 0,
      commentCount: asInt(map['commentCount']) ?? 0,
      liked: asBool(map['liked']) ?? false,
      postType: coalesceText([map['post_type']], fallback: 'post'),
      entityId: asInt(map['entity_id']),
    );
  }
}

class GroupEventItem {
  const GroupEventItem({
    required this.id,
    required this.title,
    required this.description,
    required this.location,
    required this.startsAt,
    required this.endsAt,
    required this.createdAt,
    required this.creatorHandle,
  });

  final int id;
  final String title;
  final String description;
  final String location;
  final String startsAt;
  final String endsAt;
  final String createdAt;
  final String creatorHandle;

  factory GroupEventItem.fromMap(JsonMap map) {
    return GroupEventItem(
      id: asInt(map['id']) ?? 0,
      title: coalesceText([map['title']], fallback: 'Etkinlik'),
      description: coalesceText([map['description']], fallback: ''),
      location: coalesceText([map['location']], fallback: ''),
      startsAt: coalesceText([map['starts_at']], fallback: ''),
      endsAt: coalesceText([map['ends_at']], fallback: ''),
      createdAt: coalesceText([map['created_at']], fallback: ''),
      creatorHandle: coalesceText([map['creator_kadi']], fallback: ''),
    );
  }
}

class GroupAnnouncementItem {
  const GroupAnnouncementItem({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.creatorHandle,
  });

  final int id;
  final String title;
  final String body;
  final String createdAt;
  final String creatorHandle;

  factory GroupAnnouncementItem.fromMap(JsonMap map) {
    return GroupAnnouncementItem(
      id: asInt(map['id']) ?? 0,
      title: coalesceText([map['title']], fallback: 'Duyuru'),
      body: coalesceText([map['body']], fallback: ''),
      createdAt: coalesceText([map['created_at']], fallback: ''),
      creatorHandle: coalesceText([map['creator_kadi']], fallback: ''),
    );
  }
}

class GroupDetail {
  const GroupDetail({
    required this.group,
    required this.members,
    required this.managers,
    required this.membershipStatus,
    required this.myRole,
    required this.canReviewRequests,
    required this.joinRequests,
    required this.pendingInvites,
    required this.groupEvents,
    required this.groupAnnouncements,
    required this.posts,
    required this.accessDenied,
    required this.accessMessage,
  });

  final GroupListItem group;
  final List<GroupPerson> members;
  final List<GroupPerson> managers;
  final String membershipStatus;
  final String myRole;
  final bool canReviewRequests;
  final List<GroupPerson> joinRequests;
  final List<GroupPerson> pendingInvites;
  final List<GroupEventItem> groupEvents;
  final List<GroupAnnouncementItem> groupAnnouncements;
  final List<GroupPost> posts;
  final bool accessDenied;
  final String accessMessage;

  bool get isMember => membershipStatus == 'member';
  bool get isInvited => membershipStatus == 'invited';
  bool get isPending => membershipStatus == 'pending';
  bool get canManage =>
      myRole == 'owner' || myRole == 'moderator' || myRole == 'admin';

  factory GroupDetail.fromMap(JsonMap map, {bool accessDenied = false}) {
    return GroupDetail(
      group: GroupListItem.fromMap(asJsonMap(map['group'])),
      members: asJsonMapList(
        map['members'],
      ).map(GroupPerson.fromMap).toList(growable: false),
      managers: asJsonMapList(
        map['managers'],
      ).map(GroupPerson.fromMap).toList(growable: false),
      membershipStatus: coalesceText([
        map['membershipStatus'],
      ], fallback: 'none'),
      myRole: coalesceText([map['myRole']], fallback: ''),
      canReviewRequests: asBool(map['canReviewRequests']) ?? false,
      joinRequests: asJsonMapList(
        map['joinRequests'],
      ).map(GroupPerson.fromMap).toList(growable: false),
      pendingInvites: asJsonMapList(
        map['pendingInvites'],
      ).map(GroupPerson.fromMap).toList(growable: false),
      groupEvents: asJsonMapList(
        map['groupEvents'],
      ).map(GroupEventItem.fromMap).toList(growable: false),
      groupAnnouncements: asJsonMapList(
        map['groupAnnouncements'],
      ).map(GroupAnnouncementItem.fromMap).toList(growable: false),
      posts: asJsonMapList(
        map['posts'],
      ).map(GroupPost.fromMap).toList(growable: false),
      accessDenied: accessDenied,
      accessMessage: coalesceText([map['message']], fallback: ''),
    );
  }
}

class GroupsPageData<T> {
  const GroupsPageData({required this.items, required this.hasMore});

  final List<T> items;
  final bool hasMore;
}

class GroupsRepository {
  const GroupsRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<GroupsPageData<GroupListItem>> fetchGroups({
    int limit = 30,
    int offset = 0,
  }) async {
    final result = await _apiClient.get<JsonMap>(
      '/api/new/groups',
      query: {'limit': limit, 'offset': offset},
      decoder: asJsonMap,
    );
    final payload = asJsonMap(result.rawData);
    return GroupsPageData<GroupListItem>(
      items: asJsonMapList(
        payload['items'],
      ).map(GroupListItem.fromMap).toList(growable: false),
      hasMore: asBool(payload['hasMore']) ?? false,
    );
  }

  Future<ApiResult<dynamic>> createGroup({
    required String name,
    required String description,
  }) {
    return _apiClient.post<dynamic>(
      '/api/new/groups',
      body: {'name': name, 'description': description},
    );
  }

  Future<ApiResult<JsonMap>> toggleJoin(int groupId) {
    return _apiClient.post<JsonMap>(
      '/api/new/groups/$groupId/join',
      decoder: asJsonMap,
    );
  }

  Future<ApiResult<JsonMap>> leaveGroup(int groupId) async {
    final canonical = await _apiClient.post<JsonMap>(
      '/api/new/groups/$groupId/leave',
      decoder: asJsonMap,
    );
    if (canonical.ok || !_shouldFallback(canonical.statusCode)) {
      return canonical;
    }
    return toggleJoin(groupId);
  }

  Future<GroupDetail?> fetchGroupDetail(int groupId) async {
    final result = await _apiClient.get<JsonMap>(
      '/api/new/groups/$groupId',
      decoder: asJsonMap,
    );
    if (asJsonMap(result.rawData).isEmpty) return null;
    return GroupDetail.fromMap(
      asJsonMap(result.rawData),
      accessDenied: result.statusCode == 403,
    );
  }

  Future<GroupsPageData<GroupPost>> fetchGroupPosts({
    required int groupId,
    int limit = 30,
    int offset = 0,
  }) async {
    final canonical = await _apiClient.get<JsonMap>(
      '/api/new/groups/$groupId/posts',
      query: {'limit': limit, 'offset': offset},
      decoder: asJsonMap,
    );
    if (canonical.ok || !_shouldFallback(canonical.statusCode)) {
      final payload = asJsonMap(canonical.rawData);
      return GroupsPageData(
        items: asJsonMapList(
          payload['items'],
        ).map(GroupPost.fromMap).toList(growable: false),
        hasMore: asBool(payload['hasMore']) ?? false,
      );
    }

    final detail = await fetchGroupDetail(groupId);
    if (detail == null) {
      return const GroupsPageData<GroupPost>(
        items: <GroupPost>[],
        hasMore: false,
      );
    }
    final start = offset < 0 ? 0 : offset;
    if (start >= detail.posts.length) {
      return const GroupsPageData<GroupPost>(
        items: <GroupPost>[],
        hasMore: false,
      );
    }
    final end = (start + limit).clamp(0, detail.posts.length);
    return GroupsPageData<GroupPost>(
      items: detail.posts.sublist(start, end),
      hasMore: end < detail.posts.length,
    );
  }

  Future<ApiResult<dynamic>> respondToInvite({
    required int groupId,
    required String action,
  }) {
    return _apiClient.post<dynamic>(
      '/api/new/groups/$groupId/invitations/respond',
      body: {'action': action},
    );
  }

  Future<ApiResult<JsonMap>> inviteMembers({
    required int groupId,
    required List<int> userIds,
  }) {
    return _apiClient.post<JsonMap>(
      '/api/new/groups/$groupId/invitations',
      body: {'userIds': userIds},
      decoder: asJsonMap,
    );
  }

  Future<ApiResult<dynamic>> reviewJoinRequest({
    required int groupId,
    required int requestId,
    required String action,
  }) {
    return _apiClient.post<dynamic>(
      '/api/new/groups/$groupId/requests/$requestId',
      body: {'action': action},
    );
  }

  Future<ApiResult<dynamic>> updateSettings({
    required int groupId,
    required String visibility,
    required bool showContactHint,
  }) {
    return _apiClient.post<dynamic>(
      '/api/new/groups/$groupId/settings',
      body: {'visibility': visibility, 'showContactHint': showContactHint},
    );
  }

  Future<ApiResult<dynamic>> changeRole({
    required int groupId,
    required int userId,
    required String role,
  }) {
    return _apiClient.post<dynamic>(
      '/api/new/groups/$groupId/role',
      body: {'userId': userId, 'role': role},
    );
  }

  Future<ApiResult<dynamic>> uploadCover({
    required int groupId,
    required File imageFile,
  }) {
    return _apiClient.multipart<dynamic>(
      '/api/new/groups/$groupId/cover',
      files: {'image': imageFile},
    );
  }

  Future<ApiResult<dynamic>> createPost({
    required int groupId,
    required String content,
    File? imageFile,
  }) {
    if (imageFile != null) {
      return _apiClient.multipart<dynamic>(
        '/api/new/groups/$groupId/posts/upload',
        files: {'image': imageFile},
        fields: {'content': content},
      );
    }
    return _apiClient.post<dynamic>(
      '/api/new/groups/$groupId/posts',
      body: {'content': content},
    );
  }

  Future<ApiResult<dynamic>> createEvent({
    required int groupId,
    required String title,
    required String description,
    required String location,
    required String startsAt,
    required String endsAt,
  }) {
    return _apiClient.post<dynamic>(
      '/api/new/groups/$groupId/events',
      body: {
        'title': title,
        'description': description,
        'location': location,
        'starts_at': startsAt,
        'ends_at': endsAt,
      },
    );
  }

  Future<ApiResult<dynamic>> deleteEvent({
    required int groupId,
    required int eventId,
  }) {
    return _apiClient.delete<dynamic>(
      '/api/new/groups/$groupId/events/$eventId',
    );
  }

  Future<ApiResult<dynamic>> createAnnouncement({
    required int groupId,
    required String title,
    required String body,
  }) {
    return _apiClient.post<dynamic>(
      '/api/new/groups/$groupId/announcements',
      body: {'title': title, 'body': body},
    );
  }

  Future<ApiResult<dynamic>> deleteAnnouncement({
    required int groupId,
    required int announcementId,
  }) {
    return _apiClient.delete<dynamic>(
      '/api/new/groups/$groupId/announcements/$announcementId',
    );
  }

  bool _shouldFallback(int statusCode) =>
      statusCode == 404 || statusCode == 405 || statusCode == 501;
}

final groupsRepositoryProvider = Provider<GroupsRepository>(
  (ref) => GroupsRepository(ref.watch(apiClientProvider)),
);

final groupsListProvider = FutureProvider.autoDispose<List<GroupListItem>>((
  ref,
) {
  return ref
      .watch(groupsRepositoryProvider)
      .fetchGroups(limit: 200)
      .then((value) => value.items);
});

final groupDetailProvider = FutureProvider.autoDispose
    .family<GroupDetail?, int>((ref, groupId) {
      return ref.watch(groupsRepositoryProvider).fetchGroupDetail(groupId);
    });

final groupPostsProvider = FutureProvider.autoDispose
    .family<List<GroupPost>, int>((ref, groupId) {
      return ref
          .watch(groupsRepositoryProvider)
          .fetchGroupPosts(groupId: groupId)
          .then((value) => value.items);
    });
