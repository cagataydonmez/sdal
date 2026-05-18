import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/admin_theme.dart';
import '../models/requests_models.dart';
import '../repository/requests_repository.dart';

final adminRequestsControllerProvider =
    NotifierProvider<AdminRequestsController, AdminRequestsState>(
      AdminRequestsController.new,
    );

class AdminRequestsState {
  const AdminRequestsState({
    required this.items,
    this.selectedId = '',
    this.message = '',
  });

  final AdminAsyncState<List<AdminRequestItem>> items;
  final String selectedId;
  final String message;

  AdminRequestItem? get selectedItem {
    for (final item in items.data ?? const <AdminRequestItem>[]) {
      if (item.id == selectedId) return item;
    }
    return null;
  }

  AdminRequestsState copyWith({
    AdminAsyncState<List<AdminRequestItem>>? items,
    String? selectedId,
    String? message,
  }) {
    return AdminRequestsState(
      items: items ?? this.items,
      selectedId: selectedId ?? this.selectedId,
      message: message ?? this.message,
    );
  }
}

class AdminRequestsController extends Notifier<AdminRequestsState> {
  @override
  AdminRequestsState build() {
    Future<void>.microtask(refresh);
    return const AdminRequestsState(items: AdminAsyncState.loading());
  }

  Future<void> refresh() async {
    state = state.copyWith(items: const AdminAsyncState.loading());
    try {
      final items = await ref
          .read(adminRequestsRepositoryProvider)
          .fetchRequests();
      state = state.copyWith(
        items: items.isEmpty
            ? const AdminAsyncState.empty()
            : AdminAsyncState.loaded(items),
        selectedId: items.isEmpty ? '' : items.first.id,
      );
    } catch (error) {
      state = state.copyWith(items: AdminAsyncState.error(error.toString()));
    }
  }

  void select(AdminRequestItem item) {
    state = state.copyWith(selectedId: item.id, message: '');
  }

  void resetFilters() => Future<void>.microtask(refresh);

  Future<void> review({
    required AdminRequestStatus status,
    required String reason,
  }) async {
    final selected = state.selectedItem;
    if (selected == null) return;
    await ref
        .read(adminRequestsRepositoryProvider)
        .reviewRequest(id: selected.id, status: status, reason: reason);
    final current = state.items.data ?? const <AdminRequestItem>[];
    final updated = [
      for (final item in current)
        if (item.id == selected.id) item.copyWith(status: status) else item,
    ];
    state = state.copyWith(
      items: AdminAsyncState.loaded(updated),
      message: status == AdminRequestStatus.approved
          ? 'Talep doğrulandı ve onaylandı.'
          : 'Talep gerekçeyle reddedildi.',
    );
  }
}
