import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/state/async_action_state.dart';
import '../data/community_repository.dart';

class CommunityActionController extends AutoDisposeNotifier<AsyncActionState> {
  CommunityRepository get _repository => ref.read(communityRepositoryProvider);

  @override
  AsyncActionState build() => const AsyncActionState.idle();

  Future<bool> createAnnouncement({
    required String title,
    required String body,
    File? imageFile,
  }) async {
    state = const AsyncActionState.loading(scope: 'announcements:create');
    final result = await _repository.createAnnouncement(
      title: title,
      body: body,
      imageFile: imageFile,
    );
    if (result.ok) {
      state = AsyncActionState.success(
        scope: 'announcements:create',
        message: result.message.isNotEmpty
            ? result.message
            : 'Duyuru gönderildi.',
      );
      return true;
    }
    state = AsyncActionState.error(
      scope: 'announcements:create',
      message: result.message.isNotEmpty
          ? result.message
          : 'Duyuru gönderilemedi.',
    );
    return false;
  }

  Future<bool> createEvent({
    required String title,
    required String description,
    required String location,
    required String startsAt,
    required String endsAt,
    File? imageFile,
  }) async {
    state = const AsyncActionState.loading(scope: 'events:create');
    final result = await _repository.createEvent(
      title: title,
      description: description,
      location: location,
      startsAt: startsAt,
      endsAt: endsAt,
      imageFile: imageFile,
    );
    if (result.ok) {
      state = AsyncActionState.success(
        scope: 'events:create',
        message: result.message.isNotEmpty
            ? result.message
            : 'Etkinlik gönderildi.',
      );
      return true;
    }
    state = AsyncActionState.error(
      scope: 'events:create',
      message: result.message.isNotEmpty
          ? result.message
          : 'Etkinlik oluşturulamadı.',
    );
    return false;
  }

  Future<bool> addComment({
    required int eventId,
    required String comment,
  }) async {
    state = AsyncActionState.loading(scope: 'events:comment:$eventId');
    final result = await _repository.addEventComment(
      eventId: eventId,
      comment: comment,
    );
    if (result.ok) {
      state = const AsyncActionState.success(scope: 'events:comment');
      return true;
    }
    state = AsyncActionState.error(
      scope: 'events:comment:$eventId',
      message: result.message.isNotEmpty
          ? result.message
          : 'Yorum gönderilemedi.',
    );
    return false;
  }

  Future<bool> respond({required int eventId, required String response}) async {
    state = AsyncActionState.loading(scope: 'events:respond:$eventId');
    final result = await _repository.respondToEvent(
      eventId: eventId,
      response: response,
    );
    if (result.ok) {
      state = const AsyncActionState.success(scope: 'events:respond');
      return true;
    }
    state = AsyncActionState.error(
      scope: 'events:respond:$eventId',
      message: result.message.isNotEmpty
          ? result.message
          : 'Etkinlik yanıtı kaydedilemedi.',
    );
    return false;
  }

  Future<bool> updateVisibility({
    required int eventId,
    required bool showCounts,
    required bool showAttendeeNames,
    required bool showDeclinerNames,
  }) async {
    state = AsyncActionState.loading(scope: 'events:visibility:$eventId');
    final result = await _repository.updateResponseVisibility(
      eventId: eventId,
      showCounts: showCounts,
      showAttendeeNames: showAttendeeNames,
      showDeclinerNames: showDeclinerNames,
    );
    if (result.ok) {
      state = const AsyncActionState.success(scope: 'events:visibility');
      return true;
    }
    state = AsyncActionState.error(
      scope: 'events:visibility:$eventId',
      message: result.message.isNotEmpty
          ? result.message
          : 'Görünürlük ayarları kaydedilemedi.',
    );
    return false;
  }

  Future<bool> notifyAudience({
    required int eventId,
    required String mode,
  }) async {
    state = AsyncActionState.loading(scope: 'events:notify:$eventId');
    final result = await _repository.notifyEventAudience(
      eventId: eventId,
      mode: mode,
    );
    if (result.ok) {
      state = const AsyncActionState.success(scope: 'events:notify');
      return true;
    }
    state = AsyncActionState.error(
      scope: 'events:notify:$eventId',
      message: result.message.isNotEmpty
          ? result.message
          : 'Bildirim gönderilemedi.',
    );
    return false;
  }
}

final communityActionControllerProvider =
    AutoDisposeNotifierProvider<CommunityActionController, AsyncActionState>(
      CommunityActionController.new,
    );
