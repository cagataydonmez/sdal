import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/providers.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_result.dart';
import '../../../core/network/json_utils.dart';

class JobItem {
  const JobItem({
    required this.id,
    required this.posterId,
    required this.company,
    required this.title,
    required this.description,
    required this.location,
    required this.jobType,
    required this.workMode,
    required this.link,
    required this.image,
    required this.posterHandle,
    required this.createdAt,
    required this.updatedAt,
    required this.myApplicationId,
    required this.myApplicationStatus,
    required this.myApplicationDecisionNote,
    required this.showInFeed,
    required this.publicationStatus,
    required this.approvalStatus,
    required this.reviewNote,
  });

  final int id;
  final int posterId;
  final String company;
  final String title;
  final String description;
  final String location;
  final String jobType;
  final String workMode;
  final String link;
  final String image;
  final String posterHandle;
  final String createdAt;
  final String updatedAt;
  final int myApplicationId;
  final String myApplicationStatus;
  final String myApplicationDecisionNote;
  final bool showInFeed;
  final String publicationStatus;
  final String approvalStatus;
  final String reviewNote;

  bool get isEdited => updatedAt.isNotEmpty;
  bool get isPublished => publicationStatus == 'published';
  bool get isDraft => publicationStatus == 'draft';
  bool get isPendingApproval => approvalStatus == 'pending';

  factory JobItem.fromMap(JsonMap map) {
    return JobItem(
      id: asInt(map['id']) ?? 0,
      posterId: asInt(map['poster_id']) ?? 0,
      company: coalesceText([map['company']], fallback: ''),
      title: coalesceText([map['title']], fallback: 'İş ilanı'),
      description: coalesceText([map['description']], fallback: ''),
      location: coalesceText([map['location']], fallback: ''),
      jobType: coalesceText([map['job_type']], fallback: ''),
      workMode: coalesceText([map['work_mode']], fallback: ''),
      link: coalesceText([map['link']], fallback: ''),
      image: coalesceText([map['image']], fallback: ''),
      posterHandle: coalesceText([map['poster_kadi']], fallback: ''),
      createdAt: coalesceText([map['created_at']], fallback: ''),
      updatedAt: coalesceText([map['updated_at']], fallback: ''),
      myApplicationId: asInt(map['my_application_id']) ?? 0,
      myApplicationStatus: coalesceText([
        map['my_application_status'],
      ], fallback: ''),
      myApplicationDecisionNote: coalesceText([
        map['my_application_decision_note'],
      ], fallback: ''),
      showInFeed: asBool(map['show_in_feed']) ?? true,
      publicationStatus: coalesceText(
        [map['publication_status']],
        fallback: (asBool(map['show_in_feed']) ?? true) ? 'published' : 'draft',
      ),
      approvalStatus: coalesceText([
        map['approval_status'],
      ], fallback: 'not_required'),
      reviewNote: coalesceText([map['review_note']], fallback: ''),
    );
  }
}

class JobApplicationItem {
  const JobApplicationItem({
    required this.id,
    required this.jobId,
    required this.applicantId,
    required this.coverLetter,
    required this.cvLink,
    required this.contactChannel,
    required this.contactValue,
    required this.city,
    required this.createdAt,
    required this.status,
    required this.decisionNote,
    required this.handle,
    required this.displayName,
    required this.photo,
  });

  final int id;
  final int jobId;
  final int applicantId;
  final String coverLetter;
  final String cvLink;
  final String contactChannel;
  final String contactValue;
  final String city;
  final String createdAt;
  final String status;
  final String decisionNote;
  final String handle;
  final String displayName;
  final String photo;

  bool get isPending => status == 'pending';
  bool get isReviewed => status != 'pending';

  factory JobApplicationItem.fromMap(JsonMap map) {
    return JobApplicationItem(
      id: asInt(map['id']) ?? 0,
      jobId: asInt(map['job_id']) ?? 0,
      applicantId: asInt(map['applicant_id']) ?? 0,
      coverLetter: coalesceText([map['cover_letter']], fallback: ''),
      cvLink: coalesceText([map['cv_link']], fallback: ''),
      contactChannel: coalesceText([map['contact_channel']], fallback: ''),
      contactValue: coalesceText([map['contact_value']], fallback: ''),
      city: coalesceText([map['city']], fallback: ''),
      createdAt: coalesceText([map['created_at']], fallback: ''),
      status: coalesceText([map['status']], fallback: 'pending'),
      decisionNote: coalesceText([map['decision_note']], fallback: ''),
      handle: coalesceText([map['kadi']], fallback: ''),
      displayName: coalesceText([
        '${asString(map['isim']) ?? ''} ${asString(map['soyisim']) ?? ''}'
            .trim(),
        map['kadi'],
      ], fallback: 'SDAL Üyesi'),
      photo: coalesceText([map['resim']], fallback: ''),
    );
  }
}

class OpportunityItem {
  const OpportunityItem({
    required this.id,
    required this.title,
    required this.summary,
    required this.whyNow,
    required this.category,
    required this.priorityBucket,
    required this.score,
    required this.targetHref,
    required this.targetLabel,
    required this.reasons,
    required this.entityType,
    required this.entityId,
    required this.memberId,
    required this.memberFollowing,
  });

  final String id;
  final String title;
  final String summary;
  final String whyNow;
  final String category;
  final String priorityBucket;
  final double score;
  final String targetHref;
  final String targetLabel;
  final List<String> reasons;
  final String entityType;
  final int? entityId;
  final int memberId;
  final bool memberFollowing;

  bool get isMemberSuggestion => entityType == 'user' && memberId > 0;

  factory OpportunityItem.fromMap(JsonMap map) {
    final target = asJsonMap(map['target']);
    final entityType = coalesceText([map['entity_type']], fallback: '');
    final entityId = asInt(map['entity_id']);
    return OpportunityItem(
      id: coalesceText([map['id']], fallback: ''),
      title: coalesceText([map['title']], fallback: 'Fırsat'),
      summary: coalesceText([map['summary']], fallback: ''),
      whyNow: coalesceText([map['why_now']], fallback: ''),
      category: coalesceText([map['category']], fallback: 'updates'),
      priorityBucket: coalesceText([map['priority_bucket']], fallback: 'later'),
      score: (map['score'] is num)
          ? (map['score'] as num).toDouble()
          : double.tryParse('${map['score'] ?? ''}') ?? 0,
      targetHref: coalesceText([target['href']], fallback: ''),
      targetLabel: coalesceText([target['label']], fallback: 'Aç'),
      reasons: (map['reasons'] is List)
          ? (map['reasons'] as List)
                .map((item) => coalesceText([item], fallback: ''))
                .where((item) => item.isNotEmpty)
                .toList(growable: false)
          : const <String>[],
      entityType: entityType,
      entityId: entityId,
      memberId:
          asInt(map['member_id']) ?? (entityType == 'user' ? entityId ?? 0 : 0),
      memberFollowing: asBool(map['member_following']) ?? false,
    );
  }
}

class OpportunityInboxPageData {
  const OpportunityInboxPageData({
    required this.items,
    required this.hasMore,
    required this.nextCursor,
  });

  final List<OpportunityItem> items;
  final bool hasMore;
  final String nextCursor;
}

class OpportunitiesRepository {
  const OpportunitiesRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<List<JobItem>> fetchJobs({
    String search = '',
    String? q,
    String location = '',
    String? city,
    String jobType = '',
    String? type,
    int limit = 40,
    int offset = 0,
    String status = '',
  }) async {
    final queryText = (q ?? search).trim();
    final cityText = (city ?? location).trim();
    final typeText = (type ?? jobType).trim();
    final result = await _apiClient.get<JsonMap>(
      '/api/new/jobs',
      query: {
        'limit': limit.clamp(1, 100),
        'offset': offset < 0 ? 0 : offset,
        if (queryText.isNotEmpty) 'q': queryText,
        if (queryText.isNotEmpty) 'search': queryText,
        if (cityText.isNotEmpty) 'city': cityText,
        if (cityText.isNotEmpty) 'location': cityText,
        if (typeText.isNotEmpty) 'type': typeText,
        if (typeText.isNotEmpty) 'job_type': typeText,
        if (status.isNotEmpty) 'status': status,
      },
      decoder: asJsonMap,
    );
    return asJsonMapList(
      asJsonMap(result.rawData)['items'],
    ).map(JobItem.fromMap).toList(growable: false);
  }

  Future<JobItem?> fetchJob(int jobId) async {
    try {
      final result = await _apiClient.get<JsonMap>(
        '/api/new/jobs/$jobId',
        decoder: asJsonMap,
      );
      final map = asJsonMap(result.rawData);
      if (map.isEmpty) return null;
      return JobItem.fromMap(map);
    } catch (_) {
      return null;
    }
  }

  Future<ApiResult<dynamic>> createJob({
    required String company,
    required String title,
    required String description,
    required String location,
    required String jobType,
    required String workMode,
    required String link,
    File? imageFile,
    bool showInFeed = true,
    bool publish = true,
  }) {
    final fields = <String, dynamic>{
      'company': company,
      'title': title,
      'description': description,
      'location': location,
      'job_type': jobType,
      'work_mode': workMode,
      'link': link,
      'show_in_feed': showInFeed ? '1' : '0',
      'publish': publish ? '1' : '0',
    };
    if (imageFile != null) {
      return _apiClient.multipart<dynamic>(
        '/api/new/jobs/upload',
        files: {'image': imageFile},
        fields: fields,
      );
    }
    return _apiClient.post<dynamic>('/api/new/jobs', body: fields);
  }

  Future<ApiResult<dynamic>> editJob({
    required int jobId,
    required String company,
    required String title,
    required String description,
    required String location,
    required String jobType,
    required String workMode,
    required String link,
    File? imageFile,
    bool? showInFeed,
  }) {
    final fields = <String, dynamic>{
      'company': company,
      'title': title,
      'description': description,
      'location': location,
      'job_type': jobType,
      'work_mode': workMode,
      'link': link,
    };
    if (showInFeed != null) {
      fields['show_in_feed'] = showInFeed ? '1' : '0';
    }
    if (imageFile != null) {
      return _apiClient.multipart<dynamic>(
        '/api/new/jobs/$jobId/upload',
        files: {'image': imageFile},
        fields: fields,
      );
    }
    return _apiClient.patch<dynamic>('/api/new/jobs/$jobId', body: fields);
  }

  Future<ApiResult<dynamic>> deleteJob(int jobId) {
    return _apiClient.delete<dynamic>('/api/new/jobs/$jobId');
  }

  Future<ApiResult<dynamic>> applyToJob({
    required int jobId,
    String coverLetter = '',
    String cvLink = '',
    String contactChannel = '',
    String contactValue = '',
    String city = '',
  }) {
    return _apiClient.post<dynamic>(
      '/api/new/jobs/$jobId/apply',
      body: {
        'cover_letter': coverLetter,
        if (cvLink.isNotEmpty) 'cv_link': cvLink,
        if (contactChannel.isNotEmpty) 'contact_channel': contactChannel,
        if (contactValue.isNotEmpty) 'contact_value': contactValue,
        if (city.isNotEmpty) 'city': city,
      },
    );
  }

  Future<List<JobApplicationItem>> fetchApplications(int jobId) async {
    final result = await _apiClient.get<JsonMap>(
      '/api/new/jobs/$jobId/applications',
      decoder: asJsonMap,
    );
    return asJsonMapList(
      asJsonMap(result.rawData)['items'],
    ).map(JobApplicationItem.fromMap).toList(growable: false);
  }

  Future<JobApplicationItem?> fetchApplicationDetail({
    required int jobId,
    required int applicationId,
  }) async {
    try {
      final result = await _apiClient.get<JsonMap>(
        '/api/new/jobs/$jobId/applications/$applicationId',
        decoder: asJsonMap,
      );
      final map = asJsonMap(result.rawData);
      if (map.isEmpty) return null;
      return JobApplicationItem.fromMap(map);
    } catch (_) {
      return null;
    }
  }

  Future<ApiResult<dynamic>> reviewApplication({
    required int jobId,
    required int applicationId,
    required String status,
    required String decisionNote,
  }) {
    return _apiClient.post<dynamic>(
      '/api/new/jobs/$jobId/applications/$applicationId/review',
      body: {'status': status, 'decision_note': decisionNote},
    );
  }

  Future<OpportunityInboxPageData> fetchOpportunityInbox({
    String tab = 'all',
    String cursor = '',
  }) async {
    final result = await _apiClient.get<JsonMap>(
      '/api/new/opportunities',
      query: {
        if (tab.trim().isNotEmpty) 'tab': tab.trim(),
        if (cursor.trim().isNotEmpty) 'cursor': cursor.trim(),
      },
      decoder: asJsonMap,
    );
    final payload = asJsonMap(result.rawData);
    final data = asJsonMap(payload['data']).isNotEmpty
        ? asJsonMap(payload['data'])
        : payload;
    final inbox = asJsonMap(data['opportunities']).isNotEmpty
        ? asJsonMap(data['opportunities'])
        : data;
    return OpportunityInboxPageData(
      items: asJsonMapList(
        inbox['items'],
      ).map(OpportunityItem.fromMap).toList(growable: false),
      hasMore: asBool(inbox['hasMore']) ?? false,
      nextCursor: coalesceText([inbox['next_cursor']], fallback: ''),
    );
  }
}

final opportunitiesRepositoryProvider = Provider<OpportunitiesRepository>(
  (ref) => OpportunitiesRepository(ref.watch(apiClientProvider)),
);
