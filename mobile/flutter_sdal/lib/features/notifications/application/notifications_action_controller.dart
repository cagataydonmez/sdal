import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/state/async_action_state.dart';
import '../data/notifications_repository.dart';

class NotificationsActionController
    extends AutoDisposeNotifier<AsyncActionState> {
  NotificationsRepository get _repository =>
      ref.read(notificationsRepositoryProvider);

  @override
  AsyncActionState build() => const AsyncActionState.idle();

  Future<bool> markAllRead() async {
    state = const AsyncActionState.loading(scope: 'markAllRead');
    final result = await _repository.markAllRead();
    if (result.ok) {
      _refreshAll();
      state = AsyncActionState.success(
        scope: 'markAllRead',
        message: result.message.isNotEmpty
            ? result.message
            : 'Bildirimler okundu olarak işaretlendi.',
      );
      return true;
    }
    state = AsyncActionState.error(
      scope: 'markAllRead',
      message: result.message.isNotEmpty
          ? result.message
          : 'İşlem başarısız oldu.',
    );
    return false;
  }

  Future<bool> markRead(int notificationId) async {
    state = AsyncActionState.loading(scope: 'markRead:$notificationId');
    final result = await _repository.markRead(notificationId);
    if (result.ok) {
      ref.invalidate(notificationsProvider);
      ref.invalidate(notificationUnreadCountProvider);
      state = AsyncActionState.success(
        scope: 'markRead:$notificationId',
        message: result.message.isNotEmpty
            ? result.message
            : 'Bildirim okundu.',
      );
      return true;
    }
    state = AsyncActionState.error(
      scope: 'markRead:$notificationId',
      message: result.message.isNotEmpty
          ? result.message
          : 'İşlem başarısız oldu.',
    );
    return false;
  }

  Future<NotificationTarget?> open(int notificationId) async {
    state = AsyncActionState.loading(scope: 'open:$notificationId');
    final result = await _repository.openNotification(notificationId);
    ref.invalidate(notificationsProvider);
    ref.invalidate(notificationUnreadCountProvider);
    if (!result.ok) {
      state = AsyncActionState.error(
        scope: 'open:$notificationId',
        message: result.message.isNotEmpty
            ? result.message
            : 'Bildirim açılamadı.',
      );
      return null;
    }
    final payload = result.rawData is Map<String, dynamic>
        ? result.rawData as Map<String, dynamic>
        : <String, dynamic>{};
    final data = payload['data'] is Map<String, dynamic>
        ? payload['data'] as Map<String, dynamic>
        : payload;
    final targetRaw = data['target'] is Map<String, dynamic>
        ? data['target'] as Map<String, dynamic>
        : <String, dynamic>{};
    state = const AsyncActionState.success(scope: 'open');
    return NotificationTarget.fromMap(targetRaw);
  }

  Future<bool> runAction(NotificationActionItem action) async {
    state = AsyncActionState.loading(scope: 'action:${action.kind}');
    final result = await _repository.runAction(action);
    if (result.ok) {
      _refreshAll();
      state = AsyncActionState.success(
        scope: 'action:${action.kind}',
        message: result.message.isNotEmpty
            ? result.message
            : '${action.label} tamamlandı.',
      );
      return true;
    }
    state = AsyncActionState.error(
      scope: 'action:${action.kind}',
      message: result.message.isNotEmpty
          ? result.message
          : 'İşlem başarısız oldu.',
    );
    return false;
  }

  Future<bool> savePreferences(NotificationPreferences preferences) async {
    state = const AsyncActionState.loading(scope: 'preferences');
    final result = await _repository.savePreferences(preferences);
    if (result.ok) {
      ref.invalidate(notificationPreferencesProvider);
      state = AsyncActionState.success(
        scope: 'preferences',
        message: result.message.isNotEmpty
            ? result.message
            : 'Bildirim tercihleri güncellendi.',
      );
      return true;
    }
    state = AsyncActionState.error(
      scope: 'preferences',
      message: result.message.isNotEmpty
          ? result.message
          : 'Tercihler kaydedilemedi.',
    );
    return false;
  }

  void _refreshAll() {
    ref.invalidate(notificationsProvider);
    ref.invalidate(notificationPreferencesProvider);
    ref.invalidate(notificationUnreadCountProvider);
  }

  void reset() {
    state = const AsyncActionState.idle();
  }
}

final notificationsActionControllerProvider =
    AutoDisposeNotifierProvider<
      NotificationsActionController,
      AsyncActionState
    >(NotificationsActionController.new);
