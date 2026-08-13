import 'package:flutter/material.dart';

/// Palette for the Food & Attraction Discovery module, taken from the Figma
/// mockups: warm cream backgrounds, tan actions, soft category badges.
///
/// Kept separate from the shared `app_theme.dart` so this module can be
/// styled without touching the auth/profile module's theme.
abstract final class DiscoveryColors {
  static const Color cream = Color(0xFFFAE8D9);
  static const Color creamDeep = Color(0xFFF5DCC7);
  static const Color tan = Color(0xFFDFA878);
  static const Color tanDark = Color(0xFFC98F5F);
  static const Color ink = Color(0xFF3D3229);
  static const Color inkMuted = Color(0xFF8A7965);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color toast = Color(0xFF2B2B2B);
  static const Color successBg = Color(0xFFDCEBD3);
  static const Color successInk = Color(0xFF3E6B33);
  static const Color errorBg = Color(0xFFF6D6D6);
  static const Color errorInk = Color(0xFF8B3A3A);
  static const Color star = Color(0xFFE8A33D);

  /// Badge fills, keyed off the place category.
  static const Color badgeFood = Color(0xFFF5C99B);
  static const Color badgeHeritage = Color(0xFFE8D5BC);
  static const Color badgeNature = Color(0xFFC8DDB8);
  static const Color badgeMuseum = Color(0xFFDCCFE4);
  static const Color badgeShopping = Color(0xFFF3CFC6);
}
