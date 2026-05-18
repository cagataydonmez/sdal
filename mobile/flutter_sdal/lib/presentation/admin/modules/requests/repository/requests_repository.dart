import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../features/admin/data/admin_repository.dart' as legacy;
import '../models/requests_models.dart';

final adminRequestsRepositoryProvider = Provider<AdminRequestsRepository>(
  (ref) => AdminRequestsRepository(ref.watch(legacy.adminRepositoryProvider)),
);

class AdminRequestsRepository {
  const AdminRequestsRepository(this._adminRepository);

  final legacy.AdminRepository _adminRepository;

  Future<List<AdminRequestItem>> fetchRequests() async {
    final results = await Future.wait([
      _adminRepository.fetchMemberRequestPreview(limit: 30),
      _adminRepository.fetchVerificationRequestPreview(limit: 30),
      _adminRepository.fetchTeacherNetworkLinkPreview(limit: 30),
    ]);
    final memberRequests =
        results[0] as legacy.AdminPreviewList<legacy.AdminRequestQueueItem>;
    final verificationRequests =
        results[1]
            as legacy.AdminPreviewList<legacy.AdminVerificationQueueItem>;
    final teacherLinks =
        results[2]
            as legacy.AdminPreviewList<legacy.AdminTeacherNetworkLinkItem>;
    return [
      for (final item in memberRequests.items) _fromMemberRequest(item),
      for (final item in verificationRequests.items) _fromVerification(item),
      for (final item in teacherLinks.items) _fromTeacherNetwork(item),
    ];
  }

  Future<void> reviewRequest({
    required String id,
    required AdminRequestStatus status,
    required String reason,
  }) async {
    if (status == AdminRequestStatus.rejected && reason.trim().isEmpty) {
      throw ArgumentError('Reddetme gerekçesi zorunlu.');
    }
    final parts = id.split(':');
    if (parts.length != 2) throw ArgumentError('Geçersiz talep kimliği.');
    final numericId = int.tryParse(parts.last);
    if (numericId == null || numericId <= 0) {
      throw ArgumentError('Geçersiz talep kimliği.');
    }
    final backendStatus = status == AdminRequestStatus.approved
        ? 'approved'
        : 'rejected';
    switch (parts.first) {
      case 'member':
        await _adminRepository.reviewMemberRequest(
          id: numericId,
          status: backendStatus,
          resolutionNote: reason,
        );
        return;
      case 'verification':
        await _adminRepository.reviewVerificationRequest(
          id: numericId,
          status: backendStatus,
        );
        return;
      case 'teacher':
        await _adminRepository.reviewTeacherNetworkLink(
          id: numericId,
          status: backendStatus,
          note: reason,
        );
        return;
      default:
        throw ArgumentError('Desteklenmeyen talep tipi.');
    }
  }

  AdminRequestItem _fromMemberRequest(legacy.AdminRequestQueueItem item) {
    return AdminRequestItem(
      id: 'member:${item.id}',
      kind: AdminRequestKind.membership,
      requesterName: item.requesterName,
      graduationYear: item.requestedGraduationYear,
      summary: item.categoryLabel,
      status: _statusFromText(item.status),
      evidence: const <AdminVerificationEvidence>[],
    );
  }

  AdminRequestItem _fromVerification(legacy.AdminVerificationQueueItem item) {
    return AdminRequestItem(
      id: 'verification:${item.id}',
      kind: AdminRequestKind.graduationYearChange,
      requesterName: item.requesterName,
      graduationYear: item.graduationYear,
      summary: item.isTeacherVerification
          ? 'Öğretmen doğrulaması'
          : 'Profil doğrulama başvurusu',
      status: _statusFromText(item.status),
      evidence: [
        if (item.proofPath.isNotEmpty)
          AdminVerificationEvidence(
            label: 'Mezuniyet belgesi',
            url: item.proofPath,
            kind: 'document',
          ),
        if (item.proofImageRecordId.isNotEmpty)
          AdminVerificationEvidence(
            label: 'Kanıt görsel kaydı',
            url: item.proofImageRecordId,
            kind: 'image',
          ),
      ],
    );
  }

  AdminRequestItem _fromTeacherNetwork(
    legacy.AdminTeacherNetworkLinkItem item,
  ) {
    return AdminRequestItem(
      id: 'teacher:${item.id}',
      kind: AdminRequestKind.teacherNetwork,
      requesterName: item.alumniName,
      graduationYear: item.alumniGraduationYear,
      summary: '${item.teacherName} · ${item.relationshipType}',
      status: _statusFromText(item.reviewStatus),
      evidence: [
        if (item.notes.isNotEmpty)
          AdminVerificationEvidence(
            label: 'Başvuru notu',
            url: item.notes,
            kind: 'note',
          ),
      ],
    );
  }

  AdminRequestStatus _statusFromText(String value) {
    return switch (value.trim().toLowerCase()) {
      'approved' => AdminRequestStatus.approved,
      'rejected' => AdminRequestStatus.rejected,
      _ => AdminRequestStatus.pending,
    };
  }
}
