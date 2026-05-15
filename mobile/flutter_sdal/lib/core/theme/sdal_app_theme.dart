import 'package:flutter/material.dart';
import 'sdal_theme_tokens.dart';

enum SdalAppTheme {
  kor,
  atlas,
  vibe;

  static SdalAppTheme fromString(String? value) {
    return switch (value?.toLowerCase().trim()) {
      'atlas' => atlas,
      'vibe' => vibe,
      _ => kor,
    };
  }

  String get id => name;

  String get displayName => switch (this) {
    kor => 'Kor',
    atlas => 'Atlas',
    vibe => 'Vibe',
  };

  String get tagline => switch (this) {
    kor => 'Sıcak & samimi',
    atlas => 'Profesyonel & sakin',
    vibe => 'Sosyal & enerjik',
  };

  /// Dark-mode accent color used for watchOS .tint()
  Color get watchAccent => switch (this) {
    kor => const Color(0xFFE99A73),
    atlas => const Color(0xFF82B8E0),
    vibe => const Color(0xFFBB96F5),
  };

  /// Three representative swatch colors for the admin picker
  List<Color> get swatches => switch (this) {
    kor => const [Color(0xFFE99A73), Color(0xFF2A6A4C), Color(0xFF17120F)],
    atlas => const [Color(0xFF82B8E0), Color(0xFF5AC8A0), Color(0xFF0F1820)],
    vibe => const [Color(0xFFBB96F5), Color(0xFF5AC8A0), Color(0xFF130F1E)],
  };

  String get logoAsset => 'assets/logo_$name.png';

  SdalThemeTokens get lightTokens => switch (this) {
    kor => SdalThemeTokens.light,
    atlas => _atlasLight,
    vibe => _vibeLight,
  };

  SdalThemeTokens get darkTokens => switch (this) {
    kor => SdalThemeTokens.dark,
    atlas => _atlasDark,
    vibe => _vibeDark,
  };

  SdalThemeTokens tokensFor(Brightness brightness) =>
      brightness == Brightness.dark ? darkTokens : lightTokens;
}

// ---------------------------------------------------------------------------
// Atlas — cool professional blues
// ---------------------------------------------------------------------------

const _atlasLight = SdalThemeTokens(
  canvas: Color(0xFFF0F4F8),
  canvasSubtle: Color(0xFFE2EBF2),
  panel: Color(0xFFFAFCFE),
  panelRaised: Color(0xFFEEF4FA),
  panelMuted: Color(0xFFE0EBF4),
  panelBorder: Color(0xFFB0CADA),
  accent: Color(0xFF2478B0),
  accentMuted: Color(0xFFCDE4F5),
  success: Color(0xFF1E6B4C),
  successMuted: Color(0xFFD5EDE3),
  warning: Color(0xFF7A5A14),
  warningMuted: Color(0xFFF0E2C2),
  info: Color(0xFF245578),
  infoMuted: Color(0xFFD0E8F2),
  danger: Color(0xFF9E3430),
  dangerMuted: Color(0xFFF2D8D6),
  chatOutgoing: Color(0xFF204F6C),
  chatIncoming: Color(0xFFFAFCFE),
  storyActive: Color(0xFF2478B0),
  storyInactive: Color(0xFFAABECA),
  storyOverlay: Color(0xB30C1A26),
  imagePlaceholder: Color(0xFFD6E4EE),
  imageError: Color(0xFFC8D9E4),
  foreground: Color(0xFF0E1E2C),
  foregroundMuted: Color(0xFF506070),
  foregroundOnAccent: Color(0xFFF4FAFF),
  adminExperiment: Color(0xFF5A6FA8),
);

const _atlasDark = SdalThemeTokens(
  canvas: Color(0xFF0F1820),
  canvasSubtle: Color(0xFF162030),
  panel: Color(0xFF1C2C3C),
  panelRaised: Color(0xFF243444),
  panelMuted: Color(0xFF2C3E50),
  panelBorder: Color(0xFF3E5468),
  accent: Color(0xFF82B8E0),
  accentMuted: Color(0xFF1C3C58),
  success: Color(0xFF6ABFA0),
  successMuted: Color(0xFF183A2C),
  warning: Color(0xFFCCA84E),
  warningMuted: Color(0xFF3E2E10),
  info: Color(0xFF7AC8DA),
  infoMuted: Color(0xFF163040),
  danger: Color(0xFFE08880),
  dangerMuted: Color(0xFF4A2020),
  chatOutgoing: Color(0xFF284C64),
  chatIncoming: Color(0xFF1C2C3C),
  storyActive: Color(0xFF82B8E0),
  storyInactive: Color(0xFF4A6070),
  storyOverlay: Color(0xD9040C14),
  imagePlaceholder: Color(0xFF2A3C4E),
  imageError: Color(0xFF3A4E5E),
  foreground: Color(0xFFE8F2FA),
  foregroundMuted: Color(0xFFAABECA),
  foregroundOnAccent: Color(0xFF0A1620),
  adminExperiment: Color(0xFF9ABAEE),
);

// ---------------------------------------------------------------------------
// Vibe — vivid violet social
// ---------------------------------------------------------------------------

const _vibeLight = SdalThemeTokens(
  canvas: Color(0xFFF3F0F9),
  canvasSubtle: Color(0xFFE8E0F4),
  panel: Color(0xFFFCFAFF),
  panelRaised: Color(0xFFF0EAF9),
  panelMuted: Color(0xFFE4DDF2),
  panelBorder: Color(0xFFC4B0DC),
  accent: Color(0xFF7248C8),
  accentMuted: Color(0xFFE2D4F8),
  success: Color(0xFF226844),
  successMuted: Color(0xFFD4EDE0),
  warning: Color(0xFF7A5814),
  warningMuted: Color(0xFFF2E2C0),
  info: Color(0xFF2C5880),
  infoMuted: Color(0xFFD0E4F4),
  danger: Color(0xFF9E3030),
  dangerMuted: Color(0xFFF2D4D4),
  chatOutgoing: Color(0xFF4A2A80),
  chatIncoming: Color(0xFFFCFAFF),
  storyActive: Color(0xFF7248C8),
  storyInactive: Color(0xFFB8A8D0),
  storyOverlay: Color(0xB3120A20),
  imagePlaceholder: Color(0xFFDDD4EE),
  imageError: Color(0xFFCEC4E4),
  foreground: Color(0xFF180E2C),
  foregroundMuted: Color(0xFF605080),
  foregroundOnAccent: Color(0xFFFBF6FF),
  adminExperiment: Color(0xFF9068D8),
);

const _vibeDark = SdalThemeTokens(
  canvas: Color(0xFF130F1E),
  canvasSubtle: Color(0xFF1C1630),
  panel: Color(0xFF251E3C),
  panelRaised: Color(0xFF2E2648),
  panelMuted: Color(0xFF382E56),
  panelBorder: Color(0xFF524070),
  accent: Color(0xFFBB96F5),
  accentMuted: Color(0xFF3C2460),
  success: Color(0xFF72C09C),
  successMuted: Color(0xFF1A3828),
  warning: Color(0xFFCCAA50),
  warningMuted: Color(0xFF3E3010),
  info: Color(0xFF7AC0D8),
  infoMuted: Color(0xFF183040),
  danger: Color(0xFFE08888),
  dangerMuted: Color(0xFF4A1E1E),
  chatOutgoing: Color(0xFF3C2060),
  chatIncoming: Color(0xFF251E3C),
  storyActive: Color(0xFFBB96F5),
  storyInactive: Color(0xFF605080),
  storyOverlay: Color(0xD90A0616),
  imagePlaceholder: Color(0xFF382E56),
  imageError: Color(0xFF46385E),
  foreground: Color(0xFFF0ECFF),
  foregroundMuted: Color(0xFFBEB0D8),
  foregroundOnAccent: Color(0xFF100A20),
  adminExperiment: Color(0xFFCC9AFF),
);
