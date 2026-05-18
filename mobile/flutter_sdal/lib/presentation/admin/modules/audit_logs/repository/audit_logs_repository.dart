import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/security/audit_diff_viewer.dart';
import '../models/audit_logs_models.dart';

final auditLogsRepositoryProvider = Provider<AuditLogsRepository>(
  (_) => const AuditLogsRepository(),
);

class AuditLogsRepository {
  const AuditLogsRepository();

  Future<AuditLogsSnapshot> fetchAuditLogs() async {
    await Future<void>.delayed(const Duration(milliseconds: 190));
    return const AuditLogsSnapshot(
      entries: [
        AuditLogEntry(
          id: 'aud-1',
          actorName: 'Root Admin',
          action: 'user.status.updated',
          target: 'Kerem Uslu',
          happenedAt: 'Bugün 14:22',
          diffEntries: [
            AuditDiffEntry(
              field: 'status',
              oldValue: 'active',
              newValue: 'suspended',
            ),
            AuditDiffEntry(
              field: 'reason',
              oldValue: '-',
              newValue: 'Kişisel veri paylaşımı',
            ),
          ],
        ),
        AuditLogEntry(
          id: 'aud-2',
          actorName: 'Operasyon Admin',
          action: 'broadcast.sent',
          target: 'Tüm Üyeler',
          happenedAt: 'Dün 19:04',
          diffEntries: [
            AuditDiffEntry(
              field: 'target',
              oldValue: 'dry_run',
              newValue: 'all_members',
            ),
            AuditDiffEntry(
              field: 'recipients',
              oldValue: '0',
              newValue: '1840',
            ),
          ],
        ),
      ],
    );
  }
}
