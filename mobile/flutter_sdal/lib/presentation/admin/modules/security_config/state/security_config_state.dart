import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/admin_theme.dart';
import '../models/security_config_models.dart';
import '../repository/security_config_repository.dart';

final securityConfigControllerProvider =
    NotifierProvider<
      SecurityConfigController,
      AdminAsyncState<SecurityConfigSnapshot>
    >(SecurityConfigController.new);

class SecurityConfigController
    extends Notifier<AdminAsyncState<SecurityConfigSnapshot>> {
  @override
  AdminAsyncState<SecurityConfigSnapshot> build() {
    Future<void>.microtask(refresh);
    return const AdminAsyncState.loading();
  }

  Future<void> refresh() async {
    state = const AdminAsyncState.loading();
    try {
      state = AdminAsyncState.loaded(
        await ref.read(securityConfigRepositoryProvider).fetchSecurityConfig(),
      );
    } catch (error) {
      state = AdminAsyncState.error(error.toString());
    }
  }

  Future<void> revokeSession(String sessionId, String securityToken) async {
    await ref
        .read(securityConfigRepositoryProvider)
        .revokeSession(sessionId, securityToken);
    await refresh();
  }

  void resetFilters() => Future<void>.microtask(refresh);
}
