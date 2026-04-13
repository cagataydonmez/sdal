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
    this.selectedUser,
    this.panelHeightFactor = 0.28,
    this.showPollingRequests = true,
    this.disabledCategories = const <String>{},
  });

  static const minPanelHeightFactor = 0.18;
  static const maxPanelHeightFactor = 0.76;

  final bool isEnabled;
  final AdminApiMonitorSelection? selectedUser;
  final double panelHeightFactor;
  final bool showPollingRequests;
  final Set<String> disabledCategories;

  bool get isExpanded => panelHeightFactor >= 0.45;

  AdminApiMonitorState copyWith({
    bool? isEnabled,
    AdminApiMonitorSelection? selectedUser,
    bool clearSelectedUser = false,
    double? panelHeightFactor,
    bool? showPollingRequests,
    Set<String>? disabledCategories,
  }) {
    return AdminApiMonitorState(
      isEnabled: isEnabled ?? this.isEnabled,
      selectedUser: clearSelectedUser
          ? null
          : (selectedUser ?? this.selectedUser),
      panelHeightFactor: panelHeightFactor ?? this.panelHeightFactor,
      showPollingRequests: showPollingRequests ?? this.showPollingRequests,
      disabledCategories: disabledCategories ?? this.disabledCategories,
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
    state = state.copyWith(isEnabled: false);
  }

  void toggleEnabled() {
    state.isEnabled ? deactivate() : activate();
  }

  void setPanelHeightFactor(double value) {
    state = state.copyWith(
      panelHeightFactor: value.clamp(
        AdminApiMonitorState.minPanelHeightFactor,
        AdminApiMonitorState.maxPanelHeightFactor,
      ),
    );
  }

  void adjustPanelHeightFactor(double delta) {
    setPanelHeightFactor(state.panelHeightFactor + delta);
  }

  void toggleExpanded() {
    setPanelHeightFactor(state.isExpanded ? 0.28 : 0.62);
  }

  void selectUser(AdminApiMonitorSelection selection) {
    state = state.copyWith(selectedUser: selection);
  }

  void useSelfAsDefault() {
    state = state.copyWith(clearSelectedUser: true);
  }

  void setShowPollingRequests(bool value) {
    state = state.copyWith(showPollingRequests: value);
  }

  void toggleCategory(String category) {
    final next = <String>{...state.disabledCategories};
    if (next.contains(category)) {
      next.remove(category);
    } else {
      next.add(category);
    }
    state = state.copyWith(disabledCategories: next);
  }

  void showAllCategories() {
    state = state.copyWith(disabledCategories: const <String>{});
  }
}

final adminApiMonitorControllerProvider =
    NotifierProvider<AdminApiMonitorController, AdminApiMonitorState>(
      AdminApiMonitorController.new,
    );
