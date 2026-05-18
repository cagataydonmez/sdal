import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/moderation_models.dart';

final moderationRepositoryProvider = Provider<ModerationRepository>(
  (_) => ModerationRepository(),
);

class ModerationRepository {
  Future<List<ModerationItem>> fetchQueue() async {
    await Future<void>.delayed(const Duration(milliseconds: 240));
    final now = DateTime.now();
    return [
      ModerationItem(
        id: 'mod-101',
        type: ModerationContentType.post,
        title: 'Cohort grubunda kişisel veri paylaşımı',
        body:
            'Bir mezunun telefon numarası açık biçimde paylaşılmış. Raporlayanlar verinin kaldırılmasını istiyor.',
        authorName: 'Burak A.',
        authorRiskLabel: '1 uyarı, son 30 günde 2 rapor',
        violationCategory: PolicyCategory.personalData,
        severity: ModerationSeverity.critical,
        createdAt: now.subtract(const Duration(hours: 2)),
        reporters: [
          ModerationReporter(
            name: 'Elif K.',
            reason: 'Kişisel veri',
            reportedAt: now.subtract(const Duration(hours: 1, minutes: 42)),
          ),
          ModerationReporter(
            name: 'Mert Y.',
            reason: 'İzin yok',
            reportedAt: now.subtract(const Duration(hours: 1, minutes: 18)),
          ),
        ],
      ),
      ModerationItem(
        id: 'mod-102',
        type: ModerationContentType.comment,
        title: 'Tartışma başlığında saldırgan yorum',
        body:
            'Yorumda hedef gösteren ifadeler var. Üst kurul görüşü gerekebilir.',
        authorName: 'Derya S.',
        authorRiskLabel: 'Temiz sicil',
        violationCategory: PolicyCategory.harassment,
        severity: ModerationSeverity.high,
        createdAt: now.subtract(const Duration(hours: 5)),
        lock: ModerationLock(
          moderatorName: 'Deniz Moderatör',
          lockedAt: now.subtract(const Duration(minutes: 12)),
        ),
        reporters: [
          ModerationReporter(
            name: 'Ayşe T.',
            reason: 'Taciz',
            reportedAt: now.subtract(const Duration(hours: 4)),
          ),
        ],
      ),
      ModerationItem(
        id: 'mod-103',
        type: ModerationContentType.event,
        title: 'Onaysız etkinlik duyurusu',
        body:
            'Etkinlik okul dışı ve resmi bağlantı belirtmiyor. Yayından önce doğrulama istenmiş.',
        authorName: 'Selin P.',
        authorRiskLabel: 'Etkinlik sahibi',
        violationCategory: PolicyCategory.misinformation,
        severity: ModerationSeverity.medium,
        createdAt: now.subtract(const Duration(hours: 8)),
        reporters: [
          ModerationReporter(
            name: 'Operasyon Botu',
            reason: 'Otomatik politika eşleşmesi',
            reportedAt: now.subtract(const Duration(hours: 7)),
          ),
        ],
      ),
    ];
  }

  Future<ModerationItem> lockItem(ModerationItem item) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    if (item.isLockedByOther) return item;
    return item.copyWith(
      lock: ModerationLock(
        moderatorName: 'Mevcut Admin',
        lockedAt: DateTime.now(),
      ),
    );
  }

  Future<void> submitDecision(ModerationDecision decision) async {
    await Future<void>.delayed(const Duration(milliseconds: 220));
    if (decision.reason.trim().length < 8) {
      throw ArgumentError('Karar gerekçesi en az 8 karakter olmalı.');
    }
  }
}
