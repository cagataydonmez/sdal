import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../features/admin/data/admin_repository.dart' as legacy;
import '../models/communication_models.dart';

final communicationRepositoryProvider = Provider<CommunicationRepository>(
  (ref) => CommunicationRepository(ref.watch(legacy.adminRepositoryProvider)),
);

class CommunicationRepository {
  const CommunicationRepository(this._adminRepository);

  final legacy.AdminRepository _adminRepository;

  Future<CommunicationSnapshot> loadComposer() async {
    final settings = await _adminRepository.fetchPushSettings();
    return CommunicationSnapshot(
      draft: const BroadcastDraft(
        segment: BroadcastTargetSegment.allMembers,
        title: '',
        body: '',
        imageUrl: '',
        deepLink: '/feed',
        cohort: '',
      ),
      dryRun: BroadcastDryRunResult(
        estimatedRecipients: settings.registeredUsers,
        validationMessage: settings.enabled
            ? 'Push servisi açık, kayıtlı cihaz verisi backendden alındı.'
            : 'Push servisi kapalı görünüyor.',
      ),
    );
  }

  Future<BroadcastDryRunResult> dryRun(BroadcastDraft draft) async {
    final settings = await _adminRepository.fetchPushSettings();
    final base = switch (draft.segment) {
      BroadcastTargetSegment.allMembers => settings.registeredUsers,
      BroadcastTargetSegment.graduatesOnly => settings.registeredUsers,
      BroadcastTargetSegment.teachersOnly => 0,
      BroadcastTargetSegment.cohort =>
        draft.cohort.trim().isEmpty ? 0 : settings.registeredUsers,
    };
    return BroadcastDryRunResult(
      estimatedRecipients: base,
      validationMessage: base == 0
          ? 'Cohort seçilmediği için alıcı bulunamadı.'
          : 'Bildirimi Test Et (Dry Run) tamamlandı.',
    );
  }

  Future<void> sendBroadcast({
    required BroadcastDraft draft,
    required String securityToken,
  }) async {
    if (securityToken.isEmpty) {
      throw ArgumentError('Toplu bildirim için step-up token zorunlu.');
    }
    await _adminRepository.sendNotificationBroadcast(
      target: _targetForSegment(draft.segment),
      sender: 'admin',
      title: draft.title,
      body: draft.body,
      imageUrl: draft.imageUrl,
      targetRoute: draft.deepLink,
      targetLabel: draft.deepLink,
    );
  }

  String _targetForSegment(BroadcastTargetSegment segment) {
    return switch (segment) {
      BroadcastTargetSegment.allMembers => 'all',
      BroadcastTargetSegment.graduatesOnly => 'verified',
      BroadcastTargetSegment.teachersOnly => 'teachers',
      BroadcastTargetSegment.cohort => 'cohort',
    };
  }
}
