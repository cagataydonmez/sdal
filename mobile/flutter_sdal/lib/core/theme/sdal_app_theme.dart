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
    atlas => 'Premium & kobalt',
    vibe  => 'Elektrik & canlı',
    zinc  => 'Noir & keskin',
    ember => 'Lüks & altın',
    mist  => 'Zümrüt & taze',
  };

  /// Dark-mode accent for watchOS .tint().
  Color get watchAccent => switch (this) {
    kor   => const Color(0xFFE99A73),
    atlas => const Color(0xFF4D9FFF),
    vibe  => const Color(0xFFB47FFF),
    zinc  => const Color(0xFF22D3EE),
    ember => const Color(0xFFFFB800),
    mist  => const Color(0xFF51CF66),
  };

  /// Three representative swatch colors for the theme picker.
  List<Color> get swatches => switch (this) {
    kor   => const [Color(0xFFE99A73), Color(0xFFB45637), Color(0xFF17120F)],
    atlas => const [Color(0xFF4D9FFF), Color(0xFF1060A0), Color(0xFF0A1428)],
    vibe  => const [Color(0xFFB47FFF), Color(0xFF6200EE), Color(0xFF110820)],
    zinc  => const [Color(0xFF22D3EE), Color(0xFF0891B2), Color(0xFF0A0A0B)],
    ember => const [Color(0xFFFFB800), Color(0xFFD4700A), Color(0xFF1A1000)],
    mist  => const [Color(0xFF51CF66), Color(0xFF087F5B), Color(0xFF081210)],
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
// Atlas — deep cobalt, premium precision, clean navy depth
// ---------------------------------------------------------------------------

const _atlasLight = SdalThemeTokens(
  canvas: Color(0xFFF1F5FB),
  canvasSubtle: Color(0xFFE3EDF8),
  panel: Color(0xFFFBFDFF),
  panelRaised: Color(0xFFEBF2FB),
  panelMuted: Color(0xFFDAEAF8),
  panelBorder: Color(0xFFAAC8E8),
  accent: Color(0xFF1060A0),
  accentMuted: Color(0xFFCCE3F8),
  success: Color(0xFF1A6B48),
  successMuted: Color(0xFFD0EDE0),
  warning: Color(0xFF7A5A14),
  warningMuted: Color(0xFFF0E2C0),
  info: Color(0xFF244880),
  infoMuted: Color(0xFFCCD8F4),
  danger: Color(0xFF9E3430),
  dangerMuted: Color(0xFFF2D8D6),
  chatOutgoing: Color(0xFF1A4A70),
  chatIncoming: Color(0xFFFBFDFF),
  storyActive: Color(0xFF1060A0),
  storyInactive: Color(0xFFA4C2DC),
  storyOverlay: Color(0xB30A1628),
  imagePlaceholder: Color(0xFFCADEF2),
  imageError: Color(0xFFBCD0E8),
  foreground: Color(0xFF0A1628),
  foregroundMuted: Color(0xFF486078),
  foregroundOnAccent: Color(0xFFF0F8FF),
  adminExperiment: Color(0xFF4060B0),
  cardRadius: 12,
  buttonRadius: 10,
  inputRadius: 12,
  panelBorderWidth: 0.8,
);

const _atlasDark = SdalThemeTokens(
  canvas: Color(0xFF0A1428),
  canvasSubtle: Color(0xFF101E38),
  panel: Color(0xFF162040),
  panelRaised: Color(0xFF1C2A4C),
  panelMuted: Color(0xFF243460),
  panelBorder: Color(0xFF385068),
  accent: Color(0xFF4D9FFF),
  accentMuted: Color(0xFF1A3060),
  success: Color(0xFF60BA90),
  successMuted: Color(0xFF143428),
  warning: Color(0xFFCCAA48),
  warningMuted: Color(0xFF3A2C0E),
  info: Color(0xFF70C0E0),
  infoMuted: Color(0xFF143040),
  danger: Color(0xFFE08078),
  dangerMuted: Color(0xFF481E1E),
  chatOutgoing: Color(0xFF1E3C60),
  chatIncoming: Color(0xFF162040),
  storyActive: Color(0xFF4D9FFF),
  storyInactive: Color(0xFF385068),
  storyOverlay: Color(0xD904081E),
  imagePlaceholder: Color(0xFF223460),
  imageError: Color(0xFF2C3E58),
  foreground: Color(0xFFE8F2FF),
  foregroundMuted: Color(0xFF9ABBDC),
  foregroundOnAccent: Color(0xFF0A1428),
  adminExperiment: Color(0xFF80A0E0),
  cardRadius: 12,
  buttonRadius: 10,
  inputRadius: 12,
  panelBorderWidth: 0.8,
);

// ---------------------------------------------------------------------------
// Vibe — electric violet, vivid energy, bold saturated punch
// ---------------------------------------------------------------------------

const _vibeLight = SdalThemeTokens(
  canvas: Color(0xFFF7F3FF),
  canvasSubtle: Color(0xFFEDE4FF),
  panel: Color(0xFFFEFCFF),
  panelRaised: Color(0xFFF3ECFF),
  panelMuted: Color(0xFFE8DCFF),
  panelBorder: Color(0xFFCCB0F0),
  accent: Color(0xFF6200EE),
  accentMuted: Color(0xFFE8D6FF),
  success: Color(0xFF1E6844),
  successMuted: Color(0xFFD0EDE0),
  warning: Color(0xFF7A5814),
  warningMuted: Color(0xFFF2E2C0),
  info: Color(0xFF2A5080),
  infoMuted: Color(0xFFCCDCF4),
  danger: Color(0xFF9E3030),
  dangerMuted: Color(0xFFF4D4D4),
  chatOutgoing: Color(0xFF3A0A90),
  chatIncoming: Color(0xFFFEFCFF),
  storyActive: Color(0xFF6200EE),
  storyInactive: Color(0xFFBBA8E0),
  storyOverlay: Color(0xB3100820),
  imagePlaceholder: Color(0xFFDDD0FF),
  imageError: Color(0xFFCEC0F0),
  foreground: Color(0xFF14083A),
  foregroundMuted: Color(0xFF584878),
  foregroundOnAccent: Color(0xFFFAF4FF),
  adminExperiment: Color(0xFF9050E0),
  cardRadius: 24,
  buttonRadius: 22,
  inputRadius: 22,
  panelBorderWidth: 0.7,
);

const _vibeDark = SdalThemeTokens(
  canvas: Color(0xFF110820),
  canvasSubtle: Color(0xFF1A1030),
  panel: Color(0xFF221840),
  panelRaised: Color(0xFF2C2050),
  panelMuted: Color(0xFF382A60),
  panelBorder: Color(0xFF504078),
  accent: Color(0xFFB47FFF),
  accentMuted: Color(0xFF361A60),
  success: Color(0xFF68C090),
  successMuted: Color(0xFF183828),
  warning: Color(0xFFCCAA50),
  warningMuted: Color(0xFF3C2E10),
  info: Color(0xFF72C0E0),
  infoMuted: Color(0xFF163040),
  danger: Color(0xFFE08888),
  dangerMuted: Color(0xFF4A1E1E),
  chatOutgoing: Color(0xFF3A1070),
  chatIncoming: Color(0xFF221840),
  storyActive: Color(0xFFB47FFF),
  storyInactive: Color(0xFF504078),
  storyOverlay: Color(0xD90A0618),
  imagePlaceholder: Color(0xFF362A60),
  imageError: Color(0xFF44346C),
  foreground: Color(0xFFF2EEFF),
  foregroundMuted: Color(0xFFBBAAE0),
  foregroundOnAccent: Color(0xFF0E0420),
  adminExperiment: Color(0xFFCC90FF),
  cardRadius: 24,
  buttonRadius: 22,
  inputRadius: 22,
  panelBorderWidth: 0.7,
);

// ---------------------------------------------------------------------------
// Zinc — noir editorial, electric teal accent, razor-sharp
// ---------------------------------------------------------------------------

const _zincLight = SdalThemeTokens(
  canvas: Color(0xFFF3F4F6),
  canvasSubtle: Color(0xFFE6E8EC),
  panel: Color(0xFFFAFAFB),
  panelRaised: Color(0xFFEDEEF1),
  panelMuted: Color(0xFFDFE1E6),
  panelBorder: Color(0xFFBCC0C8),
  accent: Color(0xFF0891B2),
  accentMuted: Color(0xFFCCF0F8),
  success: Color(0xFF1E6844),
  successMuted: Color(0xFFD0EDE0),
  warning: Color(0xFF7A5A14),
  warningMuted: Color(0xFFF0E2C0),
  info: Color(0xFF1C4A6E),
  infoMuted: Color(0xFFCCDCF0),
  danger: Color(0xFF9E3430),
  dangerMuted: Color(0xFFF0D8D6),
  chatOutgoing: Color(0xFF1A3A48),
  chatIncoming: Color(0xFFFAFAFB),
  storyActive: Color(0xFF0891B2),
  storyInactive: Color(0xFFA0AABC),
  storyOverlay: Color(0xB30A0C10),
  imagePlaceholder: Color(0xFFD4D8E0),
  imageError: Color(0xFFC8CCD4),
  foreground: Color(0xFF101216),
  foregroundMuted: Color(0xFF545C68),
  foregroundOnAccent: Color(0xFFF0FAFF),
  adminExperiment: Color(0xFF4860A8),
  cardRadius: 6,
  buttonRadius: 4,
  inputRadius: 6,
  panelBorderWidth: 0.8,
);

const _zincDark = SdalThemeTokens(
  canvas: Color(0xFF0A0A0B),
  canvasSubtle: Color(0xFF101012),
  panel: Color(0xFF141416),
  panelRaised: Color(0xFF1C1C1E),
  panelMuted: Color(0xFF242428),
  panelBorder: Color(0xFF34343A),
  accent: Color(0xFF22D3EE),
  accentMuted: Color(0xFF0E2A2E),
  success: Color(0xFF4ADE80),
  successMuted: Color(0xFF0E2818),
  warning: Color(0xFFFBBF24),
  warningMuted: Color(0xFF2C2008),
  info: Color(0xFF38BDF8),
  infoMuted: Color(0xFF0C2030),
  danger: Color(0xFFF87171),
  dangerMuted: Color(0xFF2C1010),
  chatOutgoing: Color(0xFF1A3038),
  chatIncoming: Color(0xFF141416),
  storyActive: Color(0xFF22D3EE),
  storyInactive: Color(0xFF34343A),
  storyOverlay: Color(0xD9020204),
  imagePlaceholder: Color(0xFF1C1C24),
  imageError: Color(0xFF242430),
  foreground: Color(0xFFF4F4F5),
  foregroundMuted: Color(0xFF848490),
  foregroundOnAccent: Color(0xFF02080A),
  adminExperiment: Color(0xFF7090D8),
  cardRadius: 6,
  buttonRadius: 4,
  inputRadius: 6,
  panelBorderWidth: 0.8,
);

// ---------------------------------------------------------------------------
// Ember — wildfire amber, rich luxury gold, warm depth
// ---------------------------------------------------------------------------

const _emberLight = SdalThemeTokens(
  canvas: Color(0xFFFDF7EE),
  canvasSubtle: Color(0xFFF5E8D6),
  panel: Color(0xFFFFFEF8),
  panelRaised: Color(0xFFF8EDD8),
  panelMuted: Color(0xFFEEDCC0),
  panelBorder: Color(0xFFD4A860),
  accent: Color(0xFFD4700A),
  accentMuted: Color(0xFFFFF0CC),
  success: Color(0xFF1E6844),
  successMuted: Color(0xFFD0EDE0),
  warning: Color(0xFF8A5A10),
  warningMuted: Color(0xFFF2E0B8),
  info: Color(0xFF2A5478),
  infoMuted: Color(0xFFCCE4F4),
  danger: Color(0xFF9E3428),
  dangerMuted: Color(0xFFF4D4D0),
  chatOutgoing: Color(0xFF6A3800),
  chatIncoming: Color(0xFFFFFEF8),
  storyActive: Color(0xFFD4700A),
  storyInactive: Color(0xFFCCB080),
  storyOverlay: Color(0xB3221200),
  imagePlaceholder: Color(0xFFECDCAC),
  imageError: Color(0xFFE0CC9C),
  foreground: Color(0xFF2A1400),
  foregroundMuted: Color(0xFF6C4C1A),
  foregroundOnAccent: Color(0xFFFFFAF0),
  adminExperiment: Color(0xFF7050A0),
  cardRadius: 16,
  buttonRadius: 14,
  inputRadius: 14,
  panelBorderWidth: 0.8,
);

const _emberDark = SdalThemeTokens(
  canvas: Color(0xFF1A1000),
  canvasSubtle: Color(0xFF221800),
  panel: Color(0xFF2C1C00),
  panelRaised: Color(0xFF382400),
  panelMuted: Color(0xFF443000),
  panelBorder: Color(0xFF664410),
  accent: Color(0xFFFFB800),
  accentMuted: Color(0xFF5C3800),
  success: Color(0xFF78C098),
  successMuted: Color(0xFF1C3C28),
  warning: Color(0xFFD4AA50),
  warningMuted: Color(0xFF3E2800),
  info: Color(0xFF78C0D8),
  infoMuted: Color(0xFF163040),
  danger: Color(0xFFE08878),
  dangerMuted: Color(0xFF4A2018),
  chatOutgoing: Color(0xFF4E3400),
  chatIncoming: Color(0xFF2C1C00),
  storyActive: Color(0xFFFFB800),
  storyInactive: Color(0xFF705030),
  storyOverlay: Color(0xD90A0600),
  imagePlaceholder: Color(0xFF443200),
  imageError: Color(0xFF543E00),
  foreground: Color(0xFFFFF8E6),
  foregroundMuted: Color(0xFFD4A858),
  foregroundOnAccent: Color(0xFF1A0E00),
  adminExperiment: Color(0xFFCC9AFF),
  cardRadius: 16,
  buttonRadius: 14,
  inputRadius: 14,
  panelBorderWidth: 0.8,
);

// ---------------------------------------------------------------------------
// Mist — vibrant emerald, fresh vitality, spring-green dark mode
// ---------------------------------------------------------------------------

const _mistLight = SdalThemeTokens(
  canvas: Color(0xFFF0FAF5),
  canvasSubtle: Color(0xFFDFF3E8),
  panel: Color(0xFFFAFEFC),
  panelRaised: Color(0xFFEBF8F1),
  panelMuted: Color(0xFFD6F0E4),
  panelBorder: Color(0xFF9ACDB5),
  accent: Color(0xFF087F5B),
  accentMuted: Color(0xFFBBEDD8),
  success: Color(0xFF206848),
  successMuted: Color(0xFFCCEEDC),
  warning: Color(0xFF7A5A14),
  warningMuted: Color(0xFFEEE0BE),
  info: Color(0xFF245470),
  infoMuted: Color(0xFFCCE4F0),
  danger: Color(0xFF9E3838),
  dangerMuted: Color(0xFFF2D4D4),
  chatOutgoing: Color(0xFF1C5038),
  chatIncoming: Color(0xFFFAFEFC),
  storyActive: Color(0xFF087F5B),
  storyInactive: Color(0xFF8ABFAA),
  storyOverlay: Color(0xB3081A10),
  imagePlaceholder: Color(0xFFBEE8D4),
  imageError: Color(0xFFAEDCC8),
  foreground: Color(0xFF081E14),
  foregroundMuted: Color(0xFF3E6050),
  foregroundOnAccent: Color(0xFFF0FBF6),
  adminExperiment: Color(0xFF5850A8),
  cardRadius: 22,
  buttonRadius: 18,
  inputRadius: 18,
  panelBorderWidth: 0.7,
);

const _mistDark = SdalThemeTokens(
  canvas: Color(0xFF081210),
  canvasSubtle: Color(0xFF0E1C18),
  panel: Color(0xFF142018),
  panelRaised: Color(0xFF1A2C20),
  panelMuted: Color(0xFF203828),
  panelBorder: Color(0xFF2C4C38),
  accent: Color(0xFF51CF66),
  accentMuted: Color(0xFF0E3C20),
  success: Color(0xFF6CD098),
  successMuted: Color(0xFF143828),
  warning: Color(0xFFCCAA50),
  warningMuted: Color(0xFF3C2E10),
  info: Color(0xFF70C0D8),
  infoMuted: Color(0xFF143040),
  danger: Color(0xFFE08888),
  dangerMuted: Color(0xFF481E1E),
  chatOutgoing: Color(0xFF163C28),
  chatIncoming: Color(0xFF142018),
  storyActive: Color(0xFF51CF66),
  storyInactive: Color(0xFF2C4C38),
  storyOverlay: Color(0xD9040E08),
  imagePlaceholder: Color(0xFF1A3028),
  imageError: Color(0xFF223C30),
  foreground: Color(0xFFD8F5E6),
  foregroundMuted: Color(0xFF72A888),
  foregroundOnAccent: Color(0xFF041008),
  adminExperiment: Color(0xFF9898E8),
  cardRadius: 22,
  buttonRadius: 18,
  inputRadius: 18,
  panelBorderWidth: 0.7,
);
