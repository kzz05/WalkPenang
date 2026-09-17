// ---------------------------------------------------------------------------
// profile_form_fields_test.dart
// Profile — switching units must carry the typed values across
// ---------------------------------------------------------------------------
//
// Driving the mixin through a bare ChangeNotifier rather than
// EditProfileController: the conversion logic is the part worth pinning down,
// and this way it runs without Firebase, an ImagePicker or a profile store.

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:walkpenang/constants/country_dial_codes.dart';
import 'package:walkpenang/constants/unit_system.dart';
import 'package:walkpenang/constants/validation_messages.dart';
import 'package:walkpenang/controllers/profile_form_fields.dart';

class _Fields extends ChangeNotifier with ProfileFormFields {
  int notifications = 0;

  @override
  void safeNotify() {
    notifications++;
    notifyListeners();
  }
}

void main() {
  late _Fields fields;

  setUp(() => fields = _Fields());
  tearDown(() => fields.disposeProfileFormFields());

  group('seeding from a stored profile', () {
    test('metric fills the centimetres box and leaves feet/inches empty', () {
      fields.seedProfileFields(heightCm: 173, weightKg: 68, units: 'metric');
      expect(fields.heightCtrl.text, '173');
      expect(fields.weightCtrl.text, '68');
      expect(fields.heightFeetCtrl.text, isEmpty);
      expect(fields.heightInchesCtrl.text, isEmpty);
    });

    test('imperial fills feet and inches instead', () {
      fields.seedProfileFields(heightCm: 172.72, weightKg: 68, units: 'imperial');
      expect(fields.heightFeetCtrl.text, '5');
      expect(fields.heightInchesCtrl.text, '8');
      expect(fields.weightCtrl.text, '150');
      expect(fields.heightCtrl.text, isEmpty);
    });

    test('an empty profile leaves the boxes blank rather than showing 0', () {
      fields.seedProfileFields(heightCm: 0, weightKg: 0, units: 'metric');
      expect(fields.heightCtrl.text, isEmpty);
      expect(fields.weightCtrl.text, isEmpty);
    });

    test('a number stored with no country defaults to Malaysia', () {
      fields.seedProfileFields(
        heightCm: 173,
        weightKg: 68,
        units: 'metric',
        phoneNumber: '123456789',
      );
      expect(fields.phoneCountry.isoCode, kDefaultCountryIso);
      expect(fields.phoneNational, '123456789');
    });
  });

  group('switching units mid-form', () {
    // Without this the boxes keep their old numbers under new captions, so
    // "173" would sit in a field now labelled `ft`.
    test('metric to imperial converts what is already typed', () {
      fields.seedProfileFields(heightCm: 173, weightKg: 68, units: 'metric');
      fields.setUnits('imperial');

      expect(fields.unitSystem, UnitSystem.imperial);
      expect(fields.heightFeetCtrl.text, '5');
      expect(fields.heightInchesCtrl.text, '8');
      expect(fields.weightCtrl.text, '150');
    });

    test('imperial back to metric converts the other way', () {
      fields.seedProfileFields(heightCm: 172.72, weightKg: 68, units: 'imperial');
      fields.setUnits('metric');

      expect(fields.unitSystem, UnitSystem.metric);
      expect(double.parse(fields.heightCtrl.text), closeTo(172.7, 0.05));
      expect(double.parse(fields.weightCtrl.text), closeTo(68.0, 0.1));
      expect(fields.heightFeetCtrl.text, isEmpty);
    });

    test('picks up edits made since the screen opened', () {
      fields.seedProfileFields(heightCm: 173, weightKg: 68, units: 'metric');
      fields.heightCtrl.text = '150';
      fields.setUnits('imperial');
      expect(fields.heightFeetCtrl.text, '4');
      expect(fields.heightInchesCtrl.text, '11');
    });

    test('empty boxes stay empty instead of converting to nonsense', () {
      fields.setUnits('imperial');
      expect(fields.heightFeetCtrl.text, isEmpty);
      expect(fields.heightInchesCtrl.text, isEmpty);
      expect(fields.weightCtrl.text, isEmpty);
    });

    test('unparseable input is not turned into a number', () {
      fields.heightCtrl.text = '.';
      fields.weightCtrl.text = 'abc';
      fields.setUnits('imperial');
      expect(fields.heightFeetCtrl.text, isEmpty);
      expect(fields.heightInchesCtrl.text, isEmpty);
      expect(fields.weightCtrl.text, isEmpty);
    });

    test('a trailing decimal point still converts, since it parses', () {
      // `double.tryParse('17.')` is 17.0, so this is a real 17 cm rather than
      // half-typed rubbish — converting it to 0'7" is the honest answer, and
      // the validator is what tells the tourist it is far too short.
      fields.heightCtrl.text = '17.';
      fields.setUnits('imperial');
      expect(fields.heightFeetCtrl.text, '0');
      expect(fields.heightInchesCtrl.text, '7');
    });

    test('re-selecting the current unit changes nothing and does not notify',
        () {
      fields.seedProfileFields(heightCm: 173, weightKg: 68, units: 'metric');
      fields.notifications = 0;
      fields.setUnits('metric');
      expect(fields.notifications, 0);
      expect(fields.heightCtrl.text, '173');
    });
  });

  group('reading back in canonical metric', () {
    test('imperial input is converted, never stored as typed', () {
      // The original bug: 67 inches went into heightCm as 67, and 150 lb went
      // into weightKg as 150, corrupting BMI and every calorie figure after.
      fields.setUnits('imperial');
      fields.heightFeetCtrl.text = '5';
      fields.heightInchesCtrl.text = '7';
      fields.weightCtrl.text = '150';

      expect(fields.readHeightCm(), closeTo(170.18, 0.01));
      expect(fields.readWeightKg(), closeTo(68.04, 0.01));
    });

    test('metric input passes through untouched', () {
      fields.heightCtrl.text = '173';
      fields.weightCtrl.text = '68';
      expect(fields.readHeightCm(), 173);
      expect(fields.readWeightKg(), 68);
    });

    test('unreadable input reads as null, not zero', () {
      fields.heightCtrl.text = 'tall';
      expect(fields.readHeightCm(), isNull);
      expect(fields.readWeightKg(), isNull);
    });
  });

  group('saving does not drift an untouched value', () {
    test('an imperial profile saved unchanged keeps its exact centimetres', () {
      fields.seedProfileFields(heightCm: 173.4, weightKg: 68.2, units: 'imperial');
      expect(fields.resolvedHeightCm(173.4), 173.4);
      expect(fields.resolvedWeightKg(68.2), 68.2);
    });

    test('an edited imperial value does convert', () {
      fields.seedProfileFields(heightCm: 173.4, weightKg: 68.2, units: 'imperial');
      fields.heightInchesCtrl.text = '10';
      expect(fields.resolvedHeightCm(173.4), closeTo(177.8, 0.01));
    });

    test('a blank box falls back to the stored value', () {
      fields.seedProfileFields(heightCm: 173, weightKg: 68, units: 'metric');
      fields.heightCtrl.clear();
      expect(fields.resolvedHeightCm(173), 173);
    });
  });

  group('validation follows the selected unit', () {
    test('weight is judged in kilograms or pounds accordingly', () {
      // 400 is an impossible weight in kilograms and an ordinary one in
      // pounds, so the same input has to be judged differently per unit.
      expect(fields.validateWeight('400'), ValidationMessages.weightOutOfRange);
      fields.setUnits('imperial');
      expect(fields.validateWeight('400'), isNull);
      // And the message names the unit the tourist is actually typing in.
      expect(fields.validateWeight('700'),
          ValidationMessages.weightOutOfRangeLb);
    });

    test('height uses one box in metric and two in imperial', () {
      expect(fields.validateHeight('173'), isNull);
      fields.setUnits('imperial');
      expect(fields.validateHeightFeet('5'), isNull);
      expect(fields.validateHeightInches('8'), isNull);
    });

    test('phone rules follow the selected country', () {
      fields.setPhoneCountry(countryByIso('US'));
      expect(fields.phoneCountry.dialCode, '1');
      expect(fields.validatePhone('4155550100'), isNull);
      // Valid in Singapore, not in the United States.
      expect(fields.validatePhone('91234567'),
          ValidationMessages.phoneInvalidForCountry('United States'));
    });
  });

  group('the stored number is canonical', () {
    test('a typed trunk zero is not what reaches Firestore', () {
      fields.setPhoneCountry(countryByIso('MY'));
      fields.phoneCtrl.text = '0123456789';
      // The tourist may write their number however they like; the profile
      // stores the national number libphonenumber resolves it to.
      expect(fields.phoneNational, '123456789');
    });

    test('a number that needs no change passes through untouched', () {
      fields.setPhoneCountry(countryByIso('MY'));
      fields.phoneCtrl.text = '1112013343';
      expect(fields.phoneNational, '1112013343');
    });

    test('a leading zero that belongs to the number is kept', () {
      fields.setPhoneCountry(countryByIso('IT'));
      fields.phoneCtrl.text = '0612345678';
      expect(fields.phoneNational, '0612345678');
    });

    test('an empty field stores nothing', () {
      fields.phoneCtrl.text = '   ';
      expect(fields.phoneNational, '');
    });
  });
}
