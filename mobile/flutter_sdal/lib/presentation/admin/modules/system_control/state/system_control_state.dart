import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/admin_theme.dart';
import '../models/system_control_models.dart';
import '../repository/system_control_repository.dart';

final systemControlControllerProvider =
    NotifierProvider<
      SystemControlController,
      AdminAsyncState<SystemControlSnapshot>
    >(SystemControlController.new);

class SystemControlController
    extends Notifier<AdminAsyncState<SystemControlSnapshot>> {
  @override
  AdminAsyncState<SystemControlSnapshot> build() {
    Future<void>.microtask(refresh);
    return const AdminAsyncState.loading();
  }

  Future<void> refresh() async {
    state = const AdminAsyncState.loading();
    try {
      state = AdminAsyncState.loaded(
        await ref.read(systemControlRepositoryProvider).fetchSystemControl(),
      );
    } catch (error) {
      state = AdminAsyncState.error(error.toString());
    }
  }

  void updateMaintenanceMode(bool value) {
    final current = state.data;
    if (current == null) return;
    state = AdminAsyncState.loaded(current.copyWith(maintenanceMode: value));
  }

  void updateRule(String platform, String version) {
    final current = state.data;
    if (current == null) return;
    state = AdminAsyncState.loaded(
      current.copyWith(
        updateRules: [
          for (final rule in current.updateRules)
            if (rule.platform == platform)
              rule.copyWith(minimumVersion: version)
            else
              rule,
        ],
      ),
    );
  }

  Future<void> save(String securityToken) async {
    final current = state.data;
    if (current == null) return;
    await ref
        .read(systemControlRepositoryProvider)
        .saveSettings(current, securityToken);
  }

  void resetFilters() => Future<void>.microtask(refresh);
}
