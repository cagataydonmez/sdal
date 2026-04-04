import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_sdal/core/network/api_result.dart';
import 'package:flutter_sdal/core/state/async_action_state.dart';
import 'package:flutter_sdal/features/notifications/application/notifications_action_controller.dart';
import 'package:flutter_sdal/features/notifications/data/notifications_repository.dart';
import '../../test_support/fake_api_client.dart';

void main() {
  test(
    'NotificationsActionController returns target for open action',
    () async {
      final container = ProviderContainer(
        overrides: [
          notificationsRepositoryProvider.overrideWithValue(
            _FakeNotificationsRepository(),
          ),
        ],
      );
      addTearDown(container.dispose);

      final target = await container
          .read(notificationsActionControllerProvider.notifier)
          .open(7);

      expect(target?.route, '/new/profile/verification');
      final state = container.read(notificationsActionControllerProvider);
      expect(state.status, AsyncActionStatus.success);
    },
  );

  test(
    'NotificationsActionController reports failed preference save',
    () async {
      final container = ProviderContainer(
        overrides: [
          notificationsRepositoryProvider.overrideWithValue(
            _FakeNotificationsRepository(savePreferencesOk: false),
          ),
        ],
      );
      addTearDown(container.dispose);

      final ok = await container
          .read(notificationsActionControllerProvider.notifier)
          .savePreferences(
            const NotificationPreferences(
              categories: {'system': true},
              quietModeEnabled: false,
              quietModeStart: '',
              quietModeEnd: '',
            ),
          );

      expect(ok, isFalse);
      final state = container.read(notificationsActionControllerProvider);
      expect(state.status, AsyncActionStatus.error);
      expect(state.scope, 'preferences');
    },
  );
}

class _FakeNotificationsRepository extends NotificationsRepository {
  _FakeNotificationsRepository({this.savePreferencesOk = true})
    : super(FakeApiClient());

  final bool savePreferencesOk;

  @override
  Future<ApiResult<Map<String, dynamic>>> openNotification(
    int notificationId,
  ) async {
    return ApiResult<Map<String, dynamic>>(
      ok: true,
      statusCode: 200,
      message: '',
      code: '',
      data: {
        'target': {
          'route': '/new/profile/verification',
          'href': '/new/profile/verification?notification=7',
          'label': 'Go',
        },
      },
      rawData: {
        'target': {
          'route': '/new/profile/verification',
          'href': '/new/profile/verification?notification=7',
          'label': 'Go',
        },
      },
    );
  }

  @override
  Future<ApiResult<dynamic>> savePreferences(
    NotificationPreferences preferences,
  ) async {
    return ApiResult<dynamic>(
      ok: savePreferencesOk,
      statusCode: savePreferencesOk ? 200 : 400,
      message: savePreferencesOk ? '' : 'save fail',
      code: '',
      data: null,
      rawData: null,
    );
  }
}
