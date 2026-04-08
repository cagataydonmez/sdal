import 'package:flutter/material.dart';

@immutable
class SdalThemeTokens extends ThemeExtension<SdalThemeTokens> {
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
    canvas: Color(0xFFF7F1E8),
    canvasSubtle: Color(0xFFF0E5D6),
    panel: Color(0xFFFFFBF5),
    panelRaised: Color(0xFFF9F2E8),
    panelMuted: Color(0xFFF1E8DA),
    panelBorder: Color(0xFFD8CABB),
    accent: Color(0xFFC8633C),
    accentMuted: Color(0xFFF2D7CB),
    success: Color(0xFF2C6B4B),
    successMuted: Color(0xFFE3EFE7),
    warning: Color(0xFF9B6A1C),
    warningMuted: Color(0xFFF4E7CF),
    info: Color(0xFF355C87),
    infoMuted: Color(0xFFE5EDF7),
    danger: Color(0xFFAA4834),
    dangerMuted: Color(0xFFF6E2DD),
    chatOutgoing: Color(0xFF2E4958),
    chatIncoming: Color(0xFFFFFBF5),
    storyActive: Color(0xFFC8633C),
    storyInactive: Color(0xFFCDBEAC),
    storyOverlay: Color(0xB314100C),
    imagePlaceholder: Color(0xFFE8DDCF),
    imageError: Color(0xFFDCCFC0),
    foreground: Color(0xFF241C16),
    foregroundMuted: Color(0xFF6E6255),
    foregroundOnAccent: Color(0xFFFFFAF6),
    adminExperiment: Color(0xFF6A4FB4),
  );

  static const dark = SdalThemeTokens(
    canvas: Color(0xFF16120E),
    canvasSubtle: Color(0xFF1E1813),
    panel: Color(0xFF241E19),
    panelRaised: Color(0xFF2B241E),
    panelMuted: Color(0xFF322921),
    panelBorder: Color(0xFF4B3E33),
    accent: Color(0xFFE18B64),
    accentMuted: Color(0xFF563427),
    success: Color(0xFF78B691),
    successMuted: Color(0xFF24392C),
    warning: Color(0xFFD2A14F),
    warningMuted: Color(0xFF45341B),
    info: Color(0xFF8EB2E0),
    infoMuted: Color(0xFF223447),
    danger: Color(0xFFE28A77),
    dangerMuted: Color(0xFF4E2920),
    chatOutgoing: Color(0xFF345061),
    chatIncoming: Color(0xFF2B241E),
    storyActive: Color(0xFFE18B64),
    storyInactive: Color(0xFF5D5146),
    storyOverlay: Color(0xD9070604),
    imagePlaceholder: Color(0xFF3A3027),
    imageError: Color(0xFF4A3C31),
    foreground: Color(0xFFF4ECE0),
    foregroundMuted: Color(0xFFC6B7A6),
    foregroundOnAccent: Color(0xFF1B130D),
    adminExperiment: Color(0xFFAB94E6),
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
