import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_sdal/core/network/api_result.dart';
import 'package:flutter_sdal/core/state/async_action_state.dart';
import 'package:flutter_sdal/features/groups/application/groups_action_controller.dart';
import 'package:flutter_sdal/features/groups/data/groups_repository.dart';
import '../../test_support/fake_api_client.dart';

void main() {
  test('GroupsActionController reports create success', () async {
    final container = ProviderContainer(
      overrides: [
        groupsRepositoryProvider.overrideWithValue(_FakeGroupsRepository()),
      ],
    );
    addTearDown(container.dispose);

    final ok = await container
        .read(groupsActionControllerProvider.notifier)
        .createGroup(name: 'Yeni Grup', description: 'Aciklama');

    expect(ok, isTrue);
    final state = container.read(groupsActionControllerProvider);
    expect(state.status, AsyncActionStatus.success);
    expect(state.scope, 'groups:create');
  });

  test('GroupsActionController exposes membership status after join', () async {
    final container = ProviderContainer(
      overrides: [
        groupsRepositoryProvider.overrideWithValue(
          _FakeGroupsRepository(membershipStatus: 'pending'),
        ),
      ],
    );
    addTearDown(container.dispose);

    final status = await container
        .read(groupsActionControllerProvider.notifier)
        .toggleJoin(8);

    expect(status, 'pending');
    final state = container.read(groupsActionControllerProvider);
    expect(state.status, AsyncActionStatus.success);
    expect(state.scope, 'groups:join');
  });
}

class _FakeGroupsRepository extends GroupsRepository {
  _FakeGroupsRepository({this.membershipStatus = 'member'})
    : super(FakeApiClient());

  final String membershipStatus;

  @override
  Future<ApiResult<dynamic>> createGroup({
    required String name,
    required String description,
  }) async {
    return ApiResult<dynamic>(
      ok: true,
      statusCode: 200,
      message: 'ok',
      code: '',
      data: null,
      rawData: const <String, dynamic>{'ok': true},
    );
  }

  @override
  Future<ApiResult<Map<String, dynamic>>> toggleJoin(int groupId) async {
    return ApiResult<Map<String, dynamic>>(
      ok: true,
      statusCode: 200,
      message: 'ok',
      code: '',
      data: <String, dynamic>{'membershipStatus': membershipStatus},
      rawData: <String, dynamic>{'membershipStatus': membershipStatus},
    );
  }
}
