import 'package:flutter/material.dart';

import 'palette.dart';
import 'tokens.dart';

/// Builds the two Komorebi [ThemeData]s from the design tokens (SPEC §3).
///
/// Shapes are generously rounded; surfaces are flat paper with hairline
/// borders instead of heavy elevation shadows.
ThemeData meadowTheme() => _build(
      brightness: Brightness.light,
      tokens: KomorebiTokens.meadow,
      scheme: const ColorScheme.light(
        primary: MeadowPalette.leaf,
        onPrimary: MeadowPalette.paper,
        primaryContainer: MeadowPalette.moss,
        onPrimaryContainer: MeadowPalette.ink,
        secondary: MeadowPalette.persimmon,
        onSecondary: MeadowPalette.paper,
        tertiary: MeadowPalette.sky,
        onTertiary: MeadowPalette.ink,
        error: MeadowPalette.persimmon,
        onError: MeadowPalette.paper,
        surface: MeadowPalette.paper,
        onSurface: MeadowPalette.ink,
        surfaceContainerHighest: MeadowPalette.paperDeep,
        onSurfaceVariant: MeadowPalette.inkSoft,
        outline: MeadowPalette.inkSoft,
      ),
    );

ThemeData twilightTheme() => _build(
      brightness: Brightness.dark,
      tokens: KomorebiTokens.twilight,
      scheme: const ColorScheme.dark(
        primary: TwilightPalette.lantern,
        onPrimary: TwilightPalette.night,
        primaryContainer: TwilightPalette.ember,
        onPrimaryContainer: TwilightPalette.mist,
        secondary: TwilightPalette.vermilion,
        onSecondary: TwilightPalette.mist,
        tertiary: TwilightPalette.river,
        onTertiary: TwilightPalette.mist,
        error: TwilightPalette.vermilion,
        onError: TwilightPalette.mist,
        surface: TwilightPalette.night,
        onSurface: TwilightPalette.mist,
        surfaceContainerHighest: TwilightPalette.nightRaised,
        onSurfaceVariant: TwilightPalette.mistSoft,
        outline: TwilightPalette.mistSoft,
      ),
    );

ThemeData _build({
  required Brightness brightness,
  required ColorScheme scheme,
  required KomorebiTokens tokens,
}) {
  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: tokens.paper,
  );

  final textTheme = base.textTheme
      .apply(bodyColor: tokens.ink, displayColor: tokens.ink)
      .copyWith(
        // Headings lean a little literary; body stays airy and readable.
        headlineMedium: base.textTheme.headlineMedium?.copyWith(
          color: tokens.ink,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
        titleLarge: base.textTheme.titleLarge?.copyWith(
          color: tokens.ink,
          fontWeight: FontWeight.w600,
        ),
        bodyMedium: base.textTheme.bodyMedium?.copyWith(height: 1.4),
      );

  final cardShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(16),
    side: BorderSide(color: tokens.cardBorder),
  );

  return base.copyWith(
    textTheme: textTheme,
    extensions: [tokens],
    appBarTheme: AppBarTheme(
      backgroundColor: tokens.paper,
      foregroundColor: tokens.ink,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: textTheme.titleLarge,
    ),
    cardTheme: CardThemeData(
      color: tokens.paperRaised,
      elevation: 0,
      shape: cardShape,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: tokens.paperRaised,
      indicatorColor: tokens.accentSoft,
      selectedIconTheme: IconThemeData(color: tokens.ink),
      unselectedIconTheme: IconThemeData(color: tokens.inkSoft),
      selectedLabelTextStyle: textTheme.labelMedium!.copyWith(color: tokens.ink),
      unselectedLabelTextStyle:
          textTheme.labelMedium!.copyWith(color: tokens.inkSoft),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: tokens.paperRaised,
      indicatorColor: tokens.accentSoft,
      iconTheme: WidgetStatePropertyAll(IconThemeData(color: tokens.ink)),
      labelTextStyle: WidgetStatePropertyAll(
        textTheme.labelSmall!.copyWith(color: tokens.ink),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        selectedBackgroundColor: tokens.accentSoft,
        selectedForegroundColor: tokens.ink,
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: tokens.paperRaised,
      side: BorderSide(color: tokens.cardBorder),
      shape: const StadiumBorder(),
    ),
    dividerTheme: DividerThemeData(color: tokens.cardBorder, space: 1),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: tokens.ink,
      contentTextStyle: TextStyle(color: tokens.paper),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}
