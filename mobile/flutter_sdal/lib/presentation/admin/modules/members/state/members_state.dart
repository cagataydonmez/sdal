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

  void resetFilters() => Future<void>.microtask(refresh);
}
