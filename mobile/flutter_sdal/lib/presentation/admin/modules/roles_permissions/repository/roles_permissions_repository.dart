import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/roles_permissions_models.dart';

final rolesPermissionsRepositoryProvider = Provider<RolesPermissionsRepository>(
  (_) => const RolesPermissionsRepository(),
);

class RolesPermissionsRepository {
  const RolesPermissionsRepository();

  Future<RolesPermissionsSnapshot> fetchMatrix() async {
    await Future<void>.delayed(const Duration(milliseconds: 210));
    return RolesPermissionsSnapshot(
      rows: [
        for (final module in PermissionModule.values)
          PermissionMatrixRow(
            module: module,
            enabledRoles: module == PermissionModule.system
                ? {AdminRole.root}
                : {
                    AdminRole.root,
                    AdminRole.admin,
                    if (module != PermissionModule.communication)
                      AdminRole.moderator,
                  },
          ),
      ],
      restrictions: const [
        CohortRestriction(
          moderatorName: 'Deniz Moderatör',
          yearRange: '2008-2016',
        ),
        CohortRestriction(
          moderatorName: 'Ayşe Moderatör',
          yearRange: '2017-2026',
        ),
      ],
    );
  }

  Future<void> saveMatrix(RolesPermissionsSnapshot snapshot) async {
    await Future<void>.delayed(const Duration(milliseconds: 180));
  }
}
