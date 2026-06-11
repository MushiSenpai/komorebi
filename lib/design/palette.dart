import 'package:flutter/material.dart';

/// Raw color values for the two Komorebi themes (SPEC §3).
///
/// Nothing outside `lib/design/` should reference these directly —
/// widgets consume colors via [Theme.of] and the KomorebiTokens extension.
abstract final class MeadowPalette {
  // My Neighbor Totoro — daytime meadow.
  static const paper = Color(0xFFF6F1E1); // cream washi paper
  static const paperDeep = Color(0xFFEDE5CE); // shaded paper, cards/rails
  static const ink = Color(0xFF4A3F35); // warm brown ink
  static const inkSoft = Color(0xFF8A7B6C); // secondary text
  static const leaf = Color(0xFF7C9A6D); // soft green, primary
  static const leafDeep = Color(0xFF5E7B52); // pressed/active green
  static const moss = Color(0xFFB5C9A5); // containers, chips
  static const sky = Color(0xFF9DBBC7); // info accents
  static const persimmon = Color(0xFFCB7B5C); // warm highlight / danger-soft
  static const blossom = Color(0xFFE3B7B1); // tertiary accents
}

abstract final class TwilightPalette {
  // Spirited Away — evening bathhouse.
  static const night = Color(0xFF1B2238); // deep indigo base
  static const nightRaised = Color(0xFF242C47); // cards, rails
  static const mist = Color(0xFFD8D3C4); // primary text, lantern-lit paper
  static const mistSoft = Color(0xFF9A96A8); // secondary text
  static const lantern = Color(0xFFE8A84C); // lantern gold, primary
  static const lanternDeep = Color(0xFFC78A33); // pressed/active gold
  static const ember = Color(0xFF6B4F2A); // gold containers
  static const vermilion = Color(0xFFC3514E); // bathhouse red accent
  static const river = Color(0xFF5A7E9E); // cool info accent
  static const spirit = Color(0xFF8FA98F); // soft green-grey tertiary
}
