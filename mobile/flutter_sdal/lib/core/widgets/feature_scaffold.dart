import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../l10n/context_l10n.dart';
import '../shell/shell_metadata_repository.dart';
import '../session/session_controller.dart';
import '../session/session_models.dart';
import '../theme/sdal_theme_tokens.dart';
import 'remote_avatar.dart';

enum FeatureScaffoldBackground { neutral, editorial, utility, immersive }

class FeatureScaffold extends ConsumerWidget {
  const FeatureScaffold({
    super.key,
    required this.title,
    required this.child,
    this.actions,
    this.floatingActionButton,
    this.background = FeatureScaffoldBackground.neutral,
  });

  final String title;
  final Widget child;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final FeatureScaffoldBackground background;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = Theme.of(context).sdal;
    final l10n = context.l10n;
    final session = ref.watch(sessionControllerProvider).valueOrNull;
    final shellMenu = ref.watch(shellMenuProvider).valueOrNull;
    final shellSidebar = ref.watch(shellSidebarProvider).valueOrNull;
    final location = GoRouterState.of(context).uri.path;
    final canPop = Navigator.of(context).canPop();
    final resolvedActions = <Widget>[
      ...?actions,
      _AppMenuButton(
        session: session,
        currentLocation: location,
        shellMenu: shellMenu,
        shellSidebar: shellSidebar,
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leadingWidth: session?.user != null ? (canPop ? 92 : 64) : null,
        leading: session?.user != null
            ? _ProfileLeading(session: session!, canPop: canPop)
            : (canPop ? const BackButton() : null),
        centerTitle: true,
        title: canPop
            ? Text(title)
            : Tooltip(
                message: l10n.tabFeed,
                child: Semantics(
                  button: true,
                  label: l10n.tabFeed,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => context.go('/feed'),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: tokens.panelBorder,
                          width: 1.5,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10.5),
                        child: ExcludeSemantics(
                          child: Image.asset('icon.png', height: 32, width: 32),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
        actions: resolvedActions,
      ),
      floatingActionButton: floatingActionButton,
      body: Container(
        decoration: switch (background) {
          FeatureScaffoldBackground.editorial => BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [tokens.canvas, tokens.canvasSubtle],
            ),
          ),
          FeatureScaffoldBackground.utility => BoxDecoration(
            color: tokens.panelMuted,
          ),
          FeatureScaffoldBackground.immersive => BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [tokens.canvasSubtle, tokens.canvas],
            ),
          ),
          FeatureScaffoldBackground.neutral => BoxDecoration(
            color: tokens.canvas,
          ),
        },
        child: SafeArea(top: false, child: child),
      ),
    );
  }
}

class _ProfileLeading extends StatelessWidget {
  const _ProfileLeading({required this.session, required this.canPop});

  final SessionSnapshot session;
  final bool canPop;

  @override
  Widget build(BuildContext context) {
    final user = session.user;
    final l10n = context.l10n;
    if (user == null) {
      return canPop ? const BackButton() : const SizedBox.shrink();
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(width: 8),
        Semantics(
          button: true,
          label: l10n.profileOpenAction,
          child: Tooltip(
            message: l10n.profileOpenAction,
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: () => context.go('/profile'),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Center(
                    child: RemoteAvatar(
                      label: user.displayName,
                      imageUrl: session.config
                          .resolveUrl(user.photo)
                          .toString(),
                      radius: 16,
                      excludeFromSemantics: true,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (canPop)
          IconButton(
            tooltip: l10n.backAction,
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.chevron_left_rounded),
          ),
      ],
    );
  }
}

class _AppMenuButton extends StatelessWidget {
  const _AppMenuButton({
    required this.session,
    required this.currentLocation,
    required this.shellMenu,
    required this.shellSidebar,
  });

  final SessionSnapshot? session;
  final String currentLocation;
  final ShellMenuSnapshot? shellMenu;
  final ShellSidebarSnapshot? shellSidebar;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return IconButton(
      tooltip: l10n.quickMenuAction,
      onPressed: () {
        showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          showDragHandle: true,
          builder: (sheetContext) => _AppMenuSheet(
            session: session,
            currentLocation: currentLocation,
            shellMenu: shellMenu,
            shellSidebar: shellSidebar,
          ),
        );
      },
      icon: const Icon(Icons.grid_view_rounded),
    );
  }
}

class _AppMenuSheet extends ConsumerWidget {
  const _AppMenuSheet({
    required this.session,
    required this.currentLocation,
    required this.shellMenu,
    required this.shellSidebar,
  });

  final SessionSnapshot? session;
  final String currentLocation;
  final ShellMenuSnapshot? shellMenu;
  final ShellSidebarSnapshot? shellSidebar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final user = session?.user;
    final quickAccessUsers =
        ref.watch(quickAccessUsersProvider).valueOrNull ??
        const <QuickAccessUser>[];
    final menuLabelsByRoute = <String, String>{
      for (final item in shellMenu?.appItems ?? const <ShellMenuItem>[])
        if (item.appRoute != null) item.appRoute!: item.label,
    };
    final communityEntries = _sortModuleEntries([
      if (_isModuleVisible('groups'))
        _MenuEntry(
          route: '/groups',
          icon: Icons.groups_outlined,
          label: menuLabelsByRoute['/groups'] ?? l10n.groupsTitle,
          moduleKey: 'groups',
        ),
      if (_isModuleVisible('events'))
        _MenuEntry(
          route: '/events',
          icon: Icons.event_outlined,
          label: menuLabelsByRoute['/events'] ?? 'Etkinlikler',
          moduleKey: 'events',
        ),
      if (_isModuleVisible('announcements'))
        _MenuEntry(
          route: '/announcements',
          icon: Icons.campaign_outlined,
          label: menuLabelsByRoute['/announcements'] ?? 'Duyurular',
          moduleKey: 'announcements',
        ),
      if (_isModuleVisible('requests'))
        _MenuEntry(
          route: '/requests',
          icon: Icons.assignment_outlined,
          label: menuLabelsByRoute['/requests'] ?? l10n.requestsTitle,
          moduleKey: 'requests',
        ),
      if (_isModuleVisible('networking'))
        _MenuEntry(
          route: '/network/hub',
          icon: Icons.hub_outlined,
          label: menuLabelsByRoute['/network/hub'] ?? 'Networking',
          moduleKey: 'networking',
        ),
      if (_isModuleVisible('teachers_network'))
        _MenuEntry(
          route: '/network/teachers',
          icon: Icons.school_outlined,
          label:
              menuLabelsByRoute['/network/teachers'] ?? 'Ogretmen baglantilari',
          moduleKey: 'teachers_network',
        ),
      if (_isModuleVisible('jobs'))
        _MenuEntry(
          route: '/jobs',
          icon: Icons.work_outline,
          label: menuLabelsByRoute['/jobs'] ?? l10n.jobsTitle,
          moduleKey: 'jobs',
        ),
      if (_isModuleVisible('opportunities'))
        _MenuEntry(
          route: '/opportunities',
          icon: Icons.auto_awesome_outlined,
          label: menuLabelsByRoute['/opportunities'] ?? 'Firsatlar',
          moduleKey: 'opportunities',
        ),
      if (_isModuleVisible('albums'))
        _MenuEntry(
          route: '/albums',
          icon: Icons.photo_library_outlined,
          label: menuLabelsByRoute['/albums'] ?? l10n.albumsTitle,
          moduleKey: 'albums',
        ),
      if (_isModuleVisible('following'))
        _MenuEntry(
          route: '/following',
          icon: Icons.favorite_border,
          label: menuLabelsByRoute['/following'] ?? 'Takipler',
          moduleKey: 'following',
        ),
      if (_isModuleVisible('feed'))
        _MenuEntry(
          route: '/feed/live-chat',
          icon: Icons.forum_outlined,
          label: menuLabelsByRoute['/feed/live-chat'] ?? l10n.liveChatTitle,
          moduleKey: 'feed',
        ),
    ]);
    final staticRoutes = {
      '/feed',
      '/explore',
      '/inbox',
      '/notifications',
      '/profile',
      for (final entry in communityEntries) entry.route,
      '/admin',
    };
    final extraMenuEntries = (shellMenu?.appItems ?? const <ShellMenuItem>[])
        .where(
          (item) =>
              item.appRoute != null && !staticRoutes.contains(item.appRoute),
        )
        .map(
          (item) => _MenuEntry(
            route: item.appRoute!,
            icon: iconForShellRoute(item.appRoute!),
            label: item.label,
          ),
        )
        .toList(growable: false);
    final sections = <_MenuSection>[
      _MenuSection(
        title: 'Ana gezinme',
        entries: [
          _MenuEntry(
            route: '/feed',
            icon: Icons.dynamic_feed_outlined,
            label: menuLabelsByRoute['/feed'] ?? l10n.feedTitle,
          ),
          _MenuEntry(
            route: '/explore',
            icon: Icons.explore_outlined,
            label: menuLabelsByRoute['/explore'] ?? l10n.exploreTitle,
          ),
          _MenuEntry(
            route: '/inbox',
            icon: Icons.chat_bubble_outline,
            label: menuLabelsByRoute['/inbox'] ?? l10n.tabInbox,
          ),
          _MenuEntry(
            route: '/notifications',
            icon: Icons.notifications_outlined,
            label:
                menuLabelsByRoute['/notifications'] ?? l10n.notificationsTitle,
          ),
          _MenuEntry(
            route: '/profile',
            icon: Icons.person_outline,
            label: menuLabelsByRoute['/profile'] ?? l10n.profileTitle,
          ),
        ],
      ),
      if (communityEntries.isNotEmpty)
        _MenuSection(title: 'Topluluk', entries: communityEntries),
      if (extraMenuEntries.isNotEmpty)
        _MenuSection(title: 'Ek sayfalar', entries: extraMenuEntries),
      if (user?.isAdmin ?? false)
        const _MenuSection(
          title: 'Yonetim',
          entries: [
            _MenuEntry(
              route: '/admin',
              icon: Icons.admin_panel_settings_outlined,
              label: 'Admin paneli',
            ),
          ],
        ),
    ];

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: ListView(
          shrinkWrap: true,
          children: [
            if (user != null) ...[
              Text(
                user.displayName,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(
                '@${user.kadi}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).sdal.foregroundMuted,
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (shellSidebar != null) ...[
              _SidebarHighlights(sidebar: shellSidebar!),
              const SizedBox(height: 18),
            ],
            if (quickAccessUsers.isNotEmpty) ...[
              Text(
                'Hızlı erişim',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Card(
                margin: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (
                      var index = 0;
                      index < quickAccessUsers.length;
                      index++
                    )
                      _QuickAccessTile(
                        user: quickAccessUsers[index],
                        session: session,
                        showDivider: index < quickAccessUsers.length - 1,
                        onRemove: () async {
                          final messenger = ScaffoldMessenger.of(context);
                          final result = await ref
                              .read(shellMetadataRepositoryProvider)
                              .removeQuickAccessUser(
                                quickAccessUsers[index].id,
                              );
                          ref.invalidate(quickAccessUsersProvider);
                          if (!context.mounted) return;
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(
                                result.ok
                                    ? 'Hızlı erişimden kaldırıldı.'
                                    : (result.message.isNotEmpty
                                          ? result.message
                                          : 'İşlem tamamlanamadı.'),
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
            ],
            for (final section in sections) ...[
              Text(
                section.title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Card(
                margin: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (var index = 0; index < section.entries.length; index++)
                      _MenuTile(
                        entry: section.entries[index],
                        selected: _matches(section.entries[index].route),
                        showDivider: index < section.entries.length - 1,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
            ],
          ],
        ),
      ),
    );
  }

  bool _matches(String route) =>
      currentLocation == route || currentLocation.startsWith('$route/');

  bool _isModuleVisible(String moduleKey) =>
      session?.isModuleVisible(moduleKey) ?? true;

  List<_MenuEntry> _sortModuleEntries(List<_MenuEntry> entries) {
    final order = session?.moduleMenuOrder ?? const <String>[];
    if (order.isEmpty) return entries;
    final orderIndex = <String, int>{
      for (var index = 0; index < order.length; index++) order[index]: index,
    };
    final sorted = [...entries];
    sorted.sort((left, right) {
      final leftIndex = left.moduleKey == null
          ? null
          : orderIndex[left.moduleKey];
      final rightIndex = right.moduleKey == null
          ? null
          : orderIndex[right.moduleKey];
      if (leftIndex == null && rightIndex == null) return 0;
      if (leftIndex == null) return 1;
      if (rightIndex == null) return -1;
      return leftIndex.compareTo(rightIndex);
    });
    return sorted;
  }
}

class _QuickAccessTile extends StatelessWidget {
  const _QuickAccessTile({
    required this.user,
    required this.session,
    required this.showDivider,
    required this.onRemove,
  });

  final QuickAccessUser user;
  final SessionSnapshot? session;
  final bool showDivider;
  final Future<void> Function() onRemove;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).sdal;
    final l10n = context.l10n;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          leading: Stack(
            clipBehavior: Clip.none,
            children: [
              RemoteAvatar(
                label: user.displayName,
                imageUrl:
                    session?.config.resolveUrl(user.photo).toString() ?? '',
                radius: 22,
              ),
              if (user.isOnline)
                Positioned(
                  right: -1,
                  bottom: -1,
                  child: Container(
                    width: 11,
                    height: 11,
                    decoration: BoxDecoration(
                      color: tokens.success,
                      shape: BoxShape.circle,
                      border: Border.all(color: tokens.canvas, width: 2),
                    ),
                  ),
                ),
            ],
          ),
          title: Text(user.displayName),
          subtitle: user.graduationYear.isEmpty
              ? null
              : Text('${user.graduationYear} mezunu'),
          trailing: IconButton(
            tooltip: l10n.quickAccessRemoveAction,
            onPressed: onRemove,
            icon: const Icon(Icons.push_pin_outlined),
          ),
          onTap: () {
            Navigator.of(context).pop();
            context.push('/members/${user.id}');
          },
        ),
        if (showDivider) const Divider(height: 1),
      ],
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.entry,
    required this.selected,
    required this.showDivider,
  });

  final _MenuEntry entry;
  final bool selected;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).sdal;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          selected: selected,
          selectedTileColor: tokens.accentMuted.withValues(alpha: 0.55),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          leading: Icon(entry.icon),
          title: Text(entry.label),
          trailing: selected
              ? Icon(Icons.check_circle, color: tokens.accent)
              : const Icon(Icons.chevron_right),
          onTap: () {
            Navigator.of(context).pop();
            context.go(entry.route);
          },
        ),
        if (showDivider) const Divider(height: 1),
      ],
    );
  }
}

class _MenuSection {
  const _MenuSection({required this.title, required this.entries});

  final String title;
  final List<_MenuEntry> entries;
}

class _MenuEntry {
  const _MenuEntry({
    required this.route,
    required this.icon,
    required this.label,
    this.moduleKey,
  });

  final String route;
  final IconData icon;
  final String label;
  final String? moduleKey;
}

class _SidebarHighlights extends StatelessWidget {
  const _SidebarHighlights({required this.sidebar});

  final ShellSidebarSnapshot sidebar;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stats = <({IconData icon, String label})>[
      (
        icon: Icons.circle_rounded,
        label: '${sidebar.onlineUsers.length} cevrimici uye',
      ),
      (
        icon: Icons.markunread_outlined,
        label: '${sidebar.newMessagesCount} yeni mesaj',
      ),
      (
        icon: Icons.person_add_alt_1_rounded,
        label: '${sidebar.newMembers.length} yeni uye',
      ),
    ];
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final stat in stats)
              DecoratedBox(
                decoration: BoxDecoration(
                  color: theme.sdal.panelMuted,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 9,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(stat.icon, size: 16),
                      const SizedBox(width: 6),
                      Text(stat.label),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
