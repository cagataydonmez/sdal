import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/admin_theme.dart';
import '../models/moderation_models.dart';
import '../repository/moderation_repository.dart';

final moderationControllerProvider =
    NotifierProvider<ModerationController, ModerationQueueState>(
      ModerationController.new,
    );

class ModerationQueueState {
  const ModerationQueueState({
    required this.items,
    this.selectedId = '',
    this.search = '',
    this.message = '',
  });

  final AdminAsyncState<List<ModerationItem>> items;
  final String selectedId;
  final String search;
  final String message;

  List<ModerationItem> get visibleItems {
    final data = items.data ?? const <ModerationItem>[];
    if (search.trim().isEmpty) return data;
    final needle = search.toLowerCase();
    return data
        .where(
          (item) =>
              item.title.toLowerCase().contains(needle) ||
              item.authorName.toLowerCase().contains(needle),
        )
        .toList(growable: false);
  }

  ModerationItem? get selectedItem {
    for (final item in items.data ?? const <ModerationItem>[]) {
      if (item.id == selectedId) return item;
    }
    return null;
  }

  ModerationQueueState copyWith({
    AdminAsyncState<List<ModerationItem>>? items,
    String? selectedId,
    String? search,
    String? message,
  }) {
    return ModerationQueueState(
      items: items ?? this.items,
      selectedId: selectedId ?? this.selectedId,
      search: search ?? this.search,
      message: message ?? this.message,
    );
  }
}

class ModerationController extends Notifier<ModerationQueueState> {
  @override
  ModerationQueueState build() {
    Future<void>.microtask(refresh);
    return const ModerationQueueState(items: AdminAsyncState.loading());
  }

  Future<void> refresh() async {
    state = state.copyWith(items: const AdminAsyncState.loading(), message: '');
    try {
      final items = await ref.read(moderationRepositoryProvider).fetchQueue();
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

  Future<void> selectItem(ModerationItem item) async {
    final locked = await ref.read(moderationRepositoryProvider).lockItem(item);
    final current = state.items.data ?? const <ModerationItem>[];
    final updated = [
      for (final existing in current)
        if (existing.id == locked.id) locked else existing,
    ];
    state = state.copyWith(
      items: AdminAsyncState.loaded(updated),
      selectedId: locked.id,
      message: locked.isLockedByOther
          ? 'Moderatör ${locked.lock!.moderatorName} inceliyor'
          : '',
    );
  }

  void updateSearch(String value) {
    state = state.copyWith(search: value);
  }

  void resetFilters() {
    state = state.copyWith(search: '');
    Future<void>.microtask(refresh);
  }

  Future<void> submitDecision(ModerationDecision decision) async {
    await ref.read(moderationRepositoryProvider).submitDecision(decision);
    final current = state.items.data ?? const <ModerationItem>[];
    final updated = current
        .where((item) => item.id != decision.itemId)
        .toList(growable: false);
    state = state.copyWith(
      items: updated.isEmpty
          ? const AdminAsyncState.empty()
          : AdminAsyncState.loaded(updated),
      selectedId: updated.isEmpty ? '' : updated.first.id,
      message: 'Karar kaydedildi ve audit kuyruğuna işlendi.',
    );
  }
}
