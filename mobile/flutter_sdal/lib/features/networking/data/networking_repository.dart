import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/providers.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_result.dart';
import '../../../core/network/json_utils.dart';

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
  });

  final int id;
  final String name;
  final String handle;
  final String city;
  final String profession;
  final String photo;
  final bool verified;

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

  Future<List<TeacherLinkRecord>> fetchTeacherLinks() async {
    final result = await _apiClient.get<JsonMap>(
      '/api/new/teachers/network',
      decoder: asJsonMap,
    );
    final payload = asJsonMap(result.rawData);
    final items = asJsonMapList(asJsonMap(payload['data'])['items']);
    return items.map(TeacherLinkRecord.fromMap).toList(growable: false);
  }

  Future<List<TeacherOption>> searchTeacherOptions(String term) async {
    final result = await _apiClient.get<JsonMap>(
      '/api/new/teachers/options',
      query: {'term': term, 'limit': 12},
      decoder: asJsonMap,
    );
    final items = asJsonMapList(
      asJsonMap(asJsonMap(result.rawData)['data'])['items'],
    );
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

final teacherLinksProvider =
    FutureProvider.autoDispose<List<TeacherLinkRecord>>(
      (ref) => ref.watch(networkingRepositoryProvider).fetchTeacherLinks(),
    );

final teacherOptionsProvider = FutureProvider.autoDispose
    .family<List<TeacherOption>, String>((ref, term) {
      if (term.trim().isEmpty) return Future.value(const <TeacherOption>[]);
      return ref.watch(networkingRepositoryProvider).searchTeacherOptions(term);
    });
