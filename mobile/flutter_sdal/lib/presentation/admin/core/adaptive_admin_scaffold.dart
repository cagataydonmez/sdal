import 'package:flutter/material.dart';

import 'admin_theme.dart';

class AdaptiveAdminScaffold extends StatelessWidget {
  const AdaptiveAdminScaffold({
    super.key,
    required this.selectedModule,
    required this.onModuleSelected,
    required this.body,
    required this.onExit,
    this.actions = const <Widget>[],
  });

  final AdminModuleId selectedModule;
  final ValueChanged<AdminModuleId> onModuleSelected;
  final Widget body;
  final VoidCallback onExit;
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
              leading: IconButton(
                tooltip: 'Admin panelden çık',
                onPressed: onExit,
                icon: const Icon(Icons.close),
              ),
              title: Text(adminDestinations[safeIndex].label),
              actions: actions,
            ),
            body: body,
            bottomNavigationBar: SafeArea(
              top: false,
              child: _AdminMobileModuleBar(
                selectedIndex: safeIndex,
                onSelected: (index) =>
                    onModuleSelected(adminDestinations[index].id),
              ),
            ),
          );
        }

        final extended = breakpoint == AdminBreakpoint.desktop;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Yönetim Komuta Merkezi'),
            leading: IconButton(
              tooltip: 'Admin panelden çık',
              onPressed: onExit,
              icon: const Icon(Icons.close),
            ),
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

class _AdminMobileModuleBar extends StatefulWidget {
  const _AdminMobileModuleBar({
    required this.selectedIndex,
    required this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  State<_AdminMobileModuleBar> createState() => _AdminMobileModuleBarState();
}

class _AdminMobileModuleBarState extends State<_AdminMobileModuleBar> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToSelected());
  }

  @override
  void didUpdateWidget(covariant _AdminMobileModuleBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex != widget.selectedIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToSelected());
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToSelected() {
    if (!_scrollController.hasClients) return;
    final rawOffset = (widget.selectedIndex * 100.0) - 24.0;
    final targetOffset = rawOffset < 0 ? 0.0 : rawOffset;
    final cappedOffset =
        targetOffset > _scrollController.position.maxScrollExtent
        ? _scrollController.position.maxScrollExtent
        : targetOffset;
    _scrollController.animateTo(
      cappedOffset,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: SizedBox(
        height: 72,
        child: ListView.separated(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          scrollDirection: Axis.horizontal,
          itemCount: adminDestinations.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final destination = adminDestinations[index];
            final selected = index == widget.selectedIndex;
            return Semantics(
              selected: selected,
              button: true,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => widget.onSelected(index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  constraints: const BoxConstraints(minWidth: 92),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? scheme.primaryContainer
                        : scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: selected ? scheme.primary : scheme.outlineVariant,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        selected ? destination.selectedIcon : destination.icon,
                        size: 20,
                        color: selected
                            ? scheme.onPrimaryContainer
                            : scheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        destination.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: selected
                                  ? scheme.onPrimaryContainer
                                  : scheme.onSurfaceVariant,
                              fontWeight: selected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
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
            listPane: listPane,
            detailPane: detailPane,
            actionPane: actionPane,
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

class _AdminMobileWorkspace extends StatefulWidget {
  const _AdminMobileWorkspace({
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
  State<_AdminMobileWorkspace> createState() => _AdminMobileWorkspaceState();
}

class _AdminMobileWorkspaceState extends State<_AdminMobileWorkspace> {
  int _selectedPane = 0;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
          if (widget.header != null) ...[
            const SizedBox(height: 12),
            widget.header!,
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<int>(
              selected: {_selectedPane},
              onSelectionChanged: (selection) =>
                  setState(() => _selectedPane = selection.first),
              segments: const [
                ButtonSegment<int>(
                  value: 0,
                  icon: Icon(Icons.view_list_outlined),
                  label: Text('Liste'),
                ),
                ButtonSegment<int>(
                  value: 1,
                  icon: Icon(Icons.article_outlined),
                  label: Text('Detay'),
                ),
                ButtonSegment<int>(
                  value: 2,
                  icon: Icon(Icons.rule_outlined),
                  label: Text('İşlem'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: IndexedStack(
              index: _selectedPane,
              children: [
                _AdminMobilePane(child: widget.listPane),
                _AdminMobilePane(child: widget.detailPane),
                _AdminMobilePane(child: widget.actionPane),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminMobilePane extends StatelessWidget {
  const _AdminMobilePane({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(padding: const EdgeInsets.only(bottom: 12), child: child);
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
