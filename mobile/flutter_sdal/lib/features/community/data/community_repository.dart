import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/providers.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_result.dart';
import '../../../core/network/json_utils.dart';

class AnnouncementItem {
  const AnnouncementItem({
    required this.id,
    required this.title,
    required this.body,
    required this.image,
    required this.createdAt,
    required this.updatedAt,
    required this.creatorHandle,
    required this.createdBy,
    required this.approved,
    required this.publicationStatus,
    required this.approvalStatus,
    required this.showInFeed,
    required this.reviewNote,
  });

  final int id;
  final String title;
  final String body;
  final String image;
  final String createdAt;
  final String updatedAt;
  final String creatorHandle;
  final int createdBy;
  final bool approved;
  final String publicationStatus;
  final String approvalStatus;
  final bool showInFeed;
  final String reviewNote;

  bool get isEdited => updatedAt.isNotEmpty;
  bool get isPublished => publicationStatus == 'published' || approved;
  bool get isDraft => publicationStatus == 'draft';
  bool get isPendingApproval => approvalStatus == 'pending';

  factory AnnouncementItem.fromMap(JsonMap map) {
    return AnnouncementItem(
      id: asInt(map['id']) ?? 0,
      title: coalesceText([map['title']], fallback: 'Duyuru'),
      body: coalesceText([map['body']], fallback: ''),
      image: coalesceText([map['image']], fallback: ''),
      createdAt: coalesceText([map['created_at']], fallback: ''),
      updatedAt: coalesceText([map['updated_at']], fallback: ''),
      creatorHandle: coalesceText([map['creator_kadi']], fallback: ''),
      createdBy: asInt(map['created_by']) ?? 0,
      approved: asBool(map['approved']) ?? true,
      publicationStatus: coalesceText(
        [map['publication_status']],
        fallback: (asBool(map['approved']) ?? true)
            ? 'published'
            : 'pending_publication',
      ),
      approvalStatus: coalesceText([
        map['approval_status'],
      ], fallback: 'not_required'),
      showInFeed: asBool(map['show_in_feed']) ?? true,
      reviewNote: coalesceText([map['review_note']], fallback: ''),
    );
  }
}

class EventVisibility {
  const EventVisibility({
    required this.showCounts,
    required this.showAttendeeNames,
    required this.showDeclinerNames,
  });

  final bool showCounts;
  final bool showAttendeeNames;
  final bool showDeclinerNames;

  factory EventVisibility.fromMap(JsonMap map) {
    return EventVisibility(
      showCounts:
          asBool(map['showCounts']) ??
          asBool(map['show_response_counts']) ??
          false,
      showAttendeeNames:
          asBool(map['showAttendeeNames']) ??
          asBool(map['show_attendee_names']) ??
          false,
      showDeclinerNames:
          asBool(map['showDeclinerNames']) ??
          asBool(map['show_decliner_names']) ??
          false,
    );
  }
}

class EventItem {
  const EventItem({
    required this.id,
    required this.title,
    required this.description,
    required this.location,
    required this.image,
    required this.createdAt,
    required this.updatedAt,
    required this.startsAt,
    required this.endsAt,
    required this.createdBy,
    required this.creatorHandle,
    required this.approved,
    required this.myResponse,
    required this.attendCount,
    required this.declineCount,
    required this.canManageResponses,
    required this.visibility,
    required this.publicationStatus,
    required this.approvalStatus,
    required this.showInFeed,
    required this.reviewNote,
  });

  final int id;
  final String title;
  final String description;
  final String location;
  final String image;
  final String createdAt;
  final String updatedAt;
  final String startsAt;
  final String endsAt;
  final int createdBy;
  final String creatorHandle;
  final bool approved;
  final String myResponse;
  final int attendCount;
  final int declineCount;
  final bool canManageResponses;
  final EventVisibility visibility;
  final String publicationStatus;
  final String approvalStatus;
  final bool showInFeed;
  final String reviewNote;

  bool get isEdited => updatedAt.isNotEmpty;
  bool get isPublished => publicationStatus == 'published' || approved;
  bool get isDraft => publicationStatus == 'draft';
  bool get isPendingApproval => approvalStatus == 'pending';

  factory EventItem.fromMap(JsonMap map) {
    final counts = asJsonMap(map['response_counts']);
    return EventItem(
      id: asInt(map['id']) ?? 0,
      title: coalesceText([map['title']], fallback: 'Etkinlik'),
      description: coalesceText([map['description']], fallback: ''),
      location: coalesceText([map['location']], fallback: ''),
      image: coalesceText([map['image']], fallback: ''),
      createdAt: coalesceText([map['created_at']], fallback: ''),
      updatedAt: coalesceText([map['updated_at']], fallback: ''),
      startsAt: coalesceText([map['starts_at']], fallback: ''),
      endsAt: coalesceText([map['ends_at']], fallback: ''),
      createdBy: asInt(map['created_by']) ?? 0,
      creatorHandle: coalesceText([map['creator_kadi']], fallback: ''),
      approved: asBool(map['approved']) ?? true,
      myResponse: coalesceText([map['my_response']], fallback: ''),
      attendCount: asInt(counts['attend']) ?? 0,
      declineCount: asInt(counts['decline']) ?? 0,
      canManageResponses: asBool(map['can_manage_responses']) ?? false,
      visibility: EventVisibility.fromMap(
        asJsonMap(map['response_visibility']),
      ),
      publicationStatus: coalesceText(
        [map['publication_status']],
        fallback: (asBool(map['approved']) ?? true)
            ? 'published'
            : 'pending_publication',
      ),
      approvalStatus: coalesceText([
        map['approval_status'],
      ], fallback: 'not_required'),
      showInFeed: asBool(map['show_in_feed']) ?? true,
      reviewNote: coalesceText([map['review_note']], fallback: ''),
    );
  }
}

class EventComment {
  const EventComment({
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

  factory EventComment.fromMap(JsonMap map) {
    return EventComment(
      id: asInt(map['id']) ?? 0,
      comment: coalesceText([map['comment']], fallback: ''),
      createdAt: coalesceText([map['created_at']], fallback: ''),
      userId: asInt(map['user_id']) ?? 0,
      handle: coalesceText([map['kadi']], fallback: ''),
      displayName: coalesceText([
        '${asString(map['isim']) ?? ''} ${asString(map['soyisim']) ?? ''}'
            .trim(),
        map['kadi'],
      ], fallback: 'SDAL Üyesi'),
      photo: coalesceText([map['resim']], fallback: ''),
      verified: asBool(map['verified']) ?? false,
    );
  }
}

class EntityComment {
  const EntityComment({
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

  factory EntityComment.fromMap(JsonMap map) {
    final first = coalesceText([map['isim']], fallback: '');
    final last = coalesceText([map['soyisim']], fallback: '');
    final fullName = '$first $last'.trim();
    final handle = coalesceText([map['kadi']], fallback: '');
    return EntityComment(
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

class AnnouncementDetail {
  const AnnouncementDetail({
    required this.item,
    required this.comments,
    required this.likeCount,
    required this.liked,
    required this.allowComments,
    required this.allowLikes,
  });

  final AnnouncementItem item;
  final List<EntityComment> comments;
  final int likeCount;
  final bool liked;
  final bool allowComments;
  final bool allowLikes;

  factory AnnouncementDetail.fromMap(JsonMap map) {
    return AnnouncementDetail(
      item: AnnouncementItem.fromMap(map),
      comments: asJsonMapList(
        map['comments'],
      ).map(EntityComment.fromMap).toList(growable: false),
      likeCount: asInt(map['like_count']) ?? 0,
      liked: asBool(map['liked']) ?? false,
      allowComments: (asInt(map['allow_comments']) ?? 1) == 1,
      allowLikes: (asInt(map['allow_likes']) ?? 1) == 1,
    );
  }
}

class EventDetail {
  const EventDetail({
    required this.item,
    required this.comments,
    required this.likeCount,
    required this.liked,
    required this.allowComments,
    required this.allowLikes,
  });

  final EventItem item;
  final List<EntityComment> comments;
  final int likeCount;
  final bool liked;
  final bool allowComments;
  final bool allowLikes;

  factory EventDetail.fromMap(JsonMap map) {
    return EventDetail(
      item: EventItem.fromMap(map),
      comments: asJsonMapList(
        map['comments'],
      ).map(EntityComment.fromMap).toList(growable: false),
      likeCount: asInt(map['like_count']) ?? 0,
      liked: asBool(map['liked']) ?? false,
      allowComments: (asInt(map['allow_comments']) ?? 1) == 1,
      allowLikes: (asInt(map['allow_likes']) ?? 1) == 1,
    );
  }
}

class CommunityPageData<T> {
  const CommunityPageData({required this.items, required this.hasMore});

  final List<T> items;
  final bool hasMore;
}

class CommunityRepository {
  const CommunityRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<CommunityPageData<AnnouncementItem>> fetchAnnouncements({
    int limit = 15,
    int offset = 0,
    bool? approved,
    String status = '',
  }) async {
    final query = <String, dynamic>{'limit': limit, 'offset': offset};
    if (status.isNotEmpty) {
      query['status'] = status;
    } else if (approved != null) {
      query['approved'] = approved ? '1' : '0';
    }
    final result = await _apiClient.get<JsonMap>(
      '/api/new/announcements',
      query: query,
      decoder: asJsonMap,
    );
    final payload = asJsonMap(result.rawData);
    return CommunityPageData(
      items: asJsonMapList(
        payload['items'],
      ).map(AnnouncementItem.fromMap).toList(growable: false),
      hasMore: asBool(payload['hasMore']) ?? false,
    );
  }

  Future<ApiResult<dynamic>> createAnnouncement({
    required String title,
    required String body,
    File? imageFile,
    bool showInFeed = true,
    bool publish = true,
  }) {
    final fields = <String, dynamic>{
      'title': title,
      'body': body,
      'show_in_feed': showInFeed ? '1' : '0',
      'publish': publish ? '1' : '0',
    };
    if (imageFile != null) {
      return _apiClient.multipart<dynamic>(
        '/api/new/announcements/upload',
        files: {'image': imageFile},
        fields: fields,
      );
    }
    return _apiClient.post<dynamic>('/api/new/announcements', body: fields);
  }

  Future<ApiResult<dynamic>> approveAnnouncement({
    required int announcementId,
    required bool approved,
  }) {
    return _apiClient.post<dynamic>(
      '/api/new/announcements/$announcementId/approve',
      body: {'approved': approved ? '1' : '0'},
    );
  }

  Future<ApiResult<dynamic>> deleteAnnouncement(int announcementId) {
    return _apiClient.delete<dynamic>('/api/new/announcements/$announcementId');
  }

  Future<CommunityPageData<EventItem>> fetchEvents({
    int limit = 15,
    int offset = 0,
    bool? approved,
    String status = '',
  }) async {
    final query = <String, dynamic>{'limit': limit, 'offset': offset};
    if (status.isNotEmpty) {
      query['status'] = status;
    } else if (approved != null) {
      query['approved'] = approved ? '1' : '0';
    }
    final result = await _apiClient.get<JsonMap>(
      '/api/new/events',
      query: query,
      decoder: asJsonMap,
    );
    final payload = asJsonMap(result.rawData);
    return CommunityPageData(
      items: asJsonMapList(
        payload['items'],
      ).map(EventItem.fromMap).toList(growable: false),
      hasMore: asBool(payload['hasMore']) ?? false,
    );
  }

  Future<ApiResult<dynamic>> createEvent({
    required String title,
    required String description,
    required String location,
    required String startsAt,
    required String endsAt,
    File? imageFile,
    bool showInFeed = true,
    bool publish = true,
  }) {
    final fields = <String, dynamic>{
      'title': title,
      'description': description,
      'location': location,
      'starts_at': startsAt,
      'ends_at': endsAt,
      'show_in_feed': showInFeed ? '1' : '0',
      'publish': publish ? '1' : '0',
    };
    if (imageFile != null) {
      return _apiClient.multipart<dynamic>(
        '/api/new/events/upload',
        files: {'image': imageFile},
        fields: fields,
      );
    }
    return _apiClient.post<dynamic>('/api/new/events', body: fields);
  }

  Future<ApiResult<dynamic>> approveEvent({
    required int eventId,
    required bool approved,
  }) {
    return _apiClient.post<dynamic>(
      '/api/new/events/$eventId/approve',
      body: {'approved': approved ? '1' : '0'},
    );
  }

  Future<ApiResult<dynamic>> deleteEvent(int eventId) {
    return _apiClient.delete<dynamic>('/api/new/events/$eventId');
  }

  Future<List<EventComment>> fetchEventComments(int eventId) async {
    final result = await _apiClient.get<JsonMap>(
      '/api/new/events/$eventId/comments',
      decoder: asJsonMap,
    );
    return asJsonMapList(
      asJsonMap(result.rawData)['items'],
    ).map(EventComment.fromMap).toList(growable: false);
  }

  Future<ApiResult<dynamic>> addEventComment({
    required int eventId,
    required String comment,
  }) {
    return _apiClient.post<dynamic>(
      '/api/new/events/$eventId/comments',
      body: {'comment': comment},
    );
  }

  Future<ApiResult<dynamic>> respondToEvent({
    required int eventId,
    required String response,
  }) {
    return _apiClient.post<dynamic>(
      '/api/new/events/$eventId/respond',
      body: {'response': response},
    );
  }

  Future<ApiResult<JsonMap>> updateResponseVisibility({
    required int eventId,
    required bool showCounts,
    required bool showAttendeeNames,
    required bool showDeclinerNames,
  }) {
    return _apiClient.post<JsonMap>(
      '/api/new/events/$eventId/response-visibility',
      body: {
        'showCounts': showCounts,
        'showAttendeeNames': showAttendeeNames,
        'showDeclinerNames': showDeclinerNames,
      },
      decoder: asJsonMap,
    );
  }

  Future<ApiResult<JsonMap>> notifyEventAudience({
    required int eventId,
    required String mode,
  }) {
    return _apiClient.post<JsonMap>(
      '/api/new/events/$eventId/notify',
      body: {'mode': mode},
      decoder: asJsonMap,
    );
  }

  Future<EventDetail?> fetchEventDetail(int eventId) async {
    final result = await _apiClient.get<JsonMap>(
      '/api/new/events/$eventId',
      decoder: asJsonMap,
    );
    final map = asJsonMap(result.rawData);
    if (map.isEmpty) return null;
    return EventDetail.fromMap(map);
  }

  Future<ApiResult<dynamic>> toggleEventLike(int eventId) {
    return _apiClient.post<dynamic>('/api/new/events/$eventId/like');
  }

  Future<ApiResult<dynamic>> setEventInteractions({
    required int eventId,
    bool? allowComments,
    bool? allowLikes,
  }) {
    return _apiClient.post<dynamic>(
      '/api/new/events/$eventId/interactions',
      body: {'allowComments': ?allowComments, 'allowLikes': ?allowLikes},
    );
  }

  Future<AnnouncementDetail?> fetchAnnouncementDetail(
    int announcementId,
  ) async {
    final result = await _apiClient.get<JsonMap>(
      '/api/new/announcements/$announcementId',
      decoder: asJsonMap,
    );
    final map = asJsonMap(result.rawData);
    if (map.isEmpty) return null;
    return AnnouncementDetail.fromMap(map);
  }

  Future<ApiResult<dynamic>> addAnnouncementComment({
    required int announcementId,
    required String comment,
  }) {
    return _apiClient.post<dynamic>(
      '/api/new/announcements/$announcementId/comments',
      body: {'comment': comment},
    );
  }

  Future<ApiResult<dynamic>> toggleAnnouncementLike(int announcementId) {
    return _apiClient.post<dynamic>(
      '/api/new/announcements/$announcementId/like',
    );
  }

  Future<ApiResult<dynamic>> setAnnouncementInteractions({
    required int announcementId,
    bool? allowComments,
    bool? allowLikes,
  }) {
    return _apiClient.post<dynamic>(
      '/api/new/announcements/$announcementId/interactions',
      body: {'allowComments': ?allowComments, 'allowLikes': ?allowLikes},
    );
  }
}

final communityRepositoryProvider = Provider<CommunityRepository>(
  (ref) => CommunityRepository(ref.watch(apiClientProvider)),
);
