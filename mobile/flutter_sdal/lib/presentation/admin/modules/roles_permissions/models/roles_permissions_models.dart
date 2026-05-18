enum AdminRole { root, admin, moderator, auditor }

enum PermissionModule {
  moderation,
  requests,
  members,
  communication,
  security,
  system,
  audit,
}

class PermissionMatrixRow {
  const PermissionMatrixRow({required this.module, required this.enabledRoles});

  final PermissionModule module;
  final Set<AdminRole> enabledRoles;

  PermissionMatrixRow toggle(AdminRole role, bool enabled) {
    final next = Set<AdminRole>.from(enabledRoles);
    if (enabled) {
      next.add(role);
    } else {
      next.remove(role);
    }
    return PermissionMatrixRow(module: module, enabledRoles: next);
  }
}

class CohortRestriction {
  const CohortRestriction({
    required this.moderatorName,
    required this.yearRange,
  });

  final String moderatorName;
  final String yearRange;
}

class RolesPermissionsSnapshot {
  const RolesPermissionsSnapshot({
    required this.rows,
    required this.restrictions,
  });

  final List<PermissionMatrixRow> rows;
  final List<CohortRestriction> restrictions;

  RolesPermissionsSnapshot copyWith({
    List<PermissionMatrixRow>? rows,
    List<CohortRestriction>? restrictions,
  }) {
    return RolesPermissionsSnapshot(
      rows: rows ?? this.rows,
      restrictions: restrictions ?? this.restrictions,
    );
  }
}

String adminRoleLabel(AdminRole role) {
  return switch (role) {
    AdminRole.root => 'Root',
    AdminRole.admin => 'Admin',
    AdminRole.moderator => 'Moderator',
    AdminRole.auditor => 'Auditor',
  };
}

String permissionModuleLabel(PermissionModule module) {
  return switch (module) {
    PermissionModule.moderation => 'Moderasyon',
    PermissionModule.requests => 'Talepler',
    PermissionModule.members => 'Üyeler',
    PermissionModule.communication => 'İletişim',
    PermissionModule.security => 'Güvenlik',
    PermissionModule.system => 'Sistem',
    PermissionModule.audit => 'Audit',
  };
}
