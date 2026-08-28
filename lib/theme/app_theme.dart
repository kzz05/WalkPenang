import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// 🎨 Design tokens transcribed from "00 · Design Tokens".
///
/// The single source of truth for colour, type and radius across **every**
/// module — auth, map, discovery, walking and rewards all draw from here.
/// Views build widgets out of these; they never hard-code a hex value and
/// they never declare a private palette of their own.
///
/// The palette is entirely light: cream ground, white cards, sand for
/// emphasis. There is deliberately no black or near-black fill — an element
/// that needs to stand out uses [surface] (sand), not darkness.
class AppColors {
  const AppColors._();

  // ── Ground and fills ────────────────────────────────────────────────────

  /// The cream page ground behind every screen.
  static const background = Color(0xFFFFF3EA);

  /// A deeper tone of the ground, for banded sections and inset wells that
  /// need to separate from [background] without becoming a card.
  static const backgroundDeep = Color(0xFFF5DCC7);

  /// The default card, sheet and input fill.
  static const card = Color(0xFFFFFFFF);

  /// Emphasis fill — the one element on a screen that should read loudest
  /// (BMI card, bottom nav, stat headline, map overlays).
  ///
  /// This was pure black until the palette was unified; it is now the sand,
  /// so emphasis comes from warmth rather than contrast. Text on it uses
  /// [onSurface]/[onSurfaceMuted], which are dark ink — never white.
  static const surface = primary;

  /// Action fill — buttons, selected chips, the progress indicator.
  static const primary = Color(0xFFE4B592);

  /// A darker sand for pressed states and borders on [primary].
  static const primaryDeep = Color(0xFFC98F5F);

  /// Empty-avatar and progress-track fill.
  static const placeholder = Color(0xFFCFD5D0);

  // ── Ink ─────────────────────────────────────────────────────────────────

  /// Primary text, and the ink used on top of [primary] and [surface].
  static const onPrimary = Color(0xFF111111);

  /// Alias of [onPrimary], for reading clarity on emphasis surfaces.
  static const onSurface = onPrimary;

  /// Secondary body copy on the cream ground or a white card.
  static const muted = Color(0x8A111111);

  /// Secondary copy sitting on an emphasis ([surface]) fill.
  static const onSurfaceMuted = Color(0xA6111111);

  /// The faintest readable ink — captions and disabled labels.
  static const subtle = Color(0x59111111);

  // ── Lines and depth ─────────────────────────────────────────────────────

  /// Hairline around white inputs and between list rows.
  static const outline = Color(0x1F111111);

  /// White, for dividers drawn on top of a coloured fill.
  static const border = Color(0xFFFFFFFF);

  /// The single card shadow used app-wide. Warm ink rather than black, so it
  /// tints with the palette instead of greying it.
  static const cardShadow = Color(0x0F111111);

  /// Scrim over imagery, e.g. the map's attribution strip.
  static const scrim = Color(0x66111111);

  // ── Semantic status ─────────────────────────────────────────────────────
  // Each state is a saturated ink plus a pale tint for its card background.
  // Muted to sit alongside the sand palette rather than shout over it.

  /// Passing state — verified, complete, within range.
  static const success = Color(0xFF3E8E5A);
  static const successTint = Color(0xFFF0F7F2);

  /// Halfway state — acceptable but not recommended.
  static const warning = Color(0xFFD98C3F);
  static const warningTint = Color(0xFFFFF5EE);

  /// Failing state — rejected input, blocked check-in, out of range.
  static const danger = Color(0xFFC0392B);
  static const dangerTint = Color(0xFFFBEAEA);

  /// Rating stars.
  static const star = Color(0xFFE8A33D);

  // ── Data accents ────────────────────────────────────────────────────────
  // The dot colours that key a figure to its meaning on stat tiles. Kept
  // distinct from the semantic set: these label a quantity, not a state.

  /// CO₂ saved.
  static const carbon = success;

  /// Calories burned.
  static const calories = Color(0xFFE0713C);

  /// Journey completion.
  static const completion = Color(0xFF5B7FDB);

  /// Points and rewards.
  static const rewards = Color(0xFFE0A93C);

  // ── Category badges ─────────────────────────────────────────────────────
  // Soft fills keyed off a place's category, with [onPrimary] ink on top.

  static const badgeFood = Color(0xFFF5C99B);
  static const badgeHeritage = Color(0xFFE8D5BC);
  static const badgeNature = Color(0xFFC8DDB8);
  static const badgeMuseum = Color(0xFFDCCFE4);
  static const badgeShopping = Color(0xFFF3CFC6);

  // ── Map & GPS accents ───────────────────────────────────────────────────
  // Derived from the primary terracotta so map pins read as part of the same
  // palette, while still separating food from attractions at a glance. These
  // are map-specific marks, not new states — status colour still comes from
  // the shared semantic set above.

  /// Food establishment pins (UC-007).
  static const foodPin = Color(0xFFD97742);

  /// Tourist attraction pins (UC-007).
  static const attractionPin = Color(0xFF3F8A8B);

  /// Anything the Places response typed as neither food nor attraction.
  static const otherPin = Color(0xFF8A7360);

  /// Dark casing drawn under the route polyline so the terracotta line stays
  /// readable over both the cream and the night map styles.
  static const routeCasing = Color(0xFF3B2A1D);

  /// Google's own location blue — reused for the live position puck and the
  /// recentre control so the "that's me" affordance matches what tourists
  /// already recognise from Google Maps itself.
  static const navigationBlue = Color(0xFF4285F4);
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

/// Wires the tokens into Material so stock widgets (dialogs, snackbars, cards,
/// chips, inputs, sheets) inherit the brand instead of Flutter's purple
/// defaults.
///
/// Every module runs on this one theme. Anything a screen can get from here it
/// should not restate locally — that is what kept the modules looking like
/// three different apps.
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
      error: AppColors.danger,
    ),
    textTheme: GoogleFonts.jostTextTheme(base.textTheme).apply(
      bodyColor: AppColors.onPrimary,
      displayColor: AppColors.onPrimary,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.onPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: AppType.heading,
    ),
    cardTheme: const CardThemeData(
      color: AppColors.card,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.smAll),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.card,
      selectedColor: AppColors.primary,
      side: const BorderSide(color: AppColors.outline),
      labelStyle: AppType.monoValue,
      secondaryLabelStyle: AppType.monoValue,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.card,
      hintStyle: AppType.body.copyWith(color: AppColors.muted),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: const OutlineInputBorder(
        borderRadius: AppRadius.smAll,
        borderSide: BorderSide(color: AppColors.outline),
      ),
      enabledBorder: const OutlineInputBorder(
        borderRadius: AppRadius.smAll,
        borderSide: BorderSide(color: AppColors.outline),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: AppRadius.smAll,
        borderSide: BorderSide(color: AppColors.primary, width: 1.6),
      ),
      errorBorder: const OutlineInputBorder(
        borderRadius: AppRadius.smAll,
        borderSide: BorderSide(color: AppColors.danger),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        minimumSize: const Size.fromHeight(52),
        textStyle: AppType.button,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
      ),
    ),
    // One bottom bar for the whole app: a white bar, a soft cream pill behind
    // the selected item, and its icon switching from outline to filled. The
    // Discovery module's Discover/Favorites bar and HomeView's main nav both
    // render from this.
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.card,
      indicatorColor: AppColors.backgroundDeep,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      height: 64,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      indicatorShape: const RoundedRectangleBorder(
        borderRadius: AppRadius.mdAll,
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          size: 22,
          color: states.contains(WidgetState.selected)
              ? AppColors.onPrimary
              : AppColors.muted,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => AppType.body.copyWith(
          fontSize: 11,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w700
              : FontWeight.w500,
          color: states.contains(WidgetState.selected)
              ? AppColors.onPrimary
              : AppColors.muted,
        ),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.smAll),
      titleTextStyle: AppType.heading,
      contentTextStyle: AppType.body.copyWith(color: AppColors.muted),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.surface,
      contentTextStyle: AppType.body.copyWith(color: AppColors.onSurface),
      behavior: SnackBarBehavior.floating,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.smAll),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.primary,
      linearTrackColor: AppColors.placeholder,
    ),
  );
}
