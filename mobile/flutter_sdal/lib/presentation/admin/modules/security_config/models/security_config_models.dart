class SuspiciousLoginAttempt {
  const SuspiciousLoginAttempt({
    required this.ipPreview,
    required this.deviceHash,
    required this.location,
    required this.reason,
  });

  final String ipPreview;
  final String deviceHash;
  final String location;
  final String reason;
}

class AdminSessionRecord {
  const AdminSessionRecord({
    required this.id,
    required this.adminName,
    required this.device,
    required this.lastSeen,
  });

  final String id;
  final String adminName;
  final String device;
  final String lastSeen;
}

class VerificationLimitRecord {
  const VerificationLimitRecord({
    required this.userName,
    required this.channel,
    required this.attemptCount,
  });

  final String userName;
  final String channel;
  final int attemptCount;
}

class SecurityConfigSnapshot {
  const SecurityConfigSnapshot({
    required this.suspiciousLogins,
    required this.adminSessions,
    required this.limitRecords,
  });

  final List<SuspiciousLoginAttempt> suspiciousLogins;
  final List<AdminSessionRecord> adminSessions;
  final List<VerificationLimitRecord> limitRecords;
}
