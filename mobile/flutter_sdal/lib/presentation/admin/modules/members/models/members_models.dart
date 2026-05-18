enum MemberPenaltyStatus { clear, warned, suspended, banned }

class MemberTimelineEvent {
  const MemberTimelineEvent({
    required this.title,
    required this.detail,
    required this.happenedAt,
  });

  final String title;
  final String detail;
  final DateTime happenedAt;
}

class MemberRecord {
  const MemberRecord({
    required this.id,
    required this.name,
    required this.email,
    required this.graduationYear,
    required this.role,
    required this.penaltyStatus,
    required this.timeline,
  });

  final String id;
  final String name;
  final String email;
  final String graduationYear;
  final String role;
  final MemberPenaltyStatus penaltyStatus;
  final List<MemberTimelineEvent> timeline;

  MemberRecord copyWith({
    MemberPenaltyStatus? penaltyStatus,
    List<MemberTimelineEvent>? timeline,
  }) {
    return MemberRecord(
      id: id,
      name: name,
      email: email,
      graduationYear: graduationYear,
      role: role,
      penaltyStatus: penaltyStatus ?? this.penaltyStatus,
      timeline: timeline ?? this.timeline,
    );
  }
}

String memberPenaltyLabel(MemberPenaltyStatus status) {
  return switch (status) {
    MemberPenaltyStatus.clear => 'Temiz',
    MemberPenaltyStatus.warned => 'Uyarılı',
    MemberPenaltyStatus.suspended => 'Askıda',
    MemberPenaltyStatus.banned => 'Yasaklı',
  };
}
