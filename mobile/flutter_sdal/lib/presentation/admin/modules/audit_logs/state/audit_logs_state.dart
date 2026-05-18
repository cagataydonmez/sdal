import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/admin_theme.dart';
import '../models/audit_logs_models.dart';
import '../repository/audit_logs_repository.dart';

final auditLogsControllerProvider =
    NotifierProvider<AuditLogsController, AuditLogsState>(
      AuditLogsController.new,
    );

class AuditLogsState {
  const AuditLogsState({required this.snapshot, this.selectedId = ''});

  final AdminAsyncState<AuditLogsSnapshot> snapshot;
  final String selectedId;

  AuditLogEntry? get selectedEntry {
    for (final entry in snapshot.data?.entries ?? const <AuditLogEntry>[]) {
      if (entry.id == selectedId) return entry;
    }
    return null;
  }

  AuditLogsState copyWith({
    AdminAsyncState<AuditLogsSnapshot>? snapshot,
    String? selectedId,
  }) {
    return AuditLogsState(
      snapshot: snapshot ?? this.snapshot,
      selectedId: selectedId ?? this.selectedId,
    );
  }
}

class AuditLogsController extends Notifier<AuditLogsState> {
  @override
  AuditLogsState build() {
    Future<void>.microtask(refresh);
    return const AuditLogsState(snapshot: AdminAsyncState.loading());
  }

  Future<void> refresh() async {
    state = state.copyWith(snapshot: const AdminAsyncState.loading());
    try {
      final snapshot = await ref
          .read(auditLogsRepositoryProvider)
          .fetchAuditLogs();
      state = state.copyWith(
        snapshot: snapshot.entries.isEmpty
            ? const AdminAsyncState.empty()
            : AdminAsyncState.loaded(snapshot),
        selectedId: snapshot.entries.isEmpty ? '' : snapshot.entries.first.id,
      );
    } catch (error) {
      state = state.copyWith(snapshot: AdminAsyncState.error(error.toString()));
    }
  }

  void select(AuditLogEntry entry) {
    state = state.copyWith(selectedId: entry.id);
  }

  void resetFilters() => Future<void>.microtask(refresh);
}
