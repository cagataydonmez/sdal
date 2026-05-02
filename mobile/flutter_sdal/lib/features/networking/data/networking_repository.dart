import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/providers.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_result.dart';
import '../../../core/network/json_utils.dart';

class NetworkingTelemetryEvent {
  const NetworkingTelemetryEvent({
    required this.eventName,
    required this.sourceSurface,
    this.targetUserId,
    this.entityType = '',
    this.entityId,
    this.metadata,
  });

  final String eventName;
  final String sourceSurface;
  final int? targetUserId;
  final String entityType;
  final int? entityId;
  final Map<String, dynamic>? metadata;

  JsonMap toJson() => <String, dynamic>{
    'event_name': eventName,
    'source_surface': sourceSurface,
    if (targetUserId != null) 'target_user_id': targetUserId,
    if (entityType.trim().isNotEmpty) 'entity_type': entityType,
    if (entityId != null) 'entity_id': entityId,
    if (metadata != null && metadata!.isNotEmpty) 'metadata': metadata,
  };
}

class NetworkMetricsPayload {
  const NetworkMetricsPayload({
    required this.window,
    required this.connectionsRequested,
    required this.connectionsAccepted,
    required this.connectionsPendingIncoming,
    required this.connectionsPendingOutgoing,
    required this.mentorshipRequested,
    required this.mentorshipAccepted,
    required this.teacherLinksCreated,
    required this.timeToFirstNetworkSuccessDays,
  });

  final String window;
  final int connectionsRequested;
  final int connectionsAccepted;
  final int connectionsPendingIncoming;
  final int connectionsPendingOutgoing;
  final int mentorshipRequested;
  final int mentorshipAccepted;
  final int teacherLinksCreated;
  final int? timeToFirstNetworkSuccessDays;

  factory NetworkMetricsPayload.fromMap(JsonMap map) {
    final payload = asJsonMap(map['data']).isEmpty
        ? map
        : asJsonMap(map['data']);
    final metrics = asJsonMap(payload['metrics']);
    final connections = asJsonMap(metrics['connections']);
    final mentorship = asJsonMap(metrics['mentorship']);
    final teacherLinks = asJsonMap(metrics['teacherLinks']);
    return NetworkMetricsPayload(
      window: coalesceText([payload['window']], fallback: '30d'),
      connectionsRequested: asInt(connections['requested']) ?? 0,
      connectionsAccepted: asInt(connections['accepted']) ?? 0,
      connectionsPendingIncoming: asInt(connections['pending_incoming']) ?? 0,
      connectionsPendingOutgoing: asInt(connections['pending_outgoing']) ?? 0,
      mentorshipRequested: asInt(mentorship['requested']) ?? 0,
      mentorshipAccepted: asInt(mentorship['accepted']) ?? 0,
      teacherLinksCreated: asInt(teacherLinks['created']) ?? 0,
      timeToFirstNetworkSuccessDays: asInt(
        metrics['time_to_first_network_success_days'],
      ),
    );
  }
}

class NetworkMemberRef {
  const NetworkMemberRef({
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

  factory NetworkMemberRef.fromMap(JsonMap map) {
    return NetworkMemberRef(
      id:
          asInt(map['peer_id']) ??
          asInt(map['source_user_id']) ??
          asInt(map['id']) ??
          0,
      name: coalesceText([
        map['isim'],
        map['name'],
        map['kadi'],
      ], fallback: 'SDAL Üyesi'),
      handle: coalesceText([map['kadi']], fallback: ''),
      photo: coalesceText([map['resim'], map['photo']], fallback: ''),
      verified: asBool(map['verified']) ?? false,
    );
  }
}

class NetworkRequestItem {
  const NetworkRequestItem({
    required this.id,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.member,
    this.focusArea = '',
    this.message = '',
  });

  final int id;
  final String status;
  final String createdAt;
  final String updatedAt;
  final NetworkMemberRef member;
  final String focusArea;
  final String message;

  factory NetworkRequestItem.fromMap(JsonMap map) {
    return NetworkRequestItem(
      id: asInt(map['id']) ?? 0,
      status: coalesceText([map['status']], fallback: ''),
      createdAt: coalesceText([
        map['created_at'],
        map['createdAt'],
      ], fallback: ''),
      updatedAt: coalesceText([
        map['updated_at'],
        map['updatedAt'],
      ], fallback: ''),
      member: NetworkMemberRef.fromMap(map),
      focusArea: coalesceText([map['focus_area']], fallback: ''),
      message: coalesceText([map['message']], fallback: ''),
    );
  }
}

enum NetworkRequestDirection {
  incoming('incoming'),
  outgoing('outgoing');

  const NetworkRequestDirection(this.apiValue);
  final String apiValue;
}

enum ConnectionRequestStatus {
  pending('pending'),
  accepted('accepted'),
  ignored('ignored');

  const ConnectionRequestStatus(this.apiValue);
  final String apiValue;
}

enum MentorshipRequestStatus {
  requested('requested'),
  accepted('accepted'),
  declined('declined'),
  cancelled('cancelled');

  const MentorshipRequestStatus(this.apiValue);
  final String apiValue;
}

class ConnectionRequestQuery {
  const ConnectionRequestQuery({
    required this.direction,
    required this.status,
    this.limit = 30,
    this.offset = 0,
  });

  final NetworkRequestDirection direction;
  final ConnectionRequestStatus status;
  final int limit;
  final int offset;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConnectionRequestQuery &&
          runtimeType == other.runtimeType &&
          direction == other.direction &&
          status == other.status &&
          limit == other.limit &&
          offset == other.offset;

  @override
  int get hashCode => Object.hash(direction, status, limit, offset);
}

class MentorshipRequestQuery {
  const MentorshipRequestQuery({
    required this.direction,
    required this.status,
    this.limit = 30,
    this.offset = 0,
  });

  final NetworkRequestDirection direction;
  final MentorshipRequestStatus status;
  final int limit;
  final int offset;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MentorshipRequestQuery &&
          runtimeType == other.runtimeType &&
          direction == other.direction &&
          status == other.status &&
          limit == other.limit &&
          offset == other.offset;

  @override
  int get hashCode => Object.hash(direction, status, limit, offset);
}

class TeacherLinkEvent {
  const TeacherLinkEvent({
    required this.id,
    required this.message,
    required this.createdAt,
    required this.readAt,
    required this.member,
  });

  final int id;
  final String message;
  final String createdAt;
  final String readAt;
  final NetworkMemberRef member;

  bool get isUnread => readAt.isEmpty;

  factory TeacherLinkEvent.fromMap(JsonMap map) {
    return TeacherLinkEvent(
      id: asInt(map['id']) ?? 0,
      message: coalesceText([
        map['message'],
      ], fallback: 'Yeni öğretmen bağlantısı bildirimi.'),
      createdAt: coalesceText([map['created_at']], fallback: ''),
      readAt: coalesceText([map['read_at']], fallback: ''),
      member: NetworkMemberRef.fromMap(map),
    );
  }
}

class TeacherOption {
  const TeacherOption({
    required this.id,
    required this.name,
    required this.handle,
    required this.photo,
    required this.studentCount,
    required this.existingLinkCount,
  });

  final int id;
  final String name;
  final String handle;
  final String photo;
  final int studentCount;
  final int existingLinkCount;

  factory TeacherOption.fromMap(JsonMap map) {
    return TeacherOption(
      id: asInt(map['id']) ?? 0,
      name: coalesceText([map['isim'], map['kadi']], fallback: 'Öğretmen'),
      handle: coalesceText([map['kadi']], fallback: ''),
      photo: coalesceText([map['resim']], fallback: ''),
      studentCount: asInt(map['student_count']) ?? 0,
      existingLinkCount: asInt(map['existing_link_count']) ?? 0,
    );
  }
}

class TeacherLinkRecord {
  const TeacherLinkRecord({
    required this.id,
    required this.relationshipType,
    required this.classYear,
    required this.notes,
    required this.member,
  });

  final int id;
  final String relationshipType;
  final String classYear;
  final String notes;
  final NetworkMemberRef member;

  factory TeacherLinkRecord.fromMap(JsonMap map) {
    return TeacherLinkRecord(
      id: asInt(map['id']) ?? 0,
      relationshipType: coalesceText([map['relationship_type']], fallback: ''),
      classYear: coalesceText([map['class_year']], fallback: ''),
      notes: coalesceText([map['notes']], fallback: ''),
      member: NetworkMemberRef.fromMap(map),
    );
  }
}

class NetworkDiscoverySuggestion {
  const NetworkDiscoverySuggestion({
    required this.id,
    required this.name,
    required this.handle,
    required this.city,
    required this.profession,
    required this.photo,
    required this.verified,
    required this.following,
  });

  final int id;
  final String name;
  final String handle;
  final String city;
  final String profession;
  final String photo;
  final bool verified;
  final bool following;

  factory NetworkDiscoverySuggestion.fromMap(JsonMap map) {
    return NetworkDiscoverySuggestion(
      id: asInt(map['id']) ?? 0,
      name: coalesceText([
        map['isim'],
        map['name'],
        map['kadi'],
      ], fallback: 'SDAL Üyesi'),
      handle: coalesceText([map['kadi']], fallback: ''),
      city: coalesceText([map['sehir'], map['city']], fallback: ''),
      profession: coalesceText([
        map['meslek'],
        map['profession'],
      ], fallback: ''),
      photo: coalesceText([map['resim'], map['photo']], fallback: ''),
      verified: asBool(map['verified']) ?? false,
      following: asBool(map['following']) ?? false,
    );
  }
}

class NetworkHubPayload {
  const NetworkHubPayload({
    required this.actionableCount,
    required this.incomingConnections,
    required this.outgoingConnections,
    required this.incomingMentorship,
    required this.outgoingMentorship,
    required this.teacherEvents,
    required this.discoverySuggestions,
  });

  final int actionableCount;
  final List<NetworkRequestItem> incomingConnections;
  final List<NetworkRequestItem> outgoingConnections;
  final List<NetworkRequestItem> incomingMentorship;
  final List<NetworkRequestItem> outgoingMentorship;
  final List<TeacherLinkEvent> teacherEvents;
  final List<NetworkDiscoverySuggestion> discoverySuggestions;

  factory NetworkHubPayload.fromMap(JsonMap map) {
    final hub = asJsonMap(map['hub']);
    final inbox = asJsonMap(hub['inbox']);
    final connections = asJsonMap(inbox['connections']);
    final mentorship = asJsonMap(inbox['mentorship']);
    final teacherLinks = asJsonMap(inbox['teacherLinks']);
    final discovery = asJsonMap(hub['discovery']);

    return NetworkHubPayload(
      actionableCount: asInt(asJsonMap(hub['counts'])['actionable']) ?? 0,
      incomingConnections: asJsonMapList(
        connections['incoming'],
      ).map(NetworkRequestItem.fromMap).toList(growable: false),
      outgoingConnections: asJsonMapList(
        connections['outgoing'],
      ).map(NetworkRequestItem.fromMap).toList(growable: false),
      incomingMentorship: asJsonMapList(
        mentorship['incoming'],
      ).map(NetworkRequestItem.fromMap).toList(growable: false),
      outgoingMentorship: asJsonMapList(
        mentorship['outgoing'],
      ).map(NetworkRequestItem.fromMap).toList(growable: false),
      teacherEvents: asJsonMapList(
        teacherLinks['events'],
      ).map(TeacherLinkEvent.fromMap).toList(growable: false),
      discoverySuggestions: asJsonMapList(
        discovery['suggestions'],
      ).map(NetworkDiscoverySuggestion.fromMap).toList(growable: false),
    );
  }
}

class NetworkInboxPayload {
  const NetworkInboxPayload({
    required this.incomingConnections,
    required this.outgoingConnections,
    required this.incomingMentorship,
    required this.outgoingMentorship,
    required this.teacherEvents,
  });

  final List<NetworkRequestItem> incomingConnections;
  final List<NetworkRequestItem> outgoingConnections;
  final List<NetworkRequestItem> incomingMentorship;
  final List<NetworkRequestItem> outgoingMentorship;
  final List<TeacherLinkEvent> teacherEvents;

  factory NetworkInboxPayload.fromMap(JsonMap map) {
    final inbox = asJsonMap(map['inbox']);
    final connections = asJsonMap(inbox['connections']);
    final mentorship = asJsonMap(inbox['mentorship']);
    final teacherLinks = asJsonMap(inbox['teacherLinks']);
    return NetworkInboxPayload(
      incomingConnections: asJsonMapList(
        connections['incoming'],
      ).map(NetworkRequestItem.fromMap).toList(growable: false),
      outgoingConnections: asJsonMapList(
        connections['outgoing'],
      ).map(NetworkRequestItem.fromMap).toList(growable: false),
      incomingMentorship: asJsonMapList(
        mentorship['incoming'],
      ).map(NetworkRequestItem.fromMap).toList(growable: false),
      outgoingMentorship: asJsonMapList(
        mentorship['outgoing'],
      ).map(NetworkRequestItem.fromMap).toList(growable: false),
      teacherEvents: asJsonMapList(
        teacherLinks['events'],
      ).map(TeacherLinkEvent.fromMap).toList(growable: false),
    );
  }
}

class NetworkingRepository {
  const NetworkingRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<NetworkHubPayload> fetchHub() async {
    final result = await _apiClient.get<JsonMap>(
      '/api/new/network/hub',
      decoder: asJsonMap,
    );
    return NetworkHubPayload.fromMap(asJsonMap(result.rawData));
  }

  Future<NetworkInboxPayload> fetchInbox() async {
    final result = await _apiClient.get<JsonMap>(
      '/api/new/network/inbox',
      decoder: asJsonMap,
    );
    return NetworkInboxPayload.fromMap(asJsonMap(result.rawData));
  }

  Future<List<NetworkRequestItem>> fetchConnectionRequests(
    ConnectionRequestQuery query,
  ) async {
    final result = await _apiClient.get<JsonMap>(
      '/api/new/connections/requests',
      query: {
        'direction': query.direction.apiValue,
        'status': query.status.apiValue,
        'limit': query.limit,
        'offset': query.offset,
      },
      decoder: asJsonMap,
    );
    final payload = asJsonMap(result.rawData);
    final data = asJsonMap(payload['data']).isEmpty
        ? payload
        : asJsonMap(payload['data']);
    return asJsonMapList(
      data['items'],
    ).map(NetworkRequestItem.fromMap).toList(growable: false);
  }

  Future<List<NetworkRequestItem>> fetchMentorshipRequests(
    MentorshipRequestQuery query,
  ) async {
    final result = await _apiClient.get<JsonMap>(
      '/api/new/mentorship/requests',
      query: {
        'direction': query.direction.apiValue,
        'status': query.status.apiValue,
        'limit': query.limit,
        'offset': query.offset,
      },
      decoder: asJsonMap,
    );
    final payload = asJsonMap(result.rawData);
    final data = asJsonMap(payload['data']).isEmpty
        ? payload
        : asJsonMap(payload['data']);
    return asJsonMapList(
      data['items'],
    ).map(NetworkRequestItem.fromMap).toList(growable: false);
  }

  Future<NetworkMetricsPayload> fetchMetrics({String window = '30d'}) async {
    final result = await _apiClient.get<JsonMap>(
      '/api/new/network/metrics',
      query: {'window': window},
      decoder: asJsonMap,
    );
    return NetworkMetricsPayload.fromMap(asJsonMap(result.rawData));
  }

  Future<List<TeacherLinkRecord>> fetchTeacherLinks() async {
    final result = await _apiClient.get<JsonMap>(
      '/api/new/teachers/network',
      decoder: asJsonMap,
    );
    final items = asJsonMapList(asJsonMap(result.rawData)['items']);
    return items.map(TeacherLinkRecord.fromMap).toList(growable: false);
  }

  Future<List<TeacherOption>> searchTeacherOptions(
    String term, {
    int? includeId,
  }) async {
    final queryText = term.trim();
    final result = await _apiClient.get<JsonMap>(
      '/api/new/teachers/options',
      query: {
        if (queryText.isNotEmpty) 'q': queryText,
        if (queryText.isNotEmpty) 'term': queryText,
        'limit': 12,
        if ((includeId ?? 0) > 0) 'include_id': includeId,
      },
      decoder: asJsonMap,
    );
    final items = asJsonMapList(asJsonMap(result.rawData)['items']);
    return items.map(TeacherOption.fromMap).toList(growable: false);
  }

  Future<ApiResult<dynamic>> requestConnection(int memberId) {
    return _apiClient.post<dynamic>(
      '/api/new/connections/request/$memberId',
      body: const {'source_surface': 'flutter_network_hub'},
    );
  }

  Future<ApiResult<dynamic>> acceptConnection(int requestId) {
    return _apiClient.post<dynamic>(
      '/api/new/connections/accept/$requestId',
      body: const {'source_surface': 'flutter_network_inbox'},
    );
  }

  Future<ApiResult<dynamic>> ignoreConnection(int requestId) {
    return _apiClient.post<dynamic>(
      '/api/new/connections/ignore/$requestId',
      body: const {'source_surface': 'flutter_network_inbox'},
    );
  }

  Future<ApiResult<dynamic>> cancelConnection(int requestId) {
    return _apiClient.post<dynamic>(
      '/api/new/connections/cancel/$requestId',
      body: const {'source_surface': 'flutter_network_inbox'},
    );
  }

  Future<ApiResult<dynamic>> requestMentorship({
    required int memberId,
    String focusArea = '',
    String message = '',
  }) {
    return _apiClient.post<dynamic>(
      '/api/new/mentorship/request/$memberId',
      body: {
        'focus_area': focusArea,
        'message': message,
        'source_surface': 'flutter_network_hub',
      },
    );
  }

  Future<ApiResult<dynamic>> acceptMentorship(int requestId) {
    return _apiClient.post<dynamic>(
      '/api/new/mentorship/accept/$requestId',
      body: const {'source_surface': 'flutter_network_inbox'},
    );
  }

  Future<ApiResult<dynamic>> declineMentorship(int requestId) {
    return _apiClient.post<dynamic>(
      '/api/new/mentorship/decline/$requestId',
      body: const {'source_surface': 'flutter_network_inbox'},
    );
  }

  Future<ApiResult<dynamic>> markTeacherLinksRead() {
    return _apiClient.post<dynamic>(
      '/api/new/network/inbox/teacher-links/read',
      body: const {'source_surface': 'flutter_network_inbox'},
    );
  }

  Future<ApiResult<dynamic>> createTeacherLink({
    required int teacherId,
    required String relationshipType,
    String classYear = '',
    String notes = '',
    bool confirmSimilar = false,
  }) {
    return _apiClient.post<dynamic>(
      '/api/new/teachers/network/link/$teacherId',
      body: {
        'relationship_type': relationshipType,
        'class_year': classYear,
        'notes': notes,
        'confirm_similar': confirmSimilar,
        'source_surface': 'flutter_teacher_links',
        'created_via': 'manual_alumni_link',
      },
    );
  }

  Future<ApiResult<JsonMap>> trackTelemetry(NetworkingTelemetryEvent event) {
    return _apiClient.post<JsonMap>(
      '/api/new/network/telemetry',
      body: event.toJson(),
      decoder: asJsonMap,
    );
  }
}

final networkingRepositoryProvider = Provider<NetworkingRepository>(
  (ref) => NetworkingRepository(ref.watch(apiClientProvider)),
);

final networkHubProvider = FutureProvider.autoDispose<NetworkHubPayload>(
  (ref) => ref.watch(networkingRepositoryProvider).fetchHub(),
);

final networkInboxProvider = FutureProvider.autoDispose<NetworkInboxPayload>(
  (ref) => ref.watch(networkingRepositoryProvider).fetchInbox(),
);

final connectionRequestsProvider = FutureProvider.autoDispose
    .family<List<NetworkRequestItem>, ConnectionRequestQuery>(
      (ref, query) => ref
          .watch(networkingRepositoryProvider)
          .fetchConnectionRequests(query),
    );

final mentorshipRequestsProvider = FutureProvider.autoDispose
    .family<List<NetworkRequestItem>, MentorshipRequestQuery>(
      (ref, query) => ref
          .watch(networkingRepositoryProvider)
          .fetchMentorshipRequests(query),
    );

final networkMetricsProvider =
    FutureProvider.autoDispose<NetworkMetricsPayload>(
      (ref) => ref.watch(networkingRepositoryProvider).fetchMetrics(),
    );

final teacherLinksProvider =
    FutureProvider.autoDispose<List<TeacherLinkRecord>>(
      (ref) => ref.watch(networkingRepositoryProvider).fetchTeacherLinks(),
    );

final teacherOptionsProvider =
    FutureProvider.family<List<TeacherOption>, String>((ref, term) {
      return ref.watch(networkingRepositoryProvider).searchTeacherOptions(term);
    });
