import 'package:flutter/material.dart';

import '../constants/country_dial_codes.dart';
import '../constants/unit_system.dart';
import '../utils/phone_number_rules.dart';
import '../utils/unit_conversion.dart';
import '../utils/validators.dart';

/// The height, weight and phone fields shared by the sign-up profile step and
/// the edit-profile screen.
///
/// Both screens ask for exactly the same things under exactly the same rules —
/// "a profile that was valid at registration can't be edited into an invalid
/// one" — so the controllers held two copies of this logic. Unit conversion
/// makes that duplication expensive to get right twice, hence one mixin.
mixin ProfileFormFields on ChangeNotifier {
  // ── Height and weight ─────────────────────────────────────────────────────

  /// Centimetres. Used when [unitSystem] is metric.
  final TextEditingController heightCtrl = TextEditingController();

  /// Whole feet and the inches beside them. Used when [unitSystem] is
  /// imperial — people say "five eight", not "68 inches".
  final TextEditingController heightFeetCtrl = TextEditingController();
  final TextEditingController heightInchesCtrl = TextEditingController();

  /// Kilograms or pounds depending on [unitSystem]; one box either way.
  final TextEditingController weightCtrl = TextEditingController();

  final TextEditingController phoneCtrl = TextEditingController();

  UnitSystem _unitSystem = UnitSystem.metric;
  Country _phoneCountry = countryByIso(kDefaultCountryIso);

  UnitSystem get unitSystem => _unitSystem;

  /// The string the profile persists. Views bind the dropdown to this.
  String get units => _unitSystem.storageValue;

  bool get isImperial => _unitSystem == UnitSystem.imperial;

  Country get phoneCountry => _phoneCountry;

  /// Each controller guards against notifying after disposal; the mixin defers
  /// to that rather than calling [notifyListeners] behind its back.
  void safeNotify();

  /// Fills the fields from a stored profile. Call once, from the constructor.
  void seedProfileFields({
    required double heightCm,
    required double weightKg,
    required String units,
    String? phoneNumber,
    String? phoneCountryIso,
  }) {
    _unitSystem = UnitSystem.fromStorage(units);
    _phoneCountry = countryByIso(phoneCountryIso);
    phoneCtrl.text = phoneNumber ?? '';
    _writeHeight(heightCm > 0 ? heightCm : null);
    _writeWeight(weightKg > 0 ? weightKg : null);
  }

  /// Switches units, carrying whatever is already typed across.
  ///
  /// Without the conversion the boxes keep their old numbers under new labels,
  /// so `173` would sit in a field now captioned `ft`. Anything empty or
  /// half-typed stays empty rather than being converted to nonsense.
  void setUnits(String? value) {
    final next = UnitSystem.fromStorage(value);
    if (next == _unitSystem) return;

    final heightCm = readHeightCm();
    final weightKg = readWeightKg();
    _unitSystem = next;
    _writeHeight(heightCm);
    _writeWeight(weightKg);
    safeNotify();
  }

  void setPhoneCountry(Country country) {
    _phoneCountry = country;
    safeNotify();
  }

  // ── Reading the fields back in canonical metric ───────────────────────────

  /// The typed height in centimetres, or null when the boxes are empty or
  /// unparseable. Always metric — that is what the profile stores.
  double? readHeightCm() {
    if (!isImperial) {
      final parsed = double.tryParse(heightCtrl.text.trim());
      return (parsed != null && parsed.isFinite && parsed > 0) ? parsed : null;
    }
    final feet = int.tryParse(heightFeetCtrl.text.trim());
    final inches = double.tryParse(heightInchesCtrl.text.trim());
    if (feet == null || inches == null || !inches.isFinite) return null;
    final cm = UnitConversion.feetInchesToCm(feet, inches);
    return cm > 0 ? cm : null;
  }

  /// The typed weight in kilograms, or null when the box is empty.
  double? readWeightKg() {
    final parsed = double.tryParse(weightCtrl.text.trim());
    if (parsed == null || !parsed.isFinite || parsed <= 0) return null;
    return isImperial ? UnitConversion.poundsToKg(parsed) : parsed;
  }

  /// The height to save, preserving [storedCm] when the displayed figure has
  /// not changed — see the round-trip note in [UnitConversion].
  double resolvedHeightCm(double storedCm) {
    if (!isImperial) return readHeightCm() ?? storedCm;
    final feet = int.tryParse(heightFeetCtrl.text.trim());
    final inches = double.tryParse(heightInchesCtrl.text.trim());
    if (feet == null || inches == null || !inches.isFinite) return storedCm;
    return UnitConversion.resolveHeightCm(
      storedCm: storedCm,
      feet: feet,
      inches: inches,
    );
  }

  /// The weight to save, preserving [storedKg] when the displayed figure has
  /// not changed.
  double resolvedWeightKg(double storedKg) {
    if (!isImperial) return readWeightKg() ?? storedKg;
    final pounds = double.tryParse(weightCtrl.text.trim());
    if (pounds == null || !pounds.isFinite) return storedKg;
    return UnitConversion.resolveWeightKg(
      storedKg: storedKg,
      pounds: pounds,
    );
  }

  /// The number as it should be stored: canonical national digits, with the
  /// dial code living separately in [phoneCountry].
  ///
  /// Runs the typed text back through libphonenumber so a tourist who writes
  /// their number the way they always write it — `0123456789` — still has
  /// `123456789` written to Firestore. Unparseable text is returned as typed;
  /// the form's validator blocks the save before it can reach storage.
  String get phoneNational {
    final raw = phoneCtrl.text.trim();
    if (raw.isEmpty) return '';
    final check = PhoneNumberRules.check(raw, _phoneCountry);
    return check.isValid ? check.nationalNumber : raw;
  }

  // ── Validation ────────────────────────────────────────────────────────────

  String? validateHeight(String? v) => Validators.heightCm(v);

  String? validateHeightFeet(String? v) => Validators.heightFeet(v);

  /// Reports the combined feet + inches range as well as the inches box
  /// itself, because the total is only knowable once both are in hand.
  String? validateHeightInches(String? v) =>
      Validators.heightImperial(heightFeetCtrl.text, v);

  String? validateWeight(String? v) =>
      isImperial ? Validators.weightLb(v) : Validators.weightKg(v);

  String? validatePhone(String? v) =>
      Validators.phoneNational(v, _phoneCountry);

  // ── Internals ─────────────────────────────────────────────────────────────

  void _writeHeight(double? cm) {
    if (cm == null) {
      heightCtrl.clear();
      heightFeetCtrl.clear();
      heightInchesCtrl.clear();
      return;
    }
    if (isImperial) {
      final h = UnitConversion.cmToFeetInches(cm);
      heightFeetCtrl.text = h.feet.toString();
      heightInchesCtrl.text = h.inches.toString();
      heightCtrl.clear();
    } else {
      heightCtrl.text = UnitConversion.fieldText(cm);
      heightFeetCtrl.clear();
      heightInchesCtrl.clear();
    }
  }

  void _writeWeight(double? kg) {
    if (kg == null) {
      weightCtrl.clear();
      return;
    }
    weightCtrl.text = isImperial
        ? UnitConversion.kgToDisplayPounds(kg).toString()
        : UnitConversion.fieldText(kg);
  }

  void disposeProfileFormFields() {
    heightCtrl.dispose();
    heightFeetCtrl.dispose();
    heightInchesCtrl.dispose();
    weightCtrl.dispose();
    phoneCtrl.dispose();
  }
}
