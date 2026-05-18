import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../features/admin/data/admin_repository.dart' as legacy;
import '../../../core/security/audit_diff_viewer.dart';
import '../models/audit_logs_models.dart';

final auditLogsRepositoryProvider = Provider<AuditLogsRepository>(
  (ref) => AuditLogsRepository(ref.watch(legacy.adminRepositoryProvider)),
);

class AuditLogsRepository {
  const AuditLogsRepository(this._adminRepository);

  final legacy.AdminRepository _adminRepository;

  Future<AuditLogsSnapshot> fetchAuditLogs() async {
    final snapshot = await _adminRepository.fetchAuditLog();
    return AuditLogsSnapshot(
      entries: snapshot.items.map(_fromLegacy).toList(growable: false),
    );
  }

  AuditLogEntry _fromLegacy(legacy.AdminAuditLogItem item) {
    return AuditLogEntry(
      id: '${item.id}',
      actorName: item.actorLabel,
      action: item.action,
      target: '${item.targetType}:${item.targetId}',
      happenedAt: item.createdAt,
      diffEntries: _diffFromMetadata(item.metadata),
    );
  }

  List<AuditDiffEntry> _diffFromMetadata(Map<String, Object?> metadata) {
    final entries = <AuditDiffEntry>[];
    for (final entry in metadata.entries) {
      final value = entry.value;
      if (value is Map) {
        final oldValue = value['old'] ?? value['before'];
        final newValue = value['new'] ?? value['after'];
        if (oldValue != null || newValue != null) {
          entries.add(
            AuditDiffEntry(
              field: entry.key,
              oldValue: '$oldValue',
              newValue: '$newValue',
            ),
          );
          continue;
        }
      }
      entries.add(
        AuditDiffEntry(field: entry.key, oldValue: '-', newValue: '$value'),
      );
    }
    return entries;
  }
}
