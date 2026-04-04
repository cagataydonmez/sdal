import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_sdal/core/network/api_result.dart';
import 'package:flutter_sdal/core/state/async_action_state.dart';
import 'package:flutter_sdal/features/following/application/following_action_controller.dart';
import 'package:flutter_sdal/features/following/data/following_repository.dart';
import '../../test_support/fake_api_client.dart';

void main() {
  test('FollowingActionController reports unfollow success', () async {
    final container = ProviderContainer(
      overrides: [
        followingRepositoryProvider.overrideWithValue(
          _FakeFollowingRepository(following: false),
        ),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(followingActionControllerProvider.notifier);
    final following = await notifier.toggleFollow(42);

    expect(following, isFalse);
    final state = container.read(followingActionControllerProvider);
    expect(state.status, AsyncActionStatus.success);
    expect(state.scope, 'follow:42');
  });

  test('FollowingActionController reports errors from repository', () async {
    final container = ProviderContainer(
      overrides: [
        followingRepositoryProvider.overrideWithValue(
          _FakeFollowingRepository(ok: false),
        ),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(followingActionControllerProvider.notifier);
    final following = await notifier.toggleFollow(7);

    expect(following, isNull);
    final state = container.read(followingActionControllerProvider);
    expect(state.status, AsyncActionStatus.error);
    expect(state.scope, 'follow:7');
  });
}

class _FakeFollowingRepository extends FollowingRepository {
  _FakeFollowingRepository({this.ok = true, this.following = false})
    : super(FakeApiClient());

  final bool ok;
  final bool following;

  @override
  Future<ApiResult<Map<String, dynamic>>> toggleFollow(int memberId) async {
    return ApiResult<Map<String, dynamic>>(
      ok: ok,
      statusCode: ok ? 200 : 400,
      message: ok ? 'ok' : 'failed',
      code: '',
      data: <String, dynamic>{'following': following},
      rawData: <String, dynamic>{'following': following},
    );
  }
}
