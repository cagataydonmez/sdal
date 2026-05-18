import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/adaptive_admin_scaffold.dart';
import 'core/admin_theme.dart';
import 'modules/audit_logs/views/audit_logs_view.dart';
import 'modules/communication/views/communication_view.dart';
import 'modules/dashboard/views/dashboard_view.dart';
import 'modules/members/views/members_view.dart';
import 'modules/moderation/views/moderation_view.dart';
import 'modules/requests/views/requests_view.dart';
import 'modules/roles_permissions/views/roles_permissions_view.dart';
import 'modules/security_config/views/security_config_view.dart';
import 'modules/system_control/views/system_control_view.dart';

class SdalAdaptiveAdminPanel extends ConsumerStatefulWidget {
  const SdalAdaptiveAdminPanel({
    super.key,
    this.initialModule = AdminModuleId.dashboard,
  });

  final AdminModuleId initialModule;

  @override
  ConsumerState<SdalAdaptiveAdminPanel> createState() =>
      _SdalAdaptiveAdminPanelState();
}

class _SdalAdaptiveAdminPanelState
    extends ConsumerState<SdalAdaptiveAdminPanel> {
  late AdminModuleId _selectedModule;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _selectedModule = widget.initialModule;
    _pageController = PageController(
      initialPage: _moduleIndex(widget.initialModule),
    );
  }

  @override
  void didUpdateWidget(covariant SdalAdaptiveAdminPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialModule != widget.initialModule) {
      _selectedModule = widget.initialModule;
      _pageController.jumpToPage(_moduleIndex(widget.initialModule));
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mobile = MediaQuery.sizeOf(context).width < 600;
    return Theme(
      data: theme.copyWith(
        extensions: [
          ...theme.extensions.values.where(
            (extension) => extension is! AdminPanelTokens,
          ),
          AdminPanelTokens(
            success: Colors.green.shade700,
            warning: Colors.orange.shade800,
            info: theme.colorScheme.primary,
            danger: theme.colorScheme.error,
            surfaceTint: theme.colorScheme.surfaceContainerHighest,
          ),
        ],
      ),
      child: AdaptiveAdminScaffold(
        selectedModule: _selectedModule,
        onModuleSelected: _selectModule,
        onExit: _exitAdminPanel,
        actions: [
          IconButton(
            tooltip: 'Güvenlik durumu',
            onPressed: () => _selectModule(AdminModuleId.securityConfig),
            icon: const Icon(Icons.security_outlined),
          ),
        ],
        body: PageView(
          controller: _pageController,
          physics: mobile
              ? const PageScrollPhysics()
              : const NeverScrollableScrollPhysics(),
          onPageChanged: (index) {
            final module = adminDestinations[index].id;
            if (module != _selectedModule) {
              setState(() => _selectedModule = module);
            }
          },
          children: [
            for (final destination in adminDestinations)
              _AdminModuleHost(module: destination.id),
          ],
        ),
      ),
    );
  }

  void _selectModule(AdminModuleId module) {
    final nextIndex = _moduleIndex(module);
    setState(() => _selectedModule = module);
    if (_pageController.hasClients) {
      _pageController.animateToPage(
        nextIndex,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _exitAdminPanel() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go('/');
  }

  int _moduleIndex(AdminModuleId module) {
    final index = adminDestinations.indexWhere(
      (destination) => destination.id == module,
    );
    return index < 0 ? 0 : index;
  }
}

class _AdminModuleHost extends StatelessWidget {
  const _AdminModuleHost({required this.module});

  final AdminModuleId module;

  @override
  Widget build(BuildContext context) {
    return switch (module) {
      AdminModuleId.dashboard => const DashboardView(),
      AdminModuleId.moderation => const ModerationView(),
      AdminModuleId.requests => const RequestsView(),
      AdminModuleId.members => const MembersView(),
      AdminModuleId.communication => const CommunicationView(),
      AdminModuleId.securityConfig => const SecurityConfigView(),
      AdminModuleId.systemControl => const SystemControlView(),
      AdminModuleId.rolesPermissions => const RolesPermissionsView(),
      AdminModuleId.auditLogs => const AuditLogsView(),
    };
  }
}
