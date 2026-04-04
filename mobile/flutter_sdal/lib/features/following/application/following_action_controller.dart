import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/json_utils.dart';
import '../../../core/state/async_action_state.dart';
import '../data/following_repository.dart';

class FollowingActionController extends AutoDisposeNotifier<AsyncActionState> {
  FollowingRepository get _repository => ref.read(followingRepositoryProvider);

  @override
  AsyncActionState build() => const AsyncActionState.idle();

  Future<bool?> toggleFollow(int memberId) async {
    state = AsyncActionState.loading(scope: 'follow:$memberId');
    final result = await _repository.toggleFollow(memberId);
    final following = asBool(asJsonMap(result.rawData)['following']);
    if (result.ok) {
      state = AsyncActionState.success(
        scope: 'follow:$memberId',
        message: following == true ? 'Takip edildi.' : 'Takip bırakıldı.',
      );
      return following;
    }
    state = AsyncActionState.error(
      scope: 'follow:$memberId',
      message: result.message.isNotEmpty
          ? result.message
          : 'Takip işlemi tamamlanamadı.',
    );
    return null;
  }

  void reset() {
    state = const AsyncActionState.idle();
  }
}

final followingActionControllerProvider =
    AutoDisposeNotifierProvider<FollowingActionController, AsyncActionState>(
      FollowingActionController.new,
    );
