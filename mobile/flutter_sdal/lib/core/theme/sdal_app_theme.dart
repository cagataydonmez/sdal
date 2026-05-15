import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'sdal_theme_tokens.dart';

enum SdalAppTheme {
  kor,
  atlas,
  vibe,
  zinc,
  ember,
  mist;

  static SdalAppTheme fromString(String? value) {
    return switch (value?.toLowerCase().trim()) {
      'atlas' => atlas,
      'vibe'  => vibe,
      'zinc'  => zinc,
      'ember' => ember,
      'mist'  => mist,
      _       => kor,
    };
  }

  String get id => name;

  String get displayName => switch (this) {
    kor   => 'Kor',
    atlas => 'Atlas',
    vibe  => 'Vibe',
    zinc  => 'Zinc',
    ember => 'Ember',
    mist  => 'Mist',
  };

  String get tagline => switch (this) {
    kor   => 'Sıcak & samimi',
    atlas => 'Keskin & yapısal',
    vibe  => 'Yuvarlak & enerjik',
    zinc  => 'Minimal & editoryal',
    ember => 'Lüks & amber',
    mist  => 'Havadar & organik',
  };

  /// Dark-mode accent for watchOS .tint().
  Color get watchAccent => switch (this) {
    kor   => const Color(0xFFE99A73),
    atlas => const Color(0xFF82B8E0),
    vibe  => const Color(0xFFBB96F5),
    zinc  => const Color(0xFFC8CDD6),
    ember => const Color(0xFFF0C050),
    mist  => const Color(0xFF80C89C),
  };

  /// Three representative swatch colors for the theme picker.
  List<Color> get swatches => switch (this) {
    kor   => const [Color(0xFFE99A73), Color(0xFFB45637), Color(0xFF17120F)],
    atlas => const [Color(0xFF82B8E0), Color(0xFF2478B0), Color(0xFF0F1820)],
    vibe  => const [Color(0xFFBB96F5), Color(0xFF7248C8), Color(0xFF130F1E)],
    zinc  => const [Color(0xFF2D3540), Color(0xFFC4C8CD), Color(0xFF0E1014)],
    ember => const [Color(0xFFF0C050), Color(0xFFB88020), Color(0xFF1A1200)],
    mist  => const [Color(0xFF80C89C), Color(0xFF3A7A58), Color(0xFF0C1610)],
  };

  String get logoAsset => 'assets/logo_$name.png';

  SdalThemeTokens get lightTokens => switch (this) {
    kor   => SdalThemeTokens.light,
    atlas => _atlasLight,
    vibe  => _vibeLight,
    zinc  => _zincLight,
    ember => _emberLight,
    mist  => _mistLight,
  };

  SdalThemeTokens get darkTokens => switch (this) {
    kor   => SdalThemeTokens.dark,
    atlas => _atlasDark,
    vibe  => _vibeDark,
    zinc  => _zincDark,
    ember => _emberDark,
    mist  => _mistDark,
  };

  SdalThemeTokens tokensFor(Brightness brightness) =>
      brightness == Brightness.dark ? darkTokens : lightTokens;

  // ---------------------------------------------------------------------------
  // Font integration
  // ---------------------------------------------------------------------------

  /// The ThemeData fontFamily string.
  /// Kor uses the local Manrope asset; others resolve via Google Fonts.
  String get materialFontFamily => switch (this) {
    kor   => 'Manrope',
    atlas => GoogleFonts.ibmPlexSans().fontFamily!,
    vibe  => GoogleFonts.nunito().fontFamily!,
    zinc  => GoogleFonts.dmSans().fontFamily!,
    ember => GoogleFonts.outfit().fontFamily!,
    mist  => GoogleFonts.jost().fontFamily!,
  };

  /// Apply this theme's typeface to [base]. For Kor the base is returned
  /// unchanged because Manrope is already wired via [materialFontFamily].
  TextTheme applyFont(TextTheme base) => switch (this) {
    kor   => base,
    atlas => GoogleFonts.ibmPlexSansTextTheme(base),
    vibe  => GoogleFonts.nunitoTextTheme(base),
    zinc  => GoogleFonts.dmSansTextTheme(base),
    ember => GoogleFonts.outfitTextTheme(base),
    mist  => GoogleFonts.jostTextTheme(base),
  };
}

// ---------------------------------------------------------------------------
// Atlas — structured steel-blue, razor-sharp corners
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
  cardRadius: 10,
  buttonRadius: 8,
  inputRadius: 10,
  panelBorderWidth: 1.0,
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
  cardRadius: 10,
  buttonRadius: 8,
  inputRadius: 10,
  panelBorderWidth: 1.0,
);

// ---------------------------------------------------------------------------
// Vibe — vivid violet, pillowy-round corners
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
  cardRadius: 28,
  buttonRadius: 24,
  inputRadius: 24,
  panelBorderWidth: 0.5,
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
  cardRadius: 28,
  buttonRadius: 24,
  inputRadius: 24,
  panelBorderWidth: 0.5,
);

// ---------------------------------------------------------------------------
// Zinc — near-neutral slate, knife-sharp corners, editorial
// ---------------------------------------------------------------------------

const _zincLight = SdalThemeTokens(
  canvas: Color(0xFFF2F3F5),
  canvasSubtle: Color(0xFFE5E8EC),
  panel: Color(0xFFFAFBFC),
  panelRaised: Color(0xFFEEEFF2),
  panelMuted: Color(0xFFE0E3E8),
  panelBorder: Color(0xFFC2C6CE),
  accent: Color(0xFF2D3540),
  accentMuted: Color(0xFFD4D8DE),
  success: Color(0xFF2A6A4A),
  successMuted: Color(0xFFD5EDE3),
  warning: Color(0xFF7A5A14),
  warningMuted: Color(0xFFEFE2C0),
  info: Color(0xFF2A5070),
  infoMuted: Color(0xFFCEE0EE),
  danger: Color(0xFF9E3430),
  dangerMuted: Color(0xFFF0D8D6),
  chatOutgoing: Color(0xFF2A3A48),
  chatIncoming: Color(0xFFFAFBFC),
  storyActive: Color(0xFF2D3540),
  storyInactive: Color(0xFFA8B0BC),
  storyOverlay: Color(0xB30A0C10),
  imagePlaceholder: Color(0xFFD8DCE2),
  imageError: Color(0xFFC8CDD4),
  foreground: Color(0xFF141820),
  foregroundMuted: Color(0xFF5A6070),
  foregroundOnAccent: Color(0xFFF5F7FA),
  adminExperiment: Color(0xFF5060A0),
  cardRadius: 6,
  buttonRadius: 4,
  inputRadius: 6,
  panelBorderWidth: 0.8,
);

const _zincDark = SdalThemeTokens(
  canvas: Color(0xFF0E1014),
  canvasSubtle: Color(0xFF14181E),
  panel: Color(0xFF1A1E24),
  panelRaised: Color(0xFF20262E),
  panelMuted: Color(0xFF282E38),
  panelBorder: Color(0xFF38404C),
  accent: Color(0xFFC8CDD6),
  accentMuted: Color(0xFF2A3040),
  success: Color(0xFF72C09A),
  successMuted: Color(0xFF183828),
  warning: Color(0xFFCCAA50),
  warningMuted: Color(0xFF3C2E10),
  info: Color(0xFF78C0D8),
  infoMuted: Color(0xFF183040),
  danger: Color(0xFFE08880),
  dangerMuted: Color(0xFF481E1E),
  chatOutgoing: Color(0xFF283444),
  chatIncoming: Color(0xFF1A1E24),
  storyActive: Color(0xFFC8CDD6),
  storyInactive: Color(0xFF485058),
  storyOverlay: Color(0xD9040608),
  imagePlaceholder: Color(0xFF242A34),
  imageError: Color(0xFF303844),
  foreground: Color(0xFFECF0F6),
  foregroundMuted: Color(0xFF8A9098),
  foregroundOnAccent: Color(0xFF0E1014),
  adminExperiment: Color(0xFF8898D8),
  cardRadius: 6,
  buttonRadius: 4,
  inputRadius: 6,
  panelBorderWidth: 0.8,
);

// ---------------------------------------------------------------------------
// Ember — warm amber gold luxury, borderless cards, medium radius
// ---------------------------------------------------------------------------

const _emberLight = SdalThemeTokens(
  canvas: Color(0xFFFBF5EC),
  canvasSubtle: Color(0xFFF2E8D8),
  panel: Color(0xFFFFFDF5),
  panelRaised: Color(0xFFF8F0E0),
  panelMuted: Color(0xFFEEE0C8),
  panelBorder: Color(0xFFD4B880),
  accent: Color(0xFFB88020),
  accentMuted: Color(0xFFF4E4A8),
  success: Color(0xFF286848),
  successMuted: Color(0xFFD2EDE0),
  warning: Color(0xFF8C5A10),
  warningMuted: Color(0xFFF2E0B8),
  info: Color(0xFF2A5878),
  infoMuted: Color(0xFFCCE4F4),
  danger: Color(0xFF9E3428),
  dangerMuted: Color(0xFFF2D4D0),
  chatOutgoing: Color(0xFF5A3800),
  chatIncoming: Color(0xFFFFFDF5),
  storyActive: Color(0xFFB88020),
  storyInactive: Color(0xFFCCB888),
  storyOverlay: Color(0xB3201400),
  imagePlaceholder: Color(0xFFEAD8B0),
  imageError: Color(0xFFE0CCAA),
  foreground: Color(0xFF281800),
  foregroundMuted: Color(0xFF6A5020),
  foregroundOnAccent: Color(0xFFFFF8E8),
  adminExperiment: Color(0xFF7050A0),
  cardRadius: 16,
  buttonRadius: 14,
  inputRadius: 14,
  panelBorderWidth: 0.0,
);

const _emberDark = SdalThemeTokens(
  canvas: Color(0xFF1A1200),
  canvasSubtle: Color(0xFF221800),
  panel: Color(0xFF2C1E00),
  panelRaised: Color(0xFF362600),
  panelMuted: Color(0xFF402E00),
  panelBorder: Color(0xFF604010),
  accent: Color(0xFFF0C050),
  accentMuted: Color(0xFF5A3800),
  success: Color(0xFF78C098),
  successMuted: Color(0xFF1C3C28),
  warning: Color(0xFFD4AA50),
  warningMuted: Color(0xFF3E2800),
  info: Color(0xFF78C0D8),
  infoMuted: Color(0xFF163040),
  danger: Color(0xFFE08878),
  dangerMuted: Color(0xFF4A2018),
  chatOutgoing: Color(0xFF4A3000),
  chatIncoming: Color(0xFF2C1E00),
  storyActive: Color(0xFFF0C050),
  storyInactive: Color(0xFF705030),
  storyOverlay: Color(0xD908060A),
  imagePlaceholder: Color(0xFF403000),
  imageError: Color(0xFF503C00),
  foreground: Color(0xFFFFF5DC),
  foregroundMuted: Color(0xFFD0A860),
  foregroundOnAccent: Color(0xFF1A0E00),
  adminExperiment: Color(0xFFCC9AFF),
  cardRadius: 16,
  buttonRadius: 14,
  inputRadius: 14,
  panelBorderWidth: 0.0,
);

// ---------------------------------------------------------------------------
// Mist — sage green, organic humanist, soft rounded corners
// ---------------------------------------------------------------------------

const _mistLight = SdalThemeTokens(
  canvas: Color(0xFFEFF4F0),
  canvasSubtle: Color(0xFFE0EBE3),
  panel: Color(0xFFFAFDF9),
  panelRaised: Color(0xFFEDF5EF),
  panelMuted: Color(0xFFDDEBE0),
  panelBorder: Color(0xFFAAC8B4),
  accent: Color(0xFF3A7A58),
  accentMuted: Color(0xFFC4E4D0),
  success: Color(0xFF267050),
  successMuted: Color(0xFFCCEEDC),
  warning: Color(0xFF7A5A14),
  warningMuted: Color(0xFFEEE0BE),
  info: Color(0xFF2A5870),
  infoMuted: Color(0xFFCCE4F0),
  danger: Color(0xFF9E3838),
  dangerMuted: Color(0xFFF0D4D4),
  chatOutgoing: Color(0xFF284838),
  chatIncoming: Color(0xFFFAFDF9),
  storyActive: Color(0xFF3A7A58),
  storyInactive: Color(0xFFA0C0AC),
  storyOverlay: Color(0xB30C1A10),
  imagePlaceholder: Color(0xFFCEE4D6),
  imageError: Color(0xFFC0D8C8),
  foreground: Color(0xFF0C201A),
  foregroundMuted: Color(0xFF4A6858),
  foregroundOnAccent: Color(0xFFF0FBF4),
  adminExperiment: Color(0xFF6050A8),
  cardRadius: 24,
  buttonRadius: 20,
  inputRadius: 20,
  panelBorderWidth: 0.6,
);

const _mistDark = SdalThemeTokens(
  canvas: Color(0xFF0C1610),
  canvasSubtle: Color(0xFF121E16),
  panel: Color(0xFF18261C),
  panelRaised: Color(0xFF1E2E22),
  panelMuted: Color(0xFF24382A),
  panelBorder: Color(0xFF304A38),
  accent: Color(0xFF80C89C),
  accentMuted: Color(0xFF1E4830),
  success: Color(0xFF70C090),
  successMuted: Color(0xFF183C28),
  warning: Color(0xFFCCA850),
  warningMuted: Color(0xFF3C2E10),
  info: Color(0xFF78C0D8),
  infoMuted: Color(0xFF163040),
  danger: Color(0xFFE08888),
  dangerMuted: Color(0xFF481E1E),
  chatOutgoing: Color(0xFF1E4830),
  chatIncoming: Color(0xFF18261C),
  storyActive: Color(0xFF80C89C),
  storyInactive: Color(0xFF405848),
  storyOverlay: Color(0xD904100A),
  imagePlaceholder: Color(0xFF203428),
  imageError: Color(0xFF2A4030),
  foreground: Color(0xFFDCF2E6),
  foregroundMuted: Color(0xFF80A890),
  foregroundOnAccent: Color(0xFF080E0A),
  adminExperiment: Color(0xFF9898E8),
  cardRadius: 24,
  buttonRadius: 20,
  inputRadius: 20,
  panelBorderWidth: 0.6,
);
