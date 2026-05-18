import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/requests_models.dart';

final adminRequestsRepositoryProvider = Provider<AdminRequestsRepository>(
  (_) => const AdminRequestsRepository(),
);

class AdminRequestsRepository {
  const AdminRequestsRepository();

  Future<List<AdminRequestItem>> fetchRequests() async {
    await Future<void>.delayed(const Duration(milliseconds: 210));
    return const [
      AdminRequestItem(
        id: 'req-201',
        kind: AdminRequestKind.membership,
        requesterName: 'Ece Karaca',
        graduationYear: '2014',
        summary:
            'Mezun hesabı açmak istiyor. LinkedIn profili okul bilgisiyle eşleşiyor.',
        status: AdminRequestStatus.pending,
        evidence: [
          AdminVerificationEvidence(
            label: 'LinkedIn URL',
            url: 'https://linkedin.com/in/ece-karaca',
            kind: 'link',
          ),
          AdminVerificationEvidence(
            label: 'Mezuniyet belgesi',
            url: 'secure://documents/req-201.pdf',
            kind: 'document',
          ),
        ],
      ),
      AdminRequestItem(
        id: 'req-202',
        kind: AdminRequestKind.teacherNetwork,
        requesterName: 'Can Öz',
        graduationYear: '2009',
        summary:
            'Öğretmen ağına yeni bağlantı ekledi, ilişki notu doğrulama bekliyor.',
        status: AdminRequestStatus.pending,
        evidence: [
          AdminVerificationEvidence(
            label: 'Öğretmen profili',
            url: 'https://sdal.example/teachers/42',
            kind: 'link',
          ),
        ],
      ),
    ];
  }

  Future<void> reviewRequest({
    required String id,
    required AdminRequestStatus status,
    required String reason,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 180));
    if (status == AdminRequestStatus.rejected && reason.trim().isEmpty) {
      throw ArgumentError('Reddetme gerekçesi zorunlu.');
    }
  }
}
