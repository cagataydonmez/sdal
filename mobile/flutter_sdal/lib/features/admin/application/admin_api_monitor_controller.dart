import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/admin_repository.dart';

class AdminApiMonitorSelection {
  const AdminApiMonitorSelection({
    required this.id,
    required this.name,
    required this.handle,
    required this.role,
  });

  final int id;
  final String name;
  final String handle;
  final String role;

  String get displayLabel => handle.isNotEmpty ? '@$handle' : name;

  factory AdminApiMonitorSelection.fromUserPreview(AdminUserPreviewItem item) {
    return AdminApiMonitorSelection(
      id: item.id,
      name: item.name,
      handle: item.handle,
      role: item.role,
    );
  }

  factory AdminApiMonitorSelection.fromMonitorUser(AdminApiMonitorUser user) {
    return AdminApiMonitorSelection(
      id: user.id,
      name: user.name,
      handle: user.handle,
      role: user.role,
    );
  }
}

class AdminApiMonitorState {
  const AdminApiMonitorState({
    this.isEnabled = false,
    this.isExpanded = false,
    this.selectedUser,
  });

  final bool isEnabled;
  final bool isExpanded;
  final AdminApiMonitorSelection? selectedUser;

  AdminApiMonitorState copyWith({
    bool? isEnabled,
    bool? isExpanded,
    AdminApiMonitorSelection? selectedUser,
    bool clearSelectedUser = false,
  }) {
    return AdminApiMonitorState(
      isEnabled: isEnabled ?? this.isEnabled,
      isExpanded: isExpanded ?? this.isExpanded,
      selectedUser: clearSelectedUser
          ? null
          : (selectedUser ?? this.selectedUser),
    );
  }
}

class AdminApiMonitorController extends Notifier<AdminApiMonitorState> {
  @override
  AdminApiMonitorState build() => const AdminApiMonitorState();

  void activate() {
    state = state.copyWith(isEnabled: true);
  }

  void deactivate() {
    state = state.copyWith(isEnabled: false, isExpanded: false);
  }

  void toggleEnabled() {
    if (state.isEnabled) {
      deactivate();
      return;
    }
    activate();
  }

  void setExpanded(bool value) {
    state = state.copyWith(isExpanded: value);
  }

  void toggleExpanded() {
    state = state.copyWith(isExpanded: !state.isExpanded);
  }

  void selectUser(AdminApiMonitorSelection selection) {
    state = state.copyWith(selectedUser: selection);
  }

  void useSelfAsDefault() {
    state = state.copyWith(clearSelectedUser: true);
  }
}

final adminApiMonitorControllerProvider =
    NotifierProvider<AdminApiMonitorController, AdminApiMonitorState>(
      AdminApiMonitorController.new,
    );
