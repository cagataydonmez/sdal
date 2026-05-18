import 'package:flutter/material.dart';

import 'admin_theme.dart';

class AdaptiveAdminScaffold extends StatelessWidget {
  const AdaptiveAdminScaffold({
    super.key,
    required this.selectedModule,
    required this.onModuleSelected,
    required this.body,
    this.actions = const <Widget>[],
  });

  final AdminModuleId selectedModule;
  final ValueChanged<AdminModuleId> onModuleSelected;
  final Widget body;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final breakpoint = adminBreakpointForWidth(constraints.maxWidth);
        final selectedIndex = adminDestinations.indexWhere(
          (destination) => destination.id == selectedModule,
        );
        final safeIndex = selectedIndex < 0 ? 0 : selectedIndex;

        if (breakpoint == AdminBreakpoint.mobile) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Yönetim Komuta Merkezi'),
              actions: actions,
            ),
            body: body,
            bottomNavigationBar: BottomNavigationBar(
              type: BottomNavigationBarType.fixed,
              currentIndex: safeIndex,
              onTap: (index) => onModuleSelected(adminDestinations[index].id),
              items: [
                for (final destination in adminDestinations)
                  BottomNavigationBarItem(
                    icon: Icon(destination.icon),
                    activeIcon: Icon(destination.selectedIcon),
                    label: destination.label,
                  ),
              ],
            ),
          );
        }

        final extended = breakpoint == AdminBreakpoint.desktop;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Yönetim Komuta Merkezi'),
            actions: actions,
          ),
          body: Row(
            children: [
              NavigationRail(
                extended: extended,
                selectedIndex: safeIndex,
                minExtendedWidth: 212,
                labelType: extended
                    ? NavigationRailLabelType.none
                    : NavigationRailLabelType.selected,
                onDestinationSelected: (index) =>
                    onModuleSelected(adminDestinations[index].id),
                destinations: [
                  for (final destination in adminDestinations)
                    NavigationRailDestination(
                      icon: Icon(destination.icon),
                      selectedIcon: Icon(destination.selectedIcon),
                      label: Text(destination.label),
                    ),
                ],
              ),
              const VerticalDivider(width: 1),
              Expanded(child: body),
            ],
          ),
        );
      },
    );
  }
}

class AdminAdaptiveWorkspace extends StatelessWidget {
  const AdminAdaptiveWorkspace({
    super.key,
    required this.title,
    required this.listPane,
    required this.detailPane,
    required this.actionPane,
    this.header,
  });

  final String title;
  final Widget? header;
  final Widget listPane;
  final Widget detailPane;
  final Widget actionPane;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final breakpoint = adminBreakpointForWidth(constraints.maxWidth);
        final content = switch (breakpoint) {
          AdminBreakpoint.mobile => _AdminMobileWorkspace(
            title: title,
            header: header,
            child: listPane,
          ),
          AdminBreakpoint.tablet => _AdminTabletWorkspace(
            title: title,
            header: header,
            listPane: listPane,
            detailPane: detailPane,
            actionPane: actionPane,
          ),
          AdminBreakpoint.desktop => _AdminDesktopWorkspace(
            title: title,
            header: header,
            listPane: listPane,
            detailPane: detailPane,
            actionPane: actionPane,
          ),
        };
        return content;
      },
    );
  }
}

class AdminStateView<T> extends StatelessWidget {
  const AdminStateView({
    super.key,
    required this.state,
    required this.onRetry,
    required this.onResetFilters,
    required this.builder,
  });

  final AdminAsyncState<T> state;
  final VoidCallback onRetry;
  final VoidCallback onResetFilters;
  final Widget Function(T data) builder;

  @override
  Widget build(BuildContext context) {
    if (state.isLoading) return const AdminLoadingSkeleton();
    if (state.status == AdminDataStatus.empty) {
      return AdminEmptyPanel(onResetFilters: onResetFilters);
    }
    if (state.status == AdminDataStatus.error) {
      return AdminErrorPanel(message: state.message, onRetry: onRetry);
    }
    final data = state.data;
    if (data == null) return const AdminLoadingSkeleton();
    return builder(data);
  }
}

class AdminLoadingSkeleton extends StatefulWidget {
  const AdminLoadingSkeleton({super.key});

  @override
  State<AdminLoadingSkeleton> createState() => _AdminLoadingSkeletonState();
}

class _AdminLoadingSkeletonState extends State<AdminLoadingSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHighest;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final opacity = 0.35 + (_controller.value * 0.35);
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: 7,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) => Opacity(
            opacity: opacity,
            child: Container(
              height: index == 0 ? 92 : 64,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        );
      },
    );
  }
}

class AdminEmptyPanel extends StatelessWidget {
  const AdminEmptyPanel({super.key, required this.onResetFilters});

  final VoidCallback onResetFilters;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off_outlined, size: 40),
            const SizedBox(height: 12),
            Text(
              'Aranan kriterlere uygun kayıt bulunamadı. Filtreleri temizleyebilirsiniz.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onResetFilters,
              icon: const Icon(Icons.filter_alt_off_outlined),
              label: const Text('Filtreleri Sıfırla'),
            ),
          ],
        ),
      ),
    );
  }
}

class AdminErrorPanel extends StatelessWidget {
  const AdminErrorPanel({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Container(
        margin: const EdgeInsets.all(20),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: scheme.errorContainer,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: scheme.error),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: scheme.onErrorContainer),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onErrorContainer),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Yeniden Dene'),
            ),
          ],
        ),
      ),
    );
  }
}

class AdminFilterBar extends StatelessWidget {
  const AdminFilterBar({
    super.key,
    required this.searchLabel,
    required this.onSearchChanged,
    required this.filters,
  });

  final String searchLabel;
  final ValueChanged<String> onSearchChanged;
  final List<Widget> filters;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search),
            labelText: searchLabel,
            border: const OutlineInputBorder(),
          ),
          onChanged: onSearchChanged,
        ),
        if (filters.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: filters),
        ],
      ],
    );
  }
}

class AdminDetailPlaceholder extends StatelessWidget {
  const AdminDetailPlaceholder({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 42, color: color),
            const SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }
}

class AdminPanelCard extends StatelessWidget {
  const AdminPanelCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(padding: padding, child: child),
    );
  }
}

class _AdminMobileWorkspace extends StatelessWidget {
  const _AdminMobileWorkspace({
    required this.title,
    required this.child,
    this.header,
  });

  final String title;
  final Widget? header;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(title, style: Theme.of(context).textTheme.headlineSmall),
        if (header != null) ...[const SizedBox(height: 12), header!],
        const SizedBox(height: 14),
        SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.68,
          child: child,
        ),
      ],
    );
  }
}

class _AdminTabletWorkspace extends StatelessWidget {
  const _AdminTabletWorkspace({
    required this.title,
    required this.listPane,
    required this.detailPane,
    required this.actionPane,
    this.header,
  });

  final String title;
  final Widget? header;
  final Widget listPane;
  final Widget detailPane;
  final Widget actionPane;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineSmall),
          if (header != null) ...[const SizedBox(height: 12), header!],
          const SizedBox(height: 14),
          Expanded(
            child: Row(
              children: [
                Expanded(flex: 4, child: listPane),
                const SizedBox(width: 12),
                Expanded(
                  flex: 6,
                  child: Column(
                    children: [
                      Expanded(flex: 6, child: detailPane),
                      const SizedBox(height: 12),
                      Expanded(flex: 4, child: actionPane),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminDesktopWorkspace extends StatelessWidget {
  const _AdminDesktopWorkspace({
    required this.title,
    required this.listPane,
    required this.detailPane,
    required this.actionPane,
    this.header,
  });

  final String title;
  final Widget? header;
  final Widget listPane;
  final Widget detailPane;
  final Widget actionPane;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineSmall),
          if (header != null) ...[const SizedBox(height: 12), header!],
          const SizedBox(height: 14),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 3, child: listPane),
                const SizedBox(width: 14),
                Expanded(flex: 5, child: detailPane),
                const SizedBox(width: 14),
                Expanded(flex: 3, child: actionPane),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
