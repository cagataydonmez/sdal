import 'package:flutter/material.dart';
import 'sdal_theme_tokens.dart';

final ThemeData sdalLightTheme = buildSdalLightTheme();
final ThemeData sdalDarkTheme = buildSdalDarkTheme();

ThemeData buildSdalLightTheme() => _buildSdalTheme(
  brightness: Brightness.light,
  tokens: SdalThemeTokens.light,
);

ThemeData buildSdalDarkTheme() =>
    _buildSdalTheme(brightness: Brightness.dark, tokens: SdalThemeTokens.dark);

ThemeData _buildSdalTheme({
  required Brightness brightness,
  required SdalThemeTokens tokens,
}) {
  final colorScheme =
      ColorScheme.fromSeed(
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

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: tokens.canvas,
    brightness: brightness,
    fontFamily: 'Manrope',
    extensions: <ThemeExtension<dynamic>>[tokens],
  );

  return base.copyWith(
    textTheme: base.textTheme.copyWith(
      headlineMedium: base.textTheme.headlineMedium?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.8,
        color: tokens.foreground,
      ),
      headlineSmall: base.textTheme.headlineSmall?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.4,
        color: tokens.foreground,
      ),
      titleLarge: base.textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
        color: tokens.foreground,
      ),
      titleMedium: base.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w700,
        color: tokens.foreground,
      ),
      labelLarge: base.textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w600,
        color: tokens.foreground,
      ),
      bodyLarge: base.textTheme.bodyLarge?.copyWith(color: tokens.foreground),
      bodyMedium: base.textTheme.bodyMedium?.copyWith(color: tokens.foreground),
      bodySmall: base.textTheme.bodySmall?.copyWith(
        color: tokens.foregroundMuted,
      ),
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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(SdalThemeTokens.radius2xl),
        side: BorderSide(color: tokens.panelBorder),
      ),
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
        borderRadius: BorderRadius.circular(SdalThemeTokens.radiusXl),
        borderSide: BorderSide(color: tokens.panelBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(SdalThemeTokens.radiusXl),
        borderSide: BorderSide(color: tokens.panelBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(SdalThemeTokens.radiusXl),
        borderSide: BorderSide(color: tokens.accent, width: 1.5),
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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(SdalThemeTokens.radiusXl),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return tokens.accentMuted;
          return tokens.panel;
        }),
        foregroundColor: WidgetStateProperty.all(tokens.foreground),
        side: WidgetStateProperty.all(BorderSide(color: tokens.panelBorder)),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(SdalThemeTokens.radiusLg),
          ),
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: tokens.accent,
        foregroundColor: tokens.foregroundOnAccent,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SdalThemeTokens.radiusLg),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: tokens.foreground,
        side: BorderSide(color: tokens.panelBorder),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SdalThemeTokens.radiusLg),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: tokens.accent),
    ),
  );
}
