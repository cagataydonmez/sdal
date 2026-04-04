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
    required this.link,
    required this.posterHandle,
    required this.createdAt,
    required this.myApplicationId,
    required this.myApplicationStatus,
    required this.myApplicationDecisionNote,
  });

  final int id;
  final int posterId;
  final String company;
  final String title;
  final String description;
  final String location;
  final String jobType;
  final String link;
  final String posterHandle;
  final String createdAt;
  final int myApplicationId;
  final String myApplicationStatus;
  final String myApplicationDecisionNote;

  factory JobItem.fromMap(JsonMap map) {
    return JobItem(
      id: asInt(map['id']) ?? 0,
      posterId: asInt(map['poster_id']) ?? 0,
      company: coalesceText([map['company']], fallback: ''),
      title: coalesceText([map['title']], fallback: 'İş ilanı'),
      description: coalesceText([map['description']], fallback: ''),
      location: coalesceText([map['location']], fallback: ''),
      jobType: coalesceText([map['job_type']], fallback: ''),
      link: coalesceText([map['link']], fallback: ''),
      posterHandle: coalesceText([map['poster_kadi']], fallback: ''),
      createdAt: coalesceText([map['created_at']], fallback: ''),
      myApplicationId: asInt(map['my_application_id']) ?? 0,
      myApplicationStatus: coalesceText([
        map['my_application_status'],
      ], fallback: ''),
      myApplicationDecisionNote: coalesceText([
        map['my_application_decision_note'],
      ], fallback: ''),
    );
  }
}

class JobApplicationItem {
  const JobApplicationItem({
    required this.id,
    required this.jobId,
    required this.applicantId,
    required this.coverLetter,
    required this.createdAt,
    required this.status,
    required this.decisionNote,
    required this.handle,
    required this.displayName,
  });

  final int id;
  final int jobId;
  final int applicantId;
  final String coverLetter;
  final String createdAt;
  final String status;
  final String decisionNote;
  final String handle;
  final String displayName;

  factory JobApplicationItem.fromMap(JsonMap map) {
    return JobApplicationItem(
      id: asInt(map['id']) ?? 0,
      jobId: asInt(map['job_id']) ?? 0,
      applicantId: asInt(map['applicant_id']) ?? 0,
      coverLetter: coalesceText([map['cover_letter']], fallback: ''),
      createdAt: coalesceText([map['created_at']], fallback: ''),
      status: coalesceText([map['status']], fallback: 'pending'),
      decisionNote: coalesceText([map['decision_note']], fallback: ''),
      handle: coalesceText([map['kadi']], fallback: ''),
      displayName: coalesceText([
        '${asString(map['isim']) ?? ''} ${asString(map['soyisim']) ?? ''}'
            .trim(),
        map['kadi'],
      ], fallback: 'SDAL Üyesi'),
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

  factory OpportunityItem.fromMap(JsonMap map) {
    final target = asJsonMap(map['target']);
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
    String location = '',
    String jobType = '',
  }) async {
    final result = await _apiClient.get<JsonMap>(
      '/api/new/jobs',
      query: {
        if (search.trim().isNotEmpty) 'search': search.trim(),
        if (location.trim().isNotEmpty) 'location': location.trim(),
        if (jobType.trim().isNotEmpty) 'job_type': jobType.trim(),
      },
      decoder: asJsonMap,
    );
    return asJsonMapList(
      asJsonMap(result.rawData)['items'],
    ).map(JobItem.fromMap).toList(growable: false);
  }

  Future<ApiResult<dynamic>> createJob({
    required String company,
    required String title,
    required String description,
    required String location,
    required String jobType,
    required String link,
  }) {
    return _apiClient.post<dynamic>(
      '/api/new/jobs',
      body: {
        'company': company,
        'title': title,
        'description': description,
        'location': location,
        'job_type': jobType,
        'link': link,
      },
    );
  }

  Future<ApiResult<dynamic>> deleteJob(int jobId) {
    return _apiClient.delete<dynamic>('/api/new/jobs/$jobId');
  }

  Future<ApiResult<dynamic>> applyToJob({
    required int jobId,
    required String coverLetter,
  }) {
    return _apiClient.post<dynamic>(
      '/api/new/jobs/$jobId/apply',
      body: {'cover_letter': coverLetter},
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
