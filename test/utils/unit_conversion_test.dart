// ---------------------------------------------------------------------------
// unit_conversion_test.dart
// Profile — the unit toggle must not change what is stored
// ---------------------------------------------------------------------------
//
// The bug this guards: `units` used to be a string nobody read. A tourist who
// picked Imperial and typed their real height in inches passed the cm
// validator — 67 is inside 50-250 — and 67 was written to `heightCm`. The same
// for 150 lb landing in `weightKg`, which then fed distanceKm * weightKg * 0.9
// and the BMI getter. Conversion is the whole fix, so it is tested directly.

import 'package:test/test.dart';
import 'package:walkpenang/constants/unit_system.dart';
import 'package:walkpenang/constants/validation_messages.dart';
import 'package:walkpenang/utils/unit_conversion.dart';

void main() {
  group('height', () {
    test('splits centimetres into feet and inches', () {
      expect(UnitConversion.cmToFeetInches(170), const ImperialHeight(5, 7));
      expect(UnitConversion.cmToFeetInches(172.72), const ImperialHeight(5, 8));
      expect(UnitConversion.cmToFeetInches(182.88), const ImperialHeight(6, 0));
    });

    test('carries into the next foot rather than showing 12 inches', () {
      // 5'11.6" must read 6'0", not the impossible 5'12".
      expect(UnitConversion.cmToFeetInches(182.3), const ImperialHeight(6, 0));
    });

    test('converts feet and inches back to centimetres', () {
      expect(UnitConversion.feetInchesToCm(5, 8), closeTo(172.72, 1e-9));
      expect(UnitConversion.feetInchesToCm(0, 1), closeTo(2.54, 1e-9));
    });

    test('an absent height is not rendered as zero feet', () {
      expect(UnitConversion.cmToFeetInches(0), const ImperialHeight(0, 0));
      expect(UnitConversion.cmToFeetInches(double.nan),
          const ImperialHeight(0, 0));
    });
  });

  group('weight', () {
    test('converts between kilograms and pounds', () {
      expect(UnitConversion.kgToDisplayPounds(68), 150);
      expect(UnitConversion.poundsToKg(150), closeTo(68.0389, 1e-4));
      expect(UnitConversion.kgToPounds(100), closeTo(220.462, 1e-3));
    });
  });

  group('round-tripping does not drift the stored value', () {
    // 170 cm displays as 5'7", and 5'7" converts back to 170.18 cm. Re-saving
    // an untouched profile would nudge the tourist's own height every time
    // they opened the screen, so an unchanged display must keep the original.
    test('an untouched height keeps its exact stored centimetres', () {
      final shown = UnitConversion.cmToFeetInches(170);
      final resolved = UnitConversion.resolveHeightCm(
        storedCm: 170,
        feet: shown.feet,
        inches: shown.inches.toDouble(),
      );
      expect(resolved, 170.0);
    });

    test('repeated saves never accumulate drift', () {
      var stored = 173.4;
      for (var i = 0; i < 20; i++) {
        final shown = UnitConversion.cmToFeetInches(stored);
        stored = UnitConversion.resolveHeightCm(
          storedCm: stored,
          feet: shown.feet,
          inches: shown.inches.toDouble(),
        );
      }
      expect(stored, 173.4);
    });

    test('an edited height does convert', () {
      expect(
        UnitConversion.resolveHeightCm(storedCm: 170, feet: 5, inches: 8),
        closeTo(172.72, 1e-9),
      );
    });

    test('an untouched weight keeps its exact stored kilograms', () {
      final pounds = UnitConversion.kgToDisplayPounds(68).toDouble();
      expect(
        UnitConversion.resolveWeightKg(storedKg: 68, pounds: pounds),
        68.0,
      );
    });

    test('an edited weight does convert', () {
      expect(
        UnitConversion.resolveWeightKg(storedKg: 68, pounds: 160),
        closeTo(72.5748, 1e-4),
      );
    });
  });

  group('the imperial bounds round inwards from the metric ones', () {
    // Validators check imperial entries against the imperial constants so the
    // rule enforced is exactly the rule the message states. That is only safe
    // while every imperial bound converts to a metric value inside the stored
    // range — otherwise the form would accept a height it then rejects, or
    // reject the very figure its own message calls allowed.
    test('the height bounds convert inside the centimetre range', () {
      final min = UnitConversion.feetInchesToCm(
        ValidationMessages.heightMinFeet,
        ValidationMessages.heightMinInches.toDouble(),
      );
      final max = UnitConversion.feetInchesToCm(
        ValidationMessages.heightMaxFeet,
        ValidationMessages.heightMaxInches.toDouble(),
      );
      expect(min, greaterThanOrEqualTo(ValidationMessages.heightMinCm));
      expect(max, lessThanOrEqualTo(ValidationMessages.heightMaxCm));
      // And they are the tightest such bounds — one inch further out would
      // escape the range, which is what makes them the right pair.
      expect(min - UnitConversion.cmPerInch,
          lessThan(ValidationMessages.heightMinCm));
      expect(max + UnitConversion.cmPerInch,
          greaterThan(ValidationMessages.heightMaxCm));
    });

    test('the weight bounds convert inside the kilogram range', () {
      final min = UnitConversion.poundsToKg(
          ValidationMessages.weightMinLb.toDouble());
      final max = UnitConversion.poundsToKg(
          ValidationMessages.weightMaxLb.toDouble());
      expect(min, greaterThanOrEqualTo(ValidationMessages.weightMinKg));
      expect(max, lessThanOrEqualTo(ValidationMessages.weightMaxKg));
      expect(UnitConversion.poundsToKg(ValidationMessages.weightMinLb - 1),
          lessThan(ValidationMessages.weightMinKg));
      expect(UnitConversion.poundsToKg(ValidationMessages.weightMaxLb + 1),
          greaterThan(ValidationMessages.weightMaxKg));
    });
  });

  group('display formatting', () {
    test('drops a meaningless trailing zero', () {
      // Settings interpolated the raw double and read "170.0 cm".
      expect(UnitConversion.formatHeight(170.0, UnitSystem.metric), '170 cm');
      expect(UnitConversion.formatWeight(68.0, UnitSystem.metric), '68 kg');
    });

    test('keeps a meaningful decimal', () {
      expect(UnitConversion.formatHeight(170.5, UnitSystem.metric), '170.5 cm');
    });

    test('renders imperial in the units the tourist chose', () {
      expect(UnitConversion.formatHeight(170, UnitSystem.imperial), '5\' 7"');
      expect(UnitConversion.formatWeight(68, UnitSystem.imperial), '150 lb');
    });

    test('an unset metric reads as a dash, not a zero', () {
      expect(UnitConversion.formatHeight(0, UnitSystem.metric), '—');
      expect(UnitConversion.formatWeight(0, UnitSystem.imperial), '—');
    });
  });

  group('UnitSystem parsing', () {
    test('round-trips the stored string', () {
      expect(UnitSystem.fromStorage('metric'), UnitSystem.metric);
      expect(UnitSystem.fromStorage('imperial'), UnitSystem.imperial);
      expect(UnitSystem.imperial.storageValue, 'imperial');
    });

    test('anything unrecognised falls back to metric', () {
      // A profile written before the preference existed, or a typo, must not
      // stop the screen from loading.
      expect(UnitSystem.fromStorage(null), UnitSystem.metric);
      expect(UnitSystem.fromStorage(''), UnitSystem.metric);
      expect(UnitSystem.fromStorage('Imperial'), UnitSystem.metric);
    });
  });
}
