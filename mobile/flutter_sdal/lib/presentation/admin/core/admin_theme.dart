import 'package:flutter/material.dart';

enum AdminBreakpoint { mobile, tablet, desktop }

enum AdminModuleId {
  dashboard,
  moderation,
  requests,
  members,
  communication,
  securityConfig,
  systemControl,
  rolesPermissions,
  auditLogs,
}

enum AdminDataStatus { initial, loading, loaded, empty, error }

class AdminAsyncState<T> {
  const AdminAsyncState._({required this.status, this.data, this.message = ''});

  const AdminAsyncState.initial() : this._(status: AdminDataStatus.initial);

  const AdminAsyncState.loading() : this._(status: AdminDataStatus.loading);

  const AdminAsyncState.loaded(T data)
    : this._(status: AdminDataStatus.loaded, data: data);

  const AdminAsyncState.empty()
    : this._(status: AdminDataStatus.empty, message: '');

  const AdminAsyncState.error(String message)
    : this._(status: AdminDataStatus.error, message: message);

  final AdminDataStatus status;
  final T? data;
  final String message;

  bool get isLoading =>
      status == AdminDataStatus.initial || status == AdminDataStatus.loading;
}

class AdminNavigationDestination {
  const AdminNavigationDestination({
    required this.id,
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final AdminModuleId id;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

const adminDestinations = <AdminNavigationDestination>[
  AdminNavigationDestination(
    id: AdminModuleId.dashboard,
    label: 'Komuta',
    icon: Icons.dashboard_outlined,
    selectedIcon: Icons.dashboard,
  ),
  AdminNavigationDestination(
    id: AdminModuleId.moderation,
    label: 'Moderasyon',
    icon: Icons.shield_outlined,
    selectedIcon: Icons.shield,
  ),
  AdminNavigationDestination(
    id: AdminModuleId.requests,
    label: 'Talepler',
    icon: Icons.assignment_turned_in_outlined,
    selectedIcon: Icons.assignment_turned_in,
  ),
  AdminNavigationDestination(
    id: AdminModuleId.members,
    label: 'Üyeler',
    icon: Icons.groups_outlined,
    selectedIcon: Icons.groups,
  ),
  AdminNavigationDestination(
    id: AdminModuleId.communication,
    label: 'İletişim',
    icon: Icons.campaign_outlined,
    selectedIcon: Icons.campaign,
  ),
  AdminNavigationDestination(
    id: AdminModuleId.securityConfig,
    label: 'Güvenlik',
    icon: Icons.phonelink_lock_outlined,
    selectedIcon: Icons.phonelink_lock,
  ),
  AdminNavigationDestination(
    id: AdminModuleId.systemControl,
    label: 'Sistem',
    icon: Icons.tune_outlined,
    selectedIcon: Icons.tune,
  ),
  AdminNavigationDestination(
    id: AdminModuleId.rolesPermissions,
    label: 'Yetkiler',
    icon: Icons.admin_panel_settings_outlined,
    selectedIcon: Icons.admin_panel_settings,
  ),
  AdminNavigationDestination(
    id: AdminModuleId.auditLogs,
    label: 'Audit',
    icon: Icons.fact_check_outlined,
    selectedIcon: Icons.fact_check,
  ),
];

AdminBreakpoint adminBreakpointForWidth(double width) {
  if (width < 600) return AdminBreakpoint.mobile;
  if (width < 840) return AdminBreakpoint.tablet;
  return AdminBreakpoint.desktop;
}

Color adminSeverityColor(BuildContext context, String severity) {
  final scheme = Theme.of(context).colorScheme;
  return switch (severity) {
    'critical' => scheme.error,
    'high' => Colors.deepOrange,
    'medium' => Colors.amber.shade800,
    'low' => scheme.primary,
    _ => scheme.outline,
  };
}

class AdminPanelTokens extends ThemeExtension<AdminPanelTokens> {
  const AdminPanelTokens({
    required this.success,
    required this.warning,
    required this.info,
    required this.danger,
    required this.surfaceTint,
  });

  final Color success;
  final Color warning;
  final Color info;
  final Color danger;
  final Color surfaceTint;

  static AdminPanelTokens of(BuildContext context) {
    final extension = Theme.of(context).extension<AdminPanelTokens>();
    if (extension != null) return extension;
    final scheme = Theme.of(context).colorScheme;
    return AdminPanelTokens(
      success: Colors.green.shade700,
      warning: Colors.orange.shade800,
      info: scheme.primary,
      danger: scheme.error,
      surfaceTint: scheme.surfaceContainerHighest,
    );
  }

  @override
  AdminPanelTokens copyWith({
    Color? success,
    Color? warning,
    Color? info,
    Color? danger,
    Color? surfaceTint,
  }) {
    return AdminPanelTokens(
      success: success ?? this.success,
      warning: warning ?? this.warning,
      info: info ?? this.info,
      danger: danger ?? this.danger,
      surfaceTint: surfaceTint ?? this.surfaceTint,
    );
  }

  @override
  AdminPanelTokens lerp(ThemeExtension<AdminPanelTokens>? other, double t) {
    if (other is! AdminPanelTokens) return this;
    return AdminPanelTokens(
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      info: Color.lerp(info, other.info, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      surfaceTint: Color.lerp(surfaceTint, other.surfaceTint, t)!,
    );
  }
}
