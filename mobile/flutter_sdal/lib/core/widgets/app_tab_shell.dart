import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/messenger/data/messenger_repository.dart';
import '../../features/notifications/data/notifications_repository.dart';
import '../l10n/context_l10n.dart';
import '../onboarding/account_setup_progress_store.dart';
import '../routing/route_refresh_coordinator.dart';
import '../session/session_controller.dart';
import '../session/session_models.dart';
import '../shell/shell_metadata_repository.dart';
import '../theme/sdal_theme_tokens.dart';

class _DragOffsetInheritedWidget extends InheritedWidget {
  const _DragOffsetInheritedWidget({
    required this.dragOffset,
    required super.child,
  });

  final double dragOffset;

  @override
  bool updateShouldNotify(_DragOffsetInheritedWidget oldWidget) =>
      dragOffset != oldWidget.dragOffset;

  static double of(BuildContext context) {
    return context
            .dependOnInheritedWidgetOfExactType<_DragOffsetInheritedWidget>()
            ?.dragOffset ??
        0;
  }
}

Widget buildAppTabNavigationContainer(
  BuildContext context,
  StatefulNavigationShell navigationShell,
  List<Widget> children,
) {
  final dragOffset = _DragOffsetInheritedWidget.of(context);
  return _SlidingTabBranchContainer(
    currentIndex: navigationShell.currentIndex,
    dragOffset: dragOffset,
    children: children,
  );
}

class AppTabShell extends ConsumerStatefulWidget {
  const AppTabShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<AppTabShell> createState() => _AppTabShellState();
}

class _AppTabShellState extends ConsumerState<AppTabShell> {
  static const _messengerTabIndex = 2;
  static const _tabRootPaths = <String>[
    '/feed',
    '/explore',
    '/messenger',
    '/notifications',
    '/profile',
  ];
  static const _swipeDistanceThreshold = 96.0;
  static const _swipeVelocityThreshold = 450.0;
  int _lastIndex = -1;
  String _lastVisibleLocation = '';
  double _horizontalDragDistance = 0;

  void _onTap(int index) {
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  void _onHorizontalDragStart(DragStartDetails details) {
    _horizontalDragDistance = 0;
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    _horizontalDragDistance += details.primaryDelta ?? 0;
    setState(() {});
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    final direction = velocity.abs() >= _swipeVelocityThreshold
        ? velocity.sign
        : _horizontalDragDistance.abs() >= _swipeDistanceThreshold
        ? _horizontalDragDistance.sign
        : 0.0;

    if (direction == 0) {
      _horizontalDragDistance = 0;
      setState(() {});
      return;
    }

    final currentIndex = widget.navigationShell.currentIndex;
    final targetIndex = direction < 0 ? currentIndex + 1 : currentIndex - 1;
    if (targetIndex < 0 || targetIndex >= _tabRootPaths.length) {
      _horizontalDragDistance = 0;
      setState(() {});
      return;
    }

    _horizontalDragDistance = 0;
    widget.navigationShell.goBranch(targetIndex);
  }

  bool _canSwipeBetweenTabs(BuildContext context) {
    try {
      return _tabRootPaths.contains(GoRouterState.of(context).uri.path);
    } catch (_) {
      return true;
    }
  }

  Uri _currentUri(BuildContext context) {
    try {
      return GoRouterState.of(context).uri;
    } catch (_) {
      return Uri(path: _tabRootPaths[widget.navigationShell.currentIndex]);
    }
  }

  bool _shouldShowAccountSetupBanner(
    SessionSnapshot? session,
    String location,
    bool verificationRequestSubmitted,
  ) {
    if (session?.requiresInitialGraduationClaim == true) return false;
    final requiresVerificationPrompt =
        session?.requiresVerification == true && !verificationRequestSubmitted;
    if (session?.requiresProfileCompletion != true &&
        !requiresVerificationPrompt) {
      return false;
    }
    return switch (location) {
      '/profile/edit' ||
      '/profile/onboarding' ||
      '/profile/verification' => false,
      _ => true,
    };
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = widget.navigationShell.currentIndex;

    // When the user switches away from the messenger tab (e.g. by tapping
    // another tab without pressing back), dispose() on ThreadDetailPage is
    // never called. Detect the tab change here and clear activeMessengerThreadIdProvider
    // so that incoming messages show in the badge.
    if (_lastIndex != currentIndex) {
      if (_lastIndex == _messengerTabIndex &&
          currentIndex != _messengerTabIndex) {
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
    final session = ref.watch(sessionControllerProvider).value;
    final currentUri = _currentUri(context);
    final location = currentUri.path;
    if (_lastVisibleLocation != currentUri.toString()) {
      _lastVisibleLocation = currentUri.toString();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        scheduleRouteSilentRefresh(ref, currentUri);
      });
    }
    final userId = session?.user?.id ?? 0;
    final verificationRequestSubmitted = userId > 0
        ? ref.watch(verificationRequestSubmittedProvider(userId)).value ?? false
        : false;
    final unreadMessages = localUnreadMessages;
    final unreadNotifications = math.max(
      localUnreadNotifications,
      shellMenu?.badgeForRoute('/notifications') ?? 0,
    );
    final canSwipeBetweenTabs = _canSwipeBetweenTabs(context);
    return Scaffold(
      body: Stack(
        children: [
          _DragOffsetInheritedWidget(
            dragOffset: _horizontalDragDistance,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onHorizontalDragStart: canSwipeBetweenTabs
                  ? _onHorizontalDragStart
                  : null,
              onHorizontalDragUpdate: canSwipeBetweenTabs
                  ? _onHorizontalDragUpdate
                  : null,
              onHorizontalDragEnd: canSwipeBetweenTabs
                  ? _onHorizontalDragEnd
                  : null,
              child: widget.navigationShell,
            ),
          ),
          if (_shouldShowAccountSetupBanner(
            session,
            location,
            verificationRequestSubmitted,
          ))
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _AccountSetupBanner(
                requiresProfileCompletion:
                    session?.requiresProfileCompletion == true,
                requiresVerification:
                    session?.requiresVerification == true &&
                    !verificationRequestSubmitted,
                onProfileTap: () => context.go('/profile/edit'),
                onVerificationTap: () => context.go('/profile/verification'),
              ),
            ),
        ],
      ),
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

class _SlidingTabBranchContainer extends StatefulWidget {
  const _SlidingTabBranchContainer({
    required this.currentIndex,
    required this.dragOffset,
    required this.children,
  });

  final int currentIndex;
  final double dragOffset;
  final List<Widget> children;

  @override
  State<_SlidingTabBranchContainer> createState() =>
      _SlidingTabBranchContainerState();
}

class _SlidingTabBranchContainerState extends State<_SlidingTabBranchContainer>
    with SingleTickerProviderStateMixin {
  static const _duration = Duration(milliseconds: 220);
  late final AnimationController _controller;
  late final Animation<double> _animation;
  int? _previousIndex;
  int _direction = 1;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _duration)
      ..value = 1;
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void didUpdateWidget(covariant _SlidingTabBranchContainer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex == widget.currentIndex) return;
    _previousIndex = oldWidget.currentIndex;
    _direction = widget.currentIndex > oldWidget.currentIndex ? 1 : -1;
    _controller.forward(from: 0).whenComplete(() {
      if (mounted) setState(() => _previousIndex = null);
    });
  }

  double _getScreenWidth(BuildContext context) {
    return MediaQuery.of(context).size.width;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        return Stack(
          fit: StackFit.expand,
          children: [
            for (var index = 0; index < widget.children.length; index++)
              _buildBranch(index, widget.children[index]),
          ],
        );
      },
    );
  }

  Widget _buildBranch(int index, Widget child) {
    final isCurrent = index == widget.currentIndex;
    final isPrevious = index == _previousIndex;
    final isVisible = isCurrent || isPrevious;

    if (!isVisible) {
      return Offstage(
        offstage: true,
        child: TickerMode(enabled: false, child: child),
      );
    }

    return Builder(
      builder: (context) {
        final screenWidth = _getScreenWidth(context);
        final isDragging = widget.dragOffset.abs() > 0;

        if (isDragging) {
          final dragProgress = (widget.dragOffset.abs() / screenWidth).clamp(
            0.0,
            1.0,
          );
          final dragDirection = widget.dragOffset.sign;

          final offset = isCurrent
              ? Offset(dragDirection * dragProgress, 0)
              : Offset(-dragDirection * dragProgress, 0);

          return FractionalTranslation(
            translation: offset,
            child: IgnorePointer(
              ignoring: !isCurrent,
              child: TickerMode(enabled: isCurrent, child: child),
            ),
          );
        }

        final progress = _animation.value;
        final offset = isCurrent
            ? Offset(_direction * (1 - progress), 0)
            : Offset(-_direction * progress, 0);

        return FractionalTranslation(
          translation: offset,
          child: IgnorePointer(
            ignoring: !isCurrent,
            child: TickerMode(enabled: isCurrent, child: child),
          ),
        );
      },
    );
  }
}

class _AccountSetupBanner extends StatelessWidget {
  const _AccountSetupBanner({
    required this.requiresProfileCompletion,
    required this.requiresVerification,
    required this.onProfileTap,
    required this.onVerificationTap,
  });

  final bool requiresProfileCompletion;
  final bool requiresVerification;
  final VoidCallback onProfileTap;
  final VoidCallback onVerificationTap;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).sdal;
    final needsBoth = requiresProfileCompletion && requiresVerification;
    final title = requiresProfileCompletion
        ? 'Hesabını hazırla'
        : 'Doğrulama bekliyor';
    final message = needsBoth
        ? 'Önce profil bilgilerini tamamla, ardından doğrulama talebini gönder.'
        : requiresProfileCompletion
        ? 'Profil bilgilerini tamamlayarak önerileri ve rehberi daha doğru hale getir.'
        : 'Bazı etkileşimler için profil doğrulaması gerekiyor.';
    final actionLabel = requiresProfileCompletion ? 'Tamamla' : 'Doğrula';
    final onTap = requiresProfileCompletion ? onProfileTap : onVerificationTap;

    return SafeArea(
      bottom: false,
      child: Material(
        color:
            (requiresProfileCompletion ? tokens.warningMuted : tokens.infoMuted)
                .withValues(alpha: 0.92),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final content = Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    requiresProfileCompletion
                        ? Icons.assignment_ind_outlined
                        : Icons.verified_user_outlined,
                    color: requiresProfileCompletion
                        ? tokens.warning
                        : tokens.info,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          message,
                          maxLines: constraints.maxWidth < 360 ? 3 : 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              );

              if (constraints.maxWidth < 360) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    content,
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: onTap,
                        child: Text(actionLabel),
                      ),
                    ),
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: content),
                  const SizedBox(width: 10),
                  TextButton(onPressed: onTap, child: Text(actionLabel)),
                ],
              );
            },
          ),
        ),
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
