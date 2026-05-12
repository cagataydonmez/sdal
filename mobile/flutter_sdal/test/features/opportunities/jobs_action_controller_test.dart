import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_sdal/core/network/api_result.dart';
import 'package:flutter_sdal/core/state/async_action_state.dart';
import 'package:flutter_sdal/features/opportunities/application/jobs_action_controller.dart';
import 'package:flutter_sdal/features/opportunities/data/opportunities_repository.dart';
import '../../test_support/fake_api_client.dart';

void main() {
  test('JobsActionController reports apply failures', () async {
    final container = ProviderContainer(
      overrides: [
        opportunitiesRepositoryProvider.overrideWithValue(
          _FakeOpportunitiesRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);

    final ok = await container
        .read(jobsActionControllerProvider.notifier)
        .apply(jobId: 42, coverLetter: 'test');

    expect(ok, isFalse);
    final state = container.read(jobsActionControllerProvider);
    expect(state.status, AsyncActionStatus.error);
    expect(state.scope, 'jobs:apply:42');
  });
}

class _FakeOpportunitiesRepository extends OpportunitiesRepository {
  _FakeOpportunitiesRepository() : super(FakeApiClient());

  @override
  Future<ApiResult<dynamic>> applyToJob({
    required int jobId,
    String coverLetter = '',
    String cvLink = '',
    String contactChannel = '',
    String contactValue = '',
    String city = '',
  }) async {
    return const ApiResult<dynamic>(
      ok: false,
      statusCode: 400,
      message: 'failed',
      code: '',
      data: null,
      rawData: null,
    );
  }
}
