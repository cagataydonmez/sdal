enum ModerationContentType { post, comment, story, job, event }

enum ModerationSeverity { low, medium, high, critical }

enum PolicyCategory {
  spam,
  personalData,
  harassment,
  misinformation,
  inappropriateMedia,
  wrongCohort,
}

enum ModerationActionType { approve, removeContent, banUser, escalate }

class ModerationReporter {
  const ModerationReporter({
    required this.name,
    required this.reason,
    required this.reportedAt,
  });

  final String name;
  final String reason;
  final DateTime reportedAt;
}

class ModerationLock {
  const ModerationLock({required this.moderatorName, required this.lockedAt});

  final String moderatorName;
  final DateTime lockedAt;
}

class ModerationItem {
  const ModerationItem({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.authorUserId,
    required this.authorName,
    required this.authorRiskLabel,
    required this.violationCategory,
    required this.severity,
    required this.reporters,
    required this.createdAt,
    this.lock,
  });

  final String id;
  final ModerationContentType type;
  final String title;
  final String body;
  final int authorUserId;
  final String authorName;
  final String authorRiskLabel;
  final PolicyCategory violationCategory;
  final ModerationSeverity severity;
  final List<ModerationReporter> reporters;
  final DateTime createdAt;
  final ModerationLock? lock;

  bool get isLockedByOther =>
      lock != null && lock!.moderatorName != 'Mevcut Admin';

  ModerationItem copyWith({ModerationLock? lock}) {
    return ModerationItem(
      id: id,
      type: type,
      title: title,
      body: body,
      authorUserId: authorUserId,
      authorName: authorName,
      authorRiskLabel: authorRiskLabel,
      violationCategory: violationCategory,
      severity: severity,
      reporters: reporters,
      createdAt: createdAt,
      lock: lock,
    );
  }
}

class ModerationDecision {
  const ModerationDecision({
    required this.itemId,
    required this.actionType,
    required this.policyCategory,
    required this.reason,
    required this.securityToken,
  });

  final String itemId;
  final ModerationActionType actionType;
  final PolicyCategory policyCategory;
  final String reason;
  final String securityToken;
}

String moderationContentTypeLabel(ModerationContentType type) {
  return switch (type) {
    ModerationContentType.post => 'Post',
    ModerationContentType.comment => 'Yorum',
    ModerationContentType.story => 'Hikaye',
    ModerationContentType.job => 'İlan',
    ModerationContentType.event => 'Etkinlik',
  };
}

String moderationSeverityValue(ModerationSeverity severity) {
  return switch (severity) {
    ModerationSeverity.low => 'low',
    ModerationSeverity.medium => 'medium',
    ModerationSeverity.high => 'high',
    ModerationSeverity.critical => 'critical',
  };
}

String moderationSeverityLabel(ModerationSeverity severity) {
  return switch (severity) {
    ModerationSeverity.low => 'Düşük',
    ModerationSeverity.medium => 'Orta',
    ModerationSeverity.high => 'Yüksek',
    ModerationSeverity.critical => 'Kritik',
  };
}

String policyCategoryLabel(PolicyCategory category) {
  return switch (category) {
    PolicyCategory.spam => 'Spam',
    PolicyCategory.personalData => 'Kişisel veri',
    PolicyCategory.harassment => 'Taciz',
    PolicyCategory.misinformation => 'Yanıltıcı bilgi',
    PolicyCategory.inappropriateMedia => 'Uygunsuz görsel',
    PolicyCategory.wrongCohort => 'Yanlış cohort',
  };
}
