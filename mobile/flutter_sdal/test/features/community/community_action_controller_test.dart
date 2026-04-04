import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_sdal/core/network/api_result.dart';
import 'package:flutter_sdal/core/state/async_action_state.dart';
import 'package:flutter_sdal/features/community/application/community_action_controller.dart';
import 'package:flutter_sdal/features/community/data/community_repository.dart';
import '../../test_support/fake_api_client.dart';

void main() {
  test(
    'CommunityActionController reports announcement create success',
    () async {
      final container = ProviderContainer(
        overrides: [
          communityRepositoryProvider.overrideWithValue(
            _FakeCommunityRepository(),
          ),
        ],
      );
      addTearDown(container.dispose);

      final ok = await container
          .read(communityActionControllerProvider.notifier)
          .createAnnouncement(title: 'Title', body: 'Body');

      expect(ok, isTrue);
      final state = container.read(communityActionControllerProvider);
      expect(state.status, AsyncActionStatus.success);
      expect(state.scope, 'announcements:create');
    },
  );
}

class _FakeCommunityRepository extends CommunityRepository {
  _FakeCommunityRepository() : super(FakeApiClient());

  @override
  Future<ApiResult<dynamic>> createAnnouncement({
    required String title,
    required String body,
    dynamic imageFile,
  }) async {
    return const ApiResult<dynamic>(
      ok: true,
      statusCode: 200,
      message: '',
      code: '',
      data: null,
      rawData: null,
    );
  }
}
