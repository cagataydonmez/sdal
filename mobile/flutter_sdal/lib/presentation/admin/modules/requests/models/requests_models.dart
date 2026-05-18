enum AdminRequestKind { membership, graduationYearChange, teacherNetwork }

enum AdminRequestStatus { pending, approved, rejected }

class AdminVerificationEvidence {
  const AdminVerificationEvidence({
    required this.label,
    required this.url,
    required this.kind,
  });

  final String label;
  final String url;
  final String kind;
}

class AdminRequestItem {
  const AdminRequestItem({
    required this.id,
    required this.kind,
    required this.requesterName,
    required this.graduationYear,
    required this.summary,
    required this.status,
    required this.evidence,
  });

  final String id;
  final AdminRequestKind kind;
  final String requesterName;
  final String graduationYear;
  final String summary;
  final AdminRequestStatus status;
  final List<AdminVerificationEvidence> evidence;

  AdminRequestItem copyWith({AdminRequestStatus? status}) {
    return AdminRequestItem(
      id: id,
      kind: kind,
      requesterName: requesterName,
      graduationYear: graduationYear,
      summary: summary,
      status: status ?? this.status,
      evidence: evidence,
    );
  }
}

String adminRequestKindLabel(AdminRequestKind kind) {
  return switch (kind) {
    AdminRequestKind.membership => 'Üyelik talebi',
    AdminRequestKind.graduationYearChange => 'Mezuniyet yılı değişikliği',
    AdminRequestKind.teacherNetwork => 'Öğretmen Ağı başvurusu',
  };
}

String adminRequestStatusLabel(AdminRequestStatus status) {
  return switch (status) {
    AdminRequestStatus.pending => 'Bekliyor',
    AdminRequestStatus.approved => 'Onaylandı',
    AdminRequestStatus.rejected => 'Reddedildi',
  };
}
