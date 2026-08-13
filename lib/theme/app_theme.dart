import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// 🎨 Design tokens transcribed from "00 · Design Tokens".
///
/// This file is the single source of truth for colour, type and radius.
/// Views build widgets out of these — they never hard-code a hex value.
class AppColors {
  const AppColors._();

  // ── Tokens straight from the spec sheet ─────────────────────────────────
  static const primary = Color(0xFFE4B592);
  static const background = Color(0xFFFFF3EA);
  static const surface = Color(0xFF000000);
  static const onPrimary = Color(0xFF111111);
  static const border = Color(0xFFFFFFFF);

  // ── Derived shades, so the mockups' greys stay consistent ───────────────
  /// Hairline around white inputs and between settings rows.
  static const outline = Color(0x1F111111);

  /// Secondary body copy sitting on the cream background.
  static const muted = Color(0x8A111111);

  /// Secondary copy sitting inside a black surface.
  static const onSurfaceMuted = Color(0x99FFFFFF);

  /// Empty-avatar and progress-track fill.
  static const placeholder = Color(0xFFCFD5D0);

  // ── Semantic status shades ──────────────────────────────────────────────
  // Muted to sit alongside the sand palette rather than shout over it. Used
  // by the password strength meter and any other pass/warn/fail read-out.

  /// Failing state — a rejected field or a weak password.
  static const danger = Color(0xFFC0492F);

  /// Halfway state — acceptable but not recommended.
  static const warning = Color(0xFFD98C3F);

  /// Passing state — every requirement met.
  static const success = Color(0xFF3F7D58);
}

/// Corner radii — SM 10 for cards and inputs, MD 50 for pills.
class AppRadius {
  const AppRadius._();

  static const double sm = 10;
  static const double md = 50;

  static const smAll = BorderRadius.all(Radius.circular(sm));
  static const mdAll = BorderRadius.all(Radius.circular(md));
}

/// Type ramp — Jost for everything human-readable, IBM Plex Mono for the
/// small uppercase labels that give the design its instrument-panel feel.
class AppType {
  const AppType._();

  /// Jost Bold 32 — page titles.
  static TextStyle get display => GoogleFonts.jost(
    fontSize: 32,
    fontWeight: FontWeight.w700,
    color: AppColors.onPrimary,
    height: 1.1,
    letterSpacing: -0.4,
  );

  /// Jost SemiBold 18 — card titles and section headings.
  static TextStyle get heading => GoogleFonts.jost(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: AppColors.onPrimary,
  );

  /// Jost Medium 15 — body copy and text-field values.
  static TextStyle get body => GoogleFonts.jost(
    fontSize: 15,
    fontWeight: FontWeight.w500,
    color: AppColors.onPrimary,
  );

  /// IBM Plex Mono 10 — the uppercase micro-labels. Always tracked out wide.
  static TextStyle get mono => GoogleFonts.ibmPlexMono(
    fontSize: 10,
    fontWeight: FontWeight.w400,
    letterSpacing: 1.6,
    color: AppColors.muted,
  );

  /// Same mono, sized for chips and read-out values.
  static TextStyle get monoValue => GoogleFonts.ibmPlexMono(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.6,
    color: AppColors.onPrimary,
  );

  /// Jost Bold 26 — the big numbers on stat tiles and the BMI card.
  static TextStyle get stat => GoogleFonts.jost(
    fontSize: 26,
    fontWeight: FontWeight.w700,
    color: AppColors.onPrimary,
    height: 1.1,
  );

  /// Jost Bold 15, tracked out — every pill button in the app.
  static TextStyle get button => GoogleFonts.jost(
    fontSize: 15,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.1,
    color: AppColors.onPrimary,
  );
}

/// Wires the tokens into Material so stock widgets (dialogs, snackbars,
/// text selection) inherit the brand instead of Flutter's purple defaults.
ThemeData buildAppTheme() {
  final base = ThemeData(useMaterial3: true);

  return base.copyWith(
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
    ).copyWith(
      primary: AppColors.primary,
      onPrimary: AppColors.onPrimary,
      surface: AppColors.background,
      onSurface: AppColors.onPrimary,
    ),
    textTheme: GoogleFonts.jostTextTheme(base.textTheme).apply(
      bodyColor: AppColors.onPrimary,
      displayColor: AppColors.onPrimary,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.smAll),
      titleTextStyle: AppType.heading,
      contentTextStyle: AppType.body.copyWith(color: AppColors.muted),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.surface,
      contentTextStyle: AppType.body.copyWith(color: Colors.white),
      behavior: SnackBarBehavior.floating,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.smAll),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.primary,
      linearTrackColor: AppColors.placeholder,
    ),
  );
}
