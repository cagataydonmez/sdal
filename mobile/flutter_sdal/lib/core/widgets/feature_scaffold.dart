import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../l10n/context_l10n.dart';
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
    final session = ref.watch(sessionControllerProvider).valueOrNull;
    final location = GoRouterState.of(context).uri.path;
    final canPop = Navigator.of(context).canPop();
    final resolvedActions = <Widget>[
      ...?actions,
      _AppMenuButton(session: session, currentLocation: location),
    ];

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leadingWidth: session?.user != null ? (canPop ? 92 : 64) : null,
        leading: session?.user != null
            ? _ProfileLeading(session: session!, canPop: canPop)
            : (canPop ? const BackButton() : null),
        title: Text(title),
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
    if (user == null) {
      return canPop ? const BackButton() : const SizedBox.shrink();
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(width: 8),
        InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: () => context.go('/profile'),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: RemoteAvatar(
              label: user.displayName,
              imageUrl: session.config.resolveUrl(user.photo).toString(),
              radius: 16,
            ),
          ),
        ),
        if (canPop)
          IconButton(
            tooltip: 'Geri',
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.chevron_left_rounded),
          ),
      ],
    );
  }
}

class _AppMenuButton extends StatelessWidget {
  const _AppMenuButton({required this.session, required this.currentLocation});

  final SessionSnapshot? session;
  final String currentLocation;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Hızlı menü',
      onPressed: () {
        showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          showDragHandle: true,
          builder: (sheetContext) =>
              _AppMenuSheet(session: session, currentLocation: currentLocation),
        );
      },
      icon: const Icon(Icons.grid_view_rounded),
    );
  }
}

class _AppMenuSheet extends StatelessWidget {
  const _AppMenuSheet({required this.session, required this.currentLocation});

  final SessionSnapshot? session;
  final String currentLocation;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final user = session?.user;
    final sections = <_MenuSection>[
      _MenuSection(
        title: 'Ana gezinme',
        entries: [
          _MenuEntry(
            route: '/feed',
            icon: Icons.dynamic_feed_outlined,
            label: l10n.feedTitle,
          ),
          _MenuEntry(
            route: '/explore',
            icon: Icons.explore_outlined,
            label: l10n.exploreTitle,
          ),
          _MenuEntry(
            route: '/inbox',
            icon: Icons.chat_bubble_outline,
            label: l10n.tabInbox,
          ),
          _MenuEntry(
            route: '/notifications',
            icon: Icons.notifications_outlined,
            label: l10n.notificationsTitle,
          ),
          _MenuEntry(
            route: '/profile',
            icon: Icons.person_outline,
            label: l10n.profileTitle,
          ),
        ],
      ),
      _MenuSection(
        title: 'Topluluk',
        entries: [
          if (_isModuleVisible('groups'))
            _MenuEntry(
              route: '/groups',
              icon: Icons.groups_outlined,
              label: l10n.groupsTitle,
            ),
          if (_isModuleVisible('events'))
            const _MenuEntry(
              route: '/events',
              icon: Icons.event_outlined,
              label: 'Etkinlikler',
            ),
          if (_isModuleVisible('announcements'))
            const _MenuEntry(
              route: '/announcements',
              icon: Icons.campaign_outlined,
              label: 'Duyurular',
            ),
          if (_isModuleVisible('requests'))
            _MenuEntry(
              route: '/requests',
              icon: Icons.assignment_outlined,
              label: l10n.requestsTitle,
            ),
          if (_isModuleVisible('networking'))
            const _MenuEntry(
              route: '/network/hub',
              icon: Icons.hub_outlined,
              label: 'Networking',
            ),
          if (_isModuleVisible('teachers_network'))
            const _MenuEntry(
              route: '/network/teachers',
              icon: Icons.school_outlined,
              label: 'Ogretmen baglantilari',
            ),
          if (_isModuleVisible('jobs'))
            _MenuEntry(
              route: '/jobs',
              icon: Icons.work_outline,
              label: l10n.jobsTitle,
            ),
          if (_isModuleVisible('opportunities'))
            const _MenuEntry(
              route: '/opportunities',
              icon: Icons.auto_awesome_outlined,
              label: 'Firsatlar',
            ),
          if (_isModuleVisible('albums'))
            _MenuEntry(
              route: '/albums',
              icon: Icons.photo_library_outlined,
              label: l10n.albumsTitle,
            ),
          if (_isModuleVisible('following'))
            const _MenuEntry(
              route: '/following',
              icon: Icons.favorite_border,
              label: 'Takipler',
            ),
          if (_isModuleVisible('feed'))
            _MenuEntry(
              route: '/feed/live-chat',
              icon: Icons.forum_outlined,
              label: l10n.liveChatTitle,
            ),
        ],
      ),
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
      session?.isModuleOpen(moduleKey) ?? true;
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
  });

  final String route;
  final IconData icon;
  final String label;
}
