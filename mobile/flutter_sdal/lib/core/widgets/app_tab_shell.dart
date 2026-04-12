import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/messenger/data/messenger_repository.dart';
import '../../features/notifications/data/notifications_repository.dart';
import '../l10n/context_l10n.dart';
import '../shell/shell_metadata_repository.dart';
import '../theme/sdal_theme_tokens.dart';

class AppTabShell extends ConsumerStatefulWidget {
  const AppTabShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<AppTabShell> createState() => _AppTabShellState();
}

class _AppTabShellState extends ConsumerState<AppTabShell> {
  static const _messengerTabIndex = 2;
  int _lastIndex = -1;

  void _onTap(int index) {
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = widget.navigationShell.currentIndex;

    // When the user switches away from the messenger tab (e.g. by tapping
    // another tab without pressing back), dispose() on ThreadDetailPage is
    // never called. Detect the tab change here and clear activeMessengerThreadIdProvider
    // so that incoming messages show in the badge.
    if (_lastIndex != currentIndex) {
      if (_lastIndex == _messengerTabIndex && currentIndex != _messengerTabIndex) {
        // Leaving messenger tab: clear the active thread so incoming messages
        // show in the badge count.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final notifier = ref.read(activeMessengerThreadIdProvider.notifier);
          if (notifier.state != null) notifier.state = null;
        });
      } else if (_lastIndex != -1 &&
          _lastIndex != _messengerTabIndex &&
          currentIndex == _messengerTabIndex) {
        // Returning to messenger tab: the thread detail page is still mounted
        // but won't rebuild on its own. Invalidating the threads provider
        // forces a rebuild so _scheduleMarkThreadRead fires and clears the badge.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          ref.invalidate(messengerThreadsProvider(''));
        });
      }
      _lastIndex = currentIndex;
    }

    final l10n = context.l10n;
    final localUnreadMessages =
        ref.watch(messengerUnreadCountProvider).value ?? 0;
    final localUnreadNotifications =
        ref.watch(notificationUnreadCountProvider).value ?? 0;
    final shellMenu = ref.watch(shellMenuProvider).value;
    final unreadMessages = localUnreadMessages;
    final unreadNotifications = math.max(
      localUnreadNotifications,
      shellMenu?.badgeForRoute('/notifications') ?? 0,
    );
    return Scaffold(
      body: widget.navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: widget.navigationShell.currentIndex,
        onDestinationSelected: _onTap,
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.dynamic_feed_outlined),
            selectedIcon: const Icon(Icons.dynamic_feed),
            label: l10n.tabFeed,
          ),
          NavigationDestination(
            icon: const Icon(Icons.explore_outlined),
            selectedIcon: const Icon(Icons.explore),
            label: l10n.tabExplore,
          ),
          NavigationDestination(
            icon: _NavBadgeIcon(
              icon: Icons.chat_bubble_outline,
              count: unreadMessages,
              unreadSemanticLabel: l10n.messagesUnreadCount(unreadMessages),
            ),
            selectedIcon: _NavBadgeIcon(
              icon: Icons.chat_bubble,
              count: unreadMessages,
              unreadSemanticLabel: l10n.messagesUnreadCount(unreadMessages),
            ),
            label: l10n.messagesTitle,
          ),
          NavigationDestination(
            icon: _NavBadgeIcon(
              icon: Icons.notifications_outlined,
              count: unreadNotifications,
              unreadSemanticLabel: l10n.notificationsUnreadCount(
                unreadNotifications,
              ),
            ),
            selectedIcon: _NavBadgeIcon(
              icon: Icons.notifications,
              count: unreadNotifications,
              unreadSemanticLabel: l10n.notificationsUnreadCount(
                unreadNotifications,
              ),
            ),
            label: l10n.tabNotifications,
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline),
            selectedIcon: const Icon(Icons.person),
            label: l10n.tabProfile,
          ),
        ],
      ),
    );
  }
}

class _NavBadgeIcon extends StatelessWidget {
  const _NavBadgeIcon({
    required this.icon,
    required this.count,
    required this.unreadSemanticLabel,
  });

  final IconData icon;
  final int count;
  final String unreadSemanticLabel;

  @override
  Widget build(BuildContext context) {
    final badgeLabel = count > 99 ? '99+' : '$count';
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(icon),
        if (count > 0)
          Positioned(
            right: -10,
            top: -6,
            child: Semantics(
              container: true,
              liveRegion: true,
              label: unreadSemanticLabel,
              child: ExcludeSemantics(
                child: Container(
                  constraints: const BoxConstraints(
                    minWidth: 18,
                    minHeight: 18,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.error,
                    borderRadius: BorderRadius.circular(
                      SdalThemeTokens.radiusPill,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      badgeLabel,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onError,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        height: 1,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
