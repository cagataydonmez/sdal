import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/adaptive_admin_scaffold.dart';
import '../models/roles_permissions_models.dart';
import '../state/roles_permissions_state.dart';

class RolesPermissionsView extends ConsumerWidget {
  const RolesPermissionsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(rolesPermissionsControllerProvider);
    final controller = ref.read(rolesPermissionsControllerProvider.notifier);
    return AdminStateView<RolesPermissionsSnapshot>(
      state: state,
      onRetry: controller.refresh,
      onResetFilters: controller.resetFilters,
      builder: (snapshot) => AdminAdaptiveWorkspace(
        title: 'Rol ve İzin Mimarisi',
        listPane: _PermissionMatrix(snapshot: snapshot),
        detailPane: _RoleDescriptions(snapshot: snapshot),
        actionPane: _CohortRestrictions(snapshot: snapshot),
      ),
    );
  }
}

class _PermissionMatrix extends ConsumerWidget {
  const _PermissionMatrix({required this.snapshot});

  final RolesPermissionsSnapshot snapshot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(rolesPermissionsControllerProvider.notifier);
    return AdminPanelCard(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: [
            const DataColumn(label: Text('Modül')),
            for (final role in AdminRole.values)
              DataColumn(label: Text(adminRoleLabel(role))),
          ],
          rows: [
            for (final row in snapshot.rows)
              DataRow(
                cells: [
                  DataCell(Text(permissionModuleLabel(row.module))),
                  for (final role in AdminRole.values)
                    DataCell(
                      Checkbox(
                        value: row.enabledRoles.contains(role),
                        onChanged: role == AdminRole.root
                            ? null
                            : (value) => controller.toggle(
                                row.module,
                                role,
                                value ?? false,
                              ),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _RoleDescriptions extends StatelessWidget {
  const _RoleDescriptions({required this.snapshot});

  final RolesPermissionsSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return AdminPanelCard(
      child: ListView(
        children: [
          for (final role in AdminRole.values)
            ListTile(
              leading: const Icon(Icons.security_outlined),
              title: Text(adminRoleLabel(role)),
              subtitle: Text(_roleDescription(role)),
            ),
        ],
      ),
    );
  }

  String _roleDescription(AdminRole role) {
    return switch (role) {
      AdminRole.root => 'Sistem, DB, factory reset ve permission groups.',
      AdminRole.admin => 'Operasyonel yönetim ve moderasyon.',
      AdminRole.moderator => 'Cohort ve izin kapsamlı moderasyon.',
      AdminRole.auditor => 'Salt okunur denetim ve raporlama.',
    };
  }
}

class _CohortRestrictions extends ConsumerWidget {
  const _CohortRestrictions({required this.snapshot});

  final RolesPermissionsSnapshot snapshot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(rolesPermissionsControllerProvider.notifier);
    return AdminPanelCard(
      child: ListView(
        children: [
          Text(
            'Cohort Kısıtlaması',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          for (final restriction in snapshot.restrictions)
            TextFormField(
              initialValue: restriction.yearRange,
              decoration: InputDecoration(
                labelText: restriction.moderatorName,
                border: const OutlineInputBorder(),
              ),
            ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: controller.save,
            icon: const Icon(Icons.save_outlined),
            label: const Text('İzin Matrisini Kaydet'),
          ),
        ],
      ),
    );
  }
}
