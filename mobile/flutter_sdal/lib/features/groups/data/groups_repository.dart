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

  bool get isEntityPost =>
      postType == 'group_event' ||
      postType == 'group_announcement' ||
      postType == 'event' ||
      postType == 'announcement';

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

class GroupEntityComment {
  const GroupEntityComment({
    required this.id,
    required this.comment,
    required this.createdAt,
    required this.userId,
    required this.handle,
    required this.displayName,
    required this.photo,
    required this.verified,
  });

  final int id;
  final String comment;
  final String createdAt;
  final int userId;
  final String handle;
  final String displayName;
  final String photo;
  final bool verified;

  factory GroupEntityComment.fromMap(JsonMap map) {
    final first = coalesceText([map['isim']], fallback: '');
    final last = coalesceText([map['soyisim']], fallback: '');
    final fullName = '$first $last'.trim();
    final handle = coalesceText([map['kadi']], fallback: '');
    return GroupEntityComment(
      id: asInt(map['id']) ?? 0,
      comment: coalesceText([map['comment']], fallback: ''),
      createdAt: coalesceText([map['created_at']], fallback: ''),
      userId: asInt(map['user_id']) ?? 0,
      handle: handle,
      displayName: fullName.isNotEmpty
          ? fullName
          : (handle.isNotEmpty ? '@$handle' : 'SDAL Üyesi'),
      photo: coalesceText([map['resim']], fallback: ''),
      verified: asBool(map['verified']) ?? false,
    );
  }
}

class GroupContentApprovalSetting {
  const GroupContentApprovalSetting({
    required this.entityType,
    required this.approvalRequired,
  });

  final String entityType;
  final bool approvalRequired;

  factory GroupContentApprovalSetting.fromMap(JsonMap map) {
    return GroupContentApprovalSetting(
      entityType: coalesceText([
        map['entityType'],
        map['entity_type'],
      ], fallback: ''),
      approvalRequired:
          asBool(map['approvalRequired'] ?? map['approval_required']) ?? false,
    );
  }
}

class GroupContentApprovalItem {
  const GroupContentApprovalItem({
    required this.id,
    required this.entityType,
    required this.title,
    required this.body,
    required this.createdAt,
  });

  final int id;
  final String entityType;
  final String title;
  final String body;
  final String createdAt;

  String get typeLabel {
    switch (entityType) {
      case 'group_post':
        return 'Post';
      case 'group_event':
        return 'Etkinlik';
      case 'group_announcement':
        return 'Duyuru';
      default:
        return entityType;
    }
  }

  factory GroupContentApprovalItem.fromMap(JsonMap map) {
    return GroupContentApprovalItem(
      id: asInt(map['id']) ?? 0,
      entityType: coalesceText([
        map['entity_type'],
        map['entityType'],
      ], fallback: ''),
      title: coalesceText([map['title']], fallback: ''),
      body: coalesceText([map['body']], fallback: ''),
      createdAt: coalesceText([
        map['created_at'],
        map['createdAt'],
      ], fallback: ''),
    );
  }
}

class GroupEventDetail {
  const GroupEventDetail({
    required this.event,
    required this.comments,
    required this.likeCount,
    required this.liked,
    required this.allowComments,
    required this.allowLikes,
    required this.canManage,
  });

  final GroupEventItem event;
  final List<GroupEntityComment> comments;
  final int likeCount;
  final bool liked;
  final bool allowComments;
  final bool allowLikes;
  final bool canManage;

  factory GroupEventDetail.fromMap(JsonMap map, {required bool canManage}) {
    return GroupEventDetail(
      event: GroupEventItem.fromMap(map),
      comments: asJsonMapList(
        map['comments'],
      ).map(GroupEntityComment.fromMap).toList(growable: false),
      likeCount: asInt(map['like_count']) ?? 0,
      liked: asBool(map['liked']) ?? false,
      allowComments: (asInt(map['allow_comments']) ?? 1) == 1,
      allowLikes: (asInt(map['allow_likes']) ?? 1) == 1,
      canManage: canManage,
    );
  }
}

class GroupAnnouncementDetail {
  const GroupAnnouncementDetail({
    required this.announcement,
    required this.comments,
    required this.likeCount,
    required this.liked,
    required this.allowComments,
    required this.allowLikes,
    required this.canManage,
  });

  final GroupAnnouncementItem announcement;
  final List<GroupEntityComment> comments;
  final int likeCount;
  final bool liked;
  final bool allowComments;
  final bool allowLikes;
  final bool canManage;

  factory GroupAnnouncementDetail.fromMap(
    JsonMap map, {
    required bool canManage,
  }) {
    return GroupAnnouncementDetail(
      announcement: GroupAnnouncementItem.fromMap(map),
      comments: asJsonMapList(
        map['comments'],
      ).map(GroupEntityComment.fromMap).toList(growable: false),
      likeCount: asInt(map['like_count']) ?? 0,
      liked: asBool(map['liked']) ?? false,
      allowComments: (asInt(map['allow_comments']) ?? 1) == 1,
      allowLikes: (asInt(map['allow_likes']) ?? 1) == 1,
      canManage: canManage,
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

  Future<List<GroupContentApprovalSetting>> fetchContentApprovalSettings({
    required int groupId,
  }) async {
    final result = await _apiClient.get<JsonMap>(
      '/api/new/groups/$groupId/content-approval-settings',
      decoder: asJsonMap,
    );
    return asJsonMapList(
      asJsonMap(result.rawData)['settings'],
    ).map(GroupContentApprovalSetting.fromMap).toList(growable: false);
  }

  Future<ApiResult<dynamic>> updateContentApprovalSetting({
    required int groupId,
    required String entityType,
    required bool approvalRequired,
  }) {
    return _apiClient.put<dynamic>(
      '/api/new/groups/$groupId/content-approval-settings',
      body: {'entity_type': entityType, 'approval_required': approvalRequired},
    );
  }

  Future<List<GroupContentApprovalItem>> fetchContentApprovals({
    required int groupId,
  }) async {
    final result = await _apiClient.get<JsonMap>(
      '/api/new/groups/$groupId/approvals',
      decoder: asJsonMap,
    );
    return asJsonMapList(
      asJsonMap(result.rawData)['items'],
    ).map(GroupContentApprovalItem.fromMap).toList(growable: false);
  }

  Future<ApiResult<dynamic>> reviewContentApproval({
    required int groupId,
    required String entityType,
    required int entityId,
    required String status,
    String note = '',
  }) {
    return _apiClient.post<dynamic>(
      '/api/new/groups/$groupId/approvals/$entityType/$entityId/review',
      body: {'status': status, if (note.trim().isNotEmpty) 'note': note.trim()},
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
    bool showInFeed = true,
  }) {
    return _apiClient.post<dynamic>(
      '/api/new/groups/$groupId/events',
      body: {
        'title': title,
        'description': description,
        'location': location,
        'starts_at': startsAt,
        'ends_at': endsAt,
        'show_in_feed': showInFeed ? '1' : '0',
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
    bool showInFeed = true,
  }) {
    return _apiClient.post<dynamic>(
      '/api/new/groups/$groupId/announcements',
      body: {
        'title': title,
        'body': body,
        'show_in_feed': showInFeed ? '1' : '0',
      },
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

  Future<GroupEventDetail?> fetchGroupEventDetail({
    required int groupId,
    required int eventId,
    required bool canManage,
  }) async {
    final result = await _apiClient.get<JsonMap>(
      '/api/new/groups/$groupId/events/$eventId',
      decoder: asJsonMap,
    );
    final map = asJsonMap(result.rawData);
    if (map.isEmpty) return null;
    return GroupEventDetail.fromMap(map, canManage: canManage);
  }

  Future<ApiResult<dynamic>> addGroupEventComment({
    required int groupId,
    required int eventId,
    required String comment,
  }) {
    return _apiClient.post<dynamic>(
      '/api/new/groups/$groupId/events/$eventId/comments',
      body: {'comment': comment},
    );
  }

  Future<ApiResult<dynamic>> toggleGroupEventLike({
    required int groupId,
    required int eventId,
  }) {
    return _apiClient.post<dynamic>(
      '/api/new/groups/$groupId/events/$eventId/like',
    );
  }

  Future<ApiResult<dynamic>> setGroupEventInteractions({
    required int groupId,
    required int eventId,
    bool? allowComments,
    bool? allowLikes,
  }) {
    return _apiClient.post<dynamic>(
      '/api/new/groups/$groupId/events/$eventId/interactions',
      body: {'allowComments': ?allowComments, 'allowLikes': ?allowLikes},
    );
  }

  Future<GroupAnnouncementDetail?> fetchGroupAnnouncementDetail({
    required int groupId,
    required int announcementId,
    required bool canManage,
  }) async {
    final result = await _apiClient.get<JsonMap>(
      '/api/new/groups/$groupId/announcements/$announcementId',
      decoder: asJsonMap,
    );
    final map = asJsonMap(result.rawData);
    if (map.isEmpty) return null;
    return GroupAnnouncementDetail.fromMap(map, canManage: canManage);
  }

  Future<ApiResult<dynamic>> addGroupAnnouncementComment({
    required int groupId,
    required int announcementId,
    required String comment,
  }) {
    return _apiClient.post<dynamic>(
      '/api/new/groups/$groupId/announcements/$announcementId/comments',
      body: {'comment': comment},
    );
  }

  Future<ApiResult<dynamic>> toggleGroupAnnouncementLike({
    required int groupId,
    required int announcementId,
  }) {
    return _apiClient.post<dynamic>(
      '/api/new/groups/$groupId/announcements/$announcementId/like',
    );
  }

  Future<ApiResult<dynamic>> setGroupAnnouncementInteractions({
    required int groupId,
    required int announcementId,
    bool? allowComments,
    bool? allowLikes,
  }) {
    return _apiClient.post<dynamic>(
      '/api/new/groups/$groupId/announcements/$announcementId/interactions',
      body: {'allowComments': ?allowComments, 'allowLikes': ?allowLikes},
    );
  }
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

final groupContentApprovalSettingsProvider = FutureProvider.autoDispose
    .family<List<GroupContentApprovalSetting>, int>((ref, groupId) {
      return ref
          .watch(groupsRepositoryProvider)
          .fetchContentApprovalSettings(groupId: groupId);
    });

final groupContentApprovalsProvider = FutureProvider.autoDispose
    .family<List<GroupContentApprovalItem>, int>((ref, groupId) {
      return ref
          .watch(groupsRepositoryProvider)
          .fetchContentApprovals(groupId: groupId);
    });

final groupPostsProvider = FutureProvider.autoDispose
    .family<List<GroupPost>, int>((ref, groupId) {
      return ref
          .watch(groupsRepositoryProvider)
          .fetchGroupPosts(groupId: groupId)
          .then((value) => value.items);
    });
