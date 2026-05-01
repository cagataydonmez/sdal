import 'package:flutter/material.dart';

@immutable
class SdalThemeTokens extends ThemeExtension<SdalThemeTokens> {
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

  static const light = SdalThemeTokens(
    canvas: Color(0xFFF7F2E9),
    canvasSubtle: Color(0xFFEDE2D3),
    panel: Color(0xFFFFFCF7),
    panelRaised: Color(0xFFFAF4EB),
    panelMuted: Color(0xFFEFE5D8),
    panelBorder: Color(0xFFD3C1AF),
    accent: Color(0xFFB45637),
    accentMuted: Color(0xFFF3D8CA),
    success: Color(0xFF2A6A4C),
    successMuted: Color(0xFFDDEFE6),
    warning: Color(0xFF8A5D16),
    warningMuted: Color(0xFFF2E3C4),
    info: Color(0xFF2F6078),
    infoMuted: Color(0xFFDCECF0),
    danger: Color(0xFFA44635),
    dangerMuted: Color(0xFFF4DDD8),
    chatOutgoing: Color(0xFF315565),
    chatIncoming: Color(0xFFFFFCF7),
    storyActive: Color(0xFFB45637),
    storyInactive: Color(0xFFC7B6A4),
    storyOverlay: Color(0xB315100C),
    imagePlaceholder: Color(0xFFE5D9CA),
    imageError: Color(0xFFD8C9B8),
    foreground: Color(0xFF261B14),
    foregroundMuted: Color(0xFF66594C),
    foregroundOnAccent: Color(0xFFFFFAF4),
    adminExperiment: Color(0xFF7055A6),
  );

  static const dark = SdalThemeTokens(
    canvas: Color(0xFF17120F),
    canvasSubtle: Color(0xFF211915),
    panel: Color(0xFF29211C),
    panelRaised: Color(0xFF312821),
    panelMuted: Color(0xFF3A3028),
    panelBorder: Color(0xFF57483B),
    accent: Color(0xFFE99A73),
    accentMuted: Color(0xFF5B3427),
    success: Color(0xFF80C49A),
    successMuted: Color(0xFF223B2D),
    warning: Color(0xFFD9A94F),
    warningMuted: Color(0xFF4A3518),
    info: Color(0xFF8FC8D6),
    infoMuted: Color(0xFF203844),
    danger: Color(0xFFE6907E),
    dangerMuted: Color(0xFF552A22),
    chatOutgoing: Color(0xFF3B6170),
    chatIncoming: Color(0xFF312821),
    storyActive: Color(0xFFE99A73),
    storyInactive: Color(0xFF67584A),
    storyOverlay: Color(0xD9080604),
    imagePlaceholder: Color(0xFF42362D),
    imageError: Color(0xFF514237),
    foreground: Color(0xFFF6EDE2),
    foregroundMuted: Color(0xFFCDBCAA),
    foregroundOnAccent: Color(0xFF1E130C),
    adminExperiment: Color(0xFFB79AF0),
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
    );
  }
}

extension SdalThemeTokensThemeData on ThemeData {
  SdalThemeTokens get sdal =>
      extension<SdalThemeTokens>() ??
      (brightness == Brightness.dark
          ? SdalThemeTokens.dark
          : SdalThemeTokens.light);
}
