import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/messenger/data/messenger_repository.dart';
import '../../features/notifications/data/notifications_repository.dart';
import '../l10n/context_l10n.dart';
import '../shell/shell_metadata_repository.dart';

class AppTabShell extends ConsumerWidget {
  const AppTabShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  void _onTap(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final localUnreadMessages =
        ref.watch(messengerUnreadCountProvider).valueOrNull ?? 0;
    final localUnreadNotifications =
        ref.watch(notificationUnreadCountProvider).valueOrNull ?? 0;
    final shellMenu = ref.watch(shellMenuProvider).valueOrNull;
    final shellSidebar = ref.watch(shellSidebarProvider).valueOrNull;
    final unreadMessages = math.max(
      localUnreadMessages,
      shellMenu?.badgeForRoute('/inbox') ?? shellSidebar?.newMessagesCount ?? 0,
    );
    final unreadNotifications = math.max(
      localUnreadNotifications,
      shellMenu?.badgeForRoute('/notifications') ?? 0,
    );
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
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
            label: l10n.tabInbox,
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
                    borderRadius: BorderRadius.circular(999),
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
