import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// 🎨 Design tokens transcribed from "00 · Design Tokens".
///
/// The single source of truth for colour, type and radius across **every**
/// module — auth, map, discovery, walking and rewards all draw from here.
/// Views build widgets out of these; they never hard-code a hex value and
/// they never declare a private palette of their own.
///
/// The palette is derived from the logo: indigo `#3F22EC`, mint `#3EFFC0`,
/// pink `#FA66AE`, sampled from the artwork rather than eyeballed.
///
/// Mint and pink both fail WCAG contrast on white (1.4:1 and 2.9:1), so they
/// never carry text, small icons or thin strokes on a light surface. Indigo
/// passes at 9.5:1 and does the UI work; mint and pink live on the map, on
/// tinted washes, and as fills. Where their meaning is needed *in text*, the
/// darkened family members [success] and [secondaryInk] stand in.
///
/// Neutrals are cooled toward indigo so the chrome sits with the brand rather
/// than looking like grey borrowed from elsewhere.
class AppColors {
  const AppColors._();

  // ── Ground and fills ────────────────────────────────────────────────────

  /// The page ground behind every screen.
  static const background = Color(0xFFF7F6FD);

  /// A deeper tone of the ground, for banded sections and inset wells that
  /// need to separate from [background] without becoming a card.
  static const backgroundDeep = Color(0xFFEDEBF8);

  /// The default card, sheet and input fill.
  static const card = Color(0xFFFFFFFF);

  /// Emphasis fill — bottom nav, BMI card, stat headline, selected rows.
  ///
  /// No longer an alias of [primary]. Indigo is saturated enough that it needs
  /// white text, whereas these surfaces are full of dark body copy; the pale
  /// indigo wash gives them separation while keeping [onSurface] ink readable.
  static const surface = Color(0xFFEDEBF8);

  /// Action fill — buttons, active tab, the user's location dot.
  static const primary = Color(0xFF3F22EC);

  /// Pressed and held states.
  static const primaryDeep = Color(0xFF2A16A8);

  /// Empty-avatar and progress-track fill.
  static const placeholder = Color(0xFFD9D6EC);

  // ── Ink ─────────────────────────────────────────────────────────────────

  /// Body text — an indigo-tinted near-black, 16.4:1 on white.
  ///
  /// Note this is ink, *not* the colour to put on a [primary] fill. Indigo
  /// buttons take [onPrimaryFill]. The two were the same token while [primary]
  /// was a pale sand; a saturated primary forces them apart.
  static const onPrimary = Color(0xFF14103A);

  /// Text and icons sitting on a saturated [primary] or [primaryDeep] fill.
  static const onPrimaryFill = Color(0xFFFFFFFF);

  /// Alias of [onPrimary], for reading clarity on emphasis surfaces.
  static const onSurface = onPrimary;

  /// Supporting text on the ground or a white card.
  static const muted = Color(0xFF4A4668);

  /// Secondary copy sitting on an emphasis ([surface]) fill.
  static const onSurfaceMuted = Color(0xFF4A4668);

  /// The faintest readable ink — captions, placeholders and disabled labels.
  static const subtle = Color(0xFF8E8AAE);

  // ── Lines and depth ─────────────────────────────────────────────────────

  /// Hairline around inputs and between list rows.
  static const outline = Color(0xFFD9D6EC);

  /// White, for dividers drawn on top of a coloured fill.
  static const border = Color(0xFFFFFFFF);

  /// The single card shadow used app-wide. Indigo-tinted ink rather than
  /// black, so it tints with the palette instead of greying it.
  static const cardShadow = Color(0x1414103A);

  /// Scrim over imagery, e.g. the map's loading state.
  static const scrim = Color(0x6614103A);

  // ── Semantic status ─────────────────────────────────────────────────────
  // Each state is a saturated ink plus a pale tint for its card background.

  /// Passing state — verified, complete, within range. The readable member of
  /// the mint family, since mint itself cannot carry text.
  static const success = Color(0xFF00875F);
  static const successTint = Color(0xFFDFF9EE);

  /// Halfway state — acceptable but not recommended.
  static const warning = Color(0xFFFFB020);
  static const warningTint = Color(0xFFFFF4E0);

  /// Failing state — rejected input, blocked check-in, out of range.
  ///
  /// Warm red rather than a true red: pure red sits too close to the brand
  /// pink at a glance, and in this app pink means "tap here, there's a mural".
  static const danger = Color(0xFFE8384F);
  static const dangerTint = Color(0xFFFDEAEC);

  /// Rating stars.
  static const star = Color(0xFFFFB020);

  // ── Brand accents ───────────────────────────────────────────────────────
  // The two logo colours that cannot carry text, plus their readable inks.
  // Reserved meanings: mint is always *your route*, pink is always *a place*.

  /// Mint — route line, progress fill, "walking now". Fills only.
  static const accent = Color(0xFF3EFFC0);

  /// Pink — POI markers and category pills. Fills only.
  static const secondary = Color(0xFFFA66AE);

  /// The readable pink, for saved/favourite icons and text.
  static const secondaryInk = Color(0xFFB22C72);

  // Pale washes — the way a brand colour gets to fill an area behind ink
  // without the ink losing contrast.

  /// Selected rows and chip backgrounds.
  static const primaryWash = Color(0xFFEDEBF8);

  /// Success badges and completed stops.
  static const accentWash = Color(0xFFDFF9EE);

  /// Saved-list and saved-button background.
  static const secondaryWash = Color(0xFFFFEAF4);

  // ── Data accents ────────────────────────────────────────────────────────
  // The dot colours that key a figure to its meaning on stat tiles. Kept
  // distinct from the semantic set: these label a quantity, not a state.

  /// CO₂ saved.
  static const carbon = success;

  /// Calories burned.
  static const calories = secondaryInk;

  /// Journey completion.
  static const completion = primary;

  /// Points and rewards.
  static const rewards = Color(0xFFFFB020);

  // ── Category badges ─────────────────────────────────────────────────────
  // Soft washes keyed off a place's category, with [onPrimary] ink on top.

  static const badgeFood = Color(0xFFFFEAF4);
  static const badgeHeritage = Color(0xFFEDEBF8);
  static const badgeNature = Color(0xFFDFF9EE);
  static const badgeMuseum = Color(0xFFE6E3F5);
  static const badgeShopping = Color(0xFFFFF4E0);
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
      onPrimary: AppColors.onPrimaryFill,
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
      secondaryLabelStyle:
          AppType.monoValue.copyWith(color: AppColors.onPrimaryFill),
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
        foregroundColor: AppColors.onPrimaryFill,
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
