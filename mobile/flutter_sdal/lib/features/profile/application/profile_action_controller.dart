import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/state/async_action_state.dart';
import '../../../core/session/session_controller.dart';
import '../data/profile_repository.dart';

class ProfileActionController extends Notifier<AsyncActionState> {
  ProfileRepository get _repository => ref.read(profileRepositoryProvider);

  @override
  AsyncActionState build() => const AsyncActionState.idle();

  Future<bool> updateProfile(ProfileData profile) async {
    state = const AsyncActionState.loading(scope: 'profile:update');
    final result = await _repository.updateProfile(profile);
    if (result.ok) {
      ref.invalidate(profileProvider);
      ref.invalidate(sessionControllerProvider);
      state = AsyncActionState.success(
        scope: 'profile:update',
        message: result.message.isNotEmpty
            ? result.message
            : 'Profil güncellendi.',
      );
      return true;
    }
    state = AsyncActionState.error(
      scope: 'profile:update',
      message: result.message.isNotEmpty
          ? result.message
          : 'Profil güncellenemedi.',
    );
    return false;
  }

  Future<bool> requestEmailChange(String email) async {
    state = const AsyncActionState.loading(scope: 'profile:email');
    final result = await _repository.requestEmailChange(email);
    if (result.ok) {
      state = AsyncActionState.success(
        scope: 'profile:email',
        message: result.message.isNotEmpty
            ? result.message
            : 'E-posta değişikliği isteği gönderildi.',
      );
      return true;
    }
    state = AsyncActionState.error(
      scope: 'profile:email',
      message: result.message.isNotEmpty
          ? result.message
          : 'İşlem başarısız oldu.',
    );
    return false;
  }

  Future<bool> changePassword({
    required String currentPassword,
    required String nextPassword,
    required String nextPasswordRepeat,
  }) async {
    state = const AsyncActionState.loading(scope: 'profile:password');
    final result = await _repository.changePassword(
      currentPassword: currentPassword,
      nextPassword: nextPassword,
      nextPasswordRepeat: nextPasswordRepeat,
    );
    if (result.ok) {
      state = AsyncActionState.success(
        scope: 'profile:password',
        message: result.message.isNotEmpty
            ? result.message
            : 'Şifre güncellendi.',
      );
      return true;
    }
    state = AsyncActionState.error(
      scope: 'profile:password',
      message: result.message.isNotEmpty
          ? result.message
          : 'Şifre değiştirilemedi.',
    );
    return false;
  }

  Future<bool> uploadPhoto(File file) async {
    state = const AsyncActionState.loading(scope: 'profile:photo');
    final result = await _repository.uploadPhoto(file);
    if (result.ok) {
      ref.invalidate(profileProvider);
      ref.invalidate(sessionControllerProvider);
      state = AsyncActionState.success(
        scope: 'profile:photo',
        message: result.message.isNotEmpty
            ? result.message
            : 'Profil fotoğrafı güncellendi.',
      );
      return true;
    }
    state = AsyncActionState.error(
      scope: 'profile:photo',
      message: result.message.isNotEmpty
          ? result.message
          : 'Fotoğraf yüklenemedi.',
    );
    return false;
  }

  Future<VerificationUploadResult?> uploadVerificationProof(File file) async {
    state = const AsyncActionState.loading(scope: 'profile:proof');
    final result = await _repository.uploadVerificationProof(file);
    if (!result.ok) {
      state = AsyncActionState.error(
        scope: 'profile:proof',
        message: result.message.isNotEmpty
            ? result.message
            : 'Kanıt yüklenemedi.',
      );
      return null;
    }
    final upload = VerificationUploadResult.fromMap(result.rawData);
    state = const AsyncActionState.success(
      scope: 'profile:proof',
      message: 'Kanıt dosyası yüklendi.',
    );
    return upload;
  }

  Future<bool> submitVerificationRequest({
    String proofPath = '',
    String proofImageRecordId = '',
  }) async {
    state = const AsyncActionState.loading(scope: 'profile:verification');
    final result = await _repository.submitVerificationRequest(
      proofPath: proofPath,
      proofImageRecordId: proofImageRecordId,
    );
    if (result.ok) {
      ref.invalidate(sessionControllerProvider);
      state = AsyncActionState.success(
        scope: 'profile:verification',
        message: result.message.isNotEmpty
            ? result.message
            : 'Doğrulama talebi gönderildi.',
      );
      return true;
    }
    state = AsyncActionState.error(
      scope: 'profile:verification',
      message: result.message.isNotEmpty
          ? result.message
          : 'Talep gönderilemedi.',
    );
    return false;
  }

  void reset() {
    state = const AsyncActionState.idle();
  }
}

final profileActionControllerProvider =
    NotifierProvider.autoDispose<ProfileActionController, AsyncActionState>(
      ProfileActionController.new,
    );
