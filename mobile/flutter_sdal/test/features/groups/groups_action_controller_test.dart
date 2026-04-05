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

  test('GroupsActionController returns invite sent count', () async {
    final container = ProviderContainer(
      overrides: [
        groupsRepositoryProvider.overrideWithValue(
          _FakeGroupsRepository(inviteSentCount: 3),
        ),
      ],
    );
    addTearDown(container.dispose);

    final sent = await container
        .read(groupsActionControllerProvider.notifier)
        .inviteMembers(groupId: 8, userIds: const [1, 2, 3]);

    expect(sent, 3);
    final state = container.read(groupsActionControllerProvider);
    expect(state.status, AsyncActionStatus.success);
    expect(state.scope, 'groups:invite-members');
  });

  test('GroupsActionController reports role change success', () async {
    final container = ProviderContainer(
      overrides: [
        groupsRepositoryProvider.overrideWithValue(_FakeGroupsRepository()),
      ],
    );
    addTearDown(container.dispose);

    final ok = await container
        .read(groupsActionControllerProvider.notifier)
        .changeRole(groupId: 9, userId: 44, role: 'moderator');

    expect(ok, isTrue);
    final state = container.read(groupsActionControllerProvider);
    expect(state.status, AsyncActionStatus.success);
    expect(state.scope, 'groups:role');
  });
}

class _FakeGroupsRepository extends GroupsRepository {
  _FakeGroupsRepository({
    this.membershipStatus = 'member',
    this.inviteSentCount = 1,
  }) : super(FakeApiClient());

  final String membershipStatus;
  final int inviteSentCount;

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

  @override
  Future<ApiResult<Map<String, dynamic>>> inviteMembers({
    required int groupId,
    required List<int> userIds,
  }) async {
    return ApiResult<Map<String, dynamic>>(
      ok: true,
      statusCode: 200,
      message: 'ok',
      code: '',
      data: <String, dynamic>{'sent': inviteSentCount},
      rawData: <String, dynamic>{'sent': inviteSentCount},
    );
  }

  @override
  Future<ApiResult<dynamic>> changeRole({
    required int groupId,
    required int userId,
    required String role,
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
}
