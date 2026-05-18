import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/admin_theme.dart';
import '../models/dashboard_models.dart';
import '../repository/dashboard_repository.dart';

final dashboardControllerProvider =
    NotifierProvider<DashboardController, AdminAsyncState<DashboardSnapshot>>(
      DashboardController.new,
    );

class DashboardController extends Notifier<AdminAsyncState<DashboardSnapshot>> {
  @override
  AdminAsyncState<DashboardSnapshot> build() {
    Future<void>.microtask(refresh);
    return const AdminAsyncState.loading();
  }

  Future<void> refresh() async {
    state = const AdminAsyncState.loading();
    try {
      final snapshot = await ref
          .read(dashboardRepositoryProvider)
          .fetchDashboard();
      state = snapshot.isEmpty
          ? const AdminAsyncState.empty()
          : AdminAsyncState.loaded(snapshot);
    } catch (error) {
      state = AdminAsyncState.error(error.toString());
    }
  }

  void resetFilters() {
    Future<void>.microtask(refresh);
  }
}
