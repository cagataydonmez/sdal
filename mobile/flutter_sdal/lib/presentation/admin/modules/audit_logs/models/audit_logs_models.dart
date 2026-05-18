import '../../../core/security/audit_diff_viewer.dart';

class AuditLogEntry {
  const AuditLogEntry({
    required this.id,
    required this.actorName,
    required this.action,
    required this.target,
    required this.happenedAt,
    required this.diffEntries,
  });

  final String id;
  final String actorName;
  final String action;
  final String target;
  final String happenedAt;
  final List<AuditDiffEntry> diffEntries;
}

class AuditLogsSnapshot {
  const AuditLogsSnapshot({required this.entries});

  final List<AuditLogEntry> entries;
}
