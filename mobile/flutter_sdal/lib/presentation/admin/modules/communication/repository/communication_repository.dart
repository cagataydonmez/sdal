import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/communication_models.dart';

final communicationRepositoryProvider = Provider<CommunicationRepository>(
  (_) => const CommunicationRepository(),
);

class CommunicationRepository {
  const CommunicationRepository();

  Future<CommunicationSnapshot> loadComposer() async {
    await Future<void>.delayed(const Duration(milliseconds: 180));
    return const CommunicationSnapshot(
      draft: BroadcastDraft(
        segment: BroadcastTargetSegment.allMembers,
        title: 'SDAL Sosyal duyurusu',
        body: 'Topluluk için yeni bir güncelleme var.',
        imageUrl: '',
        deepLink: '/feed',
        cohort: '',
      ),
      dryRun: BroadcastDryRunResult(
        estimatedRecipients: 1840,
        validationMessage: 'Dry run başarılı, gönderim kuralları uygun.',
      ),
    );
  }

  Future<BroadcastDryRunResult> dryRun(BroadcastDraft draft) async {
    await Future<void>.delayed(const Duration(milliseconds: 170));
    final base = switch (draft.segment) {
      BroadcastTargetSegment.allMembers => 1840,
      BroadcastTargetSegment.graduatesOnly => 1510,
      BroadcastTargetSegment.teachersOnly => 92,
      BroadcastTargetSegment.cohort => draft.cohort.trim().isEmpty ? 0 : 128,
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
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (securityToken.isEmpty) {
      throw ArgumentError('Toplu bildirim için step-up token zorunlu.');
    }
  }
}
