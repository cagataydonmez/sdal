import 'package:flutter/material.dart';
import 'sdal_app_theme.dart';
import 'sdal_theme_tokens.dart';

final ThemeData sdalLightTheme = buildSdalLightTheme();
final ThemeData sdalDarkTheme = buildSdalDarkTheme();

ThemeData buildSdalLightTheme([SdalAppTheme appTheme = SdalAppTheme.kor]) =>
    _buildSdalTheme(
      brightness: Brightness.light,
      tokens: appTheme.lightTokens,
      appTheme: appTheme,
    );

ThemeData buildSdalDarkTheme([SdalAppTheme appTheme = SdalAppTheme.kor]) =>
    _buildSdalTheme(
      brightness: Brightness.dark,
      tokens: appTheme.darkTokens,
      appTheme: appTheme,
    );

ThemeData _buildSdalTheme({
  required Brightness brightness,
  required SdalThemeTokens tokens,
  SdalAppTheme appTheme = SdalAppTheme.kor,
}) {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: tokens.accent,
    brightness: brightness,
  ).copyWith(
    primary: tokens.accent,
    secondary: tokens.info,
    surface: tokens.panel,
    onSurface: tokens.foreground,
    onPrimary: tokens.foregroundOnAccent,
    onSecondary: tokens.foregroundOnAccent,
    outline: tokens.panelBorder,
    error: tokens.danger,
    onError: tokens.foregroundOnAccent,
  );

  // For Kor we use the local Manrope asset via fontFamily.
  // For all other themes Google Fonts handles font loading.
  final fontFamily = appTheme == SdalAppTheme.kor
      ? 'Manrope'
      : appTheme.materialFontFamily;

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: tokens.canvas,
    brightness: brightness,
    fontFamily: fontFamily,
    extensions: <ThemeExtension<dynamic>>[tokens],
  );

  // Apply the per-theme typeface across all text styles.
  final tt = appTheme.applyFont(base.textTheme);

  // Shape helpers derived from per-theme tokens.
  final cardShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(tokens.cardRadius),
    side: tokens.panelBorderWidth > 0
        ? BorderSide(color: tokens.panelBorder, width: tokens.panelBorderWidth)
        : BorderSide.none,
  );
  final buttonShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(tokens.buttonRadius),
  );
  final inputRadius = BorderRadius.circular(tokens.inputRadius);
  final inputBorder = tokens.panelBorderWidth > 0
      ? BorderSide(color: tokens.panelBorder, width: tokens.panelBorderWidth)
      : BorderSide.none;
  final inputFocusedBorder = tokens.panelBorderWidth > 0
      ? BorderSide(color: tokens.accent, width: tokens.panelBorderWidth + 0.5)
      : BorderSide(color: tokens.accent, width: 1.5);

  return base.copyWith(
    textTheme: tt.copyWith(
      headlineMedium: tt.headlineMedium?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.8,
        color: tokens.foreground,
      ),
      headlineSmall: tt.headlineSmall?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.4,
        color: tokens.foreground,
      ),
      titleLarge: tt.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
        color: tokens.foreground,
      ),
      titleMedium: tt.titleMedium?.copyWith(
        fontWeight: FontWeight.w700,
        color: tokens.foreground,
      ),
      labelLarge: tt.labelLarge?.copyWith(
        fontWeight: FontWeight.w600,
        color: tokens.foreground,
      ),
      bodyLarge: tt.bodyLarge?.copyWith(color: tokens.foreground),
      bodyMedium: tt.bodyMedium?.copyWith(color: tokens.foreground),
      bodySmall: tt.bodySmall?.copyWith(color: tokens.foregroundMuted),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: tokens.foreground,
      elevation: 0,
      centerTitle: false,
      scrolledUnderElevation: 0,
    ),
    cardTheme: CardThemeData(
      color: tokens.panel,
      elevation: 0,
      shape: cardShape,
      margin: EdgeInsets.zero,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: tokens.panel.withValues(alpha: 0.96),
      indicatorColor: tokens.accentMuted,
      surfaceTintColor: Colors.transparent,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w700
              : FontWeight.w600,
          color: states.contains(WidgetState.selected)
              ? tokens.foreground
              : tokens.foregroundMuted,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: tokens.panel,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: inputRadius,
        borderSide: inputBorder,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: inputRadius,
        borderSide: inputBorder,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: inputRadius,
        borderSide: inputFocusedBorder,
      ),
      labelStyle: TextStyle(color: tokens.foregroundMuted),
      hintStyle: TextStyle(color: tokens.foregroundMuted),
      helperStyle: TextStyle(color: tokens.foregroundMuted),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: tokens.panelRaised,
      contentTextStyle: TextStyle(color: tokens.foreground),
      actionTextColor: tokens.accent,
      behavior: SnackBarBehavior.floating,
    ),
    dividerTheme: DividerThemeData(
      color: tokens.panelBorder,
      space: 1,
      thickness: 1,
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: tokens.panelMuted,
      side: BorderSide(color: tokens.panelBorder),
      selectedColor: tokens.accentMuted,
      labelStyle: TextStyle(color: tokens.foreground),
      secondaryLabelStyle: TextStyle(color: tokens.foreground),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(SdalThemeTokens.radiusPill),
      ),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: tokens.accent,
      linearTrackColor: tokens.panelMuted,
      circularTrackColor: tokens.panelMuted,
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: tokens.accent,
      foregroundColor: tokens.foregroundOnAccent,
      shape: buttonShape,
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return tokens.accentMuted;
          return tokens.panel;
        }),
        foregroundColor: WidgetStateProperty.all(tokens.foreground),
        side: WidgetStateProperty.all(
          BorderSide(
            color: tokens.panelBorder,
            width: tokens.panelBorderWidth.clamp(0.5, 2.0),
          ),
        ),
        shape: WidgetStateProperty.all(buttonShape),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: tokens.accent,
        foregroundColor: tokens.foregroundOnAccent,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        shape: buttonShape,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: tokens.foreground,
        side: BorderSide(color: tokens.panelBorder),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        shape: buttonShape,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: tokens.accent),
    ),
  );
}
