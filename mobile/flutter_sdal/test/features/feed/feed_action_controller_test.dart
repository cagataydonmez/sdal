import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_sdal/core/network/api_result.dart';
import 'package:flutter_sdal/core/state/async_action_state.dart';
import 'package:flutter_sdal/features/feed/application/feed_action_controller.dart';
import 'package:flutter_sdal/features/feed/data/feed_repository.dart';
import '../../test_support/fake_api_client.dart';

void main() {
  test('FeedActionController reports success for post creation', () async {
    final container = ProviderContainer(
      overrides: [
        feedRepositoryProvider.overrideWithValue(
          _FakeFeedRepository(createPostOk: true),
        ),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(feedActionControllerProvider.notifier);
    final ok = await notifier.createPost(content: 'Merhaba');

    expect(ok, isTrue);
    final state = container.read(feedActionControllerProvider);
    expect(state.status, AsyncActionStatus.success);
    expect(state.scope, 'createPost');
  });

  test('FeedActionController reports error for failed comment', () async {
    final container = ProviderContainer(
      overrides: [
        feedRepositoryProvider.overrideWithValue(
          _FakeFeedRepository(commentOk: false),
        ),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(feedActionControllerProvider.notifier);
    final ok = await notifier.createComment(postId: 42, comment: 'Nope');

    expect(ok, isFalse);
    final state = container.read(feedActionControllerProvider);
    expect(state.status, AsyncActionStatus.error);
    expect(state.scope, 'comment:42');
  });
}

class _FakeFeedRepository extends FeedRepository {
  _FakeFeedRepository({this.createPostOk = true, this.commentOk = true})
    : super(FakeApiClient());

  final bool createPostOk;
  final bool commentOk;

  @override
  Future<ApiResult<dynamic>> createPost({
    required String content,
    String feedType = 'main',
  }) async {
    return ApiResult<dynamic>(
      ok: createPostOk,
      statusCode: createPostOk ? 200 : 400,
      message: createPostOk ? 'ok' : 'fail',
      code: '',
      data: null,
      rawData: null,
    );
  }

  @override
  Future<ApiResult<dynamic>> togglePostLike(int postId) async {
    return ApiResult<dynamic>(
      ok: true,
      statusCode: 200,
      message: '',
      code: '',
      data: null,
      rawData: null,
    );
  }

  @override
  Future<ApiResult<dynamic>> toggleReaction(FeedItem item) async {
    return ApiResult<dynamic>(
      ok: true,
      statusCode: 200,
      message: '',
      code: '',
      data: null,
      rawData: null,
    );
  }

  @override
  Future<ApiResult<dynamic>> createComment({
    required int postId,
    required String comment,
  }) async {
    return ApiResult<dynamic>(
      ok: commentOk,
      statusCode: commentOk ? 200 : 400,
      message: commentOk ? '' : 'comment fail',
      code: '',
      data: null,
      rawData: null,
    );
  }
}
