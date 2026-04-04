import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_sdal/core/network/api_result.dart';
import 'package:flutter_sdal/core/network/json_utils.dart';
import 'package:flutter_sdal/core/state/async_action_state.dart';
import 'package:flutter_sdal/features/requests/application/requests_action_controller.dart';
import 'package:flutter_sdal/features/requests/data/requests_repository.dart';
import '../../test_support/fake_api_client.dart';

void main() {
  test('RequestsActionController reports upload success', () async {
    final container = ProviderContainer(
      overrides: [
        requestsRepositoryProvider.overrideWithValue(_FakeRequestsRepository()),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(requestsActionControllerProvider.notifier);
    final attachment = await notifier.uploadAttachment(File('/tmp/proof.jpg'));

    expect(attachment, isNotNull);
    final state = container.read(requestsActionControllerProvider);
    expect(state.status, AsyncActionStatus.success);
    expect(state.scope, 'requests:upload');
  });

  test('RequestsActionController reports create failures', () async {
    final container = ProviderContainer(
      overrides: [
        requestsRepositoryProvider.overrideWithValue(
          _FakeRequestsRepository(createOk: false),
        ),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(requestsActionControllerProvider.notifier);
    final ok = await notifier.createRequest(
      categoryKey: 'graduation_year_change',
      payload: <String, dynamic>{'note': 'test'},
    );

    expect(ok, isFalse);
    final state = container.read(requestsActionControllerProvider);
    expect(state.status, AsyncActionStatus.error);
    expect(state.scope, 'requests:create');
  });
}

class _FakeRequestsRepository extends RequestsRepository {
  _FakeRequestsRepository({this.createOk = true}) : super(FakeApiClient());

  final bool createOk;

  @override
  Future<ApiResult<RequestAttachment>> uploadAttachment(File file) async {
    return ApiResult<RequestAttachment>(
      ok: true,
      statusCode: 200,
      message: 'ok',
      code: '',
      data: const RequestAttachment(
        name: 'proof.jpg',
        mime: 'image/jpeg',
        size: 42,
        url: '/uploads/request-attachments/proof.jpg',
      ),
      rawData: const <String, dynamic>{},
    );
  }

  @override
  Future<ApiResult<dynamic>> createRequest({
    required String categoryKey,
    required JsonMap payload,
  }) async {
    return ApiResult<dynamic>(
      ok: createOk,
      statusCode: createOk ? 200 : 400,
      message: createOk ? 'ok' : 'failed',
      code: '',
      data: null,
      rawData: null,
    );
  }
}
