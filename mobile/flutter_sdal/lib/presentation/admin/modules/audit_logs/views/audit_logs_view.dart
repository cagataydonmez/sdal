import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/adaptive_admin_scaffold.dart';
import '../../../core/security/audit_diff_viewer.dart';
import '../models/audit_logs_models.dart';
import '../state/audit_logs_state.dart';

class AuditLogsView extends ConsumerWidget {
  const AuditLogsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(auditLogsControllerProvider);
    final controller = ref.read(auditLogsControllerProvider.notifier);
    return AdminStateView<AuditLogsSnapshot>(
      state: state.snapshot,
      onRetry: controller.refresh,
      onResetFilters: controller.resetFilters,
      builder: (snapshot) => AdminAdaptiveWorkspace(
        title: 'Audit Logs',
        listPane: _AuditTable(
          entries: snapshot.entries,
          selectedId: state.selectedId,
        ),
        detailPane: AuditDiffViewer(
          entries: state.selectedEntry?.diffEntries ?? const <AuditDiffEntry>[],
        ),
        actionPane: _AuditContext(entry: state.selectedEntry),
      ),
    );
  }
}

class _AuditTable extends ConsumerWidget {
  const _AuditTable({required this.entries, required this.selectedId});

  final List<AuditLogEntry> entries;
  final String selectedId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(auditLogsControllerProvider.notifier);
    return AdminPanelCard(
      child: SingleChildScrollView(
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Actor')),
            DataColumn(label: Text('Action')),
            DataColumn(label: Text('Target')),
            DataColumn(label: Text('Time')),
          ],
          rows: [
            for (final entry in entries)
              DataRow(
                selected: entry.id == selectedId,
                onSelectChanged: (_) => controller.select(entry),
                cells: [
                  DataCell(Text(entry.actorName)),
                  DataCell(Text(entry.action)),
                  DataCell(Text(entry.target)),
                  DataCell(Text(entry.happenedAt)),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _AuditContext extends StatelessWidget {
  const _AuditContext({required this.entry});

  final AuditLogEntry? entry;

  @override
  Widget build(BuildContext context) {
    return AdminPanelCard(
      child: ListView(
        children: [
          Text(
            'Denetim izi bağlamı',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          Text('Actor: ${entry?.actorName ?? '-'}'),
          Text('Action: ${entry?.action ?? '-'}'),
          Text('Target: ${entry?.target ?? '-'}'),
          Text('Time: ${entry?.happenedAt ?? '-'}'),
        ],
      ),
    );
  }
}
