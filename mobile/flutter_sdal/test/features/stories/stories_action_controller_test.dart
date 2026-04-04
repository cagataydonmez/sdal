import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_sdal/core/network/api_result.dart';
import 'package:flutter_sdal/core/state/async_action_state.dart';
import 'package:flutter_sdal/features/stories/application/stories_action_controller.dart';
import 'package:flutter_sdal/features/stories/data/stories_repository.dart';
import '../../test_support/fake_api_client.dart';

void main() {
  test('StoriesActionController reports upload success', () async {
    final container = ProviderContainer(
      overrides: [
        storiesRepositoryProvider.overrideWithValue(_FakeStoriesRepository()),
      ],
    );
    addTearDown(container.dispose);

    final ok = await container
        .read(storiesActionControllerProvider.notifier)
        .uploadStory(imageFile: File('/tmp/story.jpg'), caption: 'Merhaba');

    expect(ok, isTrue);
    final state = container.read(storiesActionControllerProvider);
    expect(state.status, AsyncActionStatus.success);
    expect(state.scope, 'stories:upload');
  });
}

class _FakeStoriesRepository extends StoriesRepository {
  _FakeStoriesRepository() : super(FakeApiClient());

  @override
  Future<ApiResult<dynamic>> uploadStory({
    required File imageFile,
    required String caption,
    String feedType = 'main',
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
