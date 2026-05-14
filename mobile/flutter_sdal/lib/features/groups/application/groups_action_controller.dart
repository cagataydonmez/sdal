import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/json_utils.dart';
import '../../../core/state/async_action_state.dart';
import '../data/groups_repository.dart';

class GroupsActionController extends Notifier<AsyncActionState> {
  GroupsRepository get _repository => ref.read(groupsRepositoryProvider);

  @override
  AsyncActionState build() => const AsyncActionState.idle();

  Future<bool> createGroup({
    required String name,
    required String description,
  }) async {
    state = const AsyncActionState.loading(scope: 'groups:create');
    final result = await _repository.createGroup(
      name: name,
      description: description,
    );
    if (result.ok) {
      state = const AsyncActionState.success(scope: 'groups:create');
      return true;
    }
    state = AsyncActionState.error(
      scope: 'groups:create',
      message: result.message.isNotEmpty
          ? result.message
          : 'Grup olusturulamadi.',
    );
    return false;
  }

  Future<String?> toggleJoin(int groupId) async {
    state = AsyncActionState.loading(scope: 'groups:join:$groupId');
    final result = await _repository.toggleJoin(groupId);
    if (result.ok) {
      state = const AsyncActionState.success(scope: 'groups:join');
      return coalesceText([
        asJsonMap(result.rawData)['membershipStatus'],
      ], fallback: '');
    }
    state = AsyncActionState.error(
      scope: 'groups:join:$groupId',
      message: result.message.isNotEmpty
          ? result.message
          : 'Uyelik islemi tamamlanamadi.',
    );
    return null;
  }

  Future<String?> leaveGroup(int groupId) async {
    state = AsyncActionState.loading(scope: 'groups:leave:$groupId');
    final result = await _repository.leaveGroup(groupId);
    if (result.ok) {
      state = const AsyncActionState.success(scope: 'groups:leave');
      return coalesceText([
        asJsonMap(result.rawData)['membershipStatus'],
      ], fallback: '');
    }
    state = AsyncActionState.error(
      scope: 'groups:leave:$groupId',
      message: result.message.isNotEmpty
          ? result.message
          : 'Gruptan ayrılma işlemi tamamlanamadı.',
    );
    return null;
  }

  Future<bool> respondToInvite({
    required int groupId,
    required String action,
  }) async {
    state = AsyncActionState.loading(scope: 'groups:invite:$groupId:$action');
    final result = await _repository.respondToInvite(
      groupId: groupId,
      action: action,
    );
    if (result.ok) {
      state = const AsyncActionState.success(scope: 'groups:invite');
      return true;
    }
    state = AsyncActionState.error(
      scope: 'groups:invite:$groupId:$action',
      message: result.message.isNotEmpty
          ? result.message
          : 'Davet islemi tamamlanamadi.',
    );
    return false;
  }

  Future<int?> inviteMembers({
    required int groupId,
    required List<int> userIds,
  }) async {
    state = AsyncActionState.loading(scope: 'groups:invite-members:$groupId');
    final result = await _repository.inviteMembers(
      groupId: groupId,
      userIds: userIds,
    );
    if (result.ok) {
      state = const AsyncActionState.success(scope: 'groups:invite-members');
      return asInt(asJsonMap(result.rawData)['sent']) ?? 0;
    }
    state = AsyncActionState.error(
      scope: 'groups:invite-members:$groupId',
      message: result.message.isNotEmpty
          ? result.message
          : 'Davetler gonderilemedi.',
    );
    return null;
  }

  Future<bool> reviewJoinRequest({
    required int groupId,
    required int requestId,
    required String action,
  }) async {
    state = AsyncActionState.loading(
      scope: 'groups:request:$groupId:$requestId:$action',
    );
    final result = await _repository.reviewJoinRequest(
      groupId: groupId,
      requestId: requestId,
      action: action,
    );
    if (result.ok) {
      state = const AsyncActionState.success(scope: 'groups:request');
      return true;
    }
    state = AsyncActionState.error(
      scope: 'groups:request:$groupId:$requestId:$action',
      message: result.message.isNotEmpty
          ? result.message
          : 'Katilim istegi guncellenemedi.',
    );
    return false;
  }

  Future<bool> updateSettings({
    required int groupId,
    required String visibility,
    required bool showContactHint,
  }) async {
    state = AsyncActionState.loading(scope: 'groups:settings:$groupId');
    final result = await _repository.updateSettings(
      groupId: groupId,
      visibility: visibility,
      showContactHint: showContactHint,
    );
    if (result.ok) {
      state = const AsyncActionState.success(scope: 'groups:settings');
      return true;
    }
    state = AsyncActionState.error(
      scope: 'groups:settings:$groupId',
      message: result.message.isNotEmpty
          ? result.message
          : 'Grup ayarlari kaydedilemedi.',
    );
    return false;
  }

  Future<bool> changeRole({
    required int groupId,
    required int userId,
    required String role,
  }) async {
    state = AsyncActionState.loading(scope: 'groups:role:$groupId:$userId');
    final result = await _repository.changeRole(
      groupId: groupId,
      userId: userId,
      role: role,
    );
    if (result.ok) {
      state = const AsyncActionState.success(scope: 'groups:role');
      return true;
    }
    state = AsyncActionState.error(
      scope: 'groups:role:$groupId:$userId',
      message: result.message.isNotEmpty
          ? result.message
          : 'Rol guncellenemedi.',
    );
    return false;
  }

  Future<bool> uploadCover({
    required int groupId,
    required File imageFile,
  }) async {
    state = AsyncActionState.loading(scope: 'groups:cover:$groupId');
    final result = await _repository.uploadCover(
      groupId: groupId,
      imageFile: imageFile,
    );
    if (result.ok) {
      state = const AsyncActionState.success(scope: 'groups:cover');
      return true;
    }
    state = AsyncActionState.error(
      scope: 'groups:cover:$groupId',
      message: result.message.isNotEmpty
          ? result.message
          : 'Kapak gorseli yuklenemedi.',
    );
    return false;
  }

  Future<bool> createPost({
    required int groupId,
    required String content,
    File? imageFile,
  }) async {
    state = AsyncActionState.loading(scope: 'groups:post:$groupId');
    final result = await _repository.createPost(
      groupId: groupId,
      content: content,
      imageFile: imageFile,
    );
    if (result.ok) {
      state = const AsyncActionState.success(scope: 'groups:post');
      return true;
    }
    state = AsyncActionState.error(
      scope: 'groups:post:$groupId',
      message: result.message.isNotEmpty
          ? result.message
          : 'Paylasim gonderilemedi.',
    );
    return false;
  }

  Future<bool> createEvent({
    required int groupId,
    required String title,
    required String description,
    required String location,
    required String startsAt,
    required String endsAt,
    File? imageFile,
    bool showInFeed = true,
    bool publish = true,
  }) async {
    state = AsyncActionState.loading(scope: 'groups:event:$groupId');
    final result = await _repository.createEvent(
      groupId: groupId,
      title: title,
      description: description,
      location: location,
      startsAt: startsAt,
      endsAt: endsAt,
      imageFile: imageFile,
      showInFeed: showInFeed,
      publish: publish,
    );
    if (result.ok) {
      state = const AsyncActionState.success(scope: 'groups:event');
      return true;
    }
    state = AsyncActionState.error(
      scope: 'groups:event:$groupId',
      message: result.message.isNotEmpty
          ? result.message
          : 'Etkinlik olusturulamadi.',
    );
    return false;
  }

  Future<bool> updateEvent({
    required int groupId,
    required int eventId,
    required String title,
    required String description,
    required String location,
    required String startsAt,
    required String endsAt,
    File? imageFile,
    bool? showInFeed,
    bool? publish,
  }) async {
    state = AsyncActionState.loading(scope: 'groups:event-update:$eventId');
    final result = await _repository.updateEvent(
      groupId: groupId,
      eventId: eventId,
      title: title,
      description: description,
      location: location,
      startsAt: startsAt,
      endsAt: endsAt,
      imageFile: imageFile,
      showInFeed: showInFeed,
      publish: publish,
    );
    if (result.ok) {
      state = const AsyncActionState.success(scope: 'groups:event-update');
      return true;
    }
    state = AsyncActionState.error(
      scope: 'groups:event-update:$eventId',
      message: result.message.isNotEmpty
          ? result.message
          : 'Etkinlik güncellenemedi.',
    );
    return false;
  }

  Future<bool> deleteEvent({required int groupId, required int eventId}) async {
    state = AsyncActionState.loading(scope: 'groups:event-delete:$eventId');
    final result = await _repository.deleteEvent(
      groupId: groupId,
      eventId: eventId,
    );
    if (result.ok) {
      state = const AsyncActionState.success(scope: 'groups:event-delete');
      return true;
    }
    state = AsyncActionState.error(
      scope: 'groups:event-delete:$eventId',
      message: result.message.isNotEmpty
          ? result.message
          : 'Etkinlik silinemedi.',
    );
    return false;
  }

  Future<bool> setEventPublished({
    required int groupId,
    required int eventId,
    required bool publish,
  }) async {
    state = AsyncActionState.loading(scope: 'groups:event-publish:$eventId');
    final result = await _repository.setEventPublished(
      groupId: groupId,
      eventId: eventId,
      publish: publish,
    );
    if (result.ok) {
      state = AsyncActionState.success(
        scope: 'groups:event-publish:$eventId',
        message: publish
            ? 'Etkinlik yayına alındı.'
            : 'Etkinlik taslaklara alındı.',
      );
      return true;
    }
    state = AsyncActionState.error(
      scope: 'groups:event-publish:$eventId',
      message: result.message.isNotEmpty
          ? result.message
          : 'Etkinlik durumu güncellenemedi.',
    );
    return false;
  }

  Future<bool> createAnnouncement({
    required int groupId,
    required String title,
    required String body,
    File? imageFile,
    bool showInFeed = true,
    bool publish = true,
  }) async {
    state = AsyncActionState.loading(scope: 'groups:announcement:$groupId');
    final result = await _repository.createAnnouncement(
      groupId: groupId,
      title: title,
      body: body,
      imageFile: imageFile,
      showInFeed: showInFeed,
      publish: publish,
    );
    if (result.ok) {
      state = const AsyncActionState.success(scope: 'groups:announcement');
      return true;
    }
    state = AsyncActionState.error(
      scope: 'groups:announcement:$groupId',
      message: result.message.isNotEmpty
          ? result.message
          : 'Duyuru eklenemedi.',
    );
    return false;
  }

  Future<bool> updateAnnouncement({
    required int groupId,
    required int announcementId,
    required String title,
    required String body,
    File? imageFile,
    bool? showInFeed,
    bool? publish,
  }) async {
    state = AsyncActionState.loading(
      scope: 'groups:announcement-update:$announcementId',
    );
    final result = await _repository.updateAnnouncement(
      groupId: groupId,
      announcementId: announcementId,
      title: title,
      body: body,
      imageFile: imageFile,
      showInFeed: showInFeed,
      publish: publish,
    );
    if (result.ok) {
      state = const AsyncActionState.success(
        scope: 'groups:announcement-update',
      );
      return true;
    }
    state = AsyncActionState.error(
      scope: 'groups:announcement-update:$announcementId',
      message: result.message.isNotEmpty
          ? result.message
          : 'Duyuru güncellenemedi.',
    );
    return false;
  }

  Future<bool> deleteAnnouncement({
    required int groupId,
    required int announcementId,
  }) async {
    state = AsyncActionState.loading(
      scope: 'groups:announcement-delete:$announcementId',
    );
    final result = await _repository.deleteAnnouncement(
      groupId: groupId,
      announcementId: announcementId,
    );
    if (result.ok) {
      state = const AsyncActionState.success(
        scope: 'groups:announcement-delete',
      );
      return true;
    }
    state = AsyncActionState.error(
      scope: 'groups:announcement-delete:$announcementId',
      message: result.message.isNotEmpty
          ? result.message
          : 'Duyuru silinemedi.',
    );
    return false;
  }

  Future<bool> setAnnouncementPublished({
    required int groupId,
    required int announcementId,
    required bool publish,
  }) async {
    state = AsyncActionState.loading(
      scope: 'groups:announcement-publish:$announcementId',
    );
    final result = await _repository.setAnnouncementPublished(
      groupId: groupId,
      announcementId: announcementId,
      publish: publish,
    );
    if (result.ok) {
      state = AsyncActionState.success(
        scope: 'groups:announcement-publish:$announcementId',
        message: publish
            ? 'Duyuru yayına alındı.'
            : 'Duyuru taslaklara alındı.',
      );
      return true;
    }
    state = AsyncActionState.error(
      scope: 'groups:announcement-publish:$announcementId',
      message: result.message.isNotEmpty
          ? result.message
          : 'Duyuru durumu güncellenemedi.',
    );
    return false;
  }
}

final groupsActionControllerProvider =
    NotifierProvider.autoDispose<GroupsActionController, AsyncActionState>(
      GroupsActionController.new,
    );
