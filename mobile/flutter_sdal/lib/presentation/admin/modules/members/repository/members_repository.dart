import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../features/admin/data/admin_repository.dart' as legacy;
import '../models/members_models.dart';

final membersRepositoryProvider = Provider<MembersRepository>(
  (ref) => MembersRepository(ref.watch(legacy.adminRepositoryProvider)),
);

class MembersRepository {
  const MembersRepository(this._adminRepository);

  final legacy.AdminRepository _adminRepository;

  Future<List<MemberRecord>> fetchMembers() async {
    final preview = await _adminRepository.fetchUserPreview(
      query: const legacy.AdminUserListQuery(limit: 50),
    );
    return preview.items.map(_fromLegacy).toList(growable: false);
  }

  Future<void> addWarning({
    required String memberId,
    required String reason,
  }) async {
    await _adminRepository.addUserWarning(
      id: _numericId(memberId),
      reason: reason,
    );
  }

  Future<void> updateStatus({
    required String memberId,
    required String status,
    required String reason,
  }) async {
    await _adminRepository.updateUserStatus(
      id: _numericId(memberId),
      status: status,
      reason: reason,
    );
  }

  int _numericId(String memberId) {
    final id = int.tryParse(memberId) ?? 0;
    if (id <= 0) throw ArgumentError('Geçersiz üye kaydı.');
    return id;
  }

  MemberRecord _fromLegacy(legacy.AdminUserPreviewItem user) {
    return MemberRecord(
      id: '${user.id}',
      name: user.name,
      email: user.email,
      graduationYear: user.graduationYear,
      role: user.role,
      penaltyStatus: MemberPenaltyStatus.clear,
      timeline: [
        MemberTimelineEvent(
          title: 'Üye kaydı yüklendi',
          detail: user.handle.isEmpty ? user.email : '@${user.handle}',
          happenedAt: DateTime.now(),
        ),
        if (user.engagementScore > 0)
          MemberTimelineEvent(
            title: 'Engagement skoru',
            detail: '${user.engagementScore} puan',
            happenedAt: DateTime.now(),
          ),
      ],
    );
  }
}
