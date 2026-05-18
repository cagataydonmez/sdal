import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/admin_theme.dart';
import '../models/roles_permissions_models.dart';
import '../repository/roles_permissions_repository.dart';

final rolesPermissionsControllerProvider =
    NotifierProvider<
      RolesPermissionsController,
      AdminAsyncState<RolesPermissionsSnapshot>
    >(RolesPermissionsController.new);

class RolesPermissionsController
    extends Notifier<AdminAsyncState<RolesPermissionsSnapshot>> {
  @override
  AdminAsyncState<RolesPermissionsSnapshot> build() {
    Future<void>.microtask(refresh);
    return const AdminAsyncState.loading();
  }

  Future<void> refresh() async {
    state = const AdminAsyncState.loading();
    try {
      state = AdminAsyncState.loaded(
        await ref.read(rolesPermissionsRepositoryProvider).fetchMatrix(),
      );
    } catch (error) {
      state = AdminAsyncState.error(error.toString());
    }
  }

  void toggle(PermissionModule module, AdminRole role, bool enabled) {
    final current = state.data;
    if (current == null) return;
    state = AdminAsyncState.loaded(
      current.copyWith(
        rows: [
          for (final row in current.rows)
            if (row.module == module) row.toggle(role, enabled) else row,
        ],
      ),
    );
  }

  Future<void> save() async {
    final current = state.data;
    if (current == null) return;
    await ref.read(rolesPermissionsRepositoryProvider).saveMatrix(current);
  }

  void resetFilters() => Future<void>.microtask(refresh);
}
