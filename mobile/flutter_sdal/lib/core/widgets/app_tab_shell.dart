import 'dart:math' as math;
import 'dart:ui';

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
import '../theme/sdal_ux_profile.dart';
import 'feature_primary_action.dart';
import '../../l10n/generated/app_localizations.dart';

// ── Inherited widgets ──────────────────────────────────────────────────────

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

/// Lets FeatureScaffold open the side drawer when navStyle == sideDrawer.
class AppTabScaffoldKey extends InheritedWidget {
  const AppTabScaffoldKey({
    super.key,
    required this.scaffoldKey,
    required super.child,
  });

  final GlobalKey<ScaffoldState> scaffoldKey;

  @override
  bool updateShouldNotify(AppTabScaffoldKey old) =>
      scaffoldKey != old.scaffoldKey;

  static GlobalKey<ScaffoldState>? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<AppTabScaffoldKey>()
      ?.scaffoldKey;
}

// ── Tab container builder ──────────────────────────────────────────────────

Widget buildAppTabNavigationContainer(
  BuildContext context,
  StatefulNavigationShell navigationShell,
  List<Widget> children,
) {
  final tokens = Theme.of(context).sdal;
  final dragOffset = _DragOffsetInheritedWidget.of(context);
  final durationMs = tokens.animationDurationMs;

  return switch (tokens.transitionStyle) {
    SdalTransitionStyle.fade => _FadeTabContainer(
      currentIndex: navigationShell.currentIndex,
      durationMs: durationMs,
      children: children,
    ),
    SdalTransitionStyle.blurFade => _BlurFadeTabContainer(
      currentIndex: navigationShell.currentIndex,
      durationMs: durationMs,
      children: children,
    ),
    SdalTransitionStyle.scale => _ScaleTabContainer(
      currentIndex: navigationShell.currentIndex,
      durationMs: durationMs,
      children: children,
    ),
    SdalTransitionStyle.none => IndexedStack(
      index: navigationShell.currentIndex,
      sizing: StackFit.expand,
      children: children,
    ),
    SdalTransitionStyle.slide => _SlidingTabBranchContainer(
      currentIndex: navigationShell.currentIndex,
      dragOffset: dragOffset,
      children: children,
    ),
  };
}

// ── AppTabShell ────────────────────────────────────────────────────────────

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

  final _scaffoldKey = GlobalKey<ScaffoldState>();

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

  NavigationDestinationLabelBehavior _labelBehavior(SdalNavLabelMode mode) =>
      switch (mode) {
        SdalNavLabelMode.always =>
          NavigationDestinationLabelBehavior.alwaysShow,
        SdalNavLabelMode.selectedOnly =>
          NavigationDestinationLabelBehavior.onlyShowSelected,
        SdalNavLabelMode.never => NavigationDestinationLabelBehavior.alwaysHide,
      };

  List<NavigationDestination> _buildDestinations(
    AppLocalizations l10n,
    int unreadMessages,
    int unreadNotifications,
  ) => [
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
        unreadSemanticLabel: l10n.notificationsUnreadCount(unreadNotifications),
      ),
      selectedIcon: _NavBadgeIcon(
        icon: Icons.notifications,
        count: unreadNotifications,
        unreadSemanticLabel: l10n.notificationsUnreadCount(unreadNotifications),
      ),
      label: l10n.tabNotifications,
    ),
    NavigationDestination(
      icon: const Icon(Icons.person_outline),
      selectedIcon: const Icon(Icons.person),
      label: l10n.tabProfile,
    ),
  ];

  Widget _buildBody({
    required BuildContext context,
    required bool canSwipeBetweenTabs,
    required SessionSnapshot? session,
    required String location,
    required bool verificationRequestSubmitted,
  }) {
    return Stack(
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
    );
  }

  // ── Standard bottom bar ──────────────────────────────────────────────────

  Widget _buildStandardBar({
    required BuildContext context,
    required SdalThemeTokens tokens,
    required Widget body,
    required List<NavigationDestination> destinations,
  }) {
    Color? indicatorColor;
    if (tokens.navIndicator == SdalNavIndicator.none ||
        tokens.navIndicator == SdalNavIndicator.accentIcon) {
      indicatorColor = Colors.transparent;
    }

    final navBar = NavigationBarTheme(
      data: NavigationBarThemeData(
        labelBehavior: _labelBehavior(tokens.navLabelMode),
        indicatorColor: indicatorColor,
      ),
      child: NavigationBar(
        selectedIndex: widget.navigationShell.currentIndex,
        onDestinationSelected: _onTap,
        destinations: destinations,
      ),
    );

    if (tokens.navBarBackground == SdalNavBarBackground.frosted ||
        tokens.navBarBackground == SdalNavBarBackground.transparentBlur) {
      return Scaffold(
        body: body,
        bottomNavigationBar: _FrostedNavBarWrapper(
          blurSigma: tokens.blurSigma,
          glassOpacity:
              tokens.navBarBackground == SdalNavBarBackground.transparentBlur
              ? 0.0
              : 0.72,
          tokens: tokens,
          child: navBar,
        ),
      );
    }

    return Scaffold(body: body, bottomNavigationBar: navBar);
  }

  // ── Floating pill (Nova) ─────────────────────────────────────────────────

  Widget _buildFloatingPill({
    required BuildContext context,
    required SdalThemeTokens tokens,
    required Widget body,
    required int unreadMessages,
    required int unreadNotifications,
  }) {
    final mq = MediaQuery.of(context);
    final pillH = tokens.navBarHeight;
    final pillPad = tokens.floatingPillBottomPad;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: MediaQuery(
              data: mq.copyWith(
                padding: mq.padding.copyWith(
                  bottom: mq.padding.bottom + pillH + pillPad,
                ),
              ),
              child: body,
            ),
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: mq.padding.bottom + pillPad,
            child: _FloatingPillNav(
              currentIndex: widget.navigationShell.currentIndex,
              onTap: _onTap,
              unreadMessages: unreadMessages,
              unreadNotifications: unreadNotifications,
              tokens: tokens,
            ),
          ),
        ],
      ),
    );
  }

  // ── Side drawer (Prism) ──────────────────────────────────────────────────

  Widget _buildSideDrawer({
    required BuildContext context,
    required SdalThemeTokens tokens,
    required Widget body,
    required List<NavigationDestination> destinations,
    required AppLocalizations l10n,
  }) {
    return AppTabScaffoldKey(
      scaffoldKey: _scaffoldKey,
      child: Scaffold(
        key: _scaffoldKey,
        drawer: _DrawerNav(
          currentIndex: widget.navigationShell.currentIndex,
          onTap: (index) {
            _scaffoldKey.currentState?.closeDrawer();
            _onTap(index);
          },
          l10n: l10n,
          tokens: tokens,
        ),
        body: body,
      ),
    );
  }

  // ── Transparent overlay bar (Dusk) ───────────────────────────────────────

  Widget _buildTransparentBar({
    required BuildContext context,
    required SdalThemeTokens tokens,
    required Widget body,
    required List<NavigationDestination> destinations,
  }) {
    final mq = MediaQuery.of(context);
    final navH = tokens.navBarHeight;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: MediaQuery(
              data: mq.copyWith(
                padding: mq.padding.copyWith(bottom: mq.padding.bottom + navH),
              ),
              child: body,
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _TransparentNavBar(
              currentIndex: widget.navigationShell.currentIndex,
              onTap: _onTap,
              destinations: destinations,
              navH: navH,
              blurSigma: tokens.blurSigma,
              bottomPadding: mq.padding.bottom,
              tokens: tokens,
            ),
          ),
        ],
      ),
    );
  }

  // ── Material FAB (Flux) ──────────────────────────────────────────────────

  Widget _buildMaterialFab({
    required BuildContext context,
    required SdalThemeTokens tokens,
    required Widget body,
    required List<NavigationDestination> destinations,
    required String location,
  }) {
    final navBar = NavigationBarTheme(
      data: NavigationBarThemeData(
        labelBehavior: _labelBehavior(tokens.navLabelMode),
      ),
      child: NavigationBar(
        selectedIndex: widget.navigationShell.currentIndex,
        onDestinationSelected: _onTap,
        destinations: destinations,
      ),
    );

    return ValueListenableBuilder<FeaturePrimaryActionSnapshot?>(
      valueListenable: FeaturePrimaryActionRegistry.notifier,
      builder: (context, snapshot, _) {
        final action = FeaturePrimaryActionRegistry.actionFor(location);
        return Scaffold(
          body: body,
          bottomNavigationBar: navBar,
          floatingActionButton: action == null
              ? null
              : FloatingActionButton(
                  heroTag: 'sdal_nav_fab_$location',
                  backgroundColor: tokens.accent,
                  foregroundColor: tokens.foregroundOnAccent,
                  tooltip: action.semanticLabel,
                  onPressed: () => FeaturePrimaryActionRegistry.actionFor(
                    location,
                  )?.onPressed(),
                  child: Icon(action.icon),
                ),
          floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        );
      },
    );
  }

  // ── Main build ───────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final currentIndex = widget.navigationShell.currentIndex;

    if (_lastIndex != currentIndex) {
      if (_lastIndex == _messengerTabIndex &&
          currentIndex != _messengerTabIndex) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final notifier = ref.read(activeMessengerThreadIdProvider.notifier);
          if (notifier.state != null) notifier.state = null;
        });
      } else if (_lastIndex != -1 &&
          _lastIndex != _messengerTabIndex &&
          currentIndex == _messengerTabIndex) {
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
    final tokens = Theme.of(context).sdal;

    final body = _buildBody(
      context: context,
      canSwipeBetweenTabs: canSwipeBetweenTabs,
      session: session,
      location: location,
      verificationRequestSubmitted: verificationRequestSubmitted,
    );

    final destinations = _buildDestinations(
      l10n,
      unreadMessages,
      unreadNotifications,
    );

    return switch (tokens.navStyle) {
      SdalNavStyle.floatingPill => _buildFloatingPill(
        context: context,
        tokens: tokens,
        body: body,
        unreadMessages: unreadMessages,
        unreadNotifications: unreadNotifications,
      ),
      SdalNavStyle.sideDrawer => _buildSideDrawer(
        context: context,
        tokens: tokens,
        body: body,
        destinations: destinations,
        l10n: l10n,
      ),
      SdalNavStyle.transparentBar => _buildTransparentBar(
        context: context,
        tokens: tokens,
        body: body,
        destinations: destinations,
      ),
      SdalNavStyle.materialFab => _buildMaterialFab(
        context: context,
        tokens: tokens,
        body: body,
        destinations: destinations,
        location: location,
      ),
      SdalNavStyle.bottomBar => _buildStandardBar(
        context: context,
        tokens: tokens,
        body: body,
        destinations: destinations,
      ),
    };
  }
}

// ── Transition containers ──────────────────────────────────────────────────

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
        final screenWidth = MediaQuery.of(context).size.width;
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

class _FadeTabContainer extends StatefulWidget {
  const _FadeTabContainer({
    required this.currentIndex,
    required this.durationMs,
    required this.children,
  });

  final int currentIndex;
  final int durationMs;
  final List<Widget> children;

  @override
  State<_FadeTabContainer> createState() => _FadeTabContainerState();
}

class _FadeTabContainerState extends State<_FadeTabContainer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  int? _previousIndex;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: widget.durationMs),
    )..value = 1;
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
  }

  @override
  void didUpdateWidget(_FadeTabContainer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex == widget.currentIndex) return;
    _previousIndex = oldWidget.currentIndex;
    _controller.forward(from: 0).whenComplete(() {
      if (mounted) setState(() => _previousIndex = null);
    });
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
      builder: (_, child) => Stack(
        fit: StackFit.expand,
        children: [
          for (var i = 0; i < widget.children.length; i++)
            _buildPage(i, widget.children[i]),
        ],
      ),
    );
  }

  Widget _buildPage(int index, Widget child) {
    final isCurrent = index == widget.currentIndex;
    final isPrevious = index == _previousIndex;
    if (!isCurrent && !isPrevious) {
      return Offstage(
        offstage: true,
        child: TickerMode(enabled: false, child: child),
      );
    }
    return FadeTransition(
      opacity: isCurrent ? _animation : ReverseAnimation(_animation),
      child: IgnorePointer(
        ignoring: !isCurrent,
        child: TickerMode(enabled: isCurrent, child: child),
      ),
    );
  }
}

class _BlurFadeTabContainer extends StatefulWidget {
  const _BlurFadeTabContainer({
    required this.currentIndex,
    required this.durationMs,
    required this.children,
  });

  final int currentIndex;
  final int durationMs;
  final List<Widget> children;

  @override
  State<_BlurFadeTabContainer> createState() => _BlurFadeTabContainerState();
}

class _BlurFadeTabContainerState extends State<_BlurFadeTabContainer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  int? _previousIndex;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: widget.durationMs),
    )..value = 1;
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
  }

  @override
  void didUpdateWidget(_BlurFadeTabContainer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex == widget.currentIndex) return;
    _previousIndex = oldWidget.currentIndex;
    _controller.forward(from: 0).whenComplete(() {
      if (mounted) setState(() => _previousIndex = null);
    });
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
      builder: (_, child) => Stack(
        fit: StackFit.expand,
        children: [
          for (var i = 0; i < widget.children.length; i++)
            _buildPage(i, widget.children[i]),
        ],
      ),
    );
  }

  Widget _buildPage(int index, Widget child) {
    final isCurrent = index == widget.currentIndex;
    final isPrevious = index == _previousIndex;
    if (!isCurrent && !isPrevious) {
      return Offstage(
        offstage: true,
        child: TickerMode(enabled: false, child: child),
      );
    }
    final opacity = isCurrent ? _animation.value : 1 - _animation.value;
    final blurAmount = isCurrent
        ? (1 - _animation.value) * 10
        : _animation.value * 10;

    return Opacity(
      opacity: opacity.clamp(0.0, 1.0),
      child: blurAmount > 0.5
          ? ImageFiltered(
              imageFilter: ImageFilter.blur(
                sigmaX: blurAmount,
                sigmaY: blurAmount,
              ),
              child: IgnorePointer(
                ignoring: !isCurrent,
                child: TickerMode(enabled: isCurrent, child: child),
              ),
            )
          : IgnorePointer(
              ignoring: !isCurrent,
              child: TickerMode(enabled: isCurrent, child: child),
            ),
    );
  }
}

class _ScaleTabContainer extends StatefulWidget {
  const _ScaleTabContainer({
    required this.currentIndex,
    required this.durationMs,
    required this.children,
  });

  final int currentIndex;
  final int durationMs;
  final List<Widget> children;

  @override
  State<_ScaleTabContainer> createState() => _ScaleTabContainerState();
}

class _ScaleTabContainerState extends State<_ScaleTabContainer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fade;
  late Animation<double> _scale;
  int? _previousIndex;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: widget.durationMs),
    )..value = 1;
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _scale = Tween<double>(
      begin: 0.94,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
  }

  @override
  void didUpdateWidget(_ScaleTabContainer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex == widget.currentIndex) return;
    _previousIndex = oldWidget.currentIndex;
    _controller.forward(from: 0).whenComplete(() {
      if (mounted) setState(() => _previousIndex = null);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, child) => Stack(
        fit: StackFit.expand,
        children: [
          for (var i = 0; i < widget.children.length; i++)
            _buildPage(i, widget.children[i]),
        ],
      ),
    );
  }

  Widget _buildPage(int index, Widget child) {
    final isCurrent = index == widget.currentIndex;
    final isPrevious = index == _previousIndex;
    if (!isCurrent && !isPrevious) {
      return Offstage(
        offstage: true,
        child: TickerMode(enabled: false, child: child),
      );
    }
    return FadeTransition(
      opacity: isCurrent ? _fade : ReverseAnimation(_fade),
      child: ScaleTransition(
        scale: isCurrent
            ? _scale
            : Tween<double>(begin: 1.0, end: 0.94).animate(
                CurvedAnimation(parent: _controller, curve: Curves.easeIn),
              ),
        child: IgnorePointer(
          ignoring: !isCurrent,
          child: TickerMode(enabled: isCurrent, child: child),
        ),
      ),
    );
  }
}

// ── Nav widgets ────────────────────────────────────────────────────────────

/// Frosted glass wrapper for NavigationBar (bottomBar with frosted bg).
class _FrostedNavBarWrapper extends StatelessWidget {
  const _FrostedNavBarWrapper({
    required this.blurSigma,
    required this.glassOpacity,
    required this.tokens,
    required this.child,
  });

  final double blurSigma;
  final double glassOpacity;
  final SdalThemeTokens tokens;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final sigma = blurSigma.clamp(0.1, 50.0);
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
        child: ColoredBox(
          color: tokens.panel.withValues(alpha: glassOpacity),
          child: NavigationBarTheme(
            data: const NavigationBarThemeData(
              backgroundColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Icon-only floating pill navigation (Nova).
class _FloatingPillNav extends StatelessWidget {
  const _FloatingPillNav({
    required this.currentIndex,
    required this.onTap,
    required this.unreadMessages,
    required this.unreadNotifications,
    required this.tokens,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final int unreadMessages;
  final int unreadNotifications;
  final SdalThemeTokens tokens;

  static const _icons = <IconData>[
    Icons.dynamic_feed_outlined,
    Icons.explore_outlined,
    Icons.chat_bubble_outline,
    Icons.notifications_outlined,
    Icons.person_outline,
  ];
  static const _selectedIcons = <IconData>[
    Icons.dynamic_feed,
    Icons.explore,
    Icons.chat_bubble,
    Icons.notifications,
    Icons.person,
  ];

  @override
  Widget build(BuildContext context) {
    final sigma = tokens.blurSigma.clamp(0.1, 50.0);
    final badges = [0, 0, unreadMessages, unreadNotifications, 0];

    return ClipRRect(
      borderRadius: BorderRadius.circular(SdalThemeTokens.radiusPill),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
        child: Container(
          height: tokens.navBarHeight,
          decoration: BoxDecoration(
            color: tokens.panel.withValues(alpha: tokens.glassOpacity + 0.65),
            borderRadius: BorderRadius.circular(SdalThemeTokens.radiusPill),
            border: Border.all(color: tokens.panelBorder, width: 0.5),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(5, (index) {
              final isSelected = index == currentIndex;
              final icon = isSelected ? _selectedIcons[index] : _icons[index];
              final color = isSelected ? tokens.accent : tokens.foregroundMuted;
              final badge = badges[index];
              return Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(
                      SdalThemeTokens.radiusPill,
                    ),
                    onTap: () => onTap(index),
                    child: Center(
                      child: badge > 0
                          ? Badge(
                              label: Text(badge > 99 ? '99+' : '$badge'),
                              child: Icon(icon, color: color, size: 22),
                            )
                          : Icon(icon, color: color, size: 22),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

/// Full-height side navigation drawer (Prism).
class _DrawerNav extends StatelessWidget {
  const _DrawerNav({
    required this.currentIndex,
    required this.onTap,
    required this.l10n,
    required this.tokens,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final AppLocalizations l10n;
  final SdalThemeTokens tokens;

  static const _icons = <IconData>[
    Icons.dynamic_feed_outlined,
    Icons.explore_outlined,
    Icons.chat_bubble_outline,
    Icons.notifications_outlined,
    Icons.person_outline,
  ];
  static const _selectedIcons = <IconData>[
    Icons.dynamic_feed,
    Icons.explore,
    Icons.chat_bubble,
    Icons.notifications,
    Icons.person,
  ];

  @override
  Widget build(BuildContext context) {
    final labels = [
      l10n.tabFeed,
      l10n.tabExplore,
      l10n.messagesTitle,
      l10n.tabNotifications,
      l10n.tabProfile,
    ];

    return NavigationDrawer(
      selectedIndex: currentIndex,
      onDestinationSelected: onTap,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 32, 16, 16),
          child: Text(
            'SDAL',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: tokens.accent,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
            ),
          ),
        ),
        const Divider(indent: 28, endIndent: 28),
        const SizedBox(height: 8),
        for (var i = 0; i < 5; i++)
          NavigationDrawerDestination(
            icon: Icon(_icons[i]),
            selectedIcon: Icon(_selectedIcons[i]),
            label: Text(labels[i]),
          ),
      ],
    );
  }
}

/// Transparent nav bar with blur backdrop (Dusk).
class _TransparentNavBar extends StatelessWidget {
  const _TransparentNavBar({
    required this.currentIndex,
    required this.onTap,
    required this.destinations,
    required this.navH,
    required this.blurSigma,
    required this.bottomPadding,
    required this.tokens,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<NavigationDestination> destinations;
  final double navH;
  final double blurSigma;
  final double bottomPadding;
  final SdalThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    final sigma = blurSigma.clamp(0.1, 50.0);
    final height = navH + bottomPadding;
    return SizedBox(
      height: height,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.40),
                          Colors.black.withValues(alpha: 0.12),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.only(bottom: bottomPadding + 8),
            child: Material(
              color: Colors.transparent,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(destinations.length, (index) {
                  final destination = destinations[index];
                  final selected = index == currentIndex;
                  final icon = selected
                      ? destination.selectedIcon ?? destination.icon
                      : destination.icon;
                  return Semantics(
                    selected: selected,
                    button: true,
                    label: destination.label,
                    child: SizedBox(
                      width: 58,
                      height: 56,
                      child: IconButton(
                        tooltip: destination.label,
                        onPressed: () => onTap(index),
                        color: selected ? tokens.accent : Colors.white70,
                        style: IconButton.styleFrom(
                          backgroundColor: selected
                              ? tokens.accent.withValues(alpha: 0.18)
                              : Colors.black.withValues(alpha: 0.14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              SdalThemeTokens.radiusPill,
                            ),
                          ),
                        ),
                        icon: IconTheme(
                          data: IconThemeData(
                            color: selected ? tokens.accent : Colors.white70,
                          ),
                          child: icon,
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Account setup banner ───────────────────────────────────────────────────

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

// ── Badge icon ─────────────────────────────────────────────────────────────

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
