import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/admin_theme.dart';
import '../models/communication_models.dart';
import '../repository/communication_repository.dart';

final communicationControllerProvider =
    NotifierProvider<CommunicationController, CommunicationState>(
      CommunicationController.new,
    );

class CommunicationState {
  const CommunicationState({required this.snapshot, this.message = ''});

  final AdminAsyncState<CommunicationSnapshot> snapshot;
  final String message;

  CommunicationState copyWith({
    AdminAsyncState<CommunicationSnapshot>? snapshot,
    String? message,
  }) {
    return CommunicationState(
      snapshot: snapshot ?? this.snapshot,
      message: message ?? this.message,
    );
  }
}

class CommunicationController extends Notifier<CommunicationState> {
  @override
  CommunicationState build() {
    Future<void>.microtask(refresh);
    return const CommunicationState(snapshot: AdminAsyncState.loading());
  }

  Future<void> refresh() async {
    state = state.copyWith(snapshot: const AdminAsyncState.loading());
    try {
      final snapshot = await ref
          .read(communicationRepositoryProvider)
          .loadComposer();
      state = state.copyWith(snapshot: AdminAsyncState.loaded(snapshot));
    } catch (error) {
      state = state.copyWith(snapshot: AdminAsyncState.error(error.toString()));
    }
  }

  void updateDraft(BroadcastDraft draft) {
    final current = state.snapshot.data;
    if (current == null) return;
    state = state.copyWith(
      snapshot: AdminAsyncState.loaded(
        CommunicationSnapshot(draft: draft, dryRun: current.dryRun),
      ),
    );
  }

  Future<void> dryRun() async {
    final current = state.snapshot.data;
    if (current == null) return;
    final result = await ref
        .read(communicationRepositoryProvider)
        .dryRun(current.draft);
    state = state.copyWith(
      snapshot: AdminAsyncState.loaded(
        CommunicationSnapshot(draft: current.draft, dryRun: result),
      ),
      message: result.validationMessage,
    );
  }

  Future<void> send(String securityToken) async {
    final current = state.snapshot.data;
    if (current == null) return;
    await ref
        .read(communicationRepositoryProvider)
        .sendBroadcast(draft: current.draft, securityToken: securityToken);
    state = state.copyWith(
      message: 'Toplu bildirim gönderim kuyruğuna alındı.',
    );
  }

  void resetFilters() => Future<void>.microtask(refresh);
}
