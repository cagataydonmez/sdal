import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/adaptive_admin_scaffold.dart';
import '../../../core/security/step_up_auth_dialog.dart';
import '../models/system_control_models.dart';
import '../state/system_control_state.dart';

class SystemControlView extends ConsumerWidget {
  const SystemControlView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(systemControlControllerProvider);
    final controller = ref.read(systemControlControllerProvider.notifier);
    return AdminStateView<SystemControlSnapshot>(
      state: state,
      onRetry: controller.refresh,
      onResetFilters: controller.resetFilters,
      builder: (snapshot) => AdminAdaptiveWorkspace(
        title: 'Sistem Kontrolleri ve Lokalizasyon',
        listPane: _SystemSettings(snapshot: snapshot),
        detailPane: _LocalizationTable(snapshot: snapshot),
        actionPane: _SystemSavePanel(snapshot: snapshot),
      ),
    );
  }
}

class _SystemSettings extends ConsumerWidget {
  const _SystemSettings({required this.snapshot});

  final SystemControlSnapshot snapshot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(systemControlControllerProvider.notifier);
    return AdminPanelCard(
      child: ListView(
        children: [
          SwitchListTile(
            value: snapshot.maintenanceMode,
            onChanged: controller.updateMaintenanceMode,
            title: const Text('Bakım modu'),
            subtitle: const Text(
              'Açıldığında uygulama genel erişimi durdurulur.',
            ),
          ),
          const Divider(),
          for (final rule in snapshot.updateRules)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: TextFormField(
                initialValue: rule.minimumVersion,
                decoration: InputDecoration(
                  labelText: '${rule.platform} zorunlu minimum versiyon',
                  border: const OutlineInputBorder(),
                ),
                onChanged: (value) =>
                    controller.updateRule(rule.platform, value),
              ),
            ),
        ],
      ),
    );
  }
}

class _LocalizationTable extends StatelessWidget {
  const _LocalizationTable({required this.snapshot});

  final SystemControlSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return AdminPanelCard(
      child: SingleChildScrollView(
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Localization Key')),
            DataColumn(label: Text('TR')),
            DataColumn(label: Text('EN')),
          ],
          rows: [
            for (final row in snapshot.localizationRows)
              DataRow(
                cells: [
                  DataCell(Text(row.keyName)),
                  DataCell(Text(row.trValue)),
                  DataCell(Text(row.enValue)),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _SystemSavePanel extends ConsumerWidget {
  const _SystemSavePanel({required this.snapshot});

  final SystemControlSnapshot snapshot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(systemControlControllerProvider.notifier);
    return AdminPanelCard(
      child: ListView(
        children: [
          Text(
            'Değişiklik özeti',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            snapshot.maintenanceMode
                ? 'Bakım modu açılacak.'
                : 'Bakım modu kapalı kalacak.',
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () async {
              final token = await StepUpAuthDialog.confirm(
                context,
                operationLabel: 'Sistem ayarlarını kaydet',
                riskDescription:
                    'Bu işlem uygulama genel davranışını değiştirebilir.',
              );
              if (token != null) await controller.save(token.token);
            },
            icon: const Icon(Icons.save_outlined),
            label: const Text('Sistem Ayarlarını Kaydet'),
          ),
        ],
      ),
    );
  }
}
