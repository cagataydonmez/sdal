import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_sdal/core/network/api_result.dart';
import 'package:flutter_sdal/core/network/api_result_parser.dart';
import 'package:flutter_sdal/features/opportunities/data/opportunities_repository.dart';

import '../../test_support/fake_api_client.dart';

void main() {
  group('OpportunitiesRepository serialization', () {
    test(
      'fetchJobs sends documented and backend-compatible query aliases',
      () async {
        final apiClient = _RecordingApiClient(
          getRawData: const {'items': <Map<String, Object?>>[]},
        );
        final repository = OpportunitiesRepository(apiClient);

        await repository.fetchJobs(
          q: 'engineer',
          city: 'Istanbul',
          type: 'remote',
          limit: 25,
          offset: 10,
        );

        expect(apiClient.lastMethod, 'GET');
        expect(apiClient.lastPath, '/api/new/jobs');
        expect(apiClient.lastQuery, {
          'limit': 25,
          'offset': 10,
          'q': 'engineer',
          'search': 'engineer',
          'city': 'Istanbul',
          'location': 'Istanbul',
          'type': 'remote',
          'job_type': 'remote',
        });
      },
    );

    test('createJob sends city/location and type/job_type aliases', () async {
      final apiClient = _RecordingApiClient();
      final repository = OpportunitiesRepository(apiClient);

      await repository.createJob(
        company: 'SDAL',
        title: 'iOS Engineer',
        description: 'Build Flutter surfaces',
        location: 'Ankara',
        jobType: 'hybrid',
        workMode: 'remote',
        link: 'https://example.com/job',
      );

      expect(apiClient.lastMethod, 'POST');
      expect(apiClient.lastPath, '/api/new/jobs');
      expect(apiClient.lastBody, {
        'company': 'SDAL',
        'title': 'iOS Engineer',
        'description': 'Build Flutter surfaces',
        'city': 'Ankara',
        'location': 'Ankara',
        'type': 'hybrid',
        'job_type': 'hybrid',
        'link': 'https://example.com/job',
      });
    });

    test('applyToJob sends both coverLetter and cover_letter', () async {
      final apiClient = _RecordingApiClient();
      final repository = OpportunitiesRepository(apiClient);

      await repository.applyToJob(jobId: 42, coverLetter: 'I am interested.');

      expect(apiClient.lastMethod, 'POST');
      expect(apiClient.lastPath, '/api/new/jobs/42/apply');
      expect(apiClient.lastBody, {
        'coverLetter': 'I am interested.',
        'cover_letter': 'I am interested.',
      });
    });
  });
}

class _RecordingApiClient extends FakeApiClient {
  _RecordingApiClient({
    this.getRawData = const {'items': <Map<String, Object?>>[]},
  });

  final dynamic getRawData;

  String? lastMethod;
  String? lastPath;
  Map<String, dynamic>? lastQuery;
  Object? lastBody;

  @override
  Future<ApiResult<T>> get<T>(
    String path, {
    Map<String, dynamic>? query,
    ApiDecoder<T>? decoder,
  }) async {
    lastMethod = 'GET';
    lastPath = path;
    lastQuery = query == null ? null : Map<String, dynamic>.from(query);
    return ApiResult<T>(
      ok: true,
      statusCode: 200,
      message: '',
      code: '',
      data: decoder == null ? null : decoder(getRawData),
      rawData: getRawData,
    );
  }

  @override
  Future<ApiResult<T>> post<T>(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    ApiDecoder<T>? decoder,
  }) async {
    lastMethod = 'POST';
    lastPath = path;
    lastQuery = query == null ? null : Map<String, dynamic>.from(query);
    lastBody = body;
    return ApiResult<T>(
      ok: true,
      statusCode: 200,
      message: '',
      code: '',
      data: decoder == null
          ? null
          : decoder(const <String, Object?>{'ok': true}),
      rawData: const <String, Object?>{'ok': true},
    );
  }
}
