import 'package:flutter/material.dart';
import 'sdal_ux_profile.dart';

@immutable
class SdalThemeTokens extends ThemeExtension<SdalThemeTokens> {
  // Legacy static constants kept for any widget that still references them.
  static const double radiusXs = 12;
  static const double radiusSm = 14;
  static const double radiusMd = 16;
  static const double radiusLg = 18;
  static const double radiusXl = 20;
  static const double radius2xl = 24;
  static const double radiusPill = 999;

  const SdalThemeTokens({
    // ── Color tokens ──────────────────────────────────────────────────────────
    required this.canvas,
    required this.canvasSubtle,
    required this.panel,
    required this.panelRaised,
    required this.panelMuted,
    required this.panelBorder,
    required this.accent,
    required this.accentMuted,
    required this.success,
    required this.successMuted,
    required this.warning,
    required this.warningMuted,
    required this.info,
    required this.infoMuted,
    required this.danger,
    required this.dangerMuted,
    required this.chatOutgoing,
    required this.chatIncoming,
    required this.storyActive,
    required this.storyInactive,
    required this.storyOverlay,
    required this.imagePlaceholder,
    required this.imageError,
    required this.foreground,
    required this.foregroundMuted,
    required this.foregroundOnAccent,
    required this.adminExperiment,
    // ── Shape tokens ──────────────────────────────────────────────────────────
    this.cardRadius = 20.0,
    this.buttonRadius = 18.0,
    this.inputRadius = 20.0,
    this.panelBorderWidth = 1.0,
    // ── Logo asset path ───────────────────────────────────────────────────────
    this.logoAsset = 'icon.png',
    // ── UX Profile — Navigation ───────────────────────────────────────────────
    this.navStyle = SdalNavStyle.bottomBar,
    this.navLabelMode = SdalNavLabelMode.always,
    this.navIndicator = SdalNavIndicator.filledPill,
    this.navBarBackground = SdalNavBarBackground.solid,
    // ── UX Profile — App Bar / Header ─────────────────────────────────────────
    this.headerStyle = SdalHeaderStyle.standard,
    this.headerBackground = SdalHeaderBackground.solid,
    this.logoPosition = SdalLogoPosition.center,
    this.avatarPosition = SdalAvatarPosition.leading,
    this.titleAlignment = SdalTitleAlignment.center,
    // ── UX Profile — Cards & Surfaces ─────────────────────────────────────────
    this.cardStyle = SdalCardStyle.elevated,
    this.surfaceDepth = SdalSurfaceDepth.subtle,
    this.borderStyle = SdalBorderStyle.thin,
    this.backgroundPattern = SdalBackgroundPattern.solid,
    // ── UX Profile — Feed & List Layout ──────────────────────────────────────
    this.feedLayout = SdalFeedLayout.singleColumn,
    this.listItemStyle = SdalListItemStyle.card,
    this.separatorStyle = SdalSeparatorStyle.spacer,
    this.scrollPhysics = SdalScrollPhysics.bouncing,
    // ── UX Profile — Interaction & Animation ─────────────────────────────────
    this.tapFeedback = SdalTapFeedback.ripple,
    this.transitionStyle = SdalTransitionStyle.slide,
    this.animationSpeed = SdalAnimationSpeed.normal,
    this.scrollBehavior = SdalScrollBehavior.standard,
    // ── UX Profile — Avatar & Identity ───────────────────────────────────────
    this.avatarShape = SdalAvatarShape.circle,
    this.avatarBorder = SdalAvatarBorder.none,
    this.onlineIndicator = SdalOnlineIndicator.dot,
    this.memberBadgeStyle = SdalMemberBadgeStyle.pill,
    // ── UX Profile — Data Presentation ───────────────────────────────────────
    this.metaPlacement = SdalMetaPlacement.below,
    this.actionsStyle = SdalActionsStyle.iconRow,
    this.statsDisplay = SdalStatsDisplay.chips,
    this.timestampStyle = SdalTimestampStyle.relative,
    // ── UX Profile — Modals & Overlays ───────────────────────────────────────
    this.menuStyle = SdalMenuStyle.bottomSheet,
    this.modalBackdrop = SdalModalBackdrop.dim,
    this.sheetStyle = SdalSheetStyle.pillHandle,
    // ── UX Profile — Empty & Loading ─────────────────────────────────────────
    this.loadingStyle = SdalLoadingStyle.skeleton,
    this.emptyStateStyle = SdalEmptyStateStyle.centered,
    // ── UX Profile — Images & Media ──────────────────────────────────────────
    this.imageShape = SdalImageShape.roundedSmall,
    this.imageOverlay = SdalImageOverlay.none,
    this.placeholderStyle = SdalPlaceholderStyle.shimmer,
    // ── UX Profile — Typography Personality ──────────────────────────────────
    this.headingWeight = SdalHeadingWeight.semibold,
    this.bodyLineHeight = SdalBodyLineHeight.normal,
    this.letterSpacing = SdalLetterSpacing.normal,
    this.typographyHierarchy = SdalTypographyHierarchy.standard,
    // ── UX Profile — Spacing System ───────────────────────────────────────────
    this.spacingScale = SdalSpacingScale.normal,
    this.contentInset = SdalContentInset.standard,
    // ── UX Profile — Badges ───────────────────────────────────────────────────
    this.badgeStyle = SdalBadgeStyle.count,
    this.unreadIndicator = SdalUnreadIndicator.badgeCount,
    // ── UX Profile — Status & Feedback ───────────────────────────────────────
    this.toastPosition = SdalToastPosition.bottom,
    this.toastStyle = SdalToastStyle.snackbar,
    // ── Scalar UX Metrics ─────────────────────────────────────────────────────
    this.blurSigma = 0.0,
    this.glassOpacity = 0.0,
    this.glassSheetOpacity = 0.50,
    this.navBarHeight = 80.0,
    this.floatingPillBottomPad = 16.0,
    this.appBarHeight = 56.0,
    this.heroHeaderHeight = 0.0,
    this.contentPaddingH = 16.0,
    this.cardSpacing = 12.0,
    this.animationDurationMs = 220,
    this.feedImageAspect = 1.78,
  });

  // ── Color fields ──────────────────────────────────────────────────────────
  final Color canvas;
  final Color canvasSubtle;
  final Color panel;
  final Color panelRaised;
  final Color panelMuted;
  final Color panelBorder;
  final Color accent;
  final Color accentMuted;
  final Color success;
  final Color successMuted;
  final Color warning;
  final Color warningMuted;
  final Color info;
  final Color infoMuted;
  final Color danger;
  final Color dangerMuted;
  final Color chatOutgoing;
  final Color chatIncoming;
  final Color storyActive;
  final Color storyInactive;
  final Color storyOverlay;
  final Color imagePlaceholder;
  final Color imageError;
  final Color foreground;
  final Color foregroundMuted;
  final Color foregroundOnAccent;
  final Color adminExperiment;

  // ── Shape fields ──────────────────────────────────────────────────────────
  final double cardRadius;
  final double buttonRadius;
  final double inputRadius;
  final double panelBorderWidth;
  final String logoAsset;

  // ── UX Profile — Navigation ───────────────────────────────────────────────
  final SdalNavStyle navStyle;
  final SdalNavLabelMode navLabelMode;
  final SdalNavIndicator navIndicator;
  final SdalNavBarBackground navBarBackground;

  // ── UX Profile — App Bar / Header ─────────────────────────────────────────
  final SdalHeaderStyle headerStyle;
  final SdalHeaderBackground headerBackground;
  final SdalLogoPosition logoPosition;
  final SdalAvatarPosition avatarPosition;
  final SdalTitleAlignment titleAlignment;

  // ── UX Profile — Cards & Surfaces ─────────────────────────────────────────
  final SdalCardStyle cardStyle;
  final SdalSurfaceDepth surfaceDepth;
  final SdalBorderStyle borderStyle;
  final SdalBackgroundPattern backgroundPattern;

  // ── UX Profile — Feed & List Layout ──────────────────────────────────────
  final SdalFeedLayout feedLayout;
  final SdalListItemStyle listItemStyle;
  final SdalSeparatorStyle separatorStyle;
  final SdalScrollPhysics scrollPhysics;

  // ── UX Profile — Interaction & Animation ─────────────────────────────────
  final SdalTapFeedback tapFeedback;
  final SdalTransitionStyle transitionStyle;
  final SdalAnimationSpeed animationSpeed;
  final SdalScrollBehavior scrollBehavior;

  // ── UX Profile — Avatar & Identity ───────────────────────────────────────
  final SdalAvatarShape avatarShape;
  final SdalAvatarBorder avatarBorder;
  final SdalOnlineIndicator onlineIndicator;
  final SdalMemberBadgeStyle memberBadgeStyle;

  // ── UX Profile — Data Presentation ───────────────────────────────────────
  final SdalMetaPlacement metaPlacement;
  final SdalActionsStyle actionsStyle;
  final SdalStatsDisplay statsDisplay;
  final SdalTimestampStyle timestampStyle;

  // ── UX Profile — Modals & Overlays ───────────────────────────────────────
  final SdalMenuStyle menuStyle;
  final SdalModalBackdrop modalBackdrop;
  final SdalSheetStyle sheetStyle;

  // ── UX Profile — Empty & Loading ─────────────────────────────────────────
  final SdalLoadingStyle loadingStyle;
  final SdalEmptyStateStyle emptyStateStyle;

  // ── UX Profile — Images & Media ──────────────────────────────────────────
  final SdalImageShape imageShape;
  final SdalImageOverlay imageOverlay;
  final SdalPlaceholderStyle placeholderStyle;

  // ── UX Profile — Typography Personality ──────────────────────────────────
  final SdalHeadingWeight headingWeight;
  final SdalBodyLineHeight bodyLineHeight;
  final SdalLetterSpacing letterSpacing;
  final SdalTypographyHierarchy typographyHierarchy;

  // ── UX Profile — Spacing System ───────────────────────────────────────────
  final SdalSpacingScale spacingScale;
  final SdalContentInset contentInset;

  // ── UX Profile — Badges ───────────────────────────────────────────────────
  final SdalBadgeStyle badgeStyle;
  final SdalUnreadIndicator unreadIndicator;

  // ── UX Profile — Status & Feedback ───────────────────────────────────────
  final SdalToastPosition toastPosition;
  final SdalToastStyle toastStyle;

  // ── Scalar UX Metrics ─────────────────────────────────────────────────────
  /// BackdropFilter σ for glass and frosted effects. 0.0 = no blur.
  final double blurSigma;

  /// Opacity of the glass card fill. 0.0 = fully transparent, 0.5 = heavy.
  final double glassOpacity;

  /// Opacity of fullscreen modal/menu backdrops.
  final double glassSheetOpacity;

  /// Total height of the bottom navigation bar. 0.0 = no bar (sideDrawer).
  final double navBarHeight;

  /// Distance of floating pill from the bottom safe-area edge.
  final double floatingPillBottomPad;

  /// AppBar height in collapsed/standard state.
  final double appBarHeight;

  /// Maximum height of the collapsible hero header. 0.0 = no hero.
  final double heroHeaderHeight;

  /// Horizontal padding applied to main content areas.
  final double contentPaddingH;

  /// Vertical gap between feed cards/items.
  final double cardSpacing;

  /// Base animation duration in milliseconds.
  final int animationDurationMs;

  /// Feed card image aspect ratio (width / height).
  final double feedImageAspect;

  // ── Kor light (default) ───────────────────────────────────────────────────
  static const light = SdalThemeTokens(
    canvas: Color(0xFFFFF8F1),
    canvasSubtle: Color(0xFFF4E4D8),
    panel: Color(0xFFFFFCF7),
    panelRaised: Color(0xFFF7E8DA),
    panelMuted: Color(0xFFEFD7C5),
    panelBorder: Color(0xFFD7A68C),
    accent: Color(0xFF9A452D),
    accentMuted: Color(0xFFFFDED0),
    success: Color(0xFF246A4B),
    successMuted: Color(0xFFD7EFE1),
    warning: Color(0xFF85530C),
    warningMuted: Color(0xFFF5E1B8),
    info: Color(0xFF2E4D82),
    infoMuted: Color(0xFFD7E2F6),
    danger: Color(0xFFA33A34),
    dangerMuted: Color(0xFFF5D8D3),
    chatOutgoing: Color(0xFF753522),
    chatIncoming: Color(0xFFFFFCF7),
    storyActive: Color(0xFF2E4D82),
    storyInactive: Color(0xFFD7A68C),
    storyOverlay: Color(0xB3201008),
    imagePlaceholder: Color(0xFFEACCB7),
    imageError: Color(0xFFD9B9A4),
    foreground: Color(0xFF24100A),
    foregroundMuted: Color(0xFF74513E),
    foregroundOnAccent: Color(0xFFFFF8F1),
    adminExperiment: Color(0xFF5C58B0),
    cardRadius: 18,
    buttonRadius: 16,
    inputRadius: 18,
    panelBorderWidth: 1.0,
    logoAsset: 'assets/logo_kor.png',
    navStyle: SdalNavStyle.bottomBar,
    navLabelMode: SdalNavLabelMode.always,
    navIndicator: SdalNavIndicator.filledPill,
    navBarBackground: SdalNavBarBackground.elevated,
    headerStyle: SdalHeaderStyle.standard,
    headerBackground: SdalHeaderBackground.solid,
    logoPosition: SdalLogoPosition.center,
    avatarPosition: SdalAvatarPosition.leading,
    titleAlignment: SdalTitleAlignment.center,
    cardStyle: SdalCardStyle.elevated,
    surfaceDepth: SdalSurfaceDepth.raised,
    borderStyle: SdalBorderStyle.thin,
    backgroundPattern: SdalBackgroundPattern.subtleGradient,
    feedLayout: SdalFeedLayout.magazine,
    listItemStyle: SdalListItemStyle.card,
    separatorStyle: SdalSeparatorStyle.spacer,
    tapFeedback: SdalTapFeedback.scalePress,
    transitionStyle: SdalTransitionStyle.slide,
    animationSpeed: SdalAnimationSpeed.normal,
    avatarBorder: SdalAvatarBorder.photoRim,
    onlineIndicator: SdalOnlineIndicator.ring,
    memberBadgeStyle: SdalMemberBadgeStyle.iconTag,
    actionsStyle: SdalActionsStyle.pillButtons,
    statsDisplay: SdalStatsDisplay.chips,
    loadingStyle: SdalLoadingStyle.skeleton,
    emptyStateStyle: SdalEmptyStateStyle.card,
    imageShape: SdalImageShape.roundedLarge,
    imageOverlay: SdalImageOverlay.gradientBottom,
    headingWeight: SdalHeadingWeight.bold,
    typographyHierarchy: SdalTypographyHierarchy.editorial,
    spacingScale: SdalSpacingScale.normal,
    contentInset: SdalContentInset.standard,
    navBarHeight: 82.0,
    appBarHeight: 58.0,
    contentPaddingH: 18.0,
    cardSpacing: 14.0,
    animationDurationMs: 230,
    feedImageAspect: 1.45,
  );

  // ── Kor dark (default) ────────────────────────────────────────────────────
  static const dark = SdalThemeTokens(
    canvas: Color(0xFF120D0B),
    canvasSubtle: Color(0xFF1C1512),
    panel: Color(0xFF251B16),
    panelRaised: Color(0xFF30221B),
    panelMuted: Color(0xFF3A2A22),
    panelBorder: Color(0xFF6A4A3C),
    accent: Color(0xFFD88B68),
    accentMuted: Color(0xFF4A2B20),
    success: Color(0xFF8AC39F),
    successMuted: Color(0xFF1E3A2B),
    warning: Color(0xFFD0A45C),
    warningMuted: Color(0xFF3D2A12),
    info: Color(0xFFA5BCE7),
    infoMuted: Color(0xFF22324F),
    danger: Color(0xFFE09A90),
    dangerMuted: Color(0xFF482620),
    chatOutgoing: Color(0xFF5A3326),
    chatIncoming: Color(0xFF251B16),
    storyActive: Color(0xFFD88B68),
    storyInactive: Color(0xFF6A4A3C),
    storyOverlay: Color(0xD9050302),
    imagePlaceholder: Color(0xFF3F2A21),
    imageError: Color(0xFF4D332A),
    foreground: Color(0xFFFFF1E8),
    foregroundMuted: Color(0xFFCFAA99),
    foregroundOnAccent: Color(0xFF170A05),
    adminExperiment: Color(0xFFB8B0E8),
    cardRadius: 18,
    buttonRadius: 16,
    inputRadius: 18,
    panelBorderWidth: 1.0,
    logoAsset: 'assets/logo_kor.png',
    navStyle: SdalNavStyle.bottomBar,
    navLabelMode: SdalNavLabelMode.always,
    navIndicator: SdalNavIndicator.filledPill,
    navBarBackground: SdalNavBarBackground.elevated,
    headerStyle: SdalHeaderStyle.standard,
    headerBackground: SdalHeaderBackground.solid,
    logoPosition: SdalLogoPosition.center,
    avatarPosition: SdalAvatarPosition.leading,
    titleAlignment: SdalTitleAlignment.center,
    cardStyle: SdalCardStyle.elevated,
    surfaceDepth: SdalSurfaceDepth.raised,
    borderStyle: SdalBorderStyle.thin,
    backgroundPattern: SdalBackgroundPattern.subtleGradient,
    feedLayout: SdalFeedLayout.magazine,
    listItemStyle: SdalListItemStyle.card,
    separatorStyle: SdalSeparatorStyle.spacer,
    tapFeedback: SdalTapFeedback.scalePress,
    transitionStyle: SdalTransitionStyle.slide,
    animationSpeed: SdalAnimationSpeed.normal,
    avatarBorder: SdalAvatarBorder.photoRim,
    onlineIndicator: SdalOnlineIndicator.ring,
    memberBadgeStyle: SdalMemberBadgeStyle.iconTag,
    actionsStyle: SdalActionsStyle.pillButtons,
    statsDisplay: SdalStatsDisplay.chips,
    loadingStyle: SdalLoadingStyle.skeleton,
    emptyStateStyle: SdalEmptyStateStyle.card,
    imageShape: SdalImageShape.roundedLarge,
    imageOverlay: SdalImageOverlay.gradientBottom,
    headingWeight: SdalHeadingWeight.bold,
    typographyHierarchy: SdalTypographyHierarchy.editorial,
    spacingScale: SdalSpacingScale.normal,
    contentInset: SdalContentInset.standard,
    navBarHeight: 82.0,
    appBarHeight: 58.0,
    contentPaddingH: 18.0,
    cardSpacing: 14.0,
    animationDurationMs: 230,
    feedImageAspect: 1.45,
  );

  @override
  SdalThemeTokens copyWith({
    Color? canvas,
    Color? canvasSubtle,
    Color? panel,
    Color? panelRaised,
    Color? panelMuted,
    Color? panelBorder,
    Color? accent,
    Color? accentMuted,
    Color? success,
    Color? successMuted,
    Color? warning,
    Color? warningMuted,
    Color? info,
    Color? infoMuted,
    Color? danger,
    Color? dangerMuted,
    Color? chatOutgoing,
    Color? chatIncoming,
    Color? storyActive,
    Color? storyInactive,
    Color? storyOverlay,
    Color? imagePlaceholder,
    Color? imageError,
    Color? foreground,
    Color? foregroundMuted,
    Color? foregroundOnAccent,
    Color? adminExperiment,
    double? cardRadius,
    double? buttonRadius,
    double? inputRadius,
    double? panelBorderWidth,
    String? logoAsset,
    SdalNavStyle? navStyle,
    SdalNavLabelMode? navLabelMode,
    SdalNavIndicator? navIndicator,
    SdalNavBarBackground? navBarBackground,
    SdalHeaderStyle? headerStyle,
    SdalHeaderBackground? headerBackground,
    SdalLogoPosition? logoPosition,
    SdalAvatarPosition? avatarPosition,
    SdalTitleAlignment? titleAlignment,
    SdalCardStyle? cardStyle,
    SdalSurfaceDepth? surfaceDepth,
    SdalBorderStyle? borderStyle,
    SdalBackgroundPattern? backgroundPattern,
    SdalFeedLayout? feedLayout,
    SdalListItemStyle? listItemStyle,
    SdalSeparatorStyle? separatorStyle,
    SdalScrollPhysics? scrollPhysics,
    SdalTapFeedback? tapFeedback,
    SdalTransitionStyle? transitionStyle,
    SdalAnimationSpeed? animationSpeed,
    SdalScrollBehavior? scrollBehavior,
    SdalAvatarShape? avatarShape,
    SdalAvatarBorder? avatarBorder,
    SdalOnlineIndicator? onlineIndicator,
    SdalMemberBadgeStyle? memberBadgeStyle,
    SdalMetaPlacement? metaPlacement,
    SdalActionsStyle? actionsStyle,
    SdalStatsDisplay? statsDisplay,
    SdalTimestampStyle? timestampStyle,
    SdalMenuStyle? menuStyle,
    SdalModalBackdrop? modalBackdrop,
    SdalSheetStyle? sheetStyle,
    SdalLoadingStyle? loadingStyle,
    SdalEmptyStateStyle? emptyStateStyle,
    SdalImageShape? imageShape,
    SdalImageOverlay? imageOverlay,
    SdalPlaceholderStyle? placeholderStyle,
    SdalHeadingWeight? headingWeight,
    SdalBodyLineHeight? bodyLineHeight,
    SdalLetterSpacing? letterSpacing,
    SdalTypographyHierarchy? typographyHierarchy,
    SdalSpacingScale? spacingScale,
    SdalContentInset? contentInset,
    SdalBadgeStyle? badgeStyle,
    SdalUnreadIndicator? unreadIndicator,
    SdalToastPosition? toastPosition,
    SdalToastStyle? toastStyle,
    double? blurSigma,
    double? glassOpacity,
    double? glassSheetOpacity,
    double? navBarHeight,
    double? floatingPillBottomPad,
    double? appBarHeight,
    double? heroHeaderHeight,
    double? contentPaddingH,
    double? cardSpacing,
    int? animationDurationMs,
    double? feedImageAspect,
  }) {
    return SdalThemeTokens(
      canvas: canvas ?? this.canvas,
      canvasSubtle: canvasSubtle ?? this.canvasSubtle,
      panel: panel ?? this.panel,
      panelRaised: panelRaised ?? this.panelRaised,
      panelMuted: panelMuted ?? this.panelMuted,
      panelBorder: panelBorder ?? this.panelBorder,
      accent: accent ?? this.accent,
      accentMuted: accentMuted ?? this.accentMuted,
      success: success ?? this.success,
      successMuted: successMuted ?? this.successMuted,
      warning: warning ?? this.warning,
      warningMuted: warningMuted ?? this.warningMuted,
      info: info ?? this.info,
      infoMuted: infoMuted ?? this.infoMuted,
      danger: danger ?? this.danger,
      dangerMuted: dangerMuted ?? this.dangerMuted,
      chatOutgoing: chatOutgoing ?? this.chatOutgoing,
      chatIncoming: chatIncoming ?? this.chatIncoming,
      storyActive: storyActive ?? this.storyActive,
      storyInactive: storyInactive ?? this.storyInactive,
      storyOverlay: storyOverlay ?? this.storyOverlay,
      imagePlaceholder: imagePlaceholder ?? this.imagePlaceholder,
      imageError: imageError ?? this.imageError,
      foreground: foreground ?? this.foreground,
      foregroundMuted: foregroundMuted ?? this.foregroundMuted,
      foregroundOnAccent: foregroundOnAccent ?? this.foregroundOnAccent,
      adminExperiment: adminExperiment ?? this.adminExperiment,
      cardRadius: cardRadius ?? this.cardRadius,
      buttonRadius: buttonRadius ?? this.buttonRadius,
      inputRadius: inputRadius ?? this.inputRadius,
      panelBorderWidth: panelBorderWidth ?? this.panelBorderWidth,
      logoAsset: logoAsset ?? this.logoAsset,
      navStyle: navStyle ?? this.navStyle,
      navLabelMode: navLabelMode ?? this.navLabelMode,
      navIndicator: navIndicator ?? this.navIndicator,
      navBarBackground: navBarBackground ?? this.navBarBackground,
      headerStyle: headerStyle ?? this.headerStyle,
      headerBackground: headerBackground ?? this.headerBackground,
      logoPosition: logoPosition ?? this.logoPosition,
      avatarPosition: avatarPosition ?? this.avatarPosition,
      titleAlignment: titleAlignment ?? this.titleAlignment,
      cardStyle: cardStyle ?? this.cardStyle,
      surfaceDepth: surfaceDepth ?? this.surfaceDepth,
      borderStyle: borderStyle ?? this.borderStyle,
      backgroundPattern: backgroundPattern ?? this.backgroundPattern,
      feedLayout: feedLayout ?? this.feedLayout,
      listItemStyle: listItemStyle ?? this.listItemStyle,
      separatorStyle: separatorStyle ?? this.separatorStyle,
      scrollPhysics: scrollPhysics ?? this.scrollPhysics,
      tapFeedback: tapFeedback ?? this.tapFeedback,
      transitionStyle: transitionStyle ?? this.transitionStyle,
      animationSpeed: animationSpeed ?? this.animationSpeed,
      scrollBehavior: scrollBehavior ?? this.scrollBehavior,
      avatarShape: avatarShape ?? this.avatarShape,
      avatarBorder: avatarBorder ?? this.avatarBorder,
      onlineIndicator: onlineIndicator ?? this.onlineIndicator,
      memberBadgeStyle: memberBadgeStyle ?? this.memberBadgeStyle,
      metaPlacement: metaPlacement ?? this.metaPlacement,
      actionsStyle: actionsStyle ?? this.actionsStyle,
      statsDisplay: statsDisplay ?? this.statsDisplay,
      timestampStyle: timestampStyle ?? this.timestampStyle,
      menuStyle: menuStyle ?? this.menuStyle,
      modalBackdrop: modalBackdrop ?? this.modalBackdrop,
      sheetStyle: sheetStyle ?? this.sheetStyle,
      loadingStyle: loadingStyle ?? this.loadingStyle,
      emptyStateStyle: emptyStateStyle ?? this.emptyStateStyle,
      imageShape: imageShape ?? this.imageShape,
      imageOverlay: imageOverlay ?? this.imageOverlay,
      placeholderStyle: placeholderStyle ?? this.placeholderStyle,
      headingWeight: headingWeight ?? this.headingWeight,
      bodyLineHeight: bodyLineHeight ?? this.bodyLineHeight,
      letterSpacing: letterSpacing ?? this.letterSpacing,
      typographyHierarchy: typographyHierarchy ?? this.typographyHierarchy,
      spacingScale: spacingScale ?? this.spacingScale,
      contentInset: contentInset ?? this.contentInset,
      badgeStyle: badgeStyle ?? this.badgeStyle,
      unreadIndicator: unreadIndicator ?? this.unreadIndicator,
      toastPosition: toastPosition ?? this.toastPosition,
      toastStyle: toastStyle ?? this.toastStyle,
      blurSigma: blurSigma ?? this.blurSigma,
      glassOpacity: glassOpacity ?? this.glassOpacity,
      glassSheetOpacity: glassSheetOpacity ?? this.glassSheetOpacity,
      navBarHeight: navBarHeight ?? this.navBarHeight,
      floatingPillBottomPad:
          floatingPillBottomPad ?? this.floatingPillBottomPad,
      appBarHeight: appBarHeight ?? this.appBarHeight,
      heroHeaderHeight: heroHeaderHeight ?? this.heroHeaderHeight,
      contentPaddingH: contentPaddingH ?? this.contentPaddingH,
      cardSpacing: cardSpacing ?? this.cardSpacing,
      animationDurationMs: animationDurationMs ?? this.animationDurationMs,
      feedImageAspect: feedImageAspect ?? this.feedImageAspect,
    );
  }

  @override
  SdalThemeTokens lerp(ThemeExtension<SdalThemeTokens>? other, double t) {
    if (other is! SdalThemeTokens) return this;
    return SdalThemeTokens(
      canvas: Color.lerp(canvas, other.canvas, t)!,
      canvasSubtle: Color.lerp(canvasSubtle, other.canvasSubtle, t)!,
      panel: Color.lerp(panel, other.panel, t)!,
      panelRaised: Color.lerp(panelRaised, other.panelRaised, t)!,
      panelMuted: Color.lerp(panelMuted, other.panelMuted, t)!,
      panelBorder: Color.lerp(panelBorder, other.panelBorder, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentMuted: Color.lerp(accentMuted, other.accentMuted, t)!,
      success: Color.lerp(success, other.success, t)!,
      successMuted: Color.lerp(successMuted, other.successMuted, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      warningMuted: Color.lerp(warningMuted, other.warningMuted, t)!,
      info: Color.lerp(info, other.info, t)!,
      infoMuted: Color.lerp(infoMuted, other.infoMuted, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      dangerMuted: Color.lerp(dangerMuted, other.dangerMuted, t)!,
      chatOutgoing: Color.lerp(chatOutgoing, other.chatOutgoing, t)!,
      chatIncoming: Color.lerp(chatIncoming, other.chatIncoming, t)!,
      storyActive: Color.lerp(storyActive, other.storyActive, t)!,
      storyInactive: Color.lerp(storyInactive, other.storyInactive, t)!,
      storyOverlay: Color.lerp(storyOverlay, other.storyOverlay, t)!,
      imagePlaceholder: Color.lerp(
        imagePlaceholder,
        other.imagePlaceholder,
        t,
      )!,
      imageError: Color.lerp(imageError, other.imageError, t)!,
      foreground: Color.lerp(foreground, other.foreground, t)!,
      foregroundMuted: Color.lerp(foregroundMuted, other.foregroundMuted, t)!,
      foregroundOnAccent: Color.lerp(
        foregroundOnAccent,
        other.foregroundOnAccent,
        t,
      )!,
      adminExperiment: Color.lerp(adminExperiment, other.adminExperiment, t)!,
      cardRadius: _lerpDouble(cardRadius, other.cardRadius, t),
      buttonRadius: _lerpDouble(buttonRadius, other.buttonRadius, t),
      inputRadius: _lerpDouble(inputRadius, other.inputRadius, t),
      panelBorderWidth: _lerpDouble(
        panelBorderWidth,
        other.panelBorderWidth,
        t,
      ),
      logoAsset: t < 0.5 ? logoAsset : other.logoAsset,
      // Enum fields snap at t=0.5
      navStyle: t < 0.5 ? navStyle : other.navStyle,
      navLabelMode: t < 0.5 ? navLabelMode : other.navLabelMode,
      navIndicator: t < 0.5 ? navIndicator : other.navIndicator,
      navBarBackground: t < 0.5 ? navBarBackground : other.navBarBackground,
      headerStyle: t < 0.5 ? headerStyle : other.headerStyle,
      headerBackground: t < 0.5 ? headerBackground : other.headerBackground,
      logoPosition: t < 0.5 ? logoPosition : other.logoPosition,
      avatarPosition: t < 0.5 ? avatarPosition : other.avatarPosition,
      titleAlignment: t < 0.5 ? titleAlignment : other.titleAlignment,
      cardStyle: t < 0.5 ? cardStyle : other.cardStyle,
      surfaceDepth: t < 0.5 ? surfaceDepth : other.surfaceDepth,
      borderStyle: t < 0.5 ? borderStyle : other.borderStyle,
      backgroundPattern: t < 0.5 ? backgroundPattern : other.backgroundPattern,
      feedLayout: t < 0.5 ? feedLayout : other.feedLayout,
      listItemStyle: t < 0.5 ? listItemStyle : other.listItemStyle,
      separatorStyle: t < 0.5 ? separatorStyle : other.separatorStyle,
      scrollPhysics: t < 0.5 ? scrollPhysics : other.scrollPhysics,
      tapFeedback: t < 0.5 ? tapFeedback : other.tapFeedback,
      transitionStyle: t < 0.5 ? transitionStyle : other.transitionStyle,
      animationSpeed: t < 0.5 ? animationSpeed : other.animationSpeed,
      scrollBehavior: t < 0.5 ? scrollBehavior : other.scrollBehavior,
      avatarShape: t < 0.5 ? avatarShape : other.avatarShape,
      avatarBorder: t < 0.5 ? avatarBorder : other.avatarBorder,
      onlineIndicator: t < 0.5 ? onlineIndicator : other.onlineIndicator,
      memberBadgeStyle: t < 0.5 ? memberBadgeStyle : other.memberBadgeStyle,
      metaPlacement: t < 0.5 ? metaPlacement : other.metaPlacement,
      actionsStyle: t < 0.5 ? actionsStyle : other.actionsStyle,
      statsDisplay: t < 0.5 ? statsDisplay : other.statsDisplay,
      timestampStyle: t < 0.5 ? timestampStyle : other.timestampStyle,
      menuStyle: t < 0.5 ? menuStyle : other.menuStyle,
      modalBackdrop: t < 0.5 ? modalBackdrop : other.modalBackdrop,
      sheetStyle: t < 0.5 ? sheetStyle : other.sheetStyle,
      loadingStyle: t < 0.5 ? loadingStyle : other.loadingStyle,
      emptyStateStyle: t < 0.5 ? emptyStateStyle : other.emptyStateStyle,
      imageShape: t < 0.5 ? imageShape : other.imageShape,
      imageOverlay: t < 0.5 ? imageOverlay : other.imageOverlay,
      placeholderStyle: t < 0.5 ? placeholderStyle : other.placeholderStyle,
      headingWeight: t < 0.5 ? headingWeight : other.headingWeight,
      bodyLineHeight: t < 0.5 ? bodyLineHeight : other.bodyLineHeight,
      letterSpacing: t < 0.5 ? letterSpacing : other.letterSpacing,
      typographyHierarchy: t < 0.5
          ? typographyHierarchy
          : other.typographyHierarchy,
      spacingScale: t < 0.5 ? spacingScale : other.spacingScale,
      contentInset: t < 0.5 ? contentInset : other.contentInset,
      badgeStyle: t < 0.5 ? badgeStyle : other.badgeStyle,
      unreadIndicator: t < 0.5 ? unreadIndicator : other.unreadIndicator,
      toastPosition: t < 0.5 ? toastPosition : other.toastPosition,
      toastStyle: t < 0.5 ? toastStyle : other.toastStyle,
      // Scalar metrics interpolate smoothly
      blurSigma: _lerpDouble(blurSigma, other.blurSigma, t),
      glassOpacity: _lerpDouble(glassOpacity, other.glassOpacity, t),
      glassSheetOpacity: _lerpDouble(
        glassSheetOpacity,
        other.glassSheetOpacity,
        t,
      ),
      navBarHeight: _lerpDouble(navBarHeight, other.navBarHeight, t),
      floatingPillBottomPad: _lerpDouble(
        floatingPillBottomPad,
        other.floatingPillBottomPad,
        t,
      ),
      appBarHeight: _lerpDouble(appBarHeight, other.appBarHeight, t),
      heroHeaderHeight: _lerpDouble(
        heroHeaderHeight,
        other.heroHeaderHeight,
        t,
      ),
      contentPaddingH: _lerpDouble(contentPaddingH, other.contentPaddingH, t),
      cardSpacing: _lerpDouble(cardSpacing, other.cardSpacing, t),
      animationDurationMs: _lerpInt(
        animationDurationMs,
        other.animationDurationMs,
        t,
      ),
      feedImageAspect: _lerpDouble(feedImageAspect, other.feedImageAspect, t),
    );
  }

  static double _lerpDouble(double a, double b, double t) => a + (b - a) * t;
  static int _lerpInt(int a, int b, double t) => (a + (b - a) * t).round();

  // Keep the old public name for any call sites that use it.
  static double lerpDouble(double a, double b, double t) =>
      _lerpDouble(a, b, t);
}

extension SdalThemeTokensThemeData on ThemeData {
  SdalThemeTokens get sdal =>
      extension<SdalThemeTokens>() ??
      (brightness == Brightness.dark
          ? SdalThemeTokens.dark
          : SdalThemeTokens.light);
}
