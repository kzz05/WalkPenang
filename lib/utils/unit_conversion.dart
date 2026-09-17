import '../constants/unit_system.dart';

/// Conversions between the stored metric body metrics and what an imperial
/// tourist types and reads.
///
/// [UserProfile] stores centimetres and kilograms and nothing else. These
/// helpers exist purely so the profile form and the settings read-out can
/// speak the user's chosen units without any other part of the app — BMI, the
/// calorie model, the reward ledger — having to know a preference exists.
class UnitConversion {
  const UnitConversion._();

  /// Exact by definition (international yard and pound agreement, 1959).
  static const double cmPerInch = 2.54;
  static const double kgPerPound = 0.45359237;
  static const int inchesPerFoot = 12;

  // ── Height ────────────────────────────────────────────────────────────────

  static double feetInchesToCm(int feet, double inches) =>
      (feet * inchesPerFoot + inches) * cmPerInch;

  static double cmToTotalInches(double cm) => cm / cmPerInch;

  /// Splits a stored height into whole feet and whole inches for display.
  ///
  /// Inches are rounded to the nearest whole inch because that is how people
  /// state their height; 11.6in rounds up to 12 and carries into the next
  /// foot rather than rendering the impossible `5' 12"`.
  static ImperialHeight cmToFeetInches(double cm) {
    if (!cm.isFinite || cm <= 0) return const ImperialHeight(0, 0);
    var inches = (cmToTotalInches(cm)).round();
    final feet = inches ~/ inchesPerFoot;
    inches = inches % inchesPerFoot;
    return ImperialHeight(feet, inches);
  }

  // ── Weight ────────────────────────────────────────────────────────────────

  static double kgToPounds(double kg) => kg / kgPerPound;

  static double poundsToKg(double pounds) => pounds * kgPerPound;

  /// Whole pounds, matching how the field is presented.
  static int kgToDisplayPounds(double kg) {
    if (!kg.isFinite || kg <= 0) return 0;
    return kgToPounds(kg).round();
  }

  // ── Round-trip guards ─────────────────────────────────────────────────────
  //
  // Displaying 170cm as 5'7" and converting straight back yields 170.18cm, so
  // a tourist who opened Edit Profile and saved without touching anything
  // would nudge their own height every time. These two helpers keep the stored
  // value byte-identical unless the displayed figure actually changed.

  static double resolveHeightCm({
    required double storedCm,
    required int feet,
    required double inches,
  }) {
    final shown = cmToFeetInches(storedCm);
    if (shown.feet == feet && shown.inches == inches) return storedCm;
    return feetInchesToCm(feet, inches);
  }

  static double resolveWeightKg({
    required double storedKg,
    required double pounds,
  }) {
    if (kgToDisplayPounds(storedKg) == pounds) return storedKg;
    return poundsToKg(pounds);
  }

  // ── Display ───────────────────────────────────────────────────────────────

  static String formatHeight(double heightCm, UnitSystem units) {
    if (!heightCm.isFinite || heightCm <= 0) return '—';
    if (units == UnitSystem.imperial) {
      final h = cmToFeetInches(heightCm);
      return "${h.feet}' ${h.inches}\"";
    }
    return '${_trim(heightCm)} cm';
  }

  static String formatWeight(double weightKg, UnitSystem units) {
    if (!weightKg.isFinite || weightKg <= 0) return '—';
    if (units == UnitSystem.imperial) {
      return '${kgToDisplayPounds(weightKg)} lb';
    }
    return '${_trim(weightKg)} kg';
  }

  /// Drops a meaningless trailing `.0` — the settings screen rendered
  /// `170.0 cm` because it interpolated the raw double.
  static String _trim(double value) {
    final rounded = double.parse(value.toStringAsFixed(1));
    if (rounded == rounded.roundToDouble()) return rounded.toInt().toString();
    return rounded.toString();
  }

  /// The text to seed a field with, empty when there is nothing stored yet so
  /// the form shows a placeholder rather than `0`.
  static String fieldText(num value) {
    if (value <= 0) return '';
    if (value is int) return value.toString();
    return _trim(value.toDouble());
  }
}

/// A height split the way it is entered in imperial: whole feet plus whole
/// inches.
class ImperialHeight {
  final int feet;
  final int inches;

  const ImperialHeight(this.feet, this.inches);

  @override
  bool operator ==(Object other) =>
      other is ImperialHeight && other.feet == feet && other.inches == inches;

  @override
  int get hashCode => Object.hash(feet, inches);

  @override
  String toString() => "$feet' $inches\"";
}
