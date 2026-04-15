import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/state/async_action_state.dart';
import '../data/notifications_repository.dart';

class NotificationsActionController extends Notifier<AsyncActionState> {
  NotificationsRepository get _repository =>
      ref.read(notificationsRepositoryProvider);

  @override
  AsyncActionState build() => const AsyncActionState.idle();

  Future<bool> markAllRead({
    Iterable<AppNotification> trackedItems = const <AppNotification>[],
  }) async {
    state = const AsyncActionState.loading(scope: 'markAllRead');
    final result = await _repository.markAllRead();
    if (result.ok) {
      final unreadItems = trackedItems.where((item) => item.isUnread);
      unawaited(
        _repository.trackTelemetry(
          unreadItems
              .map(
                (item) => NotificationTelemetryEvent(
                  notificationId: item.id,
                  notificationType: item.type,
                  eventName: 'no_action',
                  surface: 'notifications_page',
                  actionKind: 'mark_all_read',
                ),
              )
              .toList(growable: false),
        ),
      );
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

  Future<bool> markRead(
    int notificationId, {
    String notificationType = '',
  }) async {
    state = AsyncActionState.loading(scope: 'markRead:$notificationId');
    final result = await _repository.markRead(notificationId);
    if (result.ok) {
      unawaited(
        _repository.trackTelemetry([
          NotificationTelemetryEvent(
            notificationId: notificationId,
            notificationType: notificationType,
            eventName: 'no_action',
            surface: 'notifications_page',
            actionKind: 'mark_read',
          ),
        ]),
      );
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

  Future<NotificationTarget?> open(
    int notificationId, {
    String notificationType = '',
  }) async {
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
    unawaited(
      _repository.trackTelemetry([
        NotificationTelemetryEvent(
          notificationId: notificationId,
          notificationType: notificationType,
          eventName: 'open',
          surface: 'notifications_page',
          actionKind: 'open',
        ),
      ]),
    );
    state = const AsyncActionState.success(scope: 'open');
    return NotificationTarget.fromMap(targetRaw);
  }

  Future<bool> runAction(
    NotificationActionItem action, {
    int? notificationId,
    String notificationType = '',
  }) async {
    state = AsyncActionState.loading(scope: 'action:${action.kind}');
    final result = await _repository.runAction(action);
    if (result.ok) {
      unawaited(
        _repository.trackTelemetry([
          NotificationTelemetryEvent(
            notificationId: notificationId,
            notificationType: notificationType,
            eventName: 'action',
            surface: 'notifications_page',
            actionKind: action.kind,
          ),
        ]),
      );
      if (notificationId != null) {
        unawaited(_repository.markRead(notificationId));
      }
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

  Future<bool> delete(int notificationId) async {
    state = AsyncActionState.loading(scope: 'delete:$notificationId');
    final result = await _repository.deleteNotification(notificationId);
    if (result.ok) {
      ref.invalidate(notificationUnreadCountProvider);
      state = AsyncActionState.success(
        scope: 'delete:$notificationId',
        message:
            result.message.isNotEmpty ? result.message : 'Bildirim silindi.',
      );
      return true;
    }
    state = AsyncActionState.error(
      scope: 'delete:$notificationId',
      message: result.message.isNotEmpty
          ? result.message
          : 'Bildirim silinemedi.',
    );
    return false;
  }

  Future<bool> deleteAll() async {
    state = const AsyncActionState.loading(scope: 'deleteAll');
    final result = await _repository.deleteAllNotifications();
    if (result.ok) {
      _refreshAll();
      state = AsyncActionState.success(
        scope: 'deleteAll',
        message: result.message.isNotEmpty
            ? result.message
            : 'Tüm bildirimler silindi.',
      );
      return true;
    }
    state = AsyncActionState.error(
      scope: 'deleteAll',
      message: result.message.isNotEmpty
          ? result.message
          : 'Bildirimler silinemedi.',
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

  Future<void> trackImpressions(Iterable<AppNotification> items) async {
    await _repository.trackTelemetry(
      items
          .map(
            (item) => NotificationTelemetryEvent(
              notificationId: item.id,
              notificationType: item.type,
              eventName: 'impression',
              surface: 'notifications_page',
            ),
          )
          .toList(growable: false),
    );
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
    NotifierProvider.autoDispose<
      NotificationsActionController,
      AsyncActionState
    >(NotificationsActionController.new);
