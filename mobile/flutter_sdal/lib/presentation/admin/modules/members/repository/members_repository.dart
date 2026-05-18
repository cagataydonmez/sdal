import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/members_models.dart';

final membersRepositoryProvider = Provider<MembersRepository>(
  (_) => const MembersRepository(),
);

class MembersRepository {
  const MembersRepository();

  Future<List<MemberRecord>> fetchMembers() async {
    await Future<void>.delayed(const Duration(milliseconds: 220));
    final now = DateTime.now();
    return [
      MemberRecord(
        id: 'mem-1',
        name: 'Mina Demir',
        email: 'mina@example.com',
        graduationYear: '2012',
        role: 'Moderator',
        penaltyStatus: MemberPenaltyStatus.warned,
        timeline: [
          MemberTimelineEvent(
            title: 'Kayıt Oldu',
            detail: 'Mobil uygulamadan kayıt açtı.',
            happenedAt: now.subtract(const Duration(days: 240)),
          ),
          MemberTimelineEvent(
            title: 'Profil Doğrulandı',
            detail: 'LinkedIn ve mezuniyet yılı eşleşti.',
            happenedAt: now.subtract(const Duration(days: 238)),
          ),
          MemberTimelineEvent(
            title: '1 Uyarı Aldı',
            detail: 'Cohort dışı paylaşım uyarısı.',
            happenedAt: now.subtract(const Duration(days: 12)),
          ),
        ],
      ),
      MemberRecord(
        id: 'mem-2',
        name: 'Kerem Uslu',
        email: 'kerem@example.com',
        graduationYear: '2005',
        role: 'User',
        penaltyStatus: MemberPenaltyStatus.suspended,
        timeline: [
          MemberTimelineEvent(
            title: 'Kayıt Oldu',
            detail: 'Web üzerinden kayıt açtı.',
            happenedAt: now.subtract(const Duration(days: 420)),
          ),
          MemberTimelineEvent(
            title: 'Postu Silindi',
            detail: 'Kişisel veri paylaşımı kaldırıldı.',
            happenedAt: now.subtract(const Duration(days: 2)),
          ),
          MemberTimelineEvent(
            title: 'Askıya Alındı',
            detail: '24 saatlik güvenlik askısı.',
            happenedAt: now.subtract(const Duration(hours: 18)),
          ),
        ],
      ),
    ];
  }
}
