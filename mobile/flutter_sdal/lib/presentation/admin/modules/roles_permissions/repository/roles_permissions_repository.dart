import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../features/admin/data/admin_repository.dart' as legacy;
import '../models/roles_permissions_models.dart';

final rolesPermissionsRepositoryProvider = Provider<RolesPermissionsRepository>(
  (ref) =>
      RolesPermissionsRepository(ref.watch(legacy.adminRepositoryProvider)),
);

class RolesPermissionsRepository {
  const RolesPermissionsRepository(this._adminRepository);

  final legacy.AdminRepository _adminRepository;

  Future<RolesPermissionsSnapshot> fetchMatrix() async {
    final definitions = await _adminRepository.fetchPermissions();
    final groups = await _adminRepository.fetchPermissionGroups();
    return RolesPermissionsSnapshot(
      rows: [
        for (final module in PermissionModule.values)
          PermissionMatrixRow(
            module: module,
            enabledRoles: _rolesForModule(module, definitions, groups),
          ),
      ],
      restrictions: const <CohortRestriction>[],
    );
  }

  Future<void> saveMatrix(RolesPermissionsSnapshot snapshot) async {
    await _adminRepository.savePermissionMatrix(
      rows: [
        for (final row in snapshot.rows)
          {
            'module': row.module.name,
            'roles': row.enabledRoles.map((role) => role.name).toList(),
          },
      ],
    );
  }

  Set<AdminRole> _rolesForModule(
    PermissionModule module,
    List<legacy.AdminPermissionDefinition> definitions,
    List<legacy.AdminPermissionGroup> groups,
  ) {
    final moduleNeedles = _needlesForModule(module);
    final keys = definitions
        .where(
          (definition) =>
              moduleNeedles.any((needle) => definition.key.contains(needle)),
        )
        .map((definition) => definition.key)
        .toSet();
    final roles = <AdminRole>{AdminRole.root};
    for (final group in groups) {
      final role = _roleFromGroup(group.name);
      if (role == null) continue;
      final hasPermission = group.permissions.any(
        (permission) =>
            keys.contains(permission.key) &&
            (permission.canRead || permission.canWrite),
      );
      if (hasPermission) roles.add(role);
    }
    return roles;
  }

  List<String> _needlesForModule(PermissionModule module) {
    return switch (module) {
      PermissionModule.moderation => ['post', 'story', 'comment', 'moderate'],
      PermissionModule.requests => ['request', 'verify', 'teacher'],
      PermissionModule.members => ['member', 'user', 'role'],
      PermissionModule.communication => [
        'communication',
        'notification',
        'push',
        'broadcast',
      ],
      PermissionModule.security => ['security', 'auth'],
      PermissionModule.system => ['site', 'language', 'database', 'operation'],
      PermissionModule.audit => ['audit'],
    };
  }

  AdminRole? _roleFromGroup(String name) {
    return switch (name.trim().toLowerCase()) {
      'admin' => AdminRole.admin,
      'mod' || 'moderator' => AdminRole.moderator,
      'auditor' => AdminRole.auditor,
      'root' => AdminRole.root,
      _ => null,
    };
  }
}
