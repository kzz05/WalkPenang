import 'package:flutter/material.dart';

import 'package:walkpenang/theme/discovery_colors.dart';

/// ThemeData for the Food & Attraction Discovery module.
///
/// Separate from the shared `app_theme.dart` (which belongs to the
/// auth/profile module) so the two can be styled independently. Widget tests
/// import this too, so the rendered output matches the running app.
final ThemeData discoveryTheme = ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(
    seedColor: DiscoveryColors.tan,
    primary: DiscoveryColors.tan,
    onPrimary: Colors.white,
    surface: DiscoveryColors.surface,
    onSurface: DiscoveryColors.ink,
  ),
  scaffoldBackgroundColor: DiscoveryColors.cream,
  appBarTheme: const AppBarTheme(
    backgroundColor: DiscoveryColors.cream,
    foregroundColor: DiscoveryColors.ink,
    elevation: 0,
    scrolledUnderElevation: 0,
    centerTitle: false,
  ),
  cardTheme: CardThemeData(
    color: DiscoveryColors.surface,
    elevation: 0,
    margin: EdgeInsets.zero,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
  ),
  chipTheme: ChipThemeData(
    backgroundColor: DiscoveryColors.surface,
    selectedColor: DiscoveryColors.tan,
    side: BorderSide.none,
    labelStyle: const TextStyle(
      color: DiscoveryColors.ink,
      fontWeight: FontWeight.w500,
      fontSize: 13,
    ),
    secondaryLabelStyle: const TextStyle(
      color: Colors.white,
      fontWeight: FontWeight.w600,
      fontSize: 13,
    ),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: DiscoveryColors.surface,
    hintStyle: const TextStyle(color: DiscoveryColors.inkMuted, fontSize: 14),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(24),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(24),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(24),
      borderSide: const BorderSide(color: DiscoveryColors.tan, width: 1.5),
    ),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      backgroundColor: DiscoveryColors.tan,
      foregroundColor: Colors.white,
      minimumSize: const Size.fromHeight(52),
      textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
    ),
  ),
  bottomSheetTheme: const BottomSheetThemeData(
    backgroundColor: DiscoveryColors.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
  ),
  snackBarTheme: SnackBarThemeData(
    backgroundColor: DiscoveryColors.toast,
    contentTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
  ),
);
