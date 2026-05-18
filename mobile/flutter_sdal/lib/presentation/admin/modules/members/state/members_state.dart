import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/admin_theme.dart';
import '../models/members_models.dart';
import '../repository/members_repository.dart';

final membersControllerProvider =
    NotifierProvider<MembersController, MembersState>(MembersController.new);

class MembersState {
  const MembersState({required this.members, this.selectedId = ''});

  final AdminAsyncState<List<MemberRecord>> members;
  final String selectedId;

  MemberRecord? get selectedMember {
    for (final member in members.data ?? const <MemberRecord>[]) {
      if (member.id == selectedId) return member;
    }
    return null;
  }

  MembersState copyWith({
    AdminAsyncState<List<MemberRecord>>? members,
    String? selectedId,
  }) {
    return MembersState(
      members: members ?? this.members,
      selectedId: selectedId ?? this.selectedId,
    );
  }
}

class MembersController extends Notifier<MembersState> {
  @override
  MembersState build() {
    Future<void>.microtask(refresh);
    return const MembersState(members: AdminAsyncState.loading());
  }

  Future<void> refresh() async {
    state = state.copyWith(members: const AdminAsyncState.loading());
    try {
      final members = await ref.read(membersRepositoryProvider).fetchMembers();
      state = state.copyWith(
        members: members.isEmpty
            ? const AdminAsyncState.empty()
            : AdminAsyncState.loaded(members),
        selectedId: members.isEmpty ? '' : members.first.id,
      );
    } catch (error) {
      state = state.copyWith(members: AdminAsyncState.error(error.toString()));
    }
  }

  void select(MemberRecord member) {
    state = state.copyWith(selectedId: member.id);
  }

  Future<void> addWarning(String reason) async {
    final member = state.selectedMember;
    if (member == null) return;
    await ref
        .read(membersRepositoryProvider)
        .addWarning(memberId: member.id, reason: reason);
    _replaceSelected(
      member.copyWith(
        penaltyStatus: MemberPenaltyStatus.warned,
        timeline: [
          MemberTimelineEvent(
            title: 'Uyarı eklendi',
            detail: reason,
            happenedAt: DateTime.now(),
          ),
          ...member.timeline,
        ],
      ),
    );
  }

  Future<void> updateSelectedStatus({
    required MemberPenaltyStatus penaltyStatus,
    required String backendStatus,
    required String reason,
    required String timelineTitle,
  }) async {
    final member = state.selectedMember;
    if (member == null) return;
    await ref
        .read(membersRepositoryProvider)
        .updateStatus(
          memberId: member.id,
          status: backendStatus,
          reason: reason,
        );
    _replaceSelected(
      member.copyWith(
        penaltyStatus: penaltyStatus,
        timeline: [
          MemberTimelineEvent(
            title: timelineTitle,
            detail: reason,
            happenedAt: DateTime.now(),
          ),
          ...member.timeline,
        ],
      ),
    );
  }

  void _replaceSelected(MemberRecord updated) {
    final current = state.members.data ?? const <MemberRecord>[];
    state = state.copyWith(
      members: AdminAsyncState.loaded([
        for (final member in current)
          if (member.id == updated.id) updated else member,
      ]),
      selectedId: updated.id,
    );
  }

  void resetFilters() => Future<void>.microtask(refresh);
}
