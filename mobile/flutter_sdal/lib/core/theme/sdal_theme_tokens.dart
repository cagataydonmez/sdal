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
    canvas: Color(0xFFF5F5FF),
    canvasSubtle: Color(0xFFEBEBFF),
    panel: Color(0xFFFEFEFF),
    panelRaised: Color(0xFFEEEEFF),
    panelMuted: Color(0xFFE2E2FF),
    panelBorder: Color(0xFFB8B8E8),
    accent: Color(0xFF3E3FBC),
    accentMuted: Color(0xFFDDDEFF),
    success: Color(0xFF1E6B48),
    successMuted: Color(0xFFD0EDE0),
    warning: Color(0xFF7A5A14),
    warningMuted: Color(0xFFF0E2C0),
    info: Color(0xFF244880),
    infoMuted: Color(0xFFCCD8F4),
    danger: Color(0xFF9E3430),
    dangerMuted: Color(0xFFF2D8D6),
    chatOutgoing: Color(0xFF2A2080),
    chatIncoming: Color(0xFFFEFEFF),
    storyActive: Color(0xFF3E3FBC),
    storyInactive: Color(0xFFB0B0D8),
    storyOverlay: Color(0xB30C0C28),
    imagePlaceholder: Color(0xFFD8D8F0),
    imageError: Color(0xFFC8C8E8),
    foreground: Color(0xFF0A0A1E),
    foregroundMuted: Color(0xFF484878),
    foregroundOnAccent: Color(0xFFF8F8FF),
    adminExperiment: Color(0xFF7060C8),
    cardRadius: 20,
    buttonRadius: 18,
    inputRadius: 20,
    panelBorderWidth: 1.0,
    logoAsset: 'assets/logo_kor.png',
  );

  // ── Kor dark (default) ────────────────────────────────────────────────────
  static const dark = SdalThemeTokens(
    canvas: Color(0xFF0C0C1E),
    canvasSubtle: Color(0xFF12122A),
    panel: Color(0xFF181838),
    panelRaised: Color(0xFF20204A),
    panelMuted: Color(0xFF28285C),
    panelBorder: Color(0xFF404078),
    accent: Color(0xFF818CF8),
    accentMuted: Color(0xFF242460),
    success: Color(0xFF68C090),
    successMuted: Color(0xFF183428),
    warning: Color(0xFFCCAA50),
    warningMuted: Color(0xFF3C2E10),
    info: Color(0xFF70C0E0),
    infoMuted: Color(0xFF143040),
    danger: Color(0xFFE08080),
    dangerMuted: Color(0xFF4A1E1E),
    chatOutgoing: Color(0xFF282870),
    chatIncoming: Color(0xFF181838),
    storyActive: Color(0xFF818CF8),
    storyInactive: Color(0xFF404078),
    storyOverlay: Color(0xD9040410),
    imagePlaceholder: Color(0xFF242458),
    imageError: Color(0xFF2E2E60),
    foreground: Color(0xFFEEEEFF),
    foregroundMuted: Color(0xFF9898C8),
    foregroundOnAccent: Color(0xFF0A0A1E),
    adminExperiment: Color(0xFFA098E8),
    cardRadius: 20,
    buttonRadius: 18,
    inputRadius: 20,
    panelBorderWidth: 1.0,
    logoAsset: 'assets/logo_kor.png',
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
      floatingPillBottomPad: floatingPillBottomPad ?? this.floatingPillBottomPad,
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
      imagePlaceholder: Color.lerp(imagePlaceholder, other.imagePlaceholder, t)!,
      imageError: Color.lerp(imageError, other.imageError, t)!,
      foreground: Color.lerp(foreground, other.foreground, t)!,
      foregroundMuted: Color.lerp(foregroundMuted, other.foregroundMuted, t)!,
      foregroundOnAccent: Color.lerp(foregroundOnAccent, other.foregroundOnAccent, t)!,
      adminExperiment: Color.lerp(adminExperiment, other.adminExperiment, t)!,
      cardRadius: _lerpDouble(cardRadius, other.cardRadius, t),
      buttonRadius: _lerpDouble(buttonRadius, other.buttonRadius, t),
      inputRadius: _lerpDouble(inputRadius, other.inputRadius, t),
      panelBorderWidth: _lerpDouble(panelBorderWidth, other.panelBorderWidth, t),
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
      typographyHierarchy: t < 0.5 ? typographyHierarchy : other.typographyHierarchy,
      spacingScale: t < 0.5 ? spacingScale : other.spacingScale,
      contentInset: t < 0.5 ? contentInset : other.contentInset,
      badgeStyle: t < 0.5 ? badgeStyle : other.badgeStyle,
      unreadIndicator: t < 0.5 ? unreadIndicator : other.unreadIndicator,
      toastPosition: t < 0.5 ? toastPosition : other.toastPosition,
      toastStyle: t < 0.5 ? toastStyle : other.toastStyle,
      // Scalar metrics interpolate smoothly
      blurSigma: _lerpDouble(blurSigma, other.blurSigma, t),
      glassOpacity: _lerpDouble(glassOpacity, other.glassOpacity, t),
      glassSheetOpacity: _lerpDouble(glassSheetOpacity, other.glassSheetOpacity, t),
      navBarHeight: _lerpDouble(navBarHeight, other.navBarHeight, t),
      floatingPillBottomPad: _lerpDouble(floatingPillBottomPad, other.floatingPillBottomPad, t),
      appBarHeight: _lerpDouble(appBarHeight, other.appBarHeight, t),
      heroHeaderHeight: _lerpDouble(heroHeaderHeight, other.heroHeaderHeight, t),
      contentPaddingH: _lerpDouble(contentPaddingH, other.contentPaddingH, t),
      cardSpacing: _lerpDouble(cardSpacing, other.cardSpacing, t),
      animationDurationMs: _lerpInt(animationDurationMs, other.animationDurationMs, t),
      feedImageAspect: _lerpDouble(feedImageAspect, other.feedImageAspect, t),
    );
  }

  static double _lerpDouble(double a, double b, double t) => a + (b - a) * t;
  static int _lerpInt(int a, int b, double t) => (a + (b - a) * t).round();

  // Keep the old public name for any call sites that use it.
  static double lerpDouble(double a, double b, double t) => _lerpDouble(a, b, t);
}

extension SdalThemeTokensThemeData on ThemeData {
  SdalThemeTokens get sdal =>
      extension<SdalThemeTokens>() ??
      (brightness == Brightness.dark
          ? SdalThemeTokens.dark
          : SdalThemeTokens.light);
}
