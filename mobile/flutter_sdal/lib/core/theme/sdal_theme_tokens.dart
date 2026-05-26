import 'package:flutter/material.dart';

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
    // ── Shape tokens (per-theme, same for light & dark) ──────────────
    this.cardRadius = 20.0,
    this.buttonRadius = 18.0,
    this.inputRadius = 20.0,
    this.panelBorderWidth = 1.0,
    // ── Logo asset path (per-theme) ───────────────────────────────────
    this.logoAsset = 'icon.png',
  });

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

  /// Radius used for card surfaces.
  final double cardRadius;

  /// Radius used for filled/outlined buttons and FAB.
  final double buttonRadius;

  /// Radius used for text input fields.
  final double inputRadius;

  /// Width of panel border lines. 0.0 = borderless.
  final double panelBorderWidth;

  /// Asset path for the theme-specific app logo shown in the logo badge.
  final String logoAsset;

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
      cardRadius: lerpDouble(cardRadius, other.cardRadius, t),
      buttonRadius: lerpDouble(buttonRadius, other.buttonRadius, t),
      inputRadius: lerpDouble(inputRadius, other.inputRadius, t),
      panelBorderWidth: lerpDouble(panelBorderWidth, other.panelBorderWidth, t),
      logoAsset: t < 0.5 ? logoAsset : other.logoAsset,
    );
  }

  static double lerpDouble(double a, double b, double t) => a + (b - a) * t;
}

extension SdalThemeTokensThemeData on ThemeData {
  SdalThemeTokens get sdal =>
      extension<SdalThemeTokens>() ??
      (brightness == Brightness.dark
          ? SdalThemeTokens.dark
          : SdalThemeTokens.light);
}
