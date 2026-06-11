import 'package:flutter/material.dart';

import 'palette.dart';

/// Komorebi's semantic design tokens, attached to [ThemeData] as an extension.
///
/// Use `context.komorebi` (see extension below) instead of reaching for
/// palette constants, so widgets automatically follow the active theme.
@immutable
class KomorebiTokens extends ThemeExtension<KomorebiTokens> {
  const KomorebiTokens({
    required this.paper,
    required this.paperRaised,
    required this.ink,
    required this.inkSoft,
    required this.accent,
    required this.accentSoft,
    required this.warmAccent,
    required this.coolAccent,
    required this.danger,
    required this.cardBorder,
  });

  /// App background — the "page" everything sits on.
  final Color paper;

  /// Raised surfaces: cards, rails, sheets.
  final Color paperRaised;

  /// Primary text / icon ink.
  final Color ink;

  /// Secondary text ink.
  final Color inkSoft;

  /// The theme's signature accent (meadow leaf / lantern gold).
  final Color accent;

  /// Tinted containers for the accent (chips, selected states).
  final Color accentSoft;

  /// Warm secondary accent (persimmon / vermilion).
  final Color warmAccent;

  /// Cool secondary accent (sky / river).
  final Color coolAccent;

  /// Errors and destructive actions.
  final Color danger;

  /// Hairline border used on cards for the hand-drawn outline feel.
  final Color cardBorder;

  static const meadow = KomorebiTokens(
    paper: MeadowPalette.paper,
    paperRaised: MeadowPalette.paperDeep,
    ink: MeadowPalette.ink,
    inkSoft: MeadowPalette.inkSoft,
    accent: MeadowPalette.leaf,
    accentSoft: MeadowPalette.moss,
    warmAccent: MeadowPalette.persimmon,
    coolAccent: MeadowPalette.sky,
    danger: MeadowPalette.persimmon,
    cardBorder: Color(0x334A3F35),
  );

  static const twilight = KomorebiTokens(
    paper: TwilightPalette.night,
    paperRaised: TwilightPalette.nightRaised,
    ink: TwilightPalette.mist,
    inkSoft: TwilightPalette.mistSoft,
    accent: TwilightPalette.lantern,
    accentSoft: TwilightPalette.ember,
    warmAccent: TwilightPalette.vermilion,
    coolAccent: TwilightPalette.river,
    danger: TwilightPalette.vermilion,
    cardBorder: Color(0x33D8D3C4),
  );

  @override
  KomorebiTokens copyWith({
    Color? paper,
    Color? paperRaised,
    Color? ink,
    Color? inkSoft,
    Color? accent,
    Color? accentSoft,
    Color? warmAccent,
    Color? coolAccent,
    Color? danger,
    Color? cardBorder,
  }) {
    return KomorebiTokens(
      paper: paper ?? this.paper,
      paperRaised: paperRaised ?? this.paperRaised,
      ink: ink ?? this.ink,
      inkSoft: inkSoft ?? this.inkSoft,
      accent: accent ?? this.accent,
      accentSoft: accentSoft ?? this.accentSoft,
      warmAccent: warmAccent ?? this.warmAccent,
      coolAccent: coolAccent ?? this.coolAccent,
      danger: danger ?? this.danger,
      cardBorder: cardBorder ?? this.cardBorder,
    );
  }

  @override
  KomorebiTokens lerp(KomorebiTokens? other, double t) {
    if (other == null) return this;
    return KomorebiTokens(
      paper: Color.lerp(paper, other.paper, t)!,
      paperRaised: Color.lerp(paperRaised, other.paperRaised, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      inkSoft: Color.lerp(inkSoft, other.inkSoft, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
      warmAccent: Color.lerp(warmAccent, other.warmAccent, t)!,
      coolAccent: Color.lerp(coolAccent, other.coolAccent, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      cardBorder: Color.lerp(cardBorder, other.cardBorder, t)!,
    );
  }
}

extension KomorebiTokensX on BuildContext {
  KomorebiTokens get komorebi => Theme.of(this).extension<KomorebiTokens>()!;
}
